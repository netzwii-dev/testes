-- Só remove FOLHAS (FTF Homestead) sem tocar no resto

local function isVegetation(obj)
    local name = obj.Name:lower()

    -- elementos típicos de folhagem
    local vegTerms = {"leaf","leaves","grass","bush","plant"}

    for _, term in ipairs(vegTerms) do
        if name:find(term) then
            return true
        end
    end

    -- também tenta detectar malhas que são claramente vegetação
    if obj:IsA("MeshPart") then
        local meshId = tostring(obj.MeshId):lower()
        if meshId:find("leaf") or meshId:find("grass") then
            return true
        end
    end

    return false
end

for _, v in pairs(workspace:GetDescendants()) do
    if v:IsA("BasePart") then

        -- ignora partes essenciais do jogador
        if v:IsDescendantOf(game.Players.LocalPlayer.Character) then
            continue
        end

        -- só vegetação não colidível e pequena
        if (not v.CanCollide)
        and isVegetation(v)
        and v.Size.Magnitude < 8 -- folhas normalmente pequenas
        then
            v.Transparency = 1
        end
    end
end

print("Folhagens do mapa Homestead removidas com segurança!")
