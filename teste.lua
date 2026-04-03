-- FLICK HUMANIZADO COM OVERSHOOT REAL (SEM EMPURRÃO)
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

    -- impulso original (não mexe)
    hrp.Velocity = Vector3.new(hrp.Velocity.X, 44.8, hrp.Velocity.Z)
    hum:ChangeState(Enum.HumanoidStateType.Jumping)

    local baseYaw = hrp.Orientation.Y
    local angle = pickNextFlick()

    local steps = math.random(7,9)
    local delay = 0.01

    -- overshoot real (20°–30°)
    local overshoot = math.rad(math.random(20,30))
    local useOvershoot = math.random() < 0.9

    -- =========================
    -- 1. IDA
    -- =========================
    for i = 1, steps do
        local alpha = i / steps
        local curve = math.sin(alpha * (math.pi/2)) -- só ida

        local offset = angle * curve
        hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, math.rad(baseYaw) + offset, 0)

        RunService.RenderStepped:Wait()
        task.wait(delay)
    end

    -- =========================
    -- 2. VOLTA NORMAL
    -- =========================
    for i = 1, steps do
        local alpha = i / steps
        local curve = math.cos(alpha * (math.pi/2)) -- volta

        local offset = angle * curve
        hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, math.rad(baseYaw) + offset, 0)

        RunService.RenderStepped:Wait()
        task.wait(delay)
    end

    -- =========================
    -- 3. OVERSHOOT + CORREÇÃO
    -- =========================
    if useOvershoot then
        local smallSteps = 4

        -- passa do centro
        for i = 1, smallSteps do
            local alpha = i / smallSteps
            local offset = -overshoot * alpha

            hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, math.rad(baseYaw) + offset, 0)

            RunService.RenderStepped:Wait()
            task.wait(delay)
        end

        -- volta pro centro
        for i = 1, smallSteps do
            local alpha = i / smallSteps
            local offset = -overshoot * (1 - alpha)

            hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, math.rad(baseYaw) + offset, 0)

            RunService.RenderStepped:Wait()
            task.wait(delay)
        end
    end

    -- reset final garantido
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
