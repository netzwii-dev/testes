-- (Wallhop Humanoid Type - Made by NT)
-- PC version with configurable keybinds, hide GUI key, toggle script key, and on-screen notices

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

-- CONFIG
local DEFAULT_HIDE_GUI_KEY = Enum.KeyCode.RightShift
local DEFAULT_TOGGLE_SCRIPT_KEY = Enum.KeyCode.Q

-- STATES
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

local waitingForHideKey = false
local waitingForToggleKey = false

local lastHitInstance = nil
local lastFlickAngle = nil

-- GUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AutoWallHopGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = PlayerGui

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 240, 0, 190)
MainFrame.Position = UDim2.new(0, 150, 0, 40)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 14)

local Stroke = Instance.new("UIStroke")
Stroke.Color = Color3.fromRGB(60, 60, 60)
Stroke.Thickness = 1
Stroke.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -20, 0, 30)
Title.Position = UDim2.new(0, 10, 0, 8)
Title.BackgroundTransparency = 1
Title.Text = "Wallhop PC"
Title.TextColor3 = Color3.fromRGB(255,255,255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 18
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = MainFrame

local ToggleButton = Instance.new("TextButton")
ToggleButton.Size = UDim2.new(1, -20, 0, 42)
ToggleButton.Position = UDim2.new(0, 10, 0, 42)
ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
ToggleButton.Text = "Wall Hop Off"
ToggleButton.TextColor3 = Color3.fromRGB(255,255,255)
ToggleButton.Font = Enum.Font.GothamBold
ToggleButton.TextSize = 16
ToggleButton.Parent = MainFrame
Instance.new("UICorner", ToggleButton).CornerRadius = UDim.new(0, 12)

local HideGuiBindButton = Instance.new("TextButton")
HideGuiBindButton.Size = UDim2.new(1, -20, 0, 34)
HideGuiBindButton.Position = UDim2.new(0, 10, 0, 95)
HideGuiBindButton.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
HideGuiBindButton.Text = "Hide GUI Key: " .. hideGuiKey.Name
HideGuiBindButton.TextColor3 = Color3.fromRGB(220,220,220)
HideGuiBindButton.Font = Enum.Font.Gotham
HideGuiBindButton.TextSize = 14
HideGuiBindButton.Parent = MainFrame
Instance.new("UICorner", HideGuiBindButton).CornerRadius = UDim.new(0, 10)

local ToggleBindButton = Instance.new("TextButton")
ToggleBindButton.Size = UDim2.new(1, -20, 0, 34)
ToggleBindButton.Position = UDim2.new(0, 10, 0, 134)
ToggleBindButton.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
ToggleBindButton.Text = "Toggle Script Key: " .. toggleScriptKey.Name
ToggleBindButton.TextColor3 = Color3.fromRGB(220,220,220)
ToggleBindButton.Font = Enum.Font.Gotham
ToggleBindButton.TextSize = 14
ToggleBindButton.Parent = MainFrame
Instance.new("UICorner", ToggleBindButton).CornerRadius = UDim.new(0, 10)

local InfoLabel = Instance.new("TextLabel")
InfoLabel.Size = UDim2.new(1, -20, 0, 14)
InfoLabel.Position = UDim2.new(0, 10, 1, -20)
InfoLabel.BackgroundTransparency = 1
InfoLabel.Text = "PC keybind system enabled"
InfoLabel.TextColor3 = Color3.fromRGB(140,140,140)
InfoLabel.Font = Enum.Font.Gotham
InfoLabel.TextSize = 11
InfoLabel.TextXAlignment = Enum.TextXAlignment.Left
InfoLabel.Parent = MainFrame

-- notice gui
local NoticeHolder = Instance.new("Frame")
NoticeHolder.Name = "NoticeHolder"
NoticeHolder.AnchorPoint = Vector2.new(0.5, 0)
NoticeHolder.Position = UDim2.new(0.5, 0, 0, 20)
NoticeHolder.Size = UDim2.new(0, 320, 0, 50)
NoticeHolder.BackgroundTransparency = 1
NoticeHolder.Parent = ScreenGui

local Notice = Instance.new("TextLabel")
Notice.Size = UDim2.new(1, 0, 1, 0)
Notice.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
Notice.BackgroundTransparency = 1
Notice.TextTransparency = 1
Notice.Text = ""
Notice.TextColor3 = Color3.fromRGB(255,255,255)
Notice.Font = Enum.Font.GothamBold
Notice.TextSize = 16
Notice.Parent = NoticeHolder
Instance.new("UICorner", Notice).CornerRadius = UDim.new(0, 12)

local NoticeStroke = Instance.new("UIStroke")
NoticeStroke.Color = Color3.fromRGB(70,70,70)
NoticeStroke.Transparency = 1
NoticeStroke.Parent = Notice

local function showNotice(text)
	Notice.Text = text

	local fadeIn1 = TweenService:Create(Notice, TweenInfo.new(0.18), {
		BackgroundTransparency = 0.2,
		TextTransparency = 0
	})
	local fadeIn2 = TweenService:Create(NoticeStroke, TweenInfo.new(0.18), {
		Transparency = 0
	})

	fadeIn1:Play()
	fadeIn2:Play()

	task.spawn(function()
		task.wait(1.4)
		local fadeOut1 = TweenService:Create(Notice, TweenInfo.new(0.25), {
			BackgroundTransparency = 1,
			TextTransparency = 1
		})
		local fadeOut2 = TweenService:Create(NoticeStroke, TweenInfo.new(0.25), {
			Transparency = 1
		})
		fadeOut1:Play()
		fadeOut2:Play()
	end)
end

local function updateToggleButton()
	ToggleButton.Text = isWallHopEnabled and "Wall Hop On" or "Wall Hop Off"
	ToggleButton.BackgroundColor3 = isWallHopEnabled and Color3.fromRGB(40,40,40) or Color3.fromRGB(0,0,0)
end

local function updateBindButtons()
	HideGuiBindButton.Text = waitingForHideKey and "Press any key for Hide GUI..." or ("Hide GUI Key: " .. hideGuiKey.Name)
	ToggleBindButton.Text = waitingForToggleKey and "Press any key for Toggle Script..." or ("Toggle Script Key: " .. toggleScriptKey.Name)
end

local function setGuiVisible(state)
	guiVisible = state
	MainFrame.Visible = state
	if state then
		showNotice("GUI shown")
	else
		showNotice("GUI hidden")
	end
end

RunService.RenderStepped:Connect(function()
	local inset = GuiService:GetGuiInset()
	if guiVisible then
		MainFrame.Position = UDim2.new(0, 150, 0, inset.Y + 10)
	end
end)

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
	if not hum or not hrp then return end

	local stillValid = isWallHopping or (tick() - lastWallHopTime <= WALLHOP_GRACE_TIME)
	if not stillValid then return end

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

local function pickNextFlick()
	local minAngle, maxAngle = 50, 80
	local attempt = 0
	local angle
	repeat
		angle = math.random(minAngle, maxAngle)
		attempt += 1
	until not lastFlickAngle or math.abs(angle - lastFlickAngle) >= 10 or attempt > 20
	lastFlickAngle = angle
	return math.rad(angle)
end

local function performVideoFlick()
	if isFlicking then return end
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
			curve = math.sin((alpha / 0.6) * (math.pi / 2))
		else
			curve = math.sin(((1 - alpha) / 0.4) * (math.pi / 2))
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

ToggleButton.MouseButton1Click:Connect(function()
	isWallHopEnabled = not isWallHopEnabled
	updateToggleButton()
	showNotice(isWallHopEnabled and "Wallhop enabled" or "Wallhop disabled")
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

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

	local key = input.KeyCode
	if key == Enum.KeyCode.Unknown then return end

	if waitingForHideKey then
		if key ~= toggleScriptKey then
			hideGuiKey = key
			waitingForHideKey = false
			updateBindButtons()
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

updateToggleButton()
updateBindButtons()

print("Made by netzwii | Humanoid Wallhop PC - Loaded Successfullyyy ✅")
