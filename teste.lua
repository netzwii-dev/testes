-- FTF Homestead: remove folhas que atrapalham visão
local Workspace = game:GetService("Workspace")

-- Palavras-chaves que geralmente indicam folhas ou arbustos
local LEAF_KEYWORDS = {"leaf","leaves","bush","grass","plant"}

local function isLeaf(obj)
    local name = obj.Name:lower()
    for _, keyword in ipairs(LEAF_KEYWORDS) do
        if name:find(keyword) then
            return true
        end
    end
    return false
end

for _, obj in ipairs(Workspace:GetDescendants()) do
    if obj:IsA("BasePart") or obj:IsA("MeshPart") then
        if isLeaf(obj) then
            obj.Transparency = 1
            obj.CanCollide = false -- folhas atravessáveis
        end
    end
end

print("Folhas do mapa Homestead removidas")
