-- sudoku with friends helper
-- escaneia números visíveis no tabuleiro, resolve e mostra o que colocar

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local function getParentGui()
	local ok, cg = pcall(function()
		return CoreGui
	end)

	if ok and cg then
		return cg
	end

	return PlayerGui
end

local guiParent = getParentGui()

local old = guiParent:FindFirstChild("SudokuWithFriendsHelper")
if old then
	old:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SudokuWithFriendsHelper"
screenGui.ResetOnSpawn = false
screenGui.Parent = guiParent

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 360, 0, 460)
main.Position = UDim2.new(0, 25, 0.5, -230)
main.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
main.BorderSizePixel = 0
main.Parent = screenGui

Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -50, 0, 40)
title.Position = UDim2.new(0, 12, 0, 0)
title.BackgroundTransparency = 1
title.Text = "sudoku helper"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 21
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = main

local close = Instance.new("TextButton")
close.Size = UDim2.new(0, 35, 0, 32)
close.Position = UDim2.new(1, -42, 0, 5)
close.BackgroundColor3 = Color3.fromRGB(170, 45, 45)
close.Text = "X"
close.TextColor3 = Color3.fromRGB(255, 255, 255)
close.TextSize = 18
close.Font = Enum.Font.GothamBold
close.Parent = main

Instance.new("UICorner", close).CornerRadius = UDim.new(0, 8)

close.MouseButton1Click:Connect(function()
	screenGui:Destroy()
end)

local scanButton = Instance.new("TextButton")
scanButton.Size = UDim2.new(1, -24, 0, 38)
scanButton.Position = UDim2.new(0, 12, 0, 48)
scanButton.BackgroundColor3 = Color3.fromRGB(60, 90, 180)
scanButton.Text = "scan / resolver tabuleiro"
scanButton.TextColor3 = Color3.fromRGB(255, 255, 255)
scanButton.TextSize = 16
scanButton.Font = Enum.Font.GothamBold
scanButton.Parent = main

Instance.new("UICorner", scanButton).CornerRadius = UDim.new(0, 8)

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -24, 0, 28)
status.Position = UDim2.new(0, 12, 0, 92)
status.BackgroundTransparency = 1
status.Text = "chegue perto do tabuleiro e aperte scan"
status.TextColor3 = Color3.fromRGB(220, 220, 220)
status.TextSize = 13
status.Font = Enum.Font.Gotham
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = main

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -24, 1, -135)
scroll.Position = UDim2.new(0, 12, 0, 125)
scroll.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 6
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.Parent = main

Instance.new("UICorner", scroll).CornerRadius = UDim.new(0, 10)

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = scroll

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 8)
padding.PaddingBottom = UDim.new(0, 8)
padding.PaddingLeft = UDim.new(0, 8)
padding.PaddingRight = UDim.new(0, 8)
padding.Parent = scroll

local function clearScroll()
	for _, v in ipairs(scroll:GetChildren()) do
		if v:IsA("TextLabel") then
			v:Destroy()
		end
	end
end

local function addLine(text, color)
	local item = Instance.new("TextLabel")
	item.Size = UDim2.new(1, -10, 0, 32)
	item.BackgroundColor3 = Color3.fromRGB(48, 48, 48)
	item.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	item.TextSize = 14
	item.Font = Enum.Font.Gotham
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.Text = "  " .. text
	item.Parent = scroll

	Instance.new("UICorner", item).CornerRadius = UDim.new(0, 8)

	task.defer(function()
		scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
	end)
end

local function isDigitText(txt)
	txt = tostring(txt or "")
	txt = txt:gsub("%s+", "")
	return txt:match("^[1-9]$") ~= nil
end

local function getGuiCenter(obj)
	local ok, pos, size = pcall(function()
		return obj.AbsolutePosition, obj.AbsoluteSize
	end)

	if not ok or not pos or not size then
		return nil
	end

	if size.X <= 0 or size.Y <= 0 then
		return nil
	end

	return Vector2.new(pos.X + size.X / 2, pos.Y + size.Y / 2)
end

local function collectNumbers()
	local nums = {}

	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
			if isDigitText(obj.Text) then
				local center = getGuiCenter(obj)

				if center then
					table.insert(nums, {
						value = tonumber(obj.Text:gsub("%s+", "")),
						x = center.X,
						y = center.Y,
						obj = obj
					})
				end
			end
		end
	end

	return nums
end

local function buildGridFromNumbers(nums)
	local minX, maxX = math.huge, -math.huge
	local minY, maxY = math.huge, -math.huge

	for _, n in ipairs(nums) do
		minX = math.min(minX, n.x)
		maxX = math.max(maxX, n.x)
		minY = math.min(minY, n.y)
		maxY = math.max(maxY, n.y)
	end

	local width = maxX - minX
	local height = maxY - minY

	local padX = width / 8 / 2
	local padY = height / 8 / 2

	minX -= padX
	maxX += padX
	minY -= padY
	maxY += padY

	width = maxX - minX
	height = maxY - minY

	local grid = {}

	for r = 1, 9 do
		grid[r] = {}
		for c = 1, 9 do
			grid[r][c] = 0
		end
	end

	for _, n in ipairs(nums) do
		local col = math.floor(((n.x - minX) / width) * 9) + 1
		local row = math.floor(((n.y - minY) / height) * 9) + 1

		col = math.clamp(col, 1, 9)
		row = math.clamp(row, 1, 9)

		grid[row][col] = n.value
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

local function printGrid(grid)
	for r = 1, 9 do
		local line = ""

		for c = 1, 9 do
			line ..= tostring(grid[r][c]) .. " "
			if c % 3 == 0 then
				line ..= " "
			end
		end

		print(line)
	end
end

scanButton.MouseButton1Click:Connect(function()
	clearScroll()

	status.Text = "escaneando..."

	local nums = collectNumbers()

	if #nums < 10 then
		status.Text = "não achei números suficientes"
		addLine("não consegui achar o tabuleiro.", Color3.fromRGB(255, 120, 120))
		addLine("fica perto do tabuleiro e deixa ele visível na tela.")
		addLine("se ainda não pegar, o jogo não usa TextLabel nos números.")
		return
	end

	local original = buildGridFromNumbers(nums)
	local ok, err = validateGrid(original)

	if not ok then
		status.Text = "erro no scan"
		addLine(err, Color3.fromRGB(255, 120, 120))
		addLine("tenta olhar mais reto pro tabuleiro e apertar scan de novo.")
		return
	end

	local solved = copyGrid(original)

	if solve(solved) then
		status.Text = "resolvido | números achados: " .. tostring(#nums)
		addLine("solução encontrada:", Color3.fromRGB(120, 255, 120))

		local count = 0

		for r = 1, 9 do
			for c = 1, 9 do
				if original[r][c] == 0 then
					count += 1
					addLine("linha " .. r .. " | coluna " .. c .. " = " .. solved[r][c])
				end
			end
		end

		if count == 0 then
			addLine("esse tabuleiro já está completo.")
		end

		print("sudoku detectado:")
		printGrid(original)

		print("sudoku resolvido:")
		printGrid(solved)
	else
		status.Text = "não consegui resolver"
		addLine("não consegui resolver esse tabuleiro.", Color3.fromRGB(255, 120, 120))
		addLine("provavelmente o scan pegou alguma posição errada.")
		addLine("tenta ficar de frente pro tabuleiro e escanear de novo.")
	end
end)
