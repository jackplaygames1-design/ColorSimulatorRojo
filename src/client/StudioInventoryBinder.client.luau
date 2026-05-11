-- Hooks the editable Studio InventoryWindow without rebuilding the UI.
-- Uses your hand-made objects:
-- InventoryWindow > Content > GridPanel > PreviewSlot1...
-- InventoryWindow > Content > DetailsPanel > PreviewImage/ItemName/RarityLabel/StatsLabel/EquipButton/LockButton/DeleteButton

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local signalConnected = setmetatable({}, { __mode = "k" })
local popConnected = setmetatable({}, { __mode = "k" })
local selectedItem = nil
local warned = {}

local DEMO_ITEMS = {
	{ id = "rainbow_color", name = "Rainbow Color", rarity = "Rare", mutation = "Glitched", power = 25, equipped = false, locked = false, color = Color3.fromRGB(255, 65, 175) },
	{ id = "red_color", name = "Red Color", rarity = "Common", mutation = "None", power = 8, equipped = false, locked = false, color = Color3.fromRGB(235, 60, 65) },
	{ id = "orange_color", name = "Orange Color", rarity = "Uncommon", mutation = "Glimmer", power = 14, equipped = false, locked = false, color = Color3.fromRGB(255, 145, 45) },
	{ id = "pipe_color", name = "Pipe Color", rarity = "Uncommon", mutation = "Shadowed", power = 18, equipped = false, locked = false, color = Color3.fromRGB(70, 210, 255) },
	{ id = "gem_color", name = "Gem Color", rarity = "Rare", mutation = "Prism", power = 20, equipped = false, locked = false, color = Color3.fromRGB(55, 255, 185) },
	{ id = "void_color", name = "Void Color", rarity = "Legendary", mutation = "Corrupted", power = 40, equipped = false, locked = false, color = Color3.fromRGB(145, 75, 255) },
	{ id = "sun_color", name = "Sun Color", rarity = "Rare", mutation = "Solar", power = 28, equipped = false, locked = false, color = Color3.fromRGB(255, 220, 70) },
	{ id = "ink_color", name = "Ink Color", rarity = "Rare", mutation = "Inkblot", power = 31, equipped = false, locked = false, color = Color3.fromRGB(70, 45, 125) },
	{ id = "error_color", name = "Error Color", rarity = "Legendary", mutation = "Error 404", power = 55, equipped = false, locked = false, color = Color3.fromRGB(255, 35, 105) },
}

local function warnOnce(key, message)
	if warned[key] then
		return
	end
	warned[key] = true
	warn(message)
end

local function getRemote(name)
	local events = ReplicatedStorage:FindFirstChild("Events")
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	return (events and events:FindFirstChild(name)) or (remotes and remotes:FindFirstChild(name)) or ReplicatedStorage:FindFirstChild(name)
end

local function fireRemote(name, item)
	local remote = getRemote(name)
	if remote and remote:IsA("RemoteEvent") then
		remote:FireServer(item.id or item.name, item)
		return true
	end
	warnOnce("missing_" .. name, "StudioInventoryBinder: remote " .. name .. " was not found yet.")
	return false
end

local function findInventoryWindow()
	for _, descendant in ipairs(playerGui:GetDescendants()) do
		if descendant.Name == "InventoryWindow" and descendant:IsA("GuiObject") then
			return descendant
		end
	end
	return nil
end

local function findFirst(parent, names)
	for _, name in ipairs(names) do
		local found = parent:FindFirstChild(name, true)
		if found then
			return found
		end
	end
	return nil
end

local function getContent(window)
	local content = window:FindFirstChild("Content")
	if content and content:IsA("GuiObject") then
		return content
	end
	return window
end

local function removeGeneratedOverlay(window)
	local content = getContent(window)
	local generated = content:FindFirstChild("AutoFunctionalContent")
	if generated then
		generated:Destroy()
	end
end

local function getManualParts(window)
	local content = getContent(window)
	local gridPanel = content:FindFirstChild("GridPanel", true) or content:FindFirstChild("ItemGrid", true) or content
	local detailsPanel = content:FindFirstChild("DetailsPanel", true)
	if not detailsPanel then
		warnOnce("missing_details", "StudioInventoryBinder: DetailsPanel missing in InventoryWindow.")
		return nil
	end

	return {
		content = content,
		gridPanel = gridPanel,
		detailsPanel = detailsPanel,
		previewImage = findFirst(detailsPanel, { "PreviewImage", "PreviewIcon", "ImageButton", "Icon" }),
		itemName = findFirst(detailsPanel, { "ItemName", "SelectedName", "NameLabel" }),
		rarityLabel = findFirst(detailsPanel, { "RarityLabel", "Rarity" }),
		statsLabel = findFirst(detailsPanel, { "StatsLabel", "Stats" }),
		equipButton = findFirst(detailsPanel, { "EquipButton" }),
		lockButton = findFirst(detailsPanel, { "LockButton" }),
		deleteButton = findFirst(detailsPanel, { "DeleteButton" }),
	}
end

local function setText(label, text)
	if label and (label:IsA("TextLabel") or label:IsA("TextButton")) then
		label.Text = text
		label.Visible = true
	end
end

local function setImageColor(gui, color)
	if gui and (gui:IsA("ImageLabel") or gui:IsA("ImageButton")) then
		gui.ImageColor3 = color
		gui.BackgroundTransparency = 1
		gui.Visible = true
	elseif gui and gui:IsA("GuiObject") then
		gui.BackgroundColor3 = color
		gui.Visible = true
	end
end

local function getMutationColor(item)
	local mutation = string.lower(item.mutation or "")
	if string.find(mutation, "glitch") or string.find(mutation, "corrupt") or string.find(mutation, "error") then
		return Color3.fromRGB(255, 35, 105)
	elseif string.find(mutation, "shadow") or string.find(mutation, "void") or string.find(mutation, "ink") then
		return Color3.fromRGB(110, 55, 190)
	elseif string.find(mutation, "glimmer") or string.find(mutation, "solar") or string.find(mutation, "prism") then
		return Color3.fromRGB(255, 230, 95)
	end
	return Color3.fromRGB(210, 220, 235)
end

local function updateSlotVisual(slot, item, isSelected)
	if not slot or not slot:IsA("GuiObject") then
		return
	end

	local icon = slot:FindFirstChild("Icon", true) or slot:FindFirstChild("PreviewIcon", true)
	local glow = slot:FindFirstChild("MutationGlow", true)
	local equippedBadge = slot:FindFirstChild("EquippedBadge", true)
	local lockBadge = slot:FindFirstChild("LockBadge", true)
	local stroke = slot:FindFirstChildOfClass("UIStroke")

	if slot:IsA("TextButton") then
		slot.Text = ""
	end
	if slot:IsA("GuiButton") then
		slot.Active = true
		slot.Selectable = true
		slot.AutoButtonColor = false
	end

	if icon then
		setImageColor(icon, item.color)
		if icon:IsA("TextLabel") or icon:IsA("TextButton") then
			icon.Text = item.name:sub(1, 3):upper()
		end
	end
	if glow and glow:IsA("GuiObject") then
		glow.BackgroundColor3 = getMutationColor(item)
		glow.BackgroundTransparency = item.mutation == "None" and 0.85 or 0.35
		glow.Visible = true
	end
	if equippedBadge and equippedBadge:IsA("GuiObject") then
		equippedBadge.Visible = item.equipped == true
	end
	if lockBadge and lockBadge:IsA("GuiObject") then
		lockBadge.Visible = item.locked == true
	end
	if stroke then
		stroke.Color = isSelected and Color3.fromRGB(72, 235, 255) or Color3.fromRGB(35, 38, 45)
		stroke.Thickness = isSelected and 4 or 2
	end
end

local function updateDetails(parts, item)
	selectedItem = item
	setText(parts.itemName, item.name)
	setText(parts.rarityLabel, item.rarity .. " • " .. item.mutation)
	setText(parts.statsLabel, "Power: " .. tostring(item.power) .. "\nEquipped: " .. (item.equipped and "Yes" or "No") .. "\nLocked: " .. (item.locked and "Yes" or "No"))
	setImageColor(parts.previewImage, item.color)
	if parts.equipButton and parts.equipButton:IsA("GuiButton") then
		parts.equipButton.Text = item.equipped and "UNEQUIP" or "EQUIP"
	end
	if parts.lockButton and parts.lockButton:IsA("GuiButton") then
		parts.lockButton.Text = item.locked and "UNLOCK" or "LOCK"
	end
end

local function addButtonPop(button)
	if not button or not button:IsA("GuiButton") or popConnected[button] then
		return
	end
	popConnected[button] = true
	local scale = button:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = button
	button.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1.05 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1 }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.94 }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.08), { Scale = 1.05 }):Play()
	end)
end

local function collectSlots(parts)
	local slots = {}
	for _, descendant in ipairs(parts.gridPanel:GetDescendants()) do
		if descendant:IsA("GuiButton") and descendant.Name:match("^PreviewSlot%d+") then
			table.insert(slots, descendant)
		end
	end
	table.sort(slots, function(a, b)
		return a.Name < b.Name
	end)
	return slots
end

local function hookInventory(window)
	removeGeneratedOverlay(window)
	local parts = getManualParts(window)
	if not parts then
		return false
	end

	local slots = collectSlots(parts)
	if #slots == 0 then
		warnOnce("missing_slots", "StudioInventoryBinder: no PreviewSlot buttons found inside GridPanel.")
		return false
	end

	local function refreshAll()
		for index, slot in ipairs(slots) do
			local item = DEMO_ITEMS[index]
			if item then
				slot.Visible = true
				updateSlotVisual(slot, item, item == selectedItem)
			else
				slot.Visible = false
			end
		end
	end

	for index, slot in ipairs(slots) do
		local item = DEMO_ITEMS[index]
		if item then
			slot.Active = true
			slot.Selectable = true
			addButtonPop(slot)
			if not signalConnected[slot] then
				signalConnected[slot] = true
				slot.Activated:Connect(function()
					updateDetails(parts, item)
					refreshAll()
				end)
			end
		end
	end

	local function hookAction(button, callback)
		if button and button:IsA("GuiButton") then
			addButtonPop(button)
			if not signalConnected[button] then
				signalConnected[button] = true
				button.Activated:Connect(function()
					if selectedItem then
						callback(selectedItem)
						updateDetails(parts, selectedItem)
						refreshAll()
					end
				end)
			end
		end
	end

	hookAction(parts.equipButton, function(item)
		item.equipped = not item.equipped
		fireRemote("EquipPet", item)
	end)
	hookAction(parts.lockButton, function(item)
		item.locked = not item.locked
		fireRemote("LockPet", item)
	end)
	hookAction(parts.deleteButton, function(item)
		if item.locked then
			warn("StudioInventoryBinder: cannot delete locked item " .. item.name)
			return
		end
		fireRemote("DeletePet", item)
	end)

	selectedItem = selectedItem or DEMO_ITEMS[1]
	updateDetails(parts, selectedItem)
	refreshAll()
	window:SetAttribute("StudioInventoryBound", true)
	return true
end

local function tryHook()
	local window = findInventoryWindow()
	if not window then
		return false
	end
	return hookInventory(window)
end

task.defer(function()
	local started = os.clock()
	while os.clock() - started < 12 do
		if tryHook() then
			return
		end
		task.wait(0.25)
	end
	warnOnce("not_found", "StudioInventoryBinder: InventoryWindow was not found or is missing required objects.")
end)

playerGui.DescendantAdded:Connect(function(descendant)
	if descendant.Name == "InventoryWindow" or descendant.Name == "AutoFunctionalContent" or descendant.Name:match("^PreviewSlot%d+") then
		task.defer(tryHook)
	end
end)

while task.wait(1) do
	local window = findInventoryWindow()
	if window then
		removeGeneratedOverlay(window)
	end
end
