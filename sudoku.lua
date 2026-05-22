-- sudoku with friends solver sem gui
-- mostra os números azuis nas casas vazias
-- quando você preencher a casa, o número azul some sozinho

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")

local connections = {}

local function clearOld()
	for _, conn in ipairs(connections) do
		pcall(function()
			conn:Disconnect()
		end)
	end

	table.clear(connections)

	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj.Name == "SolverValue" then
			obj:Destroy()
		end
	end
end

local function getDistanceFromBoard(surfaceGui)
	local part = surfaceGui:FindFirstAncestorWhichIsA("BasePart")

	if not part then
		return math.huge
	end

	return (part.Position - hrp.Position).Magnitude
end

local function findNearestBoard()
	local placedBoards = workspace:FindFirstChild("PlacedBoards")

	if not placedBoards then
		return nil
	end

	local bestGui = nil
	local bestDist = math.huge

	for _, obj in ipairs(placedBoards:GetDescendants()) do
		if obj:IsA("SurfaceGui") then
			local frame = obj:FindFirstChild("Frame")

			if frame then
				local hasCells = false

				for _, cell in ipairs(frame:GetChildren()) do
					if cell:GetAttribute("Row") and cell:GetAttribute("Col") then
						hasCells = true
						break
					end
				end

				if hasCells then
					local dist = getDistanceFromBoard(obj)

					if dist < bestDist then
						bestDist = dist
						bestGui = obj
					end
				end
			end
		end
	end

	return bestGui
end

local function readNumberFromCell(cell)
	local clue = cell:FindFirstChild("ClueValue")

	if clue and clue:IsA("TextLabel") then
		local txt = tostring(clue.Text or ""):gsub("%s+", "")

		if txt:match("^[1-9]$") then
			return tonumber(txt)
		end
	end

	local txt = tostring(cell.Text or ""):gsub("%s+", "")

	if txt:match("^[1-9]$") then
		return tonumber(txt)
	end

	for _, obj in ipairs(cell:GetChildren()) do
		if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
			if obj.Name ~= "SolverValue" then
				local t = tostring(obj.Text or ""):gsub("%s+", "")

				if t:match("^[1-9]$") then
					return tonumber(t)
				end
			end
		end
	end

	return 0
end

local function getCells(surfaceGui)
	local frame = surfaceGui:FindFirstChild("Frame")
	local cells = {}

	for _, cell in ipairs(frame:GetChildren()) do
		local row = cell:GetAttribute("Row")
		local col = cell:GetAttribute("Col")

		if typeof(row) == "number" and typeof(col) == "number" and row >= 1 and row <= 9 and col >= 1 and col <= 9 then
			cells[row] = cells[row] or {}
			cells[row][col] = cell
		end
	end

	return cells
end

local function buildGrid(cells)
	local grid = {}

	for r = 1, 9 do
		grid[r] = {}

		for c = 1, 9 do
			local cell = cells[r] and cells[r][c]

			if cell then
				grid[r][c] = readNumberFromCell(cell)
			else
				grid[r][c] = 0
			end
		end
	end

	return grid
end

local function copyGrid(grid)
	local new = {}

	for r = 1, 9 do
		new[r] = {}

		for c = 1, 9 do
			new[r][c] = grid[r][c]
		end
	end

	return new
end

local function canPlace(grid, num, row, col)
	for c = 1, 9 do
		if grid[row][c] == num then
			return false
		end
	end

	for r = 1, 9 do
		if grid[r][col] == num then
			return false
		end
	end

	local startRow = math.floor((row - 1) / 3) * 3 + 1
	local startCol = math.floor((col - 1) / 3) * 3 + 1

	for r = startRow, startRow + 2 do
		for c = startCol, startCol + 2 do
			if grid[r][c] == num then
				return false
			end
		end
	end

	return true
end

local function validateGrid(grid)
	for r = 1, 9 do
		for c = 1, 9 do
			local v = grid[r][c]

			if v ~= 0 then
				grid[r][c] = 0

				if not canPlace(grid, v, r, c) then
					grid[r][c] = v
					return false, "número repetido na linha " .. r .. ", coluna " .. c
				end

				grid[r][c] = v
			end
		end
	end

	return true
end

local function findEmpty(grid)
	for r = 1, 9 do
		for c = 1, 9 do
			if grid[r][c] == 0 then
				return r, c
			end
		end
	end

	return nil, nil
end

local function solve(grid)
	local row, col = findEmpty(grid)

	if not row then
		return true
	end

	for num = 1, 9 do
		if canPlace(grid, num, row, col) then
			grid[row][col] = num

			if solve(grid) then
				return true
			end

			grid[row][col] = 0
		end
	end

	return false
end

local function removeSolverNumber(cell)
	local solver = cell:FindFirstChild("SolverValue")

	if solver then
		solver:Destroy()
	end
end

local function addNumberOnCell(cell, number)
	removeSolverNumber(cell)

	local value = Instance.new("TextLabel")
	value.Name = "SolverValue"
	value.Size = UDim2.new(1, 0, 1, 0)
	value.Position = UDim2.new(0, 0, 0, 0)
	value.BackgroundTransparency = 1
	value.Text = tostring(number)
	value.TextColor3 = Color3.fromRGB(0, 170, 255)
	value.TextStrokeTransparency = 0
	value.TextScaled = true
	value.Font = Enum.Font.GothamBlack
	value.ZIndex = 999
	value.Parent = cell
end

local function watchCell(cell)
	local function check()
		task.wait()

		local current = readNumberFromCell(cell)

		if current ~= 0 then
			removeSolverNumber(cell)
		end
	end

	local clue = cell:FindFirstChild("ClueValue")

	if clue and clue:IsA("TextLabel") then
		table.insert(connections, clue:GetPropertyChangedSignal("Text"):Connect(check))
	end

	table.insert(connections, cell.ChildAdded:Connect(function(child)
		task.wait()

		if child.Name ~= "SolverValue" then
			check()

			if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
				table.insert(connections, child:GetPropertyChangedSignal("Text"):Connect(check))
			end
		end
	end))

	table.insert(connections, cell.ChildRemoved:Connect(function()
		task.wait()
		check()
	end))
end

clearOld()

local board = findNearestBoard()

if not board then
	warn("não achei nenhum tabuleiro em workspace.PlacedBoards")
	return
end

local cells = getCells(board)
local original = buildGrid(cells)

local ok, err = validateGrid(original)

if not ok then
	warn("erro no tabuleiro: " .. err)
	return
end

local solved = copyGrid(original)

if not solve(solved) then
	warn("não consegui resolver. talvez o tabuleiro ainda não carregou tudo ou tem número errado.")
	return
end

local count = 0

for r = 1, 9 do
	for c = 1, 9 do
		if original[r][c] == 0 then
			count += 1

			local number = solved[r][c]
			local cell = cells[r] and cells[r][c]

			if cell then
				addNumberOnCell(cell, number)
				watchCell(cell)
			end
		end
	end
end

print("sudoku resolvido. números mostrados: " .. count)
