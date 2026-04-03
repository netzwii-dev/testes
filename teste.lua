-- AUTO WALLHOP + DOUBLE JUMP (FLICK CORRIGIDO DE VERDADE)

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- UI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AutoWallHopGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = PlayerGui

local TextButton = Instance.new("TextButton")
TextButton.Size = UDim2.new(0, 140, 0, 50)
TextButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
TextButton.Text = "Wall Hop Off"
TextButton.TextColor3 = Color3.fromRGB(255,255,255)
TextButton.Font = Enum.Font.GothamBold
TextButton.TextScaled = true
TextButton.Parent = ScreenGui
Instance.new("UICorner", TextButton).CornerRadius = UDim.new(0, 12)

RunService.RenderStepped:Connect(function()
	local inset = GuiService:GetGuiInset()
	TextButton.Position = UDim2.new(0, 150, 0, inset.Y - 58)
end)

local ToggleUI = Instance.new("TextButton")
ToggleUI.Size = UDim2.new(0, 50, 0, 50)
ToggleUI.Position = UDim2.new(0, 20, 0, 200)
ToggleUI.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
ToggleUI.Text = "≡"
ToggleUI.TextScaled = true
ToggleUI.TextColor3 = Color3.fromRGB(255,255,255)
ToggleUI.Font = Enum.Font.GothamBold
ToggleUI.Parent = ScreenGui
Instance.new("UICorner", ToggleUI).CornerRadius = UDim.new(1, 0)

-- DRAG
local dragging = false
local dragInput, dragStart, startPos

local function update(input)
	local delta = input.Position - dragStart
	ToggleUI.Position = UDim2.new(
		startPos.X.Scale,
		startPos.X.Offset + delta.X,
		startPos.Y.Scale,
		startPos.Y.Offset + delta.Y
	)
end

ToggleUI.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragStart = input.Position
		startPos = ToggleUI.Position

		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)
	end
end)

ToggleUI.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
		dragInput = input
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input == dragInput and dragging then
		update(input)
	end
end)

local uiVisible = true
ToggleUI.MouseButton1Click:Connect(function()
	uiVisible = not uiVisible
	TextButton.Visible = uiVisible
end)

-- STATES
local isWallHopEnabled = false
local isFlicking = false
local lastFlickTime = 0
local Camera = workspace.CurrentCamera

local isWallHopping = false
local lastWallHopTime = 0
local WALLHOP_GRACE_TIME = 1.5

local canDoubleJump = false
local lastDoubleJump = 0
local DOUBLE_JUMP_COOLDOWN = 3

-- CROUCH CHECK
local function isCrouching(hum, hrp)
	if not hum or not hrp then return false end
	local horizontalSpeed = Vector3.new(hrp.Velocity.X, 0, hrp.Velocity.Z).Magnitude
	return hum.WalkSpeed <= 9 and horizontalSpeed < 8
end

-- CHARACTER
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

-- DOUBLE JUMP
UserInputService.JumpRequest:Connect(function()
	if not isWallHopEnabled then return end

	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChild("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp then return end

	local stillValid = isWallHopping or (tick() - lastWallHopTime <= WALLHOP_GRACE_TIME)
	if not stillValid then return end

	if canDoubleJump and tick() - lastDoubleJump > DOUBLE_JUMP_COOLDOWN then
		lastDoubleJump = tick()
		canDoubleJump = false

		hrp.Velocity = Vector3.new(hrp.Velocity.X, 34.5, hrp.Velocity.Z)
		hum:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end)

-- FLICK CORRIGIDO (SEM IR PRO CENTRO)
local function performVideoFlick()
	if isFlicking then return end
	isFlicking = true

	isWallHopping = true
	lastWallHopTime = tick()

	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChild("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp then
		isFlicking = false
		return
	end

	hum:ChangeState(Enum.HumanoidStateType.Jumping)
	hrp.Velocity = Vector3.new(hrp.Velocity.X, 44.8, hrp.Velocity.Z)

	local start = Camera.CFrame

	local direction = 1
	local angle = math.rad(math.random(42, 60))

	-- 🔥 mantém pitch original (SEM lookVector)
	local target = start * CFrame.Angles(0, angle * direction, 0)

	local durationIn = math.random(90, 120) / 1000
	local durationOut = math.random(60, 90) / 1000

	-- ida
	local t0 = tick()
	while true do
		local t = (tick() - t0) / durationIn
		if t >= 1 then break end

		local alpha = t * 0.75 + (t^2) * 0.25
		Camera.CFrame = start:Lerp(target, alpha)

		RunService.RenderStepped:Wait()
	end

	Camera.CFrame = target

	task.wait(math.random(6, 12)/1000)

	-- retorno controlado
	local rand = math.random()
	local offset = 0

	if rand <= 0.4 then
		offset = 0
	elseif rand <= 0.7 then
		offset = math.rad(1)
	else
		offset = math.rad(-1)
	end

	local finalCF = start * CFrame.Angles(0, offset, 0)

	-- volta
	local t1 = tick()
	while true do
		local t = (tick() - t1) / durationOut
		if t >= 1 then break end

		local alpha = t * 0.85 + (t^2) * 0.15
		Camera.CFrame = target:Lerp(finalCF, alpha)

		RunService.RenderStepped:Wait()
	end

	Camera.CFrame = finalCF

	task.delay(0.25, function()
		isWallHopping = false
	end)

	isFlicking = false
end

-- WALL DETECT
local lastHitInstance = nil

local function isPlayerCharacter(instance)
	if not instance then return false end
	local model = instance:FindFirstAncestorOfClass("Model")
	return model and model:FindFirstChildOfClass("Humanoid")
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

	if horizontal.Magnitude > 0 then
		horizontal = horizontal.Unit
	end

	local direction = horizontal * 1.55

	for _, offset in ipairs({
		Vector3.new(0, -2.2, 0),
		Vector3.new(0, -1.2, 0),
		Vector3.new(0, -0.4, 0)
	}) do
		local ray = workspace:Raycast(hrp.Position + offset, direction, params)

		if ray and ray.Instance and ray.Instance.CanCollide then
			if not isPlayerCharacter(ray.Instance) then
				if lastHitInstance and lastHitInstance ~= ray.Instance then
					if hrp.Velocity.Y < -2.2 and tick() - lastFlickTime > 0.085 then
						lastFlickTime = tick()
						performVideoFlick()
					end
				end
				lastHitInstance = ray.Instance
				return
			end
		end
	end

	lastHitInstance = nil
end)

TextButton.MouseButton1Click:Connect(function()
	isWallHopEnabled = not isWallHopEnabled
	TextButton.Text = isWallHopEnabled and "Wall Hop On" or "Wall Hop Off"
end)

print("WallHop Loaded (flick realmente corrigido)")
