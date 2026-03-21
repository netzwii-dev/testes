-- LocalScript dentro de um ScreenGui
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer

-- Criar GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "Dance2ButtonGui"
screenGui.Parent = player:WaitForChild("PlayerGui")

-- Botão circular moderno
local button = Instance.new("TextButton")
button.Size = UDim2.new(0,70,0,70)
button.Position = UDim2.new(0.9,0,0.85,0)
button.AnchorPoint = Vector2.new(0.5,0.5)
button.BackgroundColor3 = Color3.fromRGB(0,0,0)
button.BorderColor3 = Color3.fromRGB(255,255,255)
button.BorderSizePixel = 2
button.Text = "D"
button.TextColor3 = Color3.fromRGB(255,255,255)
button.TextScaled = true
button.Font = Enum.Font.GothamBold
button.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0.5,0)
corner.Parent = button

-- Função que dispara /e dance2 via chat
local function sendDance2()
    -- Usa pcall para evitar erros se chat não estiver pronto
    pcall(function()
        -- Envia a mensagem para o canal geral do chat
        StarterGui:SetCore("ChatMakeSystemMessage", {Text = ""}) -- apenas ativa o chat
        game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
        game:GetService("VirtualInputManager"):SendText("/e dance2")
        game:GetService("VirtualInputManager"):SendKeyPress(Enum.KeyCode.Return, true, false, true)
    end)
end

-- Conectar clique do botão
button.MouseButton1Click:Connect(sendDance2)
