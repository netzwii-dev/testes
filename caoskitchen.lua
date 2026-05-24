--// Caos na Cozinha - Console Scanner V3 Mobile
--// Feito para jogar no console em partes pequenas, sem copiar texto gigante
--// Botões:
--// PRINT PEDIDO = mostra só pedido atual / ingredientes visíveis
--// PRINT MAPA = mostra ingredientes/estações encontrados no mapa
--// PRINT PERTO = mostra objetos próximos importantes
--// SALVAR TXT = tenta salvar em arquivo, se o executor suportar writefile

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local lp = Players.LocalPlayer

local function now()
    return os.date("%H:%M:%S")
end

local function normAsset(x)
    x = tostring(x or "")
    local id = x:match("rbxassetid://(%d+)") or x:match("id=(%d+)")
    if id then return id end
    if x:find("textures/ui/GuiImagePlaceholder") then
        return "PLACEHOLDER"
    end
    return x
end

local function path(obj)
    local ok, res = pcall(function()
        return obj:GetFullName()
    end)
    return ok and res or tostring(obj)
end

local function pos(obj)
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

local function getRoot()
    return lp:FindFirstChild("PlayerGui")
end

local function getRecipes()
    local pg = getRoot()
    if not pg then return nil end

    local root = pg:FindFirstChild("Root")
    local hud = root and root:FindFirstChild("HUD")
    return hud and hud:FindFirstChild("Recipes")
end

local function printLine(s)
    print("[CKSCAN] " .. tostring(s))
end

local function warnLine(s)
    warn("[CKSCAN] " .. tostring(s))
end

local function printSection(title, lines)
    warnLine("========== " .. title .. " | " .. now() .. " ==========")

    local chunk = {}
    local count = 0

    for _, line in ipairs(lines) do
        table.insert(chunk, line)
        count = count + 1

        if count >= 18 then
            printLine(table.concat(chunk, "\n"))
            table.clear(chunk)
            count = 0
            task.wait(0.15)
        end
    end

    if #chunk > 0 then
        printLine(table.concat(chunk, "\n"))
    end

    warnLine("========== FIM " .. title .. " ==========")
end

local function collectPedido()
    local lines = {}
    local recipes = getRecipes()

    table.insert(lines, "Player: " .. lp.Name)

    if not recipes then
        table.insert(lines, "Recipes não encontrado em PlayerGui.Root.HUD.Recipes")
        return lines
    end

    table.insert(lines, "Recipes path: " .. path(recipes))
    table.insert(lines, "")

    local recipeIndex = 0

    for _, recipeFrame in ipairs(recipes:GetChildren()) do
        if recipeFrame:IsA("GuiObject") and recipeFrame.Visible then
            local lower = recipeFrame.Name:lower()

            if lower:find("recipe") then
                recipeIndex = recipeIndex + 1
                table.insert(lines, "---- RECEITA #" .. recipeIndex .. " ----")
                table.insert(lines, "Frame: " .. path(recipeFrame))

                local recipeImage = recipeFrame:FindFirstChild("RecipeImage", true)
                if recipeImage and recipeImage:IsA("ImageLabel") then
                    table.insert(lines, "RecipeImage: " .. tostring(recipeImage.Image) .. " | id=" .. normAsset(recipeImage.Image))
                end

                local ingredientCount = 0

                for _, d in ipairs(recipeFrame:GetDescendants()) do
                    if (d:IsA("ImageLabel") or d:IsA("ImageButton")) and d.Visible then
                        local p = path(d):lower()
                        local img = tostring(d.Image or "")
                        local id = normAsset(img)

                        local isUseful =
                            p:find("ingredient") or
                            d.Name:lower():find("cookingmethod") or
                            d.Name:lower():find("recipeimage")

                        if isUseful and id ~= "PLACEHOLDER" then
                            ingredientCount += 1
                            table.insert(lines, ingredientCount .. ") UI " .. d.Name)
                            table.insert(lines, "   img=" .. img .. " | id=" .. id)
                            table.insert(lines, "   visible=" .. tostring(d.Visible) .. " size=" .. math.floor(d.AbsoluteSize.X) .. "x" .. math.floor(d.AbsoluteSize.Y))
                            table.insert(lines, "   path=" .. path(d))
                        end
                    elseif (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Visible then
                        local txt = tostring(d.Text or "")
                        if txt ~= "" and txt ~= " " then
                            table.insert(lines, "TEXT " .. d.Name .. " = " .. txt)
                            table.insert(lines, "   path=" .. path(d))
                        end
                    end
                end

                table.insert(lines, "")
            end
        end
    end

    if recipeIndex == 0 then
        table.insert(lines, "Nenhuma RecipeFrame visível achada. Vou listar imagens úteis dentro de Recipes:")
        for _, d in ipairs(recipes:GetDescendants()) do
            if (d:IsA("ImageLabel") or d:IsA("ImageButton")) and d.Visible then
                local p = path(d):lower()
                local id = normAsset(d.Image)
                if p:find("recipe") or p:find("ingredient") or p:find("cooking") then
                    table.insert(lines, d.Name .. " | id=" .. id .. " | path=" .. path(d))
                end
            end
        end
    end

    return lines
end

local function objectImages(obj)
    local out = {}

    for _, d in ipairs(obj:GetDescendants()) do
        if d:IsA("Decal") or d:IsA("Texture") then
            table.insert(out, d.ClassName .. " " .. d.Name .. " texture=" .. tostring(d.Texture) .. " id=" .. normAsset(d.Texture))
        elseif d:IsA("ImageLabel") or d:IsA("ImageButton") then
            table.insert(out, d.ClassName .. " " .. d.Name .. " image=" .. tostring(d.Image) .. " id=" .. normAsset(d.Image))
        elseif d:IsA("MeshPart") then
            local tid = tostring(d.TextureID or "")
            if tid ~= "" then
                table.insert(out, "MeshPart " .. d.Name .. " textureID=" .. tid .. " id=" .. normAsset(tid))
            end
        elseif d:IsA("SpecialMesh") then
            local tid = tostring(d.TextureId or "")
            if tid ~= "" then
                table.insert(out, "SpecialMesh " .. d.Name .. " textureId=" .. tid .. " id=" .. normAsset(tid))
            end
        end
    end

    return out
end

local function attrs(obj)
    local out = {}

    for k, v in pairs(obj:GetAttributes()) do
        table.insert(out, tostring(k) .. "=" .. tostring(v))
    end

    return out
end

local function collectMapa()
    local lines = {}
    local root = workspace:FindFirstChild("Interactables") or workspace

    table.insert(lines, "Root: " .. path(root))
    table.insert(lines, "")

    local keys = {
        "FoodBin",
        "Seaweed",
        "Rice",
        "Salmon",
        "Cucumber",
        "Tuna",
        "Shrimp",
        "Fish",
        "Plate",
        "Dish",
        "ChoppingBoard",
        "Countertop",
        "Stove",
        "Pot",
        "Pan",
        "Appliance",
    }

    local found = {}
    local used = {}

    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("Folder") or obj:IsA("BasePart") then
            local n = obj.Name:lower()

            for _, key in ipairs(keys) do
                if n:find(key:lower(), 1, true) then
                    local p = path(obj)

                    -- evita listar peça demais dentro do mesmo model
                    local model = obj:IsA("Model") and obj or obj:FindFirstAncestorOfClass("Model")
                    if model and model:IsDescendantOf(root) then
                        p = path(model)
                        obj = model
                    end

                    if not used[p] then
                        used[p] = true
                        table.insert(found, obj)
                    end

                    break
                end
            end
        end
    end

    table.insert(lines, "Encontrados: " .. tostring(#found))
    table.insert(lines, "")

    for i, obj in ipairs(found) do
        table.insert(lines, "---- OBJ #" .. i .. " ----")
        table.insert(lines, "Name: " .. obj.Name .. " [" .. obj.ClassName .. "]")
        table.insert(lines, "Path: " .. path(obj))
        table.insert(lines, "Pos: " .. pos(obj))

        local a = attrs(obj)
        if #a > 0 then
            table.insert(lines, "Attributes:")
            for _, x in ipairs(a) do
                table.insert(lines, "  " .. x)
            end
        end

        local imgs = objectImages(obj)
        if #imgs > 0 then
            table.insert(lines, "Images/Meshes:")
            for _, x in ipairs(imgs) do
                table.insert(lines, "  " .. x)
            end
        end

        local childNames = {}
        for _, c in ipairs(obj:GetChildren()) do
            table.insert(childNames, c.Name .. "[" .. c.ClassName .. "]")
        end

        if #childNames > 0 then
            table.insert(lines, "Children: " .. table.concat(childNames, ", "))
        end

        table.insert(lines, "")
    end

    return lines
end

local function collectPerto()
    local lines = {}
    local char = lp.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    if not hrp then
        table.insert(lines, "HumanoidRootPart não encontrado")
        return lines
    end

    local root = workspace:FindFirstChild("Interactables") or workspace
    local radius = 18
    local found = {}

    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("BasePart") then
            local dist = (obj.Position - hrp.Position).Magnitude
            if dist <= radius then
                local model = obj:FindFirstAncestorOfClass("Model")
                table.insert(found, {
                    dist = dist,
                    obj = model or obj,
                    part = obj
                })
            end
        end
    end

    table.sort(found, function(a, b)
        return a.dist < b.dist
    end)

    local used = {}
    for _, item in ipairs(found) do
        local obj = item.obj
        local p = path(obj)

        if not used[p] then
            used[p] = true
            table.insert(lines, "[" .. math.floor(item.dist) .. " studs] " .. obj.Name .. " [" .. obj.ClassName .. "]")
            table.insert(lines, "Path: " .. p)
            table.insert(lines, "Part: " .. item.part.Name)
            table.insert(lines, "Pos: " .. pos(obj))

            local imgs = objectImages(obj)
            for i = 1, math.min(#imgs, 4) do
                table.insert(lines, "  " .. imgs[i])
            end

            table.insert(lines, "")
        end
    end

    return lines
end

local lastDump = ""

local function saveTxt(title, lines)
    local txt = "CAOS NA COZINHA " .. title .. "\nPlayer: " .. lp.Name .. "\nTime: " .. now() .. "\n\n" .. table.concat(lines, "\n")
    lastDump = txt

    if writefile then
        local filename = "caos_kitchen_" .. title:gsub("%s+", "_"):lower() .. ".txt"
        writefile(filename, txt)
        warnLine("Arquivo salvo: " .. filename)
    else
        warnLine("writefile não suportado pelo executor")
    end

    if setclipboard then
        local small = txt:sub(1, 4500)
        setclipboard(small)
        warnLine("Primeiros 4500 caracteres copiados também")
    end
end

local function makeGui()
    local old = lp.PlayerGui:FindFirstChild("CKConsoleScannerV3")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "CKConsoleScannerV3"
    gui.ResetOnSpawn = false
    gui.Parent = lp:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 190, 0, 205)
    frame.Position = UDim2.new(0, 15, 0.35, 0)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    frame.BackgroundTransparency = 0.12
    frame.Parent = gui

    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -10, 0, 30)
    title.Position = UDim2.new(0, 5, 0, 5)
    title.BackgroundTransparency = 1
    title.Text = "CK Scanner V3"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.Parent = frame

    local function btn(text, y, cb)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -20, 0, 35)
        b.Position = UDim2.new(0, 10, 0, y)
        b.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.TextScaled = true
        b.Font = Enum.Font.GothamBold
        b.Text = text
        b.Parent = frame
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)

        b.MouseButton1Click:Connect(function()
            b.Text = "AGUARDE..."
            task.spawn(function()
                pcall(cb)
                task.wait(0.8)
                b.Text = text
            end)
        end)
    end

    btn("PRINT PEDIDO", 42, function()
        local lines = collectPedido()
        printSection("PEDIDO", lines)
        saveTxt("PEDIDO", lines)
    end)

    btn("PRINT MAPA", 82, function()
        local lines = collectMapa()
        printSection("MAPA", lines)
        saveTxt("MAPA", lines)
    end)

    btn("PRINT PERTO", 122, function()
        local lines = collectPerto()
        printSection("PERTO", lines)
        saveTxt("PERTO", lines)
    end)

    btn("DESTRUIR GUI", 162, function()
        gui:Destroy()
    end)
end

makeGui()
warnLine("Scanner V3 carregado. Abra o console e use PRINT PEDIDO / PRINT MAPA / PRINT PERTO.")
