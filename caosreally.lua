-- AUTOFARM: CAOS NA COZINHA / COOKING CHAOS
-- Fluxo corrigido: carne primeiro -> abacaxi -> tomate -> vender
-- Baseado nas regras do TXT: Kebab / Cidade Symmetri

print("[Autofarm] Carregado: Cooking Chaos / Caos na Cozinha - fluxo corrigido")

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Interactables = Workspace:WaitForChild("Interactables")

------------------------------------------------------------
-- CONFIG
------------------------------------------------------------

local ACTION_COOLDOWN = 0.45
local MOVE_TIMEOUT = 4
local INTERACT_DISTANCE = 8

-- Observação: este arquivo corrige a detecção de item na mão.
-- Noclip/forçar speed não foi incluído aqui; use apenas mecânicas permitidas no seu próprio projeto/teste.
local WAIT_ITEM_TIMEOUT = 8
local WAIT_COOK_TIMEOUT = 14
local WAIT_SINK_TIMEOUT = 12

local busy = false
local lastAction = 0
local currentState = "Idle"

-- Ordem principal de produção.
-- A carne SEMPRE vem primeiro. Depois Pineapple e Tomato.
local productionStep = "Meat" -- Meat -> Pineapple -> Tomato -> Meat...

------------------------------------------------------------
-- UTILS BÁSICOS
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
            return cf.Position
        end
    end

    if obj:IsA("BasePart") then
        return obj.Position
    end

    local part = obj:FindFirstChildWhichIsA("BasePart", true)
    if part then
        return part.Position
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

local function hasTypeOrName(obj, wanted)
    if not obj then return false end
    if obj.Name == wanted then return true end
    if obj:GetAttribute("Type") == wanted then return true end
    return false
end

------------------------------------------------------------
-- ITEM NA MÃO
------------------------------------------------------------

local VALID_HELD_TYPES = {
    RawBeef = true,
    Pineapple = true,
    Tomato = true,
    ChoppedMeat = true,
    PineappleRings = true,
    ChoppedTomato = true,
    Plate = true,
    DirtyPlate = true,
}

local lastHeldDebugType = nil
local lastHeldDebugPath = nil

local function getHeldItem()
    local char = getCharacter()
    if not char then return nil, nil end

    -- Correção principal v2:
    -- Em Cooking Chaos, o item pode NÃO ser filho do Character.
    -- Às vezes ele continua dentro de Workspace.Interactables e só fica soldado/perto da mão.
    -- Então a detecção agora faz 2 passagens:
    -- 1) Character/Tool/descendentes.
    -- 2) Interactables próximos da mão/root, evitando FoodBins/appliances estáticos.
    local bestItem = nil
    local bestType = nil
    local bestScore = -math.huge

    local function normalizeType(obj)
        if not obj then return nil end

        local itemType = obj:GetAttribute("Type")
            or obj:GetAttribute("FoodType")
            or obj.Name

        if VALID_HELD_TYPES[itemType] then
            return itemType
        end

        return nil
    end

    local function getMainItemObject(obj)
        if not obj then return nil end
        if obj:IsA("Tool") then return obj end

        local cur = obj
        while cur and cur ~= char and cur ~= Interactables and cur ~= Workspace do
            local t = normalizeType(cur)
            if t and (cur:IsA("Model") or cur:IsA("Tool")) then
                return cur
            end
            cur = cur.Parent
        end

        return obj
    end

    local function consider(obj, score, forcedType)
        if not obj then return end

        local itemType = forcedType or normalizeType(obj)
        if not VALID_HELD_TYPES[itemType] then
            return
        end

        local mainObj = getMainItemObject(obj)
        if not mainObj then return end

        if mainObj:IsA("Tool") then
            score += 80
        elseif mainObj:IsA("Model") then
            score += 65
        elseif mainObj:IsA("BasePart") then
            score += 20
        end

        local path = mainObj:GetFullName()
        if string.find(path, "Hand") or string.find(path, "Right") or string.find(path, "Left") then
            score += 20
        end

        if score > bestScore then
            bestItem = mainObj
            bestType = itemType
            bestScore = score
        end
    end

    -- 1) Busca normal dentro do Character.
    for _, child in ipairs(char:GetChildren()) do
        consider(child, 200)
    end

    for _, d in ipairs(char:GetDescendants()) do
        consider(d, 120)
    end

    -- 2) Fallback importante: item ainda em Workspace.Interactables, mas perto/na mão.
    -- Isso resolve RawBeef que aparece como Workspace.Interactables.RawBeef mesmo após pegar.
    local root = getRoot()
    local handParts = {}

    local possibleHands = {
        "RightHand",
        "LeftHand",
        "Right Arm",
        "Left Arm",
        "RightLowerArm",
        "LeftLowerArm",
        "RightUpperArm",
        "LeftUpperArm",
    }

    for _, name in ipairs(possibleHands) do
        local part = char:FindFirstChild(name, true)
        if part and part:IsA("BasePart") then
            table.insert(handParts, part)
        end
    end

    local function nearCharacterHandsOrRoot(obj)
        local pos = safePivot(obj)
        if not pos then return false, math.huge end

        local bestD = math.huge

        for _, hand in ipairs(handParts) do
            local d = (hand.Position - pos).Magnitude
            if d < bestD then bestD = d end
        end

        if root then
            local d = (root.Position - pos).Magnitude
            if d < bestD then bestD = d end
        end

        -- Distância maior para root porque alguns models ficam no centro do personagem.
        return bestD <= 7, bestD
    end

    local function isStaticHolder(obj)
        if not obj then return false end
        local applianceType = obj:GetAttribute("ApplianceType")
        if applianceType then return true end
        if obj.Name == "FoodBin" or obj.Name == "Countertop" or obj.Name == "ChoppingBoard" or obj.Name == "Hob" or obj.Name == "Sink" or obj.Name == "PlateSpawner" or obj.Name == "Sell" or obj.Name == "SellPoint" then
            return true
        end
        return false
    end

    for _, obj in ipairs(Interactables:GetDescendants()) do
        local itemType = normalizeType(obj)
        if itemType then
            local mainObj = getMainItemObject(obj)

            if mainObj and not isDescendantOfCharacter(mainObj) and not isStaticHolder(mainObj.Parent) and not isStaticHolder(mainObj) then
                local near, d = nearCharacterHandsOrRoot(mainObj)
                if near then
                    -- Quanto mais perto, maior a chance de ser o item segurado.
                    consider(mainObj, 100 - d, itemType)
                end
            end
        end
    end

    if bestItem and (bestType ~= lastHeldDebugType or bestItem:GetFullName() ~= lastHeldDebugPath) then
        lastHeldDebugType = bestType
        lastHeldDebugPath = bestItem:GetFullName()
        print("[Autofarm][MÃO]", tostring(bestType), bestItem:GetFullName())
    elseif not bestItem and lastHeldDebugType ~= nil then
        lastHeldDebugType = nil
        lastHeldDebugPath = nil
        print("[Autofarm][MÃO] vazia")
    end

    return bestItem, bestType
end

local function waitForHeldType(wantedType, timeout)
    local started = now()
    timeout = timeout or WAIT_ITEM_TIMEOUT

    while now() - started < timeout do
        local held, heldType = getHeldItem()
        if heldType == wantedType then
            return held
        end
        task.wait(0.12)
    end

    return nil
end

local function waitUntilHandsEmpty(timeout)
    local started = now()
    timeout = timeout or 3

    while now() - started < timeout do
        local _, heldType = getHeldItem()
        if not heldType then
            return true
        end
        task.wait(0.12)
    end

    return false
end

------------------------------------------------------------
-- BUSCAS NO MAPA
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

    if container.Name == ingredientName then
        return true
    end

    if container:GetAttribute("Type") == ingredientName then
        return true
    end

    return container:FindFirstChild(ingredientName, true) ~= nil
end

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
-- MOVIMENTO E INTERAÇÃO
------------------------------------------------------------

local function moveNear(target)
    local humanoid = getHumanoid()
    local root = getRoot()
    local pos = safePivot(target)

    if not humanoid or not root or not pos then
        return false
    end

    if (root.Position - pos).Magnitude <= INTERACT_DISTANCE then
        return true
    end

    humanoid:MoveTo(pos)

    local started = now()
    while now() - started < MOVE_TIMEOUT do
        root = getRoot()
        if not root then return false end

        if (root.Position - pos).Magnitude <= INTERACT_DISTANCE then
            return true
        end

        task.wait(0.05)
    end

    return false
end

local function findPrompt(target)
    if not target then return nil end

    if target:IsA("ProximityPrompt") then
        return target
    end

    return target:FindFirstChildWhichIsA("ProximityPrompt", true)
end

local function tryInteract(target)
    if not target then return false end

    local reached = moveNear(target)
    if not reached then
        print("[Autofarm] Falhou ao chegar em:", target.Name)
        return false
    end

    local prompt = findPrompt(target)

    if prompt then
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

    warn("[Autofarm] Nenhum ProximityPrompt encontrado em:", target:GetFullName())
    return false
end

local function doAction(stateName, fn)
    if not canAct() then return end

    print("[Autofarm][AÇÃO]", stateName)
    setBusy(true, stateName)
    lastAction = now()

    task.spawn(function()
        local ok, err = pcall(fn)
        if not ok then
            warn("[Autofarm erro][" .. tostring(stateName) .. "]", err)
        end

        task.wait(ACTION_COOLDOWN)
        setBusy(false, "Idle")
    end)
end

------------------------------------------------------------
-- PRATOS / INGREDIENTES
------------------------------------------------------------

local function isPlateObject(obj)
    if not obj then return false end
    return obj:GetAttribute("Type") == "Plate" or obj.Name == "Plate"
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

local function getAllWorldPlates()
    local plates = {}
    local seen = {}

    for _, obj in ipairs(Interactables:GetDescendants()) do
        if isPlateObject(obj) and not isDescendantOfCharacter(obj) then
            if not seen[obj] then
                seen[obj] = true
                table.insert(plates, obj)
            end
        end
    end

    return plates
end

local function getNearestCleanEmptyPlate()
    return getNearestWhere(function(obj)
        if not isPlateObject(obj) or isDescendantOfCharacter(obj) then return false end
        local state = getPlateState(obj)
        return state.count == 0
    end)
end

local function getBestPlate(ingredientType)
    local bestPlate = nil
    local bestScore = -math.huge
    local bestDistance = math.huge

    for _, plate in ipairs(getAllWorldPlates()) do
        local state = getPlateState(plate)

        if not state.complete and not plateAlreadyHasIngredient(state, ingredientType) then
            local score = 0

            if wouldCompletePlate(state, ingredientType) then
                score += 1000
            end

            -- Prioridade extra: depois que a carne existe, abacaxi/tomate devem preferir prato com carne.
            if ingredientType ~= "CookedMeat" and state.hasMeat then
                score += 350
            end

            score += state.count * 100

            local d = distanceTo(plate)
            score -= d * 0.01

            if score > bestScore or (score == bestScore and d < bestDistance) then
                bestPlate = plate
                bestScore = score
                bestDistance = d
            end
        end
    end

    return bestPlate
end

local function getNearestCompletePlate()
    return getNearestWhere(function(obj)
        if not isPlateObject(obj) or isDescendantOfCharacter(obj) then return false end
        local state = getPlateState(obj)
        return state.complete
    end)
end

local function isHeldPlateComplete(held)
    if not held then return false end
    return getPlateState(held).complete
end

local function isHeldPlatePartial(held)
    if not held then return false end
    if not isPlateObject(held) then return false end
    local state = getPlateState(held)
    return state.count > 0 and not state.complete
end

------------------------------------------------------------
-- PANELA / HOB / FRYINGPAN
------------------------------------------------------------

local function getFryingPan(hob)
    if not hob then return nil end

    if hob.Name == "FryingPan" then
        return hob
    end

    return hob:FindFirstChild("FryingPan", true)
end

local function getNearestHobWithPan()
    return getNearestWhere(function(obj)
        if obj:GetAttribute("ApplianceType") == "Hob" or obj.Name == "Hob" then
            return getFryingPan(obj) ~= nil
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

local function waitForPanReady(hob)
    local started = now()

    while now() - started < WAIT_COOK_TIMEOUT do
        if isPanReady(hob) then
            return true
        end

        if isPanBurnt(hob) then
            warn("[Autofarm] Carne queimou na panela.")
            return false
        end

        task.wait(0.15)
    end

    return false
end

------------------------------------------------------------
-- PIA / SINK
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

local function waitForSinkToFinish(sink)
    local started = now()

    while now() - started < WAIT_SINK_TIMEOUT do
        if not isSinkWashing(sink) then
            return true
        end
        task.wait(0.15)
    end

    return false
end

local function getActiveSink()
    return getNearestWhere(function(obj)
        if obj:GetAttribute("ApplianceType") == "Sink" or obj.Name == "Sink" then
            return isSinkWashing(obj)
        end
        return false
    end)
end

------------------------------------------------------------
-- FLUXOS AUXILIARES
------------------------------------------------------------

local function getSellPoint()
    return getNearestByName("SellPoint")
        or getNearestAppliance("Sell")
        or getNearestByName("Sell")
end

local function putHeldPlateOnCounter()
    local counter = getNearestEmptyCountertop()
    if counter then
        return tryInteract(counter)
    end
    return false
end

local function sellHeldOrWorldCompletePlate(held)
    local sellPoint = getSellPoint()
    if not sellPoint then return false end

    if held and isHeldPlateComplete(held) then
        return tryInteract(sellPoint)
    end

    local complete = getNearestCompletePlate()
    if complete then
        if tryInteract(complete) then
            task.wait(0.2)
            local heldNow = select(1, getHeldItem())
            if heldNow and isHeldPlateComplete(heldNow) then
                return tryInteract(sellPoint)
            end
        end
    end

    return false
end

local function cutHeldRawIngredient(rawType, resultType)
    local board = getNearestAppliance("ChoppingBoard")
    if not board then return false end

    if not tryInteract(board) then return false end

    local started = now()
    while now() - started < WAIT_ITEM_TIMEOUT do
        local _, heldType = getHeldItem()

        if heldType == resultType then
            return true
        end

        if board:FindFirstChild(resultType, true) or hasIngredient(board, resultType) then
            -- Alguns mapas deixam o item cortado na tábua. Interage de novo para pegar.
            tryInteract(board)
            task.wait(0.2)

            local _, afterType = getHeldItem()
            if afterType == resultType then
                return true
            end
        end

        task.wait(0.15)
    end

    return false
end

local function getFoodAndWait(foodType)
    local bin = getNearestFoodBin(foodType)
    if not bin then return false end

    if tryInteract(bin) then
        return waitForHeldType(foodType, 3) ~= nil
    end

    return false
end

------------------------------------------------------------
-- FLUXO PRINCIPAL DA CARNE
------------------------------------------------------------

local function fullMeatFlowFromRawBeef()
    -- 1. Garantir RawBeef na mão.
    local _, heldType = getHeldItem()
    if heldType ~= "RawBeef" then
        print("[Autofarm] Pegando RawBeef no FoodBin")
        if not getFoodAndWait("RawBeef") then
            print("[Autofarm] Não conseguiu confirmar RawBeef na mão")
            return false
        end
    end

    -- 2. RawBeef -> ChoppedMeat na bancada de corte.
    print("[Autofarm] RawBeef detectado. Indo cortar na ChoppingBoard")
    if not cutHeldRawIngredient("RawBeef", "ChoppedMeat") then
        print("[Autofarm] Falhou ao transformar RawBeef em ChoppedMeat")
        return false
    end

    -- 3. ChoppedMeat -> panela.
    local hob = getNearestHobWithPan()
    if not hob then return false end

    if isPanBurnt(hob) then
        warn("[Autofarm] Panela encontrada está queimada. Ignorando fluxo da carne.")
        return false
    end

    print("[Autofarm] ChoppedMeat detectado. Indo colocar na panela")
    if not tryInteract(hob) then return false end

    -- 4. Enquanto assa, pegar o prato limpo mais próximo.
    task.wait(0.25)
    local _, afterPanType = getHeldItem()
    if afterPanType == "ChoppedMeat" then
        print("[Autofarm] Ainda está com ChoppedMeat; interação na panela pode ter falhado")
        return false
    end

    local plate = getNearestCleanEmptyPlate()
    if plate then
        print("[Autofarm] Carne assando. Pegando Plate limpo mais próximo")
        tryInteract(plate)
        waitForHeldType("Plate", 3)
    else
        print("[Autofarm] Nenhum Plate limpo encontrado enquanto a carne assa")
    end

    -- 5. Voltar para a panela e aguardar ficar pronta.
    print("[Autofarm] Voltando para a panela e aguardando TickImage")
    moveNear(hob)
    if not waitForPanReady(hob) then
        return false
    end

    -- 6. Precisa estar com Plate para pegar a carne pronta.
    local heldPlate, heldPlateType = getHeldItem()
    if heldPlateType ~= "Plate" then
        local newPlate = getNearestCleanEmptyPlate()
        if newPlate then
            print("[Autofarm] Pegando Plate antes de retirar CookedMeat")
            tryInteract(newPlate)
            heldPlate = waitForHeldType("Plate", 3)
        end
    end

    if not heldPlate then
        print("[Autofarm] Não há Plate na mão para pegar a carne pronta")
        return false
    end

    print("[Autofarm] Carne pronta. Pegando CookedMeat com o Plate")
    if not tryInteract(hob) then return false end

    task.wait(0.35)

    -- 7. Colocar prato com CookedMeat em bancada vazia mais próxima.
    local heldAfter = select(1, getHeldItem())
    if heldAfter and hasIngredient(heldAfter, "CookedMeat") then
        print("[Autofarm] Plate com CookedMeat. Colocando na Countertop vazia mais próxima")
        putHeldPlateOnCounter()
        waitUntilHandsEmpty(2)
        productionStep = "Pineapple"
        return true
    end

    print("[Autofarm] Não confirmou CookedMeat no prato após pegar da panela")
    return false
end

------------------------------------------------------------
-- FLUXOS DOS INGREDIENTES FINAIS
------------------------------------------------------------

local function fullCutAndPlateFlow(foodType, finalType, nextStep)
    local _, heldType = getHeldItem()

    if heldType ~= foodType and heldType ~= finalType then
        print("[Autofarm] Pegando " .. foodType .. " no FoodBin")
        if not getFoodAndWait(foodType) then
            print("[Autofarm] Não conseguiu confirmar " .. foodType .. " na mão")
            return false
        end
    end

    heldType = select(2, getHeldItem())
    if heldType == foodType then
        print("[Autofarm] " .. foodType .. " detectado. Indo cortar")
        if not cutHeldRawIngredient(foodType, finalType) then
            print("[Autofarm] Falhou ao transformar " .. foodType .. " em " .. finalType)
            return false
        end
    end

    heldType = select(2, getHeldItem())
    if heldType ~= finalType then
        print("[Autofarm] Ainda não está segurando " .. finalType)
        return false
    end

    local plate = getBestPlate(finalType)
    if not plate then
        print("[Autofarm] Nenhum prato válido para " .. finalType)
        return false
    end

    print("[Autofarm] Colocando " .. finalType .. " no melhor Plate")
    if not tryInteract(plate) then return false end

    task.wait(0.35)

    -- Se completou, vender. Se não, continuar para o próximo ingrediente.
    local complete = getNearestCompletePlate()
    if complete then
        print("[Autofarm] Prato completo detectado. Vendendo")
        if tryInteract(complete) then
            task.wait(0.2)
            local held = select(1, getHeldItem())
            if held and isHeldPlateComplete(held) then
                sellHeldOrWorldCompletePlate(held)
            end
        end
        productionStep = "Meat"
        return true
    end

    productionStep = nextStep
    return true
end

------------------------------------------------------------
-- FLUXOS POR ITEM NA MÃO
------------------------------------------------------------

local function handleRawIngredient(itemType)
    local expected
    if itemType == "RawBeef" then
        expected = "ChoppedMeat"
    elseif itemType == "Pineapple" then
        expected = "PineappleRings"
    elseif itemType == "Tomato" then
        expected = "ChoppedTomato"
    end

    if not expected then return end

    doAction("Cortar " .. itemType, function()
        cutHeldRawIngredient(itemType, expected)
    end)
end

local function handleChoppedMeat()
    doAction("Fluxo da carne: colocar ChoppedMeat na panela, pegar prato e retirar CookedMeat", function()
        local hob = getNearestHobWithPan()
        if not hob then return end

        if isPanBurnt(hob) then
            warn("[Autofarm] Panela mais próxima está queimada. Ignorando.")
            return
        end

        if not tryInteract(hob) then return end

        local plate = getNearestCleanEmptyPlate()
        if plate then
            print("[Autofarm] Pegando Plate enquanto a carne assa")
            tryInteract(plate)
            waitForHeldType("Plate", 3)
        end

        moveNear(hob)
        if waitForPanReady(hob) then
            local _, heldType = getHeldItem()
            if heldType == "Plate" then
                tryInteract(hob)
                task.wait(0.35)
                local held = select(1, getHeldItem())
                if held and hasIngredient(held, "CookedMeat") then
                    putHeldPlateOnCounter()
                    productionStep = "Pineapple"
                end
            end
        end
    end)
end

local function handleFinalIngredient(itemType)
    doAction("Colocar " .. itemType .. " no melhor Plate", function()
        local plate = getBestPlate(itemType)
        if not plate then
            print("[Autofarm] Nenhum prato válido encontrado para:", itemType)
            return
        end

        tryInteract(plate)
        task.wait(0.35)

        local complete = getNearestCompletePlate()
        if complete then
            print("[Autofarm] Prato completo detectado após adicionar ingrediente. Vendendo")
            if tryInteract(complete) then
                task.wait(0.2)
                local held = select(1, getHeldItem())
                if held and isHeldPlateComplete(held) then
                    sellHeldOrWorldCompletePlate(held)
                end
            end
            productionStep = "Meat"
        elseif itemType == "PineappleRings" then
            productionStep = "Tomato"
        elseif itemType == "ChoppedTomato" then
            productionStep = "Meat"
        end
    end)
end

local function handleDirtyPlate()
    local sink = getNearestAppliance("Sink")
    if not sink then return end

    doAction("Lavar DirtyPlate", function()
        tryInteract(sink)
        waitForSinkToFinish(sink)

        task.wait(0.2)

        local _, heldType = getHeldItem()
        if heldType == "Plate" then
            print("[Autofarm] Plate limpo após lavar. Colocando na Countertop vazia")
            putHeldPlateOnCounter()
        end
    end)
end

local function handleCleanPlate(held)
    if isHeldPlateComplete(held) then
        doAction("Vender Plate completo", function()
            sellHeldOrWorldCompletePlate(held)
            productionStep = "Meat"
        end)
        return
    end

    local readyPan = getNearestReadyPan()
    if readyPan then
        doAction("Pegar CookedMeat pronto com Plate", function()
            tryInteract(readyPan)
            task.wait(0.35)

            local heldAfter = select(1, getHeldItem())
            if heldAfter and hasIngredient(heldAfter, "CookedMeat") then
                putHeldPlateOnCounter()
                productionStep = "Pineapple"
            end
        end)
        return
    end

    if isHeldPlatePartial(held) then
        doAction("Colocar Plate parcial na Countertop vazia", function()
            putHeldPlateOnCounter()
        end)
        return
    end

    doAction("Colocar Plate limpo na Countertop vazia", function()
        putHeldPlateOnCounter()
    end)
end

------------------------------------------------------------
-- BUSCA DE NOVA TAREFA QUANDO NÃO HÁ ITEM NA MÃO
------------------------------------------------------------

local function handleEmptyHands()
    -- 1. Vender prato completo primeiro.
    local completePlate = getNearestCompletePlate()
    if completePlate then
        doAction("Pegar e vender Plate completo", function()
            sellHeldOrWorldCompletePlate(nil)
            productionStep = "Meat"
        end)
        return
    end

    -- 2. Se existe panela pronta por algum motivo, pegar Plate e retirar.
    local readyPan = getNearestReadyPan()
    if readyPan then
        doAction("Panela pronta: pegar Plate e retirar CookedMeat", function()
            local plate = getNearestCleanEmptyPlate()
            if plate then
                tryInteract(plate)
                if waitForHeldType("Plate", 3) then
                    tryInteract(readyPan)
                    task.wait(0.35)
                    local held = select(1, getHeldItem())
                    if held and hasIngredient(held, "CookedMeat") then
                        putHeldPlateOnCounter()
                        productionStep = "Pineapple"
                    end
                end
            end
        end)
        return
    end

    -- 3. Lavar pratos sujos quando spawnarem.
    local dirty = getNearestWhere(function(obj)
        return obj:GetAttribute("Type") == "DirtyPlate" or obj.Name == "DirtyPlate"
    end)

    if dirty then
        doAction("Pegar DirtyPlate e lavar", function()
            tryInteract(dirty)
            task.wait(0.2)

            local _, heldType = getHeldItem()
            if heldType == "DirtyPlate" then
                local sink = getNearestAppliance("Sink")
                if sink then
                    tryInteract(sink)
                    waitForSinkToFinish(sink)
                    task.wait(0.2)

                    local _, afterType = getHeldItem()
                    if afterType == "Plate" then
                        putHeldPlateOnCounter()
                    end
                end
            end
        end)
        return
    end

    -- 4. Produção em ordem: CARNE SEMPRE PRIMEIRO, depois ABACAXI, depois TOMATE.
    if productionStep == "Meat" then
        doAction("Fluxo completo da carne", function()
            fullMeatFlowFromRawBeef()
        end)
        return
    end

    if productionStep == "Pineapple" then
        doAction("Fluxo do abacaxi", function()
            fullCutAndPlateFlow("Pineapple", "PineappleRings", "Tomato")
        end)
        return
    end

    if productionStep == "Tomato" then
        doAction("Fluxo do tomate", function()
            fullCutAndPlateFlow("Tomato", "ChoppedTomato", "Meat")
        end)
        return
    end

    productionStep = "Meat"
end

------------------------------------------------------------
-- LOOP PRINCIPAL
------------------------------------------------------------

RunService.Heartbeat:Connect(function()
    if not canAct() then
        return
    end

    local char = getCharacter()
    if not char then return end

    -- Se alguma pia está lavando, respeitar a regra de não fazer nada.
    local activeSink = getActiveSink()
    if activeSink then
        return
    end

    local held, itemType = getHeldItem()

    if itemType == "RawBeef" or itemType == "Pineapple" or itemType == "Tomato" then
        handleRawIngredient(itemType)

    elseif itemType == "ChoppedMeat" then
        handleChoppedMeat()

    elseif itemType == "PineappleRings" or itemType == "ChoppedTomato" then
        handleFinalIngredient(itemType)

    elseif itemType == "DirtyPlate" then
        handleDirtyPlate()

    elseif itemType == "Plate" then
        handleCleanPlate(held)

    else
        handleEmptyHands()
    end
end)
