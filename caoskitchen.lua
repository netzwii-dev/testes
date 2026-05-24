--// Caos na Cozinha - ESP automático por imagem do pedido
--// tenta detectar ingrediente automaticamente pelo ícone/asset id

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local lp = Players.LocalPlayer

local ESP = {
    Enabled = true,
    CurrentHighlight = nil,
    CurrentBillboard = nil,
    CurrentTarget = nil,
}

local SETTINGS = {
    SearchRoot = workspace:FindFirstChild("Interactables") or workspace,
    RecipeRootPath = {"Root", "HUD", "Recipes"},

    -- nomes prováveis das estações
    CutNames = {"chopping", "cut", "knife", "faca"},
    CookNames = {"stove", "pot", "pan", "cook", "panela", "fogao", "fogão"},
    PlateNames = {"plate", "dish", "prato", "countertop"},

    -- nomes que geralmente representam ingredientes
    IngredientContainerNames = {"foodbin", "seaweed", "rice", "salmon", "cucumber", "tuna", "shrimp", "fish"},
}

local function normAsset(x)
    x = tostring(x or "")
    local id = x:match("rbxassetid://(%d+)") or x:match("rbxasset://(%d+)") or x:match("id=(%d+)") or x:match("(%d+)")
    return id
end

local function getPath(root, path)
    local cur = root
    for _, name in ipairs(path) do
        cur = cur and cur:FindFirstChild(name)
    end
    return cur
end

local function getChar()
    return lp.Character or lp.CharacterAdded:Wait()
end

local function getHRP()
    return getChar():FindFirstChild("HumanoidRootPart")
end

local function getPos(obj)
    if not obj then return nil end

    if obj:IsA("BasePart") then
        return obj.Position
    end

    if obj:IsA("Model") then
        local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
        return part and part.Position
    end

    local part = obj:FindFirstAncestorWhichIsA("BasePart")
    return part and part.Position
end

local function getAdornee(obj)
    if not obj then return nil end

    if obj:IsA("Model") or obj:IsA("BasePart") then
        return obj
    end

    return obj:FindFirstAncestorOfClass("Model") or obj:FindFirstAncestorWhichIsA("BasePart")
end

local function hasName(obj, names)
    local n = string.lower(obj.Name)

    for _, key in ipairs(names) do
        key = string.lower(key)
        if string.find(n, key, 1, true) then
            return true
        end
    end

    return false
end

local function destroyESP()
    if ESP.CurrentHighlight then
        ESP.CurrentHighlight:Destroy()
        ESP.CurrentHighlight = nil
    end

    if ESP.CurrentBillboard then
        ESP.CurrentBillboard:Destroy()
        ESP.CurrentBillboard = nil
    end

    ESP.CurrentTarget = nil
end

local function makeESP(obj, text)
    local adornee = getAdornee(obj)
    if not adornee then return end
    if ESP.CurrentTarget == adornee then return end

    destroyESP()

    ESP.CurrentTarget = adornee

    local h = Instance.new("Highlight")
    h.Name = "CaosKitchenESP"
    h.Adornee = adornee
    h.FillColor = Color3.fromRGB(255, 0, 0)
    h.OutlineColor = Color3.fromRGB(255, 255, 255)
    h.FillTransparency = 0.35
    h.OutlineTransparency = 0
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Parent = game.CoreGui

    ESP.CurrentHighlight = h

    local part
    if adornee:IsA("BasePart") then
        part = adornee
    elseif adornee:IsA("Model") then
        part = adornee.PrimaryPart or adornee:FindFirstChildWhichIsA("BasePart", true)
    end

    if part then
        local bb = Instance.new("BillboardGui")
        bb.Name = "CaosKitchenLabel"
        bb.Adornee = part
        bb.Size = UDim2.new(0, 190, 0, 42)
        bb.StudsOffset = Vector3.new(0, 3.5, 0)
        bb.AlwaysOnTop = true
        bb.Parent = game.CoreGui

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        label.BackgroundTransparency = 0.25
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextStrokeTransparency = 0
        label.TextScaled = true
        label.Font = Enum.Font.GothamBold
        label.Text = text
        label.Parent = bb

        Instance.new("UICorner", label).CornerRadius = UDim.new(0, 8)

        ESP.CurrentBillboard = bb
    end
end

local function getVisibleRecipeImages()
    local recipes = getPath(lp.PlayerGui, SETTINGS.RecipeRootPath)
    if not recipes then return {} end

    local result = {}

    for _, ui in ipairs(recipes:GetDescendants()) do
        if ui:IsA("ImageLabel") or ui:IsA("ImageButton") then
            local img = tostring(ui.Image or "")
            local id = normAsset(img)
            local size = ui.AbsoluteSize

            if ui.Visible and id and img ~= "" and size.X > 10 and size.Y > 10 then
                table.insert(result, {
                    ui = ui,
                    name = ui.Name,
                    image = img,
                    id = id,
                    pos = ui.AbsolutePosition,
                    size = ui.AbsoluteSize,
                    path = ui:GetFullName(),
                })
            end
        end
    end

    return result
end

local function isIngredientUI(info)
    local path = string.lower(info.path)
    local name = string.lower(info.name)

    if string.find(path, "ingredient", 1, true) then
        if not string.find(name, "template", 1, true) then
            return true
        end
    end

    -- às vezes o template visível é o próprio item
    if string.find(path, "ingredients", 1, true) and info.id ~= normAsset("rbxasset://textures/ui/GuiImagePlaceholder.png") then
        return true
    end

    return false
end

local function getCurrentIngredientAsset()
    local imgs = getVisibleRecipeImages()

    -- prioridade: imagens dentro de Ingredients
    for _, info in ipairs(imgs) do
        if isIngredientUI(info) then
            if info.id and not string.find(info.image, "Placeholder") then
                return info.id, info
            end
        end
    end

    -- fallback: pega imagem pequena do pedido
    for _, info in ipairs(imgs) do
        local path = string.lower(info.path)

        if string.find(path, "recipe", 1, true)
            and not string.find(path, "border", 1, true)
            and not string.find(path, "timer", 1, true)
            and not string.find(info.name:lower(), "border", 1, true) then

            return info.id, info
        end
    end

    return nil, nil
end

local function getCookingMethodAsset()
    local recipes = getPath(lp.PlayerGui, SETTINGS.RecipeRootPath)
    if not recipes then return nil end

    for _, ui in ipairs(recipes:GetDescendants()) do
        if ui:IsA("ImageLabel") or ui:IsA("ImageButton") then
            local path = string.lower(ui:GetFullName())
            if ui.Visible and string.find(path, "cookingmethod", 1, true) then
                return normAsset(ui.Image), ui
            end
        end
    end

    return nil, nil
end

local function objectHasAsset(obj, wantedId)
    if not wantedId then return false end

    for _, d in ipairs(obj:GetDescendants()) do
        if d:IsA("Decal") or d:IsA("Texture") then
            if normAsset(d.Texture) == wantedId then
                return true
            end

        elseif d:IsA("ImageLabel") or d:IsA("ImageButton") then
            if normAsset(d.Image) == wantedId then
                return true
            end

        elseif d:IsA("MeshPart") then
            if normAsset(d.TextureID) == wantedId then
                return true
            end

        elseif d:IsA("SpecialMesh") then
            if normAsset(d.TextureId) == wantedId then
                return true
            end
        end
    end

    return false
end

local function findIngredientByAsset(assetId)
    local root = SETTINGS.SearchRoot
    local hrp = getHRP()
    if not root or not hrp or not assetId then return nil end

    local best
    local bestDist = math.huge

    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("Folder") then
            if hasName(obj, SETTINGS.IngredientContainerNames) or objectHasAsset(obj, assetId) then
                if objectHasAsset(obj, assetId) then
                    local pos = getPos(obj)
                    if pos then
                        local dist = (pos - hrp.Position).Magnitude
                        if dist < bestDist then
                            best = obj
                            bestDist = dist
                        end
                    end
                end
            end
        elseif obj:IsA("BasePart") then
            if objectHasAsset(obj, assetId) then
                local pos = getPos(obj)
                if pos then
                    local dist = (pos - hrp.Position).Magnitude
                    if dist < bestDist then
                        best = obj
                        bestDist = dist
                    end
                end
            end
        end
    end

    return best
end

local function findNearestByNames(names)
    local root = SETTINGS.SearchRoot
    local hrp = getHRP()
    if not root or not hrp then return nil end

    local best
    local bestDist = math.huge

    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("BasePart") then
            if hasName(obj, names) then
                local pos = getPos(obj)
                if pos then
                    local dist = (pos - hrp.Position).Magnitude
                    if dist < bestDist then
                        best = obj
                        bestDist = dist
                    end
                end
            end
        end
    end

    return best
end

local function isHoldingItem()
    local char = getChar()

    for _, v in ipairs(char:GetChildren()) do
        if v:IsA("Tool") then
            return true, v.Name
        end
    end

    -- alguns jogos grudam o item como Model/Part no personagem
    for _, v in ipairs(char:GetDescendants()) do
        local n = string.lower(v.Name)

        if string.find(n, "food", 1, true)
            or string.find(n, "ingredient", 1, true)
            or string.find(n, "seaweed", 1, true)
            or string.find(n, "rice", 1, true)
            or string.find(n, "salmon", 1, true)
            or string.find(n, "cucumber", 1, true)
            or string.find(n, "fish", 1, true) then
            return true, v.Name
        end
    end

    return false, nil
end

local stage = "getIngredient"
local lastIngredientAsset = nil
local lastHolding = false

RunService.RenderStepped:Connect(function()
    if not ESP.Enabled then
        destroyESP()
        return
    end

    local ingredientAsset = getCurrentIngredientAsset()
    if not ingredientAsset then
        destroyESP()
        return
    end

    if ingredientAsset ~= lastIngredientAsset then
        lastIngredientAsset = ingredientAsset
        stage = "getIngredient"
    end

    local holding = isHoldingItem()

    if holding and not lastHolding then
        local methodAsset = getCookingMethodAsset()

        -- por enquanto tenta decidir pela imagem/nome do cooking method.
        -- se não souber, manda para cortar primeiro, porque sushi geralmente precisa cortar.
        stage = "prepare"
    elseif not holding and lastHolding then
        stage = "getIngredient"
    end

    lastHolding = holding

    if stage == "getIngredient" then
        local target = findIngredientByAsset(ingredientAsset)

        if target then
            makeESP(target, "PEGAR INGREDIENTE")
        else
            destroyESP()
        end

    elseif stage == "prepare" then
        local methodId = getCookingMethodAsset()
        local target

        -- sem mapa dos ícones ainda, então tenta achar estação mais provável.
        -- se tiver ChoppingBoard no mapa, usa ele primeiro.
        target = findNearestByNames(SETTINGS.CutNames)

        if target then
            makeESP(target, "PREPARAR / CORTAR")
        else
            target = findNearestByNames(SETTINGS.CookNames)
            if target then
                makeESP(target, "COZINHAR")
            else
                target = findNearestByNames(SETTINGS.PlateNames)
                if target then
                    makeESP(target, "LEVAR AO PRATO")
                end
            end
        end
    end
end)

-- botão mobile liga/desliga
local gui = Instance.new("ScreenGui")
gui.Name = "CaosKitchenAutoESPButton"
gui.ResetOnSpawn = false
gui.Parent = lp:WaitForChild("PlayerGui")

local btn = Instance.new("TextButton")
btn.Size = UDim2.new(0, 135, 0, 42)
btn.Position = UDim2.new(0, 20, 0.35, 0)
btn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
btn.TextColor3 = Color3.fromRGB(255, 255, 255)
btn.TextScaled = true
btn.Font = Enum.Font.GothamBold
btn.Text = "ESP: ON"
btn.Parent = gui

Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

btn.MouseButton1Click:Connect(function()
    ESP.Enabled = not ESP.Enabled
    btn.Text = ESP.Enabled and "ESP: ON" or "ESP: OFF"

    if not ESP.Enabled then
        destroyESP()
    end
end)
