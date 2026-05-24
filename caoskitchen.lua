--// Caos na Cozinha - Scanner Profundo Mobile v2
--// objetivo: descobrir o nome real do pedido atual e dos ingredientes do mapa
--// use: execute, clique "COPIAR SCAN", cole o resultado no ChatGPT

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local lp = Players.LocalPlayer

local function copy(txt)
    if setclipboard then
        setclipboard(txt)
    elseif toclipboard then
        toclipboard(txt)
    elseif syn and syn.write_clipboard then
        syn.write_clipboard(txt)
    else
        warn("seu executor nao tem setclipboard/toclipboard")
    end
end

local function path(x)
    local ok, res = pcall(function()
        return x:GetFullName()
    end)
    return ok and res or tostring(x)
end

local function assetId(x)
    x = tostring(x or "")
    return x:match("rbxassetid://(%d+)") or x:match("(%d+)") or x
end

local function posOf(obj)
    local p
    if obj:IsA("BasePart") then
        p = obj
    elseif obj:IsA("Model") then
        p = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
    else
        p = obj:FindFirstAncestorWhichIsA("BasePart")
    end

    if p then
        return string.format("%d, %d, %d", p.Position.X, p.Position.Y, p.Position.Z)
    end

    return "sem pos"
end

local function addAttrs(lines, obj, prefix)
    local attrs = obj:GetAttributes()
    local has = false

    for k, v in pairs(attrs) do
        if not has then
            table.insert(lines, prefix .. "ATTRIBUTES:")
            has = true
        end
        table.insert(lines, prefix .. "  " .. tostring(k) .. " = " .. tostring(v))
    end
end

local function interestingValue(v)
    if v:IsA("StringValue") then
        return "StringValue = " .. tostring(v.Value)
    elseif v:IsA("IntValue") or v:IsA("NumberValue") then
        return v.ClassName .. " = " .. tostring(v.Value)
    elseif v:IsA("BoolValue") then
        return "BoolValue = " .. tostring(v.Value)
    elseif v:IsA("ObjectValue") then
        return "ObjectValue = " .. (v.Value and path(v.Value) or "nil")
    elseif v:IsA("TextLabel") or v:IsA("TextButton") or v:IsA("TextBox") then
        if tostring(v.Text or "") ~= "" then
            return v.ClassName .. " Text = " .. tostring(v.Text)
        end
    elseif v:IsA("ImageLabel") or v:IsA("ImageButton") then
        if tostring(v.Image or "") ~= "" then
            return v.ClassName .. " Image = " .. tostring(v.Image) .. " | id=" .. tostring(assetId(v.Image))
        end
    elseif v:IsA("Decal") or v:IsA("Texture") then
        if tostring(v.Texture or "") ~= "" then
            return v.ClassName .. " Texture = " .. tostring(v.Texture) .. " | id=" .. tostring(assetId(v.Texture))
        end
    elseif v:IsA("MeshPart") then
        local a = {}
        if tostring(v.MeshId or "") ~= "" then table.insert(a, "MeshId=" .. tostring(v.MeshId)) end
        if tostring(v.TextureID or "") ~= "" then table.insert(a, "TextureID=" .. tostring(v.TextureID) .. " | id=" .. tostring(assetId(v.TextureID))) end
        if #a > 0 then return "MeshPart " .. table.concat(a, " | ") end
    elseif v:IsA("SpecialMesh") then
        local a = {}
        if tostring(v.MeshId or "") ~= "" then table.insert(a, "MeshId=" .. tostring(v.MeshId)) end
        if tostring(v.TextureId or "") ~= "" then table.insert(a, "TextureId=" .. tostring(v.TextureId) .. " | id=" .. tostring(assetId(v.TextureId))) end
        if #a > 0 then return "SpecialMesh " .. table.concat(a, " | ") end
    elseif v:IsA("ProximityPrompt") then
        return "ProximityPrompt ActionText=" .. tostring(v.ActionText) .. " | ObjectText=" .. tostring(v.ObjectText)
    end

    return nil
end

local function dumpObject(lines, obj, title, maxDesc)
    table.insert(lines, "")
    table.insert(lines, "------------------------------")
    table.insert(lines, title)
    table.insert(lines, "NAME: " .. obj.Name)
    table.insert(lines, "CLASS: " .. obj.ClassName)
    table.insert(lines, "PATH: " .. path(obj))
    table.insert(lines, "POS: " .. posOf(obj))

    addAttrs(lines, obj, "")

    local tags = {}
    pcall(function()
        tags = CollectionService:GetTags(obj)
    end)
    if #tags > 0 then
        table.insert(lines, "TAGS: " .. table.concat(tags, ", "))
    end

    local count = 0
    for _, d in ipairs(obj:GetDescendants()) do
        local val = interestingValue(d)
        if val then
            count += 1
            table.insert(lines, "DESC: " .. path(d))
            table.insert(lines, "  " .. val)
            addAttrs(lines, d, "  ")

            if count >= maxDesc then
                table.insert(lines, "  ... limite de descendentes atingido")
                break
            end
        end
    end
end

local function scanGui(lines)
    table.insert(lines, "========== GUI / PEDIDO ==========")

    local root = lp:FindFirstChild("PlayerGui")
    if not root then
        table.insert(lines, "sem PlayerGui")
        return
    end

    for _, d in ipairs(root:GetDescendants()) do
        local p = string.lower(path(d))
        local n = string.lower(d.Name)

        local relevant =
            string.find(p, "recipe", 1, true)
            or string.find(p, "ingredient", 1, true)
            or string.find(p, "order", 1, true)
            or string.find(p, "pedido", 1, true)
            or string.find(p, "hud", 1, true)

        if relevant then
            local val = interestingValue(d)
            if val then
                table.insert(lines, "")
                table.insert(lines, "UI: " .. path(d))
                table.insert(lines, val)
                if d:IsA("GuiObject") then
                    table.insert(lines, "Visible=" .. tostring(d.Visible) .. " Size=" .. tostring(math.floor(d.AbsoluteSize.X)) .. "x" .. tostring(math.floor(d.AbsoluteSize.Y)) .. " Pos=" .. tostring(math.floor(d.AbsolutePosition.X)) .. "," .. tostring(math.floor(d.AbsolutePosition.Y)))
                end
                addAttrs(lines, d, "")
            end
        end
    end
end

local function scanInteractables(lines)
    table.insert(lines, "")
    table.insert(lines, "========== WORKSPACE.INTERACTABLES ==========")

    local root = workspace:FindFirstChild("Interactables")
    if not root then
        table.insert(lines, "nao achei workspace.Interactables")
        return
    end

    local keywords = {
        "food", "bin", "ingredient", "rice", "seaweed", "salmon", "cucumber", "fish",
        "tuna", "shrimp", "egg", "meat", "cheese", "tomato", "lettuce", "onion",
        "chopping", "cut", "knife", "board", "plate", "dish", "counter", "stove",
        "pot", "pan", "cook", "appliance"
    }

    local used = {}
    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("Folder") or obj:IsA("BasePart") then
            local low = string.lower(obj.Name)
            local full = string.lower(path(obj))
            local ok = false

            for _, k in ipairs(keywords) do
                if string.find(low, k, 1, true) or string.find(full, k, 1, true) then
                    ok = true
                    break
                end
            end

            if ok and not used[path(obj)] then
                used[path(obj)] = true
                dumpObject(lines, obj, "OBJETO DO MAPA", 25)
            end
        end
    end
end

local function scanReplicatedStorage(lines)
    table.insert(lines, "")
    table.insert(lines, "========== REPLICATEDSTORAGE POSSIVEIS DADOS ==========")

    local keywords = {
        "recipe", "recipes", "ingredient", "ingredients", "food", "foods",
        "order", "orders", "kitchen", "cook", "dish", "dishes"
    }

    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        local low = string.lower(obj.Name)
        local full = string.lower(path(obj))
        local ok = false

        for _, k in ipairs(keywords) do
            if string.find(low, k, 1, true) or string.find(full, k, 1, true) then
                ok = true
                break
            end
        end

        if ok then
            if obj:IsA("ModuleScript") then
                table.insert(lines, "")
                table.insert(lines, "MODULE: " .. path(obj))
            else
                local val = interestingValue(obj)
                if val then
                    table.insert(lines, "")
                    table.insert(lines, "DATA: " .. path(obj))
                    table.insert(lines, val)
                    addAttrs(lines, obj, "")
                end
            end
        end
    end
end

local function buildScan()
    local lines = {}
    table.insert(lines, "CAOS NA COZINHA SCAN V2")
    table.insert(lines, "Player: " .. lp.Name)
    table.insert(lines, "Time: " .. os.date("%H:%M:%S"))

    scanGui(lines)
    scanInteractables(lines)
    scanReplicatedStorage(lines)

    return table.concat(lines, "\n")
end

local old = lp.PlayerGui:FindFirstChild("CaosScannerV2")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "CaosScannerV2"
gui.ResetOnSpawn = false
gui.Parent = lp:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 230, 0, 95)
frame.Position = UDim2.new(0, 20, 0.42, 0)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
frame.BackgroundTransparency = 0.15
frame.Parent = gui

local c = Instance.new("UICorner")
c.CornerRadius = UDim.new(0, 10)
c.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -10, 0, 35)
title.Position = UDim2.new(0, 5, 0, 5)
title.BackgroundTransparency = 1
title.Text = "Scanner V2"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = frame

local btn = Instance.new("TextButton")
btn.Size = UDim2.new(1, -20, 0, 42)
btn.Position = UDim2.new(0, 10, 0, 45)
btn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
btn.Text = "COPIAR SCAN"
btn.TextColor3 = Color3.fromRGB(255, 255, 255)
btn.TextScaled = true
btn.Font = Enum.Font.GothamBold
btn.Parent = frame

local bc = Instance.new("UICorner")
bc.CornerRadius = UDim.new(0, 8)
bc.Parent = btn

btn.MouseButton1Click:Connect(function()
    btn.Text = "SCANEANDO..."
    task.wait()

    local text = buildScan()
    copy(text)
    print(text)
    warn("SCAN V2 COPIADO")

    btn.Text = "COPIADO!"
    task.wait(1.2)
    btn.Text = "COPIAR SCAN"
end)
