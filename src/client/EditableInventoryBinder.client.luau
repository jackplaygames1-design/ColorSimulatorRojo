-- Safely populates the editable Studio InventoryWindow with the player's existing Colors/pets.
-- IMPORTANT: this script is display/equip only. It never deletes, rewrites, or clears hatched Colors.
-- It uses the existing Player.PetData values created by DataManager and the existing EquipPet RemoteEvent.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local PetData = require(ReplicatedStorage:WaitForChild("PetData"))
local Events = ReplicatedStorage:WaitForChild("Events")
local equipPetEvent = Events:WaitForChild("EquipPet")

local petFolder = player:WaitForChild("PetData", 30)
local petInventoryValue = petFolder and petFolder:WaitForChild("Inventory", 30)
local petEquippedValue = petFolder and petFolder:WaitForChild("Equipped", 30)

local selectedRecord = nil
local currentTab = "Colors"

local function getMainHUD()
	local root = playerGui:WaitForChild("ClientUIRoot", 30)
	if not root then
		warn("EditableInventoryBinder: ClientUIRoot missing")
		return nil
	end
	return root:WaitForChild("MainHUD", 30)
end

local function getWindows(mainHUD)
	local modalWindows = mainHUD:FindFirstChild("ModalWindows")
	if modalWindows and modalWindows:FindFirstChild("Windows") then
		return modalWindows.Windows
	end
	return mainHUD:FindFirstChild("Windows")
end

local function splitCsv(value)
	local out = {}
	if type(value) ~= "string" or value == "" then
		return out
	end
	for _, item in ipairs(string.split(value, ",")) do
		item = string.gsub(item, "^%s+", "")
		item = string.gsub(item, "%s+$", "")
		if item ~= "" then
			table.insert(out, item)
		end
	end
	return out
end

local function parsePetRecord(encoded)
	if type(encoded) ~= "string" or encoded == "" then
		return nil
	end

	local parts = string.split(encoded, ":")
	local record

	if #parts >= 3 then
		-- Current DataManager format: variantKey:petId:stackAmount:trait:shiny:personality:mutation
		record = {
			variantKey = parts[1],
			petId = parts[2],
			stackAmount = tonumber(parts[3]) or 1,
			traitId = parts[4] or "Neutral",
			isShiny = parts[5] == "shiny" or parts[5] == "true",
			personalityId = parts[6] or "Neutral",
			mutationId = parts[7] or "None",
		}
	else
		-- Very old fallback: petId only.
		record = {
			variantKey = encoded,
			petId = encoded,
			stackAmount = 1,
			traitId = "Neutral",
			isShiny = false,
			personalityId = "Neutral",
			mutationId = "None",
		}
	end

	if not record.petId or record.petId == "" then
		return nil
	end

	if not record.variantKey or record.variantKey == "" then
		record.variantKey = record.petId
	end

	return record
end

local function getInventoryRecords()
	local records = {}
	if not petInventoryValue then
		return records
	end

	for _, encoded in ipairs(splitCsv(petInventoryValue.Value)) do
		local record = parsePetRecord(encoded)
		if record then
			table.insert(records, record)
		end
	end

	table.sort(records, function(a, b)
		return tostring(a.petId) < tostring(b.petId)
	end)

	return records
end

local function getEquippedSet()
	local equipped = {}
	if not petEquippedValue then
		return equipped
	end
	for _, key in ipairs(splitCsv(petEquippedValue.Value)) do
		equipped[key] = true
	end
	return equipped
end

local function findDeep(parent, name)
	return parent and parent:FindFirstChild(name, true)
end

local function setText(obj, value)
	if obj and (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) then
		obj.Text = tostring(value or "")
	end
end

local function petDisplayName(record)
	local definition = PetData.Pets and PetData.Pets[record.petId]
	return (definition and (definition.displayName or definition.DisplayName or definition.name)) or record.petId
end

local function petRarity(record)
	local definition = PetData.Pets and PetData.Pets[record.petId]
	return (definition and (definition.rarity or definition.Rarity)) or "Color"
end

local function petPower(record)
	local definition = PetData.Pets and PetData.Pets[record.petId]
	return tonumber(definition and (definition.power or definition.Power or definition.multiplier or definition.Multiplier)) or 1
end

local function clearGeneratedCards(grid)
	for _, child in ipairs(grid:GetChildren()) do
		if child:GetAttribute("EditableInventoryGeneratedCard") == true then
			child:Destroy()
		end
	end
end

local function getSlots(grid)
	local slots = {}
	for _, child in ipairs(grid:GetChildren()) do
		if child:IsA("GuiObject") and string.match(child.Name, "^Slot%d+$") then
			table.insert(slots, child)
		end
	end
	table.sort(slots, function(a, b)
		local ai = tonumber(string.match(a.Name, "%d+")) or 0
		local bi = tonumber(string.match(b.Name, "%d+")) or 0
		return ai < bi
	end)
	return slots
end

local function createCard(grid, index)
	local card = Instance.new("TextButton")
	card.Name = "PetCard" .. index
	card:SetAttribute("EditableInventoryGeneratedCard", true)
	card.Text = ""
	card.AutoButtonColor = true
	card.BackgroundColor3 = Color3.fromRGB(245, 249, 255)
	card.BorderSizePixel = 0
	card.Size = UDim2.fromOffset(112, 132)
	card.Parent = grid

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(35, 38, 45)
	stroke.Thickness = 2
	stroke.Parent = card

	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.BackgroundColor3 = Color3.fromRGB(229, 236, 247)
	icon.BorderSizePixel = 0
	icon.Position = UDim2.fromScale(0.12, 0.07)
	icon.Size = UDim2.fromScale(0.76, 0.48)
	icon.Font = Enum.Font.GothamBlack
	icon.TextSize = 16
	icon.TextColor3 = Color3.fromRGB(31, 34, 45)
	icon.TextWrapped = true
	icon.Parent = card
	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(0, 14)
	iconCorner.Parent = icon

	local name = Instance.new("TextLabel")
	name.Name = "Name"
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromScale(0.08, 0.58)
	name.Size = UDim2.fromScale(0.84, 0.17)
	name.Font = Enum.Font.GothamBlack
	name.TextSize = 12
	name.TextColor3 = Color3.fromRGB(31, 34, 45)
	name.TextWrapped = true
	name.Parent = card

	local meta = Instance.new("TextLabel")
	meta.Name = "Meta"
	meta.BackgroundTransparency = 1
	meta.Position = UDim2.fromScale(0.08, 0.76)
	meta.Size = UDim2.fromScale(0.84, 0.16)
	meta.Font = Enum.Font.GothamBold
	meta.TextSize = 10
	meta.TextColor3 = Color3.fromRGB(100, 108, 124)
	meta.TextWrapped = true
	meta.Parent = card

	return card
end

local function fillCard(card, record, equipped)
	card.Visible = true
	card:SetAttribute("VariantKey", record.variantKey)
	card:SetAttribute("PetId", record.petId)

	local short = string.upper(string.sub(petDisplayName(record), 1, 2))
	setText(card:FindFirstChild("Icon", true), short)
	setText(card:FindFirstChild("IconText", true), short)
	setText(card:FindFirstChild("Name", true), petDisplayName(record))
	setText(card:FindFirstChild("Meta", true), petRarity(record) .. " x" .. tostring(record.stackAmount or 1))

	local oldIcon = card:FindFirstChild("Icon", true)
	if oldIcon and oldIcon:IsA("TextLabel") and oldIcon.Text == "IMG" then
		oldIcon.Text = short
	end

	local stroke = card:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = equipped and Color3.fromRGB(72, 210, 102) or Color3.fromRGB(35, 38, 45)
		stroke.Thickness = equipped and 4 or 2
	end

	card.MouseButton1Click:Connect(function()
		selectedRecord = record
		local inventoryWindow = card:FindFirstAncestor("InventoryWindow")
		if inventoryWindow then
			local details = findDeep(inventoryWindow, "DetailsPanel") or findDeep(inventoryWindow, "DetailPanel")
			if details then
				setText(findDeep(details, "SelectLabel"), petDisplayName(record))
				setText(findDeep(details, "Title"), petDisplayName(record))
				setText(findDeep(details, "Name"), petDisplayName(record))
				setText(findDeep(details, "Description"), petRarity(record) .. " • Power " .. tostring(petPower(record)) .. " • x" .. tostring(record.stackAmount or 1))
				setText(findDeep(details, "InfoText"), "Trait: " .. tostring(record.traitId or "Neutral") .. " | Mutation: " .. tostring(record.mutationId or "None"))
			end
		end
	end)
end

local function showEmpty(grid, text)
	clearGeneratedCards(grid)
	for _, slot in ipairs(getSlots(grid)) do
		slot.Visible = false
	end

	local empty = grid:FindFirstChild("NoItemsLabel")
	if not empty then
		empty = Instance.new("TextLabel")
		empty.Name = "NoItemsLabel"
		empty.BackgroundTransparency = 1
		empty.Size = UDim2.fromScale(1, 1)
		empty.Font = Enum.Font.GothamBlack
		empty.TextSize = 22
		empty.TextColor3 = Color3.fromRGB(100, 108, 124)
		empty.TextWrapped = true
		empty.Parent = grid
	end
	empty.Visible = true
	empty.Text = text
end

local function populateColors(inventoryWindow)
	local grid = findDeep(inventoryWindow, "ItemGrid") or findDeep(inventoryWindow, "Grid") or findDeep(inventoryWindow, "Content")
	if not grid then
		warn("EditableInventoryBinder: Inventory grid missing")
		return
	end

	local empty = grid:FindFirstChild("NoItemsLabel")
	if empty then
		empty.Visible = false
	end

	clearGeneratedCards(grid)
	local records = getInventoryRecords()
	local equipped = getEquippedSet()

	if #records == 0 then
		showEmpty(grid, "No Colors yet. Hatch colors to see them here.")
		return
	end

	local slots = getSlots(grid)
	for _, slot in ipairs(slots) do
		slot.Visible = false
	end

	for index, record in ipairs(records) do
		local card = slots[index]
		if not card then
			card = createCard(grid, index)
		end
		fillCard(card, record, equipped[record.variantKey] == true or equipped[record.petId] == true)
	end
end

local function showNonColorTab(inventoryWindow, tabName)
	local grid = findDeep(inventoryWindow, "ItemGrid") or findDeep(inventoryWindow, "Grid") or findDeep(inventoryWindow, "Content")
	if not grid then return end
	showEmpty(grid, tabName .. " coming soon.")
end

local function setTab(inventoryWindow, tabName)
	currentTab = tabName
	if tabName == "Colors" then
		populateColors(inventoryWindow)
	else
		showNonColorTab(inventoryWindow, tabName)
	end
end

local hooked = false
local function hookInventoryWindow(inventoryWindow)
	if hooked then return end
	hooked = true

	for _, obj in ipairs(inventoryWindow:GetDescendants()) do
		if obj:IsA("GuiButton") then
			local name = obj.Name
			local text = obj:IsA("TextButton") and obj.Text or ""
			local tabName = string.gsub(name, "Tab$", "")
			if tabName == "Colors" or text == "Colors" then
				obj.MouseButton1Click:Connect(function() setTab(inventoryWindow, "Colors") end)
			elseif tabName == "Brushes" or text == "Brushes" then
				obj.MouseButton1Click:Connect(function() setTab(inventoryWindow, "Brushes") end)
			elseif tabName == "Potions" or text == "Potions" then
				obj.MouseButton1Click:Connect(function() setTab(inventoryWindow, "Potions") end)
			elseif tabName == "Items" or text == "Items" then
				obj.MouseButton1Click:Connect(function() setTab(inventoryWindow, "Items") end)
			elseif name == "EquipButton" or text == "EQUIP" or text == "SELECT" then
				obj.MouseButton1Click:Connect(function()
					if selectedRecord then
						equipPetEvent:FireServer(selectedRecord.variantKey)
					else
						warn("Select a Color first.")
					end
				end)
			elseif name == "DeleteButton" or text == "DELETE" then
				obj.AutoButtonColor = false
				if obj:IsA("TextButton") then
					obj.Text = "DELETE OFF"
				end
				obj.MouseButton1Click:Connect(function()
					warn("Delete is disabled to protect hatched Colors.")
				end)
			elseif name == "LockButton" or text == "LOCK" then
				obj.MouseButton1Click:Connect(function()
					warn("Locking is not wired yet; no data was changed.")
				end)
			end
		end
	end

	setTab(inventoryWindow, "Colors")
	if petInventoryValue then
		petInventoryValue.Changed:Connect(function()
			if currentTab == "Colors" then
				populateColors(inventoryWindow)
			end
		end)
	end
	if petEquippedValue then
		petEquippedValue.Changed:Connect(function()
			if currentTab == "Colors" then
				populateColors(inventoryWindow)
			end
		end)
	end
end

local mainHUD = getMainHUD()
local windows = mainHUD and getWindows(mainHUD)
local inventoryWindow = windows and windows:WaitForChild("InventoryWindow", 30)
if inventoryWindow then
	hookInventoryWindow(inventoryWindow)
else
	warn("EditableInventoryBinder: InventoryWindow missing; no runtime window will be created.")
end
