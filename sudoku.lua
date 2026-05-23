-- sudoku with friends helper
-- botão estilo Wallhop do Cerber X
-- sem On/Off: clicou, executa o solver inteiro no tabuleiro embaixo de você

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

local BUTTON_GUI_NAME = "SudokuCerberButtonGui"
local SOLVER_VALUE_NAME = "SolverValue"

local currentBoard = nil
local currentBoardKey = nil
local currentCells = nil
local currentSolution = nil
local currentCellStates = nil

local solverConnections = {}
local dragConnections = {}
local shadowRegistry = {}

local lastAutoFill = 0
local AUTOFILL_INTERVAL = 0.08
local lastAutoFillKey = nil

local function noTextStroke(obj)
	pcall(function()
		obj.TextStrokeTransparency = 1
	end)
end

local function registerShadow(host, shadow)
	shadowRegistry[host] = shadowRegistry[host] or {}
	table.insert(shadowRegistry[host], shadow)
end

local function setHostShadowVisible(host, visible)
	local list = shadowRegistry[host]
	if not list then
		return
	end

	for _, shadow in ipairs(list) do
		shadow.Visible = visible
		shadow.BackgroundTransparency = visible and shadow:GetAttribute("BaseTransparency") or 1
	end
end

local function addTrueRoundedShadow(parent, cornerRadius, strength, shadowColor)
	strength = strength or 1
	shadowColor = shadowColor or Color3.fromRGB(0, 0, 0)

	local layers = {
		{grow = math.floor(8 * strength), transparency = 0.82, y = 2},
		{grow = math.floor(16 * strength), transparency = 0.90, y = 4},
		{grow = math.floor(24 * strength), transparency = 0.95, y = 6},
	}

	for _, cfg in ipairs(layers) do
		local shadow = Instance.new("Frame")
		shadow.Name = "TrueShadow"
		shadow.AnchorPoint = Vector2.new(0.5, 0.5)
		shadow.Position = UDim2.new(0.5, 0, 0.5, cfg.y)
		shadow.Size = UDim2.new(1, cfg.grow, 1, cfg.grow)
		shadow.BackgroundColor3 = shadowColor
		shadow.BackgroundTransparency = cfg.transparency
		shadow.BorderSizePixel = 0
		shadow.ZIndex = math.max(parent.ZIndex - 1, 0)
		shadow.Parent = parent
		shadow:SetAttribute("BaseTransparency", cfg.transparency)

		Instance.new("UICorner", shadow).CornerRadius =
			UDim.new(0, cornerRadius + math.floor(cfg.grow / 2.1))

		registerShadow(parent, shadow)
	end
end

local function clearSolverConnections()
	for _, c in ipairs(solverConnections) do
		pcall(function()
			c:Disconnect()
		end)
	end

	table.clear(solverConnections)
end

local function clearDragConnections()
	for _, c in ipairs(dragConnections) do
		pcall(function()
			c:Disconnect()
		end)
	end

	table.clear(dragConnections)
end

local function clearSolverValues()
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj.Name == SOLVER_VALUE_NAME then
			obj:Destroy()
		end
	end
end

local function clearCurrentSolver()
	clearSolverConnections()
	clearSolverValues()

	currentBoard = nil
	currentBoardKey = nil
	currentCells = nil
	currentSolution = nil
	currentCellStates = nil
	lastAutoFillKey = nil
end

local function getChar()
	return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getHRP()
	local char = getChar()
	return char:FindFirstChild("HumanoidRootPart")
end

local function readNumberFromCell(cell)
	local clue = cell:FindFirstChild("ClueValue")

	if clue and clue:IsA("TextLabel") then
		local txt = tostring(clue.Text or ""):gsub("%s+", "")

		if txt:match("^[1-9]$") then
			return tonumber(txt)
		end
	end

	if cell:IsA("TextLabel") or cell:IsA("TextButton") or cell:IsA("TextBox") then
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

		local current = readNumberFromCell(cell)

		if current ~= 0 then
			removeSolverNumber(cell)
		end
	end

	local clue = cell:FindFirstChild("ClueValue")

	if clue and clue:IsA("TextLabel") then
		table.insert(solverConnections, clue:GetPropertyChangedSignal("Text"):Connect(check))
	end

	table.insert(solverConnections, cell.ChildAdded:Connect(function(child)
		task.wait()

		if child.Name ~= SOLVER_VALUE_NAME then
			check()

			if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
				table.insert(solverConnections, child:GetPropertyChangedSignal("Text"):Connect(check))
			end
		end
	end))

	table.insert(solverConnections, cell.ChildRemoved:Connect(function()
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

	local placedBoards = workspace:FindFirstChild("PlacedBoards")
	if not placedBoards then
		return false
	end

	if not surfaceGui:IsDescendantOf(placedBoards) then
		return false
	end

	return getCells(surfaceGui) ~= nil
end

local function findBoardFromPart(part)
	if not part then
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

	local parent = part.Parent

	while parent and parent ~= workspace do
		for _, obj in ipairs(parent:GetDescendants()) do
			addCandidate(obj)
		end

		if workspace:FindFirstChild("PlacedBoards") and parent:IsDescendantOf(workspace.PlacedBoards) then
			break
		end

		parent = parent.Parent
	end

	return candidates[1]
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

local function captureCellStates(cells)
	local states = {}

	for r = 1, 9 do
		for c = 1, 9 do
			local cell = cells[r] and cells[r][c]

			if cell then
				states[cell] = {
					color = cell.BackgroundColor3,
					transparency = cell.BackgroundTransparency
				}
			end
		end
	end

	return states
end

local function colorDistance(a, b)
	local dr = a.R - b.R
	local dg = a.G - b.G
	local db = a.B - b.B

	return math.sqrt(dr * dr + dg * dg + db * db)
end

local function getSelectionScore(cell)
	local score = 0

	for _, attrName in ipairs({"Selected", "IsSelected", "Focused", "Current", "ActiveCell"}) do
		local v = cell:GetAttribute(attrName)

		if v == true then
			score += 100
		end
	end

	local base = currentCellStates and currentCellStates[cell]

	if base then
		local dist = colorDistance(cell.BackgroundColor3, base.color)
		local transDiff = math.abs(cell.BackgroundTransparency - base.transparency)

		score += dist * 40
		score += transDiff * 10
	end

	local c = cell.BackgroundColor3

	if c.B >= 0.8 and c.G >= 0.75 and c.R >= 0.65 then
		score += 8
	end

	local stroke = cell:FindFirstChildOfClass("UIStroke")

	if stroke and stroke.Transparency < 0.8 then
		score += 2
	end

	return score
end

local function findSelectedEmptyCell()
	if not currentCells then
		return nil
	end

	local bestCell = nil
	local bestRow = nil
	local bestCol = nil
	local bestScore = 0

	for r = 1, 9 do
		for c = 1, 9 do
			local cell = currentCells[r] and currentCells[r][c]

			if cell and readNumberFromCell(cell) == 0 then
				local score = getSelectionScore(cell)

				if score > bestScore and score >= 3 then
					bestScore = score
					bestCell = cell
					bestRow = r
					bestCol = c
				end
			end
		end
	end

	if bestCell then
		return bestCell, bestRow, bestCol
	end

	return nil
end

local function isGuiActuallyVisible(obj)
	if not obj or not obj:IsA("GuiObject") then
		return false
	end

	local current = obj

	while current do
		if current:IsA("GuiObject") and not current.Visible then
			return false
		end

		current = current.Parent
	end

	return true
end

local function getDisplayedText(button)
	if button:IsA("TextButton") or button:IsA("TextLabel") or button:IsA("TextBox") then
		local t = tostring(button.Text or ""):gsub("%s+", "")

		if t ~= "" then
			return t
		end
	end

	for _, obj in ipairs(button:GetDescendants()) do
		if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
			local t = tostring(obj.Text or ""):gsub("%s+", "")

			if t ~= "" then
				return t
			end
		end
	end

	return ""
end

local function collectGuiRoots()
	local roots = {PlayerGui}

	local ok, coreGui = pcall(function()
		return game:GetService("CoreGui")
	end)

	if ok and coreGui then
		table.insert(roots, coreGui)
	end

	return roots
end

local function findNumberPadButton(num)
	local target = tostring(num)
	local viewport = Camera and Camera.ViewportSize or Vector2.new(1920, 1080)

	local best = nil
	local bestScore = -math.huge

	for _, root in ipairs(collectGuiRoots()) do
		for _, obj in ipairs(root:GetDescendants()) do
			if obj:IsA("GuiButton") and isGuiActuallyVisible(obj) then
				local shown = getDisplayedText(obj)

				if shown == target then
					local pos = obj.AbsolutePosition
					local size = obj.AbsoluteSize

					if size.X >= 30 and size.Y >= 30 then
						local score = 0

						if pos.X > viewport.X * 0.5 then
							score += 250
						end

						if pos.Y > viewport.Y * 0.45 then
							score += 250
						end

						score += size.X + size.Y
						score += pos.X * 0.05
						score += pos.Y * 0.03

						if score > bestScore then
							bestScore = score
							best = obj
						end
					end
				end
			end
		end
	end

	return best
end

local function clickGuiButton(button)
	if not button or not button.Parent then
		return false
	end

	local done = false

	if firesignal then
		pcall(function()
			firesignal(button.MouseButton1Click)
			done = true
		end)

		if not done then
			pcall(function()
				firesignal(button.MouseButton1Down)
				firesignal(button.MouseButton1Up)
				done = true
			end)
		end

		if not done then
			pcall(function()
				firesignal(button.Activated)
				done = true
			end)
		end
	end

	if not done then
		pcall(function()
			local vim = game:GetService("VirtualInputManager")
			local center = button.AbsolutePosition + button.AbsoluteSize / 2

			vim:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 1)
			vim:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 1)

			done = true
		end)
	end

	return done
end

local function solveCurrentBoard()
	clearCurrentSolver()

	local board = findBoardUnderPlayer()

	if not board then
		warn("Sudoku: nenhum tabuleiro encontrado embaixo de você.")
		return
	end

	local cells = getCells(board)

	if not cells then
		warn("Sudoku: não consegui ler as casas desse tabuleiro.")
		return
	end

	local original = buildGrid(cells)

	if not validateGrid(original) then
		warn("Sudoku: tabuleiro inválido ou com número repetido.")
		return
	end

	local solved = copyGrid(original)

	if not solve(solved) then
		warn("Sudoku: não consegui resolver esse tabuleiro.")
		return
	end

	currentBoard = board
	currentBoardKey = getBoardKey(board)
	currentCells = cells
	currentSolution = solved
	currentCellStates = captureCellStates(cells)
	lastAutoFillKey = nil

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

	print("Sudoku executado. Dicas mostradas: " .. tostring(count))
end

local function tryAutoFillSelectedCell()
	if not currentBoard or not currentCells or not currentSolution then
		return
	end

	local cell, row, col = findSelectedEmptyCell()

	if not cell or not row or not col then
		lastAutoFillKey = nil
		return
	end

	if readNumberFromCell(cell) ~= 0 then
		return
	end

	local correct = currentSolution[row][col]

	if not correct then
		return
	end

	local key = tostring(currentBoardKey) .. ":" .. tostring(row) .. ":" .. tostring(col)

	if lastAutoFillKey == key then
		return
	end

	local numberButton = findNumberPadButton(correct)

	if not numberButton then
		return
	end

	local ok = clickGuiButton(numberButton)

	if ok then
		lastAutoFillKey = key

		task.delay(0.35, function()
			if cell and cell.Parent and readNumberFromCell(cell) == 0 then
				lastAutoFillKey = nil
			end
		end)
	end
end

local function canUseMobileTap(obj)
	local lastDragTime = obj:GetAttribute("LastDragTime")

	if typeof(lastDragTime) == "number" then
		return tick() - lastDragTime > 0.12
	end

	return true
end

local function bindFreeDrag(handle, target, onMove, holdTime)
	local activeInput = nil
	local dragStart = nil
	local startPos = nil
	local holdSatisfied = false
	local holdCanceled = false
	local holdId = 0

	holdTime = holdTime or 0

	table.insert(dragConnections, handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			activeInput = input
			dragStart = input.Position
			startPos = target.Position
			holdSatisfied = false
			holdCanceled = false
			holdId += 1

			local myHoldId = holdId

			if holdTime <= 0 then
				holdSatisfied = true
			else
				task.delay(holdTime, function()
					if activeInput == input and not holdCanceled and holdId == myHoldId then
						holdSatisfied = true
						handle:SetAttribute("LastDragTime", tick())
					end
				end)
			end
		end
	end))

	table.insert(dragConnections, UserInputService.InputChanged:Connect(function(input)
		if input == activeInput and dragStart and startPos then
			local delta = input.Position - dragStart

			if not holdSatisfied then
				if delta.Magnitude >= 8 then
					holdCanceled = true
				end

				return
			end

			if delta.Magnitude >= 6 then
				handle:SetAttribute("LastDragTime", tick())
			end

			target.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)

			if onMove then
				onMove(delta)
			end
		end
	end))

	table.insert(dragConnections, UserInputService.InputEnded:Connect(function(input)
		if input == activeInput then
			activeInput = nil
			dragStart = nil
			startPos = nil
			holdSatisfied = false
			holdCanceled = false
			holdId += 1
		end
	end))
end

local function createSudokuButton()
	local old = PlayerGui:FindFirstChild(BUTTON_GUI_NAME)

	if old then
		old:Destroy()
	end

	clearDragConnections()

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = BUTTON_GUI_NAME
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = PlayerGui

	local button = Instance.new("TextButton")
	button.Name = "SudokuButton"
	button.Size = UDim2.new(0, 140, 0, 50)
	button.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	button.Text = "Sudoku"
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Font = Enum.Font.GothamBold
	button.TextScaled = true
	button.AutoButtonColor = false
	button.BorderSizePixel = 0
	button.Parent = screenGui
	button:SetAttribute("LastDragTime", 0)
	button:SetAttribute("CustomMoved", false)

	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 12)
	noTextStroke(button)
	addTrueRoundedShadow(button, 14, 1.15, Color3.fromRGB(0, 0, 0))

	local function placeDefault()
		local insetNow = GuiService:GetGuiInset()

		if not button:GetAttribute("CustomMoved") then
			button.Position = UDim2.new(0, 150, 0, insetNow.Y - 58)
		end
	end

	RunService.RenderStepped:Connect(placeDefault)
	placeDefault()

	bindFreeDrag(button, button, function()
		button:SetAttribute("CustomMoved", true)
	end, 0.5)

	button.Activated:Connect(function()
		if not canUseMobileTap(button) then
			return
		end

		TweenService:Create(button, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = Color3.fromRGB(25, 25, 25)
		}):Play()

		task.delay(0.1, function()
			if button and button.Parent then
				TweenService:Create(button, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					BackgroundColor3 = Color3.fromRGB(0, 0, 0)
				}):Play()
			end
		end)

		solveCurrentBoard()
	end)
end

createSudokuButton()

RunService.Heartbeat:Connect(function()
	local now = os.clock()

	if now - lastAutoFill >= AUTOFILL_INTERVAL then
		lastAutoFill = now
		tryAutoFillSelectedCell()
	end
end)

LocalPlayer.CharacterAdded:Connect(function()
	task.wait(1)
	clearCurrentSolver()
end)

print("Sudoku helper carregado. Clique no botão Sudoku para executar.")
