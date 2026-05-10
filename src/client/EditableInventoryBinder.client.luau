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
local renderDetails

local function disconnectCards()
	for _, connection in ipairs(cardConnections) do
		if connection and connection.Connected then
			connection:Disconnect()
		end
	end
	table.clear(cardConnections)
end

local function ensureFrame(parent, name, className)
	local frame = parent:FindFirstChild(name)
	if frame and frame:IsA("GuiObject") then
		return frame
	end
	frame = Instance.new(className or "Frame")
	frame.Name = name
	frame.BackgroundTransparency = className == "ScrollingFrame" and 1 or 0
	frame.BackgroundColor3 = Color3.fromRGB(244, 248, 252)
	frame.BorderSizePixel = 0
	frame.Parent = parent
	return frame
end

local function ensureLabel(parent, name, text)
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
	label.TextSize = 14
	label.Text = text or ""
	label.Parent = parent
	return label
end

local function ensureButton(parent, name, text)
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
	button.TextSize = 15
	button.Text = text or "OK"
	button.Parent = parent
	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 10)
	return button
end

local function setText(object, value)
	if object and (object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox")) then
		object.Text = tostring(value or "")
	end
end

local function setButtonEnabled(button, enabled)
	button.Visible = true
	button.Active = enabled == true
	button.AutoButtonColor = enabled == true
	button.BackgroundTransparency = enabled and 0 or 0.35
end

local function getSlotIndex(slot)
	return tonumber(string.match(slot.Name, "^Slot(%d+)$")) or math.huge
end

local function collectEditableSlots(parent)
	local slots = {}
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("GuiObject") and string.match(child.Name, "^Slot%d+$") then
			table.insert(slots, child)
		end
	end
	table.sort(slots, function(a, b)
		return getSlotIndex(a) < getSlotIndex(b)
	end)
	return slots
end

local function prepareStructure()
	ui.tabs = inventoryWindow:FindFirstChild("Tabs") or ensureFrame(inventoryWindow, "Tabs")
	ui.body = inventoryWindow:FindFirstChild("Content") or inventoryWindow:FindFirstChild("Body") or ensureFrame(inventoryWindow, "Content")
	ui.body.Position = ui.body.Position == UDim2.new() and UDim2.fromOffset(22, 122) or ui.body.Position
	ui.body.Size = ui.body.Size == UDim2.new() and UDim2.new(1, -44, 1, -148) or ui.body.Size

	ui.gridPanel = ui.body:FindFirstChild("ItemGrid") or ui.body:FindFirstChild("GridPanel") or ensureFrame(ui.body, "ItemGrid")
	ui.gridPanel.Position = UDim2.fromOffset(12, 12)
	ui.gridPanel.Size = UDim2.new(0.62, -20, 1, -24)
	ui.gridPanel.BackgroundColor3 = Color3.fromRGB(246, 249, 255)
	ui.slots = collectEditableSlots(ui.gridPanel)
	ui.usesEditableSlots = #ui.slots > 0

	if ui.usesEditableSlots then
		ui.grid = ui.gridPanel
	else
		ui.grid = ui.gridPanel:FindFirstChild("Grid") or ensureFrame(ui.gridPanel, "Grid", "ScrollingFrame")
		ui.grid.Position = UDim2.fromOffset(8, 8)
		ui.grid.Size = UDim2.new(1, -16, 1, -48)
		ui.grid.ScrollBarThickness = 6
		ui.grid.CanvasSize = UDim2.fromOffset(0, 0)

		local layout = ui.grid:FindFirstChildOfClass("UIGridLayout") or Instance.new("UIGridLayout")
		layout.CellPadding = UDim2.fromOffset(10, 10)
		layout.CellSize = UDim2.fromOffset(146, 140)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = ui.grid
		if not ui.grid:GetAttribute("InventoryLayoutBound") then
			ui.grid:SetAttribute("InventoryLayoutBound", true)
			layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
				ui.grid.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 20)
			end)
		end
	end

	ui.emptyText = ensureLabel(ui.gridPanel, "EmptyText", "")
	ui.emptyText.Position = UDim2.fromOffset(12, 52)
	ui.emptyText.Size = UDim2.new(1, -24, 0, 70)
	ui.emptyText.Font = Enum.Font.GothamBlack
	ui.emptyText.TextSize = 20
	ui.emptyText.TextXAlignment = Enum.TextXAlignment.Center
	ui.emptyText.TextYAlignment = Enum.TextYAlignment.Center
	ui.emptyText.Visible = false

	ui.footer = ui.gridPanel:FindFirstChild("Footer") or ensureFrame(ui.gridPanel, "Footer")
	ui.footer.Position = UDim2.new(0, 8, 1, -38)
	ui.footer.Size = UDim2.new(1, -16, 0, 30)
	ui.footer.BackgroundTransparency = 1
	ui.capacityText = ensureLabel(ui.footer, "CapacityText", "")
	ui.capacityText.Size = UDim2.fromScale(1, 1)
	ui.capacityText.TextXAlignment = Enum.TextXAlignment.Right

	ui.detailPanel = ui.body:FindFirstChild("DetailsPanel") or ui.body:FindFirstChild("DetailPanel") or ensureFrame(ui.body, "DetailsPanel")
	ui.detailPanel.Position = UDim2.new(0.64, 0, 0, 12)
	ui.detailPanel.Size = UDim2.new(0.36, -12, 1, -24)
	ui.detailPanel.BackgroundColor3 = Color3.fromRGB(239, 246, 255)

	ui.bigPreview = ui.detailPanel:FindFirstChild("BigPreview") or ensureFrame(ui.detailPanel, "BigPreview")
	ui.bigPreview.Position = UDim2.fromOffset(16, 16)
	ui.bigPreview.Size = UDim2.new(1, -32, 0, 112)
	ui.bigPreview.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	ui.selectedName = ui.detailPanel:FindFirstChild("SelectedName") or ui.detailPanel:FindFirstChild("SelectLabel") or ensureLabel(ui.detailPanel, "SelectedName", "Select an Item")
	ui.selectedName.Position = UDim2.fromOffset(16, 138)
	ui.selectedName.Size = UDim2.new(1, -32, 0, 32)
	ui.selectedName.Font = Enum.Font.GothamBlack
	ui.selectedName.TextSize = 20
	ui.selectedRarity = ensureLabel(ui.detailPanel, "SelectedRarity", "")
	ui.selectedRarity.Position = UDim2.fromOffset(16, 172)
	ui.selectedRarity.Size = UDim2.new(1, -32, 0, 26)
	ui.selectedDescription = ensureLabel(ui.detailPanel, "SelectedDescription", "Choose a card to see details.")
	ui.selectedDescription.Position = UDim2.fromOffset(16, 202)
	ui.selectedDescription.Size = UDim2.new(1, -32, 0, 58)
	ui.statsBox = ui.detailPanel:FindFirstChild("StatsBox") or ensureFrame(ui.detailPanel, "StatsBox")
	ui.statsBox.Position = UDim2.fromOffset(16, 268)
	ui.statsBox.Size = UDim2.new(1, -32, 0, 78)
	ui.statsBox.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	ui.statsText = ensureLabel(ui.statsBox, "StatsText", "")
	ui.statsText.Position = UDim2.fromOffset(10, 8)
	ui.statsText.Size = UDim2.new(1, -20, 1, -16)

	ui.equipButton = ensureButton(ui.detailPanel, "EquipButton", "EQUIP")
	ui.equipButton.Position = UDim2.new(0, 16, 1, -130)
	ui.equipButton.Size = UDim2.new(1, -32, 0, 34)
	ui.lockButton = ensureButton(ui.detailPanel, "LockButton", "LOCK")
	ui.lockButton.Position = UDim2.new(0, 16, 1, -88)
	ui.lockButton.Size = UDim2.new(1, -32, 0, 34)
	ui.deleteButton = ensureButton(ui.detailPanel, "DeleteButton", "DELETE")
	ui.deleteButton.Position = UDim2.new(0, 16, 1, -46)
	ui.deleteButton.Size = UDim2.new(1, -32, 0, 34)

	ui.cardTemplate = ui.grid:FindFirstChild("ItemCardTemplate")
	if not ui.cardTemplate and not ui.usesEditableSlots then
		ui.cardTemplate = Instance.new("TextButton")
		ui.cardTemplate.Name = "ItemCardTemplate"
		ui.cardTemplate.Visible = false
		ui.cardTemplate.Text = ""
		ui.cardTemplate.AutoButtonColor = true
		ui.cardTemplate.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		ui.cardTemplate.BorderSizePixel = 0
		ui.cardTemplate.Size = UDim2.fromOffset(146, 140)
		ui.cardTemplate.Parent = ui.grid
		Instance.new("UICorner", ui.cardTemplate).CornerRadius = UDim.new(0, 12)
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(35, 38, 45)
		stroke.Thickness = 2
		stroke.Parent = ui.cardTemplate
	end
end

local function clearPreview(preview)
	for _, child in ipairs(preview:GetChildren()) do
		if child.Name == "PreviewViewport" or child.Name == "PreviewImage" or child.Name == "PreviewText" then
			child:Destroy()
		end
	end
end

local function paintPreview(preview, item)
	clearPreview(preview)
	if item.IconImage and item.IconImage ~= "" then
		local image = Instance.new("ImageLabel")
		image.Name = "PreviewImage"
		image.BackgroundTransparency = 1
		image.Image = item.IconImage
		image.Size = UDim2.fromScale(1, 1)
		image.Parent = preview
		return
	end

	if item.Kind == "Color" and item.PetId then
		local viewport = Instance.new("ViewportFrame")
		viewport.Name = "PreviewViewport"
		viewport.BackgroundTransparency = 1
		viewport.Size = UDim2.fromScale(1, 1)
		viewport.Parent = preview
		local ok = pcall(function()
			PetModelUtil.MountViewport(viewport, item.PetId, { spin = false })
		end)
		if ok then
			return
		end
		viewport:Destroy()
	end

	local label = Instance.new("TextLabel")
	label.Name = "PreviewText"
	label.BackgroundColor3 = item.IconColor or Color3.fromRGB(225, 235, 248)
	label.BorderSizePixel = 0
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeColor3 = Color3.fromRGB(35, 38, 45)
	label.TextStrokeTransparency = 0
	label.Text = item.IconText or string.upper(string.sub(item.Name or item.Id or "IT", 1, 2))
	label.Parent = preview
	Instance.new("UICorner", label).CornerRadius = UDim.new(0, 10)
end

local function makeCard(item, index)
	if not ui.cardTemplate then
		return
	end
	local card = ui.cardTemplate:Clone()
	card.Name = "ItemCard_" .. tostring(index)
	card:SetAttribute("EditableInventoryGeneratedCard", true)
	card.Visible = true
	card.LayoutOrder = index
	card.Parent = ui.grid

	for _, child in ipairs(card:GetChildren()) do
		if child:IsA("GuiObject") and child.Name ~= "UICorner" then
			child:Destroy()
		end
	end

	local preview = ensureFrame(card, "Preview")
	preview.Position = UDim2.fromOffset(10, 8)
	preview.Size = UDim2.new(1, -20, 0, 76)
	preview.BackgroundColor3 = Color3.fromRGB(242, 247, 255)
	paintPreview(preview, item)

	local name = ensureLabel(card, "Name", item.Name)
	name.Position = UDim2.fromOffset(8, 88)
	name.Size = UDim2.new(1, -16, 0, 28)
	name.Font = Enum.Font.GothamBlack
	name.TextSize = 13
	name.TextXAlignment = Enum.TextXAlignment.Center
	local meta = ensureLabel(card, "Meta", "")
	meta.Position = UDim2.fromOffset(8, 116)
	meta.Size = UDim2.new(1, -16, 0, 20)
	meta.TextSize = 11
	meta.TextXAlignment = Enum.TextXAlignment.Center
	meta.Text = item.Equipped and "EQUIPPED" or (item.Amount and ("x" .. tostring(item.Amount)) or tostring(item.Rarity or ""))

	local stroke = card:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = item.Equipped and Color3.fromRGB(84, 225, 112) or (item.Locked and Color3.fromRGB(88, 174, 255) or Color3.fromRGB(35, 38, 45))
		stroke.Thickness = item.Equipped and 4 or 2
	end

	local connection = card.Activated:Connect(function()
		selectedItem = item
		renderDetails()
	end)
	table.insert(cardConnections, connection)
end

local function clearEditableSlot(slot)
	slot:SetAttribute("InventoryItemKind", nil)
	slot:SetAttribute("InventoryItemId", nil)
	slot.Active = false
	if slot:IsA("GuiButton") then
		slot.AutoButtonColor = false
	end

	for _, child in ipairs(slot:GetChildren()) do
		if child:GetAttribute("EditableInventoryGenerated") == true then
			child:Destroy()
		end
	end

	local icon = slot:FindFirstChild("Icon", true)
	if icon and icon:IsA("TextLabel") then
		icon.Text = ""
		icon.BackgroundTransparency = 1
	elseif icon and icon:IsA("ImageLabel") then
		icon.Image = ""
		icon.BackgroundTransparency = 1
	end

	local stroke = slot:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = Color3.fromRGB(35, 38, 45)
		stroke.Thickness = 2
	end
end

local function bindSlotClick(slot, item)
	local function selectItem()
		selectedItem = item
		renderDetails()
	end

	if slot:IsA("GuiButton") then
		slot.Active = true
		slot.AutoButtonColor = true
		table.insert(cardConnections, slot.Activated:Connect(selectItem))
	else
		slot.Active = true
		table.insert(cardConnections, slot.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				selectItem()
			end
		end))
	end
end

local function fillEditableSlot(slot, item)
	clearEditableSlot(slot)
	slot.Visible = true
	slot:SetAttribute("InventoryItemKind", item.Kind)
	slot:SetAttribute("InventoryItemId", item.Id)

	local icon = slot:FindFirstChild("Icon", true)
	local previewParent = icon and icon:IsA("GuiObject") and icon or slot
	if icon and (icon:IsA("TextLabel") or icon:IsA("TextButton")) then
		icon.Text = ""
		icon.BackgroundTransparency = 1
	end
	paintPreview(previewParent, item)

	local name = ensureLabel(slot, "ItemName", tostring(item.Name or item.Id or "Color"))
	name:SetAttribute("EditableInventoryGenerated", true)
	name.Position = UDim2.new(0, 4, 1, -32)
	name.Size = UDim2.new(1, -8, 0, 16)
	name.Font = Enum.Font.GothamBlack
	name.TextScaled = true
	name.TextXAlignment = Enum.TextXAlignment.Center
	name.TextYAlignment = Enum.TextYAlignment.Center
	name.TextColor3 = Color3.fromRGB(35, 38, 45)
	setText(name, item.Name or item.Id or "Color")

	local meta = ensureLabel(slot, "ItemMeta", "")
	meta:SetAttribute("EditableInventoryGenerated", true)
	meta.Position = UDim2.new(0, 4, 1, -16)
	meta.Size = UDim2.new(1, -8, 0, 14)
	meta.Font = Enum.Font.GothamBold
	meta.TextScaled = true
	meta.TextXAlignment = Enum.TextXAlignment.Center
	meta.TextYAlignment = Enum.TextYAlignment.Center
	meta.TextColor3 = Color3.fromRGB(78, 85, 104)
	setText(meta, item.Equipped and "EQUIPPED" or (item.Amount and ("x" .. tostring(item.Amount)) or tostring(item.Rarity or "")))

	local stroke = slot:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = item.Equipped and Color3.fromRGB(84, 225, 112) or (item.Locked and Color3.fromRGB(88, 174, 255) or Color3.fromRGB(35, 38, 45))
		stroke.Thickness = item.Equipped and 4 or 2
	end

	bindSlotClick(slot, item)
end

renderDetails = function()
	local item = selectedItem
	if not item then
		clearPreview(ui.bigPreview)
		setText(ui.selectedName, "Select an Item")
		setText(ui.selectedRarity, "")
		setText(ui.selectedDescription, "Choose a card to see details.")
		setText(ui.statsText, "")
		setText(ui.equipButton, "SELECT")
		setButtonEnabled(ui.equipButton, false)
		setText(ui.lockButton, "LOCK")
		setButtonEnabled(ui.lockButton, false)
		setText(ui.deleteButton, "DELETE")
		setButtonEnabled(ui.deleteButton, false)
		return
	end

	paintPreview(ui.bigPreview, item)
	setText(ui.selectedName, item.Name)
	setText(ui.selectedRarity, item.Rarity or item.Mutation or item.Kind)
	setText(ui.selectedDescription, item.Description or item.Bonus or "")
	setText(ui.statsText, table.concat(item.Stats or {}, "\n"))

	if item.Kind == "Color" then
		setText(ui.equipButton, item.Equipped and "UNEQUIP" or "EQUIP")
		setButtonEnabled(ui.equipButton, true)
		setText(ui.lockButton, item.Locked and "UNLOCK" or "LOCK")
		setButtonEnabled(ui.lockButton, true)
		setText(ui.deleteButton, "DELETE")
		setButtonEnabled(ui.deleteButton, not item.Locked and not item.Equipped)
	elseif item.Kind == "Brush" then
		setText(ui.equipButton, item.Equipped and "EQUIPPED" or "EQUIP")
		setButtonEnabled(ui.equipButton, not item.Equipped)
		setText(ui.lockButton, "LOCK")
		setButtonEnabled(ui.lockButton, false)
		setText(ui.deleteButton, "DELETE")
		setButtonEnabled(ui.deleteButton, false)
	else
		setText(ui.equipButton, item.Usable and "USE" or "INFO")
		setButtonEnabled(ui.equipButton, item.Usable == true)
		setText(ui.lockButton, "LOCK")
		setButtonEnabled(ui.lockButton, false)
		setText(ui.deleteButton, "DELETE")
		setButtonEnabled(ui.deleteButton, false)
	end
end

local function getTabItems()
	return inventoryData[currentTab] or {}
end

local function renderInventory()
	disconnectCards()
	if ui.usesEditableSlots then
		ui.slots = collectEditableSlots(ui.gridPanel)
		for _, slot in ipairs(ui.slots) do
			clearEditableSlot(slot)
			slot.Visible = false
		end
	else
		for _, child in ipairs(ui.grid:GetChildren()) do
			if child:GetAttribute("EditableInventoryGeneratedCard") == true then
				child:Destroy()
			elseif child:IsA("GuiObject") and child.Name ~= "ItemCardTemplate" then
				child.Visible = false
			end
		end
	end

	for _, tabName in ipairs(TAB_NAMES) do
		local tab = ui.tabs:FindFirstChild(tabName .. "Tab", true)
		if tab and tab:IsA("TextButton") then
			local active = tabName == currentTab
			tab.BackgroundColor3 = active and Color3.fromRGB(82, 219, 225) or Color3.fromRGB(232, 238, 248)
			tab.TextColor3 = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(38, 36, 52)
		end
	end

	local items = getTabItems()
	ui.emptyText.Visible = #items == 0
	if not ui.usesEditableSlots then
		ui.grid.Visible = #items > 0
	end
	ui.emptyText.Text = "No " .. string.lower(currentTab) .. " yet."
	ui.capacityText.Text = "Colors: " .. tostring(inventoryData.Count or 0) .. " / " .. tostring(inventoryData.Capacity or 75)

	for index, item in ipairs(items) do
		if ui.usesEditableSlots then
			local slot = ui.slots[index]
			if slot then
				fillEditableSlot(slot, item)
			end
		else
			makeCard(item, index)
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
		local tab = ui.tabs:FindFirstChild(tabName .. "Tab", true)
		if tab and tab:IsA("GuiButton") and tab:GetAttribute("EditableInventoryBound") ~= true then
			tab:SetAttribute("EditableInventoryBound", true)
			tab.Activated:Connect(function()
				currentTab = tabName
				selectedItem = nil
				renderInventory()
			end)
		end
	end

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
	ui.lockButton.Activated:Connect(function()
		if selectedItem and selectedItem.Kind == "Color" then
			sendAction("Lock", selectedItem)
		end
	end)
	ui.deleteButton.Activated:Connect(function()
		if selectedItem and selectedItem.Kind == "Color" and not selectedItem.Locked and not selectedItem.Equipped then
			sendAction("Delete", selectedItem)
		end
	end)
end

prepareStructure()
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
