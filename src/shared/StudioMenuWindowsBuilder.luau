-- Studio-only helper for creating editable menu window shells in StarterGui.
-- Run from the Studio command bar in edit mode:
-- require(game.ReplicatedStorage.StudioMenuWindowsBuilder).Build()
-- Settings-only refresh:
-- require(game.ReplicatedStorage.StudioMenuWindowsBuilder).UpdateSettingsWindow()
-- Codes-only refresh:
-- require(game.ReplicatedStorage.StudioMenuWindowsBuilder).UpdateCodesWindow()
-- Shop-only refresh:
-- require(game.ReplicatedStorage.StudioMenuWindowsBuilder).UpdateShopWindow()
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Builder = {}
local RobuxShopConfig = require(ReplicatedStorage:WaitForChild("RobuxShopConfig"))

local OUTLINE = Color3.fromRGB(35, 38, 45)
local TEXT_DARK = Color3.fromRGB(38, 36, 52)
local TAB_INACTIVE = Color3.fromRGB(232, 238, 248)
local CYAN = Color3.fromRGB(76, 214, 224)
local GREEN = Color3.fromRGB(84, 225, 112)

local function findOrCreate(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing, false
	end
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance, true
end

local function applyCorner(instance, radius)
	local corner = instance:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 18)
	corner.Parent = instance
	return corner
end

local function applyStroke(instance, color, thickness)
	local stroke = instance:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	stroke.Color = color or OUTLINE
	stroke.Thickness = thickness or 3
	stroke.Parent = instance
	return stroke
end

local function text(parent, name, value, position, size, textSize)
	local label, created = findOrCreate(parent, "TextLabel", name)
	if created then
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.TextColor3 = TEXT_DARK
		label.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
		label.TextStrokeTransparency = 0.35
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Center
	end
	label.Text = value
	label.Position = position
	label.Size = size
	label.TextSize = textSize or 22
	return label
end

local function button(parent, name, value, position, size, color)
	local btn, created = findOrCreate(parent, "TextButton", name)
	if created then
		btn.AutoButtonColor = true
		btn.Font = Enum.Font.GothamBlack
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.TextStrokeColor3 = OUTLINE
		btn.TextStrokeTransparency = 0
	end
	btn.Text = value
	btn.Position = position
	btn.Size = size
	btn.BackgroundColor3 = color or GREEN
	btn.BorderSizePixel = 0
	applyCorner(btn, 12)
	applyStroke(btn, OUTLINE, 2)
	return btn
end

local function textBox(parent, name, placeholder, position, size)
	local existing = parent:FindFirstChild(name)
	if existing and not existing:IsA("TextBox") then
		existing.Name = name .. "Legacy"
		if existing:IsA("GuiObject") then
			existing.Visible = false
		end
		existing = nil
	end

	local box = existing or Instance.new("TextBox")
	box.Name = name
	box.ClearTextOnFocus = false
	box.Font = Enum.Font.GothamBlack
	box.PlaceholderText = placeholder
	box.PlaceholderColor3 = Color3.fromRGB(130, 138, 158)
	box.Text = ""
	box.TextColor3 = Color3.fromRGB(38, 36, 52)
	box.TextSize = 24
	box.TextXAlignment = Enum.TextXAlignment.Center
	box.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	box.BorderSizePixel = 0
	box.Position = position
	box.Size = size
	box.Parent = parent
	applyCorner(box, 16)
	applyStroke(box, Color3.fromRGB(35, 38, 45), 3)
	return box
end

local function frame(parent, name, position, size, color)
	local f, created = findOrCreate(parent, "Frame", name)
	if created then
		f.BorderSizePixel = 0
	end
	f.Position = position
	f.Size = size
	f.BackgroundColor3 = color or Color3.fromRGB(255, 255, 255)
	applyCorner(f, 18)
	applyStroke(f, Color3.fromRGB(35, 38, 45), 2)
	return f
end

local function makeTabs(window, names)
	local tabs = frame(window, "Tabs", UDim2.fromOffset(22, 68), UDim2.new(1, -44, 0, 40), Color3.fromRGB(255, 255, 255))
	tabs.BackgroundTransparency = 1
	local layout = tabs:FindFirstChildOfClass("UIListLayout") or Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = tabs

	for index, tabName in ipairs(names) do
		local tab = button(tabs, tabName .. "Tab", tabName, UDim2.fromOffset(0, 0), UDim2.fromOffset(118, 34), index == 1 and Color3.fromRGB(82, 219, 225) or Color3.fromRGB(232, 238, 248))
		tab.LayoutOrder = index
		tab.TextColor3 = index == 1 and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(38, 36, 52)
	end
	return tabs
end

local function makeWindow(windowsFolder, name, title, tabs)
	local window = frame(windowsFolder, name, UDim2.fromScale(0.5, 0.43), UDim2.fromOffset(780, 470), Color3.fromRGB(255, 255, 255))
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Visible = false
	window.ClipsDescendants = false
	applyCorner(window, 24)
	applyStroke(window, Color3.fromRGB(35, 38, 45), 4)

	text(window, "Title", title, UDim2.fromOffset(24, 14), UDim2.new(1, -112, 0, 42), 30)
	button(window, "CloseButton", "X", UDim2.new(1, -70, 0, 14), UDim2.fromOffset(52, 48), Color3.fromRGB(188, 21, 28))
	if tabs and #tabs > 0 then
		makeTabs(window, tabs)
	end

	local content = frame(window, "Content", UDim2.fromOffset(22, tabs and 122 or 82), UDim2.new(1, -44, 1, tabs and -148 or -108), Color3.fromRGB(244, 248, 252))
	content.ClipsDescendants = false
	return window, content
end

local function makeInventory(windowsFolder)
	local window, content = makeWindow(windowsFolder, "InventoryWindow", "INVENTORY", { "Colors", "Brushes", "Potions", "Items" })
	window.Size = UDim2.fromOffset(860, 560)
	window.Position = UDim2.fromScale(0.5, 0.46)
	content.Size = UDim2.new(1, -44, 1, -148)
	local tabs = window:FindFirstChild("Tabs")
	if tabs then
		local layout = tabs:FindFirstChildOfClass("UIListLayout")
		if layout then
			layout.Padding = UDim.new(0, 8)
		end
		for index, tabName in ipairs({ "Colors", "Brushes", "Potions", "Items" }) do
			local tab = tabs:FindFirstChild(tabName .. "Tab")
			if tab and tab:IsA("GuiObject") then
				tab.LayoutOrder = index
				tab.Size = UDim2.new(0.25, -8, 1, -4)
			end
		end
	end

	local grid = frame(content, "ItemGrid", UDim2.fromOffset(12, 12), UDim2.new(0.66, -20, 1, -24), Color3.fromRGB(246, 249, 255))
	local details = frame(content, "DetailsPanel", UDim2.new(0.68, 0, 0, 12), UDim2.new(0.32, -12, 1, -24), Color3.fromRGB(239, 246, 255))
	frame(details, "BigPreview", UDim2.fromOffset(16, 16), UDim2.new(1, -32, 0, 90), Color3.fromRGB(255, 255, 255))
	text(details, "SelectedName", "Select an Item", UDim2.fromOffset(16, 118), UDim2.new(1, -32, 0, 30), 20).TextXAlignment = Enum.TextXAlignment.Center
	text(details, "SelectedRarity", "", UDim2.fromOffset(16, 150), UDim2.new(1, -32, 0, 22), 14).TextXAlignment = Enum.TextXAlignment.Center
	text(details, "SelectedDescription", "Choose a card to see details.", UDim2.fromOffset(16, 178), UDim2.new(1, -32, 0, 46), 13).TextXAlignment = Enum.TextXAlignment.Left
	local stats = frame(details, "StatsBox", UDim2.fromOffset(16, 230), UDim2.new(1, -32, 0, 34), Color3.fromRGB(255, 255, 255))
	text(stats, "StatsText", "", UDim2.fromOffset(10, 6), UDim2.new(1, -20, 1, -12), 12)
	for i = 1, 12 do
		local x = ((i - 1) % 4) * 124 + 14
		local y = math.floor((i - 1) / 4) * 114 + 14
		local slot = frame(grid, "Slot" .. i, UDim2.fromOffset(x, y), UDim2.fromOffset(112, 102), Color3.fromRGB(235, 239, 246))
		local icon = frame(slot, "Icon", UDim2.fromOffset(8, 8), UDim2.new(1, -16, 0, 54), Color3.fromRGB(225, 235, 248))
		text(icon, "IconText", "IMG", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 18).TextXAlignment = Enum.TextXAlignment.Center
		text(slot, "ItemName", "Item", UDim2.new(0, 6, 1, -36), UDim2.new(1, -12, 0, 18), 12).TextXAlignment = Enum.TextXAlignment.Center
		text(slot, "ItemMeta", "", UDim2.new(0, 6, 1, -18), UDim2.new(1, -12, 0, 14), 10).TextXAlignment = Enum.TextXAlignment.Center
	end
	button(details, "EquipButton", "EQUIP", UDim2.new(0, 16, 1, -116), UDim2.new(1, -32, 0, 32), Color3.fromRGB(84, 225, 112))
	button(details, "LockButton", "LOCK", UDim2.new(0, 16, 1, -76), UDim2.new(1, -32, 0, 32), Color3.fromRGB(88, 174, 255))
	button(details, "DeleteButton", "DELETE", UDim2.new(0, 16, 1, -36), UDim2.new(1, -32, 0, 32), Color3.fromRGB(220, 46, 58))
	return window
end

local function makeCardGrid(content, names)
	for index, item in ipairs(names) do
		local x = ((index - 1) % 3) * 238 + 14
		local y = math.floor((index - 1) / 3) * 132 + 14
		local card = frame(content, item:gsub("%s+", "") .. "Card", UDim2.fromOffset(x, y), UDim2.fromOffset(222, 118), Color3.fromRGB(255, 255, 255))
		local icon = frame(card, "Icon", UDim2.fromOffset(10, 10), UDim2.fromOffset(58, 58), Color3.fromRGB(225, 244, 255))
		text(icon, "IconText", item:sub(1, 2):upper(), UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 18).TextXAlignment = Enum.TextXAlignment.Center
		text(card, "Name", item, UDim2.fromOffset(78, 8), UDim2.new(1, -88, 0, 28), 17)
		text(card, "Description", "Editable item card.", UDim2.fromOffset(78, 38), UDim2.new(1, -88, 0, 34), 12)
		text(card, "Price", "Price", UDim2.fromOffset(10, 76), UDim2.fromOffset(90, 28), 13)
		button(card, "BuyButton", "BUY", UDim2.new(1, -110, 1, -42), UDim2.fromOffset(96, 32), Color3.fromRGB(84, 225, 112))
	end
end

local function makeSettingsGrid(content)
	local cards = {
		{
			name = "MusicCard",
			icon = "MU",
			title = "Music",
			description = "Background music.",
			status = "ON",
			buttonText = "TURN OFF",
		},
		{
			name = "SFXCard",
			icon = "SF",
			title = "SFX",
			description = "Sound effects.",
			status = "ON",
			buttonText = "TURN OFF",
		},
		{
			name = "HidePetsCard",
			icon = "HI",
			title = "Hide Pets",
			description = "Pet visibility option coming soon.",
			status = "SOON",
			buttonText = "SOON",
		},
		{
			name = "LowDetailCard",
			icon = "LO",
			title = "Low Detail",
			description = "Reduce visual effects.",
			status = "OFF",
			buttonText = "TURN ON",
		},
		{
			name = "AutoDeleteCard",
			icon = "AU",
			title = "Auto Delete",
			description = "Auto-delete rules coming soon.",
			status = "SOON",
			buttonText = "SOON",
		},
		{
			name = "CodesCard",
			icon = "CO",
			title = "Codes",
			description = "Open code redemption.",
			status = "WINDOW",
			buttonText = "OPEN",
		},
	}

	for index, item in ipairs(cards) do
		local x = ((index - 1) % 3) * 238 + 14
		local y = math.floor((index - 1) / 3) * 132 + 14
		local card = frame(
			content,
			item.name,
			UDim2.fromOffset(x, y),
			UDim2.fromOffset(222, 118),
			Color3.fromRGB(255, 255, 255)
		)
		local icon = frame(
			card,
			"Icon",
			UDim2.fromOffset(10, 10),
			UDim2.fromOffset(58, 58),
			Color3.fromRGB(225, 244, 255)
		)
		text(icon, "IconText", item.icon, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 18).TextXAlignment =
			Enum.TextXAlignment.Center
		text(card, "Name", item.title, UDim2.fromOffset(78, 8), UDim2.new(1, -88, 0, 28), 17)
		text(card, "Description", item.description, UDim2.fromOffset(78, 38), UDim2.new(1, -88, 0, 34), 12)
		text(card, "Price", item.status, UDim2.fromOffset(10, 76), UDim2.fromOffset(90, 28), 13)
		button(
			card,
			"BuyButton",
			item.buttonText,
			UDim2.new(1, -110, 1, -42),
			UDim2.fromOffset(96, 32),
			Color3.fromRGB(84, 225, 112)
		)
	end
end

local function hideUnusedCodeContent(content)
	local keep = {
		CodeBox = true,
		CodePrompt = true,
		InfoPanel = true,
		InfoText = true,
		RecentRewards = true,
		RedeemButton = true,
		StatusText = true,
	}

	for _, child in ipairs(content:GetChildren()) do
		if child:IsA("GuiObject") and not keep[child.Name] then
			child.Visible = false
		end
	end
end

local function makeCodeRewardSlot(parent, index, title, body)
	local slot = frame(
		parent,
		"RewardSlot" .. tostring(index),
		UDim2.fromOffset((index - 1) * 192, 0),
		UDim2.fromOffset(176, 62),
		Color3.fromRGB(255, 255, 255)
	)
	slot.LayoutOrder = index
	slot.BackgroundTransparency = 0
	text(slot, "GiftLabel", "GIFT", UDim2.fromOffset(10, 0), UDim2.fromOffset(54, 62), 15).TextXAlignment =
		Enum.TextXAlignment.Center
	text(slot, "RewardTitle", title, UDim2.fromOffset(66, 10), UDim2.new(1, -76, 0, 22), 13)
	text(slot, "RewardBody", body, UDim2.fromOffset(66, 34), UDim2.new(1, -76, 0, 18), 11)
end

local function makeCodesContent(content)
	hideUnusedCodeContent(content)

	content.BackgroundColor3 = Color3.fromRGB(246, 249, 255)
	content.ClipsDescendants = false

	local prompt = text(
		content,
		"CodePrompt",
		"ENTER A CODE",
		UDim2.fromOffset(34, 22),
		UDim2.new(1, -68, 0, 46),
		32
	)
	prompt.TextXAlignment = Enum.TextXAlignment.Center
	prompt.TextStrokeTransparency = 0.25

	local box = textBox(content, "CodeBox", "TYPE CODE HERE", UDim2.fromOffset(54, 92), UDim2.new(1, -238, 0, 58))
	box.TextSize = 23

	local redeem = button(
		content,
		"RedeemButton",
		"REDEEM",
		UDim2.new(1, -170, 0, 92),
		UDim2.fromOffset(116, 58),
		Color3.fromRGB(82, 219, 225)
	)
	redeem.TextSize = 22

	local infoPanel = frame(
		content,
		"InfoPanel",
		UDim2.fromOffset(54, 172),
		UDim2.new(1, -108, 0, 76),
		Color3.fromRGB(234, 239, 248)
	)
	infoPanel.BackgroundTransparency = 0
	applyStroke(infoPanel, Color3.fromRGB(211, 219, 232), 2)

	local infoAccent = frame(infoPanel, "Accent", UDim2.fromOffset(18, 14), UDim2.fromOffset(7, 48), Color3.fromRGB(88, 140, 255))
	applyCorner(infoAccent, 8)
	local info = text(
		infoPanel,
		"InfoText",
		"Follow socials or join the community for exclusive codes.",
		UDim2.fromOffset(44, 12),
		UDim2.new(1, -66, 0, 26),
		15
	)
	info.TextStrokeTransparency = 1
	local status = text(
		infoPanel,
		"StatusText",
		"Try RELEASE, COLOR, or PET.",
		UDim2.fromOffset(44, 38),
		UDim2.new(1, -66, 0, 24),
		13
	)
	status.Font = Enum.Font.GothamBold
	status.TextColor3 = Color3.fromRGB(88, 96, 120)
	status.TextStrokeTransparency = 1

	local recentTitle = text(
		content,
		"RecentTitle",
		"RECENT REWARDS",
		UDim2.fromOffset(54, 266),
		UDim2.new(1, -108, 0, 28),
		18
	)
	recentTitle.TextXAlignment = Enum.TextXAlignment.Center

	local rewards = frame(
		content,
		"RecentRewards",
		UDim2.fromOffset(54, 306),
		UDim2.new(1, -108, 0, 66),
		Color3.fromRGB(246, 249, 255)
	)
	rewards.BackgroundTransparency = 1
	for _, child in ipairs(rewards:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	makeCodeRewardSlot(rewards, 1, "RELEASE", "Coins")
	makeCodeRewardSlot(rewards, 2, "COLOR", "Color")
	makeCodeRewardSlot(rewards, 3, "PET", "Starter Color")
end

local SHOP_TABS = { "Featured", "Gamepasses", "Boosts", "Currency" }

local function getGamepass(passId)
	return RobuxShopConfig.getGamepass(passId)
end

local function getProductsForCategory(categoryName)
	local products = {}
	for _, product in ipairs(RobuxShopConfig.getSortedDevProducts()) do
		if tostring(product.category or "") == categoryName then
			table.insert(products, product)
		end
	end
	return products
end

local function setGuiBase(guiObject, zIndex)
	guiObject.BorderSizePixel = 0
	guiObject.ZIndex = zIndex
	if guiObject:IsA("TextLabel") or guiObject:IsA("TextButton") or guiObject:IsA("TextBox") then
		guiObject.TextWrapped = true
	end
end

local function makeScale(parent, name)
	local scale = parent:FindFirstChild(name)
	if not scale or not scale:IsA("UIScale") then
		scale = Instance.new("UIScale")
		scale.Name = name
		scale.Parent = parent
	end
	scale.Scale = 1
	return scale
end

local function makeShopText(parent, name, value, position, size, textSize, color, zIndex)
	local label = text(parent, name, value, position, size, textSize)
	label.TextColor3 = color or TEXT_DARK
	label.TextStrokeTransparency = 1
	label.TextScaled = false
	label.ZIndex = zIndex or 1005
	return label
end

local function makeShopButton(parent, name, value, position, size, color, zIndex)
	local shopButton = button(parent, name, value, position, size, color or GREEN)
	shopButton.AutoButtonColor = false
	shopButton.TextScaled = false
	shopButton.TextSize = 15
	shopButton.TextWrapped = true
	shopButton.ZIndex = zIndex or 1006
	makeScale(shopButton, "ButtonScale")
	return shopButton
end

local function makeBadge(parent, textValue, position, size, zIndex)
	local badge = frame(parent, "Badge", position, size, Color3.fromRGB(255, 221, 84))
	badge.ZIndex = zIndex or 1006
	applyCorner(badge, 12)
	applyStroke(badge, OUTLINE, 2)
	local badgeText = makeShopText(badge, "Text", textValue, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 13, TEXT_DARK, badge.ZIndex + 1)
	badgeText.Font = Enum.Font.GothamBlack
	badgeText.TextXAlignment = Enum.TextXAlignment.Center
	badgeText.TextScaled = true
	return badge
end

local function clearGeneratedChildren(parent)
	for _, child in ipairs(parent:GetChildren()) do
		if child:GetAttribute("StudioShopGenerated") == true then
			child:Destroy()
		end
	end
end

local function clearShopPage(parent)
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("GuiObject") or child:IsA("UIGridLayout") or child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

local function clearLegacyContentChildren(content)
	local keep = {
		FeaturedPage = true,
		GamepassesPage = true,
		BoostsPage = true,
		CurrencyPage = true,
	}
	for _, child in ipairs(content:GetChildren()) do
		if
			(child:IsA("GuiObject") and not keep[child.Name])
			or child:IsA("UIGridLayout")
			or child:IsA("UIListLayout")
			or child:IsA("UIPadding")
		then
			child:Destroy()
		end
	end
end

local function prepShopWindow(shopWindow)
	shopWindow.AnchorPoint = Vector2.new(0.5, 0.5)
	shopWindow.Position = UDim2.fromScale(0.5, 0.5)
	shopWindow.Size = UDim2.fromOffset(820, 500)
	shopWindow.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	shopWindow.BorderSizePixel = 0
	shopWindow.ClipsDescendants = false
	shopWindow.ZIndex = 1000
	applyCorner(shopWindow, 24)
	applyStroke(shopWindow, OUTLINE, 4)

	local title = text(shopWindow, "Title", "ROBUX SHOP", UDim2.fromOffset(26, 16), UDim2.new(1, -120, 0, 46), 32)
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = TEXT_DARK
	title.TextStrokeTransparency = 1
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 1002

	local closeButton = shopWindow:FindFirstChild("CloseButton")
	if closeButton and closeButton:IsA("ImageButton") then
		closeButton.Position = UDim2.new(1, -72, 0, 16)
		closeButton.Size = UDim2.fromOffset(54, 54)
		closeButton.BackgroundColor3 = Color3.fromRGB(188, 21, 28)
		closeButton.BorderSizePixel = 0
		closeButton.ZIndex = 1003
		applyCorner(closeButton, 14)
		applyStroke(closeButton, OUTLINE, 2)
		local runtimeText = text(closeButton, "RuntimeText", "X", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 28)
		runtimeText.TextScaled = true
		runtimeText.TextXAlignment = Enum.TextXAlignment.Center
		runtimeText.TextColor3 = Color3.fromRGB(255, 255, 255)
		runtimeText.TextStrokeTransparency = 0
		runtimeText.TextStrokeColor3 = OUTLINE
		runtimeText.ZIndex = 1004
	else
		closeButton = button(shopWindow, "CloseButton", "X", UDim2.new(1, -72, 0, 16), UDim2.fromOffset(54, 54), Color3.fromRGB(188, 21, 28))
		closeButton.ZIndex = 1003
		closeButton.TextScaled = true
	end

	return shopWindow
end

local function makeShopTabs(shopWindow)
	local tabs = frame(shopWindow, "Tabs", UDim2.fromOffset(26, 76), UDim2.new(1, -52, 0, 48), Color3.fromRGB(255, 255, 255))
	tabs.BackgroundTransparency = 1
	tabs.ZIndex = 1002

	local oldBundles = tabs:FindFirstChild("BundlesTab")
	if oldBundles then
		oldBundles.Name = "FeaturedTab"
	end
	local oldPotions = tabs:FindFirstChild("PotionsTab")
	if oldPotions then
		oldPotions.Name = "BoostsTab"
	end

	local layout = tabs:FindFirstChildOfClass("UIListLayout") or Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = tabs

	for index, tabName in ipairs(SHOP_TABS) do
		local tab = button(tabs, tabName .. "Tab", tabName, UDim2.fromOffset(0, 0), UDim2.fromOffset(150, 38), index == 1 and CYAN or TAB_INACTIVE)
		tab.LayoutOrder = index
		tab.AutoButtonColor = false
		tab.TextScaled = false
		tab.TextSize = 20
		tab.Font = Enum.Font.GothamBlack
		tab.TextColor3 = index == 1 and Color3.fromRGB(255, 255, 255) or TEXT_DARK
		tab.ZIndex = 1003
		applyCorner(tab, 14)
		applyStroke(tab, OUTLINE, 2)
	end

	return tabs
end

local function makeShopPages(shopWindow)
	local content = frame(shopWindow, "Content", UDim2.fromOffset(26, 136), UDim2.new(1, -52, 1, -164), Color3.fromRGB(244, 248, 252))
	content.BorderSizePixel = 0
	content.ClipsDescendants = true
	content.ZIndex = 1001
	applyCorner(content, 18)
	applyStroke(content, OUTLINE, 3)
	clearLegacyContentChildren(content)

	for index, pageName in ipairs({ "FeaturedPage", "GamepassesPage", "BoostsPage", "CurrencyPage" }) do
		local page = frame(content, pageName, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), Color3.fromRGB(244, 248, 252))
		page.BackgroundTransparency = 1
		page.ZIndex = 1002
		page.Visible = index == 1
		clearShopPage(page)
	end

	return content
end

local function makeIconCircle(parent, name, iconTextValue, color, position, size, zIndex)
	local circle = frame(parent, name, position, size, color)
	circle.ZIndex = zIndex or 1004
	applyCorner(circle, 99)
	applyStroke(circle, OUTLINE, 2)
	makeScale(circle, "IconScale")

	local iconLabel = makeShopText(circle, "IconText", iconTextValue, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 26, Color3.fromRGB(255, 255, 255), circle.ZIndex + 1)
	iconLabel.Font = Enum.Font.GothamBlack
	iconLabel.TextXAlignment = Enum.TextXAlignment.Center
	iconLabel.TextScaled = true
	iconLabel.TextStrokeTransparency = 0
	iconLabel.TextStrokeColor3 = OUTLINE
	return circle
end

local function scrollingFrame(parent, name, position, size)
	local existing = parent:FindFirstChild(name)
	if existing and not existing:IsA("ScrollingFrame") then
		existing:Destroy()
		existing = nil
	end

	local scroller = existing or Instance.new("ScrollingFrame")
	scroller.Name = name
	scroller.Position = position
	scroller.Size = size
	scroller.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	scroller.BorderSizePixel = 0
	scroller.ScrollBarThickness = 6
	scroller.ScrollingDirection = Enum.ScrollingDirection.X
	scroller.CanvasPosition = Vector2.new(0, 0)
	scroller.Parent = parent
	applyCorner(scroller, 14)
	applyStroke(scroller, OUTLINE, 2)
	return scroller
end

local function makeInfinitePackTierCard(parent, tier, layoutOrder)
	local card = frame(parent, tier.id .. "Card", UDim2.fromScale(0, 0), UDim2.fromOffset(96, 118), Color3.fromRGB(255, 255, 255))
	card:SetAttribute("StudioShopGenerated", true)
	card:SetAttribute("ShopItemId", tier.id)
	card:SetAttribute("ShopItemKind", "InfinitePackTier")
	card.LayoutOrder = layoutOrder
	card.ZIndex = 1005
	makeScale(card, "CardScale")
	applyCorner(card, 12)
	applyStroke(card, OUTLINE, 2)

	local rewardBox = frame(card, "RewardBox", UDim2.fromOffset(9, 8), UDim2.fromOffset(78, 62), tier.color or CYAN)
	rewardBox.ZIndex = 1006
	applyCorner(rewardBox, 10)
	applyStroke(rewardBox, OUTLINE, 2)
	local icon = makeShopText(rewardBox, "IconText", tostring(tier.icon or "?"), UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 22, Color3.fromRGB(255, 255, 255), 1007)
	icon.Font = Enum.Font.GothamBlack
	icon.TextXAlignment = Enum.TextXAlignment.Center
	icon.TextScaled = true
	icon.TextStrokeTransparency = 0
	icon.TextStrokeColor3 = OUTLINE

	local reward = makeShopText(card, "RewardLabel", tostring(tier.rewardText or tier.displayName or ""), UDim2.fromOffset(7, 72), UDim2.fromOffset(82, 18), 10, TEXT_DARK, 1007)
	reward.Font = Enum.Font.GothamBold
	reward.TextXAlignment = Enum.TextXAlignment.Center
	reward.TextWrapped = true

	local buttonText = tier.free and "FREE" or tostring(tier.price or 0) .. " R$"
	local buy = makeShopButton(card, "BuyButton", buttonText, UDim2.fromOffset(9, 90), UDim2.fromOffset(78, 24), tier.free and GREEN or Color3.fromRGB(118, 235, 80), 1007)
	buy.TextSize = tier.free and 18 or 15
end

local function makeInfinitePackPanel(featuredPage)
	local pack = RobuxShopConfig.InfinitePack
	local tiers = RobuxShopConfig.getInfinitePackTiers and RobuxShopConfig.getInfinitePackTiers() or {}
	if not pack or #tiers == 0 then
		return
	end

	local panel = frame(featuredPage, "InfinitePackPanel", UDim2.fromOffset(16, 12), UDim2.new(1, -32, 0, 214), Color3.fromRGB(184, 246, 255))
	panel:SetAttribute("StudioShopGenerated", true)
	panel.BorderSizePixel = 0
	panel.ClipsDescendants = true
	panel.ZIndex = 1003
	applyCorner(panel, 18)
	applyStroke(panel, OUTLINE, 3)

	local rainbow = frame(panel, "RainbowBand", UDim2.new(-0.05, 0, 0, 54), UDim2.new(1.1, 0, 0, 64), Color3.fromRGB(255, 122, 188))
	rainbow:SetAttribute("StudioShopGenerated", true)
	rainbow.BackgroundTransparency = 0.38
	rainbow.Rotation = -7
	rainbow.ZIndex = 1004
	local rainbowStroke = rainbow:FindFirstChildOfClass("UIStroke")
	if rainbowStroke then
		rainbowStroke:Destroy()
	end

	local title = makeShopText(panel, "Title", tostring(pack.displayName or "THE INFINITE PACK!"), UDim2.new(0, 210, 0, 12), UDim2.new(1, -230, 0, 40), 32, TEXT_DARK, 1006)
	title.Font = Enum.Font.GothamBlack
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.TextScaled = true
	title.TextStrokeTransparency = 0
	title.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)

	local reset = makeShopText(panel, "ResetLabel", "Resets in 23:59:59", UDim2.fromOffset(18, 14), UDim2.fromOffset(190, 34), 22, TEXT_DARK, 1006)
	reset.Font = Enum.Font.GothamBlack
	reset.TextScaled = true
	reset.TextStrokeTransparency = 0
	reset.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)

	local track = scrollingFrame(panel, "TierTrack", UDim2.fromOffset(14, 62), UDim2.new(1, -28, 0, 138))
	track:SetAttribute("StudioShopGenerated", true)
	track.ZIndex = 1005
	track.CanvasSize = UDim2.fromOffset((#tiers * 134) + 60, 0)

	local list = track:FindFirstChildOfClass("UIListLayout") or Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Left
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = track

	for index, tier in ipairs(tiers) do
		makeInfinitePackTierCard(track, tier, index * 2)
		if index < #tiers then
			local arrow = makeShopText(track, "Arrow" .. tostring(index), "->", UDim2.fromScale(0, 0), UDim2.fromOffset(18, 118), 26, OUTLINE, 1007)
			arrow:SetAttribute("StudioShopGenerated", true)
			arrow.LayoutOrder = (index * 2) + 1
			arrow.TextXAlignment = Enum.TextXAlignment.Center
			arrow.TextScaled = true
		end
	end
end

local function makeInfiniteHero(featuredPage)
	local pass = getGamepass("InfinitePass")
	if not pass then
		return
	end

	local card = frame(featuredPage, "InfinitePassHeroCard", UDim2.fromOffset(16, 12), UDim2.new(1, -32, 0, 126), pass.color)
	card:SetAttribute("StudioShopGenerated", true)
	card:SetAttribute("ShopItemId", pass.id)
	card:SetAttribute("ShopItemKind", "Gamepass")
	card.BorderSizePixel = 0
	card.ClipsDescendants = true
	card.ZIndex = 1003
	makeScale(card, "CardScale")
	applyCorner(card, 20)
	applyStroke(card, Color3.fromRGB(72, 235, 255), 4)

	local glow = frame(card, "Glow", UDim2.new(-0.05, 0, -0.2, 0), UDim2.new(1.1, 0, 1.4, 0), Color3.fromRGB(72, 235, 255))
	glow.BackgroundTransparency = 0.72
	glow.ZIndex = 1004
	applyCorner(glow, 30)

	for index, circle in ipairs({
		{ "GlowCircle1", UDim2.new(0.18, 0, -0.35, 0), UDim2.fromOffset(170, 170), Color3.fromRGB(255, 255, 255) },
		{ "GlowCircle2", UDim2.new(0.58, 0, 0.45, 0), UDim2.fromOffset(130, 130), Color3.fromRGB(72, 235, 255) },
		{ "GlowCircle3", UDim2.new(0.82, 0, -0.18, 0), UDim2.fromOffset(120, 120), Color3.fromRGB(177, 141, 255) },
	}) do
		local glowCircle = frame(card, circle[1], circle[2], circle[3], circle[4])
		glowCircle:SetAttribute("StudioShopGenerated", true)
		glowCircle.BackgroundTransparency = 0.75
		glowCircle.ZIndex = 1004 + index
		applyCorner(glowCircle, 99)
	end

	local shimmer = frame(card, "ShimmerBar", UDim2.new(-0.18, 0, -0.35, 0), UDim2.new(0, 48, 1.75, 0), Color3.fromRGB(255, 255, 255))
	shimmer.Rotation = -18
	shimmer.BackgroundTransparency = 0.7
	shimmer.ZIndex = 1004
	local shimmerStroke = shimmer:FindFirstChildOfClass("UIStroke")
	if shimmerStroke then
		shimmerStroke:Destroy()
	end

	makeIconCircle(card, "IconCircle", pass.icon or "∞", Color3.fromRGB(30, 35, 70), UDim2.new(0, 18, 0.5, -42), UDim2.fromOffset(84, 84), 1005)
	local heroIcon = card:FindFirstChild("IconCircle")
	if heroIcon and heroIcon:IsA("GuiObject") then
		heroIcon.Position = UDim2.new(0, 18, 0.5, -36)
		heroIcon.Size = UDim2.fromOffset(72, 72)
	end
	local title = makeShopText(card, "Title", "INFINITE PASS", UDim2.fromOffset(104, 14), UDim2.new(0.48, 0, 0, 30), 24, Color3.fromRGB(255, 255, 255), 1006)
	title.TextScaled = true
	local description = makeShopText(card, "Description", "The ultimate permanent upgrade.", UDim2.fromOffset(104, 46), UDim2.new(0.48, 0, 0, 22), 16, Color3.fromRGB(230, 245, 255), 1006)
	description.Font = Enum.Font.GothamBold
	description.TextScaled = true
	local perks = makeShopText(card, "Perks", "∞ Infinite color capacity\n+5 equipped Colors\nDaily gems\nExclusive aura", UDim2.fromOffset(112, 84), UDim2.new(0.48, 0, 0, 60), 14, Color3.fromRGB(255, 255, 255), 1006)
	perks.TextYAlignment = Enum.TextYAlignment.Top
	perks.Position = UDim2.fromOffset(104, 70)
	perks.Size = UDim2.new(0.5, 0, 0, 48)
	perks.TextSize = 12

	makeBadge(card, pass.badge or "BEST VALUE", UDim2.new(1, -150, 0, 14), UDim2.fromOffset(130, 28), 1006)
	local price = makeShopText(card, "PriceLabel", tostring(pass.price or 999) .. " R$", UDim2.new(1, -190, 0, 50), UDim2.fromOffset(170, 30), 22, Color3.fromRGB(255, 255, 255), 1006)
	price.TextScaled = true
	price.TextXAlignment = Enum.TextXAlignment.Center
	local buy = makeShopButton(card, "BuyButton", "BUY " .. tostring(pass.price or 999) .. " R$", UDim2.new(1, -190, 1, -42), UDim2.fromOffset(170, 32), GREEN, 1007)
	buy.TextSize = 20
end

local function makeNormalGamepassCard(parent, pass, layoutOrder, compact)
	local cardSize = compact and UDim2.fromOffset(138, 64) or UDim2.fromOffset(225, 80)
	local card = frame(parent, pass.id .. "Card", UDim2.fromScale(0, 0), cardSize, Color3.fromRGB(255, 255, 255))
	card:SetAttribute("StudioShopGenerated", true)
	card:SetAttribute("ShopItemId", pass.id)
	card:SetAttribute("ShopItemKind", "Gamepass")
	card.LayoutOrder = layoutOrder
	card.ZIndex = 1003
	makeScale(card, "CardScale")
	applyCorner(card, 16)
	applyStroke(card, OUTLINE, 2)

	local iconColor = (pass.color or CYAN):Lerp(Color3.fromRGB(255, 255, 255), 0.35)
	makeIconCircle(
		card,
		"IconCircle",
		tostring(pass.icon or "?"),
		iconColor,
		compact and UDim2.fromOffset(7, 8) or UDim2.fromOffset(10, 10),
		compact and UDim2.fromOffset(42, 42) or UDim2.fromOffset(50, 50),
		1004
	)

	local title = makeShopText(
		card,
		"Title",
		tostring(pass.displayName or pass.id),
		compact and UDim2.fromOffset(54, 7) or UDim2.fromOffset(72, 8),
		compact and UDim2.new(1, -60, 0, 20) or UDim2.new(1, -82, 0, 22),
		compact and 12 or 16,
		TEXT_DARK,
		1005
	)
	title.TextScaled = false
	local description = makeShopText(card, "Description", tostring(pass.description or ""), UDim2.fromOffset(72, 30), UDim2.new(1, -82, 0, 22), 10, TEXT_DARK, 1005)
	description.Font = Enum.Font.GothamBold
	description.TextWrapped = true
	description.Visible = not compact
	local price = makeShopText(card, "PriceLabel", tostring(pass.price or 0) .. " R$", UDim2.new(0, 12, 1, -34), UDim2.fromOffset(82, 24), 16, TEXT_DARK, 1005)
	price.Visible = false
	price.TextXAlignment = Enum.TextXAlignment.Center
	local buy = makeShopButton(
		card,
		"BuyButton",
		"BUY",
		compact and UDim2.new(1, -78, 1, -24) or UDim2.new(1, -112, 1, -28),
		compact and UDim2.fromOffset(68, 18) or UDim2.fromOffset(102, 22),
		GREEN,
		1005
	)
	buy.TextSize = compact and 10 or 12
	buy:SetAttribute("DefaultText", "BUY R$ " .. tostring(pass.price or 0))
	if pass.badge and pass.badge ~= "" then
		local badge = makeBadge(
			card,
			tostring(pass.badge),
			compact and UDim2.new(0, 8, 1, -22) or UDim2.new(0, 10, 1, -28),
			compact and UDim2.fromOffset(58, 18) or UDim2.fromOffset(92, 22),
			1006
		)
		badge.BackgroundTransparency = 0.05
	end
end

local function makeSmallCards(featuredPage)
	local holder = frame(featuredPage, "SmallCards", UDim2.fromOffset(16, 238), UDim2.new(1, -32, 1, -250), Color3.fromRGB(244, 248, 252))
	holder:SetAttribute("StudioShopGenerated", true)
	holder.BackgroundTransparency = 1
	holder.ZIndex = 1002

	local grid = holder:FindFirstChildOfClass("UIGridLayout") or Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(138, 64)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.FillDirectionMaxCells = 5
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.VerticalAlignment = Enum.VerticalAlignment.Top
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = holder

	local layoutOrder = 0
	for _, passId in ipairs({ "VIP", "DoubleCoins", "LuckyHatch", "Plus3Colors", "SupportDev" }) do
		local pass = getGamepass(passId)
		if pass then
			layoutOrder += 1
			makeNormalGamepassCard(holder, pass, layoutOrder, true)
		end
	end
end

local function makeProductCard(parent, product, layoutOrder)
	local card = frame(parent, product.id .. "Card", UDim2.fromScale(0, 0), UDim2.fromOffset(225, 112), Color3.fromRGB(255, 255, 255))
	card:SetAttribute("StudioShopGenerated", true)
	card:SetAttribute("ShopItemId", product.id)
	card:SetAttribute("ShopItemKind", "Product")
	card.LayoutOrder = layoutOrder
	card.ZIndex = 1003
	makeScale(card, "CardScale")
	applyCorner(card, 16)
	applyStroke(card, OUTLINE, 2)
	local iconColor = (product.color or CYAN):Lerp(Color3.fromRGB(255, 255, 255), 0.35)
	makeIconCircle(card, "IconCircle", tostring(product.icon or "?"), iconColor, UDim2.fromOffset(12, 14), UDim2.fromOffset(58, 58), 1004)
	makeShopText(card, "Title", tostring(product.displayName or product.id), UDim2.fromOffset(80, 12), UDim2.new(1, -90, 0, 26), 18, TEXT_DARK, 1005).TextScaled = true
	makeShopText(card, "Description", tostring(product.description or ""), UDim2.fromOffset(80, 42), UDim2.new(1, -90, 0, 32), 12, TEXT_DARK, 1005)
	makeShopText(card, "PriceLabel", "COMING SOON", UDim2.new(0, 12, 1, -34), UDim2.fromOffset(96, 24), 14, TEXT_DARK, 1005).TextScaled = true
	makeShopButton(card, "BuyButton", "COMING SOON", UDim2.new(1, -124, 1, -40), UDim2.fromOffset(112, 30), Color3.fromRGB(170, 180, 205), 1005)
end

local function makeGridPage(page, holderName, items, kind)
	local holder = frame(page, holderName, UDim2.fromOffset(16, 14), UDim2.new(1, -32, 1, -28), Color3.fromRGB(244, 248, 252))
	holder:SetAttribute("StudioShopGenerated", true)
	holder.BackgroundTransparency = 1
	holder.ZIndex = 1002
	local grid = holder:FindFirstChildOfClass("UIGridLayout") or Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(225, 112)
	grid.CellPadding = UDim2.fromOffset(12, 12)
	grid.FillDirectionMaxCells = 3
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.VerticalAlignment = Enum.VerticalAlignment.Top
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = holder

	for index, item in ipairs(items) do
		if kind == "Gamepass" then
			makeNormalGamepassCard(holder, item, index)
		else
			makeProductCard(holder, item, index)
		end
	end
end

local function makeFeaturedShopContent(content)
	local featuredPage = content:FindFirstChild("FeaturedPage")
	if not featuredPage or not featuredPage:IsA("Frame") then
		return
	end
	clearGeneratedChildren(featuredPage)
	makeInfinitePackPanel(featuredPage)
	makeSmallCards(featuredPage)

	local gamepassesPage = content:FindFirstChild("GamepassesPage")
	if gamepassesPage and gamepassesPage:IsA("Frame") then
		clearGeneratedChildren(gamepassesPage)
		local passes = {}
		for _, pass in ipairs(RobuxShopConfig.getSortedGamepasses()) do
			table.insert(passes, pass)
		end
		makeGridPage(gamepassesPage, "GamepassCards", passes, "Gamepass")
	end

	local boostsPage = content:FindFirstChild("BoostsPage")
	if boostsPage and boostsPage:IsA("Frame") then
		clearGeneratedChildren(boostsPage)
		makeGridPage(boostsPage, "BoostCards", getProductsForCategory("Boosts"), "Product")
	end

	local currencyPage = content:FindFirstChild("CurrencyPage")
	if currencyPage and currencyPage:IsA("Frame") then
		clearGeneratedChildren(currencyPage)
		makeGridPage(currencyPage, "CurrencyCards", getProductsForCategory("Currency"), "Product")
	end
end

local function makeShopWindow(windowsFolder)
	local shopWindow = windowsFolder:FindFirstChild("ShopWindow")
	if not shopWindow or not shopWindow:IsA("GuiObject") then
		shopWindow = frame(windowsFolder, "ShopWindow", UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(820, 500), Color3.fromRGB(255, 255, 255))
	end

	prepShopWindow(shopWindow)
	makeShopTabs(shopWindow)
	local content = makeShopPages(shopWindow)
	makeFeaturedShopContent(content)
	return shopWindow
end

local function makeShopTemplates(shopWindow)
	local templates = findOrCreate(shopWindow, "Folder", "Templates")
	local card, created = findOrCreate(templates, "Frame", "ShopCardTemplate")
	card.Visible = false
	card.Size = UDim2.new(1, -6, 0, 116)
	card.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	card.BorderSizePixel = 0
	applyCorner(card, 12)
	applyStroke(card, Color3.fromRGB(35, 38, 45), 2)

	local icon = frame(card, "Icon", UDim2.fromOffset(12, 14), UDim2.fromOffset(72, 72), Color3.fromRGB(244, 248, 252))
	text(icon, "IconText", "VIP", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 20).TextXAlignment = Enum.TextXAlignment.Center

	local image = icon:FindFirstChild("IconImage")
	if not image then
		image = Instance.new("ImageLabel")
		image.Name = "IconImage"
		image.Parent = icon
	end
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(1, 1)
	image.Visible = false

	text(card, "Name", "Product", UDim2.fromOffset(96, 10), UDim2.new(1, -238, 0, 26), 18)
	text(card, "Description", "Description", UDim2.fromOffset(96, 38), UDim2.new(1, -238, 0, 40), 13)
	text(card, "Badge", "BADGE", UDim2.fromOffset(96, 80), UDim2.new(1, -238, 0, 22), 12)
	text(card, "Price", "R$ 0", UDim2.new(1, -130, 0, 14), UDim2.fromOffset(112, 24), 14).TextXAlignment = Enum.TextXAlignment.Center
	button(card, "BuyButton", "BUY", UDim2.new(1, -130, 1, -48), UDim2.fromOffset(112, 34), Color3.fromRGB(84, 225, 112))

	if created then
		print("StudioMenuWindowsBuilder: created ShopWindow.Templates.ShopCardTemplate")
	end
end

local function getSettingsContent()
	local root = StarterGui:FindFirstChild("ClientUIRoot")
	local mainHud = root and root:FindFirstChild("MainHUD")
	local modalWindows = mainHud and mainHud:FindFirstChild("ModalWindows")
	local windowsFolder = modalWindows and modalWindows:FindFirstChild("Windows")
	local settingsWindow = windowsFolder and windowsFolder:FindFirstChild("SettingsWindow")
	return settingsWindow and settingsWindow:FindFirstChild("Content")
end

local function getWindowContent(windowName)
	local root = StarterGui:FindFirstChild("ClientUIRoot")
	local mainHud = root and root:FindFirstChild("MainHUD")
	local modalWindows = mainHud and mainHud:FindFirstChild("ModalWindows")
	local windowsFolder = modalWindows and modalWindows:FindFirstChild("Windows")
	local window = windowsFolder and windowsFolder:FindFirstChild(windowName)
		or StarterGui:FindFirstChild(windowName, true)
	if not window or not window:IsA("GuiObject") then
		return nil
	end

	local content = window:FindFirstChild("Content") or window:FindFirstChild("Content", true)
	if content and content:IsA("GuiObject") then
		return content
	end

	return frame(
		window,
		"Content",
		UDim2.fromOffset(22, 82),
		UDim2.new(1, -44, 1, -108),
		Color3.fromRGB(244, 248, 252)
	)
end

function Builder.UpdateSettingsWindow()
	if not RunService:IsStudio() then
		warn("StudioMenuWindowsBuilder.UpdateSettingsWindow can only run in Roblox Studio.")
		return
	end
	if RunService:IsRunning() then
		warn("StudioMenuWindowsBuilder.UpdateSettingsWindow should be run in edit mode, not during Play.")
		return
	end

	local content = getSettingsContent()
	if not content then
		warn("StudioMenuWindowsBuilder.UpdateSettingsWindow could not find StarterGui.ClientUIRoot.MainHUD.ModalWindows.Windows.SettingsWindow.Content.")
		return
	end

	makeSettingsGrid(content)
	print("StudioMenuWindowsBuilder: updated SettingsWindow card text.")
end

function Builder.UpdateCodesWindow()
	if not RunService:IsStudio() then
		warn("StudioMenuWindowsBuilder.UpdateCodesWindow can only run in Roblox Studio.")
		return
	end
	if RunService:IsRunning() then
		warn("StudioMenuWindowsBuilder.UpdateCodesWindow should be run in edit mode, not during Play.")
		return
	end

	local content = getWindowContent("CodesWindow")
	if not content then
		warn("StudioMenuWindowsBuilder.UpdateCodesWindow could not find a CodesWindow under StarterGui.")
		return
	end

	makeCodesContent(content)
	print("StudioMenuWindowsBuilder: updated CodesWindow layout.")
end

function Builder.UpdateShopWindow()
	if not RunService:IsStudio() then
		warn("StudioMenuWindowsBuilder.UpdateShopWindow can only run in Roblox Studio.")
		return
	end
	if RunService:IsRunning() then
		warn("StudioMenuWindowsBuilder.UpdateShopWindow should be run in edit mode, not during Play.")
		return
	end

	local root = StarterGui:FindFirstChild("ClientUIRoot")
	local mainHud = root and root:FindFirstChild("MainHUD")
	local modalWindows = mainHud and mainHud:FindFirstChild("ModalWindows")
	local windowsFolder = modalWindows and modalWindows:FindFirstChild("Windows")
	local existingShopWindow = StarterGui:FindFirstChild("ShopWindow", true)
	if not windowsFolder and existingShopWindow and existingShopWindow.Parent then
		windowsFolder = existingShopWindow.Parent
	end
	if not windowsFolder then
		warn("StudioMenuWindowsBuilder.UpdateShopWindow could not find a ShopWindow or Windows folder under StarterGui.")
		return
	end

	makeShopWindow(windowsFolder)
	print("StudioMenuWindowsBuilder: updated ShopWindow Featured shop layout.")
end

function Builder.Build()
	if not RunService:IsStudio() then
		warn("StudioMenuWindowsBuilder.Build can only run in Roblox Studio.")
		return
	end
	if RunService:IsRunning() then
		warn("StudioMenuWindowsBuilder.Build should be run in edit mode, not during Play.")
		return
	end

	local root = findOrCreate(StarterGui, "ScreenGui", "ClientUIRoot")
	root.ResetOnSpawn = false
	root.IgnoreGuiInset = false
	root.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	root.DisplayOrder = math.max(root.DisplayOrder, 100)

	local mainHud = frame(root, "MainHUD", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), Color3.fromRGB(255, 255, 255))
	mainHud.BackgroundTransparency = 1
	mainHud.Visible = true
	mainHud.ClipsDescendants = false

	findOrCreate(mainHud, "Frame", "CurrencyBar").BackgroundTransparency = 1
	findOrCreate(mainHud, "Frame", "BottomRow").BackgroundTransparency = 1
	local dim = findOrCreate(mainHud, "Frame", "DimBackground")
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	dim.BackgroundTransparency = 0.45
	dim.ZIndex = 10
	dim.Visible = false

	local modalWindows = findOrCreate(mainHud, "Folder", "ModalWindows")
	local windowsFolder = findOrCreate(modalWindows, "Folder", "Windows")
	makeInventory(windowsFolder)
	makeShopWindow(windowsFolder)
	local _, upgradesContent = makeWindow(windowsFolder, "UpgradesWindow", "UPGRADES", { "Player", "Colors", "Rank" })
	makeCardGrid(upgradesContent, { "Walk Speed", "Brush Power", "Coin Boost", "Gem Luck" })
	local _, settingsContent = makeWindow(windowsFolder, "SettingsWindow", "SETTINGS", {})
	makeSettingsGrid(settingsContent)
	local _, codesContent = makeWindow(windowsFolder, "CodesWindow", "CODES", {})
	makeCodesContent(codesContent)
	local _, tradeContent = makeWindow(windowsFolder, "TradeWindow", "TRADE", {})
	text(tradeContent, "ComingSoon", "Trading is coming soon!", UDim2.fromScale(0, 0.35), UDim2.fromScale(1, 0.18), 28).TextXAlignment = Enum.TextXAlignment.Center
	local _, worldsContent = makeWindow(windowsFolder, "WorldsWindow", "WORLDS", {})
	makeCardGrid(worldsContent, { "Origin Sector", "Red Wastelands", "Orange Sector", "Inside Pipes" })
	local _, questsContent = makeWindow(windowsFolder, "DailyQuestsWindow", "DAILY QUESTS", {})
	makeCardGrid(questsContent, { "Clean Color Spills", "Earn Coins", "Hatch Colors" })

	print("StudioMenuWindowsBuilder: editable UI created at StarterGui.ClientUIRoot.MainHUD.ModalWindows.Windows")
end

return Builder
