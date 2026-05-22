-- sudoku with friends debug scanner
-- use perto do tabuleiro e veja o Output/console

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")

local MAX_DISTANCE = 120
local results = {}

local function distFromPlayer(obj)
	local part

	if obj:IsA("BasePart") then
		part = obj
	elseif obj:IsA("Model") then
		part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
	else
		part = obj:FindFirstAncestorWhichIsA("BasePart")
	end

	if not part then
		return nil
	end

	return (part.Position - hrp.Position).Magnitude
end

local function safeFullName(obj)
	local ok, name = pcall(function()
		return obj:GetFullName()
	end)
	return ok and name or obj.Name
end

local function add(text)
	table.insert(results, text)
	print(text)
end

add("========== SUDOKU DEBUG SCAN ==========")
add("posição do player: " .. tostring(hrp.Position))
add("procurando objetos perto do player...")

for _, obj in ipairs(workspace:GetDescendants()) do
	local d = distFromPlayer(obj)

	if d and d <= MAX_DISTANCE then
		local class = obj.ClassName
		local name = obj.Name:lower()

		local interesting =
			obj:IsA("SurfaceGui")
			or obj:IsA("BillboardGui")
			or obj:IsA("TextLabel")
			or obj:IsA("TextButton")
			or obj:IsA("TextBox")
			or obj:IsA("IntValue")
			or obj:IsA("NumberValue")
			or obj:IsA("StringValue")
			or obj:IsA("ObjectValue")
			or name:find("sudoku")
			or name:find("board")
			or name:find("tabuleiro")
			or name:find("cell")
			or name:find("tile")
			or name:find("square")
			or name:find("grid")
			or name:find("number")
			or name:find("numero")

		if interesting then
			add("")
			add("OBJETO: " .. safeFullName(obj))
			add("CLASS: " .. class)
			add("DIST: " .. math.floor(d))

			if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
				add("TEXT: [" .. tostring(obj.Text) .. "]")
				add("VISIBLE: " .. tostring(obj.Visible))
				add("ABS POS: " .. tostring(obj.AbsolutePosition))
				add("ABS SIZE: " .. tostring(obj.AbsoluteSize))
			end

			if obj:IsA("IntValue") or obj:IsA("NumberValue") or obj:IsA("StringValue") or obj:IsA("ObjectValue") then
				add("VALUE: " .. tostring(obj.Value))
			end

			local attrs = obj:GetAttributes()
			for k, v in pairs(attrs) do
				add("ATTRIBUTE: " .. tostring(k) .. " = " .. tostring(v))
			end
		end
	end
end

add("")
add("========== SCAN FINALIZADO ==========")
add("total de linhas: " .. tostring(#results))
