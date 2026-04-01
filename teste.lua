-- AUTO WALLHOP + DOUBLE JUMP (CORRIGIDO)

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

-- DOUBLE JUMP SYSTEM
local wallHopTime = 0
local REQUIRED_WALLHOP_TIME = 3
local doubleJumpReady = false

-- WALL DETECT
local lastHitInstance = nil
local touchingWall = false

local function isPlayerCharacter(instance)
    if not instance then return false end
    local model = instance:FindFirstAncestorOfClass("Model")
    if model and model:FindFirstChildOfClass("Humanoid") then
        return true
    end
    return false
end

-- CHARACTER HANDLER
local function setupCharacter(char)
    local hum = char:WaitForChild("Humanoid")

    hum.StateChanged:Connect(function(_, new)
        if new == Enum.HumanoidStateType.Landed then
            wallHopTime = 0
            doubleJumpReady = false
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

    local state = hum:GetState()

    -- só permite no ar (corrigido)
    if state ~= Enum.HumanoidStateType.Freefall and state ~= Enum.HumanoidStateType.Jumping then
        return
    end

    if doubleJumpReady then
        doubleJumpReady = false

        hrp.Velocity = Vector3.new(hrp.Velocity.X, 34.5, hrp.Velocity.Z)
        hum:ChangeState(Enum.HumanoidStateType.Jumping)

        task.delay(0.18, function()
            if hum then
                hum:ChangeState(Enum.HumanoidStateType.Freefall)
            end
        end)
    end
end)

-- FLICK
local function performVideoFlick()
    if isFlicking then return end
    isFlicking = true

    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChild("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then
        isFlicking = false
        return
    end

    hum:ChangeState(Enum.HumanoidStateType.Jumping)
    hrp.Velocity = Vector3.new(hrp.Velocity.X, 44.8, hrp.Velocity.Z)

    local startCFrame = Camera.CFrame
    local flickRotation = CFrame.fromAxisAngle(startCFrame.UpVector, math.rad(45))
    local targetCFrame = flickRotation * startCFrame

    Camera.CFrame = targetCFrame
    task.wait(0.015)
    Camera.CFrame = startCFrame

    isFlicking = false
end

-- MAIN LOOP
RunService.Heartbeat:Connect(function(dt)
    if not isWallHopEnabled then return end

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChild("Humanoid")
    if not hrp or not hum then return end

    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {char}
    params.FilterType = Enum.RaycastFilterType.Exclude

    local look = Camera.CFrame.LookVector
    local horizontal = Vector3.new(look.X, 0, look.Z).Unit * 1.55

    local ray = workspace:Raycast(hrp.Position, horizontal, params)

    touchingWall = false

    if ray and ray.Instance and ray.Instance.CanCollide then
        if not isPlayerCharacter(ray.Instance) then
            touchingWall = true
        end
    end

    local state = hum:GetState()

    -- acumula tempo REAL de wallhop
    if touchingWall and (state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping) then
        wallHopTime += dt
        if wallHopTime >= REQUIRED_WALLHOP_TIME then
            doubleJumpReady = true
        end
    end

    -- executa flick
    if touchingWall and hrp.Velocity.Y < -2.2 and tick() - lastFlickTime > 0.085 then
        lastFlickTime = tick()
        performVideoFlick()
    end
end)

-- TOGGLE
TextButton.MouseButton1Click:Connect(function()
    isWallHopEnabled = not isWallHopEnabled
    TextButton.Text = isWallHopEnabled and "Wall Hop On" or "Wall Hop Off"
end)

print("WallHop Loaded (CORRIGIDO DE VERDADE)")
