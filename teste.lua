-- LocalScript dentro de um ScreenGui
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local UserInputService = game:GetService("UserInputService")

-- Criando a GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DanceButtonGui"
screenGui.Parent = playerGui

-- Criando o botão circular
local button = Instance.new("TextButton")
button.Size = UDim2.new(0, 50, 0, 50)
button.Position = UDim2.new(0.9, 0, 0.8, 0)
button.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
button.Text = "D"
button.TextScaled = true
button.Font = Enum.Font.SourceSansBold
button.BorderSizePixel = 0
button.TextColor3 = Color3.fromRGB(255,255,255)
button.AnchorPoint = Vector2.new(0.5, 0.5)

local uicorner = Instance.new("UICorner")
uicorner.CornerRadius = UDim.new(0.5, 0)
uicorner.Parent = button

button.Parent = screenGui

-- Variáveis de arrastar
local dragging = false
local dragInput, mousePos, framePos
local holdTime = 1 -- tempo para poder arrastar
local holdStart

-- Função de atualizar posição
local function update(input)
    local delta = input.Position - mousePos
    button.Position = UDim2.new(
        0,
        math.clamp(framePos.X + delta.X, 0, workspace.CurrentCamera.ViewportSize.X - button.AbsoluteSize.X),
        0,
        math.clamp(framePos.Y + delta.Y, 0, workspace.CurrentCamera.ViewportSize.Y - button.AbsoluteSize.Y)
    )
end

-- Detecta clique/arraste
button.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        holdStart = tick()
        mousePos = input.Position
        framePos = Vector2.new(button.Position.X.Offset, button.Position.Y.Offset)
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                if dragging then
                    dragging = false
                else
                    local held = tick() - holdStart
                    if held < holdTime then
                        -- Clique curto: executa a dança
                        local character = player.Character
                        if character then
                            local humanoid = character:FindFirstChildOfClass("Humanoid")
                            if humanoid then
                                local anim = Instance.new("Animation")
                                anim.AnimationId = "rbxassetid://507766666" -- dance2 AnimationId
                                local track = humanoid:LoadAnimation(anim)
                                track:Play()
                            end
                        end
                    end
                end
            end
        end)
    end
end)

button.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        update(input)
    end
end)

-- Verifica se segurou tempo suficiente para arrastar
button.MouseButton1Down:Connect(function()
    task.spawn(function()
        task.wait(holdTime)
        if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
            dragging = true
        end
    end)
end)
