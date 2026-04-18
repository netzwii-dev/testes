-- UI VISUAL TEST ONLY - Made by nyhito / adjusted by chatscript
-- Apenas visual/interface para testes

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")

local selectedMode = nil

local DEFAULT_HIDE_GUI_KEY = Enum.KeyCode.RightShift
local DEFAULT_TOGGLE_SCRIPT_KEY = Enum.KeyCode.Q
local DEFAULT_TOGGLE_BEAST_SLOW_KEY = Enum.KeyCode.E

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

local fakeWallhopEnabled = false
local fakeSlowEnabled = false

local ScreenGui
local MainFrame
local MiniButton
local MobileButton
local MobileMenuButton
local MobilePanel
local MobileBeastSlowRow
local MobileHideGuiRow
local ToggleButton
local HideGuiBindButton
local ToggleBindButton
local BeastSlowBindButton
local Notice
local NoticeStroke

local mobileBeastSlowSwitch
local mobileBeastSlowKnob
local mobileHideGuiSwitch
local mobileHideGuiKnob

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

local function noTextStroke(obj)
	obj.TextStrokeTransparency = 1
end

local function addTrueRoundedShadow(parent, cornerRadius, strength, shadowColor)
	strength = strength or 1
	shadowColor = shadowColor or Color3.fromRGB(0, 0, 0)

	local layers = {
		{grow = math.floor(6 * strength), transparency = 0.84, y = 1},
		{grow = math.floor(12 * strength), transparency = 0.90, y = 2},
		{grow = math.floor(18 * strength), transparency = 0.95, y = 3},
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
		shadow.ZIndex = 0
		shadow.Parent = parent

		Instance.new("UICorner", shadow).CornerRadius =
			UDim.new(0, cornerRadius + math.floor(cfg.grow / 2.2))
	end
end

local function setGroupTransparency(root, bgT, textT)
	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("Frame") or obj:IsA("TextButton") or obj:IsA("TextLabel") then
			pcall(function()
				obj.BackgroundTransparency = bgT
			end)
		end

		if obj:IsA("TextButton") or obj:IsA("TextLabel") then
			pcall(function()
				obj.TextTransparency = textT
			end)
		end

		if obj:IsA("UIStroke") then
			pcall(function()
				obj.Transparency = math.clamp(bgT, 0, 1)
			end)
		end
	end
end

local function elegantShow(root, finalSize, finalPosition, finalBgTransparency)
	if not root then return end

	root.Visible = true
	root.AnchorPoint = Vector2.new(0.5, 0.5)

	local targetSize = finalSize or root.Size
	local targetPos = finalPosition or root.Position
	local targetBg = finalBgTransparency
	if targetBg == nil then
		targetBg = root.BackgroundTransparency
	end

	root.Size = UDim2.new(
		targetSize.X.Scale * 0.72, math.floor(targetSize.X.Offset * 0.72),
		targetSize.Y.Scale * 0.72, math.floor(targetSize.Y.Offset * 0.72)
	)
	root.Position = targetPos
	root.BackgroundTransparency = 1
	setGroupTransparency(root, 1, 1)

	TweenService:Create(root, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Size = targetSize,
		Position = targetPos,
		BackgroundTransparency = targetBg
	}):Play()

	task.delay(0.03, function()
		for _, obj in ipairs(root:GetDescendants()) do
			if obj:IsA("Frame") or obj:IsA("TextButton") or obj:IsA("TextLabel") then
				local goal = {}
				if obj:IsA("Frame") or obj:IsA("TextButton") then
					goal.BackgroundTransparency = 0
				end
				if obj:IsA("TextButton") or obj:IsA("TextLabel") then
					goal.TextTransparency = 0
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
	local shrinkSize = UDim2.new(
		currentSize.X.Scale * 0.76, math.floor(currentSize.X.Offset * 0.76),
		currentSize.Y.Scale * 0.76, math.floor(currentSize.Y.Offset * 0.76)
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
			TweenService:Create(obj, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In), goal):Play()
		elseif obj:IsA("UIStroke") then
			TweenService:Create(obj, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Transparency = 1
			}):Play()
		end
	end

	local tween = TweenService:Create(root, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
		Size = shrinkSize,
		BackgroundTransparency = 1
	})
	tween:Play()
	tween.Completed:Connect(function()
		root.Visible = false
		if onDone then onDone() end
	end)
end

local activeNoticeId = 0
local function showNotice(text)
	if selectedMode ~= "PC" or not Notice or not NoticeStroke then
		return
	end

	activeNoticeId += 1
	local noticeId = activeNoticeId

	Notice.Text = text
	Notice.Visible = true
	Notice.AnchorPoint = Vector2.new(1, 0)
	Notice.Position = UDim2.new(1, 0, 0, 0)
	Notice.Size = UDim2.new(0, 150, 0, 18)
	Notice.BackgroundTransparency = 1
	Notice.TextTransparency = 1
	NoticeStroke.Transparency = 1

	TweenService:Create(Notice, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 200, 0, 26),
		BackgroundTransparency = 0.08,
		TextTransparency = 0
	}):Play()

	TweenService:Create(NoticeStroke, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 0.9
	}):Play()

	task.spawn(function()
		task.wait(1)
		if noticeId ~= activeNoticeId then
			return
		end

		TweenService:Create(Notice, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
			Size = UDim2.new(0, 150, 0, 18),
			BackgroundTransparency = 1,
			TextTransparency = 1
		}):Play()

		TweenService:Create(NoticeStroke, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Transparency = 1
		}):Play()
	end)
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
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 12)

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
	noTextStroke(label)

	local switch = Instance.new("Frame")
	switch.Size = UDim2.new(0, 54, 0, 28)
	switch.Position = UDim2.new(1, -66, 0.5, -14)
	switch.BackgroundColor3 = Color3.fromRGB(20,20,24)
	switch.BorderSizePixel = 0
	switch.Parent = row
	Instance.new("UICorner", switch).CornerRadius = UDim.new(1, 0)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 26, 0, 26)
	knob.Position = UDim2.new(0, 3, 0.5, -13)
	knob.BackgroundColor3 = Color3.fromRGB(0,0,0)
	knob.BorderSizePixel = 0
	knob.Parent = switch
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

	return row, switch, knob
end

local function updateToggleButton()
	if selectedMode == "PC" and ToggleButton then
		ToggleButton.Text = fakeWallhopEnabled and "Wall Hop On" or "Wall Hop Off"
	elseif selectedMode == "Mobile" and MobileButton then
		MobileButton.Text = fakeWallhopEnabled and "Wallhop On" or "Wallhop Off"
	end
end

local function setMobileWallhopVisualHidden(hidden)
	if not MobileButton then return end

	MobileButton.BackgroundTransparency = hidden and 1 or 0
	MobileButton.TextTransparency = hidden and 1 or 0
end

local function updateMobilePanelButtons()
	if MobileBeastSlowRow and MobileBeastSlowRow:FindFirstChild("Label") then
		MobileBeastSlowRow.Label.Text = "Beast Slow"
	end
	if MobileHideGuiRow and MobileHideGuiRow:FindFirstChild("Label") then
		MobileHideGuiRow.Label.Text = "Hide GUI"
	end

	updateSwitchVisual(mobileBeastSlowSwitch, mobileBeastSlowKnob, fakeSlowEnabled)
	updateSwitchVisual(mobileHideGuiSwitch, mobileHideGuiKnob, mobileWallhopGuiHidden)
	setMobileWallhopVisualHidden(mobileWallhopGuiHidden)
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

local function applyVisibility()
	if selectedMode == "PC" then
		if MainFrame then
			MainFrame.Visible = guiVisible and not guiMinimized
		end
		if MiniButton then
			MiniButton.Visible = guiVisible and guiMinimized
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
		end
		setMobileWallhopVisualHidden(mobileWallhopGuiHidden)
	end
end

local function setGuiVisible(state)
	guiVisible = state
	applyVisibility()
	showNotice(state and "GUI shown" or "GUI hidden")
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

	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.new(1, -20, 0, 16)
	sub.Position = UDim2.new(0, 10, 0, 34)
	sub.BackgroundTransparency = 1
	sub.Text = "FtF Wallhop • visual test"
	sub.TextColor3 = Color3.fromRGB(95,95,95)
	sub.Font = Enum.Font.Gotham
	sub.TextSize = 12
	sub.Parent = frame
	noTextStroke(sub)

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
local function setMinimized(state)
	if selectedMode ~= "PC" then
		return
	end

	guiMinimized = state

	if state then
		if MainFrame and MiniButton then
			MiniButton.Position = MainFrame.Position
			MainFrame.Visible = false
			MiniButton.BackgroundTransparency = 1
			MiniButton.TextTransparency = 1
			MiniButton.Visible = true

			TweenService:Create(MiniButton, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = 0,
				TextTransparency = 0
			}):Play()
		end
		showNotice("GUI minimized")
	else
		if MainFrame and MiniButton then
			MainFrame.Position = MiniButton.Position
			MiniButton.Visible = false
			MainFrame.Visible = true
			elegantShow(MainFrame, UDim2.new(0, 265, 0, 196), MainFrame.Position, 0)
		end
		showNotice("GUI restored")
	end
end

local function buildMobileGui()
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
	Instance.new("UICorner", MobileButton).CornerRadius = UDim.new(0, 12)
	noTextStroke(MobileButton)
	addTrueRoundedShadow(MobileButton, 14, 1, Color3.fromRGB(0, 0, 0))

	MobileMenuButton = Instance.new("TextButton")
	MobileMenuButton.Size = UDim2.new(0, 54, 0, 54)
	MobileMenuButton.Position = UDim2.new(0, 20, 0, 180)
	MobileMenuButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	MobileMenuButton.Text = "≡"
	MobileMenuButton.TextColor3 = Color3.fromRGB(255,255,255)
	MobileMenuButton.Font = Enum.Font.GothamBold
	MobileMenuButton.TextSize = 22
	MobileMenuButton.Parent = ScreenGui
	Instance.new("UICorner", MobileMenuButton).CornerRadius = UDim.new(1, 0)
	noTextStroke(MobileMenuButton)
	addTrueRoundedShadow(MobileMenuButton, 999, 1, Color3.fromRGB(0, 0, 0))

	MobilePanel = Instance.new("Frame")
	MobilePanel.Size = UDim2.new(0, 170, 0, 94)
	MobilePanel.Position = UDim2.new(0, 20, 0, 240)
	MobilePanel.AnchorPoint = Vector2.new(0.5, 0.5)
	MobilePanel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	MobilePanel.BorderSizePixel = 0
	MobilePanel.Visible = false
	MobilePanel.Parent = ScreenGui
	Instance.new("UICorner", MobilePanel).CornerRadius = UDim.new(0, 14)
	addTrueRoundedShadow(MobilePanel, 14, 1, Color3.fromRGB(0, 0, 0))

	MobileBeastSlowRow, mobileBeastSlowSwitch, mobileBeastSlowKnob = createSwitchRow(MobilePanel, 7, "Beast Slow")
	MobileHideGuiRow, mobileHideGuiSwitch, mobileHideGuiKnob = createSwitchRow(MobilePanel, 47, "Hide GUI")

	RunService.RenderStepped:Connect(function()
		if selectedMode ~= "Mobile" then return end
		local inset = GuiService:GetGuiInset()
		if not MobileButton:GetAttribute("CustomMoved") then
			MobileButton.Position = UDim2.new(0, 150, 0, inset.Y - 58)
		end
	end)

	local wallhopDrag = {
		holding = false,
		input = nil,
		startPos = nil,
		startInput = nil
	}

	MobileButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			wallhopDrag.holding = true
			wallhopDrag.input = input
			wallhopDrag.startPos = MobileButton.Position
			wallhopDrag.startInput = input.Position
		end
	end)

	MobileButton.InputChanged:Connect(function(input)
		if wallhopDrag.holding and wallhopDrag.input == input and input.UserInputType == Enum.UserInputType.Touch then
			local delta = input.Position - wallhopDrag.startInput
			MobileButton.Position = UDim2.new(
				wallhopDrag.startPos.X.Scale,
				wallhopDrag.startPos.X.Offset + delta.X,
				wallhopDrag.startPos.Y.Scale,
				wallhopDrag.startPos.Y.Offset + delta.Y
			)
			MobileButton:SetAttribute("CustomMoved", true)
		end
	end)

	MobileButton.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch and wallhopDrag.input == input then
			wallhopDrag.holding = false
			wallhopDrag.input = nil
		end
	end)

	local menuDrag = {
		holding = false,
		input = nil,
		startPos = nil,
		startInput = nil
	}

	MobileMenuButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			menuDrag.holding = true
			menuDrag.input = input
			menuDrag.startPos = MobileMenuButton.Position
			menuDrag.startInput = input.Position
		end
	end)

	MobileMenuButton.InputChanged:Connect(function(input)
		if menuDrag.holding and menuDrag.input == input and input.UserInputType == Enum.UserInputType.Touch then
			local delta = input.Position - menuDrag.startInput
			MobileMenuButton.Position = UDim2.new(
				menuDrag.startPos.X.Scale,
				menuDrag.startPos.X.Offset + delta.X,
				menuDrag.startPos.Y.Scale,
				menuDrag.startPos.Y.Offset + delta.Y
			)
		end
	end)

	MobileMenuButton.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch and menuDrag.input == input then
			menuDrag.holding = false
			menuDrag.input = nil
		end
	end)

	local panelDrag = {
		holding = false,
		input = nil,
		startPos = nil,
		startInput = nil
	}

	MobilePanel.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			panelDrag.holding = true
			panelDrag.input = input
			panelDrag.startPos = MobilePanel.Position
			panelDrag.startInput = input.Position
		end
	end)

	MobilePanel.InputChanged:Connect(function(input)
		if panelDrag.holding and panelDrag.input == input and input.UserInputType == Enum.UserInputType.Touch then
			local delta = input.Position - panelDrag.startInput
			MobilePanel.Position = UDim2.new(
				panelDrag.startPos.X.Scale,
				panelDrag.startPos.X.Offset + delta.X,
				panelDrag.startPos.Y.Scale,
				panelDrag.startPos.Y.Offset + delta.Y
			)
		end
	end)

	MobilePanel.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch and panelDrag.input == input then
			panelDrag.holding = false
			panelDrag.input = nil
		end
	end)

	MobileButton.MouseButton1Click:Connect(function()
		fakeWallhopEnabled = not fakeWallhopEnabled
		updateToggleButton()
	end)

	MobileMenuButton.MouseButton1Click:Connect(function()
		mobileMenuOpen = not mobileMenuOpen
		if mobileMenuOpen then
			elegantShow(MobilePanel, UDim2.new(0, 170, 0, 94), MobilePanel.Position, 0)
		else
			elegantHide(MobilePanel)
		end
	end)

	MobileBeastSlowRow.MouseButton1Click:Connect(function()
		fakeSlowEnabled = not fakeSlowEnabled
		updateMobilePanelButtons()
	end)

	MobileHideGuiRow.MouseButton1Click:Connect(function()
		mobileWallhopGuiHidden = not mobileWallhopGuiHidden
		updateMobilePanelButtons()
	end)

	updateMobilePanelButtons()
end

local function buildPCGui()
	ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "AutoWallHopGui"
	ScreenGui.ResetOnSpawn = false
	ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ScreenGui.Parent = PlayerGui

	MainFrame = Instance.new("Frame")
	MainFrame.Size = UDim2.new(0, 265, 0, 196)
	MainFrame.Position = UDim2.new(0.5, -132, 0.5, -98)
	MainFrame.AnchorPoint = Vector2.new(0, 0)
	MainFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	MainFrame.BorderSizePixel = 0
	MainFrame.Parent = ScreenGui
	MainFrame.Visible = true
	Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 16)
	addTrueRoundedShadow(MainFrame, 16, 1.25, Color3.fromRGB(0, 0, 0))

	local TopBar = Instance.new("Frame")
	TopBar.Size = UDim2.new(1, 0, 0, 34)
	TopBar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	TopBar.BorderSizePixel = 0
	TopBar.Parent = MainFrame
	Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0, 16)

	local Title = Instance.new("TextLabel")
	Title.Size = UDim2.new(1, -45, 1, 0)
	Title.Position = UDim2.new(0, 12, 0, 0)
	Title.BackgroundTransparency = 1
	Title.Text = "Wallhop PC"
	Title.TextColor3 = Color3.fromRGB(255,255,255)
	Title.Font = Enum.Font.GothamBold
	Title.TextSize = 16
	Title.TextXAlignment = Enum.TextXAlignment.Left
	Title.Parent = TopBar
	noTextStroke(Title)

	local MinimizeButton = Instance.new("TextButton")
	MinimizeButton.Size = UDim2.new(0, 24, 0, 24)
	MinimizeButton.Position = UDim2.new(1, -30, 0.5, -12)
	MinimizeButton.BackgroundColor3 = Color3.fromRGB(8,8,8)
	MinimizeButton.Text = "—"
	MinimizeButton.TextColor3 = Color3.fromRGB(255,255,255)
	MinimizeButton.Font = Enum.Font.GothamBold
	MinimizeButton.TextSize = 18
	MinimizeButton.Parent = TopBar
	Instance.new("UICorner", MinimizeButton).CornerRadius = UDim.new(1, 0)
	noTextStroke(MinimizeButton)

	ToggleButton = Instance.new("TextButton")
	ToggleButton.Size = UDim2.new(1, -16, 0, 40)
	ToggleButton.Position = UDim2.new(0, 8, 0, 44)
	ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	ToggleButton.Text = "Wall Hop Off"
	ToggleButton.TextColor3 = Color3.fromRGB(255,255,255)
	ToggleButton.Font = Enum.Font.GothamBold
	ToggleButton.TextSize = 15
	ToggleButton.Parent = MainFrame
	Instance.new("UICorner", ToggleButton).CornerRadius = UDim.new(0, 12)
	noTextStroke(ToggleButton)

	HideGuiBindButton = Instance.new("TextButton")
	HideGuiBindButton.Size = UDim2.new(1, -16, 0, 30)
	HideGuiBindButton.Position = UDim2.new(0, 8, 0, 92)
	HideGuiBindButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	HideGuiBindButton.TextColor3 = Color3.fromRGB(255,255,255)
	HideGuiBindButton.Font = Enum.Font.GothamBold
	HideGuiBindButton.TextSize = 13
	HideGuiBindButton.Parent = MainFrame
	Instance.new("UICorner", HideGuiBindButton).CornerRadius = UDim.new(0, 10)
	noTextStroke(HideGuiBindButton)

	ToggleBindButton = Instance.new("TextButton")
	ToggleBindButton.Size = UDim2.new(1, -16, 0, 30)
	ToggleBindButton.Position = UDim2.new(0, 8, 0, 127)
	ToggleBindButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	ToggleBindButton.TextColor3 = Color3.fromRGB(255,255,255)
	ToggleBindButton.Font = Enum.Font.GothamBold
	ToggleBindButton.TextSize = 13
	ToggleBindButton.Parent = MainFrame
	Instance.new("UICorner", ToggleBindButton).CornerRadius = UDim.new(0, 10)
	noTextStroke(ToggleBindButton)

	BeastSlowBindButton = Instance.new("TextButton")
	BeastSlowBindButton.Size = UDim2.new(1, -16, 0, 30)
	BeastSlowBindButton.Position = UDim2.new(0, 8, 0, 162)
	BeastSlowBindButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	BeastSlowBindButton.TextColor3 = Color3.fromRGB(255,255,255)
	BeastSlowBindButton.Font = Enum.Font.GothamBold
	BeastSlowBindButton.TextSize = 13
	BeastSlowBindButton.Parent = MainFrame
	Instance.new("UICorner", BeastSlowBindButton).CornerRadius = UDim.new(0, 10)
	noTextStroke(BeastSlowBindButton)

	MiniButton = Instance.new("TextButton")
	MiniButton.Size = UDim2.new(0, 58, 0, 34)
	MiniButton.Position = MainFrame.Position
	MiniButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	MiniButton.Text = "GUI"
	MiniButton.TextColor3 = Color3.fromRGB(255,255,255)
	MiniButton.Font = Enum.Font.GothamBold
	MiniButton.TextSize = 14
	MiniButton.Visible = false
	MiniButton.Parent = ScreenGui
	Instance.new("UICorner", MiniButton).CornerRadius = UDim.new(0, 12)
	noTextStroke(MiniButton)
	addTrueRoundedShadow(MiniButton, 12, 1, Color3.fromRGB(0, 0, 0))

	Notice = Instance.new("TextLabel")
	Notice.Size = UDim2.new(0, 200, 0, 26)
	Notice.Position = UDim2.new(1, 0, 0, 0)
	Notice.AnchorPoint = Vector2.new(1, 0)
	Notice.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	Notice.BackgroundTransparency = 1
	Notice.TextColor3 = Color3.fromRGB(255,255,255)
	Notice.TextTransparency = 1
	Notice.Font = Enum.Font.GothamBold
	Notice.TextSize = 13
	Notice.Visible = true
	Notice.Parent = ScreenGui
	Instance.new("UICorner", Notice).CornerRadius = UDim.new(0, 10)
	noTextStroke(Notice)

	NoticeStroke = Instance.new("UIStroke")
	NoticeStroke.Color = Color3.fromRGB(255,255,255)
	NoticeStroke.Thickness = 1
	NoticeStroke.Transparency = 1
	NoticeStroke.Parent = Notice

	local dragging = false
	local dragInput
	local dragStart
	local startPos

	local function updateDrag(input, frame)
		local delta = input.Position - dragStart
		frame.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
	end

	local function bindDrag(dragObject, frame)
		dragObject.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				dragInput = input
				dragStart = input.Position
				startPos = frame.Position

				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						dragging = false
					end
				end)
			end
		end)

		dragObject.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				dragInput = input
			end
		end)

		UserInputService.InputChanged:Connect(function(input)
			if input == dragInput and dragging then
				updateDrag(input, frame)
			end
		end)
	end

	bindDrag(TopBar, MainFrame)
	bindDrag(MiniButton, MiniButton)

	MinimizeButton.MouseButton1Click:Connect(function()
		setMinimized(true)
	end)

	MiniButton.MouseButton1Click:Connect(function()
		setMinimized(false)
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
		fakeWallhopEnabled = not fakeWallhopEnabled
		updateToggleButton()
		showNotice(fakeWallhopEnabled and "Wallhop enabled" or "Wallhop disabled")
	end)

	RunService.RenderStepped:Connect(function()
		if selectedMode ~= "PC" then return end
		local inset = GuiService:GetGuiInset()
		if guiVisible and not dragging then
			if not guiMinimized and MainFrame.Position == UDim2.new(0.5, -132, 0.5, -98) then
				MainFrame.Position = UDim2.new(0.5, -132, 0.5, -98 + inset.Y / 2)
			end
		end
	end)

	updateBindButtons()
	MainFrame.Visible = true
	elegantShow(MainFrame, UDim2.new(0, 265, 0, 196), MainFrame.Position, 0)
	showNotice("PC version loaded")
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

	local key = input.KeyCode

	if selectedMode == "PC" then
		if waitingForHideKey then
			if key ~= toggleScriptKey and key ~= toggleBeastSlowKey then
				hideGuiKey = key
				waitingForHideKey = false
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
			fakeWallhopEnabled = not fakeWallhopEnabled
			updateToggleButton()
			showNotice(fakeWallhopEnabled and "Wallhop enabled" or "Wallhop disabled")
			return
		end

		if key == toggleBeastSlowKey then
			fakeSlowEnabled = not fakeSlowEnabled
			showNotice(fakeSlowEnabled and "Beast Slow enabled" or "Beast Slow disabled")
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
	applyVisibility()
end)

print("UI visual test loaded successfully")
