-- Mogged [Skins Battle] - Focused MogerStat / RemoteEvent Detector
-- Seguro/read-only: não altera nota, não chama RemoteFunction e não mexe em valores.
-- Objetivo: descobrir melhor de onde a nota aparece e quais RemoteEvents do servidor disparam perto da mudança.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local AGRemotes = ReplicatedStorage:WaitForChild("AGGameRemotes", 10)

local function full(obj)
	local ok, name = pcall(function()
		return obj:GetFullName()
	end)
	return ok and name or tostring(obj)
end

local function serialize(v, depth)
	depth = depth or 0
	if depth > 2 then
		return "..."
	end

	local t = typeof(v)

	if t == "Instance" then
		return full(v) .. " [" .. v.ClassName .. "]"
	elseif t == "table" then
		local parts = {}
		local count = 0

		for k, val in pairs(v) do
			count += 1
			if count > 20 then
				table.insert(parts, "...+" .. tostring(count - 20))
				break
			end

			table.insert(parts, "[" .. tostring(k) .. "]=" .. serialize(val, depth + 1))
		end

		return "{" .. table.concat(parts, ", ") .. "}"
	else
		return tostring(v)
	end
end

local function get1v1()
	local screenGui = PlayerGui:FindFirstChild("ScreenGui")
	local frame = screenGui and screenGui:FindFirstChild("Frame")
	return frame and frame:FindFirstChild("1v1")
end

local function getLabel(path)
	local obj = get1v1()
	if not obj then
		return nil
	end

	for _, name in ipairs(path) do
		obj = obj and obj:FindFirstChild(name)
	end

	if obj and obj:IsA("TextLabel") then
		return obj
	end

	return nil
end

local labels = {
	YouLive = {"You", "Stat", "MogerStat"},
	EnemyLive = {"Enemy", "Stat", "MogerStat"},
	YouEnd = {"end", "YOU", "MogerStat"},
	EnemyEnd = {"end", "ENEMY", "MogerStat"},
	YouElo = {"You", "Stat", "Elo"},
	EnemyElo = {"Enemy", "Stat", "Elo"},
	EndYouElo = {"end", "YOU", "Elo"},
	EndEnemyElo = {"end", "ENEMY", "Elo"},
	Timer = {"TIMER"},
	PreStartTimer = {"PreStart", "Timer"},
}

local lastText = {}
local recentRemoteEvents = {}

local function logRemote(name, args)
	local line = os.date("%X") .. " | " .. name .. " | " .. args
	table.insert(recentRemoteEvents, line)

	if #recentRemoteEvents > 15 then
		table.remove(recentRemoteEvents, 1)
	end

	print("[REMOTE EVENT]", line)
end

local function printRecentRemotes()
	if #recentRemoteEvents == 0 then
		print("  recent remotes: none")
		return
	end

	print("  recent remotes:")
	for _, line in ipairs(recentRemoteEvents) do
		print("   ", line)
	end
end

local function readCurrent()
	local current = {}

	for key, path in pairs(labels) do
		local label = getLabel(path)
		current[key] = label and tostring(label.Text) or "nil"
	end

	return current
end

local function printCurrentSnapshot(reason)
	local c = readCurrent()

	print("\n========== MOGGED SCORE SNAPSHOT:", reason, "==========")
	print("YouLive:", c.YouLive)
	print("EnemyLive:", c.EnemyLive)
	print("YouEnd:", c.YouEnd)
	print("EnemyEnd:", c.EnemyEnd)
	print("YouElo:", c.YouElo)
	print("EnemyElo:", c.EnemyElo)
	print("EndYouElo:", c.EndYouElo)
	print("EndEnemyElo:", c.EndEnemyElo)
	print("Timer:", c.Timer)
	print("PreStartTimer:", c.PreStartTimer)
	printRecentRemotes()
	print("====================================================\n")
end

local function attachLabelWatcher(key, label)
	if not label or lastText[label] ~= nil then
		return
	end

	lastText[label] = tostring(label.Text)

	print("[LABEL FOUND]", key, full(label), "=", tostring(label.Text))

	label:GetPropertyChangedSignal("Text"):Connect(function()
		local newText = tostring(label.Text)
		local oldText = lastText[label]

		if newText ~= oldText then
			lastText[label] = newText
			print("[MOGER CHANGE]", key, full(label), ":", tostring(oldText), "->", newText)

			if key == "YouEnd" or key == "EnemyEnd" or key == "EndYouElo" or key == "EndEnemyElo" then
				printCurrentSnapshot("END VALUE CHANGED")
			end
		end
	end)
end

local function scanLabels()
	local onevone = get1v1()
	if not onevone then
		return
	end

	for key, path in pairs(labels) do
		local label = getLabel(path)
		if label then
			attachLabelWatcher(key, label)
		end
	end
end

local function connectRemoteEvents()
	if not AGRemotes then
		warn("AGGameRemotes não encontrado.")
		return
	end

	print("\n========== AGGameRemotes ==========")

	for _, obj in ipairs(AGRemotes:GetDescendants()) do
		if obj:IsA("RemoteEvent") then
			print("[CONNECT REMOTE EVENT]", full(obj))

			obj.OnClientEvent:Connect(function(...)
				local args = table.pack(...)
				local parts = {}

				for i = 1, args.n do
					table.insert(parts, "#" .. tostring(i) .. "=" .. serialize(args[i]))
				end

				logRemote(full(obj), table.concat(parts, " | "))
			end)
		elseif obj:IsA("RemoteFunction") then
			print("[REMOTE FUNCTION FOUND]", full(obj), "-- não dá pra ouvir passivamente sem hook.")
		end
	end

	print("===================================\n")
end

local function listImportant()
	print("===== IMPORTANT PATHS =====")

	local analyze = AGRemotes and AGRemotes:FindFirstChild("AnalyzePreviewSkin")
	if analyze then
		print("AnalyzePreviewSkin:", full(analyze), "[" .. analyze.ClassName .. "]")
	end

	local match = AGRemotes and AGRemotes:FindFirstChild("MatchEvent")
	if match then
		print("MatchEvent:", full(match), "[" .. match.ClassName .. "]")
	end

	local rankConfig = ReplicatedStorage:FindFirstChild("AGRankConfig")
	if rankConfig then
		print("AGRankConfig:", full(rankConfig), "[" .. rankConfig.ClassName .. "]")
	end

	local moger = ReplicatedStorage:FindFirstChild("Moger")
	if moger then
		print("Moger:", full(moger), "[" .. moger.ClassName .. "]")
	end

	print("===========================\n")
end

print("===== MOGGED FOCUSED DETECTOR START =====")
print("PlaceId:", game.PlaceId)
print("LocalPlayer:", LocalPlayer.Name)

listImportant()
connectRemoteEvents()

-- tenta achar labels já existentes
scanLabels()
printCurrentSnapshot("INITIAL")

-- continua procurando caso a tela 1v1 recrie a GUI
PlayerGui.DescendantAdded:Connect(function(obj)
	task.defer(function()
		if obj:IsA("TextLabel") then
			local name = full(obj)
			if name:find("MogerStat", 1, true) or name:find("Elo", 1, true) or name:find("TIMER", 1, true) then
				scanLabels()
			end
		end
	end)
end)

task.spawn(function()
	while task.wait(0.25) do
		scanLabels()
	end
end)

print("Detector ativo. Entre/termine uma batalha e copie:")
print("- [MOGER CHANGE]")
print("- [REMOTE EVENT]")
print("- snapshots de END VALUE CHANGED")
print("===== MOGGED FOCUSED DETECTOR READY =====")
