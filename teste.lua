-- LocalScript dentro de um ScreenGui
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

-- Função para detectar RemoteEvent de emote automaticamente
local function findEmoteRemote(root)
    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("RemoteEvent") and obj.Name:lower():find("emote") then
            return obj
        end
    end
    return nil
end

local emoteRemote = findEmoteRemote(ReplicatedStorage)

if not emoteRemote then
    warn("Não foi possível localizar RemoteEvent de emote. Dance2 não funcionará.")
end

-- Função que dispara a dança uma vez
local function sendDance2()
    if emoteRemote then
        pcall(function()
            emoteRemote:FireServer("dance2")
        end)
    else
        warn("RemoteEvent de emote não encontrado.")
    end
end

-- Conectar clique do botão
button.MouseButton1Click:Connect(sendDance2)
