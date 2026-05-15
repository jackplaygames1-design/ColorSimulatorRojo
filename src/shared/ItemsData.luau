-- ModuleScript in ReplicatedStorage named "ItemsData"
local ItemsData = {}

ItemsData.Rarities = {
	Common = { color = Color3.fromRGB(180, 180, 180), order = 1 },
	Uncommon = { color = Color3.fromRGB(80, 200, 80), order = 2 },
	Rare = { color = Color3.fromRGB(80, 120, 255), order = 3 },
	Epic = { color = Color3.fromRGB(180, 60, 255), order = 4 },
	Legendary = { color = Color3.fromRGB(255, 200, 0), order = 5 },
	Mythic = { color = Color3.fromRGB(255, 60, 60), order = 6 },
	Event = { color = Color3.fromRGB(255, 140, 0), order = 7 },
}

ItemsData.Items = {
	LuckPotion = {
		displayName = "Luck Potion",
		icon = "LK",
		rarity = "Uncommon",
		category = "Boosts",
		description = "Doubles your egg luck for 10 minutes.",
		usable = true,
		boostType = "luck",
		boostDuration = 600,
	},
	CoinPotion = {
		displayName = "Coin Potion",
		icon = "CO",
		rarity = "Common",
		category = "Boosts",
		description = "2x coins earned for 10 minutes.",
		usable = true,
		boostType = "coins",
		boostDuration = 600,
	},
	HatchPotion = {
		displayName = "Hatch Speed Potion",
		icon = "HS",
		rarity = "Rare",
		category = "Boosts",
		description = "Hatch eggs 50% faster for 15 minutes.",
		usable = true,
		boostType = "hatch",
		boostDuration = 900,
	},
	SpeedPotion = {
		displayName = "Speed Potion",
		icon = "SP",
		rarity = "Common",
		category = "Boosts",
		description = "Move 30% faster for 10 minutes.",
		usable = true,
		boostType = "speed",
		boostDuration = 600,
	},
	RangePotion = {
		displayName = "Range Potion",
		icon = "RG",
		rarity = "Uncommon",
		category = "Boosts",
		description = "Increase pickup range for 10 minutes.",
		usable = true,
		boostType = "range",
		boostDuration = 600,
	},

	TripleHatchTicket = {
		displayName = "Triple Hatch Ticket",
		icon = "3X",
		rarity = "Rare",
		category = "Items",
		description = "Hatch 3 eggs at once!",
		usable = true,
	},
	RainbowKey = {
		displayName = "Rainbow Key",
		icon = "RK",
		rarity = "Epic",
		category = "Items",
		description = "Opens a Rainbow Chest for amazing rewards.",
		usable = true,
	},
	EventToken = {
		displayName = "Event Token",
		icon = "EV",
		rarity = "Event",
		category = "Items",
		description = "Used to purchase exclusive event items.",
		usable = false,
	},

	MysteryCrate = {
		displayName = "Mystery Crate",
		icon = "CR",
		rarity = "Uncommon",
		category = "Items",
		description = "Contains a random assortment of items.",
		usable = true,
	},

	ColorDust = {
		displayName = "Color Dust",
		icon = "CD",
		rarity = "Common",
		category = "Materials",
		description = "Used in crafting and upgrades.",
		usable = false,
	},
	FusionGem = {
		displayName = "Fusion Gem",
		icon = "FG",
		rarity = "Rare",
		category = "Materials",
		description = "Required for fusing high-tier Colors.",
		usable = false,
	},
	UpgradeCrystal = {
		displayName = "Upgrade Crystal",
		icon = "UC",
		rarity = "Uncommon",
		category = "Materials",
		description = "Used to upgrade Color power.",
		usable = false,
	},
	PetEssence = {
		displayName = "Color Essence",
		icon = "PE",
		rarity = "Epic",
		category = "Materials",
		description = "Extracted from rare Colors. Highly valuable.",
		usable = false,
	},
	PaintShard = {
		displayName = "Paint Shard",
		icon = "PS",
		rarity = "Common",
		category = "Materials",
		description = "Fragments of solidified color energy.",
		usable = false,
	},

	StarterHoverboard = {
		displayName = "Starter Hoverboard",
		icon = "HB",
		rarity = "Rare",
		category = "Hoverboards",
		description = "A cosmetic board slot for future movement cosmetics.",
		usable = false,
	},
	PaintBooth = {
		displayName = "Paint Booth",
		icon = "BT",
		rarity = "Uncommon",
		category = "Booths",
		description = "A cosmetic booth skin slot for future trading and booth features.",
		usable = false,
	},
	PowerEnchant = {
		displayName = "Power Enchant",
		icon = "EN",
		rarity = "Epic",
		category = "Enchants",
		description = "An enchant collectible slot for future Color buffs.",
		usable = false,
	},
	ExclusiveTicket = {
		displayName = "Exclusive Ticket",
		icon = "EX",
		rarity = "Legendary",
		category = "Exclusives",
		description = "A rare collectible slot for exclusive rewards.",
		usable = false,
	},
}

function ItemsData.formatNum(n)
	n = tonumber(n) or 0
	if n >= 1000000 then
		return string.format("%.1fM", n / 1000000)
	elseif n >= 1000 then
		return string.format("%.1fK", n / 1000)
	end
	return tostring(n)
end

return ItemsData
