-- Mogged [Skins Battle] - RoundEnd Score Full Logger
-- Read-only: não altera nada. Só escuta o MatchEvent e imprime o resultado completo.
-- Objetivo: pegar SkinScore, TeamScores, EloDelta e descobrir se a nota vem pronta do servidor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local AGGameRemotes = ReplicatedStorage:WaitForChild("AGGameRemotes")
local MatchEvent = AGGameRemotes:WaitForChild("MatchEvent")

local logs = {}

local function fullName(obj)
	local ok, result = pcall(function()
		return obj:GetFullName()
	end)
	return ok and result or tostring(obj)
end

local function serialize(value, depth, visited)
	depth = depth or 0
	visited = visited or {}

	if depth > 8 then
		return "..."
	end

	local t = typeof(value)

	if t == "Instance" then
		return fullName(value) .. " [" .. value.ClassName .. "]"
	end

	if t ~= "table" then
		return tostring(value)
	end

	if visited[value] then
		return "<recursive>"
	end
	visited[value] = true

	local parts = {}
	local keys = {}

	for k in pairs(value) do
		table.insert(keys, k)
	end

	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)

	for _, k in ipairs(keys) do
		local v = value[k]
		table.insert(parts, string.rep("  ", depth + 1) .. "[" .. tostring(k) .. "] = " .. serialize(v, depth + 1, visited))
	end

	visited[value] = nil

	if #parts == 0 then
		return "{}"
	end

	return "{\n" .. table.concat(parts, ",\n") .. "\n" .. string.rep("  ", depth) .. "}"
end

local function addLog(text)
	table.insert(logs, text)
	print(text)
end

local function copyLogs()
	local final = table.concat(logs, "\n")

	if setclipboard then
		setclipboard(final)
		print("Mogged RoundEnd Logger: output copiado para o clipboard.")
	else
		print("Mogged RoundEnd Logger: seu executor não tem setclipboard, copie pelo console.")
	end
end

local function tryExtractRoundEnd(data)
	if typeof(data) ~= "table" then
		return
	end

	addLog("\n========== ROUNDEND EXTRACT ==========")

	if data.matchId then
		addLog("matchId = " .. tostring(data.matchId))
	end

	if data.mode then
		addLog("mode = " .. tostring(data.mode))
	end

	if data.isDraw ~= nil then
		addLog("isDraw = " .. tostring(data.isDraw))
	end

	if data.winningTeamIndex ~= nil then
		addLog("winningTeamIndex = " .. tostring(data.winningTeamIndex))
	end

	if data.TeamScores then
		addLog("TeamScores:")
		for teamIndex, score in pairs(data.TeamScores) do
			addLog("  Team " .. tostring(teamIndex) .. " = " .. tostring(score))
		end
	end

	if data.results then
		addLog("results:")
		for i, result in pairs(data.results) do
			if typeof(result) == "table" then
				addLog("  Result #" .. tostring(i))
				addLog("    Name = " .. tostring(result.Name))
				addLog("    DisplayName = " .. tostring(result.DisplayName))
				addLog("    UserId = " .. tostring(result.UserId))
				addLog("    TeamIndex = " .. tostring(result.TeamIndex))
				addLog("    SkinScore = " .. tostring(result.SkinScore))
				addLog("    EloBefore = " .. tostring(result.EloBefore))
				addLog("    EloAfter = " .. tostring(result.EloAfter))
				addLog("    EloDelta = " .. tostring(result.EloDelta))
				addLog("    Outcome = " .. tostring(result.Outcome))
			else
				addLog("  Result #" .. tostring(i) .. " = " .. tostring(result))
			end
		end
	end

	addLog("======================================\n")
end

print("===== MOGGED ROUNDEND SCORE LOGGER START =====")
print("LocalPlayer:", LocalPlayer.Name)
print("MatchEvent:", fullName(MatchEvent))
print("Agora termine uma partida. Quando sair RoundEnd, ele vai imprimir tudo e tentar copiar o output.")

MatchEvent.OnClientEvent:Connect(function(eventName, data)
	addLog("\n[MatchEvent] " .. tostring(eventName))

	if eventName == "RoundEnd" then
		addLog("FULL DATA:")
		addLog(serialize(data))
		tryExtractRoundEnd(data)

		task.delay(0.2, copyLogs)
	elseif eventName == "MatchFound" or eventName == "RoundStart" then
		addLog("DATA:")
		addLog(serialize(data))
	end
end)

-- Também tenta mostrar os valores atuais da GUI no momento da execução.
task.defer(function()
	local pg = LocalPlayer:FindFirstChild("PlayerGui")
	local sg = pg and pg:FindFirstChild("ScreenGui")
	local frame = sg and sg:FindFirstChild("Frame")
	local one = frame and frame:FindFirstChild("1v1")

	if one then
		local function getText(...)
			local obj = one
			for _, name in ipairs({...}) do
				obj = obj and obj:FindFirstChild(name)
			end
			return obj and obj:IsA("TextLabel") and obj.Text or "nil"
		end

		addLog("\nCURRENT GUI:")
		addLog("YouLive = " .. getText("You", "Stat", "MogerStat"))
		addLog("EnemyLive = " .. getText("Enemy", "Stat", "MogerStat"))
		addLog("YouEnd = " .. getText("end", "YOU", "MogerStat"))
		addLog("EnemyEnd = " .. getText("end", "ENEMY", "MogerStat"))
	end
end)
