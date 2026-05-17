local RankDefinitions = {}

RankDefinitions.MaxRank = 5

RankDefinitions.XP = {
	Coins = 0.1,
	Gems = 2,
}

RankDefinitions.Rebirth = {
	PetDamageMultiplier = 1.1,
	RewardMultiplier = 1.05,
	EggLuckMultiplier = 1.05,
}

RankDefinitions.Ranks = {
	[1] = {
		Name = "Beginner Cleaner",
		Icon = "1",
		XPRequired = 250,
		QuestsRequired = 10,
		RewardCoins = 0,
		RewardGems = 0,
		Passives = {
			PetDamageMultiplier = 1,
			RewardMultiplier = 1,
			EggLuckMultiplier = 1,
			MutationChanceMultiplier = 1,
		},
	},
	[2] = {
		Name = "Color Scrubber",
		Icon = "2",
		XPRequired = 750,
		QuestsRequired = 10,
		RewardCoins = 500,
		RewardGems = 50,
		Passives = {
			PetDamageMultiplier = 1.1,
			RewardMultiplier = 1.05,
			EggLuckMultiplier = 1,
			MutationChanceMultiplier = 1,
		},
	},
	[3] = {
		Name = "Core Hunter",
		Icon = "3",
		XPRequired = 2000,
		QuestsRequired = 10,
		RewardCoins = 2500,
		RewardGems = 200,
		Passives = {
			PetDamageMultiplier = 1.2,
			RewardMultiplier = 1.1,
			EggLuckMultiplier = 1.05,
			MutationChanceMultiplier = 1,
		},
	},
	[4] = {
		Name = "Mutation Seeker",
		Icon = "4",
		XPRequired = 5000,
		QuestsRequired = 10,
		RewardCoins = 10000,
		RewardGems = 750,
		Passives = {
			PetDamageMultiplier = 1.35,
			RewardMultiplier = 1.15,
			EggLuckMultiplier = 1.1,
			MutationChanceMultiplier = 1.05,
		},
	},
	[5] = {
		Name = "Color Master",
		Icon = "5",
		XPRequired = 10000,
		QuestsRequired = 10,
		RewardCoins = 30000,
		RewardGems = 2000,
		Passives = {
			PetDamageMultiplier = 1.5,
			RewardMultiplier = 1.25,
			EggLuckMultiplier = 1.2,
			MutationChanceMultiplier = 1.1,
		},
	},
}

local function quest(id, text, kind, target, extra)
	local data = extra or {}
	data.Id = id
	data.Text = text
	data.Kind = kind
	data.Target = target
	return data
end

RankDefinitions.Quests = {
	[1] = {
		quest("spill_5", "Break 5 Color Spills", "BreakableType", 5, { BreakableType = "ColorSpill" }),
		quest("clump_3", "Break 3 Color Clumps", "BreakableType", 3, { BreakableType = "ColorClump" }),
		quest("crate_1", "Break 1 Color Crate", "BreakableType", 1, { BreakableType = "ColorCrate" }),
		quest("coins_250", "Collect 250 Coins", "Coins", 250),
		quest("gems_25", "Collect 25 Gems", "Gems", 25),
		quest("hatch_1", "Hatch 1 Color", "Hatch", 1),
		quest("equip_1", "Equip 1 Color", "EquipColor", 1),
		quest("break_10", "Break 10 total breakables", "BreakableAny", 10),
		quest("coins_500", "Collect 500 Coins", "Coins", 500),
		quest("chest_1", "Break 1 Color Chest", "BreakableType", 1, { BreakableType = "ColorChest" }),
	},
	[2] = {
		quest("spill_15", "Break 15 Color Spills", "BreakableType", 15, { BreakableType = "ColorSpill" }),
		quest("clump_10", "Break 10 Color Clumps", "BreakableType", 10, { BreakableType = "ColorClump" }),
		quest("crate_5", "Break 5 Color Crates", "BreakableType", 5, { BreakableType = "ColorCrate" }),
		quest("chest_3", "Break 3 Color Chests", "BreakableType", 3, { BreakableType = "ColorChest" }),
		quest("coins_1500", "Collect 1,500 Coins", "Coins", 1500),
		quest("gems_100", "Collect 100 Gems", "Gems", 100),
		quest("hatch_5", "Hatch 5 Colors", "Hatch", 5),
		quest("rare_hatch_1", "Hatch 1 Rare or better Color", "HatchRarityAtLeast", 1, { Rarity = "Rare" }),
		quest("break_40", "Break 40 total breakables", "BreakableAny", 40),
		quest("rankxp_750", "Earn 750 Rank XP", "RankXP", 750),
	},
	[3] = {
		quest("spill_30", "Break 30 Color Spills", "BreakableType", 30, { BreakableType = "ColorSpill" }),
		quest("clump_20", "Break 20 Color Clumps", "BreakableType", 20, { BreakableType = "ColorClump" }),
		quest("crate_15", "Break 15 Color Crates", "BreakableType", 15, { BreakableType = "ColorCrate" }),
		quest("chest_8", "Break 8 Color Chests", "BreakableType", 8, { BreakableType = "ColorChest" }),
		quest("huge_1", "Break 1 Huge Color Chest", "BreakableType", 1, { BreakableType = "HugeColorChest" }),
		quest("coins_5000", "Collect 5,000 Coins", "Coins", 5000),
		quest("gems_300", "Collect 300 Gems", "Gems", 300),
		quest("hatch_15", "Hatch 15 Colors", "Hatch", 15),
		quest("epic_hatch_1", "Hatch 1 Epic or better Color", "HatchRarityAtLeast", 1, { Rarity = "Epic" }),
		quest("rankxp_2000", "Earn 2,000 Rank XP", "RankXP", 2000),
	},
	[4] = {
		quest("spill_60", "Break 60 Color Spills", "BreakableType", 60, { BreakableType = "ColorSpill" }),
		quest("clump_40", "Break 40 Color Clumps", "BreakableType", 40, { BreakableType = "ColorClump" }),
		quest("crate_25", "Break 25 Color Crates", "BreakableType", 25, { BreakableType = "ColorCrate" }),
		quest("chest_15", "Break 15 Color Chests", "BreakableType", 15, { BreakableType = "ColorChest" }),
		quest("huge_3", "Break 3 Huge Color Chests", "BreakableType", 3, { BreakableType = "HugeColorChest" }),
		quest("coins_15000", "Collect 15,000 Coins", "Coins", 15000),
		quest("gems_1000", "Collect 1,000 Gems", "Gems", 1000),
		quest("hatch_40", "Hatch 40 Colors", "Hatch", 40),
		quest(
			"legendary_hatch_1",
			"Hatch 1 Legendary or better Color",
			"HatchRarityAtLeast",
			1,
			{ Rarity = "Legendary" }
		),
		quest("rankxp_5000", "Earn 5,000 Rank XP", "RankXP", 5000),
	},
	[5] = {
		quest("spill_100", "Break 100 Color Spills", "BreakableType", 100, { BreakableType = "ColorSpill" }),
		quest("clump_75", "Break 75 Color Clumps", "BreakableType", 75, { BreakableType = "ColorClump" }),
		quest("crate_50", "Break 50 Color Crates", "BreakableType", 50, { BreakableType = "ColorCrate" }),
		quest("chest_25", "Break 25 Color Chests", "BreakableType", 25, { BreakableType = "ColorChest" }),
		quest("huge_5", "Break 5 Huge Color Chests", "BreakableType", 5, { BreakableType = "HugeColorChest" }),
		quest(
			"giant_1",
			"Break 1 Giant Color Core Chest",
			"BreakableType",
			1,
			{ BreakableType = "GiantColorCoreChest" }
		),
		quest("coins_50000", "Collect 50,000 Coins", "Coins", 50000),
		quest("gems_3000", "Collect 3,000 Gems", "Gems", 3000),
		quest("hatch_100", "Hatch 100 Colors", "Hatch", 100),
		quest("mythic_hatch_1", "Hatch 1 Mythic or better Color", "HatchRarityAtLeast", 1, { Rarity = "Mythic" }),
	},
}

RankDefinitions.RarityOrder = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	Legendary = 5,
	Mythic = 6,
	Secret = 7,
}

function RankDefinitions.GetRank(rank)
	return RankDefinitions.Ranks[math.clamp(math.floor(tonumber(rank) or 1), 1, RankDefinitions.MaxRank)]
end

function RankDefinitions.GetQuests(rank)
	return RankDefinitions.Quests[math.clamp(math.floor(tonumber(rank) or 1), 1, RankDefinitions.MaxRank)] or {}
end

function RankDefinitions.IsRarityAtLeast(rarity, minimum)
	return (RankDefinitions.RarityOrder[tostring(rarity or "Common")] or 0)
		>= (RankDefinitions.RarityOrder[tostring(minimum or "Common")] or 0)
end

return RankDefinitions
