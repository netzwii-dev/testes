-- LocalScript dentro de um ScreenGui
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

-- Criar GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "Dance2Button"
screenGui.Parent = player:WaitForChild("PlayerGui")

-- Botão circular simples
local button = Instance.new("TextButton")
button.Size = UDim2.new(0, 60, 0, 60)
button.Position = UDim2.new(0.9, 0, 0.85, 0)
button.AnchorPoint = Vector2.new(0.5, 0.5)
button.BackgroundColor3 = Color3.fromRGB(0,0,0)
button.BorderColor3 = Color3.fromRGB(255,255,255)
button.BorderSizePixel = 2
button.Text = "D"
button.TextColor3 = Color3.fromRGB(255,255,255)
button.TextScaled = true
button.Font = Enum.Font.GothamBold

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0.5,0)
corner.Parent = button

button.Parent = screenGui

-- Função para enviar o comando de dança
local function sendDance2()
    local chatEvent = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
    if chatEvent and chatEvent:FindFirstChild("SayMessageRequest") then
        chatEvent.SayMessageRequest:FireServer("/e dance2","All")
    else
        warn("Evento de chat não encontrado, dance2 não foi enviado.")
    end
end

-- Conectar clique
button.MouseButton1Click:Connect(sendDance2)
