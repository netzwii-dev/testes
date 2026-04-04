-- AUTO WALLHOP (ULTRA CLEAN COM FLICK HUMANIZADO + OVERSHOOT)

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

-- INPUT BUFFER
local lastJumpRequestTime = 0
local JUMP_REQUEST_BUFFER = 0.18
local jumpConsumedForWallhop = false

local function isCrouching(hum, hrp)
    if not hum or not hrp then return false end
    local horizontalSpeed = Vector3.new(hrp.Velocity.X, 0, hrp.Velocity.Z).Magnitude
    return hum.WalkSpeed <= 9 and horizontalSpeed < 8
end

local function setupCharacter(char)
    local hum = char:WaitForChild("Humanoid")

    hum.StateChanged:Connect(function(_, new)
        if new == Enum.HumanoidStateType.Landed then
            jumpConsumedForWallhop = false
        end
    end)
end

if LocalPlayer.Character then
    setupCharacter(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(setupCharacter)

-- REGISTRA INPUT REAL DE PULO
UserInputService.JumpRequest:Connect(function()
    lastJumpRequestTime = tick()
    jumpConsumedForWallhop = false
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
    jumpConsumedForWallhop = true

    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChild("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then
        isFlicking = false
        return
    end

    local baseYaw = hrp.Orientation.Y
    local angle = pickNextFlick()

    -- 95% flick atual / 5% flick rápido
    local useFastFlick = math.random() < 0.05

    local steps
    local delayMin
    local delayMax

    if useFastFlick then
        steps = math.random(4,5)
        delayMin = 0.0045
        delayMax = 0.0065
    else
        steps = math.random(7,9)
        delayMin = 0.008
        delayMax = 0.012
    end

    local baseDelay = 0.01

    -- OVERSHOOT CONFIG
    local overshoot = math.rad(math.random(20,30))
    local useOvershoot = math.random() < 0.9

    -- deixa o jogo ver um jump real
    hum.Jump = true

    -- espera 1 frame antes do impulso
    RunService.RenderStepped:Wait()

    -- impulso vertical usando AssemblyLinearVelocity
    local currentVel = hrp.AssemblyLinearVelocity
    hrp.AssemblyLinearVelocity = Vector3.new(
        currentVel.X,
        math.max(currentVel.Y, 44.8),
        currentVel.Z
    )

    -- FLICK
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

    -- OVERSHOOT ATRASADO
    if useOvershoot then
        task.delay(0.05, function()
            if not hrp or not hrp.Parent then return end

            local smallSteps = 4

            for i = 1, smallSteps do
                local alpha = i / smallSteps
                local offset = -overshoot * alpha
                hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, math.rad(baseYaw) + offset, 0)
                RunService.RenderStepped:Wait()
                task.wait(baseDelay)
            end

            for i = 1, smallSteps do
                local alpha = i / smallSteps
                local offset = -overshoot * (1 - alpha)
                hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, math.rad(baseYaw) + offset, 0)
                RunService.RenderStepped:Wait()
                task.wait(baseDelay)
            end

            hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, math.rad(baseYaw), 0)
        end)
    end

    hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, math.rad(baseYaw), 0)

    task.delay(0.15, function()
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
    local result = nil

    local offsets = {Vector3.new(0,-2.2,0), Vector3.new(0,-1.2,0), Vector3.new(0,-0.4,0)}
    for _, offset in ipairs(offsets) do
        local origin = hrp.Position + offset
        local ray = workspace:Raycast(origin, direction, params)
        if ray and ray.Instance and ray.Instance.CanCollide and not isPlayerCharacter(ray.Instance) then
            if hasValidHorizontalEdge(ray, params) then
                result = ray
                break
            end
        end
    end

    local hasRecentJumpInput = (tick() - lastJumpRequestTime) <= JUMP_REQUEST_BUFFER

    if result and result.Instance then
        if lastHitInstance and lastHitInstance ~= result.Instance then
            if hrp.Velocity.Y < -2.2
                and tick() - lastFlickTime > WALLHOP_COOLDOWN
                and hasRecentJumpInput
                and not jumpConsumedForWallhop then

                lastFlickTime = tick()
                performVideoFlick()
            end
        end
        lastHitInstance = result.Instance
    else
        lastHitInstance = nil
    end

    if not hasRecentJumpInput and not isWallHopping then
        jumpConsumedForWallhop = false
    end
end)

-- TOGGLE
TextButton.MouseButton1Click:Connect(function()
    isWallHopEnabled = not isWallHopEnabled
    TextButton.Text = isWallHopEnabled and "Wall Hop On" or "Wall Hop Off"
    TextButton.BackgroundColor3 = isWallHopEnabled and Color3.fromRGB(40,40,40) or Color3.fromRGB(0,0,0)
end)

print("WallHop Loaded (wallhop atrelado a JumpRequest recente)")
