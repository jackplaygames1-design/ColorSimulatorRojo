-- Script in ServerScriptService named "DataManager"
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local ColorData = require(ReplicatedStorage:WaitForChild("ColorData"))
local PetData = require(ReplicatedStorage:WaitForChild("PetData"))
local RankService = require(script.Parent:WaitForChild("RankService"))
local SettingsData = require(ReplicatedStorage:WaitForChild("SettingsData"))
local ToolData = require(ReplicatedStorage:WaitForChild("ToolData"))

local GameStore = DataStoreService:GetDataStore("ColorSimulator_v1")
local Events = ReplicatedStorage:WaitForChild("Events")
local playerDataDirtyEvent = Events:FindFirstChild("PlayerDataDirty")
if not playerDataDirtyEvent then
	playerDataDirtyEvent = Instance.new("BindableEvent")
	playerDataDirtyEvent.Name = "PlayerDataDirty"
	playerDataDirtyEvent.Parent = Events
end
local requestSetSettingEvent = Events:FindFirstChild("RequestSetSetting")
if not requestSetSettingEvent then
	requestSetSettingEvent = Instance.new("RemoteEvent")
	requestSetSettingEvent.Name = "RequestSetSetting"
	requestSetSettingEvent.Parent = Events
end
local settingsUpdatedEvent = Events:FindFirstChild("SettingsUpdated")
if not settingsUpdatedEvent then
	settingsUpdatedEvent = Instance.new("RemoteEvent")
	settingsUpdatedEvent.Name = "SettingsUpdated"
	settingsUpdatedEvent.Parent = Events
end
local markTutorialProgressEvent = Events:FindFirstChild("MarkTutorialProgress")
if not markTutorialProgressEvent then
	markTutorialProgressEvent = Instance.new("RemoteEvent")
	markTutorialProgressEvent.Name = "MarkTutorialProgress"
	markTutorialProgressEvent.Parent = Events
end

local ENABLE_STUDIO_DATASTORE = false
local AUTO_SAVE_INTERVAL = RunService:IsStudio() and 0 or 180
local MIN_SAVE_INTERVAL = 90
local CRITICAL_SAVE_DELAY = 8
local CRITICAL_SAVE_COOLDOWN = 45
local CURRENT_DATA_VERSION = 5
local sessionData

local warnedMigrationKeys = {}
local function warnOnce(key, message)
	if warnedMigrationKeys[key] then
		return
	end
	warnedMigrationKeys[key] = true
	warn(message)
end

-- Default data for a brand new player.
-- Player-facing companions are called Colors, but saved data keeps Pet fields for backward compatibility.
local DEFAULT_DATA = {
	Version = CURRENT_DATA_VERSION,
	DataVersion = CURRENT_DATA_VERSION,
	Coins = 0,
	Gems = 0,
	Diamonds = 0,
	Rebirths = 0,
	RankLevel = 1,
	RankXP = 0,
	RankTotalXP = 0,
	UnlockedColors = { "Red" },
	CurrentWorld = "Red",
	UnlockedTeleports = { "OriginSector" },
	PetInventory = {}, -- canonical saved Color inventory; list of { petId = "RedBlob", stackAmount = 1, traitId = "Neutral", mutationId = "None" }
	EquippedPets = {}, -- list of Color variant keys
	LockedPets = {}, -- variant keys protected from deletion
	OwnedPaintTools = { "StarterBrush" },
	EquippedPaintTool = "StarterBrush",
	Settings = {
		Music = true,
		SFX = true,
		Popups = true,
		LowFX = false,
	},
	Upgrades = {},
	RedeemedCodes = {}, -- [normalizedCode] = uses
	TutorialCompleted = true,
	TutorialProgress = {
		SeenTraitsTutorial = false,
		MutationsUnlocked = false,
		HasSeenMutationTutorial = false,
	},
	GroupRewards = {
		LastDailyGemClaim = "",
	},
	GamepassGrants = {},
	InfinitePackClaims = {
		ResetKey = "",
		ClaimedTiers = {},
	},
}

local function infinitePackResetKey()
	return os.date("!%Y-%m-%d")
end

local OWNER_RAINBOW_PET_ID = "DevRainbowPet"
local OWNER_RAINBOW_PET_TRAIT = "SuperLucky"
local OWNER_RAINBOW_PET_NAMES = {
	jackdoesrb = true,
}

local function shouldOwnRainbowPet(player)
	if not player then
		return false
	end
	if OWNER_RAINBOW_PET_NAMES[string.lower(player.Name)] then
		return true
	end
	return game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
end

local function makeOwnerRainbowRecord()
	return {
		petId = OWNER_RAINBOW_PET_ID,
		stackAmount = 1,
		traitId = PetData.normalizeTraitId(OWNER_RAINBOW_PET_TRAIT),
		traitName = PetData.normalizeTraitId(OWNER_RAINBOW_PET_TRAIT),
		isShiny = false,
		personalityId = "Neutral",
		mutationId = PetData.normalizeMutationId("None"),
		mergeTier = "Normal",
	}
end

local function ensureOwnerRainbowPetList(player, list)
	if not shouldOwnRainbowPet(player) then
		return list
	end

	list = type(list) == "table" and list or {}
	local wanted = makeOwnerRainbowRecord()
	local wantedKey = PetData.makeVariantKey(wanted.petId, wanted.personalityId, wanted.mutationId, wanted.traitId)
	for _, record in ipairs(list) do
		if type(record) == "table" then
			local traitId = PetData.normalizeTraitId(record.traitId or record.TraitId or record.traitName or "Neutral")
			local mutationId = PetData.normalizeMutationId(record.mutationId or record.MutationId or "None")
			local personalityId =
				PetData.normalizePersonalityId(record.personalityId or record.PersonalityId or "Neutral")
			local recordKey = PetData.makeVariantKey(record.petId or record.PetId, personalityId, mutationId, traitId)
			if recordKey == wantedKey then
				record.petId = OWNER_RAINBOW_PET_ID
				record.stackAmount = math.max(1, tonumber(record.stackAmount or record.StackAmount) or 1)
				record.traitId = wanted.traitId
				record.traitName = wanted.traitName
				record.isShiny = false
				record.personalityId = "Neutral"
				record.mutationId = wanted.mutationId
				record.mergeTier = "Normal"
				return list
			end
		end
	end

	table.insert(list, wanted)
	return list
end

-- Deep copy a table so defaults are never mutated
local function deepCopy(tbl)
	if type(tbl) ~= "table" then
		return tbl
	end
	local copy = {}
	for k, v in pairs(tbl) do
		copy[k] = type(v) == "table" and deepCopy(v) or v
	end
	return copy
end

-- Fill defaults only where fields are missing. Existing saved tables are preserved.
local function DeepFillMissing(target, defaults)
	if type(target) ~= "table" then
		target = {}
	end
	for key, defaultValue in pairs(defaults or {}) do
		local currentValue = target[key]
		if currentValue == nil then
			target[key] = deepCopy(defaultValue)
		elseif type(currentValue) == "table" and type(defaultValue) == "table" then
			DeepFillMissing(currentValue, defaultValue)
		end
	end
	return target
end

local function normalizeUnlockedColorList(value)
	local set = {}
	if type(value) == "table" then
		for key, colorType in pairs(value) do
			if colorType == true then
				colorType = key
			end
			local world = ColorData.getWorldByColor(colorType)
			if world then
				set[world.primaryColor] = true
			end
		end
	elseif type(value) == "string" then
		for _, colorType in ipairs(string.split(value, ",")) do
			local world = ColorData.getWorldByColor(colorType)
			if world then
				set[world.primaryColor] = true
			end
		end
	end

	set.Red = true
	local highestUnlockedIndex = 1
	for index, world in ipairs(ColorData.Worlds or {}) do
		if set[world.primaryColor] then
			highestUnlockedIndex = math.max(highestUnlockedIndex, index)
		end
	end
	for index = 1, highestUnlockedIndex do
		local world = ColorData.Worlds[index]
		if world then
			set[world.primaryColor] = true
		end
	end

	local ordered = {}
	for _, world in ipairs(ColorData.Worlds or {}) do
		if set[world.primaryColor] then
			table.insert(ordered, world.primaryColor)
		end
	end
	return ordered
end

local function getHighestUnlockedColor(unlockedColors)
	local set = {}
	for _, colorType in ipairs(unlockedColors or {}) do
		set[colorType] = true
	end

	local highest = "Red"
	for _, world in ipairs(ColorData.Worlds or {}) do
		if set[world.primaryColor] then
			highest = world.primaryColor
		end
	end
	return highest
end

local function normalizeCurrentWorld(colorType, unlockedColors)
	local world = ColorData.getWorldByColor(colorType)
	local normalized = world and world.primaryColor or nil
	if normalized then
		for _, unlockedColor in ipairs(unlockedColors or {}) do
			if unlockedColor == normalized then
				return normalized
			end
		end
	end
	return getHighestUnlockedColor(unlockedColors)
end

local function normalizeTeleportList(value)
	local seen = {}
	local ordered = {}

	local function add(locationId)
		locationId = tostring(locationId or "")
		if locationId == "" or seen[locationId] then
			return
		end
		seen[locationId] = true
		table.insert(ordered, locationId)
	end

	add("OriginSector")
	if type(value) == "table" then
		for key, locationId in pairs(value) do
			if locationId == true then
				locationId = key
			end
			add(locationId)
		end
	elseif type(value) == "string" then
		for _, locationId in ipairs(string.split(value, ",")) do
			add(locationId)
		end
	end

	return ordered
end

local function normalizePaintToolList(value)
	local seen = {}
	local ordered = {}

	local function add(toolId)
		toolId = tostring(toolId or "")
		if toolId == "" or seen[toolId] then
			return
		end
		if ToolData.isValid and not ToolData.isValid(toolId) then
			warnOnce("invalid-brush-" .. toolId, "DataManager: invalid saved brush id repaired: " .. toolId)
			return
		end
		seen[toolId] = true
		table.insert(ordered, toolId)
	end

	if type(value) == "string" then
		for _, toolId in ipairs(string.split(value, ",")) do
			add(toolId)
		end
	elseif type(value) == "table" then
		for key, toolId in pairs(value) do
			if toolId == true then
				add(key)
			else
				add(toolId)
			end
		end
	end

	if not seen.StarterBrush then
		table.insert(ordered, 1, "StarterBrush")
	end
	return ordered
end

local function normalizeEquippedPaintTool(toolId, ownedTools)
	toolId = tostring(toolId or "")
	local owned = {}
	for _, ownedToolId in ipairs(ownedTools or {}) do
		owned[ownedToolId] = true
	end

	if toolId ~= "" and owned[toolId] then
		return toolId
	end
	return "StarterBrush"
end

local function normalizeSettings(settings)
	return SettingsData.Normalize(settings)
end

local function applySettingAttributes(player, settings)
	local normalized = normalizeSettings(settings)
	for key, value in pairs(normalized) do
		player:SetAttribute("Setting" .. key, value)
	end
end

local function sendSettings(player, success, settingKey, message)
	local settingsFolder = player:FindFirstChild("Settings")
	local settings = {}
	if settingsFolder then
		for key, defaultValue in pairs(SettingsData.Defaults) do
			local value = settingsFolder:FindFirstChild(key)
			settings[key] = value and value:IsA("BoolValue") and value.Value or defaultValue
		end
	else
		local cached = sessionData and sessionData[player]
		settings = normalizeSettings(cached and cached.Settings)
	end

	settingsUpdatedEvent:FireClient(player, normalizeSettings(settings), success ~= false, settingKey, message)
end

local function encodePetRecord(record)
	if type(record) == "string" then
		return record
	end

	local petId = record.petId or record.PetId
	if not petId or petId == "" then
		return nil
	end

	local stackAmount = tonumber(record.stackAmount or record.StackAmount or record.amount or record.Amount) or 1
	local traitId = record.traitId
		or record.TraitId
		or record.traitName
		or record.TraitName
		or record.trait
		or "Neutral"
	if type(traitId) == "table" then
		traitId = traitId.Id or traitId.id or traitId.name or "Neutral"
	end
	traitId = PetData.normalizeTraitId(traitId)

	local shiny = record.isShiny or record.IsShiny
	local shinyText = shiny and "shiny" or "normal"
	local personalityId = record.personalityId or record.PersonalityId or "Neutral"
	local mutationId = PetData.normalizeMutationId(record.mutationId or record.MutationId or "None")
	local variantKey = PetData.makeVariantKey(petId, personalityId, mutationId, traitId)

	return tostring(variantKey)
		.. ":"
		.. tostring(petId)
		.. ":"
		.. tostring(math.max(1, stackAmount))
		.. ":"
		.. tostring(traitId)
		.. ":"
		.. shinyText
		.. ":"
		.. tostring(personalityId)
		.. ":"
		.. tostring(mutationId)
end

local function decodePetRecord(encoded)
	local segments = string.split(encoded, ":")
	local variantKey
	local petId
	local stackIndex
	if tonumber(segments[2]) then
		petId = segments[1]
		variantKey = petId
		stackIndex = 2
	else
		variantKey = segments[1]
		petId = segments[2]
		stackIndex = 3
	end
	if not petId or petId == "" then
		return nil
	end

	return {
		variantKey = variantKey,
		petId = petId,
		stackAmount = tonumber(segments[stackIndex]) or 1,
		traitId = PetData.normalizeTraitId(segments[stackIndex + 1]),
		traitName = PetData.normalizeTraitId(segments[stackIndex + 1]),
		isShiny = segments[stackIndex + 2] == "shiny" or segments[stackIndex + 2] == "true",
		personalityId = segments[stackIndex + 3] or "Neutral",
		mutationId = PetData.normalizeMutationId(segments[stackIndex + 4] or "None"),
	}
end

local function countPetStacks(records)
	if type(records) ~= "table" then
		return 0
	end

	local count = 0
	for _, record in pairs(records) do
		if type(record) == "table" or type(record) == "string" then
			count += 1
		end
	end
	return count
end

local function countPetAmount(records)
	if type(records) ~= "table" then
		return 0
	end

	local total = 0
	for _, record in pairs(records) do
		if type(record) == "table" then
			total += math.max(
				1,
				tonumber(
					record.stackAmount
						or record.StackAmount
						or record.amount
						or record.Amount
						or record.count
						or record.Count
				) or 1
			)
		elseif type(record) == "string" and record ~= "" then
			local decoded = decodePetRecord(record)
			total += decoded and math.max(1, tonumber(decoded.stackAmount) or 1) or 1
		end
	end
	return total
end

local function copyStringList(value)
	local list = {}
	if type(value) ~= "table" then
		return list
	end

	for _, item in ipairs(value) do
		if item ~= nil and tostring(item) ~= "" then
			table.insert(list, tostring(item))
		end
	end
	return list
end

local function parsePetInventoryValue(value)
	local records = {}
	if type(value) ~= "string" or value == "" then
		return records
	end

	for _, encoded in ipairs(string.split(value, ",")) do
		local record = decodePetRecord(encoded)
		if record then
			table.insert(records, record)
		end
	end
	return records
end

local function tryGetPetInventorySnapshot(player)
	local snapshotFunction = ServerStorage:FindFirstChild("PetInventorySnapshot")
	if not snapshotFunction or not snapshotFunction:IsA("BindableFunction") then
		return nil
	end

	local ok, records, equipped, locked = pcall(function()
		return snapshotFunction:Invoke(player)
	end)
	if not ok then
		warn(
			"DataManager: failed to read PetHandler inventory snapshot for " .. player.Name .. ": " .. tostring(records)
		)
		return nil
	end
	if type(records) ~= "table" then
		return nil
	end

	return records, copyStringList(equipped), copyStringList(locked)
end

local function countList(value)
	return type(value) == "table" and #value or 0
end

local function countMap(value)
	if type(value) ~= "table" then
		return 0
	end

	local total = 0
	for _ in pairs(value) do
		total += 1
	end
	return total
end

local function countUnlockedSectors(data)
	return countList(data and data.UnlockedColors)
end

local function ownsUnlockedColor(data, colorType)
	for _, unlockedColor in ipairs((data and data.UnlockedColors) or {}) do
		if unlockedColor == colorType then
			return true
		end
	end
	return false
end

local function ownsPaintTool(data, toolId)
	for _, ownedToolId in ipairs((data and data.OwnedPaintTools) or {}) do
		if ownedToolId == toolId then
			return true
		end
	end
	return false
end

local function finiteNumber(value, fallback, fieldName, player)
	local numberValue = tonumber(value)
	if not numberValue or numberValue ~= numberValue or numberValue == math.huge or numberValue == -math.huge then
		if player then
			warn("DataManager: repaired invalid numeric field " .. tostring(fieldName) .. " for " .. player.Name)
		end
		return fallback
	end
	return numberValue
end

local function getRecordVariantKey(record)
	if type(record) ~= "table" then
		return nil
	end
	return PetData.makeVariantKey(record.petId, record.personalityId, record.mutationId, record.traitId)
end

local function resolveEquippedPetKey(records, key)
	if not key or key == "" then
		return nil
	end

	key = tostring(key)
	for _, record in ipairs(records or {}) do
		local variantKey = getRecordVariantKey(record)
		if variantKey == key or record.petId == key then
			return variantKey
		end

		local legacyParts = string.split(key, "|")
		if #legacyParts >= 3 and legacyParts[1] == record.petId then
			local traitMatches = PetData.normalizeTraitId(legacyParts[2]) == PetData.normalizeTraitId(record.traitId)
			local mutationMatches = PetData.normalizeMutationId(legacyParts[3])
				== PetData.normalizeMutationId(record.mutationId)
			if traitMatches and mutationMatches then
				return variantKey
			end
		end
	end
	return nil
end

local function sanitizeEquippedPetList(equippedList, petRecords, player)
	local sanitized = {}
	local seen = {}
	if type(equippedList) ~= "table" then
		return sanitized
	end

	for _, key in ipairs(equippedList) do
		local resolvedKey = resolveEquippedPetKey(petRecords, key)
		if resolvedKey and not seen[resolvedKey] then
			seen[resolvedKey] = true
			table.insert(sanitized, resolvedKey)
		elseif key and key ~= "" and player then
			warn("DataManager: removed invalid equipped Color for " .. player.Name .. ": " .. tostring(key))
		end
	end
	return sanitized
end

local function formatProfileSummary(data)
	return "v="
		.. tostring(data and (data.DataVersion or data.Version))
		.. " coins="
		.. tostring(data and data.Coins or 0)
		.. " gems="
		.. tostring(data and data.Gems or 0)
		.. " colorStacks="
		.. tostring(countPetStacks(data and data.PetInventory))
		.. " colorAmount="
		.. tostring(countPetAmount(data and data.PetInventory))
		.. " equippedColors="
		.. tostring(countList(data and data.EquippedPets))
		.. " brushes="
		.. tostring(countList(data and data.OwnedPaintTools))
		.. " equippedBrush="
		.. tostring(data and data.EquippedPaintTool or "")
		.. " sectors="
		.. tostring(countUnlockedSectors(data))
		.. " currentWorld="
		.. tostring(data and data.CurrentWorld or "")
		.. " rank="
		.. tostring(data and data.RankLevel or 1)
		.. " rankXP="
		.. tostring(data and data.RankXP or 0)
		.. " codes="
		.. tostring(countMap(data and data.RedeemedCodes))
		.. " grants="
		.. tostring(countMap(data and data.GamepassGrants))
end

local function logProfileSummary(player, phase, data, reason)
	print(
		"DataManager ["
			.. tostring(phase)
			.. "] "
			.. tostring(player and (player.Name .. "/" .. player.UserId) or "unknown")
			.. " reason="
			.. tostring(reason or "load")
			.. " "
			.. formatProfileSummary(data)
	)
end

local function normalizePetIdFromKey(key)
	if type(key) ~= "string" or key == "" then
		return nil
	end

	local colonParts = string.split(key, ":")
	if #colonParts >= 2 then
		return colonParts[2] ~= "" and colonParts[2] or colonParts[1]
	end

	local variantParts = string.split(key, "|")
	return variantParts[1] ~= "" and variantParts[1] or key
end

local function normalizePetRecord(record, sourceKey, backupList)
	local normalized

	if type(record) == "string" then
		if string.find(record, ":", 1, true) then
			normalized = decodePetRecord(record)
		elseif record ~= "" then
			normalized = {
				petId = record,
				stackAmount = 1,
			}
		end
	elseif type(record) == "number" and sourceKey ~= nil then
		normalized = {
			petId = normalizePetIdFromKey(tostring(sourceKey)),
			stackAmount = record,
		}
	elseif type(record) == "table" then
		local petId = record.petId
			or record.PetId
			or record.colorId
			or record.ColorId
			or record.id
			or record.Id
			or normalizePetIdFromKey(type(sourceKey) == "string" and sourceKey or nil)

		if petId and petId ~= "" then
			normalized = {
				variantKey = record.variantKey or record.VariantKey or record.key or record.Key,
				petId = tostring(petId),
				stackAmount = tonumber(
					record.stackAmount
						or record.StackAmount
						or record.amount
						or record.Amount
						or record.count
						or record.Count
						or record.qty
						or record.Quantity
				) or 1,
				traitId = record.traitId
					or record.TraitId
					or record.traitName
					or record.TraitName
					or record.trait
					or record.Trait,
				mutationId = record.mutationId or record.MutationId or record.mutation or record.Mutation,
				mergeTier = record.mergeTier or record.MergeTier or record.currentStackTier or record.CurrentStackTier,
				isShiny = record.isShiny or record.IsShiny or record.shiny or record.Shiny,
				personalityId = record.personalityId or record.PersonalityId or "Neutral",
			}
		end
	end

	if not normalized or not normalized.petId or normalized.petId == "" then
		table.insert(backupList, deepCopy(record))
		warnOnce("unreadable-color-entry", "DataManager: unreadable saved Color entry preserved in LegacyPetsBackup.")
		return nil
	end

	normalized.petId = tostring(normalized.petId)
	normalized.stackAmount = math.max(1, math.floor(tonumber(normalized.stackAmount) or 1))
	normalized.traitId = PetData.normalizeTraitId(normalized.traitId or "Neutral")
	normalized.traitName = normalized.traitId
	normalized.mutationId = PetData.normalizeMutationId(normalized.mutationId or "None")
	normalized.personalityId = PetData.normalizePersonalityId(normalized.personalityId or "Neutral")
	normalized.mergeTier = normalized.mergeTier or "Normal"
	normalized.isShiny = normalized.isShiny == true or normalized.isShiny == "true" or normalized.isShiny == "shiny"

	if not PetData.Pets[normalized.petId] then
		warnOnce(
			"unknown-color-" .. normalized.petId,
			"Unknown saved ColorId preserved: " .. tostring(normalized.petId)
		)
	end

	return normalized
end

local function addNormalizedInventoryRecord(recordsByKey, record)
	if not record then
		return
	end

	local variantKey = PetData.makeVariantKey(record.petId, record.personalityId, record.mutationId, record.traitId)
	local existing = recordsByKey[variantKey]
	if existing then
		existing.stackAmount += math.max(1, tonumber(record.stackAmount) or 1)
		existing.isShiny = existing.isShiny or record.isShiny == true
	else
		record.variantKey = variantKey
		recordsByKey[variantKey] = record
	end
end

local function normalizeInventorySource(source, recordsByKey, backupList)
	if type(source) == "string" then
		for _, encoded in ipairs(string.split(source, ",")) do
			if encoded ~= "" then
				addNormalizedInventoryRecord(recordsByKey, normalizePetRecord(encoded, nil, backupList))
			end
		end
	elseif type(source) == "table" then
		for key, value in pairs(source) do
			addNormalizedInventoryRecord(recordsByKey, normalizePetRecord(value, key, backupList))
		end
	end
end

local function mergeInventorySource(source, recordsByKey, backupList)
	local sourceRecordsByKey = {}
	normalizeInventorySource(source, sourceRecordsByKey, backupList)
	for variantKey, record in pairs(sourceRecordsByKey) do
		local existing = recordsByKey[variantKey]
		if existing then
			-- Same variant found in legacy aliases. Keep the highest stack to avoid duplicating
			-- mirrored Pets/Colors aliases on future loads.
			existing.stackAmount = math.max(tonumber(existing.stackAmount) or 1, tonumber(record.stackAmount) or 1)
			existing.isShiny = existing.isShiny or record.isShiny == true
		else
			recordsByKey[variantKey] = record
		end
	end
end

local function inventoryMapToList(recordsByKey)
	local list = {}
	for _, record in pairs(recordsByKey) do
		table.insert(list, {
			petId = record.petId,
			stackAmount = math.max(1, tonumber(record.stackAmount) or 1),
			traitId = PetData.normalizeTraitId(record.traitId),
			traitName = PetData.normalizeTraitId(record.traitId),
			isShiny = record.isShiny == true,
			personalityId = PetData.normalizePersonalityId(record.personalityId),
			mutationId = PetData.normalizeMutationId(record.mutationId),
			mergeTier = record.mergeTier or "Normal",
		})
	end
	table.sort(list, function(a, b)
		return tostring(a.petId) < tostring(b.petId)
	end)
	return list
end

local function normalizeEquippedSource(source, equippedList, seen)
	if type(source) == "string" then
		for _, key in ipairs(string.split(source, ",")) do
			if key ~= "" and not seen[key] then
				seen[key] = true
				table.insert(equippedList, key)
			end
		end
	elseif type(source) == "table" then
		for key, value in pairs(source) do
			local equippedKey
			if type(value) == "string" then
				equippedKey = value
			elseif type(value) == "table" then
				equippedKey = value.variantKey
					or value.VariantKey
					or value.petId
					or value.PetId
					or value.colorId
					or value.ColorId
			else
				equippedKey = tostring(key)
			end
			if equippedKey and equippedKey ~= "" and value ~= false and not seen[equippedKey] then
				seen[equippedKey] = true
				table.insert(equippedList, equippedKey)
			end
		end
	end
end

local function sourceHasEntries(source)
	if type(source) == "string" then
		return source ~= ""
	elseif type(source) == "table" then
		return next(source) ~= nil
	end
	return false
end

local function backupLegacyCompanionData(data, oldVersion)
	local hasLegacyInventory = sourceHasEntries(data.Pets)
		or sourceHasEntries(data.Colors)
		or sourceHasEntries(data.PetStacks)
		or sourceHasEntries(data.ColorStacks)
		or sourceHasEntries(data.ColorInventory)
		or sourceHasEntries(data.Inventory)
	local hasOlderCanonicalInventory = (tonumber(oldVersion) or 0) < CURRENT_DATA_VERSION
		and (
			sourceHasEntries(data.PetInventory)
			or sourceHasEntries(data.EquippedPets)
			or sourceHasEntries(data.EquippedColors)
		)
	if not hasLegacyInventory and not hasOlderCanonicalInventory then
		return
	end

	data.MigrationBackups = type(data.MigrationBackups) == "table" and data.MigrationBackups or {}
	local backupKey = "Pets_v" .. tostring(oldVersion or "unknown")
	if not data.MigrationBackups[backupKey] then
		data.MigrationBackups[backupKey] = {
			PetInventory = deepCopy(data.PetInventory),
			Pets = deepCopy(data.Pets),
			Colors = deepCopy(data.Colors),
			PetStacks = deepCopy(data.PetStacks),
			ColorStacks = deepCopy(data.ColorStacks),
			ColorInventory = deepCopy(data.ColorInventory),
			Inventory = deepCopy(data.Inventory),
			EquippedPets = deepCopy(data.EquippedPets),
			EquippedColors = deepCopy(data.EquippedColors),
		}
	end

	if data.LegacyPetsBackup == nil then
		data.LegacyPetsBackup = deepCopy(data.MigrationBackups[backupKey])
	end
end

local function migrateData(saved)
	local raw = type(saved) == "table" and saved or {}
	local data = deepCopy(raw)
	local oldVersion = tonumber(data.DataVersion or data.Version) or 0
	local hadTutorialCompletionFlag = raw.TutorialCompleted ~= nil
	local savedCurrentWorld = raw.CurrentWorld or raw.ActiveWorldColor or raw.HighestUnlockedWorld

	backupLegacyCompanionData(data, oldVersion)
	DeepFillMissing(data, DEFAULT_DATA)
	if not sourceHasEntries(raw.UnlockedColors) then
		local inferredUnlocked = {}
		for _, colorType in pairs({ raw.HighestUnlockedWorld, raw.ActiveWorldColor, raw.CurrentWorld }) do
			if ColorData.getWorldByColor(colorType) then
				table.insert(inferredUnlocked, colorType)
			end
		end
		if #inferredUnlocked > 0 then
			data.UnlockedColors = inferredUnlocked
		end
	end
	data.UnlockedColors = normalizeUnlockedColorList(data.UnlockedColors)
	data.CurrentWorld = normalizeCurrentWorld(
		savedCurrentWorld or data.CurrentWorld or data.ActiveWorldColor or data.HighestUnlockedWorld,
		data.UnlockedColors
	)
	data.ActiveWorldColor = data.CurrentWorld
	data.UnlockedTeleports =
		normalizeTeleportList(data.UnlockedTeleports or data.UnlockedLocations or data.UnlockedZones)
	data.HighestUnlockedWorld = getHighestUnlockedColor(data.UnlockedColors)
	local rankData = RankService.NormalizeData(data)
	data.RankLevel = rankData.RankLevel
	data.RankXP = rankData.RankXP
	data.RankTotalXP = rankData.RankTotalXP
	data.OwnedPaintTools = normalizePaintToolList(data.OwnedPaintTools)
	data.EquippedPaintTool = normalizeEquippedPaintTool(data.EquippedPaintTool, data.OwnedPaintTools)
	if not hadTutorialCompletionFlag then
		local hasOldProgress = (#data.UnlockedColors > 1)
			or (#(data.OwnedPaintTools or {}) > 1)
			or (#(data.PetInventory or {}) > 0)
			or sourceHasEntries(data.Pets)
			or sourceHasEntries(data.Colors)
			or sourceHasEntries(data.Inventory)
			or sourceHasEntries(data.ColorInventory)
			or ((tonumber(data.Coins) or 0) > 0)
		if hasOldProgress then
			data.TutorialCompleted = true
		end
	end

	local backupList = {}
	local recordsByKey = {}
	mergeInventorySource(data.PetInventory, recordsByKey, backupList)
	mergeInventorySource(data.Pets, recordsByKey, backupList)
	mergeInventorySource(data.Colors, recordsByKey, backupList)
	mergeInventorySource(data.PetStacks, recordsByKey, backupList)
	mergeInventorySource(data.ColorStacks, recordsByKey, backupList)
	mergeInventorySource(data.ColorInventory, recordsByKey, backupList)
	mergeInventorySource(data.Inventory, recordsByKey, backupList)

	data.PetInventory = inventoryMapToList(recordsByKey)
	data.Pets = deepCopy(data.PetInventory)
	data.Colors = deepCopy(data.PetInventory)
	data.LockedPets = type(data.LockedPets) == "table" and data.LockedPets or {}

	data.EquippedPets = {}
	local seenEquipped = {}
	normalizeEquippedSource(raw.EquippedPets, data.EquippedPets, seenEquipped)
	normalizeEquippedSource(raw.EquippedColors, data.EquippedPets, seenEquipped)

	if #backupList > 0 then
		data.LegacyPetsBackup = data.LegacyPetsBackup or {}
		data.LegacyPetsBackup.UnreadableEntries = data.LegacyPetsBackup.UnreadableEntries or {}
		for _, entry in ipairs(backupList) do
			table.insert(data.LegacyPetsBackup.UnreadableEntries, entry)
		end
	end

	data.RedeemedCodes = type(data.RedeemedCodes) == "table" and data.RedeemedCodes or {}
	data.Settings = normalizeSettings(data.Settings)
	data.TutorialProgress = type(data.TutorialProgress) == "table" and data.TutorialProgress or {}
	data.TutorialProgress.SeenTraitsTutorial = data.TutorialProgress.SeenTraitsTutorial == true
	data.TutorialProgress.MutationsUnlocked = data.TutorialProgress.MutationsUnlocked == true
	data.TutorialProgress.HasSeenMutationTutorial = data.TutorialProgress.HasSeenMutationTutorial == true
	data.GroupRewards = type(data.GroupRewards) == "table" and data.GroupRewards or {}
	data.GamepassGrants = type(data.GamepassGrants) == "table" and data.GamepassGrants or {}
	data.InfinitePackClaims = type(data.InfinitePackClaims) == "table" and data.InfinitePackClaims or {}
	data.InfinitePackClaims.ResetKey = tostring(data.InfinitePackClaims.ResetKey or "")
	data.InfinitePackClaims.ClaimedTiers = type(data.InfinitePackClaims.ClaimedTiers) == "table"
			and data.InfinitePackClaims.ClaimedTiers
		or {}
	if data.InfinitePackClaims.ResetKey ~= infinitePackResetKey() then
		data.InfinitePackClaims.ResetKey = infinitePackResetKey()
		data.InfinitePackClaims.ClaimedTiers = {}
	end
	data.DataVersion = CURRENT_DATA_VERSION
	data.Version = CURRENT_DATA_VERSION
	return data
end

local function validateProfileData(player, data, context)
	data = type(data) == "table" and data or deepCopy(DEFAULT_DATA)

	data.Coins = math.max(0, math.floor(finiteNumber(data.Coins, 0, "Coins", player)))
	data.Gems = math.max(0, math.floor(finiteNumber(data.Gems, 0, "Gems", player)))
	data.Diamonds = math.max(0, math.floor(finiteNumber(data.Diamonds, 0, "Diamonds", player)))
	data.Rebirths = math.max(0, math.floor(finiteNumber(data.Rebirths, 0, "Rebirths", player)))

	data.UnlockedColors = normalizeUnlockedColorList(data.UnlockedColors)
	data.CurrentWorld = normalizeCurrentWorld(
		data.CurrentWorld or data.ActiveWorldColor or data.HighestUnlockedWorld,
		data.UnlockedColors
	)
	data.ActiveWorldColor = data.CurrentWorld
	data.UnlockedTeleports =
		normalizeTeleportList(data.UnlockedTeleports or data.UnlockedLocations or data.UnlockedZones)
	data.HighestUnlockedWorld = getHighestUnlockedColor(data.UnlockedColors)
	local rankData = RankService.NormalizeData(data)
	data.RankLevel = rankData.RankLevel
	data.RankXP = rankData.RankXP
	data.RankTotalXP = rankData.RankTotalXP

	local recordsByKey = {}
	local backupList = {}
	mergeInventorySource(data.PetInventory, recordsByKey, backupList)
	data.PetInventory = inventoryMapToList(recordsByKey)
	data.EquippedPets = sanitizeEquippedPetList(data.EquippedPets, data.PetInventory, player)
	data.LockedPets = type(data.LockedPets) == "table" and data.LockedPets or {}

	data.OwnedPaintTools = normalizePaintToolList(data.OwnedPaintTools)
	data.EquippedPaintTool = normalizeEquippedPaintTool(data.EquippedPaintTool, data.OwnedPaintTools)
	data.Settings = normalizeSettings(data.Settings)
	data.Upgrades = type(data.Upgrades) == "table" and data.Upgrades or {}
	for key, value in pairs(data.Upgrades) do
		data.Upgrades[key] = math.max(0, math.floor(finiteNumber(value, 0, "Upgrades." .. tostring(key), player)))
	end
	data.RedeemedCodes = type(data.RedeemedCodes) == "table" and data.RedeemedCodes or {}
	data.TutorialCompleted = true
	data.TutorialProgress = type(data.TutorialProgress) == "table" and data.TutorialProgress or {}
	data.TutorialProgress.SeenTraitsTutorial = data.TutorialProgress.SeenTraitsTutorial == true
	data.TutorialProgress.MutationsUnlocked = data.TutorialProgress.MutationsUnlocked == true
	data.TutorialProgress.HasSeenMutationTutorial = data.TutorialProgress.HasSeenMutationTutorial == true
	data.GroupRewards = type(data.GroupRewards) == "table" and data.GroupRewards or {}
	data.GroupRewards.LastDailyGemClaim = tostring(data.GroupRewards.LastDailyGemClaim or "")
	data.GamepassGrants = type(data.GamepassGrants) == "table" and data.GamepassGrants or {}
	data.InfinitePackClaims = type(data.InfinitePackClaims) == "table" and data.InfinitePackClaims or {}
	data.InfinitePackClaims.ResetKey = tostring(data.InfinitePackClaims.ResetKey or "")
	data.InfinitePackClaims.ClaimedTiers = type(data.InfinitePackClaims.ClaimedTiers) == "table"
			and data.InfinitePackClaims.ClaimedTiers
		or {}
	if data.InfinitePackClaims.ResetKey ~= infinitePackResetKey() then
		data.InfinitePackClaims.ResetKey = infinitePackResetKey()
		data.InfinitePackClaims.ClaimedTiers = {}
	end
	data.DataVersion = CURRENT_DATA_VERSION
	data.Version = CURRENT_DATA_VERSION
	data.Pets = deepCopy(data.PetInventory)
	data.Colors = deepCopy(data.PetInventory)

	if #backupList > 0 then
		data.LegacyPetsBackup = data.LegacyPetsBackup or {}
		data.LegacyPetsBackup.UnreadableEntries = data.LegacyPetsBackup.UnreadableEntries or {}
		for _, entry in ipairs(backupList) do
			table.insert(data.LegacyPetsBackup.UnreadableEntries, entry)
		end
		if player then
			warn(
				"DataManager: preserved unreadable Color entries during "
					.. tostring(context or "validation")
					.. " for "
					.. player.Name
			)
		end
	end

	return data
end

local function markPlayerDirty(player, reason)
	if player then
		playerDataDirtyEvent:Fire(player, reason)
	end
end

local function watchValueForDirty(player, valueObject, reason)
	if valueObject and valueObject:IsA("ValueBase") then
		valueObject:GetPropertyChangedSignal("Value"):Connect(function()
			markPlayerDirty(player, reason)
		end)
	end
end

local DATA_FOLDERS = {
	leaderstats = true,
	ColorStorage = true,
	Upgrades = true,
	RankData = true,
	PetData = true,
	RedeemedCodes = true,
	Settings = true,
	GroupRewards = true,
	GamepassGrants = true,
	InfinitePackClaims = true,
	TutorialObjectives = true,
}

local function clearGeneratedDataFolders(player)
	for _, child in ipairs(player:GetChildren()) do
		if DATA_FOLDERS[child.Name] then
			child:Destroy()
		end
	end
end

-- ========================
--   LOAD DATA
-- ========================
local function loadData(player)
	if RunService:IsStudio() and not ENABLE_STUDIO_DATASTORE then
		print("DataManager: using unsaved Studio test data for " .. player.Name)
		return validateProfileData(player, migrateData(deepCopy(DEFAULT_DATA)), "studio-default")
	end

	local key = "Player_" .. player.UserId
	local data
	local lastError

	-- Retry up to 3 times in case of DataStore hiccups
	for attempt = 1, 3 do
		local success, result = pcall(function()
			return GameStore:GetAsync(key)
		end)
		if success then
			data = validateProfileData(
				player,
				migrateData(result or deepCopy(DEFAULT_DATA)),
				result and "cloud-load" or "new-profile"
			)
			break
		else
			lastError = result
			warn("DataStore load failed (attempt " .. attempt .. "): " .. tostring(result))
			task.wait(2)
		end
	end

	-- Never fall back to blank/default cloud data after a load failure.
	-- Saving a default profile in this state can permanently wipe real player progress.
	if not data then
		warn(
			"DataManager: profile load failed for "
				.. player.Name
				.. "/"
				.. player.UserId
				.. "; save disabled for this session. "
				.. tostring(lastError)
		)
		return nil
	end

	return data
end

-- ========================
--   SAVE DATA
-- ========================
local function saveData(player, data)
	if not data then
		return
	end
	if RunService:IsStudio() and not ENABLE_STUDIO_DATASTORE then
		return true
	end

	local key = "Player_" .. player.UserId

	for attempt = 1, 3 do
		local success, err = pcall(function()
			GameStore:UpdateAsync(key, function(oldData)
				local merged = type(oldData) == "table" and deepCopy(oldData) or {}
				for field, value in pairs(data) do
					merged[field] = deepCopy(value)
				end
				return merged
			end)
		end)
		if success then
			return true
		else
			warn("DataStore save failed (attempt " .. attempt .. "): " .. tostring(err))
			task.wait(2)
		end
	end
	warn("All save attempts failed for " .. player.Name)
	return false
end

-- ========================
--   BUILD PLAYER INSTANCES
--   from their loaded data
-- ========================
local function applyData(player, data)
	clearGeneratedDataFolders(player)
	data.PetInventory = ensureOwnerRainbowPetList(player, data.PetInventory)
	data.Pets = deepCopy(data.PetInventory)
	data.Colors = deepCopy(data.PetInventory)

	-- Leaderstats (shows on leaderboard)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	player.ChildAdded:Connect(function(child)
		if child.Name == "leaderstats" and child ~= leaderstats then
			task.defer(function()
				if child.Parent == player then
					child:Destroy()
					warn("DataManager: removed duplicate leaderstats folder for " .. player.Name)
				end
			end)
		end
	end)

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = data.Coins
	coins.Parent = leaderstats

	local gems = Instance.new("IntValue")
	gems.Name = "Gems"
	gems.Value = data.Gems
	gems.Parent = leaderstats

	local diamonds = Instance.new("IntValue")
	diamonds.Name = "Diamonds"
	diamonds.Value = data.Diamonds
	diamonds.Parent = leaderstats

	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = data.Rebirths
	rebirths.Parent = leaderstats

	local rankData = RankService.NormalizeData(data)
	local rankFolder = Instance.new("Folder")
	rankFolder.Name = "RankData"
	rankFolder.Parent = player
	RankService.ApplyToFolder(player, rankFolder, rankData)
	for _, child in ipairs(rankFolder:GetChildren()) do
		watchValueForDirty(player, child, "rank")
	end
	rankFolder.ChildAdded:Connect(function(child)
		watchValueForDirty(player, child, "rank")
		markPlayerDirty(player, "rank")
		RankService.SyncPlayerAttributes(player)
	end)

	-- ColorStorage keeps world/unlock state for backward compatibility with existing scripts and saves.
	local storage = Instance.new("Folder")
	storage.Name = "ColorStorage"
	storage.Parent = player

	local unlockedColors = Instance.new("StringValue")
	unlockedColors.Name = "UnlockedColors"
	unlockedColors.Value = table.concat(data.UnlockedColors, ",")
	unlockedColors.Parent = storage

	-- Legacy client compatibility only. The current loop awards Coins instantly
	-- and does not use storage/selling, but older in-place HUD scripts may still
	-- wait for these values before wiring menu buttons.
	local colorHeld = Instance.new("IntValue")
	colorHeld.Name = "ColorHeld"
	colorHeld.Value = 0
	colorHeld.Parent = storage

	local maxCapacity = Instance.new("IntValue")
	maxCapacity.Name = "MaxCapacity"
	maxCapacity.Value = 1000000
	maxCapacity.Parent = storage

	local storageCapacity = Instance.new("IntValue")
	storageCapacity.Name = "StorageCapacity"
	storageCapacity.Value = maxCapacity.Value
	storageCapacity.Parent = storage

	local currentWorld = Instance.new("StringValue")
	currentWorld.Name = "CurrentWorld"
	currentWorld.Value = normalizeCurrentWorld(data.CurrentWorld, data.UnlockedColors)
	currentWorld.Parent = storage
	player:SetAttribute("ActiveWorldColor", currentWorld.Value)
	currentWorld:GetPropertyChangedSignal("Value"):Connect(function()
		currentWorld.Value = normalizeCurrentWorld(currentWorld.Value, string.split(unlockedColors.Value, ","))
		player:SetAttribute("ActiveWorldColor", currentWorld.Value)
	end)

	local unlockedTeleports = Instance.new("StringValue")
	unlockedTeleports.Name = "UnlockedTeleports"
	unlockedTeleports.Value = table.concat(normalizeTeleportList(data.UnlockedTeleports), ",")
	unlockedTeleports.Parent = storage

	watchValueForDirty(player, coins, "coins")
	watchValueForDirty(player, gems, "gems")
	watchValueForDirty(player, diamonds, "diamonds")
	watchValueForDirty(player, rebirths, "rebirths")
	watchValueForDirty(player, unlockedColors, "unlocked-colors")
	watchValueForDirty(player, currentWorld, "current-world")
	watchValueForDirty(player, unlockedTeleports, "unlocked-teleports")

	local groupRewardsFolder = Instance.new("Folder")
	groupRewardsFolder.Name = "GroupRewards"
	groupRewardsFolder.Parent = player

	local lastGroupDailyClaim = Instance.new("StringValue")
	lastGroupDailyClaim.Name = "LastDailyGemClaim"
	lastGroupDailyClaim.Value = data.GroupRewards and tostring(data.GroupRewards.LastDailyGemClaim or "") or ""
	lastGroupDailyClaim.Parent = groupRewardsFolder
	watchValueForDirty(player, lastGroupDailyClaim, "group-rewards")

	local gamepassGrantsFolder = Instance.new("Folder")
	gamepassGrantsFolder.Name = "GamepassGrants"
	gamepassGrantsFolder.Parent = player

	for passId, owns in pairs(data.GamepassGrants or {}) do
		if owns == true then
			local value = Instance.new("BoolValue")
			value.Name = tostring(passId)
			value.Value = true
			value.Parent = gamepassGrantsFolder
			watchValueForDirty(player, value, "gamepass-grants")
			player:SetAttribute("Pass_" .. tostring(passId), true)
		end
	end

	gamepassGrantsFolder.ChildAdded:Connect(function(child)
		watchValueForDirty(player, child, "gamepass-grants")
		markPlayerDirty(player, "gamepass-grants")
	end)

	local infinitePackClaimsFolder = Instance.new("Folder")
	infinitePackClaimsFolder.Name = "InfinitePackClaims"
	infinitePackClaimsFolder.Parent = player

	local infinitePackResetKey = Instance.new("StringValue")
	infinitePackResetKey.Name = "ResetKey"
	infinitePackResetKey.Value = data.InfinitePackClaims and tostring(data.InfinitePackClaims.ResetKey or "") or ""
	infinitePackResetKey.Parent = infinitePackClaimsFolder
	watchValueForDirty(player, infinitePackResetKey, "infinite-pack-claims")

	local infinitePackClaimedTiers = Instance.new("Folder")
	infinitePackClaimedTiers.Name = "ClaimedTiers"
	infinitePackClaimedTiers.Parent = infinitePackClaimsFolder
	for tierId, claimed in pairs((data.InfinitePackClaims and data.InfinitePackClaims.ClaimedTiers) or {}) do
		if claimed == true then
			local value = Instance.new("BoolValue")
			value.Name = tostring(tierId)
			value.Value = true
			value.Parent = infinitePackClaimedTiers
			watchValueForDirty(player, value, "infinite-pack-claims")
			player:SetAttribute("InfinitePackClaimed_" .. tostring(tierId), true)
		end
	end
	infinitePackClaimedTiers.ChildAdded:Connect(function(child)
		watchValueForDirty(player, child, "infinite-pack-claims")
		markPlayerDirty(player, "infinite-pack-claims")
	end)

	-- Upgrade level storage (read by UpgradeHandler)
	local upgradeFolder = Instance.new("Folder")
	upgradeFolder.Name = "Upgrades"
	upgradeFolder.Parent = player

	for levelKey, levelVal in pairs(data.Upgrades or {}) do
		if levelKey == "ColorStorage_Level" then
			continue
		end
		local v = Instance.new("IntValue")
		v.Name = levelKey
		v.Value = levelVal
		v.Parent = upgradeFolder
		watchValueForDirty(player, v, "upgrade")
	end
	upgradeFolder.ChildAdded:Connect(function(child)
		watchValueForDirty(player, child, "upgrade")
		markPlayerDirty(player, "upgrade-added")
	end)

	-- Pet data (stored as folder with values)
	local petFolder = Instance.new("Folder")
	petFolder.Name = "PetData"
	petFolder.Parent = player

	local invValue = Instance.new("StringValue")
	invValue.Name = "Inventory"
	-- Encoded as: variantKey:petId:stackAmount:traitId:shiny:personalityId:mutationId
	local invList = {}
	for _, p in ipairs(data.PetInventory or {}) do
		local encoded = encodePetRecord(p)
		if encoded then
			table.insert(invList, encoded)
		end
	end
	invValue.Value = table.concat(invList, ",")
	invValue.Parent = petFolder
	watchValueForDirty(player, invValue, "color-inventory")

	local equippedValue = Instance.new("StringValue")
	equippedValue.Name = "Equipped"
	equippedValue.Value = table.concat(data.EquippedPets, ",")
	equippedValue.Parent = petFolder
	watchValueForDirty(player, equippedValue, "equipped-colors")

	local lockedValue = Instance.new("StringValue")
	lockedValue.Name = "Locked"
	lockedValue.Value = table.concat(type(data.LockedPets) == "table" and data.LockedPets or {}, ",")
	lockedValue.Parent = petFolder
	watchValueForDirty(player, lockedValue, "locked-colors")

	local toolsFolder = player:FindFirstChild("PaintTools")
	if not toolsFolder then
		toolsFolder = Instance.new("Folder")
		toolsFolder.Name = "PaintTools"
		toolsFolder.Parent = player
	end

	local ownedPaintTools = normalizePaintToolList(data.OwnedPaintTools)
	local equippedPaintTool = normalizeEquippedPaintTool(data.EquippedPaintTool, ownedPaintTools)

	local ownedTools = toolsFolder:FindFirstChild("Owned")
	if not ownedTools then
		ownedTools = Instance.new("StringValue")
		ownedTools.Name = "Owned"
		ownedTools.Parent = toolsFolder
	end
	ownedTools.Value = table.concat(ownedPaintTools or { "StarterBrush" }, ",")
	if ownedTools.Value == "" then
		ownedTools.Value = "StarterBrush"
	end
	watchValueForDirty(player, ownedTools, "paint-tools-owned")

	local equippedTool = toolsFolder:FindFirstChild("Equipped")
	if not equippedTool then
		equippedTool = Instance.new("StringValue")
		equippedTool.Name = "Equipped"
		equippedTool.Parent = toolsFolder
	end
	equippedTool.Value = equippedPaintTool or "StarterBrush"
	if equippedTool.Value == "" then
		equippedTool.Value = "StarterBrush"
	end
	watchValueForDirty(player, equippedTool, "paint-tool-equipped")

	local settingsFolder = Instance.new("Folder")
	settingsFolder.Name = "Settings"
	settingsFolder.Parent = player
	local normalizedSettings = normalizeSettings(data.Settings)
	for key, value in pairs(normalizedSettings) do
		local setting = Instance.new("BoolValue")
		setting.Name = key
		setting.Value = value == true
		setting.Parent = settingsFolder
		watchValueForDirty(player, setting, "settings")
	end
	applySettingAttributes(player, normalizedSettings)

	local redeemedFolder = Instance.new("Folder")
	redeemedFolder.Name = "RedeemedCodes"
	redeemedFolder.Parent = player
	for code, uses in pairs(data.RedeemedCodes or {}) do
		local v = Instance.new("IntValue")
		v.Name = tostring(code)
		v.Value = tonumber(uses) or 1
		v.Parent = redeemedFolder
		watchValueForDirty(player, v, "redeemed-code")
	end
	redeemedFolder.ChildAdded:Connect(function(child)
		watchValueForDirty(player, child, "redeemed-code")
		markPlayerDirty(player, "redeemed-code-added")
	end)

	local tutorialProgress = player:FindFirstChild("TutorialProgress")
	if not tutorialProgress then
		tutorialProgress = Instance.new("Folder")
		tutorialProgress.Name = "TutorialProgress"
		tutorialProgress.Parent = player
	end
	local seenTraits = tutorialProgress:FindFirstChild("SeenTraitsTutorial")
	if not seenTraits then
		seenTraits = Instance.new("BoolValue")
		seenTraits.Name = "SeenTraitsTutorial"
		seenTraits.Parent = tutorialProgress
	end
	seenTraits.Value = data.TutorialProgress and data.TutorialProgress.SeenTraitsTutorial == true
	watchValueForDirty(player, seenTraits, "tutorial-progress")

	local mutationsUnlocked = tutorialProgress:FindFirstChild("MutationsUnlocked")
	if not mutationsUnlocked then
		mutationsUnlocked = Instance.new("BoolValue")
		mutationsUnlocked.Name = "MutationsUnlocked"
		mutationsUnlocked.Parent = tutorialProgress
	end
	mutationsUnlocked.Value = data.TutorialProgress and data.TutorialProgress.MutationsUnlocked == true
	watchValueForDirty(player, mutationsUnlocked, "tutorial-progress")

	local hasSeenMutationTutorial = tutorialProgress:FindFirstChild("HasSeenMutationTutorial")
	if not hasSeenMutationTutorial then
		hasSeenMutationTutorial = Instance.new("BoolValue")
		hasSeenMutationTutorial.Name = "HasSeenMutationTutorial"
		hasSeenMutationTutorial.Parent = tutorialProgress
	end
	hasSeenMutationTutorial.Value = data.TutorialProgress and data.TutorialProgress.HasSeenMutationTutorial == true
	watchValueForDirty(player, hasSeenMutationTutorial, "tutorial-progress")
	sendSettings(player, true, nil, "Settings loaded.")
end

-- ========================
--   COLLECT CURRENT DATA
--   from player instances (to save)
-- ========================
local function collectData(player)
	local previousData = sessionData and sessionData[player]
	local data = deepCopy(previousData or DEFAULT_DATA)

	local stats = player:FindFirstChild("leaderstats")
	if stats then
		data.Coins = stats:FindFirstChild("Coins") and stats.Coins.Value or 0
		data.Gems = stats:FindFirstChild("Gems") and stats.Gems.Value or 0
		data.Diamonds = stats:FindFirstChild("Diamonds") and stats.Diamonds.Value or 0
		data.Rebirths = stats:FindFirstChild("Rebirths") and stats.Rebirths.Value or 0
	end

	local rankFolder = player:FindFirstChild("RankData")
	if rankFolder then
		local rankLevel = rankFolder:FindFirstChild("RankLevel")
		local rankXP = rankFolder:FindFirstChild("RankXP")
		local rankTotalXP = rankFolder:FindFirstChild("RankTotalXP")
		local normalizedRank = RankService.NormalizeData({
			RankLevel = rankLevel and rankLevel:IsA("ValueBase") and rankLevel.Value or data.RankLevel,
			RankXP = rankXP and rankXP:IsA("ValueBase") and rankXP.Value or data.RankXP,
			RankTotalXP = rankTotalXP and rankTotalXP:IsA("ValueBase") and rankTotalXP.Value or data.RankTotalXP,
		})
		data.RankLevel = normalizedRank.RankLevel
		data.RankXP = normalizedRank.RankXP
		data.RankTotalXP = normalizedRank.RankTotalXP
	end

	local storage = player:FindFirstChild("ColorStorage")
	if storage then
		local upgradeFolder = player:FindFirstChild("Upgrades")
		if upgradeFolder then
			data.Upgrades = {}
			for _, child in ipairs(upgradeFolder:GetChildren()) do
				if child:IsA("IntValue") and child.Name:find("_Level") and child.Name ~= "ColorStorage_Level" then
					data.Upgrades[child.Name] = child.Value
				end
			end
		end

		local colorsVal = storage:FindFirstChild("UnlockedColors")
		if colorsVal and colorsVal.Value ~= "" then
			data.UnlockedColors = normalizeUnlockedColorList(colorsVal.Value)
		end

		local currentWorld = storage:FindFirstChild("CurrentWorld")
		data.CurrentWorld = normalizeCurrentWorld(
			currentWorld and currentWorld.Value or player:GetAttribute("ActiveWorldColor"),
			data.UnlockedColors
		)

		local teleportsVal = storage:FindFirstChild("UnlockedTeleports")
		data.UnlockedTeleports = normalizeTeleportList(teleportsVal and teleportsVal.Value or data.UnlockedTeleports)
	end

	local petFolder = player:FindFirstChild("PetData")
	local previousPetInventory = type(data.PetInventory) == "table" and deepCopy(data.PetInventory) or {}
	local snapshotInventory, snapshotEquipped, snapshotLocked = tryGetPetInventorySnapshot(player)
	local selectedPetSource = "previous"
	if petFolder then
		local invVal = petFolder:FindFirstChild("Inventory")
		local folderInventory = invVal and parsePetInventoryValue(invVal.Value) or {}

		if
			snapshotInventory and (countPetAmount(snapshotInventory) > 0 or countPetAmount(previousPetInventory) == 0)
		then
			data.PetInventory = deepCopy(snapshotInventory)
			selectedPetSource = "snapshot"
		elseif countPetAmount(folderInventory) > 0 then
			data.PetInventory = folderInventory
			selectedPetSource = "folder"
		else
			data.PetInventory = previousPetInventory
		end

		local equippedVal = petFolder:FindFirstChild("Equipped")
		if selectedPetSource == "snapshot" then
			data.EquippedPets = snapshotEquipped or {}
		elseif equippedVal and equippedVal.Value ~= "" then
			data.EquippedPets = string.split(equippedVal.Value, ",")
		end

		local lockedVal = petFolder:FindFirstChild("Locked")
		if selectedPetSource == "snapshot" then
			data.LockedPets = snapshotLocked or {}
		elseif lockedVal and lockedVal.Value ~= "" then
			data.LockedPets = string.split(lockedVal.Value, ",")
		end
	elseif
		snapshotInventory and (countPetAmount(snapshotInventory) > 0 or countPetAmount(previousPetInventory) == 0)
	then
		data.PetInventory = deepCopy(snapshotInventory)
		data.EquippedPets = snapshotEquipped or {}
		data.LockedPets = snapshotLocked or {}
	else
		data.PetInventory = previousPetInventory
	end
	data.PetInventory = ensureOwnerRainbowPetList(player, data.PetInventory)

	local toolsFolder = player:FindFirstChild("PaintTools")
	if toolsFolder then
		local ownedTools = toolsFolder:FindFirstChild("Owned")
		if ownedTools and ownedTools.Value ~= "" then
			data.OwnedPaintTools = string.split(ownedTools.Value, ",")
		end

		local equippedTool = toolsFolder:FindFirstChild("Equipped")
		if equippedTool and equippedTool.Value ~= "" then
			data.EquippedPaintTool = equippedTool.Value
		end
	end
	data.OwnedPaintTools = normalizePaintToolList(data.OwnedPaintTools)
	data.EquippedPaintTool = normalizeEquippedPaintTool(data.EquippedPaintTool, data.OwnedPaintTools)

	local settingsFolder = player:FindFirstChild("Settings")
	if settingsFolder then
		data.Settings = {}
		for key, defaultValue in pairs(SettingsData.Defaults) do
			local setting = settingsFolder:FindFirstChild(key)
			data.Settings[key] = setting and setting:IsA("BoolValue") and setting.Value or defaultValue
		end
	else
		data.Settings = normalizeSettings(previousData and previousData.Settings)
	end

	local redeemedFolder = player:FindFirstChild("RedeemedCodes")
	if redeemedFolder then
		data.RedeemedCodes = {}
		for _, child in ipairs(redeemedFolder:GetChildren()) do
			if child:IsA("IntValue") then
				data.RedeemedCodes[child.Name] = child.Value
			end
		end
	end

	data.TutorialCompleted = true
	local tutorialProgress = player:FindFirstChild("TutorialProgress")
	local seenTraits = tutorialProgress and tutorialProgress:FindFirstChild("SeenTraitsTutorial")
	local mutationsUnlocked = tutorialProgress and tutorialProgress:FindFirstChild("MutationsUnlocked")
	local hasSeenMutationTutorial = tutorialProgress and tutorialProgress:FindFirstChild("HasSeenMutationTutorial")
	data.TutorialProgress = {
		SeenTraitsTutorial = seenTraits and seenTraits.Value == true or false,
		MutationsUnlocked = mutationsUnlocked and mutationsUnlocked.Value == true or false,
		HasSeenMutationTutorial = hasSeenMutationTutorial and hasSeenMutationTutorial.Value == true or false,
	}
	local groupRewardsFolder = player:FindFirstChild("GroupRewards")
	local lastGroupDailyClaim = groupRewardsFolder and groupRewardsFolder:FindFirstChild("LastDailyGemClaim")
	data.GroupRewards = {
		LastDailyGemClaim = lastGroupDailyClaim and tostring(lastGroupDailyClaim.Value or "") or "",
	}
	local gamepassGrantsFolder = player:FindFirstChild("GamepassGrants")
	data.GamepassGrants = {}
	if gamepassGrantsFolder then
		for _, child in ipairs(gamepassGrantsFolder:GetChildren()) do
			if child:IsA("BoolValue") and child.Value == true then
				data.GamepassGrants[child.Name] = true
			end
		end
	end
	local infinitePackClaimsFolder = player:FindFirstChild("InfinitePackClaims")
	local infinitePackResetKey = infinitePackClaimsFolder and infinitePackClaimsFolder:FindFirstChild("ResetKey")
	local infinitePackClaimedTiers = infinitePackClaimsFolder
		and infinitePackClaimsFolder:FindFirstChild("ClaimedTiers")
	data.InfinitePackClaims = {
		ResetKey = infinitePackResetKey and tostring(infinitePackResetKey.Value or "") or "",
		ClaimedTiers = {},
	}
	if infinitePackClaimedTiers then
		for _, child in ipairs(infinitePackClaimedTiers:GetChildren()) do
			if child:IsA("BoolValue") and child.Value == true then
				data.InfinitePackClaims.ClaimedTiers[child.Name] = true
			end
		end
	end
	data.PetInventory = ensureOwnerRainbowPetList(player, data.PetInventory)
	data.DataVersion = CURRENT_DATA_VERSION
	data.Version = CURRENT_DATA_VERSION
	data.Pets = deepCopy(data.PetInventory)
	data.Colors = deepCopy(data.PetInventory)

	return data
end

-- ========================
--   PLAYER ADDED / REMOVING
-- ========================
sessionData = {} -- cache data per player during session
local sessionStartPetAmounts = {}
local profileLoaded = {}
local profileLoadFailed = {}
local lastSaveAt = {}
local lastCriticalSaveAt = {}
local saveInFlight = {}
local dirtyPlayers = {}
local lastDirtyReasons = {}
local criticalSaveQueued = {}

local CRITICAL_REASONS = {
	["hatch-color"] = true,
	["grant-color"] = true,
	["merge-color"] = true,
	["equip-color"] = true,
	["lock-color"] = true,
	["delete-color"] = true,
	["player-removing"] = true,
	["color-inventory"] = true,
	["paint-tool-purchased"] = true,
	["paint-tools-owned"] = true,
	["paint-tool-equipped"] = true,
	["unlocked-colors"] = true,
	["current-world"] = true,
	["tutorial-completed"] = true,
	["tutorial-progress"] = true,
	["settings"] = true,
	["group-rewards"] = true,
	["gamepass-grants"] = true,
	["rank-up"] = true,
}

local function addDestructiveIssue(issues, label, oldValue, newValue)
	table.insert(issues, label .. " " .. tostring(oldValue) .. " -> " .. tostring(newValue))
end

local function getEffectiveSaveReason(player, reason)
	if (reason == "leaving" or reason == "shutdown" or reason == "autosave") and lastDirtyReasons[player] then
		return tostring(lastDirtyReasons[player])
	end
	return tostring(reason or lastDirtyReasons[player] or "save")
end

local function checkDestructiveSave(player, previousData, newData, reason)
	if not previousData or player:GetAttribute("IntentionalProfileReset") == true then
		return true
	end

	local issues = {}
	local effectiveReason = getEffectiveSaveReason(player, reason)
	local previousPetAmount = countPetAmount(previousData.PetInventory)
	local newPetAmount = countPetAmount(newData.PetInventory)
	if previousPetAmount > 0 and newPetAmount == 0 then
		addDestructiveIssue(issues, "Color amount", previousPetAmount, newPetAmount)
	end

	local previousToolCount = countList(previousData.OwnedPaintTools)
	local newToolCount = countList(newData.OwnedPaintTools)
	if previousToolCount > 1 and newToolCount <= 1 then
		addDestructiveIssue(issues, "owned brushes", previousToolCount, newToolCount)
	end

	local previousSectorCount = countUnlockedSectors(previousData)
	local newSectorCount = countUnlockedSectors(newData)
	if previousSectorCount > 1 and newSectorCount <= 1 then
		addDestructiveIssue(issues, "unlocked sectors", previousSectorCount, newSectorCount)
	end
	if ownsUnlockedColor(previousData, "Orange") and not ownsUnlockedColor(newData, "Orange") then
		table.insert(issues, "Orange unlock would be removed")
	end

	local previousEquippedTool = tostring(previousData.EquippedPaintTool or "")
	local newEquippedTool = tostring(newData.EquippedPaintTool or "")
	if
		previousEquippedTool ~= ""
		and previousEquippedTool ~= "StarterBrush"
		and newEquippedTool == "StarterBrush"
		and ownsPaintTool(newData, previousEquippedTool)
		and effectiveReason ~= "paint-tool-equipped"
	then
		addDestructiveIssue(issues, "equipped brush", previousEquippedTool, newEquippedTool)
	end

	if #issues == 0 then
		return true
	end

	warn(
		"DATA LOSS PROTECTION: blocked save for "
			.. player.Name
			.. "/"
			.. player.UserId
			.. " reason="
			.. effectiveReason
			.. " issues=["
			.. table.concat(issues, "; ")
			.. "]"
			.. " old={"
			.. formatProfileSummary(previousData)
			.. "}"
			.. " new={"
			.. formatProfileSummary(newData)
			.. "}"
	)
	return false
end

local function savePlayerNow(player, reason, force)
	if not player then
		return false
	end

	if profileLoadFailed[player] then
		warn("DataManager: blocked save for " .. player.Name .. " because profile load failed.")
		return false
	end

	if not profileLoaded[player] then
		warn(
			"DataManager: blocked save before profile load completed for "
				.. player.Name
				.. " ("
				.. tostring(reason or "save")
				.. ")"
		)
		return false
	end

	if saveInFlight[player] then
		if not force then
			return false
		end

		local waitStartedAt = os.clock()
		while saveInFlight[player] and os.clock() - waitStartedAt < 10 do
			task.wait(0.1)
		end

		if saveInFlight[player] then
			warn(
				"DataManager: save still in flight for "
					.. player.Name
					.. "; skipped forced "
					.. tostring(reason or "save")
			)
			return false
		end
	end

	local now = os.clock()
	if not force and lastSaveAt[player] and now - lastSaveAt[player] < MIN_SAVE_INTERVAL then
		return false
	end

	saveInFlight[player] = true
	local data = validateProfileData(player, collectData(player), "pre-save")
	local previousData = sessionData[player]

	if previousData then
		data.MigrationBackups = deepCopy(previousData.MigrationBackups)
		data.LegacyPetsBackup = deepCopy(previousData.LegacyPetsBackup)
	end

	local intentionalReset = player:GetAttribute("IntentionalProfileReset") == true
	local loadedPetAmount = sessionStartPetAmounts[player] or countPetAmount(previousData and previousData.PetInventory)
	local currentPetAmount = countPetAmount(data.PetInventory)
	if loadedPetAmount > 0 and currentPetAmount == 0 and not intentionalReset then
		warn(
			"DataManager: Refusing to save suspicious empty pet inventory for player because session loaded with pets."
		)
		saveInFlight[player] = nil
		return false
	end
	if not checkDestructiveSave(player, previousData, data, reason) then
		saveInFlight[player] = nil
		return false
	end

	logProfileSummary(player, "save", data, getEffectiveSaveReason(player, reason))
	local ok = saveData(player, data)
	saveInFlight[player] = nil

	if ok then
		lastSaveAt[player] = now
		dirtyPlayers[player] = nil
		lastDirtyReasons[player] = nil
		sessionData[player] = deepCopy(data)
		sessionStartPetAmounts[player] = currentPetAmount
		if intentionalReset then
			player:SetAttribute("IntentionalProfileReset", nil)
		end
	end

	return ok
end

local function queueCriticalSave(player, reason, delaySeconds)
	if RunService:IsStudio() and not ENABLE_STUDIO_DATASTORE then
		return
	end
	if not player or criticalSaveQueued[player] then
		return
	end

	criticalSaveQueued[player] = true
	task.delay(delaySeconds or CRITICAL_SAVE_DELAY, function()
		criticalSaveQueued[player] = nil
		if not player or not player.Parent or not dirtyPlayers[player] then
			return
		end

		local now = os.clock()
		local last = lastCriticalSaveAt[player] or 0
		local remaining = CRITICAL_SAVE_COOLDOWN - (now - last)
		if remaining > 0 then
			queueCriticalSave(player, reason, remaining)
			return
		end

		if savePlayerNow(player, "critical-" .. tostring(reason or "data"), true) then
			lastCriticalSaveAt[player] = os.clock()
			print(
				"DataManager: critical save completed for " .. player.Name .. " (" .. tostring(reason or "data") .. ")"
			)
		end
	end)
end

playerDataDirtyEvent.Event:Connect(function(player, reason)
	if not player or not player:IsA("Player") then
		return
	end
	if profileLoadFailed[player] then
		warn(
			"DataManager: ignored dirty flag after load failure for " .. player.Name .. " (" .. tostring(reason) .. ")"
		)
		return
	end
	if not profileLoaded[player] then
		warn(
			"DataManager: ignored dirty flag before profile load for " .. player.Name .. " (" .. tostring(reason) .. ")"
		)
		return
	end

	dirtyPlayers[player] = reason or true
	lastDirtyReasons[player] = tostring(reason or true)
	if CRITICAL_REASONS[tostring(reason)] then
		queueCriticalSave(player, reason, CRITICAL_SAVE_DELAY)
	end
end)

local ALLOWED_TUTORIAL_PROGRESS_KEYS = {
	SeenTraitsTutorial = true,
	MutationsUnlocked = true,
	HasSeenMutationTutorial = true,
}

markTutorialProgressEvent.OnServerEvent:Connect(function(player, key)
	if not profileLoaded[player] then
		warn("DataManager: rejected tutorial progress before profile load for " .. player.Name)
		return
	end
	key = tostring(key or "")
	if not ALLOWED_TUTORIAL_PROGRESS_KEYS[key] then
		return
	end
	local folder = player:FindFirstChild("TutorialProgress")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "TutorialProgress"
		folder.Parent = player
	end
	local value = folder:FindFirstChild(key)
	if not value then
		value = Instance.new("BoolValue")
		value.Name = key
		value.Parent = folder
	end
	if value.Value ~= true then
		value.Value = true
		markPlayerDirty(player, "tutorial-progress")
	end
end)

requestSetSettingEvent.OnServerEvent:Connect(function(player, settingKey, value)
	if not profileLoaded[player] then
		sendSettings(player, false, settingKey, "Data is still loading.")
		return
	end
	settingKey = tostring(settingKey or "")
	if not SettingsData.IsAllowedKey(settingKey) then
		warn("Settings: rejected invalid key from " .. player.Name .. ": " .. settingKey)
		sendSettings(player, false, settingKey, "Invalid setting.")
		return
	end

	if type(value) ~= "boolean" then
		warn("Settings: rejected non-boolean value from " .. player.Name .. " for " .. settingKey)
		sendSettings(player, false, settingKey, "Invalid setting value.")
		return
	end

	local settingsFolder = player:FindFirstChild("Settings")
	if not settingsFolder then
		player:WaitForChild("Settings", 5)
		settingsFolder = player:FindFirstChild("Settings")
	end
	if not settingsFolder then
		sendSettings(player, false, settingKey, "Settings are still loading.")
		return
	end

	local settingValue = settingsFolder:FindFirstChild(settingKey)
	if not settingValue then
		settingValue = Instance.new("BoolValue")
		settingValue.Name = settingKey
		settingValue.Value = SettingsData.Defaults[settingKey] == true
		settingValue.Parent = settingsFolder
		watchValueForDirty(player, settingValue, "settings")
	end

	settingValue.Value = value
	player:SetAttribute("Setting" .. settingKey, value)
	local cached = sessionData[player]
	if cached then
		cached.Settings = normalizeSettings(cached.Settings)
		cached.Settings[settingKey] = value
	end
	markPlayerDirty(player, "settings")
	sendSettings(player, true, settingKey, "Saved.")
end)

local function printPetData(player)
	if not RunService:IsStudio() or not player then
		return false
	end

	local data = player.Parent and collectData(player) or sessionData[player]
	if not data then
		warn("PrintPetData: no data found for player")
		return false
	end

	print("PrintPetData for " .. player.Name)
	print("  Summary = " .. formatProfileSummary(data))
	print("  DataVersion = " .. tostring(data.DataVersion or data.Version))
	print("  Color stacks = " .. tostring(countPetStacks(data.PetInventory)))
	print("  Color amount = " .. tostring(countPetAmount(data.PetInventory)))
	print("  Equipped count = " .. tostring(type(data.EquippedPets) == "table" and #data.EquippedPets or 0))
	print("  Legacy Pets alias present = " .. tostring(type(data.Pets) == "table"))
	print("  Legacy Colors alias present = " .. tostring(type(data.Colors) == "table"))
	print("  Legacy backup present = " .. tostring(data.LegacyPetsBackup ~= nil or data.MigrationBackups ~= nil))

	for index, entry in ipairs(data.PetInventory or {}) do
		if index > 5 then
			break
		end
		print(
			"  Sample "
				.. index
				.. ": "
				.. tostring(entry.petId)
				.. " x"
				.. tostring(entry.stackAmount or entry.Amount or 1)
				.. " trait="
				.. tostring(entry.traitId or entry.TraitId or "Neutral")
				.. " mutation="
				.. tostring(entry.mutationId or entry.MutationId or "None")
		)
	end

	return true
end

if RunService:IsStudio() then
	local printPetDataFunction = ReplicatedStorage:FindFirstChild("PrintPetData")
	if not printPetDataFunction then
		printPetDataFunction = Instance.new("BindableFunction")
		printPetDataFunction.Name = "PrintPetData"
		printPetDataFunction.Parent = ReplicatedStorage
	end
	printPetDataFunction.OnInvoke = function(playerName)
		local player = playerName and Players:FindFirstChild(tostring(playerName)) or Players:GetPlayers()[1]
		return printPetData(player)
	end

	local printProfileDataFunction = ReplicatedStorage:FindFirstChild("PrintProfileData")
	if not printProfileDataFunction then
		printProfileDataFunction = Instance.new("BindableFunction")
		printProfileDataFunction.Name = "PrintProfileData"
		printProfileDataFunction.Parent = ReplicatedStorage
	end
	printProfileDataFunction.OnInvoke = function(playerName)
		local player = playerName and Players:FindFirstChild(tostring(playerName)) or Players:GetPlayers()[1]
		return printPetData(player)
	end

	local testPetMigrationFunction = ReplicatedStorage:FindFirstChild("TestPetMigration")
	if not testPetMigrationFunction then
		testPetMigrationFunction = Instance.new("BindableFunction")
		testPetMigrationFunction.Name = "TestPetMigration"
		testPetMigrationFunction.Parent = ReplicatedStorage
	end
	testPetMigrationFunction.OnInvoke = function(fakeOldData)
		local migrated = validateProfileData(
			nil,
			migrateData(type(fakeOldData) == "table" and fakeOldData or {}),
			"studio-migration-test"
		)
		print(
			"TestPetMigration: DataVersion="
				.. tostring(migrated.DataVersion)
				.. " stacks="
				.. tostring(countPetStacks(migrated.PetInventory))
				.. " amount="
				.. tostring(countPetAmount(migrated.PetInventory))
		)
		return migrated
	end
end

Players.PlayerAdded:Connect(function(player)
	profileLoaded[player] = false
	profileLoadFailed[player] = false
	player:SetAttribute("DataManagerReady", false)
	player:SetAttribute("DataManagerLoadFailed", false)
	local data = loadData(player)
	if not data then
		profileLoadFailed[player] = true
		player:SetAttribute("DataManagerLoadFailed", true)
		player:Kick("Your data did not load safely. Please rejoin.")
		return
	end
	sessionData[player] = data
	sessionStartPetAmounts[player] = countPetAmount(data.PetInventory)
	applyData(player, data)
	profileLoaded[player] = true
	player:SetAttribute("DataManagerReady", true)
	logProfileSummary(player, "load", data, "PlayerAdded")
	print("Loaded data for " .. player.Name)
end)

Players.PlayerRemoving:Connect(function(player)
	savePlayerNow(player, "leaving", true)
	sessionData[player] = nil
	lastSaveAt[player] = nil
	lastCriticalSaveAt[player] = nil
	saveInFlight[player] = nil
	dirtyPlayers[player] = nil
	lastDirtyReasons[player] = nil
	criticalSaveQueued[player] = nil
	sessionStartPetAmounts[player] = nil
	profileLoaded[player] = nil
	profileLoadFailed[player] = nil
end)

-- ========================
--   AUTO SAVE
-- ========================
task.spawn(function()
	if AUTO_SAVE_INTERVAL <= 0 then
		return
	end

	while true do
		task.wait(AUTO_SAVE_INTERVAL)
		for _, player in ipairs(Players:GetPlayers()) do
			if dirtyPlayers[player] then
				savePlayerNow(player, "autosave", false)
			end
		end
	end
end)

-- ========================
--   SAVE ON SERVER CLOSE
--   (handles crashes / shutdowns)
-- ========================
game:BindToClose(function()
	if RunService:IsStudio() and not ENABLE_STUDIO_DATASTORE then
		print("DataManager: Studio server closing; DataStore save skipped.")
		return
	end

	for _, player in ipairs(Players:GetPlayers()) do
		savePlayerNow(player, "shutdown", true)
	end
	print("Server closing — all data saved.")
end)
