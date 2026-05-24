--// Caos na Cozinha - Plate Debug / Checklist Scanner v1
--// Objetivo:
--// 1) Ler o pedido atual pela UI.
--// 2) Mostrar uma lista do pedido atual no console.
--// 3) Monitorar pratos/countertops próximos para descobrir como o jogo registra ingredientes colocados.
--//
--// Use:
--// - PRINT PEDIDO: mostra os IDs dos ingredientes do pedido atual.
--// - PRINT PRATOS: mostra pratos/countertops próximos e o que tem dentro.
--// - MONITOR: liga/desliga um monitor que printa quando muda algo em pratos/countertops.
--//
--// Depois de colocar 1 ingrediente no prato, aperta PRINT PRATOS e manda o resultado.
--// Se o MONITOR detectar mudança, manda também o print do console.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")

local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")

local ScreenGuiName = "CKPlateDebugV1"
local monitorEnabled = false
local lastPlateSignature = ""

local IGNORE_IDS = {
    ["140157429295813"] = true,
    ["133105772499368"] = true,
    ["72733766243904"] = true,
    ["75742169776390"] = true,
}

local METHOD_NAMES = {
    ["125425887763635"] = "cozinhar",
    ["102782857320968"] = "cortar",
    ["123188384272883"] = "cortar",
}

local INGREDIENT_HINTS = {
    ["139735918683467"] = "alga",
    ["109051711884970"] = "arroz",
    ["125527817193846"] = "pepino/outro",
    ["139351714153211"] = "ingrediente",
    ["93974625470297"] = "ingrediente",
}

local function normAsset(x)
    x = tostring(x or "")
    local id = x:match("rbxassetid://(%d+)") or x:match("id=(%d+)")
    return id
end

local function path(obj)
    local ok, res = pcall(function()
        return obj:GetFullName()
    end)
    return ok and res or tostring(obj)
end

local function getChar()
    return lp.Character or lp.CharacterAdded:Wait()
end

local function getHRP()
    local char = getChar()
    return char:FindFirstChild("HumanoidRootPart")
end

local function getPos(obj)
    local part

    if obj:IsA("BasePart") then
        part = obj
    elseif obj:IsA("Model") then
        part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
    else
        part = obj:FindFirstAncestorWhichIsA("BasePart")
    end

    if not part then
        return "sem pos"
    end

    return math.floor(part.Position.X) .. "," .. math.floor(part.Position.Y) .. "," .. math.floor(part.Position.Z)
end

local function getRecipesRoot()
    local root = pg:FindFirstChild("Root")
    local hud = root and root:FindFirstChild("HUD")
    return hud and hud:FindFirstChild("Recipes")
end

local function getRecipeFrames()
    local recipes = getRecipesRoot()
    local frames = {}

    if not recipes then
        return frames
    end

    for _, child in ipairs(recipes:GetChildren()) do
        if child:IsA("GuiObject") and child.Visible and child.Name:lower():find("recipe") then
            table.insert(frames, child)
        end
    end

    return frames
end

local function getOrderItems()
    local items = {}

    for _, frame in ipairs(getRecipeFrames()) do
        local ingredientsRoot = frame:FindFirstChild("Ingredients", true)
        local addedTemplate = false

        if ingredientsRoot then
            for _, template in ipairs(ingredientsRoot:GetChildren()) do
                if template:IsA("GuiObject") and template.Visible then
                    local ingredientId
                    local methodId

                    local cookingMethod = template:FindFirstChild("CookingMethod", true)
                    if cookingMethod and (cookingMethod:IsA("ImageLabel") or cookingMethod:IsA("ImageButton")) and cookingMethod.Visible then
                        methodId = normAsset(cookingMethod.Image)
                    end

                    for _, d in ipairs(template:GetDescendants()) do
                        if (d:IsA("ImageLabel") or d:IsA("ImageButton")) and d.Visible then
                            local p = path(d):lower()
                            local id = normAsset(d.Image)

                            if id and not IGNORE_IDS[id] then
                                if p:find("ingredientimagetemplate") or d.Name:lower():find("ingredientimage") then
                                    ingredientId = id
                                    break
                                end
                            end
                        end
                    end

                    if ingredientId then
                        addedTemplate = true
                        table.insert(items, {
                            id = ingredientId,
                            method = methodId,
                            name = INGREDIENT_HINTS[ingredientId] or ("item " .. ingredientId),
                            methodName = METHOD_NAMES[methodId] or (methodId and ("método " .. methodId) or "sem preparo"),
                        })
                    end
                end
            end
        end

        if not addedTemplate then
            local recipeImage = frame:FindFirstChild("RecipeImage", true)
            if recipeImage and recipeImage:IsA("ImageLabel") and recipeImage.Visible then
                local id = normAsset(recipeImage.Image)
                if id and not IGNORE_IDS[id] then
                    table.insert(items, {
                        id = id,
                        method = nil,
                        name = INGREDIENT_HINTS[id] or ("item " .. id),
                        methodName = "sem preparo",
                    })
                end
            end
        end
    end

    local clean = {}
    local seen = {}

    for _, item in ipairs(items) do
        local key = item.id .. "|" .. tostring(item.method)
        if not seen[key] then
            seen[key] = true
            table.insert(clean, item)
        end
    end

    return clean
end

local function printBlock(title, lines)
    warn("[CK PLATE] ===== " .. title .. " =====")

    local chunk = {}

    for _, line in ipairs(lines) do
        table.insert(chunk, line)

        if #chunk >= 14 then
            print("[CK PLATE]\n" .. table.concat(chunk, "\n"))
            table.clear(chunk)
            task.wait(0.08)
        end
    end

    if #chunk > 0 then
        print("[CK PLATE]\n" .. table.concat(chunk, "\n"))
    end

    warn("[CK PLATE] ===== FIM " .. title .. " =====")
end

local function printPedido()
    local lines = {}
    local items = getOrderItems()

    table.insert(lines, "Pedido atual:")
    table.insert(lines, "Quantidade: " .. tostring(#items))
    table.insert(lines, "")

    for i, item in ipairs(items) do
        table.insert(lines, tostring(i) .. ") " .. item.name)
        table.insert(lines, "   ingredientId=" .. tostring(item.id))
        table.insert(lines, "   methodId=" .. tostring(item.method))
        table.insert(lines, "   methodName=" .. tostring(item.methodName))
    end

    printBlock("PEDIDO", lines)
end

local function readValues(obj, prefix, out, limit)
    limit = limit or 160

    for _, d in ipairs(obj:GetDescendants()) do
        if #out >= limit then
            return
        end

        if d:IsA("StringValue") or d:IsA("IntValue") or d:IsA("NumberValue") or d:IsA("BoolValue") or d:IsA("ObjectValue") then
            table.insert(out, prefix .. "VALUE " .. d.Name .. " [" .. d.ClassName .. "] = " .. tostring(d.Value) .. " | " .. path(d))
        elseif d:IsA("Decal") or d:IsA("Texture") then
            local id = normAsset(d.Texture)
            if id then
                table.insert(out, prefix .. "ASSET " .. d.Name .. " [" .. d.ClassName .. "] id=" .. id .. " | " .. path(d))
            end
        elseif d:IsA("ImageLabel") or d:IsA("ImageButton") then
            local id = normAsset(d.Image)
            if id then
                table.insert(out, prefix .. "ASSET " .. d.Name .. " [" .. d.ClassName .. "] id=" .. id .. " | " .. path(d))
            end
        elseif d:IsA("MeshPart") then
            local id = normAsset(d.TextureID)
            if id then
                table.insert(out, prefix .. "MESH " .. d.Name .. " textureId=" .. id .. " | " .. path(d))
            end
        elseif d:IsA("SpecialMesh") then
            local id = normAsset(d.TextureId)
            if id then
                table.insert(out, prefix .. "MESH " .. d.Name .. " textureId=" .. id .. " | " .. path(d))
            end
        end
    end
end

local function attrs(obj)
    local t = {}

    for k, v in pairs(obj:GetAttributes()) do
        table.insert(t, tostring(k) .. "=" .. tostring(v))
    end

    return t
end

local function looksLikePlateObj(obj)
    local n = obj.Name:lower()
    local p = path(obj):lower()

    return n:find("plate", 1, true)
        or n:find("dish", 1, true)
        or p:find(".plate", 1, true)
        or p:find("plate", 1, true)
        or p:find("dish", 1, true)
        or n:find("itemposition", 1, true)
end

local function getNearbyPlateObjects(radius)
    radius = radius or 25

    local root = workspace:FindFirstChild("Interactables") or workspace
    local hrp = getHRP()
    local result = {}
    local used = {}

    if not hrp then
        return result
    end

    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Model") then
            if looksLikePlateObj(obj) then
                local pos
                if obj:IsA("BasePart") then
                    pos = obj.Position
                else
                    local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
                    pos = part and part.Position
                end

                if pos and (pos - hrp.Position).Magnitude <= radius then
                    local target = obj:IsA("Model") and obj or obj:FindFirstAncestorOfClass("Model") or obj
                    local p = path(target)

                    if not used[p] then
                        used[p] = true
                        table.insert(result, target)
                    end
                end
            end
        end
    end

    return result
end

local function plateSignature()
    local plates = getNearbyPlateObjects(40)
    local parts = {}

    table.sort(plates, function(a, b)
        return path(a) < path(b)
    end)

    for _, plate in ipairs(plates) do
        local block = {path(plate)}

        for k, v in pairs(plate:GetAttributes()) do
            table.insert(block, "A:" .. tostring(k) .. "=" .. tostring(v))
        end

        for _, d in ipairs(plate:GetDescendants()) do
            if d:IsA("StringValue") or d:IsA("IntValue") or d:IsA("NumberValue") or d:IsA("BoolValue") then
                table.insert(block, "V:" .. path(d) .. "=" .. tostring(d.Value))
            elseif d:IsA("ObjectValue") then
                table.insert(block, "O:" .. path(d) .. "=" .. tostring(d.Value))
            elseif d:IsA("Decal") or d:IsA("Texture") then
                local id = normAsset(d.Texture)
                if id then table.insert(block, "D:" .. path(d) .. "=" .. id) end
            elseif d:IsA("ImageLabel") or d:IsA("ImageButton") then
                local id = normAsset(d.Image)
                if id then table.insert(block, "I:" .. path(d) .. "=" .. id) end
            elseif d:IsA("MeshPart") then
                local id = normAsset(d.TextureID)
                if id then table.insert(block, "M:" .. path(d) .. "=" .. id) end
            elseif d:IsA("SpecialMesh") then
                local id = normAsset(d.TextureId)
                if id then table.insert(block, "SM:" .. path(d) .. "=" .. id) end
            end
        end

        table.insert(parts, table.concat(block, "|"))
    end

    return table.concat(parts, "\n---\n")
end

local function printPratos()
    local lines = {}
    local plates = getNearbyPlateObjects(35)

    table.insert(lines, "Objetos de prato/itemposition perto:")
    table.insert(lines, "Quantidade: " .. tostring(#plates))
    table.insert(lines, "")

    for i, plate in ipairs(plates) do
        table.insert(lines, "---- PRATO/OBJ #" .. tostring(i) .. " ----")
        table.insert(lines, "Name: " .. plate.Name .. " [" .. plate.ClassName .. "]")
        table.insert(lines, "Path: " .. path(plate))
        table.insert(lines, "Pos: " .. getPos(plate))

        local a = attrs(plate)
        if #a > 0 then
            table.insert(lines, "Attributes:")
            for _, x in ipairs(a) do
                table.insert(lines, "  " .. x)
            end
        end

        table.insert(lines, "Children:")
        for _, c in ipairs(plate:GetChildren()) do
            table.insert(lines, "  - " .. c.Name .. " [" .. c.ClassName .. "]")
        end

        readValues(plate, "  ", lines, 240)
        table.insert(lines, "")
    end

    printBlock("PRATOS", lines)
end

RunService.Heartbeat:Connect(function()
    if not monitorEnabled then
        return
    end

    local sig = plateSignature()

    if lastPlateSignature == "" then
        lastPlateSignature = sig
        return
    end

    if sig ~= lastPlateSignature then
        lastPlateSignature = sig
        warn("[CK PLATE] MUDANÇA DETECTADA EM PRATO/COUNTERTOP")
        printPratos()
    end
end)

local old = pg:FindFirstChild(ScreenGuiName)
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = ScreenGuiName
gui.ResetOnSpawn = false
gui.Parent = pg

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 220, 0, 180)
frame.Position = UDim2.new(0, 18, 0.40, 0)
frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
frame.BackgroundTransparency = 0.12
frame.BorderSizePixel = 0
frame.Active = true
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -16, 0, 30)
title.Position = UDim2.new(0, 8, 0, 8)
title.BackgroundTransparency = 1
title.Text = "Plate Debug"
title.TextColor3 = Color3.fromRGB(255,255,255)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = frame

local function btn(text, y)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -20, 0, 32)
    b.Position = UDim2.new(0, 10, 0, y)
    b.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
    b.TextColor3 = Color3.fromRGB(255,255,255)
    b.TextScaled = true
    b.Font = Enum.Font.GothamBold
    b.Text = text
    b.BorderSizePixel = 0
    b.Parent = frame
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
    return b
end

local pedidoBtn = btn("PRINT PEDIDO", 45)
local pratosBtn = btn("PRINT PRATOS", 81)
local monitorBtn = btn("MONITOR: OFF", 117)
local closeBtn = btn("FECHAR", 153)

pedidoBtn.MouseButton1Click:Connect(printPedido)
pratosBtn.MouseButton1Click:Connect(printPratos)

monitorBtn.MouseButton1Click:Connect(function()
    monitorEnabled = not monitorEnabled
    lastPlateSignature = ""
    monitorBtn.Text = monitorEnabled and "MONITOR: ON" or "MONITOR: OFF"
end)

closeBtn.MouseButton1Click:Connect(function()
    gui:Destroy()
end)

-- arrastar
do
    local dragging = false
    local dragStart
    local startPos

    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)

    frame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and dragStart and startPos then
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
                local delta = input.Position - dragStart
                frame.Position = UDim2.new(
                    startPos.X.Scale,
                    startPos.X.Offset + delta.X,
                    startPos.Y.Scale,
                    startPos.Y.Offset + delta.Y
                )
            end
        end
    end)
end

warn("[CK PLATE] Debug carregado.")
warn("[CK PLATE] Faça assim: PRINT PEDIDO, depois coloque 1 ingrediente no prato, depois PRINT PRATOS.")
warn("[CK PLATE] Também pode ligar MONITOR antes de colocar o ingrediente.")
