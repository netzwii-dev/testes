-- (Wallhop Humanoid Type - Made by NT)
-- Simple button version
-- Refino: edge válida = precisa ter parede ACIMA e EMBAIXO da borda
-- Refino: detecção de beast mais profunda

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

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

local lastHitPosition = nil
local MIN_HIT_DISTANCE = 0.2
local lastFlickAngle = nil

-- queda: distinguir pulo x queda de borda
local airborneSource = nil -- "jump" ou "ledge"
local airborneStartY = nil
local airborneStartTime = 0
local jumpedRecently = false

local LEDGE_BLOCK_DISTANCE = 6.0
local LEDGE_BLOCK_TIME = 0.20

-- cache de beast
local beastCache = false
local lastBeastCheck = 0
local BEAST_CACHE_TIME = 0.6

local function isCrouching(hum, hrp)
	if not hum or not hrp then
		return false
	end

	local horizontalSpeed = Vector3.new(hrp.Velocity.X, 0, hrp.Velocity.Z).Magnitude
	return hum.WalkSpeed <= 9 and horizontalSpeed < 8
end

local function textLooksBeast(text)
	if typeof(text) ~= "string" then
		return false
	end

	text = string.lower(text)

	return string.find(text, "beast", 1, true)
		or string.find(text, "killer", 1, true)
		or string.find(text, "monster", 1, true)
		or string.find(text, "hammer", 1, true)
end

local function scoreBeastFromContainer(container)
	if not container then
		return 0
	end

	local score = 0

	for _, obj in ipairs(container:GetDescendants()) do
		if obj:IsA("Tool") then
			local n = string.lower(obj.Name)
			if string.find(n, "hammer", 1, true) then
				score += 4
			elseif textLooksBeast(n) then
				score += 3
			end
		elseif obj:IsA("StringValue") then
			local n = string.lower(obj.Name)
			local v = string.lower(tostring(obj.Value))

			if textLooksBeast(n) then
				score += 2
			end
			if textLooksBeast(v) then
				score += 3
			end
		elseif obj:IsA("BoolValue") then
			local n = string.lower(obj.Name)
			if obj.Value and (
				textLooksBeast(n)
				or string.find(n, "isbeast", 1, true)
				or string.find(n, "beastmode", 1, true)
			) then
				score += 4
			end
		elseif obj:IsA("IntValue") or obj:IsA("NumberValue") then
			local n = string.lower(obj.Name)
			if textLooksBeast(n) then
				score += 1
			end
		end
	end

	return score
end

local function isLikelyBeast(player, char)
	local now = tick()
	if now - lastBeastCheck <= BEAST_CACHE_TIME then
		return beastCache
	end

	local score = 0

	if player.Team and textLooksBeast(player.Team.Name) then
		score += 5
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		score += scoreBeastFromContainer(backpack)
	end

	if char then
		score += scoreBeastFromContainer(char)

		local equippedTool = char:FindFirstChildOfClass("Tool")
		if equippedTool then
			local toolName = string.lower(equippedTool.Name)
			if string.find(toolName, "hammer", 1, true) then
				score += 5
			elseif textLooksBeast(toolName) then
				score += 3
			end
		end
	end

	local stats = player:FindFirstChild("leaderstats")
	if stats then
		score += scoreBeastFromContainer(stats)
	end

	beastCache = score >= 5
	lastBeastCheck = now

	return beastCache
end

local function setupCharacter(char)
	local hum = char:WaitForChild("Humanoid")
	local hrp = char:WaitForChild("HumanoidRootPart")

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

	-- beast: não usa o double jump do script
	if isLikelyBeast(LocalPlayer, char) then
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
			if not hrp or not hrp.Parent then
				return
			end

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

	task.delay(0.05, function()
		blockDoubleJump = false
	end)

	task.delay(0.15, function()
		isWallHopping = false
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

local function probeIntoSameWall(hitPos, normal, yOffset, params, originalInstance)
	local origin = hitPos + Vector3.new(0, yOffset, 0) + (normal * 0.08)
	local probe = workspace:Raycast(origin, -normal * 0.32, params)

	if not probe or not probe.Instance then
		return false
	end

	if probe.Instance ~= originalInstance then
		return false
	end

	if not probe.Instance.CanCollide then
		return false
	end

	if not isWallLikeSurface(probe.Normal) then
		return false
	end

	return true
end

local function hasOpenCenterEdge(hitPos, normal, params, originalInstance)
	local origin = hitPos + (normal * 0.08)
	local probe = workspace:Raycast(origin, -normal * 0.32, params)

	if not probe or not probe.Instance then
		return true
	end

	if probe.Instance ~= originalInstance then
		return true
	end

	return false
end

local function hasValidHorizontalEdge(rayResult, params)
	if not rayResult or not rayResult.Instance then
		return false
	end

	local hitPos = rayResult.Position
	local normal = rayResult.Normal.Unit
	local wallInstance = rayResult.Instance

	-- precisa existir parede ACIMA e EMBAIXO da borda
	-- isso elimina:
	-- vermelho = só acima
	-- laranja = só abaixo
	local hasAboveNear = probeIntoSameWall(hitPos, normal, 0.75, params, wallInstance)
	local hasBelowNear = probeIntoSameWall(hitPos, normal, -0.75, params, wallInstance)

	if not (hasAboveNear and hasBelowNear) then
		return false
	end

	-- reforço extra para não aceitar falso positivo em transição ruim
	local hasAboveFar = probeIntoSameWall(hitPos, normal, 1.15, params, wallInstance)
	local hasBelowFar = probeIntoSameWall(hitPos, normal, -1.15, params, wallInstance)

	if not ((hasAboveNear or hasAboveFar) and (hasBelowNear or hasBelowFar)) then
		return false
	end

	-- no centro da borda precisa existir descontinuidade local,
	-- senão é só face lisa comum
	local centerOpen = hasOpenCenterEdge(hitPos, normal, params, wallInstance)
	if not centerOpen then
		return false
	end

	return true
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

	local localIsBeast = isLikelyBeast(LocalPlayer, char)

	if isCrouching(hum, hrp) then
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
		local angleLimit = localIsBeast and 22 or 25
		local validAngle = isWithinWallhopAngle(Camera.CFrame.LookVector, result.Normal, angleLimit)

		if validAngle then
			local farEnough = true
			if lastHitPosition then
				farEnough = (result.Position - lastHitPosition).Magnitude >= MIN_HIT_DISTANCE
			end

			local minFallVelocity = localIsBeast and -1.15 or -0.8

			if hrp.Velocity.Y < minFallVelocity and tick() - lastFlickTime > WALLHOP_COOLDOWN and farEnough then
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
	isWallHopEnabled = not isWallHopEnabled
	TextButton.Text = isWallHopEnabled and "Wall Hop On" or "Wall Hop Off"
end)

print("Made by netzwi | Humanoid Wallhop - Loaded Successfully ✅")
