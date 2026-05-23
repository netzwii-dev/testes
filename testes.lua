-- Cerber X - FTF Computer Detector
-- Execute no Flee the Facility, fique perto de um PC que você consegue interagir,
-- tente começar/terminar um pouco o hack e depois me mande o output copiado.

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local function getHRP()
	local char = LocalPlayer.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function getPos(obj)
	if not obj or not obj.Parent then
		return nil
	end

	if obj:IsA("BasePart") then
		return obj.Position
	end

	if obj:IsA("Model") then
		local ok, cf = pcall(function()
			return obj:GetPivot()
		end)
		if ok and cf then
			return cf.Position
		end

		local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
		if part then
			return part.Position
		end
	end

	local part = obj:FindFirstAncestorWhichIsA("BasePart")
	if part then
		return part.Position
	end

	local model = obj:FindFirstAncestorOfClass("Model")
	if model then
		return getPos(model)
	end

	return nil
end

local function distFromMe(obj)
	local hrp = getHRP()
	local pos = getPos(obj)
	if not hrp or not pos then
		return math.huge
	end
	return (pos - hrp.Position).Magnitude
end

local function safeValue(obj)
	if obj:IsA("StringValue") or obj:IsA("BoolValue") or obj:IsA("IntValue") or obj:IsA("NumberValue") then
		return tostring(obj.Value)
	end
	return nil
end

local function hasComputerText(obj)
	local text = tostring(obj.Name or ""):lower()

	if obj:IsA("ProximityPrompt") then
		text ..= " " .. tostring(obj.ActionText or ""):lower()
		text ..= " " .. tostring(obj.ObjectText or ""):lower()
	end

	return text:find("computer", 1, true)
		or text:find("hack", 1, true)
		or text:find("pc", 1, true)
		or text:find("screen", 1, true)
		or text:find("monitor", 1, true)
		or text:find("keyboard", 1, true)
		or text:find("progress", 1, true)
		or text:find("percentage", 1, true)
		or text:find("percent", 1, true)
end

local function getTopModel(obj)
	local current = obj
	local best = nil

	while current and current ~= workspace do
		if current:IsA("Model") then
			best = current
		end
		current = current.Parent
	end

	return best or obj
end

local function shortChildren(model)
	local names = {}
	local count = 0

	for _, child in ipairs(model:GetChildren()) do
		count += 1
		if count <= 35 then
			table.insert(names, child.Name .. "[" .. child.ClassName .. "]")
		end
	end

	if count > 35 then
		table.insert(names, "... +" .. tostring(count - 35) .. " more")
	end

	return table.concat(names, ", ")
end

local function inspectModel(model)
	local lines = {}
	table.insert(lines, "MODEL: " .. model:GetFullName())
	table.insert(lines, "CLASS: " .. model.ClassName)
	table.insert(lines, "DISTANCE: " .. string.format("%.1f", distFromMe(model)))
	table.insert(lines, "CHILDREN: " .. shortChildren(model))

	local prompts = {}
	local detectors = {}
	local values = {}
	local remotes = {}
	local namedParts = {}

	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("ProximityPrompt") then
			table.insert(prompts, d:GetFullName() .. " | ActionText=" .. tostring(d.ActionText) .. " | ObjectText=" .. tostring(d.ObjectText) .. " | Enabled=" .. tostring(d.Enabled))
		elseif d:IsA("ClickDetector") then
			table.insert(detectors, d:GetFullName() .. " | MaxActivationDistance=" .. tostring(d.MaxActivationDistance))
		elseif d:IsA("StringValue") or d:IsA("BoolValue") or d:IsA("IntValue") or d:IsA("NumberValue") then
			table.insert(values, d:GetFullName() .. " = " .. tostring(d.Value))
		elseif d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("BindableEvent") or d:IsA("BindableFunction") then
			table.insert(remotes, d:GetFullName() .. " [" .. d.ClassName .. "]")
		elseif d:IsA("BasePart") and hasComputerText(d) then
			table.insert(namedParts, d:GetFullName() .. " | Size=" .. tostring(d.Size) .. " | Transparency=" .. tostring(d.Transparency) .. " | CanCollide=" .. tostring(d.CanCollide))
		end
	end

	table.insert(lines, "PROMPTS:")
	if #prompts > 0 then
		for _, v in ipairs(prompts) do table.insert(lines, "  " .. v) end
	else
		table.insert(lines, "  none")
	end

	table.insert(lines, "CLICK DETECTORS:")
	if #detectors > 0 then
		for _, v in ipairs(detectors) do table.insert(lines, "  " .. v) end
	else
		table.insert(lines, "  none")
	end

	table.insert(lines, "VALUES:")
	if #values > 0 then
		for i, v in ipairs(values) do
			if i <= 80 then
				table.insert(lines, "  " .. v)
			end
		end
		if #values > 80 then
			table.insert(lines, "  ... +" .. tostring(#values - 80) .. " more values")
		end
	else
		table.insert(lines, "  none")
	end

	table.insert(lines, "REMOTES/BINDABLES:")
	if #remotes > 0 then
		for _, v in ipairs(remotes) do table.insert(lines, "  " .. v) end
	else
		table.insert(lines, "  none")
	end

	table.insert(lines, "NAMED PARTS:")
	if #namedParts > 0 then
		for i, v in ipairs(namedParts) do
			if i <= 60 then
				table.insert(lines, "  " .. v)
			end
		end
		if #namedParts > 60 then
			table.insert(lines, "  ... +" .. tostring(#namedParts - 60) .. " more parts")
		end
	else
		table.insert(lines, "  none")
	end

	return table.concat(lines, "\n")
end

local function scan()
	local found = {}
	local added = {}

	for _, obj in ipairs(workspace:GetDescendants()) do
		if hasComputerText(obj) or obj:IsA("ProximityPrompt") or obj:IsA("ClickDetector") then
			local root = getTopModel(obj)
			if root and root.Parent and not added[root] then
				local dist = distFromMe(root)
				if dist <= 700 then
					added[root] = true
					table.insert(found, {root = root, dist = dist})
				end
			end
		end
	end

	table.sort(found, function(a, b)
		return a.dist < b.dist
	end)

	local out = {}
	table.insert(out, "===== CERBER X FTF COMPUTER DETECTOR =====")
	table.insert(out, "PlaceId: " .. tostring(game.PlaceId))
	table.insert(out, "LocalPlayer: " .. LocalPlayer.Name)
	local hrp = getHRP()
	table.insert(out, "MyPosition: " .. (hrp and tostring(hrp.Position) or "nil"))
	table.insert(out, "Candidates found within 700 studs: " .. tostring(#found))
	table.insert(out, "")

	for i, info in ipairs(found) do
		if i <= 15 then
			table.insert(out, "-------------------- #" .. tostring(i) .. " --------------------")
			table.insert(out, inspectModel(info.root))
			table.insert(out, "")
		end
	end

	local final = table.concat(out, "\n")
	print(final)

	if setclipboard then
		setclipboard(final)
		print("Cerber X Computer Detector: output copiado pro clipboard.")
	else
		print("Cerber X Computer Detector: copie o output do console.")
	end
end

-- Scan inicial
scan()

-- Monitor de mudanças por 25 segundos enquanto você interage/hackeia.
local watching = true
task.delay(25, function()
	watching = false
	print("Cerber X Computer Detector: monitoramento encerrado.")
end)

local changed = {}

local function logChange(obj, extra)
	if not watching then return end
	local root = getTopModel(obj)
	local d = distFromMe(root)
	if d > 700 then return end

	local line = "[CHANGE] " .. obj:GetFullName() .. " [" .. obj.ClassName .. "]"
	if extra then line ..= " | " .. extra end
	if not changed[line] then
		changed[line] = true
		print(line)
	end
end

for _, obj in ipairs(workspace:GetDescendants()) do
	if obj:IsA("StringValue") or obj:IsA("BoolValue") or obj:IsA("IntValue") or obj:IsA("NumberValue") then
		pcall(function()
			obj.Changed:Connect(function()
				logChange(obj, "Value=" .. tostring(obj.Value))
			end)
		end)
	elseif obj:IsA("ProximityPrompt") then
		pcall(function()
			obj.Triggered:Connect(function(player)
				logChange(obj, "TriggeredBy=" .. tostring(player))
			end)
		end)
	end
end

workspace.DescendantAdded:Connect(function(obj)
	if watching and (hasComputerText(obj) or obj:IsA("ProximityPrompt") or obj:IsA("ClickDetector")) then
		task.wait(0.1)
		logChange(obj, "ADDED")
	end
end)

print("Agora tente interagir/hackear um PC por alguns segundos e depois me mande os [CHANGE] e o output copiado.")
