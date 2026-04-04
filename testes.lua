-- (Wallhop Humanoid Type - Made by NT)

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

-- STATES
local isWallHopEnabled = false
local isFlicking = false
local lastFlickTime = 0
local Camera = workspace.CurrentCamera

local isWallHopping = false
local lastWallHopTime = 0
local WALLHOP_GRACE_TIME = 1.5
local WALLHOP_COOLDOWN = 0.18

-- DOUBLE JUMP
local canDoubleJump = false
local lastDoubleJump = 0
local DOUBLE_JUMP_COOLDOWN = 3
local blockDoubleJump = false

-- GEM READY TRACKER (SÓ DO DOUBLE JUMP DO SCRIPT)
local gemReadyEffect = nil
local gemReadyTweening = false
local gemReadyPart = nil
local gemRechargeCycle = 0

local function isCrouching(hum, hrp)
    if not hum or not hrp then return false end
    local horizontalSpeed = Vector3.new(hrp.Velocity.X, 0, hrp.Velocity.Z).Magnitude
    return hum.WalkSpeed <= 9 and horizontalSpeed < 8
end

local function getGemPart(char)
    return char:FindFirstChild("RightHand")
        or char:FindFirstChild("RightLowerArm")
        or char:FindFirstChild("RightUpperArm")
        or char:FindFirstChild("Right Arm")
        or char:FindFirstChild("UpperTorso")
        or char:FindFirstChild("HumanoidRootPart")
end

local function createGemReadyEffect(char)
    local old = char:FindFirstChild("GemReadyEffect", true)
    if old then
        old:Destroy()
    end

    gemReadyPart = getGemPart(char)
    if not gemReadyPart then return nil end

    local holder = Instance.new("BillboardGui")
    holder.Name = "GemReadyEffect"
    holder.Size = UDim2.new(0, 95, 0, 95)
    holder.StudsOffset = Vector3.new(1.48, 0.28, 0)
    holder.AlwaysOnTop = true
    holder.LightInfluence = 0
    holder.MaxDistance = 200
    holder.Enabled = false
    holder.Adornee = gemReadyPart
    holder.Parent = char

    local glow = Instance.new("ImageLabel")
    glow.Name = "Glow"
    glow.BackgroundTransparency = 1
    glow.AnchorPoint = Vector2.new(0.5, 0.5)
    glow.Position = UDim2.new(0.5, 0, 0.5, 0)
    glow.Size = UDim2.new(0.62, 0, 0.62, 0)
    glow.Image = "rbxassetid://241594314"
    glow.ImageTransparency = 1
    glow.ScaleType = Enum.ScaleType.Fit
    glow.ZIndex = 10
    glow.Parent = holder

    return holder
end

local function playGemRechargeAnimation()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChild("Humanoid")
    if not hum then return end

    local originalOffset = hum.CameraOffset

    for i = 1, 5 do
        local a = i / 5
        hum.CameraOffset = originalOffset + Vector3.new(0.03 * a, 0.015 * a, 0)
        RunService.RenderStepped:Wait()
    end

    for i = 1, 7 do
        local a = i / 7
        hum.CameraOffset = originalOffset + Vector3.new(0.03 * (1 - a), 0.015 * (1 - a), 0)
        RunService.RenderStepped:Wait()
    end

    hum.CameraOffset = originalOffset
end

local function playGemReadyEffect()
    if gemReadyTweening then return end

    local char = LocalPlayer.Character
    if not char then return end

    if not gemReadyEffect or not gemReadyEffect.Parent then
        gemReadyEffect = createGemReadyEffect(char)
    end
    if not gemReadyEffect then return end

    if not gemReadyPart or not gemReadyPart.Parent then
        gemReadyPart = getGemPart(char)
        if not gemReadyPart then return end
        gemReadyEffect.Adornee = gemReadyPart
    end

    local glow = gemReadyEffect:FindFirstChild("Glow")
    if not glow then return end

    gemReadyTweening = true
    gemReadyEffect.Enabled = true
    gemReadyEffect.Adornee = gemReadyPart

    glow.ImageTransparency = 1
    glow.Size = UDim2.new(0.62, 0, 0.62, 0)
    glow.Position = UDim2.new(0.5, 0, 0.5, 0)

    for i = 1, 8 do
        local alpha = i / 8
        glow.ImageTransparency = 1 - (0.88 * alpha)
        local size = 0.62 + 0.58 * alpha
        glow.Size = UDim2.new(size, 0, size, 0)
        glow.Position = UDim2.new(0.5, 0, 0.5, 0)
        RunService.RenderStepped:Wait()
    end

    task.wait(0.08)

    for i = 1, 10 do
        local alpha = i / 10
        glow.ImageTransparency = 0.12 + (0.88 * alpha)
        local size = 1.2 + 0.5 * alpha
        glow.Size = UDim2.new(size, 0, size, 0)
        glow.Position = UDim2.new(0.5, 0, 0.5, 0)
        RunService.RenderStepped:Wait()
    end

    gemReadyEffect.Enabled = false
    gemReadyTweening = false
end

local function setupCharacter(char)
    local hum = char:WaitForChild("Humanoid")

    gemRechargeCycle = 0
    gemReadyTweening = false

    task.defer(function()
        gemReadyEffect = createGemReadyEffect(char)
    end)

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

        -- agenda APENAS a recarga visual do DOUBLE JUMP DO SCRIPT
        gemRechargeCycle += 1
        local myCycle = gemRechargeCycle

        task.delay(DOUBLE_JUMP_COOLDOWN, function()
            if myCycle ~= gemRechargeCycle then return end
            if not LocalPlayer.Character then return end

            task.spawn(playGemReadyEffect)
            task.spawn(playGemRechargeAnimation)
        end)

        hrp.Velocity = Vector3.new(hrp.Velocity.X, 30, hrp.Velocity.Z)
        hum:ChangeState(Enum.HumanoidStateType.Jumping)

        task.delay(0.18, function()
            if hum then
                hum:ChangeState(Enum.HumanoidStateType.Freefall)
            end
        end)
    end
end)

-- LAST FLICK ANGLE
local lastFlickAngle = nil
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

-- FLICK HUMANIZADO (ORIGINAL + OVERSHOOT ATRASADO)
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

    task.delay(0.05, function() blockDoubleJump = false end)
    task.delay(0.15, function() isWallHopping = false end)

    isFlicking = false
end

-- WALL DETECT
local lastHitInstance = nil
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

-- TOGGLE
TextButton.MouseButton1Click:Connect(function()
    isWallHopEnabled = not isWallHopEnabled
    TextButton.Text = isWallHopEnabled and "Wall Hop On" or "Wall Hop Off"
    TextButton.BackgroundColor3 = isWallHopEnabled and Color3.fromRGB(40,40,40) or Color3.fromRGB(0,0,0)
end)

print("Humanoid Wallhop cu - Loaded Successfully ✅")
