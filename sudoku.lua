-- sudoku with friends helper
-- interface mobile fiel ao Cerber X + auto-preencher / auto-notas corrigidos
-- Auto-preencher: só funciona com a ferramenta "Preencher" selecionada.
-- Auto-notas: só funciona com a ferramenta "Notas" selecionada e adiciona somente o número correto da casa.
-- Notas não contam como número colocado e não removem a dica azul.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

local SCREEN_GUI_NAME = "SudokuCerberMobileGui"
local SOLVER_VALUE_NAME = "SolverValue"

local ScreenGui
local MobileButton
local MobileMenuButton
local MobilePanel
local mobileDragHandle
local autoFillSwitch
local autoFillKnob
local autoNotesSwitch
local autoNotesKnob

local autoFillEnabled = true
local autoNotesEnabled = false
local mobileMenuOpen = false

local currentBoard = nil
local currentBoardKey = nil
local currentCells = nil
local currentSolution = nil

local solverConnections = {}
local dragConnections = {}
local shadowRegistry = {}

local actionToken = 0
local lastActionKey = ""
local lastActionTime = 0
local numberPadCache = nil
local numberPadCacheTime = 0

local function noTextStroke(obj)
	pcall(function()
		obj.TextStrokeTransparency = 1
	end)
end

local function setTargetTransparency(obj, bg, text)
	if bg ~= nil then obj:SetAttribute("TargetBGTransparency", bg) end
	if text ~= nil then obj:SetAttribute("TargetTextTransparency", text) end
end

local function getTargetBG(obj)
	local v = obj:GetAttribute("TargetBGTransparency")
	return typeof(v) == "number" and v or obj.BackgroundTransparency
end

local function getTargetText(obj)
	local v = obj:GetAttribute("TargetTextTransparency")
	return typeof(v) == "number" and v or obj.TextTransparency
end

local function registerShadow(host, shadow)
	shadowRegistry[host] = shadowRegistry[host] or {}
	table.insert(shadowRegistry[host], shadow)
end

local function setHostShadowVisible(host, visible)
	local list = shadowRegistry[host]
	if not list then return end

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

local function addClickAnimation(button, cornerRadius)
	if not button then return end

	local overlay = Instance.new("Frame")
	overlay.Name = "ClickOverlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.Position = UDim2.new(0, 0, 0, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	overlay.BackgroundTransparency = 1
	overlay.BorderSizePixel = 0
	overlay.ZIndex = button.ZIndex + 25
	overlay.Active = false
	overlay.Parent = button

	Instance.new("UICorner", overlay).CornerRadius = cornerRadius or UDim.new(0, 12)

	local function setAlpha(alpha)
		if not overlay or not overlay.Parent then return end
		TweenService:Create(
			overlay,
			TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{BackgroundTransparency = alpha}
		):Play()
	end

	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			setAlpha(0.82)
		end
	end)

	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			setAlpha(1)
		end
	end)

	button.Activated:Connect(function()
		setAlpha(0.82)
		task.delay(0.08, function()
			setAlpha(1)
		end)
	end)
end

local function elegantShow(root, finalSize, finalPosition, finalBgTransparency)
	if not root then return end

	root.Visible = true

	local targetSize = finalSize or root.Size
	local targetPos = finalPosition or root.Position
	local targetBg = finalBgTransparency
	if targetBg == nil then targetBg = getTargetBG(root) end

	root.Size = UDim2.new(
		targetSize.X.Scale * 0.72,
		math.floor(targetSize.X.Offset * 0.72),
		targetSize.Y.Scale * 0.72,
		math.floor(targetSize.Y.Offset * 0.72)
	)

	root.Position = targetPos
	root.BackgroundTransparency = 1
	setHostShadowVisible(root, false)

	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("Frame") or obj:IsA("TextButton") or obj:IsA("TextLabel") then
			pcall(function() obj.BackgroundTransparency = 1 end)
		end
		if obj:IsA("TextButton") or obj:IsA("TextLabel") then
			pcall(function() obj.TextTransparency = 1 end)
		end
		if obj:IsA("UIStroke") then
			pcall(function() obj.Transparency = 1 end)
		end
	end

	TweenService:Create(root, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Size = targetSize,
		Position = targetPos,
		BackgroundTransparency = targetBg
	}):Play()

	task.delay(0.03, function()
		if not root or not root.Parent then return end

		setHostShadowVisible(root, true)

		for _, obj in ipairs(root:GetDescendants()) do
			if obj:IsA("Frame") or obj:IsA("TextButton") or obj:IsA("TextLabel") then
				local goal = {}

				if obj:IsA("Frame") or obj:IsA("TextButton") then
					goal.BackgroundTransparency = getTargetBG(obj)
				end

				if obj:IsA("TextButton") or obj:IsA("TextLabel") then
					goal.TextTransparency = getTargetText(obj)
				end

				TweenService:Create(obj, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
			elseif obj:IsA("UIStroke") then
				TweenService:Create(obj, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Transparency = 0
				}):Play()
			end
		end
	end)
end

local function elegantHide(root, onDone)
	if not root then
		if onDone then onDone() end
		return
	end

	local currentSize = root.Size
	local currentPos = root.Position
	local shrinkSize = UDim2.new(
		currentSize.X.Scale * 0.965,
		math.floor(currentSize.X.Offset * 0.965),
		currentSize.Y.Scale * 0.965,
		math.floor(currentSize.Y.Offset * 0.965)
	)

	local liftPos = UDim2.new(
		currentPos.X.Scale,
		currentPos.X.Offset,
		currentPos.Y.Scale,
		currentPos.Y.Offset + 4
	)

	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("Frame") or obj:IsA("TextButton") or obj:IsA("TextLabel") then
			local goal = {}

			if obj:IsA("Frame") or obj:IsA("TextButton") then
				goal.BackgroundTransparency = 1
			end

			if obj:IsA("TextButton") or obj:IsA("TextLabel") then
				goal.TextTransparency = 1
			end

			TweenService:Create(
				obj,
				TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
				goal
			):Play()
		elseif obj:IsA("UIStroke") then
			TweenService:Create(
				obj,
				TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
				{Transparency = 1}
			):Play()
		end
	end

	setHostShadowVisible(root, false)

	local tween = TweenService:Create(
		root,
		TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
		{
			Size = shrinkSize,
			Position = liftPos,
			BackgroundTransparency = 1
		}
	)

	tween:Play()
	tween.Completed:Connect(function()
		if root and root.Parent then
			root.Visible = false
			root.Size = currentSize
			root.Position = currentPos
		end

		if onDone then onDone() end
	end)
end

local function canUseMobileTap(obj)
	local lastDragTime = obj:GetAttribute("LastDragTime")
	if typeof(lastDragTime) == "number" then
		return (tick() - lastDragTime) > 0.12
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

			if onMove then onMove(delta) end
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

local function bindRowPress(button, callback)
	if not button then return end

	local activeInput = nil
	local startPos = nil
	local moved = false
	local lastTap = 0

	button.Active = true
	button.Selectable = false
	button.AutoButtonColor = false

	local function fire()
		local now = tick()
		if now - lastTap < 0.08 then return end
		lastTap = now
		callback()
	end

	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			activeInput = input
			startPos = input.Position
			moved = false
		end
	end)

	button.InputChanged:Connect(function(input)
		if input == activeInput and startPos then
			local delta = input.Position - startPos
			if delta.Magnitude > 8 then moved = true end
		end
	end)

	button.InputEnded:Connect(function(input)
		if input == activeInput then
			local wasMoved = moved
			activeInput = nil
			startPos = nil
			moved = false

			if not wasMoved and canUseMobileTap(button) then
				fire()
			end
		end
	end)

	if button:IsA("GuiButton") then
		button.Activated:Connect(function()
			if canUseMobileTap(button) then fire() end
		end)
	end
end

local function updateSwitchVisual(switchFrame, knob, enabled)
	if not switchFrame or not knob then return end

	local offPos = UDim2.new(0, 3, 0.5, -13)
	local onPos = UDim2.new(1, -29, 0.5, -13)

	TweenService:Create(switchFrame, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundColor3 = enabled and Color3.fromRGB(190,190,190) or Color3.fromRGB(20,20,24)
	}):Play()

	TweenService:Create(knob, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = enabled and onPos or offPos,
		BackgroundColor3 = enabled and Color3.fromRGB(255,255,255) or Color3.fromRGB(0,0,0)
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
	setTargetTransparency(row, 0, 1)
	addClickAnimation(row, UDim.new(0, 12))

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(0, 130, 1, 0)
	label.Position = UDim2.new(0, 12, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = labelText
	label.TextColor3 = Color3.fromRGB(255,255,255)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 15
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = row
	label.ZIndex = 6
	label.Active = false
	noTextStroke(label)
	setTargetTransparency(label, 1, 0)

	local switch = Instance.new("Frame")
	switch.Size = UDim2.new(0, 54, 0, 28)
	switch.Position = UDim2.new(1, -94, 0.5, -14)
	switch.BackgroundColor3 = Color3.fromRGB(20,20,24)
	switch.BorderSizePixel = 0
	switch.Parent = row
	switch.ZIndex = 6
	switch.Active = false
	Instance.new("UICorner", switch).CornerRadius = UDim.new(1, 0)
	setTargetTransparency(switch, 0, nil)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 26, 0, 26)
	knob.Position = UDim2.new(0, 3, 0.5, -13)
	knob.BackgroundColor3 = Color3.fromRGB(0,0,0)
	knob.BorderSizePixel = 0
	knob.Parent = switch
	knob.ZIndex = 7
	knob.Active = false
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
	setTargetTransparency(knob, 0, nil)

	local switchHitbox = Instance.new("TextButton")
	switchHitbox.Name = "SwitchHitbox"
	switchHitbox.Size = UDim2.new(0, 68, 0, 38)
	switchHitbox.Position = UDim2.new(1, -101, 0.5, -19)
	switchHitbox.BackgroundTransparency = 1
	switchHitbox.Text = ""
	switchHitbox.AutoButtonColor = false
	switchHitbox.BorderSizePixel = 0
	switchHitbox.ZIndex = 20
	switchHitbox.Parent = row
	switchHitbox.Active = true
	switchHitbox.Selectable = false

	return row, switch, knob, switchHitbox
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
	setTargetTransparency(row, 0, 1)
	addClickAnimation(row, UDim.new(0, 12))

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, -24, 1, 0)
	label.Position = UDim2.new(0, 12, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = labelText
	label.TextColor3 = Color3.fromRGB(255,255,255)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.Parent = row
	label.ZIndex = 6
	label.Active = false
	noTextStroke(label)
	setTargetTransparency(label, 1, 0)

	return row
end

local function clearSolverConnections()
	for _, c in ipairs(solverConnections) do
		pcall(function() c:Disconnect() end)
	end
	table.clear(solverConnections)
end

local function clearDragConnections()
	for _, c in ipairs(dragConnections) do
		pcall(function() c:Disconnect() end)
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
	lastActionKey = ""
	lastActionTime = 0
	actionToken += 1
end

local function getChar()
	return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getHRP()
	local char = getChar()
	return char:FindFirstChild("HumanoidRootPart")
end

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
	if not frame then return nil end

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

	if total < 81 then return nil end
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
		if grid[row][c] == num then return false end
	end

	for r = 1, 9 do
		if grid[r][col] == num then return false end
	end

	local startRow = math.floor((row - 1) / 3) * 3 + 1
	local startCol = math.floor((col - 1) / 3) * 3 + 1

	for r = startRow, startRow + 2 do
		for c = startCol, startCol + 2 do
			if grid[r][c] == num then return false end
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
			if grid[r][c] == 0 then return r, c end
		end
	end
	return nil, nil
end

local function solve(grid)
	local row, col = findEmpty(grid)
	if not row then return true end

	for num = 1, 9 do
		if canPlace(grid, num, row, col) then
			grid[row][col] = num

			if solve(grid) then return true end

			grid[row][col] = 0
		end
	end

	return false
end

local function removeSolverNumber(cell)
	local old = cell:FindFirstChild(SOLVER_VALUE_NAME)
	if old then old:Destroy() end
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
		if child and child.Name == "ClueValue" then
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
	if ok then return name end
	return tostring(surfaceGui)
end

local function isValidBoardSurface(surfaceGui)
	if not surfaceGui or not surfaceGui:IsA("SurfaceGui") then return false end

	local placedBoards = workspace:FindFirstChild("PlacedBoards")
	if not placedBoards then return false end
	if not surfaceGui:IsDescendantOf(placedBoards) then return false end

	return getCells(surfaceGui) ~= nil
end

local function findBoardFromPart(part)
	if not part then return nil end

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
	if not hrp then return nil end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {LocalPlayer.Character}
	params.IgnoreWater = true

	local origin = hrp.Position + Vector3.new(0, 2, 0)
	local direction = Vector3.new(0, -18, 0)

	local result = workspace:Raycast(origin, direction, params)
	if result and result.Instance then
		local board = findBoardFromPart(result.Instance)
		if board then return board end
	end

	local placedBoards = workspace:FindFirstChild("PlacedBoards")
	if not placedBoards then return nil end

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
	if not obj or not obj:IsA("GuiObject") then return false end
	if ScreenGui and obj:IsDescendantOf(ScreenGui) then return false end

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
		if t ~= "" then return t end
	end

	for _, child in ipairs(obj:GetDescendants()) do
		if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
			local t = tostring(child.Text or ""):gsub("%s+", "")
			if t ~= "" then return t end
		end
	end

	return ""
end

local function collectGuiRoots()
	local roots = {PlayerGui}
	local ok, coreGui = pcall(function()
		return game:GetService("CoreGui")
	end)

	if ok and coreGui then table.insert(roots, coreGui) end

	return roots
end

local function colorBlueScore(color)
	return (color.B * 2.2 + color.G * 1.1) - (color.R * 1.8)
end

local function toolButtonScore(obj)
	local score = 0

	if obj:IsA("GuiObject") then
		score += colorBlueScore(obj.BackgroundColor3) * 10
		if obj.BackgroundTransparency < 0.8 then score += 2 end
	end

	for _, child in ipairs(obj:GetDescendants()) do
		if child:IsA("UIStroke") then
			score += colorBlueScore(child.Color) * (child.Transparency < 0.5 and 16 or 6)
			if child.Thickness >= 2 then score += 4 end
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

local function scoreDigitCluster(map)
	local viewport = Camera and Camera.ViewportSize or Vector2.new(1920, 1080)

	local minX, minY = math.huge, math.huge
	local maxX, maxY = -math.huge, -math.huge
	local areaSum = 0
	local centers = {}

	for i = 1, 9 do
		local item = map[tostring(i)]
		if not item then return -math.huge end

		local p = item.button.AbsolutePosition
		local s = item.button.AbsoluteSize
		local c = p + s / 2

		centers[i] = c
		areaSum += s.X * s.Y

		minX = math.min(minX, p.X)
		minY = math.min(minY, p.Y)
		maxX = math.max(maxX, p.X + s.X)
		maxY = math.max(maxY, p.Y + s.Y)
	end

	local width = maxX - minX
	local height = maxY - minY
	local area = width * height
	local centerX = (minX + maxX) / 2
	local centerY = (minY + maxY) / 2

	local score = 0
	score += centerX * 0.08
	score += centerY * 0.12
	score += areaSum * 0.002

	if centerX > viewport.X * 0.45 then score += 900 end
	if centerY > viewport.Y * 0.34 then score += 900 end

	if area >= 25000 and area <= 320000 then
		score += 420
	else
		score -= math.abs(area - 120000) * 0.0015
	end

	local row1 = (centers[1].Y + centers[2].Y + centers[3].Y) / 3
	local row2 = (centers[4].Y + centers[5].Y + centers[6].Y) / 3
	local row3 = (centers[7].Y + centers[8].Y + centers[9].Y) / 3

	local col1 = (centers[1].X + centers[4].X + centers[7].X) / 3
	local col2 = (centers[2].X + centers[5].X + centers[8].X) / 3
	local col3 = (centers[3].X + centers[6].X + centers[9].X) / 3

	local gridPenalty = 0
	gridPenalty += math.abs(centers[1].Y - row1) + math.abs(centers[2].Y - row1) + math.abs(centers[3].Y - row1)
	gridPenalty += math.abs(centers[4].Y - row2) + math.abs(centers[5].Y - row2) + math.abs(centers[6].Y - row2)
	gridPenalty += math.abs(centers[7].Y - row3) + math.abs(centers[8].Y - row3) + math.abs(centers[9].Y - row3)
	gridPenalty += math.abs(centers[1].X - col1) + math.abs(centers[4].X - col1) + math.abs(centers[7].X - col1)
	gridPenalty += math.abs(centers[2].X - col2) + math.abs(centers[5].X - col2) + math.abs(centers[8].X - col2)
	gridPenalty += math.abs(centers[3].X - col3) + math.abs(centers[6].X - col3) + math.abs(centers[9].X - col3)

	score -= gridPenalty * 1.8

	if row1 < row2 and row2 < row3 then score += 200 end
	if col1 < col2 and col2 < col3 then score += 200 end

	return score
end

local function findNumberPadCluster()
	local now = os.clock()

	if numberPadCache and now - numberPadCacheTime < 0.35 then
		return numberPadCache
	end

	local candidates = {}

	for _, root in ipairs(collectGuiRoots()) do
		for _, obj in ipairs(root:GetDescendants()) do
			if obj:IsA("GuiButton") and isGuiActuallyVisible(obj) then
				local shown = getDisplayedText(obj)

				if shown:match("^[1-9]$") then
					local size = obj.AbsoluteSize

					if size.X >= 30 and size.Y >= 30 then
						table.insert(candidates, obj)
					end
				end
			end
		end
	end

	local rootsToCheck = {}

	for _, button in ipairs(candidates) do
		local parent = button.Parent
		local depth = 0

		while parent and parent ~= PlayerGui and depth < 7 do
			if parent:IsA("GuiObject") or parent:IsA("ScreenGui") then
				rootsToCheck[parent] = true
			end

			parent = parent.Parent
			depth += 1
		end
	end

	local bestMap = nil
	local bestScore = -math.huge

	for root in pairs(rootsToCheck) do
		local map = {}

		for _, button in ipairs(root:GetDescendants()) do
			if button:IsA("GuiButton") and isGuiActuallyVisible(button) then
				local shown = getDisplayedText(button)

				if shown:match("^[1-9]$") then
					local old = map[shown]

					if not old or (button.AbsoluteSize.X * button.AbsoluteSize.Y) > (old.button.AbsoluteSize.X * old.button.AbsoluteSize.Y) then
						map[shown] = {button = button}
					end
				end
			end
		end

		local hasAll = true

		for i = 1, 9 do
			if not map[tostring(i)] then
				hasAll = false
				break
			end
		end

		if hasAll then
			local score = scoreDigitCluster(map)

			if score > bestScore then
				bestScore = score
				bestMap = map
			end
		end
	end

	numberPadCache = bestMap
	numberPadCacheTime = now

	return bestMap
end

local function findNumberPadButton(num)
	local cluster = findNumberPadCluster()
	if cluster and cluster[tostring(num)] then
		return cluster[tostring(num)].button
	end
	return nil
end

local function clickGuiButton(button)
	if not button or not button.Parent then return false end

	local ok = false

	pcall(function()
		local center = button.AbsolutePosition + button.AbsoluteSize / 2
		VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 1)
		task.wait(0.025)
		VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 1)
		ok = true
	end)

	if ok then return true end

	if firesignal then
		pcall(function()
			firesignal(button.MouseButton1Click)
			ok = true
		end)

		if not ok then
			pcall(function()
				firesignal(button.Activated)
				ok = true
			end)
		end
	end

	return ok
end

local function clickNumber(num, token, delayTime)
	task.delay(delayTime or 0, function()
		if token ~= actionToken then return end

		local numberButton = findNumberPadButton(num)

		if not numberButton then
			warn("Sudoku: não achei o botão " .. tostring(num) .. " do teclado 1-9.")
			return
		end

		clickGuiButton(numberButton)
	end)
end

local function getCellRowCol(cell)
	if not cell or not cell.Parent then return nil, nil end

	local row = cell:GetAttribute("Row")
	local col = cell:GetAttribute("Col")

	if typeof(row) ~= "number" or typeof(col) ~= "number" then return nil, nil end
	if row < 1 or row > 9 or col < 1 or col > 9 then return nil, nil end

	return row, col
end

local function autoFillExactCell(cell)
	if not autoFillEnabled then return end
	if getSelectedTool() ~= "fill" then return end
	if not currentBoard or not currentCells or not currentSolution then return end

	local row, col = getCellRowCol(cell)
	if not row then return end

	if readPlacedNumberFromCell(cell) ~= 0 then
		removeSolverNumber(cell)
		return
	end

	local correct = currentSolution[row][col]
	if typeof(correct) ~= "number" or correct < 1 or correct > 9 then return end

	actionToken += 1
	local token = actionToken
	local key = tostring(currentBoardKey) .. ":fill:" .. row .. ":" .. col .. ":" .. correct
	local now = os.clock()

	if lastActionKey == key and now - lastActionTime < 0.28 then return end

	lastActionKey = key
	lastActionTime = now

	task.delay(0.09, function()
		if token ~= actionToken then return end
		if not currentBoard or not cell or not cell.Parent then return end
		if readPlacedNumberFromCell(cell) ~= 0 then
			removeSolverNumber(cell)
			return
		end
		if getSelectedTool() ~= "fill" then return end

		clickNumber(correct, token, 0)
	end)
end

local function autoNotesExactCell(cell)
	if not autoNotesEnabled then return end
	if getSelectedTool() ~= "notes" then return end
	if not currentBoard or not currentCells or not currentSolution then return end

	local row, col = getCellRowCol(cell)
	if not row then return end

	if readPlacedNumberFromCell(cell) ~= 0 then
		removeSolverNumber(cell)
		return
	end

	local correct = currentSolution[row][col]
	if typeof(correct) ~= "number" or correct < 1 or correct > 9 then return end

	actionToken += 1
	local token = actionToken
	local key = tostring(currentBoardKey) .. ":note:" .. row .. ":" .. col .. ":" .. correct
	local now = os.clock()

	if lastActionKey == key and now - lastActionTime < 0.48 then return end

	lastActionKey = key
	lastActionTime = now

	task.delay(0.12, function()
		if token ~= actionToken then return end
		if not currentBoard or not cell or not cell.Parent then return end
		if readPlacedNumberFromCell(cell) ~= 0 then
			removeSolverNumber(cell)
			return
		end
		if getSelectedTool() ~= "notes" then return end

		-- Auto-notas: somente a nota do número correto. Sem sequência.
		clickNumber(correct, token, 0)
	end)
end

local function handleCellTap(cell)
	local selectedTool = getSelectedTool()

	if selectedTool == "fill" then
		autoFillExactCell(cell)
	elseif selectedTool == "notes" then
		autoNotesExactCell(cell)
	end
end

local function bindCellActions(cell)
	if not cell or not cell:IsA("GuiButton") then return end

	local activeInput = nil
	local startPos = nil
	local moved = false
	local lastTap = 0

	table.insert(solverConnections, cell.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			activeInput = input
			startPos = input.Position
			moved = false
			actionToken += 1
		end
	end))

	table.insert(solverConnections, cell.InputChanged:Connect(function(input)
		if input == activeInput and startPos then
			local delta = input.Position - startPos
			if delta.Magnitude > 8 then moved = true end
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
	lastActionKey = ""
	lastActionTime = 0
	actionToken += 1
	numberPadCache = nil

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

local function updateMobilePanelButtons()
	if MobileButton then
		MobileButton.Text = "Sudoku"
	end

	updateSwitchVisual(autoFillSwitch, autoFillKnob, autoFillEnabled)
	updateSwitchVisual(autoNotesSwitch, autoNotesKnob, autoNotesEnabled)
end

local function buildMobileGui()
	local old = PlayerGui:FindFirstChild(SCREEN_GUI_NAME)
	if old then old:Destroy() end

	clearDragConnections()

	ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = SCREEN_GUI_NAME
	ScreenGui.ResetOnSpawn = false
	ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ScreenGui.Parent = PlayerGui

	local function createFloatingMobileButton(name, text)
		local button = Instance.new("TextButton")
		button.Name = name
		button.Size = UDim2.new(0, 140, 0, 50)
		button.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		button.Text = text
		button.TextColor3 = Color3.fromRGB(255,255,255)
		button.Font = Enum.Font.GothamBold
		button.TextScaled = true
		button.Visible = true
		button.Parent = ScreenGui
		button:SetAttribute("LastDragTime", 0)
		button:SetAttribute("CustomMoved", false)
		Instance.new("UICorner", button).CornerRadius = UDim.new(0, 12)
		noTextStroke(button)
		addTrueRoundedShadow(button, 14, 1.15, Color3.fromRGB(0, 0, 0))
		setTargetTransparency(button, 0, 0)
		addClickAnimation(button, UDim.new(0, 12))
		return button
	end

	MobileButton = createFloatingMobileButton("SudokuButton", "Sudoku")

	local inset = GuiService:GetGuiInset()

	MobileMenuButton = Instance.new("TextButton")
	MobileMenuButton.Name = "SudokuMenuButton"
	MobileMenuButton.Size = UDim2.new(0, 54, 0, 54)
	MobileMenuButton.Position = UDim2.new(0, 86, 0, inset.Y - 60)
	MobileMenuButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	MobileMenuButton.Text = "≡"
	MobileMenuButton.TextColor3 = Color3.fromRGB(255,255,255)
	MobileMenuButton.Font = Enum.Font.GothamBold
	MobileMenuButton.TextSize = 22
	MobileMenuButton.AutoButtonColor = false
	MobileMenuButton.BorderSizePixel = 0
	MobileMenuButton.Parent = ScreenGui
	MobileMenuButton:SetAttribute("LastDragTime", 0)
	Instance.new("UICorner", MobileMenuButton).CornerRadius = UDim.new(1, 0)
	noTextStroke(MobileMenuButton)
	addTrueRoundedShadow(MobileMenuButton, 999, 1.05, Color3.fromRGB(0, 0, 0))
	setTargetTransparency(MobileMenuButton, 0, 0)
	addClickAnimation(MobileMenuButton, UDim.new(1, 0))

	MobilePanel = Instance.new("Frame")
	MobilePanel.Name = "SudokuMobilePanel"
	MobilePanel.Size = UDim2.new(0, 232, 0, 324)
	MobilePanel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	MobilePanel.BorderSizePixel = 0
	MobilePanel.Visible = false
	MobilePanel.Parent = ScreenGui
	MobilePanel:SetAttribute("CustomMoved", false)
	Instance.new("UICorner", MobilePanel).CornerRadius = UDim.new(0, 14)
	addTrueRoundedShadow(MobilePanel, 14, 1.15, Color3.fromRGB(0, 0, 0))
	setTargetTransparency(MobilePanel, 0, nil)

	mobileDragHandle = Instance.new("Frame")
	mobileDragHandle.Name = "MobileDragHandle"
	mobileDragHandle.Size = UDim2.new(1, -16, 0, 14)
	mobileDragHandle.Position = UDim2.new(0, 7, 0, 5)
	mobileDragHandle.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
	mobileDragHandle.BorderSizePixel = 0
	mobileDragHandle.Parent = MobilePanel
	mobileDragHandle.Active = true
	Instance.new("UICorner", mobileDragHandle).CornerRadius = UDim.new(1, 0)
	setTargetTransparency(mobileDragHandle, 0, nil)

	local functionsPage = Instance.new("ScrollingFrame")
	functionsPage.Name = "MobileFunctionsPage"
	functionsPage.Size = UDim2.new(1, 0, 1, -30)
	functionsPage.Position = UDim2.new(0, 0, 0, 26)
	functionsPage.BackgroundTransparency = 1
	functionsPage.BorderSizePixel = 0
	functionsPage.ScrollBarThickness = 3
	functionsPage.ScrollingDirection = Enum.ScrollingDirection.Y
	functionsPage.CanvasSize = UDim2.new(0, 0, 0, 145)
	functionsPage.Parent = MobilePanel

	local solveRow = createSimpleRow(functionsPage, 8, "Resolver tabuleiro")
	local autoFillRow, fillSwitch, fillKnob, fillHitbox = createSwitchRow(functionsPage, 52, "Auto-preencher")
	local autoNotesRow, notesSwitch, notesKnob, notesHitbox = createSwitchRow(functionsPage, 96, "Auto-notas")

	autoFillSwitch = fillSwitch
	autoFillKnob = fillKnob
	autoNotesSwitch = notesSwitch
	autoNotesKnob = notesKnob

	local function placeMobileButtonDefault()
		local insetNow = GuiService:GetGuiInset()

		if not MobileButton:GetAttribute("CustomMoved") then
			MobileButton.Position = UDim2.new(0, 150, 0, insetNow.Y - 58)
		end
	end

	local function placePanelToRightOfSudoku()
		local xOffset = MobileButton.Position.X.Offset + MobileButton.Size.X.Offset + 28
		local yOffset = MobileButton.Position.Y.Offset + 6
		MobilePanel.Position = UDim2.new(0, xOffset, 0, yOffset)
	end

	table.insert(dragConnections, RunService.RenderStepped:Connect(function()
		placeMobileButtonDefault()

		if mobileMenuOpen and not MobilePanel:GetAttribute("CustomMoved") then
			placePanelToRightOfSudoku()
		end
	end))

	placeMobileButtonDefault()
	placePanelToRightOfSudoku()

	bindFreeDrag(MobileButton, MobileButton, function()
		MobileButton:SetAttribute("CustomMoved", true)

		if not MobilePanel:GetAttribute("CustomMoved") then
			placePanelToRightOfSudoku()
		end
	end, 0.5)

	bindFreeDrag(MobileMenuButton, MobileMenuButton)
	bindFreeDrag(mobileDragHandle, MobilePanel, function()
		MobilePanel:SetAttribute("CustomMoved", true)
	end)

	MobileButton.Activated:Connect(function()
		if not canUseMobileTap(MobileButton) then return end
		solveCurrentBoard()
	end)

	MobileMenuButton.Activated:Connect(function()
		if not canUseMobileTap(MobileMenuButton) then return end

		mobileMenuOpen = not mobileMenuOpen

		if mobileMenuOpen then
			if not MobilePanel:GetAttribute("CustomMoved") then
				placePanelToRightOfSudoku()
			end

			MobilePanel.BackgroundTransparency = 1
			MobilePanel.Size = UDim2.new(0, 224, 0, 316)

			elegantShow(MobilePanel, UDim2.new(0, 232, 0, 324), MobilePanel.Position, 0)
		else
			elegantHide(MobilePanel)
		end
	end)

	bindRowPress(solveRow, function()
		solveCurrentBoard()
	end)

	local function toggleFill()
		autoFillEnabled = not autoFillEnabled
		actionToken += 1
		updateMobilePanelButtons()
	end

	local function toggleNotes()
		autoNotesEnabled = not autoNotesEnabled
		actionToken += 1
		updateMobilePanelButtons()
	end

	bindRowPress(autoFillRow, toggleFill)
	bindRowPress(fillHitbox, toggleFill)
	bindRowPress(autoNotesRow, toggleNotes)
	bindRowPress(notesHitbox, toggleNotes)

	updateMobilePanelButtons()
	setHostShadowVisible(MobilePanel, false)
end

buildMobileGui()

LocalPlayer.CharacterAdded:Connect(function()
	task.wait(1)
	clearCurrentSolver()
end)

print("Sudoku helper carregado.")
print("UI no estilo Cerber X.")
print("Auto-preencher: apenas com Preencher selecionado.")
print("Auto-notas: apenas com Notas selecionado, e só adiciona o número correto.")
