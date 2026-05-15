-- Binds the editable ShopWindow and fills an empty placeholder with a usable shop layout.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local RobuxShopConfig = require(ReplicatedStorage:WaitForChild("RobuxShopConfig"))
local iconConfigModule = ReplicatedStorage:FindFirstChild("GamepassIconConfig")
local GamepassIconConfig = iconConfigModule and require(iconConfigModule) or { Icons = {}, ByShopItemId = {} }
local Events = ReplicatedStorage:WaitForChild("Events", 30)
local claimInfinitePackTierEvent = Events and Events:WaitForChild("ClaimInfinitePackTier", 30)

local OUTLINE = Color3.fromRGB(35, 38, 45)
local TEXT_DARK = Color3.fromRGB(38, 36, 52)
local MUTED = Color3.fromRGB(92, 98, 116)
local CYAN = Color3.fromRGB(76, 214, 224)
local TAB_ACTIVE = Color3.fromRGB(76, 214, 224)
local TAB_INACTIVE = Color3.fromRGB(232, 238, 248)
local GREEN = Color3.fromRGB(84, 225, 112)
local DISABLED = Color3.fromRGB(170, 180, 205)
local GOLD = Color3.fromRGB(255, 218, 74)
local PANEL = Color3.fromRGB(246, 249, 255)
local COMING_SOON_TEXT = "COMING SOON"
local SHOP_WINDOW_POSITION = UDim2.fromScale(0.5, 0.47)
local SHOP_WINDOW_SIZE = UDim2.fromScale(0.76, 0.68)
local CLOSE_BUTTON_POSITION = UDim2.new(1, -78, 0, -42)
local CLOSE_BUTTON_SIZE = UDim2.fromOffset(70, 70)

local PAGE_NAMES = {
	Featured = "FeaturedPage",
	Gamepasses = "GamepassesPage",
	Boosts = "BoostsPage",
	Currency = "CurrencyPage",
}

local PREMIUM_PULSE_IDS = {
	VIP = true,
	LuckyHatch = true,
}

local COMING_SOON_PAGES = {
	Boosts = true,
	Currency = true,
}

local gamepassesById = {}
for _, pass in ipairs(RobuxShopConfig.Gamepasses or {}) do
	gamepassesById[pass.id] = pass
end

local productsById = {}
for _, product in ipairs(RobuxShopConfig.DevProducts or {}) do
	productsById[product.id] = product
end

local infinitePackTiersById = {}
local infinitePackTiers = {}
if RobuxShopConfig.getInfinitePackTiers then
	for _, tier in ipairs(RobuxShopConfig.getInfinitePackTiers()) do
		table.insert(infinitePackTiers, tier)
		infinitePackTiersById[tier.id] = tier
	end
end

local warned = {}
local ownedCache = {}
local claimingInfinitePackTier = {}

local function warnOnce(key, message)
	if warned[key] then
		return
	end
	warned[key] = true
	warn(message)
end

local function getMainHUD()
	return playerGui:WaitForChild("MainHUD", 30)
end

local function getWindows(mainHUD)
	local modalWindows = mainHUD and mainHUD:FindFirstChild("ModalWindows")
	return modalWindows
end

local function getTextLabel(parent, name)
	local object = parent and parent:FindFirstChild(name, true)
	return object and object:IsA("TextLabel") and object or nil
end

local function getButton(parent)
	local object = parent and parent:FindFirstChild("BuyButton", true)
	return object and object:IsA("GuiButton") and object or nil
end

local function getStroke(parent)
	return parent and parent:FindFirstChildOfClass("UIStroke")
end

local function getShopIconSpec(item)
	if type(item) ~= "table" then
		return nil
	end

	local iconKey = item.iconKey or (GamepassIconConfig.ByShopItemId and GamepassIconConfig.ByShopItemId[item.id])
	return iconKey and GamepassIconConfig.Icons and GamepassIconConfig.Icons[iconKey] or nil
end

local function applyShopIcon(card, item)
	if not card or type(item) ~= "table" then
		return
	end

	local iconCircle = card:FindFirstChild("IconCircle", true) or card:FindFirstChild("RewardBox", true)
	if not iconCircle or not iconCircle:IsA("GuiObject") then
		return
	end

	local spec = getShopIconSpec(item)
	local image = spec and tostring(spec.Image or "") or ""
	if image == "" then
		image = tostring(item.iconImage or "")
	end

	local iconImage = iconCircle:FindFirstChild("IconImage")
	if not iconImage or not iconImage:IsA("ImageLabel") then
		warnOnce(
			"missing-icon-" .. tostring(item.id or item.name or item.iconKey),
			"EditableShopBinder: missing Studio-authored IconImage under " .. iconCircle:GetFullName()
		)
		return
	end
	iconImage.Image = image
	iconImage.Visible = image ~= ""
	iconImage:SetAttribute("GamepassIconKey", item.iconKey or "")
	iconImage:SetAttribute("ExpectedGamepassIconFile", spec and spec.SourceFile or item.iconSourceFile or "")

	local iconText = iconCircle:FindFirstChild("IconText")
	if iconText and iconText:IsA("TextLabel") then
		iconText.Text = tostring(item.icon or iconText.Text or "?")
		iconText.Visible = image == ""
	end

	iconCircle:SetAttribute("GamepassIconKey", item.iconKey or "")
	iconCircle:SetAttribute("ExpectedGamepassIconFile", spec and spec.SourceFile or item.iconSourceFile or "")
end

local function applyCorner(instance, radius)
	local corner = instance:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 12)
	corner.Parent = instance
	return corner
end

local function applyStroke(instance, color, thickness)
	local stroke = instance:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	stroke.Color = color or OUTLINE
	stroke.Thickness = thickness or 2
	stroke.Parent = instance
	return stroke
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

local function makeFrame(parent, name, position, size, color, zIndex)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Position = position
	frame.Size = size
	frame.BackgroundColor3 = color or Color3.fromRGB(255, 255, 255)
	frame.BorderSizePixel = 0
	frame.ZIndex = zIndex or 1003
	frame.Parent = parent
	applyCorner(frame, 16)
	applyStroke(frame, OUTLINE, 2)
	return frame
end

local function makeText(parent, name, value, position, size, textSize, color, zIndex)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = Enum.Font.GothamBlack
	label.Text = tostring(value or "")
	label.TextColor3 = color or TEXT_DARK
	label.TextSize = textSize or 18
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextStrokeTransparency = 1
	label.ZIndex = zIndex or 1004
	label.Parent = parent
	return label
end

local function makeButton(parent, name, value, position, size, color, zIndex)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Position = position
	button.Size = size
	button.BackgroundColor3 = color or GREEN
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Font = Enum.Font.GothamBlack
	button.Text = tostring(value or "")
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 16
	button.TextScaled = true
	button.TextWrapped = true
	button.TextStrokeColor3 = OUTLINE
	button.TextStrokeTransparency = 0
	button.ZIndex = zIndex or 1005
	button.Parent = parent
	applyCorner(button, 12)
	applyStroke(button, OUTLINE, 2)
	makeScale(button, "ButtonScale")
	return button
end

local function clearGeneratedLayout(parent)
	for _, child in ipairs(parent:GetChildren()) do
		if
			child:IsA("GuiObject")
			or child:IsA("UIGridLayout")
			or child:IsA("UIListLayout")
			or child:IsA("UIPadding")
		then
			child:Destroy()
		end
	end
end

local function clearWindowForGeneratedShop(shopWindow)
	for _, child in ipairs(shopWindow:GetChildren()) do
		if
			child.Name ~= "CloseButton"
			and (
				child:IsA("GuiObject")
				or child:IsA("UIGridLayout")
				or child:IsA("UIListLayout")
				or child:IsA("UIPadding")
			)
		then
			child:Destroy()
		end
	end
end

local function getSortedGamepasses()
	if RobuxShopConfig.getSortedGamepasses then
		return RobuxShopConfig.getSortedGamepasses()
	end

	local passes = {}
	for _, pass in ipairs(RobuxShopConfig.Gamepasses or {}) do
		if pass.showInShop ~= false then
			table.insert(passes, pass)
		end
	end
	table.sort(passes, function(a, b)
		return (a.sortOrder or 999) < (b.sortOrder or 999)
	end)
	return passes
end

local function getProductsForCategory(categoryName)
	local products = {}
	local source = RobuxShopConfig.getSortedDevProducts and RobuxShopConfig.getSortedDevProducts()
		or RobuxShopConfig.DevProducts
		or {}
	for _, product in ipairs(source) do
		if product.showInShop ~= false and tostring(product.category or "") == categoryName then
			table.insert(products, product)
		end
	end
	return products
end

local function makeIconCircle(parent, name, item, position, size, zIndex)
	local iconColor = (item.color or CYAN):Lerp(Color3.fromRGB(255, 255, 255), 0.28)
	local circle = makeFrame(parent, name, position, size, iconColor, zIndex or 1004)
	applyCorner(circle, 999)
	makeScale(circle, "IconScale")

	local iconText = makeText(
		circle,
		"IconText",
		tostring(item.icon or "?"),
		UDim2.fromScale(0, 0),
		UDim2.fromScale(1, 1),
		24,
		Color3.fromRGB(255, 255, 255),
		(circle.ZIndex or 1004) + 1
	)
	iconText.TextXAlignment = Enum.TextXAlignment.Center
	iconText.TextScaled = true
	iconText.TextStrokeColor3 = OUTLINE
	iconText.TextStrokeTransparency = 0

	local iconImage = Instance.new("ImageLabel")
	iconImage.Name = "IconImage"
	iconImage.BackgroundTransparency = 1
	iconImage.BorderSizePixel = 0
	iconImage.Position = UDim2.fromOffset(3, 3)
	iconImage.Size = UDim2.new(1, -6, 1, -6)
	iconImage.ScaleType = Enum.ScaleType.Fit
	iconImage.ZIndex = iconText.ZIndex + 1
	iconImage.Image = tostring(item.iconImage or "")
	iconImage.Visible = iconImage.Image ~= ""
	iconImage.Parent = circle
	iconText.Visible = iconImage.Image == ""
	return circle
end

local function styleCloseButton(shopWindow)
	local closeButton = shopWindow:FindFirstChild("CloseButton")
	if closeButton and not closeButton:IsA("GuiButton") then
		closeButton:Destroy()
		closeButton = nil
	end
	if not closeButton then
		closeButton = makeButton(
			shopWindow,
			"CloseButton",
			"X",
			CLOSE_BUTTON_POSITION,
			CLOSE_BUTTON_SIZE,
			Color3.fromRGB(188, 21, 28),
			1006
		)
	end

	closeButton.Position = CLOSE_BUTTON_POSITION
	closeButton.Size = CLOSE_BUTTON_SIZE
	closeButton.BackgroundColor3 = Color3.fromRGB(216, 24, 32)
	closeButton.BorderSizePixel = 0
	closeButton.ZIndex = 1006
	applyCorner(closeButton, 14)
	applyStroke(closeButton, OUTLINE, 2)
	if closeButton:IsA("TextButton") then
		closeButton.Text = "X"
		closeButton.TextScaled = false
		closeButton.TextSize = 48
		closeButton.Font = Enum.Font.GothamBlack
		pcall(function()
			closeButton.FontFace =
				Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy, Enum.FontStyle.Normal)
		end)
		closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		closeButton.TextStrokeColor3 = OUTLINE
		closeButton.TextStrokeTransparency = 0
	else
		local runtimeText = closeButton:FindFirstChild("RuntimeText")
		if runtimeText and runtimeText:IsA("GuiObject") then
			runtimeText:Destroy()
		end

		local closeIcon = closeButton:FindFirstChild("CloseIcon")
		if not closeIcon or not closeIcon:IsA("TextLabel") then
			if closeIcon then
				closeIcon:Destroy()
			end
			closeIcon = makeText(
				closeButton,
				"CloseIcon",
				"X",
				UDim2.fromScale(0, 0),
				UDim2.fromScale(1, 1),
				28,
				Color3.fromRGB(255, 255, 255),
				1007
			)
		end
		closeIcon.Text = "X"
		closeIcon.TextScaled = false
		closeIcon.TextSize = 48
		closeIcon.Font = Enum.Font.GothamBlack
		pcall(function()
			closeIcon.FontFace =
				Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy, Enum.FontStyle.Normal)
		end)
		closeIcon.TextXAlignment = Enum.TextXAlignment.Center
		closeIcon.TextYAlignment = Enum.TextYAlignment.Center
		closeIcon.TextStrokeColor3 = OUTLINE
		closeIcon.TextStrokeTransparency = 0
	end
end

local function makeShopTabs(shopWindow)
	local tabs = makeFrame(
		shopWindow,
		"Tabs",
		UDim2.fromOffset(26, 76),
		UDim2.new(1, -52, 0, 48),
		Color3.fromRGB(255, 255, 255),
		1002
	)
	tabs.BackgroundTransparency = 1
	local stroke = tabs:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke:Destroy()
	end

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = tabs

	for index, tabName in ipairs({ "Featured", "Gamepasses", "Boosts", "Currency" }) do
		local tab = makeButton(
			tabs,
			tabName .. "Tab",
			tabName,
			UDim2.fromScale(0, 0),
			UDim2.fromOffset(150, 38),
			index == 1 and TAB_ACTIVE or TAB_INACTIVE,
			1003
		)
		tab.LayoutOrder = index
		tab.TextSize = 18
		tab.TextColor3 = index == 1 and Color3.fromRGB(255, 255, 255) or TEXT_DARK
		tab.TextStrokeTransparency = index == 1 and 0 or 1
	end
	return tabs
end

local function makeContentPages(shopWindow)
	local content = makeFrame(shopWindow, "Content", UDim2.fromOffset(26, 136), UDim2.new(1, -52, 1, -164), PANEL, 1001)
	content.ClipsDescendants = true
	applyCorner(content, 18)
	applyStroke(content, OUTLINE, 3)

	for index, pageName in ipairs({ "FeaturedPage", "GamepassesPage", "BoostsPage", "CurrencyPage" }) do
		local page = makeFrame(content, pageName, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), PANEL, 1002)
		page.BackgroundTransparency = 1
		page.Visible = index == 1
		local pageStroke = page:FindFirstChildOfClass("UIStroke")
		if pageStroke then
			pageStroke:Destroy()
		end
	end
	return content
end

local function makeInfiniteTierCard(parent, tier, layoutOrder)
	local card = makeFrame(
		parent,
		tostring(tier.id) .. "Card",
		UDim2.fromScale(0, 0),
		UDim2.fromOffset(98, 118),
		Color3.fromRGB(255, 255, 255),
		1005
	)
	card:SetAttribute("ShopItemId", tier.id)
	card:SetAttribute("ShopItemKind", "InfinitePackTier")
	card.LayoutOrder = layoutOrder
	makeScale(card, "CardScale")
	applyCorner(card, 12)

	local iconCircle = makeIconCircle(card, "IconCircle", tier, UDim2.fromOffset(9, 8), UDim2.fromOffset(80, 60), 1006)
	applyCorner(iconCircle, 10)
	applyShopIcon(card, tier)

	local reward = makeText(
		card,
		"RewardLabel",
		tostring(tier.rewardText or tier.displayName or ""),
		UDim2.fromOffset(7, 70),
		UDim2.fromOffset(84, 18),
		10,
		TEXT_DARK,
		1007
	)
	reward.Font = Enum.Font.GothamBold
	reward.TextXAlignment = Enum.TextXAlignment.Center

	local price = makeText(
		card,
		"PriceLabel",
		tier.free and "FREE" or (tostring(tier.price or 0) .. " R$"),
		UDim2.fromOffset(9, 90),
		UDim2.fromOffset(78, 22),
		12,
		TEXT_DARK,
		1007
	)
	price.TextXAlignment = Enum.TextXAlignment.Center
	price.Visible = false

	local buy = makeButton(
		card,
		"BuyButton",
		tier.free and "FREE" or (tostring(tier.price or 0) .. " R$"),
		UDim2.fromOffset(9, 90),
		UDim2.fromOffset(80, 24),
		tier.free and GREEN or Color3.fromRGB(118, 235, 80),
		1007
	)
	buy.TextSize = tier.free and 18 or 14
	return card
end

local function makeShopCard(parent, item, kind, layoutOrder, compact)
	local cardSize = compact and UDim2.fromOffset(140, 66) or UDim2.fromOffset(225, 112)
	local card = makeFrame(
		parent,
		tostring(item.id) .. "Card",
		UDim2.fromScale(0, 0),
		cardSize,
		Color3.fromRGB(255, 255, 255),
		1003
	)
	card:SetAttribute("ShopItemId", item.id)
	card:SetAttribute("ShopItemKind", kind)
	card.LayoutOrder = layoutOrder
	makeScale(card, "CardScale")

	local icon = makeIconCircle(
		card,
		"IconCircle",
		item,
		compact and UDim2.fromOffset(8, 8) or UDim2.fromOffset(12, 14),
		compact and UDim2.fromOffset(42, 42) or UDim2.fromOffset(58, 58),
		1004
	)
	if kind == "Gamepass" then
		applyShopIcon(card, item)
	end

	local title = makeText(
		card,
		"Title",
		tostring(item.displayName or item.id),
		compact and UDim2.fromOffset(56, 7) or UDim2.fromOffset(82, 12),
		compact and UDim2.new(1, -64, 0, 20) or UDim2.new(1, -94, 0, 26),
		compact and 12 or 17,
		TEXT_DARK,
		1005
	)
	title.TextScaled = compact

	local description = makeText(
		card,
		"Description",
		tostring(item.description or ""),
		UDim2.fromOffset(82, 42),
		UDim2.new(1, -94, 0, 32),
		12,
		MUTED,
		1005
	)
	description.Font = Enum.Font.GothamBold
	description.Visible = not compact

	local price = makeText(
		card,
		"PriceLabel",
		tostring(item.price or 0) .. " R$",
		UDim2.fromOffset(12, 78),
		UDim2.fromOffset(96, 24),
		14,
		TEXT_DARK,
		1005
	)
	price.TextXAlignment = Enum.TextXAlignment.Center
	price.Visible = false

	local buy = makeButton(
		card,
		"BuyButton",
		"BUY",
		compact and UDim2.new(1, -78, 1, -24) or UDim2.new(1, -124, 1, -40),
		compact and UDim2.fromOffset(68, 18) or UDim2.fromOffset(112, 30),
		kind == "Product" and DISABLED or GREEN,
		1005
	)
	buy.TextSize = compact and 10 or 13

	if item.badge and item.badge ~= "" then
		local badge = makeFrame(
			card,
			"Badge",
			compact and UDim2.new(0, 8, 1, -22) or UDim2.new(0, 12, 1, -38),
			compact and UDim2.fromOffset(58, 18) or UDim2.fromOffset(94, 24),
			GOLD,
			1006
		)
		applyCorner(badge, 999)
		local badgeText = makeText(
			badge,
			"Text",
			tostring(item.badge),
			UDim2.fromScale(0, 0),
			UDim2.fromScale(1, 1),
			compact and 9 or 11,
			TEXT_DARK,
			1007
		)
		badgeText.TextXAlignment = Enum.TextXAlignment.Center
		badgeText.TextScaled = true
	end

	return card
end

local function bindCanvasToLayout(scroller, layout, paddingY)
	local function resize()
		scroller.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + (paddingY or 24))
	end
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resize)
	task.defer(resize)
end

local function makeGridPage(page, holderName, items, kind)
	local scroller = Instance.new("ScrollingFrame")
	scroller.Name = holderName
	scroller.Position = UDim2.fromOffset(16, 14)
	scroller.Size = UDim2.new(1, -32, 1, -28)
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.ScrollBarThickness = 6
	scroller.ScrollBarImageColor3 = MUTED
	scroller.ScrollingDirection = Enum.ScrollingDirection.Y
	scroller.CanvasSize = UDim2.fromOffset(0, 0)
	scroller.ZIndex = 1002
	scroller.Parent = page

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 2)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.Parent = scroller

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(225, 112)
	grid.CellPadding = UDim2.fromOffset(12, 12)
	grid.FillDirectionMaxCells = 3
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.VerticalAlignment = Enum.VerticalAlignment.Top
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroller
	bindCanvasToLayout(scroller, grid, 24)

	for index, item in ipairs(items) do
		makeShopCard(scroller, item, kind, index, false)
	end
end

local function styleComingSoonLabel(label, textSize)
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBlack
	label.Text = COMING_SOON_TEXT
	label.TextColor3 = TEXT_DARK
	label.TextScaled = true
	label.TextSize = textSize or 44
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0
end

local function ensureComingSoonLabel(parent, name, zIndex)
	local label = parent:FindFirstChild(name)
	if not label or not label:IsA("TextLabel") then
		if label then
			label:Destroy()
		end
		label = Instance.new("TextLabel")
		label.Name = name
		label.Parent = parent
	end

	label.Position = UDim2.fromScale(0.08, 0.24)
	label.Size = UDim2.fromScale(0.84, 0.52)
	label.ZIndex = zIndex or ((parent:IsA("GuiObject") and parent.ZIndex + 4) or 1006)
	label.Visible = true
	styleComingSoonLabel(label, 44)
	return label
end

local function applyPageComingSoon(page)
	for _, child in ipairs(page:GetChildren()) do
		if child:IsA("GuiObject") and child.Name ~= "ComingSoonLabel" then
			child.Visible = false
		end
	end

	page:SetAttribute("ShopComingSoonPage", true)
	ensureComingSoonLabel(page, "ComingSoonLabel", page.ZIndex + 5)
end

local function applyForeverPackComingSoon(shopWindow)
	local panel = shopWindow:FindFirstChild("InfinitePackPanel", true)
	if not panel or not panel:IsA("GuiObject") then
		return
	end

	for _, child in ipairs(panel:GetChildren()) do
		if child:IsA("GuiObject") and child.Name ~= "RainbowBand" and child.Name ~= "Title" then
			child.Visible = false
		end
	end

	local title = panel:FindFirstChild("Title")
	if title and title:IsA("TextLabel") then
		title.Position = UDim2.fromScale(0.07, 0.25)
		title.Size = UDim2.fromScale(0.86, 0.5)
		title.ZIndex = math.max(title.ZIndex, panel.ZIndex + 6)
		title.Visible = true
		styleComingSoonLabel(title, 48)
	else
		ensureComingSoonLabel(panel, "ComingSoonLabel", panel.ZIndex + 6)
	end
end

local function applyComingSoonShopSections(shopWindow)
	local content = shopWindow:FindFirstChild("Content", true)
	if content then
		for pageKey, shouldShowComingSoon in pairs(COMING_SOON_PAGES) do
			local page = shouldShowComingSoon and content:FindFirstChild(PAGE_NAMES[pageKey])
			if page and page:IsA("GuiObject") then
				applyPageComingSoon(page)
			end
		end
	end

	applyForeverPackComingSoon(shopWindow)
end

local function makeFeaturedShopPage(page)
	local pack = RobuxShopConfig.InfinitePack or {}
	local panel = makeFrame(
		page,
		"InfinitePackPanel",
		UDim2.fromOffset(16, 12),
		UDim2.new(1, -32, 0, 214),
		Color3.fromRGB(184, 246, 255),
		1003
	)
	panel.ClipsDescendants = true
	applyCorner(panel, 18)
	applyStroke(panel, OUTLINE, 3)

	local shine = makeFrame(
		panel,
		"RainbowBand",
		UDim2.new(-0.05, 0, 0, 52),
		UDim2.new(1.1, 0, 0, 62),
		Color3.fromRGB(255, 122, 188),
		1004
	)
	shine.BackgroundTransparency = 0.38
	shine.Rotation = -7
	local shineStroke = shine:FindFirstChildOfClass("UIStroke")
	if shineStroke then
		shineStroke:Destroy()
	end

	local reset = makeText(
		panel,
		"ResetLabel",
		"Resets in 23:59:59",
		UDim2.fromOffset(18, 14),
		UDim2.fromOffset(190, 34),
		22,
		TEXT_DARK,
		1006
	)
	reset.TextScaled = true
	reset.TextStrokeTransparency = 0
	reset.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)

	local title = makeText(
		panel,
		"Title",
		tostring(pack.displayName or "THE FOREVER PACK!"),
		UDim2.new(0, 210, 0, 12),
		UDim2.new(1, -230, 0, 40),
		30,
		TEXT_DARK,
		1006
	)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.TextScaled = true
	title.TextStrokeTransparency = 0
	title.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)

	local track = Instance.new("ScrollingFrame")
	track.Name = "TierTrack"
	track.Position = UDim2.fromOffset(14, 62)
	track.Size = UDim2.new(1, -28, 0, 138)
	track.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	track.BorderSizePixel = 0
	track.ScrollBarThickness = 0
	track.ScrollingDirection = Enum.ScrollingDirection.X
	track.CanvasSize = UDim2.fromOffset((#infinitePackTiers * 128) + 80, 0)
	track.ZIndex = 1005
	track.Parent = panel
	applyCorner(track, 14)
	applyStroke(track, OUTLINE, 2)

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Left
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = track

	for index, tier in ipairs(infinitePackTiers) do
		makeInfiniteTierCard(track, tier, index * 2)
		if index < #infinitePackTiers then
			local arrow = makeText(
				track,
				"Arrow" .. tostring(index),
				"->",
				UDim2.fromScale(0, 0),
				UDim2.fromOffset(18, 118),
				26,
				OUTLINE,
				1007
			)
			arrow.LayoutOrder = (index * 2) + 1
			arrow.TextXAlignment = Enum.TextXAlignment.Center
			arrow.TextScaled = true
		end
	end

	local holder = makeFrame(page, "SpotlightCards", UDim2.fromOffset(16, 238), UDim2.new(1, -32, 1, -250), PANEL, 1002)
	holder.BackgroundTransparency = 1
	local holderStroke = holder:FindFirstChildOfClass("UIStroke")
	if holderStroke then
		holderStroke:Destroy()
	end

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(140, 66)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.FillDirectionMaxCells = 5
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.VerticalAlignment = Enum.VerticalAlignment.Top
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = holder

	for index, pass in ipairs(getSortedGamepasses()) do
		if index <= 5 then
			makeShopCard(holder, pass, "Gamepass", index, true)
		end
	end
end

local function hasEditableShopLayout(shopWindow)
	if not shopWindow:FindFirstChild("Tabs") or not shopWindow:FindFirstChild("Content") then
		return false
	end
	for _, descendant in ipairs(shopWindow:GetDescendants()) do
		if descendant:IsA("GuiObject") and descendant:GetAttribute("ShopItemId") then
			return true
		end
	end
	return false
end

local function ensureShopLayout(shopWindow)
	if hasEditableShopLayout(shopWindow) then
		return
	end

	clearWindowForGeneratedShop(shopWindow)
	shopWindow.AnchorPoint = Vector2.new(0.5, 0.5)
	shopWindow.Position = SHOP_WINDOW_POSITION
	shopWindow.Size = SHOP_WINDOW_SIZE
	shopWindow.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	shopWindow.BorderSizePixel = 0
	shopWindow.ClipsDescendants = false
	shopWindow.ZIndex = math.max(shopWindow.ZIndex, 1000)
	applyCorner(shopWindow, 24)
	applyStroke(shopWindow, OUTLINE, 4)

	local title = makeText(
		shopWindow,
		"Title",
		"ROBUX SHOP",
		UDim2.fromOffset(26, 16),
		UDim2.new(1, -120, 0, 46),
		32,
		TEXT_DARK,
		1002
	)
	title.TextScaled = true
	styleCloseButton(shopWindow)
	makeShopTabs(shopWindow)
	local content = makeContentPages(shopWindow)

	local featuredPage = content:FindFirstChild("FeaturedPage")
	if featuredPage and featuredPage:IsA("GuiObject") then
		clearGeneratedLayout(featuredPage)
		makeFeaturedShopPage(featuredPage)
	end

	local gamepassesPage = content:FindFirstChild("GamepassesPage")
	if gamepassesPage and gamepassesPage:IsA("GuiObject") then
		clearGeneratedLayout(gamepassesPage)
		makeGridPage(gamepassesPage, "GamepassCards", getSortedGamepasses(), "Gamepass")
	end

	local boostsPage = content:FindFirstChild("BoostsPage")
	if boostsPage and boostsPage:IsA("GuiObject") then
		clearGeneratedLayout(boostsPage)
		makeGridPage(boostsPage, "BoostCards", getProductsForCategory("Boosts"), "Product")
	end

	local currencyPage = content:FindFirstChild("CurrencyPage")
	if currencyPage and currencyPage:IsA("GuiObject") then
		clearGeneratedLayout(currencyPage)
		makeGridPage(currencyPage, "CurrencyCards", getProductsForCategory("Currency"), "Product")
	end
end

local function findScale(parent, name)
	local scale = parent:FindFirstChild(name)
	if scale and scale:IsA("UIScale") then
		return scale
	end
	return nil
end

local function tweenScale(scale, value, duration)
	if not scale then
		return
	end
	TweenService:Create(scale, TweenInfo.new(duration or 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Scale = value,
	}):Play()
end

local function setButtonText(button, text)
	if button:IsA("TextButton") then
		button.Text = text
	end
end

local function setButtonEnabled(button, enabled)
	button.Active = enabled
	button.Selectable = enabled
	button.AutoButtonColor = false
	pcall(function()
		button.Interactable = enabled
	end)
end

local function getCurrencyRewardAmount(reward, currencyName)
	local rewardKind = tostring(reward.rewardKind or "")
	if currencyName == "Coins" then
		return math.floor(tonumber(reward.coinReward or (rewardKind == "Coin" and reward.amount) or 0) or 0)
	elseif currencyName == "Gems" then
		return math.floor(tonumber(reward.gemReward or (rewardKind == "Gem" and reward.amount) or 0) or 0)
	elseif currencyName == "Diamonds" then
		return math.floor(tonumber(reward.diamondReward or (rewardKind == "Diamond" and reward.amount) or 0) or 0)
	end
	return 0
end

local function hasClaimableFreeReward(tier)
	return getCurrencyRewardAmount(tier, "Coins") > 0
		or getCurrencyRewardAmount(tier, "Gems") > 0
		or getCurrencyRewardAmount(tier, "Diamonds") > 0
end

local function isInfinitePackTierClaimed(tier)
	if not tier then
		return false
	end
	if player:GetAttribute("InfinitePackClaimed_" .. tostring(tier.id)) == true then
		return true
	end
	local folder = player:FindFirstChild("InfinitePackClaims")
	local claimedTiers = folder and folder:FindFirstChild("ClaimedTiers")
	local claim = claimedTiers and claimedTiers:FindFirstChild(tostring(tier.id))
	return claim and claim:IsA("BoolValue") and claim.Value == true
end

local function getCurrentInfinitePackTier()
	for _, tier in ipairs(infinitePackTiers) do
		if not isInfinitePackTierClaimed(tier) then
			return tier
		end
	end
	return nil
end

local function ownsPass(pass)
	if not pass then
		return false
	end
	if player:GetAttribute("Pass_" .. tostring(pass.id)) == true then
		ownedCache[pass.id] = true
		return true
	end
	if ownedCache[pass.id] ~= nil then
		return ownedCache[pass.id]
	end

	local gamepassId = tonumber(pass.gamepassId)
	if not gamepassId or gamepassId <= 0 then
		ownedCache[pass.id] = false
		return false
	end

	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepassId)
	end)
	ownedCache[pass.id] = ok and owns == true
	return ownedCache[pass.id]
end

local function setOwnedVisual(card, owned)
	local stroke = getStroke(card)
	if stroke then
		stroke.Color = owned and GREEN or OUTLINE
		stroke.Thickness = owned and 4 or 2
	end
end

local function updateGamepassCard(card, pass)
	local button = getButton(card)
	local priceLabel = getTextLabel(card, "PriceLabel")
	local owned = ownsPass(pass)
	local gamepassId = tonumber(pass.gamepassId)
	local hasRealId = gamepassId and gamepassId > 0

	if priceLabel then
		priceLabel.Text = tostring(pass.price or 0) .. " R$"
	end

	setOwnedVisual(card, owned)
	if not button then
		return
	end

	if owned then
		setButtonText(button, "OWNED ✓")
		button.BackgroundColor3 = GREEN
		setButtonEnabled(button, false)
	elseif hasRealId then
		setButtonText(button, "BUY " .. tostring(pass.price or 0) .. " R$")
		button.BackgroundColor3 = GREEN
		setButtonEnabled(button, true)
	else
		setButtonText(button, "SET ID")
		button.BackgroundColor3 = DISABLED
		setButtonEnabled(button, false)
	end
end

local function updateProductCard(card, product)
	local button = getButton(card)
	local priceLabel = getTextLabel(card, "PriceLabel")
	local productId = tonumber(product.productId)
	local hasRealId = productId and productId > 0

	if priceLabel then
		priceLabel.Text = hasRealId and (tostring(product.price or 0) .. " R$") or "COMING SOON"
	end

	setOwnedVisual(card, false)
	if not button then
		return
	end

	if hasRealId then
		setButtonText(button, "BUY " .. tostring(product.price or 0) .. " R$")
		button.BackgroundColor3 = GREEN
		setButtonEnabled(button, true)
	else
		setButtonText(button, "COMING SOON")
		button.BackgroundColor3 = DISABLED
		setButtonEnabled(button, false)
	end
end

local function updateInfinitePackTierCard(card, tier)
	local button = getButton(card)
	local priceLabel = getTextLabel(card, "PriceLabel")
	local rewardLabel = getTextLabel(card, "RewardLabel")
	local iconCircle = card:FindFirstChild("IconCircle", true) or card:FindFirstChild("RewardBox", true)
	local currentTier = getCurrentInfinitePackTier()
	local isCurrent = currentTier and currentTier.id == tier.id
	local productId = tonumber(tier.productId)
	local isFree = tier.free == true or tonumber(tier.price) == 0
	local hasRealId = productId and productId > 0
	local claimed = isInfinitePackTierClaimed(tier)
	local claimableFreeReward = hasClaimableFreeReward(tier)

	if rewardLabel then
		rewardLabel.Text = tostring(tier.rewardText or tier.displayName or "")
	end
	if iconCircle and iconCircle:IsA("GuiObject") then
		iconCircle.BackgroundColor3 = tier.color or iconCircle.BackgroundColor3
	end
	applyShopIcon(card, tier)

	if priceLabel then
		priceLabel.Text = isFree and "FREE" or (tostring(tier.price or 0) .. " R$")
	end

	setOwnedVisual(card, claimed)
	if not button then
		return
	end

	if claimed then
		setButtonText(button, "CLAIMED")
		button.BackgroundColor3 = GREEN
		setButtonEnabled(button, false)
	elseif claimingInfinitePackTier[tier.id] then
		setButtonText(button, "CLAIMING")
		button.BackgroundColor3 = DISABLED
		setButtonEnabled(button, false)
	elseif not isCurrent then
		setButtonText(button, "LOCKED")
		button.BackgroundColor3 = DISABLED
		setButtonEnabled(button, false)
	elseif isFree and claimableFreeReward then
		setButtonText(button, "FREE")
		button.BackgroundColor3 = GREEN
		setButtonEnabled(button, true)
	elseif isFree then
		setButtonText(button, "SOON")
		button.BackgroundColor3 = DISABLED
		setButtonEnabled(button, false)
	elseif hasRealId then
		setButtonText(button, tostring(tier.price or 0) .. " R$")
		button.BackgroundColor3 = GREEN
		setButtonEnabled(button, true)
	else
		setButtonText(button, "SET ID")
		button.BackgroundColor3 = DISABLED
		setButtonEnabled(button, false)
	end
end

local function focusInfinitePackTrack(shopWindow)
	local currentTier = getCurrentInfinitePackTier()
	if not currentTier then
		return
	end

	local track = shopWindow:FindFirstChild("TierTrack", true)
	if not track or not track:IsA("ScrollingFrame") then
		return
	end
	track.ScrollingEnabled = false
	track.ScrollBarThickness = 0

	local card = track:FindFirstChild(tostring(currentTier.id) .. "Card")
	if not card or not card:IsA("GuiObject") then
		return
	end

	task.defer(function()
		if not card.Parent or not track.Parent then
			return
		end
		local targetX = card.AbsolutePosition.X - track.AbsolutePosition.X + track.CanvasPosition.X - 8
		track.CanvasPosition = Vector2.new(math.max(0, targetX), 0)
	end)
end

local function updateCardState(card)
	local itemId = card:GetAttribute("ShopItemId")
	local kind = card:GetAttribute("ShopItemKind")
	if kind == "Gamepass" then
		local pass = gamepassesById[itemId]
		if pass then
			applyShopIcon(card, pass)
			updateGamepassCard(card, pass)
		end
	elseif kind == "Product" then
		local product = productsById[itemId]
		if product then
			updateProductCard(card, product)
		end
	elseif kind == "InfinitePackTier" then
		local tier = infinitePackTiersById[itemId]
		if tier then
			updateInfinitePackTierCard(card, tier)
		end
	end
end

local function bindButton(card)
	if card:GetAttribute("EditableShopCardBound") == true then
		return
	end
	card:SetAttribute("EditableShopCardBound", true)

	local cardScale = findScale(card, "CardScale")
	card.MouseEnter:Connect(function()
		local stroke = getStroke(card)
		local itemId = card:GetAttribute("ShopItemId")
		local pass = gamepassesById[itemId]
		local tier = infinitePackTiersById[itemId]
		tweenScale(cardScale, 1.025, 0.12)
		if stroke and pass and not ownsPass(pass) then
			stroke.Color = pass.color or TAB_ACTIVE
			stroke.Thickness = 3
		elseif stroke and tier then
			stroke.Color = tier.color or TAB_ACTIVE
			stroke.Thickness = 3
		end
	end)
	card.MouseLeave:Connect(function()
		tweenScale(cardScale, 1, 0.12)
		updateCardState(card)
	end)

	local button = getButton(card)
	if not button then
		return
	end

	local buttonScale = findScale(button, "ButtonScale")
	button.MouseEnter:Connect(function()
		tweenScale(buttonScale, 1.05, 0.1)
	end)
	button.MouseLeave:Connect(function()
		tweenScale(buttonScale, 1, 0.1)
	end)
	button.MouseButton1Down:Connect(function()
		tweenScale(buttonScale, 0.94, 0.08)
	end)
	button.MouseButton1Up:Connect(function()
		tweenScale(buttonScale, 1.05, 0.08)
	end)
	button.Activated:Connect(function()
		local itemId = card:GetAttribute("ShopItemId")
		local kind = card:GetAttribute("ShopItemKind")
		if kind == "Gamepass" then
			local pass = gamepassesById[itemId]
			local gamepassId = pass and tonumber(pass.gamepassId)
			if pass and not ownsPass(pass) and gamepassId and gamepassId > 0 then
				MarketplaceService:PromptGamePassPurchase(player, gamepassId)
			end
		elseif kind == "Product" then
			local product = productsById[itemId]
			local productId = product and tonumber(product.productId)
			if product and productId and productId > 0 then
				MarketplaceService:PromptProductPurchase(player, productId)
			end
		elseif kind == "InfinitePackTier" then
			local tier = infinitePackTiersById[itemId]
			local productId = tier and tonumber(tier.productId)
			local isFree = tier and (tier.free == true or tonumber(tier.price) == 0)
			if tier and isFree and hasClaimableFreeReward(tier) and not isInfinitePackTierClaimed(tier) then
				if claimInfinitePackTierEvent and claimInfinitePackTierEvent:IsA("RemoteEvent") then
					claimingInfinitePackTier[tier.id] = true
					updateCardState(card)
					claimInfinitePackTierEvent:FireServer(tier.id)
				else
					warnOnce("infinite-pack-free", "EditableShopBinder: ClaimInfinitePackTier remote is missing.")
				end
			elseif tier and isFree then
				warnOnce(
					"infinite-pack-unsupported-free",
					"EditableShopBinder: this free Infinite Pack reward is not wired yet."
				)
			elseif tier and productId and productId > 0 then
				MarketplaceService:PromptProductPurchase(player, productId)
			end
		end
	end)
end

local function startShimmer(card)
	if card:GetAttribute("EditableShopShimmerStarted") == true then
		return
	end
	local shimmer = card:FindFirstChild("ShimmerBar", true)
	if not shimmer or not shimmer:IsA("GuiObject") then
		return
	end
	card:SetAttribute("EditableShopShimmerStarted", true)
	task.spawn(function()
		while shimmer.Parent do
			shimmer.Position = UDim2.new(-0.2, 0, -0.3, 0)
			local tween = TweenService:Create(
				shimmer,
				TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Position = UDim2.new(1.2, 0, -0.3, 0) }
			)
			tween:Play()
			tween.Completed:Wait()
			task.wait(1.8)
		end
	end)
end

local function startIconPulse(card)
	local itemId = card:GetAttribute("ShopItemId")
	if not PREMIUM_PULSE_IDS[itemId] or card:GetAttribute("EditableShopPulseStarted") == true then
		return
	end
	local iconCircle = card:FindFirstChild("IconCircle", true)
	if not iconCircle or not iconCircle:IsA("GuiObject") then
		return
	end
	local scale = findScale(iconCircle, "IconScale")
	card:SetAttribute("EditableShopPulseStarted", true)
	task.spawn(function()
		while iconCircle.Parent do
			tweenScale(scale, 1.08, 0.55)
			task.wait(0.55)
			tweenScale(scale, 1, 0.55)
			task.wait(1.35)
		end
	end)
end

local function updateAllCards(shopWindow)
	for _, descendant in ipairs(shopWindow:GetDescendants()) do
		if descendant:IsA("GuiObject") and descendant:GetAttribute("ShopItemId") then
			updateCardState(descendant)
			bindButton(descendant)
			if descendant.Name == "InfinitePassHeroCard" then
				startShimmer(descendant)
			end
			startIconPulse(descendant)
		end
	end
	focusInfinitePackTrack(shopWindow)
end

local function watchInfinitePackClaims(shopWindow)
	local function refresh()
		updateAllCards(shopWindow)
	end

	local function bindClaimFolder(folder)
		if not folder then
			return
		end
		if folder:GetAttribute("EditableShopClaimFolderWatched") ~= true then
			folder:SetAttribute("EditableShopClaimFolderWatched", true)
			folder.ChildAdded:Connect(function(child)
				if child.Name == "ClaimedTiers" then
					bindClaimFolder(folder)
					refresh()
				end
			end)
		end

		local claimedTiers = folder and folder:FindFirstChild("ClaimedTiers")
		if not claimedTiers or claimedTiers:GetAttribute("EditableShopClaimsWatched") == true then
			return
		end
		claimedTiers:SetAttribute("EditableShopClaimsWatched", true)
		claimedTiers.ChildAdded:Connect(refresh)
		claimedTiers.ChildRemoved:Connect(refresh)
	end

	bindClaimFolder(player:FindFirstChild("InfinitePackClaims"))
	player.ChildAdded:Connect(function(child)
		if child.Name == "InfinitePackClaims" then
			bindClaimFolder(child)
			refresh()
		end
	end)

	for _, tier in pairs(infinitePackTiersById) do
		player:GetAttributeChangedSignal("InfinitePackClaimed_" .. tostring(tier.id)):Connect(refresh)
	end
end

local function getTabs(shopWindow)
	return shopWindow:FindFirstChild("Tabs", true)
end

local function getContent(shopWindow)
	return shopWindow:FindFirstChild("Content", true)
end

local function showPage(shopWindow, pageKey)
	local content = getContent(shopWindow)
	local tabs = getTabs(shopWindow)
	if not content then
		return
	end

	for key, pageName in pairs(PAGE_NAMES) do
		local page = content:FindFirstChild(pageName)
		if page and page:IsA("GuiObject") then
			page.Visible = key == pageKey
		end
	end

	if tabs then
		for key in pairs(PAGE_NAMES) do
			local tab = tabs:FindFirstChild(key .. "Tab", true)
			if tab and tab:IsA("TextButton") then
				local active = key == pageKey
				tab.BackgroundColor3 = active and TAB_ACTIVE or TAB_INACTIVE
				tab.TextColor3 = active and Color3.fromRGB(255, 255, 255) or TEXT_DARK
			end
		end
	end
end

local function bindTabs(shopWindow)
	local tabs = getTabs(shopWindow)
	if not tabs then
		warnOnce("missing-tabs", "EditableShopBinder: ShopWindow.Tabs is missing.")
		return
	end
	for key in pairs(PAGE_NAMES) do
		local tab = tabs:FindFirstChild(key .. "Tab", true)
		if tab and tab:IsA("GuiButton") and tab:GetAttribute("EditableShopTabBound") ~= true then
			tab:SetAttribute("EditableShopTabBound", true)
			tab.Activated:Connect(function()
				showPage(shopWindow, key)
			end)
		end
	end
	showPage(shopWindow, "Featured")
end

local mainHUD = getMainHUD()
local windows = mainHUD and getWindows(mainHUD)
local shopWindow = windows and windows:WaitForChild("ShopWindow", 30)
if not shopWindow then
	warn("EditableShopBinder: missing PlayerGui.MainHUD.ModalWindows.ShopWindow")
	return
end

ensureShopLayout(shopWindow)
applyComingSoonShopSections(shopWindow)

if claimInfinitePackTierEvent and claimInfinitePackTierEvent:IsA("RemoteEvent") then
	claimInfinitePackTierEvent.OnClientEvent:Connect(function(action, tierId, payload)
		tierId = tostring(tierId or "")
		claimingInfinitePackTier[tierId] = nil
		if action == "Claimed" then
			player:SetAttribute("InfinitePackClaimed_" .. tierId, true)
		elseif payload and payload.message then
			warnOnce(
				"infinite-pack-claim-" .. tierId .. "-" .. tostring(payload.message),
				"EditableShopBinder: " .. tostring(payload.message)
			)
		end
		updateAllCards(shopWindow)
	end)
end

watchInfinitePackClaims(shopWindow)
bindTabs(shopWindow)
updateAllCards(shopWindow)
shopWindow.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("GuiObject") and descendant:GetAttribute("ShopItemId") then
		task.defer(function()
			updateCardState(descendant)
			bindButton(descendant)
			startIconPulse(descendant)
		end)
	end
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(purchasingPlayer, gamepassId, wasPurchased)
	if purchasingPlayer ~= player or not wasPurchased then
		return
	end
	for _, pass in ipairs(RobuxShopConfig.Gamepasses or {}) do
		if tonumber(pass.gamepassId) == tonumber(gamepassId) then
			ownedCache[pass.id] = true
			player:SetAttribute("Pass_" .. pass.id, true)
			break
		end
	end
	updateAllCards(shopWindow)
end)

for _, pass in ipairs(RobuxShopConfig.Gamepasses or {}) do
	player:GetAttributeChangedSignal("Pass_" .. pass.id):Connect(function()
		ownedCache[pass.id] = player:GetAttribute("Pass_" .. pass.id) == true
		updateAllCards(shopWindow)
	end)
end

print("[EditableShopBinder] Featured Robux shop bound to existing Studio UI.")
