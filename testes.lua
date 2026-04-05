-- (Wallhop Humanoid Type - Made by NT)
-- Dual loader: choose PC GUI or Mobile GUI, same wallhop logic

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

-- CONFIG
local DEFAULT_HIDE_GUI_KEY = Enum.KeyCode.RightShift
local DEFAULT_TOGGLE_SCRIPT_KEY = Enum.KeyCode.Q
local SETTINGS_FILE = "netzwii_wallhop_pc_settings.json"

-- STATES
local selectedMode = nil -- "PC" or "Mobile"

local isWallHopEnabled = false
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

local hideGuiKey = DEFAULT_HIDE_GUI_KEY
local toggleScriptKey = DEFAULT_TOGGLE_SCRIPT_KEY
local guiVisible = true
local guiMinimized = false

local waitingForHideKey = false
local waitingForToggleKey = false

local lastHitInstance = nil
local lastFlickAngle = nil

-- GUI REFS
local ScreenGui
local MainFrame
local MiniButton
local ToggleButton
local HideGuiBindButton
local ToggleBindButton
local Notice
local NoticeStroke
local MobileButton

-- SETTINGS
local function safeKeyCodeFromName(name, fallback)
	if typeof(name) ~= "string" then
		return fallback
	end

	local ok, result = pcall(function()
		return Enum.KeyCode[name]
	end)

	if ok and result then
		return result
	end

	return fallback
end

local function saveSettings()
	if not writefile or not isfile then
		return
	end

	local data = {
		hideGuiKey = hideGuiKey.Name,
		toggleScriptKey = toggleScriptKey.Name,
	}

	pcall(function()
		writefile(SETTINGS_FILE, HttpService:JSONEncode(data))
	end)
end

local function loadSettings()
	if not readfile or not isfile then
		return
	end

	if not isfile(SETTINGS_FILE) then
		return
	end

	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(readfile(SETTINGS_FILE))
	end)

	if ok and decoded then
		hideGuiKey = safeKeyCodeFromName(decoded.hideGuiKey, DEFAULT_HIDE_GUI_KEY)
		toggleScriptKey = safeKeyCodeFromName(decoded.toggleScriptKey, DEFAULT_TOGGLE_SCRIPT_KEY)
	end
end

loadSettings()

local activeNoticeId = 0
local function showNotice(text)
	if selectedMode ~= "PC" or not Notice or not NoticeStroke then
		return
	end

	activeNoticeId += 1
	local noticeId = activeNoticeId

	Notice.Text = text
	Notice.Position = UDim2.new(1, 230, 0, 0)
	Notice.TextTransparency = 1
	Notice.BackgroundTransparency = 0.12
	NoticeStroke.Transparency = 1

	TweenService:Create(Notice, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(1, 0, 0, 0),
		TextTransparency = 0
	}):Play()

	TweenService:Create(NoticeStroke, TweenInfo.new(0.14), {
		Transparency = 0.15
	}):Play()

	task.spawn(function()
		task.wait(1)
		if noticeId ~= activeNoticeId then
			return
		end

		TweenService:Create(Notice, TweenInfo.new(0.26, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(1, 240, 0, 0),
			TextTransparency = 1,
			BackgroundTransparency = 1
		}):Play()

		TweenService:Create(NoticeStroke, TweenInfo.new(0.2), {
			Transparency = 1
		}):Play()
	end)
end

local function updateToggleButton()
	if selectedMode == "PC" and ToggleButton then
		ToggleButton.Text = isWallHopEnabled and "Wall Hop On" or "Wall Hop Off"
		ToggleButton.BackgroundColor3 = isWallHopEnabled and Color3.fromRGB(10, 18, 10) or Color3.fromRGB(4, 4, 4)
		if MiniButton then
			MiniButton.Text = isWallHopEnabled and "FtF Wallhop • ON" or "FtF Wallhop"
		end
	elseif selectedMode == "Mobile" and MobileButton then
		MobileButton.Text = isWallHopEnabled and "Wall Hop On" or "Wall Hop Off"
		MobileButton.BackgroundColor3 = isWallHopEnabled and Color3.fromRGB(40,40,40) or Color3.fromRGB(0,0,0)
	end
end

local function updateBindButtons()
	if selectedMode ~= "PC" then
		return
	end

	if HideGuiBindButton then
		HideGuiBindButton.Text = waitingForHideKey and "Press any key for Hide GUI..." or ("Hide GUI Key: " .. hideGuiKey.Name)
	end
	if ToggleBindButton then
		ToggleBindButton.Text = waitingForToggleKey and "Press any key for Toggle Script..." or ("Toggle Script Key: " .. toggleScriptKey.Name)
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
	end
end

local function setGuiVisible(state)
	guiVisible = state
	applyVisibility()
	showNotice(state and "GUI shown" or "GUI hidden")
end

local function setMinimized(state)
	if selectedMode ~= "PC" then
		return
	end

	guiMinimized = state
	applyVisibility()

	if state then
		if MiniButton and MainFrame then
			MiniButton.Position = MainFrame.Position
		end
		showNotice("GUI minimized")
	else
		if MainFrame and MiniButton then
			MainFrame.Position = MiniButton.Position
		end
		showNotice("GUI restored")
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

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(25, 25, 25)
	stroke.Transparency = 0.15
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
	sub.Text = "same wallhop, different GUI"
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
	MainFrame.Position = UDim2.new(0, 150, 0, 40)
	MainFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	MainFrame.BorderSizePixel = 0
	MainFrame.Parent = ScreenGui
	Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 16)

	local Shadow1 = Instance.new("Frame")
	Shadow1.AnchorPoint = Vector2.new(0.5, 0.5)
	Shadow1.Position = UDim2.new(0.5, 0, 0.5, 3)
	Shadow1.Size = UDim2.new(1, 8, 1, 8)
	Shadow1.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	Shadow1.BackgroundTransparency = 0.82
	Shadow1.BorderSizePixel = 0
	Shadow1.ZIndex = 0
	Shadow1.Parent = MainFrame
	Instance.new("UICorner", Shadow1).CornerRadius = UDim.new(0, 18)

	local Shadow2 = Instance.new("Frame")
	Shadow2.AnchorPoint = Vector2.new(0.5, 0, 0.5, 5)
	Shadow2.Size = UDim2.new(1, 16, 1, 16)
	Shadow2.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	Shadow2.BackgroundTransparency = 0.9
	Shadow2.BorderSizePixel = 0
	Shadow2.ZIndex = 0
	Shadow2.Parent = MainFrame
	Instance.new("UICorner", Shadow2).CornerRadius = UDim.new(0, 20)

	local Stroke = Instance.new("UIStroke")
	Stroke.Color = Color3.fromRGB(22, 22, 22)
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

	local MinStroke = Instance.new("UIStroke")
	MinStroke.Color = Color3.fromRGB(28, 28, 28)
	MinStroke.Transparency = 0.15
	MinStroke.Parent = MinimizeButton

	local ContentFrame = Instance.new("Frame")
	ContentFrame.Name = "ContentFrame"
	ContentFrame.Size = UDim2.new(1, -20, 1, -58)
	ContentFrame.Position = UDim2.new(0, 10, 0, 48)
	ContentFrame.BackgroundTransparency = 1
	ContentFrame.Parent = MainFrame

	ToggleButton = Instance.new("TextButton")
	ToggleButton.Size = UDim2.new(1, 0, 0, 44)
	ToggleButton.Position = UDim2.new(0, 0, 0, 0)
	ToggleButton.BackgroundColor3 = Color3.fromRGB(4, 4, 4)
	ToggleButton.Text = "Wall Hop Off"
	ToggleButton.TextColor3 = Color3.fromRGB(255,255,255)
	ToggleButton.Font = Enum.Font.GothamBold
	ToggleButton.TextSize = 22
	ToggleButton.Parent = ContentFrame
	Instance.new("UICorner", ToggleButton).CornerRadius = UDim.new(0, 12)

	local ToggleStroke = Instance.new("UIStroke")
	ToggleStroke.Color = Color3.fromRGB(20, 20, 20)
	ToggleStroke.Transparency = 0.1
	ToggleStroke.Parent = ToggleButton

	HideGuiBindButton = Instance.new("TextButton")
	HideGuiBindButton.Size = UDim2.new(1, 0, 0, 36)
	HideGuiBindButton.Position = UDim2.new(0, 0, 0, 58)
	HideGuiBindButton.BackgroundColor3 = Color3.fromRGB(4, 4, 4)
	HideGuiBindButton.TextColor3 = Color3.fromRGB(225,225,225)
	HideGuiBindButton.Font = Enum.Font.Gotham
	HideGuiBindButton.TextSize = 14
	HideGuiBindButton.Parent = ContentFrame
	Instance.new("UICorner", HideGuiBindButton).CornerRadius = UDim.new(0, 11)

	local HideStroke = Instance.new("UIStroke")
	HideStroke.Color = Color3.fromRGB(20, 20, 20)
	HideStroke.Transparency = 0.1
	HideStroke.Parent = HideGuiBindButton

	ToggleBindButton = Instance.new("TextButton")
	ToggleBindButton.Size = UDim2.new(1, 0, 0, 36)
	ToggleBindButton.Position = UDim2.new(0, 0, 0, 101)
	ToggleBindButton.BackgroundColor3 = Color3.fromRGB(4, 4, 4)
	ToggleBindButton.TextColor3 = Color3.fromRGB(225,225,225)
	ToggleBindButton.Font = Enum.Font.Gotham
	ToggleBindButton.TextSize = 14
	ToggleBindButton.Parent = ContentFrame
	Instance.new("UICorner", ToggleBindButton).CornerRadius = UDim.new(0, 11)

	local ToggleBindStroke = Instance.new("UIStroke")
	ToggleBindStroke.Color = Color3.fromRGB(20, 20, 20)
	ToggleBindStroke.Transparency = 0.1
	ToggleBindStroke.Parent = ToggleBindButton

	local BottomLabel = Instance.new("TextLabel")
	BottomLabel.Size = UDim2.new(1, -4, 0, 16)
	BottomLabel.Position = UDim2.new(0, 2, 1, -18)
	BottomLabel.BackgroundTransparency = 1
	BottomLabel.Text = "the best ftf wallhop ever - netzwii painel"
	BottomLabel.TextColor3 = Color3.fromRGB(85, 85, 85)
	BottomLabel.Font = Enum.Font.Gotham
	BottomLabel.TextSize = 10
	BottomLabel.TextXAlignment = Enum.TextXAlignment.Left
	BottomLabel.Parent = ContentFrame

	MiniButton = Instance.new("TextButton")
	MiniButton.Name = "MiniButton"
	MiniButton.Size = UDim2.new(0, 140, 0, 40)
	MiniButton.Position = MainFrame.Position
	MiniButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	MiniButton.Visible = false
	MiniButton.Text = "FtF Wallhop"
	MiniButton.TextColor3 = Color3.fromRGB(255,255,255)
	MiniButton.Font = Enum.Font.GothamBold
	MiniButton.TextSize = 14
	MiniButton.Parent = ScreenGui
	Instance.new("UICorner", MiniButton).CornerRadius = UDim.new(1, 0)

	local MiniShadow1 = Instance.new("Frame")
	MiniShadow1.AnchorPoint = Vector2.new(0.5, 0.5)
	MiniShadow1.Position = UDim2.new(0.5, 0, 0.5, 2)
	MiniShadow1.Size = UDim2.new(1, 8, 1, 8)
	MiniShadow1.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	MiniShadow1.BackgroundTransparency = 0.84
	MiniShadow1.BorderSizePixel = 0
	MiniShadow1.ZIndex = 0
	MiniShadow1.Parent = MiniButton
	Instance.new("UICorner", MiniShadow1).CornerRadius = UDim.new(1, 0)

	local MiniShadow2 = Instance.new("Frame")
	MiniShadow2.AnchorPoint = Vector2.new(0.5, 0.5)
	MiniShadow2.Position = UDim2.new(0.5, 0, 0.5, 3)
	MiniShadow2.Size = UDim2.new(1, 14, 1, 14)
	MiniShadow2.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	MiniShadow2.BackgroundTransparency = 0.92
	MiniShadow2.BorderSizePixel = 0
	MiniShadow2.ZIndex = 0
	MiniShadow2.Parent = MiniButton
	Instance.new("UICorner", MiniShadow2).CornerRadius = UDim.new(1, 0)

	local MiniStroke = Instance.new("UIStroke")
	MiniStroke.Color = Color3.fromRGB(22, 22, 22)
	MiniStroke.Transparency = 0.12
	MiniStroke.Parent = MiniButton

	local NoticeHolder = Instance.new("Frame")
	NoticeHolder.Name = "NoticeHolder"
	NoticeHolder.AnchorPoint = Vector2.new(1, 0)
	NoticeHolder.Position = UDim2.new(1, -12, 0, 6)
	NoticeHolder.Size = UDim2.new(0, 210, 0, 30)
	NoticeHolder.BackgroundTransparency = 1
	NoticeHolder.Parent = ScreenGui

	Notice = Instance.new("TextLabel")
	Notice.AnchorPoint = Vector2.new(1, 0)
	Notice.Position = UDim2.new(1, 230, 0, 0)
	Notice.Size = UDim2.new(0, 200, 0, 28)
	Notice.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	Notice.BackgroundTransparency = 0.12
	Notice.TextTransparency = 1
	Notice.Text = ""
	Notice.TextColor3 = Color3.fromRGB(255,255,255)
	Notice.Font = Enum.Font.GothamBold
	Notice.TextSize = 11
	Notice.TextXAlignment = Enum.TextXAlignment.Center
	Notice.Parent = NoticeHolder
	Instance.new("UICorner", Notice).CornerRadius = UDim.new(1, 0)

	NoticeStroke = Instance.new("UIStroke")
	NoticeStroke.Color = Color3.fromRGB(22, 22, 22)
	NoticeStroke.Transparency = 1
	NoticeStroke.Parent = Notice

	local dragging = false
	local dragStart
	local startPos
	local dragTarget = MainFrame

	local function beginDrag(input, target)
		dragging = true
		dragTarget = target
		dragStart = input.Position
		startPos = target.Position
	end

	local function updateDrag(input)
		if not dragging or not dragTarget then
			return
		end

		local delta = input.Position - dragStart
		dragTarget.Position = UDim2.new(
			startPos.X.Scale,
			startPos.X.Offset + delta.X,
			startPos.Y.Scale,
			startPos.Y.Offset + delta.Y
		)
	end

	local function bindDrag(handle, target)
		handle.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				beginDrag(input, target)
				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						dragging = false
					end
				end)
			end
		end)
	end

	bindDrag(TopBar, MainFrame)
	bindDrag(MiniButton, MiniButton)

	UserInputService.InputChanged:Connect(function(input)
		if selectedMode == "PC" and input.UserInputType == Enum.UserInputType.MouseMovement then
			updateDrag(input)
		end
	end)

	RunService.RenderStepped:Connect(function()
		if selectedMode ~= "PC" then return end

		local inset = GuiService:GetGuiInset()

		if guiVisible and not dragging then
			if not guiMinimized and MainFrame.Position == UDim2.new(0, 150, 0, 40) then
				MainFrame.Position = UDim2.new(0, 150, 0, inset.Y + 10)
			end
			if guiMinimized and MiniButton.Position == UDim2.new(0, 150, 0, 40) then
				MiniButton.Position = UDim2.new(0, 150, 0, inset.Y + 10)
			end
		end
	end)

	ToggleButton.MouseButton1Click:Connect(function()
		isWallHopEnabled = not isWallHopEnabled
		updateToggleButton()
		showNotice(isWallHopEnabled and "Wallhop enabled" or "Wallhop disabled")
	end)

	MinimizeButton.MouseButton1Click:Connect(function()
		setMinimized(true)
	end)

	MiniButton.MouseButton1Click:Connect(function()
		setMinimized(false)
	end)

	HideGuiBindButton.MouseButton1Click:Connect(function()
		waitingForHideKey = true
		waitingForToggleKey = false
		updateBindButtons()
		showNotice("Press a key for Hide GUI")
	end)

	ToggleBindButton.MouseButton1Click:Connect(function()
		waitingForToggleKey = true
		waitingForHideKey = false
		updateBindButtons()
		showNotice("Press a key for Toggle Script")
	end)
end

local function buildMobileGui()
	ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "AutoWallHopGuiMobile"
	ScreenGui.ResetOnSpawn = false
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

	RunService.RenderStepped:Connect(function()
		if selectedMode ~= "Mobile" then return end
		local inset = GuiService:GetGuiInset()
		MobileButton.Position = UDim2.new(0, 150, 0, inset.Y - 58)
	end)

	MobileButton.MouseButton1Click:Connect(function()
		isWallHopEnabled = not isWallHopEnabled
		updateToggleButton()
	end)
end

local function isCrouching(hum, hrp)
	if not hum or not hrp then return false end
	local horizontalSpeed = Vector3.new(hrp.Velocity.X, 0, hrp.Velocity.Z).Magnitude
	return hum.WalkSpeed <= 9 and horizontalSpeed < 8
end

local function setupCharacter(char)
	local hum = char:WaitForChild("Humanoid")
	hum.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Freefall then
			canDoubleJump = true
		end
		if new == Enum.HumanoidStateType.Landed then
			canDoubleJump = false
		end
	end)
end

if LocalPlayer.Character then
	setupCharacter(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(setupCharacter)

UserInputService.JumpRequest:Connect(function()
	if not isWallHopEnabled or blockDoubleJump then return end

	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChild("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp then
		isFlicking = false
		return
	end

	hrp.Velocity = Vector3.new(hrp.Velocity.X, 44.8, hrp.Velocity.Z)
	hum:ChangeState(Enum.HumanoidStateType.Jumping)

	local baseYaw = hrp.Orientation.Y
	local angle = -pickNextFlick()

	local flickRoll = math.random()
	local steps
	local delayMin
	local delayMax

	if flickRoll < 0.10 then
		steps = math.random(3,4)
		delayMin = 0.003
		delayMax = 0.0045
	elseif flickRoll < 0.40 then
		steps = math.random(4,5)
		delayMin = 0.0045
		delayMax = 0.0065
	else
		steps = math.random(7,9)
		delayMin = 0.008
		delayMax = 0.012
	end

	local baseDelay = 0.01
	local overshoot = math.rad(math.random(20,30))
	local useOvershoot = math.random() < 0.9

	for i = 1, steps do
		local alpha = i / steps
		local curve
		if alpha <= 0.6 then
			curve = math.sin((alpha / 0.6) * (math.pi/2))
		else
			curve = math.sin(((1 - alpha) / 0.4) * (math.pi/2))
		end

		local offset = angle * curve
		hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, math.rad(baseYaw) + offset, 0)

		RunService.RenderStepped:Wait()
		task.wait(delayMin + math.random() * (delayMax - delayMin))
	end

	if useOvershoot then
		task.delay(0.05, function()
			if not hrp or not hrp.Parent then return end

			local smallSteps = 4

			for i = 1, smallSteps do
				local alpha = i / smallSteps
				local offset = overshoot * alpha
				hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, math.rad(baseYaw) + offset, 0)
				RunService.RenderStepped:Wait()
				task.wait(baseDelay)
			end

			for i = 1, smallSteps do
				local alpha = i / smallSteps
				local offset = overshoot * (1 - alpha)
				hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, math.rad(baseYaw) + offset, 0)
				RunService.RenderStepped:Wait()
				task.wait(baseDelay)
			end

			hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, math.rad(baseYaw), 0)
		end)
	end

	hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, math.rad(baseYaw), 0)

	if hum:GetState() ~= Enum.HumanoidStateType.Freefall then
		hum:ChangeState(Enum.HumanoidStateType.Freefall)
	end

	task.delay(0.05, function()
		blockDoubleJump = false
	end)

	task.delay(0.15, function()
		isWallHopping = false
	end)

	isFlicking = false
	end
	local function isPlayerCharacter(instance)
	if not instance then return false end
	local model = instance:FindFirstAncestorOfClass("Model")
	return model and model:FindFirstChildOfClass("Humanoid")
end

local function hasValidHorizontalEdge(rayResult, params)
	if not rayResult or not rayResult.Instance then return false end

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

	if not foundHorizontalEdge then
		return false
	end

	return true
end

local function findValidWall(hrp, params, directions)
	local offsets = {
		Vector3.new(0,-2.2,0),
		Vector3.new(0,-1.2,0),
		Vector3.new(0,-0.4,0)
	}

	for _, dir in ipairs(directions) do
		for _, offset in ipairs(offsets) do
			local origin = hrp.Position + offset
			local ray = workspace:Raycast(origin, dir, params)
			if ray and ray.Instance and ray.Instance.CanCollide and not isPlayerCharacter(ray.Instance) then
				if hasValidHorizontalEdge(ray, params) then
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
	if not selectedMode then return end
	if not isWallHopEnabled then return end

	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChild("Humanoid")

	if not hrp or not hum then return end
	if isCrouching(hum, hrp) then return end

	local params = RaycastParams.new()
	params.FilterDescendantsInstances = {char}
	params.FilterType = Enum.RaycastFilterType.Exclude

	local look = Camera.CFrame.LookVector
	local horizontal = Vector3.new(look.X, 0, look.Z)

	if horizontal.Magnitude <= 0 then
		lastHitInstance = nil
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
		local validAngle = isWithinWallhopAngle(Camera.CFrame.LookVector, result.Normal, 25)

		if validAngle then
			if lastHitInstance and lastHitInstance ~= result.Instance then
				if hrp.Velocity.Y < -2.2 and tick() - lastFlickTime > WALLHOP_COOLDOWN then
					lastFlickTime = tick()
					performVideoFlick()
				end
			end
			lastHitInstance = result.Instance
		else
			lastHitInstance = nil
		end
	else
		lastHitInstance = nil
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if selectedMode ~= "PC" then return end
	if gameProcessed then return end
	if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

	local key = input.KeyCode
	if key == Enum.KeyCode.Unknown then return end

	if waitingForHideKey then
		if key ~= toggleScriptKey then
			hideGuiKey = key
			waitingForHideKey = false
			updateBindButtons()
			saveSettings()
			showNotice("Hide GUI key set to " .. key.Name)
		else
			showNotice("This key is already used by Toggle Script")
		end
		return
	end

	if waitingForToggleKey then
		if key ~= hideGuiKey then
			toggleScriptKey = key
			waitingForToggleKey = false
			updateBindButtons()
			saveSettings()
			showNotice("Toggle Script key set to " .. key.Name)
		else
			showNotice("This key is already used by Hide GUI")
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
end)

createModeSelector(function(mode)
	selectedMode = mode

	if mode == "PC" then
		buildPCGui()
		updateBindButtons()
		showNotice("PC version loaded")
	else
		buildMobileGui()
	end

	updateToggleButton()
	applyVisibility()
end)

print("Made by netzwii | Dual Wallhop Loader - Loaded Successfully ✅")
