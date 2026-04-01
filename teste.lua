local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

-- PLAYER
local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local root = char:WaitForChild("HumanoidRootPart")

-- CONFIG
local MAP_CENTER = root.Position -- pega a posição UMA VEZ
local MAX_DISTANCE = 350

-- Função para ignorar players
local function isCharacter(part)
	local model = part:FindFirstAncestorOfClass("Model")
	return model and model:FindFirstChildOfClass("Humanoid")
end

-- Checa se está dentro da área (raio 350 do player no momento da ativação)
local function isInsideMap(part)
	return (part.Position - MAP_CENTER).Magnitude <= MAX_DISTANCE
end

-- Função para checar se a cor é verde aproximada
local function isGreen(part)
	local color = part.Color
	return color.G > color.R and color.G > color.B
end

-- Função para checar se é um tronco marrom
local function isBrownTrunk(part)
	local color = part.Color
	return color.R > 0.3 and color.G > 0.15 and color.B < 0.1
		and part.Size.Y > 2
end

-- Loop único (roda só uma vez)
for _, part in pairs(Workspace:GetDescendants()) do
	if part:IsA("BasePart") 
	and not isCharacter(part) 
	and isInsideMap(part) then
		
		if not part.CanCollide then
			
			if isGreen(part) then
				part:Destroy()
			else
				local aboveTrunk = false
				
				for _, checkPart in pairs(Workspace:GetDescendants()) do
					if checkPart:IsA("BasePart") and isBrownTrunk(checkPart) then
						
						local dx = math.abs(part.Position.X - checkPart.Position.X)
						local dz = math.abs(part.Position.Z - checkPart.Position.Z)
						
						if dx < 5 and dz < 5 and part.Position.Y > checkPart.Position.Y then
							aboveTrunk = true
							break
						end
					end
				end
				
				if not aboveTrunk then
					part:Destroy()
				end
			end
		end
	end
end
