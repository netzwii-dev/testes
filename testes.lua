local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local selectedMode = nil
local ScreenGui
local MainFrame
local MiniButton
local MobileButton
local MobileHideButton

local function addBlurShadow(parent, cornerRadius, spread, baseTransparency)
	spread = spread or 14
	baseTransparency = baseTransparency or 0.86

	local layers = {
		{grow = math.floor(spread * 0.45), y = 1, transparency = baseTransparency - 0.05},
		{grow = math.floor(spread * 0.9),  y = 2, transparency = baseTransparency},
		{grow = math.floor(spread * 1.35), y = 3, transparency = baseTransparency + 0.05},
	}

	for _, cfg in ipairs(layers) do
		local shadow = Instance.new("Frame")
		shadow.Name = "BlurShadow"
		shadow.AnchorPoint = Vector2.new(0.5, 0.5)
		shadow.Position = UDim2.new(0.5, 0, 0.5, cfg.y)
		shadow.Size = UDim2.new(1, cfg.grow, 1, cfg.grow)
		shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		shadow.BackgroundTransparency = math.clamp(cfg.transparency, 0, 1)
		shadow.BorderSizePixel = 0
		shadow.ZIndex = 0
		shadow.Parent = parent
		Instance.new("UICorner", shadow).CornerRadius = UDim.new(0, cornerRadius + math.floor(cfg.grow / 3))
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
	frame.Position = UDim2.new(0.5, -140, 0.5, -85)
	frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	frame.BorderSizePixel = 0
	frame.Parent = selectorGui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 16)

	addBlurShadow(frame, 16, 12, 0.86)

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(18, 18, 18)
	stroke.Transparency = 0.18
	stroke.Parent = frame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -20, 0, 28)
	title.Position = UDim2.new(0, 10, 0, 10)
	title.BackgroundTransparency = 1
	title.Text = "Choose Version"
	title.TextColor3 = Color3.fromRGB(255,255,255)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 22
	title.Parent = frame

	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.new(1, -20, 0, 16)
	sub.Position = UDim2.new(0, 10, 0, 38)
	sub.BackgroundTransparency = 1
	sub.Text = "Best WH ever, netzwi panel"
	sub.TextColor3 = Color3.fromRGB(95,95,95)
	sub.Font = Enum.Font.Gotham
	sub.TextSize = 12
	sub.Parent = frame

	local pcButton = Instance.new("TextButton")
	pcButton.Size = UDim2.new(1, -20, 0, 42)
	pcButton.Position = UDim2.new(0, 10, 0, 68)
	pcButton.BackgroundColor3 = Color3.fromRGB(5, 5, 5)
	pcButton.Text = "PC Version"
	pcButton.TextColor3 = Color3.fromRGB(255,255,255)
	pcButton.Font = Enum.Font.GothamBold
	pcButton.TextSize = 17
	pcButton.Parent = frame
	Instance.new("UICorner", pcButton).CornerRadius = UDim.new(0, 12)

	local mobileButton = Instance.new("TextButton")
	mobileButton.Size = UDim2.new(1, -20, 0, 42)
	mobileButton.Position = UDim2.new(0, 10, 0, 116)
	mobileButton.BackgroundColor3 = Color3.fromRGB(5, 5, 5)
	mobileButton.Text = "Mobile Version"
	mobileButton.TextColor3 = Color3.fromRGB(255,255,255)
	mobileButton.Font = Enum.Font.GothamBold
	mobileButton.TextSize = 17
	mobileButton.Parent = frame
	Instance.new("UICorner", mobileButton).CornerRadius = UDim.new(0, 12)

	pcButton.MouseButton1Click:Connect(function()
		selectorGui:Destroy()
		onPick("PC")
	end)

	mobileButton.MouseButton1Click:Connect(function()
		selectorGui:Destroy()
		onPick("Mobile")
	end)
end

local function buildPCGui()
	ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "FtFWallhopGuiPC"
	ScreenGui.ResetOnSpawn = false
	ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ScreenGui.Parent = PlayerGui

	MainFrame = Instance.new("Frame")
	MainFrame.Name = "MainFrame"
	MainFrame.Size = UDim2.new(0, 270, 0, 210)
	MainFrame.Position = UDim2.new(0.5, -135, 0.5, -105)
	MainFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	MainFrame.BorderSizePixel = 0
	MainFrame.Parent = ScreenGui
	Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 16)

	addBlurShadow(MainFrame, 16, 12, 0.86)

	local Stroke = Instance.new("UIStroke")
	Stroke.Color = Color3.fromRGB(20, 20, 20)
	Stroke.Thickness = 1
	Stroke.Transparency = 0.2
	Stroke.Parent = MainFrame

	local TopBar = Instance.new("Frame")
	TopBar.Name = "TopBar"
	TopBar.Size = UDim2.new(1, 0, 0, 46)
	TopBar.BackgroundTransparency = 1
	TopBar.Parent = MainFrame

	local Title = Instance.new("TextLabel")
	Title.Size = UDim2.new(1, -44, 0, 24)
	Title.Position = UDim2.new(0, 14, 0, 8)
	Title.BackgroundTransparency = 1
	Title.Text = "FtF Wallhop"
	Title.TextColor3 = Color3.fromRGB(255, 255, 255)
	Title.Font = Enum.Font.GothamBold
	Title.TextSize = 21
	Title.TextXAlignment = Enum.TextXAlignment.Left
	Title.Parent = TopBar

	local SubTitle = Instance.new("TextLabel")
	SubTitle.Size = UDim2.new(1, -44, 0, 14)
	SubTitle.Position = UDim2.new(0, 14, 0, 28)
	SubTitle.BackgroundTransparency = 1
	SubTitle.Text = "PC Version"
	SubTitle.TextColor3 = Color3.fromRGB(110, 110, 110)
	SubTitle.Font = Enum.Font.Gotham
	SubTitle.TextSize = 11
	SubTitle.TextXAlignment = Enum.TextXAlignment.Left
	SubTitle.Parent = TopBar

	local MinimizeButton = Instance.new("TextButton")
	MinimizeButton.Size = UDim2.new(0, 24, 0, 24)
	MinimizeButton.Position = UDim2.new(1, -31, 0, 9)
	MinimizeButton.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
	MinimizeButton.Text = "—"
	MinimizeButton.TextColor3 = Color3.fromRGB(225, 225, 225)
	MinimizeButton.Font = Enum.Font.GothamBold
	MinimizeButton.TextSize = 15
	MinimizeButton.Parent = TopBar
	Instance.new("UICorner", MinimizeButton).CornerRadius = UDim.new(1, 0)

	local ContentFrame = Instance.new("Frame")
	ContentFrame.Name = "ContentFrame"
	ContentFrame.Size = UDim2.new(1, -20, 1, -58)
	ContentFrame.Position = UDim2.new(0, 10, 0, 48)
	ContentFrame.BackgroundTransparency = 1
	ContentFrame.Parent = MainFrame

	local ToggleButton = Instance.new("TextButton")
	ToggleButton.Size = UDim2.new(1, 0, 0, 44)
	ToggleButton.Position = UDim2.new(0, 0, 0, 0)
	ToggleButton.BackgroundColor3 = Color3.fromRGB(4, 4, 4)
	ToggleButton.Text = "Wall Hop Off"
	ToggleButton.TextColor3 = Color3.fromRGB(255,255,255)
	ToggleButton.Font = Enum.Font.GothamBold
	ToggleButton.TextSize = 22
	ToggleButton.Parent = ContentFrame
	Instance.new("UICorner", ToggleButton).CornerRadius = UDim.new(0, 12)

	local HideGuiBindButton = Instance.new("TextButton")
	HideGuiBindButton.Size = UDim2.new(1, 0, 0, 36)
	HideGuiBindButton.Position = UDim2.new(0, 0, 0, 58)
	HideGuiBindButton.BackgroundColor3 = Color3.fromRGB(4, 4, 4)
	HideGuiBindButton.Text = "Hide GUI Key: RightShift"
	HideGuiBindButton.TextColor3 = Color3.fromRGB(225,225,225)
	HideGuiBindButton.Font = Enum.Font.Gotham
	HideGuiBindButton.TextSize = 14
	HideGuiBindButton.Parent = ContentFrame
	Instance.new("UICorner", HideGuiBindButton).CornerRadius = UDim.new(0, 11)

	local ToggleBindButton = Instance.new("TextButton")
	ToggleBindButton.Size = UDim2.new(1, 0, 0, 36)
	ToggleBindButton.Position = UDim2.new(0, 0, 0, 101)
	ToggleBindButton.BackgroundColor3 = Color3.fromRGB(4, 4, 4)
	ToggleBindButton.Text = "Toggle Script Key: Q"
	ToggleBindButton.TextColor3 = Color3.fromRGB(225,225,225)
	ToggleBindButton.Font = Enum.Font.Gotham
	ToggleBindButton.TextSize = 14
	ToggleBindButton.Parent = ContentFrame
	Instance.new("UICorner", ToggleBindButton).CornerRadius = UDim.new(0, 11)

	local BottomLabel = Instance.new("TextLabel")
	BottomLabel.Size = UDim2.new(1, -4, 0, 16)
	BottomLabel.Position = UDim2.new(0, 2, 1, -18)
	BottomLabel.BackgroundTransparency = 1
	BottomLabel.Text = "the best ftf wallhop ever - netzwi panel"
	BottomLabel.TextColor3 = Color3.fromRGB(85, 85, 85)
	BottomLabel.Font = Enum.Font.Gotham
	BottomLabel.TextSize = 10
	BottomLabel.TextXAlignment = Enum.TextXAlignment.Left
	BottomLabel.Parent = ContentFrame

	MiniButton = Instance.new("TextButton")
	MiniButton.Name = "MiniButton"
	MiniButton.Size = UDim2.new(0, 140, 0, 40)
	MiniButton.Position = UDim2.new(0.5, -70, 0.5, -20)
	MiniButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	MiniButton.Visible = false
	MiniButton.Text = "FtF Wallhop"
	MiniButton.TextColor3 = Color3.fromRGB(255,255,255)
	MiniButton.Font = Enum.Font.GothamBold
	MiniButton.TextSize = 14
	MiniButton.Parent = ScreenGui
	Instance.new("UICorner", MiniButton).CornerRadius = UDim.new(1, 0)

	addBlurShadow(MiniButton, 999, 10, 0.86)

	MinimizeButton.MouseButton1Click:Connect(function()
		MainFrame.Visible = false
		MiniButton.Visible = true
		MiniButton.Position = MainFrame.Position
	end)

	MiniButton.MouseButton1Click:Connect(function()
		MainFrame.Position = MiniButton.Position
		MainFrame.Visible = true
		MiniButton.Visible = false
	end)
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
	MobileButton.Text = "Wall Hop Off"
	MobileButton.TextColor3 = Color3.fromRGB(255,255,255)
	MobileButton.Font = Enum.Font.GothamBold
	MobileButton.TextScaled = true
	MobileButton.Parent = ScreenGui
	Instance.new("UICorner", MobileButton).CornerRadius = UDim.new(0, 12)

	addBlurShadow(MobileButton, 14, 10, 0.86)

	MobileHideButton = Instance.new("TextButton")
	MobileHideButton.Size = UDim2.new(0, 54, 0, 54)
	MobileHideButton.Position = UDim2.new(0, 20, 0, 180)
	MobileHideButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	MobileHideButton.Text = "≡"
	MobileHideButton.TextColor3 = Color3.fromRGB(255,255,255)
	MobileHideButton.Font = Enum.Font.GothamBold
	MobileHideButton.TextSize = 22
	MobileHideButton.Parent = ScreenGui
	Instance.new("UICorner", MobileHideButton).CornerRadius = UDim.new(1, 0)

	addBlurShadow(MobileHideButton, 999, 10, 0.86)

	RunService.RenderStepped:Connect(function()
		if selectedMode ~= "Mobile" then return end
		local inset = GuiService:GetGuiInset()
		if not MobileButton:GetAttribute("CustomMoved") then
			MobileButton.Position = UDim2.new(0, 150, 0, inset.Y - 58)
		end
	end)

	local drag = {
		target = nil,
		input = nil,
		startInputPos = nil,
		startTargetPos = nil,
		holdReady = false,
		holdStamp = 0,
		moved = false,
		clickAllowed = false,
	}

	local function resetDrag()
		drag.target = nil
		drag.input = nil
		drag.startInputPos = nil
		drag.startTargetPos = nil
		drag.holdReady = false
		drag.holdStamp = 0
		drag.moved = false
		drag.clickAllowed = false
	end

	local function prepareHold(target, input, needHold)
		drag.target = target
		drag.input = input
		drag.startInputPos = input.Position
		drag.startTargetPos = target.Position
		drag.moved = false
		drag.clickAllowed = true

		if needHold then
			drag.holdReady = false
			drag.holdStamp = tick()
			local stamp = drag.holdStamp
			task.spawn(function()
				task.wait(0.5)
				if drag.target == target and drag.input == input and drag.holdStamp == stamp then
					drag.holdReady = true
				end
			end)
		else
			drag.holdReady = true
			drag.holdStamp = tick()
		end
	end

	local function beginTracking(target, needHold)
		target.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				prepareHold(target, input, needHold)

				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						if drag.target == target and not drag.moved and target == MobileHideButton then
							MobileButton.Visible = not MobileButton.Visible
						end
						resetDrag()
					end
				end)
			end
		end)
	end

	beginTracking(MobileButton, true)
	beginTracking(MobileHideButton, false)

	UserInputService.InputChanged:Connect(function(input)
		if selectedMode ~= "Mobile" then return end
		if not drag.target or not drag.input then return end
		if input ~= drag.input then return end
		if not drag.holdReady then return end

		local delta = input.Position - drag.startInputPos

		drag.target.Position = UDim2.new(
			drag.startTargetPos.X.Scale,
			drag.startTargetPos.X.Offset + delta.X,
			drag.startTargetPos.Y.Scale,
			drag.startTargetPos.Y.Offset + delta.Y
		)

		drag.moved = true

		if drag.target == MobileButton then
			MobileButton:SetAttribute("CustomMoved", true)
		end
	end)
end

createModeSelector(function(mode)
	selectedMode = mode

	if mode == "PC" then
		buildPCGui()
	else
		buildMobileGui()
	end
end)
