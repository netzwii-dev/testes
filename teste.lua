-- LocalScript: Wallhop View otimizado FTF Practice
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- Configurações
local LineColor = Color3.new(1,1,1)
local LineThickness = 2
local MaxDistance = 100 -- distância máxima para desenhar linhas

-- Tabela de linhas ativas
local activeLines = {}

-- Função para criar linha 2D
local function CreateLine(startPos, endPos)
    local line = Drawing.new("Line")
    line.From = startPos
    line.To = endPos
    line.Color = LineColor
    line.Thickness = LineThickness
    line.Transparency = 1
    return line
end

-- Filtra partes relevantes (paredes, plataformas e chão acessível)
local function GetRelevantParts()
    local parts = {}
    local rootPos = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.Position
    if not rootPos then return parts end

    for _, part in pairs(workspace:GetDescendants()) do
        if part:IsA("BasePart") and part.Anchored and part.CanCollide and part.Size.Magnitude > 2 then
            local distance = (part.Position - rootPos).Magnitude
            if distance <= MaxDistance then
                -- Só desenha superfícies horizontais (chão/plataformas) ou verticais (paredes)
                local size = part.Size
                if size.Y < 0.5 or size.X < 0.5 or size.Z < 0.5 then
                    continue
                end
                table.insert(parts, part)
            end
        end
    end
    return parts
end

-- Cria linhas 2D apenas nas bordas de superfícies relevantes
local function DrawPart(part)
    local pos = part.Position
    local size = part.Size

    local topY = pos.Y + size.Y/2
    local bottomY = pos.Y - size.Y/2
    local leftX = pos.X - size.X/2
    local rightX = pos.X + size.X/2
    local frontZ = pos.Z - size.Z/2
    local backZ = pos.Z + size.Z/2

    local points = {
        -- borda superior (horizontal)
        Vector3.new(leftX, topY, frontZ),
        Vector3.new(rightX, topY, frontZ),
        Vector3.new(rightX, topY, backZ),
        Vector3.new(leftX, topY, backZ),
        -- borda inferior (horizontal)
        Vector3.new(leftX, bottomY, frontZ),
        Vector3.new(rightX, bottomY, frontZ),
        Vector3.new(rightX, bottomY, backZ),
        Vector3.new(leftX, bottomY, backZ),
    }

    local edges = {
        {1,2},{2,3},{3,4},{4,1}, -- topo
        {5,6},{6,7},{7,8},{8,5}, -- base
        {1,5},{2,6},{3,7},{4,8}, -- vertical
    }

    local lineObjects = {}
    for _, e in pairs(edges) do
        local screenStart, onScreen1 = Camera:WorldToViewportPoint(points[e[1]])
        local screenEnd, onScreen2 = Camera:WorldToViewportPoint(points[e[2]])
        if onScreen1 or onScreen2 then
            local line = CreateLine(Vector2.new(screenStart.X, screenStart.Y), Vector2.new(screenEnd.X, screenEnd.Y))
            table.insert(lineObjects, line)
        end
    end
    return lineObjects
end

-- Atualiza linhas a cada frame
RunService.RenderStepped:Connect(function()
    -- Remove linhas antigas
    for _, line in pairs(activeLines) do
        line:Remove()
    end
    activeLines = {}

    local parts = GetRelevantParts()
    for _, part in pairs(parts) do
        local lines = DrawPart(part)
        for _, l in pairs(lines) do
            table.insert(activeLines, l)
        end
    end
end)
