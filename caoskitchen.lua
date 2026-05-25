--// Caos na Cozinha - Botão Contador Minimal v3
--// Pedido atual: mostra só o número que falta.
--// Quando todos os ingredientes aparecem no prato: mostra ✅
--//
--// Sem painel, sem lista, sem nomes.
--// Botão pequeno na posição do antigo "Pedido ON/OFF".
--// Para mover: segure por 0.5s e arraste.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")

local GUI_NAME = "CookCaosMinimalCounterV3"

local IGNORE_IDS = {
    ["140157429295813"] = true,
    ["133105772499368"] = true,
    ["72733766243904"] = true,
    ["75742169776390"] = true,
}

local btn
local currentKey = ""
local currentTotal = 0
local lastUpdate = 0

local HOLD_TO_DRAG = 0.5
local dragging = false
local holding = false
local holdStarted = 0
local dragStart
local startPos
local activeInput

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
    s.Transparency = alpha or 0.65
    s.Parent = obj
end

local function pulse()
    if not btn then return end
    local original = btn.Size

    TweenService:Create(btn, TweenInfo.new(0.08), {
        Size = original + UDim2.new(0, 4, 0, 4)
    }):Play()

    task.delay(0.09, function()
        if btn then
            TweenService:Create(btn, TweenInfo.new(0.10), {
                Size = original
            }):Play()
        end
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

local function readIngredientIdFromTemplate(template)
    for _, d in ipairs(template:GetDescendants()) do
        if (d:IsA("ImageLabel") or d:IsA("ImageButton")) and d.Visible then
            local p = safePath(d):lower()
            local id = normAsset(d.Image)

            if id and not IGNORE_IDS[id] then
                if p:find("ingredientimagetemplate", 1, true) or d.Name:lower():find("ingredientimage", 1, true) then
                    return id
                end
            end
        end
    end

    return nil
end

local function getCurrentOrderIds()
    local frames = getVisibleRecipeFrames()
    local frame = frames[1]

    if not frame then
        return {}
    end

    local ids = {}
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
            local id = readIngredientIdFromTemplate(template)
            if id then
                table.insert(ids, id)
            end
        end
    end

    -- fallback para receita/ordem de 1 item
    if #ids == 0 then
        local recipeImage = frame:FindFirstChild("RecipeImage", true)
        if recipeImage and recipeImage:IsA("ImageLabel") and recipeImage.Visible then
            local id = normAsset(recipeImage.Image)
            if id and not IGNORE_IDS[id] then
                table.insert(ids, id)
            end
        end
    end

    return ids
end

local function makeKey(ids)
    return table.concat(ids, "|")
end

local function isIngredientName(name)
    name = string.lower(tostring(name or ""))

    if name == "" then return false end

    local bad = {
        plate = true,
        sushi = true,
        unwrapped = true,
        wrapped = true,
        weld = true,
        model = true,
        itemposition = true,
        ingredientsui = true,
        progressbar = true,
        saucepan = true,
        hob = true,
        choppingboard = true,
        countertop = true,
        platespawner = true,
        part = true,
        handle = true,
        sound = true,
        frame = true,
        icon = true,
        plusicon = true,
    }

    if bad[name] then
        return false
    end

    return true
end

local function findPlateSushiRoots()
    local roots = {}
    local interactables = workspace:FindFirstChild("Interactables") or workspace

    for _, obj in ipairs(interactables:GetDescendants()) do
        if obj:IsA("Model") and obj.Name == "Sushi" then
            local p = safePath(obj):lower()

            -- não prende em mapa fixo; só precisa estar dentro de algum Plate
            if p:find("plate", 1, true) then
                table.insert(roots, obj)
            end
        end
    end

    return roots
end

local function nearestIngredientModel(obj, sushiRoot)
    local cur = obj

    while cur and cur ~= sushiRoot do
        if cur:IsA("Model") and isIngredientName(cur.Name) then
            return cur
        end
        cur = cur.Parent
    end

    return nil
end

local function countPlacedIngredients()
    local found = {}

    for _, sushi in ipairs(findPlateSushiRoots()) do
        for _, d in ipairs(sushi:GetDescendants()) do
            if d:IsA("BasePart") or d:IsA("MeshPart") then
                local model = nearestIngredientModel(d, sushi)

                if model then
                    found[safePath(model)] = true
                elseif isIngredientName(d.Name) then
                    found[safePath(d)] = true
                end
            end
        end
    end

    local n = 0
    for _ in pairs(found) do
        n += 1
    end

    return n
end

local function updateButton()
    local ids = getCurrentOrderIds()
    local key = makeKey(ids)

    if key ~= currentKey then
        currentKey = key
        currentTotal = #ids
        pulse()
    else
        currentTotal = #ids
    end

    if currentTotal <= 0 then
        btn.Text = "-"
        btn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        return
    end

    local placed = countPlacedIngredients()
    local missing = math.max(currentTotal - placed, 0)

    if missing <= 0 then
        btn.Text = "✅"
        btn.BackgroundColor3 = Color3.fromRGB(0, 90, 35)
    else
        btn.Text = tostring(missing)
        btn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    end
end

local old = pg:FindFirstChild(GUI_NAME)
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = GUI_NAME
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = pg

local inset = GuiService:GetGuiInset()

btn = Instance.new("TextButton")
btn.Name = "Counter"
btn.Size = UDim2.new(0, 44, 0, 44)
btn.Position = UDim2.new(0, 145, 0, inset.Y - 52)
btn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
btn.TextColor3 = Color3.fromRGB(255, 255, 255)
btn.TextScaled = true
btn.Font = Enum.Font.GothamBlack
btn.Text = "-"
btn.BorderSizePixel = 0
btn.AutoButtonColor = false
btn.Active = true
btn.Parent = gui
addCorner(btn, 12)
addStroke(btn, 0.62)

btn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        holding = true
        dragging = false
        holdStarted = tick()
        dragStart = input.Position
        startPos = btn.Position
        activeInput = input

        task.delay(HOLD_TO_DRAG, function()
            if holding and activeInput == input then
                dragging = true
                TweenService:Create(btn, TweenInfo.new(0.12), {
                    BackgroundTransparency = 0.18
                }):Play()
            end
        end)
    end
end)

btn.InputEnded:Connect(function(input)
    if input == activeInput or input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        holding = false
        dragging = false
        activeInput = nil

        TweenService:Create(btn, TweenInfo.new(0.12), {
            BackgroundTransparency = 0
        }):Play()
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and dragStart and startPos then
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            btn.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end
end)

RunService.Heartbeat:Connect(function()
    if tick() - lastUpdate > 0.20 then
        lastUpdate = tick()
        pcall(updateButton)
    end
end)

warn("[CK MINIMAL] carregado.")
warn("[CK MINIMAL] Botão pequeno: número = ingredientes faltando, ✅ = prato completo.")
warn("[CK MINIMAL] Segure o botão por 0.5s para arrastar.")
