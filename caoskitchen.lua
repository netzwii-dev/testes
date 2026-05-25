--// Caos na Cozinha - Pedido Contador Simples v2
--// Ideia:
--// - Mostra só o pedido mais atual.
--// - Mostra quantos ingredientes faltam.
--// - Quando algum ingrediente entra no prato, diminui 1.
--// - Quando completar, mostra ✅.
--// - Quando entregar e aparecer outro pedido, atualiza sozinho.
--//
--// Não depende de mapa, panela, faca ou chams.
--// Só depende da UI do pedido + objetos dentro do prato/Sushi.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")

local GUI_NAME = "CookCaosPedidoContadorV2"

local IGNORE_IDS = {
    ["140157429295813"] = true, -- IngredientTemplate fundo
    ["133105772499368"] = true,
    ["72733766243904"] = true,
    ["75742169776390"] = true,
}

local ID_TO_NAME = {
    ["139735918683467"] = "alga",
    ["109051711884970"] = "arroz",
    ["125527817193846"] = "pepino",
}

-- corrigido pelo seu print: esse ID era panela/cozinhar, não faca
local METHOD_TO_NAME = {
    ["102782857320968"] = "cozinhar",
    ["125425887763635"] = "cozinhar",
    ["123188384272883"] = "cortar",
}

local enabled = true
local compact = false
local currentKey = ""
local currentItems = {}
local orderStartTime = 0

local gui, panel, mainButton, titleLabel, countLabel, itemList, statusLabel
local rows = {}

local function normAsset(x)
    x = tostring(x or "")
    return x:match("rbxassetid://(%d+)") or x:match("id=(%d+)")
end

local function safePath(obj)
    local ok, res = pcall(function()
        return obj:GetFullName()
    end)
    return ok and res or tostring(obj)
end

local function addCorner(obj, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r)
    c.Parent = obj
end

local function addStroke(obj, alpha)
    local s = Instance.new("UIStroke")
    s.Color = Color3.fromRGB(255,255,255)
    s.Thickness = 1
    s.Transparency = alpha or 0.75
    s.Parent = obj
end

local function clickAnim(btn)
    local base = btn.BackgroundColor3
    btn.MouseButton1Down:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.07), {
            BackgroundColor3 = Color3.fromRGB(50,50,50),
            Size = btn.Size - UDim2.new(0,2,0,2)
        }):Play()
    end)
    btn.MouseButton1Up:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.10), {
            BackgroundColor3 = base,
            Size = btn.Size + UDim2.new(0,2,0,2)
        }):Play()
    end)
end

local function getRecipesRoot()
    local root = pg:FindFirstChild("Root")
    local hud = root and root:FindFirstChild("HUD")
    return hud and hud:FindFirstChild("Recipes")
end

local function getVisibleRecipeFrames()
    local recipes = getRecipesRoot()
    local frames = {}

    if not recipes then
        return frames
    end

    for _, child in ipairs(recipes:GetChildren()) do
        if child:IsA("GuiObject") and child.Visible and child.Name:lower():find("recipe") then
            -- ignora template invisível/velho que fica fora da tela
            if child.AbsoluteSize.X > 5 and child.AbsoluteSize.Y > 5 then
                table.insert(frames, child)
            end
        end
    end

    table.sort(frames, function(a, b)
        if math.abs(a.AbsolutePosition.X - b.AbsolutePosition.X) > 4 then
            return a.AbsolutePosition.X < b.AbsolutePosition.X
        end
        return a.AbsolutePosition.Y < b.AbsolutePosition.Y
    end)

    return frames
end

local function readItemFromTemplate(template)
    local ingredientId = nil
    local methodId = nil

    local methodObj = template:FindFirstChild("CookingMethod", true)
    if methodObj and (methodObj:IsA("ImageLabel") or methodObj:IsA("ImageButton")) and methodObj.Visible then
        methodId = normAsset(methodObj.Image)
    end

    for _, d in ipairs(template:GetDescendants()) do
        if (d:IsA("ImageLabel") or d:IsA("ImageButton")) and d.Visible then
            local p = safePath(d):lower()
            local id = normAsset(d.Image)

            if id and not IGNORE_IDS[id] then
                if p:find("ingredientimagetemplate", 1, true) or d.Name:lower():find("ingredientimage", 1, true) then
                    ingredientId = id
                    break
                end
            end
        end
    end

    if not ingredientId then
        return nil
    end

    local methodName = METHOD_TO_NAME[methodId] or (methodId and "preparar" or "sem preparo")

    return {
        id = ingredientId,
        method = methodId,
        name = ID_TO_NAME[ingredientId] or ("item"),
        methodName = methodName,
    }
end

local function getCurrentOrderItems()
    local frames = getVisibleRecipeFrames()
    local frame = frames[1] -- pedido mais atual/primeiro da fila

    if not frame then
        return {}
    end

    local result = {}
    local ingredientsRoot = frame:FindFirstChild("Ingredients", true)

    if ingredientsRoot then
        local templates = {}

        for _, template in ipairs(ingredientsRoot:GetChildren()) do
            if template:IsA("GuiObject") and template.Visible and template.AbsoluteSize.X > 3 and template.AbsoluteSize.Y > 3 then
                table.insert(templates, template)
            end
        end

        table.sort(templates, function(a, b)
            return a.AbsolutePosition.X < b.AbsolutePosition.X
        end)

        for _, template in ipairs(templates) do
            local item = readItemFromTemplate(template)
            if item then
                table.insert(result, item)
            end
        end
    end

    -- fallback se algum pedido for de 1 item só
    if #result == 0 then
        local recipeImage = frame:FindFirstChild("RecipeImage", true)
        if recipeImage and recipeImage:IsA("ImageLabel") and recipeImage.Visible then
            local id = normAsset(recipeImage.Image)
            if id and not IGNORE_IDS[id] then
                table.insert(result, {
                    id = id,
                    method = nil,
                    name = ID_TO_NAME[id] or "item",
                    methodName = "sem preparo",
                })
            end
        end
    end

    return result
end

local function orderKey(items)
    local t = {}
    for _, item in ipairs(items) do
        table.insert(t, item.id .. ":" .. tostring(item.method))
    end
    return table.concat(t, "|")
end

local function isIngredientModelName(name)
    name = string.lower(tostring(name or ""))

    if name == "" then return false end
    if name == "plate" then return false end
    if name == "sushi" then return false end
    if name == "unwrapped" then return false end
    if name == "wrapped" then return false end
    if name == "weld" then return false end
    if name == "model" then return false end
    if name == "itemposition" then return false end
    if name == "ingredientsui" then return false end
    if name == "progressbar" then return false end
    if name == "saucepan" then return false end
    if name == "hob" then return false end
    if name == "choppingboard" then return false end
    if name == "countertop" then return false end
    if name == "platespawner" then return false end

    return true
end

local function findPlateSushiRoots()
    local roots = {}
    local interactables = workspace:FindFirstChild("Interactables") or workspace

    for _, obj in ipairs(interactables:GetDescendants()) do
        if obj:IsA("Model") and obj.Name == "Sushi" then
            local p = safePath(obj):lower()
            if p:find("plate", 1, true) then
                table.insert(roots, obj)
            end
        end
    end

    return roots
end

local function getNearestIngredientModelUnderSushi(obj, sushiRoot)
    local cur = obj

    while cur and cur ~= sushiRoot do
        if cur:IsA("Model") and isIngredientModelName(cur.Name) then
            return cur
        end
        cur = cur.Parent
    end

    return nil
end

local function getPlateIngredientKeys()
    local keys = {}

    for _, sushi in ipairs(findPlateSushiRoots()) do
        for _, d in ipairs(sushi:GetDescendants()) do
            if d:IsA("BasePart") or d:IsA("MeshPart") then
                local model = getNearestIngredientModelUnderSushi(d, sushi)
                if model then
                    keys[safePath(model)] = true
                else
                    -- fallback para item que seja MeshPart solto dentro do Sushi
                    if isIngredientModelName(d.Name) then
                        keys[safePath(d)] = true
                    end
                end
            end
        end
    end

    local list = {}
    for k in pairs(keys) do
        table.insert(list, k)
    end

    table.sort(list)
    return list
end

local function getPlacedCount()
    local list = getPlateIngredientKeys()
    return #list
end

local function clearRows()
    for _, r in ipairs(rows) do
        if r and r.Parent then
            r:Destroy()
        end
    end
    table.clear(rows)
end

local function render()
    if not panel or not itemList then return end

    clearRows()

    local total = #currentItems
    local placed = getPlacedCount()
    local remaining = math.max(total - placed, 0)

    if total == 0 then
        titleLabel.Text = "Pedido atual"
        countLabel.Text = "-"
        statusLabel.Text = "sem pedido"
    elseif remaining <= 0 then
        titleLabel.Text = "Pedido atual"
        countLabel.Text = "✅"
        statusLabel.Text = "concluído"
    else
        titleLabel.Text = "Pedido atual"
        countLabel.Text = tostring(remaining)
        statusLabel.Text = "faltam " .. tostring(remaining) .. "/" .. tostring(total)
    end

    local rowH = compact and 24 or 30
    local y = 0

    if total == 0 then
        local row = Instance.new("TextLabel")
        row.Size = UDim2.new(1, -8, 0, 34)
        row.Position = UDim2.new(0, 4, 0, y)
        row.BackgroundTransparency = 1
        row.Text = "aguardando pedido..."
        row.TextColor3 = Color3.fromRGB(255,255,255)
        row.TextScaled = true
        row.Font = Enum.Font.GothamBold
        row.Parent = itemList
        table.insert(rows, row)
        return
    end

    for i, item in ipairs(currentItems) do
        local row = Instance.new("TextLabel")
        row.Size = UDim2.new(1, -8, 0, rowH)
        row.Position = UDim2.new(0, 4, 0, y)
        row.BackgroundColor3 = Color3.fromRGB(14,14,14)
        row.BackgroundTransparency = 0.05
        row.BorderSizePixel = 0
        row.TextColor3 = Color3.fromRGB(255,255,255)
        row.TextScaled = true
        row.Font = Enum.Font.GothamBold
        row.TextXAlignment = Enum.TextXAlignment.Left
        row.Parent = itemList
        addCorner(row, 9)

        local prep = ""
        if item.methodName and item.methodName ~= "sem preparo" then
            prep = " — " .. item.methodName
        end

        row.Text = "  " .. tostring(i) .. ". " .. item.name .. prep

        table.insert(rows, row)
        y += rowH + 5
    end

    itemList.CanvasSize = UDim2.new(0, 0, 0, y + 8)
end

local function makeBtn(parent, text, x, y, w, cb)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, w, 0, 32)
    b.Position = UDim2.new(0, x, 0, y)
    b.BackgroundColor3 = Color3.fromRGB(0,0,0)
    b.TextColor3 = Color3.fromRGB(255,255,255)
    b.TextScaled = true
    b.Font = Enum.Font.GothamBold
    b.Text = text
    b.BorderSizePixel = 0
    b.Parent = parent
    addCorner(b, 9)
    addStroke(b, 0.82)
    clickAnim(b)
    b.MouseButton1Click:Connect(cb)
    return b
end

local function buildGui()
    local old = pg:FindFirstChild(GUI_NAME)
    if old then old:Destroy() end

    gui = Instance.new("ScreenGui")
    gui.Name = GUI_NAME
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = pg

    local inset = GuiService:GetGuiInset()

    mainButton = Instance.new("TextButton")
    mainButton.Size = UDim2.new(0, 118, 0, 44)
    mainButton.Position = UDim2.new(0, 145, 0, inset.Y - 52)
    mainButton.BackgroundColor3 = Color3.fromRGB(0,0,0)
    mainButton.TextColor3 = Color3.fromRGB(255,255,255)
    mainButton.TextScaled = true
    mainButton.Font = Enum.Font.GothamBold
    mainButton.Text = "Pedido ON"
    mainButton.BorderSizePixel = 0
    mainButton.Parent = gui
    addCorner(mainButton, 12)
    addStroke(mainButton, 0.78)
    clickAnim(mainButton)

    panel = Instance.new("Frame")
    panel.Size = UDim2.new(0, 245, 0, 225)
    panel.Position = UDim2.new(0, 16, 0.40, 0)
    panel.BackgroundColor3 = Color3.fromRGB(0,0,0)
    panel.BackgroundTransparency = 0.08
    panel.BorderSizePixel = 0
    panel.Active = true
    panel.Parent = gui
    addCorner(panel, 16)
    addStroke(panel, 0.72)

    titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -78, 0, 34)
    titleLabel.Position = UDim2.new(0, 12, 0, 8)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "Pedido atual"
    titleLabel.TextColor3 = Color3.fromRGB(255,255,255)
    titleLabel.TextScaled = true
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = panel

    countLabel = Instance.new("TextLabel")
    countLabel.Size = UDim2.new(0, 54, 0, 42)
    countLabel.Position = UDim2.new(1, -64, 0, 7)
    countLabel.BackgroundColor3 = Color3.fromRGB(15,15,15)
    countLabel.TextColor3 = Color3.fromRGB(255,255,255)
    countLabel.TextScaled = true
    countLabel.Font = Enum.Font.GothamBlack
    countLabel.Text = "-"
    countLabel.BorderSizePixel = 0
    countLabel.Parent = panel
    addCorner(countLabel, 12)
    addStroke(countLabel, 0.82)

    statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -20, 0, 24)
    statusLabel.Position = UDim2.new(0, 10, 0, 45)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "aguardando..."
    statusLabel.TextColor3 = Color3.fromRGB(210,210,210)
    statusLabel.TextScaled = true
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = panel

    itemList = Instance.new("ScrollingFrame")
    itemList.Size = UDim2.new(1, -18, 0, 105)
    itemList.Position = UDim2.new(0, 9, 0, 72)
    itemList.BackgroundTransparency = 1
    itemList.BorderSizePixel = 0
    itemList.ScrollBarThickness = 3
    itemList.CanvasSize = UDim2.new(0, 0, 0, 0)
    itemList.Parent = panel

    makeBtn(panel, "Compacto", 10, 184, 105, function()
        compact = not compact
        render()
    end)

    makeBtn(panel, "Fechar", 126, 184, 105, function()
        panel.Visible = not panel.Visible
    end)

    mainButton.MouseButton1Click:Connect(function()
        enabled = not enabled
        mainButton.Text = enabled and "Pedido ON" or "Pedido OFF"
        panel.Visible = enabled
    end)

    -- arrastar
    local dragging = false
    local dragStart
    local startPos

    panel.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = panel.Position
        end
    end)

    panel.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and dragStart and startPos then
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
                local delta = input.Position - dragStart
                panel.Position = UDim2.new(
                    startPos.X.Scale,
                    startPos.X.Offset + delta.X,
                    startPos.Y.Scale,
                    startPos.Y.Offset + delta.Y
                )
            end
        end
    end)
end

buildGui()

local lastUpdate = 0

RunService.Heartbeat:Connect(function()
    if not enabled then
        return
    end

    local items = getCurrentOrderItems()
    local key = orderKey(items)

    -- pedido novo ou pedido entregue/trocou
    if key ~= currentKey then
        currentKey = key
        currentItems = items
        orderStartTime = tick()
        render()
    end

    if tick() - lastUpdate > 0.25 then
        lastUpdate = tick()
        render()
    end
end)

warn("[CK CONTADOR] carregado.")
warn("[CK CONTADOR] Mostra total do pedido atual e diminui conforme aparecem ingredientes dentro do Plate.Sushi.")
warn("[CK CONTADOR] Se algum mapa usar outro nome além de Plate.Sushi, manda print do debug.")
