-- (Wallhop Humanoid Type - Made by NT)
-- Simple button version

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

-- kill previous gui / previous session
local SCRIPT_VERSION = "external-slow-v3-fix-highwalls"

_G.__NWT_WALLHOP_SESSION = (_G.__NWT_WALLHOP_SESSION or 0) + 1
local THIS_SESSION = _G.__NWT_WALLHOP_SESSION

local oldGui = PlayerGui:FindFirstChild("AutoWallHopGui")
if oldGui then
	oldGui:Destroy()
end

local function sessionAlive()
	return _G.__NWT_WALLHOP_SESSION == THIS_SESSION
end

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

local SlowButton = Instance.new("TextButton")
SlowButton.Size = UDim2.new(0, 140, 0, 50)
SlowButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
SlowButton.Text = "Slow Off"
SlowButton.TextColor3 = Color3.fromRGB(255,255,255)
SlowButton.Font = Enum.Font.GothamBold
SlowButton.TextScaled = true
SlowButton.Parent = ScreenGui
Instance.new("UICorner", SlowButton).CornerRadius = UDim.new(0, 12)

RunService.RenderStepped:Connect(function()
	if not sessionAlive() or not ScreenGui.Parent then
		return
	end

	local inset = GuiService:GetGuiInset()
	TextButton.Position = UDim2.new(0, 150, 0, inset.Y - 58)
	SlowButton.Position = UDim2.new(0, 150, 0, inset.Y - 2)
end)

-- STATES
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
local MIN_HIT_DISTANCE = 0.08
local lastFlickAngle = nil

local airborneSource = nil
local airborneStartY = nil
local airborneStartTime = 0
local jumpedRecently = false

local LEDGE_BLOCK_DISTANCE = 6.0
local LEDGE_BLOCK_TIME = 0.20

-- slow manual
local SLOW_DURATION = 0.8
local SLOW_WALKSPEED = 9
local DEFAULT_WALKSPEED = 16
local slowToken = 0
local scriptSlowActive = false

local function isExternalSlow(hum, hrp)
	if not hum or not hrp then
		return false
	end

	if scriptSlowActive then
		return false
	end

	local horizontalSpeed = Vector3.new(hrp.Velocity.X, 0, hrp.Velocity.Z).Magnitude
	return hum.WalkSpeed <= 9 and horizontalSpeed < 8
end

local function clearScriptSlowInstant()
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
		if not sessionAlive() then
			return
		end

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

local function setupCharacter(char)
	if not sessionAlive() then
		return
	end

	local hum = char:WaitForChild("Humanoid")
	local hrp = char:WaitForChild("HumanoidRootPart")

	slowToken = 0
	scriptSlowActive = false

	hum.StateChanged:Connect(function(_, new)
		if not sessionAlive() then
			return
		end

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
		end
	end)
end

if LocalPlayer.Character then
	setupCharacter(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(setupCharacter)

UserInputService.JumpRequest:Connect(function()
	if not sessionAlive() then
		return
	end

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

	if isExternalSlow(hum, hrp) then
		return
	end

	if canDoubleJump and tick() - lastDoubleJump > DOUBLE_JUMP_COOLDOWN then
		lastDoubleJump = tick()
		canDoubleJump = false

		hrp.Velocity = Vector3.new(hrp.Velocity.X, 30, hrp.Velocity.Z)
		hum:ChangeState(Enum.HumanoidStateType.Jumping)

		task.delay(0.18, function()
			if not sessionAlive() then
				return
			end

			if hum and hum.Parent then
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

local function getFlickProfile()
	local flickRoll = math.random()

	if flickRoll < 0.10 then
		return {
			steps = math.random(4, 5),
			delayMin = 0.0048,
			delayMax = 0.0062,
			overshootMin = 18,
			overshootMax = 24,
			baseDelay = 0.0105
		}
	elseif flickRoll < 0.40 then
		return {
			steps = math.random(5, 6),
			delayMin = 0.0055,
			delayMax = 0.0078,
			overshootMin = 18,
			overshootMax = 27,
			baseDelay = 0.0105
		}
	else
		return {
			steps = math.random(7, 10),
			delayMin = 0.008,
			delayMax = 0.0125,
			overshootMin = 20,
			overshootMax = 32,
			baseDelay = 0.01
		}
	end
end

local function performVideoFlick()
	if not sessionAlive() then
		return
	end

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

	if isExternalSlow(hum, hrp) then
		isWallHopping = false
		blockDoubleJump = false
		isFlicking = false
		return
	end

	hum:ChangeState(Enum.HumanoidStateType.Jumping)

	local baseYaw = hrp.Orientation.Y
	local angle = -pickNextFlick()

	local profile = getFlickProfile()
	local steps = profile.steps
	local delayMin = profile.delayMin
	local delayMax = profile.delayMax
	local baseDelay = profile.baseDelay
	local overshoot = math.rad(math.random(profile.overshootMin, profile.overshootMax))
	local useOvershoot = math.random() < 0.9

	for i = 1, steps do
		if not sessionAlive() then
			return
		end

		if isExternalSlow(hum, hrp) then
			hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, math.rad(baseYaw), 0)
			isWallHopping = false
			blockDoubleJump = false
			isFlicking = false
			return
		end

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
			if not sessionAlive() then
				return
			end

			if not hrp or not hrp.Parent then
				return
			end

			if not char or not char.Parent or isExternalSlow(hum, hrp) then
				hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, math.rad(baseYaw), 0)
				return
			end

			local smallSteps = 4

			for i = 1, smallSteps do
				if not sessionAlive() then
					return
				end

				if not char or not char.Parent or isExternalSlow(hum, hrp) then
					hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, math.rad(baseYaw), 0)
					return
				end

				local alpha = i / smallSteps
				local offset = overshoot * alpha
				hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, math.rad(baseYaw) + offset, 0)
				RunService.RenderStepped:Wait()
				task.wait(baseDelay)
			end

			for i = 1, smallSteps do
				if not sessionAlive() then
					return
				end

				if not char or not char.Parent or isExternalSlow(hum, hrp) then
					hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, math.rad(baseYaw), 0)
					return
				end

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

	if isSlowEnabled then
		applyWallhopSlow(hum)
	end

	task.delay(0.05, function()
		if sessionAlive() then
			blockDoubleJump = false
		end
	end)

	task.delay(0.15, function()
		if sessionAlive() then
			isWallHopping = false
		end
	end)

	isFlicking = false
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

local function hasSupportBelowEdge(rayResult, params)
	if not rayResult or not rayResult.Instance then
		return false
	end

	local hitPos = rayResult.Position
	local normal = rayResult.Normal.Unit
	local wall = rayResult.Instance

	local tangent = normal:Cross(Vector3.new(0, 1, 0))
	if tangent.Magnitude < 0.001 then
		tangent = Vector3.new(1, 0, 0)
	else
		tangent = tangent.Unit
	end

	local checkCenter = hitPos - Vector3.new(0, 0.65, 0) - normal * 0.18
	local checkSize = Vector3.new(0.8, 0.9, 0.7)

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = {LocalPlayer.Character}

	local parts = workspace:GetPartBoundsInBox(CFrame.new(checkCenter), checkSize, overlapParams)

	for _, part in ipairs(parts) do
		if part and part.CanCollide and part ~= wall and not isPlayerCharacter(part) and part.Transparency < 1 then
			return true
		end
	end

	local sameWallHits = 0

	for _, sx in ipairs({-0.22, 0, 0.22}) do
		for _, y in ipairs({-0.28, -0.48, -0.72}) do
			local origin = hitPos + tangent * sx + Vector3.new(0, y, 0) + normal * 0.38
			local probe = workspace:Raycast(origin, -normal * 1.0, params)
			if probe and probe.Instance == wall then
				sameWallHits += 1
			end
		end
	end

	return sameWallHits >= 2
end

local function hasValidHorizontalEdge(rayResult, params)
	if not rayResult or not rayResult.Instance then
		return false
	end

	local hitPos = rayResult.Position
	local normal = rayResult.Normal.Unit
	local wall = rayResult.Instance

	local tangent = normal:Cross(Vector3.new(0, 1, 0))
	if tangent.Magnitude < 0.001 then
		tangent = Vector3.new(1, 0, 0)
	else
		tangent = tangent.Unit
	end

	local function faceExistsAt(y)
		local hits = 0
		for _, sx in ipairs({-0.2, 0, 0.2}) do
			local origin = hitPos + Vector3.new(0, y, 0) + tangent * sx + normal * 0.4
			local probe = workspace:Raycast(origin, -normal * 1.0, params)
			if probe and probe.Instance == wall then
				hits += 1
			end
		end
		return hits
	end

	local aboveNear = faceExistsAt(0.18)
	local aboveFar = faceExistsAt(0.34)
	local belowNear = faceExistsAt(-0.18)
	local belowFar = faceExistsAt(-0.42)

	local hasAbove = (aboveNear + aboveFar) >= 2
	local hasBelow = (belowNear + belowFar) >= 1

	if not hasAbove or not hasBelow then
		return false
	end

	if aboveNear == belowNear and aboveFar == belowFar then
		return false
	end

	if not hasSupportBelowEdge(rayResult, params) then
		return false
	end

	return true
end

local function findValidWall(hrp, params, directions)
	local offsets = {
		Vector3.new(0, -2.45, 0),
		Vector3.new(0, -2.3, 0),
		Vector3.new(0, -2.15, 0),
		Vector3.new(0, -2.0, 0),
		Vector3.new(0, -1.8, 0),
		Vector3.new(0, -1.55, 0),
		Vector3.new(0, -1.3, 0),
		Vector3.new(0, -1.05, 0)
	}

	for _, dir in ipairs(directions) do
		for _, offset in ipairs(offsets) do
			local origin = hrp.Position + offset
			local ray = workspace:Raycast(origin, dir, params)

			if ray
				and ray.Instance
				and ray.Instance.CanCollide
				and not isPlayerCharacter(ray.Instance)
				and isWallLikeSurface(ray.Normal)
				and hasValidHorizontalEdge(ray, params)
			then
				return ray
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
	if not sessionAlive() then
		return
	end

	if not isWallHopEnabled then
		return
	end

	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChild("Humanoid")

	if not hrp or not hum then
		return
	end

	if isExternalSlow(hum, hrp) then
		lastHitPosition = nil
		return
	end

	local state = hum:GetState()
	local airborne = state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping

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
		local validAngle = isWithinWallhopAngle(Camera.CFrame.LookVector, result.Normal, 25)

		if validAngle then
			local farEnough = true
			if lastHitPosition then
				farEnough = (result.Position - lastHitPosition).Magnitude >= MIN_HIT_DISTANCE
			end

			if hrp.Velocity.Y < -0.15 and tick() - lastFlickTime > WALLHOP_COOLDOWN and farEnough then
				if isExternalSlow(hum, hrp) then
					lastHitPosition = nil
					return
				end

				lastFlickTime = tick()
				lastHitPosition = result.Position
				performVideoFlick()
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

TextButton.MouseButton1Click:Connect(function()
	if not sessionAlive() then
		return
	end

	isWallHopEnabled = not isWallHopEnabled
	TextButton.Text = isWallHopEnabled and "Wall Hop On" or "Wall Hop Off"
end)

SlowButton.MouseButton1Click:Connect(function()
	if not sessionAlive() then
		return
	end

	isSlowEnabled = not isSlowEnabled
	SlowButton.Text = isSlowEnabled and "Slow On" or "Slow Off"

	if not isSlowEnabled then
		clearScriptSlowInstant()
	end
end)

print("Made by netzwiiiiiiii | Humanoid Wallhop - Loaded Successfully ✅ | "..SCRIPT_VERSION)
