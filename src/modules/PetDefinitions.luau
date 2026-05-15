local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ColorData = require(ReplicatedStorage:WaitForChild("ColorData"))
local PetData = require(ReplicatedStorage:WaitForChild("PetData"))

local PetDefinitions = {}

local RARITY_ACCENTS = {
	Common = Color3.fromRGB(185, 190, 205),
	Uncommon = Color3.fromRGB(105, 225, 125),
	Rare = Color3.fromRGB(100, 150, 255),
	Epic = Color3.fromRGB(185, 90, 255),
	Legendary = Color3.fromRGB(255, 214, 76),
}

local WORLD_THEMES = {
	Red = {
		IconColor = Color3.fromRGB(235, 65, 72),
		CardColor = Color3.fromRGB(255, 221, 224),
		AccentColor = Color3.fromRGB(255, 110, 94),
	},
	Orange = {
		IconColor = Color3.fromRGB(255, 145, 45),
		CardColor = Color3.fromRGB(255, 229, 190),
		AccentColor = Color3.fromRGB(255, 190, 76),
	},
	Yellow = {
		IconColor = Color3.fromRGB(255, 232, 70),
		CardColor = Color3.fromRGB(255, 246, 194),
		AccentColor = Color3.fromRGB(255, 205, 58),
	},
	Green = {
		IconColor = Color3.fromRGB(86, 220, 105),
		CardColor = Color3.fromRGB(212, 248, 218),
		AccentColor = Color3.fromRGB(135, 255, 135),
	},
	Neon = {
		IconColor = Color3.fromRGB(42, 245, 225),
		CardColor = Color3.fromRGB(210, 255, 250),
		AccentColor = Color3.fromRGB(78, 185, 255),
	},
	Blue = {
		IconColor = Color3.fromRGB(72, 145, 255),
		CardColor = Color3.fromRGB(218, 236, 255),
		AccentColor = Color3.fromRGB(84, 218, 255),
	},
	Purple = {
		IconColor = Color3.fromRGB(172, 92, 245),
		CardColor = Color3.fromRGB(238, 222, 255),
		AccentColor = Color3.fromRGB(220, 132, 255),
	},
	Rainbow = {
		IconColor = Color3.fromRGB(255, 255, 255),
		CardColor = Color3.fromRGB(226, 212, 255),
		AccentColor = Color3.fromRGB(255, 220, 80),
		UseRainbowGradient = true,
	},
}

local definitionsById = nil
local orderedDefinitions = nil

local function makeModelName(petId, pet)
	return pet.modelName or pet.ModelName or petId
end

local function getEggWorldInfo()
	local infoByPetId = {}
	for _, eggId in ipairs(PetData.EggOrder or {}) do
		local egg = PetData.Eggs and PetData.Eggs[eggId]
		if egg then
			local areaColor = egg.areaColor or "Red"
			local world = ColorData.getWorldByColor(areaColor)
			local worldNumber = ColorData.getWorldIndex(areaColor) or (world and world.order) or 1
			for _, entry in ipairs(egg.pets or {}) do
				infoByPetId[entry.petId] = infoByPetId[entry.petId]
					or {
						AreaColor = areaColor,
						WorldNumber = worldNumber,
						EggId = eggId,
					}
			end
		end
	end
	return infoByPetId
end

local function buildDefinition(petId, pet, eggWorldInfo)
	local eggInfo = eggWorldInfo[petId] or {}
	local areaColor = pet.areaColor or eggInfo.AreaColor or "Red"
	local theme = WORLD_THEMES[areaColor] or WORLD_THEMES.Red
	local rarity = pet.rarity or "Common"
	local petColor = pet.color or theme.IconColor
	local isRainbow = areaColor == "Rainbow"
		or petId == "DevRainbowPet"
		or string.find(string.lower(petId), "rainbow", 1, true) ~= nil

	return {
		Id = petId,
		DisplayName = pet.displayName or petId,
		Rarity = rarity,
		WorldNumber = pet.worldNumber or eggInfo.WorldNumber or 1,
		AreaColor = areaColor,
		EggId = eggInfo.EggId,
		ModelName = makeModelName(petId, pet),
		IconColor = pet.IconColor or pet.iconColor or (isRainbow and Color3.fromRGB(255, 255, 255) or petColor),
		CardColor = pet.CardColor or pet.cardColor or theme.CardColor or petColor:Lerp(Color3.new(1, 1, 1), 0.78),
		AccentColor = pet.AccentColor
			or pet.accentColor
			or (isRainbow and Color3.fromRGB(255, 220, 80) or RARITY_ACCENTS[rarity] or theme.AccentColor or petColor),
		UseRainbowGradient = pet.UseRainbowGradient == true
			or pet.useRainbowGradient == true
			or theme.UseRainbowGradient == true
			or isRainbow,
		BaseColor = petColor,
		IsLegendaryColorOrb = pet.isLegendaryColorOrb == true,
	}
end

local function rebuild()
	local eggWorldInfo = getEggWorldInfo()
	definitionsById = {}
	orderedDefinitions = {}

	for petId, pet in pairs(PetData.Pets or {}) do
		local definition = buildDefinition(petId, pet, eggWorldInfo)
		definitionsById[petId] = definition
		table.insert(orderedDefinitions, definition)
	end

	table.sort(orderedDefinitions, function(a, b)
		if a.WorldNumber == b.WorldNumber then
			if a.Rarity == b.Rarity then
				return a.DisplayName < b.DisplayName
			end
			return tostring(a.Rarity) < tostring(b.Rarity)
		end
		return (a.WorldNumber or 1) < (b.WorldNumber or 1)
	end)
end

function PetDefinitions.Get(petId)
	if PetData.resolvePetId then
		petId = PetData.resolvePetId(petId)
	end
	if not definitionsById then
		rebuild()
	end
	return definitionsById[petId]
end

function PetDefinitions.GetAll()
	if not orderedDefinitions then
		rebuild()
	end
	return orderedDefinitions
end

function PetDefinitions.Rebuild()
	rebuild()
	return orderedDefinitions
end

return PetDefinitions
