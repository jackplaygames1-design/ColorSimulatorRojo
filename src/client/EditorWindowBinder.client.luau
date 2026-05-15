-- Disabled: no fallback window content should be created at runtime.
if true then
	return
end

-- Binds editor-built MainHUD.Windows to live player data.
-- This script does not create ScreenGuis or rebuild top-level window frames.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ColorData = require(ReplicatedStorage:WaitForChild("ColorData"))
local ItemsData = require(ReplicatedStorage:WaitForChild("ItemsData"))
local PetData = require(ReplicatedStorage:WaitForChild("PetData"))
local RobuxShopConfig = require(ReplicatedStorage:WaitForChild("RobuxShopConfig"))
local SettingsData = require(ReplicatedStorage:WaitForChild("SettingsData"))
local ToolData = require(ReplicatedStorage:WaitForChild("ToolData"))
local UpgradeData = require(ReplicatedStorage:WaitForChild("UpgradeData"))
local Modules = ReplicatedStorage:WaitForChild("Modules")
local PetDefinitions = require(Modules:WaitForChild("PetDefinitions"))
local PetModelUtil = require(Modules:WaitForChild("PetModelUtil"))

local Events = ReplicatedStorage:WaitForChild("Events")
local equipPetEvent = Events:WaitForChild("EquipPet")
local lockPetEvent = Events:WaitForChild("LockPet")
local deletePetEvent = Events:WaitForChild("DeletePet")
local petsLoadedEvent = Events:WaitForChild("PetsLoaded")
local equipPaintToolEvent = Events:WaitForChild("EquipPaintTool")
local useItemEvent = Events:WaitForChild("UseItem")
local purchaseUpgradeEvent = Events:WaitForChild("PurchaseUpgrade")
local unlockAreaEvent = Events:WaitForChild("UnlockArea")
local requestTravelToSectorEvent = Events:WaitForChild("RequestTravelToSector")
local requestSetSettingEvent = Events:WaitForChild("RequestSetSetting")
local settingsUpdatedEvent = Events:WaitForChild("SettingsUpdated")
local redeemCodeEvent = Events:WaitForChild("RedeemCode")
local dailyQuestRemote = ReplicatedStorage:WaitForChild("DailyQuestRemote", 10)

local LEGACY_ROOT_LAYERS = {
	InventoryUI = true,
	ShopUI = true,
	WorldUI = true,
	GamepassUI = true,
	DailyQuestGui = true,
	CodesUI = true,
}

local TAB_NAMES = { "Colors", "Brushes", "Potions", "Items" }
local RARITY_ORDER = { Legendary = 1, Epic = 2, Rare = 3, Uncommon = 4, Common = 5 }
local BIND_INVENTORY_WINDOW = false
local BIND_WORLDS_WINDOW = false
local BIND_DAILY_QUESTS_WINDOW = false
local FALLBACK_DAILY_QUESTS = {
	{
		id = "CleanColorSpills",
		title = "CLEAN COLOR SPILLS",
		description = "Clean 40 color spills.",
		iconText = "BRUSH",
		progress = 0,
		target = 40,
		rewardCurrency = "Gems",
		rewardAmount = 20,
		reward = 20,
		claimed = false,
	},
	{
		id = "EarnCoins",
		title = "EARN COINS",
		description = "Earn 1,000 coins.",
		iconText = "COINS",
		progress = 0,
		target = 1000,
		rewardCurrency = "Gems",
		rewardAmount = 25,
		reward = 25,
		claimed = false,
	},
	{
		id = "HatchColors",
		title = "HATCH COLORS",
		description = "Hatch 3 colors from eggs.",
		iconText = "EGG",
		progress = 0,
		target = 3,
		rewardCurrency = "Gems",
		rewardAmount = 30,
		reward = 30,
		claimed = false,
	},
}

local root = playerGui:WaitForChild("ClientUIRoot", 15)
if not root then
	warn("EditorWindowBinder: missing PlayerGui.ClientUIRoot")
	return
end

local mainHud = root:WaitForChild("MainHUD", 15)
if not mainHud then
	warn("EditorWindowBinder: missing ClientUIRoot.MainHUD")
	return
end

local modalWindows = mainHud:WaitForChild("ModalWindows", 10)
local windows = modalWindows and modalWindows:WaitForChild("Windows", 10) or mainHud:FindFirstChild("Windows")
if not windows then
	warn("EditorWindowBinder: missing MainHUD.ModalWindows.Windows")
	return
end
if not modalWindows then
	warn("EditorWindowBinder: using legacy MainHUD.Windows. Expected MainHUD.ModalWindows.Windows.")
end

local inventoryWindow = windows:WaitForChild("InventoryWindow", 10)
if not inventoryWindow or not inventoryWindow:IsA("GuiObject") then
	warn("EditorWindowBinder: missing MainHUD.ModalWindows.Windows.InventoryWindow")
	return
end

local petFolder = player:WaitForChild("PetData", 10)
local petInventoryValue = petFolder and petFolder:WaitForChild("Inventory", 10)
local petEquippedValue = petFolder and petFolder:WaitForChild("Equipped", 10)

local paintToolsFolder = player:WaitForChild("PaintTools", 10)
local ownedPaintToolsValue = paintToolsFolder and paintToolsFolder:WaitForChild("Owned", 10)
local equippedPaintToolValue = paintToolsFolder and paintToolsFolder:WaitForChild("Equipped", 10)

local currentTab = "Colors"
local currentShopTab = "Gamepasses"
local SHOP_GAMEPASS_IDS = {
	VIP = true,
	DoubleCoins = true,
	LuckyHatch = true,
}
local colorEntries = {}
local equippedColors = {}
local lockedColors = {}
local playerItems = {}
local selectedEntry = nil

local ui = {}
local connections = {}

local function disconnectAll(list)
	for _, connection in ipairs(list) do
		if connection and connection.Connected then
			connection:Disconnect()
		end
	end
	table.clear(list)
end

local function hideLegacyRootLayers()
	for _, child in ipairs(root:GetChildren()) do
		if LEGACY_ROOT_LAYERS[child.Name] and child:IsA("GuiObject") then
			child.Visible = false
		end
	end
end

local function requestEditorWindow(windowName)
	root:SetAttribute("RequestedWindow", windowName)
	root:SetAttribute("RequestedWindowNonce", os.clock())
	hideLegacyRootLayers()
end

local function ensureFrame(parent, name, position, size, color)
	local frame = parent:FindFirstChild(name)
	if frame and frame:IsA("GuiObject") then
		return frame
	end

	frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = color or Color3.fromRGB(246, 249, 255)
	frame.BorderSizePixel = 0
	frame.Position = position or UDim2.fromScale(0, 0)
	frame.Size = size or UDim2.fromScale(1, 1)
	frame.Parent = parent
	return frame
end

local function ensureLabel(parent, name, text, position, size, textSize)
	local label = parent:FindFirstChild(name)
	if label and label:IsA("TextLabel") then
		return label
	end

	label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(38, 36, 52)
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextSize = textSize or 16
	label.Text = text or ""
	label.Position = position or UDim2.fromScale(0, 0)
	label.Size = size or UDim2.fromScale(1, 0)
	label.Parent = parent
	return label
end

local function ensureButton(parent, name, text, position, size)
	local button = parent:FindFirstChild(name)
	if button and button:IsA("TextButton") then
		return button
	end

	button = Instance.new("TextButton")
	button.Name = name
	button.AutoButtonColor = true
	button.BackgroundColor3 = Color3.fromRGB(84, 225, 112)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBlack
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextStrokeColor3 = Color3.fromRGB(35, 38, 45)
	button.TextStrokeTransparency = 0
	button.TextSize = 16
	button.Text = text or "OK"
	button.Position = position or UDim2.fromScale(0, 0)
	button.Size = size or UDim2.fromOffset(120, 34)
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button

	return button
end

local function findGuiObject(parent, name)
	local object = parent and parent:FindFirstChild(name)
	if object and object:IsA("GuiObject") then
		return object
	end
	return nil
end

local function setButtonEnabled(button, enabled)
	if not button then
		return
	end
	button.Visible = true
	button.Active = enabled
	button.AutoButtonColor = enabled
	button.BackgroundTransparency = enabled and 0 or 0.35
end

local function connectPress(guiObject, callback)
	if not guiObject then
		return
	end
	if guiObject:IsA("GuiButton") then
		guiObject.Active = true
		guiObject.Activated:Connect(callback)
	else
		guiObject.Active = true
		guiObject.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				callback()
			end
		end)
	end
end

local function getEntryKey(entry)
	if typeof(entry) == "table" then
		return entry.variantKey or entry.petId
	end
	return tostring(entry or "")
end

local function parsePetInventoryValue(value)
	local entries = {}
	if not value or value == "" then
		return entries
	end

	for _, encoded in ipairs(string.split(value, ",")) do
		if encoded == "" then
			continue
		end

		local segments = string.split(encoded, ":")
		local variantKey
		local petId
		local stackIndex
		if tonumber(segments[2]) then
			petId = segments[1]
			stackIndex = 2
		else
			variantKey = segments[1]
			petId = segments[2]
			stackIndex = 3
		end

		if petId and petId ~= "" then
			local stackAmount = tonumber(segments[stackIndex]) or 1
			local traitId = PetData.normalizeTraitId(segments[stackIndex + 1])
			local shinyStr = segments[stackIndex + 2] or "normal"
			local personalityId = PetData.normalizePersonalityId(segments[stackIndex + 3] or "Neutral")
			local mutationId = PetData.normalizeMutationId(segments[stackIndex + 4] or "None")
			variantKey = variantKey or PetData.makeVariantKey(petId, personalityId, mutationId, traitId)

			local entry = PetData.buildPetEntry(
				petId,
				math.max(1, stackAmount),
				shinyStr == "shiny" or shinyStr == "true",
				personalityId,
				mutationId,
				traitId
			)
			if entry then
				entry.variantKey = variantKey
				entry.effectivePower = entry.finalPower
				table.insert(entries, entry)
			end
		end
	end

	return entries
end

local function parseEquippedValue(value)
	local equipped = {}
	for _, variantKey in ipairs(string.split(value or "", ",")) do
		if variantKey ~= "" then
			table.insert(equipped, variantKey)
		end
	end
	return equipped
end

local function parseLockedValue(value)
	local locked = {}
	for _, variantKey in ipairs(string.split(value or "", ",")) do
		if variantKey ~= "" then
			locked[variantKey] = true
		end
	end
	return locked
end

local function isColorEquipped(entry)
	local key = getEntryKey(entry)
	for _, equippedKey in ipairs(equippedColors) do
		if equippedKey == key then
			return true
		end
	end
	return false
end

local function isColorLocked(entry)
	return lockedColors[getEntryKey(entry)] == true or entry.isLocked == true
end

local function getOwnedPaintToolSet()
	local set = { StarterBrush = true }
	local csv = ownedPaintToolsValue and ownedPaintToolsValue.Value or "StarterBrush"
	for _, toolId in ipairs(string.split(csv, ",")) do
		if toolId ~= "" then
			set[toolId] = true
		end
	end
	return set
end

local function getEquippedPaintToolId()
	if equippedPaintToolValue and equippedPaintToolValue.Value ~= "" then
		return equippedPaintToolValue.Value
	end
	return "StarterBrush"
end

local function isPotion(item)
	return item and (item.boostType ~= nil or item.category == "Boosts")
end

local function setItemQuantity(itemId, quantity)
	quantity = tonumber(quantity) or 0
	if quantity > 0 then
		playerItems[itemId] = quantity
	else
		playerItems[itemId] = nil
	end
end

local function clearList()
	if not ui.list then
		return
	end
	disconnectAll(connections)
	for _, child in ipairs(ui.list:GetChildren()) do
		if not child:IsA("UIGridLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function ensureInventoryStructure()
	ui.tabs = findGuiObject(inventoryWindow, "Tabs")
		or ensureFrame(inventoryWindow, "Tabs", UDim2.fromOffset(22, 68), UDim2.new(1, -44, 0, 40))
	ui.content = findGuiObject(inventoryWindow, "Content")
		or ensureFrame(inventoryWindow, "Content", UDim2.fromOffset(22, 122), UDim2.new(1, -44, 1, -148))
	ui.gridRoot = findGuiObject(ui.content, "ItemGrid")
		or ensureFrame(ui.content, "ItemGrid", UDim2.fromOffset(12, 12), UDim2.new(0.62, -20, 1, -24))
	ui.details = findGuiObject(inventoryWindow, "DetailsPanel")
		or findGuiObject(ui.content, "DetailsPanel")
		or ensureFrame(inventoryWindow, "DetailsPanel", UDim2.new(0.64, 0, 0, 122), UDim2.new(0.36, -34, 1, -148))

	for _, child in ipairs(ui.gridRoot:GetChildren()) do
		if child:IsA("GuiObject") and child.Name ~= "BinderList" then
			child.Visible = false
		end
	end

	ui.list = ui.gridRoot:FindFirstChild("BinderList")
	if not ui.list or not ui.list:IsA("ScrollingFrame") then
		ui.list = Instance.new("ScrollingFrame")
		ui.list.Name = "BinderList"
		ui.list.BackgroundTransparency = 1
		ui.list.BorderSizePixel = 0
		ui.list.Position = UDim2.fromScale(0, 0)
		ui.list.Size = UDim2.fromScale(1, 1)
		ui.list.CanvasSize = UDim2.fromOffset(0, 0)
		ui.list.ScrollBarThickness = 6
		ui.list.Parent = ui.gridRoot
	end

	local layout = ui.list:FindFirstChildOfClass("UIGridLayout") or Instance.new("UIGridLayout")
	layout.CellPadding = UDim2.fromOffset(10, 10)
	layout.CellSize = UDim2.fromOffset(130, 112)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = ui.list
	if not ui.list:GetAttribute("BinderLayoutConnected") then
		ui.list:SetAttribute("BinderLayoutConnected", true)
		layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			ui.list.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 18)
		end)
	end

	local padding = ui.list:FindFirstChildOfClass("UIPadding") or Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = ui.list

	ui.templates = inventoryWindow:FindFirstChild("Templates") or Instance.new("Folder")
	ui.templates.Name = "Templates"
	ui.templates.Parent = inventoryWindow

	ui.cardTemplate = ui.templates:FindFirstChild("ItemCardTemplate")
	if not ui.cardTemplate or not ui.cardTemplate:IsA("GuiObject") then
		local template = Instance.new("Frame")
		template.Name = "ItemCardTemplate"
		template.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		template.BorderSizePixel = 0
		template.Size = UDim2.fromOffset(130, 112)
		template.Visible = false
		template.Parent = ui.templates

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = template

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(35, 38, 45)
		stroke.Thickness = 2
		stroke.Parent = template

		ensureLabel(template, "IconText", "IT", UDim2.fromOffset(8, 8), UDim2.fromOffset(40, 28), 18).TextXAlignment =
			Enum.TextXAlignment.Center
		ensureLabel(template, "Name", "Item", UDim2.fromOffset(8, 38), UDim2.new(1, -16, 0, 32), 13)
		ensureLabel(template, "Meta", "Meta", UDim2.fromOffset(8, 72), UDim2.new(1, -16, 0, 28), 11)
		ui.cardTemplate = template
	else
		ui.cardTemplate.Visible = false
	end

	ui.detailTitle =
		ensureLabel(ui.details, "SelectLabel", "Select an Item", UDim2.fromOffset(14, 12), UDim2.new(1, -28, 0, 36), 22)
	ui.detailTitle.TextXAlignment = Enum.TextXAlignment.Center
	ui.detailName = ensureLabel(ui.details, "NameLabel", "", UDim2.fromOffset(14, 54), UDim2.new(1, -28, 0, 36), 20)
	ui.detailMeta = ensureLabel(ui.details, "MetaLabel", "", UDim2.fromOffset(14, 92), UDim2.new(1, -28, 0, 38), 14)
	ui.detailDescription = ensureLabel(
		ui.details,
		"DescriptionLabel",
		"Choose a card to see details.",
		UDim2.fromOffset(14, 136),
		UDim2.new(1, -28, 0, 96),
		14
	)
	ui.detailStats = ensureLabel(ui.details, "StatsLabel", "", UDim2.fromOffset(14, 238), UDim2.new(1, -28, 0, 90), 13)
	ui.actionButton =
		ensureButton(ui.details, "EquipButton", "EQUIP", UDim2.new(0, 14, 1, -132), UDim2.new(1, -28, 0, 34))
	ui.lockButton =
		ensureButton(ui.details, "LockButton", "COMING SOON", UDim2.new(0, 14, 1, -90), UDim2.new(1, -28, 0, 34))
	ui.deleteButton =
		ensureButton(ui.details, "DeleteButton", "COMING SOON", UDim2.new(0, 14, 1, -48), UDim2.new(1, -28, 0, 34))

	connectPress(ui.actionButton, function()
		if not selectedEntry then
			return
		end

		if selectedEntry.kind == "Color" then
			if isColorEquipped(selectedEntry.entry) then
				equipPetEvent:FireServer("unequip", getEntryKey(selectedEntry.entry))
			else
				equipPetEvent:FireServer("equip", getEntryKey(selectedEntry.entry))
			end
		elseif selectedEntry.kind == "Brush" then
			equipPaintToolEvent:FireServer(selectedEntry.tool.Id, true)
		elseif selectedEntry.kind == "Item" and selectedEntry.item.usable then
			useItemEvent:FireServer(selectedEntry.itemId, 1)
		end
	end)

	connectPress(ui.lockButton, function()
		if selectedEntry and selectedEntry.kind == "Color" then
			local entry = selectedEntry.entry
			lockPetEvent:FireServer(getEntryKey(entry), not isColorLocked(entry))
		end
	end)
	connectPress(ui.deleteButton, function()
		if selectedEntry and selectedEntry.kind == "Color" then
			deletePetEvent:FireServer(getEntryKey(selectedEntry.entry))
		end
	end)
end

local function setTabVisuals()
	for _, tabName in ipairs(TAB_NAMES) do
		local tab = ui.tabs and ui.tabs:FindFirstChild(tabName .. "Tab")
		if tab and tab:IsA("TextButton") then
			local active = tabName == currentTab
			tab.BackgroundColor3 = active and Color3.fromRGB(82, 219, 225) or Color3.fromRGB(232, 238, 248)
			tab.TextColor3 = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(38, 36, 52)
		end
	end
end

local function setDetailsEmpty(message)
	selectedEntry = nil
	ui.detailTitle.Text = "Select an Item"
	ui.detailName.Text = ""
	ui.detailMeta.Text = ""
	ui.detailDescription.Text = message or "Choose a card to see details."
	ui.detailStats.Text = ""
	ui.actionButton.Text = "SELECT"
	setButtonEnabled(ui.actionButton, false)
	ui.lockButton.Text = "COMING SOON"
	ui.deleteButton.Text = "COMING SOON"
	setButtonEnabled(ui.lockButton, false)
	setButtonEnabled(ui.deleteButton, false)
end

local function setDetailsForColor(entry)
	selectedEntry = { kind = "Color", entry = entry }
	local pet = PetData.Pets[entry.petId] or {}
	local definition = PetDefinitions.Get(entry.petId)
	local equipped = isColorEquipped(entry)
	local locked = isColorLocked(entry)

	ui.detailTitle.Text = "Color Details"
	ui.detailName.Text = entry.displayName or pet.displayName or entry.petId
	ui.detailMeta.Text = tostring(entry.rarity or pet.rarity or "Unknown")
		.. " | x"
		.. PetData.formatStack(entry.stackAmount or 1)
	ui.detailDescription.Text = tostring(entry.traitName or "Neutral")
		.. ": "
		.. tostring(entry.traitDescription or "No special trait.")
	ui.detailStats.Text = table.concat({
		"Power: " .. tostring(entry.effectivePower or entry.finalPower or 0),
		"Color Gain: x" .. string.format("%.2f", tonumber(entry.colorMult) or 1),
		"Sell Value: x" .. string.format("%.2f", tonumber(entry.coinMult) or 1),
		"Model: " .. tostring((definition and definition.ModelName) or pet.modelName or entry.petId),
	}, "\n")
	ui.actionButton.Text = equipped and "UNEQUIP" or "EQUIP"
	setButtonEnabled(ui.actionButton, true)
	ui.lockButton.Text = locked and "UNLOCK" or "LOCK"
	ui.deleteButton.Text = "DELETE"
	setButtonEnabled(ui.lockButton, true)
	setButtonEnabled(ui.deleteButton, not locked and not equipped)
end

local function setDetailsForBrush(tool)
	selectedEntry = { kind = "Brush", tool = tool }
	local equipped = getEquippedPaintToolId() == tool.Id

	ui.detailTitle.Text = "Brush Details"
	ui.detailName.Text = tool.DisplayName or tool.Id
	ui.detailMeta.Text = tostring(tool.Rarity or "Common") .. " | " .. tostring(tool.World or "World")
	ui.detailDescription.Text = tostring(tool.Description or tool.PassiveDescription or "Paint tool.")
	ui.detailStats.Text = table.concat({
		"Power: x" .. string.format("%.2f", tonumber(tool.PowerMultiplier) or 1),
		"Range: " .. tostring(tool.Range or "-"),
		"Width: " .. tostring(tool.Width or "-"),
		"Cooldown: " .. tostring(tool.Cooldown or "-"),
	}, "\n")
	ui.actionButton.Text = equipped and "EQUIPPED" or "EQUIP"
	setButtonEnabled(ui.actionButton, not equipped)
	ui.lockButton.Text = "LOCK COMING SOON"
	ui.deleteButton.Text = "DELETE COMING SOON"
	setButtonEnabled(ui.lockButton, false)
	setButtonEnabled(ui.deleteButton, false)
end

local function setDetailsForItem(itemId, item, quantity)
	selectedEntry = { kind = "Item", itemId = itemId, item = item }
	local usable = item.usable == true

	ui.detailTitle.Text = isPotion(item) and "Potion Details" or "Item Details"
	ui.detailName.Text = item.displayName or itemId
	ui.detailMeta.Text = tostring(item.rarity or "Common") .. " | x" .. ItemsData.formatNum(quantity or 0)
	ui.detailDescription.Text = tostring(item.description or "Inventory item.")
	ui.detailStats.Text = item.boostType
			and ("Boost: " .. tostring(item.boostType) .. "\nDuration: " .. tostring(item.boostDuration or 0) .. "s")
		or ""
	ui.actionButton.Text = usable and "USE" or "INFO"
	setButtonEnabled(ui.actionButton, usable)
	ui.lockButton.Text = "LOCKED"
	ui.deleteButton.Text = "DELETE COMING SOON"
	setButtonEnabled(ui.lockButton, false)
	setButtonEnabled(ui.deleteButton, false)
end

local function makeCard(layoutOrder, icon, title, meta, color, callback)
	local card = ui.cardTemplate:Clone()
	card.Name = "InventoryCard_" .. tostring(layoutOrder)
	card.Visible = true
	card.LayoutOrder = layoutOrder
	card.Parent = ui.list
	card.Active = true

	local stroke = card:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = color or Color3.fromRGB(35, 38, 45)
	end

	local iconLabel = card:FindFirstChild("IconText", true)
	if iconLabel and iconLabel:IsA("TextLabel") then
		iconLabel.Text = icon
		iconLabel.TextColor3 = color or Color3.fromRGB(38, 36, 52)
	end

	local nameLabel = card:FindFirstChild("Name", true)
	if nameLabel and nameLabel:IsA("TextLabel") then
		nameLabel.Text = title
	end

	local metaLabel = card:FindFirstChild("Meta", true)
	if metaLabel and metaLabel:IsA("TextLabel") then
		metaLabel.Text = meta
	end

	local viewport = card:FindFirstChildWhichIsA("ViewportFrame", true)
	if viewport and callback and string.sub(icon, 1, 1) ~= "" then
		-- PetModelUtil is intentionally used only when the editable template has a viewport slot.
		-- Text/color cards remain the fallback for simple Studio templates.
	end

	local connection
	connection = card.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			callback()
		end
	end)
	table.insert(connections, connection)

	return card
end

local function makeEmptyInventoryCard(message)
	makeCard(
		1,
		"--",
		message or "No items yet",
		"Come back after you earn one.",
		Color3.fromRGB(170, 180, 205),
		function() end
	)
end

local function refreshColors()
	table.sort(colorEntries, function(a, b)
		local rarityCompare = (RARITY_ORDER[a.rarity] or 99) < (RARITY_ORDER[b.rarity] or 99)
		if (RARITY_ORDER[a.rarity] or 99) ~= (RARITY_ORDER[b.rarity] or 99) then
			return rarityCompare
		end
		return (a.effectivePower or a.finalPower or 0) > (b.effectivePower or b.finalPower or 0)
	end)

	local count = 0
	for _, entry in ipairs(colorEntries) do
		count += 1
		local pet = PetData.Pets[entry.petId] or {}
		local definition = PetDefinitions.Get(entry.petId)
		local displayName = entry.displayName or pet.displayName or entry.petId
		local color = (definition and definition.IconColor)
			or entry.baseColor
			or pet.color
			or Color3.fromRGB(170, 180, 205)
		local icon = string.upper(string.sub(displayName, 1, 2))
		local equippedText = isColorEquipped(entry) and " | EQUIPPED" or ""
		local lockedText = isColorLocked(entry) and " | LOCKED" or ""
		local meta = tostring(entry.rarity or pet.rarity or "Color")
			.. " x"
			.. PetData.formatStack(entry.stackAmount or 1)
			.. equippedText
			.. lockedText
		local card = makeCard(count, icon, displayName, meta, color, function()
			setDetailsForColor(entry)
		end)
		local viewport = card:FindFirstChildWhichIsA("ViewportFrame", true)
		if viewport then
			pcall(function()
				PetModelUtil.MountViewport(viewport, entry.petId, { spin = false })
			end)
		end
	end

	return count
end

local function refreshBrushes()
	local owned = getOwnedPaintToolSet()
	local count = 0
	for _, toolId in ipairs(ToolData.Order or {}) do
		local tool = ToolData.Tools[toolId]
		if tool and owned[toolId] then
			count += 1
			local color = ToolData.RarityColors and ToolData.RarityColors[tool.Rarity or "Common"]
				or tool.PaintColor
				or Color3.fromRGB(82, 219, 225)
			local equippedText = getEquippedPaintToolId() == tool.Id and " | EQUIPPED" or ""
			makeCard(
				count,
				tool.ShortName or "BR",
				tool.DisplayName or tool.Id,
				tostring(tool.Rarity or "Brush") .. equippedText,
				color,
				function()
					setDetailsForBrush(tool)
				end
			)
		end
	end
	return count
end

local function getSortedOwnedItems(wantPotions)
	local list = {}
	for itemId, quantity in pairs(playerItems) do
		local item = ItemsData.Items[itemId]
		if item and quantity > 0 and isPotion(item) == wantPotions then
			table.insert(list, { id = itemId, item = item, quantity = quantity })
		end
	end
	table.sort(list, function(a, b)
		local rarityA = ItemsData.Rarities[a.item.rarity or "Common"]
		local rarityB = ItemsData.Rarities[b.item.rarity or "Common"]
		local orderA = rarityA and rarityA.order or 99
		local orderB = rarityB and rarityB.order or 99
		if orderA ~= orderB then
			return orderA > orderB
		end
		return (a.item.displayName or a.id) < (b.item.displayName or b.id)
	end)
	return list
end

local function refreshItems(wantPotions)
	local list = getSortedOwnedItems(wantPotions)
	for index, entry in ipairs(list) do
		local rarity = ItemsData.Rarities[entry.item.rarity or "Common"]
		makeCard(
			index,
			entry.item.icon or "IT",
			entry.item.displayName or entry.id,
			"x" .. ItemsData.formatNum(entry.quantity),
			rarity and rarity.color or Color3.fromRGB(170, 180, 205),
			function()
				setDetailsForItem(entry.id, entry.item, entry.quantity)
			end
		)
	end
	return #list
end

local function refreshInventory()
	if not ui.list then
		return
	end

	clearList()
	setTabVisuals()

	local count = 0
	if currentTab == "Colors" then
		count = refreshColors()
	elseif currentTab == "Brushes" then
		count = refreshBrushes()
	elseif currentTab == "Potions" then
		count = refreshItems(true)
	elseif currentTab == "Items" then
		count = refreshItems(false)
	end

	if count == 0 then
		makeEmptyInventoryCard("No items yet")
		setDetailsEmpty("No items yet.")
	elseif not selectedEntry then
		setDetailsEmpty("Choose a card to see details.")
	end
end

local function setTab(tabName)
	currentTab = tabName
	selectedEntry = nil
	refreshInventory()
end

local function wireTabs()
	for _, tabName in ipairs(TAB_NAMES) do
		local tab = ui.tabs:FindFirstChild(tabName .. "Tab")
		if not tab or not tab:IsA("TextButton") then
			tab = ensureButton(ui.tabs, tabName .. "Tab", tabName, UDim2.fromOffset(0, 0), UDim2.fromOffset(118, 34))
		end
		connectPress(tab, function()
			setTab(tabName)
		end)
	end
end

local function refreshPetsFromValues()
	if petInventoryValue then
		colorEntries = parsePetInventoryValue(petInventoryValue.Value)
	end
	if petEquippedValue then
		equippedColors = parseEquippedValue(petEquippedValue.Value)
	end
	local lockedValue = petFolder and petFolder:FindFirstChild("Locked")
	if lockedValue and lockedValue:IsA("StringValue") then
		lockedColors = parseLockedValue(lockedValue.Value)
	end
	if inventoryWindow.Visible then
		refreshInventory()
	end
end

local function applyPetState(inventory, equipped)
	colorEntries = inventory or {}
	equippedColors = equipped or {}
	table.clear(lockedColors)
	for _, entry in ipairs(colorEntries) do
		if entry.isLocked == true then
			lockedColors[getEntryKey(entry)] = true
		end
	end
	if inventoryWindow.Visible then
		refreshInventory()
	end
end

local function setupDataListeners()
	if petInventoryValue then
		petInventoryValue:GetPropertyChangedSignal("Value"):Connect(refreshPetsFromValues)
	end
	if petEquippedValue then
		petEquippedValue:GetPropertyChangedSignal("Value"):Connect(refreshPetsFromValues)
	end
	local lockedValue = petFolder and petFolder:FindFirstChild("Locked")
	if lockedValue and lockedValue:IsA("StringValue") then
		lockedValue:GetPropertyChangedSignal("Value"):Connect(refreshPetsFromValues)
	end
	if petFolder then
		petFolder.ChildAdded:Connect(function(child)
			if child.Name == "Locked" and child:IsA("StringValue") then
				child:GetPropertyChangedSignal("Value"):Connect(refreshPetsFromValues)
				refreshPetsFromValues()
			end
		end)
	end
	if ownedPaintToolsValue then
		ownedPaintToolsValue:GetPropertyChangedSignal("Value"):Connect(function()
			if currentTab == "Brushes" and inventoryWindow.Visible then
				refreshInventory()
			end
		end)
	end
	if equippedPaintToolValue then
		equippedPaintToolValue:GetPropertyChangedSignal("Value"):Connect(function()
			if currentTab == "Brushes" and inventoryWindow.Visible then
				refreshInventory()
			end
		end)
	end

	petsLoadedEvent.OnClientEvent:Connect(applyPetState)
	useItemEvent.OnClientEvent:Connect(function(resultType, arg1, arg2)
		if resultType == "sync" and type(arg1) == "table" then
			table.clear(playerItems)
			for itemId, quantity in pairs(arg1) do
				setItemQuantity(itemId, quantity)
			end
		elseif resultType == "update" or resultType == "used" or resultType == "boosted" then
			setItemQuantity(arg1, arg2)
		end

		if (currentTab == "Potions" or currentTab == "Items") and inventoryWindow.Visible then
			refreshInventory()
		end
	end)
end

local function getWindowContent(windowName)
	local window = windows:FindFirstChild(windowName)
	if not window or not window:IsA("GuiObject") then
		warn("EditorWindowBinder: missing MainHUD.ModalWindows.Windows." .. windowName)
		return nil, nil
	end

	local content = findGuiObject(window, "Content")
		or ensureFrame(window, "Content", UDim2.fromOffset(22, 82), UDim2.new(1, -44, 1, -108))
	return window, content
end

local function ensureBinderList(content)
	local list = content:FindFirstChild("BinderList")
	if not list or not list:IsA("ScrollingFrame") then
		list = Instance.new("ScrollingFrame")
		list.Name = "BinderList"
		list.BackgroundTransparency = 1
		list.BorderSizePixel = 0
		list.Position = UDim2.fromScale(0, 0)
		list.Size = UDim2.fromScale(1, 1)
		list.CanvasSize = UDim2.fromOffset(0, 0)
		list.ScrollBarThickness = 6
		list.Parent = content
	end

	for _, child in ipairs(content:GetChildren()) do
		if child ~= list and child:IsA("GuiObject") then
			child.Visible = false
		end
	end

	local layout = list:FindFirstChildOfClass("UIListLayout") or Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 10)
	layout.Parent = list
	if not list:GetAttribute("BinderLayoutConnected") then
		list:SetAttribute("BinderLayoutConnected", true)
		layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			list.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 20)
		end)
	end

	local padding = list:FindFirstChildOfClass("UIPadding") or Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.Parent = list

	for _, child in ipairs(list:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end

	return list
end

local function makeWindowCard(list, order, title, body, buttonText, callback, color)
	local card = Instance.new("Frame")
	card.Name = "BinderCard_" .. tostring(order)
	card.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	card.BorderSizePixel = 0
	card.LayoutOrder = order
	card.Size = UDim2.new(1, -6, 0, 98)
	card.Parent = list

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Color3.fromRGB(35, 38, 45)
	stroke.Thickness = 2
	stroke.Parent = card

	ensureLabel(card, "Title", title, UDim2.fromOffset(14, 10), UDim2.new(1, -150, 0, 26), 18)
	ensureLabel(card, "Body", body, UDim2.fromOffset(14, 40), UDim2.new(1, -150, 0, 48), 13)

	if buttonText then
		local button =
			ensureButton(card, "ActionButton", buttonText, UDim2.new(1, -128, 0.5, -17), UDim2.fromOffset(112, 34))
		if callback then
			connectPress(button, callback)
		else
			setButtonEnabled(button, false)
		end
	end

	return card
end

local function getOwnedColorSet()
	local storage = player:FindFirstChild("ColorStorage")
	local unlockedValue = storage and storage:FindFirstChild("UnlockedColors")
	return ColorData.getUnlockedColorSet(unlockedValue and unlockedValue.Value or "Red")
end

local function getCurrentWorld()
	local storage = player:FindFirstChild("ColorStorage")
	local currentValue = storage and storage:FindFirstChild("CurrentWorld")
	return currentValue and currentValue.Value or player:GetAttribute("ActiveWorldColor") or "Red"
end

local function getCurrentCoins()
	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	return coins and tonumber(coins.Value) or 0
end

local function getUpgradeLevel(upgradeId)
	local folder = player:FindFirstChild("Upgrades")
	if not folder then
		return 0
	end

	local levelValue = folder:FindFirstChild(upgradeId .. "_Level")
	if levelValue and (levelValue:IsA("IntValue") or levelValue:IsA("NumberValue")) then
		return levelValue.Value
	end
	return 0
end

local renderShop

local function getOrCreateTemplatesFolder(window)
	local templates = window:FindFirstChild("Templates")
	if not templates then
		templates = Instance.new("Folder")
		templates.Name = "Templates"
		templates.Parent = window
	end
	return templates
end

local function ensureShopCardTemplate(shopWindow)
	local templates = getOrCreateTemplatesFolder(shopWindow)
	local template = templates:FindFirstChild("ShopCardTemplate")
	if template and template:IsA("GuiObject") then
		template.Visible = false
		return template
	end

	template = Instance.new("Frame")
	template.Name = "ShopCardTemplate"
	template.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	template.BorderSizePixel = 0
	template.Size = UDim2.new(1, -6, 0, 116)
	template.Visible = false
	template.Parent = templates

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = template

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(35, 38, 45)
	stroke.Thickness = 2
	stroke.Parent = template

	local iconFrame =
		ensureFrame(template, "Icon", UDim2.fromOffset(12, 14), UDim2.fromOffset(72, 72), Color3.fromRGB(244, 248, 252))
	ensureLabel(iconFrame, "IconText", "VIP", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 20).TextXAlignment =
		Enum.TextXAlignment.Center
	local image = Instance.new("ImageLabel")
	image.Name = "IconImage"
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(1, 1)
	image.Visible = false
	image.Parent = iconFrame

	ensureLabel(template, "Name", "Product", UDim2.fromOffset(96, 10), UDim2.new(1, -238, 0, 26), 18)
	ensureLabel(template, "Description", "Description", UDim2.fromOffset(96, 38), UDim2.new(1, -238, 0, 40), 13)
	ensureLabel(template, "Badge", "", UDim2.fromOffset(96, 80), UDim2.new(1, -238, 0, 22), 12)
	ensureLabel(template, "Price", "R$ 0", UDim2.new(1, -130, 0, 14), UDim2.fromOffset(112, 24), 14).TextXAlignment =
		Enum.TextXAlignment.Center
	ensureButton(template, "BuyButton", "BUY", UDim2.new(1, -130, 1, -48), UDim2.fromOffset(112, 34))

	return template
end

local function ensureShopTabs(shopWindow)
	local tabs = findGuiObject(shopWindow, "Tabs")
		or ensureFrame(shopWindow, "Tabs", UDim2.fromOffset(22, 68), UDim2.new(1, -44, 0, 40))
	local desiredTabs = { "Bundles", "Gamepasses", "Potions", "Currency" }
	local desiredSet = {}
	for index, tabName in ipairs(desiredTabs) do
		desiredSet[tabName .. "Tab"] = true
		local tab = tabs:FindFirstChild(tabName .. "Tab")
		if not tab or not tab:IsA("TextButton") then
			tab = ensureButton(tabs, tabName .. "Tab", tabName, UDim2.fromOffset(0, 0), UDim2.fromOffset(118, 34))
		end
		tab.Text = tabName
		tab.LayoutOrder = index
		tab.Visible = true
		if not tab:GetAttribute("ShopTabConnected") then
			tab:SetAttribute("ShopTabConnected", true)
			connectPress(tab, function()
				currentShopTab = tabName
				renderShop()
			end)
		end
	end

	for _, child in ipairs(tabs:GetChildren()) do
		if child:IsA("GuiObject") and string.sub(child.Name, -3) == "Tab" and not desiredSet[child.Name] then
			child.Visible = false
		end
	end

	return tabs
end

local function setShopTabVisuals(tabs)
	for _, tabName in ipairs({ "Bundles", "Gamepasses", "Potions", "Currency" }) do
		local tab = tabs and tabs:FindFirstChild(tabName .. "Tab")
		if tab and tab:IsA("TextButton") then
			local active = tabName == currentShopTab
			tab.BackgroundColor3 = active and Color3.fromRGB(82, 219, 225) or Color3.fromRGB(232, 238, 248)
			tab.TextColor3 = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(38, 36, 52)
		end
	end
end

local function setShopTitle(shopWindow)
	local title = shopWindow:FindFirstChild("Title")
	if title and title:IsA("TextLabel") then
		title.Text = "ROBUX SHOP"
	end
end

local function ownsGamepass(pass)
	local gamepassId = tonumber(pass and pass.gamepassId)
	if not gamepassId or gamepassId <= 0 then
		return false
	end

	if player:GetAttribute("Pass_" .. tostring(pass.id)) == true then
		return true
	end

	local grants = player:FindFirstChild("GamepassGrants")
	local grant = grants and (grants:FindFirstChild(tostring(pass.id)) or grants:FindFirstChild(tostring(gamepassId)))
	return grant and grant:IsA("BoolValue") and grant.Value == true
end

local function makeShopCard(list, template, order, data)
	local card = template:Clone()
	card.Name = "ShopCard_" .. tostring(order)
	card.LayoutOrder = order
	card.Visible = true
	card.Parent = list

	local iconImage = card:FindFirstChild("IconImage", true)
	if iconImage and iconImage:IsA("ImageLabel") then
		iconImage.Image = tostring(data.image or "")
		iconImage.Visible = data.image ~= nil and data.image ~= ""
	end

	local iconText = card:FindFirstChild("IconText", true)
	if iconText and iconText:IsA("TextLabel") then
		iconText.Text = tostring(data.icon or "")
		iconText.Visible = not (data.image ~= nil and data.image ~= "")
	end

	local name = card:FindFirstChild("Name", true)
	if name and name:IsA("TextLabel") then
		name.Text = tostring(data.title or "")
	end

	local description = card:FindFirstChild("Description", true)
	if description and description:IsA("TextLabel") then
		description.Text = tostring(data.description or "")
	end

	local badge = card:FindFirstChild("Badge", true)
	if badge and badge:IsA("TextLabel") then
		badge.Text = tostring(data.badge or "")
		badge.Visible = data.badge ~= nil and data.badge ~= ""
	end

	local price = card:FindFirstChild("Price", true)
	if price and price:IsA("TextLabel") then
		price.Text = tostring(data.priceText or "")
	end

	local button = card:FindFirstChild("BuyButton", true)
	if button and button:IsA("TextButton") then
		button.Text = tostring(data.buttonText or "BUY")
		if data.callback then
			setButtonEnabled(button, true)
			connectPress(button, data.callback)
		else
			setButtonEnabled(button, false)
		end
	end

	local stroke = card:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = data.color or Color3.fromRGB(35, 38, 45)
	end

	return card
end

function renderShop()
	local shopWindow, content = getWindowContent("ShopWindow")
	if not content then
		return
	end

	setShopTitle(shopWindow)
	local tabs = ensureShopTabs(shopWindow)
	setShopTabVisuals(tabs)
	local template = ensureShopCardTemplate(shopWindow)
	local list = ensureBinderList(content)
	local order = 0

	if currentShopTab == "Gamepasses" then
		for _, pass in ipairs(RobuxShopConfig.getSortedGamepasses()) do
			if not SHOP_GAMEPASS_IDS[pass.id] then
				continue
			end
			order += 1
			local gamepassId = tonumber(pass.gamepassId)
			local owned = ownsGamepass(pass)
			local canPrompt = gamepassId and gamepassId > 0 and not owned
			makeShopCard(list, template, order, {
				icon = pass.icon,
				image = pass.iconImage,
				title = pass.displayName or pass.id,
				description = pass.description or "Gamepass",
				badge = pass.badge,
				priceText = pass.price and ("R$ " .. tostring(pass.price)) or "R$ ?",
				buttonText = owned and "OWNED" or (canPrompt and "BUY" or "SET ID"),
				callback = canPrompt and function()
					MarketplaceService:PromptGamePassPurchase(player, gamepassId)
				end or nil,
				color = pass.color,
			})
		end
		if order == 0 then
			makeShopCard(list, template, 1, {
				icon = "GP",
				title = "Gamepasses",
				description = "Gamepass config is not ready.",
				priceText = "",
				buttonText = "COMING SOON",
				color = Color3.fromRGB(170, 180, 205),
			})
		end
	elseif currentShopTab == "Potions" then
		local hasPotionProducts = false
		for _, product in ipairs(RobuxShopConfig.getSortedDevProducts()) do
			if product.category == "Potions" or product.category == "Boosts" or product.boostType then
				hasPotionProducts = true
				order += 1
				local productId = tonumber(product.productId)
				makeShopCard(list, template, order, {
					icon = product.icon,
					image = product.iconImage,
					title = product.displayName or product.id,
					description = product.description or "Boost",
					badge = product.badge,
					priceText = product.price and ("R$ " .. tostring(product.price)) or "R$ ?",
					buttonText = productId and productId > 0 and "BUY" or "SET ID",
					callback = productId and productId > 0 and function()
						MarketplaceService:PromptProductPurchase(player, productId)
					end or nil,
					color = product.color,
				})
			end
		end
		if not hasPotionProducts then
			makeShopCard(list, template, 1, {
				icon = "POT",
				title = "Potions",
				description = "Potion products coming soon.",
				priceText = "",
				buttonText = "COMING SOON",
				color = Color3.fromRGB(170, 180, 205),
			})
		end
	elseif currentShopTab == "Currency" then
		local products = RobuxShopConfig.getSortedDevProducts()
		if #products == 0 then
			makeShopCard(list, template, 1, {
				icon = "$",
				title = "Currency",
				description = "Currency packs coming soon.",
				priceText = "",
				buttonText = "COMING SOON",
				color = Color3.fromRGB(170, 180, 205),
			})
		else
			for _, product in ipairs(products) do
				order += 1
				local productId = tonumber(product.productId)
				makeShopCard(list, template, order, {
					icon = product.icon,
					image = product.iconImage,
					title = product.displayName or product.id,
					description = product.description or "Currency pack",
					badge = product.badge,
					priceText = product.price and ("R$ " .. tostring(product.price)) or "R$ ?",
					buttonText = productId and productId > 0 and "BUY" or "SET ID",
					callback = productId and productId > 0 and function()
						MarketplaceService:PromptProductPurchase(player, productId)
					end or nil,
					color = product.color,
				})
			end
		end
	elseif currentShopTab == "Bundles" then
		makeShopCard(list, template, 1, {
			icon = "FP",
			title = "FOREVER PAINTER",
			description = "Permanent supporter bundle coming soon.",
			priceText = "",
			buttonText = "COMING SOON",
			color = Color3.fromRGB(177, 141, 255),
		})
	end
end

local function renderUpgrades()
	local _, content = getWindowContent("UpgradesWindow")
	if not content then
		return
	end

	local list = ensureBinderList(content)
	for index, upgrade in ipairs(UpgradeData.Upgrades or {}) do
		if not upgrade.id then
			warn("EditorWindowBinder: UpgradeData entry missing id at index " .. tostring(index))
			continue
		end

		local level = getUpgradeLevel(upgrade.id)
		local maxLevel = #(upgrade.levels or {})
		local nextLevel = math.min(level + 1, maxLevel)
		local nextData = upgrade.levels and upgrade.levels[nextLevel]
		local maxed = level >= maxLevel
		local body = "Level "
			.. tostring(level)
			.. "/"
			.. tostring(maxLevel)
			.. "\nCurrent: "
			.. UpgradeData.getValueDisplay(upgrade.id, level)
			.. "\n"
			.. tostring(upgrade.description or "")
		if nextData then
			body ..= "\nNext: " .. UpgradeData.getValueDisplay(upgrade.id, nextLevel) .. " | " .. UpgradeData.formatNumber(
				nextData.cost
			) .. " Coins"
		end

		makeWindowCard(
			list,
			index,
			upgrade.displayName or upgrade.id,
			body,
			maxed and "MAXED" or "UPGRADE",
			maxed and nil or function()
				purchaseUpgradeEvent:FireServer(upgrade.id)
			end,
			Color3.fromRGB(116, 232, 158)
		)
	end
end

local function getSettingValue(settingKey, defaultValue)
	local folder = player:FindFirstChild("Settings")
	local value = folder and folder:FindFirstChild(settingKey)
	if value and value:IsA("BoolValue") then
		return value.Value
	end
	return defaultValue
end

local function renderSettings()
	local _, content = getWindowContent("SettingsWindow")
	if not content then
		return
	end

	local list = ensureBinderList(content)
	local settings = {
		{ title = "Music", key = "Music", default = true },
		{ title = "SFX", key = "SFX", default = true },
		{ title = "Low Detail", key = "LowFX", default = false },
	}

	for index, setting in ipairs(settings) do
		local enabled = getSettingValue(setting.key, setting.default)
		makeWindowCard(
			list,
			index,
			setting.title,
			"Current: " .. (enabled and "ON" or "OFF"),
			enabled and "TURN OFF" or "TURN ON",
			function()
				requestSetSettingEvent:FireServer(setting.key, not enabled)
			end,
			Color3.fromRGB(82, 219, 225)
		)
	end

	makeWindowCard(
		list,
		4,
		"Hide Pets",
		"This setting is not in the current settings schema yet.",
		"COMING SOON",
		nil,
		Color3.fromRGB(170, 180, 205)
	)
	makeWindowCard(
		list,
		5,
		"Auto Delete",
		"Auto delete configuration is coming soon.",
		"COMING SOON",
		nil,
		Color3.fromRGB(170, 180, 205)
	)
end

local codeStatusLabel = nil

local function trim(text)
	return string.gsub(tostring(text or ""), "^%s*(.-)%s*$", "%1")
end

local function renderCodes()
	local codeWindow, content = getWindowContent("CodesWindow")
	if not content then
		return
	end

	local codeBox = codeWindow:FindFirstChild("CodeBox", true) or codeWindow:FindFirstChild("CodeInput", true)
	local redeemButton = codeWindow:FindFirstChild("RedeemButton", true)
	local infoText = codeWindow:FindFirstChild("InfoText", true)
		or codeWindow:FindFirstChild("StatusText", true)
		or codeWindow:FindFirstChild("StatusLabel", true)
	local recentRewards = codeWindow:FindFirstChild("RecentRewards", true)

	if not (codeBox and codeBox:IsA("TextBox") and redeemButton and redeemButton:IsA("GuiButton")) then
		local list = ensureBinderList(content)
		local card =
			makeWindowCard(list, 1, "Codes", "Enter a code and redeem it.", nil, nil, Color3.fromRGB(255, 224, 104))
		codeBox = Instance.new("TextBox")
		codeBox.Name = "CodeBox"
		codeBox.PlaceholderText = "CODE"
		codeBox.Text = ""
		codeBox.ClearTextOnFocus = false
		codeBox.Font = Enum.Font.GothamBold
		codeBox.TextSize = 16
		codeBox.TextColor3 = Color3.fromRGB(38, 36, 52)
		codeBox.BackgroundColor3 = Color3.fromRGB(244, 248, 252)
		codeBox.BorderSizePixel = 0
		codeBox.Position = UDim2.new(1, -260, 0.5, -17)
		codeBox.Size = UDim2.fromOffset(132, 34)
		codeBox.Parent = card
		redeemButton =
			ensureButton(card, "RedeemButton", "REDEEM", UDim2.new(1, -118, 0.5, -17), UDim2.fromOffset(102, 34))
		infoText = card:FindFirstChild("Body")
	end

	if infoText and infoText:IsA("TextLabel") then
		codeStatusLabel = infoText
		if codeStatusLabel.Text == "" then
			codeStatusLabel.Text = "Enter a code."
		end
	end

	if recentRewards and recentRewards:IsA("TextLabel") and recentRewards.Text == "" then
		recentRewards.Text = "Recent rewards will appear here."
	end

	if redeemButton and redeemButton:IsA("GuiButton") and not redeemButton:GetAttribute("EditorCodesBound") then
		redeemButton:SetAttribute("EditorCodesBound", true)
		connectPress(redeemButton, function()
			local box = codeWindow:FindFirstChild("CodeBox", true) or codeWindow:FindFirstChild("CodeInput", true)
			local code = box and box:IsA("TextBox") and trim(box.Text) or ""
			if code == "" then
				if codeStatusLabel then
					codeStatusLabel.Text = "Enter a code first."
				end
				return
			end
			if codeStatusLabel then
				codeStatusLabel.Text = "Checking code..."
			end
			redeemCodeEvent:FireServer(code)
		end)
	end
end

local function renderTrade()
	local _, content = getWindowContent("TradeWindow")
	if not content then
		return
	end
	if content:GetAttribute("EditableTradeBinderOwns") == true then
		return
	end
	local list = ensureBinderList(content)
	makeWindowCard(list, 1, "Trading", "Trading is coming soon.", nil, nil, Color3.fromRGB(192, 154, 255))
end

local WORLD_CARD_NAMES = {
	Red = { "RedAreaCard", "RedWorldCard", "RedSectorCard", "RedCard" },
	Orange = { "OrangeAreaCard", "OrangeWorldCard", "OrangeSectorCard", "OrangeCard" },
	Blue = { "BlueAreaCard", "BlueWorldCard", "BlueSectorCard", "BlueCard" },
	Yellow = { "YellowAreaCard", "YellowWorldCard", "YellowSectorCard", "YellowCard" },
	Green = { "GreenAreaCard", "GreenWorldCard", "GreenSectorCard", "GreenCard" },
	Purple = { "PurpleAreaCard", "PurpleWorldCard", "PurpleSectorCard", "PurpleCard" },
	Neon = { "NeonAreaCard", "NeonWorldCard", "NeonSectorCard", "NeonCard" },
	Rainbow = { "RainbowAreaCard", "RainbowWorldCard", "RainbowSectorCard", "RainbowCard" },
}

local function findWorldCard(content, colorType)
	for _, name in ipairs(WORLD_CARD_NAMES[colorType] or {}) do
		local card = content:FindFirstChild(name, true)
		if card and card:IsA("GuiObject") then
			return card
		end
	end
	return nil
end

local function findTeleportButton(card, colorType)
	if not card then
		return nil
	end

	local button = card:FindFirstChild("TeleportButton", true)
		or card:FindFirstChild("WorldTeleportButton_" .. tostring(colorType), true)
	if button and button:IsA("TextButton") then
		return button
	end
	return nil
end

local function setWorldButtonFeedback(button, text, restoreText)
	if not button then
		return
	end
	button.Text = text
	task.delay(1.2, function()
		if button and button.Parent and button.Text == text then
			button.Text = restoreText
		end
	end)
end

local function teleportToWorld(world, button)
	local colorType = world and (world.primaryColor or world.id)
	if not colorType then
		return
	end

	local unlocked = getOwnedColorSet()
	if unlocked[colorType] ~= true then
		setWorldButtonFeedback(button, "LOCKED", "LOCKED")
		warn("EditorWindowBinder: blocked locked Sector teleport to " .. tostring(colorType))
		return
	end

	if getCurrentWorld() == colorType then
		setWorldButtonFeedback(button, "CURRENT", "CURRENT")
		return
	end

	requestTravelToSectorEvent:FireServer(colorType)
	setWorldButtonFeedback(button, "GOING", "GO")
end

local function unlockWorld(world, button)
	local colorType = world and (world.primaryColor or world.id)
	if not colorType then
		return
	end

	local previous = ColorData.getPreviousWorld(colorType)
	local unlocked = getOwnedColorSet()
	if previous and unlocked[previous.primaryColor] ~= true then
		setWorldButtonFeedback(button, "LOCKED", "UNLOCK")
		return
	end

	local cost = tonumber(world.UnlockCost or world.unlockCost) or 0
	if getCurrentCoins() < cost then
		setWorldButtonFeedback(button, "NEED COINS", "UNLOCK")
		return
	end

	unlockAreaEvent:FireServer("unlock", colorType)
	setWorldButtonFeedback(button, "BUYING", "UNLOCK")
end

local function bindWorldCard(content, world, isUnlocked, isCurrent)
	local colorType = world.primaryColor or world.id
	local card = findWorldCard(content, colorType)
	local button = findTeleportButton(card, colorType)
	if not button then
		return false
	end

	button.Visible = true
	local previous = ColorData.getPreviousWorld(colorType)
	local canUnlock = not isUnlocked
		and (not previous or getOwnedColorSet()[previous.primaryColor] == true)
		and getCurrentCoins() >= (tonumber(world.UnlockCost or world.unlockCost) or 0)
	button.Active = isUnlocked or canUnlock
	button.AutoButtonColor = isUnlocked or canUnlock
	button.Text = isCurrent and "CURRENT" or (isUnlocked and "GO" or (canUnlock and "UNLOCK" or "LOCKED"))
	button.BackgroundTransparency = (isUnlocked or canUnlock) and 0 or 0.25

	if not button:GetAttribute("EditorWorldTeleportBound") then
		button:SetAttribute("EditorWorldTeleportBound", true)
		connectPress(button, function()
			local boundColor = button:GetAttribute("WorldColor")
			local boundWorld = boundColor and ColorData.getWorldByColor(boundColor) or world
			local boundUnlocked = getOwnedColorSet()
			local boundPrimaryColor = boundWorld and (boundWorld.primaryColor or boundWorld.id)
			if boundPrimaryColor and boundUnlocked[boundPrimaryColor] ~= true then
				unlockWorld(boundWorld, button)
			else
				teleportToWorld(boundWorld, button)
			end
		end)
	end
	button:SetAttribute("WorldColor", colorType)

	local status = card
		and (
			card:FindFirstChild("Status", true)
			or card:FindFirstChild("StatusLabel", true)
			or card:FindFirstChild("Requirement", true)
		)
	if status and status:IsA("TextLabel") then
		status.Text = isUnlocked and (isCurrent and "Current Sector" or "Unlocked")
			or ("Unlock for " .. UpgradeData.formatNumber(world.UnlockCost or world.unlockCost or 0) .. " Coins")
	end

	return true
end

local function renderWorlds()
	local _, content = getWindowContent("WorldsWindow")
	if not content then
		return
	end

	local unlocked = getOwnedColorSet()
	local current = getCurrentWorld()
	local boundExistingCards = 0
	for _, world in ipairs(ColorData.Worlds or {}) do
		local colorType = world.primaryColor or world.id
		local isUnlocked = unlocked[colorType] == true
		local isCurrent = current == colorType
		if bindWorldCard(content, world, isUnlocked, isCurrent) then
			boundExistingCards += 1
		end
	end

	if boundExistingCards > 0 then
		local list = content:FindFirstChild("BinderList")
		if list and list:IsA("GuiObject") then
			list.Visible = false
		end
		return
	end

	local list = ensureBinderList(content)
	for index, world in ipairs(ColorData.Worlds or {}) do
		local colorType = world.primaryColor or world.id
		local isUnlocked = unlocked[colorType] == true
		local isCurrent = current == colorType
		local requirement = isUnlocked and "Unlocked"
			or (
				"Requires "
				.. tostring(world.RequiredZoneId or "previous Sector")
				.. " | "
				.. UpgradeData.formatNumber(world.UnlockCost or world.unlockCost or 0)
				.. " Coins"
			)
		local previous = ColorData.getPreviousWorld(colorType)
		local canUnlock = not isUnlocked
			and (not previous or unlocked[previous.primaryColor] == true)
			and getCurrentCoins() >= (tonumber(world.UnlockCost or world.unlockCost) or 0)
		local buttonText = isCurrent and "CURRENT" or (isUnlocked and "GO" or (canUnlock and "UNLOCK" or "LOCKED"))
		local colorConfig = colorType and ColorData.Colors[colorType]
		local card
		card = makeWindowCard(
			list,
			index,
			world.DisplayName or world.name or colorType,
			requirement,
			buttonText,
			(isUnlocked or canUnlock)
					and function()
						local button = card and card:FindFirstChild("ActionButton", true)
						if isUnlocked then
							teleportToWorld(world, button)
						else
							unlockWorld(world, button)
						end
					end
				or nil,
			colorConfig and colorConfig.color
		)
	end
end

local dailyQuestData = nil

local function formatDuration(seconds)
	seconds = math.max(0, math.floor(tonumber(seconds) or 0))
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	return string.format("%02dh %02dm", hours, minutes)
end

local function copyDailyQuestFallback(index)
	local source = FALLBACK_DAILY_QUESTS[index] or FALLBACK_DAILY_QUESTS[1]
	local copy = {}
	for key, value in pairs(source) do
		copy[key] = value
	end
	return copy
end

local function getDailyQuestRows(data)
	local source = type(data) == "table" and (data.Quests or data.quests) or nil
	local rows = {}
	if type(source) == "table" then
		for index = 1, 3 do
			if type(source[index]) == "table" then
				rows[index] = source[index]
			end
		end
	end
	for index = 1, 3 do
		if type(rows[index]) ~= "table" then
			rows[index] = copyDailyQuestFallback(index)
		end
	end
	return rows
end

local function renderDailyQuests()
	local _, content = getWindowContent("DailyQuestsWindow")
	if not content then
		return
	end

	local list = ensureBinderList(content)
	if not dailyQuestRemote then
		makeWindowCard(
			list,
			1,
			"Daily Quests",
			"DailyQuestRemote is missing. Showing progress is unavailable.",
			nil,
			nil,
			Color3.fromRGB(170, 180, 205)
		)
		warn("EditorWindowBinder: DailyQuestRemote missing.")
		return
	end

	if not dailyQuestData then
		makeWindowCard(list, 1, "Daily Quests", "Requesting quests...", nil, nil, Color3.fromRGB(170, 180, 205))
		dailyQuestRemote:FireServer("Get")
		return
	end

	local resetLabel = Instance.new("TextLabel")
	resetLabel.Name = "ResetTimer"
	resetLabel.BackgroundTransparency = 1
	resetLabel.LayoutOrder = 0
	resetLabel.Size = UDim2.new(1, -6, 0, 26)
	resetLabel.Font = Enum.Font.GothamBlack
	resetLabel.TextColor3 = Color3.fromRGB(38, 36, 52)
	resetLabel.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
	resetLabel.TextStrokeTransparency = 0.2
	resetLabel.TextSize = 16
	resetLabel.TextXAlignment = Enum.TextXAlignment.Left
	resetLabel.Text = "Resets in: " .. formatDuration(dailyQuestData.resetIn)
	resetLabel.Parent = list

	local quests = getDailyQuestRows(dailyQuestData)
	for index = 1, 3 do
		local quest = quests[index]
		local progress = tonumber(quest.progress or quest.amount) or 0
		local required = tonumber(quest.target or quest.requiredAmount or quest.required or quest.goal) or 1
		local complete = progress >= required
		local claimed = quest.claimed == true
		local rewardAmount = tonumber(quest.rewardAmount or quest.reward) or 0
		local rewardCurrency = tostring(quest.rewardCurrency or "Gems")
		local iconText = quest.iconText and (tostring(quest.iconText) .. "  ") or ""
		local body = tostring(quest.description or "")
			.. "\n"
			.. tostring(progress)
			.. "/"
			.. tostring(required)
			.. " | Reward: "
			.. tostring(rewardAmount)
			.. " "
			.. rewardCurrency
		makeWindowCard(
			list,
			index,
			iconText .. tostring(quest.title or ("Quest " .. tostring(index))),
			body,
			claimed and "CLAIMED" or (complete and "CLAIM" or "IN PROGRESS"),
			(complete and not claimed) and function()
				dailyQuestRemote:FireServer("Claim", index)
			end or nil,
			complete and Color3.fromRGB(116, 232, 158) or Color3.fromRGB(82, 219, 225)
		)
	end
end

local function refreshAuxiliaryWindows()
	renderShop()
	renderUpgrades()
	renderSettings()
	renderCodes()
	renderTrade()
	if BIND_WORLDS_WINDOW then
		renderWorlds()
	end
	if BIND_DAILY_QUESTS_WINDOW then
		renderDailyQuests()
	end
end

local function setupAuxiliaryListeners()
	purchaseUpgradeEvent.OnClientEvent:Connect(function()
		renderUpgrades()
	end)
	settingsUpdatedEvent.OnClientEvent:Connect(function()
		renderSettings()
	end)
	redeemCodeEvent.OnClientEvent:Connect(function(success, message)
		renderCodes()
		if codeStatusLabel then
			codeStatusLabel.Text = tostring(message or (success and "Code redeemed!" or "Could not redeem code."))
			codeStatusLabel.TextColor3 = success and Color3.fromRGB(35, 130, 55) or Color3.fromRGB(220, 80, 90)
		end
	end)

	if dailyQuestRemote then
		dailyQuestRemote.OnClientEvent:Connect(function(action, data)
			if BIND_DAILY_QUESTS_WINDOW and (action == "Open" or action == "Update" or action == "Locked") then
				dailyQuestData = data
				renderDailyQuests()
			end
		end)
	end

	local settingsFolder = player:FindFirstChild("Settings")
	if settingsFolder then
		for _, child in ipairs(settingsFolder:GetChildren()) do
			if child:IsA("BoolValue") then
				child:GetPropertyChangedSignal("Value"):Connect(renderSettings)
			end
		end
		settingsFolder.ChildAdded:Connect(function(child)
			if child:IsA("BoolValue") then
				child:GetPropertyChangedSignal("Value"):Connect(renderSettings)
				renderSettings()
			end
		end)
	end

	local upgradesFolder = player:FindFirstChild("Upgrades")
	if upgradesFolder then
		for _, child in ipairs(upgradesFolder:GetChildren()) do
			if child:IsA("ValueBase") then
				child:GetPropertyChangedSignal("Value"):Connect(renderUpgrades)
			end
		end
		upgradesFolder.ChildAdded:Connect(function(child)
			if child:IsA("ValueBase") then
				child:GetPropertyChangedSignal("Value"):Connect(renderUpgrades)
				renderUpgrades()
			end
		end)
	end

	if BIND_WORLDS_WINDOW then
		local colorStorage = player:FindFirstChild("ColorStorage")
		if colorStorage then
			for _, valueName in ipairs({ "UnlockedColors", "CurrentWorld" }) do
				local value = colorStorage:FindFirstChild(valueName)
				if value and value:IsA("ValueBase") then
					value:GetPropertyChangedSignal("Value"):Connect(renderWorlds)
				end
			end
		end
		local leaderstats = player:FindFirstChild("leaderstats")
		local coins = leaderstats and leaderstats:FindFirstChild("Coins")
		if coins and coins:IsA("ValueBase") then
			coins:GetPropertyChangedSignal("Value"):Connect(renderWorlds)
		end
	end

	for _, windowName in ipairs({
		"ShopWindow",
		"UpgradesWindow",
		"SettingsWindow",
		"CodesWindow",
		"TradeWindow",
		"WorldsWindow",
		"DailyQuestsWindow",
	}) do
		local window = windows:FindFirstChild(windowName)
		if window and window:IsA("GuiObject") then
			window:GetPropertyChangedSignal("Visible"):Connect(function()
				if window.Visible then
					if windowName == "ShopWindow" then
						renderShop()
					elseif windowName == "UpgradesWindow" then
						renderUpgrades()
					elseif windowName == "SettingsWindow" then
						renderSettings()
					elseif windowName == "CodesWindow" then
						renderCodes()
					elseif windowName == "TradeWindow" then
						renderTrade()
					elseif BIND_WORLDS_WINDOW and windowName == "WorldsWindow" then
						renderWorlds()
					elseif BIND_DAILY_QUESTS_WINDOW and windowName == "DailyQuestsWindow" then
						renderDailyQuests()
					end
				end
			end)
		end
	end
end

hideLegacyRootLayers()
root.ChildAdded:Connect(function(child)
	if LEGACY_ROOT_LAYERS[child.Name] and child:IsA("GuiObject") then
		child.Visible = false
	end
end)

setupAuxiliaryListeners()
if BIND_INVENTORY_WINDOW then
	ensureInventoryStructure()
	wireTabs()
	setupDataListeners()
	refreshPetsFromValues()
	setDetailsEmpty("Choose a card to see details.")
	refreshInventory()
end
refreshAuxiliaryWindows()

inventoryWindow:GetPropertyChangedSignal("Visible"):Connect(function()
	hideLegacyRootLayers()
	if BIND_INVENTORY_WINDOW and inventoryWindow.Visible then
		refreshPetsFromValues()
		refreshInventory()
	end
end)

print("[EditorWindowBinder] auxiliary editable windows bound; EditableInventoryBinder owns InventoryWindow.")
