-- sudoku with friends helper
-- botão estilo Wallhop do Cerber X
-- clicou no botão: resolve o tabuleiro embaixo de você
-- clicou em uma casa vazia do tabuleiro: preenche com o número correto daquela casa
-- versão mais precisa: usa o Row/Col da casa clicada, não tenta adivinhar pela cor/seleção

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

local solverConnections = {}
local dragConnections = {}
local shadowRegistry = {}

local lastClickedCellKey = nil
local lastClickedTime = 0

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

local function addCerberClickAnimation(button)
	if not button then
		return
	end

	local pressOverlay = Instance.new("Frame")
	pressOverlay.Name = "PressOverlay"
	pressOverlay.Size = UDim2.new(1, 0, 1, 0)
	pressOverlay.Position = UDim2.new(0, 0, 0, 0)
	pressOverlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	pressOverlay.BackgroundTransparency = 1
	pressOverlay.BorderSizePixel = 0
	pressOverlay.ZIndex = button.ZIndex + 1
	pressOverlay.Active = false
	pressOverlay.Parent = button

	Instance.new("UICorner", pressOverlay).CornerRadius = UDim.new(0, 12)

	local pressing = false

	local function setOverlay(alpha)
		pcall(function()
			TweenService:Create(
				pressOverlay,
				TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{BackgroundTransparency = alpha}
			):Play()
		end)
	end

	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			pressing = true
			setOverlay(0.82)
		end
	end)

	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			pressing = false
			setOverlay(1)
		end
	end)

	button.MouseLeave:Connect(function()
		if pressing then
			pressing = false
			setOverlay(1)
		end
	end)

	button.Activated:Connect(function()
		setOverlay(0.82)

		task.delay(0.08, function()
			if pressOverlay and pressOverlay.Parent then
				setOverlay(1)
			end
		end)
	end)
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
	lastClickedCellKey = nil
	lastClickedTime = 0
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

local function findNumberPadCluster()
	local viewport = Camera and Camera.ViewportSize or Vector2.new(1920, 1080)
	local allButtons = {}

	for _, root in ipairs(collectGuiRoots()) do
		for _, obj in ipairs(root:GetDescendants()) do
			if obj:IsA("GuiButton") and isGuiActuallyVisible(obj) then
				local shown = getDisplayedText(obj)

				if shown:match("^[1-9]$") then
					local pos = obj.AbsolutePosition
					local size = obj.AbsoluteSize

					if size.X >= 30 and size.Y >= 30 then
						table.insert(allButtons, {
							button = obj,
							num = shown,
							pos = pos,
							size = size,
							center = pos + size / 2
						})
					end
				end
			end
		end
	end

	local bestCluster = nil
	local bestScore = -math.huge

	for _, base in ipairs(allButtons) do
		local cluster = {}
		local nums = {}

		for _, item in ipairs(allButtons) do
			local dx = math.abs(item.center.X - base.center.X)
			local dy = math.abs(item.center.Y - base.center.Y)

			if dx <= 520 and dy <= 360 then
				cluster[item.num] = item
				nums[item.num] = true
			end
		end

		local hasAll = true
		for i = 1, 9 do
			if not nums[tostring(i)] then
				hasAll = false
				break
			end
		end

		if hasAll then
			local minX, minY = math.huge, math.huge
			local maxX, maxY = -math.huge, -math.huge

			for i = 1, 9 do
				local item = cluster[tostring(i)]
				minX = math.min(minX, item.pos.X)
				minY = math.min(minY, item.pos.Y)
				maxX = math.max(maxX, item.pos.X + item.size.X)
				maxY = math.max(maxY, item.pos.Y + item.size.Y)
			end

			local width = maxX - minX
			local height = maxY - minY
			local area = width * height
			local centerX = (minX + maxX) / 2
			local centerY = (minY + maxY) / 2

			local score = 0
			score += centerX * 0.04
			score += centerY * 0.08

			if centerX > viewport.X * 0.45 then
				score += 500
			end

			if centerY > viewport.Y * 0.35 then
				score += 500
			end

			if area >= 30000 and area <= 300000 then
				score += 350
			else
				score -= math.abs(area - 110000) * 0.001
			end

			if score > bestScore then
				bestScore = score
				bestCluster = cluster
			end
		end
	end

	return bestCluster
end

local function findNumberPadButton(num)
	local cluster = findNumberPadCluster()

	if cluster and cluster[tostring(num)] then
		return cluster[tostring(num)].button
	end

	return nil
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

local function autoFillExactCell(cell)
	if not currentBoard or not currentCells or not currentSolution then
		return
	end

	if not cell or not cell.Parent then
		return
	end

	local row = cell:GetAttribute("Row")
	local col = cell:GetAttribute("Col")

	if typeof(row) ~= "number" or typeof(col) ~= "number" then
		return
	end

	if row < 1 or row > 9 or col < 1 or col > 9 then
		return
	end

	if readNumberFromCell(cell) ~= 0 then
		removeSolverNumber(cell)
		return
	end

	local correct = currentSolution[row][col]

	if typeof(correct) ~= "number" or correct < 1 or correct > 9 then
		return
	end

	local key = tostring(currentBoardKey) .. ":" .. tostring(row) .. ":" .. tostring(col) .. ":" .. tostring(correct)
	local now = os.clock()

	if lastClickedCellKey == key and now - lastClickedTime < 0.28 then
		return
	end

	lastClickedCellKey = key
	lastClickedTime = now

	task.delay(0.035, function()
		if not currentBoard or not cell or not cell.Parent then
			return
		end

		if readNumberFromCell(cell) ~= 0 then
			removeSolverNumber(cell)
			return
		end

		local numberButton = findNumberPadButton(correct)

		if not numberButton then
			warn("Sudoku: não achei o botão " .. tostring(correct) .. " do teclado 1-9.")
			return
		end

		local ok = clickGuiButton(numberButton)

		if ok then
			task.delay(0.18, function()
				if cell and cell.Parent and readNumberFromCell(cell) ~= 0 then
					removeSolverNumber(cell)
				end
			end)
		end
	end)
end

local function bindCellAutoFill(cell)
	if not cell or not cell:IsA("GuiButton") then
		return
	end

	local activeInput = nil
	local startPos = nil
	local moved = false
	local lastTap = 0

	table.insert(solverConnections, cell.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			activeInput = input
			startPos = input.Position
			moved = false
		end
	end))

	table.insert(solverConnections, cell.InputChanged:Connect(function(input)
		if input == activeInput and startPos then
			local delta = input.Position - startPos

			if delta.Magnitude > 8 then
				moved = true
			end
		end
	end))

	table.insert(solverConnections, cell.InputEnded:Connect(function(input)
		if input == activeInput then
			local wasMoved = moved
			activeInput = nil
			startPos = nil
			moved = false

			if not wasMoved then
				local now = tick()

				if now - lastTap > 0.08 then
					lastTap = now
					autoFillExactCell(cell)
				end
			end
		end
	end))

	table.insert(solverConnections, cell.Activated:Connect(function()
		local now = tick()

		if now - lastTap > 0.08 then
			lastTap = now
			autoFillExactCell(cell)
		end
	end))
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
	lastClickedCellKey = nil
	lastClickedTime = 0

	local count = 0

	for r = 1, 9 do
		for c = 1, 9 do
			local cell = cells[r] and cells[r][c]

			if cell then
				bindCellAutoFill(cell)

				if original[r][c] == 0 then
					count += 1
					addNumberOnCell(cell, solved[r][c])
					watchCell(cell)
				end
			end
		end
	end

	print("Sudoku executado com clique preciso. Dicas mostradas: " .. tostring(count))
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
	button.ZIndex = 50
	button.Parent = screenGui
	button:SetAttribute("LastDragTime", 0)
	button:SetAttribute("CustomMoved", false)

	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 12)
	noTextStroke(button)
	addTrueRoundedShadow(button, 14, 1.15, Color3.fromRGB(0, 0, 0))
	addCerberClickAnimation(button)

	local function placeDefault()
		local insetNow = GuiService:GetGuiInset()

		if not button:GetAttribute("CustomMoved") then
			button.Position = UDim2.new(0, 150, 0, insetNow.Y - 58)
		end
	end

	table.insert(dragConnections, RunService.RenderStepped:Connect(placeDefault))
	placeDefault()

	bindFreeDrag(button, button, function()
		button:SetAttribute("CustomMoved", true)
	end, 0.5)

	button.Activated:Connect(function()
		if not canUseMobileTap(button) then
			return
		end

		solveCurrentBoard()
	end)
end

createSudokuButton()

LocalPlayer.CharacterAdded:Connect(function()
	task.wait(1)
	clearCurrentSolver()
end)

print("Sudoku helper carregado. Clique no botão Sudoku para resolver. Clique em uma casa vazia para auto-preencher.")
