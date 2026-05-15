-- ModuleScript in ReplicatedStorage named "PetData"
local ColorMutationData = require(script.Parent:WaitForChild("ColorMutationData"))
local ColorPersonalityData = require(script.Parent:WaitForChild("ColorPersonalityData"))
local ColorTraitData = require(script.Parent:WaitForChild("ColorTraitData"))
local GameBalance = require(script.Parent:WaitForChild("GameBalance"))
local LegendaryColorOrbDefinitions =
	require(script.Parent:WaitForChild("Modules"):WaitForChild("LegendaryColorOrbDefinitions"))
local RunService = game:GetService("RunService")

local PetData = {}
local warnedUnknownColorIds = {}
PetData.FallbackPetId = "RedBlob"
PetData.LegacyPetIdAliases = {
	Unknown = "RedBlob",
	unknown = "RedBlob",
	UnknownColor = "RedBlob",
	["Unknown Color"] = "RedBlob",
	StarterPet = "RedBlob",
	StarterColor = "RedBlob",
	DefaultPet = "RedBlob",
	DefaultColor = "RedBlob",
}

local function warnUnknownColorOnce(petId)
	if warnedUnknownColorIds[petId] then
		return
	end
	warnedUnknownColorIds[petId] = true
	warn("Unknown saved ColorId preserved: " .. tostring(petId))
end

-- These are called Colors in player-facing UI, even if internal code uses Pet for legacy reasons.
-- Add or replace weekly Colors by editing PetData.Pets, PetData.Eggs, and PetData.EggOrder.

function PetData.GetCompanionTypeName()
	return "Color"
end

function PetData.GetCompanionPluralName()
	return "Colors"
end

function PetData.GetCompanionDisplayName(petId)
	petId = PetData.resolvePetId(petId)
	local pet = PetData.Pets and PetData.Pets[petId]
	return pet and pet.displayName or "Unknown Color"
end

function PetData.normalizePersonalityId(personalityId)
	if ColorPersonalityData.Personalities[personalityId or ""] then
		return personalityId
	end
	return ColorPersonalityData.DefaultId
end

function PetData.normalizeMutationId(mutationId)
	return ColorMutationData.normalize(mutationId)
end

function PetData.normalizeTraitId(traitId)
	return ColorTraitData.normalize(traitId)
end

function PetData.makeVariantKey(petId, personalityId, mutationId, traitId)
	-- The second argument remains named personalityId for old callers. Variant identity now uses
	-- the real Color Trait plus Mutation so different hatched variants do not merge together.
	mutationId = PetData.normalizeMutationId(mutationId)
	traitId = PetData.normalizeTraitId(traitId)
	if traitId == ColorTraitData.DefaultId and mutationId == ColorMutationData.NoneId then
		return tostring(petId)
	end
	return tostring(petId) .. "|" .. traitId .. "|" .. mutationId
end

PetData.Pets = {
	RedBlob = {
		displayName = "Crimson",
		rarity = "Common",
		color = Color3.fromRGB(220, 50, 50),
		breakPower = 2,
		colorMult = 1.1,
		coinMult = 1.0,
	},
	RedCubey = {
		displayName = "Scarlet",
		rarity = "Common",
		color = Color3.fromRGB(245, 70, 75),
		breakPower = 2,
		colorMult = 1.12,
		coinMult = 1.02,
	},
	RoseRabbit = {
		displayName = "Rose",
		rarity = "Common",
		color = Color3.fromRGB(255, 110, 130),
		breakPower = 3,
		colorMult = 1.15,
		coinMult = 1.06,
	},
	CrimsonSprite = {
		displayName = "Ruby",
		rarity = "Uncommon",
		color = Color3.fromRGB(255, 80, 105),
		breakPower = 5,
		colorMult = 1.28,
		coinMult = 1.12,
	},
	BlueBunny = {
		displayName = "Azure",
		rarity = "Common",
		color = Color3.fromRGB(50, 100, 220),
		breakPower = 2,
		colorMult = 1.0,
		coinMult = 1.1,
	},
	YellowBee = {
		displayName = "Lemon",
		rarity = "Common",
		color = Color3.fromRGB(240, 210, 40),
		breakPower = 3,
		colorMult = 1.0,
		coinMult = 1.0,
	},
	GreenSprout = {
		displayName = "Lime",
		rarity = "Uncommon",
		color = Color3.fromRGB(60, 180, 80),
		breakPower = 5,
		colorMult = 1.25,
		coinMult = 1.1,
	},
	PurpleBat = {
		displayName = "Violet",
		rarity = "Uncommon",
		color = Color3.fromRGB(140, 60, 200),
		breakPower = 6,
		colorMult = 1.2,
		coinMult = 1.2,
	},
	OrangeFox = {
		displayName = "Tangerine",
		rarity = "Rare",
		color = Color3.fromRGB(240, 130, 30),
		breakPower = 10,
		colorMult = 1.5,
		coinMult = 1.3,
	},
	PinkSpirit = {
		displayName = "Coral",
		rarity = "Rare",
		color = Color3.fromRGB(255, 160, 180),
		breakPower = 12,
		colorMult = 1.4,
		coinMult = 1.5,
	},
	NeonCubey = {
		displayName = "Electric Cyan",
		rarity = "Epic",
		color = Color3.fromRGB(0, 255, 200),
		breakPower = 20,
		colorMult = 2.0,
		coinMult = 1.8,
	},
	RainbowDragon = {
		displayName = "Prismatic Gold",
		rarity = "Legendary",
		color = Color3.fromRGB(255, 255, 100),
		breakPower = 50,
		colorMult = 3.0,
		coinMult = 3.0,
	},

	BlueMouse = {
		displayName = "Cobalt",
		rarity = "Common",
		color = Color3.fromRGB(72, 145, 255),
		breakPower = 8,
		colorMult = 1.4,
		coinMult = 1.2,
	},
	AquaTurtle = {
		displayName = "Cyan",
		rarity = "Common",
		color = Color3.fromRGB(80, 210, 230),
		breakPower = 10,
		colorMult = 1.45,
		coinMult = 1.25,
	},
	SapphireCat = {
		displayName = "Sapphire",
		rarity = "Rare",
		color = Color3.fromRGB(45, 85, 220),
		breakPower = 16,
		colorMult = 1.8,
		coinMult = 1.45,
	},
	TideDragon = {
		displayName = "Cerulean",
		rarity = "Epic",
		color = Color3.fromRGB(40, 235, 255),
		breakPower = 30,
		colorMult = 2.4,
		coinMult = 1.9,
	},
	DeepSeaStar = {
		displayName = "Indigo",
		rarity = "Legendary",
		color = Color3.fromRGB(120, 210, 255),
		breakPower = 70,
		colorMult = 4.0,
		coinMult = 3.1,
	},

	SunChick = {
		displayName = "Amber",
		rarity = "Common",
		color = Color3.fromRGB(255, 224, 70),
		breakPower = 22,
		colorMult = 2.2,
		coinMult = 1.7,
	},
	HoneyBear = {
		displayName = "Marigold",
		rarity = "Common",
		color = Color3.fromRGB(255, 190, 60),
		breakPower = 26,
		colorMult = 2.35,
		coinMult = 1.8,
	},
	Goldfinch = {
		displayName = "Gold",
		rarity = "Rare",
		color = Color3.fromRGB(255, 238, 120),
		breakPower = 42,
		colorMult = 3.0,
		coinMult = 2.25,
	},
	SolarLion = {
		displayName = "Saffron",
		rarity = "Epic",
		color = Color3.fromRGB(255, 160, 45),
		breakPower = 78,
		colorMult = 4.3,
		coinMult = 3.1,
	},
	StarPhoenix = {
		displayName = "Ivory",
		rarity = "Legendary",
		color = Color3.fromRGB(255, 245, 145),
		breakPower = 165,
		colorMult = 7.5,
		coinMult = 5.2,
	},

	MossPup = {
		displayName = "Moss",
		rarity = "Common",
		color = Color3.fromRGB(85, 205, 95),
		breakPower = 55,
		colorMult = 4.8,
		coinMult = 3.5,
	},
	LeafBunny = {
		displayName = "Mint",
		rarity = "Common",
		color = Color3.fromRGB(125, 230, 105),
		breakPower = 62,
		colorMult = 5.2,
		coinMult = 3.8,
	},
	EmeraldFox = {
		displayName = "Emerald",
		rarity = "Rare",
		color = Color3.fromRGB(45, 190, 95),
		breakPower = 100,
		colorMult = 6.7,
		coinMult = 4.8,
	},
	VineGolem = {
		displayName = "Jade",
		rarity = "Epic",
		color = Color3.fromRGB(55, 160, 75),
		breakPower = 185,
		colorMult = 9.3,
		coinMult = 6.6,
	},
	ForestWyvern = {
		displayName = "Viridian",
		rarity = "Legendary",
		color = Color3.fromRGB(115, 255, 150),
		breakPower = 390,
		colorMult = 15.0,
		coinMult = 10.5,
	},

	AmethystBat = {
		displayName = "Amethyst",
		rarity = "Common",
		color = Color3.fromRGB(155, 95, 230),
		breakPower = 150,
		colorMult = 11.5,
		coinMult = 8.8,
	},
	MagicMoth = {
		displayName = "Lavender",
		rarity = "Rare",
		color = Color3.fromRGB(185, 120, 255),
		breakPower = 240,
		colorMult = 15.5,
		coinMult = 11.5,
	},
	RoyalSlime = {
		displayName = "Orchid",
		rarity = "Epic",
		color = Color3.fromRGB(140, 45, 215),
		breakPower = 440,
		colorMult = 23.0,
		coinMult = 17.0,
	},
	VoidUnicorn = {
		displayName = "Ultraviolet",
		rarity = "Legendary",
		color = Color3.fromRGB(215, 190, 255),
		breakPower = 900,
		colorMult = 42.0,
		coinMult = 30.0,
	},

	NeonGecko = {
		displayName = "Neon Teal",
		rarity = "Common",
		color = Color3.fromRGB(0, 255, 200),
		breakPower = 520,
		colorMult = 34.0,
		coinMult = 25.0,
	},
	LaserPanda = {
		displayName = "Laser Green",
		rarity = "Rare",
		color = Color3.fromRGB(30, 255, 145),
		breakPower = 850,
		colorMult = 48.0,
		coinMult = 35.0,
	},
	CyberWolf = {
		displayName = "Cyber Blue",
		rarity = "Epic",
		color = Color3.fromRGB(0, 180, 255),
		breakPower = 1550,
		colorMult = 75.0,
		coinMult = 55.0,
	},
	NeonHydra = {
		displayName = "Neon Cyan",
		rarity = "Legendary",
		color = Color3.fromRGB(90, 255, 230),
		breakPower = 3200,
		colorMult = 135.0,
		coinMult = 95.0,
	},

	RainbowSlime = {
		displayName = "Pearl",
		rarity = "Common",
		color = Color3.fromRGB(255, 255, 255),
		breakPower = 2300,
		colorMult = 110.0,
		coinMult = 80.0,
	},
	PrismBee = {
		displayName = "Silver",
		rarity = "Rare",
		color = Color3.fromRGB(255, 240, 140),
		breakPower = 3600,
		colorMult = 160.0,
		coinMult = 115.0,
	},
	SpectrumFox = {
		displayName = "Magenta",
		rarity = "Epic",
		color = Color3.fromRGB(255, 120, 220),
		breakPower = 6800,
		colorMult = 260.0,
		coinMult = 185.0,
	},
	ColorTitan = {
		displayName = "Spectrum",
		rarity = "Legendary",
		color = Color3.fromRGB(255, 255, 180),
		breakPower = 14000,
		colorMult = 500.0,
		coinMult = 350.0,
	},
	DevRainbowPet = {
		displayName = "Rainbow Pet",
		rarity = "Legendary",
		color = Color3.fromRGB(255, 255, 255),
		breakPower = 250000,
		colorMult = 2500.0,
		coinMult = 1500.0,
		modelName = "DevRainbowPet",
		iconColor = Color3.fromRGB(255, 255, 255),
		cardColor = Color3.fromRGB(226, 212, 255),
		accentColor = Color3.fromRGB(255, 220, 80),
		useRainbowGradient = true,
	},
}

for _, orb in ipairs(LegendaryColorOrbDefinitions) do
	PetData.Pets[orb.Id] = {
		displayName = orb.DisplayName,
		rarity = "Legendary",
		color = orb.MainColor,
		breakPower = orb.BreakPower or 50,
		colorMult = orb.ColorMultiplier or 3,
		coinMult = orb.CoinMultiplier or 3,
		modelName = orb.ModelName,
		worldNumber = orb.WorldNumber,
		areaColor = orb.AreaColor,
		isLegendaryColorOrb = true,
	}
end

function PetData.resolvePetId(petId)
	petId = tostring(petId or "")
	if PetData.Pets[petId] then
		return petId, false
	end

	local alias = PetData.LegacyPetIdAliases[petId]
	if alias and PetData.Pets[alias] then
		return alias, true
	end

	local compact = string.gsub(petId, "%s+", "")
	alias = PetData.LegacyPetIdAliases[compact]
	if alias and PetData.Pets[alias] then
		return alias, true
	end

	local fallback = PetData.FallbackPetId
	if PetData.Pets[fallback] then
		return fallback, true
	end

	for id in pairs(PetData.Pets or {}) do
		return id, true
	end

	return petId, true
end

PetData.Eggs = {
	ColorEgg = {
		displayName = "Color Egg",
		areaColor = "Red",
		cost = 250,
		color = Color3.fromRGB(180, 100, 255),
		pets = {
			{ petId = "RedBlob", chance = 40 },
			{ petId = "RedCubey", chance = 35 },
			{ petId = "RoseRabbit", chance = 20 },
			{ petId = "CrimsonSprite", chance = 5 },
			{ petId = "red_legendary_orb", chance = 1 },
		},
	},
	OrangeEgg = {
		displayName = "Orange Egg",
		areaColor = "Orange",
		cost = 1500,
		color = Color3.fromRGB(255, 145, 45),
		pets = {
			{ petId = "OrangeFox", chance = 42 },
			{ petId = "CrimsonSprite", chance = 30 },
			{ petId = "Goldfinch", chance = 18 },
			{ petId = "SolarLion", chance = 7 },
			{ petId = "orange_legendary_orb", chance = 1 },
		},
	},
	BlueEgg = {
		displayName = "Blue Egg",
		areaColor = "Blue",
		cost = 5000,
		color = Color3.fromRGB(86, 166, 255),
		pets = {
			{ petId = "BlueMouse", chance = 42 },
			{ petId = "AquaTurtle", chance = 33 },
			{ petId = "SapphireCat", chance = 18 },
			{ petId = "TideDragon", chance = 6 },
			{ petId = "blue_legendary_orb", chance = 1 },
		},
	},
	YellowEgg = {
		displayName = "Yellow Egg",
		areaColor = "Yellow",
		cost = 15000,
		color = Color3.fromRGB(255, 224, 86),
		pets = {
			{ petId = "SunChick", chance = 42 },
			{ petId = "HoneyBear", chance = 33 },
			{ petId = "Goldfinch", chance = 18 },
			{ petId = "SolarLion", chance = 6 },
			{ petId = "yellow_legendary_orb", chance = 1 },
		},
	},
	GreenEgg = {
		displayName = "Green Egg",
		areaColor = "Green",
		cost = 50000,
		color = Color3.fromRGB(92, 222, 112),
		pets = {
			{ petId = "MossPup", chance = 42 },
			{ petId = "LeafBunny", chance = 33 },
			{ petId = "EmeraldFox", chance = 18 },
			{ petId = "VineGolem", chance = 6 },
			{ petId = "green_legendary_orb", chance = 1 },
		},
	},
	PurpleEgg = {
		displayName = "Purple Egg",
		areaColor = "Purple",
		cost = 175000,
		color = Color3.fromRGB(170, 100, 255),
		pets = {
			{ petId = "PurpleBat", chance = 40 },
			{ petId = "AmethystBat", chance = 32 },
			{ petId = "MagicMoth", chance = 20 },
			{ petId = "RoyalSlime", chance = 7 },
			{ petId = "purple_legendary_orb", chance = 1 },
		},
	},
	NeonEgg = {
		displayName = "Neon Egg",
		areaColor = "Neon",
		cost = 600000,
		color = Color3.fromRGB(0, 255, 200),
		pets = {
			{ petId = "NeonGecko", chance = 42 },
			{ petId = "LaserPanda", chance = 33 },
			{ petId = "CyberWolf", chance = 18 },
			{ petId = "NeonCubey", chance = 6 },
			{ petId = "cyan_legendary_orb", chance = 1 },
		},
	},
	RainbowEgg = {
		displayName = "Rainbow Egg",
		areaColor = "Rainbow",
		cost = 2000000,
		color = Color3.fromRGB(255, 255, 255),
		pets = {
			{ petId = "RainbowSlime", chance = 42 },
			{ petId = "PrismBee", chance = 33 },
			{ petId = "SpectrumFox", chance = 18 },
			{ petId = "RainbowDragon", chance = 6 },
			{ petId = "rainbow_legendary_orb", chance = 1 },
		},
	},
}

PetData.EggOrder = { "ColorEgg", "OrangeEgg", "GreenEgg", "BlueEgg", "YellowEgg", "PurpleEgg", "NeonEgg", "RainbowEgg" }

PetData.StackTiers = {
	{
		name = "Normal",
		minStack = 1,
		prefix = "",
		powerMult = 1.0,
		coinMult = 1.0,
		auraColor = nil,
		auraEffect = "none",
	},
	{
		name = "Gilded",
		minStack = 100,
		prefix = "Gilded",
		powerMult = 1.25,
		coinMult = 1.10,
		auraColor = Color3.fromRGB(255, 200, 50),
		auraEffect = "shimmer",
	},
	{
		name = "Royal",
		minStack = 1000,
		prefix = "Royal",
		powerMult = 2.0,
		coinMult = 1.25,
		auraColor = Color3.fromRGB(180, 60, 255),
		auraEffect = "glow",
	},
	{
		name = "Celestial",
		minStack = 10000,
		prefix = "Celestial",
		powerMult = 4.0,
		coinMult = 1.50,
		auraColor = Color3.fromRGB(100, 220, 255),
		auraEffect = "ethereal",
	},
}

PetData.MERGE_REQUIREMENT = 5
PetData.SHINY_POWER_MULT = 1.5
PetData.SHINY_COIN_MULT = 1.35
PetData.SHINY_COLOR_MULT = 1.35

function PetData.getStackTier(stackAmount)
	local result = PetData.StackTiers[1]
	for _, tier in ipairs(PetData.StackTiers) do
		if stackAmount >= tier.minStack then
			result = tier
		end
	end
	return result
end

function PetData.getStackTierIndex(stackAmount)
	local tier = PetData.getStackTier(stackAmount)
	for i, entry in ipairs(PetData.StackTiers) do
		if entry.name == tier.name then
			return i
		end
	end
	return 1
end

function PetData.getNextStackTier(stackAmount)
	local index = PetData.getStackTierIndex(stackAmount)
	return PetData.StackTiers[index + 1], index + 1
end

function PetData.getMergeInfo(stackAmount)
	stackAmount = tonumber(stackAmount) or 1
	local tierIndex = PetData.getStackTierIndex(stackAmount)
	local currentTier = PetData.StackTiers[tierIndex]
	local nextTier = PetData.StackTiers[tierIndex + 1]
	if not currentTier or not nextTier then
		return {
			canMerge = false,
			currentTier = currentTier,
			nextTier = nil,
			ownedForTier = math.max(1, stackAmount - (currentTier and currentTier.minStack or 1) + 1),
			required = PetData.MERGE_REQUIREMENT,
			resultStack = stackAmount,
		}
	end

	local ownedForTier = stackAmount - currentTier.minStack + 1
	local canMerge = ownedForTier >= PetData.MERGE_REQUIREMENT
	local extraProgress = math.max(0, ownedForTier - PetData.MERGE_REQUIREMENT)

	return {
		canMerge = canMerge,
		currentTier = currentTier,
		nextTier = nextTier,
		ownedForTier = ownedForTier,
		required = PetData.MERGE_REQUIREMENT,
		resultStack = nextTier.minStack + extraProgress,
	}
end

function PetData.buildPetEntry(petId, stackAmount, isShiny, personalityId, mutationId, traitId)
	local requestedPetId = tostring(petId or "")
	local resolvedPetId, wasResolved = PetData.resolvePetId(requestedPetId)
	petId = resolvedPetId
	local pet = PetData.Pets[petId]
	local isUnknownColor = wasResolved == true
	if not pet then
		isUnknownColor = true
		warnUnknownColorOnce(requestedPetId)
		pet = {
			displayName = "Unknown Color",
			rarity = "Unknown",
			color = Color3.fromRGB(170, 180, 205),
			breakPower = 0,
			colorMult = 1,
			coinMult = 1,
		}
	elseif wasResolved then
		warnUnknownColorOnce(requestedPetId)
	end

	stackAmount = tonumber(stackAmount) or 1
	personalityId = PetData.normalizePersonalityId(personalityId)
	mutationId = PetData.normalizeMutationId(mutationId)
	traitId = PetData.normalizeTraitId(traitId)
	local personality = ColorPersonalityData.get(personalityId)
	local trait = ColorTraitData.get(traitId)
	local mutation = ColorMutationData.get(mutationId)
	local tier = PetData.getStackTier(stackAmount)
	local displayName = pet.displayName
	if tier.prefix and tier.prefix ~= "" then
		displayName = tier.prefix .. " " .. pet.displayName
	end
	if isShiny then
		displayName = "Shiny " .. displayName
	end
	if ColorMutationData.isMutated(mutationId) then
		displayName = mutation.DisplayName .. " " .. displayName
	end

	local auraColor = tier.auraColor or pet.color
	if isShiny then
		auraColor = pet.color:Lerp(Color3.fromRGB(255, 255, 255), 0.55)
	end
	if ColorMutationData.isMutated(mutationId) then
		auraColor = mutation.AuraColor or auraColor
	end

	local mutationPowerMult = mutation.PowerMultiplier or 1
	local legacyShinyPowerMult = isShiny and PetData.SHINY_POWER_MULT or 1
	local petBalance = GameBalance.Pets or {}
	local powerScale = tonumber(petBalance.PowerScale) or 1
	local rewardBonusScale = tonumber(petBalance.RewardBonusScale) or 1
	local rawPower = pet.breakPower * tier.powerMult * legacyShinyPowerMult * mutationPowerMult * powerScale
	local finalPower = pet.breakPower > 0 and math.max(1, math.floor(rawPower)) or 0
	local rawColorMult = pet.colorMult * tier.coinMult * (isShiny and PetData.SHINY_COLOR_MULT or 1)
	local rawCoinMult = pet.coinMult * tier.coinMult * (isShiny and PetData.SHINY_COIN_MULT or 1)
	local effectiveColorMult = 1 + (math.max(0, rawColorMult - 1) * rewardBonusScale)
	local effectiveCoinMult = 1 + (math.max(0, rawCoinMult - 1) * rewardBonusScale)

	return {
		variantKey = PetData.makeVariantKey(petId, personalityId, mutationId, traitId),
		petId = petId,
		isUnknownColor = isUnknownColor,
		unknownColorId = isUnknownColor and requestedPetId or nil,
		resolvedFromPetId = isUnknownColor and requestedPetId or nil,
		baseName = pet.displayName,
		isShiny = isShiny == true,
		traitId = traitId,
		traitName = trait.DisplayName,
		traitDescription = trait.Description,
		traitEffects = trait.Effects,
		traitTextColor = trait.TextColor,
		traitIcon = trait.Icon,
		personalityId = personalityId,
		personalityName = trait.DisplayName,
		personalityDescription = trait.Description,
		personalityColor = trait.TextColor,
		personalityEffectType = personality.EffectType,
		personalityEffectValue = personality.EffectValue,
		mutationId = mutationId,
		mutationName = mutation.DisplayName,
		mutationDescription = mutation.Description,
		mutationRarityText = mutation.RarityText,
		mutationType = mutation.Type,
		mutationRarity = mutation.Rarity,
		mutationVisualTheme = mutation.VisualTheme,
		mutationSpecialEffect = mutation.SpecialEffect,
		mutationVisualEffect = mutation.VisualEffect,
		mutationStatModifiers = mutation.StatModifiers,
		mutationTypeColor = mutation.TypeColor,
		mutationAuraColor = mutation.AuraColor,
		mutationVisualTag = mutation.VisualTag,
		mutationPowerMultiplier = mutation.PowerMultiplier or 1,
		hasMutation = ColorMutationData.isMutated(mutationId),
		rarity = pet.rarity,
		basePower = pet.breakPower,
		stackAmount = stackAmount,
		currentStackTier = tier.name,
		displayName = displayName,
		finalPower = finalPower,
		auraColor = auraColor,
		auraEffect = ColorMutationData.isMutated(mutationId) and mutation.VisualTag
			or (isShiny and "shiny" or tier.auraEffect),
		baseColor = pet.color,
		colorMult = effectiveColorMult,
		coinMult = effectiveCoinMult,
		rawColorMult = rawColorMult,
		rawCoinMult = rawCoinMult,
	}
end

function PetData.formatStack(n)
	n = tonumber(n) or 0
	if n >= 1000000 then
		return string.format("%.1fm", n / 1000000)
	elseif n >= 1000 then
		return string.format("%.1fk", n / 1000)
	end
	return tostring(n)
end

function PetData.rollEgg(eggId, luckMult)
	local egg = PetData.Eggs[eggId]
	if not egg then
		return nil
	end
	local maxLuckMult = 2.5
	if RunService:IsStudio() then
		local testing = GameBalance.Testing or {}
		maxLuckMult = tonumber(testing.MaxStudioHatchLuckMultiplier) or maxLuckMult
	end
	luckMult = math.clamp(tonumber(luckMult) or 1, 1, maxLuckMult)
	local rarityBoost = {
		Uncommon = 0.08,
		Rare = 0.18,
		Epic = 0.35,
		Legendary = 0.65,
	}

	local total = 0
	for _, entry in ipairs(egg.pets) do
		local pet = PetData.Pets[entry.petId]
		local boost = pet and rarityBoost[pet.rarity] or 0
		total += entry.chance * (1 + ((luckMult - 1) * boost))
	end

	local roll = math.random() * total
	local cumulative = 0
	for _, entry in ipairs(egg.pets) do
		local pet = PetData.Pets[entry.petId]
		local boost = pet and rarityBoost[pet.rarity] or 0
		cumulative += entry.chance * (1 + ((luckMult - 1) * boost))
		if roll <= cumulative then
			return entry.petId
		end
	end

	return egg.pets[1].petId
end

return PetData
