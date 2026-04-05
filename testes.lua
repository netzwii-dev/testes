local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "FtFWallhopGuiPreview"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 270, 0, 210)
MainFrame.Position = UDim2.new(0.5, -135, 0.5, -105)
MainFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 16)

local Shadow1 = Instance.new("Frame")
Shadow1.Name = "Shadow1"
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
Shadow2.Name = "Shadow2"
Shadow2.AnchorPoint = Vector2.new(0.5, 0.5)
Shadow2.Position = UDim2.new(0.5, 0, 0.5, 5)
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

local ToggleStroke = Instance.new("UIStroke")
ToggleStroke.Color = Color3.fromRGB(20, 20, 20)
ToggleStroke.Transparency = 0.1
ToggleStroke.Parent = ToggleButton

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

local HideStroke = Instance.new("UIStroke")
HideStroke.Color = Color3.fromRGB(20, 20, 20)
HideStroke.Transparency = 0.1
HideStroke.Parent = HideGuiBindButton

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

local MiniButton = Instance.new("TextButton")
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

local Notice = Instance.new("TextLabel")
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

local NoticeStroke = Instance.new("UIStroke")
NoticeStroke.Color = Color3.fromRGB(22, 22, 22)
NoticeStroke.Transparency = 1
NoticeStroke.Parent = Notice

local activeNoticeId = 0
local function showNotice(text)
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

local guiVisible = true
local guiMinimized = false

local function applyVisibility()
	MainFrame.Visible = guiVisible and not guiMinimized
	MiniButton.Visible = guiVisible and guiMinimized
end

local function setMinimized(state)
	guiMinimized = state
	applyVisibility()

	if state then
		MiniButton.Position = MainFrame.Position
		showNotice("GUI minimized")
	else
		MainFrame.Position = MiniButton.Position
		showNotice("GUI restored")
	end
end

MinimizeButton.MouseButton1Click:Connect(function()
	setMinimized(true)
end)

MiniButton.MouseButton1Click:Connect(function()
	setMinimized(false)
end)

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
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		updateDrag(input)
	end
end)

showNotice("GUI loaded")
