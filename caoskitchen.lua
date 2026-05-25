--// LoopSpeed 25 - simples/nativo
--// Sem GUI, sem botão.
--// Mantém WalkSpeed em 25 igual loopspeed.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SPEED = 25
local lp = Players.LocalPlayer

-- remove versão antiga, se tiver
if getgenv then
    if getgenv().CK_LoopSpeed_Conn then
        pcall(function()
            getgenv().CK_LoopSpeed_Conn:Disconnect()
        end)
    end
    getgenv().CK_LoopSpeed_Conn = nil
end

local function setSpeed()
    local char = lp.Character
    if not char then return end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    if hum.WalkSpeed ~= SPEED then
        hum.WalkSpeed = SPEED
    end
end

lp.CharacterAdded:Connect(function()
    task.wait(0.5)
    setSpeed()
end)

local conn = RunService.Heartbeat:Connect(function()
    pcall(setSpeed)
end)

if getgenv then
    getgenv().CK_LoopSpeed_Conn = conn
end

setSpeed()
warn("[LoopSpeed] ativo: " .. tostring(SPEED))
