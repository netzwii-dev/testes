-- CCF Parts seguro (remove apenas folhas/decorações)
local ignoreNames = {
    "Door", "Freezer", "Computer", "Locker", "Cabinet", "Armory", "Button"
}

for _, v in pairs(workspace:GetDescendants()) do
    if v:IsA("BasePart") and v.CanCollide == false then
        
        local skip = false
        -- ignora objetos pelo nome
        for _, name in pairs(ignoreNames) do
            if v.Name:lower():find(name:lower()) then
                skip = true
                break
            end
        end
        
        -- ignora personagens
        if v:IsDescendantOf(game.Players.LocalPlayer.Character) then
            skip = true
        end
        
        -- ignora partes grandes (paredes, freezers, armários)
        if v.Size.Magnitude > 10 then
            skip = true
        end

        if not skip then
            v.Transparency = 1
        end
    end
end

print("CCF Parts aplicado apenas nas folhas/decorações")
