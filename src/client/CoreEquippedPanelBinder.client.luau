-- Optional binder for an editable EquippedPanel. It fills existing slot frames
-- only; no runtime UI is created.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ClientUIRoot = require(ReplicatedStorage:WaitForChild("ClientUIRoot"))
local ColorMutationData = require(ReplicatedStorage:WaitForChild("ColorMutationData"))

local Events = ReplicatedStorage:WaitForChild("Events")
local petsLoadedEvent = Events:WaitForChild("PetsLoaded")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local inventoryAction = remotes:WaitForChild("InventoryAction")

local mainHud = ClientUIRoot.GetRoot(playerGui)
local warned = false
local inventory = {}
local equipped = {}

local function findPanel()
	if not mainHud then
		return nil
	end
	local panel = mainHud:FindFirstChild("EquippedPanel", true)
	if panel and panel:IsA("GuiObject") then
		return panel
	end
	return nil
end

local panel = findPanel()
if not panel then
	if not warned then
		warned = true
		warn(
			"CoreEquippedPanelBinder: optional editable EquippedPanel missing. Add EquippedPanel > EquippedSlots > Slot frames and UnequipAllButton to enable the team panel."
		)
	end
	return
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

local slotsRoot = findDescendantByNames(panel, { "EquippedSlots", "Slots", "SlotContainer" }) or panel
local countLabel = findDescendantByNames(panel, { "EquippedCountLabel", "CountLabel", "Title", "EquippedLabel" })
local unequipAllButton = findDescendantByNames(panel, { "UnequipAllButton", "UnequipAll", "ClearButton" })

local function collectSlots()
	local slots = {}
	for _, child in ipairs(slotsRoot:GetChildren()) do
		if
			child:IsA("GuiObject") and (string.find(child.Name, "Slot") or child:GetAttribute("EquippedSlot") == true)
		then
			table.insert(slots, child)
		end
	end
	table.sort(slots, function(a, b)
		if a.LayoutOrder ~= b.LayoutOrder then
			return a.LayoutOrder < b.LayoutOrder
		end
		return a.Name < b.Name
	end)
	return slots
end

local function setText(object, value)
	if object and (object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox")) then
		object.Text = tostring(value or "")
	end
end

local function getEntryKey(entry)
	return tostring(entry.variantKey or entry.ColorId or entry.colorId or entry.petId or "")
end

local function getMutationText(entry)
	local mutation = ColorMutationData.get(entry and entry.mutationId)
	if not mutation then
		return ""
	end
	if entry.IsGlitched == true or entry.isGlitched == true then
		return "GLITCHED " .. string.upper(mutation.DisplayName)
	end
	return string.upper(mutation.DisplayName)
end

local function findEntry(key)
	key = tostring(key or "")
	for _, entry in ipairs(inventory) do
		if getEntryKey(entry) == key or tostring(entry.petId or "") == key then
			return entry
		end
	end
	return nil
end

local function render()
	local slots = collectSlots()
	if countLabel then
		setText(countLabel, "EQUIPPED " .. tostring(#equipped) .. " / 3")
	end

	for index, slot in ipairs(slots) do
		local entry = findEntry(equipped[index])
		slot.Visible = true
		slot:SetAttribute("EquippedColorKey", entry and getEntryKey(entry) or "")
		local nameLabel = findDescendantByNames(slot, { "NameLabel", "ColorNameLabel", "Name", "Title" })
		local mutationLabel = findDescendantByNames(slot, { "MutationLabel", "MutationText", "BadgeLabel", "Meta" })
		local powerLabel = findDescendantByNames(slot, { "PowerLabel", "PowerText", "StatsLabel" })
		if entry then
			setText(nameLabel, entry.ColorName or entry.displayName or entry.petId or "Color")
			setText(mutationLabel, getMutationText(entry))
			setText(powerLabel, tostring(entry.Power or entry.finalPower or ""))
		else
			setText(nameLabel, "Empty")
			setText(mutationLabel, "")
			setText(powerLabel, "")
		end
	end
end

petsLoadedEvent.OnClientEvent:Connect(function(inventoryPayload, equippedPayload)
	if type(inventoryPayload) == "table" then
		inventory = inventoryPayload
	end
	if type(equippedPayload) == "table" then
		equipped = equippedPayload
	end
	render()
end)

if unequipAllButton and unequipAllButton:IsA("GuiButton") then
	unequipAllButton.Activated:Connect(function()
		for _, key in ipairs(equipped) do
			inventoryAction:FireServer("Unequip", {
				Kind = "Color",
				Id = key,
			})
		end
	end)
end

render()
