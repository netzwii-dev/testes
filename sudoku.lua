-- sudoku with friends solver real scan
-- detecta workspace.PlacedBoards, lê Row/Col/ClueValue e coloca o número em cada quadrado

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")

local function getGuiParent()
	local ok, cg = pcall(function()
		return CoreGui
	end)

	if ok and cg then
		return cg
	end

	return player:WaitForChild("PlayerGui")
end

local function clearOld()
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj.Name == "SolverValue" or obj.Name == "SolverStroke" then
			obj:Destroy()
		end
	end

	local old = getGuiParent():FindFirstChild("SudokuSolverPanel")
	if old then
		old:Destroy()
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
			local t = tostring(obj.Text or ""):gsub("%s+", "")

			if t:match("^[1-9]$") then
				return tonumber(t)
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

local function addNumberOnCell(cell, number)
	local old = cell:FindFirstChild("SolverValue")
	if old then
		old:Destroy()
	end

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

local function createPanel(lines)
	local guiParent = getGuiParent()

	local gui = Instance.new("ScreenGui")
	gui.Name = "SudokuSolverPanel"
	gui.ResetOnSpawn = false
	gui.Parent = guiParent

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 300, 0, 390)
	frame.Position = UDim2.new(0, 20, 0.5, -195)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	frame.BorderSizePixel = 0
	frame.Parent = gui

	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -45, 0, 38)
	title.Position = UDim2.new(0, 10, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "sudoku resolvido"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 18
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local close = Instance.new("TextButton")
	close.Size = UDim2.new(0, 32, 0, 30)
	close.Position = UDim2.new(1, -37, 0, 5)
	close.BackgroundColor3 = Color3.fromRGB(180, 45, 45)
	close.Text = "X"
	close.TextColor3 = Color3.fromRGB(255, 255, 255)
	close.TextSize = 16
	close.Font = Enum.Font.GothamBold
	close.Parent = frame

	Instance.new("UICorner", close).CornerRadius = UDim.new(0, 8)

	close.MouseButton1Click:Connect(function()
		gui:Destroy()
	end)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -20, 1, -50)
	scroll.Position = UDim2.new(0, 10, 0, 42)
	scroll.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.Parent = frame

	Instance.new("UICorner", scroll).CornerRadius = UDim.new(0, 10)

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 5)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 7)
	padding.PaddingLeft = UDim.new(0, 7)
	padding.PaddingRight = UDim.new(0, 7)
	padding.PaddingBottom = UDim.new(0, 7)
	padding.Parent = scroll

	for _, text in ipairs(lines) do
		local item = Instance.new("TextLabel")
		item.Size = UDim2.new(1, -8, 0, 29)
		item.BackgroundColor3 = Color3.fromRGB(48, 48, 48)
		item.Text = "  " .. text
		item.TextColor3 = Color3.fromRGB(255, 255, 255)
		item.TextSize = 13
		item.Font = Enum.Font.Gotham
		item.TextXAlignment = Enum.TextXAlignment.Left
		item.Parent = scroll

		Instance.new("UICorner", item).CornerRadius = UDim.new(0, 7)
	end

	task.defer(function()
		scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 15)
	end)
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

local lines = {}
local count = 0

for r = 1, 9 do
	for c = 1, 9 do
		if original[r][c] == 0 then
			count += 1

			local number = solved[r][c]
			local cell = cells[r] and cells[r][c]

			if cell then
				addNumberOnCell(cell, number)
			end

			table.insert(lines, "linha " .. r .. " | coluna " .. c .. " = " .. number)
		end
	end
end

if count == 0 then
	table.insert(lines, "tabuleiro já está completo")
end

createPanel(lines)

print("sudoku resolvido. casas preenchidas pelo helper: " .. count)
