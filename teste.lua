-- Ultra Optimized Wallhop View (FE Safe)
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local HighlightParts = {} -- tabela de Neons já criados
local LastPlayerPos = Vector3.new(0,0,0)
local UpdateDistance = 5 -- distância mínima para atualizar highlights

local function CreateNeon(part)
    local neon = Instance.new("Part")
    neon.Size = Vector3.new(part.Size.X, 0.2, part.Size.Z)
    neon.CFrame = part.CFrame + Vector3.new(0, part.Size.Y/2, 0)
    neon.Anchored = true
    neon.CanCollide = false
    neon.Transparency = 0.5
    neon.Material = Enum.Material.Neon
    neon.Color = Color3.fromRGB(0, 255, 255)
    neon.Parent = Workspace
    return neon
end

local function UpdateHighlights()
    local playerPos = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.Position
    if not playerPos then return end

    if (playerPos - LastPlayerPos).Magnitude < UpdateDistance then
        return -- não atualiza se o jogador quase não se moveu
    end
    LastPlayerPos = playerPos

    local index = 1
    for _, part in ipairs(Workspace:GetDescendants()) do
        if part:IsA("BasePart") and part.Anchored and part.CanCollide then
            local partTop = part.Position.Y + part.Size.Y/2
            local distance = (Vector3.new(part.Position.X, 0, part.Position.Z) - Vector3.new(playerPos.X, 0, playerPos.Z)).Magnitude
            if distance < 20 then -- alcance máximo para highlight
                if not HighlightParts[index] then
                    HighlightParts[index] = CreateNeon(part)
                end
                HighlightParts[index].Size = Vector3.new(part.Size.X, 0.2, part.Size.Z)
                HighlightParts[index].CFrame = part.CFrame + Vector3.new(0, part.Size.Y/2, 0)
                index = index + 1
            end
        end
    end

    -- remove neons excedentes
    for i = index, #HighlightParts do
        HighlightParts[i]:Destroy()
        HighlightParts[i] = nil
    end
end

RunService.RenderStepped:Connect(UpdateHighlights)
