--// Caos na Cozinha - Scanner V4 FOCADO
--// Não imprime o mapa inteiro. Ele pega os IDS do pedido atual
--// e procura no workspace só objetos que tenham esses mesmos IDS.
--// Melhor para mobile/console.

local Players = game:GetService("Players")
local lp = Players.LocalPlayer

local function normAsset(x)
    x = tostring(x or "")
    local id = x:match("rbxassetid://(%d+)") or x:match("id=(%d+)")
    if id then return id end
    if x:find("textures/ui/GuiImagePlaceholder") then return nil end
    return nil
end

local function getPath(obj)
    local ok, res = pcall(function()
        return obj:GetFullName()
    end)
    return ok and res or tostring(obj)
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

    if not part then return "sem pos" end
    return math.floor(part.Position.X) .. "," .. math.floor(part.Position.Y) .. "," .. math.floor(part.Position.Z)
end

local function printBlock(title, lines)
    warn("[CK V4] ===== " .. title .. " =====")
    local buf = {}

    for i, line in ipairs(lines) do
        table.insert(buf, line)

        if #buf >= 12 then
            print("[CK V4]\n" .. table.concat(buf, "\n"))
            table.clear(buf)
            task.wait(0.12)
        end
    end

    if #buf > 0 then
        print("[CK V4]\n" .. table.concat(buf, "\n"))
    end

    warn("[CK V4] ===== FIM " .. title .. " =====")
end

local function getRecipesRoot()
    local pg = lp:FindFirstChild("PlayerGui")
    local root = pg and pg:FindFirstChild("Root")
    local hud = root and root:FindFirstChild("HUD")
    return hud and hud:FindFirstChild("Recipes")
end

local function collectCurrentRecipeIds()
    local recipes = getRecipesRoot()
    local ids = {}
    local lines = {}

    if not recipes then
        return ids, {"Recipes não encontrado"}
    end

    for _, ui in ipairs(recipes:GetDescendants()) do
        if (ui:IsA("ImageLabel") or ui:IsA("ImageButton")) and ui.Visible then
            local p = getPath(ui):lower()
            local id = normAsset(ui.Image)

            if id then
                local useful =
                    p:find("recipeimage") or
                    p:find("ingredientimagetemplate") or
                    p:find("cookingmethod")

                if useful then
                    table.insert(ids, id)
                    table.insert(lines, ui.Name .. " = " .. id .. " | " .. getPath(ui))
                end
            end
        end
    end

    local unique = {}
    local clean = {}

    for _, id in ipairs(ids) do
        if not unique[id] then
            unique[id] = true
            table.insert(clean, id)
        end
    end

    return clean, lines
end

local function objHasId(obj, wanted)
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

        if id and wanted[id] then
            return id, d
        end
    end

    return nil, nil
end

local function importantAncestor(obj)
    local cur = obj

    while cur and cur ~= workspace do
        local n = cur.Name:lower()

        if n:find("foodbin", 1, true)
            or n:find("seaweed", 1, true)
            or n:find("rice", 1, true)
            or n:find("salmon", 1, true)
            or n:find("cucumber", 1, true)
            or n:find("tuna", 1, true)
            or n:find("shrimp", 1, true)
            or n:find("fish", 1, true)
            or n:find("chopping", 1, true)
            or n:find("countertop", 1, true)
            or n:find("plate", 1, true)
            or n:find("dish", 1, true)
            or n:find("pot", 1, true)
            or n:find("stove", 1, true)
            or n:find("pan", 1, true) then
            return cur
        end

        cur = cur.Parent
    end

    return obj:FindFirstAncestorOfClass("Model") or obj
end

local function scanMatchingRecipeIds()
    local ids, recipeLines = collectCurrentRecipeIds()
    local wanted = {}
    local lines = {}

    table.insert(lines, "IDS DO PEDIDO ATUAL:")
    for _, l in ipairs(recipeLines) do
        table.insert(lines, "  " .. l)
    end

    table.insert(lines, "")
    table.insert(lines, "MATCHES NO MAPA:")

    for _, id in ipairs(ids) do
        wanted[id] = true
    end

    local root = workspace:FindFirstChild("Interactables") or workspace
    local used = {}
    local count = 0

    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("Folder") or obj:IsA("BasePart") then
            local matchedId, matchedObj = objHasId(obj, wanted)

            if matchedId then
                local target = importantAncestor(matchedObj)
                local p = getPath(target)

                if not used[p .. matchedId] then
                    used[p .. matchedId] = true
                    count += 1

                    table.insert(lines, "")
                    table.insert(lines, "#" .. count .. " ID " .. matchedId)
                    table.insert(lines, "Target: " .. target.Name .. " [" .. target.ClassName .. "]")
                    table.insert(lines, "TargetPath: " .. p)
                    table.insert(lines, "Pos: " .. getPos(target))
                    table.insert(lines, "MatchedObj: " .. matchedObj.Name .. " [" .. matchedObj.ClassName .. "]")
                    table.insert(lines, "MatchedPath: " .. getPath(matchedObj))
                end
            end
        end
    end

    if count == 0 then
        table.insert(lines, "Nenhum objeto do mapa bateu com os IDs do pedido.")
        table.insert(lines, "Nesse caso o jogo provavelmente não reutiliza o mesmo asset no mapa.")
    end

    printBlock("MATCH PEDIDO -> MAPA", lines)
end

local function scanOnlyFoodBins()
    local lines = {}
    local root = workspace:FindFirstChild("Interactables") or workspace
    local used = {}
    local count = 0

    for _, obj in ipairs(root:GetDescendants()) do
        local n = obj.Name:lower()
        if (obj:IsA("Model") or obj:IsA("Folder") or obj:IsA("BasePart")) and n:find("foodbin", 1, true) then
            local target = obj:IsA("Model") and obj or obj:FindFirstAncestorOfClass("Model") or obj
            local p = getPath(target)

            if not used[p] then
                used[p] = true
                count += 1

                table.insert(lines, "")
                table.insert(lines, "FOODBIN #" .. count)
                table.insert(lines, "Path: " .. p)
                table.insert(lines, "Pos: " .. getPos(target))

                for _, d in ipairs(target:GetDescendants()) do
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

                    if id then
                        local dn = d.Name:lower()
                        if dn:find("icon", 1, true) or dn:find("ingredient", 1, true) or dn:find("label", 1, true) or d:IsA("Decal") or d:IsA("Texture") then
                            table.insert(lines, "  " .. d.Name .. " [" .. d.ClassName .. "] id=" .. id)
                        end
                    end
                end
            end
        end
    end

    if count == 0 then
        table.insert(lines, "Nenhum FoodBin encontrado.")
    end

    printBlock("FOODBINS", lines)
end

local function makeGui()
    local old = lp.PlayerGui:FindFirstChild("CKScannerV4Focused")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "CKScannerV4Focused"
    gui.ResetOnSpawn = false
    gui.Parent = lp:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 210, 0, 150)
    frame.Position = UDim2.new(0, 15, 0.38, 0)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    frame.BackgroundTransparency = 0.12
    frame.Parent = gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -10, 0, 30)
    title.Position = UDim2.new(0, 5, 0, 5)
    title.BackgroundTransparency = 1
    title.Text = "CK Scanner V4"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.Parent = frame

    local function btn(text, y, cb)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -20, 0, 40)
        b.Position = UDim2.new(0, 10, 0, y)
        b.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.TextScaled = true
        b.Font = Enum.Font.GothamBold
        b.Text = text
        b.Parent = frame
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)

        b.MouseButton1Click:Connect(function()
            b.Text = "PRINTANDO..."
            task.spawn(function()
                pcall(cb)
                task.wait(0.8)
                b.Text = text
            end)
        end)
    end

    btn("MATCH PEDIDO", 42, scanMatchingRecipeIds)
    btn("SÓ FOODBINS", 88, scanOnlyFoodBins)
end

makeGui()
warn("[CK V4] carregado. Use MATCH PEDIDO ou SÓ FOODBINS.")
