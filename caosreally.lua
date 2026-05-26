-- AUTOFARM: CAOS NA COZINHA / COOKING CHAOS
-- Fluxo rápido por teleporte + confirmação de estado
-- Baseado nas regras: Kebab / Cidade Symmetri

print("[Autofarm] Cooking Chaos carregado | modo rápido + teleporte + confirmação de estado")

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Interactables = Workspace:WaitForChild("Interactables")

------------------------------------------------------------
-- CONFIG
------------------------------------------------------------

local USE_TELEPORT = true
local TELEPORT_OFFSET = 3.25
local ACTION_COOLDOWN = 0.10
local INTERACT_WAIT = 0.03
local WAIT_TIMEOUT = 10
local currentState = "Idle"
local busy = false
local lastAction = 0

------------------------------------------------------------
-- UTILS
------------------------------------------------------------

local function now()
    return os.clock()
end

local function log(...)
    print("[Autofarm]", ...)
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
        if ok and cf then return cf.Position end
    end

    if obj:IsA("BasePart") then
        return obj.Position
    end

    local part = obj:FindFirstChildWhichIsA("BasePart", true)
    return part and part.Position or nil
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

local function getType(obj)
    if not obj then return nil end
    return obj:GetAttribute("Type") or obj.Name
end

local function hasIngredient(container, ingredientName)
    if not container then return false end
    if container.Name == ingredientName then return true end
    if container:GetAttribute("Type") == ingredientName then return true end
    return container:FindFirstChild(ingredientName, true) ~= nil
end

------------------------------------------------------------
-- ITEM NA MÃO
-- Detecta item direto no Character, dentro de Tool, descendente,
-- ou objeto de Interactables muito próximo do personagem/mão.
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

local function detectTypeFromObject(obj)
    if not obj then return nil end

    local attrType = obj:GetAttribute("Type")
    if attrType and ITEM_TYPES[attrType] then
        return attrType
    end

    if ITEM_TYPES[obj.Name] then
        return obj.Name
    end

    return nil
end

local function getHeldItem()
    local char = getCharacter()
    if not char then return nil, nil end

    -- 1. Filho direto do Character.
    for _, child in ipairs(char:GetChildren()) do
        local t = detectTypeFromObject(child)
        if t then return child, t end
    end

    -- 2. Tool ou descendentes dentro da Tool.
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then
        local t = detectTypeFromObject(tool)
        if t then return tool, t end

        for _, d in ipairs(tool:GetDescendants()) do
            t = detectTypeFromObject(d)
            if t then return tool, t end
        end
    end

    -- 3. Qualquer descendente do Character.
    for _, d in ipairs(char:GetDescendants()) do
        local t = detectTypeFromObject(d)
        if t then return d, t end
    end

    -- 4. Fallback: objeto de Interactables colado no personagem/mão.
    local root = getRoot()
    if root then
        local best, bestType, bestDist = nil, nil, math.huge
        for _, obj in ipairs(Interactables:GetDescendants()) do
            local t = detectTypeFromObject(obj)
            if t and not obj:IsA("ProximityPrompt") then
                local pos = safePivot(obj)
                if pos then
                    local d = (root.Position - pos).Magnitude
                    if d <= 5 and d < bestDist then
                        best = obj
                        bestType = t
                        bestDist = d
                    end
                end
            end
        end
        if best then return best, bestType end
    end

    return nil, nil
end

------------------------------------------------------------
-- BUSCAS
------------------------------------------------------------

local function getNearestWhere(predicate)
    local root = getRoot()
    if not root then return nil end

    local closest, minD = nil, math.huge
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
        return obj.Name == "FoodBin" and obj:GetAttribute("FoodType") == foodType
    end)
end

local function isPlateObject(obj)
    return obj and (obj:GetAttribute("Type") == "Plate" or obj.Name == "Plate")
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

local function getAllWorldPlates()
    local plates, seen = {}, {}
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
        if not isPlateObject(obj) or isDescendantOfCharacter(obj) then return false end
        local s = getPlateState(obj)
        return s.count == 0 and not s.complete
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
    local bestPlate, bestScore, bestDistance = nil, -math.huge, math.huge

    for _, plate in ipairs(getAllWorldPlates()) do
        local state = getPlateState(plate)

        if not state.complete and not plateAlreadyHasIngredient(state, ingredientType) then
            local score = 0

            -- Carne sempre é base: para abacaxi/tomate, preferir pratos que já tenham carne.
            if ingredientType ~= "CookedMeat" and state.hasMeat then
                score += 450
            end

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
        return isPlateObject(obj) and getPlateState(obj).complete
    end)
end

local function getNearestPlateWithMeatMissingPineapple()
    return getNearestWhere(function(obj)
        if not isPlateObject(obj) then return false end
        local s = getPlateState(obj)
        return s.hasMeat and not s.hasPineapple and not s.complete
    end)
end

local function getNearestPlateWithMeatPineappleMissingTomato()
    return getNearestWhere(function(obj)
        if not isPlateObject(obj) then return false end
        local s = getPlateState(obj)
        return s.hasMeat and s.hasPineapple and not s.hasTomato
    end)
end

local function getNearestEmptyCountertop()
    return getNearestWhere(function(obj)
        if obj:GetAttribute("ApplianceType") ~= "Countertop" and obj.Name ~= "Countertop" then
            return false
        end

        local blocked = {
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
            if blocked[d.Name] or blocked[d:GetAttribute("Type")] then
                return false
            end
        end
        return true
    end)
end

------------------------------------------------------------
-- HOB / PANELA
------------------------------------------------------------

local function getFryingPan(hob)
    if not hob then return nil end
    if hob.Name == "FryingPan" then return hob end
    return hob:FindFirstChild("FryingPan", true)
end

local function getNearestHobWithPan()
    return getNearestWhere(function(obj)
        return (obj:GetAttribute("ApplianceType") == "Hob" or obj.Name == "Hob")
            and getFryingPan(obj) ~= nil
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
    return pan and hasIngredient(pan, "ChoppedMeat") or false
end

local function getNearestReadyPan()
    return getNearestWhere(function(obj)
        return (obj:GetAttribute("ApplianceType") == "Hob" or obj.Name == "Hob")
            and isPanReady(obj)
    end)
end

local function getNearestCookingPan()
    return getNearestWhere(function(obj)
        return (obj:GetAttribute("ApplianceType") == "Hob" or obj.Name == "Hob")
            and panHasChoppedMeat(obj)
            and not isPanBurnt(obj)
    end)
end

------------------------------------------------------------
-- SINK
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

local function getActiveSink()
    return getNearestWhere(function(obj)
        return (obj:GetAttribute("ApplianceType") == "Sink" or obj.Name == "Sink")
            and isSinkWashing(obj)
    end)
end

------------------------------------------------------------
-- TELEPORTE + INTERAÇÃO IMEDIATA
------------------------------------------------------------

local function teleportNear(target)
    local root = getRoot()
    local pos = safePivot(target)
    if not root or not pos then return false end

    local direction = root.Position - pos
    if direction.Magnitude < 0.1 then
        direction = Vector3.new(0, 0, 1)
    end

    direction = direction.Unit
    local targetPos = pos + direction * TELEPORT_OFFSET
    root.CFrame = CFrame.lookAt(targetPos, pos)

    task.wait(INTERACT_WAIT)
    return true
end

local function walkNear(target)
    local humanoid = getHumanoid()
    local root = getRoot()
    local pos = safePivot(target)
    if not humanoid or not root or not pos then return false end

    humanoid:MoveTo(pos)
    local started = now()
    while now() - started < 2 do
        root = getRoot()
        if root and (root.Position - pos).Magnitude <= 8 then return true end
        task.wait(0.04)
    end
    return false
end

local function goNear(target)
    if USE_TELEPORT and teleportNear(target) then
        return true
    end
    return walkNear(target)
end

local function findPrompt(target)
    if not target then return nil end
    if target:IsA("ProximityPrompt") then return target end
    return target:FindFirstChildWhichIsA("ProximityPrompt", true)
end

local function interactNow(target, label)
    if not target then return false end

    local reached = goNear(target)
    if not reached then
        log("Falhou ao chegar em", label or target.Name)
        return false
    end

    local prompt = findPrompt(target)
    if not prompt then
        warn("[Autofarm] Nenhum ProximityPrompt encontrado em:", target:GetFullName())
        return false
    end

    log("Interact:", label or target.Name)

    local hold = prompt.HoldDuration or 0
    pcall(function()
        prompt:InputHoldBegin()
    end)

    task.wait(math.max(hold + 0.02, 0.04))

    pcall(function()
        prompt:InputHoldEnd()
    end)

    return true
end

local function waitUntil(label, predicate, timeout)
    local started = now()
    timeout = timeout or WAIT_TIMEOUT

    while now() - started < timeout do
        local ok, result = pcall(predicate)
        if ok and result then
            log("Confirmado:", label)
            return true
        end
        task.wait(0.06)
    end

    log("Timeout:", label)
    return false
end

local function doAction(stateName, fn)
    if not canAct() then return end

    setBusy(true, stateName)
    lastAction = now()
    log("Ação:", stateName)

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
-- CONFIRMAÇÕES DE ESTADO
------------------------------------------------------------

local function heldIs(itemType)
    local _, heldType = getHeldItem()
    return heldType == itemType
end

local function heldPlateHas(ingredient)
    local held, heldType = getHeldItem()
    return heldType == "Plate" and hasIngredient(held, ingredient)
end

local function isHeldPlateComplete()
    local held, heldType = getHeldItem()
    return heldType == "Plate" and getPlateState(held).complete
end

local function pickupFromBoardIfReady(board, expectedType)
    if not board then return false end

    if hasIngredient(board, expectedType) and not heldIs(expectedType) then
        interactNow(board, "pegar " .. expectedType .. " da ChoppingBoard")
        return waitUntil(expectedType .. " na mão", function()
            return heldIs(expectedType)
        end, 3)
    end

    return heldIs(expectedType)
end

local function cutAndPickup(rawType, expectedType)
    local board = getNearestAppliance("ChoppingBoard")
    if not board then return end

    interactNow(board, "colocar/cortar " .. rawType)

    waitUntil(expectedType .. " pronto na ChoppingBoard ou mão", function()
        return heldIs(expectedType) or hasIngredient(board, expectedType)
    end, 8)

    pickupFromBoardIfReady(board, expectedType)
end

local function putFinalIngredientOnBestPlate(ingredientType)
    local plate = getBestPlate(ingredientType)
    if not plate then
        log("Nenhum prato válido para", ingredientType)
        return
    end

    interactNow(plate, "colocar " .. ingredientType .. " no melhor prato")

    waitUntil(ingredientType .. " saiu da mão", function()
        local _, heldType = getHeldItem()
        return heldType ~= ingredientType
    end, 3)
end

------------------------------------------------------------
-- FLUXOS
------------------------------------------------------------

local function handleRawIngredient(itemType)
    local expected = nil
    if itemType == "RawBeef" then expected = "ChoppedMeat" end
    if itemType == "Pineapple" then expected = "PineappleRings" end
    if itemType == "Tomato" then expected = "ChoppedTomato" end
    if not expected then return end

    doAction("Cortar " .. itemType, function()
        cutAndPickup(itemType, expected)
    end)
end

local function handleChoppedMeat()
    local hob = getNearestHobWithPan()
    if not hob then return end

    if isPanBurnt(hob) then
        log("Panela queimada ignorada")
        return
    end

    doAction("Colocar ChoppedMeat na panela", function()
        interactNow(hob, "colocar ChoppedMeat na FryingPan")

        waitUntil("ChoppedMeat saiu da mão e está cozinhando", function()
            local _, heldType = getHeldItem()
            return heldType ~= "ChoppedMeat" and panHasChoppedMeat(hob)
        end, 4)
    end)
end

local function handlePlate(held)
    if isHeldPlateComplete() then
        local sellPoint = getNearestByName("SellPoint") or getNearestAppliance("Sell") or getNearestByName("Sell")
        if sellPoint then
            doAction("Vender prato completo", function()
                interactNow(sellPoint, "vender prato completo")
                waitUntil("mão vazia após venda", function()
                    local _, heldType = getHeldItem()
                    return heldType ~= "Plate"
                end, 3)
            end)
        end
        return
    end

    local readyPan = getNearestReadyPan()
    local cookingPan = getNearestCookingPan()

    -- Se tem carne na panela, o Plate deve ir para a panela.
    if readyPan or cookingPan then
        local pan = readyPan or cookingPan
        doAction("Ir com Plate para panela", function()
            if not isPanReady(pan) then
                goNear(pan)
                waitUntil("carne pronta na panela", function()
                    return isPanReady(pan) or isPanBurnt(pan)
                end, 12)
            end

            if isPanReady(pan) then
                interactNow(pan, "pegar CookedMeat com Plate")
                waitUntil("CookedMeat no Plate da mão", function()
                    return heldPlateHas("CookedMeat")
                end, 4)

                if heldPlateHas("CookedMeat") then
                    local counter = getNearestEmptyCountertop()
                    if counter then
                        interactNow(counter, "colocar Plate com CookedMeat na bancada vazia")
                        waitUntil("mão vazia após colocar prato com carne", function()
                            local _, heldType = getHeldItem()
                            return heldType ~= "Plate"
                        end, 3)
                    end
                end
            end
        end)
        return
    end

    -- Plate parcial/limpo sem uso imediato: bancada vazia.
    local counter = getNearestEmptyCountertop()
    if counter then
        doAction("Colocar Plate na bancada vazia", function()
            interactNow(counter, "colocar Plate na bancada")
            waitUntil("mão vazia após colocar Plate", function()
                local _, heldType = getHeldItem()
                return heldType ~= "Plate"
            end, 3)
        end)
    end
end

local function handleDirtyPlate()
    local sink = getNearestAppliance("Sink")
    if not sink then return end

    doAction("Lavar DirtyPlate", function()
        interactNow(sink, "lavar DirtyPlate")

        waitUntil("pia terminar lavagem", function()
            return not isSinkWashing(sink)
        end, 12)

        waitUntil("Plate limpo na mão", function()
            return heldIs("Plate")
        end, 4)

        if heldIs("Plate") then
            local counter = getNearestEmptyCountertop()
            if counter then
                interactNow(counter, "colocar Plate limpo na bancada")
            end
        end
    end)
end

local function handleEmptyHands()
    -- 1. Vender prato completo antes de produzir mais.
    local completePlate = getNearestCompletePlate()
    if completePlate then
        doAction("Pegar e vender prato completo", function()
            interactNow(completePlate, "pegar prato completo")

            waitUntil("Plate completo na mão", function()
                return isHeldPlateComplete()
            end, 3)

            if isHeldPlateComplete() then
                local sellPoint = getNearestByName("SellPoint") or getNearestAppliance("Sell") or getNearestByName("Sell")
                if sellPoint then
                    interactNow(sellPoint, "vender prato completo")
                end
            end
        end)
        return
    end

    -- 2. DirtyPlate tem prioridade operacional, mas sem interromper lavagem ativa.
    local dirty = getNearestWhere(function(obj)
        return obj:GetAttribute("Type") == "DirtyPlate" or obj.Name == "DirtyPlate"
    end)

    if dirty then
        doAction("Pegar DirtyPlate", function()
            interactNow(dirty, "pegar DirtyPlate")
            waitUntil("DirtyPlate na mão", function()
                return heldIs("DirtyPlate")
            end, 3)
        end)
        return
    end

    -- 3. Se tem carne cozinhando/pronta, pegar Plate primeiro; só ir à panela quando Plate estiver na mão.
    local cookingPan = getNearestCookingPan()
    if cookingPan then
        local plate = getNearestCleanEmptyPlate()
        if plate then
            doAction("Pegar Plate para carne da panela", function()
                interactNow(plate, "pegar Plate limpo")
                waitUntil("Plate na mão", function()
                    return heldIs("Plate")
                end, 3)
            end)
        end
        return
    end

    -- 4. Carne SEMPRE é a primeira base do ciclo.
    local meatPlate = getNearestWhere(function(obj)
        return isPlateObject(obj) and getPlateState(obj).hasMeat and not getPlateState(obj).complete
    end)

    local rawOrChoppedInProgress = getNearestWhere(function(obj)
        return hasIngredient(obj, "RawBeef") or hasIngredient(obj, "ChoppedMeat")
    end)

    if not meatPlate and not rawOrChoppedInProgress then
        local rawBeefBin = getNearestFoodBin("RawBeef")
        if rawBeefBin then
            doAction("Pegar RawBeef", function()
                interactNow(rawBeefBin, "pegar RawBeef")
                waitUntil("RawBeef na mão", function()
                    return heldIs("RawBeef")
                end, 3)
            end)
        end
        return
    end

    -- 5. Depois da carne, abacaxi.
    local needPineapplePlate = getNearestPlateWithMeatMissingPineapple()
    local pineappleInProgress = getNearestWhere(function(obj)
        return hasIngredient(obj, "Pineapple") or hasIngredient(obj, "PineappleRings")
    end)

    if needPineapplePlate and not pineappleInProgress then
        local pineappleBin = getNearestFoodBin("Pineapple")
        if pineappleBin then
            doAction("Pegar Pineapple", function()
                interactNow(pineappleBin, "pegar Pineapple")
                waitUntil("Pineapple na mão", function()
                    return heldIs("Pineapple")
                end, 3)
            end)
        end
        return
    end

    -- 6. Depois do abacaxi, tomate.
    local needTomatoPlate = getNearestPlateWithMeatPineappleMissingTomato()
    local tomatoInProgress = getNearestWhere(function(obj)
        return hasIngredient(obj, "Tomato") or hasIngredient(obj, "ChoppedTomato")
    end)

    if needTomatoPlate and not tomatoInProgress then
        local tomatoBin = getNearestFoodBin("Tomato")
        if tomatoBin then
            doAction("Pegar Tomato", function()
                interactNow(tomatoBin, "pegar Tomato")
                waitUntil("Tomato na mão", function()
                    return heldIs("Tomato")
                end, 3)
            end)
        end
        return
    end
end

------------------------------------------------------------
-- LOOP PRINCIPAL
------------------------------------------------------------

RunService.Heartbeat:Connect(function()
    if not canAct() then return end
    if not getCharacter() or not getRoot() then return end

    -- Enquanto lava, não fazer nada.
    if getActiveSink() then return end

    local held, itemType = getHeldItem()

    if itemType then
        log("Mão:", itemType, held and held:GetFullName() or "?")
    end

    if itemType == "RawBeef" or itemType == "Pineapple" or itemType == "Tomato" then
        handleRawIngredient(itemType)

    elseif itemType == "ChoppedMeat" then
        handleChoppedMeat()

    elseif itemType == "PineappleRings" then
        doAction("Colocar PineappleRings no prato", function()
            putFinalIngredientOnBestPlate("PineappleRings")
        end)

    elseif itemType == "ChoppedTomato" then
        doAction("Colocar ChoppedTomato no prato", function()
            putFinalIngredientOnBestPlate("ChoppedTomato")
        end)

    elseif itemType == "DirtyPlate" then
        handleDirtyPlate()

    elseif itemType == "Plate" then
        handlePlate(held)

    else
        handleEmptyHands()
    end
end)
