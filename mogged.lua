local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local keywords = {
	"moger", "mog", "stat", "score", "rating", "rate",
	"elo", "1v1", "battle", "result", "winner", "enemy", "you"
}

local function hasKeyword(s)
	s = tostring(s or ""):lower()
	for _, k in ipairs(keywords) do
		if s:find(k, 1, true) then
			return true
		end
	end
	return false
end

local function full(obj)
	local ok, name = pcall(function()
		return obj:GetFullName()
	end)
	return ok and name or tostring(obj)
end

print("===== MOGGED FORMULA / SCRIPT FINDER =====")

print("\n--- GUI 1v1 TREE ---")
local gui = PlayerGui:FindFirstChild("ScreenGui")
local frame = gui and gui:FindFirstChild("Frame")
local onevone = frame and frame:FindFirstChild("1v1")

if onevone then
	print("1v1 path:", full(onevone))

	for _, obj in ipairs(onevone:GetDescendants()) do
		if hasKeyword(obj.Name) or obj:IsA("LocalScript") or obj:IsA("ModuleScript") or obj:IsA("TextLabel") then
			local extra = ""

			if obj:IsA("TextLabel") or obj:IsA("TextButton") then
				extra = " | Text=" .. tostring(obj.Text)
			elseif obj:IsA("StringValue") or obj:IsA("BoolValue") or obj:IsA("IntValue") or obj:IsA("NumberValue") then
				extra = " | Value=" .. tostring(obj.Value)
			end

			print(full(obj), "[" .. obj.ClassName .. "]" .. extra)
		end
	end
else
	warn("Não achei PlayerGui.ScreenGui.Frame.1v1")
end

print("\n--- LOCAL SCRIPTS IN PLAYERGUI ---")
for _, obj in ipairs(PlayerGui:GetDescendants()) do
	if obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
		if hasKeyword(obj.Name) or hasKeyword(full(obj)) then
			print(full(obj), "[" .. obj.ClassName .. "]")
		end
	end
end

print("\n--- REPLICATEDSTORAGE CANDIDATES ---")
for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
	if hasKeyword(obj.Name) or obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
		print(full(obj), "[" .. obj.ClassName .. "]")
	end
end

print("\n--- CURRENT SCORE PATHS ---")

local function printLabel(pathName, obj)
	if obj and obj:IsA("TextLabel") then
		print(pathName .. " =", obj.Text, "| path:", full(obj))
	else
		print(pathName .. " = nil")
	end
end

if onevone then
	local you = onevone:FindFirstChild("You")
	local enemy = onevone:FindFirstChild("Enemy")
	local ending = onevone:FindFirstChild("end")

	printLabel("You MogerStat", you and you:FindFirstChild("Stat") and you.Stat:FindFirstChild("MogerStat"))
	printLabel("Enemy MogerStat", enemy and enemy:FindFirstChild("Stat") and enemy.Stat:FindFirstChild("MogerStat"))

	if ending then
		local endYou = ending:FindFirstChild("YOU")
		local endEnemy = ending:FindFirstChild("ENEMY")

		printLabel("End YOU MogerStat", endYou and endYou:FindFirstChild("MogerStat"))
		printLabel("End ENEMY MogerStat", endEnemy and endEnemy:FindFirstChild("MogerStat"))
	end
end

print("===== END =====")
