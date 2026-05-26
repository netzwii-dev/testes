-- AUTOFARM: CAOS NA COZINHA / COOKING CHAOS
-- Versao: 1 clique por etapa + delay 2s antes de teleporte + espera 0.5s antes de interagir
-- Baseado nas regras do TXT: Kebab / Cidade Symmetri
-- Uso recomendado: somente em jogo proprio / ambiente de teste.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Interactables = Workspace:WaitForChild("Interactables")

------------------------------------------------------------
-- CONFIG
------------------------------------------------------------

local USE_TELEPORT = true
local PRE_TELEPORT_DELAY = 2.00      -- espera ANTES de teleportar para a proxima etapa
local PROMPT_SETTLE_DELAY = 0.50     -- espera DEPOIS de teleportar, antes do unico clique
local ACTION_COOLDOWN = 0.30
local INTERACT_DISTANCE = 8
local TELEPORT_OFFSET = 4.5
local VERIFY_TIMEOUT = 10

local busy = false
local lastAction = 0
local currentState = "Idle"

------------------------------------------------------------
-- LOG
------------------------------------------------------------

local function log(...)
    print("[Autofarm]", ...)
end

------------------------------------------------------------
-- UTILS BASICOS
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

local function safeCFrame(obj)
    if not obj then return nil end

    if obj:IsA("Model") then
        local ok, cf = pcall(function()
            return obj:GetPivot()
        end)
        if ok and cf then return cf end
    end

    if obj:IsA("BasePart") then
        return obj.CFrame
    end

    local part = obj:FindFirstChildWhichIsA("BasePart", true)
    if part then
        return part.CFrame
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

local function waitUntil(predicate, label, timeout)
    timeout = timeout or VERIFY_TIMEOUT
    local started = now()

    while now() - started < timeout do
        local ok, result = pcall(predicate)
        if ok and result then
            log("Confirmado:", label)
            return true
        end
        task.wait(0.12)
    end

    log("Nao confirmou:", label)
    return false
end

------------------------------------------------------------
-- ITEM NA MAO
------------------------------------------------------------

local VALID_TYPES = {
    RawBeef = true,
    Pineapple = true,
    Tomato = true,
    ChoppedMeat = true,
    PineappleRings = true,
    ChoppedTomato = true,
    Plate = true,
    DirtyPlate = true,
}

local function typeFromObj(obj)
    if not obj then return nil end

    local attr = obj:GetAttribute("Type")
    if attr and VALID_TYPES[attr] then
        return attr
    end

    if VALID_TYPES[obj.Name] then
        return obj.Name
    end

    return nil
end

local function getHandParts()
    local char = getCharacter()
    if not char then return {} end

    local parts = {}
    local names = {
        "RightHand",
        "Right Arm",
        "LeftHand",
        "Left Arm",
        "HumanoidRootPart",
    }

    for _, name in ipairs(names) do
        local part = char:FindFirstChild(name, true)
        if part and part:IsA("BasePart") then
            table.insert(parts, part)
        end
    end

    return parts
end

local function nearHand(obj)
    local pos = safePivot(obj)
    if not pos then return false end

    for _, part in ipairs(getHandParts()) do
        if (part.Position - pos).Magnitude <= 7 then
            return true
        end
    end

    return false
end

local function getHeldItem()
    local char = getCharacter()
    if not char then return nil, nil end

    -- 1. Filhos diretos do Character.
    for _, child in ipairs(char:GetChildren()) do
        local t = typeFromObj(child)
        if t then return child, t end
    end

    -- 2. Tool e descendentes de Tool.
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then
        local t = typeFromObj(tool)
        if t then return tool, t end

        for _, d in ipairs(tool:GetDescendants()) do
            local dt = typeFromObj(d)
            if dt then return tool, dt end
        end
    end

    -- 3. Descendentes do Character.
    for _, d in ipairs(char:GetDescendants()) do
        local t = typeFromObj(d)
        if t then return d, t end
    end

    -- 4. Fallback: item do Interactables colado/perto da mao.
    for _, obj in ipairs(Interactables:GetDescendants()) do
        local t = typeFromObj(obj)
        if t and nearHand(obj) then
            return obj, t
        end
    end

    return nil, nil
end

local function heldIs(itemType)
    local _, heldType = getHeldItem()
    return heldType == itemType
end

local function handEmpty()
    local _, heldType = getHeldItem()
    return heldType == nil
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

    if container.Name == ingredientName then return true end
    if container:GetAttribute("Type") == ingredientName then return true end

    return container:FindFirstChild(ingredientName, true) ~= nil
end

------------------------------------------------------------
-- PRATOS / BANCADAS
------------------------------------------------------------

local BLOCK_COUNTER = {
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

local function heldPlateHas(ingredientName)
    local held, heldType = getHeldItem()
    return heldType == "Plate" and hasIngredient(held, ingredientName)
end

local function heldPlateComplete()
    local held, heldType = getHeldItem()
    return heldType == "Plate" and getPlateState(held).complete
end

local function getAllWorldPlates()
    local plates = {}
    local seen = {}

    for _, obj in ipairs(Interactables:GetDescendants()) do
        if isPlateObject(obj) and not isDescendantOfCharacter(obj) and not seen[obj] then
            seen[obj] = true
            table.insert(plates, obj)
        end
    end

    return plates
end

local function getNearestCleanEmptyPlate()
    return getNearestWhere(function(obj)
        if not isPlateObject(obj) then return false end
        return getPlateState(obj).count == 0
    end)
end

local function getNearestCompletePlate()
    return getNearestWhere(function(obj)
        if not isPlateObject(obj) then return false end
        return getPlateState(obj).complete
    end)
end

local function getNearestEmptyCountertop()
    return getNearestWhere(function(obj)
        if obj:GetAttribute("ApplianceType") ~= "Countertop" and obj.Name ~= "Countertop" then
            return false
        end

        for _, d in ipairs(obj:GetDescendants()) do
            if BLOCK_COUNTER[d.Name] or BLOCK_COUNTER[d:GetAttribute("Type")] then
                return false
            end
        end

        return true
    end)
end

local function plateAlreadyHasIngredient(state, ingredientType)
    if ingredientType == "CookedMeat" then return state.hasMeat end
    if ingredientType == "PineappleRings" then return state.hasPineapple end
    if ingredientType == "ChoppedTomato" then return state.hasTomato end
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
    local bestPlate = nil
    local bestScore = -math.huge
    local bestDistance = math.huge

    for _, plate in ipairs(getAllWorldPlates()) do
        local state = getPlateState(plate)
        if not state.complete and not plateAlreadyHasIngredient(state, ingredientType) then
            local score = state.count * 100
            if wouldCompletePlate(state, ingredientType) then
                score += 1000
            end

            -- Carne sempre tem prioridade de base: para abacaxi/tomate, preferir prato que ja tem carne.
            if ingredientType ~= "CookedMeat" and state.hasMeat then
                score += 500
            end

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

local function existsPlateWithMeatNeedsPineapple()
    for _, plate in ipairs(getAllWorldPlates()) do
        local s = getPlateState(plate)
        if s.hasMeat and not s.hasPineapple and not s.complete then return true end
    end
    return false
end

local function existsPlateWithMeatPineappleNeedsTomato()
    for _, plate in ipairs(getAllWorldPlates()) do
        local s = getPlateState(plate)
        if s.hasMeat and s.hasPineapple and not s.hasTomato then return true end
    end
    return false
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

    return burnt.Visible == true
        and burnt.ImageTransparency ~= nil
        and burnt.ImageTransparency < 0.5
end

local function isPanReady(hob)
    local pan = getFryingPan(hob)
    if not pan or isPanBurnt(hob) then return false end

    local tickImage = pan:FindFirstChild("TickImage", true)
    if not tickImage then return false end

    return tickImage.Visible == true
        and tickImage.ImageTransparency ~= nil
        and tickImage.ImageTransparency < 0.5
end

local function panHasChoppedMeat(hob)
    local pan = getFryingPan(hob)
    return pan and hasIngredient(pan, "ChoppedMeat")
end

local function getNearestReadyPan()
    return getNearestWhere(function(obj)
        if obj:GetAttribute("ApplianceType") ~= "Hob" and obj.Name ~= "Hob" then
            return false
        end
        return isPanReady(obj)
    end)
end

local function getNearestCookingPan()
    return getNearestWhere(function(obj)
        if obj:GetAttribute("ApplianceType") ~= "Hob" and obj.Name ~= "Hob" then
            return false
        end
        return panHasChoppedMeat(obj) and not isPanReady(obj) and not isPanBurnt(obj)
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
        if scale and scale > 0.01 then return true end
    end

    return false
end

local function waitForSinkToFinish(sink)
    return waitUntil(function()
        return not isSinkWashing(sink)
    end, "pia terminar lavagem", 14)
end

------------------------------------------------------------
-- TELEPORTE / INTERACAO: 1 CLIQUE POR ETAPA
------------------------------------------------------------

local function teleportNear(target)
    local root = getRoot()
    local cf = safeCFrame(target)
    if not root or not cf then return false end

    task.wait(PRE_TELEPORT_DELAY)

    local pos = cf.Position
    local look = cf.LookVector
    local targetPos = pos - (look * TELEPORT_OFFSET) + Vector3.new(0, 2.5, 0)

    root.CFrame = CFrame.lookAt(targetPos, pos)
    task.wait(PROMPT_SETTLE_DELAY)

    return true
end

local function walkNear(target)
    local humanoid = getHumanoid()
    local root = getRoot()
    local pos = safePivot(target)
    if not humanoid or not root or not pos then return false end

    task.wait(PRE_TELEPORT_DELAY)
    humanoid:MoveTo(pos)

    local started = now()
    while now() - started < 4 do
        root = getRoot()
        if not root then return false end
        if (root.Position - pos).Magnitude <= INTERACT_DISTANCE then
            task.wait(PROMPT_SETTLE_DELAY)
            return true
        end
        task.wait(0.05)
    end

    return false
end

local function goNear(target)
    if USE_TELEPORT then
        local ok = teleportNear(target)
        if ok then return true end
    end
    return walkNear(target)
end

local function findPrompt(target)
    if not target then return nil end
    if target:IsA("ProximityPrompt") then return target end
    return target:FindFirstChildWhichIsA("ProximityPrompt", true)
end

local function clickPromptOnce(prompt)
    if not prompt then return false end

    local hold = prompt.HoldDuration or 0

    pcall(function()
        prompt:InputHoldBegin()
    end)

    task.wait(math.max(hold + 0.04, 0.10))

    pcall(function()
        prompt:InputHoldEnd()
    end)

    return true
end

local function interactOnce(target, label)
    if not target then
        log("Alvo nil:", label)
        return false
    end

    local prompt = findPrompt(target)
    if not prompt then
        warn("[Autofarm] Nenhum ProximityPrompt encontrado em:", target:GetFullName())
        return false
    end

    log("Clique unico:", label)
    return clickPromptOnce(prompt)
end

-- Faz UMA tentativa: teleporta, espera 0.5s, clica UMA vez, depois apenas verifica.
-- Se nao confirmar, nao avanca para a proxima etapa; o loop principal podera tentar de novo depois.
local function doOneClickStep(target, label, confirmFn, timeout)
    timeout = timeout or VERIFY_TIMEOUT

    if confirmFn and confirmFn() then
        log("Ja confirmado:", label)
        return true
    end

    if not goNear(target) then
        log("Falhou ao chegar:", label)
        return false
    end

    local clicked = interactOnce(target, label)
    if not clicked then return false end

    if not confirmFn then return true end

    return waitUntil(confirmFn, label, timeout)
end

------------------------------------------------------------
-- EXECUCAO SEGURA DE ACOES
------------------------------------------------------------

local function doAction(stateName, fn)
    if not canAct() then return end

    setBusy(true, stateName)
    lastAction = now()
    log("Acao:", stateName)

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
-- FLUXOS
------------------------------------------------------------

local function cutIngredient(rawType, choppedType)
    if not heldIs(rawType) then
        log("Bloqueado: preciso estar com", rawType, "na mao.")
        return
    end

    local board = getNearestAppliance("ChoppingBoard")
    if not board then
        log("Sem ChoppingBoard.")
        return
    end

    local placed = doOneClickStep(board, "colocar " .. rawType .. " na ChoppingBoard", function()
        return not heldIs(rawType) or hasIngredient(board, rawType) or hasIngredient(board, choppedType)
    end, 5)

    if not placed then return end

    waitUntil(function()
        return hasIngredient(board, choppedType) or heldIs(choppedType)
    end, rawType .. " virar " .. choppedType, 12)

    if heldIs(choppedType) then return end

    doOneClickStep(board, "pegar " .. choppedType .. " da ChoppingBoard", function()
        return heldIs(choppedType)
    end, 8)
end

local function putChoppedMeatOnPan()
    if not heldIs("ChoppedMeat") then
        log("Bloqueado: so vou para a panela com ChoppedMeat na mao.")
        return
    end

    local hob = getNearestHobWithPan()
    if not hob then
        log("Sem Hob/FryingPan.")
        return
    end

    if isPanBurnt(hob) then
        log("Panela queimada. Ignorando.")
        return
    end

    doOneClickStep(hob, "colocar ChoppedMeat na panela", function()
        return not heldIs("ChoppedMeat") and panHasChoppedMeat(hob)
    end, 7)
end

local function getPlateAndTakeCookedMeat(hob)
    if not hob then return end

    if not heldIs("Plate") then
        if not handEmpty() then
            log("Bloqueado: mao ocupada, nao vou buscar Plate.")
            return
        end

        local plate = getNearestCleanEmptyPlate()
        if not plate then
            log("Sem Plate limpo vazio.")
            return
        end

        local gotPlate = doOneClickStep(plate, "pegar Plate limpo", function()
            return heldIs("Plate")
        end, 7)

        if not gotPlate then return end
    end

    if not heldIs("Plate") then
        log("Bloqueado: nao vou para panela sem Plate na mao.")
        return
    end

    waitUntil(function()
        return isPanReady(hob) or isPanBurnt(hob)
    end, "carne ficar pronta na panela", 18)

    if isPanBurnt(hob) then
        log("Carne queimou. Nao vou pegar.")
        return
    end

    local gotMeat = doOneClickStep(hob, "pegar CookedMeat com Plate", function()
        return heldPlateHas("CookedMeat")
    end, 8)

    if not gotMeat then return end

    local counter = getNearestEmptyCountertop()
    if counter and heldPlateHas("CookedMeat") then
        doOneClickStep(counter, "colocar Plate com CookedMeat na bancada", function()
            return handEmpty()
        end, 7)
    end
end

local function addFinalIngredientToPlate(itemType)
    if not heldIs(itemType) then
        log("Bloqueado: preciso estar com", itemType, "na mao.")
        return
    end

    local plate = getBestPlate(itemType)
    if not plate then
        log("Nenhum prato valido para", itemType)
        return
    end

    doOneClickStep(plate, "colocar " .. itemType .. " no melhor Plate", function()
        return not heldIs(itemType)
    end, 7)
end

local function sellHeldCompletePlate()
    if not heldPlateComplete() then return false end

    local sellPoint = getNearestByName("SellPoint")
        or getNearestAppliance("Sell")
        or getNearestByName("Sell")

    if not sellPoint then
        log("Sem SellPoint.")
        return false
    end

    return doOneClickStep(sellPoint, "vender Plate completo", function()
        return handEmpty()
    end, 7)
end

local function pickAndSellWorldCompletePlate()
    local completePlate = getNearestCompletePlate()
    if not completePlate then return false end

    local got = doOneClickStep(completePlate, "pegar Plate completo", function()
        return heldIs("Plate") and heldPlateComplete()
    end, 7)

    if got then
        return sellHeldCompletePlate()
    end

    return false
end

local function washDirtyPlate()
    if not heldIs("DirtyPlate") then
        log("Bloqueado: preciso estar com DirtyPlate na mao.")
        return
    end

    local sink = getNearestAppliance("Sink")
    if not sink then
        log("Sem Sink.")
        return
    end

    doOneClickStep(sink, "colocar DirtyPlate na Sink", function()
        return isSinkWashing(sink) or not heldIs("DirtyPlate")
    end, 7)

    waitForSinkToFinish(sink)

    if heldIs("Plate") then
        local counter = getNearestEmptyCountertop()
        if counter then
            doOneClickStep(counter, "colocar Plate limpo na bancada", function()
                return handEmpty()
            end, 7)
        end
    end
end

local function pickDirtyPlateIfAny()
    local dirty = getNearestWhere(function(obj)
        return obj:GetAttribute("Type") == "DirtyPlate" or obj.Name == "DirtyPlate"
    end)

    if not dirty then return false end

    return doOneClickStep(dirty, "pegar DirtyPlate", function()
        return heldIs("DirtyPlate")
    end, 7)
end

local function placeHeldPlateIfNeeded()
    if not heldIs("Plate") then return end

    if heldPlateComplete() then
        sellHeldCompletePlate()
        return
    end

    local readyPan = getNearestReadyPan()
    if readyPan then
        getPlateAndTakeCookedMeat(readyPan)
        return
    end

    local counter = getNearestEmptyCountertop()
    if counter then
        doOneClickStep(counter, "colocar Plate na bancada", function()
            return handEmpty()
        end, 7)
    end
end

local function getFoodBinItem(foodType)
    local bin = getNearestFoodBin(foodType)
    if not bin then
        log("Sem FoodBin:", foodType)
        return
    end

    doOneClickStep(bin, "pegar " .. foodType .. " no FoodBin", function()
        return heldIs(foodType)
    end, 7)
end

local function handleEmptyHands()
    -- 1. Vender prato pronto se existir.
    if pickAndSellWorldCompletePlate() then return end

    -- 2. Se tiver prato sujo, lavar.
    if pickDirtyPlateIfAny() then return end

    -- 3. Se a carne estiver pronta, pegar Plate e retirar da panela.
    local readyPan = getNearestReadyPan()
    if readyPan then
        getPlateAndTakeCookedMeat(readyPan)
        return
    end

    -- 4. Se a carne ainda estiver assando, esperar. Nao spammar panela.
    local cookingPan = getNearestCookingPan()
    if cookingPan then
        log("Carne ainda assando. Aguardando ficar pronta antes de buscar Plate.")
        return
    end

    -- 5. Carne sempre primeiro. Depois abacaxi. Depois tomate.
    if existsPlateWithMeatPineappleNeedsTomato() then
        getFoodBinItem("Tomato")
        return
    end

    if existsPlateWithMeatNeedsPineapple() then
        getFoodBinItem("Pineapple")
        return
    end

    getFoodBinItem("RawBeef")
end

------------------------------------------------------------
-- LOOP PRINCIPAL
------------------------------------------------------------

RunService.Heartbeat:Connect(function()
    if not canAct() then return end
    if not getCharacter() then return end

    -- Durante lavagem, nao faz nada.
    local activeSink = getNearestWhere(function(obj)
        if obj:GetAttribute("ApplianceType") == "Sink" or obj.Name == "Sink" then
            return isSinkWashing(obj)
        end
        return false
    end)

    if activeSink then return end

    local _, itemType = getHeldItem()

    if itemType == "RawBeef" then
        doAction("RawBeef > ChoppingBoard > ChoppedMeat", function()
            cutIngredient("RawBeef", "ChoppedMeat")
        end)

    elseif itemType == "ChoppedMeat" then
        doAction("ChoppedMeat > Hob/FryingPan", function()
            putChoppedMeatOnPan()
        end)

    elseif itemType == "Pineapple" then
        doAction("Pineapple > ChoppingBoard > PineappleRings", function()
            cutIngredient("Pineapple", "PineappleRings")
        end)

    elseif itemType == "PineappleRings" then
        doAction("PineappleRings > Plate", function()
            addFinalIngredientToPlate("PineappleRings")
        end)

    elseif itemType == "Tomato" then
        doAction("Tomato > ChoppingBoard > ChoppedTomato", function()
            cutIngredient("Tomato", "ChoppedTomato")
        end)

    elseif itemType == "ChoppedTomato" then
        doAction("ChoppedTomato > Plate", function()
            addFinalIngredientToPlate("ChoppedTomato")
        end)

    elseif itemType == "DirtyPlate" then
        doAction("DirtyPlate > Sink", function()
            washDirtyPlate()
        end)

    elseif itemType == "Plate" then
        doAction("Plate na mao", function()
            placeHeldPlateIfNeeded()
        end)

    else
        doAction("Mao vazia > proxima tarefa", function()
            handleEmptyHands()
        end)
    end
end)

print("[Autofarm] Cooking Chaos carregado | 1 clique por etapa | TP delay 2s | espera interacao 0.5s")
