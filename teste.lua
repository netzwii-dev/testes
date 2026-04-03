-- AUTO WALLHOP + DOUBLE JUMP (COM FLICK ADICIONADO)

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

-- NOVO (janela após wallhop)
local lastWallHopTime = 0
local WALLHOP_GRACE_TIME = 1.5

-- DOUBLE JUMP
local canDoubleJump = false
local lastDoubleJump = 0
local DOUBLE_JUMP_COOLDOWN = 3

-- ADICIONADO DO SCRIPT 2
local blockDoubleJump = false

-- CROUCH CHECK
local function isCrouching(hum, hrp)
    if not hum or not hrp then return false end
    local horizontalSpeed = Vector3.new(hrp.Velocity.X, 0, hrp.Velocity.Z).Magnitude
    return hum.WalkSpeed <= 9 and horizontalSpeed < 8
end

-- CHARACTER HANDLER
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

-- DOUBLE JUMP (mantido igual, só bloqueado durante flick)
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

        hrp.Velocity = Vector3.new(hrp.Velocity.X, 34.5, hrp.Velocity.Z)
        hum:ChangeState(Enum.HumanoidStateType.Jumping)

        task.delay(0.18, function()
            if hum then
                hum:ChangeState(Enum.HumanoidStateType.Freefall)
            end
        end)
    end
end)

-- FUNÇÃO DO SCRIPT 2 (INALTERADA)
local function pickCentral(values)
    local mid = math.ceil(#values/2)
    local total, weights = 0, {}

    for i=1,#values do
        local d = math.abs(i - mid)
        local w = 1/(1 + d^1.3)
        weights[i] = w
        total += w
    end

    local r = math.random() * total
    for i, w in ipairs(weights) do
        r -= w
        if r <= 0 then
            return values[i]
        end
    end

    return values[#values]
end

-- FLICK (AGORA COM O SISTEMA DO SCRIPT 2)
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

    -- impulso original
    hum:ChangeState(Enum.HumanoidStateType.Jumping)
    hrp.Velocity = Vector3.new(hrp.Velocity.X, 44.8, hrp.Velocity.Z)

    local oldAutoRotate = hum.AutoRotate
    hum.AutoRotate = false

    hrp.AssemblyAngularVelocity = Vector3.zero

    local values = {2700,2750,2800,2850,2900,2950,3000}
    local ang = pickCentral(values)

    local totalAngle = math.rad(math.clamp(ang / 40, 45, 90))
    local dir = 1

    local baseCF = hrp.CFrame
    local _, baseYaw, _ = baseCF:ToOrientation()

    local steps = 12

    for i = 1, steps do
        local alpha = i / steps
        local curve = math.sin(alpha * math.pi)
        local offset = totalAngle * curve * dir

        local pos = hrp.Position
        hrp.CFrame = CFrame.new(pos) * CFrame.Angles(0, baseYaw + offset, 0)

        RunService.RenderStepped:Wait()
    end

    hum.AutoRotate = oldAutoRotate

    task.delay(0.05, function()
        blockDoubleJump = false
    end)

    task.delay(0.1, function()
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Freefall)
        end
    end)

    task.delay(0.25, function()
        isWallHopping = false
    end)

    isFlicking = false
end

-- WALL DETECT (INALTERADO)
local lastHitInstance = nil

local function isPlayerCharacter(instance)
    if not instance then return false end
    local model = instance:FindFirstAncestorOfClass("Model")
    if model and model:FindFirstChildOfClass("Humanoid") then
        return true
    end
    return false
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

    local offsets = {
        Vector3.new(0, -2.2, 0),
        Vector3.new(0, -1.2, 0),
        Vector3.new(0, -0.4, 0)
    }

    for _, offset in ipairs(offsets) do
        local origin = hrp.Position + offset
        local ray = workspace:Raycast(origin, direction, params)

        if ray and ray.Instance and ray.Instance.CanCollide then
            if not isPlayerCharacter(ray.Instance) then
                result = ray
                break
            end
        end
    end

    if result and result.Instance then
        if lastHitInstance and lastHitInstance ~= result.Instance then
            if hrp.Velocity.Y < -2.2 and tick() - lastFlickTime > 0.085 then
                lastFlickTime = tick()
                performVideoFlick()
            end
        end
        lastHitInstance = result.Instance
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

print("WallHop Loaded (com flick integrado)")
