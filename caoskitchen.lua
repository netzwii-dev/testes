--// Caos na Cozinha - Debug Mobile
--// Botão na tela para copiar GUI do pedido + objetos próximos

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local lp = Players.LocalPlayer
local char = lp.Character or lp.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")

local function copy(txt)
    if setclipboard then
        setclipboard(txt)
    elseif toclipboard then
        toclipboard(txt)
    elseif syn and syn.write_clipboard then
        syn.write_clipboard(txt)
    end
end

local function getDist(part)
    if not part or not part:IsA("BasePart") or not hrp then
        return math.huge
    end

    return (part.Position - hrp.Position).Magnitude
end

local function findOrderImages()
    local results = {}

    for _, v in ipairs(lp.PlayerGui:GetDescendants()) do
        if v:IsA("ImageLabel") or v:IsA("ImageButton") then
            local img = tostring(v.Image or "")
            local size = v.AbsoluteSize

            if v.Visible and img ~= "" and size.X > 15 and size.Y > 15 then
                table.insert(results, {
                    name = v.Name,
                    path = v:GetFullName(),
                    image = img,
                    size = math.floor(size.X) .. "x" .. math.floor(size.Y),
                    pos = math.floor(v.AbsolutePosition.X) .. "," .. math.floor(v.AbsolutePosition.Y)
                })
            end
        end
    end

    return results
end

local function findNearbyObjects(radius)
    local found = {}

    char = lp.Character or lp.CharacterAdded:Wait()
    hrp = char:FindFirstChild("HumanoidRootPart")

    if not hrp then
        return found
    end

    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("BasePart") then
            local d = getDist(v)

            if d <= radius then
                local prompt = v:FindFirstChildWhichIsA("ProximityPrompt", true)
                local model = v:FindFirstAncestorOfClass("Model")

                table.insert(found, {
                    dist = math.floor(d),
                    name = v.Name,
                    path = v:GetFullName(),
                    model = model and model.Name or "sem model",
                    prompt = prompt and prompt:GetFullName() or "sem prompt",
                    size = tostring(v.Size)
                })
            end
        end
    end

    table.sort(found, function(a, b)
        return a.dist < b.dist
    end)

    return found
end

local function buildDebugText()
    local imgs = findOrderImages()
    local near = findNearbyObjects(35)

    local lines = {}

    table.insert(lines, "=== GUI / PEDIDO VISIVEL ===")

    for i = 1, math.min(#imgs, 20) do
        local x = imgs[i]
        table.insert(lines, "")
        table.insert(lines, i .. ") " .. x.name)
        table.insert(lines, "image: " .. x.image)
        table.insert(lines, "path: " .. x.path)
        table.insert(lines, "size: " .. x.size)
        table.insert(lines, "pos: " .. x.pos)
    end

    table.insert(lines, "")
    table.insert(lines, "=== OBJETOS PROXIMOS ===")

    for i = 1, math.min(#near, 35) do
        local x = near[i]
        table.insert(lines, "")
        table.insert(lines, i .. ") [" .. x.dist .. " studs] " .. x.name)
        table.insert(lines, "model: " .. x.model)
        table.insert(lines, "path: " .. x.path)
        table.insert(lines, "prompt: " .. x.prompt)
        table.insert(lines, "size: " .. x.size)
    end

    return table.concat(lines, "\n")
end

local gui = Instance.new("ScreenGui")
gui.Name = "KitchenDebugMobile"
gui.ResetOnSpawn = false
gui.Parent = lp:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 210, 0, 95)
frame.Position = UDim2.new(0, 20, 0.55, 0)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
frame.BackgroundTransparency = 0.15
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -10, 0, 35)
title.Position = UDim2.new(0, 5, 0, 5)
title.BackgroundTransparency = 1
title.Text = "Debug Cozinha"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = frame

local btn = Instance.new("TextButton")
btn.Size = UDim2.new(1, -20, 0, 42)
btn.Position = UDim2.new(0, 10, 0, 45)
btn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
btn.Text = "COPIAR DEBUG"
btn.TextColor3 = Color3.fromRGB(255, 255, 255)
btn.TextScaled = true
btn.Font = Enum.Font.GothamBold
btn.Parent = frame

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 8)
btnCorner.Parent = btn

btn.MouseButton1Click:Connect(function()
    local text = buildDebugText()
    copy(text)

    btn.Text = "COPIADO!"
    print(text)
    warn("DEBUG COPIADO")

    task.wait(1.2)
    btn.Text = "COPIAR DEBUG"
end)
