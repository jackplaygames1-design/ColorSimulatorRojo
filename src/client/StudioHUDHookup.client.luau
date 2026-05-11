-- Disabled: no PlayerGui UI should be created at runtime.
if true then
	return
end

-- Hooks the handmade Studio HUD buttons directly to the editable Studio window Frames.
-- This intentionally does NOT create a new ScreenGui or clone legacy runtime UI.
-- Expected editable path at play time:
-- PlayerGui > ScreenGui/ColorSimulatorUI > MainHUD > ModalWindows > Windows

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local WARNED = {}
local connectedButtons = setmetatable({}, { __mode = "k" })
local buttonScales = setmetatable({}, { __mode = "k" })
local lastActivatedAt = setmetatable({}, { __mode = "k" })
local populatedWindows = setmetatable({}, { __mode = "k" })

local BUTTON_TO_WINDOW = {
	InventoryButton = "InventoryWindow",
	ItemsButton = "InventoryWindow",
	ShopButton = "ShopWindow",
	GamepassButton = "ShopWindow",
	WorldButton = "WorldsWindow",
	WorldsButton = "WorldsWindow",
	UpgradeButton = "UpgradesWindow",
	UpgradesButton = "UpgradesWindow",
	RankButton = "RanksWindow",
	RanksButton = "RanksWindow",
	TradeButton = "TradesWindow",
	TradesButton = "TradesWindow",
	CodesButton = "CodesWindow",
}

local OPTIONAL_ALIASES = {
	TradesWindow = { "TradeWindow" },
	RanksWindow = { "RankWindow" },
	WorldsWindow = { "WorldWindow" },
}

local function warnOnce(key, message)
	if WARNED[key] then
		return
	end
	WARNED[key] = true
	warn(message)
end

local function getMainHuds()
	local huds = {}
	local seen = {}
	for _, descendant in ipairs(playerGui:GetDescendants()) do
		if descendant.Name == "MainHUD" and descendant:IsA("GuiObject") and not seen[descendant] then
			seen[descendant] = true
			table.insert(huds, descendant)
		end
	end
	return huds
end

local function getBestMainHud()
	local preferredScreen = playerGui:FindFirstChild("ScreenGui")
	local preferredHud = preferredScreen and preferredScreen:FindFirstChild("MainHUD")
	if preferredHud and preferredHud:IsA("GuiObject") then
		return preferredHud
	end

	local colorRoot = playerGui:FindFirstChild("ColorSimulatorUI")
	local colorHud = colorRoot and colorRoot:FindFirstChild("MainHUD")
	if colorHud and colorHud:IsA("GuiObject") then
		return colorHud
	end

	return getMainHuds()[1]
end

local function getWindowsFolder(mainHud)
	if not mainHud then
		return nil
	end
	local modalWindows = mainHud:FindFirstChild("ModalWindows")
	local windows = modalWindows and modalWindows:FindFirstChild("Windows")
	if windows then
		return windows
	end
	return mainHud:FindFirstChild("Windows", true)
end

local function getDimBackground(mainHud)
	if not mainHud then
		return nil
	end
	local dim = mainHud:FindFirstChild("DimBackground")
	if dim and dim:IsA("GuiObject") then
		return dim
	end
	return nil
end

local function getWindow(mainHud, wantedName)
	local windows = getWindowsFolder(mainHud)
	if not windows then
		return nil
	end

	local direct = windows:FindFirstChild(wantedName)
	if direct and direct:IsA("GuiObject") then
		return direct
	end

	for _, alias in ipairs(OPTIONAL_ALIASES[wantedName] or {}) do
		local found = windows:FindFirstChild(alias)
		if found and found:IsA("GuiObject") then
			return found
		end
	end

	return nil
end

local function getAllWindows(mainHud)
	local windowsFolder = getWindowsFolder(mainHud)
	local windows = {}
	if not windowsFolder then
		return windows
	end
	for _, child in ipairs(windowsFolder:GetChildren()) do
		if child:IsA("GuiObject") and child.Name:match("Window$") then
			table.insert(windows, child)
		end
	end
	return windows
end

local function findContent(window)
	local content = window:FindFirstChild("Content")
	if content and content:IsA("GuiObject") then
		return content
	end
	return window
end

local function clearAutoContent(content)
	local folder = content:FindFirstChild("AutoFunctionalContent")
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "AutoFunctionalContent"
	folder.Parent = content
	return folder
end

local function makeCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 12)
	corner.Parent = parent
	return corner
end

local function makeStroke(parent, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(35, 38, 45)
	stroke.Thickness = thickness or 2
	stroke.Parent = parent
	return stroke
end

local function makeFrame(parent, name, pos, size, color)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Position = pos
	frame.Size = size
	frame.BackgroundColor3 = color or Color3.fromRGB(255, 255, 255)
	frame.BorderSizePixel = 0
	frame.Parent = parent
	makeCorner(frame, 14)
	makeStroke(frame, 2)
	return frame
end

local function makeText(parent, name, text, pos, size, textSize)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = pos
	label.Size = size
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Text = text
	label.TextColor3 = Color3.fromRGB(38, 36, 52)
	label.TextWrapped = true
	label.TextScaled = false
	label.TextSize = textSize or 18
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent
	return label
end

local function makeButton(parent, name, text, pos, size, color)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Position = pos
	button.Size = size
	button.BackgroundColor3 = color or Color3.fromRGB(84, 225, 112)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBlack
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextScaled = true
	button.AutoButtonColor = true
	button.Parent = parent
	makeCorner(button, 12)
	makeStroke(button, 2)
	return button
end

local function getRemote(name)
	local events = ReplicatedStorage:FindFirstChild("Events")
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	return (events and events:FindFirstChild(name)) or (remotes and remotes:FindFirstChild(name)) or ReplicatedStorage:FindFirstChild(name)
end

local function fireRemote(name, ...)
	local remote = getRemote(name)
	if remote and remote:IsA("RemoteEvent") then
		remote:FireServer(...)
		return true
	end
	warnOnce("missing-remote-" .. name, "StudioHUDHookup: remote '" .. name .. "' is not hooked yet.")
	return false
end

local function populateInventory(window)
	local content = findContent(window)
	local folder = clearAutoContent(content)

	local grid = makeFrame(folder, "InventoryGrid", UDim2.fromOffset(12, 12), UDim2.new(0.62, -20, 1, -24), Color3.fromRGB(246, 249, 255))
	local details = makeFrame(folder, "DetailsPanel", UDim2.new(0.64, 0, 0, 12), UDim2.new(0.36, -12, 1, -24), Color3.fromRGB(239, 246, 255))

	local nameLabel = makeText(details, "SelectedName", "Rainbow Color", UDim2.fromOffset(14, 12), UDim2.new(1, -28, 0, 34), 22)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	local stats = makeText(details, "Stats", "Power: 25\nRarity: Rare\nMutation: Rainbow\nEquipped: No", UDim2.fromOffset(18, 54), UDim2.new(1, -36, 0, 118), 16)
	stats.TextYAlignment = Enum.TextYAlignment.Top

	local items = {
		{ name = "Rainbow Color", power = 25, rarity = "Rare", mutation = "Rainbow" },
		{ name = "Red Color", power = 8, rarity = "Common", mutation = "None" },
		{ name = "Orange Color", power = 14, rarity = "Uncommon", mutation = "Glow" },
		{ name = "Pipe Color", power = 18, rarity = "Uncommon", mutation = "Drip" },
		{ name = "Brush", power = 5, rarity = "Starter", mutation = "None" },
		{ name = "Gem Color", power = 20, rarity = "Rare", mutation = "Sparkle" },
	}

	for index, item in ipairs(items) do
		local x = ((index - 1) % 3) * 116 + 16
		local y = math.floor((index - 1) / 3) * 116 + 16
		local slot = makeButton(grid, "Slot" .. index, item.name, UDim2.fromOffset(x, y), UDim2.fromOffset(104, 104), Color3.fromRGB(225, 244, 255))
		slot.TextColor3 = Color3.fromRGB(38, 36, 52)
		slot.Activated:Connect(function()
			nameLabel.Text = item.name
			stats.Text = "Power: " .. item.power .. "\nRarity: " .. item.rarity .. "\nMutation: " .. item.mutation .. "\nEquipped: No"
		end)
	end

	makeButton(details, "EquipButton", "EQUIP", UDim2.new(0, 14, 1, -132), UDim2.new(1, -28, 0, 34), Color3.fromRGB(84, 225, 112)).Activated:Connect(function()
		fireRemote("EquipPet", nameLabel.Text)
	end)
	makeButton(details, "LockButton", "LOCK", UDim2.new(0, 14, 1, -90), UDim2.new(1, -28, 0, 34), Color3.fromRGB(88, 174, 255)).Activated:Connect(function()
		fireRemote("LockPet", nameLabel.Text)
	end)
	makeButton(details, "DeleteButton", "DELETE", UDim2.new(0, 14, 1, -48), UDim2.new(1, -28, 0, 34), Color3.fromRGB(220, 46, 58)).Activated:Connect(function()
		fireRemote("DeletePet", nameLabel.Text)
	end)
end

local function populateCardWindow(window, cards, actionText, actionCallback)
	local content = findContent(window)
	local folder = clearAutoContent(content)
	for index, cardData in ipairs(cards) do
		local x = ((index - 1) % 3) * 238 + 14
		local y = math.floor((index - 1) / 3) * 132 + 14
		local card = makeFrame(folder, cardData.key .. "Card", UDim2.fromOffset(x, y), UDim2.fromOffset(222, 118), Color3.fromRGB(255, 255, 255))
		makeText(card, "Name", cardData.name, UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 28), 17)
		makeText(card, "Description", cardData.description or "Placeholder card.", UDim2.fromOffset(12, 36), UDim2.new(1, -24, 0, 38), 12)
		makeText(card, "Price", cardData.price or "", UDim2.fromOffset(12, 76), UDim2.fromOffset(90, 28), 13)
		makeButton(card, "ActionButton", actionText or "USE", UDim2.new(1, -104, 1, -42), UDim2.fromOffset(90, 32), cardData.color or Color3.fromRGB(84, 225, 112)).Activated:Connect(function()
			actionCallback(cardData)
		end)
	end
end

local function populateShop(window)
	populateCardWindow(window, {
		{ key = "VIP", name = "VIP Pass", description = "Better rewards placeholder.", price = "R$ ?" },
		{ key = "Luck", name = "Luck Boost", description = "Boosts color hatch luck.", price = "R$ ?" },
		{ key = "Coins", name = "Coin Pack", description = "Coins/Gems product slot.", price = "R$ ?" },
	}, "BUY", function(card)
		warn("Shop purchase not hooked yet: " .. card.name)
	end)
end

local function populateWorlds(window)
	populateCardWindow(window, {
		{ key = "Spawn", name = "Spawn World", description = "Main color world.", price = "Unlocked" },
		{ key = "Red", name = "Red Wastelands", description = "Tutorial red zone.", price = "Unlocked" },
		{ key = "Pipes", name = "Inside the Pipes", description = "Mutation unlock zone.", price = "Locked" },
		{ key = "Orange", name = "Orange Sector", description = "Current ready sector.", price = "Unlocked" },
	}, "GO", function(card)
		if card.price == "Locked" then
			warn(card.name .. " is locked.")
			return
		end
		fireRemote("RequestTravelToSector", card.key)
	end)
end

local function populateUpgrades(window)
	populateCardWindow(window, {
		{ key = "BrushPower", name = "Brush Power", description = "Break colors faster.", price = "Gems" },
		{ key = "WalkSpeed", name = "Walk Speed", description = "Move around quicker.", price = "Gems" },
		{ key = "ColorLuck", name = "Color Luck", description = "Better hatch chances.", price = "Gems" },
		{ key = "GemBoost", name = "Gem Boost", description = "More gem rewards.", price = "Gems" },
	}, "UPGRADE", function(card)
		fireRemote("PurchaseUpgrade", card.key)
	end)
end

local function populateRanks(window)
	populateCardWindow(window, {
		{ key = "Beginner", name = "Beginner", description = "Starting rank.", price = "Free" },
		{ key = "Painter", name = "Painter", description = "Requires early progress.", price = "Coins" },
		{ key = "Collector", name = "Color Collector", description = "Requires more colors.", price = "Coins" },
		{ key = "Master", name = "Master Artist", description = "Late-game placeholder.", price = "Coins" },
	}, "RANK UP", function(card)
		warn("Rank system not hooked yet: " .. card.name)
	end)
end

local function populateTrades(window)
	populateCardWindow(window, {
		{ key = "PlayerList", name = "Player List", description = "Select nearby players here.", price = "Placeholder" },
		{ key = "Selected", name = "Selected Player", description = "Trade details show here.", price = "None" },
	}, "SEND", function()
		warn("Trade system not hooked yet.")
	end)
end

local function populateCodes(window)
	local content = findContent(window)
	local folder = clearAutoContent(content)
	makeText(folder, "Info", "Enter a code below.", UDim2.fromOffset(24, 18), UDim2.new(1, -48, 0, 36), 22)

	local box = Instance.new("TextBox")
	box.Name = "CodeTextBox"
	box.Position = UDim2.fromOffset(24, 72)
	box.Size = UDim2.new(1, -48, 0, 54)
	box.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	box.BorderSizePixel = 0
	box.Font = Enum.Font.GothamBlack
	box.PlaceholderText = "TYPE CODE HERE"
	box.Text = ""
	box.TextColor3 = Color3.fromRGB(38, 36, 52)
	box.TextScaled = true
	box.Parent = folder
	makeCorner(box, 12)
	makeStroke(box, 2)

	local status = makeText(folder, "Status", "", UDim2.fromOffset(24, 188), UDim2.new(1, -48, 0, 36), 18)
	status.TextXAlignment = Enum.TextXAlignment.Center
	makeButton(folder, "RedeemButton", "REDEEM", UDim2.fromOffset(24, 138), UDim2.new(1, -48, 0, 42), Color3.fromRGB(84, 225, 112)).Activated:Connect(function()
		if box.Text == "" then
			status.Text = "Type a code first."
			return
		end
		if fireRemote("RedeemCode", box.Text) then
			status.Text = "Code sent!"
		else
			status.Text = "Codes are not ready yet."
		end
	end)
end

local POPULATORS = {
	InventoryWindow = populateInventory,
	ShopWindow = populateShop,
	WorldsWindow = populateWorlds,
	WorldWindow = populateWorlds,
	UpgradesWindow = populateUpgrades,
	RanksWindow = populateRanks,
	RankWindow = populateRanks,
	TradesWindow = populateTrades,
	TradeWindow = populateTrades,
	CodesWindow = populateCodes,
}

local function populateWindow(window)
	if not window or populatedWindows[window] then
		return
	end
	local populator = POPULATORS[window.Name]
	if populator then
		populator(window)
		populatedWindows[window] = true
	end
end

local function setWindowOpen(mainHud, targetWindow)
	for _, window in ipairs(getAllWindows(mainHud)) do
		populateWindow(window)
		window.Visible = (window == targetWindow)
	end

	local dim = getDimBackground(mainHud)
	if dim then
		dim.Visible = targetWindow ~= nil
	end
end

local function closeAll(mainHud)
	setWindowOpen(mainHud, nil)
end

local function hookCloseButtons(mainHud)
	for _, window in ipairs(getAllWindows(mainHud)) do
		local closeButton = window:FindFirstChild("CloseButton", true)
		if closeButton and closeButton:IsA("GuiButton") and not connectedButtons[closeButton] then
			connectedButtons[closeButton] = true
			closeButton.Activated:Connect(function()
				closeAll(mainHud)
			end)
		end
	end
end

local function getOrCreateScale(button)
	local scale = buttonScales[button]
	if scale and scale.Parent == button then
		return scale
	end
	scale = button:FindFirstChild("StudioHUDScale")
	if not scale or not scale:IsA("UIScale") then
		scale = Instance.new("UIScale")
		scale.Name = "StudioHUDScale"
		scale.Parent = button
	end
	scale.Scale = 1
	buttonScales[button] = scale
	return scale
end

local function tweenScale(button, value, duration)
	local scale = getOrCreateScale(button)
	TweenService:Create(scale, TweenInfo.new(duration or 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = value }):Play()
end

local function prepareButton(button)
	button.AutoButtonColor = false
	button.Active = true
	button.Selectable = true
	button.Visible = true
	for _, descendant in ipairs(button:GetDescendants()) do
		if descendant:IsA("GuiObject") and not descendant:IsA("GuiButton") then
			descendant.Active = false
			descendant.Selectable = false
		end
	end
	getOrCreateScale(button)
end

local function openWindowForButton(buttonName)
	local mainHud = getBestMainHud()
	if not mainHud then
		warnOnce("missing-mainhud", "StudioHUDHookup: MainHUD was not found.")
		return
	end

	local wantedWindow = BUTTON_TO_WINDOW[buttonName]
	local window = wantedWindow and getWindow(mainHud, wantedWindow)
	if not window then
		warnOnce("missing-window-" .. tostring(wantedWindow), "StudioHUDHookup: missing editable window " .. tostring(wantedWindow) .. ". Run StudioMenuWindowsBuilder.Build() in edit mode or create the Frame in Studio.")
		return
	end

	populateWindow(window)
	setWindowOpen(mainHud, window)
	hookCloseButtons(mainHud)
end

local function activateButton(button, buttonName)
	local now = os.clock()
	if lastActivatedAt[button] and now - lastActivatedAt[button] < 0.2 then
		return
	end
	lastActivatedAt[button] = now
	openWindowForButton(buttonName)
end

local function hookButton(button, buttonName)
	if not button or not button:IsA("GuiButton") then
		return
	end
	prepareButton(button)
	if connectedButtons[button] then
		return
	end
	connectedButtons[button] = true

	local isPressed = false
	local isHovering = false
	button.MouseEnter:Connect(function()
		if UserInputService.MouseEnabled then
			isHovering = true
			if not isPressed then
				tweenScale(button, 1.06, 0.1)
			end
		end
	end)
	button.MouseLeave:Connect(function()
		isHovering = false
		if not isPressed then
			tweenScale(button, 1, 0.1)
		end
	end)
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isPressed = true
			tweenScale(button, 0.92, 0.06)
		end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isPressed = false
			tweenScale(button, isHovering and 1.06 or 1, 0.12)
		end
	end)
	button.Activated:Connect(function()
		tweenScale(button, 0.96, 0.05)
		task.delay(0.06, function()
			if button.Parent then
				tweenScale(button, isHovering and 1.06 or 1, 0.12)
			end
		end)
		activateButton(button, buttonName)
	end)
end

local function hookMenuButton(leftButtons)
	local menuButton = leftButtons:FindFirstChild("MenuButton") or leftButtons:FindFirstChild("InventoryButton")
	if not menuButton or not menuButton:IsA("GuiButton") then
		return
	end
	if menuButton.Name ~= "MenuButton" then
		return
	end
	if connectedButtons[menuButton] then
		return
	end

	prepareButton(menuButton)
	connectedButtons[menuButton] = true
	local expanded = true
	menuButton.Activated:Connect(function()
		expanded = not expanded
		for buttonName in pairs(BUTTON_TO_WINDOW) do
			local button = leftButtons:FindFirstChild(buttonName)
			if button and button:IsA("GuiObject") then
				button.Visible = expanded
			end
		end
	end)
end

local function hookHandmadeHud()
	local mainHud = getBestMainHud()
	if not mainHud then
		return false
	end

	local screenGui = mainHud:FindFirstAncestorOfClass("ScreenGui")
	if screenGui then
		screenGui.Enabled = true
		screenGui.ResetOnSpawn = false
		screenGui.DisplayOrder = math.max(screenGui.DisplayOrder, 999)
	end
	mainHud.Visible = true

	local leftButtons = mainHud:FindFirstChild("LeftButtons") or mainHud:FindFirstChild("BottomRow")
	if leftButtons and leftButtons:IsA("GuiObject") then
		leftButtons.Visible = true
		hookMenuButton(leftButtons)
		for buttonName in pairs(BUTTON_TO_WINDOW) do
			hookButton(leftButtons:FindFirstChild(buttonName), buttonName)
		end
	else
		warnOnce("missing-buttons", "StudioHUDHookup: could not find MainHUD.LeftButtons or MainHUD.BottomRow.")
	end

	for _, window in ipairs(getAllWindows(mainHud)) do
		populateWindow(window)
		window.Visible = false
	end
	hookCloseButtons(mainHud)
	playerGui:SetAttribute("StudioMainHUDHooked", true)
	return true
end

task.defer(function()
	local startedAt = os.clock()
	while os.clock() - startedAt < 10 do
		if hookHandmadeHud() then
			return
		end
		task.wait(0.25)
	end
	warnOnce("not-found", "StudioHUDHookup: handmade MainHUD was not found in PlayerGui.")
end)

playerGui.DescendantAdded:Connect(function(descendant)
	if descendant.Name == "MainHUD" or descendant.Name == "LeftButtons" or descendant.Name == "BottomRow" or descendant.Name:match("Window$") or BUTTON_TO_WINDOW[descendant.Name] then
		task.defer(hookHandmadeHud)
	end
end)
