-- AUTOFARM: CAOS NA COZINHA / COOKING CHAOS
-- Baseado nas regras do TXT: Kebab / Cidade Symmetri
-- Versão: teleporte rápido + confirmação obrigatória + atraso global antes de teletransportar
-- Uso recomendado: somente em jogo próprio / ambiente de teste.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Interactables = Workspace:WaitForChild("Interactables")

------------------------------------------------------------
-- CONFIG
------------------------------------------------------------

local USE_TELEPORT = true

-- Espera antes de CADA teleporte.
-- Corrige o bug de teleportar antes do servidor/cliente terminar a ação anterior.
local PRE_TELEPORT_DELAY = 1.00

-- Espera depois do teleporte para a marcação/prompt aparecer.
local PROMPT_SETTLE_DELAY = 0.35

-- Intervalo entre tentativas de interação enquanto espera a condição correta.
local CLICK_RETRY_DELAY = 0.12

local ACTION_COOLDOWN = 0.18
local INTERACT_DISTANCE = 8
local TELEPORT_OFFSET = 4.5
local WAIT_TIMEOUT = 12

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

------------------------------------------------------------
-- ITEM NA MÃO
------------------------------------------------------------

local VALID_ITEM_TYPES = {
    RawBeef = true,
    Pineapple = true,
    Tomato = true,
    ChoppedMeat = true,
    PineappleRings = true,
    ChoppedTomato = true,
    Plate = true,
    DirtyPlate = true,
}

local function getTypeFromObject(obj)
    if not obj then return nil end

    local attr = obj:GetAttribute("Type")
    if attr and VALID_ITEM_TYPES[attr] then
        return attr
    end

    if VALID_ITEM_TYPES[obj.Name] then
        return obj.Name
    end

    return nil
end

local function getHeldItem()
    local char = getCharacter()
    if not char then return nil, nil end

    -- 1. filhos diretos do Character
    for _, child in ipairs(char:GetChildren()) do
        local t = getTypeFromObject(child)
        if t then
            return child, t
        end
    end

    -- 2. Tool e descendentes
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then
        local t = getTypeFromObject(tool)
        if t then return tool, t end

        for _, d in ipairs(tool:GetDescendants()) do
            t = getTypeFromObject(d)
            if t then return tool, t end
        end
    end

    -- 3. descendentes do Character
    for _, d in ipairs(char:GetDescendants()) do
        local t = getTypeFromObject(d)
        if t then
            return d, t
        end
    end

    -- 4. fallback: item muito perto da mão/corpo, comum quando o item fica em Workspace.Interactables
    local root = getRoot()
    if root then
        local best, bestType, bestD = nil, nil, math.huge

        for _, obj in ipairs(Interactables:GetDescendants()) do
            local t = getTypeFromObject(obj)
            if t then
                local pos = safePivot(obj)
                if pos then
                    local d = (root.Position - pos).Magnitude
                    if d < bestD and d <= 5.5 then
                        best = obj
                        bestType = t
                        bestD = d
                    end
                end
            end
        end

        if best then
            return best, bestType
        end
    end

    return nil, nil
end

local function heldIs(expectedType)
    local _, itemType = getHeldItem()
    return itemType == expectedType
end

local function handEmpty()
    local _, itemType = getHeldItem()
    return itemType == nil
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
            FryingPan = true,
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
-- TELEPORTE / INTERAÇÃO
------------------------------------------------------------

local function teleportNear(target)
    local root = getRoot()
    local cf = safeCFrame(target)

    if not root or not cf then
        return false
    end

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

    if not humanoid or not root or not pos then
        return false
    end

    if (root.Position - pos).Magnitude <= INTERACT_DISTANCE then
        return true
    end

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

    if target:IsA("ProximityPrompt") then
        return target
    end

    return target:FindFirstChildWhichIsA("ProximityPrompt", true)
end

local function clickPrompt(prompt)
    if not prompt then return false end

    local hold = prompt.HoldDuration or 0

    pcall(function()
        prompt:InputHoldBegin()
    end)

    task.wait(math.max(hold + 0.03, 0.08))

    pcall(function()
        prompt:InputHoldEnd()
    end)

    return true
end

local function interactOnce(target)
    if not target then return false end

    local prompt = findPrompt(target)

    if prompt then
        return clickPrompt(prompt)
    end

    warn("[Autofarm] Nenhum ProximityPrompt encontrado em:", target:GetFullName())
    return false
end

-- Interage até a condição ficar verdadeira.
-- Isso impede avançar sem pegar/soltar o item exato esperado.
local function interactUntil(target, conditionFn, label, timeout)
    timeout = timeout or WAIT_TIMEOUT

    if not target then
        log("Falhou:", label, "alvo nil")
        return false
    end

    if conditionFn and conditionFn() then
        log("OK antes de clicar:", label)
        return true
    end

    local reached = goNear(target)
    if not reached then
        log("Falhou ao chegar:", label)
        return false
    end

    local started = now()
    while now() - started < timeout do
        if conditionFn and conditionFn() then
            log("Confirmado:", label)
            return true
        end

        interactOnce(target)

        task.wait(CLICK_RETRY_DELAY)

        if conditionFn and conditionFn() then
            log("Confirmado:", label)
            return true
        end
    end

    log("Timeout:", label)
    return false
end

local function waitUntil(conditionFn, label, timeout)
    timeout = timeout or WAIT_TIMEOUT
    local started = now()

    while now() - started < timeout do
        if conditionFn() then
            log("Confirmado:", label)
            return true
        end
        task.wait(0.12)
    end

    log("Timeout esperando:", label)
    return false
end

local function doAction(stateName, fn)
    if not canAct() then return end

    setBusy(true, stateName)
    lastAction = now()
    log("AÇÃO:", stateName)

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

local function heldPlateHas(ingredientName)
    local held, itemType = getHeldItem()
    return itemType == "Plate" and hasIngredient(held, ingredientName)
end

local function heldPlateComplete()
    local held, itemType = getHeldItem()
    if itemType ~= "Plate" then return false end
    return getPlateState(held).complete
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
        if not isPlateObject(obj) then return false end
        return getPlateState(obj).complete
    end)
end

local function getNearestCleanEmptyPlate()
    return getNearestWhere(function(obj)
        if not isPlateObject(obj) then return false end
        return getPlateState(obj).count == 0
    end)
end

------------------------------------------------------------
-- CHOPPING BOARD
------------------------------------------------------------

local function boardHas(board, itemType)
    return hasIngredient(board, itemType)
end

local function cutIngredient(rawType, choppedType)
    local board = getNearestAppliance("ChoppingBoard")
    if not board then
        log("Sem ChoppingBoard para", rawType)
        return
    end

    if not heldIs(rawType) then
        log("Bloqueado: preciso estar com", rawType, "na mão.")
        return
    end

    local placed = interactUntil(board, function()
        return not heldIs(rawType) or boardHas(board, rawType) or boardHas(board, choppedType)
    end, "colocar " .. rawType .. " na ChoppingBoard", 8)

    if not placed then return end

    waitUntil(function()
        return boardHas(board, choppedType) or heldIs(choppedType)
    end, rawType .. " virar " .. choppedType, 10)

    if heldIs(choppedType) then
        return
    end

    interactUntil(board, function()
        return heldIs(choppedType)
    end, "pegar " .. choppedType .. " da ChoppingBoard", 8)
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

local function putChoppedMeatOnPan()
    local hob = getNearestHobWithPan()
    if not hob then
        log("Sem Hob/FryingPan.")
        return
    end

    if isPanBurnt(hob) then
        log("Panela queimada. Ignorando.")
        return
    end

    if not heldIs("ChoppedMeat") then
        log("Bloqueado: só vou para a panela com ChoppedMeat na mão.")
        return
    end

    interactUntil(hob, function()
        return not heldIs("ChoppedMeat") and panHasChoppedMeat(hob)
    end, "colocar ChoppedMeat na panela", 8)
end

local function pickPlateForReadyPan(hob)
    if not hob then return end

    if not handEmpty() then
        log("Bloqueado: só vou buscar Plate se a mão estiver vazia.")
        return
    end

    local plate = getNearestCleanEmptyPlate()
    if not plate then
        log("Sem Plate limpo vazio para pegar carne.")
        return
    end

    local gotPlate = interactUntil(plate, function()
        return heldIs("Plate")
    end, "pegar Plate limpo", 8)

    if not gotPlate then return end

    if not heldIs("Plate") then
        log("Bloqueado: não vou para panela sem Plate na mão.")
        return
    end

    waitUntil(function()
        return isPanReady(hob) or isPanBurnt(hob)
    end, "carne da panela ficar pronta", 16)

    if isPanBurnt(hob) then
        log("Carne queimou. Não vou pegar.")
        return
    end

    interactUntil(hob, function()
        return heldPlateHas("CookedMeat")
    end, "pegar CookedMeat com Plate", 10)

    if heldPlateHas("CookedMeat") then
        local counter = getNearestEmptyCountertop()
        if counter then
            interactUntil(counter, function()
                return handEmpty()
            end, "colocar Plate com CookedMeat na bancada", 8)
        end
    else
        log("Bloqueado: Plate ainda não tem CookedMeat, não vou para bancada.")
    end
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
    return waitUntil(function()
        return not isSinkWashing(sink)
    end, "pia terminar lavagem", 14)
end

local function handleDirtyPlate()
    local sink = getNearestAppliance("Sink")
    if not sink then return end

    if not heldIs("DirtyPlate") then
        log("Bloqueado: preciso estar com DirtyPlate para lavar.")
        return
    end

    interactUntil(sink, function()
        return isSinkWashing(sink) or not heldIs("DirtyPlate")
    end, "colocar DirtyPlate na Sink", 8)

    waitForSinkToFinish(sink)

    task.wait(0.3)

    if heldIs("Plate") then
        local counter = getNearestEmptyCountertop()
        if counter then
            interactUntil(counter, function()
                return handEmpty()
            end, "colocar Plate limpo na bancada", 8)
        end
    end
end

------------------------------------------------------------
-- FINAL INGREDIENTS / SELL
------------------------------------------------------------

local function addFinalIngredient(itemType)
    if not heldIs(itemType) then
        log("Bloqueado: não estou com", itemType, "na mão.")
        return
    end

    local plate = getBestPlate(itemType)
    if not plate then
        log("Nenhum prato válido para", itemType)
        return
    end

    interactUntil(plate, function()
        return not heldIs(itemType)
    end, "colocar " .. itemType .. " no melhor Plate", 8)
end

local function sellCompletePlate()
    local sellPoint = getNearestByName("SellPoint")
        or getNearestAppliance("Sell")
        or getNearestByName("Sell")

    if not sellPoint then
        log("SellPoint não encontrado.")
        return
    end

    if heldIs("Plate") and heldPlateComplete() then
        interactUntil(sellPoint, function()
            return handEmpty()
        end, "vender Plate completo", 8)
        return
    end

    local completePlate = getNearestCompletePlate()
    if completePlate then
        local got = interactUntil(completePlate, function()
            return heldIs("Plate") and heldPlateComplete()
        end, "pegar Plate completo", 8)

        if got then
            interactUntil(sellPoint, function()
                return handEmpty()
            end, "vender Plate completo", 8)
        end
    end
end

------------------------------------------------------------
-- FLUXOS PRINCIPAIS
------------------------------------------------------------

local function makeMeatFlow()
    local _, itemType = getHeldItem()

    if itemType == "RawBeef" then
        cutIngredient("RawBeef", "ChoppedMeat")
        return
    end

    if itemType == "ChoppedMeat" then
        putChoppedMeatOnPan()
        return
    end

    if handEmpty() then
        local readyPan = getNearestReadyPan()
        if readyPan then
            pickPlateForReadyPan(readyPan)
            return
        end

        local cookingPan = getNearestWhere(function(obj)
            if obj:GetAttribute("ApplianceType") ~= "Hob" and obj.Name ~= "Hob" then
                return false
            end
            return panHasChoppedMeat(obj) and not isPanReady(obj) and not isPanBurnt(obj)
        end)

        if cookingPan then
            local plate = getNearestCleanEmptyPlate()
            if plate then
                local got = interactUntil(plate, function()
                    return heldIs("Plate")
                end, "pegar Plate enquanto carne assa", 8)

                if got and heldIs("Plate") then
                    waitUntil(function()
                        return isPanReady(cookingPan) or isPanBurnt(cookingPan)
                    end, "carne assar enquanto seguro Plate", 16)

                    if isPanReady(cookingPan) then
                        interactUntil(cookingPan, function()
                            return heldPlateHas("CookedMeat")
                        end, "pegar CookedMeat com Plate", 10)

                        if heldPlateHas("CookedMeat") then
                            local counter = getNearestEmptyCountertop()
                            if counter then
                                interactUntil(counter, function()
                                    return handEmpty()
                                end, "colocar Plate com CookedMeat na bancada", 8)
                            end
                        end
                    end
                end
            end
            return
        end

        local rawBeefBin = getNearestFoodBin("RawBeef")
        if rawBeefBin then
            interactUntil(rawBeefBin, function()
                return heldIs("RawBeef")
            end, "pegar RawBeef", 8)
        end
    end
end

local function makePineappleFlow()
    local _, itemType = getHeldItem()

    if itemType == "Pineapple" then
        cutIngredient("Pineapple", "PineappleRings")
        return
    end

    if itemType == "PineappleRings" then
        addFinalIngredient("PineappleRings")
        return
    end

    if handEmpty() then
        local bin = getNearestFoodBin("Pineapple")
        if bin then
            interactUntil(bin, function()
                return heldIs("Pineapple")
            end, "pegar Pineapple", 8)
        end
    end
end

local function makeTomatoFlow()
    local _, itemType = getHeldItem()

    if itemType == "Tomato" then
        cutIngredient("Tomato", "ChoppedTomato")
        return
    end

    if itemType == "ChoppedTomato" then
        addFinalIngredient("ChoppedTomato")
        return
    end

    if handEmpty() then
        local bin = getNearestFoodBin("Tomato")
        if bin then
            interactUntil(bin, function()
                return heldIs("Tomato")
            end, "pegar Tomato", 8)
        end
    end
end

local function handlePlateInHand()
    if heldPlateComplete() then
        sellCompletePlate()
        return
    end

    local readyPan = getNearestReadyPan()
    if readyPan then
        interactUntil(readyPan, function()
            return heldPlateHas("CookedMeat")
        end, "pegar CookedMeat com Plate", 10)

        if heldPlateHas("CookedMeat") then
            local counter = getNearestEmptyCountertop()
            if counter then
                interactUntil(counter, function()
                    return handEmpty()
                end, "colocar Plate com CookedMeat na bancada", 8)
            end
        end
        return
    end

    local counter = getNearestEmptyCountertop()
    if counter then
        interactUntil(counter, function()
            return handEmpty()
        end, "colocar Plate na bancada", 8)
    end
end

local function handleEmptyHands()
    -- 1. vender prato completo
    local completePlate = getNearestCompletePlate()
    if completePlate then
        sellCompletePlate()
        return
    end

    -- 2. lavar prato sujo
    local dirty = getNearestWhere(function(obj)
        return obj:GetAttribute("Type") == "DirtyPlate" or obj.Name == "DirtyPlate"
    end)

    if dirty then
        local got = interactUntil(dirty, function()
            return heldIs("DirtyPlate")
        end, "pegar DirtyPlate", 8)

        if got and heldIs("DirtyPlate") then
            handleDirtyPlate()
        end

        return
    end

    -- 3. carne sempre primeiro
    local plateWithMeat = getNearestWhere(function(obj)
        if not isPlateObject(obj) then return false end
        local state = getPlateState(obj)
        return state.hasMeat and not state.complete
    end)

    local readyPan = getNearestReadyPan()
    local anyCookingMeat = getNearestWhere(function(obj)
        if obj:GetAttribute("ApplianceType") ~= "Hob" and obj.Name ~= "Hob" then
            return false
        end
        return panHasChoppedMeat(obj) and not isPanBurnt(obj)
    end)

    if not plateWithMeat then
        if readyPan then
            pickPlateForReadyPan(readyPan)
            return
        end

        if anyCookingMeat then
            makeMeatFlow()
            return
        end

        makeMeatFlow()
        return
    end

    -- 4. depois abacaxi
    local needPineapple = getNearestWhere(function(obj)
        if not isPlateObject(obj) then return false end
        local s = getPlateState(obj)
        return s.hasMeat and not s.hasPineapple and not s.complete
    end)

    if needPineapple then
        makePineappleFlow()
        return
    end

    -- 5. depois tomate
    local needTomato = getNearestWhere(function(obj)
        if not isPlateObject(obj) then return false end
        local s = getPlateState(obj)
        return s.hasMeat and s.hasPineapple and not s.hasTomato and not s.complete
    end)

    if needTomato then
        makeTomatoFlow()
        return
    end

    -- fallback: se não achou progresso claro, começa carne
    makeMeatFlow()
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

    -- Se alguma pia está lavando, não executar nada.
    local activeSink = getNearestWhere(function(obj)
        if obj:GetAttribute("ApplianceType") == "Sink" or obj.Name == "Sink" then
            return isSinkWashing(obj)
        end
        return false
    end)

    if activeSink then
        return
    end

    local held, itemType = getHeldItem()

    if itemType == "RawBeef" then
        doAction("RawBeef -> ChoppingBoard", function()
            cutIngredient("RawBeef", "ChoppedMeat")
        end)

    elseif itemType == "ChoppedMeat" then
        doAction("ChoppedMeat -> Hob/FryingPan", function()
            putChoppedMeatOnPan()
        end)

    elseif itemType == "Pineapple" then
        doAction("Pineapple -> ChoppingBoard", function()
            cutIngredient("Pineapple", "PineappleRings")
        end)

    elseif itemType == "PineappleRings" then
        doAction("PineappleRings -> Plate", function()
            addFinalIngredient("PineappleRings")
        end)

    elseif itemType == "Tomato" then
        doAction("Tomato -> ChoppingBoard", function()
            cutIngredient("Tomato", "ChoppedTomato")
        end)

    elseif itemType == "ChoppedTomato" then
        doAction("ChoppedTomato -> Plate", function()
            addFinalIngredient("ChoppedTomato")
        end)

    elseif itemType == "DirtyPlate" then
        doAction("DirtyPlate -> Sink", function()
            handleDirtyPlate()
        end)

    elseif itemType == "Plate" then
        doAction("Plate Handling", function()
            handlePlateInHand()
        end)

    else
        doAction("Empty Hands Flow", function()
            handleEmptyHands()
        end)
    end
end)

------------------------------------------------------------
-- PRINT DE CARREGAMENTO NO FINAL DO CÓDIGO
------------------------------------------------------------

print("[Autofarm] Cooking Chaos carregado | Teleport=true | Delay antes do TP=1s | Delay prompt=0.35s | Confirmação obrttigatória de item ativa")
