-- Script in ServerScriptService named "PetHandler"
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local ColorData = require(ReplicatedStorage:WaitForChild("ColorData"))
local ColorEffectHandler = require(script.Parent:WaitForChild("ColorEffectHandler"))
local ColorMutationData = require(ReplicatedStorage:WaitForChild("ColorMutationData"))
local ColorPersonalityData = require(ReplicatedStorage:WaitForChild("ColorPersonalityData"))
local ColorTraitData = require(ReplicatedStorage:WaitForChild("ColorTraitData"))
local GameBalance = require(ReplicatedStorage:WaitForChild("GameBalance"))
local GamepassBenefits = require(script.Parent:WaitForChild("GamepassBenefits"))
local GroupRewardsService = require(script.Parent:WaitForChild("GroupRewardsService"))
local PetData = require(ReplicatedStorage:WaitForChild("PetData"))
local RankService = require(script.Parent:WaitForChild("RankService"))

-- Load PetTraits safely
local PetTraits = nil
local Modules = ReplicatedStorage:FindFirstChild("Modules")
if Modules then
	local pt = Modules:FindFirstChild("PetTraits")
	if pt then
		PetTraits = require(pt)
	end
end
if not PetTraits then
	warn("PetHandler: PetTraits module not found!")
end

local Events = ReplicatedStorage:WaitForChild("Events")
local hatchEvent = Events:WaitForChild("HatchEgg")
local equipEvent = Events:WaitForChild("EquipPet")
local lockPetEvent = Events:WaitForChild("LockPet")
local deletePetEvent = Events:WaitForChild("DeletePet")
local mergeEvent = Events:WaitForChild("MergePet")
local petAtkEvent = Events:WaitForChild("PetAttack")
local petBreakRewardEvent = Events:FindFirstChild("PetBreakReward")
if not petBreakRewardEvent then
	petBreakRewardEvent = Instance.new("RemoteEvent")
	petBreakRewardEvent.Name = "PetBreakReward"
	petBreakRewardEvent.Parent = Events
end
local petsLoadedEvent = Events:WaitForChild("PetsLoaded")
local dataDirtyEvent = Events:FindFirstChild("PlayerDataDirty")
local inventoryPetActionFunction = ServerStorage:FindFirstChild("InventoryPetAction")
if not inventoryPetActionFunction then
	inventoryPetActionFunction = Instance.new("BindableFunction")
	inventoryPetActionFunction.Name = "InventoryPetAction"
	inventoryPetActionFunction.Parent = ServerStorage
end
local petInventorySnapshotFunction = ServerStorage:FindFirstChild("PetInventorySnapshot")
if not petInventorySnapshotFunction then
	petInventorySnapshotFunction = Instance.new("BindableFunction")
	petInventorySnapshotFunction.Name = "PetInventorySnapshot"
	petInventorySnapshotFunction.Parent = ServerStorage
end
local tutorialHatchSucceededEvent = Events:FindFirstChild("TutorialHatchSucceeded")
if not tutorialHatchSucceededEvent then
	tutorialHatchSucceededEvent = Instance.new("BindableEvent")
	tutorialHatchSucceededEvent.Name = "TutorialHatchSucceeded"
	tutorialHatchSucceededEvent.Parent = Events
end
local tutorialColorEquippedEvent = Events:FindFirstChild("TutorialColorEquipped")
if not tutorialColorEquippedEvent then
	tutorialColorEquippedEvent = Instance.new("BindableEvent")
	tutorialColorEquippedEvent.Name = "TutorialColorEquipped"
	tutorialColorEquippedEvent.Parent = Events
end
local grantPetFunction = ReplicatedStorage:FindFirstChild("ServerGrantPet")
if not grantPetFunction then
	grantPetFunction = Instance.new("BindableFunction")
	grantPetFunction.Name = "ServerGrantPet"
	grantPetFunction.Parent = ReplicatedStorage
end

local MAX_EQUIPPED = 3
local DEBUG_LOGS = RunService:IsStudio()

-- inventory: { [player] = { [variantKey] = { petId, stackAmount, traitId, mutationId } } }
-- equipped:  { [player] = { variantKey, ... } }
local playerInventory = {}
local playerEquipped = {}
local playerLocked = {}
local lastMergeAt = {}
local hatchState = {}
local hatchLocks = {}
local activeHatches = {}
local unexpectedClientWarnings = {}
local getMaxSlots
local MIN_HATCH_TRANSACTION_LOCK = 5.35
local EGG_HATCH_DISTANCE_BUFFER = 6
local DEFAULT_EGG_HATCH_DISTANCE = 18
local STUDIO_DEV_PET_ID = "DevRainbowPet"
local STUDIO_DEV_PET_TRAIT = "SuperLucky"
local STUDIO_DEV_PET_STACK = 1
local OWNER_RAINBOW_PET_NAMES = {
	jackdoesrb = true,
}

local function isOwnerRainbowPlayer(player)
	if not player then
		return false
	end
	if OWNER_RAINBOW_PET_NAMES[string.lower(player.Name)] then
		return true
	end
	return game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
end

local function getOwnerRainbowVariantKey()
	return PetData.makeVariantKey(
		STUDIO_DEV_PET_ID,
		"Neutral",
		PetData.normalizeMutationId("None"),
		PetData.normalizeTraitId(STUDIO_DEV_PET_TRAIT)
	)
end

local function repairOwnerRainbowPetInMemory(player)
	if not isOwnerRainbowPlayer(player) then
		return false
	end

	local inv = playerInventory[player]
	if not inv or not PetData.Pets[STUDIO_DEV_PET_ID] then
		return false
	end

	local changed = false
	local traitId = PetData.normalizeTraitId(STUDIO_DEV_PET_TRAIT)
	local mutationId = PetData.normalizeMutationId("None")
	local variantKey = getOwnerRainbowVariantKey()
	local existing = inv[variantKey]

	if existing then
		local stackAmount = math.max(tonumber(existing.stackAmount) or 1, STUDIO_DEV_PET_STACK)
		if existing.stackAmount ~= stackAmount then
			existing.stackAmount = stackAmount
			changed = true
		end
		if existing.petId ~= STUDIO_DEV_PET_ID then
			existing.petId = STUDIO_DEV_PET_ID
			changed = true
		end
		if existing.traitId ~= traitId then
			existing.traitId = traitId
			changed = true
		end
		if existing.personalityId ~= "Neutral" then
			existing.personalityId = "Neutral"
			changed = true
		end
		if existing.mutationId ~= mutationId then
			existing.mutationId = mutationId
			changed = true
		end
		if existing.isShiny ~= false then
			existing.isShiny = false
			changed = true
		end
	else
		inv[variantKey] = {
			petId = STUDIO_DEV_PET_ID,
			stackAmount = STUDIO_DEV_PET_STACK,
			traitId = traitId,
			isShiny = false,
			personalityId = "Neutral",
			mutationId = mutationId,
		}
		changed = true
	end

	return changed
end

local function ensureOwnerRainbowEquipped(player)
	if not isOwnerRainbowPlayer(player) then
		return false
	end

	if not playerInventory[player] or not PetData.Pets[STUDIO_DEV_PET_ID] then
		return false
	end

	return repairOwnerRainbowPetInMemory(player)
end

local function reportDailyQuestProgress(player, questId, amount)
	local event = ServerStorage:FindFirstChild("DailyQuestProgress")
	if event and event:IsA("BindableEvent") then
		event:Fire(player, questId, amount)
	end
end

local function reportColorSpillCleaned(player, _part, colorType)
	reportDailyQuestProgress(player, "ColorSpillsCleaned", 1)

	if colorType == "Red" then
		reportDailyQuestProgress(player, "RedWastelandsSpillsCleaned", 1)
	end
end

local function getCharacterRoot(player)
	local character = player and player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function getEggIdFromInstance(instance)
	local current = instance
	while current and current ~= workspace do
		local eggId = current:GetAttribute("EggId")
		if eggId then
			return tostring(eggId)
		end
		current = current.Parent
	end
	return nil
end

local function isRuntimeEggPart(part, eggId)
	if not part or not part:IsA("BasePart") then
		return false
	end
	if part:FindFirstAncestor("PetAppearanceStudio") then
		return false
	end
	return getEggIdFromInstance(part) == eggId
end

local function getEggPromptDistance(part)
	local prompt = part:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		return math.max(
			DEFAULT_EGG_HATCH_DISTANCE,
			tonumber(prompt.MaxActivationDistance) or DEFAULT_EGG_HATCH_DISTANCE
		)
	end
	return DEFAULT_EGG_HATCH_DISTANCE
end

local function isPlayerNearEgg(player, eggId)
	local root = getCharacterRoot(player)
	if not root then
		return false
	end

	local closestDistance = math.huge
	local closestAllowedDistance = DEFAULT_EGG_HATCH_DISTANCE + EGG_HATCH_DISTANCE_BUFFER
	for _, obj in ipairs(workspace:GetDescendants()) do
		if isRuntimeEggPart(obj, eggId) then
			local distance = (root.Position - obj.Position).Magnitude
			local allowedDistance = getEggPromptDistance(obj) + EGG_HATCH_DISTANCE_BUFFER
			if distance < closestDistance then
				closestDistance = distance
				closestAllowedDistance = allowedDistance
			end
			if distance <= allowedDistance then
				return true
			end
		end
	end

	if DEBUG_LOGS then
		warn(
			"PetHandler: blocked hatch for "
				.. player.Name
				.. "; egg distance="
				.. (closestDistance < math.huge and string.format("%.1f", closestDistance) or "missing")
				.. " allowed="
				.. string.format("%.1f", closestAllowedDistance)
		)
	end
	return false
end

local function warnUnexpectedClientValuesOnce(player, action)
	local key = tostring(player and player.UserId or "server") .. ":" .. tostring(action)
	if unexpectedClientWarnings[key] then
		return
	end
	unexpectedClientWarnings[key] = true
	warn(action .. " ignored unexpected client value fields. Server calculates costs and rewards.")
end

local TRAIT_RANK = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	Legendary = 5,
}

local function isEggUnlocked(player, egg)
	local areaColor = egg.areaColor
	if not areaColor or areaColor == "Red" then
		return true
	end

	local storage = player:FindFirstChild("ColorStorage")
	local unlockedColors = storage and storage:FindFirstChild("UnlockedColors")
	if not unlockedColors then
		return false
	end

	return ColorData.isColorUnlocked(unlockedColors.Value, areaColor)
end

local function isBetterTrait(newTrait, oldTrait)
	if not newTrait then
		return false
	end
	if not oldTrait then
		return true
	end

	local newRank = TRAIT_RANK[newTrait.rarity] or 0
	local oldRank = TRAIT_RANK[oldTrait.rarity] or 0
	if newRank ~= oldRank then
		return newRank > oldRank
	end

	return (newTrait.weight or 999) < (oldTrait.weight or 999)
end

local function getVisualColor(colorType)
	if colorType == "Rainbow" then
		return Color3.fromRGB(215, 180, 255)
	end

	local colorInfo = ColorData.Colors[colorType]
	return colorInfo and colorInfo.color or Color3.new(1, 1, 1)
end

local function getBaseBreakableReward(part, data)
	local reward = tonumber(part:GetAttribute("BaseColorReward"))
		or tonumber(data.baseReward)
		or tonumber(data.rewardMin)
		or 1
	return math.max(1, math.floor(reward))
end

local function getZoneCoinMultiplier(colorType)
	local configured = GameBalance.Sell
		and GameBalance.Sell.ColorValueMultipliers
		and GameBalance.Sell.ColorValueMultipliers[colorType]
	local world = ColorData.getWorldByColor(colorType)
	return tonumber(configured or (world and world.colorValueMultiplier)) or 1
end

local function getInstantCoinMultiplier(player, colorType, petStats)
	local multiplier = getZoneCoinMultiplier(colorType)
	multiplier *= petStats and petStats.coinMult or 1

	local boostFolder = player:FindFirstChild("Boosts")
	local coinBoost = boostFolder and boostFolder:FindFirstChild("coins")
	if coinBoost and os.time() < coinBoost.Value then
		multiplier *= 2
	end

	multiplier *= GamepassBenefits.getCoinMultiplier(player)
	multiplier *= GroupRewardsService.GetCoinMultiplier(player)
	return multiplier
end

local function awardCoins(player, amount)
	amount = math.max(0, math.floor(tonumber(amount) or 0))
	if amount <= 0 then
		return false
	end

	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	if not coins then
		return false
	end

	coins.Value += amount
	RankService.AwardFromCoins(player, amount, "rank-pet-coins")
	reportDailyQuestProgress(player, "CoinsEarned", amount)
	return true
end

local function getStoredColor(part, colorType)
	local stored = part and part:GetAttribute("SpawnColor")
	if typeof(stored) == "Color3" then
		return stored
	end
	return getVisualColor(colorType)
end

function getMaxSlots(player)
	local pf = player:FindFirstChild("PetData")
	local baseSlots = 3
	if pf then
		local v = pf:FindFirstChild("MaxSlots")
		if v then
			baseSlots = v.Value
		end
	end
	return baseSlots + GamepassBenefits.getExtraEquippedColorSlots(player)
end

local DEFAULT_COLOR_INVENTORY_CAPACITY = 75

local function getColorInventoryCapacity(player)
	if GamepassBenefits.hasInfiniteStorage(player) then
		return math.huge
	end

	local petDataFolder = player:FindFirstChild("PetData")
	local value = petDataFolder
		and (petDataFolder:FindFirstChild("MaxInventory") or petDataFolder:FindFirstChild("MaxStorage"))
	if value and value:IsA("ValueBase") then
		local capacity = math.floor(tonumber(value.Value) or 0)
		if capacity > 0 then
			return capacity
		end
	end

	return DEFAULT_COLOR_INVENTORY_CAPACITY
end

local function countColorInventory(inventory)
	local total = 0
	for _, data in pairs(inventory or {}) do
		total += math.max(1, math.floor(tonumber(data and data.stackAmount) or 1))
	end
	return total
end

local function canAddColorsToInventory(player, inventory, amount)
	local capacity = getColorInventoryCapacity(player)
	if capacity == math.huge then
		return true, capacity, countColorInventory(inventory)
	end

	local currentCount = countColorInventory(inventory)
	amount = math.max(1, math.floor(tonumber(amount) or 1))
	return currentCount + amount <= capacity, capacity, currentCount
end

local function getDataDirtyEvent()
	if not dataDirtyEvent or not dataDirtyEvent.Parent then
		dataDirtyEvent = Events:FindFirstChild("PlayerDataDirty")
	end
	return dataDirtyEvent
end

local function markDataDirty(player, reason)
	local event = getDataDirtyEvent()
	if event and event:IsA("BindableEvent") then
		event:Fire(player, reason or "colors-changed")
	end
end

local function resolveActivePetId(petId)
	petId = tostring(petId or "")
	if PetData.Pets[petId] then
		return petId
	end

	local variantPetId = PetData.splitVariantKey(petId)
	if variantPetId and PetData.Pets[variantPetId] then
		return variantPetId
	end

	local aliases = PetData.LegacyPetIdAliases or {}
	local alias = aliases[petId]
	if alias and PetData.Pets[alias] then
		return alias
	end

	local compact = string.gsub(petId, "%s+", "")
	alias = aliases[compact]
	if alias and PetData.Pets[alias] then
		return alias
	end

	return nil
end

local function isActivePetRecord(data)
	return type(data) == "table" and resolveActivePetId(data.petId) ~= nil
end

local function normalizeInventoryData(variantKey, data)
	if not data or not data.petId then
		return nil
	end

	local variantPetId, variantTraitId, variantMutationId = PetData.splitVariantKey(variantKey)
	if not variantPetId then
		variantPetId, variantTraitId, variantMutationId = PetData.splitVariantKey(data.petId)
	end
	if variantPetId then
		data.petId = variantPetId
		data.traitId = data.traitId or variantTraitId
		data.mutationId = data.mutationId or variantMutationId
	end

	local resolvedPetId = resolveActivePetId(data.petId)
	if not resolvedPetId then
		warn("PetHandler: ignored unknown saved ColorId in active inventory: " .. tostring(data.petId))
		return nil
	end

	data.petId = resolvedPetId
	data.personalityId = PetData.normalizePersonalityId(data.personalityId)
	data.mutationId = PetData.normalizeMutationId(data.mutationId)
	data.traitId = PetData.normalizeTraitId(data.traitId)
	data.stackAmount = math.max(1, tonumber(data.stackAmount) or 1)

	local expectedKey = PetData.makeVariantKey(data.petId, data.personalityId, data.mutationId, data.traitId)
	if not variantKey or variantKey == "" or variantKey ~= expectedKey then
		variantKey = expectedKey
	end

	return variantKey, data
end

local function buildEntry(variantKey, data)
	if not data then
		return nil
	end

	local resolvedPetId = resolveActivePetId(data.petId)
	if not resolvedPetId then
		warn("PetHandler: skipped unknown ColorId while building active Color entry: " .. tostring(data.petId))
		return nil
	end
	data.petId = resolvedPetId

	local entry = PetData.buildPetEntry(
		data.petId,
		data.stackAmount,
		data.isShiny,
		data.personalityId,
		data.mutationId,
		data.traitId
	)
	if entry then
		entry.variantKey = variantKey or entry.variantKey
		local trait = ColorTraitData.get(data.traitId)
		entry.trait = {
			name = trait.DisplayName,
			description = trait.Description,
			color = trait.TextColor,
			icon = trait.Icon or "",
			rarity = trait.Id == "Neutral" and "Common" or "Uncommon",
			visualEffect = "none",
		}
		entry.effectivePower = entry.finalPower
	end
	return entry
end

local function parseLockedValue(value)
	local locked = {}
	for _, key in ipairs(string.split(value or "", ",")) do
		if key ~= "" then
			locked[key] = true
		end
	end
	return locked
end

local function lockedToCsv(player)
	local locked = playerLocked[player]
	local inventory = playerInventory[player]
	if not locked or not inventory then
		return ""
	end

	local keys = {}
	for key in pairs(locked) do
		if inventory[key] then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	return table.concat(keys, ",")
end

local function getLockedList(player)
	local lockedCsv = lockedToCsv(player)
	if lockedCsv == "" then
		return {}
	end
	return string.split(lockedCsv, ",")
end

local sanitizeEquippedList

local function getPetInventorySnapshot(player)
	if not playerInventory[player] or not playerEquipped[player] then
		return nil
	end

	ensureOwnerRainbowEquipped(player)
	sanitizeEquippedList(player)

	local records = {}
	for variantKey, data in pairs(playerInventory[player]) do
		local normalizedKey, normalizedData = normalizeInventoryData(variantKey, {
			petId = data.petId,
			stackAmount = data.stackAmount,
			traitId = data.traitId,
			isShiny = data.isShiny == true,
			personalityId = data.personalityId,
			mutationId = data.mutationId,
		})
		if normalizedKey and normalizedData then
			normalizedData.variantKey = normalizedKey
			table.insert(records, normalizedData)
		end
	end

	return records, table.clone(playerEquipped[player] or {}), getLockedList(player)
end

petInventorySnapshotFunction.OnInvoke = getPetInventorySnapshot

local function isEquippedKey(equipped, key)
	for _, equippedKey in ipairs(equipped or {}) do
		if equippedKey == key then
			return true
		end
	end
	return false
end

local function getEquippedPersonalityStats(player)
	local result = {
		colorGainMult = 1,
		sellMult = 1,
		pickupRangeMult = 1,
		walkSpeedBonus = 0,
		luckBonus = 0,
		totalPowerMult = 1,
	}
	-- Legacy personalities are no longer player-facing gameplay effects. Real effects come from
	-- ColorTraitData and ColorMutationData through ColorEffectHandler.
	return result
end

local function getPlayerLuckMultiplier(player)
	local luckMult = 1.0
	local boostFolder = player:FindFirstChild("Boosts")
	if boostFolder then
		local luckVal = boostFolder:FindFirstChild("luck")
		if luckVal and os.time() < luckVal.Value then
			luckMult = 1.5
		end
	end

	luckMult += ColorEffectHandler.GetHatchLuckBonus(player)
	if ColorEffectHandler.GetHatchLuckMultiplier then
		luckMult *= ColorEffectHandler.GetHatchLuckMultiplier(player)
	end
	local upgrades = player:FindFirstChild("Upgrades")
	local luckUpgrade = upgrades and (upgrades:FindFirstChild("Luck") or upgrades:FindFirstChild("HatchLuckMultiplier"))
	if luckUpgrade then
		luckMult *= math.max(tonumber(luckUpgrade.Value) or 1, 1)
	end
	luckMult *= GamepassBenefits.getLuckMultiplier(player)
	luckMult *= GroupRewardsService.GetLuckMultiplier(player)
	local maxLuckMult = 2.5
	if RunService:IsStudio() then
		local testing = GameBalance.Testing or {}
		luckMult *= tonumber(testing.StudioHatchLuckMultiplier) or 1
		maxLuckMult = tonumber(testing.MaxStudioHatchLuckMultiplier) or maxLuckMult
	end
	return math.clamp(luckMult, 1, maxLuckMult)
end

local function resolveInventoryKey(inventory, key)
	if not inventory or not key then
		return nil
	end

	local normalizedKey = tostring(key)
	if inventory[normalizedKey] and isActivePetRecord(inventory[normalizedKey]) then
		return normalizedKey
	end
	local legacyParts = string.split(normalizedKey, "|")

	for variantKey, data in pairs(inventory) do
		if not isActivePetRecord(data) then
			continue
		end

		if variantKey == normalizedKey or data.petId == normalizedKey then
			return variantKey
		end

		local expectedKey = PetData.makeVariantKey(data.petId, data.personalityId, data.mutationId, data.traitId)
		if expectedKey == normalizedKey then
			return variantKey
		end

		if #legacyParts >= 3 and legacyParts[1] == data.petId then
			local legacyTraitId = PetData.normalizeTraitId(legacyParts[2])
			local legacyMutationId = PetData.normalizeMutationId(legacyParts[3])
			local mutationMatches = legacyMutationId == PetData.normalizeMutationId(data.mutationId)
			local traitMatches = legacyTraitId == PetData.normalizeTraitId(data.traitId)
				or (legacyTraitId == "Neutral" and PetData.normalizeTraitId(data.traitId) == "Neutral")
			if mutationMatches and traitMatches then
				return variantKey
			end
		end
	end

	return nil
end

function sanitizeEquippedList(player)
	local equipped = playerEquipped[player]
	local inventory = playerInventory[player]
	if not equipped or not inventory then
		return
	end

	local seen = {}
	local writeIndex = 1
	for _, key in ipairs(equipped) do
		local resolvedKey = resolveInventoryKey(inventory, key)
		if resolvedKey and inventory[resolvedKey] and not seen[resolvedKey] then
			equipped[writeIndex] = resolvedKey
			seen[resolvedKey] = true
			writeIndex += 1
		elseif key and key ~= "" then
			warn("PetHandler: removed invalid equipped Color key for " .. player.Name .. ": " .. tostring(key))
		end
	end

	for index = #equipped, writeIndex, -1 do
		table.remove(equipped, index)
	end
end

local function applyWalkSpeedBonus(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	ColorEffectHandler.ApplyCharacterEffects(player)
end

-- ========================
--   SYNC TO PETDATA FOLDER
-- ========================
local function syncPetFolder(player, dirtyReason)
	local petFolder = player:FindFirstChild("PetData")
	if not petFolder then
		return
	end
	if not playerInventory[player] or not playerEquipped[player] then
		return
	end
	repairOwnerRainbowPetInMemory(player)
	sanitizeEquippedList(player)

	local invVal = petFolder:FindFirstChild("Inventory")
	local equippedVal = petFolder:FindFirstChild("Equipped")
	local lockedVal = petFolder:FindFirstChild("Locked")

	if invVal then
		local parts = {}
		for variantKey, data in pairs(playerInventory[player]) do
			if not isActivePetRecord(data) then
				warn("PetHandler: kept unknown ColorId out of PetData sync: " .. tostring(data and data.petId))
				continue
			end

			-- Format: "variantKey:petId:stackAmount:traitId:shiny:personalityId:mutationId"
			local traitStr = PetData.normalizeTraitId(data.traitId)
			local shinyStr = data.isShiny and "shiny" or "normal"
			table.insert(
				parts,
				tostring(variantKey)
					.. ":"
					.. data.petId
					.. ":"
					.. data.stackAmount
					.. ":"
					.. traitStr
					.. ":"
					.. shinyStr
					.. ":"
					.. (data.personalityId or "Neutral")
					.. ":"
					.. (data.mutationId or "None")
			)
		end
		local serializedInventory = table.concat(parts, ",")
		if serializedInventory == "" and invVal.Value ~= "" and dirtyReason ~= "delete-color" then
			warn(
				"PetHandler: blocked empty PetData inventory sync for "
					.. player.Name
					.. " ("
					.. tostring(dirtyReason)
					.. ")"
			)
		else
			invVal.Value = serializedInventory
		end
	end

	if equippedVal then
		equippedVal.Value = table.concat(playerEquipped[player], ",")
	end

	if not lockedVal then
		lockedVal = Instance.new("StringValue")
		lockedVal.Name = "Locked"
		lockedVal.Parent = petFolder
	end
	lockedVal.Value = lockedToCsv(player)

	applyWalkSpeedBonus(player)
	markDataDirty(player, dirtyReason)
end

-- ========================
--   SEND STATE TO CLIENT
-- ========================
local function sendState(player)
	if not playerInventory[player] or not playerEquipped[player] then
		return
	end

	ensureOwnerRainbowEquipped(player)
	local invList = {}
	for variantKey, data in pairs(playerInventory[player]) do
		local entry = buildEntry(variantKey, data)
		if entry then
			entry.isLocked = playerLocked[player] and playerLocked[player][variantKey] == true
			table.insert(invList, entry)
		end
	end
	sanitizeEquippedList(player)
	local equippedCopy = table.clone(playerEquipped[player] or {})
	petsLoadedEvent:FireClient(player, invList, equippedCopy)
end

local function grantPetToPlayer(player, petId, amount, traitId, isShiny, autoEquip, personalityId, mutationId)
	local inv = playerInventory[player]
	local equipped = playerEquipped[player]
	if not inv or not equipped or not PetData.Pets[petId] then
		return false, nil
	end

	personalityId = PetData.normalizePersonalityId(personalityId)
	mutationId = PetData.normalizeMutationId(mutationId)
	traitId = PetData.normalizeTraitId(traitId)
	local variantKey = PetData.makeVariantKey(petId, personalityId, mutationId, traitId)

	amount = math.max(1, math.floor(tonumber(amount) or 1))
	if inv[variantKey] then
		inv[variantKey].stackAmount += amount
		if isShiny then
			inv[variantKey].isShiny = true
		end
	else
		inv[variantKey] = {
			petId = petId,
			stackAmount = amount,
			traitId = traitId,
			isShiny = isShiny == true,
			personalityId = personalityId,
			mutationId = mutationId,
		}
		if autoEquip and #equipped < getMaxSlots(player) then
			table.insert(equipped, variantKey)
		end
	end

	local data = inv[variantKey]
	local entry = buildEntry(variantKey, data)

	syncPetFolder(player, "grant-color")
	sendState(player)
	return true, entry
end

local function shouldAlwaysOwnRainbowPet(player)
	return isOwnerRainbowPlayer(player)
end

local function ensureOwnerRainbowPet(player)
	if not shouldAlwaysOwnRainbowPet(player) then
		return
	end

	local inv = playerInventory[player]
	local equipped = playerEquipped[player]
	if not inv or not equipped or not PetData.Pets[STUDIO_DEV_PET_ID] then
		return
	end

	local changed = ensureOwnerRainbowEquipped(player)
	if not changed then
		return
	end
	syncPetFolder(player, "grant-color")
	sendState(player)
	print("Owner entitlement: added Rainbow Pet to " .. player.Name .. "'s inventory")
end

-- ========================
--   PARSE SAVED INVENTORY
-- ========================
local function parseInventory(str)
	local inv = {}
	if not str or str == "" then
		return inv
	end
	for _, part in ipairs(string.split(str, ",")) do
		local segments = string.split(part, ":")
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

		local amt = tonumber(segments[stackIndex]) or 1
		local traitId = PetData.normalizeTraitId(segments[stackIndex + 1])
		local shinyStr = segments[stackIndex + 2] or "normal"
		local personalityId = PetData.normalizePersonalityId(segments[stackIndex + 3] or "Neutral")
		local mutationId = PetData.normalizeMutationId(segments[stackIndex + 4] or "None")
		if not petId or petId == "" then
			continue
		end
		variantKey = variantKey or PetData.makeVariantKey(petId, personalityId, mutationId, traitId)

		local normalizedKey, normalizedData = normalizeInventoryData(variantKey, {
			petId = petId,
			stackAmount = math.max(1, amt),
			traitId = traitId,
			isShiny = shinyStr == "shiny" or shinyStr == "true",
			personalityId = personalityId,
			mutationId = mutationId,
		})
		if normalizedKey and normalizedData then
			inv[normalizedKey] = normalizedData
		end
	end
	return inv
end

-- ========================
--   PLAYER SETUP
-- ========================
Players.PlayerAdded:Connect(function(player)
	playerInventory[player] = {}
	playerEquipped[player] = {}
	playerLocked[player] = {}

	if player:GetAttribute("DataManagerReady") ~= true then
		player:GetAttributeChangedSignal("DataManagerReady"):Wait()
	end
	if player:GetAttribute("DataManagerReady") ~= true then
		return
	end

	local petFolder = player:WaitForChild("PetData", 10)
	if not petFolder then
		return
	end

	local invVal = petFolder:WaitForChild("Inventory", 5)
	local equippedVal = petFolder:WaitForChild("Equipped", 5)
	local lockedVal = petFolder:FindFirstChild("Locked")
	if not lockedVal then
		lockedVal = Instance.new("StringValue")
		lockedVal.Name = "Locked"
		lockedVal.Parent = petFolder
	end

	if invVal and invVal.Value ~= "" then
		playerInventory[player] = parseInventory(invVal.Value)
	end
	if lockedVal and lockedVal.Value ~= "" then
		playerLocked[player] = parseLockedValue(lockedVal.Value)
	end

	if equippedVal and equippedVal.Value ~= "" then
		local seen = {}
		local maxSlots = getMaxSlots(player)
		for _, savedKey in ipairs(string.split(equippedVal.Value, ",")) do
			local key = resolveInventoryKey(playerInventory[player], savedKey) or savedKey
			if key ~= "" and not playerInventory[player][key] then
				local legacyParts = string.split(savedKey, "|")
				if #legacyParts >= 3 then
					key = PetData.makeVariantKey(legacyParts[1], "Neutral", legacyParts[3], "Neutral")
				else
					key = PetData.makeVariantKey(savedKey, "Neutral", "None", "Neutral")
				end
			end
			if key ~= "" and playerInventory[player][key] and not seen[key] and #playerEquipped[player] < maxSlots then
				seen[key] = true
				table.insert(playerEquipped[player], key)
			end
		end
	end

	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		applyWalkSpeedBonus(player)
	end)
	if player.Character then
		applyWalkSpeedBonus(player)
	end
	local upgrades = player:FindFirstChild("Upgrades")
	local walkSpeedValue = upgrades and upgrades:FindFirstChild("WalkSpeed")
	if walkSpeedValue then
		walkSpeedValue:GetPropertyChangedSignal("Value"):Connect(function()
			applyWalkSpeedBonus(player)
		end)
	end
	ensureOwnerRainbowPet(player)
	task.wait(1)
	ensureOwnerRainbowPet(player)
	sendState(player)
end)

Players.PlayerRemoving:Connect(function(player)
	syncPetFolder(player, "player-removing")
	task.delay(20, function()
		if player.Parent ~= nil then
			return
		end

		playerInventory[player] = nil
		playerEquipped[player] = nil
		playerLocked[player] = nil
		lastMergeAt[player] = nil
		hatchState[player] = nil
		hatchLocks[player] = nil
		activeHatches[player] = nil
	end)
end)

task.spawn(function()
	while true do
		task.wait(10)
		for _, player in ipairs(Players:GetPlayers()) do
			ensureOwnerRainbowPet(player)
		end
	end
end)

-- ========================
--   HATCH EGG
-- ========================
local function getHatchCooldown(player)
	local cooldown = tonumber(GameBalance.HatchCooldown) or 2.5
	local upgrades = player:FindFirstChild("Upgrades")
	local hatchSpeed = upgrades and upgrades:FindFirstChild("HatchSpeed")
	if hatchSpeed and typeof(hatchSpeed.Value) == "number" then
		cooldown *= math.clamp(hatchSpeed.Value, 0.1, 1)
	end
	return math.max(tonumber(GameBalance.FastHatchCooldown) or 1.25, cooldown)
end

local function rejectHatch(player, message)
	hatchEvent:FireClient(player, false, nil, message)
end

local function logHatch(player, eggId, ...)
	print("[HATCH]", player and player.Name or "UnknownPlayer", tostring(eggId), ...)
end

local function releaseActiveHatch(player, expectedToken)
	if expectedToken ~= nil and activeHatches[player] ~= expectedToken then
		return
	end
	activeHatches[player] = nil
	if player and player.Parent then
		player:SetAttribute("IsHatching", false)
	end
end

local function clearHatchStateLater(player, state, delaySeconds)
	task.delay(delaySeconds, function()
		if hatchState[player] == state then
			hatchState[player] = nil
		end
	end)
end

local function isTutorialFirstHatch(player, eggId)
	return false
end

local function getEggWorldIndex(egg)
	return ColorData.getWorldIndex(egg and egg.areaColor) or 1
end

local function getHighestUnlockedWorldIndex(player)
	local storage = player:FindFirstChild("ColorStorage")
	local unlockedValue = storage and storage:FindFirstChild("UnlockedColors")
	local unlocked = ColorData.getUnlockedColorSet(unlockedValue and unlockedValue.Value or "Red")
	local highest = 1
	for index, world in ipairs(ColorData.Worlds or {}) do
		if unlocked[world.primaryColor] then
			highest = index
		end
	end
	return highest
end

local function isFeatureUnlocked(player, featureName)
	local requiredIndex = GameBalance.getFeatureUnlockWorldIndex and GameBalance.getFeatureUnlockWorldIndex(featureName)
		or 1
	return getHighestUnlockedWorldIndex(player) >= requiredIndex
end

local function getFeatureLockedMessage(featureName)
	return GameBalance.getFeatureUnlockText and GameBalance.getFeatureUnlockText(featureName)
		or ("Unlock " .. tostring(featureName) .. " later.")
end

local function traitsUnlockedForEgg(egg)
	return getEggWorldIndex(egg) >= (tonumber(GameBalance.TraitsUnlockWorldIndex) or 2)
end

local function hasUnlockedMutations(player)
	if RunService:IsStudio() and player and player:GetAttribute("ForceMutationsUnlocked") == true then
		return true
	end
	if player and player:GetAttribute("MutationsUnlocked") == true then
		return true
	end

	local progress = player and player:FindFirstChild("TutorialProgress")
	local unlocked = progress and progress:FindFirstChild("MutationsUnlocked")
	return unlocked and unlocked:IsA("BoolValue") and unlocked.Value == true
end

local function mutationsUnlockedForEgg(player, egg)
	return hasUnlockedMutations(player)
end

hatchEvent.OnServerEvent:Connect(function(player, eggId, ...)
	eggId = tostring(eggId or "")

	if activeHatches[player] then
		logHatch(player, eggId, "reject:", "Already hatching")
		rejectHatch(player, "Already hatching")
		return
	end
	local hatchToken = {}
	activeHatches[player] = hatchToken
	player:SetAttribute("IsHatching", true)

	if select("#", ...) > 0 then
		warnUnexpectedClientValuesOnce(player, "HatchEgg")
	end

	local egg = PetData.Eggs[eggId]
	if not egg then
		logHatch(player, eggId, "reject:", "Unknown egg.")
		releaseActiveHatch(player, hatchToken)
		rejectHatch(player, "Unknown egg.")
		return
	end

	local now = os.clock()
	local cooldown = getHatchCooldown(player)
	local lockSeconds = math.max(cooldown, MIN_HATCH_TRANSACTION_LOCK)
	if now < (hatchLocks[player] or 0) then
		logHatch(player, eggId, "reject:", "Already hatching")
		releaseActiveHatch(player, hatchToken)
		rejectHatch(player, "Already hatching")
		return
	end
	hatchLocks[player] = now + lockSeconds

	local function failHatch(message, retryDelay)
		hatchState[player] = nil
		hatchLocks[player] = os.clock() + (retryDelay or 0.65)
		logHatch(player, eggId, "reject:", message)
		releaseActiveHatch(player, hatchToken)
		rejectHatch(player, message)
	end

	local state = hatchState[player]
	if state and (state.active or now < (state.nextAllowedAt or 0)) then
		-- One key press can arrive as both keyboard input and a ProximityPrompt trigger.
		-- Ignore duplicates so a stale failure response cannot cancel the real hatch UI.
		logHatch(player, eggId, "reject:", "Already hatching")
		releaseActiveHatch(player, hatchToken)
		rejectHatch(player, "Already hatching")
		return
	end

	if not isEggUnlocked(player, egg) then
		failHatch("Unlock " .. tostring(egg.areaColor) .. " first!")
		return
	end

	if not isPlayerNearEgg(player, eggId) then
		failHatch("Move closer to the egg.")
		return
	end

	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		failHatch("Player stats are still loading.")
		return
	end
	local coins = stats:FindFirstChild("Coins")
	local cost = math.max(0, math.floor(tonumber(egg.cost) or 0))
	local tutorialFreeHatch = isTutorialFirstHatch(player, eggId)
	if tutorialFreeHatch then
		cost = 0
	end
	local coinsBefore = coins and coins.Value or 0
	logHatch(player, eggId, "cost:", cost, "coins before:", coinsBefore)
	if not coins or coins.Value < cost then
		failHatch("Not enough coins!")
		return
	end

	local inv = playerInventory[player]
	local equipped = playerEquipped[player]
	if not inv or not equipped then
		failHatch("Color inventory is still loading.")
		warn("PetHandler: blocked hatch before inventory was ready for " .. player.Name)
		return
	end
	local hasInventoryRoom, inventoryCapacity, inventoryCount = canAddColorsToInventory(player, inv, 1)
	if not hasInventoryRoom then
		failHatch("Inventory full")
		warn(
			"PetHandler: blocked hatch for "
				.. player.Name
				.. " because inventory is full ("
				.. tostring(inventoryCount)
				.. "/"
				.. tostring(inventoryCapacity)
				.. ")."
		)
		return
	end

	state = {
		active = true,
		eggId = eggId,
		charged = false,
		startedAt = now,
		nextAllowedAt = now + lockSeconds,
	}
	hatchState[player] = state

	local luckMult = getPlayerLuckMultiplier(player)
	local petId = PetData.rollEgg(eggId, luckMult)
	if not petId or not PetData.Pets[petId] then
		hatchState[player] = nil
		failHatch("Egg roll failed. Try again.", 1.5)
		warn("PetHandler: egg " .. tostring(eggId) .. " rolled missing Color " .. tostring(petId))
		return
	end

	local canRollTraits = traitsUnlockedForEgg(egg)
	local canRollMutations = mutationsUnlockedForEgg(player, egg)
	local trait = canRollTraits and ColorTraitData.roll() or ColorTraitData.get("Neutral")
	local forcedMutationId = RunService:IsStudio() and player:GetAttribute("ForceNextMutation") or nil
	if forcedMutationId then
		player:SetAttribute("ForceNextMutation", nil)
	end
	local mutation = canRollMutations and ColorMutationData.roll(luckMult) or ColorMutationData.get("None")
	if canRollMutations and forcedMutationId then
		local normalizedMutationId = ColorMutationData.normalize(forcedMutationId)
		if normalizedMutationId ~= ColorMutationData.NoneId then
			mutation = ColorMutationData.get(normalizedMutationId)
		end
	end
	local traitId = trait and trait.Id or "Neutral"
	local personalityId = "Neutral"
	local mutationId = mutation and mutation.Id or "None"
	local variantKey = PetData.makeVariantKey(petId, personalityId, mutationId, traitId)
	hasInventoryRoom, inventoryCapacity, inventoryCount = canAddColorsToInventory(player, inv, 1)
	if not hasInventoryRoom then
		hatchState[player] = nil
		failHatch("Inventory full")
		warn(
			"PetHandler: race-safe hatch block for "
				.. player.Name
				.. " because inventory reached "
				.. tostring(inventoryCount)
				.. "/"
				.. tostring(inventoryCapacity)
		)
		return
	end

	-- Stack or create
	local wasDuplicate = inv[variantKey] ~= nil
	local previousStackAmount = wasDuplicate and inv[variantKey].stackAmount or nil
	if inv[variantKey] then
		inv[variantKey].stackAmount += 1
		-- (for simplicity: keep existing trait — change if you want override logic)
	else
		inv[variantKey] = {
			petId = petId,
			stackAmount = 1,
			traitId = traitId,
			isShiny = false,
			personalityId = personalityId,
			mutationId = mutationId,
		}
	end

	local function rollbackHatchInventory()
		if wasDuplicate and inv[variantKey] then
			inv[variantKey].stackAmount = math.max(1, tonumber(previousStackAmount) or 1)
		else
			inv[variantKey] = nil
		end
	end

	local newStack = inv[variantKey].stackAmount
	local entry = buildEntry(variantKey, inv[variantKey])
	if not entry then
		rollbackHatchInventory()
		hatchState[player] = nil
		failHatch("Inventory update failed. Try again.", 1.5)
		warn(
			"PetHandler: hatch rolled " .. tostring(petId) .. " but failed to build inventory entry for " .. player.Name
		)
		return
	end

	if cost > 0 then
		if not coins.Parent or coins.Value < cost then
			rollbackHatchInventory()
			hatchState[player] = nil
			logHatch(player, eggId, "cost:", cost, "coins before:", coins.Value)
			failHatch("Not enough coins!")
			return
		end
		coins.Value -= cost
		state.charged = true
	end
	logHatch(player, eggId, "coins after:", coins and coins.Value or 0)

	entry.rollIsShiny = false
	entry.wasDuplicate = wasDuplicate
	entry.duplicateCount = newStack
	entry.hatchCost = cost
	entry.eggId = eggId
	entry.mergeTier = entry.currentStackTier
	entry.autoEquipped = false
	entry.manualEquipRequired = true
	entry.traitsUnlockedForEgg = canRollTraits
	entry.mutationsUnlockedForEgg = canRollMutations
	if DEBUG_LOGS then
		print(
			"Hatched Color "
				.. tostring(entry.displayName or petId)
				.. " | Trait: "
				.. tostring(entry.traitName)
				.. " | Mutation: "
				.. tostring(entry.mutationName)
				.. " | Egg: "
				.. tostring(eggId)
				.. " | Cost: "
				.. tostring(cost)
				.. (tutorialFreeHatch and " | Tutorial free hatch" or "")
		)
	end

	syncPetFolder(player, "hatch-color")
	ensureOwnerRainbowPet(player)
	sendState(player)
	hatchEvent:FireClient(player, true, entry)
	reportDailyQuestProgress(player, "ColorsHatched", 1)
	RankService.AwardForHatch(player, eggId, cost)
	if tutorialHatchSucceededEvent and tutorialHatchSucceededEvent:IsA("BindableEvent") then
		tutorialHatchSucceededEvent:Fire(player, eggId, entry)
	end

	state.active = false
	clearHatchStateLater(player, state, lockSeconds)
	task.delay(lockSeconds, function()
		if player and player.Parent then
			releaseActiveHatch(player, hatchToken)
		end
	end)
end)

grantPetFunction.OnInvoke = function(player, petId, amount, traitId, mutationId, autoEquip)
	return grantPetToPlayer(player, petId, amount, traitId, false, autoEquip ~= false, "Neutral", mutationId)
end

-- ========================
--   EQUIP / UNEQUIP
-- ========================
local function handleEquipPetAction(player, action, variantKey)
	local equipped = playerEquipped[player]
	local inventory = playerInventory[player]
	if not equipped or not inventory then
		return false, "Color inventory is not ready."
	end
	local resolvedKey = resolveInventoryKey(inventory, variantKey)

	if action == "equip" then
		if not resolvedKey or not inventory[resolvedKey] then
			return false, "You do not own that Color."
		end

		local maxSlots = getMaxSlots(player)
		for _, id in ipairs(equipped) do
			if id == resolvedKey then
				return true, "Already equipped."
			end
		end
		if #equipped < maxSlots then
			table.insert(equipped, resolvedKey)
		else
			return false, "No open Color equip slots."
		end
	elseif action == "unequip" then
		if not variantKey then
			return false, "Choose a Color first."
		end
		local removed = false
		for i, id in ipairs(equipped) do
			if id == variantKey or id == resolvedKey then
				table.remove(equipped, i)
				removed = true
				break
			end
		end
		if not removed then
			return true, "Already unequipped."
		end
	else
		return false, "Unknown Color action."
	end

	syncPetFolder(player, "equip-color")
	sendState(player)
	if
		action == "equip"
		and #equipped > 0
		and tutorialColorEquippedEvent
		and tutorialColorEquippedEvent:IsA("BindableEvent")
	then
		tutorialColorEquippedEvent:Fire(player, variantKey)
	end
	return true, action == "equip" and "Color equipped." or "Color unequipped."
end

equipEvent.OnServerEvent:Connect(function(player, action, variantKey)
	handleEquipPetAction(player, action, variantKey)
end)

-- ========================
--   LOCK / DELETE COLORS
-- ========================
local function handleLockPetAction(player, variantKey, locked)
	local inventory = playerInventory[player]
	if not inventory then
		return false, "Color inventory is not ready."
	end

	local resolvedKey = resolveInventoryKey(inventory, variantKey)
	if not resolvedKey or not inventory[resolvedKey] then
		return false, "You do not own that Color."
	end

	playerLocked[player] = playerLocked[player] or {}
	if locked == nil then
		playerLocked[player][resolvedKey] = not playerLocked[player][resolvedKey]
	else
		playerLocked[player][resolvedKey] = locked == true
	end
	if playerLocked[player][resolvedKey] ~= true then
		playerLocked[player][resolvedKey] = nil
	end

	syncPetFolder(player, "lock-color")
	sendState(player)
	lockPetEvent:FireClient(player, true, resolvedKey, playerLocked[player][resolvedKey] == true)
	return true,
		playerLocked[player][resolvedKey] == true and "Color locked." or "Color unlocked.",
		playerLocked[player][resolvedKey] == true
end

lockPetEvent.OnServerEvent:Connect(function(player, variantKey, locked)
	local ok, message = handleLockPetAction(player, variantKey, locked)
	if not ok then
		lockPetEvent:FireClient(player, false, variantKey, message)
	end
end)

local function handleDeletePetAction(player, variantKey)
	local equipped = playerEquipped[player]
	local inventory = playerInventory[player]
	if not equipped or not inventory then
		return false, "Color inventory is not ready."
	end

	local resolvedKey = resolveInventoryKey(inventory, variantKey)
	if not resolvedKey or not inventory[resolvedKey] then
		return false, "You do not own that Color."
	end
	if isEquippedKey(equipped, resolvedKey) then
		return false, "Unequip this Color before deleting it."
	end
	if playerLocked[player] and playerLocked[player][resolvedKey] == true then
		return false, "Unlock this Color before deleting it."
	end

	inventory[resolvedKey] = nil
	if playerLocked[player] then
		playerLocked[player][resolvedKey] = nil
	end
	syncPetFolder(player, "delete-color")
	sendState(player)
	deletePetEvent:FireClient(player, true, resolvedKey, "Color deleted.")
	return true, "Color deleted."
end

deletePetEvent.OnServerEvent:Connect(function(player, variantKey)
	local ok, message = handleDeletePetAction(player, variantKey)
	if not ok then
		deletePetEvent:FireClient(player, false, variantKey, message)
	end
end)

inventoryPetActionFunction.OnInvoke = function(player, action, variantKey, value)
	if action == "EquipColor" then
		return handleEquipPetAction(player, "equip", variantKey)
	elseif action == "UnequipColor" then
		return handleEquipPetAction(player, "unequip", variantKey)
	elseif action == "LockColor" then
		return handleLockPetAction(player, variantKey, value)
	elseif action == "DeleteColor" then
		return handleDeletePetAction(player, variantKey)
	end
	return false, "Unknown Color action."
end

-- ========================
--   MERGE PET STACK
-- ========================
mergeEvent.OnServerEvent:Connect(function(player, variantKey)
	local inventory = playerInventory[player]
	if not inventory then
		return
	end

	if not isFeatureUnlocked(player, "Merge") then
		mergeEvent:FireClient(player, false, variantKey, getFeatureLockedMessage("Merge"))
		return
	end

	local now = os.clock()
	if lastMergeAt[player] and now - lastMergeAt[player] < 0.5 then
		mergeEvent:FireClient(player, false, variantKey, "Slow down.")
		return
	end
	lastMergeAt[player] = now

	local resolvedKey = resolveInventoryKey(inventory, variantKey)
	local data = resolvedKey and inventory[resolvedKey]
	if not data or not PetData.Pets[data.petId] then
		mergeEvent:FireClient(player, false, variantKey, "You do not own that Color.")
		return
	end

	local mergeInfo = PetData.getMergeInfo(data.stackAmount)
	if not mergeInfo.canMerge then
		local need = math.max(0, mergeInfo.required - mergeInfo.ownedForTier)
		mergeEvent:FireClient(player, false, variantKey, "Need " .. need .. " more.")
		return
	end

	data.stackAmount = mergeInfo.resultStack

	local entry = buildEntry(resolvedKey, data)

	syncPetFolder(player, "merge-color")
	sendState(player)
	mergeEvent:FireClient(player, true, resolvedKey, entry)
end)

-- ========================
--   GET PET STATS (with trait multipliers)
-- ========================
local function getPlayerPetStats(player)
	local stats =
		{ breakPower = 0, colorMult = 1.0, coinMult = 1.0, speedMult = 1.0, pickupRangeMult = 1.0, luckBonus = 0 }
	local equipped = playerEquipped[player]
	local inventory = playerInventory[player]
	if not equipped or not inventory then
		return stats
	end
	local personalityStats = getEquippedPersonalityStats(player)
	local colorBonus = 0
	local coinBonus = 0

	for _, variantKey in ipairs(equipped) do
		local data = inventory[variantKey]
		local stack = data and data.stackAmount or 1
		local entry = data
			and PetData.buildPetEntry(
				data.petId,
				stack,
				data.isShiny,
				data.personalityId,
				data.mutationId,
				data.traitId
			)
		if entry then
			local effPower = entry.finalPower

			stats.breakPower = stats.breakPower + effPower

			colorBonus += math.max(0, (entry.colorMult or 1.0) - 1)
			coinBonus += math.max(0, (entry.coinMult or 1.0) - 1)
		end
	end

	stats.breakPower = math.floor(stats.breakPower * personalityStats.totalPowerMult)
	local petBalance = GameBalance.Pets or {}
	stats.colorMult = math.min(1 + colorBonus, tonumber(petBalance.MaxColorMultiplierFromPets) or 1.35)
	stats.coinMult = math.min(1 + coinBonus, tonumber(petBalance.MaxCoinMultiplierFromPets) or 1.35)
	stats.colorMult *= personalityStats.colorGainMult
	stats.coinMult *= personalityStats.sellMult
	stats.pickupRangeMult = personalityStats.pickupRangeMult
	stats.luckBonus = personalityStats.luckBonus

	local upgrades = player:FindFirstChild("Upgrades")
	local playerPower = upgrades and upgrades:FindFirstChild("PlayerPower")
	if playerPower then
		stats.colorMult *= playerPower.Value
	end

	local coinMultiplier = upgrades
		and (upgrades:FindFirstChild("CoinMultiplier") or upgrades:FindFirstChild("ColorMultiplier"))
	if coinMultiplier then
		stats.coinMult *= coinMultiplier.Value
	end

	local brushEffects = ColorEffectHandler.CalculateEquippedColorEffects(player)
	stats.breakPower = math.floor(stats.breakPower * (tonumber(brushEffects.PetPowerMultiplier) or 1))
	stats.coinMult *= tonumber(brushEffects.PetCoinMultiplier) or 1
	stats.pickupRangeMult *= tonumber(brushEffects.PetRangeMultiplier) or 1

	return stats
end

-- ========================
--   BREAKABLE TRACKING
-- ========================
local objectHealth = {}
local objectMaxHealth = {}
local trackedBreakables = {}

local function registerObject(obj)
	if not obj:IsA("BasePart") or not obj:GetAttribute("BreakableType") then
		return
	end
	if trackedBreakables[obj] then
		return
	end

	trackedBreakables[obj] = true
	obj.Destroying:Connect(function()
		trackedBreakables[obj] = nil
		objectHealth[obj] = nil
		objectMaxHealth[obj] = nil
	end)
	obj:GetAttributeChangedSignal("IsCollected"):Connect(function()
		local data = ColorData.Breakables[obj:GetAttribute("BreakableType")]
		if not data then
			objectHealth[obj] = nil
			objectMaxHealth[obj] = nil
			return
		end
		if obj:GetAttribute("IsCollected") == true or obj.Transparency >= 1 then
			objectHealth[obj] = 0
		else
			objectHealth[obj] = data.health
			objectMaxHealth[obj] = data.health
		end
	end)

	local data = ColorData.Breakables[obj:GetAttribute("BreakableType")]
	if data then
		objectHealth[obj] = obj:GetAttribute("IsCollected") and 0 or data.health
		objectMaxHealth[obj] = data.health
	end
end
for _, obj in ipairs(workspace:GetDescendants()) do
	registerObject(obj)
end
workspace.DescendantAdded:Connect(registerObject)

-- ========================
--   PET AUTO-ATTACK LOOP
-- ========================
local PET_ATTACK_RANGE = tonumber(GameBalance.Pets and GameBalance.Pets.AttackRange) or 16
local PET_ATTACK_INTERVAL = tonumber(GameBalance.Pets and GameBalance.Pets.AttackInterval) or 0.65
local PET_DAMAGE_SCALE = tonumber(GameBalance.Pets and GameBalance.Pets.DamageScale) or 0.35
local MIN_PET_DAMAGE_FRACTION = tonumber(GameBalance.Pets and GameBalance.Pets.MinDamageFraction) or 0.08
local lastAttack = {}

local function isPointInsideZone(part, worldPosition, margin)
	local localPoint = part.CFrame:PointToObjectSpace(worldPosition)
	local half = part.Size * 0.5 + Vector3.new(margin or 0, margin or 0, margin or 0)
	return math.abs(localPoint.X) <= half.X and math.abs(localPoint.Y) <= half.Y and math.abs(localPoint.Z) <= half.Z
end

local function getPhysicalZoneColors(root)
	local colors = {}
	if not root then
		return colors
	end

	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("BasePart") and obj:GetAttribute("ColorZone") == true then
			local colorType = obj:GetAttribute("ColorType")
			if colorType and isPointInsideZone(obj, root.Position, 12) then
				colors[colorType] = true
			end
		end
	end
	return colors
end

local function canPetAttackBreakable(player, obj, health, root, unlockedColors, maxRange, physicalZoneColors)
	if health <= 0 or not obj or not obj.Parent or obj.Transparency >= 1 or obj:GetAttribute("IsCollected") then
		return false
	end

	local colorType = obj:GetAttribute("ColorType")
	if
		unlockedColors
		and colorType
		and not ColorData.isColorUnlocked(unlockedColors.Value, colorType)
		and not (physicalZoneColors and physicalZoneColors[colorType])
	then
		return false
	end

	return (root.Position - obj.Position).Magnitude <= maxRange
end

local function getPriorityTarget(player, root, unlockedColors, physicalZoneColors, maxRange)
	local bestTarget = nil
	local bestSetAt = -math.huge
	local now = os.clock()
	maxRange = maxRange or PET_ATTACK_RANGE
	for obj, health in pairs(objectHealth) do
		if
			obj:GetAttribute("PetPriorityOwnerUserId") == player.UserId
			and (tonumber(obj:GetAttribute("PetPriorityUntil")) or 0) > now
			and canPetAttackBreakable(player, obj, health, root, unlockedColors, maxRange, physicalZoneColors)
		then
			local setAt = tonumber(obj:GetAttribute("PetPrioritySetAt")) or 0
			if setAt > bestSetAt then
				bestTarget = obj
				bestSetAt = setAt
			end
		end
	end
	return bestTarget
end

RunService.Heartbeat:Connect(function()
	local now = tick()
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		if not char then
			continue
		end
		local root = char:FindFirstChild("HumanoidRootPart")
		if not root then
			continue
		end
		if (now - (lastAttack[player] or 0)) < PET_ATTACK_INTERVAL then
			continue
		end

		local petStats = getPlayerPetStats(player)
		if petStats.breakPower <= 0 then
			continue
		end

		local storage = player:FindFirstChild("ColorStorage")
		local unlockedColors = storage and storage:FindFirstChild("UnlockedColors")
		local physicalZoneColors = getPhysicalZoneColors(root)
		local attackRange = PET_ATTACK_RANGE * (tonumber(petStats.pickupRangeMult) or 1)

		local nearest = getPriorityTarget(player, root, unlockedColors, physicalZoneColors, attackRange)
		local nearestDist = attackRange
		if not nearest then
			for obj, health in pairs(objectHealth) do
				if
					canPetAttackBreakable(player, obj, health, root, unlockedColors, attackRange, physicalZoneColors)
				then
					local dist = (root.Position - obj.Position).Magnitude
					if dist < nearestDist then
						nearest = obj
						nearestDist = dist
					end
				end
			end
		end

		if nearest then
			lastAttack[player] = now
			local breakableType = nearest:GetAttribute("BreakableType")
			local colorType = nearest:GetAttribute("ColorType")
			local colorData = ColorData.Breakables[breakableType]
			if colorData and (not objectMaxHealth[nearest] or objectMaxHealth[nearest] <= 0) then
				objectMaxHealth[nearest] = colorData.health
			end
			if
				colorData
				and (not objectHealth[nearest] or objectHealth[nearest] <= 0)
				and not nearest:GetAttribute("IsCollected")
			then
				objectHealth[nearest] = colorData.health
			end

			local maxHealth = objectMaxHealth[nearest] or (colorData and colorData.health) or 1
			local damage = math.max(petStats.breakPower * PET_DAMAGE_SCALE, maxHealth * MIN_PET_DAMAGE_FRACTION)
			objectHealth[nearest] = math.max(0, objectHealth[nearest] - damage)
			local healthPct = objectHealth[nearest] / (objectMaxHealth[nearest] or 1)

			local colorInfo = ColorData.Colors[colorType]
			if colorInfo and nearest and nearest.Parent then
				local baseColor = getStoredColor(nearest, colorType)
				nearest.Color = baseColor:Lerp(Color3.new(1, 1, 1), math.clamp((1 - healthPct) * 0.22, 0, 0.22))
			end

			petAtkEvent:FireClient(player, playerEquipped[player], nearest, colorType)

			if objectHealth[nearest] <= 0 and colorData then
				local baseReward = getBaseBreakableReward(nearest, colorData)
				local areaMult = tonumber(nearest:GetAttribute("RewardMultiplier")) or 1
				local reward = math.max(
					1,
					math.floor(
						baseReward
							* areaMult
							* petStats.colorMult
							* getInstantCoinMultiplier(player, colorType, petStats)
					)
				)
				petBreakRewardEvent:FireClient(player, {
					Amount = reward,
					ColorType = colorType,
					Position = nearest.Position,
				})
				reportColorSpillCleaned(player, nearest, colorType)
				if not awardCoins(player, reward) then
					warn("PetHandler: failed to award pet break coins for " .. tostring(player.Name))
				end

				nearest:SetAttribute("IsCollected", true)
				nearest:SetAttribute("Respawning", true)
				nearest:SetAttribute("PetPriorityOwnerUserId", nil)
				nearest:SetAttribute("PetPriorityUntil", nil)
				nearest:SetAttribute("PetPrioritySetAt", nil)
				nearest.Transparency = 1
				nearest.CanCollide = false
				objectHealth[nearest] = 0

				local respawnDelay = tonumber(nearest:GetAttribute("ContaminationRegenDelay"))
					or tonumber(nearest:GetAttribute("RespawnDelay"))
					or 5
				task.delay(respawnDelay, function()
					if nearest and nearest.Parent then
						local data = ColorData.Breakables[nearest:GetAttribute("BreakableType")]
						if data then
							local ci = ColorData.Colors[nearest:GetAttribute("ColorType")]
							local respawnColorType = nearest:GetAttribute("ColorType")
							if ci then
								nearest.Color = getStoredColor(nearest, respawnColorType)
							end
							objectHealth[nearest] = data.health
							objectMaxHealth[nearest] = data.health
							nearest.Transparency = nearest:GetAttribute("CollectorBaseTransparency") or 0
							nearest.CanCollide = false
							nearest.CanTouch = false
							nearest.CanQuery = true
							nearest:SetAttribute("IsCollected", false)
							nearest:SetAttribute("Respawning", false)
							nearest:SetAttribute("PetPriorityOwnerUserId", nil)
							nearest:SetAttribute("PetPriorityUntil", nil)
							nearest:SetAttribute("PetPrioritySetAt", nil)
						end
					end
				end)
			end
		end
	end
end)

return {
	getPlayerPetStats = getPlayerPetStats,
	AddColorToInventory = grantPetToPlayer,
}
