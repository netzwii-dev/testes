--// Caos na Cozinha - Auto ESP Chams Only + GUI estilo Sudoku/Cerber
--// Botão principal: "ESP On/Off"
--// Painel: Auto Avançar, Próximo, Reset, Chams Fill
--// Sem texto em cima dos objetos: apenas Highlight/Chams
--// Corrige arroz/panela: método de panela vai para CookStation, faca vai para ChoppingBoard.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local SCREEN_GUI_NAME = "CookCaosCerberMobileGui"

--// CONFIG PELO SCAN
local IGNORE_IDS = {
	["140157429295813"] = true, -- template/fundo do ingrediente
	["133105772499368"] = true,
	["72733766243904"] = true,
	["75742169776390"] = true,
}

-- IDs dos métodos que apareceram no seu debug.
-- Pelo print: arroz usa panela, pepino/faca usa cutting.
local COOK_METHOD_IDS = {
	["125425887763635"] = true, -- panela/pot
}

local CUT_METHOD_IDS = {
	["102782857320968"] = true,
	["123188384272883"] = true,
}

-- se aparecer método desconhecido, ele vai tentar cortar, mas nunca quando for ID da panela acima
local UNKNOWN_METHOD_GOES_TO_CUT = true

--// ESTADO
local ScreenGui = nil
local MobileButton = nil
local MobileMenuButton = nil
local MobilePanel = nil
local mobileDragHandle = nil

local mobileMenuOpen = false
local espEnabled = true
local autoAdvanceEnabled = true
local chamsFillEnabled = true

local currentHighlight = nil
local currentTarget = nil

local currentOrderKey = ""
local currentItems = {}
local currentIndex = 1
local currentStage = "GET" -- GET / CUT / COOK / PLATE
local lastHolding = false

local dragConnections = {}
local shadowRegistry = {}

--// UI HELPERS DO ESTILO SUDOKU
local function noTextStroke(obj)
	pcall(function()
		obj.TextStrokeTransparency = 1
	end)
end

local function setTargetTransparency(obj, bg, text)
	if bg ~= nil then
		obj:SetAttribute("TargetBGTransparency", bg)
	end

	if text ~= nil then
		obj:SetAttribute("TargetTextTransparency", text)
	end
end

local function getTargetBG(obj)
	local v = obj:GetAttribute("TargetBGTransparency")

	if typeof(v) == "number" then
		return v
	end

	return obj.BackgroundTransparency
end

local function getTargetText(obj)
	local v = obj:GetAttribute("TargetTextTransparency")

	if typeof(v) == "number" then
		return v
	end

	return obj.TextTransparency
end

local function registerShadow(host, shadow)
	shadowRegistry[host] = shadowRegistry[host] or {}
	table.insert(shadowRegistry[host], shadow)
end

local function setHostShadowVisible(host, visible)
	local list = shadowRegistry[host]

	if not list then
		return
	end

	for _, shadow in ipairs(list) do
		shadow.Visible = visible
		shadow.BackgroundTransparency = visible and shadow:GetAttribute("BaseTransparency") or 1
	end
end

local function addTrueRoundedShadow(parent, cornerRadius, strength, shadowColor)
	strength = strength or 1
	shadowColor = shadowColor or Color3.fromRGB(0, 0, 0)

	local layers = {
		{grow = math.floor(8 * strength), transparency = 0.82, y = 2},
		{grow = math.floor(16 * strength), transparency = 0.90, y = 4},
		{grow = math.floor(24 * strength), transparency = 0.95, y = 6},
	}

	for _, cfg in ipairs(layers) do
		local shadow = Instance.new("Frame")
		shadow.Name = "TrueShadow"
		shadow.AnchorPoint = Vector2.new(0.5, 0.5)
		shadow.Position = UDim2.new(0.5, 0, 0.5, cfg.y)
		shadow.Size = UDim2.new(1, cfg.grow, 1, cfg.grow)
		shadow.BackgroundColor3 = shadowColor
		shadow.BackgroundTransparency = cfg.transparency
		shadow.BorderSizePixel = 0
		shadow.ZIndex = math.max(parent.ZIndex - 1, 0)
		shadow.Parent = parent
		shadow:SetAttribute("BaseTransparency", cfg.transparency)

		Instance.new("UICorner", shadow).CornerRadius =
			UDim.new(0, cornerRadius + math.floor(cfg.grow / 2.1))

		registerShadow(parent, shadow)
	end
end

local function addClickAnimation(button, cornerRadius)
	if not button then
		return
	end

	local overlay = Instance.new("Frame")
	overlay.Name = "ClickOverlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.Position = UDim2.new(0, 0, 0, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	overlay.BackgroundTransparency = 1
	overlay.BorderSizePixel = 0
	overlay.ZIndex = button.ZIndex + 25
	overlay.Active = false
	overlay.Parent = button

	Instance.new("UICorner", overlay).CornerRadius = cornerRadius or UDim.new(0, 12)

	local function setAlpha(alpha)
		if not overlay or not overlay.Parent then
			return
		end

		TweenService:Create(
			overlay,
			TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{BackgroundTransparency = alpha}
		):Play()
	end

	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			setAlpha(0.82)
		end
	end)

	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			setAlpha(1)
		end
	end)

	button.Activated:Connect(function()
		setAlpha(0.82)

		task.delay(0.08, function()
			setAlpha(1)
		end)
	end)
end

local function elegantShow(root, finalSize, finalPosition, finalBgTransparency)
	if not root then
		return
	end

	root.Visible = true

	local targetSize = finalSize or root.Size
	local targetPos = finalPosition or root.Position
	local targetBg = finalBgTransparency

	if targetBg == nil then
		targetBg = getTargetBG(root)
	end

	root.Size = UDim2.new(
		targetSize.X.Scale * 0.72,
		math.floor(targetSize.X.Offset * 0.72),
		targetSize.Y.Scale * 0.72,
		math.floor(targetSize.Y.Offset * 0.72)
	)

	root.Position = targetPos
	root.BackgroundTransparency = 1
	setHostShadowVisible(root, false)

	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("Frame") or obj:IsA("TextButton") or obj:IsA("TextLabel") then
			pcall(function()
				obj.BackgroundTransparency = 1
			end)
		end

		if obj:IsA("TextButton") or obj:IsA("TextLabel") then
			pcall(function()
				obj.TextTransparency = 1
			end)
		end

		if obj:IsA("UIStroke") then
			pcall(function()
				obj.Transparency = 1
			end)
		end
	end

	TweenService:Create(root, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Size = targetSize,
		Position = targetPos,
		BackgroundTransparency = targetBg
	}):Play()

	task.delay(0.03, function()
		if not root or not root.Parent then
			return
		end

		setHostShadowVisible(root, true)

		for _, obj in ipairs(root:GetDescendants()) do
			if obj:IsA("Frame") or obj:IsA("TextButton") or obj:IsA("TextLabel") then
				local goal = {}

				if obj:IsA("Frame") or obj:IsA("TextButton") then
					goal.BackgroundTransparency = getTargetBG(obj)
				end

				if obj:IsA("TextButton") or obj:IsA("TextLabel") then
					goal.TextTransparency = getTargetText(obj)
				end

				TweenService:Create(obj, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
			elseif obj:IsA("UIStroke") then
				TweenService:Create(obj, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Transparency = 0
				}):Play()
			end
		end
	end)
end

local function elegantHide(root, onDone)
	if not root then
		if onDone then
			onDone()
		end

		return
	end

	local currentSize = root.Size
	local currentPos = root.Position
	local shrinkSize = UDim2.new(
		currentSize.X.Scale * 0.965,
		math.floor(currentSize.X.Offset * 0.965),
		currentSize.Y.Scale * 0.965,
		math.floor(currentSize.Y.Offset * 0.965)
	)

	local liftPos = UDim2.new(
		currentPos.X.Scale,
		currentPos.X.Offset,
		currentPos.Y.Scale,
		currentPos.Y.Offset + 4
	)

	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("Frame") or obj:IsA("TextButton") or obj:IsA("TextLabel") then
			local goal = {}

			if obj:IsA("Frame") or obj:IsA("TextButton") then
				goal.BackgroundTransparency = 1
			end

			if obj:IsA("TextButton") or obj:IsA("TextLabel") then
				goal.TextTransparency = 1
			end

			TweenService:Create(
				obj,
				TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
				goal
			):Play()
		elseif obj:IsA("UIStroke") then
			TweenService:Create(
				obj,
				TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
				{Transparency = 1}
			):Play()
		end
	end

	setHostShadowVisible(root, false)

	local tween = TweenService:Create(
		root,
		TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
		{
			Size = shrinkSize,
			Position = liftPos,
			BackgroundTransparency = 1
		}
	)

	tween:Play()
	tween.Completed:Connect(function()
		if root and root.Parent then
			root.Visible = false
			root.Size = currentSize
			root.Position = currentPos
		end

		if onDone then
			onDone()
		end
	end)
end

local function canUseMobileTap(obj)
	local lastDragTime = obj:GetAttribute("LastDragTime")

	if typeof(lastDragTime) == "number" then
		return (tick() - lastDragTime) > 0.12
	end

	return true
end

local function clearDragConnections()
	for _, c in ipairs(dragConnections) do
		pcall(function()
			c:Disconnect()
		end)
	end

	table.clear(dragConnections)
end

local function bindFreeDrag(handle, target, onMove, holdTime)
	local activeInput = nil
	local dragStart = nil
	local startPos = nil
	local holdSatisfied = false
	local holdCanceled = false
	local holdId = 0

	holdTime = holdTime or 0

	table.insert(dragConnections, handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			activeInput = input
			dragStart = input.Position
			startPos = target.Position
			holdSatisfied = false
			holdCanceled = false
			holdId += 1

			local myHoldId = holdId

			if holdTime <= 0 then
				holdSatisfied = true
			else
				task.delay(holdTime, function()
					if activeInput == input and not holdCanceled and holdId == myHoldId then
						holdSatisfied = true
						handle:SetAttribute("LastDragTime", tick())
					end
				end)
			end
		end
	end))

	table.insert(dragConnections, UserInputService.InputChanged:Connect(function(input)
		if input == activeInput and dragStart and startPos then
			local delta = input.Position - dragStart

			if not holdSatisfied then
				if delta.Magnitude >= 8 then
					holdCanceled = true
				end

				return
			end

			if delta.Magnitude >= 6 then
				handle:SetAttribute("LastDragTime", tick())
			end

			target.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)

			if onMove then
				onMove(delta)
			end
		end
	end))

	table.insert(dragConnections, UserInputService.InputEnded:Connect(function(input)
		if input == activeInput then
			activeInput = nil
			dragStart = nil
			startPos = nil
			holdSatisfied = false
			holdCanceled = false
			holdId += 1
		end
	end))
end

local function bindRowPress(button, callback)
	local activeInput = nil
	local startPos = nil
	local moved = false
	local lastTap = 0

	button.Active = true
	button.Selectable = false
	button.AutoButtonColor = false

	local function fire()
		local now = tick()

		if now - lastTap < 0.08 then
			return
		end

		lastTap = now
		callback()
	end

	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			activeInput = input
			startPos = input.Position
			moved = false
		end
	end)

	button.InputChanged:Connect(function(input)
		if input == activeInput and startPos then
			local delta = input.Position - startPos

			if delta.Magnitude > 8 then
				moved = true
			end
		end
	end)

	button.InputEnded:Connect(function(input)
		if input == activeInput then
			local wasMoved = moved
			activeInput = nil
			startPos = nil
			moved = false

			if not wasMoved and canUseMobileTap(button) then
				fire()
			end
		end
	end)

	if button:IsA("GuiButton") then
		button.Activated:Connect(function()
			if canUseMobileTap(button) then
				fire()
			end
		end)
	end
end

local function updateSwitchVisual(switchFrame, knob, enabled)
	if not switchFrame or not knob then
		return
	end

	local offPos = UDim2.new(0, 3, 0.5, -13)
	local onPos = UDim2.new(1, -29, 0.5, -13)

	TweenService:Create(switchFrame, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundColor3 = enabled and Color3.fromRGB(190,190,190) or Color3.fromRGB(20,20,24)
	}):Play()

	TweenService:Create(knob, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = enabled and onPos or offPos,
		BackgroundColor3 = enabled and Color3.fromRGB(255,255,255) or Color3.fromRGB(0,0,0)
	}):Play()
end

local function createSwitchRow(parent, yOffset, labelText)
	local row = Instance.new("TextButton")
	row.Size = UDim2.new(1, -14, 0, 40)
	row.Position = UDim2.new(0, 7, 0, yOffset)
	row.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	row.AutoButtonColor = false
	row.Text = ""
	row.BorderSizePixel = 0
	row.Parent = parent
	row.ZIndex = 5
	row.Active = true
	row.Selectable = false
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 12)
	setTargetTransparency(row, 0, 1)
	addClickAnimation(row, UDim.new(0, 12))

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(0, 130, 1, 0)
	label.Position = UDim2.new(0, 12, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = labelText
	label.TextColor3 = Color3.fromRGB(255,255,255)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 15
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = row
	label.ZIndex = 6
	label.Active = false
	noTextStroke(label)
	setTargetTransparency(label, 1, 0)

	local switch = Instance.new("Frame")
	switch.Size = UDim2.new(0, 54, 0, 28)
	switch.Position = UDim2.new(1, -94, 0.5, -14)
	switch.BackgroundColor3 = Color3.fromRGB(20,20,24)
	switch.BorderSizePixel = 0
	switch.Parent = row
	switch.ZIndex = 6
	switch.Active = false
	Instance.new("UICorner", switch).CornerRadius = UDim.new(1, 0)
	setTargetTransparency(switch, 0, nil)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 26, 0, 26)
	knob.Position = UDim2.new(0, 3, 0.5, -13)
	knob.BackgroundColor3 = Color3.fromRGB(0,0,0)
	knob.BorderSizePixel = 0
	knob.Parent = switch
	knob.ZIndex = 7
	knob.Active = false
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
	setTargetTransparency(knob, 0, nil)

	local switchHitbox = Instance.new("TextButton")
	switchHitbox.Name = "SwitchHitbox"
	switchHitbox.Size = UDim2.new(0, 68, 0, 38)
	switchHitbox.Position = UDim2.new(1, -101, 0.5, -19)
	switchHitbox.BackgroundTransparency = 1
	switchHitbox.Text = ""
	switchHitbox.AutoButtonColor = false
	switchHitbox.BorderSizePixel = 0
	switchHitbox.ZIndex = 20
	switchHitbox.Parent = row
	switchHitbox.Active = true
	switchHitbox.Selectable = false

	return row, switch, knob, switchHitbox
end

local function createSimpleRow(parent, yOffset, labelText)
	local row = Instance.new("TextButton")
	row.Size = UDim2.new(1, -14, 0, 40)
	row.Position = UDim2.new(0, 7, 0, yOffset)
	row.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	row.AutoButtonColor = false
	row.Text = ""
	row.BorderSizePixel = 0
	row.Parent = parent
	row.ZIndex = 5
	row.Active = true
	row.Selectable = false
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 12)
	setTargetTransparency(row, 0, 1)
	addClickAnimation(row, UDim.new(0, 12))

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, -24, 1, 0)
	label.Position = UDim2.new(0, 12, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = labelText
	label.TextColor3 = Color3.fromRGB(255,255,255)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.Parent = row
	label.ZIndex = 6
	label.Active = false
	noTextStroke(label)
	setTargetTransparency(label, 1, 0)

	return row
end

--// GAME HELPERS
local function normAsset(x)
	x = tostring(x or "")
	local id = x:match("rbxassetid://(%d+)") or x:match("id=(%d+)")
	return id
end

local function getPath(obj)
	local ok, res = pcall(function()
		return obj:GetFullName()
	end)
	return ok and res or tostring(obj)
end

local function getChar()
	return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getHRP()
	local char = getChar()
	return char:FindFirstChild("HumanoidRootPart")
end

local function getPos(obj)
	local part

	if not obj then
		return nil
	end

	if obj:IsA("BasePart") then
		part = obj
	elseif obj:IsA("Model") then
		part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
	else
		part = obj:FindFirstAncestorWhichIsA("BasePart")
	end

	return part and part.Position or nil
end

local function getAdornee(obj)
	if not obj then
		return nil
	end

	if obj:IsA("Model") or obj:IsA("BasePart") then
		return obj
	end

	return obj:FindFirstAncestorOfClass("Model") or obj:FindFirstAncestorWhichIsA("BasePart")
end

local function destroyChams()
	if currentHighlight then
		currentHighlight:Destroy()
		currentHighlight = nil
	end

	currentTarget = nil
end

local function makeChams(obj)
	if not espEnabled then
		destroyChams()
		return
	end

	local adornee = getAdornee(obj)
	if not adornee then
		destroyChams()
		return
	end

	if currentTarget == adornee then
		return
	end

	destroyChams()
	currentTarget = adornee

	local h = Instance.new("Highlight")
	h.Name = "CookCaosChamsOnly"
	h.Adornee = adornee
	h.FillColor = Color3.fromRGB(255, 0, 0)
	h.OutlineColor = Color3.fromRGB(255, 255, 255)
	h.FillTransparency = chamsFillEnabled and 0.35 or 1
	h.OutlineTransparency = 0
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Parent = game.CoreGui

	currentHighlight = h
end

local function objHasId(obj, wantedId)
	if not wantedId then
		return false
	end

	for _, d in ipairs(obj:GetDescendants()) do
		local id

		if d:IsA("Decal") or d:IsA("Texture") then
			id = normAsset(d.Texture)
		elseif d:IsA("ImageLabel") or d:IsA("ImageButton") then
			id = normAsset(d.Image)
		elseif d:IsA("MeshPart") then
			id = normAsset(d.TextureID)
		elseif d:IsA("SpecialMesh") then
			id = normAsset(d.TextureId)
		end

		if id == wantedId then
			return true, d
		end
	end

	return false, nil
end

local function getRecipesRoot()
	local pg = LocalPlayer:FindFirstChild("PlayerGui")
	local root = pg and pg:FindFirstChild("Root")
	local hud = root and root:FindFirstChild("HUD")
	return hud and hud:FindFirstChild("Recipes")
end

local function getRecipeFrames()
	local recipes = getRecipesRoot()
	local frames = {}

	if not recipes then
		return frames
	end

	for _, child in ipairs(recipes:GetChildren()) do
		if child:IsA("GuiObject") and child.Visible and child.Name:lower():find("recipe") then
			table.insert(frames, child)
		end
	end

	return frames
end

local function getIngredientFromTemplate(template)
	local ingredientId = nil
	local methodId = nil

	local cookingMethod = template:FindFirstChild("CookingMethod", true)

	if cookingMethod and (cookingMethod:IsA("ImageLabel") or cookingMethod:IsA("ImageButton")) and cookingMethod.Visible then
		methodId = normAsset(cookingMethod.Image)
	end

	for _, d in ipairs(template:GetDescendants()) do
		if (d:IsA("ImageLabel") or d:IsA("ImageButton")) and d.Visible then
			local p = getPath(d):lower()
			local id = normAsset(d.Image)

			if id and not IGNORE_IDS[id] then
				if p:find("ingredientimagetemplate") or d.Name:lower():find("ingredientimage") then
					ingredientId = id
					break
				end
			end
		end
	end

	if ingredientId then
		return {
			id = ingredientId,
			method = methodId,
		}
	end

	return nil
end

local function getOrderItems()
	local result = {}

	for _, frame in ipairs(getRecipeFrames()) do
		local ingredientsRoot = frame:FindFirstChild("Ingredients", true)
		local addedAnyTemplate = false

		if ingredientsRoot then
			for _, template in ipairs(ingredientsRoot:GetChildren()) do
				if template:IsA("GuiObject") and template.Visible then
					local item = getIngredientFromTemplate(template)

					if item and item.id then
						addedAnyTemplate = true
						table.insert(result, item)
					end
				end
			end
		end

		-- fallback: se a receita aparecer como item único sem IngredientTemplate real
		if not addedAnyTemplate then
			local recipeImage = frame:FindFirstChild("RecipeImage", true)

			if recipeImage and recipeImage:IsA("ImageLabel") and recipeImage.Visible then
				local id = normAsset(recipeImage.Image)

				if id and not IGNORE_IDS[id] then
					table.insert(result, {
						id = id,
						method = nil,
					})
				end
			end
		end
	end

	-- remove duplicação absurda do HUD mantendo ordem.
	local clean = {}
	local seenKey = {}

	for _, item in ipairs(result) do
		local key = item.id .. "|" .. tostring(item.method)

		if not seenKey[key] then
			seenKey[key] = true
			table.insert(clean, item)
		end
	end

	return clean
end

local function orderKey(items)
	local t = {}

	for _, item in ipairs(items) do
		table.insert(t, item.id .. ":" .. tostring(item.method))
	end

	return table.concat(t, ",")
end

local function findFoodBinById(id)
	local root = workspace:FindFirstChild("Interactables") or workspace
	local foodBins = root:FindFirstChild("FoodBins") or root
	local hrp = getHRP()

	if not hrp then
		return nil
	end

	local best = nil
	local bestDist = math.huge

	for _, obj in ipairs(foodBins:GetDescendants()) do
		if obj:IsA("Model") and obj.Name:lower():find("foodbin", 1, true) then
			if objHasId(obj, id) then
				local p = getPos(obj)

				if p then
					local dist = (p - hrp.Position).Magnitude

					if dist < bestDist then
						best = obj
						bestDist = dist
					end
				end
			end
		end
	end

	return best
end

local function findNearestByNames(names)
	local root = workspace:FindFirstChild("Interactables") or workspace
	local hrp = getHRP()

	if not hrp then
		return nil
	end

	local best = nil
	local bestDist = math.huge

	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("Model") or obj:IsA("BasePart") then
			local n = obj.Name:lower()
			local pth = getPath(obj):lower()

			for _, key in ipairs(names) do
				key = key:lower()

				if n:find(key, 1, true) or pth:find(key, 1, true) then
					local p = getPos(obj)

					if p then
						local dist = (p - hrp.Position).Magnitude

						if dist < bestDist then
							best = obj
							bestDist = dist
						end
					end

					break
				end
			end
		end
	end

	return best
end

local function findCutStation()
	return findNearestByNames({"ChoppingBoard", "choppingboard", "knife"})
end

local function findCookStation()
	-- prioridade para fogão/panela, evitando ChoppingBoard.
	local root = workspace:FindFirstChild("Interactables") or workspace
	local hrp = getHRP()

	if not hrp then
		return nil
	end

	local best = nil
	local bestDist = math.huge

	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("Model") or obj:IsA("BasePart") then
			local n = obj.Name:lower()
			local pth = getPath(obj):lower()

			local looksCook =
				n:find("pot", 1, true) or
				n:find("pan", 1, true) or
				n:find("stove", 1, true) or
				n:find("cook", 1, true) or
				pth:find("pot", 1, true) or
				pth:find("pan", 1, true) or
				pth:find("stove", 1, true)

			local bad =
				pth:find("chopping", 1, true) or
				pth:find("knife", 1, true)

			if looksCook and not bad then
				local p = getPos(obj)

				if p then
					local dist = (p - hrp.Position).Magnitude

					if dist < bestDist then
						best = obj
						bestDist = dist
					end
				end
			end
		end
	end

	return best
end

local function findPlate()
	return findNearestByNames({"Plate", ".Plate", "Dish"})
end

local function methodToStage(methodId)
	if not methodId then
		return "PLATE"
	end

	if COOK_METHOD_IDS[methodId] then
		return "COOK"
	end

	if CUT_METHOD_IDS[methodId] then
		return "CUT"
	end

	if UNKNOWN_METHOD_GOES_TO_CUT then
		return "CUT"
	end

	return "PLATE"
end

local function holdingSomething()
	local char = LocalPlayer.Character

	if not char then
		return false
	end

	for _, v in ipairs(char:GetChildren()) do
		if v:IsA("Tool") then
			return true
		end
	end

	for _, v in ipairs(char:GetDescendants()) do
		local n = v.Name:lower()

		if n:find("food", 1, true)
			or n:find("ingredient", 1, true)
			or n:find("rice", 1, true)
			or n:find("seaweed", 1, true)
			or n:find("salmon", 1, true)
			or n:find("cucumber", 1, true)
			or n:find("tuna", 1, true)
			or n:find("shrimp", 1, true)
			or n:find("fish", 1, true)
			or n:find("meat", 1, true)
			or n:find("beef", 1, true)
			or n:find("chicken", 1, true) then
			return true
		end
	end

	return false
end

local function resetCookState()
	currentIndex = 1
	currentStage = "GET"
	lastHolding = false
	destroyChams()
end

local function advanceCookStage()
	local item = currentItems[currentIndex]

	if not item then
		resetCookState()
		return
	end

	if currentStage == "GET" then
		currentStage = methodToStage(item.method)
	elseif currentStage == "CUT" or currentStage == "COOK" then
		currentStage = "PLATE"
	elseif currentStage == "PLATE" then
		currentIndex += 1
		currentStage = "GET"

		if currentIndex > #currentItems then
			currentIndex = 1
		end
	end
end

local function updateCookLogic()
	local items = getOrderItems()
	local key = orderKey(items)

	if key ~= "" and key ~= currentOrderKey then
		currentOrderKey = key
		currentItems = items
		currentIndex = 1
		currentStage = "GET"
		lastHolding = false
		destroyChams()
	elseif key ~= "" then
		currentItems = items
	end

	if not espEnabled or #currentItems == 0 then
		destroyChams()
		return
	end

	if currentIndex > #currentItems then
		currentIndex = 1
		currentStage = "GET"
	end

	local item = currentItems[currentIndex]

	if autoAdvanceEnabled then
		local holding = holdingSomething()

		if holding and not lastHolding and currentStage == "GET" then
			currentStage = methodToStage(item.method)
		elseif not holding and lastHolding then
			if currentStage == "CUT" or currentStage == "COOK" then
				currentStage = "PLATE"
			elseif currentStage == "PLATE" then
				currentIndex += 1
				currentStage = "GET"

				if currentIndex > #currentItems then
					currentIndex = 1
				end
			end
		end

		lastHolding = holding
	end

	local target = nil

	if currentStage == "GET" then
		target = findFoodBinById(item.id)
	elseif currentStage == "CUT" then
		target = findCutStation()
	elseif currentStage == "COOK" then
		target = findCookStation()
	elseif currentStage == "PLATE" then
		target = findPlate()
	end

	if target then
		makeChams(target)
	else
		destroyChams()
	end
end

RunService.RenderStepped:Connect(function()
	pcall(updateCookLogic)

	if currentHighlight then
		currentHighlight.FillTransparency = chamsFillEnabled and 0.35 or 1
	end
end)

--// GUI FINAL
local function createHamburgerIcon(parent)
	parent.Text = "≡"
end

local function updatePanelButtons()
	if MobileButton then
		MobileButton.Text = espEnabled and "ESP On" or "ESP Off"
	end

	updateSwitchVisual(_G.__CookAutoSwitch, _G.__CookAutoKnob, autoAdvanceEnabled)
	updateSwitchVisual(_G.__CookFillSwitch, _G.__CookFillKnob, chamsFillEnabled)
end

local function buildMobileGui()
	local old = PlayerGui:FindFirstChild(SCREEN_GUI_NAME)

	if old then
		old:Destroy()
	end

	clearDragConnections()

	ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = SCREEN_GUI_NAME
	ScreenGui.ResetOnSpawn = false
	ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ScreenGui.Parent = PlayerGui

	MobileButton = Instance.new("TextButton")
	MobileButton.Name = "ESPButton"
	MobileButton.Size = UDim2.new(0, 140, 0, 50)
	MobileButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	MobileButton.Text = "ESP On"
	MobileButton.TextColor3 = Color3.fromRGB(255,255,255)
	MobileButton.Font = Enum.Font.GothamBold
	MobileButton.TextScaled = true
	MobileButton.AutoButtonColor = false
	MobileButton.BorderSizePixel = 0
	MobileButton.Parent = ScreenGui
	MobileButton:SetAttribute("LastDragTime", 0)
	MobileButton:SetAttribute("CustomMoved", false)
	Instance.new("UICorner", MobileButton).CornerRadius = UDim.new(0, 12)
	noTextStroke(MobileButton)
	addTrueRoundedShadow(MobileButton, 14, 1.15, Color3.fromRGB(0, 0, 0))
	setTargetTransparency(MobileButton, 0, 0)
	addClickAnimation(MobileButton, UDim.new(0, 12))

	local inset = GuiService:GetGuiInset()

	MobileMenuButton = Instance.new("TextButton")
	MobileMenuButton.Name = "CookMenuButton"
	MobileMenuButton.Size = UDim2.new(0, 54, 0, 54)
	MobileMenuButton.Position = UDim2.new(0, 86, 0, inset.Y - 60)
	MobileMenuButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	MobileMenuButton.TextColor3 = Color3.fromRGB(255,255,255)
	MobileMenuButton.Font = Enum.Font.GothamBold
	MobileMenuButton.TextSize = 22
	MobileMenuButton.AutoButtonColor = false
	MobileMenuButton.BorderSizePixel = 0
	MobileMenuButton.Parent = ScreenGui
	MobileMenuButton:SetAttribute("LastDragTime", 0)
	Instance.new("UICorner", MobileMenuButton).CornerRadius = UDim.new(1, 0)
	noTextStroke(MobileMenuButton)
	addTrueRoundedShadow(MobileMenuButton, 999, 1.05, Color3.fromRGB(0, 0, 0))
	setTargetTransparency(MobileMenuButton, 0, 0)
	createHamburgerIcon(MobileMenuButton)
	addClickAnimation(MobileMenuButton, UDim.new(1, 0))

	MobilePanel = Instance.new("Frame")
	MobilePanel.Name = "CookMobilePanel"
	MobilePanel.Size = UDim2.new(0, 232, 0, 244)
	MobilePanel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	MobilePanel.BorderSizePixel = 0
	MobilePanel.Visible = false
	MobilePanel.Parent = ScreenGui
	MobilePanel:SetAttribute("CustomMoved", false)
	Instance.new("UICorner", MobilePanel).CornerRadius = UDim.new(0, 14)
	addTrueRoundedShadow(MobilePanel, 14, 1.15, Color3.fromRGB(0, 0, 0))
	setTargetTransparency(MobilePanel, 0, nil)

	mobileDragHandle = Instance.new("Frame")
	mobileDragHandle.Name = "MobileDragHandle"
	mobileDragHandle.Size = UDim2.new(1, -16, 0, 14)
	mobileDragHandle.Position = UDim2.new(0, 7, 0, 5)
	mobileDragHandle.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
	mobileDragHandle.BorderSizePixel = 0
	mobileDragHandle.Parent = MobilePanel
	mobileDragHandle.Active = true
	Instance.new("UICorner", mobileDragHandle).CornerRadius = UDim.new(1, 0)
	setTargetTransparency(mobileDragHandle, 0, nil)

	local functionsPage = Instance.new("ScrollingFrame")
	functionsPage.Name = "MobileFunctionsPage"
	functionsPage.Size = UDim2.new(1, 0, 1, -30)
	functionsPage.Position = UDim2.new(0, 0, 0, 26)
	functionsPage.BackgroundTransparency = 1
	functionsPage.BorderSizePixel = 0
	functionsPage.ScrollBarThickness = 3
	functionsPage.ScrollingDirection = Enum.ScrollingDirection.Y
	functionsPage.CanvasSize = UDim2.new(0, 0, 0, 204)
	functionsPage.Parent = MobilePanel

	local autoRow, autoSwitch, autoKnob, autoHitbox = createSwitchRow(functionsPage, 12, "Auto avançar")
	local fillRow, fillSwitch, fillKnob, fillHitbox = createSwitchRow(functionsPage, 58, "Chams fill")
	local nextRow = createSimpleRow(functionsPage, 104, "Próximo")
	local resetRow = createSimpleRow(functionsPage, 150, "Reset")

	_G.__CookAutoSwitch = autoSwitch
	_G.__CookAutoKnob = autoKnob
	_G.__CookFillSwitch = fillSwitch
	_G.__CookFillKnob = fillKnob

	local function placeMobileButtonDefault()
		local insetNow = GuiService:GetGuiInset()

		if not MobileButton:GetAttribute("CustomMoved") then
			MobileButton.Position = UDim2.new(0, 150, 0, insetNow.Y - 58)
		end
	end

	local function placePanelToRightOfButton()
		local xOffset = MobileButton.Position.X.Offset + MobileButton.Size.X.Offset + 28
		local yOffset = MobileButton.Position.Y.Offset + 6
		MobilePanel.Position = UDim2.new(0, xOffset, 0, yOffset)
	end

	RunService.RenderStepped:Connect(function()
		placeMobileButtonDefault()

		if mobileMenuOpen and not MobilePanel:GetAttribute("CustomMoved") then
			placePanelToRightOfButton()
		end
	end)

	placeMobileButtonDefault()
	placePanelToRightOfButton()

	bindFreeDrag(MobileButton, MobileButton, function()
		MobileButton:SetAttribute("CustomMoved", true)

		if not MobilePanel:GetAttribute("CustomMoved") then
			placePanelToRightOfButton()
		end
	end, 0.5)

	bindFreeDrag(MobileMenuButton, MobileMenuButton, nil, 0.5)

	bindFreeDrag(mobileDragHandle, MobilePanel, function()
		MobilePanel:SetAttribute("CustomMoved", true)
	end, 0)

	bindRowPress(MobileButton, function()
		espEnabled = not espEnabled

		if not espEnabled then
			destroyChams()
		end

		updatePanelButtons()
	end)

	bindRowPress(MobileMenuButton, function()
		mobileMenuOpen = not mobileMenuOpen

		if mobileMenuOpen then
			if not MobilePanel:GetAttribute("CustomMoved") then
				placePanelToRightOfButton()
			end

			MobilePanel.BackgroundTransparency = 1
			MobilePanel.Size = UDim2.new(0, 224, 0, 236)
			elegantShow(MobilePanel, UDim2.new(0, 232, 0, 244), MobilePanel.Position, 0)
		else
			elegantHide(MobilePanel)
		end
	end)

	local function toggleAuto()
		autoAdvanceEnabled = not autoAdvanceEnabled
		updatePanelButtons()
	end

	local function toggleFill()
		chamsFillEnabled = not chamsFillEnabled
		updatePanelButtons()
	end

	bindRowPress(autoRow, toggleAuto)
	bindRowPress(autoHitbox, toggleAuto)
	bindRowPress(fillRow, toggleFill)
	bindRowPress(fillHitbox, toggleFill)

	bindRowPress(nextRow, function()
		advanceCookStage()
	end)

	bindRowPress(resetRow, function()
		resetCookState()
	end)

	updatePanelButtons()
	setHostShadowVisible(MobilePanel, false)
end

buildMobileGui()

LocalPlayer.CharacterAdded:Connect(function()
	task.wait(1)
	resetCookState()
end)

print("CookCaos ESP carregado.")
print("GUI estilo Sudoku/Cerber aplicada.")
print("Chams only: sem texto nos objetos.")
print("Arroz/panela corrigido via COOK_METHOD_IDS.")
