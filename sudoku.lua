-- sudoku solver com gui roblox / luau
-- use 0 para casas vazias

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local grid = {
	{5,3,0, 0,7,0, 0,0,0},
	{6,0,0, 1,9,5, 0,0,0},
	{0,9,8, 0,0,0, 0,6,0},

	{8,0,0, 0,6,0, 0,0,3},
	{4,0,0, 8,0,3, 0,0,1},
	{7,0,0, 0,2,0, 0,0,6},

	{0,6,0, 0,0,0, 2,8,0},
	{0,0,0, 4,1,9, 0,0,5},
	{0,0,0, 0,8,0, 0,7,9}
}

local original = {}

for r = 1, 9 do
	original[r] = {}
	for c = 1, 9 do
		original[r][c] = grid[r][c]
	end
end

local function podeColocar(num, row, col)
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

local function acharVazio()
	for r = 1, 9 do
		for c = 1, 9 do
			if grid[r][c] == 0 then
				return r, c
			end
		end
	end

	return nil, nil
end

local function resolver()
	local row, col = acharVazio()

	if not row then
		return true
	end

	for num = 1, 9 do
		if podeColocar(num, row, col) then
			grid[row][col] = num

			if resolver() then
				return true
			end

			grid[row][col] = 0
		end
	end

	return false
end

local function criarGui()
	local old = PlayerGui:FindFirstChild("SudokuSolverGui")
	if old then
		old:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SudokuSolverGui"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = PlayerGui

	local main = Instance.new("Frame")
	main.Name = "Main"
	main.Size = UDim2.new(0, 340, 0, 430)
	main.Position = UDim2.new(0.5, -170, 0.5, -215)
	main.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	main.BorderSizePixel = 0
	main.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = main

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -45, 0, 45)
	title.Position = UDim2.new(0, 10, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "sudoku solver"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 22
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = main

	local close = Instance.new("TextButton")
	close.Size = UDim2.new(0, 35, 0, 35)
	close.Position = UDim2.new(1, -40, 0, 5)
	close.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
	close.Text = "X"
	close.TextColor3 = Color3.fromRGB(255, 255, 255)
	close.TextSize = 18
	close.Font = Enum.Font.GothamBold
	close.Parent = main

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = close

	close.MouseButton1Click:Connect(function()
		screenGui:Destroy()
	end)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -20, 1, -60)
	scroll.Position = UDim2.new(0, 10, 0, 50)
	scroll.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.Parent = main

	local scrollCorner = Instance.new("UICorner")
	scrollCorner.CornerRadius = UDim.new(0, 10)
	scrollCorner.Parent = scroll

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

	local count = 0

	for r = 1, 9 do
		for c = 1, 9 do
			if original[r][c] == 0 then
				count += 1

				local item = Instance.new("TextLabel")
				item.Size = UDim2.new(1, -10, 0, 34)
				item.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
				item.TextColor3 = Color3.fromRGB(255, 255, 255)
				item.TextSize = 16
				item.Font = Enum.Font.Gotham
				item.TextXAlignment = Enum.TextXAlignment.Left
				item.Text = "  linha " .. r .. " | coluna " .. c .. " | número " .. grid[r][c]
				item.Parent = scroll

				local itemCorner = Instance.new("UICorner")
				itemCorner.CornerRadius = UDim.new(0, 8)
				itemCorner.Parent = item
			end
		end
	end

	scroll.CanvasSize = UDim2.new(0, 0, 0, count * 40 + 20)

	if count == 0 then
		local item = Instance.new("TextLabel")
		item.Size = UDim2.new(1, -10, 0, 40)
		item.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		item.TextColor3 = Color3.fromRGB(255, 255, 255)
		item.TextSize = 16
		item.Font = Enum.Font.Gotham
		item.Text = "nenhuma casa vazia encontrada"
		item.Parent = scroll

		local itemCorner = Instance.new("UICorner")
		itemCorner.CornerRadius = UDim.new(0, 8)
		itemCorner.Parent = item
	end
end

if resolver() then
	criarGui()
else
	warn("esse sudoku não tem solução ou foi preenchido errado.")
end
