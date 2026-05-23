-- Cerber X Role Detector
-- execute isso no Flee the Facility e me mande o output

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local function safeName(v)
	return v and tostring(v.Name) or "nil"
end

local function scanAttributes(obj)
	local results = {}

	if not obj then
		return results
	end

	local ok, attrs = pcall(function()
		return obj:GetAttributes()
	end)

	if ok and attrs then
		for k, v in pairs(attrs) do
			table.insert(results, tostring(k) .. "=" .. tostring(v))
		end
	end

	return results
end

local function scanValues(obj, depth)
	local results = {}

	if not obj then
		return results
	end

	depth = depth or 2

	local function scan(current, level)
		if level > depth then
			return
		end

		for _, child in ipairs(current:GetChildren()) do
			if child:IsA("StringValue") or child:IsA("BoolValue") or child:IsA("IntValue") or child:IsA("NumberValue") then
				table.insert(results, child:GetFullName() .. " = " .. tostring(child.Value))
			end

			scan(child, level + 1)
		end
	end

	pcall(function()
		scan(obj, 1)
	end)

	return results
end

local function scanTools(player)
	local results = {}

	local char = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")

	for _, container in ipairs({char, backpack}) do
		if container then
			for _, obj in ipairs(container:GetChildren()) do
				if obj:IsA("Tool") then
					table.insert(results, obj:GetFullName())
				end
			end
		end
	end

	return results
end

local function guessRole(player)
	local role = "Unknown"

	local teamName = player.Team and player.Team.Name or ""
	local lowerTeam = string.lower(teamName)

	if lowerTeam:find("beast") or lowerTeam:find("monster") then
		role = "Beast"
	elseif lowerTeam:find("survivor") or lowerTeam:find("runner") or lowerTeam:find("player") then
		role = "Survivor"
	end

	local allText = {}

	for _, v in ipairs(scanAttributes(player)) do
		table.insert(allText, v)
	end

	if player.Character then
		for _, v in ipairs(scanAttributes(player.Character)) do
			table.insert(allText, v)
		end
	end

	for _, v in ipairs(scanValues(player, 3)) do
		table.insert(allText, v)
	end

	if player.Character then
		for _, v in ipairs(scanValues(player.Character, 3)) do
			table.insert(allText, v)
		end
	end

	for _, v in ipairs(scanTools(player)) do
		table.insert(allText, v)
	end

	for _, text in ipairs(allText) do
		local lower = string.lower(text)

		if lower:find("beast") or lower:find("hammer") then
			role = "Beast"
		elseif lower:find("survivor") then
			if role ~= "Beast" then
				role = "Survivor"
			end
		end
	end

	return role
end

local output = {}
table.insert(output, "===== CERBER X ROLE DETECTOR =====")
table.insert(output, "LocalPlayer: " .. LocalPlayer.Name)
table.insert(output, "PlaceId: " .. tostring(game.PlaceId))
table.insert(output, "JobId: " .. tostring(game.JobId))
table.insert(output, "")

for _, player in ipairs(Players:GetPlayers()) do
	table.insert(output, "------------------------------")
	table.insert(output, "Player: " .. player.Name)
	table.insert(output, "DisplayName: " .. player.DisplayName)
	table.insert(output, "Team: " .. safeName(player.Team))
	table.insert(output, "Guessed Role: " .. guessRole(player))

	local attrs = scanAttributes(player)
	table.insert(output, "Player Attributes: " .. (#attrs > 0 and table.concat(attrs, ", ") or "none"))

	local char = player.Character
	local charAttrs = scanAttributes(char)
	table.insert(output, "Character Attributes: " .. (#charAttrs > 0 and table.concat(charAttrs, ", ") or "none"))

	local tools = scanTools(player)
	table.insert(output, "Tools: " .. (#tools > 0 and table.concat(tools, ", ") or "none"))

	local values = scanValues(player, 3)
	table.insert(output, "Player Values:")
	if #values > 0 then
		for _, v in ipairs(values) do
			table.insert(output, "  " .. v)
		end
	else
		table.insert(output, "  none")
	end

	if char then
		local charValues = scanValues(char, 3)
		table.insert(output, "Character Values:")
		if #charValues > 0 then
			for _, v in ipairs(charValues) do
				table.insert(output, "  " .. v)
			end
		else
			table.insert(output, "  none")
		end
	end
end

table.insert(output, "------------------------------")
table.insert(output, "ReplicatedStorage possible role-related objects:")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
	local n = string.lower(obj.Name)
	if n:find("role") or n:find("beast") or n:find("survivor") or n:find("playerdata") or n:find("round") then
		table.insert(output, obj:GetFullName() .. " [" .. obj.ClassName .. "]")
	end
end

local final = table.concat(output, "\n")
print(final)

if setclipboard then
	setclipboard(final)
	print("Role detector output copied to clipboard.")
else
	print("setclipboard não existe nesse executor, copie pelo console.")
end
