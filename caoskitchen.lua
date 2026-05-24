--// Caos na Cozinha - Auto Cutter Clicker v1
--// Função: quando o jogo mostrar o highlight/chams vermelho na mesa de corte,
--// ele aperta automaticamente o botão de interação.
--//
--// Ideia principal:
--// - NÃO depende de mapa específico.
--// - NÃO tenta achar panela/prato.
--// - Só funciona para mesa de cortar.
--// - Só clica quando o próprio jogo já mostrou que a mesa é uma interação válida.
--//
--// Botões:
--// Auto Cut: liga/desliga
--// Test Click: testa o clique no botão de interação
--// Print Target: joga no console qual Highlight vermelho foi detectado

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")

local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")

local CONFIG = {
    Enabled = true,

    -- tempo entre cada clique automático
    Cooldown = 0.55,

    -- distância máxima até a mesa/objeto destacado
    MaxDistance = 10,

    -- palavras que identificam mesa de corte
    CutKeywords = {
        "choppingboard",
        "chopping",
        "knife",
        "cut",
        "faca",
        "cortar",
    },

    -- se true, ele só clica quando o Highlight vermelho estiver em algo de corte
    RequireRedHighlight = true,

    -- se o botão de interação do jogo tiver nome diferente, adicione aqui
    InteractButtonKeywords = {
        "interact",
        "interaction",
        "use",
        "action",
        "hand",
        "grab",
        "pickup",
        "pegar",
        "usar",
        "mão",
        "mao",
    },
}

local state = {
    lastClick = 0,
    lastTargetPath = "nenhum",
    lastButtonPath = "nenhum",
}

local function safePath(obj)
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

local function getPosition(obj)
    if not obj then
        return nil
    end

    if obj:IsA("BasePart") then
        return obj.Position
    end

    if obj:IsA("Model") then
        local p = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
        return p and p.Position
    end

    local model = obj:FindFirstAncestorOfClass("Model")
    if model then
        local p = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
        if p then
            return p.Position
        end
    end

    local part = obj:FindFirstAncestorWhichIsA("BasePart")
    return part and part.Position
end

local function pathHasAny(path, list)
    path = string.lower(path or "")

    for _, key in ipairs(list) do
        if string.find(path, string.lower(key), 1, true) then
            return true
        end
    end

    return false
end

local function isRedColor(color)
    if typeof(color) ~= "Color3" then
        return false
    end

    return color.R > 0.6 and color.G < 0.35 and color.B < 0.35
end

local function getHighlightAdornee(h)
    if not h or not h:IsA("Highlight") then
        return nil
    end

    if h.Adornee then
        return h.Adornee
    end

    if h.Parent and (h.Parent:IsA("Model") or h.Parent:IsA("BasePart")) then
        return h.Parent
    end

    return nil
end

local function findRedCutHighlight()
    local hrp = getHRP()
    if not hrp then
        return nil
    end

    local roots = {
        workspace,
        game.CoreGui,
        pg,
    }

    local best = nil
    local bestDist = math.huge

    for _, root in ipairs(roots) do
        for _, obj in ipairs(root:GetDescendants()) do
            if obj:IsA("Highlight") and obj.Enabled ~= false then
                local adornee = getHighlightAdornee(obj)
                local path = safePath(adornee or obj)

                local looksCut = pathHasAny(path, CONFIG.CutKeywords)
                local looksRed = isRedColor(obj.FillColor) or isRedColor(obj.OutlineColor)

                if looksCut and (looksRed or not CONFIG.RequireRedHighlight) then
                    local pos = getPosition(adornee or obj)

                    if pos then
                        local dist = (pos - hrp.Position).Magnitude

                        if dist < bestDist and dist <= CONFIG.MaxDistance then
                            best = adornee or obj
                            bestDist = dist
                        end
                    end
                end
            end
        end
    end

    if best then
        state.lastTargetPath = safePath(best)
    end

    return best
end

local function findVisibleInteractButton()
    local cam = workspace.CurrentCamera
    local screenSize = cam and cam.ViewportSize or Vector2.new(1280, 720)

    local best = nil
    local bestScore = math.huge

    for _, ui in ipairs(pg:GetDescendants()) do
        if ui:IsA("GuiButton") and ui.Visible and ui.Active ~= false then
            local size = ui.AbsoluteSize
            local pos = ui.AbsolutePosition
            local center = pos + (size / 2)

            if size.X >= 35 and size.Y >= 35 then
                local path = safePath(ui)
                local lower = string.lower(path)

                local hasGoodName = pathHasAny(lower, CONFIG.InteractButtonKeywords)

                -- região provável do botão de interação no mobile:
                -- meio/direita inferior, evitando o botão de pulo muito à direita
                local inMobileActionZone =
                    center.X > screenSize.X * 0.42 and
                    center.X < screenSize.X * 0.86 and
                    center.Y > screenSize.Y * 0.50 and
                    center.Y < screenSize.Y * 0.96

                if hasGoodName or inMobileActionZone then
                    local targetX = screenSize.X * 0.67
                    local targetY = screenSize.Y * 0.77

                    local dx = center.X - targetX
                    local dy = center.Y - targetY
                    local score = math.sqrt(dx * dx + dy * dy)

                    if hasGoodName then
                        score -= 180
                    end

                    -- evita botões gigantes de menu/frame
                    if size.X > 170 or size.Y > 170 then
                        score += 250
                    end

                    if score < bestScore then
                        bestScore = score
                        best = ui
                    end
                end
            end
        end
    end

    if best then
        state.lastButtonPath = safePath(best)
    end

    return best
end

local function clickGuiButton(btn)
    if not btn then
        return false
    end

    local center = btn.AbsolutePosition + (btn.AbsoluteSize / 2)

    pcall(function()
        firesignal(btn.MouseButton1Down)
    end)

    pcall(function()
        firesignal(btn.MouseButton1Click)
    end)

    pcall(function()
        firesignal(btn.Activated)
    end)

    pcall(function()
        btn:Activate()
    end)

    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 0)
        task.wait(0.03)
        VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 0)
    end)

    return true
end

local function tryFirePrompt(target)
    if not target then
        return false
    end

    local prompts = {}

    for _, d in ipairs(target:GetDescendants()) do
        if d:IsA("ProximityPrompt") and d.Enabled ~= false then
            table.insert(prompts, d)
        end
    end

    local parent = target.Parent
    if parent then
        for _, d in ipairs(parent:GetDescendants()) do
            if d:IsA("ProximityPrompt") and d.Enabled ~= false then
                table.insert(prompts, d)
            end
        end
    end

    local fired = false

    for _, prompt in ipairs(prompts) do
        pcall(function()
            fireproximityprompt(prompt)
            fired = true
        end)
    end

    return fired
end

local function autoClickCut()
    if not CONFIG.Enabled then
        return
    end

    if tick() - state.lastClick < CONFIG.Cooldown then
        return
    end

    local target = findRedCutHighlight()
    if not target then
        return
    end

    state.lastClick = tick()

    -- primeiro tenta prompt, se existir
    local promptOk = tryFirePrompt(target)

    -- depois tenta clicar no botão mobile de interação
    local btn = findVisibleInteractButton()
    if btn then
        clickGuiButton(btn)
    end
end

RunService.RenderStepped:Connect(function()
    pcall(autoClickCut)
end)

--// GUI simples mobile
local old = pg:FindFirstChild("CookCaosAutoCutterGui")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "CookCaosAutoCutterGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = pg

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 210, 0, 165)
frame.Position = UDim2.new(0, 18, 0.42, 0)
frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
frame.BackgroundTransparency = 0.12
frame.BorderSizePixel = 0
frame.Active = true
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 255, 255)
stroke.Thickness = 1
stroke.Transparency = 0.65
stroke.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -16, 0, 30)
title.Position = UDim2.new(0, 8, 0, 8)
title.BackgroundTransparency = 1
title.Text = "Auto Cutter"
title.TextColor3 = Color3.fromRGB(255,255,255)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = frame

local function makeBtn(text, y)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -20, 0, 34)
    b.Position = UDim2.new(0, 10, 0, y)
    b.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
    b.TextColor3 = Color3.fromRGB(255,255,255)
    b.TextScaled = true
    b.Font = Enum.Font.GothamBold
    b.Text = text
    b.AutoButtonColor = true
    b.BorderSizePixel = 0
    b.Parent = frame
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
    return b
end

local toggle = makeBtn("Auto Cut: ON", 45)
local test = makeBtn("Test Click", 84)
local printBtn = makeBtn("Print Target", 123)

toggle.MouseButton1Click:Connect(function()
    CONFIG.Enabled = not CONFIG.Enabled
    toggle.Text = CONFIG.Enabled and "Auto Cut: ON" or "Auto Cut: OFF"
end)

test.MouseButton1Click:Connect(function()
    local btn = findVisibleInteractButton()
    if btn then
        clickGuiButton(btn)
        warn("[AutoCutter] Test Click no botão:", safePath(btn))
    else
        warn("[AutoCutter] Nenhum botão de interação visível encontrado.")
    end
end)

printBtn.MouseButton1Click:Connect(function()
    local target = findRedCutHighlight()

    warn("[AutoCutter] Target:", target and safePath(target) or "nenhum")
    warn("[AutoCutter] LastTarget:", state.lastTargetPath)
    warn("[AutoCutter] LastButton:", state.lastButtonPath)
end)

-- arrastar painel
do
    local dragging = false
    local dragStart
    local startPos

    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)

    frame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and dragStart and startPos then
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
                local delta = input.Position - dragStart
                frame.Position = UDim2.new(
                    startPos.X.Scale,
                    startPos.X.Offset + delta.X,
                    startPos.Y.Scale,
                    startPos.Y.Offset + delta.Y
                )
            end
        end
    end)
end

warn("[AutoCutter] carregado.")
warn("[AutoCutter] Ele só tenta clicar quando detectar Highlight vermelho na ChoppingBoard/Knife/Cut.")
warn("[AutoCutter] Use Print Target perto da mesa de corte com item válido para confirmar.")
