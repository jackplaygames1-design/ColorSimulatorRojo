-- Binds the editable Studio InventoryWindow to server-owned inventory data.
-- This script only populates existing UI and sends requests. It never grants,
-- equips, deletes, or consumes anything locally.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local inventoryRequest = remotes:WaitForChild("InventoryRequest")
local inventoryAction = remotes:WaitForChild("InventoryAction")

local Events = ReplicatedStorage:WaitForChild("Events")
local hatchEvent = Events:WaitForChild("HatchEgg")
local petsLoadedEvent = Events:WaitForChild("PetsLoaded")
local useItemEvent = Events:WaitForChild("UseItem")
local equipPaintToolEvent = Events:WaitForChild("EquipPaintTool")

local InventoryIconConfig = require(ReplicatedStorage:WaitForChild("InventoryIconConfig"))

local TAB_NAMES = { "Colors", "Brushes", "Potions", "Items" }
local currentTab = "Colors"
local inventoryData = { Colors = {}, Brushes = {}, Potions = {}, Items = {}, Count = 0, Capacity = 75 }
local selectedItem = nil
local loading = false

local function waitForInventoryWindow()
	local root = playerGui:WaitForChild("ClientUIRoot", 30)
	local mainHud = root and root:WaitForChild("MainHUD", 30)
	local modalWindows = mainHud and mainHud:WaitForChild("ModalWindows", 30)
	local windows = modalWindows and modalWindows:WaitForChild("Windows", 30)
	return windows and windows:WaitForChild("InventoryWindow", 30)
end

local inventoryWindow = waitForInventoryWindow()
if not inventoryWindow or not inventoryWindow:IsA("GuiObject") then
	warn("EditableInventoryBinder: InventoryWindow missing. No runtime inventory window was created.")
	return
end

local ui = {}
local cardConnections = {}
local iconWarnings = {}
local renderDetails

local function isInventoryCardSlot(object)
	if not object or not object:IsA("GuiObject") then
		return false
	end
	if object.Name == "ItemCardTemplate" then
		return false
	end
	return string.match(object.Name, "^PreviewSlot%d+$") ~= nil
		or string.match(object.Name, "^ItemCard%d*$") ~= nil
		or object:GetAttribute("InventoryCardSlot") == true
end

local function disconnectCards()
	for _, connection in ipairs(cardConnections) do
		if connection and connection.Connected then
			connection:Disconnect()
		end
	end
	table.clear(cardConnections)
end

local function setText(object, value)
	if object and (object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox")) then
		object.Text = tostring(value or "")
	end
end

local function setDetailText(object, value)
	setText(object, value)
end

local function findTextChildByNames(parent, names)
	if not parent then
		return nil
	end
	for _, name in ipairs(names) do
		local found = parent:FindFirstChild(name, true)
		if found and (found:IsA("TextLabel") or found:IsA("TextBox")) then
			return found
		end
	end
	return nil
end

local function setButtonText(button, value)
	if not button then
		return
	end
	local label = findTextChildByNames(button, {
		"TextLabel",
		"Label",
		"Title",
		"ButtonText",
		"ActionText",
		"Name",
	})
	if label then
		setText(label, value)
		if button:IsA("TextButton") then
			button.Text = ""
		end
		return
	end
	setText(button, value)
end

local function setButtonEnabled(button, enabled)
	if not button then
		return
	end
	button.Active = enabled == true
	button.AutoButtonColor = enabled == true
end

local function findDescendantByNames(parent, names)
	if not parent then
		return nil
	end
	for _, name in ipairs(names) do
		local found = parent:FindFirstChild(name, true)
		if found then
			return found
		end
	end
	return nil
end

local function findChildByNames(parent, names)
	if not parent then
		return nil
	end
	for _, name in ipairs(names) do
		local found = parent:FindFirstChild(name)
		if found then
			return found
		end
	end
	return findDescendantByNames(parent, names)
end

local function connectGuiClick(guiObject, callback)
	if not guiObject or not guiObject:IsA("GuiObject") then
		return nil
	end

	guiObject.Active = true
	if guiObject:IsA("GuiButton") then
		guiObject.Selectable = true
		return guiObject.Activated:Connect(callback)
	end

	guiObject.Selectable = false
	return guiObject.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			callback()
		end
	end)
end

local function findCardClickTarget(card)
	if card:IsA("GuiButton") then
		return card
	end

	local namedTarget = findDescendantByNames(card, {
		"SelectButton",
		"ItemButton",
		"CardButton",
		"ClickButton",
		"Hitbox",
		"PreviewButton",
		"PreviewIcon",
		"Preview",
		"Icon",
		"ItemPreview",
		"PreviewFrame",
	})
	if namedTarget and namedTarget:IsA("GuiObject") then
		return namedTarget
	end

	return card
end

local function connectCardSelection(card, callback)
	local connected = {}

	local function connect(object)
		if not object:IsA("GuiObject") or connected[object] then
			return
		end
		connected[object] = true
		local connection = connectGuiClick(object, callback)
		if connection then
			table.insert(cardConnections, connection)
		end
	end

	connect(card)
	local preferred = findCardClickTarget(card)
	if preferred then
		connect(preferred)
	end
	for _, descendant in ipairs(card:GetDescendants()) do
		if descendant:IsA("GuiObject") then
			connect(descendant)
		end
	end
end

local function warnIconOnce(key, message)
	if iconWarnings[key] then
		return
	end
	iconWarnings[key] = true
	warn(message)
end

local function getInventoryIconSpec(iconName)
	local icons = InventoryIconConfig.Icons
	local spec = icons and icons[iconName]
	if type(spec) ~= "table" then
		return nil
	end
	return spec
end

local function getInventoryIconImage(iconName)
	local spec = getInventoryIconSpec(iconName)
	if not spec then
		return nil, nil, false
	end

	if type(spec.Image) == "string" and spec.Image ~= "" then
		return spec.Image, spec, false
	end
	if type(InventoryIconConfig.SheetImage) == "string" and InventoryIconConfig.SheetImage ~= "" then
		return InventoryIconConfig.SheetImage, spec, true
	end
	return nil, spec, false
end

local function getButtonIcon(button, iconName)
	if not button or not button:IsA("GuiObject") then
		return nil
	end
	if button:IsA("ImageButton") then
		return button
	end

	local icon = findDescendantByNames(button, {
		iconName .. "Icon",
		"ActionIcon",
		"TabIcon",
		"ButtonIcon",
		"Icon",
	})
	if icon and (icon:IsA("ImageLabel") or icon:IsA("ImageButton")) then
		return icon
	end
	return nil
end

local function applyInventoryIcon(button, iconName)
	local imageId, spec, usesSheet = getInventoryIconImage(iconName)
	if button then
		button:SetAttribute("InventoryIconName", iconName)
		button:SetAttribute("ExpectedIconFile", spec and spec.SourceFile or "")
		button:SetAttribute("ExpectedIconSheet", InventoryIconConfig.SheetSourceFile or "")
	end
	if not spec then
		return
	end

	local icon = getButtonIcon(button, iconName)
	if not icon then
		return
	end
	icon:SetAttribute("InventoryIconName", iconName)
	icon:SetAttribute("ExpectedIconFile", spec.SourceFile or "")
	icon:SetAttribute("ExpectedIconSheet", InventoryIconConfig.SheetSourceFile or "")

	if not imageId then
		warnIconOnce(
			"missing-icon-" .. iconName,
			"EditableInventoryBinder: paste a Roblox image id into InventoryIconConfig for " .. iconName
		)
		return
	end

	icon.Image = imageId
	if usesSheet then
		icon.ImageRectOffset = spec.RectOffset or Vector2.new(0, 0)
		icon.ImageRectSize = spec.RectSize or Vector2.new(0, 0)
	else
		icon.ImageRectOffset = Vector2.new(0, 0)
		icon.ImageRectSize = Vector2.new(0, 0)
	end
end

local function applyInventoryIcons()
	for _, tabName in ipairs(TAB_NAMES) do
		local tab = ui.tabs and ui.tabs:FindFirstChild(tabName .. "Tab", true)
		local iconName = InventoryIconConfig.TabIcons and InventoryIconConfig.TabIcons[tabName]
		if tab and iconName then
			applyInventoryIcon(tab, iconName, false)
		end
	end

	applyInventoryIcon(ui.equipButton, "Equip")
	applyInventoryIcon(ui.lockButton, "Lock")
	applyInventoryIcon(ui.deleteButton, "Delete")
end

local function prepareStructure()
	ui.tabs = inventoryWindow:FindFirstChild("Tabs", true)
	ui.body = inventoryWindow:FindFirstChild("Content")
	if not ui.body then
		warn("EditableInventoryBinder: missing InventoryWindow.Content")
		return false
	end

	ui.gridPanel = ui.body:FindFirstChild("GridPanel")
	if not ui.gridPanel then
		warn("EditableInventoryBinder: missing InventoryWindow.Content.GridPanel")
		return false
	end
	ui.grid = ui.gridPanel

	ui.cardTemplate = ui.gridPanel:FindFirstChild("ItemCardTemplate")
	if ui.cardTemplate and ui.cardTemplate:IsA("GuiObject") then
		ui.cardTemplate.Visible = false
	else
		warn("EditableInventoryBinder: missing InventoryWindow.Content.GridPanel.ItemCardTemplate")
		ui.cardTemplate = nil
	end

	ui.itemCards = {}
	for _, child in ipairs(ui.gridPanel:GetChildren()) do
		if isInventoryCardSlot(child) then
			table.insert(ui.itemCards, child)
		end
	end
	table.sort(ui.itemCards, function(a, b)
		if a.LayoutOrder ~= b.LayoutOrder then
			return a.LayoutOrder < b.LayoutOrder
		end
		return a.Name < b.Name
	end)
	if #ui.itemCards == 0 then
		warn("EditableInventoryBinder: add physical card slots to GridPanel; runtime card cloning is disabled.")
	end

	ui.emptyText = ui.gridPanel:FindFirstChild("EmptyText", true)
	ui.footer = ui.gridPanel:FindFirstChild("Footer", true)
	ui.capacityText = ui.footer and ui.footer:FindFirstChild("CapacityText", true)

	ui.detailPanel = ui.body:FindFirstChild("DetailsPanel")
	if not ui.detailPanel then
		warn("EditableInventoryBinder: missing InventoryWindow.Content.DetailsPanel")
		return false
	end

	ui.bigPreview = findChildByNames(ui.detailPanel, { "PreviewIcon", "BigPreview", "PreviewImage", "Preview", "Icon", "ItemPreview" })
	ui.selectedName = findChildByNames(ui.detailPanel, { "ItemName", "SelectedName", "NameLabel", "Name", "Title", "SelectLabel" })
	ui.selectedRarity = findChildByNames(ui.detailPanel, { "RarityLabel", "SelectedRarity", "Rarity", "Meta", "ItemMeta" })
	ui.selectedDescription = findChildByNames(ui.detailPanel, { "SelectedDescription", "Description", "ItemDescription" })
	ui.statsBox = findChildByNames(ui.detailPanel, { "StatsBox" })
	ui.statsText = findChildByNames(ui.detailPanel, { "StatsLabel", "StatsText", "Stats" })
	ui.equipButton = findChildByNames(ui.detailPanel, { "EquipButton", "UseButton", "PrimaryButton" })
	ui.lockButton = findChildByNames(ui.detailPanel, { "LockButton" })
	ui.deleteButton = findChildByNames(ui.detailPanel, { "DeleteButton" })
	return true
end

local function clearPreview(preview)
	return preview
end

local function setExistingPreviewImage(preview, item)
	if preview:IsA("ImageLabel") or preview:IsA("ImageButton") then
		if item.IconImage and item.IconImage ~= "" then
			preview.Image = item.IconImage
		end
		if item.IconColor then
			preview.ImageColor3 = item.IconColor
		end
		return true
	end

	local image = findDescendantByNames(preview, { "PreviewImage", "IconImage", "Image", "Icon" })
	if image and (image:IsA("ImageLabel") or image:IsA("ImageButton")) then
		if item.IconImage and item.IconImage ~= "" then
			image.Image = item.IconImage
		end
		if item.IconColor then
			image.ImageColor3 = item.IconColor
		end
		return true
	end
	return false
end

local function setExistingPreviewText(preview, item)
	local iconText = item.IconText or string.upper(string.sub(item.Name or item.Id or "IT", 1, 2))
	if preview:IsA("TextLabel") then
		setText(preview, iconText)
		return true
	end

	local label = findTextChildByNames(preview, { "PreviewText", "IconText" })
	if label then
		setText(label, iconText)
		return true
	end
	return false
end

local function paintPreview(preview, item)
	if not preview or not preview:IsA("GuiObject") then
		return
	end
	clearPreview(preview)
	setExistingPreviewImage(preview, item)
	setExistingPreviewText(preview, item)
end

local function makeCard(item, index)
	local card = ui.itemCards and ui.itemCards[index]
	if not card then
		return
	end
	card.Visible = true
	card:SetAttribute("InventoryItemId", item.Id or "")
	card:SetAttribute("InventoryItemKind", item.Kind or "")
	if card:IsA("TextButton") then
		card.Text = ""
	end
	if card:IsA("TextButton") or card:IsA("ImageButton") then
		card.AutoButtonColor = true
	end

	local preview = findDescendantByNames(card, { "PreviewIcon", "Preview", "Icon", "ItemPreview", "PreviewFrame" })
	if preview and preview:IsA("GuiObject") then
		paintPreview(preview, item)
	end

	local name = findDescendantByNames(card, { "Name", "ItemName", "Title", "ItemTitle" })
	setText(name, item.Name or item.Id or "Color")

	local meta = findDescendantByNames(card, { "Meta", "ItemMeta", "Rarity", "Amount", "Status" })
	setText(meta, item.Equipped and "EQUIPPED" or (item.Amount and ("x" .. tostring(item.Amount)) or tostring(item.Rarity or "")))

	local stroke = card:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = item.Equipped and Color3.fromRGB(84, 225, 112) or (item.Locked and Color3.fromRGB(88, 174, 255) or Color3.fromRGB(35, 38, 45))
		stroke.Thickness = item.Equipped and 4 or 2
	end

	local function selectItem()
		selectedItem = item
		renderDetails()
	end
	connectCardSelection(card, selectItem)
end

renderDetails = function()
	local item = selectedItem
	if not item then
		clearPreview(ui.bigPreview)
		setDetailText(ui.selectedName, "Select an Item")
		setDetailText(ui.selectedRarity, "")
		setDetailText(ui.selectedDescription, "Choose a card to see details.")
		setDetailText(ui.statsText, "")
		setButtonText(ui.equipButton, "SELECT")
		setButtonEnabled(ui.equipButton, false)
		setButtonText(ui.lockButton, "LOCK")
		setButtonEnabled(ui.lockButton, false)
		setButtonText(ui.deleteButton, "DELETE")
		setButtonEnabled(ui.deleteButton, false)
		return
	end

	paintPreview(ui.bigPreview, item)
	setDetailText(ui.selectedName, item.Name)
	setDetailText(ui.selectedRarity, item.Rarity or item.Mutation or item.Kind)
	setDetailText(ui.selectedDescription, item.Description or item.Bonus or "")
	setDetailText(ui.statsText, table.concat(item.Stats or {}, "\n"))

	if item.Kind == "Color" then
		setButtonText(ui.equipButton, item.Equipped and "UNEQUIP" or "EQUIP")
		setButtonEnabled(ui.equipButton, true)
		setButtonText(ui.lockButton, item.Locked and "UNLOCK" or "LOCK")
		setButtonEnabled(ui.lockButton, true)
		setButtonText(ui.deleteButton, "DELETE")
		setButtonEnabled(ui.deleteButton, not item.Locked and not item.Equipped)
	elseif item.Kind == "Brush" then
		setButtonText(ui.equipButton, item.Equipped and "EQUIPPED" or "EQUIP")
		setButtonEnabled(ui.equipButton, not item.Equipped)
		setButtonText(ui.lockButton, "LOCK")
		setButtonEnabled(ui.lockButton, false)
		setButtonText(ui.deleteButton, "DELETE")
		setButtonEnabled(ui.deleteButton, false)
	else
		setButtonText(ui.equipButton, item.Usable and "USE" or "INFO")
		setButtonEnabled(ui.equipButton, item.Usable == true)
		setButtonText(ui.lockButton, "LOCK")
		setButtonEnabled(ui.lockButton, false)
		setButtonText(ui.deleteButton, "DELETE")
		setButtonEnabled(ui.deleteButton, false)
	end
end

local function getTabItems()
	return inventoryData[currentTab] or {}
end

local function renderInventory()
	disconnectCards()
	for _, child in ipairs(ui.grid:GetChildren()) do
		if child:GetAttribute("EditableInventoryGeneratedCard") == true then
			child:Destroy()
		end
	end
	if ui.cardTemplate then
		ui.cardTemplate.Visible = false
	end

	for _, tabName in ipairs(TAB_NAMES) do
		local tab = ui.tabs and ui.tabs:FindFirstChild(tabName .. "Tab", true)
		if tab and tab:IsA("GuiButton") then
			tab:SetAttribute("InventoryTabActive", tabName == currentTab)
		end
	end

	local items = getTabItems()
	if ui.emptyText then
		ui.emptyText.Visible = #items == 0
		ui.emptyText.Text = "No " .. string.lower(currentTab) .. " yet."
	end
	if ui.capacityText then
		ui.capacityText.Text = "Colors: " .. tostring(inventoryData.Count or 0) .. " / " .. tostring(inventoryData.Capacity or 75)
	end

	for index, item in ipairs(items) do
		makeCard(item, index)
	end
	for index = #items + 1, #(ui.itemCards or {}) do
		local card = ui.itemCards[index]
		card:SetAttribute("InventoryItemId", "")
		card:SetAttribute("InventoryItemKind", "")
	end

	if selectedItem then
		local stillExists = false
		for _, item in ipairs(items) do
			if item.Id == selectedItem.Id and item.Kind == selectedItem.Kind then
				selectedItem = item
				stillExists = true
				break
			end
		end
		if not stillExists then
			selectedItem = nil
		end
	end
	renderDetails()
end

local function requestInventory()
	if loading then
		return
	end
	loading = true
	local ok, data = pcall(function()
		return inventoryRequest:InvokeServer("GetInventory")
	end)
	loading = false
	if ok and type(data) == "table" then
		inventoryData = data
		renderInventory()
	else
		warn("EditableInventoryBinder: inventory request failed: " .. tostring(data))
	end
end

local function sendAction(action, item)
	if not item then
		return
	end
	inventoryAction:FireServer(action, {
		Kind = item.Kind,
		Id = item.Id,
		Locked = not item.Locked,
	})
end

local function wireControls()
	for _, tabName in ipairs(TAB_NAMES) do
		local tab = ui.tabs and ui.tabs:FindFirstChild(tabName .. "Tab", true)
		if tab and tab:IsA("GuiButton") and tab:GetAttribute("EditableInventoryBound") ~= true then
			tab:SetAttribute("EditableInventoryBound", true)
			tab.Activated:Connect(function()
				currentTab = tabName
				selectedItem = nil
				renderInventory()
			end)
		end
	end

	if ui.equipButton and ui.equipButton:IsA("GuiButton") then
		ui.equipButton.Activated:Connect(function()
			if not selectedItem then
				return
			end
			if selectedItem.Kind == "Color" then
				sendAction(selectedItem.Equipped and "Unequip" or "Equip", selectedItem)
			elseif selectedItem.Kind == "Brush" then
				sendAction("Equip", selectedItem)
			elseif selectedItem.Kind == "Potion" or selectedItem.Kind == "Item" then
				sendAction("Use", selectedItem)
			end
		end)
	end
	if ui.lockButton and ui.lockButton:IsA("GuiButton") then
		ui.lockButton.Activated:Connect(function()
			if selectedItem and selectedItem.Kind == "Color" then
				sendAction("Lock", selectedItem)
			end
		end)
	end
	if ui.deleteButton and ui.deleteButton:IsA("GuiButton") then
		ui.deleteButton.Activated:Connect(function()
			if selectedItem and selectedItem.Kind == "Color" and not selectedItem.Locked and not selectedItem.Equipped then
				sendAction("Delete", selectedItem)
			end
		end)
	end
end

if not prepareStructure() then
	return
end
applyInventoryIcons()
wireControls()
renderDetails()

inventoryWindow:GetPropertyChangedSignal("Visible"):Connect(function()
	if inventoryWindow.Visible then
		requestInventory()
	end
end)

inventoryAction.OnClientEvent:Connect(function(result)
	if type(result) == "table" and type(result.Inventory) == "table" then
		inventoryData = result.Inventory
		renderInventory()
	else
		requestInventory()
	end
end)

hatchEvent.OnClientEvent:Connect(function(success)
	if success and inventoryWindow.Visible then
		task.defer(requestInventory)
	end
end)
petsLoadedEvent.OnClientEvent:Connect(function()
	if inventoryWindow.Visible then
		task.defer(requestInventory)
	end
end)
useItemEvent.OnClientEvent:Connect(function()
	if inventoryWindow.Visible then
		task.defer(requestInventory)
	end
end)
equipPaintToolEvent.OnClientEvent:Connect(function()
	if inventoryWindow.Visible then
		task.defer(requestInventory)
	end
end)

if inventoryWindow.Visible then
	requestInventory()
end

print("[EditableInventoryBinder] InventoryWindow bound through server bridge.")
