local PetTraits = {}

PetTraits.Traits = {
	Swift = {
		name = "Swift",
		displayName = "Swift",
		rarity = "Common",
		icon = ">>",
		description = "+20% speed",
		powerMult = 1.0,
		coinMult = 1.0,
		speedMult = 1.2,
		color = Color3.fromRGB(120, 210, 255),
		visualEffect = "spark",
		weight = 25,
	},

	Strong = {
		name = "Strong",
		displayName = "Strong",
		rarity = "Uncommon",
		icon = "+",
		description = "+25% power",
		powerMult = 1.25,
		coinMult = 1.0,
		speedMult = 1.0,
		color = Color3.fromRGB(255, 170, 80),
		visualEffect = "glow",
		weight = 18,
	},

	Magnetic = {
		name = "Magnetic",
		displayName = "Magnetic",
		rarity = "Uncommon",
		icon = "M",
		description = "+15% color, +10% coins",
		powerMult = 1.0,
		coinMult = 1.1,
		colorMult = 1.15,
		speedMult = 1.0,
		color = Color3.fromRGB(120, 255, 180),
		visualEffect = "glow",
		weight = 16,
	},

	Golden = {
		name = "Golden",
		displayName = "Golden",
		rarity = "Rare",
		icon = "$",
		description = "+35% coins",
		powerMult = 1.0,
		coinMult = 1.35,
		speedMult = 1.0,
		color = Color3.fromRGB(255, 215, 80),
		visualEffect = "spark",
		weight = 10,
	},

	Lucky = {
		name = "Lucky",
		displayName = "Lucky",
		rarity = "Rare",
		icon = "?",
		description = "+20% power, +20% coins",
		powerMult = 1.2,
		coinMult = 1.2,
		speedMult = 1.0,
		color = Color3.fromRGB(140, 255, 145),
		visualEffect = "spark",
		weight = 8,
	},

	Giant = {
		name = "Giant",
		displayName = "Giant",
		rarity = "Epic",
		icon = "^",
		description = "+60% power",
		powerMult = 1.6,
		coinMult = 1.0,
		speedMult = 0.95,
		sizeScale = 1.35,
		color = Color3.fromRGB(210, 140, 255),
		visualEffect = "giant",
		weight = 5,
	},

	Tiny = {
		name = "Tiny",
		displayName = "Tiny",
		rarity = "Epic",
		icon = ".",
		description = "+35% speed, +20% coins",
		powerMult = 0.9,
		coinMult = 1.2,
		speedMult = 1.35,
		sizeScale = 0.78,
		color = Color3.fromRGB(255, 170, 220),
		visualEffect = "spark",
		weight = 5,
	},

	Electric = {
		name = "Electric",
		displayName = "Electric",
		rarity = "Epic",
		icon = "!",
		description = "+45% power, +20% speed",
		powerMult = 1.45,
		coinMult = 1.0,
		speedMult = 1.2,
		color = Color3.fromRGB(90, 235, 255),
		visualEffect = "electric",
		weight = 4,
	},

	Rainbow = {
		name = "Rainbow",
		displayName = "Rainbow",
		rarity = "Legendary",
		icon = "*",
		description = "+75% power, +75% coins",
		powerMult = 1.75,
		coinMult = 1.75,
		speedMult = 1.15,
		color = Color3.fromRGB(255, 255, 120),
		visualEffect = "rainbow",
		weight = 2,
	},

	Celestial = {
		name = "Celestial",
		displayName = "Celestial",
		rarity = "Legendary",
		icon = "C",
		description = "+100% power, +50% coins",
		powerMult = 2.0,
		coinMult = 1.5,
		speedMult = 1.05,
		color = Color3.fromRGB(150, 215, 255),
		visualEffect = "celestial",
		weight = 1,
	},
}

PetTraits.ShinyChance = 0.02

function PetTraits.getTrait(traitId)
	return PetTraits.Traits[traitId]
end

function PetTraits.getEffectivePower(basePower, trait)
	local power = tonumber(basePower) or 0
	if not trait then
		return power
	end

	local mult = trait.powerMult or trait.multiplier or 1
	return math.floor(power * mult)
end

function PetTraits.rollShiny(luckMult)
	luckMult = tonumber(luckMult) or 1
	return math.random() < math.min(0.12, PetTraits.ShinyChance * luckMult)
end

function PetTraits.rollTrait(luckMult)
	luckMult = tonumber(luckMult) or 1

	local noTraitWeight = math.max(20, 45 / luckMult)
	local totalWeight = noTraitWeight

	for _, trait in pairs(PetTraits.Traits) do
		totalWeight += trait.weight or 0
	end

	local roll = math.random() * totalWeight
	if roll <= noTraitWeight then
		return nil
	end

	roll -= noTraitWeight
	for _, trait in pairs(PetTraits.Traits) do
		roll -= trait.weight or 0
		if roll <= 0 then
			return trait
		end
	end

	return nil
end

return PetTraits
