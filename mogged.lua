-- Mogged [Skins Battle] - Score/Value Detector
-- Use para descobrir onde a nota/valor aparece e o que muda quando o resultado é calculado.
-- Ele não altera nada: só lê GUI, Values, Attributes e possíveis Remotes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local WATCH_SECONDS = 45

local keywords = {
	"score", "rating", "rate", "points", "point", "elo", "value", "valor", "nota",
	"mog", "mogged", "skin", "battle", "win", "winner", "result", "resultado",
	"vote", "voto", "rank", "level", "avatar", "appearance"
}

local function low(s)
	return tostring(s or ""):lower()
end

local function hasKeyword(s)
	s = low(s)
	for _, k in ipairs(keywords) do
		if s:find(k, 1, true) then
			return true
		end
	end
	return false
end

local function safeFullName(obj)
	local ok, name = pcall(function()
		return obj:GetFullName()
	end)
	return ok and name or tostring(obj)
end

local function isNumericScoreText(txt)
	txt = tostring(txt or "")
	return txt:match("^%s*[%+%-]?%d+%.?%d*%s*$")
		or txt:match("^%s*[%+%-]?%d+%s*ELO%s*$")
		or txt:match("^%s*[%+%-]?%d+%.?%d*%s*/%s*10%s*$")
end

local function isValueObject(obj)
	return obj:IsA("StringValue")
		or obj:IsA("BoolValue")
		or obj:IsA("IntValue")
		or obj:IsA("NumberValue")
end

local function getValue(obj)
	if isValueObject(obj) then
		return tostring(obj.Value)
	end
	return nil
end

local function printAttrs(obj, prefix)
	local ok, attrs = pcall(function()
		return obj:GetAttributes()
	end)

	if ok and attrs then
		for k, v in pairs(attrs) do
			if hasKeyword(k) or hasKeyword(v) or isNumericScoreText(v) then
				print(prefix .. "ATTR", safeFullName(obj), "|", tostring(k), "=", tostring(v))
			end
		end
	end
end

local function dumpGui()
	print("\n========== GUI TEXTS ==========")

	local count = 0

	for _, obj in ipairs(PlayerGui:GetDescendants()) do
		if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
			local txt = tostring(obj.Text or "")
			if txt ~= "" and (hasKeyword(txt) or hasKeyword(obj.Name) or isNumericScoreText(txt)) then
				count += 1
				print("GUI", safeFullName(obj), "| Name:", obj.Name, "| Text:", txt, "| Visible:", tostring(obj.Visible))
			end
		end
	end

	print("GUI candidates:", count)
end

local function dumpPlayerData()
	print("\n========== PLAYER DATA ==========")

	for _, plr in ipairs(Players:GetPlayers()) do
		print("\nPLAYER:", plr.Name, "| Display:", plr.DisplayName, "| Team:", plr.Team and plr.Team.Name or "nil")
		printAttrs(plr, "  ")

		local leaderstats = plr:FindFirstChild("leaderstats")
		if leaderstats then
			for _, obj in ipairs(leaderstats:GetDescendants()) do
				if isValueObject(obj) then
					print("  LEADERSTAT", safeFullName(obj), "=", tostring(obj.Value))
				end
			end
		end

		for _, obj in ipairs(plr:GetDescendants()) do
			if isValueObject(obj) then
				local v = tostring(obj.Value)
				if hasKeyword(obj.Name) or hasKeyword(v) or isNumericScoreText(v) then
					print("  VALUE", safeFullName(obj), "=", v)
				end
			end
		end

		local char = plr.Character
		if char then
			printAttrs(char, "  CHAR ")
			for _, obj in ipairs(char:GetDescendants()) do
				if isValueObject(obj) then
					local v = tostring(obj.Value)
					if hasKeyword(obj.Name) or hasKeyword(v) or isNumericScoreText(v) then
						print("  CHAR VALUE", safeFullName(obj), "=", v)
					end
				end
			end
		end
	end
end

local function dumpReplicatedStorage()
	print("\n========== REPLICATED STORAGE ==========")

	local count = 0

	for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
		if hasKeyword(obj.Name) or obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or obj:IsA("ModuleScript") then
			count += 1
			if count <= 300 then
				print("RS", safeFullName(obj), "[" .. obj.ClassName .. "]")
			end
		end
	end

	print("RS candidates:", count)
end

local changes = {}

local function logChange(obj, value)
	local key = safeFullName(obj) .. " -> " .. tostring(value)
	if changes[key] then
		return
	end

	changes[key] = true
	print("[CHANGE]", safeFullName(obj), "[" .. obj.ClassName .. "] =", tostring(value))
end

local function attachWatch(obj)
	if isValueObject(obj) then
		local v = tostring(obj.Value)
		if hasKeyword(obj.Name) or hasKeyword(v) or isNumericScoreText(v) then
			pcall(function()
				obj.Changed:Connect(function()
					logChange(obj, obj.Value)
				end)
			end)
		end
	elseif obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
		pcall(function()
			obj:GetPropertyChangedSignal("Text"):Connect(function()
				local txt = tostring(obj.Text or "")
				if txt ~= "" and (hasKeyword(txt) or hasKeyword(obj.Name) or isNumericScoreText(txt)) then
					logChange(obj, txt)
				end
			end)
		end)
	elseif obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
		if hasKeyword(obj.Name) then
			print("[REMOTE CANDIDATE]", safeFullName(obj), "[" .. obj.ClassName .. "]")
		end
	end
end

local function startWatcher()
	print("\n========== WATCHER STARTED ==========")
	print("Termine uma batalha/agora espere a nota aparecer. Monitorando por", WATCH_SECONDS, "segundos.")

	for _, root in ipairs({PlayerGui, LocalPlayer, ReplicatedStorage, workspace}) do
		for _, obj in ipairs(root:GetDescendants()) do
			attachWatch(obj)
		end

		root.DescendantAdded:Connect(function(obj)
			task.wait(0.05)
			attachWatch(obj)

			if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
				local txt = tostring(obj.Text or "")
				if txt ~= "" and (hasKeyword(txt) or isNumericScoreText(txt)) then
					print("[NEW GUI TEXT]", safeFullName(obj), "=", txt)
				end
			elseif isValueObject(obj) then
				local v = tostring(obj.Value)
				if hasKeyword(obj.Name) or hasKeyword(v) or isNumericScoreText(v) then
					print("[NEW VALUE]", safeFullName(obj), "=", v)
				end
			end
		end)
	end

	task.delay(WATCH_SECONDS, function()
		print("\n========== WATCHER ENDED ==========")
		print("Me mande os [CHANGE], [NEW GUI TEXT], VALUE ou REMOTE que aparecerem perto da nota.")
	end)
end

print("===== MOGGED SCORE/VALUE DETECTOR =====")
print("PlaceId:", game.PlaceId)
print("JobId:", game.JobId)
print("LocalPlayer:", LocalPlayer.Name)
print("Time:", os.date("%X"))

dumpGui()
dumpPlayerData()
dumpReplicatedStorage()
startWatcher()

print("===== SCAN INICIAL FINALIZADO =====")
print("Quando aparecer valor tipo 3.7 / 7.3 / ELO, copie o output do console.")
