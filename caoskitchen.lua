--// Caos na Cozinha - Auto ESP v1
--// Detecta ingredientes do pedido atual pelo ID do ícone
--// Mostra chams no FoodBin do ingrediente atual
--// Depois mostra chams na faca/mesa de corte ou no prato
--// Feito para mobile. Tem botões: ESP ON/OFF, PRÓXIMO e RESET.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local lp = Players.LocalPlayer

-- ids que NÃO são ingrediente real
local IGNORE_IDS = {
    ["140157429295813"] = true, -- fundo/template do ingrediente
    ["133105772499368"] = true,
    ["72733766243904"] = true,
    ["75742169776390"] = true,
    ["125425887763635"] = true, -- ícone genérico/algum método, não usar como ingrediente
}

-- métodos conhecidos pelo scan
-- se aparecer algum CookingMethod, o script vai mandar para preparar/cortar.
-- se algum método não precisar cortar, coloque false aqui.
local METHOD_NEEDS_PREPARE = {
    ["102782857320968"] = true,
    ["123188384272883"] = true,
    ["125425887763635"] = true,
}

local ESP = {
    Enabled = true,
    Target = nil,
    Highlight = nil,
    Billboard = nil,
}

local State = {
    OrderKey = "",
    Items = {},
    Index = 1,
    Stage = "GET", -- GET / PREPARE / PLATE
    LastHolding = false,
}

local function normAsset(x)
    x = tostring(x or "")
    local id = x:match("rbxassetid://(%d+)") or x:match("id=(%d+)")
    if id then return id end
    return nil
end

local function getPath(obj)
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

    if not obj then return nil end

    if obj:IsA("BasePart") then
        part = obj
    elseif obj:IsA("Model") then
        part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
    else
        part = obj:FindFirstAncestorWhichIsA("BasePart")
    end

    return part and part.Position or nil
end

local function getAdornee(obj)
    if not obj then return nil end

    if obj:IsA("Model") or obj:IsA("BasePart") then
        return obj
    end

    return obj:FindFirstAncestorOfClass("Model") or obj:FindFirstAncestorWhichIsA("BasePart")
end

local function destroyESP()
    if ESP.Highlight then
        ESP.Highlight:Destroy()
        ESP.Highlight = nil
    end

    if ESP.Billboard then
        ESP.Billboard:Destroy()
        ESP.Billboard = nil
    end

    ESP.Target = nil
end

local function makeESP(obj, text)
    if not ESP.Enabled then
        destroyESP()
        return
    end

    local adornee = getAdornee(obj)
    if not adornee then
        destroyESP()
        return
    end

    if ESP.Target == adornee then
        if ESP.Billboard and ESP.Billboard:FindFirstChildOfClass("TextLabel") then
            ESP.Billboard:FindFirstChildOfClass("TextLabel").Text = text
        end
        return
    end

    destroyESP()
    ESP.Target = adornee

    local h = Instance.new("Highlight")
    h.Name = "CaosKitchenAutoESP"
    h.Adornee = adornee
    h.FillColor = Color3.fromRGB(255, 0, 0)
    h.OutlineColor = Color3.fromRGB(255, 255, 255)
    h.FillTransparency = 0.35
    h.OutlineTransparency = 0
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Parent = game.CoreGui
    ESP.Highlight = h

    local part
    if adornee:IsA("BasePart") then
        part = adornee
    else
        part = adornee.PrimaryPart or adornee:FindFirstChildWhichIsA("BasePart", true)
    end

    if part then
        local bb = Instance.new("BillboardGui")
        bb.Name = "CaosKitchenAutoESPLabel"
        bb.Adornee = part
        bb.Size = UDim2.new(0, 210, 0, 42)
        bb.StudsOffset = Vector3.new(0, 3.5, 0)
        bb.AlwaysOnTop = true
        bb.Parent = game.CoreGui

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        label.BackgroundTransparency = 0.22
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextStrokeTransparency = 0
        label.TextScaled = true
        label.Font = Enum.Font.GothamBold
        label.Text = text
        label.Parent = bb

        Instance.new("UICorner", label).CornerRadius = UDim.new(0, 8)
        ESP.Billboard = bb
    end
end

local function objHasId(obj, wantedId)
    if not wantedId then return false end

    for _, d in ipairs(obj:GetDescendants()) do
        local id

        if d:IsA("Decal") or d:IsA("Texture") then
            id = normAsset(d.Texture)
        elseif d:IsA("ImageLabel") or d:IsA("ImageButton") then
            id = normAsset(d.Image)
        elseif d:IsA("MeshPart") then
            id = normAsset(d.TextureID)
        elseif d:IsA("SpecialMesh") then
            id = normAsset(d.TextureId)
        end

        if id == wantedId then
            return true, d
        end
    end

    return false, nil
end

local function getRecipesRoot()
    local pg = lp:FindFirstChild("PlayerGui")
    local root = pg and pg:FindFirstChild("Root")
    local hud = root and root:FindFirstChild("HUD")
    return hud and hud:FindFirstChild("Recipes")
end

local function visibleRecipeFrames()
    local recipes = getRecipesRoot()
    local frames = {}

    if not recipes then return frames end

    for _, child in ipairs(recipes:GetChildren()) do
        if child:IsA("GuiObject") and child.Visible and child.Name:lower():find("recipe") then
            table.insert(frames, child)
        end
    end

    return frames
end

local function getOrderItems()
    local items = {}

    for _, frame in ipairs(visibleRecipeFrames()) do
        local recipeImage = frame:FindFirstChild("RecipeImage", true)
        if recipeImage and recipeImage:IsA("ImageLabel") and recipeImage.Visible then
            local id = normAsset(recipeImage.Image)
            if id and not IGNORE_IDS[id] then
                table.insert(items, {
                    id = id,
                    method = nil,
                    source = "RecipeImage",
                })
            end
        end

        local ingredientsFolder = frame:FindFirstChild("Ingredients", true)
        if ingredientsFolder then
            for _, ingTemplate in ipairs(ingredientsFolder:GetChildren()) do
                if ingTemplate:IsA("GuiObject") and ingTemplate.Visible then
                    local ingredientId
                    local methodId

                    local cookingMethod = ingTemplate:FindFirstChild("CookingMethod", true)
                    if cookingMethod and (cookingMethod:IsA("ImageLabel") or cookingMethod:IsA("ImageButton")) and cookingMethod.Visible then
                        methodId = normAsset(cookingMethod.Image)
                    end

                    for _, d in ipairs(ingTemplate:GetDescendants()) do
                        if (d:IsA("ImageLabel") or d:IsA("ImageButton")) and d.Visible then
                            local p = getPath(d):lower()
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
                        table.insert(items, {
                            id = ingredientId,
                            method = methodId,
                            source = "IngredientTemplate",
                        })
                    end
                end
            end
        end
    end

    -- remove repetição em sequência, mas mantém ordem
    local clean = {}
    local lastKey = ""

    for _, item in ipairs(items) do
        local key = item.id .. "|" .. tostring(item.method)
        if key ~= lastKey then
            table.insert(clean, item)
            lastKey = key
        end
    end

    return clean
end

local function orderKey(items)
    local parts = {}

    for _, item in ipairs(items) do
        table.insert(parts, item.id .. ":" .. tostring(item.method))
    end

    return table.concat(parts, ",")
end

local function findFoodBinById(id)
    local root = workspace:FindFirstChild("Interactables") or workspace
    local hrp = getHRP()
    if not hrp then return nil end

    local best
    local bestDist = math.huge

    local foodBins = root:FindFirstChild("FoodBins")
    local searchRoot = foodBins or root

    for _, obj in ipairs(searchRoot:GetDescendants()) do
        if obj:IsA("Model") and obj.Name:lower():find("foodbin", 1, true) then
            local has = objHasId(obj, id)
            if has then
                local p = getPos(obj)
                if p then
                    local dist = (p - hrp.Position).Magnitude
                    if dist < bestDist then
                        best = obj
                        bestDist = dist
                    end
                end
            end
        end
    end

    -- fallback: às vezes o Model tem nome igual mas fica duplicado estranho
    if not best then
        for _, obj in ipairs(searchRoot:GetDescendants()) do
            if obj:IsA("Model") then
                local has, matched = objHasId(obj, id)
                if has and matched and getPath(matched):lower():find("foodbins") then
                    local p = getPos(obj)
                    if p then
                        local dist = (p - hrp.Position).Magnitude
                        if dist < bestDist then
                            best = obj
                            bestDist = dist
                        end
                    end
                end
            end
        end
    end

    return best
end

local function findNearestByNames(names)
    local root = workspace:FindFirstChild("Interactables") or workspace
    local hrp = getHRP()
    if not hrp then return nil end

    local best
    local bestDist = math.huge

    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("BasePart") then
            local n = obj.Name:lower()

            for _, key in ipairs(names) do
                if n:find(key:lower(), 1, true) then
                    local p = getPos(obj)
                    if p then
                        local dist = (p - hrp.Position).Magnitude
                        if dist < bestDist then
                            best = obj
                            bestDist = dist
                        end
                    end
                    break
                end
            end
        end
    end

    return best
end

local function findPlate()
    local root = workspace:FindFirstChild("Interactables") or workspace
    local hrp = getHRP()
    if not hrp then return nil end

    local best
    local bestDist = math.huge

    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("BasePart") then
            local n = obj.Name:lower()
            local pth = getPath(obj):lower()

            if n:find("plate", 1, true) or pth:find(".plate", 1, true) or n:find("dish", 1, true) then
                local p = getPos(obj)
                if p then
                    local dist = (p - hrp.Position).Magnitude
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

local function findChoppingBoard()
    return findNearestByNames({"ChoppingBoard", "chopping", "knife", "cut"})
end

local function findCookStation()
    return findNearestByNames({"Stove", "Pot", "Pan", "Cook"})
end

local function holdingSomething()
    local char = lp.Character
    if not char then return false end

    for _, v in ipairs(char:GetChildren()) do
        if v:IsA("Tool") then
            return true, v.Name
        end
    end

    -- alguns jogos grudam o item como parte/model no personagem
    for _, v in ipairs(char:GetDescendants()) do
        local n = v.Name:lower()

        if n:find("food", 1, true)
            or n:find("ingredient", 1, true)
            or n:find("rice", 1, true)
            or n:find("seaweed", 1, true)
            or n:find("salmon", 1, true)
            or n:find("cucumber", 1, true)
            or n:find("tuna", 1, true)
            or n:find("shrimp", 1, true)
            or n:find("fish", 1, true) then
            return true, v.Name
        end
    end

    return false, nil
end

local function nextStage()
    local item = State.Items[State.Index]

    if not item then
        State.Index = 1
        State.Stage = "GET"
        return
    end

    if State.Stage == "GET" then
        if item.method and METHOD_NEEDS_PREPARE[item.method] then
            State.Stage = "PREPARE"
        else
            State.Stage = "PLATE"
        end
    elseif State.Stage == "PREPARE" then
        State.Stage = "PLATE"
    else
        State.Index += 1
        State.Stage = "GET"

        if State.Index > #State.Items then
            State.Index = 1
        end
    end
end

local function resetState()
    State.Index = 1
    State.Stage = "GET"
    destroyESP()
end

local function updateLogic()
    local items = getOrderItems()
    local key = orderKey(items)

    if key ~= "" and key ~= State.OrderKey then
        State.OrderKey = key
        State.Items = items
        State.Index = 1
        State.Stage = "GET"
        destroyESP()
    elseif key ~= "" then
        State.Items = items
    end

    if #State.Items == 0 then
        destroyESP()
        return
    end

    if State.Index > #State.Items then
        State.Index = 1
        State.Stage = "GET"
    end

    local holding = holdingSomething()

    -- tentativa de automático:
    -- pegou algo -> vai preparar/prato
    -- soltou algo no prato/mesa -> avança para próximo ingrediente
    if holding and not State.LastHolding then
        if State.Stage == "GET" then
            nextStage()
        end
    elseif not holding and State.LastHolding then
        if State.Stage == "PREPARE" then
            State.Stage = "PLATE"
        elseif State.Stage == "PLATE" then
            State.Index += 1
            State.Stage = "GET"
            if State.Index > #State.Items then
                State.Index = 1
            end
        end
    end

    State.LastHolding = holding

    local item = State.Items[State.Index]
    local target
    local label = ""

    if State.Stage == "GET" then
        target = findFoodBinById(item.id)
        label = "PEGAR " .. State.Index .. "/" .. #State.Items

    elseif State.Stage == "PREPARE" then
        target = findChoppingBoard() or findCookStation()
        label = "PREPARAR " .. State.Index .. "/" .. #State.Items

    elseif State.Stage == "PLATE" then
        target = findPlate()
        label = "LEVAR AO PRATO " .. State.Index .. "/" .. #State.Items
    end

    if target then
        makeESP(target, label)
    else
        destroyESP()
    end
end

RunService.RenderStepped:Connect(function()
    if not ESP.Enabled then
        destroyESP()
        return
    end

    pcall(updateLogic)
end)

-- GUI MOBILE
local function makeGui()
    local old = lp.PlayerGui:FindFirstChild("CaosKitchenAutoESP_GUI")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "CaosKitchenAutoESP_GUI"
    gui.ResetOnSpawn = false
    gui.Parent = lp:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 190, 0, 170)
    frame.Position = UDim2.new(0, 15, 0.35, 0)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    frame.BackgroundTransparency = 0.15
    frame.Parent = gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -10, 0, 32)
    title.Position = UDim2.new(0, 5, 0, 5)
    title.BackgroundTransparency = 1
    title.Text = "Caos ESP"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.Parent = frame

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -10, 0, 26)
    status.Position = UDim2.new(0, 5, 0, 137)
    status.BackgroundTransparency = 1
    status.TextColor3 = Color3.fromRGB(255, 255, 255)
    status.TextScaled = true
    status.Font = Enum.Font.Gotham
    status.Text = "carregando..."
    status.Parent = frame

    local function btn(text, y, cb)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -20, 0, 30)
        b.Position = UDim2.new(0, 10, 0, y)
        b.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.TextScaled = true
        b.Font = Enum.Font.GothamBold
        b.Text = text
        b.Parent = frame
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)

        b.MouseButton1Click:Connect(cb)
        return b
    end

    local toggleBtn
    toggleBtn = btn("ESP: ON", 42, function()
        ESP.Enabled = not ESP.Enabled
        toggleBtn.Text = ESP.Enabled and "ESP: ON" or "ESP: OFF"
        if not ESP.Enabled then destroyESP() end
    end)

    btn("PRÓXIMO", 77, function()
        nextStage()
    end)

    btn("RESET", 112, function()
        resetState()
    end)

    task.spawn(function()
        while gui.Parent do
            status.Text = State.Stage .. " | " .. tostring(State.Index) .. "/" .. tostring(#State.Items)
            task.wait(0.25)
        end
    end)
end

makeGui()
warn("[Caos ESP] carregado.")
