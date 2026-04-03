-- AUTO WALLHOP + DOUBLE JUMP (FIX REAL DOUBLE TRIGGER)

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
local WALLHOP_COOLDOWN = 0.22

-- DOUBLE JUMP
local canDoubleJump = false
local lastDoubleJump = 0
local DOUBLE_JUMP_COOLDOWN = 3
local blockDoubleJump = false

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

        hrp.Velocity = Vector3.new(hrp.Velocity.X, 34.5, hrp.Velocity.Z)

        task.delay(0.18, function()
            if hum then
                hum:ChangeState(Enum.HumanoidStateType.Freefall)
            end
        end)
    end
end)

-- RANDOM CENTRAL (igual)
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

-- FLICK (igual ao último estável)
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

    if hrp.Velocity.Y < 2 then
        hrp.Velocity = Vector3.new(hrp.Velocity.X, 44.8, hrp.Velocity.Z)
    end

    local oldAutoRotate = hum.AutoRotate
    hum.AutoRotate = false

    hrp.AssemblyAngularVelocity = Vector3.zero

    local ang = pickCentral({2600,2650,2700,2750,2800})
    local flickTime = math.random()*(0.11 - 0.08) + 0.08

    local totalAngle = math.rad(math.clamp(ang / 40, 45, 90))

    local baseCF = hrp.CFrame
    local _, baseYaw, _ = baseCF:ToOrientation()

    local steps = math.max(1, math.floor(flickTime / 0.005))

    for i = 1, steps do
        local alpha = i / steps
        local curve = math.sin(alpha * math.pi)
        local offset = totalAngle * curve

        local pos = hrp.Position
        hrp.CFrame = CFrame.new(pos) * CFrame.Angles(0, baseYaw + offset, 0)

        RunService.RenderStepped:Wait()
    end

    hum.AutoRotate = oldAutoRotate

    task.delay(0.05, function()
        blockDoubleJump = false
    end)

    task.delay(0.25, function()
        isWallHopping = false
    end)

    isFlicking = false
end

-- WALL DETECT (FIX REAL)
local lastHitInstance = nil

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

    local result = workspace:Raycast(hrp.Position, direction, params)

    if result and result.Instance then
        if lastHitInstance ~= result.Instance then
            if hrp.Velocity.Y < -2.2 and tick() - lastFlickTime > WALLHOP_COOLDOWN then
                lastFlickTime = tick()
                lastHitInstance = nil
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

print("WallHop Loaded (double trigger corrigido)")
