-- WALLHOP + DOUBLE JUMP (ANIMATION SYNC VERSION)

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Camera = workspace.CurrentCamera

-- UI (igual)
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local ScreenGui = Instance.new("ScreenGui", PlayerGui)
ScreenGui.ResetOnSpawn = false

local Button = Instance.new("TextButton", ScreenGui)
Button.Size = UDim2.new(0,140,0,50)
Button.BackgroundColor3 = Color3.fromRGB(0,0,0)
Button.TextColor3 = Color3.fromRGB(255,255,255)
Button.Font = Enum.Font.GothamBold
Button.TextScaled = true
Button.Text = "Wall Hop Off"

Instance.new("UICorner", Button).CornerRadius = UDim.new(0,12)

RunService.RenderStepped:Connect(function()
    local inset = GuiService:GetGuiInset()
    Button.Position = UDim2.new(0,150,0,inset.Y - 58)
end)

-- STATES
local enabled = false
local lastFlick = 0
local flicking = false

-- DOUBLE JUMP
local canDouble = false
local lastDouble = 0
local DOUBLE_CD = 3

-- ANIMATION CACHE
local jumpTrack, fallTrack
local animator

local function setupChar(char)
    local hum = char:WaitForChild("Humanoid")
    animator = hum:WaitForChild("Animator")

    -- pega animações já existentes
    for _,track in ipairs(animator:GetPlayingAnimationTracks()) do
        local name = track.Name:lower()
        if name:find("jump") then
            jumpTrack = track
        elseif name:find("fall") then
            fallTrack = track
        end
    end

    hum.StateChanged:Connect(function(_, new)
        if new == Enum.HumanoidStateType.Freefall then
            canDouble = true
        elseif new == Enum.HumanoidStateType.Landed then
            canDouble = false
        end
    end)
end

if LocalPlayer.Character then
    setupChar(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(setupChar)

-- 🔥 PLAY REAL ANIMATION
local function playJumpAnim()
    if jumpTrack then
        jumpTrack:Play(0.05, 1, 1)
    end
end

-- DOUBLE JUMP (ANIMATION SYNC)
UserInputService.JumpRequest:Connect(function()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    if canDouble and tick() - lastDouble > DOUBLE_CD then
        lastDouble = tick()
        canDouble = false

        playJumpAnim()

        -- impulso sincronizado com animação
        task.wait(0.03)
        hrp.Velocity = Vector3.new(hrp.Velocity.X, 44, hrp.Velocity.Z)
    end
end)

-- FLICK
local function flick()
    if flicking then return end
    flicking = true

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        flicking = false
        return
    end

    playJumpAnim()

    -- delay mínimo pra bater com animação real
    task.wait(0.025)

    -- boost calibrado
    hrp.Velocity = Vector3.new(hrp.Velocity.X, 50, hrp.Velocity.Z)

    -- câmera (igual ao seu estilo)
    local start = Camera.CFrame
    local target = start * CFrame.Angles(0, math.rad(45), 0)

    local fast = math.random() < 0.4

    Camera.CFrame = target
    task.wait(fast and 0.012 or 0.018)

    local steps = fast and 4 or 6

    for i = 1, steps do
        local alpha = (i/steps)^(fast and 1.8 or 2.2)
        Camera.CFrame = target:Lerp(start, alpha)
        task.wait(fast and 0.0045 or 0.0065)
    end

    flicking = false
end

-- WALL DETECT
local lastHit = nil

RunService.Heartbeat:Connect(function()
    if not enabled then return end

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {char}
    params.FilterType = Enum.RaycastFilterType.Exclude

    local result = workspace:Raycast(
        hrp.Position,
        Camera.CFrame.LookVector * 3,
        params
    )

    if result and result.Instance and result.Instance.CanCollide then
        if lastHit and lastHit ~= result.Instance then
            if hrp.Velocity.Y < -1 and tick() - lastFlick > 0.07 then
                lastFlick = tick()
                flick()
            end
        end
        lastHit = result.Instance
    else
        lastHit = nil
    end
end)

-- TOGGLE
Button.MouseButton1Click:Connect(function()
    enabled = not enabled
    Button.Text = enabled and "Wall Hop On" or "Wall Hop Off"
    Button.BackgroundColor3 = enabled and Color3.fromRGB(40,40,40) or Color3.fromRGB(0,0,0)
end)

print("Animation Synced WallHop Loaded")
