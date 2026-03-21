-- LocalScript inside a ScreenGui

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ModernDance2GUI"
screenGui.Parent = player:WaitForChild("PlayerGui")

-- Main button
local button = Instance.new("TextButton")
button.Size = UDim2.new(0,70,0,70)
button.Position = UDim2.new(0.9,0,0.8,0)
button.AnchorPoint = Vector2.new(0.5,0.5)
button.BackgroundColor3 = Color3.fromRGB(0,0,0)
button.BorderSizePixel = 0
button.Text = ""
button.AutoButtonColor = true

-- Add rounded corners
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0.5,0)
corner.Parent = button

-- Shadow effect
local shadow = Instance.new("UIStroke")
shadow.Color = Color3.fromRGB(255,255,255)
shadow.Thickness = 2
shadow.Transparency = 0.6
shadow.Parent = button

-- Modern icon (dance)
local icon = Instance.new("ImageLabel")
icon.Size = UDim2.new(0.6,0,0.6,0)
icon.Position = UDim2.new(0.2,0,0.2,0)
icon.BackgroundTransparency = 1
icon.Image = "rbxassetid://6073597839" -- clean dance icon
icon.ImageColor3 = Color3.fromRGB(255,255,255)
icon.Parent = button

button.Parent = screenGui

-- Dragging setup
local dragging = false
local dragStartPos
local startButtonPos
local holdTime = 1

button.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or
       input.UserInputType == Enum.UserInputType.MouseButton1 then

        dragStartPos = input.Position
        startButtonPos = button.Position
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
                    -- Click short: send /e dance2
                    local success, err = pcall(function()
                        local chatEvent = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
                            and ReplicatedStorage.DefaultChatSystemChatEvents
                        if chatEvent and chatEvent:FindFirstChild("SayMessageRequest") then
                            chatEvent.SayMessageRequest:FireServer("/e dance2","All")
                        else
                            warn("Chat event not found. Dance2 not sent.")
                        end
                    end)
                    if not success then
                        warn("Error sending /e dance2:", err)
                    end
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
                local delta = input.Position - dragStartPos
                button.Position = UDim2.new(
                    0,
                    math.clamp(startButtonPos.X.Offset + delta.X, 0, workspace.CurrentCamera.ViewportSize.X - button.AbsoluteSize.X),
                    0,
                    math.clamp(startButtonPos.Y.Offset + delta.Y, 0, workspace.CurrentCamera.ViewportSize.Y - button.AbsoluteSize.Y)
                )
            end
        end)
    end
end)
