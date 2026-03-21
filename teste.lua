-- LocalScript: Wallhop View 3D otimizado (igual FTF Practice)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")

-- Configurações
local LineColor = Color3.fromRGB(255,255,255)
local LineThickness = 0.05 -- espessura da “linha” 3D
local MaxDistance = 50 -- distância máxima para desenhar
local WallhopHeightTolerance = 5 -- altura das superfícies que podem ser wallhopadas

-- Tabela de adorns ativos
local adorns = {}

-- Remove adorns antigos
local function ClearAdorns()
    for _, a in pairs(adorns) do
        a:Destroy()
    end
    adorns = {}
end

-- Cria um highlight 3D tipo linha fina na superfície
local function CreateLinePart(cframe, size)
    local part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = false
    part.Size = size
    part.CFrame = cframe
    part.Color = LineColor
    part.Material = Enum.Material.Neon
    part.Transparency = 0
    part.Parent = Workspace
    table.insert(adorns, part)
end

-- Pega partes relevantes para wallhop perto do jogador
local function GetRelevantParts()
    local parts = {}
    local rootPos = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.Position
    if not rootPos then return parts end

    for _, part in pairs(Workspace:GetDescendants()) do
        if part:IsA("BasePart") and part.Anchored and part.CanCollide and part.Size.Magnitude > 2 then
            local distance = (part.Position - rootPos).Magnitude
            if distance <= MaxDistance then
                -- só partes acessíveis (altura próxima do jogador)
                local relY = math.abs(part.Position.Y - rootPos.Y)
                if relY <= WallhopHeightTolerance then
                    table.insert(parts, part)
                end
            end
        end
    end
    return parts
end

-- Desenha as “linhas” 3D nas bordas das partes relevantes
local function DrawWallhopView()
    ClearAdorns()
    local parts = GetRelevantParts()
    for _, part in pairs(parts) do
        local pos = part.Position
        local size = part.Size

        -- borda superior (horizontal)
        local topY = pos.Y + size.Y/2
        local leftX = pos.X - size.X/2
        local rightX = pos.X + size.X/2
        local frontZ = pos.Z - size.Z/2
        local backZ = pos.Z + size.Z/2

        local thickness = LineThickness

        -- cria linhas horizontais (topo da plataforma)
        CreateLinePart(CFrame.new((leftX+rightX)/2, topY, frontZ), Vector3.new(size.X, thickness, thickness))
        CreateLinePart(CFrame.new((leftX+rightX)/2, topY, backZ), Vector3.new(size.X, thickness, thickness))
        CreateLinePart(CFrame.new(leftX, topY, (frontZ+backZ)/2), Vector3.new(thickness, thickness, size.Z))
        CreateLinePart(CFrame.new(rightX, topY, (frontZ+backZ)/2), Vector3.new(thickness, thickness, size.Z))

        -- cria linhas verticais (bordas)
        CreateLinePart(CFrame.new(leftX, topY - size.Y/2, frontZ), Vector3.new(thickness, size.Y, thickness))
        CreateLinePart(CFrame.new(rightX, topY - size.Y/2, frontZ), Vector3.new(thickness, size.Y, thickness))
        CreateLinePart(CFrame.new(leftX, topY - size.Y/2, backZ), Vector3.new(thickness, size.Y, thickness))
        CreateLinePart(CFrame.new(rightX, topY - size.Y/2, backZ), Vector3.new(thickness, size.Y, thickness))
    end
end

-- Atualiza a cada 0.3s para não travar
RunService.Heartbeat:Connect(function(step)
    DrawWallhopView()
end)
