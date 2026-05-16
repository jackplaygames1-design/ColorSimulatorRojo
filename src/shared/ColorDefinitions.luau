local ColorDefinitions = {}

ColorDefinitions.Colors = {
	RedDrop = {
		ColorName = "Red Drop",
		Rarity = "Common",
		ColorType = "Red",
		Color = Color3.fromRGB(235, 48, 50),
		BasePower = 45,
	},
	ScarletBlob = {
		ColorName = "Scarlet Blob",
		Rarity = "Uncommon",
		ColorType = "Red",
		Color = Color3.fromRGB(255, 72, 78),
		BasePower = 115,
	},
	RubyOrb = {
		ColorName = "Ruby Orb",
		Rarity = "Rare",
		ColorType = "Red",
		Color = Color3.fromRGB(255, 58, 92),
		BasePower = 420,
	},
	CrimsonPrism = {
		ColorName = "Crimson Prism",
		Rarity = "Epic",
		ColorType = "Red",
		Color = Color3.fromRGB(255, 48, 128),
		BasePower = 1550,
	},
	CrimsonOrb = {
		ColorName = "Crimson Orb",
		Rarity = "Legendary",
		ColorType = "Red",
		Color = Color3.fromRGB(255, 40, 44),
		BasePower = 12400,
	},
	BloodPrism = {
		ColorName = "Blood Prism",
		Rarity = "Mythic",
		ColorType = "Red",
		Color = Color3.fromRGB(255, 30, 88),
		BasePower = 110000,
	},
	ErrorCrimson = {
		ColorName = "Error Crimson",
		Rarity = "Secret",
		ColorType = "Red",
		Color = Color3.fromRGB(255, 8, 8),
		BasePower = 1000000,
	},
}

ColorDefinitions.CorePools = {
	RedCore = {
		Common = { "RedDrop" },
		Uncommon = { "ScarletBlob" },
		Rare = { "RubyOrb" },
		Epic = { "CrimsonPrism" },
		Legendary = { "CrimsonOrb" },
		Mythic = { "BloodPrism" },
		Secret = { "ErrorCrimson" },
	},
}

function ColorDefinitions.Get(colorId)
	return ColorDefinitions.Colors[tostring(colorId or "")]
end

function ColorDefinitions.GetDisplayName(colorId)
	local data = ColorDefinitions.Get(colorId)
	return data and data.ColorName or tostring(colorId or "Unknown Color")
end

function ColorDefinitions.GetColorForRarity(coreId, rarity, rng)
	local pool = ColorDefinitions.CorePools[tostring(coreId or "")] or ColorDefinitions.CorePools.RedCore
	local choices = pool and pool[tostring(rarity or "")]
	if type(choices) ~= "table" or #choices == 0 then
		return "RedDrop", ColorDefinitions.Colors.RedDrop
	end

	local index = typeof(rng) == "Random" and rng:NextInteger(1, #choices) or math.random(1, #choices)
	local colorId = choices[index]
	return colorId, ColorDefinitions.Colors[colorId]
end

return ColorDefinitions
