for _, obj in ipairs(workspace:GetDescendants()) do
    if obj:IsA("BasePart") or obj:IsA("MeshPart") then
        local name = obj.Name:lower()
        
        if name:find("ccf") then
            obj.Transparency = 1
            obj.CanCollide = false
        end
    end
end
