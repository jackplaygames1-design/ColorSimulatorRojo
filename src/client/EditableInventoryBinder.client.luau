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
local tradeRequest = remotes:FindFirstChild("TradeRequest")

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
local PET_APPEARANCE_SOURCE_NAME = "PetAppearanceStudio"
local CONTENT_MARGIN = 22
local PANEL_PADDING = 14
local PANEL_GAP = 18
local MIN_DETAIL_WIDTH = 330
local MAX_DETAIL_WIDTH = 430
local MIN_CARD_WIDTH = 108
local MAX_CARD_WIDTH = 148
local CARD_GAP = 10
local TRADE_PICK_ACTIVE_ATTRIBUTE = "TradePickColorActive"
local TRADE_PICK_RETURN_ATTRIBUTE = "TradePickReturnWindow"
local TRADE_PICK_REFRESH_ATTRIBUTE = "TradePickRefreshToken"
local RUNTIME_LAYOUT_ATTRIBUTE = "AllowRuntimeInventoryLayout"

local mainHud = playerGui:WaitForChild("MainHUD", 30)
local modalWindows = mainHud and mainHud:WaitForChild("ModalWindows", 30)

local function waitForInventoryWindow()
	return modalWindows and modalWindows:WaitForChild("InventoryWindow", 30)
end

local inventoryWindow = waitForInventoryWindow()
if not inventoryWindow or not inventoryWindow:IsA("GuiObject") then
	warn("EditableInventoryBinder: missing PlayerGui.MainHUD.ModalWindows.InventoryWindow")
	return
end

local ui = {}
local cardConnections = {}
local viewportConnections = {}
local petAppearanceConnections = {}
local watchedPetAppearanceSource = nil
local petAppearanceRefreshQueued = false
local detailScrollWarningShown = false
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
	button.BackgroundTransparency = enabled == true and 0 or 0.35
	for _, descendant in ipairs(button:GetDescendants()) do
		if descendant:IsA("GuiObject") then
			descendant.Active = enabled == true
		end
	end
end

local function setButtonVisible(button, visible)
	if button and button:IsA("GuiObject") then
		button.Visible = visible == true
	end
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

local function getItemKey(item)
	if type(item) ~= "table" then
		return ""
	end

	local id = item.Id
		or item.id
		or item.Key
		or item.key
		or item.VariantKey
		or item.variantKey
		or item.PetId
		or item.petId
		or item.Name
		or item.name
	local keyParts = {
		tostring(item.Kind or item.kind or ""),
		tostring(id or ""),
		tostring(item.MutationId or item.Mutation or item.mutationId or ""),
		tostring(item.TraitId or item.Trait or item.traitId or ""),
		tostring(item.PersonalityId or item.Personality or item.personalityId or ""),
	}
	return table.concat(keyParts, "|")
end

local function isSameInventoryItem(left, right)
	local leftKey = getItemKey(left)
	return leftKey ~= "" and leftKey == getItemKey(right)
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
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
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

local function isTradePickActive()
	return mainHud and mainHud:GetAttribute(TRADE_PICK_ACTIVE_ATTRIBUTE) == true
end

local function finishTradePick()
	if not mainHud then
		return
	end
	mainHud:SetAttribute(TRADE_PICK_ACTIVE_ATTRIBUTE, false)
	local returnWindowName = tostring(mainHud:GetAttribute(TRADE_PICK_RETURN_ATTRIBUTE) or "TradeWindow")
	local returnWindow = modalWindows and modalWindows:FindFirstChild(returnWindowName)
	if inventoryWindow and inventoryWindow:IsA("GuiObject") then
		inventoryWindow.Visible = false
	end
	if returnWindow and returnWindow:IsA("GuiObject") then
		returnWindow.Visible = true
	end
	mainHud:SetAttribute(TRADE_PICK_REFRESH_ATTRIBUTE, os.clock())
end

local function tryAddPickedColorToTrade(item)
	if not isTradePickActive() then
		return false
	end
	if not item or item.Kind ~= "Color" then
		warn("EditableInventoryBinder: trade picker only accepts Color inventory cards.")
		return true
	end
	if not tradeRequest then
		tradeRequest = remotes:FindFirstChild("TradeRequest")
	end
	if not tradeRequest then
		warn("EditableInventoryBinder: missing ReplicatedStorage.Remotes.TradeRequest")
		return true
	end

	local ok, result = pcall(function()
		return tradeRequest:InvokeServer("AddColor", { ColorId = item.Id })
	end)
	if not ok then
		warn("EditableInventoryBinder: trade add failed: " .. tostring(result))
		return true
	end
	finishTradePick()
	return true
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
			applyInventoryIcon(tab, iconName)
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
	local named =
		findDescendantByNames(container, { "PreviewViewport", "PetModelPreview", "Viewport", "ViewportFrame" })
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

local STATIC_PREVIEW_NAMES = {
	BigPreview = true,
	IconText = true,
	IconImage = true,
	ItemPreview = true,
	PreviewFrame = true,
	PreviewIcon = true,
	PreviewImage = true,
	PreviewText = true,
}

local function clearGuiVisual(object)
	if object:IsA("ImageLabel") or object:IsA("ImageButton") then
		object.Image = ""
		object.ImageRectOffset = Vector2.new(0, 0)
		object.ImageRectSize = Vector2.new(0, 0)
	elseif object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
		object.Text = ""
	end
end

local function clearStaticPreviewContent(preview)
	if not preview or not preview:IsA("GuiObject") then
		return
	end

	clearGuiVisual(preview)
	for _, descendant in ipairs(preview:GetDescendants()) do
		if descendant:IsA("GuiObject") then
			clearGuiVisual(descendant)
		end
	end

	local scope = preview:IsA("ViewportFrame") and preview.Parent or nil
	if not scope then
		return
	end
	for _, descendant in ipairs(scope:GetDescendants()) do
		if
			descendant ~= preview
			and not descendant:IsDescendantOf(preview)
			and descendant:IsA("GuiObject")
			and STATIC_PREVIEW_NAMES[descendant.Name] == true
		then
			clearGuiVisual(descendant)
			for _, nested in ipairs(descendant:GetDescendants()) do
				if nested:IsA("GuiObject") then
					clearGuiVisual(nested)
				end
			end
		end
	end
end

local function setStaticPreviewVisible(preview, visible, includeLooseText)
	if not preview or not preview:IsA("GuiObject") then
		return
	end

	local scope = preview:IsA("ViewportFrame") and preview.Parent or preview
	if not scope then
		return
	end

	for _, descendant in ipairs(scope:GetDescendants()) do
		if descendant ~= preview and not descendant:IsDescendantOf(preview) and descendant:IsA("GuiObject") then
			if
				STATIC_PREVIEW_NAMES[descendant.Name] == true
				or (includeLooseText == true and (descendant:IsA("TextLabel") or descendant:IsA("TextButton")))
			then
				descendant.Visible = visible == true
			end
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

	viewport.Visible = true
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

	ui.gridPanel = ui.body:FindFirstChild("GridPanel") or ui.body:FindFirstChild("ItemGrid")
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

	ui.bigPreview = findChildByNames(ui.detailPanel, {
		"PreviewViewport",
		"PetModelPreview",
		"PreviewIcon",
		"BigPreview",
		"PreviewImage",
		"Preview",
		"Icon",
		"ItemPreview",
	})
	ui.selectedName =
		findChildByNames(ui.detailPanel, { "ItemName", "SelectedName", "NameLabel", "Name", "Title", "SelectLabel" })
	ui.selectedRarity =
		findChildByNames(ui.detailPanel, { "RarityLabel", "SelectedRarity", "Rarity", "Meta", "ItemMeta" })
	ui.selectedDescription =
		findChildByNames(ui.detailPanel, { "SelectedDescription", "Description", "ItemDescription" })
	ui.statsBox = findChildByNames(ui.detailPanel, { "StatsBox" })
	ui.statsText = findChildByNames(ui.detailPanel, { "StatsLabel", "StatsText", "Stats" })
	ui.equipButton = findChildByNames(ui.detailPanel, { "EquipButton", "UseButton", "PrimaryButton" })
	ui.lockButton = findChildByNames(ui.detailPanel, { "LockButton" })
	ui.deleteButton = findChildByNames(ui.detailPanel, { "DeleteButton" })
	return true
end

local function styleTextToFit(label, maxTextSize)
	if not label or not (label:IsA("TextLabel") or label:IsA("TextButton") or label:IsA("TextBox")) then
		return
	end
	label.TextScaled = true
	label.TextWrapped = label:IsA("TextLabel")
	label.TextTruncate = Enum.TextTruncate.AtEnd
	local constraint = label:FindFirstChildOfClass("UITextSizeConstraint")
	if constraint then
		constraint.MinTextSize = math.min(constraint.MinTextSize, 10)
		constraint.MaxTextSize = math.min(constraint.MaxTextSize, maxTextSize or 22)
	end
end

local function polishPreviewCard(card)
	if not card or not card:IsA("GuiObject") then
		return
	end

	card.ClipsDescendants = true
	local preview = findDescendantByNames(card, {
		"PreviewViewport",
		"PetModelPreview",
		"PreviewIcon",
		"Preview",
		"Icon",
		"ItemPreview",
		"PreviewFrame",
	})
	if preview and preview:IsA("GuiObject") then
		preview.AnchorPoint = Vector2.new(0.5, 0)
		preview.Position = UDim2.new(0.5, 0, 0, 8)
		preview.Size = UDim2.new(1, -20, 0.56, -8)
		preview.ClipsDescendants = true
	end

	local name = findDescendantByNames(card, { "Name", "ItemName", "Title", "ItemTitle" })
	if name and (name:IsA("TextLabel") or name:IsA("TextButton") or name:IsA("TextBox")) then
		name.Position = UDim2.new(0, 8, 0.62, 0)
		name.Size = UDim2.new(1, -16, 0, 22)
		name.TextXAlignment = Enum.TextXAlignment.Center
		styleTextToFit(name, 16)
	end

	local meta = findDescendantByNames(card, { "Meta", "ItemMeta", "Rarity", "Amount", "Status" })
	if meta and (meta:IsA("TextLabel") or meta:IsA("TextButton") or meta:IsA("TextBox")) then
		meta.Position = UDim2.new(0, 8, 1, -28)
		meta.Size = UDim2.new(1, -16, 0, 18)
		meta.TextXAlignment = Enum.TextXAlignment.Center
		styleTextToFit(meta, 13)
	end
end

local function layoutCards()
	if not ui.gridPanel or not ui.itemCards then
		return
	end

	local gridSize = ui.gridPanel.AbsoluteSize
	if gridSize.X <= 0 or gridSize.Y <= 0 then
		return
	end

	local innerWidth = math.max(1, gridSize.X - PANEL_PADDING * 2)
	local targetWidth = 126
	local columns = math.max(2, math.floor((innerWidth + CARD_GAP) / (targetWidth + CARD_GAP)))
	local cardWidth = math.floor((innerWidth - CARD_GAP * (columns - 1)) / columns)
	cardWidth = math.clamp(cardWidth, MIN_CARD_WIDTH, MAX_CARD_WIDTH)
	columns = math.max(2, math.floor((innerWidth + CARD_GAP) / (cardWidth + CARD_GAP)))

	local totalWidth = columns * cardWidth + math.max(0, columns - 1) * CARD_GAP
	local startX = PANEL_PADDING + math.max(0, math.floor((innerWidth - totalWidth) * 0.5))
	local cardHeight = math.floor(cardWidth * 0.9)

	for index, card in ipairs(ui.itemCards) do
		if card:IsA("GuiObject") then
			local col = (index - 1) % columns
			local row = math.floor((index - 1) / columns)
			card.Position =
				UDim2.fromOffset(startX + col * (cardWidth + CARD_GAP), PANEL_PADDING + row * (cardHeight + CARD_GAP))
			card.Size = UDim2.fromOffset(cardWidth, cardHeight)
			card.LayoutOrder = index
			polishPreviewCard(card)
		end
	end

	local rows = math.ceil(#ui.itemCards / columns)
	local contentHeight = PANEL_PADDING * 2 + rows * cardHeight + math.max(0, rows - 1) * CARD_GAP
	if ui.gridPanel:IsA("ScrollingFrame") then
		ui.gridPanel.AutomaticCanvasSize = Enum.AutomaticSize.None
		ui.gridPanel.CanvasSize = UDim2.fromOffset(0, contentHeight)
		ui.gridPanel.ScrollBarThickness = 8
	end

	if ui.emptyText and ui.emptyText:IsA("GuiObject") then
		ui.emptyText.AnchorPoint = Vector2.new(0.5, 0.5)
		ui.emptyText.Position = UDim2.fromScale(0.5, 0.5)
		ui.emptyText.Size = UDim2.new(1, -40, 0, 40)
	end
	if ui.footer and ui.footer:IsA("GuiObject") then
		ui.footer.AnchorPoint = Vector2.new(0, 1)
		ui.footer.Position = UDim2.new(0, PANEL_PADDING, 1, -PANEL_PADDING)
		ui.footer.Size = UDim2.new(1, -PANEL_PADDING * 2, 0, 28)
	end
end

local function polishDetails(detailWidth)
	if not ui.detailPanel or not ui.detailPanel:IsA("GuiObject") then
		return
	end

	ui.detailPanel.ClipsDescendants = true
	local detailContentHeight = 480
	if ui.detailPanel:IsA("ScrollingFrame") then
		ui.detailPanel.AutomaticCanvasSize = Enum.AutomaticSize.None
		ui.detailPanel.CanvasSize = UDim2.fromOffset(0, detailContentHeight)
		ui.detailPanel.ScrollingDirection = Enum.ScrollingDirection.Y
		ui.detailPanel.ScrollingEnabled = true
		ui.detailPanel.ScrollBarThickness = 8
		ui.detailPanel.ScrollBarImageColor3 = Color3.fromRGB(92, 98, 116)
	else
		if not detailScrollWarningShown then
			detailScrollWarningShown = true
			warn("EditableInventoryBinder: InventoryWindow.Content.DetailsPanel should be a ScrollingFrame for tall pet details.")
		end
	end

	if ui.bigPreview and ui.bigPreview:IsA("GuiObject") then
		ui.bigPreview.AnchorPoint = Vector2.new(0.5, 0)
		ui.bigPreview.Position = UDim2.new(0.5, 0, 0, 18)
		ui.bigPreview.Size = UDim2.fromOffset(math.min(170, detailWidth - 90), 118)
		ui.bigPreview.ClipsDescendants = true
	end

	if ui.selectedName and ui.selectedName:IsA("GuiObject") then
		ui.selectedName.Position = UDim2.fromOffset(24, 152)
		ui.selectedName.Size = UDim2.new(1, -48, 0, 34)
		styleTextToFit(ui.selectedName, 24)
	end
	if ui.selectedRarity and ui.selectedRarity:IsA("GuiObject") then
		ui.selectedRarity.Position = UDim2.fromOffset(24, 188)
		ui.selectedRarity.Size = UDim2.new(1, -48, 0, 24)
		styleTextToFit(ui.selectedRarity, 16)
	end
	if ui.selectedDescription and ui.selectedDescription:IsA("GuiObject") then
		ui.selectedDescription.Position = UDim2.fromOffset(28, 220)
		ui.selectedDescription.Size = UDim2.new(1, -56, 0, 56)
		styleTextToFit(ui.selectedDescription, 15)
	end
	if ui.statsBox and ui.statsBox:IsA("GuiObject") then
		ui.statsBox.Position = UDim2.fromOffset(28, 286)
		ui.statsBox.Size = UDim2.new(1, -56, 0, 88)
		ui.statsBox.ClipsDescendants = true
	end
	if ui.statsText and ui.statsText:IsA("GuiObject") then
		ui.statsText.Position = UDim2.fromOffset(10, 8)
		ui.statsText.Size = UDim2.new(1, -20, 1, -16)
		styleTextToFit(ui.statsText, 14)
	end

	local buttonWidth = math.max(86, math.floor((detailWidth - 76) / 3))
	local buttonY = 404
	if ui.equipButton and ui.equipButton:IsA("GuiObject") then
		ui.equipButton.Position = UDim2.fromOffset(22, buttonY)
		ui.equipButton.Size = UDim2.fromOffset(buttonWidth, 40)
	end
	if ui.lockButton and ui.lockButton:IsA("GuiObject") then
		ui.lockButton.Position = UDim2.new(0.5, -buttonWidth * 0.5, 0, buttonY)
		ui.lockButton.Size = UDim2.fromOffset(buttonWidth, 40)
	end
	if ui.deleteButton and ui.deleteButton:IsA("GuiObject") then
		ui.deleteButton.Position = UDim2.new(1, -buttonWidth - 22, 0, buttonY)
		ui.deleteButton.Size = UDim2.fromOffset(buttonWidth, 40)
	end
end

local function polishInventoryLayout()
	if not inventoryWindow:GetAttribute(RUNTIME_LAYOUT_ATTRIBUTE) then
		return
	end

	if not ui.body or not ui.gridPanel or not ui.detailPanel then
		return
	end

	inventoryWindow.ClipsDescendants = false
	if ui.tabs and ui.tabs:IsA("GuiObject") then
		ui.tabs.Position = UDim2.fromOffset(CONTENT_MARGIN, 68)
		ui.tabs.Size = UDim2.new(1, -CONTENT_MARGIN * 2, 0, 42)
	end
	ui.body.Position = UDim2.fromOffset(CONTENT_MARGIN, 122)
	ui.body.Size = UDim2.new(1, -CONTENT_MARGIN * 2, 1, -148)
	ui.body.ClipsDescendants = false

	local bodyWidth = ui.body.AbsoluteSize.X
	if bodyWidth <= 0 then
		return
	end

	local detailWidth = math.clamp(math.floor(bodyWidth * 0.34), MIN_DETAIL_WIDTH, MAX_DETAIL_WIDTH)
	if bodyWidth < 850 then
		detailWidth = math.clamp(math.floor(bodyWidth * 0.38), 300, 360)
	end

	ui.gridPanel.Position = UDim2.fromOffset(PANEL_PADDING, PANEL_PADDING)
	ui.gridPanel.Size = UDim2.new(1, -(detailWidth + PANEL_GAP + PANEL_PADDING * 2), 1, -PANEL_PADDING * 2)
	ui.gridPanel.ClipsDescendants = true

	ui.detailPanel.Position = UDim2.new(1, -(detailWidth + PANEL_PADDING), 0, PANEL_PADDING)
	ui.detailPanel.Size = UDim2.new(0, detailWidth, 1, -PANEL_PADDING * 2)

	layoutCards()
	polishDetails(detailWidth)
end

local layoutQueued = false
local function queueInventoryLayout()
	if layoutQueued then
		return
	end
	layoutQueued = true
	task.defer(function()
		layoutQueued = false
		polishInventoryLayout()
	end)
end

local function clearPreview(preview, keepStaticVisible)
	if not preview or not preview:IsA("GuiObject") then
		return preview
	end
	local showStatic = keepStaticVisible ~= false
	preview.Visible = showStatic
	setStaticPreviewVisible(preview, showStatic)
	local viewport = findViewportPreview(preview)
	if viewport then
		clearViewportPreview(viewport)
		viewport.Visible = false
	end
	if not showStatic then
		clearStaticPreviewContent(preview)
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
	local isDetailsPreview = preview == ui.bigPreview or preview:IsDescendantOf(ui.detailPanel)
	if mountPetViewport(viewport, item, isDetailsPreview) then
		setStaticPreviewVisible(viewport, false, not isDetailsPreview)
		return
	end
	if viewport then
		viewport.Visible = false
	end
	setExistingPreviewImage(preview, item)
	setExistingPreviewText(preview, item)
end

local function applyCardStroke(card, item)
	local stroke = card and card:FindFirstChildOfClass("UIStroke")
	if not stroke then
		return
	end

	local itemKey = item and getItemKey(item) or tostring(card:GetAttribute("InventoryItemKey") or "")
	local selectedKey = selectedItem and getItemKey(selectedItem) or ""
	local selected = itemKey ~= "" and itemKey == selectedKey
	local displayedEquipped = item and isDisplayedEquipped(item) or card:GetAttribute("InventoryItemEquipped") == true
	local locked = (item and item.Locked == true) or card:GetAttribute("InventoryItemLocked") == true

	if selected then
		stroke.Color = Color3.fromRGB(75, 214, 232)
		stroke.Thickness = 4
	elseif displayedEquipped then
		stroke.Color = Color3.fromRGB(84, 225, 112)
		stroke.Thickness = 4
	else
		stroke.Color = locked and Color3.fromRGB(88, 174, 255) or Color3.fromRGB(35, 38, 45)
		stroke.Thickness = 2
	end
end

local function refreshCardSelectionVisuals()
	for _, card in ipairs(ui.itemCards or {}) do
		if card:IsA("GuiObject") then
			applyCardStroke(card)
		end
	end
end

local function makeCard(item, index)
	local card = ui.itemCards and ui.itemCards[index]
	if not card then
		return
	end
	card.Visible = true
	card:SetAttribute("InventoryItemId", item.Id or "")
	card:SetAttribute("InventoryItemKind", item.Kind or "")
	card:SetAttribute("InventoryItemKey", getItemKey(item))
	if card:IsA("TextButton") then
		card.Text = ""
	end
	if card:IsA("TextButton") or card:IsA("ImageButton") then
		card.AutoButtonColor = true
	end

	local preview = findDescendantByNames(
		card,
		{ "PreviewViewport", "PetModelPreview", "PreviewIcon", "Preview", "Icon", "ItemPreview", "PreviewFrame" }
	)
	if preview and preview:IsA("GuiObject") then
		paintPreview(preview, item)
	end

	local name = findDescendantByNames(card, { "Name", "ItemName", "Title", "ItemTitle" })
	setText(name, item.Name or item.Id or "Color")

	local meta = findDescendantByNames(card, { "Meta", "ItemMeta", "Rarity", "Amount", "Status" })
	local displayedEquipped = isDisplayedEquipped(item)
	card:SetAttribute("InventoryItemEquipped", displayedEquipped)
	card:SetAttribute("InventoryItemLocked", item.Locked == true)
	setText(
		meta,
		displayedEquipped and "EQUIPPED"
			or (item.Amount and ("x" .. tostring(item.Amount)) or tostring(item.Rarity or ""))
	)

	applyCardStroke(card, item)

	local lastSelectAt = 0
	local function selectItem()
		local now = os.clock()
		if now - lastSelectAt < 0.08 then
			return
		end
		lastSelectAt = now
		if tryAddPickedColorToTrade(item) then
			return
		end
		selectedItem = item
		renderDetails()
		refreshCardSelectionVisuals()
	end
	connectCardSelection(card, selectItem)
end

renderDetails = function()
	local item = selectedItem
	if not item then
		clearPreview(ui.bigPreview, false)
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
		setButtonVisible(ui.equipButton, false)
		setButtonVisible(ui.lockButton, false)
		setButtonVisible(ui.deleteButton, false)
		return
	end

	setButtonVisible(ui.equipButton, true)
	setButtonVisible(ui.lockButton, true)
	setButtonVisible(ui.deleteButton, true)
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
	polishInventoryLayout()
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
		ui.capacityText.Text = "Colors: "
			.. tostring(inventoryData.Count or 0)
			.. " / "
			.. tostring(inventoryData.Capacity or 75)
	end

	for index, item in ipairs(items) do
		makeCard(item, index)
	end
	for index = #items + 1, #(ui.itemCards or {}) do
		local card = ui.itemCards[index]
		card.Visible = false
		card:SetAttribute("InventoryItemId", "")
		card:SetAttribute("InventoryItemKind", "")
		card:SetAttribute("InventoryItemKey", "")
		card:SetAttribute("InventoryItemEquipped", false)
		card:SetAttribute("InventoryItemLocked", false)
		local preview = findDescendantByNames(
			card,
			{ "PreviewViewport", "PetModelPreview", "PreviewIcon", "Preview", "Icon", "ItemPreview", "PreviewFrame" }
		)
		if preview and preview:IsA("GuiObject") then
			clearPreview(preview, false)
		end
		setText(findDescendantByNames(card, { "Name", "ItemName", "Title", "ItemTitle" }), "")
		setText(findDescendantByNames(card, { "Meta", "ItemMeta", "Rarity", "Amount", "Status" }), "")
		applyCardStroke(card)
	end

	if selectedItem then
		local stillExists = false
		for _, item in ipairs(items) do
			if isSameInventoryItem(item, selectedItem) then
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
	polishInventoryLayout()
end

local function disconnectPetAppearanceWatch()
	for _, connection in ipairs(petAppearanceConnections) do
		if connection and connection.Connected then
			connection:Disconnect()
		end
	end
	table.clear(petAppearanceConnections)
	watchedPetAppearanceSource = nil
end

local function queuePetAppearanceRefresh()
	if petAppearanceRefreshQueued then
		return
	end
	petAppearanceRefreshQueued = true
	task.delay(0.2, function()
		petAppearanceRefreshQueued = false
		if inventoryWindow.Visible then
			renderInventory()
		end
	end)
end

local function watchPetAppearanceObject(object)
	table.insert(petAppearanceConnections, object.Changed:Connect(queuePetAppearanceRefresh))
end

local function watchPetAppearanceSource(source)
	if not source or watchedPetAppearanceSource == source then
		return
	end

	disconnectPetAppearanceWatch()
	watchedPetAppearanceSource = source
	watchPetAppearanceObject(source)

	for _, descendant in ipairs(source:GetDescendants()) do
		watchPetAppearanceObject(descendant)
	end

	table.insert(
		petAppearanceConnections,
		source.DescendantAdded:Connect(function(descendant)
			watchPetAppearanceObject(descendant)
			queuePetAppearanceRefresh()
		end)
	)
	table.insert(petAppearanceConnections, source.DescendantRemoving:Connect(queuePetAppearanceRefresh))
	table.insert(
		petAppearanceConnections,
		source.AncestryChanged:Connect(function(_, parent)
			if not parent then
				disconnectPetAppearanceWatch()
				return
			end
			queuePetAppearanceRefresh()
		end)
	)
end

local function findPetAppearanceSource()
	return ReplicatedStorage:FindFirstChild(PET_APPEARANCE_SOURCE_NAME)
		or workspace:FindFirstChild(PET_APPEARANCE_SOURCE_NAME)
end

local function startPetAppearanceWatch()
	local function refreshSource()
		local source = findPetAppearanceSource()
		if source then
			watchPetAppearanceSource(source)
		end
	end

	ReplicatedStorage.ChildAdded:Connect(function(child)
		if child.Name == PET_APPEARANCE_SOURCE_NAME then
			refreshSource()
		end
	end)
	workspace.ChildAdded:Connect(function(child)
		if child.Name == PET_APPEARANCE_SOURCE_NAME then
			refreshSource()
		end
	end)

	refreshSource()
	task.delay(1, refreshSource)
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
			if
				selectedItem
				and selectedItem.Kind == "Color"
				and not selectedItem.Locked
				and not selectedItem.Equipped
			then
				sendAction("Delete", selectedItem)
			end
		end)
	end
end

if not prepareStructure() then
	return
end
polishInventoryLayout()
inventoryWindow:GetPropertyChangedSignal("AbsoluteSize"):Connect(queueInventoryLayout)
ui.body:GetPropertyChangedSignal("AbsoluteSize"):Connect(queueInventoryLayout)
ui.gridPanel:GetPropertyChangedSignal("AbsoluteSize"):Connect(queueInventoryLayout)
applyInventoryIcons()
wireControls()
renderDetails()
startPetAppearanceWatch()

inventoryWindow:GetPropertyChangedSignal("Visible"):Connect(function()
	if inventoryWindow.Visible then
		if isTradePickActive() then
			currentTab = "Colors"
			selectedItem = nil
		end
		queueInventoryLayout()
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
