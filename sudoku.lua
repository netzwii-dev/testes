-- sudoku with friends helper
-- botão Sudoku estilo Cerber X + menu mobile com switches
-- funções:
-- 1) clique no botão "Sudoku" para resolver o tabuleiro embaixo de você
-- 2) switch Auto Fill: só preenche quando a ferramenta "Preencher" estiver selecionada
-- 3) switch Auto Notes: só adiciona notas quando a ferramenta "Notas" estiver selecionada
-- 4) notas não contam como número colocado, não removem a dica azul e não acionam auto-fill

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

local BUTTON_GUI_NAME = "SudokuCerberButtonGui"
local MENU_GUI_NAME = "SudokuCerberMobileMenuGui"
local SOLVER_VALUE_NAME = "SolverValue"

local currentBoard = nil
local currentBoardKey = nil
local currentCells = nil
local currentSolution = nil

local autoFillEnabled = true
local autoNotesEnabled = false

local solverConnections = {}
local dragConnections = {}
local menuConnections = {}
local shadowRegistry = {}

local lastActionKey = nil
local lastActionTime = 0
local notedCells = {}

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
			setOverlay(0.82)
		end
	end)

	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
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

local function clearMenuConnections()
	for _, c in ipairs(menuConnections) do
		pcall(function()
			c:Disconnect()
		end)
	end

	table.clear(menuConnections)
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
	lastActionKey = nil
	lastActionTime = 0
	table.clear(notedCells)
end

local function getChar()
	return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getHRP()
	local char = getChar()
	return char:FindFirstChild("HumanoidRootPart")
end

-- lê APENAS número realmente colocado.
-- ignora HintValues/notas e qualquer outro TextLabel de notas.
local function readPlacedNumberFromCell(cell)
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
			grid[r][c] = cell and readPlacedNumberFromCell(cell) or 0
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

local function getCandidates(row, col)
	if not currentCells then
		return {}
	end

	local grid = buildGrid(currentCells)

	if grid[row][col] ~= 0 then
		return {}
	end

	local list = {}

	for num = 1, 9 do
		if canPlace(grid, num, row, col) then
			table.insert(list, num)
		end
	end

	return list
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

		local current = readPlacedNumberFromCell(cell)

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

		-- HintValues/notas não removem dica.
		if child.Name == "ClueValue" then
			check()

			if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
				table.insert(solverConnections, child:GetPropertyChangedSignal("Text"):Connect(check))
			end
		end
	end))

	table.insert(solverConnections, cell.ChildRemoved:Connect(function(child)
		task.wait()

		if child and child.Name == "ClueValue" then
			check()
		end
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

local function getDisplayedText(obj)
	if obj:IsA("TextButton") or obj:IsA("TextLabel") or obj:IsA("TextBox") then
		local t = tostring(obj.Text or ""):gsub("%s+", "")

		if t ~= "" then
			return t
		end
	end

	for _, child in ipairs(obj:GetDescendants()) do
		if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
			local t = tostring(child.Text or ""):gsub("%s+", "")

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

local function colorBlueScore(color)
	return (color.B * 2.2 + color.G * 1.1) - (color.R * 1.8)
end

local function toolButtonScore(obj)
	local score = 0

	if obj:IsA("GuiObject") then
		score += colorBlueScore(obj.BackgroundColor3) * 10

		if obj.BackgroundTransparency < 0.8 then
			score += 2
		end
	end

	for _, child in ipairs(obj:GetDescendants()) do
		if child:IsA("UIStroke") then
			score += colorBlueScore(child.Color) * (child.Transparency < 0.5 and 16 or 6)
			if child.Thickness >= 2 then
				score += 4
			end
		elseif child:IsA("GuiObject") then
			score += colorBlueScore(child.BackgroundColor3) * 3
		end
	end

	return score
end

local function findToolButtonByText(textWanted)
	local wanted = tostring(textWanted or ""):lower():gsub("%s+", "")
	local best = nil
	local bestScore = -math.huge

	for _, root in ipairs(collectGuiRoots()) do
		for _, obj in ipairs(root:GetDescendants()) do
			if obj:IsA("GuiButton") and isGuiActuallyVisible(obj) then
				local shown = getDisplayedText(obj):lower():gsub("%s+", "")

				if shown == wanted then
					local pos = obj.AbsolutePosition
					local size = obj.AbsoluteSize

					if size.X >= 40 and size.Y >= 25 then
						local score = toolButtonScore(obj)
						score += pos.Y * 0.002

						if score > bestScore then
							bestScore = score
							best = obj
						end
					end
				end
			end
		end
	end

	return best, bestScore
end

local function getSelectedTool()
	local fillButton, fillScore = findToolButtonByText("Preencher")
	local notesButton, notesScore = findToolButtonByText("Notas")
	local eraserButton, eraserScore = findToolButtonByText("Apagador")

	fillScore = fillScore or -math.huge
	notesScore = notesScore or -math.huge
	eraserScore = eraserScore or -math.huge

	if fillButton and fillScore > notesScore and fillScore > eraserScore and fillScore > 3 then
		return "fill"
	end

	if notesButton and notesScore > fillScore and notesScore > eraserScore and notesScore > 3 then
		return "notes"
	end

	if eraserButton and eraserScore > fillScore and eraserScore > notesScore and eraserScore > 3 then
		return "eraser"
	end

	return "unknown"
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

local function clickNumber(num, delayTime)
	task.delay(delayTime or 0, function()
		local numberButton = findNumberPadButton(num)

		if not numberButton then
			warn("Sudoku: não achei o botão " .. tostring(num) .. " do teclado 1-9.")
			return
		end

		clickGuiButton(numberButton)
	end)
end

local function autoFillExactCell(cell)
	if not autoFillEnabled then
		return
	end

	if getSelectedTool() ~= "fill" then
		return
	end

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

	if readPlacedNumberFromCell(cell) ~= 0 then
		removeSolverNumber(cell)
		return
	end

	local correct = currentSolution[row][col]

	if typeof(correct) ~= "number" or correct < 1 or correct > 9 then
		return
	end

	local key = tostring(currentBoardKey) .. ":fill:" .. tostring(row) .. ":" .. tostring(col) .. ":" .. tostring(correct)
	local now = os.clock()

	if lastActionKey == key and now - lastActionTime < 0.28 then
		return
	end

	lastActionKey = key
	lastActionTime = now

	task.delay(0.035, function()
		if not currentBoard or not cell or not cell.Parent then
			return
		end

		if readPlacedNumberFromCell(cell) ~= 0 then
			removeSolverNumber(cell)
			return
		end

		if getSelectedTool() ~= "fill" then
			return
		end

		clickNumber(correct, 0)
	end)
end

local function autoNotesExactCell(cell)
	if not autoNotesEnabled then
		return
	end

	if getSelectedTool() ~= "notes" then
		return
	end

	if not currentBoard or not currentCells then
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

	if readPlacedNumberFromCell(cell) ~= 0 then
		removeSolverNumber(cell)
		return
	end

	local candidates = getCandidates(row, col)

	if #candidates == 0 then
		return
	end

	local candidateKey = table.concat(candidates, "")
	local key = tostring(currentBoardKey) .. ":notes:" .. tostring(row) .. ":" .. tostring(col) .. ":" .. candidateKey

	if notedCells[key] then
		return
	end

	local now = os.clock()

	if lastActionKey == key and now - lastActionTime < 0.9 then
		return
	end

	lastActionKey = key
	lastActionTime = now
	notedCells[key] = true

	task.delay(0.04, function()
		if not currentBoard or not cell or not cell.Parent then
			return
		end

		if getSelectedTool() ~= "notes" then
			return
		end

		if readPlacedNumberFromCell(cell) ~= 0 then
			removeSolverNumber(cell)
			return
		end

		for i, num in ipairs(candidates) do
			clickNumber(num, 0.035 * (i - 1))
		end
	end)
end

local function handleCellTap(cell)
	if getSelectedTool() == "fill" then
		autoFillExactCell(cell)
	elseif getSelectedTool() == "notes" then
		autoNotesExactCell(cell)
	end
end

local function bindCellActions(cell)
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
					handleCellTap(cell)
				end
			end
		end
	end))

	table.insert(solverConnections, cell.Activated:Connect(function()
		local now = tick()

		if now - lastTap > 0.08 then
			lastTap = now
			handleCellTap(cell)
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
	lastActionKey = nil
	lastActionTime = 0
	table.clear(notedCells)

	local count = 0

	for r = 1, 9 do
		for c = 1, 9 do
			local cell = cells[r] and cells[r][c]

			if cell then
				bindCellActions(cell)

				if original[r][c] == 0 then
					count += 1
					addNumberOnCell(cell, solved[r][c])
					watchCell(cell)
				end
			end
		end
	end

	print("Sudoku executado. Dicas mostradas: " .. tostring(count))
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

	local con1 = handle.InputBegan:Connect(function(input)
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
	end)

	local con2 = UserInputService.InputChanged:Connect(function(input)
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
	end)

	local con3 = UserInputService.InputEnded:Connect(function(input)
		if input == activeInput then
			activeInput = nil
			dragStart = nil
			startPos = nil
			holdSatisfied = false
			holdCanceled = false
			holdId += 1
		end
	end)

	table.insert(dragConnections, con1)
	table.insert(dragConnections, con2)
	table.insert(dragConnections, con3)

	return con1, con2, con3
end

local function updateSwitchVisual(switchFrame, knob, enabled)
	if not switchFrame or not knob then
		return
	end

	local offPos = UDim2.new(0, 3, 0.5, -13)
	local onPos = UDim2.new(1, -29, 0.5, -13)

	TweenService:Create(switchFrame, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundColor3 = enabled and Color3.fromRGB(190, 190, 190) or Color3.fromRGB(20, 20, 24)
	}):Play()

	TweenService:Create(knob, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = enabled and onPos or offPos,
		BackgroundColor3 = enabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(0, 0, 0)
	}):Play()
end

local function createSwitchRow(parent, yOffset, labelText)
	local row = Instance.new("TextButton")
	row.Size = UDim2.new(1, -14, 0, 40)
	row.Position = UDim2.new(0, 7, 0, yOffset)
	row.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	row.AutoButtonColor = false
	row.Text = ""
	row.BorderSizePixel = 0
	row.Parent = parent
	row.ZIndex = 5
	row.Active = true
	row.Selectable = false
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 12)

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, -92, 1, 0)
	label.Position = UDim2.new(0, 12, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = labelText
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 15
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = row
	label.ZIndex = 6
	label.Active = false
	noTextStroke(label)

	local switch = Instance.new("Frame")
	switch.Size = UDim2.new(0, 54, 0, 28)
	switch.Position = UDim2.new(1, -68, 0.5, -14)
	switch.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	switch.BorderSizePixel = 0
	switch.Parent = row
	switch.ZIndex = 6
	switch.Active = false
	Instance.new("UICorner", switch).CornerRadius = UDim.new(1, 0)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 26, 0, 26)
	knob.Position = UDim2.new(0, 3, 0.5, -13)
	knob.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	knob.BorderSizePixel = 0
	knob.Parent = switch
	knob.ZIndex = 7
	knob.Active = false
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

	return row, switch, knob
end

local function createSimpleRow(parent, yOffset, labelText)
	local row = Instance.new("TextButton")
	row.Size = UDim2.new(1, -14, 0, 40)
	row.Position = UDim2.new(0, 7, 0, yOffset)
	row.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	row.AutoButtonColor = false
	row.Text = ""
	row.BorderSizePixel = 0
	row.Parent = parent
	row.ZIndex = 5
	row.Active = true
	row.Selectable = false
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 12)

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, -24, 1, 0)
	label.Position = UDim2.new(0, 12, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = labelText
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.Parent = row
	label.ZIndex = 6
	label.Active = false
	noTextStroke(label)

	return row
end

local function createMobileMenu()
	local old = PlayerGui:FindFirstChild(MENU_GUI_NAME)
	if old then
		old:Destroy()
	end

	clearMenuConnections()

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = MENU_GUI_NAME
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = PlayerGui

	local menuButton = Instance.new("TextButton")
	menuButton.Name = "SudokuMenuButton"
	menuButton.Size = UDim2.new(0, 56, 0, 56)
	menuButton.Position = UDim2.new(0, 150, 0, 20)
	menuButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	menuButton.Text = "☰"
	menuButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	menuButton.Font = Enum.Font.GothamBold
	menuButton.TextSize = 25
	menuButton.AutoButtonColor = false
	menuButton.BorderSizePixel = 0
	menuButton.ZIndex = 60
	menuButton.Parent = screenGui
	menuButton:SetAttribute("LastDragTime", 0)
	menuButton:SetAttribute("CustomMoved", false)

	Instance.new("UICorner", menuButton).CornerRadius = UDim.new(1, 0)
	noTextStroke(menuButton)
	addTrueRoundedShadow(menuButton, 28, 1.15, Color3.fromRGB(0, 0, 0))
	addCerberClickAnimation(menuButton)

	local panel = Instance.new("Frame")
	panel.Name = "SudokuMobilePanel"
	panel.Size = UDim2.new(0, 245, 0, 190)
	panel.Position = UDim2.new(0, 150, 0, 84)
	panel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.ZIndex = 55
	panel.Parent = screenGui
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 16)
	addTrueRoundedShadow(panel, 16, 1.2, Color3.fromRGB(0, 0, 0))

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -20, 0, 32)
	title.Position = UDim2.new(0, 10, 0, 8)
	title.BackgroundTransparency = 1
	title.Text = "Sudoku Settings"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 18
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 56
	title.Parent = panel
	noTextStroke(title)

	local solveRow = createSimpleRow(panel, 45, "Solve Current Board")
	local fillRow, fillSwitch, fillKnob = createSwitchRow(panel, 91, "Auto Fill")
	local notesRow, notesSwitch, notesKnob = createSwitchRow(panel, 137, "Auto Notes")

	local menuOpen = false

	local function updateMenu()
		updateSwitchVisual(fillSwitch, fillKnob, autoFillEnabled)
		updateSwitchVisual(notesSwitch, notesKnob, autoNotesEnabled)
	end

	local function setPanelVisible(state)
		menuOpen = state and true or false
		panel.Visible = menuOpen
		setHostShadowVisible(panel, menuOpen)
		updateMenu()
	end

	table.insert(menuConnections, menuButton.Activated:Connect(function()
		if not canUseMobileTap(menuButton) then
			return
		end

		setPanelVisible(not menuOpen)
	end))

	table.insert(menuConnections, solveRow.Activated:Connect(function()
		solveCurrentBoard()
	end))

	table.insert(menuConnections, fillRow.Activated:Connect(function()
		autoFillEnabled = not autoFillEnabled
		updateMenu()
	end))

	table.insert(menuConnections, notesRow.Activated:Connect(function()
		autoNotesEnabled = not autoNotesEnabled
		updateMenu()
	end))

	bindFreeDrag(menuButton, menuButton, function(delta)
		menuButton:SetAttribute("CustomMoved", true)

		panel.Position = UDim2.new(
			menuButton.Position.X.Scale,
			menuButton.Position.X.Offset,
			menuButton.Position.Y.Scale,
			menuButton.Position.Y.Offset + 64
		)
	end, 0.5)

	local function placeDefault()
		local insetNow = GuiService:GetGuiInset()

		if not menuButton:GetAttribute("CustomMoved") then
			menuButton.Position = UDim2.new(0, 150, 0, insetNow.Y + 22)
			panel.Position = UDim2.new(0, 150, 0, insetNow.Y + 86)
		end
	end

	table.insert(menuConnections, RunService.RenderStepped:Connect(placeDefault))
	placeDefault()
	updateMenu()
	setHostShadowVisible(panel, false)
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
			button.Position = UDim2.new(0, 212, 0, insetNow.Y + 25)
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

createMobileMenu()
createSudokuButton()

LocalPlayer.CharacterAdded:Connect(function()
	task.wait(1)
	clearCurrentSolver()
end)

print("Sudoku helper carregado.")
print("Clique em Sudoku para resolver.")
print("Menu ☰: Auto Fill e Auto Notes.")
print("Auto Fill só funciona com Preencher selecionado.")
print("Auto Notes só funciona com Notas selecionado.")
