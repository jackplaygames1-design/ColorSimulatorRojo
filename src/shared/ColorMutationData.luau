local ColorMutationData = {}

ColorMutationData.NoneId = "None"

local TYPE_COLORS = {
	Dark = Color3.fromRGB(92, 42, 155),
	Light = Color3.fromRGB(255, 222, 94),
	Corrupted = Color3.fromRGB(255, 42, 84),
	None = Color3.fromRGB(210, 220, 235),
}

local TYPE_AURAS = {
	Dark = Color3.fromRGB(72, 25, 125),
	Light = Color3.fromRGB(255, 238, 155),
	Corrupted = Color3.fromRGB(255, 30, 72),
	None = Color3.fromRGB(210, 220, 235),
}

local RARITY_POWER = {
	Common = 1.18,
	Rare = 1.55,
	Legendary = 2.35,
}

local RARITY_SORT = {
	Common = 10,
	Rare = 20,
	Legendary = 30,
}

local NO_MUTATION_WEIGHT = 26000

local rows = {
	-- Dark
	{
		"Dark",
		"Common",
		"Shadowed",
		"Shadowed",
		"Dark body, black mist, glowing eyes",
		"+15% Coins",
		"dark_smoke",
		"coins_boost",
		120,
	},
	{
		"Dark",
		"Common",
		"Smokefused",
		"Smokefused",
		"Smoke trails, ash particles",
		"+10% Item Drops",
		"dark_smoke",
		"item_drops",
		120,
	},
	{
		"Dark",
		"Common",
		"Oilspill",
		"Oilspill",
		"Oily rainbow-black reflections",
		"+20% Spill Coins",
		"dark_oil",
		"spill_coins",
		120,
	},
	{
		"Dark",
		"Common",
		"Obsidian",
		"Obsidian",
		"Black crystal shell, spikes",
		"+12% Damage",
		"dark_crystal",
		"damage",
		120,
	},
	{
		"Dark",
		"Common",
		"Eclipse",
		"Eclipse",
		"Floating black ring, dark rimlight",
		"+15% Pickup Radius",
		"dark_eclipse",
		"pickup_radius",
		120,
	},
	{
		"Dark",
		"Common",
		"Duskborn",
		"Duskborn",
		"Purple-black fading glow",
		"+10% Coins & Drops",
		"dark_glow",
		"coins_drops",
		120,
	},
	{
		"Dark",
		"Common",
		"Grim",
		"Grim",
		"Shadow aura, dim pulse",
		"+5% Critical Hits",
		"dark_pulse",
		"crit_chance",
		120,
	},
	{
		"Dark",
		"Common",
		"Inkblot",
		"Inkblot",
		"Ink drips, dark splashes",
		"Faster Spill Breaking",
		"dark_drips",
		"break_speed",
		120,
	},
	{
		"Dark",
		"Rare",
		"Abyssal",
		"Abyssal",
		"Void texture, orbiting debris",
		"+40% Coins",
		"dark_void",
		"coins_boost",
		24,
	},
	{
		"Dark",
		"Rare",
		"Nightmare",
		"Nightmare",
		"Distorted face, smoke wings",
		"Chance to instantly destroy weak spills",
		"dark_wings",
		"instant_weak_spill",
		24,
	},
	{
		"Dark",
		"Rare",
		"Reaper",
		"Reaper",
		"Shadow cloak, red eyes",
		"Bonus Loot Drops",
		"dark_reaper",
		"bonus_loot",
		24,
	},
	{
		"Dark",
		"Rare",
		"Voidburn",
		"Voidburn",
		"Black flames, ember sparks",
		"Combo Coin Multiplier",
		"dark_flames",
		"combo_coins",
		24,
	},
	{
		"Dark",
		"Rare",
		"CursedGold",
		"Cursed Gold",
		"Black/gold molten cracks",
		"+75% Coins",
		"dark_gold",
		"coins_boost",
		24,
	},
	{
		"Dark",
		"Rare",
		"Darkmatter",
		"Darkmatter",
		"Floating gravity particles",
		"Pulls Nearby Coins",
		"dark_gravity",
		"reward_pull",
		24,
	},
	{ "Dark", "Rare", "Hollow", "Hollow", "Empty glowing core", "Bonus Drop Chance", "dark_hollow", "drop_chance", 24 },
	{
		"Dark",
		"Rare",
		"Hexed",
		"Hexed",
		"Floating curse symbols",
		"Temporary Coin Bursts",
		"dark_runes",
		"coin_bursts",
		24,
	},
	{
		"Dark",
		"Legendary",
		"BlackHole",
		"Black Hole",
		"Mini black hole core",
		"Pulls All Nearby Rewards",
		"dark_black_hole",
		"reward_vacuum",
		3,
	},
	{
		"Dark",
		"Legendary",
		"Cataclysm",
		"Cataclysm",
		"Chaotic dark lightning",
		"Double Loot Explosions",
		"dark_lightning",
		"double_loot_explosions",
		3,
	},
	{
		"Dark",
		"Legendary",
		"Deathcore",
		"Deathcore",
		"Skeletal glow, giant smoke aura",
		"Spill Chain Explosions",
		"dark_deathcore",
		"chain_explosions",
		3,
	},
	{
		"Dark",
		"Legendary",
		"EternalNight",
		"Eternal Night",
		"Massive eclipse aura",
		"Huge Coin Multiplier",
		"dark_eclipse_massive",
		"huge_coins",
		3,
	},
	{
		"Dark",
		"Legendary",
		"Doomflare",
		"Doomflare",
		"Dark firestorm effects",
		"Massive Item Drop Bonus",
		"dark_firestorm",
		"massive_drops",
		3,
	},

	-- Light
	{
		"Light",
		"Common",
		"Glimmer",
		"Glimmer",
		"Sparkles, soft glow",
		"+15% Gems",
		"light_sparkles",
		"gems_boost",
		120,
	},
	{ "Light", "Common", "Angelic", "Angelic", "Halo, white aura", "+10% Speed", "light_halo", "speed", 120 },
	{
		"Light",
		"Common",
		"Radiant",
		"Radiant",
		"Light rays, bloom glow",
		"+20% Crystal Gems",
		"light_rays",
		"crystal_gems",
		120,
	},
	{ "Light", "Common", "Prism", "Prism", "Rainbow refraction", "+10% Luck", "light_prism", "luck", 120 },
	{
		"Light",
		"Common",
		"Starlit",
		"Starlit",
		"Orbiting stars",
		"+15% Gem Spawn Chance",
		"light_stars",
		"gem_spawn",
		120,
	},
	{
		"Light",
		"Common",
		"Luminous",
		"Luminous",
		"Bright neon glow",
		"Slight Gem Boost",
		"light_glow",
		"gems_boost",
		120,
	},
	{
		"Light",
		"Common",
		"Dawnkissed",
		"Dawnkissed",
		"Warm sunrise glow",
		"+5% Everything",
		"light_dawn",
		"everything",
		120,
	},
	{
		"Light",
		"Common",
		"Shimmering",
		"Shimmering",
		"Glitter trails",
		"Faster Pickup Collection",
		"light_trails",
		"pickup_speed",
		120,
	},
	{
		"Light",
		"Rare",
		"Celestial",
		"Celestial",
		"Constellations orbiting",
		"+50% Gems",
		"light_constellation",
		"gems_boost",
		24,
	},
	{
		"Light",
		"Rare",
		"Divine",
		"Divine",
		"Holy glow, floating runes",
		"Buffs Nearby Players",
		"light_runes",
		"support_buff",
		24,
	},
	{ "Light", "Rare", "Solar", "Solar", "Mini sun aura", "Random Double Gems", "light_sun", "double_gems", 24 },
	{
		"Light",
		"Rare",
		"Aurora",
		"Aurora",
		"Northern lights flowing",
		"Better Rare Mutation Odds",
		"light_aurora",
		"mutation_luck",
		24,
	},
	{
		"Light",
		"Rare",
		"Diamondborn",
		"Diamondborn",
		"Crystal body, intense sparkles",
		"+100% Gems",
		"light_diamond",
		"gems_boost",
		24,
	},
	{
		"Light",
		"Rare",
		"Heavenlit",
		"Heavenlit",
		"Floating feather particles",
		"Increased Luck",
		"light_feathers",
		"luck",
		24,
	},
	{
		"Light",
		"Rare",
		"Pearlescent",
		"Pearlescent",
		"Soft iridescent shell",
		"Better Egg Rewards",
		"light_pearl",
		"egg_rewards",
		24,
	},
	{
		"Light",
		"Rare",
		"Moonblessed",
		"Moonblessed",
		"Pale moon aura",
		"Nighttime Buffs",
		"light_moon",
		"night_buff",
		24,
	},
	{
		"Light",
		"Legendary",
		"Ascended",
		"Ascended",
		"Giant radiant aura",
		"Massive Gem Boost",
		"light_ascended",
		"massive_gems",
		3,
	},
	{
		"Light",
		"Legendary",
		"Ethereal",
		"Ethereal",
		"Transparent flowing energy",
		"Auto Collect Nearby Gems",
		"light_ethereal",
		"auto_collect_gems",
		3,
	},
	{
		"Light",
		"Legendary",
		"Heavenstorm",
		"Heavenstorm",
		"Holy lightning clouds",
		"Random Gem Storms",
		"light_storm",
		"gem_storms",
		3,
	},
	{
		"Light",
		"Legendary",
		"Godlight",
		"Godlight",
		"Blinding divine glow",
		"Huge Luck Boost",
		"light_godlight",
		"huge_luck",
		3,
	},
	{
		"Light",
		"Legendary",
		"Seraphic",
		"Seraphic",
		"Giant angelic energy wings",
		"Massive Support Buffs",
		"light_wings",
		"massive_support",
		3,
	},

	-- Corrupted
	{
		"Corrupted",
		"Common",
		"Glitched",
		"Glitched",
		"RGB flickers, screen tearing",
		"Hits 2 Spills",
		"corrupted_glitch",
		"multi_hit_2",
		45,
	},
	{
		"Corrupted",
		"Common",
		"Fractured",
		"Fractured",
		"Cracked geometry, floating shards",
		"Loot Explosions",
		"corrupted_shards",
		"loot_explosions",
		45,
	},
	{
		"Corrupted",
		"Common",
		"Chaotic",
		"Chaotic",
		"Random flashing colors",
		"Random Buff Cycles",
		"corrupted_chaos",
		"random_buffs",
		45,
	},
	{
		"Corrupted",
		"Common",
		"Static",
		"Static",
		"TV static effects",
		"Chain Damage",
		"corrupted_static",
		"chain_damage",
		45,
	},
	{
		"Corrupted",
		"Common",
		"Mutagenic",
		"Mutagenic",
		"Bubbling mutation blobs",
		"Duplicate Drops Chance",
		"corrupted_bubbles",
		"duplicate_drops",
		45,
	},
	{
		"Corrupted",
		"Common",
		"Scrambled",
		"Scrambled",
		"Distorted textures",
		"Random Stat Swaps",
		"corrupted_scramble",
		"stat_swaps",
		45,
	},
	{
		"Corrupted",
		"Common",
		"Bugged",
		"Bugged",
		"Broken particles, stuttering motion",
		"Speed Bursts",
		"corrupted_bugged",
		"speed_bursts",
		45,
	},
	{
		"Corrupted",
		"Common",
		"Corruptcode",
		"Corruptcode",
		"Matrix-style symbols",
		"Random Coin Spikes",
		"corrupted_code",
		"coin_spikes",
		45,
	},
	{
		"Corrupted",
		"Rare",
		"Overloaded",
		"Overloaded",
		"Massive unstable energy",
		"Hits 3 Spills",
		"corrupted_overload",
		"multi_hit_3",
		8,
	},
	{
		"Corrupted",
		"Rare",
		"Virus",
		"Virus",
		"Digital corruption spread",
		"Spreads Damage",
		"corrupted_virus",
		"spreading_damage",
		8,
	},
	{
		"Corrupted",
		"Rare",
		"BrokenReality",
		"Broken Reality",
		"Space distortion",
		"Duplicate Coins & Gems",
		"corrupted_reality",
		"duplicate_rewards",
		8,
	},
	{
		"Corrupted",
		"Rare",
		"Riftborn",
		"Riftborn",
		"Dimensional tears",
		"Teleports Between Spills",
		"corrupted_rift",
		"spill_teleport",
		8,
	},
	{
		"Corrupted",
		"Rare",
		"Hyperglitch",
		"Hyperglitch",
		"Violent RGB snapping",
		"Huge Attack Speed",
		"corrupted_hyper",
		"huge_attack_speed",
		8,
	},
	{
		"Corrupted",
		"Rare",
		"Malformed",
		"Malformed",
		"Twisted geometry",
		"Massive Random Multipliers",
		"corrupted_malformed",
		"random_multipliers",
		8,
	},
	{
		"Corrupted",
		"Rare",
		"Errorbound",
		"Errorbound",
		"Missing textures flicker",
		"Bonus Loot Bursts",
		"corrupted_error",
		"loot_bursts",
		8,
	},
	{
		"Corrupted",
		"Rare",
		"SystemFailure",
		"System Failure",
		"UI glitch aura",
		"Random Mega Crits",
		"corrupted_system",
		"mega_crits",
		8,
	},
	{
		"Corrupted",
		"Legendary",
		"Anomaly",
		"Anomaly",
		"Impossible geometry",
		"Hits All Nearby Spills",
		"corrupted_anomaly",
		"hit_all_nearby",
		1,
	},
	{
		"Corrupted",
		"Legendary",
		"Singularity",
		"Singularity",
		"Glitch black hole fusion",
		"Vacuums Rewards",
		"corrupted_singularity",
		"reward_vacuum",
		1,
	},
	{
		"Corrupted",
		"Legendary",
		"Error404",
		"Error 404",
		"Missing texture chaos",
		"Huge Random Multipliers",
		"corrupted_404",
		"huge_random_multipliers",
		1,
	},
	{
		"Corrupted",
		"Legendary",
		"OmegaCorruption",
		"Omega Corruption",
		"Giant corruption storm",
		"Attacks Entire Groups",
		"corrupted_omega",
		"group_attack",
		1,
	},
	{
		"Corrupted",
		"Legendary",
		"RealityCollapse",
		"Reality Collapse",
		"Space collapsing inward",
		"Massive AOE Destruction",
		"corrupted_collapse",
		"massive_aoe",
		1,
	},
}

local function makeStats(mutationType, rarity, specialEffect)
	local stats = {}
	local common = rarity == "Common"
	local rare = rarity == "Rare"
	local legendary = rarity == "Legendary"

	if mutationType == "Dark" then
		if specialEffect == "coins_boost" then
			stats.SellCoinsMultiplier = common and 1.15 or rare and 1.4 or 2.2
		elseif specialEffect == "spill_coins" then
			stats.SellCoinsMultiplier = common and 1.2 or 1.45
			stats.ColorGainMultiplier = common and 1.08 or 1.16
		elseif specialEffect == "item_drops" or specialEffect == "bonus_loot" or specialEffect == "drop_chance" then
			stats.ItemDropMultiplier = common and 1.10 or 1.35
		elseif specialEffect == "massive_drops" then
			stats.ItemDropMultiplier = 2.25
		elseif specialEffect == "damage" then
			stats.PowerMultiplier = common and 1.12 or 1.35
		elseif specialEffect == "pickup_radius" then
			stats.BrushRangeMultiplier = common and 1.15 or 1.35
		elseif specialEffect == "coins_drops" then
			stats.SellCoinsMultiplier = 1.10
			stats.ItemDropMultiplier = 1.10
		elseif specialEffect == "crit_chance" then
			stats.CritChanceBonus = 0.05
		elseif specialEffect == "break_speed" then
			stats.BrushCooldownMultiplier = 0.90
			stats.PowerMultiplier = 1.08
		elseif specialEffect == "instant_weak_spill" then
			stats.InstantWeakSpillChance = 0.08
			stats.PowerMultiplier = 1.28
		elseif specialEffect == "combo_coins" then
			stats.SellCoinsMultiplier = 1.3
			stats.ComboCoinMultiplier = 1.25
		elseif specialEffect == "reward_pull" or specialEffect == "reward_vacuum" then
			stats.MagnetProcChance = legendary and 0.25 or 0.12
			stats.MagnetTargets = legendary and 5 or 3
			stats.MagnetRange = legendary and 55 or 38
		elseif specialEffect == "coin_bursts" then
			stats.SellCoinsMultiplier = 1.22
			stats.CoinBurstChance = 0.08
		elseif specialEffect == "double_loot_explosions" or specialEffect == "chain_explosions" then
			stats.ItemDropMultiplier = 1.8
			stats.LightningProcChance = 0.2
			stats.LightningTargets = 3
			stats.LightningRange = 46
			stats.LightningCooldown = 2.5
		elseif specialEffect == "huge_coins" then
			stats.SellCoinsMultiplier = 2.5
		end
	elseif mutationType == "Light" then
		if specialEffect == "gems_boost" then
			stats.GemRewardMultiplier = common and 1.15 or rare and 1.5 or 2.35
		elseif specialEffect == "crystal_gems" then
			stats.GemRewardMultiplier = 1.2
		elseif specialEffect == "speed" then
			stats.WalkSpeedMultiplier = 1.10
			stats.BrushCooldownMultiplier = 0.95
		elseif specialEffect == "luck" then
			stats.HatchLuckBonus = rare and 0.12 or 0.08
		elseif specialEffect == "huge_luck" then
			stats.HatchLuckBonus = 0.28
			stats.HatchLuckMultiplier = 1.12
		elseif specialEffect == "gem_spawn" then
			stats.GemSpawnChanceMultiplier = 1.15
		elseif specialEffect == "everything" then
			stats.SellCoinsMultiplier = 1.05
			stats.GemRewardMultiplier = 1.05
			stats.PowerMultiplier = 1.05
			stats.HatchLuckBonus = 0.02
		elseif specialEffect == "pickup_speed" then
			stats.BrushRangeMultiplier = 1.10
			stats.BrushCooldownMultiplier = 0.94
		elseif specialEffect == "double_gems" then
			stats.GemRewardMultiplier = 1.3
			stats.DoubleGemChance = 0.08
		elseif specialEffect == "mutation_luck" then
			stats.MutationLuckMultiplier = 1.2
		elseif specialEffect == "egg_rewards" then
			stats.HatchLuckBonus = 0.08
			stats.SellCoinsMultiplier = 1.1
		elseif specialEffect == "auto_collect_gems" then
			stats.GemRewardMultiplier = 1.8
			stats.MagnetProcChance = 0.16
			stats.MagnetTargets = 4
			stats.MagnetRange = 46
		elseif specialEffect == "gem_storms" then
			stats.GemRewardMultiplier = 1.75
			stats.LightningProcChance = 0.18
			stats.LightningTargets = 3
			stats.LightningRange = 45
			stats.LightningCooldown = 2.8
		elseif specialEffect == "support_buff" or specialEffect == "massive_support" then
			stats.WalkSpeedMultiplier = legendary and 1.18 or 1.08
			stats.GemRewardMultiplier = legendary and 1.55 or 1.2
		else
			stats.GemRewardMultiplier = legendary and 2 or rare and 1.35 or 1.1
		end
	elseif mutationType == "Corrupted" then
		stats.PowerMultiplier = common and 1.25 or rare and 1.7 or 2.65
		stats.WalkSpeedMultiplier = common and 0.96 or rare and 0.94 or 0.92
		if specialEffect == "multi_hit_2" then
			stats.LightningProcChance = 0.18
			stats.LightningTargets = 2
		elseif specialEffect == "multi_hit_3" then
			stats.LightningProcChance = 0.24
			stats.LightningTargets = 3
		elseif
			specialEffect == "hit_all_nearby"
			or specialEffect == "group_attack"
			or specialEffect == "massive_aoe"
		then
			stats.LightningProcChance = 0.34
			stats.LightningTargets = 4
			stats.LightningRange = 55
		elseif specialEffect == "chain_damage" or specialEffect == "spreading_damage" then
			stats.LightningProcChance = 0.22
			stats.LightningTargets = 3
		elseif specialEffect == "huge_attack_speed" or specialEffect == "speed_bursts" then
			stats.BrushCooldownMultiplier = rare and 0.78 or 0.88
		elseif specialEffect == "duplicate_rewards" then
			stats.SellCoinsMultiplier = 1.35
			stats.GemRewardMultiplier = 1.35
		elseif specialEffect == "reward_vacuum" then
			stats.MagnetProcChance = 0.28
			stats.MagnetTargets = 5
			stats.MagnetRange = 55
		elseif specialEffect == "random_multipliers" or specialEffect == "huge_random_multipliers" then
			stats.RandomMultiplierCeiling = legendary and 3.5 or 2.2
			stats.SellCoinsMultiplier = legendary and 1.5 or 1.2
		elseif
			specialEffect == "loot_explosions"
			or specialEffect == "loot_bursts"
			or specialEffect == "duplicate_drops"
		then
			stats.ItemDropMultiplier = rare and 1.55 or 1.25
		elseif specialEffect == "coin_spikes" then
			stats.SellCoinsMultiplier = 1.25
			stats.CoinBurstChance = 0.12
		end
		stats.LightningRange = stats.LightningRange or (rare and 42 or common and 34 or 55)
		stats.LightningCooldown = stats.LightningCooldown or (legendary and 2.2 or rare and 2.6 or 3)
	end

	if stats.PowerMultiplier == nil then
		stats.PowerMultiplier = RARITY_POWER[rarity] or 1
	end
	stats.GemDamageMultiplier = stats.GemDamageMultiplier or stats.PowerMultiplier

	return stats
end

local function makeMutation(row, sortOrder)
	local mutationType, rarity, id, displayName, visualTheme, effectText, visualEffect, specialEffect, weight =
		table.unpack(row)
	local stats = makeStats(mutationType, rarity, specialEffect)
	local aura = TYPE_AURAS[mutationType] or TYPE_AURAS.None

	return {
		Id = id,
		DisplayName = displayName,
		Type = mutationType,
		Rarity = rarity,
		Description = effectText .. ".",
		VisualTheme = visualTheme,
		StatModifiers = stats,
		Effects = stats,
		SpecialEffect = specialEffect,
		VisualEffect = visualEffect,
		VisualTag = visualEffect,
		Weight = weight,
		ChanceWeight = weight,
		IsMutation = true,
		PowerMultiplier = stats.PowerMultiplier or 1,
		AuraColor = aura,
		TypeColor = TYPE_COLORS[mutationType] or TYPE_COLORS.None,
		RarityText = rarity .. " " .. mutationType .. " Mutation",
		SortOrder = (RARITY_SORT[rarity] or 0) * 1000 + sortOrder,
	}
end

ColorMutationData.TypeColors = TYPE_COLORS
ColorMutationData.TypeAuras = TYPE_AURAS

ColorMutationData.Mutations = {
	None = {
		Id = "None",
		DisplayName = "Normal",
		Type = "None",
		Rarity = "None",
		Description = "No mutation.",
		VisualTheme = "Standard Color appearance",
		StatModifiers = {},
		Effects = {},
		SpecialEffect = "none",
		VisualEffect = "none",
		VisualTag = "none",
		Weight = NO_MUTATION_WEIGHT,
		IsMutation = false,
		PowerMultiplier = 1,
		AuraColor = TYPE_AURAS.None,
		TypeColor = TYPE_COLORS.None,
		RarityText = "Normal",
		SortOrder = 999999,
	},
}

ColorMutationData.RollOrder = {}

for index, row in ipairs(rows) do
	local mutation = makeMutation(row, index)
	ColorMutationData.Mutations[mutation.Id] = mutation
	table.insert(ColorMutationData.RollOrder, mutation.Id)
end

local CORE_MUTATIONS = {
	Overflow = {
		Id = "Overflow",
		DisplayName = "Overflow",
		Type = "Overflow",
		Rarity = "Rare",
		Description = "Dripping paint overflow.",
		VisualTheme = "Paint drips and wet red trails",
		StatModifiers = { PowerMultiplier = 1.55, ColorGainMultiplier = 1.12 },
		Effects = { PowerMultiplier = 1.55, ColorGainMultiplier = 1.12 },
		SpecialEffect = "core_overflow",
		VisualEffect = "overflow_drip",
		VisualTag = "overflow_drip",
		Weight = 0,
		IsMutation = true,
		PowerMultiplier = 1.55,
		AuraColor = Color3.fromRGB(255, 42, 42),
		TypeColor = Color3.fromRGB(255, 58, 58),
		RarityText = "Core Mutation",
		SortOrder = 41000,
	},
	Corrupted = {
		Id = "Corrupted",
		DisplayName = "Corrupted",
		Type = "Corrupted",
		Rarity = "Rare",
		Description = "Broken purple-black color energy.",
		VisualTheme = "Dark smoke and broken particles",
		StatModifiers = { PowerMultiplier = 2.05, ColorGainMultiplier = 1.18 },
		Effects = { PowerMultiplier = 2.05, ColorGainMultiplier = 1.18 },
		SpecialEffect = "core_corrupted",
		VisualEffect = "corrupted_smoke",
		VisualTag = "corrupted_smoke",
		Weight = 0,
		IsMutation = true,
		PowerMultiplier = 2.05,
		AuraColor = Color3.fromRGB(85, 20, 125),
		TypeColor = Color3.fromRGB(190, 68, 255),
		RarityText = "Core Mutation",
		SortOrder = 42000,
	},
	Radioactive = {
		Id = "Radioactive",
		DisplayName = "Radioactive",
		Type = "Radioactive",
		Rarity = "Rare",
		Description = "Toxic green color particles.",
		VisualTheme = "Green bubbling toxic aura",
		StatModifiers = { PowerMultiplier = 1.9, ColorGainMultiplier = 1.16 },
		Effects = { PowerMultiplier = 1.9, ColorGainMultiplier = 1.16 },
		SpecialEffect = "core_radioactive",
		VisualEffect = "radioactive_toxic",
		VisualTag = "radioactive_toxic",
		Weight = 0,
		IsMutation = true,
		PowerMultiplier = 1.9,
		AuraColor = Color3.fromRGB(82, 255, 84),
		TypeColor = Color3.fromRGB(82, 255, 84),
		RarityText = "Core Mutation",
		SortOrder = 43000,
	},
}

for mutationId, mutation in pairs(CORE_MUTATIONS) do
	if not ColorMutationData.Mutations[mutationId] then
		ColorMutationData.Mutations[mutationId] = mutation
	end
end

ColorMutationData.LegacyAliases = {
	Sparked = "Shadowed",
	Chromatic = "Prism",
	Shiny = "Glimmer",
	Golden = "CursedGold",
	Featherlight = "Angelic",
	Hyper = "Hyperglitch",
	Magnetic = "Darkmatter",
	Rainbow = "Prism",
	Storm = "Heavenstorm",
}

for id in pairs(ColorMutationData.Mutations) do
	ColorMutationData.LegacyAliases[string.lower(id)] = id
end

local function normalizeRaw(mutationId)
	if type(mutationId) ~= "string" then
		return ColorMutationData.NoneId
	end

	local trimmed = string.gsub(mutationId, "^%s*(.-)%s*$", "%1")
	if trimmed == "" then
		return ColorMutationData.NoneId
	end

	return ColorMutationData.LegacyAliases[trimmed] or ColorMutationData.LegacyAliases[string.lower(trimmed)] or trimmed
end

function ColorMutationData.get(mutationId)
	mutationId = normalizeRaw(mutationId)
	return ColorMutationData.Mutations[mutationId] or ColorMutationData.Mutations[ColorMutationData.NoneId]
end

function ColorMutationData.isMutated(mutationId)
	mutationId = normalizeRaw(mutationId)
	return mutationId ~= ColorMutationData.NoneId and ColorMutationData.Mutations[mutationId] ~= nil
end

function ColorMutationData.normalize(mutationId)
	mutationId = normalizeRaw(mutationId)
	if ColorMutationData.Mutations[mutationId] then
		return mutationId
	end
	return ColorMutationData.NoneId
end

function ColorMutationData.getTypeColor(mutationType)
	return TYPE_COLORS[mutationType] or TYPE_COLORS.None
end

function ColorMutationData.getTypeAura(mutationType)
	return TYPE_AURAS[mutationType] or TYPE_AURAS.None
end

local function getMutationRollWeights(luckMultiplier)
	luckMultiplier = math.clamp(tonumber(luckMultiplier) or 1, 1, 3.5)

	local noMutationWeight = NO_MUTATION_WEIGHT
	local totalWeight = noMutationWeight
	local weighted = {}

	for _, mutationId in ipairs(ColorMutationData.RollOrder) do
		local mutation = ColorMutationData.Mutations[mutationId]
		if mutation and mutation.Weight and mutation.Weight > 0 then
			local rarityBoost = mutation.Rarity == "Legendary" and 0.85 or mutation.Rarity == "Rare" and 0.55 or 0.2
			local typePenalty = mutation.Type == "Corrupted" and 0.75 or 1
			local weight = mutation.Weight * typePenalty * (1 + ((luckMultiplier - 1) * rarityBoost))
			totalWeight += weight
			table.insert(weighted, { mutation = mutation, weight = weight })
		end
	end

	return noMutationWeight, totalWeight, weighted
end

function ColorMutationData.getRollChance(mutationId, luckMultiplier)
	mutationId = ColorMutationData.normalize(mutationId)
	local noMutationWeight, totalWeight, weighted = getMutationRollWeights(luckMultiplier)
	if totalWeight <= 0 then
		return nil
	end
	if mutationId == ColorMutationData.NoneId then
		return (noMutationWeight / totalWeight) * 100
	end
	for _, data in ipairs(weighted) do
		if data.mutation.Id == mutationId then
			return (data.weight / totalWeight) * 100
		end
	end
	return nil
end

function ColorMutationData.roll(luckMultiplier)
	local noMutationWeight, totalWeight, weighted = getMutationRollWeights(luckMultiplier)

	local roll = math.random() * totalWeight
	if roll <= noMutationWeight then
		return ColorMutationData.Mutations.None
	end
	roll -= noMutationWeight

	for _, data in ipairs(weighted) do
		roll -= data.weight
		if roll <= 0 then
			return data.mutation
		end
	end

	return ColorMutationData.Mutations.None
end

return ColorMutationData
