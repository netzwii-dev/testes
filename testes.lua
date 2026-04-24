-- (Made by nyhito)
-- All Credits: nyhito (tester, config and uploader)
-- The Best

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

local DEFAULT_HIDE_GUI_KEY = Enum.KeyCode.RightShift
local DEFAULT_TOGGLE_SCRIPT_KEY = Enum.KeyCode.Q
local DEFAULT_TOGGLE_BEAST_SLOW_KEY = Enum.KeyCode.E

local KEYBINDS_FILE = "nyhito_ftf_wallhop_keybinds.json"

local selectedMode = nil

local hideGuiKey = DEFAULT_HIDE_GUI_KEY
local toggleScriptKey = DEFAULT_TOGGLE_SCRIPT_KEY
local toggleBeastSlowKey = DEFAULT_TOGGLE_BEAST_SLOW_KEY

local waitingForHideKey = false
local waitingForToggleKey = false
local waitingForBeastSlowKey = false

local guiVisible = true
local guiMinimized = false
local mobileMenuOpen = false
local mobileWallhopGuiHidden = false

local ScreenGui
local MainFrame
local MiniButton
local MobileButton
local MobileMenuButton
local MobilePanel
local ToggleButton
local HideGuiBindButton
local ToggleBindButton
local BeastSlowBindButton
local Notice
local NoticeStroke

local PcTabFunctions
local PcTabFlicks
local PcFunctionsPage
local PcFlicksPage
local PcCurrentUsingLabel
local PcNormalWallhopButton
local PcConsoleWallhopButton

local MobileTabFunctions
local MobileTabFlicks
local MobileFunctionsPage
local MobileFlicksPage
local MobileCurrentUsingLabel
local MobileNormalWallhopRow
local MobileConsoleWallhopRow
local MobileBeastSlowRow
local MobileHideGuiRow

local mobileBeastSlowSwitch
local mobileBeastSlowKnob
local mobileHideGuiSwitch
local mobileHideGuiKnob
local mobileDragHandle

local dragConnections = {}
local shadowRegistry = {}

local clearScriptSlowInstant
local updateMobilePanelButtons
local setMobileWallhopVisualHidden
local applyVisibility
local updateFlickButtons
local switchPcTab
local switchMobileTab

local isWallHopEnabled = false
local isSlowEnabled = false
local isFlicking = false
local lastFlickTime = 0

local isWallHopping = false
local lastWallHopTime = 0
local WALLHOP_GRACE_TIME = 1.5
local WALLHOP_COOLDOWN = 0.18

local canDoubleJump = false
local lastDoubleJump = 0
local DOUBLE_JUMP_COOLDOWN = 3
local blockDoubleJump = false

local lastHitPosition = nil
local MIN_HIT_DISTANCE = 0.2
local lastFlickAngle = nil

local airborneSource = nil
local airborneStartY = nil
local airborneStartTime = 0
local jumpedRecently = false

local LEDGE_BLOCK_DISTANCE = 6.0
local LEDGE_BLOCK_TIME = 0.20

local SLOW_DURATION = 0.8
local SLOW_WALKSPEED = 9
local DEFAULT_WALKSPEED = 16
local slowToken = 0
local scriptSlowActive = false

local FIRST_FLICK_RESET_GROUND_TIME = 3
local lastLandedTime = 0
local hasWallhoppedSinceLanding = false
local specialFirstFlickArmed = false

local currentFlickMode = "Normal Wallhop"

local function destroyOld()
	for _, name in ipairs({
		"AutoWallHopGui",
		"AutoWallHopGuiMobile",
		"WallhopModeSelector"
	}) do
		local old = PlayerGui:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
end

destroyOld()

local function getKeyCodeFromName(name, fallback)
	if typeof(name) ~= "string" then
		return fallback
	end

	local ok, value = pcall(function()
		return Enum.KeyCode[name]
	end)

	if ok and value then
		return value
	end

	return fallback
end

local function savePCKeybinds()
	if not writefile then
		return
	end

	local payload = {
		hideGuiKey = hideGuiKey.Name,
		toggleScriptKey = toggleScriptKey.Name,
		toggleBeastSlowKey = toggleBeastSlowKey.Name
	}

	pcall(function()
		writefile(KEYBINDS_FILE, HttpService:JSONEncode(payload))
	end)
end

local function loadPCKeybinds()
	if not readfile or not isfile then
		return
	end

	if not isfile(KEYBINDS_FILE) then
		return
	end

	pcall(function()
		local raw = readfile(KEYBINDS_FILE)
		local decoded = HttpService:JSONDecode(raw)

		hideGuiKey = getKeyCodeFromName(decoded.hideGuiKey, DEFAULT_HIDE_GUI_KEY)
		toggleScriptKey = getKeyCodeFromName(decoded.toggleScriptKey, DEFAULT_TOGGLE_SCRIPT_KEY)
		toggleBeastSlowKey = getKeyCodeFromName(decoded.toggleBeastSlowKey, DEFAULT_TOGGLE_BEAST_SLOW_KEY)
	end)
end

local function noTextStroke(obj)
	obj.TextStrokeTransparency = 1
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

local function setTargetTransparency(obj, bg, text)
	if bg ~= nil then
		obj:SetAttribute("TargetBGTransparency", bg)
	end
	if text ~= nil then
		obj:SetAttribute("TargetTextTransparency", text)
	end
end

local function getTargetBG(obj)
	local v = obj:GetAttribute("TargetBGTransparency")
	if typeof(v) == "number" then
		return v
	end
	return obj.BackgroundTransparency
end

local function getTargetText(obj)
	local v = obj:GetAttribute("TargetTextTransparency")
	if typeof(v) == "number" then
		return v
	end
	return obj.TextTransparency
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

local function elegantShow(root, finalSize, finalPosition, finalBgTransparency)
	if not root then
		return
	end

	root.Visible = true

	local targetSize = finalSize or root.Size
	local targetPos = finalPosition or root.Position
	local targetBg = finalBgTransparency
	if targetBg == nil then
		targetBg = getTargetBG(root)
	end

	root.Size = UDim2.new(
		targetSize.X.Scale * 0.72, math.floor(targetSize.X.Offset * 0.72),
		targetSize.Y.Scale * 0.72, math.floor(targetSize.Y.Offset * 0.72)
	)
	root.Position = targetPos
	root.BackgroundTransparency = 1
	setHostShadowVisible(root, false)

	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("Frame") or obj:IsA("TextButton") or obj:IsA("TextLabel") then
			pcall(function()
				obj.BackgroundTransparency = 1
			end)
		end
		if obj:IsA("TextButton") or obj:IsA("TextLabel") then
			pcall(function()
				obj.TextTransparency = 1
			end)
		end
		if obj:IsA("UIStroke") then
			pcall(function()
				obj.Transparency = 1
			end)
		end
	end

	TweenService:Create(root, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Size = targetSize,
		Position = targetPos,
		BackgroundTransparency = targetBg
	}):Play()

	task.delay(0.03, function()
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
		if onDone then
			onDone()
		end
		return
	end

	local currentSize = root.Size
	local currentPos = root.Position
	local shrinkSize = UDim2.new(
		currentSize.X.Scale * 0.965, math.floor(currentSize.X.Offset * 0.965),
		currentSize.Y.Scale * 0.965, math.floor(currentSize.Y.Offset * 0.965)
	)

	local liftPos = UDim2.new(
		currentPos.X.Scale, currentPos.X.Offset,
		currentPos.Y.Scale, currentPos.Y.Offset + 4
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
		root.Visible = false
		root.Size = currentSize
		root.Position = currentPos

		if onDone then
			onDone()
		end
	end)
end

local activeNoticeId = 0
local function showNotice(text)
	if selectedMode ~= "PC" or not Notice or not NoticeStroke then
		return
	end

	activeNoticeId += 1
	local myId = activeNoticeId

	Notice.Text = text
	Notice.Visible = true
	Notice.Position = UDim2.new(1, -14, 0, 14)
	Notice.BackgroundTransparency = 1
	Notice.TextTransparency = 1
	NoticeStroke.Transparency = 1

	TweenService:Create(Notice, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.08,
		TextTransparency = 0,
		Position = UDim2.new(1, -14, 0, 14)
	}):Play()

	TweenService:Create(NoticeStroke, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 0.9
	}):Play()

	task.delay(1, function()
		if myId ~= activeNoticeId then
			return
		end

		TweenService:Create(Notice, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
			BackgroundTransparency = 1,
			TextTransparency = 1,
			Position = UDim2.new(1, 220, 0, 14)
		}):Play()

		TweenService:Create(NoticeStroke, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Transparency = 1
		}):Play()

		task.delay(0.22, function()
			if myId == activeNoticeId then
				Notice.Visible = false
			end
		end)
	end)
end

local function canUseMobileTap(obj)
	local lastDragTime = obj:GetAttribute("LastDragTime")
	if typeof(lastDragTime) == "number" then
		return (tick() - lastDragTime) > 0.12
	end
	return true
end

local function bindRowPress(button, callback)
	local activeInput = nil
	local startPos = nil
	local moved = false
	local lastTap = 0

	button.Active = true
	button.Selectable = false
	button.AutoButtonColor = false

	local function fire()
		local now = tick()
		if now - lastTap < 0.08 then
			return
		end
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
			if delta.Magnitude > 8 then
				moved = true
			end
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

	button.Activated:Connect(function()
		if canUseMobileTap(button) then
			fire()
		end
	end)
end

local function updateSwitchVisual(switchFrame, knob, enabled)
	if not switchFrame or not knob then
		return
	end

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

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(0, 88, 1, 0)
	label.Position = UDim2.new(0, 12, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = labelText
	label.TextColor3 = Color3.fromRGB(255,255,255)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = row
	label.ZIndex = 6
	label.Active = false
	noTextStroke(label)
	setTargetTransparency(label, 1, 0)

	local switch = Instance.new("Frame")
	switch.Size = UDim2.new(0, 54, 0, 28)
	switch.Position = UDim2.new(1, -66, 0.5, -14)
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
	setTargetTransparency(row, 0, 1)
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, -24, 1, 0)
	label.Position = UDim2.new(0, 12, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = labelText
	label.TextColor3 = Color3.fromRGB(255,255,255)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = row
	label.ZIndex = 6
	label.Active = false
	noTextStroke(label)
	setTargetTransparency(label, 1, 0)

	return row
end

local function updateToggleButton()
	if selectedMode == "PC" and ToggleButton then
		ToggleButton.Text = isWallHopEnabled and "Wall Hop On" or "Wall Hop Off"
	elseif selectedMode == "Mobile" and MobileButton then
		MobileButton.Text = isWallHopEnabled and "Wallhop On" or "Wallhop Off"
	end
end

setMobileWallhopVisualHidden = function(hidden)
	if not MobileButton then
		return
	end
	MobileButton.BackgroundTransparency = hidden and 1 or 0
	MobileButton.TextTransparency = hidden and 1 or 0
	setHostShadowVisible(MobileButton, not hidden)
end

updateFlickButtons = function()
	if PcCurrentUsingLabel then
		PcCurrentUsingLabel.Text = "Currently using: " .. currentFlickMode
	end

	if MobileCurrentUsingLabel then
		MobileCurrentUsingLabel.Text = "Currently using: " .. currentFlickMode
	end

	if PcNormalWallhopButton then
		PcNormalWallhopButton.BackgroundColor3 =
			currentFlickMode == "Normal Wallhop" and Color3.fromRGB(20,20,20) or Color3.fromRGB(6,6,6)
	end

	if PcConsoleWallhopButton then
		PcConsoleWallhopButton.BackgroundColor3 =
			currentFlickMode == "Console Wallhop" and Color3.fromRGB(20,20,20) or Color3.fromRGB(6,6,6)
	end

	if MobileNormalWallhopRow then
		MobileNormalWallhopRow.BackgroundColor3 =
			currentFlickMode == "Normal Wallhop" and Color3.fromRGB(20,20,20) or Color3.fromRGB(0,0,0)
	end

	if MobileConsoleWallhopRow then
		MobileConsoleWallhopRow.BackgroundColor3 =
			currentFlickMode == "Console Wallhop" and Color3.fromRGB(20,20,20) or Color3.fromRGB(0,0,0)
	end
end

updateMobilePanelButtons = function()
	if MobileBeastSlowRow and MobileBeastSlowRow:FindFirstChild("Label") then
		MobileBeastSlowRow.Label.Text = "Beast Slow"
	end
	if MobileHideGuiRow and MobileHideGuiRow:FindFirstChild("Label") then
		MobileHideGuiRow.Label.Text = "Hide GUI"
	end
	if MobileNormalWallhopRow and MobileNormalWallhopRow:FindFirstChild("Label") then
		MobileNormalWallhopRow.Label.Text = "Normal Wallhop"
	end
	if MobileConsoleWallhopRow and MobileConsoleWallhopRow:FindFirstChild("Label") then
		MobileConsoleWallhopRow.Label.Text = "Console Wallhop"
	end

	updateSwitchVisual(mobileBeastSlowSwitch, mobileBeastSlowKnob, isSlowEnabled)
	updateSwitchVisual(mobileHideGuiSwitch, mobileHideGuiKnob, mobileWallhopGuiHidden)
	setMobileWallhopVisualHidden(mobileWallhopGuiHidden)
	updateFlickButtons()
end

local function updateBindButtons()
	if selectedMode ~= "PC" then
		return
	end

	if HideGuiBindButton then
		HideGuiBindButton.Text = waitingForHideKey and "Press any key..." or ("Keybind Hide GUI: " .. hideGuiKey.Name)
	end
	if ToggleBindButton then
		ToggleBindButton.Text = waitingForToggleKey and "Press any key..." or ("Keybind Toggle Wallhop: " .. toggleScriptKey.Name)
	end
	if BeastSlowBindButton then
		BeastSlowBindButton.Text = waitingForBeastSlowKey and "Press any key..." or ("Keybind Toggle Beast Slow: " .. toggleBeastSlowKey.Name)
	end
end

applyVisibility = function()
	if selectedMode == "PC" then
		if MainFrame then
			MainFrame.Visible = guiVisible and not guiMinimized
			setHostShadowVisible(MainFrame, guiVisible and not guiMinimized)
		end
		if MiniButton then
			MiniButton.Visible = guiVisible and guiMinimized
			setHostShadowVisible(MiniButton, guiVisible and guiMinimized)
		end
	elseif selectedMode == "Mobile" then
		if MobileButton then
			MobileButton.Visible = guiVisible
		end
		if MobileMenuButton then
			MobileMenuButton.Visible = true
		end
		if MobilePanel then
			MobilePanel.Visible = mobileMenuOpen
			setHostShadowVisible(MobilePanel, mobileMenuOpen)
		end
		setMobileWallhopVisualHidden(mobileWallhopGuiHidden)
	end
end

local function setGuiVisible(state)
	guiVisible = state
	applyVisibility()
	showNotice(state and "GUI shown" or "GUI hidden")
end

local function setFlickMode(name)
	currentFlickMode = name
	updateFlickButtons()
	if selectedMode == "PC" then
		showNotice("Using " .. name)
	end
end

local function createModeSelector(onPick)
	local selectorGui = Instance.new("ScreenGui")
	selectorGui.Name = "WallhopModeSelector"
	selectorGui.ResetOnSpawn = false
	selectorGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	selectorGui.Parent = PlayerGui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 280, 0, 170)
	frame.Position = UDim2.new(0.5, 0, 0.5, 0)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	frame.BorderSizePixel = 0
	frame.Parent = selectorGui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 16)
	addTrueRoundedShadow(frame, 16, 1.45, Color3.fromRGB(0, 0, 0))
	setTargetTransparency(frame, 0, nil)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -20, 0, 28)
	title.Position = UDim2.new(0, 10, 0, 10)
	title.BackgroundTransparency = 1
	title.Text = "Choose Version"
	title.TextColor3 = Color3.fromRGB(255,255,255)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 22
	title.Parent = frame
	noTextStroke(title)
	setTargetTransparency(title, 1, 0)

	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.new(1, -20, 0, 16)
	sub.Position = UDim2.new(0, 10, 0, 34)
	sub.BackgroundTransparency = 1
	sub.Text = "FtF Wallhop • made by nyhito"
	sub.TextColor3 = Color3.fromRGB(95,95,95)
	sub.Font = Enum.Font.Gotham
	sub.TextSize = 12
	sub.Parent = frame
	noTextStroke(sub)
	setTargetTransparency(sub, 1, 0)

	local pcButton = Instance.new("TextButton")
	pcButton.Size = UDim2.new(1, -20, 0, 42)
	pcButton.Position = UDim2.new(0, 10, 0, 68)
	pcButton.BackgroundColor3 = Color3.fromRGB(3, 3, 3)
	pcButton.Text = "PC Version"
	pcButton.TextColor3 = Color3.fromRGB(255,255,255)
	pcButton.Font = Enum.Font.GothamBold
	pcButton.TextSize = 17
	pcButton.Parent = frame
	Instance.new("UICorner", pcButton).CornerRadius = UDim.new(0, 12)
	noTextStroke(pcButton)
	setTargetTransparency(pcButton, 0, 0)

	local mobileButton = Instance.new("TextButton")
	mobileButton.Size = UDim2.new(1, -20, 0, 42)
	mobileButton.Position = UDim2.new(0, 10, 0, 116)
	mobileButton.BackgroundColor3 = Color3.fromRGB(3, 3, 3)
	mobileButton.Text = "Mobile Version"
	mobileButton.TextColor3 = Color3.fromRGB(255,255,255)
	mobileButton.Font = Enum.Font.GothamBold
	mobileButton.TextSize = 17
	mobileButton.Parent = frame
	Instance.new("UICorner", mobileButton).CornerRadius = UDim.new(0, 12)
	noTextStroke(mobileButton)
	setTargetTransparency(mobileButton, 0, 0)

	elegantShow(frame, UDim2.new(0, 280, 0, 170), UDim2.new(0.5, 0, 0.5, 0), 0)

	pcButton.MouseButton1Click:Connect(function()
		elegantHide(frame, function()
			selectorGui:Destroy()
			onPick("PC")
		end)
	end)

	mobileButton.MouseButton1Click:Connect(function()
		elegantHide(frame, function()
			selectorGui:Destroy()
			onPick("Mobile")
		end)
	end)
end

local function clearOldDragConnections()
	for _, c in ipairs(dragConnections) do
		if c and c.Disconnect then
			c:Disconnect()
		end
	end
	table.clear(dragConnections)
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

switchPcTab = function(name)
	if not PcFunctionsPage or not PcFlicksPage or not PcTabFunctions or not PcTabFlicks then
		return
	end

	local isFunctions = name == "Functions"

	PcFunctionsPage.Visible = isFunctions
	PcFlicksPage.Visible = not isFunctions

	PcTabFunctions.BackgroundColor3 = isFunctions and Color3.fromRGB(20,20,20) or Color3.fromRGB(8,8,8)
	PcTabFlicks.BackgroundColor3 = isFunctions and Color3.fromRGB(8,8,8) or Color3.fromRGB(20,20,20)
end

switchMobileTab = function(name)
	if not MobileFunctionsPage or not MobileFlicksPage or not MobileTabFunctions or not MobileTabFlicks then
		return
	end

	local isFunctions = name == "Functions"

	MobileFunctionsPage.Visible = isFunctions
	MobileFlicksPage.Visible = not isFunctions

	MobileTabFunctions.BackgroundColor3 = isFunctions and Color3.fromRGB(20,20,20) or Color3.fromRGB(8,8,8)
	MobileTabFlicks.BackgroundColor3 = not isFunctions and Color3.fromRGB(20,20,20) or Color3.fromRGB(8,8,8)
end

local function setSlowEnabled(state)
	isSlowEnabled = state and true or false

	if not isSlowEnabled then
		clearScriptSlowInstant()
	end

	updateMobilePanelButtons()
end

local function setMobileGuiHidden(state)
	mobileWallhopGuiHidden = state and true or false
	updateMobilePanelButtons()
end

local function buildMobileGui()
	clearOldDragConnections()

	ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "AutoWallHopGuiMobile"
	ScreenGui.ResetOnSpawn = false
	ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ScreenGui.Parent = PlayerGui

	MobileButton = Instance.new("TextButton")
	MobileButton.Size = UDim2.new(0, 140, 0, 50)
	MobileButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	MobileButton.Text = "Wallhop Off"
	MobileButton.TextColor3 = Color3.fromRGB(255,255,255)
	MobileButton.Font = Enum.Font.GothamBold
	MobileButton.TextScaled = true
	MobileButton.Parent = ScreenGui
	MobileButton:SetAttribute("LastDragTime", 0)
	MobileButton:SetAttribute("CustomMoved", false)
	Instance.new("UICorner", MobileButton).CornerRadius = UDim.new(0, 12)
	noTextStroke(MobileButton)
	addTrueRoundedShadow(MobileButton, 14, 1.15, Color3.fromRGB(0, 0, 0))
	setTargetTransparency(MobileButton, 0, 0)

	local inset = GuiService:GetGuiInset()

	MobileMenuButton = Instance.new("TextButton")
	MobileMenuButton.Size = UDim2.new(0, 54, 0, 54)
	MobileMenuButton.Position = UDim2.new(0, 86, 0, inset.Y - 60)
	MobileMenuButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	MobileMenuButton.Text = "≡"
	MobileMenuButton.TextColor3 = Color3.fromRGB(255,255,255)
	MobileMenuButton.Font = Enum.Font.GothamBold
	MobileMenuButton.TextSize = 22
	MobileMenuButton.Parent = ScreenGui
	Instance.new("UICorner", MobileMenuButton).CornerRadius = UDim.new(1, 0)
	noTextStroke(MobileMenuButton)
	addTrueRoundedShadow(MobileMenuButton, 999, 1.05, Color3.fromRGB(0, 0, 0))
	setTargetTransparency(MobileMenuButton, 0, 0)

	MobilePanel = Instance.new("Frame")
	MobilePanel.Size = UDim2.new(0, 190, 0, 196)
	MobilePanel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	MobilePanel.BorderSizePixel = 0
	MobilePanel.Visible = false
	MobilePanel.Parent = ScreenGui
	Instance.new("UICorner", MobilePanel).CornerRadius = UDim.new(0, 14)
	addTrueRoundedShadow(MobilePanel, 14, 1.15, Color3.fromRGB(0, 0, 0))
	setTargetTransparency(MobilePanel, 0, nil)

	mobileDragHandle = Instance.new("Frame")
	mobileDragHandle.Size = UDim2.new(1, -14, 0, 14)
	mobileDragHandle.Position = UDim2.new(0, 7, 0, 5)
	mobileDragHandle.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
	mobileDragHandle.BorderSizePixel = 0
	mobileDragHandle.Parent = MobilePanel
	mobileDragHandle.Active = true
	Instance.new("UICorner", mobileDragHandle).CornerRadius = UDim.new(1, 0)
	setTargetTransparency(mobileDragHandle, 0, nil)

	MobileTabFunctions = Instance.new("TextButton")
	MobileTabFunctions.Size = UDim2.new(0, 82, 0, 26)
	MobileTabFunctions.Position = UDim2.new(0, 7, 0, 24)
	MobileTabFunctions.BackgroundColor3 = Color3.fromRGB(20,20,20)
	MobileTabFunctions.Text = "Functions"
	MobileTabFunctions.TextColor3 = Color3.fromRGB(255,255,255)
	MobileTabFunctions.Font = Enum.Font.GothamBold
	MobileTabFunctions.TextSize = 12
	MobileTabFunctions.Parent = MobilePanel
	MobileTabFunctions.AutoButtonColor = false
	Instance.new("UICorner", MobileTabFunctions).CornerRadius = UDim.new(0, 10)
	setTargetTransparency(MobileTabFunctions, 0, 0)
	noTextStroke(MobileTabFunctions)

	MobileTabFlicks = Instance.new("TextButton")
	MobileTabFlicks.Size = UDim2.new(0, 82, 0, 26)
	MobileTabFlicks.Position = UDim2.new(0, 95, 0, 24)
	MobileTabFlicks.BackgroundColor3 = Color3.fromRGB(8,8,8)
	MobileTabFlicks.Text = "Flicks"
	MobileTabFlicks.TextColor3 = Color3.fromRGB(255,255,255)
	MobileTabFlicks.Font = Enum.Font.GothamBold
	MobileTabFlicks.TextSize = 12
	MobileTabFlicks.Parent = MobilePanel
	MobileTabFlicks.AutoButtonColor = false
	Instance.new("UICorner", MobileTabFlicks).CornerRadius = UDim.new(0, 10)
	setTargetTransparency(MobileTabFlicks, 0, 0)
	noTextStroke(MobileTabFlicks)

	MobileFunctionsPage = Instance.new("Frame")
	MobileFunctionsPage.Size = UDim2.new(1, 0, 1, -58)
	MobileFunctionsPage.Position = UDim2.new(0, 0, 0, 58)
	MobileFunctionsPage.BackgroundTransparency = 1
	MobileFunctionsPage.Parent = MobilePanel

	MobileFlicksPage = Instance.new("Frame")
	MobileFlicksPage.Size = UDim2.new(1, 0, 1, -58)
	MobileFlicksPage.Position = UDim2.new(0, 0, 0, 58)
	MobileFlicksPage.BackgroundTransparency = 1
	MobileFlicksPage.Parent = MobilePanel
	MobileFlicksPage.Visible = false

	MobileBeastSlowRow, mobileBeastSlowSwitch, mobileBeastSlowKnob = createSwitchRow(MobileFunctionsPage, 4, "Beast Slow")
	MobileHideGuiRow, mobileHideGuiSwitch, mobileHideGuiKnob = createSwitchRow(MobileFunctionsPage, 46, "Hide GUI")

	MobileNormalWallhopRow = createSimpleRow(MobileFlicksPage, 4, "Normal Wallhop")
	MobileConsoleWallhopRow = createSimpleRow(MobileFlicksPage, 46, "Console Wallhop")

	MobileCurrentUsingLabel = Instance.new("TextLabel")
	MobileCurrentUsingLabel.Size = UDim2.new(1, -14, 0, 34)
	MobileCurrentUsingLabel.Position = UDim2.new(0, 7, 0, 92)
	MobileCurrentUsingLabel.BackgroundTransparency = 1
	MobileCurrentUsingLabel.TextColor3 = Color3.fromRGB(200,200,200)
	MobileCurrentUsingLabel.Font = Enum.Font.Gotham
	MobileCurrentUsingLabel.TextSize = 12
	MobileCurrentUsingLabel.TextWrapped = true
	MobileCurrentUsingLabel.TextXAlignment = Enum.TextXAlignment.Left
	MobileCurrentUsingLabel.TextYAlignment = Enum.TextYAlignment.Top
	MobileCurrentUsingLabel.Parent = MobileFlicksPage
	noTextStroke(MobileCurrentUsingLabel)
	setTargetTransparency(MobileCurrentUsingLabel, 1, 0)

	local function placeMobileButtonDefault()
		local insetNow = GuiService:GetGuiInset()
		if not MobileButton:GetAttribute("CustomMoved") then
			MobileButton.Position = UDim2.new(0, 150, 0, insetNow.Y - 58)
		end
	end
	local function placePanelToRightOfWallhop()
		local xOffset = MobileButton.Position.X.Offset + MobileButton.Size.X.Offset + 28
		local yOffset = MobileButton.Position.Y.Offset + 6
		MobilePanel.Position = UDim2.new(0, xOffset, 0, yOffset)
	end

	RunService.RenderStepped:Connect(function()
		if selectedMode ~= "Mobile" then
			return
		end
		placeMobileButtonDefault()

		if mobileMenuOpen and not MobilePanel:GetAttribute("CustomMoved") then
			placePanelToRightOfWallhop()
		end
	end)

	placeMobileButtonDefault()
	placePanelToRightOfWallhop()

	bindFreeDrag(MobileButton, MobileButton, function()
		MobileButton:SetAttribute("CustomMoved", true)
		if not MobilePanel:GetAttribute("CustomMoved") then
			placePanelToRightOfWallhop()
		end
	end, 0.5)

	bindFreeDrag(MobileMenuButton, MobileMenuButton)
	bindFreeDrag(mobileDragHandle, MobilePanel, function()
		MobilePanel:SetAttribute("CustomMoved", true)
	end)

	MobileButton.Activated:Connect(function()
		if not canUseMobileTap(MobileButton) then
			return
		end
		isWallHopEnabled = not isWallHopEnabled
		updateToggleButton()
	end)

	MobileMenuButton.Activated:Connect(function()
		if not canUseMobileTap(MobileMenuButton) then
			return
		end

		mobileMenuOpen = not mobileMenuOpen

		if mobileMenuOpen then
			if not MobilePanel:GetAttribute("CustomMoved") then
				placePanelToRightOfWallhop()
			end

			MobilePanel.BackgroundTransparency = 1
			MobilePanel.Size = UDim2.new(0, 184, 0, 188)

			elegantShow(MobilePanel, UDim2.new(0, 190, 0, 196), MobilePanel.Position, 0)
		else
			elegantHide(MobilePanel)
		end
	end)

	MobileTabFunctions.Activated:Connect(function()
		switchMobileTab("Functions")
	end)

	MobileTabFlicks.Activated:Connect(function()
		switchMobileTab("Flicks")
	end)

	bindRowPress(MobileBeastSlowRow, function()
		setSlowEnabled(not isSlowEnabled)
	end)

	bindRowPress(MobileHideGuiRow, function()
		setMobileGuiHidden(not mobileWallhopGuiHidden)
	end)

	bindRowPress(MobileNormalWallhopRow, function()
		setFlickMode("Normal Wallhop")
	end)

	bindRowPress(MobileConsoleWallhopRow, function()
		setFlickMode("Console Wallhop")
	end)

	switchMobileTab("Functions")
	updateMobilePanelButtons()
end

local function setMinimized(state)
	if selectedMode ~= "PC" then
		return
	end

	guiMinimized = state

	if state then
		if MainFrame and MiniButton then
			local savedPos = MainFrame.Position

			elegantHide(MainFrame, function()
				MainFrame.Visible = false

				MiniButton.Position = savedPos
				MiniButton.Visible = true
				setHostShadowVisible(MiniButton, true)

				MiniButton.BackgroundTransparency = 1
				MiniButton.TextTransparency = 1
				MiniButton.Size = UDim2.new(0, 138, 0, 38)

				local finalMiniSize = UDim2.new(0, 150, 0, 42)
				local finalMiniPos = savedPos

				TweenService:Create(
					MiniButton,
					TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
					{
						Size = finalMiniSize,
						Position = finalMiniPos,
						BackgroundTransparency = 0,
						TextTransparency = 0
					}
				):Play()
			end)
		end

		showNotice("GUI minimized")
	else
		if MainFrame and MiniButton then
			local restorePos = MiniButton.Position

			local miniTween = TweenService:Create(
				MiniButton,
				TweenInfo.new(0.16, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
				{
					BackgroundTransparency = 1,
					TextTransparency = 1,
					Size = UDim2.new(0, 140, 0, 39)
				}
			)

			miniTween:Play()
			miniTween.Completed:Connect(function()
				MiniButton.Visible = false
				setHostShadowVisible(MiniButton, false)

				MainFrame.Position = restorePos
				MainFrame.Size = UDim2.new(0, 335, 0, 270)

				elegantShow(MainFrame, UDim2.new(0, 335, 0, 270), restorePos, 0)
			end)
		end

		showNotice("GUI restored")
	end
end

local function createPcTabButton(parent, x, text)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0, 96, 0, 28)
	button.Position = UDim2.new(0, x, 0, 54)
	button.BackgroundColor3 = Color3.fromRGB(8,8,8)
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255,255,255)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 13
	button.AutoButtonColor = false
	button.Parent = parent
	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 10)
	noTextStroke(button)
	setTargetTransparency(button, 0, 0)
	return button
end

local function createPcActionButton(parent, y, text)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, -36, 0, 30)
	button.Position = UDim2.new(0, 18, 0, y)
	button.BackgroundColor3 = Color3.fromRGB(6,6,6)
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255,255,255)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 14
	button.AutoButtonColor = false
	button.Parent = parent
	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 10)
	noTextStroke(button)
	setTargetTransparency(button, 0, 0)
	return button
end

local function buildPCGui()
	clearOldDragConnections()
	loadPCKeybinds()

	ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "AutoWallHopGui"
	ScreenGui.ResetOnSpawn = false
	ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ScreenGui.Parent = PlayerGui

	MainFrame = Instance.new("Frame")
	MainFrame.Size = UDim2.new(0, 335, 0, 270)
	MainFrame.Position = UDim2.new(0.5, -167, 0.5, -135)
	MainFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	MainFrame.BorderSizePixel = 0
	MainFrame.Parent = ScreenGui
	Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 22)
	addTrueRoundedShadow(MainFrame, 22, 1.25, Color3.fromRGB(0, 0, 0))
	setTargetTransparency(MainFrame, 0, nil)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -60, 0, 30)
	title.Position = UDim2.new(0, 18, 0, 8)
	title.BackgroundTransparency = 1
	title.Text = "FtF Wallhop"
	title.TextColor3 = Color3.fromRGB(255,255,255)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 28
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = MainFrame
	noTextStroke(title)
	setTargetTransparency(title, 1, 0)

	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.new(1, -60, 0, 16)
	sub.Position = UDim2.new(0, 18, 0, 34)
	sub.BackgroundTransparency = 1
	sub.Text = "PC Version"
	sub.TextColor3 = Color3.fromRGB(95,95,95)
	sub.Font = Enum.Font.Gotham
	sub.TextSize = 14
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.Parent = MainFrame
	noTextStroke(sub)
	setTargetTransparency(sub, 1, 0)

	local MinimizeButton = Instance.new("TextButton")
	MinimizeButton.Size = UDim2.new(0, 28, 0, 28)
	MinimizeButton.Position = UDim2.new(1, -44, 0, 12)
	MinimizeButton.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
	MinimizeButton.Text = "—"
	MinimizeButton.TextColor3 = Color3.fromRGB(255,255,255)
	MinimizeButton.Font = Enum.Font.GothamBold
	MinimizeButton.TextSize = 20
	MinimizeButton.AutoButtonColor = false
	MinimizeButton.Parent = MainFrame
	Instance.new("UICorner", MinimizeButton).CornerRadius = UDim.new(1, 0)
	noTextStroke(MinimizeButton)
	setTargetTransparency(MinimizeButton, 0, 0)

	ToggleButton = Instance.new("TextButton")
	ToggleButton.Size = UDim2.new(1, -36, 0, 28)
	ToggleButton.Position = UDim2.new(0, 18, 0, 88)
	ToggleButton.BackgroundTransparency = 1
	ToggleButton.Text = "Wall Hop Off"
	ToggleButton.TextColor3 = Color3.fromRGB(255,255,255)
	ToggleButton.Font = Enum.Font.GothamBold
	ToggleButton.TextSize = 22
	ToggleButton.TextXAlignment = Enum.TextXAlignment.Left
	ToggleButton.AutoButtonColor = false
	ToggleButton.Parent = MainFrame
	noTextStroke(ToggleButton)
	setTargetTransparency(ToggleButton, 1, 0)

	PcTabFunctions = createPcTabButton(MainFrame, 18, "Functions")
	PcTabFlicks = createPcTabButton(MainFrame, 120, "Flicks")

	PcFunctionsPage = Instance.new("Frame")
	PcFunctionsPage.Size = UDim2.new(1, 0, 1, -118)
	PcFunctionsPage.Position = UDim2.new(0, 0, 0, 114)
	PcFunctionsPage.BackgroundTransparency = 1
	PcFunctionsPage.Parent = MainFrame

	PcFlicksPage = Instance.new("Frame")
	PcFlicksPage.Size = UDim2.new(1, 0, 1, -118)
	PcFlicksPage.Position = UDim2.new(0, 0, 0, 114)
	PcFlicksPage.BackgroundTransparency = 1
	PcFlicksPage.Visible = false
	PcFlicksPage.Parent = MainFrame

	HideGuiBindButton = Instance.new("TextButton")
	HideGuiBindButton.Size = UDim2.new(1, -36, 0, 18)
	HideGuiBindButton.Position = UDim2.new(0, 18, 0, 8)
	HideGuiBindButton.BackgroundTransparency = 1
	HideGuiBindButton.TextColor3 = Color3.fromRGB(255,255,255)
	HideGuiBindButton.Font = Enum.Font.Gotham
	HideGuiBindButton.TextSize = 13
	HideGuiBindButton.TextXAlignment = Enum.TextXAlignment.Left
	HideGuiBindButton.AutoButtonColor = false
	HideGuiBindButton.Parent = PcFunctionsPage
	noTextStroke(HideGuiBindButton)
	setTargetTransparency(HideGuiBindButton, 1, 0)
	ToggleBindButton = Instance.new("TextButton")
	ToggleBindButton.Size = UDim2.new(1, -36, 0, 18)
	ToggleBindButton.Position = UDim2.new(0, 18, 0, 30)
	ToggleBindButton.BackgroundTransparency = 1
	ToggleBindButton.TextColor3 = Color3.fromRGB(255,255,255)
	ToggleBindButton.Font = Enum.Font.Gotham
	ToggleBindButton.TextSize = 13
	ToggleBindButton.TextXAlignment = Enum.TextXAlignment.Left
	ToggleBindButton.AutoButtonColor = false
	ToggleBindButton.Parent = PcFunctionsPage
	noTextStroke(ToggleBindButton)
	setTargetTransparency(ToggleBindButton, 1, 0)

	BeastSlowBindButton = Instance.new("TextButton")
	BeastSlowBindButton.Size = UDim2.new(1, -36, 0, 18)
	BeastSlowBindButton.Position = UDim2.new(0, 18, 0, 52)
	BeastSlowBindButton.BackgroundTransparency = 1
	BeastSlowBindButton.TextColor3 = Color3.fromRGB(255,255,255)
	BeastSlowBindButton.Font = Enum.Font.Gotham
	BeastSlowBindButton.TextSize = 13
	BeastSlowBindButton.TextXAlignment = Enum.TextXAlignment.Left
	BeastSlowBindButton.AutoButtonColor = false
	BeastSlowBindButton.Parent = PcFunctionsPage
	noTextStroke(BeastSlowBindButton)
	setTargetTransparency(BeastSlowBindButton, 1, 0)

	PcNormalWallhopButton = createPcActionButton(PcFlicksPage, 8, "Normal Wallhop")
	PcConsoleWallhopButton = createPcActionButton(PcFlicksPage, 46, "Console Wallhop")

	PcCurrentUsingLabel = Instance.new("TextLabel")
	PcCurrentUsingLabel.Size = UDim2.new(1, -36, 0, 34)
	PcCurrentUsingLabel.Position = UDim2.new(0, 18, 0, 88)
	PcCurrentUsingLabel.BackgroundTransparency = 1
	PcCurrentUsingLabel.TextColor3 = Color3.fromRGB(200,200,200)
	PcCurrentUsingLabel.Font = Enum.Font.Gotham
	PcCurrentUsingLabel.TextSize = 13
	PcCurrentUsingLabel.TextWrapped = true
	PcCurrentUsingLabel.TextXAlignment = Enum.TextXAlignment.Left
	PcCurrentUsingLabel.TextYAlignment = Enum.TextYAlignment.Top
	PcCurrentUsingLabel.Parent = PcFlicksPage
	noTextStroke(PcCurrentUsingLabel)
	setTargetTransparency(PcCurrentUsingLabel, 1, 0)

	local footer = Instance.new("TextLabel")
	footer.Size = UDim2.new(1, -36, 0, 14)
	footer.Position = UDim2.new(0, 18, 1, -16)
	footer.BackgroundTransparency = 1
	footer.Text = "the best ftf wallhop ever - nyhito panel"
	footer.TextColor3 = Color3.fromRGB(95,95,95)
	footer.Font = Enum.Font.Gotham
	footer.TextSize = 10
	footer.TextXAlignment = Enum.TextXAlignment.Left
	footer.Parent = MainFrame
	noTextStroke(footer)
	setTargetTransparency(footer, 1, 0)

	MiniButton = Instance.new("TextButton")
	MiniButton.Size = UDim2.new(0, 150, 0, 42)
	MiniButton.Position = MainFrame.Position
	MiniButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	MiniButton.Text = "FtF Wallhop"
	MiniButton.TextColor3 = Color3.fromRGB(220,220,220)
	MiniButton.Font = Enum.Font.GothamBold
	MiniButton.TextSize = 22
	MiniButton.Visible = false
	MiniButton.AutoButtonColor = false
	MiniButton.Parent = ScreenGui
	Instance.new("UICorner", MiniButton).CornerRadius = UDim.new(1, 0)
	noTextStroke(MiniButton)
	addTrueRoundedShadow(MiniButton, 999, 1.1, Color3.fromRGB(0, 0, 0))
	setTargetTransparency(MiniButton, 0, 0)

	Notice = Instance.new("TextLabel")
	Notice.Size = UDim2.new(0, 200, 0, 26)
	Notice.Position = UDim2.new(1, -14, 0, 14)
	Notice.AnchorPoint = Vector2.new(1, 0)
	Notice.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	Notice.BackgroundTransparency = 1
	Notice.TextColor3 = Color3.fromRGB(255,255,255)
	Notice.TextTransparency = 1
	Notice.Font = Enum.Font.GothamBold
	Notice.TextSize = 13
	Notice.Visible = false
	Notice.Parent = ScreenGui
	Instance.new("UICorner", Notice).CornerRadius = UDim.new(0, 10)
	noTextStroke(Notice)
	setTargetTransparency(Notice, 0.08, 0)

	NoticeStroke = Instance.new("UIStroke")
	NoticeStroke.Color = Color3.fromRGB(255,255,255)
	NoticeStroke.Thickness = 1
	NoticeStroke.Transparency = 1
	NoticeStroke.Parent = Notice

	MinimizeButton.MouseButton1Click:Connect(function()
		setMinimized(true)
	end)

	MiniButton.MouseButton1Click:Connect(function()
		setMinimized(false)
	end)

	PcTabFunctions.MouseButton1Click:Connect(function()
		switchPcTab("Functions")
	end)

	PcTabFlicks.MouseButton1Click:Connect(function()
		switchPcTab("Flicks")
	end)

	HideGuiBindButton.MouseButton1Click:Connect(function()
		waitingForHideKey = true
		waitingForToggleKey = false
		waitingForBeastSlowKey = false
		updateBindButtons()
		showNotice("Press a key...")
	end)

	ToggleBindButton.MouseButton1Click:Connect(function()
		waitingForToggleKey = true
		waitingForHideKey = false
		waitingForBeastSlowKey = false
		updateBindButtons()
		showNotice("Press a key...")
	end)

	BeastSlowBindButton.MouseButton1Click:Connect(function()
		waitingForBeastSlowKey = true
		waitingForHideKey = false
		waitingForToggleKey = false
		updateBindButtons()
		showNotice("Press a key...")
	end)

	ToggleButton.MouseButton1Click:Connect(function()
		isWallHopEnabled = not isWallHopEnabled
		updateToggleButton()
		showNotice(isWallHopEnabled and "Wallhop enabled" or "Wallhop disabled")
	end)

	PcNormalWallhopButton.MouseButton1Click:Connect(function()
		setFlickMode("Normal Wallhop")
	end)

	PcConsoleWallhopButton.MouseButton1Click:Connect(function()
		setFlickMode("Console Wallhop")
	end)

	switchPcTab("Functions")
	updateBindButtons()
	updateFlickButtons()
	elegantShow(MainFrame, UDim2.new(0, 335, 0, 270), MainFrame.Position, 0)
	showNotice("PC version loaded")
end

clearScriptSlowInstant = function()
	slowToken += 1
	scriptSlowActive = false

	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChild("Humanoid")
	if hum and hum.Parent and hum.WalkSpeed == SLOW_WALKSPEED then
		hum.WalkSpeed = DEFAULT_WALKSPEED
	end
end

local function applyWallhopSlow(hum)
	if not hum or not hum.Parent or not isSlowEnabled then
		return
	end

	slowToken += 1
	local myToken = slowToken

	scriptSlowActive = true
	hum.WalkSpeed = SLOW_WALKSPEED

	task.delay(SLOW_DURATION, function()
		if not hum or not hum.Parent then
			scriptSlowActive = false
			return
		end

		if myToken ~= slowToken then
			return
		end

		scriptSlowActive = false

		if not isSlowEnabled then
			return
		end

		if hum.WalkSpeed == SLOW_WALKSPEED then
			hum.WalkSpeed = DEFAULT_WALKSPEED
		end
	end)
end

local function isCrouching(hum, hrp)
	if not hum or not hrp then
		return false
	end

	if scriptSlowActive then
		return false
	end

	local horizontalSpeed = Vector3.new(hrp.Velocity.X, 0, hrp.Velocity.Z).Magnitude
	return hum.WalkSpeed <= 9 and horizontalSpeed < 8
end

local function setupCharacter(char)
	local hum = char:WaitForChild("Humanoid")
	local hrp = char:WaitForChild("HumanoidRootPart")

	slowToken = 0
	scriptSlowActive = false

	hum.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Jumping then
			jumpedRecently = true
			airborneSource = "jump"
			airborneStartY = hrp.Position.Y
			airborneStartTime = tick()
		end

		if new == Enum.HumanoidStateType.Freefall then
			canDoubleJump = true

			if airborneSource == nil then
				if jumpedRecently then
					airborneSource = "jump"
				else
					airborneSource = "ledge"
				end

				airborneStartY = hrp.Position.Y
				airborneStartTime = tick()
			end
		end

		if new == Enum.HumanoidStateType.Landed then
			canDoubleJump = false
			lastHitPosition = nil
			airborneSource = nil
			airborneStartY = nil
			airborneStartTime = 0
			jumpedRecently = false

			lastLandedTime = tick()
			hasWallhoppedSinceLanding = false
			specialFirstFlickArmed = false
		end
	end)
end

if LocalPlayer.Character then
	setupCharacter(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(setupCharacter)

UserInputService.JumpRequest:Connect(function()
	if not isWallHopEnabled or blockDoubleJump then
		return
	end

	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChild("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp then
		return
	end

	local stillValid = isWallHopping or (tick() - lastWallHopTime <= WALLHOP_GRACE_TIME)
	if not stillValid then
		return
	end

	if canDoubleJump and tick() - lastDoubleJump > DOUBLE_JUMP_COOLDOWN then
		lastDoubleJump = tick()
		canDoubleJump = false

		hrp.Velocity = Vector3.new(hrp.Velocity.X, 30, hrp.Velocity.Z)
		hum:ChangeState(Enum.HumanoidStateType.Jumping)

		task.delay(0.18, function()
			if hum then
				hum:ChangeState(Enum.HumanoidStateType.Freefall)
			end
		end)
	end
end)

local function pickNextFlick(useSpecialFirst)
	local minAngle, maxAngle

	if useSpecialFirst then
		minAngle, maxAngle = 70, 80
	else
		minAngle, maxAngle = 65, 80
	end

	local attempt = 0
	local angle

	repeat
		angle = math.random(minAngle, maxAngle)
		attempt += 1
	until not lastFlickAngle or math.abs(angle - lastFlickAngle) >= 10 or attempt > 20

	lastFlickAngle = angle
	return math.rad(angle)
end

local function getFlickProfile(useSpecialFirst)
	if useSpecialFirst then
		return {
			goSteps = math.random(2, 3),
			goDelayMin = 0.0095,
			goDelayMax = 0.0120,
			holdTime = 0.01,
			returnSteps = math.random(2, 3),
			returnDelayMin = 0.0095,
			returnDelayMax = 0.0120,
			overshootMin = 22,
			overshootMax = 25,
			overshootBaseDelay = 0.0085
		}
	end

	local flickRoll = math.random()

	if flickRoll < 0.10 then
		return {
			goSteps = math.random(2, 3),
			goDelayMin = 0.0080,
			goDelayMax = 0.0103,
			holdTime = 0.01,
			returnSteps = math.random(2, 3),
			returnDelayMin = 0.0080,
			returnDelayMax = 0.0103,
			overshootMin = 12,
			overshootMax = 18,
			overshootBaseDelay = 0.0068
		}
	elseif flickRoll < 0.40 then
		return {
			goSteps = math.random(3, 4),
			goDelayMin = 0.0085,
			goDelayMax = 0.0110,
			holdTime = 0.01,
			returnSteps = math.random(3, 4),
			returnDelayMin = 0.0085,
			returnDelayMax = 0.0110,
			overshootMin = 14,
			overshootMax = 20,
			overshootBaseDelay = 0.0075
		}
	else
		return {
			goSteps = math.random(2, 3),
			goDelayMin = 0.0090,
			goDelayMax = 0.0119,
			holdTime = 0.01,
			returnSteps = math.random(2, 3),
			returnDelayMin = 0.0090,
			returnDelayMax = 0.0119,
			overshootMin = 16,
			overshootMax = 22,
			overshootBaseDelay = 0.0085
		}
	end
end

local function performNormalWallhop()
	if isFlicking then
		return
	end

	isFlicking = true
	isWallHopping = true
	lastWallHopTime = tick()
	blockDoubleJump = true

	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChild("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp then
		isFlicking = false
		return
	end

	local useSpecialFirst = specialFirstFlickArmed and not hasWallhoppedSinceLanding
	if useSpecialFirst then
		specialFirstFlickArmed = false
	end
	hasWallhoppedSinceLanding = true

	hum:ChangeState(Enum.HumanoidStateType.Jumping)

	local baseYaw = hrp.Orientation.Y
	local angle = -pickNextFlick(useSpecialFirst)
	local profile = getFlickProfile(useSpecialFirst)

	local goSteps = profile.goSteps
	local goDelayMin = profile.goDelayMin
	local goDelayMax = profile.goDelayMax
	local holdTime = profile.holdTime
	local returnSteps = profile.returnSteps
	local returnDelayMin = profile.returnDelayMin
	local returnDelayMax = profile.returnDelayMax

	local overshoot = math.rad(math.random(profile.overshootMin, profile.overshootMax) + 5)
	local overshootBaseDelay = profile.overshootBaseDelay
	local useOvershoot = math.random() < 0.40

	for i = 1, goSteps do
		local alpha = i / goSteps
		local offset = angle * alpha
		hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, math.rad(baseYaw) + offset, 0)

		if i < goSteps then
			RunService.RenderStepped:Wait()
			task.wait(goDelayMin + math.random() * (goDelayMax - goDelayMin))
		end
	end

	task.wait(holdTime)

	for i = 1, returnSteps do
		local alpha = i / returnSteps
		local offset = angle * (1 - alpha)
		hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, math.rad(baseYaw) + offset, 0)

		if i < returnSteps then
			RunService.RenderStepped:Wait()
			task.wait(returnDelayMin + math.random() * (returnDelayMax - returnDelayMin))
		end
	end

	if useOvershoot then
		task.delay(0.018, function()
			if not hrp or not hrp.Parent then
				return
			end

			local smallSteps = math.random(2, 3)
			local localDelay = overshootBaseDelay * (math.random(88, 102) / 100)

			for i = 1, smallSteps do
				local alpha = i / smallSteps
				local offset = overshoot * alpha
				hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, math.rad(baseYaw) + offset, 0)
				if i < smallSteps then
					RunService.RenderStepped:Wait()
					task.wait(localDelay)
				end
			end

			for i = 1, smallSteps do
				local alpha = i / smallSteps
				local offset = overshoot * (1 - alpha)
				hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, math.rad(baseYaw) + offset, 0)
				if i < smallSteps then
					RunService.RenderStepped:Wait()
					task.wait(localDelay)
				end
			end

			hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, math.rad(baseYaw), 0)
		end)
	end

	hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, math.rad(baseYaw), 0)

	if isSlowEnabled then
		applyWallhopSlow(hum)
	end

	task.delay(0.05, function()
		blockDoubleJump = false
	end)

	task.delay(0.15, function()
		isWallHopping = false
	end)

	isFlicking = false
end

local function performConsoleWallhop()
	if isFlicking then
		return
	end

	isFlicking = true
	isWallHopping = true
	lastWallHopTime = tick()
	blockDoubleJump = true

	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChild("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp then
		isFlicking = false
		return
	end

	hasWallhoppedSinceLanding = true
	specialFirstFlickArmed = false

	hum:ChangeState(Enum.HumanoidStateType.Jumping)

	local function getCameraFlat()
		local look = Camera.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude <= 0 then
			return nil
		end
		return flat.Unit
	end

	local function getYawFromVector(vec)
		return math.atan2(-vec.X, -vec.Z)
	end

	local function wrapAngle(angle)
		return math.atan2(math.sin(angle), math.cos(angle))
	end

	local camFlat = getCameraFlat()
	if camFlat then
		local targetYaw = getYawFromVector(camFlat)
		local flickYaw = targetYaw - math.rad(85)

		hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, flickYaw, 0)

		task.spawn(function()
			local returnSteps = 90
			local stepDelay = 0.250

			for i = 1, returnSteps do
				if not hrp or not hrp.Parent then
					break
				end

				local liveFlat = getCameraFlat()
				if not liveFlat then
					break
				end

				local liveTargetYaw = getYawFromVector(liveFlat)
				local currentYaw = math.atan2(-hrp.CFrame.LookVector.X, -hrp.CFrame.LookVector.Z)
				local delta = wrapAngle(liveTargetYaw - currentYaw)
				local nextYaw = currentYaw + (delta * 0.50)

				hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, nextYaw, 0)

				if i < returnSteps then
					RunService.RenderStepped:Wait()
					task.wait(stepDelay)
				end
			end
		end)
	end

	if isSlowEnabled then
		applyWallhopSlow(hum)
	end

	task.delay(0.12, function()
		blockDoubleJump = false
	end)

	task.delay(0.45, function()
		isWallHopping = false
	end)

	isFlicking = false
end

local function performSelectedWallhop()
	if currentFlickMode == "Console Wallhop" then
		performConsoleWallhop()
	else
		performNormalWallhop()
	end
end

local function isPlayerCharacter(instance)
	if not instance then
		return false
	end

	local model = instance:FindFirstAncestorOfClass("Model")
	return model and model:FindFirstChild("Humanoid")
end

local function isWallLikeSurface(normal)
	return math.abs(normal.Y) < 0.35
end

local function hasValidHorizontalEdge(rayResult, params)
	if not rayResult or not rayResult.Instance then
		return false
	end

	local hitPos = rayResult.Position
	local normal = rayResult.Normal.Unit

	local right = normal:Cross(Vector3.new(0, 1, 0))
	if right.Magnitude < 0.01 then
		return false
	end
	right = right.Unit

	local surfaceOffset = normal * 0.08

	local verticalChecks = {
		Vector3.new(0, 0.9, 0),
		Vector3.new(0, -0.9, 0),
		Vector3.new(0, 1.25, 0),
		Vector3.new(0, -1.25, 0),
	}

	local foundHorizontalEdge = false
	for _, vOffset in ipairs(verticalChecks) do
		local origin = hitPos + vOffset + surfaceOffset
		local probe = workspace:Raycast(origin, -normal * 0.22, params)

		if not probe or not probe.Instance or probe.Instance ~= rayResult.Instance then
			foundHorizontalEdge = true
			break
		end
	end

	return foundHorizontalEdge
end

local function findValidWall(hrp, params, directions)
	local offsets = {
		Vector3.new(0, -2.3, 0),
		Vector3.new(0, -2.2, 0),
		Vector3.new(0, -1.2, 0)
	}

	for _, dir in ipairs(directions) do
		for _, offset in ipairs(offsets) do
			local origin = hrp.Position + offset
			local ray = workspace:Raycast(origin, dir, params)

			if ray and ray.Instance and ray.Instance.CanCollide and not isPlayerCharacter(ray.Instance) then
				if isWallLikeSurface(ray.Normal) and hasValidHorizontalEdge(ray, params) then
					return ray
				end
			end
		end
	end

	return nil
end

local function isWithinWallhopAngle(cameraLook, wallNormal, maxAngleDeg)
	local look = Vector3.new(cameraLook.X, 0, cameraLook.Z)
	local normal = Vector3.new(wallNormal.X, 0, wallNormal.Z)

	if look.Magnitude <= 0 or normal.Magnitude <= 0 then
		return false
	end

	look = look.Unit
	normal = normal.Unit

	local dotFront = math.clamp(look:Dot(-normal), -1, 1)
	local dotBack = math.clamp(look:Dot(normal), -1, 1)

	local frontAngle = math.deg(math.acos(dotFront))
	local backAngle = math.deg(math.acos(dotBack))

	return frontAngle <= maxAngleDeg or backAngle <= maxAngleDeg
end

RunService.Heartbeat:Connect(function()
	if not isWallHopEnabled then
		return
	end

	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChild("Humanoid")

	if not hrp or not hum then
		return
	end

	if isCrouching(hum, hrp) then
		return
	end

	local state = hum:GetState()
	local airborne = state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping

	if state == Enum.HumanoidStateType.Landed then
		if not hasWallhoppedSinceLanding and lastLandedTime > 0 and tick() - lastLandedTime >= FIRST_FLICK_RESET_GROUND_TIME then
			specialFirstFlickArmed = true
		end
	end

	if not airborne then
		lastHitPosition = nil
		return
	end

	local allowWallhop = true

	if airborneSource == "ledge" and airborneStartY then
		local fallDistance = airborneStartY - hrp.Position.Y
		local airTime = tick() - airborneStartTime

		if fallDistance < LEDGE_BLOCK_DISTANCE and airTime < LEDGE_BLOCK_TIME then
			allowWallhop = false
		end
	end

	if not allowWallhop then
		lastHitPosition = nil
		return
	end

	local params = RaycastParams.new()
	params.FilterDescendantsInstances = {char}
	params.FilterType = Enum.RaycastFilterType.Exclude

	local look = Camera.CFrame.LookVector
	local horizontal = Vector3.new(look.X, 0, look.Z)

	if horizontal.Magnitude <= 0 then
		lastHitPosition = nil
		return
	end

	horizontal = horizontal.Unit

	local forwardDirection = horizontal * 1.55
	local backwardDirection = -horizontal * 1.55

	local result = findValidWall(hrp, params, {
		forwardDirection,
		backwardDirection
	})

	if result and result.Instance then
		local validAngle = currentFlickMode == "Console Wallhop"
			or isWithinWallhopAngle(Camera.CFrame.LookVector, result.Normal, 25)

		if validAngle then
			local farEnough = true
			if lastHitPosition then
				farEnough = (result.Position - lastHitPosition).Magnitude >= MIN_HIT_DISTANCE
			end

			if hrp.Velocity.Y < -0.8 and tick() - lastFlickTime > WALLHOP_COOLDOWN and farEnough then
				lastFlickTime = tick()
				lastHitPosition = result.Position
				performSelectedWallhop()
			else
				lastHitPosition = result.Position
			end
		else
			lastHitPosition = nil
		end
	else
		lastHitPosition = nil
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end

	local key = input.KeyCode

	if selectedMode == "PC" then
		if waitingForHideKey then
			if key ~= toggleScriptKey and key ~= toggleBeastSlowKey then
				hideGuiKey = key
				waitingForHideKey = false
				savePCKeybinds()
				updateBindButtons()
				showNotice("Hide GUI key updated")
			else
				showNotice("Key already in use")
			end
			return
		end

		if waitingForToggleKey then
			if key ~= hideGuiKey and key ~= toggleBeastSlowKey then
				toggleScriptKey = key
				waitingForToggleKey = false
				savePCKeybinds()
				updateBindButtons()
				showNotice("Wallhop key updated")
			else
				showNotice("Key already in use")
			end
			return
		end

		if waitingForBeastSlowKey then
			if key ~= hideGuiKey and key ~= toggleScriptKey then
				toggleBeastSlowKey = key
				waitingForBeastSlowKey = false
				savePCKeybinds()
				updateBindButtons()
				showNotice("Beast Slow key updated")
			else
				showNotice("Key already in use")
			end
			return
		end

		if key == hideGuiKey then
			setGuiVisible(not guiVisible)
			return
		end

		if key == toggleScriptKey then
			isWallHopEnabled = not isWallHopEnabled
			updateToggleButton()
			showNotice(isWallHopEnabled and "Wallhop enabled" or "Wallhop disabled")
			return
		end

		if key == toggleBeastSlowKey then
			setSlowEnabled(not isSlowEnabled)
			showNotice(isSlowEnabled and "Beast Slow enabled" or "Beast Slow disabled")
			return
		end
	end
end)

createModeSelector(function(mode)
	selectedMode = mode

	if mode == "PC" then
		buildPCGui()
	else
		buildMobileGui()
	end

	updateToggleButton()
	updateMobilePanelButtons()
	updateFlickButtons()
	applyVisibility()
end)

print("Best FFFlee The Facility | Made by Nyhito - Loaded Successfully ✅")
