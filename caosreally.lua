-- AUTOFARM: CAOS NA COZINHA / COOKING CHAOS
-- Versao: fluxo travado por etapa + prato estrito + 1 clique por interacao
-- Regras base: Kebab / Cidade Symmetri

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Interactables = Workspace:WaitForChild("Interactables")

------------------------------------------------------------
-- CONFIG
------------------------------------------------------------

local ACTION_COOLDOWN = 0.15

-- Tempo antes de qualquer TP para a proxima etapa.
local PRE_TELEPORT_DELAY = 2.00

-- Tempo apos teleportar antes de clicar.
local PROMPT_SETTLE_DELAY = 0.50

-- Tempo extra APENAS para ChoppingBoard e Hob/FryingPan.
-- Isso evita clicar cedo demais na bancada/panela.
local SPECIAL_APPLIANCE_CLICK_DELAY = 2.00

local VERIFY_TIMEOUT = 10
local COOK_TIMEOUT = 20
local SINK_TIMEOUT = 14

local TELEPORT_OFFSET = Vector3.new(0, 0, -4)

local busy = false
local lastAction = 0
local currentState = "Idle"

------------------------------------------------------------
-- LOG
------------------------------------------------------------

local function log(...)
    print("[Autofarm]", ...)
end

local function warnlog(...)
    warn("[Autofarm]", ...)
end

------------------------------------------------------------
-- BASICO
------------------------------------------------------------

local function now()
    return os.clock()
end

local function canAct()
    return not busy and (now() - lastAction) >= ACTION_COOLDOWN
end

local function setBusy(value, state)
    busy = value
    currentState = state or (value and "Busy" or "Idle")
end

local function getCharacter()
    return LocalPlayer.Character
end

local function getRoot()
    local char = getCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local char = getCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function safePivot(obj)
    if not obj then return nil end

    if obj:IsA("Model") then
        local ok, cf = pcall(function()
            return obj:GetPivot()
        end)
        if ok and cf then
            return cf.Position, cf
        end
    end

    if obj:IsA("BasePart") then
        return obj.Position, obj.CFrame
    end

    local part = obj:FindFirstChildWhichIsA("BasePart", true)
    if part then
        return part.Position, part.CFrame
    end

    return nil
end

local function distanceTo(obj)
    local root = getRoot()
    local pos = safePivot(obj)
    if not root or not pos then return math.huge end
    return (root.Position - pos).Magnitude
end

local function isDescendantOfCharacter(obj)
    local char = getCharacter()
    return char and obj:IsDescendantOf(char)
end

local function hasAncestorNamed(obj, names)
    local current = obj
    while current and current ~= Workspace do
        if names[current.Name] then
            return true
        end

        local applianceType = current:GetAttribute("ApplianceType")
        local utensilType = current:GetAttribute("UtensilType")

        if applianceType and names[applianceType] then
            return true
        end

        if utensilType and names[utensilType] then
            return true
        end

        current = current.Parent
    end

    return false
end

------------------------------------------------------------
-- PROMPT / TELEPORT / INTERACAO
------------------------------------------------------------

local function findPrompt(target)
    if not target then return nil end

    if target:IsA("ProximityPrompt") then
        return target
    end

    return target:FindFirstChildWhichIsA("ProximityPrompt", true)
end

local function isSpecialAppliance(target)
    if not target then return false end

    if target.Name == "ChoppingBoard" or target.Name == "Hob" or target.Name == "FryingPan" then
        return true
    end

    local applianceType = target:GetAttribute("ApplianceType")
    local utensilType = target:GetAttribute("UtensilType")

    return applianceType == "ChoppingBoard"
        or applianceType == "Hob"
        or utensilType == "FryingPan"
end

local function teleportNear(target)
    local root = getRoot()
    local pos, cf = safePivot(target)

    if not root or not pos then
        return false
    end

    task.wait(PRE_TELEPORT_DELAY)

    local targetCF = cf or CFrame.new(pos)
    local finalCF = targetCF * CFrame.new(TELEPORT_OFFSET)

    pcall(function()
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end)

    root.CFrame = CFrame.lookAt(finalCF.Position, pos)
    return true
end

local function singleInteract(target, actionName)
    if not target then return false end

    log("Acao:", actionName or "Interact", "->", target:GetFullName())

    if not teleportNear(target) then
        warnlog("Falhou ao teleportar para:", target:GetFullName())
        return false
    end

    task.wait(PROMPT_SETTLE_DELAY)

    if isSpecialAppliance(target) then
        task.wait(SPECIAL_APPLIANCE_CLICK_DELAY)
    end

    local prompt = findPrompt(target)
    if not prompt then
        warnlog("Nenhum ProximityPrompt encontrado em:", target:GetFullName())
        return false
    end

    local hold = prompt.HoldDuration or 0

    pcall(function()
        prompt:InputHoldBegin()
    end)

    task.wait(math.max(hold + 0.05, 0.12))

    pcall(function()
        prompt:InputHoldEnd()
    end)

    return true
end

local function waitUntil(timeout, predicate, label)
    local started = now()

    while now() - started < timeout do
        local ok, result = pcall(predicate)
        if ok and result then
            return true
        end
        task.wait(0.10)
    end

    if label then
        warnlog("Timeout esperando:", label)
    end

    return false
end

------------------------------------------------------------
-- ITEM NA MAO
------------------------------------------------------------

local ITEM_TYPES = {
    RawBeef = true,
    Pineapple = true,
    Tomato = true,
    ChoppedMeat = true,
    PineappleRings = true,
    ChoppedTomato = true,
    Plate = true,
    DirtyPlate = true,
}

local function detectItemType(obj)
    if not obj then return nil end

    local t = obj:GetAttribute("Type")
    if t and ITEM_TYPES[t] then
        return t
    end

    if ITEM_TYPES[obj.Name] then
        return obj.Name
    end

    return nil
end

local function getHeldItem()
    local char = getCharacter()
    local root = getRoot()
    if not char then return nil, nil end

    -- 1. Filho direto do personagem.
    for _, child in ipairs(char:GetChildren()) do
        local t = detectItemType(child)
        if t then
            return child, t
        end
    end

    -- 2. Dentro de Tool.
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then
        local t = detectItemType(tool)
        if t then
            return tool, t
        end

        for _, d in ipairs(tool:GetDescendants()) do
            local dt = detectItemType(d)
            if dt then
                return tool, dt
            end
        end
    end

    -- 3. Descendente do personagem.
    for _, d in ipairs(char:GetDescendants()) do
        local t = detectItemType(d)
        if t then
            return d, t
        end
    end

    -- 4. Fallback: item muito perto do personagem.
    -- Importante: NUNCA aceitar Hob/FryingPan/ChoppingBoard/Sink/Extinguisher como item na mao.
    if root then
        local banned = {
            Hob = true,
            FryingPan = true,
            ChoppingBoard = true,
            Sink = true,
            FoodBin = true,
            PlateSpawner = true,
            Extinguisher = true,
            FireExtinguisher = true,
        }

        local closest, closestType, bestD = nil, nil, math.huge

        for _, obj in ipairs(Interactables:GetDescendants()) do
            local t = detectItemType(obj)
            if t and not hasAncestorNamed(obj, banned) then
                local pos = safePivot(obj)
                if pos then
                    local d = (root.Position - pos).Magnitude
                    if d <= 5 and d < bestD then
                        closest = obj
                        closestType = t
                        bestD = d
                    end
                end
            end
        end

        if closest then
            return closest, closestType
        end
    end

    return nil, nil
end

local function heldIs(expectedType)
    local _, itemType = getHeldItem()
    return itemType == expectedType
end

------------------------------------------------------------
-- BUSCAS
------------------------------------------------------------

local function getNearestWhere(predicate)
    local root = getRoot()
    if not root then return nil end

    local closest = nil
    local minD = math.huge

    for _, obj in ipairs(Interactables:GetDescendants()) do
        if predicate(obj) then
            local pos = safePivot(obj)
            if pos then
                local d = (root.Position - pos).Magnitude
                if d < minD then
                    closest = obj
                    minD = d
                end
            end
        end
    end

    return closest
end

local function getNearestAppliance(applianceType)
    return getNearestWhere(function(obj)
        return obj:GetAttribute("ApplianceType") == applianceType
            or obj.Name == applianceType
            or obj:GetAttribute("ObjectText") == applianceType
    end)
end

local function getNearestByName(name)
    return getNearestWhere(function(obj)
        return obj.Name == name
    end)
end

local function getNearestFoodBin(foodType)
    return getNearestWhere(function(obj)
        return obj.Name == "FoodBin"
            and obj:GetAttribute("FoodType") == foodType
    end)
end

local function hasIngredient(container, ingredientName)
    if not container then return false end

    if container.Name == ingredientName then return true end
    if container:GetAttribute("Type") == ingredientName then return true end

    return container:FindFirstChild(ingredientName, true) ~= nil
end

------------------------------------------------------------
-- PRATOS: FILTRO CORRETO
-- Prato vazio no mapa = Countertop -> Plate(Type=Plate) sem ingredientes
------------------------------------------------------------

local function isEmptyPlate(plate)
    return plate
        and plate.Name == "Plate"
        and plate:GetAttribute("Type") == "Plate"
        and not plate:FindFirstChild("CookedMeat", true)
        and not plate:FindFirstChild("PineappleRings", true)
        and not plate:FindFirstChild("ChoppedTomato", true)
        and not plate:FindFirstChild("Kebab", true)
        and not plate:FindFirstChild("Salad", true)
end

local function isPlateObject(obj)
    if not obj then return false end

    return obj.Name == "Plate"
        and obj:GetAttribute("Type") == "Plate"
        and not hasAncestorNamed(obj, {
            Hob = true,
            FryingPan = true,
            ChoppingBoard = true,
            Sink = true,
            FoodBin = true,
            PlateSpawner = true,
            Extinguisher = true,
            FireExtinguisher = true,
        })
end

local function getPlateFromCountertop(countertop)
    if not countertop then return nil end

    if countertop:GetAttribute("ApplianceType") ~= "Countertop" and countertop.Name ~= "Countertop" then
        return nil
    end

    local plate = countertop:FindFirstChild("Plate")
    if isEmptyPlate(plate) then
        return plate
    end

    return nil
end

local function isCountertopWithEmptyPlate(countertop)
    return getPlateFromCountertop(countertop) ~= nil
end

local function getNearestCountertopWithEmptyPlate()
    return getNearestWhere(function(obj)
        return isCountertopWithEmptyPlate(obj)
    end)
end

local function getPlateState(plate)
    local hasMeat = hasIngredient(plate, "CookedMeat")
    local hasPineapple = hasIngredient(plate, "PineappleRings")
    local hasTomato = hasIngredient(plate, "ChoppedTomato")

    local count = 0
    if hasMeat then count += 1 end
    if hasPineapple then count += 1 end
    if hasTomato then count += 1 end

    return {
        hasMeat = hasMeat,
        hasPineapple = hasPineapple,
        hasTomato = hasTomato,
        count = count,
        complete = hasMeat and hasPineapple and hasTomato,
    }
end

local function heldPlateHas(ingredientName)
    local held, itemType = getHeldItem()
    if itemType ~= "Plate" or not held then return false end
    return hasIngredient(held, ingredientName)
end

local function plateAlreadyHasIngredient(state, ingredientType)
    if ingredientType == "CookedMeat" then
        return state.hasMeat
    elseif ingredientType == "PineappleRings" then
        return state.hasPineapple
    elseif ingredientType == "ChoppedTomato" then
        return state.hasTomato
    end

    return false
end

local function wouldCompletePlate(state, ingredientType)
    if ingredientType == "CookedMeat" then
        return not state.hasMeat and state.hasPineapple and state.hasTomato
    elseif ingredientType == "PineappleRings" then
        return state.hasMeat and not state.hasPineapple and state.hasTomato
    elseif ingredientType == "ChoppedTomato" then
        return state.hasMeat and state.hasPineapple and not state.hasTomato
    end

    return false
end

local function getBestPlate(ingredientType)
    local bestTarget = nil
    local bestScore = -math.huge
    local bestDistance = math.huge

    -- Aqui o alvo de interacao deve ser o Countertop que contem o Plate.
    -- Isso evita confundir Plate solto/objeto interno com prato real no mapa.
    for _, obj in ipairs(Interactables:GetDescendants()) do
        if obj:GetAttribute("ApplianceType") == "Countertop" or obj.Name == "Countertop" then
            local plate = obj:FindFirstChild("Plate")
            if plate and isPlateObject(plate) then
                local state = getPlateState(plate)

                if not state.complete and not plateAlreadyHasIngredient(state, ingredientType) then
                    local score = 0

                    if wouldCompletePlate(state, ingredientType) then
                        score += 1000
                    end

                    score += state.count * 100

                    -- Carne sempre deve ser a primeira base.
                    -- Para abacaxi/tomate, preferir prato que ja tenha carne.
                    if ingredientType ~= "CookedMeat" and state.hasMeat then
                        score += 500
                    end

                    local d = distanceTo(obj)
                    score -= d * 0.01

                    if score > bestScore or (score == bestScore and d < bestDistance) then
                        bestTarget = obj
                        bestScore = score
                        bestDistance = d
                    end
                end
            end
        end
    end

    return bestTarget
end

local function getNearestCompletePlateCountertop()
    return getNearestWhere(function(obj)
        if obj:GetAttribute("ApplianceType") ~= "Countertop" and obj.Name ~= "Countertop" then
            return false
        end

        local plate = obj:FindFirstChild("Plate")
        if not plate or not isPlateObject(plate) then return false end

        return getPlateState(plate).complete
    end)
end

------------------------------------------------------------
-- BANCADA
------------------------------------------------------------

local function getNearestEmptyCountertop()
    return getNearestWhere(function(obj)
        if obj:GetAttribute("ApplianceType") ~= "Countertop" and obj.Name ~= "Countertop" then
            return false
        end

        local blockedNames = {
            Plate = true,
            DirtyPlate = true,
            Kebab = true,
            Salad = true,
            CookedMeat = true,
            PineappleRings = true,
            ChoppedTomato = true,
            RawBeef = true,
            Pineapple = true,
            Tomato = true,
            ChoppedMeat = true,
        }

        for _, d in ipairs(obj:GetDescendants()) do
            if blockedNames[d.Name] or blockedNames[d:GetAttribute("Type")] then
                return false
            end
        end

        return true
    end)
end

------------------------------------------------------------
-- PANELA / HOB
------------------------------------------------------------

local function getFryingPan(hob)
    if not hob then return nil end
    if hob.Name == "FryingPan" then return hob end
    return hob:FindFirstChild("FryingPan", true)
end

local function getNearestHobWithPan()
    return getNearestWhere(function(obj)
        if obj:GetAttribute("ApplianceType") == "Hob" or obj.Name == "Hob" then
            return getFryingPan(obj) ~= nil and findPrompt(obj) ~= nil
        end
        return false
    end)
end

local function isPanBurnt(hob)
    local pan = getFryingPan(hob)
    if not pan then return false end

    local burnt = pan:FindFirstChild("BurntImage", true)
    if not burnt then return false end

    local visible = burnt.Visible == true
    local transparent = burnt.ImageTransparency ~= nil and burnt.ImageTransparency < 0.5

    return visible and transparent
end

local function isPanReady(hob)
    local pan = getFryingPan(hob)
    if not pan then return false end

    if isPanBurnt(hob) then
        return false
    end

    local tickImage = pan:FindFirstChild("TickImage", true)
    if not tickImage then return false end

    local visible = tickImage.Visible == true
    local transparent = tickImage.ImageTransparency ~= nil and tickImage.ImageTransparency < 0.5

    return visible and transparent
end

local function panHasChoppedMeat(hob)
    local pan = getFryingPan(hob)
    if not pan then return false end
    return hasIngredient(pan, "ChoppedMeat")
end

local function getNearestReadyPan()
    return getNearestWhere(function(obj)
        if obj:GetAttribute("ApplianceType") ~= "Hob" and obj.Name ~= "Hob" then
            return false
        end

        return isPanReady(obj)
    end)
end

------------------------------------------------------------
-- PIA
------------------------------------------------------------

local function isSinkWashing(sink)
    if not sink then return false end

    local progressBar = sink:FindFirstChild("ProgressBar", true)
    local bar = sink:FindFirstChild("Bar", true)

    if progressBar and progressBar.Enabled == true then
        return true
    end

    if bar and bar:IsA("GuiObject") then
        local scale = bar.Size.X.Scale
        if scale and scale > 0.01 then
            return true
        end
    end

    return false
end

local function anySinkWashing()
    return getNearestWhere(function(obj)
        if obj:GetAttribute("ApplianceType") == "Sink" or obj.Name == "Sink" then
            return isSinkWashing(obj)
        end
        return false
    end)
end

------------------------------------------------------------
-- CHOPPINGBOARD: ESTADOS CORRETOS
------------------------------------------------------------

local function isChoppingBoard(obj)
    return obj
        and obj:IsA("Model")
        and obj:GetAttribute("ApplianceType") == "ChoppingBoard"
end

local function hasBoardResultReady(board, resultType)
    return isChoppingBoard(board)
        and board:FindFirstChild(resultType, true) ~= nil
end

local function isBoardEmpty(board)
    if not isChoppingBoard(board) then return false end

    local blocked = {
        RawBeef = true,
        ChoppedMeat = true,
        Pineapple = true,
        PineappleRings = true,
        Tomato = true,
        ChoppedTomato = true,
    }

    for _, d in ipairs(board:GetDescendants()) do
        if blocked[d.Name] or blocked[d:GetAttribute("Type")] then
            return false
        end
    end

    return true
end

------------------------------------------------------------
-- RECEITA / ETAPAS
------------------------------------------------------------

local function cutAndPickup(rawType, resultType)
    if not heldIs(rawType) then
        warnlog("Bloqueado: esperado na mao:", rawType)
        return false
    end

    local board = getNearestAppliance("ChoppingBoard")
    if not board or not isChoppingBoard(board) then
        warnlog("Nenhuma ChoppingBoard valida encontrada")
        return false
    end

    -- Primeiro clique: coloca o ingrediente cru / inicia corte.
    singleInteract(board, "Colocar/cortar " .. rawType)

    -- NUNCA clicar para pegar antes do resultado estar pronto dentro da bancada.
    -- Para carne: so clica se ChoppingBoard tiver ChoppedMeat.
    local readyOnBoard = waitUntil(VERIFY_TIMEOUT, function()
        return hasBoardResultReady(board, resultType)
    end, resultType .. " pronto dentro da ChoppingBoard")

    if not readyOnBoard then
        warnlog("Nao vou clicar para pegar: " .. resultType .. " ainda nao esta pronto na ChoppingBoard")
        return false
    end

    -- Segundo clique: pegar APENAS quando o item correto ja existe na bancada.
    singleInteract(board, "Pegar " .. resultType .. " pronto da ChoppingBoard")

    local gotItem = waitUntil(VERIFY_TIMEOUT, function()
        return heldIs(resultType)
    end, resultType .. " na mao")

    if not gotItem then
        warnlog("Nao peguei " .. resultType .. ". Nao vou avancar para a proxima etapa.")
        return false
    end

    return true
end

local function placeChoppedMeatOnPan()
    if not heldIs("ChoppedMeat") then
        warnlog("Bloqueado: so vou para a panela com ChoppedMeat na mao")
        return false
    end

    local hob = getNearestHobWithPan()
    if not hob then
        warnlog("Nenhum Hob/FryingPan encontrado")
        return false
    end

    singleInteract(hob, "Colocar ChoppedMeat na panela")

    local placed = waitUntil(VERIFY_TIMEOUT, function()
        local _, itemType = getHeldItem()
        return itemType ~= "ChoppedMeat" and panHasChoppedMeat(hob)
    end, "ChoppedMeat saiu da mao e entrou na panela")

    if not placed then
        warnlog("A carne cortada nao foi confirmada na panela. Nao vou procurar prato ainda.")
        return false
    end

    return hob
end

local function getEmptyPlateWhileMeatCooks(hob)
    if not hob then return false end

    -- Se ja esta com Plate, nao pegar outro.
    if heldIs("Plate") then
        return true
    end

    -- So procurar prato quando estiver sem nada na mao.
    local _, itemType = getHeldItem()
    if itemType then
        warnlog("Esperando mao vazia antes de buscar Plate. Item atual:", itemType)
        return false
    end

    local countertop = getNearestCountertopWithEmptyPlate()
    if not countertop then
        warnlog("Nenhum Countertop com Plate vazio encontrado. Nao vou clicar na panela nem em objetos aleatorios.")
        return false
    end

    singleInteract(countertop, "Pegar Plate vazio do Countertop enquanto a carne assa")

    local gotPlate = waitUntil(VERIFY_TIMEOUT, function()
        return heldIs("Plate")
    end, "Plate vazio na mao")

    if not gotPlate then
        warnlog("Nao consegui confirmar Plate na mao. Nao volto para panela ainda.")
        return false
    end

    return true
end

local function waitPanReadyAndTakeWithPlate(hob)
    if not hob then return false end

    local hasPlate = getEmptyPlateWhileMeatCooks(hob)
    if not hasPlate then
        return false
    end

    local ready = waitUntil(COOK_TIMEOUT, function()
        return isPanReady(hob)
    end, "carne pronta na panela")

    if not ready then
        return false
    end

    if not heldIs("Plate") then
        warnlog("Bloqueado: panela pronta, mas nao estou com Plate na mao")
        return false
    end

    singleInteract(hob, "Pegar CookedMeat com Plate")

    local gotMeatPlate = waitUntil(VERIFY_TIMEOUT, function()
        return heldPlateHas("CookedMeat")
    end, "Plate com CookedMeat")

    if not gotMeatPlate then
        warnlog("Nao confirmei CookedMeat no prato. Nao vou para bancada ainda.")
        return false
    end

    return true
end

local function placeHeldPlateOnCounter()
    if not heldIs("Plate") then return false end

    local counter = getNearestEmptyCountertop()
    if not counter then
        warnlog("Nenhuma bancada vazia encontrada")
        return false
    end

    singleInteract(counter, "Colocar Plate na bancada vazia")

    waitUntil(VERIFY_TIMEOUT, function()
        local _, itemType = getHeldItem()
        return itemType ~= "Plate"
    end, "Plate saiu da mao")

    return true
end

local function addFinalIngredientToBestPlate(ingredientType)
    if not heldIs(ingredientType) then
        warnlog("Bloqueado: esperado ingrediente na mao:", ingredientType)
        return false
    end

    local plate = getBestPlate(ingredientType)
    if not plate then
        warnlog("Nenhum Plate valido encontrado para:", ingredientType)
        return false
    end

    singleInteract(plate, "Adicionar " .. ingredientType .. " ao melhor Plate")

    local added = waitUntil(VERIFY_TIMEOUT, function()
        local _, itemType = getHeldItem()
        return itemType ~= ingredientType and hasIngredient(plate, ingredientType)
    end, ingredientType .. " no Plate")

    if not added then
        warnlog("Nao confirmei " .. ingredientType .. " no prato.")
        return false
    end

    return true
end

local function sellCompletePlate(plate)
    if not plate then return false end

    singleInteract(plate, "Pegar Plate completo")

    local gotComplete = waitUntil(VERIFY_TIMEOUT, function()
        local held, itemType = getHeldItem()
        return itemType == "Plate" and held and getPlateState(held).complete
    end, "Plate completo na mao")

    if not gotComplete then return false end

    local sellPoint = getNearestByName("SellPoint")
        or getNearestAppliance("Sell")
        or getNearestByName("Sell")

    if not sellPoint then
        warnlog("SellPoint nao encontrado")
        return false
    end

    singleInteract(sellPoint, "Vender Plate completo")
    return true
end

local function handleDirtyPlate()
    local dirty = getNearestWhere(function(obj)
        return (obj:GetAttribute("Type") == "DirtyPlate" or obj.Name == "DirtyPlate")
            and not isDescendantOfCharacter(obj)
            and findPrompt(obj) ~= nil
    end)

    if not dirty and not heldIs("DirtyPlate") then
        return false
    end

    if dirty and not heldIs("DirtyPlate") then
        singleInteract(dirty, "Pegar DirtyPlate")
        waitUntil(VERIFY_TIMEOUT, function()
            return heldIs("DirtyPlate")
        end, "DirtyPlate na mao")
    end

    if not heldIs("DirtyPlate") then
        return false
    end

    local sink = getNearestAppliance("Sink")
    if not sink then return false end

    singleInteract(sink, "Lavar DirtyPlate")

    waitUntil(SINK_TIMEOUT, function()
        return not isSinkWashing(sink)
    end, "lavagem terminar")

    if heldIs("Plate") then
        placeHeldPlateOnCounter()
    end

    return true
end

------------------------------------------------------------
-- FLUXOS PRINCIPAIS
------------------------------------------------------------

local function meatFlowFromRawBeef()
    if not heldIs("RawBeef") then return false end

    local cutOk = cutAndPickup("RawBeef", "ChoppedMeat")
    if not cutOk then return false end

    if not heldIs("ChoppedMeat") then
        warnlog("Apos corte, nao estou com ChoppedMeat. Fluxo da carne parou.")
        return false
    end

    local hob = placeChoppedMeatOnPan()
    if not hob then return false end

    -- Agora a mao deve estar vazia. Enquanto assa, pegar Plate vazio.
    local plateOk = getEmptyPlateWhileMeatCooks(hob)
    if not plateOk then return false end

    local takeOk = waitPanReadyAndTakeWithPlate(hob)
    if not takeOk then return false end

    if heldPlateHas("CookedMeat") then
        placeHeldPlateOnCounter()
    end

    return true
end

local function pineappleFlow()
    if heldIs("Pineapple") then
        if cutAndPickup("Pineapple", "PineappleRings") then
            addFinalIngredientToBestPlate("PineappleRings")
        end
        return true
    elseif heldIs("PineappleRings") then
        addFinalIngredientToBestPlate("PineappleRings")
        return true
    end

    return false
end

local function tomatoFlow()
    if heldIs("Tomato") then
        if cutAndPickup("Tomato", "ChoppedTomato") then
            addFinalIngredientToBestPlate("ChoppedTomato")
        end
        return true
    elseif heldIs("ChoppedTomato") then
        addFinalIngredientToBestPlate("ChoppedTomato")
        return true
    end

    return false
end

local function pickFood(foodType)
    local bin = getNearestFoodBin(foodType)
    if not bin then
        warnlog("FoodBin nao encontrado:", foodType)
        return false
    end

    singleInteract(bin, "Pegar " .. foodType)

    local got = waitUntil(VERIFY_TIMEOUT, function()
        return heldIs(foodType)
    end, foodType .. " na mao")

    if not got then
        warnlog("Nao consegui confirmar " .. foodType .. " na mao")
        return false
    end

    return true
end

local function hasAnyPlateWithMeatOnlyOrPartial()
    return getNearestWhere(function(obj)
        if obj:GetAttribute("ApplianceType") ~= "Countertop" and obj.Name ~= "Countertop" then
            return false
        end

        local plate = obj:FindFirstChild("Plate")
        if not plate or not isPlateObject(plate) then return false end

        local state = getPlateState(plate)
        return state.hasMeat and not state.complete
    end) ~= nil
end

local function hasAnyPlateWithMeatAndPineappleNoTomato()
    return getNearestWhere(function(obj)
        if obj:GetAttribute("ApplianceType") ~= "Countertop" and obj.Name ~= "Countertop" then
            return false
        end

        local plate = obj:FindFirstChild("Plate")
        if not plate or not isPlateObject(plate) then return false end

        local state = getPlateState(plate)
        return state.hasMeat and state.hasPineapple and not state.hasTomato
    end) ~= nil
end

local function handleEmptyHands()
    -- 1. Vender prato completo se existir.
    local completePlate = getNearestCompletePlateCountertop()
    if completePlate then
        sellCompletePlate(completePlate)
        return
    end

    -- 2. Prato sujo.
    if handleDirtyPlate() then
        return
    end

    -- 3. Se alguma panela ja esta pronta, pegar Plate vazio e buscar carne.
    local readyPan = getNearestReadyPan()
    if readyPan then
        if getEmptyPlateWhileMeatCooks(readyPan) then
            if waitPanReadyAndTakeWithPlate(readyPan) then
                placeHeldPlateOnCounter()
            end
        end
        return
    end

    -- 4. Se uma panela esta assando, prioridade e pegar Plate vazio.
    local cookingHob = getNearestWhere(function(obj)
        if obj:GetAttribute("ApplianceType") ~= "Hob" and obj.Name ~= "Hob" then
            return false
        end
        return panHasChoppedMeat(obj) and not isPanReady(obj) and not isPanBurnt(obj)
    end)

    if cookingHob then
        getEmptyPlateWhileMeatCooks(cookingHob)
        return
    end

    -- 5. Ordem da receita: carne primeiro.
    -- Se nao tem prato com carne parcial, produzir carne.
    if not hasAnyPlateWithMeatOnlyOrPartial() then
        if pickFood("RawBeef") then
            meatFlowFromRawBeef()
        end
        return
    end

    -- 6. Depois abacaxi.
    if not hasAnyPlateWithMeatAndPineappleNoTomato() then
        if pickFood("Pineapple") then
            pineappleFlow()
        end
        return
    end

    -- 7. Depois tomate.
    if pickFood("Tomato") then
        tomatoFlow()
    end
end

------------------------------------------------------------
-- LOOP
------------------------------------------------------------

local function step()
    if not canAct() then return end

    if anySinkWashing() then
        return
    end

    local char = getCharacter()
    if not char then return end

    setBusy(true, "Step")
    lastAction = now()

    task.spawn(function()
        local ok, err = pcall(function()
            local held, itemType = getHeldItem()

            if itemType then
                log("Mao detectada:", itemType, held and held:GetFullName() or "nil")
            else
                log("Mao vazia")
            end

            if itemType == "RawBeef" then
                meatFlowFromRawBeef()

            elseif itemType == "ChoppedMeat" then
                local hob = placeChoppedMeatOnPan()
                if hob then
                    if getEmptyPlateWhileMeatCooks(hob) then
                        if waitPanReadyAndTakeWithPlate(hob) then
                            placeHeldPlateOnCounter()
                        end
                    end
                end

            elseif itemType == "Pineapple" or itemType == "PineappleRings" then
                pineappleFlow()

            elseif itemType == "Tomato" or itemType == "ChoppedTomato" then
                tomatoFlow()

            elseif itemType == "Plate" then
                local readyPan = getNearestReadyPan()
                if readyPan then
                    if waitPanReadyAndTakeWithPlate(readyPan) then
                        placeHeldPlateOnCounter()
                    end
                elseif held and getPlateState(held).complete then
                    local sellPoint = getNearestByName("SellPoint")
                        or getNearestAppliance("Sell")
                        or getNearestByName("Sell")

                    if sellPoint then
                        singleInteract(sellPoint, "Vender Plate completo")
                    end
                else
                    placeHeldPlateOnCounter()
                end

            elseif itemType == "DirtyPlate" then
                handleDirtyPlate()

            else
                handleEmptyHands()
            end
        end)

        if not ok then
            warnlog("Erro no step:", err)
        end

        task.wait(ACTION_COOLDOWN)
        setBusy(false, "Idle")
    end)
end

RunService.Heartbeat:Connect(step)

------------------------------------------------------------
-- PRINT DE CARREGAMENTO NO FINAL DO CODIGO
------------------------------------------------------------

print("[Autofarm] Cooking Chaooos carregado | Plate = Countertop->Plate vazio | ChoppingBoard so pega se resultado pronto | 1 clique por interacao")
