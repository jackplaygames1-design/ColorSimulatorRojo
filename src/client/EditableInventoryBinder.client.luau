-- Binds the editable Studio InventoryWindow to server-owned inventory data.
-- This script only populates existing UI and sends requests. It never grants,
-- equips, deletes, or consumes anything locally.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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
local paintToolState = ReplicatedStorage:FindFirstChild("PaintToolEquippedState")
local paintToolEquipChanged = ReplicatedStorage:FindFirstChild("PaintToolEquipChanged")

local InventoryIconConfig = require(ReplicatedStorage:WaitForChild("InventoryIconConfig"))
local PetModelUtil = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PetModelUtil"))

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
local viewportConnections = {}
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

local function disconnectViewport(viewport)
	local connection = viewportConnections[viewport]
	if connection and connection.Connected then
		connection:Disconnect()
	end
	viewportConnections[viewport] = nil
end

local function disconnectViewports()
	for viewport, connection in pairs(viewportConnections) do
		if connection and connection.Connected then
			connection:Disconnect()
		end
		viewportConnections[viewport] = nil
	end
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

local function getPaintToolState()
	if not (paintToolState and paintToolState.Parent) then
		paintToolState = ReplicatedStorage:FindFirstChild("PaintToolEquippedState")
	end
	return paintToolState
end

local function getPaintToolEquipChanged()
	if not (paintToolEquipChanged and paintToolEquipChanged.Parent) then
		paintToolEquipChanged = ReplicatedStorage:FindFirstChild("PaintToolEquipChanged")
	end
	return paintToolEquipChanged
end

local function isPaintToolActive()
	local state = getPaintToolState()
	return not (state and state:IsA("BoolValue")) or state.Value == true
end

local function setPaintToolActive(active)
	local state = getPaintToolState()
	if state and state:IsA("BoolValue") then
		state.Value = active == true
	end
	local event = getPaintToolEquipChanged()
	if event and event:IsA("BindableEvent") then
		event:Fire(active == true)
	end
end

local function isDisplayedEquipped(item)
	if not item or item.Equipped ~= true then
		return false
	end
	if item.Kind == "Brush" then
		return isPaintToolActive()
	end
	return true
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

local function getItemIconName(item)
	if not item then
		return nil
	end
	if item.IconName then
		return item.IconName
	end
	if item.Kind == "Color" then
		return "Sparkle"
	elseif item.Kind == "Brush" then
		return "Tag"
	elseif item.Kind == "Potion" then
		return "Stats"
	elseif item.Kind == "Item" then
		return "Inspect"
	end
	return nil
end

local function applyImageToIcon(icon, imageId, spec, usesSheet, tint)
	if not icon or not (icon:IsA("ImageLabel") or icon:IsA("ImageButton")) then
		return false
	end
	if imageId and imageId ~= "" then
		icon.Image = imageId
	end
	if usesSheet then
		icon.ImageRectOffset = spec and spec.RectOffset or Vector2.new(0, 0)
		icon.ImageRectSize = spec and spec.RectSize or Vector2.new(0, 0)
	else
		icon.ImageRectOffset = Vector2.new(0, 0)
		icon.ImageRectSize = Vector2.new(0, 0)
	end
	if tint then
		icon.ImageColor3 = tint
	end
	return true
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
		"IconImage",
		"Image",
		"Icon",
	})
	if icon and (icon:IsA("ImageLabel") or icon:IsA("ImageButton")) then
		return icon
	end
	for _, descendant in ipairs(button:GetDescendants()) do
		if descendant:IsA("ImageLabel") or descendant:IsA("ImageButton") then
			return descendant
		end
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

	applyImageToIcon(icon, imageId, spec, usesSheet)
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

local function findViewportPreview(container)
	if not container then
		return nil
	end
	if container:IsA("ViewportFrame") then
		return container
	end
	local named = findDescendantByNames(container, { "PreviewViewport", "PetModelPreview", "Viewport", "ViewportFrame" })
	if named and named:IsA("ViewportFrame") then
		return named
	end
	return container:FindFirstChildWhichIsA("ViewportFrame", true)
end

local function clearViewportPreview(viewport)
	if not viewport or not viewport:IsA("ViewportFrame") then
		return
	end
	disconnectViewport(viewport)
	if viewport.CurrentCamera and viewport.CurrentCamera:GetAttribute("EditableInventoryViewportAsset") == true then
		viewport.CurrentCamera = nil
	end
	for _, child in ipairs(viewport:GetChildren()) do
		if child:GetAttribute("EditableInventoryViewportAsset") == true then
			child:Destroy()
		end
	end
end

local function mountPetViewport(viewport, item, large)
	if not viewport or not viewport:IsA("ViewportFrame") or not item or item.Kind ~= "Color" or not item.PetId then
		return false
	end

	clearViewportPreview(viewport)

	local ok, model = pcall(function()
		return PetModelUtil.ClonePetModel(item.PetId, {
			anchored = true,
			mutationId = item.MutationId or item.Mutation,
		})
	end)
	if not ok or not model then
		return false
	end

	local world = Instance.new("WorldModel")
	world.Name = "EditableInventoryPreviewWorld"
	world:SetAttribute("EditableInventoryViewportAsset", true)
	world.Parent = viewport

	local camera = Instance.new("Camera")
	camera.Name = "EditableInventoryPreviewCamera"
	camera:SetAttribute("EditableInventoryViewportAsset", true)
	camera.FieldOfView = large and 30 or 34
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	model.Parent = world
	local targetSize = large and 3.5 or 2.9
	local extents = model:GetExtentsSize()
	local largest = math.max(extents.X, extents.Y, extents.Z)
	if largest > 0 and largest > targetSize then
		pcall(function()
			model:ScaleTo(targetSize / largest)
		end)
	end

	local angle = math.rad(22)
	model:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, angle, 0))
	camera.CFrame = CFrame.new(0, large and 0.52 or 0.42, large and 6.8 or 6.1) * CFrame.Angles(math.rad(-5), 0, 0)

	viewport.Ambient = Color3.fromRGB(210, 220, 255)
	viewport.LightColor = Color3.fromRGB(255, 255, 245)
	viewport.LightDirection = Vector3.new(-0.45, -0.75, -0.3)

	viewportConnections[viewport] = RunService.RenderStepped:Connect(function(deltaTime)
		if not viewport.Parent or not model.Parent then
			disconnectViewport(viewport)
			return
		end
		angle += deltaTime * 0.8
		model:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, angle, 0))
	end)

	return true
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

	ui.bigPreview = findChildByNames(ui.detailPanel, { "PreviewViewport", "PetModelPreview", "PreviewIcon", "BigPreview", "PreviewImage", "Preview", "Icon", "ItemPreview" })
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
	if not preview or not preview:IsA("GuiObject") then
		return preview
	end
	local viewport = findViewportPreview(preview)
	if viewport then
		clearViewportPreview(viewport)
	end
	return preview
end

local function setExistingPreviewImage(preview, item)
	local imageId = item.IconImage
	local iconSpec = nil
	local usesSheet = false
	if not imageId or imageId == "" then
		local iconName = getItemIconName(item)
		imageId, iconSpec, usesSheet = getInventoryIconImage(iconName)
	end
	if preview:IsA("ImageLabel") or preview:IsA("ImageButton") then
		return applyImageToIcon(preview, imageId, iconSpec, usesSheet, item.IconColor)
	end

	local image = findDescendantByNames(preview, { "PreviewImage", "IconImage", "Image", "Icon" })
	if image and (image:IsA("ImageLabel") or image:IsA("ImageButton")) then
		return applyImageToIcon(image, imageId, iconSpec, usesSheet, item.IconColor)
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
	local viewport = findViewportPreview(preview)
	if mountPetViewport(viewport, item, preview == ui.bigPreview or preview:IsDescendantOf(ui.detailPanel)) then
		return
	end
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

	local preview = findDescendantByNames(card, { "PreviewViewport", "PetModelPreview", "PreviewIcon", "Preview", "Icon", "ItemPreview", "PreviewFrame" })
	if preview and preview:IsA("GuiObject") then
		paintPreview(preview, item)
	end

	local name = findDescendantByNames(card, { "Name", "ItemName", "Title", "ItemTitle" })
	setText(name, item.Name or item.Id or "Color")

	local meta = findDescendantByNames(card, { "Meta", "ItemMeta", "Rarity", "Amount", "Status" })
	local displayedEquipped = isDisplayedEquipped(item)
	setText(meta, displayedEquipped and "EQUIPPED" or (item.Amount and ("x" .. tostring(item.Amount)) or tostring(item.Rarity or "")))

	local stroke = card:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = displayedEquipped and Color3.fromRGB(84, 225, 112) or (item.Locked and Color3.fromRGB(88, 174, 255) or Color3.fromRGB(35, 38, 45))
		stroke.Thickness = displayedEquipped and 4 or 2
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

	local displayedEquipped = isDisplayedEquipped(item)
	if item.Kind == "Color" then
		setButtonText(ui.equipButton, item.Equipped and "UNEQUIP" or "EQUIP")
		setButtonEnabled(ui.equipButton, true)
		setButtonText(ui.lockButton, item.Locked and "UNLOCK" or "LOCK")
		setButtonEnabled(ui.lockButton, true)
		setButtonText(ui.deleteButton, "DELETE")
		setButtonEnabled(ui.deleteButton, not item.Locked and not item.Equipped)
	elseif item.Kind == "Brush" then
		setButtonText(ui.equipButton, displayedEquipped and "UNEQUIP" or "EQUIP")
		setButtonEnabled(ui.equipButton, true)
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
	disconnectViewports()
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
		local preview = findDescendantByNames(card, { "PreviewViewport", "PetModelPreview", "PreviewIcon", "Preview", "Icon", "ItemPreview", "PreviewFrame" })
		if preview and preview:IsA("GuiObject") then
			clearPreview(preview)
		end
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
				local active = isDisplayedEquipped(selectedItem)
				setPaintToolActive(not active)
				sendAction(active and "Unequip" or "Equip", selectedItem)
				renderInventory()
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
if paintToolState and paintToolState:IsA("BoolValue") then
	paintToolState:GetPropertyChangedSignal("Value"):Connect(function()
		if inventoryWindow.Visible then
			renderInventory()
		end
	end)
end

if inventoryWindow.Visible then
	requestInventory()
end

print("[EditableInventoryBinder] InventoryWindow bound through server bridge.")
