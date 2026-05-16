-- Server bridge for the editable Studio InventoryWindow.
-- Client receives display data and requests actions; this script delegates
-- inventory mutations to the existing authoritative game systems.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ColorData = require(ReplicatedStorage:WaitForChild("ColorData"))
local ColorMutationData = require(ReplicatedStorage:WaitForChild("ColorMutationData"))
local GamepassBenefits = require(script.Parent:WaitForChild("GamepassBenefits"))
local ItemsData = require(ReplicatedStorage:WaitForChild("ItemsData"))
local PetData = require(ReplicatedStorage:WaitForChild("PetData"))
local PetDefinitions = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PetDefinitions"))
local ToolData = require(ReplicatedStorage:WaitForChild("ToolData"))

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local inventoryRequest = remotes:FindFirstChild("InventoryRequest")
if not inventoryRequest then
	inventoryRequest = Instance.new("RemoteFunction")
	inventoryRequest.Name = "InventoryRequest"
	inventoryRequest.Parent = remotes
end

local inventoryAction = remotes:FindFirstChild("InventoryAction")
if not inventoryAction then
	inventoryAction = Instance.new("RemoteEvent")
	inventoryAction.Name = "InventoryAction"
	inventoryAction.Parent = remotes
end

local petInventorySnapshotFunction = ServerStorage:FindFirstChild("PetInventorySnapshot")

local Events = ReplicatedStorage:WaitForChild("Events")
local dataDirtyEvent = Events:FindFirstChild("PlayerDataDirty")
local equipPaintToolEvent = Events:WaitForChild("EquipPaintTool")

local COLOR_CAPACITY = 75
local INFINITE_CAPACITY_LABEL = "∞"

local function splitCsv(value)
	local out = {}
	for _, item in ipairs(string.split(value or "", ",")) do
		if item ~= "" then
			table.insert(out, item)
		end
	end
	return out
end

local function setFromCsv(value)
	local set = {}
	for _, item in ipairs(splitCsv(value)) do
		set[item] = true
	end
	return set
end

local function waitForPlayerPetData(player)
	if player:GetAttribute("DataManagerReady") ~= true then
		local ready = false
		local connection
		connection = player:GetAttributeChangedSignal("DataManagerReady"):Connect(function()
			if player:GetAttribute("DataManagerReady") == true then
				ready = true
				if connection then
					connection:Disconnect()
				end
			end
		end)
		local startedAt = os.clock()
		while
			player.Parent
			and not ready
			and player:GetAttribute("DataManagerReady") ~= true
			and os.clock() - startedAt < 10
		do
			task.wait(0.1)
		end
		if connection and connection.Connected then
			connection:Disconnect()
		end
	end

	local petFolder = player:WaitForChild("PetData", 10)
	local inventoryValue = petFolder and petFolder:WaitForChild("Inventory", 10)
	local equippedValue = petFolder and petFolder:WaitForChild("Equipped", 10)
	local lockedValue = petFolder and petFolder:WaitForChild("Locked", 10)
	if inventoryValue and inventoryValue.Value == "" then
		local startedAt = os.clock()
		while player.Parent and inventoryValue.Parent and inventoryValue.Value == "" and os.clock() - startedAt < 2 do
			task.wait(0.1)
		end
	end
	return petFolder, inventoryValue, equippedValue, lockedValue
end

local function parsePetInventory(value)
	local entries = {}
	for _, encoded in ipairs(splitCsv(value)) do
		local segments = string.split(encoded, ":")
		local variantKey
		local petId
		local stackIndex
		if #segments == 1 then
			local legacyParts = string.split(encoded, "|")
			petId = legacyParts[1]
			variantKey = encoded

			local stackAmount = 1
			local traitId = PetData.normalizeTraitId(legacyParts[2] or "Neutral")
			local mutationId = PetData.normalizeMutationId(legacyParts[3] or "None")
			local personalityId = "Neutral"
			local entry = PetData.buildPetEntry(petId, stackAmount, false, personalityId, mutationId, traitId)
			if entry then
				entry.variantKey = variantKey
				entry.petId = petId
				entry.modelName = petId
				entry.legacyColorKey = encoded
				table.insert(entries, entry)
			else
				warn("EditableInventoryBridge: could not display saved Color entry " .. tostring(encoded))
			end
			continue
		elseif tonumber(segments[2]) then
			petId = segments[1]
			stackIndex = 2
		else
			variantKey = segments[1]
			petId = segments[2]
			stackIndex = 3
		end

		if petId and petId ~= "" then
			local legacyParts = string.split(petId, "|")
			local stackAmount = math.max(1, tonumber(segments[stackIndex]) or 1)
			local traitId = PetData.normalizeTraitId(segments[stackIndex + 1])
			local shinyStr = segments[stackIndex + 2] or "normal"
			local personalityId = PetData.normalizePersonalityId(segments[stackIndex + 3] or "Neutral")
			local mutationId = PetData.normalizeMutationId(segments[stackIndex + 4] or "None")
			local isCore = segments[stackIndex + 5] == "core"
			if not PetData.Pets[petId] and #legacyParts >= 3 and PetData.Pets[legacyParts[1]] then
				petId = legacyParts[1]
				traitId = PetData.normalizeTraitId(legacyParts[2])
				mutationId = PetData.normalizeMutationId(legacyParts[3])
			end
			variantKey = variantKey or PetData.makeVariantKey(petId, personalityId, mutationId, traitId)

			local entry = PetData.buildPetEntry(
				petId,
				stackAmount,
				shinyStr == "shiny" or shinyStr == "true",
				personalityId,
				mutationId,
				traitId
			)
			if entry then
				entry.variantKey = variantKey
				entry.petId = petId
				if string.find(tostring(variantKey), "|", 1, true) then
					entry.legacyColorKey = variantKey
					entry.modelName = petId
				end
				if isCore then
					local colorId = tostring(segments[stackIndex + 6] or variantKey)
					entry.variantKey = tostring(variantKey or colorId)
					entry.isCoreColor = true
					entry.IsCoreColor = true
					entry.ColorId = colorId
					entry.ColorName = entry.displayName
					entry.CoreId = tostring(segments[stackIndex + 7] or "RedCore")
					entry.CreatedAt = tonumber(segments[stackIndex + 8]) or os.time()
					entry.Power = math.max(1, math.floor(tonumber(segments[stackIndex + 9]) or entry.finalPower or 1))
					entry.finalPower = entry.Power
					entry.effectivePower = entry.Power
					entry.Rarity = tostring(segments[stackIndex + 10] or entry.rarity or "Common")
					entry.rarity = entry.Rarity
					entry.IsGlitched = segments[stackIndex + 11] == "true" or segments[stackIndex + 11] == "1"
					entry.isGlitched = entry.IsGlitched
					entry.stackAmount = 1
					entry.hasMutation = entry.mutationId ~= ColorMutationData.NoneId
				end
				table.insert(entries, entry)
			end
		end
	end
	return entries
end

local function applyCoreDisplayFields(entry, record)
	if not entry or type(record) ~= "table" then
		return entry
	end
	local isCoreColor = record.isCoreColor == true
		or record.IsCoreColor == true
		or record.colorId ~= nil
		or record.ColorId ~= nil
		or record.coreId ~= nil
		or record.CoreId ~= nil
	if not isCoreColor then
		return entry
	end

	entry.isCoreColor = true
	entry.IsCoreColor = true
	entry.variantKey =
		tostring(record.variantKey or record.VariantKey or record.colorId or record.ColorId or entry.variantKey)
	entry.ColorId = tostring(record.colorId or record.ColorId or entry.variantKey)
	entry.ColorName = tostring(record.colorName or record.ColorName or entry.displayName or entry.petId)
	entry.CoreId = tostring(record.coreId or record.CoreId or "RedCore")
	entry.CreatedAt = tonumber(record.createdAt or record.CreatedAt) or os.time()
	entry.Power = math.max(1, math.floor(tonumber(record.power or record.Power or entry.finalPower) or 1))
	entry.finalPower = entry.Power
	entry.effectivePower = entry.Power
	entry.Rarity = tostring(record.rarity or record.Rarity or entry.rarity or "Common")
	entry.rarity = entry.Rarity
	entry.displayName = entry.ColorName
	entry.baseName = entry.ColorName
	entry.stackAmount = 1
	entry.mutationId =
		PetData.normalizeMutationId(record.mutationId or record.MutationId or record.Mutation or entry.mutationId)
	entry.MutationId = entry.mutationId
	entry.Mutation = entry.mutationId ~= ColorMutationData.NoneId and entry.mutationId or nil
	entry.hasMutation = entry.mutationId ~= ColorMutationData.NoneId
	entry.IsGlitched = record.isGlitched == true or record.IsGlitched == true
	entry.isGlitched = entry.IsGlitched
	local mutation = ColorMutationData.get(entry.mutationId)
	if mutation then
		entry.mutationName = mutation.DisplayName
		entry.mutationDescription = mutation.Description
	end
	return entry
end

local function getLivePetInventorySnapshot(player)
	if not petInventorySnapshotFunction or not petInventorySnapshotFunction.Parent then
		petInventorySnapshotFunction = ServerStorage:FindFirstChild("PetInventorySnapshot")
	end
	if not (petInventorySnapshotFunction and petInventorySnapshotFunction:IsA("BindableFunction")) then
		return nil
	end

	local ok, records, equippedList, lockedList = pcall(function()
		return petInventorySnapshotFunction:Invoke(player)
	end)
	if not ok or type(records) ~= "table" then
		return nil
	end

	return records,
		type(equippedList) == "table" and equippedList or {},
		type(lockedList) == "table" and lockedList or {}
end

local function buildEntriesFromSnapshot(records)
	local entries = {}
	for _, record in ipairs(records) do
		if type(record) ~= "table" then
			continue
		end

		local petId = tostring(record.petId or record.PetId or "")
		if petId == "" then
			continue
		end

		local traitId = PetData.normalizeTraitId(record.traitId or record.TraitId or "Neutral")
		local mutationId = PetData.normalizeMutationId(record.mutationId or record.MutationId or "None")
		local personalityId = PetData.normalizePersonalityId(record.personalityId or record.PersonalityId or "Neutral")
		local stackAmount = math.max(1, tonumber(record.stackAmount or record.StackAmount or record.Amount) or 1)
		local entry = PetData.buildPetEntry(
			petId,
			stackAmount,
			record.isShiny == true or record.IsShiny == true,
			personalityId,
			mutationId,
			traitId
		)
		if entry then
			entry.variantKey = tostring(record.variantKey or record.VariantKey or entry.variantKey)
			entry.petId = petId
			entry.modelName = record.modelName or record.ModelName or entry.modelName
			applyCoreDisplayFields(entry, record)
			table.insert(entries, entry)
		end
	end
	return entries
end

local function buildSetFromList(values)
	local set = {}
	for _, value in ipairs(values or {}) do
		if value ~= nil and tostring(value) ~= "" then
			set[tostring(value)] = true
		end
	end
	return set
end

local function entryIsInSet(entry, set)
	if not entry or not set then
		return false
	end
	return set[tostring(entry.variantKey or "")] == true
		or set[tostring(entry.ColorId or entry.colorId or "")] == true
		or set[tostring(entry.petId or "")] == true
end

local function buildColorRows(player)
	local _, inventoryValue, equippedValue, lockedValue = waitForPlayerPetData(player)
	local snapshotRecords, equippedList, lockedList = getLivePetInventorySnapshot(player)
	local entries = snapshotRecords and buildEntriesFromSnapshot(snapshotRecords)
		or parsePetInventory(inventoryValue and inventoryValue.Value or "")
	local equipped = snapshotRecords and buildSetFromList(equippedList)
		or setFromCsv(equippedValue and equippedValue.Value or "")
	local locked = snapshotRecords and buildSetFromList(lockedList)
		or setFromCsv(lockedValue and lockedValue.Value or "")

	local rows = {}
	for _, entry in ipairs(entries) do
		local pet = PetData.Pets[entry.petId] or {}
		local definition = PetDefinitions.Get(entry.petId)
		local mutationName = entry.mutationId or entry.mutationName or "None"
		if mutationName == "" then
			mutationName = "None"
		end
		local mutation = ColorMutationData.get(entry.mutationId)
		local isCoreColor = entry.isCoreColor == true or entry.IsCoreColor == true
		local isGlitched = entry.isGlitched == true or entry.IsGlitched == true
		local displayName = entry.displayName or pet.displayName or entry.petId
		if isCoreColor then
			displayName = tostring(entry.ColorName or entry.colorName or displayName)
		end
		if entry.petId == "DevRainbowPet" and displayName == "Rainbow Pet" then
			displayName = "Dev Rainbow Pet"
		end
		local amount = isCoreColor and 1 or math.max(1, tonumber(entry.stackAmount) or 1)
		local rarity = entry.Rarity or entry.rarity or pet.rarity or "Color"
		if entry.legacyColorKey and entry.traitId and entry.traitId ~= "Neutral" then
			rarity = entry.traitId
		end
		local power = entry.Power or entry.finalPower or entry.effectivePower or 0
		local mutationLabel
		if mutation then
			mutationLabel = isGlitched and ("GLITCHED " .. string.upper(mutation.DisplayName))
				or (string.upper(mutation.DisplayName) .. " MUTATION")
		end
		local stats = {
			"Owned: x" .. tostring(amount),
			"Power: " .. tostring(power),
			"Color Gain: x" .. string.format("%.2f", tonumber(entry.colorMult) or 1),
			"Coin Bonus: x" .. string.format("%.2f", tonumber(entry.coinMult) or 1),
		}
		if mutationLabel then
			table.insert(stats, "Mutation: " .. mutationLabel)
		end
		table.insert(rows, {
			Id = entry.variantKey,
			Kind = "Color",
			Name = displayName,
			Rarity = rarity,
			Amount = amount,
			Equipped = entryIsInSet(entry, equipped),
			Locked = entryIsInSet(entry, locked),
			MutationId = entry.mutationId,
			Mutation = mutationName,
			MutationText = mutationLabel,
			IsGlitched = isGlitched,
			CoreId = entry.CoreId,
			ColorId = entry.ColorId,
			Trait = entry.traitName,
			Power = tostring(power),
			Bonus = mutationLabel or ("Coins x" .. string.format("%.2f", tonumber(entry.coinMult) or 1)),
			Description = tostring(
				isGlitched and "Glitched mutation jackpot."
					or (mutation and mutation.Description)
					or entry.traitDescription
					or entry.mutationDescription
					or "Color companion."
			),
			IconImage = pet.IconImage or pet.iconImage,
			IconText = entry.petId == "DevRainbowPet" and "RA" or string.upper(string.sub(displayName, 1, 2)),
			IconColor = (definition and definition.IconColor) or pet.iconColor or pet.color,
			ModelName = entry.modelName or (definition and definition.ModelName) or pet.modelName or entry.petId,
			PetId = entry.petId,
			Stats = stats,
		})
	end

	table.sort(rows, function(a, b)
		if a.Equipped ~= b.Equipped then
			return a.Equipped
		end
		return tostring(a.Name) < tostring(b.Name)
	end)
	return rows
end

local function buildBrushRows(player)
	local toolsFolder = player:FindFirstChild("PaintTools")
	local ownedValue = toolsFolder and toolsFolder:FindFirstChild("Owned")
	local equippedValue = toolsFolder and toolsFolder:FindFirstChild("Equipped")
	local owned = setFromCsv(ownedValue and ownedValue.Value or "StarterBrush")
	owned.StarterBrush = true
	local equippedId = equippedValue and equippedValue.Value or "StarterBrush"

	local rows = {}
	for _, toolId in ipairs(ToolData.Order or {}) do
		local tool = ToolData.Tools[toolId]
		if tool and owned[toolId] then
			local stats = ToolData.GetEffectiveStats and ToolData.GetEffectiveStats(tool.Id, player) or {}
			local passiveDefined = tool.PassiveEnabled == true
			local passiveUnlocked = ToolData.HasUnlockedPassive and ToolData.HasUnlockedPassive(player, tool) == true
			local passiveText = "Passive: none"
			if passiveDefined then
				if passiveUnlocked then
					passiveText = tostring(tool.PassiveName or "Passive")
						.. ": "
						.. tostring(tool.PassiveDescription or "")
				else
					local unlockColor = tostring(tool.PassiveUnlockSector or ToolData.PassiveUnlockColor or "Green")
					local world = ColorData.getWorldByColor and ColorData.getWorldByColor(unlockColor)
					passiveText = "Passive: unlocks in " .. tostring((world and world.DisplayName) or unlockColor)
				end
			end

			table.insert(rows, {
				Id = tool.Id,
				Kind = "Brush",
				Name = tool.DisplayName or tool.Id,
				Level = 1,
				Rarity = tool.Rarity or "Brush",
				Equipped = equippedId == tool.Id,
				Power = tonumber(tool.PowerMultiplier or tool.CollectPowerMultiplier) or 1,
				Description = tool.Description or tool.Flavor or "Paint tool.",
				IconText = tool.ShortName or "BR",
				IconImage = tool.IconImage or tool.iconImage,
				IconName = tool.IconKey or "Tag",
				IconColor = tool.AccentColor,
				AccentColor = tool.AccentColor,
				ModelName = tool.ModelName or tool.Id,
				Stats = {
					"Power: x"
						.. string.format("%.2f", tonumber(tool.PowerMultiplier or tool.CollectPowerMultiplier) or 1),
					"Range: " .. tostring(tool.Range or "-"),
					"Width: " .. tostring(tool.Width or "-"),
					"Ground radius: " .. tostring(math.floor(tonumber(stats.BrushRadius or tool.BrushRadius) or 0)),
					"Brush tick: "
						.. string.format("%.2fs", tonumber(stats.BrushTickRate or tool.BrushTickRate) or 0.14),
					"Speed: x" .. string.format("%.2f", tonumber(tool.UseSpeedMultiplier) or 1),
					"Active: " .. tostring(stats.ActiveName or tool.ActiveName or "Basic Swipe"),
					tostring(stats.ActiveDescription or tool.ActiveDescription or ""),
					passiveText,
				},
			})
		end
	end
	return rows
end

local function getItemsFromService(player)
	local bridge = ServerStorage:FindFirstChild("InventoryItemsBridge")
	if not bridge or not bridge:IsA("BindableFunction") then
		return {}
	end
	local ok, success, items = pcall(function()
		return bridge:Invoke(player, "GetInventory")
	end)
	if ok and success == true and type(items) == "table" then
		return items
	end
	return {}
end

local function isPotion(item)
	return item and (item.boostType ~= nil or item.category == "Boosts")
end

local function makeStats(...)
	local stats = {}
	for index = 1, select("#", ...) do
		local value = select(index, ...)
		if value ~= nil and value ~= "" then
			table.insert(stats, tostring(value))
		end
	end
	return stats
end

local function buildItemRows(player, wantPotions)
	local rows = {}
	for itemId, quantity in pairs(getItemsFromService(player)) do
		local item = ItemsData.Items[itemId]
		quantity = math.floor(tonumber(quantity) or 0)
		if item and quantity > 0 and isPotion(item) == wantPotions then
			table.insert(rows, {
				Id = itemId,
				Kind = wantPotions and "Potion" or "Item",
				Name = item.displayName or itemId,
				Rarity = item.rarity or "Common",
				Amount = quantity,
				Duration = item.boostDuration and (tostring(math.floor(item.boostDuration / 60)) .. " min") or nil,
				Description = item.description or "Inventory item.",
				Usable = item.usable == true,
				IconText = item.icon or string.upper(string.sub(item.displayName or itemId, 1, 2)),
				IconImage = item.IconImage or item.iconImage,
				Stats = makeStats(
					item.boostType and ("Boost: " .. tostring(item.boostType)) or nil,
					item.boostDuration and ("Duration: " .. tostring(item.boostDuration) .. "s") or nil
				),
			})
		end
	end
	table.sort(rows, function(a, b)
		return tostring(a.Name) < tostring(b.Name)
	end)
	return rows
end

local function buildInventory(player)
	local colors = buildColorRows(player)
	local colorAmount = 0
	for _, color in ipairs(colors) do
		colorAmount += math.max(1, tonumber(color.Amount) or 1)
	end
	return {
		Colors = colors,
		Brushes = buildBrushRows(player),
		Potions = buildItemRows(player, true),
		Items = buildItemRows(player, false),
		Count = colorAmount,
		Capacity = GamepassBenefits.hasInfiniteStorage(player) and INFINITE_CAPACITY_LABEL or COLOR_CAPACITY,
	}
end

local function markDirty(player, reason)
	if dataDirtyEvent and dataDirtyEvent:IsA("BindableEvent") then
		dataDirtyEvent:Fire(player, reason)
	end
end

local function setBrushEquipped(player, brushId, equippedRequested)
	local toolsFolder = player:FindFirstChild("PaintTools")
	local ownedValue = toolsFolder and toolsFolder:FindFirstChild("Owned")
	local equippedValue = toolsFolder and toolsFolder:FindFirstChild("Equipped")
	brushId = ToolData.ResolveBrushId and ToolData.ResolveBrushId(brushId) or brushId
	local tool = ToolData.Tools[brushId or ""]
	if not tool or not ownedValue or not equippedValue then
		return false, "Brush data is not ready."
	end
	local owned = setFromCsv(ownedValue.Value)
	owned.StarterBrush = true
	if not owned[tool.Id] then
		return false, "You do not own this brush."
	end

	if equippedRequested == false then
		if equippedValue.Value == tool.Id then
			equippedValue.Value = "StarterBrush"
			markDirty(player, "paint-tool-equipped")
			equipPaintToolEvent:FireClient(player, true, "StarterBrush", "Equipped Starter Brush")
		end
		return true, "Brush unequipped."
	end

	equippedValue.Value = tool.Id
	markDirty(player, "paint-tool-equipped")
	equipPaintToolEvent:FireClient(player, true, tool.Id, "Equipped " .. (tool.DisplayName or tool.Id))
	return true, "Brush equipped."
end

local function runPetAction(player, action, id, value)
	local bridge = ServerStorage:FindFirstChild("InventoryPetAction")
	if not bridge or not bridge:IsA("BindableFunction") then
		return false, "Color inventory action bridge is not ready."
	end
	local ok, success, message = pcall(function()
		return bridge:Invoke(player, action, id, value)
	end)
	if not ok then
		warn("EditableInventoryBridge pet action failed: " .. tostring(success))
		return false, "Color action failed."
	end
	return success == true, tostring(message or (success and "Done." or "Action failed."))
end

local function useItem(player, itemId)
	local bridge = ServerStorage:FindFirstChild("InventoryItemsBridge")
	if not bridge or not bridge:IsA("BindableFunction") then
		return false, "Item inventory is not ready."
	end
	local ok, success, message = pcall(function()
		return bridge:Invoke(player, "UseItem", itemId, 1)
	end)
	if not ok then
		warn("EditableInventoryBridge item action failed: " .. tostring(success))
		return false, "Item action failed."
	end
	return success == true, tostring(message or (success and "Item used." or "Item action failed."))
end

inventoryRequest.OnServerInvoke = function(player, action)
	if action ~= nil and action ~= "GetInventory" then
		return nil
	end
	return buildInventory(player)
end

inventoryAction.OnServerEvent:Connect(function(player, action, payload)
	payload = type(payload) == "table" and payload or {}
	local id = tostring(payload.Id or payload.id or "")
	local kind = tostring(payload.Kind or payload.kind or "")
	local ok = false
	local message = "Unknown inventory action."

	if action == "Equip" and kind == "Color" then
		ok, message = runPetAction(player, "EquipColor", id)
	elseif action == "Unequip" and kind == "Color" then
		ok, message = runPetAction(player, "UnequipColor", id)
	elseif action == "Lock" and kind == "Color" then
		ok, message = runPetAction(player, "LockColor", id, payload.Locked == true)
	elseif action == "Delete" and kind == "Color" then
		ok, message = runPetAction(player, "DeleteColor", id)
	elseif action == "Equip" and kind == "Brush" then
		ok, message = setBrushEquipped(player, id, true)
	elseif action == "Unequip" and kind == "Brush" then
		ok, message = setBrushEquipped(player, id, false)
	elseif action == "Use" and (kind == "Potion" or kind == "Item") then
		ok, message = useItem(player, id)
	end

	inventoryAction:FireClient(player, {
		Success = ok,
		Message = message,
		Action = action,
		Kind = kind,
		Id = id,
		Inventory = buildInventory(player),
	})
end)
