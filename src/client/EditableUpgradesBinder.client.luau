-- Binds the editable Studio UpgradesWindow to the real upgrade system.
-- This script does not create replacement upgrade cards; it only wires the existing Studio UI.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local UpgradeData = require(ReplicatedStorage:WaitForChild("UpgradeData"))
local iconConfigModule = ReplicatedStorage:FindFirstChild("UpgradeIconConfig")
local UpgradeIconConfig = iconConfigModule and require(iconConfigModule) or { Icons = {}, ByUpgradeId = {} }

local Events = ReplicatedStorage:WaitForChild("Events")
local purchaseUpgradeEvent = Events:WaitForChild("PurchaseUpgrade")
local upgradeUpdatedEvent = Events:WaitForChild("UpgradeUpdated", 30)

local COLORS = {
	ActiveTab = Color3.fromRGB(82, 219, 225),
	InactiveTab = Color3.fromRGB(232, 238, 248),
	Green = Color3.fromRGB(72, 220, 101),
	Disabled = Color3.fromRGB(170, 178, 194),
	Text = Color3.fromRGB(38, 36, 52),
	Muted = Color3.fromRGB(92, 98, 116),
	Outline = Color3.fromRGB(35, 38, 45),
}

local CARD_UPGRADE_IDS = {
	BrushPowerCard = "BrushPower",
	BrushSizeCard = "BrushSize",
	CoinBoostCard = "ColorMultiplier",
	CoinCapacityCard = "CoinCapacity",
	CoinMultiplierCard = "ColorMultiplier",
	CritChanceCard = "CritChance",
	GemBoostCard = "GemMultiplier",
	GemCapacityCard = "GemCapacity",
	GemLuckCard = "Luck",
	GemLuckICard = "Luck",
	GemMultiplierCard = "GemMultiplier",
	GemValueCard = "GemValue",
	HealthCard = "Health",
	InventorySizeCard = "PetSlots",
	LuckCard = "Luck",
	PaintCapacityCard = "PaintCapacity",
	PaintSpeedCard = "PaintSpeed",
	PassiveIncomeCard = "PassiveIncome",
	PetSlotsCard = "PetSlots",
	PlayerPowerCard = "PlayerPower",
	SellValueCard = "SellValue",
	SplashRangeCard = "PickupRange",
	WalkSpeedCard = "WalkSpeed",
}

local TAB_CATEGORIES = {
	BrushTab = "Brush",
	ColorsTab = "Brush",
	EconomyTab = "Economy",
	PlayerTab = "Player",
	RankTab = "Economy",
}

local TAB_LABELS = {
	Brush = "Brush",
	Economy = "Economy",
	Player = "Player",
}

local upgradeLevels = {}
local cardsByUpgradeId = {}
local connectedButtons = setmetatable({}, { __mode = "k" })
local connectedTabs = setmetatable({}, { __mode = "k" })
local activeCategory = "Player"
local upgradesWindow = nil

local CARD_COLUMNS = 3
local CARD_PADDING_X = 14
local CARD_PADDING_Y = 14
local CARD_GAP_X = 14
local CARD_GAP_Y = 12
local DEFAULT_CARD_SIZE = UDim2.fromOffset(222, 118)

local function findMainHUD()
	local root = playerGui:WaitForChild("ClientUIRoot", 30)
	return root and root:WaitForChild("MainHUD", 30)
end

local function findWindowsFolder(main)
	local modal = main and main:FindFirstChild("ModalWindows")
	if modal and modal:FindFirstChild("Windows") then
		return modal.Windows
	end
	return main and main:FindFirstChild("Windows")
end

local function getContent(window)
	return window:FindFirstChild("Content", true) or window
end

local function getGems()
	local leaderstats = player:FindFirstChild("leaderstats")
	local gems = leaderstats and (leaderstats:FindFirstChild("Gems") or leaderstats:FindFirstChild("Diamonds"))
	return gems and gems.Value or 0
end

local function getLevel(upgradeId)
	local canonicalId = UpgradeData.getCanonicalId(upgradeId) or upgradeId
	if upgradeLevels[canonicalId] ~= nil then
		return upgradeLevels[canonicalId]
	end

	local folder = player:FindFirstChild("Upgrades")
	local value = folder and folder:FindFirstChild(canonicalId .. "_Level")
	return value and value.Value or 0
end

local function findNamedDescendant(root, name)
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant.Name == name then
			return descendant
		end
	end
	return nil
end

local function setText(root, name, text)
	local gui = findNamedDescendant(root, name)
	if gui and (gui:IsA("TextLabel") or gui:IsA("TextButton")) then
		gui.Text = text
	end
end

local function setTextColor(root, name, color)
	local gui = findNamedDescendant(root, name)
	if gui and (gui:IsA("TextLabel") or gui:IsA("TextButton")) then
		gui.TextColor3 = color
	end
end

local function findNameLabel(card)
	local named = findNamedDescendant(card, "Name")
	if named and named:IsA("TextLabel") then
		return named
	end

	for _, descendant in ipairs(card:GetDescendants()) do
		if descendant:IsA("TextLabel") and descendant.Name ~= "IconText" then
			return descendant
		end
	end
	return nil
end

local function findBuyButton(card)
	local named = findNamedDescendant(card, "BuyButton")
	if named and named:IsA("TextButton") then
		return named
	end

	for _, descendant in ipairs(card:GetDescendants()) do
		if descendant:IsA("TextButton") then
			return descendant
		end
	end
	return nil
end

local findUpgradeForCard

local function findCardTemplate(content, category)
	for _, descendant in ipairs(content:GetDescendants()) do
		if descendant:IsA("GuiObject") and descendant.Name:match("Card$") then
			local upgrade = findUpgradeForCard(descendant)
			if upgrade and (not category or upgrade.category == category) then
				return descendant
			end
		end
	end

	for _, descendant in ipairs(content:GetDescendants()) do
		if descendant:IsA("GuiObject") and descendant.Name:match("Card$") then
			return descendant
		end
	end
	return nil
end

function findUpgradeForCard(card)
	local attributeId = card:GetAttribute("UpgradeId")
	local upgrade = attributeId and UpgradeData.getUpgrade(tostring(attributeId))
	if upgrade then
		return upgrade
	end

	local mappedId = CARD_UPGRADE_IDS[card.Name]
	upgrade = mappedId and UpgradeData.getUpgrade(mappedId)
	if upgrade then
		return upgrade
	end

	upgrade = UpgradeData.getUpgradeByCardName(card.Name)
	if upgrade then
		return upgrade
	end

	local nameLabel = findNameLabel(card)
	if nameLabel then
		return UpgradeData.getUpgradeByCardName(nameLabel.Text)
	end
	return nil
end

local function setButtonInteractable(button, interactable)
	button.Active = interactable
	button.AutoButtonColor = interactable
	pcall(function()
		button.Interactable = interactable
	end)
end

local function applyIcon(card, upgrade)
	local iconKey = upgrade.iconKey or UpgradeIconConfig.ByUpgradeId[upgrade.id]
	local iconData = iconKey and UpgradeIconConfig.Icons[iconKey]
	if iconData then
		card:SetAttribute("ExpectedUpgradeIconFile", iconData.SourceFile or "")
	end

	local iconRoot = findNamedDescendant(card, "Icon") or card
	if iconData and iconRoot and iconRoot:IsA("GuiObject") then
		iconRoot:SetAttribute("ExpectedUpgradeIconFile", iconData.SourceFile or "")
	end

	local iconImage = findNamedDescendant(card, "IconImage")
	if not iconImage and iconRoot and iconRoot:IsA("GuiObject") then
		iconImage = Instance.new("ImageLabel")
		iconImage.Name = "IconImage"
		iconImage.BackgroundTransparency = 1
		iconImage.Size = UDim2.fromScale(1, 1)
		iconImage.ZIndex = iconRoot.ZIndex + 1
		iconImage.Parent = iconRoot
	end
	if iconImage and (iconImage:IsA("ImageLabel") or iconImage:IsA("ImageButton")) then
		local image = iconData and iconData.Image or ""
		if iconData then
			iconImage:SetAttribute("ExpectedUpgradeIconFile", iconData.SourceFile or "")
		end
		iconImage.Image = image
		iconImage.Visible = image ~= ""
		iconImage.BackgroundTransparency = 1
	end

	local iconText = findNamedDescendant(card, "IconText")
	if not iconText and iconRoot and iconRoot:IsA("GuiObject") then
		iconText = Instance.new("TextLabel")
		iconText.Name = "IconText"
		iconText.BackgroundTransparency = 1
		iconText.Size = UDim2.fromScale(1, 1)
		iconText.Font = Enum.Font.GothamBlack
		iconText.TextColor3 = COLORS.Text
		iconText.TextScaled = true
		iconText.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
		iconText.TextStrokeTransparency = 0.35
		iconText.ZIndex = iconRoot.ZIndex + 2
		iconText.Parent = iconRoot
	end
	if iconText and iconText:IsA("TextLabel") then
		iconText.Text = tostring(upgrade.icon or "")
		if iconImage and iconImage.Visible then
			iconText.Visible = false
		else
			iconText.Visible = true
		end
	end
end

local function layoutVisibleCards()
	local categoryUpgrades = UpgradeData.getCategoryUpgrades(activeCategory)
	for index, upgrade in ipairs(categoryUpgrades) do
		local card = cardsByUpgradeId[upgrade.id]
		if card then
			local cardSize = card.Size
			if cardSize == UDim2.fromScale(0, 0) then
				cardSize = DEFAULT_CARD_SIZE
				card.Size = cardSize
			end

			local column = (index - 1) % CARD_COLUMNS
			local row = math.floor((index - 1) / CARD_COLUMNS)
			card.Position = UDim2.fromOffset(
				CARD_PADDING_X + column * ((cardSize.X.Offset > 0 and cardSize.X.Offset or 222) + CARD_GAP_X),
				CARD_PADDING_Y + row * ((cardSize.Y.Offset > 0 and cardSize.Y.Offset or 118) + CARD_GAP_Y)
			)
			card.LayoutOrder = index
		end
	end
end

local function updateCard(upgradeId)
	local canonicalId = UpgradeData.getCanonicalId(upgradeId) or upgradeId
	local card = cardsByUpgradeId[canonicalId]
	local upgrade = UpgradeData.getUpgrade(canonicalId)
	if not card or not upgrade then
		return
	end

	local level = getLevel(canonicalId)
	local maxLevel = #(upgrade.levels or {})
	local nextData = UpgradeData.getNextLevelData(canonicalId, level)
	local priceText = "MAX"
	local buttonText = "MAX"
	local canBuy = false

	if nextData then
		local cost = math.max(0, math.floor(tonumber(nextData.cost) or 0))
		local currencyName = nextData.currency or upgrade.currency or "Gems"
		priceText = UpgradeData.formatNumber(cost) .. " " .. currencyName
		canBuy = getGems() >= cost
		buttonText = canBuy and "BUY" or "NEED"
	end

	card:SetAttribute("UpgradeId", canonicalId)
	card.Visible = upgrade.category == activeCategory
	applyIcon(card, upgrade)

	setText(card, "Name", upgrade.displayName)
	setText(card, "Description", "Lv. " .. tostring(level) .. "/" .. tostring(maxLevel) .. " - " .. upgrade.description)
	setText(card, "Price", priceText)
	setText(card, "Level", "Lv. " .. tostring(level) .. "/" .. tostring(maxLevel))
	setText(card, "CurrentValue", "Now: " .. UpgradeData.getValueDisplay(canonicalId, level))
	setText(card, "NextValue", nextData and ("Next: " .. UpgradeData.getValueDisplay(canonicalId, level + 1)) or "Maxed")

	local buy = findBuyButton(card)
	if buy then
		buy.Text = buttonText
		buy.BackgroundColor3 = nextData and canBuy and COLORS.Green or COLORS.Disabled
		setButtonInteractable(buy, nextData ~= nil)
	end
end

local function updateTabs()
	if not upgradesWindow then
		return
	end

	local tabs = upgradesWindow:FindFirstChild("Tabs", true)
	if not tabs then
		return
	end

	for _, child in ipairs(tabs:GetChildren()) do
		if child:IsA("TextButton") then
			local category = TAB_CATEGORIES[child.Name]
			if category then
				child.Text = TAB_LABELS[category] or category
				child.BackgroundColor3 = category == activeCategory and COLORS.ActiveTab or COLORS.InactiveTab
				child.TextColor3 = COLORS.Text
			end
		end
	end
end

local function updateAllCards()
	for upgradeId in pairs(cardsByUpgradeId) do
		updateCard(upgradeId)
	end
	layoutVisibleCards()
	updateTabs()
end

local function bindCard(card, upgrade)
	local canonicalId = UpgradeData.getCanonicalId(upgrade.id) or upgrade.id
	cardsByUpgradeId[canonicalId] = card
	card:SetAttribute("UpgradeId", canonicalId)
	applyIcon(card, upgrade)

	local buy = findBuyButton(card)
	if buy and not connectedButtons[buy] then
		connectedButtons[buy] = true
		buy.Activated:Connect(function()
			local level = getLevel(canonicalId)
			if not UpgradeData.getNextLevelData(canonicalId, level) then
				return
			end
			purchaseUpgradeEvent:FireServer(canonicalId)
		end)
	end
	updateCard(canonicalId)
end

local function bindTabs(window)
	local tabs = window:FindFirstChild("Tabs", true)
	if not tabs then
		return
	end

	for _, child in ipairs(tabs:GetChildren()) do
		if child:IsA("TextButton") then
			local category = TAB_CATEGORIES[child.Name]
			if category and not connectedTabs[child] then
				connectedTabs[child] = true
				child.Activated:Connect(function()
					activeCategory = category
					updateAllCards()
				end)
			end
		end
	end
	updateTabs()
end

local function bindExistingCards(window)
	local content = getContent(window)
	cardsByUpgradeId = {}

	for _, descendant in ipairs(content:GetDescendants()) do
		if descendant:IsA("GuiObject") and descendant.Name:match("Card$") then
			local upgrade = findUpgradeForCard(descendant)
			if upgrade then
				bindCard(descendant, upgrade)
			end
		end
	end

	for _, upgrade in ipairs(UpgradeData.Upgrades or {}) do
		local canonicalId = UpgradeData.getCanonicalId(upgrade.id) or upgrade.id
		if not cardsByUpgradeId[canonicalId] then
			local template = findCardTemplate(content, upgrade.category)
			if template then
				local card = template:Clone()
				card.Name = canonicalId .. "Card"
				card.Parent = template.Parent
				bindCard(card, upgrade)
			end
		end
	end

	updateAllCards()
end

local main = findMainHUD()
local windows = findWindowsFolder(main)
upgradesWindow = windows and windows:WaitForChild("UpgradesWindow", 30)

if upgradesWindow then
	bindTabs(upgradesWindow)
	bindExistingCards(upgradesWindow)
	print("[EditableUpgradesBinder] UpgradesWindow bound to Gem upgrades.")
else
	warn("EditableUpgradesBinder: UpgradesWindow missing; no runtime window will be created.")
end

if upgradeUpdatedEvent then
	upgradeUpdatedEvent.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		if type(payload.Levels) == "table" then
			for upgradeId, level in pairs(payload.Levels) do
				local canonicalId = UpgradeData.getCanonicalId(tostring(upgradeId)) or tostring(upgradeId)
				upgradeLevels[canonicalId] = tonumber(level) or 0
			end
		end
		updateAllCards()
		if payload.Message and payload.Success == false then
			warn("Upgrade failed: " .. tostring(payload.Message))
		end
	end)
end

purchaseUpgradeEvent.OnClientEvent:Connect(function(success, _upgradeId, message)
	if success == false and message then
		warn("Upgrade failed: " .. tostring(message))
	end
end)

local leaderstats = player:WaitForChild("leaderstats", 30)
if leaderstats then
	for _, currencyName in ipairs({ "Gems", "Diamonds" }) do
		local value = leaderstats:FindFirstChild(currencyName)
		if value then
			value:GetPropertyChangedSignal("Value"):Connect(updateAllCards)
		end
	end
	leaderstats.ChildAdded:Connect(function(child)
		if child.Name == "Gems" or child.Name == "Diamonds" then
			child:GetPropertyChangedSignal("Value"):Connect(updateAllCards)
			updateAllCards()
		end
	end)
end

local upgradesFolder = player:WaitForChild("Upgrades", 30)
if upgradesFolder then
	upgradesFolder.ChildAdded:Connect(function(child)
		if child:IsA("IntValue") and child.Name:find("_Level") then
			child:GetPropertyChangedSignal("Value"):Connect(updateAllCards)
			updateAllCards()
		end
	end)
	for _, child in ipairs(upgradesFolder:GetChildren()) do
		if child:IsA("IntValue") and child.Name:find("_Level") then
			child:GetPropertyChangedSignal("Value"):Connect(updateAllCards)
		end
	end
end
