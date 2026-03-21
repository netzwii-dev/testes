-- LocalScript dentro de um ScreenGui
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer

-- criar ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FTFDance2ButtonGui"
screenGui.Parent = player:WaitForChild("PlayerGui")

-- botão moderno
local button = Instance.new("TextButton")
button.Size = UDim2.new(0, 70, 0, 70)
button.Position = UDim2.new(0.9, 0, 0.85, 0)
button.AnchorPoint = Vector2.new(0.5, 0.5)
button.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
button.BorderSizePixel = 0
button.AutoButtonColor = false

-- sombra
local shadow = Instance.new("UIStroke")
shadow.Color = Color3.fromRGB(255, 255, 255)
shadow.Thickness = 2
shadow.Transparency = 0.7
shadow.Parent = button

-- borda arredondada
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0.5, 0)
corner.Parent = button

-- ícone moderno
local icon = Instance.new("ImageLabel")
icon.Size = UDim2.new(0.6, 0, 0.6, 0)
icon.Position = UDim2.new(0.2, 0, 0.2, 0)
icon.BackgroundTransparency = 1
icon.Image = "rbxassetid://6031094678" -- ícone genérico
icon.ImageColor3 = Color3.fromRGB(255,255,255)
icon.Parent = button

button.Parent = screenGui

-- arrastar
local dragging = false
local dragStart
local startPos
local holdTime = 1

button.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or 
       input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragStart = input.Position
        startPos = button.Position
        local held = true

        task.spawn(function()
            task.wait(holdTime)
            if held then
                dragging = true
            end
        end)

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                if dragging then
                    dragging = false
                else
                    -- clique curto: abrir chat com comando
                    StarterGui:SetCore("ChatMakeSystemMessage", {
                        Text = ""; -- opcional
                    })
                    -- abrir chat
                    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
                    -- inserir comando no chat
                    task.wait(0.1)
                    game:GetService("VirtualInputManager"):SendText("/e dance2")
                    game:GetService("VirtualInputManager"):SendKeyPress(Enum.KeyCode.Return, true, false, true)
                end
                held = false
            end
        end)
    end
end)

button.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or 
       input.UserInputType == Enum.UserInputType.MouseMovement then
        input.Changed:Connect(function()
            if dragging and input.UserInputState == Enum.UserInputState.Change then
                local delta = input.Position - dragStart
                button.Position = UDim2.new(
                    0,
                    math.clamp(startPos.X.Offset + delta.X, 0, workspace.CurrentCamera.ViewportSize.X - button.AbsoluteSize.X),
                    0,
                    math.clamp(startPos.Y.Offset + delta.Y, 0, workspace.CurrentCamera.ViewportSize.Y - button.AbsoluteSize.Y)
                )
            end
        end)
    end
end)
