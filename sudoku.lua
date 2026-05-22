-- sudoku with friends helper
-- botão Sudoku On/Off
-- funciona no tabuleiro que você estiver em cima

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local sudokuEnabled = false
local currentBoard = nil
local currentCells = nil
local currentBoardKey = nil

local connections = {}
local dragConnections = {}

local SCAN_INTERVAL = 0.35
local lastScan = 0

local BUTTON_NAME = "SudokuToggleGui"
local SOLVER_VALUE_NAME = "SolverValue"

local function getChar()
	return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getHRP()
	local char = getChar()
	return char:FindFirstChild("HumanoidRootPart")
end

local function disconnectAll()
	for _, c in ipairs(connections) do
		pcall(function()
			c:Disconnect()
		end)
	end

	table.clear(connections)
end

local function clearSolverValues()
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj.Name == SOLVER_VALUE_NAME then
			obj:Destroy()
		end
	end
end

local function clearCurrentBoard()
	disconnectAll()
	clearSolverValues()
	currentBoard = nil
	currentCells = nil
	currentBoardKey = nil
end

local function readNumberFromCell(cell)
	local clue = cell:FindFirstChild("ClueValue")

	if clue and clue:IsA("TextLabel") then
		local txt = tostring(clue.Text or ""):gsub("%s+", "")

		if txt:match("^[1-9]$") then
			return tonumber(txt)
		end
	end

	if cell:IsA("TextButton") or cell:IsA("TextLabel") or cell:IsA("TextBox") then
		local txt = tostring(cell.Text or ""):gsub("%s+", "")

		if txt:match("^[1-9]$") then
			return tonumber(txt)
		end
	end

	for _, obj in ipairs(cell:GetChildren()) do
		if obj.Name ~= SOLVER_VALUE_NAME then
			if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
				local txt = tostring(obj.Text or ""):gsub("%s+", "")

				if txt:match("^[1-9]$") then
					return tonumber(txt)
				end
			end
		end
	end

	return 0
end

local function getCells(surfaceGui)
	local frame = surfaceGui:FindFirstChild("Frame")
	if not frame then
		return nil
	end

	local cells = {}
	local total = 0

	for _, cell in ipairs(frame:GetChildren()) do
		local row = cell:GetAttribute("Row")
		local col = cell:GetAttribute("Col")

		if typeof(row) == "number" and typeof(col) == "number" then
			if row >= 1 and row <= 9 and col >= 1 and col <= 9 then
				cells[row] = cells[row] or {}
				cells[row][col] = cell
				total += 1
			end
		end
	end

	if total < 81 then
		return nil
	end

	return cells
end

local function buildGrid(cells)
	local grid = {}

	for r = 1, 9 do
		grid[r] = {}

		for c = 1, 9 do
			local cell = cells[r] and cells[r][c]
			grid[r][c] = cell and readNumberFromCell(cell) or 0
		end
	end

	return grid
end

local function copyGrid(grid)
	local new = {}

	for r = 1, 9 do
		new[r] = {}

		for c = 1, 9 do
			new[r][c] = grid[r][c]
		end
	end

	return new
end

local function canPlace(grid, num, row, col)
	for c = 1, 9 do
		if grid[row][c] == num then
			return false
		end
	end

	for r = 1, 9 do
		if grid[r][col] == num then
			return false
		end
	end

	local startRow = math.floor((row - 1) / 3) * 3 + 1
	local startCol = math.floor((col - 1) / 3) * 3 + 1

	for r = startRow, startRow + 2 do
		for c = startCol, startCol + 2 do
			if grid[r][c] == num then
				return false
			end
		end
	end

	return true
end

local function validateGrid(grid)
	for r = 1, 9 do
		for c = 1, 9 do
			local v = grid[r][c]

			if v ~= 0 then
				grid[r][c] = 0

				if not canPlace(grid, v, r, c) then
					grid[r][c] = v
					return false
				end

				grid[r][c] = v
			end
		end
	end

	return true
end

local function findEmpty(grid)
	for r = 1, 9 do
		for c = 1, 9 do
			if grid[r][c] == 0 then
				return r, c
			end
		end
	end

	return nil, nil
end

local function solve(grid)
	local row, col = findEmpty(grid)

	if not row then
		return true
	end

	for num = 1, 9 do
		if canPlace(grid, num, row, col) then
			grid[row][col] = num

			if solve(grid) then
				return true
			end

			grid[row][col] = 0
		end
	end

	return false
end

local function removeSolverNumber(cell)
	local old = cell:FindFirstChild(SOLVER_VALUE_NAME)

	if old then
		old:Destroy()
	end
end

local function addNumberOnCell(cell, number)
	removeSolverNumber(cell)

	local value = Instance.new("TextLabel")
	value.Name = SOLVER_VALUE_NAME
	value.Size = UDim2.new(1, 0, 1, 0)
	value.Position = UDim2.new(0, 0, 0, 0)
	value.BackgroundTransparency = 1
	value.Text = tostring(number)
	value.TextColor3 = Color3.fromRGB(0, 170, 255)
	value.TextStrokeTransparency = 0
	value.TextScaled = true
	value.Font = Enum.Font.GothamBlack
	value.ZIndex = 999
	value.Parent = cell
end

local function watchCell(cell)
	local function check()
		task.wait()

		if not sudokuEnabled then
			return
		end

		local current = readNumberFromCell(cell)

		if current ~= 0 then
			removeSolverNumber(cell)
		end
	end

	local clue = cell:FindFirstChild("ClueValue")

	if clue and clue:IsA("TextLabel") then
		table.insert(connections, clue:GetPropertyChangedSignal("Text"):Connect(check))
	end

	table.insert(connections, cell.ChildAdded:Connect(function(child)
		task.wait()

		if child.Name ~= SOLVER_VALUE_NAME then
			check()

			if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
				table.insert(connections, child:GetPropertyChangedSignal("Text"):Connect(check))
			end
		end
	end))

	table.insert(connections, cell.ChildRemoved:Connect(function()
		task.wait()
		check()
	end))
end

local function getBoardKey(surfaceGui)
	local ok, name = pcall(function()
		return surfaceGui:GetFullName()
	end)

	if ok then
		return name
	end

	return tostring(surfaceGui)
end

local function isValidBoardSurface(surfaceGui)
	if not surfaceGui or not surfaceGui:IsA("SurfaceGui") then
		return false
	end

	if not surfaceGui:IsDescendantOf(workspace:FindFirstChild("PlacedBoards") or workspace) then
		return false
	end

	local cells = getCells(surfaceGui)

	return cells ~= nil
end

local function findBoardFromPart(part)
	if not part then
		return nil
	end

	local placedBoards = workspace:FindFirstChild("PlacedBoards")
	if not placedBoards then
		return nil
	end

	local candidates = {}

	local function addCandidate(obj)
		if obj and obj:IsA("SurfaceGui") and isValidBoardSurface(obj) then
			table.insert(candidates, obj)
		end
	end

	for _, obj in ipairs(part:GetDescendants()) do
		addCandidate(obj)
	end

	for _, obj in ipairs(part:GetChildren()) do
		addCandidate(obj)
	end

	local parent = part.Parent
	while parent and parent ~= workspace do
		for _, obj in ipairs(parent:GetDescendants()) do
			addCandidate(obj)
		end

		if parent:IsDescendantOf(placedBoards) then
			break
		end

		parent = parent.Parent
	end

	if #candidates > 0 then
		return candidates[1]
	end

	return nil
end

local function findBoardUnderPlayer()
	local hrp = getHRP()
	if not hrp then
		return nil
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {LocalPlayer.Character}
	params.IgnoreWater = true

	local origin = hrp.Position + Vector3.new(0, 2, 0)
	local direction = Vector3.new(0, -18, 0)

	local result = workspace:Raycast(origin, direction, params)

	if result and result.Instance then
		local board = findBoardFromPart(result.Instance)

		if board then
			return board
		end
	end

	local placedBoards = workspace:FindFirstChild("PlacedBoards")
	if not placedBoards then
		return nil
	end

	local bestBoard = nil
	local bestDist = math.huge

	for _, obj in ipairs(placedBoards:GetDescendants()) do
		if obj:IsA("SurfaceGui") and isValidBoardSurface(obj) then
			local part = obj:FindFirstAncestorWhichIsA("BasePart")

			if part then
				local localPos = part.CFrame:PointToObjectSpace(hrp.Position)
				local halfX = part.Size.X / 2 + 3
				local halfZ = part.Size.Z / 2 + 3
				local vertical = math.abs(localPos.Y)

				if math.abs(localPos.X) <= halfX and math.abs(localPos.Z) <= halfZ and vertical <= 12 then
					local dist = (part.Position - hrp.Position).Magnitude

					if dist < bestDist then
						bestDist = dist
						bestBoard = obj
					end
				end
			end
		end
	end

	return bestBoard
end

local function solveBoard(surfaceGui)
	if not surfaceGui or not surfaceGui.Parent then
		return
	end

	local cells = getCells(surfaceGui)
	if not cells then
		return
	end

	local original = buildGrid(cells)

	if not validateGrid(original) then
		return
	end

	local solved = copyGrid(original)

	if not solve(solved) then
		return
	end

	disconnectAll()
	clearSolverValues()

	local count = 0

	for r = 1, 9 do
		for c = 1, 9 do
			if original[r][c] == 0 then
				local cell = cells[r] and cells[r][c]

				if cell then
					count += 1
					addNumberOnCell(cell, solved[r][c])
					watchCell(cell)
				end
			end
		end
	end

	currentBoard = surfaceGui
	currentCells = cells
	currentBoardKey = getBoardKey(surfaceGui)

	print("Sudoku: tabuleiro resolvido | dicas mostradas: " .. tostring(count))
end

local function refreshCurrentBoard()
	if not sudokuEnabled then
		return
	end

	local board = findBoardUnderPlayer()

	if not board then
		if currentBoard then
			clearCurrentBoard()
		end

		return
	end

	local key = getBoardKey(board)

	if key ~= currentBoardKey then
		solveBoard(board)
	end
end

local function setSudokuEnabled(state)
	sudokuEnabled = state and true or false

	if not sudokuEnabled then
		clearCurrentBoard()
	else
		refreshCurrentBoard()
	end
end

local function clearOldButton()
	local old = PlayerGui:FindFirstChild(BUTTON_NAME)

	if old then
		old:Destroy()
	end

	for _, c in ipairs(dragConnections) do
		pcall(function()
			c:Disconnect()
		end)
	end

	table.clear(dragConnections)
end

local function bindDrag(button)
	local dragging = false
	local dragStart = nil
	local startPos = nil
	local moved = false

	table.insert(dragConnections, button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			moved = false
			dragStart = input.Position
			startPos = button.Position
		end
	end))

	table.insert(dragConnections, UserInputService.InputChanged:Connect(function(input)
		if dragging and dragStart and startPos then
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
				local delta = input.Position - dragStart

				if delta.Magnitude > 6 then
					moved = true
				end

				button.Position = UDim2.new(
					startPos.X.Scale,
					startPos.X.Offset + delta.X,
					startPos.Y.Scale,
					startPos.Y.Offset + delta.Y
				)
			end
		end
	end))

	table.insert(dragConnections, UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) then
			dragging = false

			task.delay(0.05, function()
				moved = false
			end)
		end
	end))

	return function()
		return moved
	end
end

local function createButton()
	clearOldButton()

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = BUTTON_NAME
	screenGui.ResetOnSpawn = false
	screenGui.Parent = PlayerGui

	local button = Instance.new("TextButton")
	button.Name = "SudokuButton"
	button.Size = UDim2.new(0, 132, 0, 46)
	button.Position = UDim2.new(0, 22, 0.58, 0)
	button.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	button.BorderSizePixel = 0
	button.Text = "Sudoku Off"
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 16
	button.Font = Enum.Font.GothamBold
	button.AutoButtonColor = false
	button.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Thickness = 1
	stroke.Transparency = 0.85
	stroke.Parent = button

	local isDragging = bindDrag(button)

	local function updateVisual()
		button.Text = sudokuEnabled and "Sudoku On" or "Sudoku Off"

		TweenService:Create(button, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = sudokuEnabled and Color3.fromRGB(25, 25, 25) or Color3.fromRGB(0, 0, 0)
		}):Play()
	end

	button.Activated:Connect(function()
		if isDragging() then
			return
		end

		setSudokuEnabled(not sudokuEnabled)
		updateVisual()
	end)

	updateVisual()
end

createButton()

table.insert(connections, RunService.Heartbeat:Connect(function()
	if not sudokuEnabled then
		return
	end

	local now = os.clock()

	if now - lastScan >= SCAN_INTERVAL then
		lastScan = now
		refreshCurrentBoard()
	end
end))

LocalPlayer.CharacterAdded:Connect(function()
	task.wait(1)

	if sudokuEnabled then
		clearCurrentBoard()
		refreshCurrentBoard()
	end
end)

print("Sudoku helper carregado. use o botão Sudoku On/Off.")
