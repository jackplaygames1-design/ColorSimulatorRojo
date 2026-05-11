-- ModuleScript in ReplicatedStorage named "RobuxShopConfig"
local RobuxShopConfig = {}

-- Replace any 0 gamepassId/productId values with the real IDs from creator.roblox.com.
-- The in-game UI is safe: passes without a real ID show as "Set ID" instead of prompting.
RobuxShopConfig.Gamepasses = {
	-- Hidden legacy placeholder; the real Infinite Pack lives in RobuxShopConfig.InfinitePack.
	{
		id = "LegacyInfinitePass",
		displayName = "INFINITE PASS",
		description = "Infinite storage, +5 equipped Colors, VIP aura, daily gems, and an exclusive Infinite tag.",
		icon = "∞",
		iconImage = "",
		price = 999,
		color = Color3.fromRGB(105, 80, 255),
		gamepassId = 0,
		sortOrder = 1,
		badge = "BEST VALUE",
		infiniteStorage = true,
		extraEquippedColors = 5,
		luckMultiplier = 1.2,
		dailyGemBonus = 50,
		infiniteTag = true,
		showInShop = false,
	},
	{
		id = "AutoSell",
		displayName = "AUTO SELL",
		description = "Legacy pass hidden while Color breaks award Coins instantly.",
		icon = "AUTO",
		iconKey = "auto_sell",
		iconSourceFile = "assets/ui/gamepass/autosell.png",
		iconImage = "rbxthumb://type=GamePass&id=1825700534&w=150&h=150",
		price = 149,
		color = Color3.fromRGB(255, 199, 87),
		gamepassId = 1825700534,
		sortOrder = 50,
		badge = "AUTOMATION",
		autoSell = true,
		showInShop = false,
	},
	{
		id = "Plus3Colors",
		displayName = "+3 COLORS",
		description = "Equip 3 extra Colors for more power and better bonuses.",
		icon = "+3",
		iconKey = "plus_3_colors",
		iconSourceFile = "assets/ui/gamepass/3pluscolors.png",
		iconImage = "rbxthumb://type=GamePass&id=1825682519&w=150&h=150",
		price = 199,
		color = Color3.fromRGB(114, 203, 255),
		gamepassId = 1825682519,
		sortOrder = 50,
		badge = "MORE POWER",
		extraEquippedColors = 3,
	},
	{
		id = "DoubleCoins",
		displayName = "2x COINS",
		description = "Earn 2x more Coins from Color breaks and progression.",
		icon = "2x",
		iconKey = "double_coins",
		iconSourceFile = "assets/ui/gamepass/2xcoin.png",
		iconImage = "rbxthumb://type=GamePass&id=1823157511&w=150&h=150",
		price = 249,
		color = Color3.fromRGB(255, 221, 84),
		gamepassId = 1823157511,
		sortOrder = 30,
		badge = "GRINDING",
		coinMultiplier = 2,
	},
	{
		id = "VIP",
		displayName = "VIP",
		description = "VIP tag, bonus rewards, and future VIP perks.",
		icon = "VIP",
		iconKey = "vip",
		iconSourceFile = "assets/ui/gamepass/vip.png",
		iconImage = "rbxthumb://type=GamePass&id=1825282612&w=150&h=150",
		price = 299,
		color = Color3.fromRGB(177, 141, 255),
		gamepassId = 1825282612,
		sortOrder = 10,
		badge = "PREMIUM",
		isVIP = true,
		extraEquippedColors = 1,
		luckMultiplier = 1.1,
	},
	{
		id = "LuckyHatch",
		displayName = "LUCKY HATCH",
		description = "Better chance for rare Colors and mutations.",
		icon = "LUCK",
		iconKey = "lucky_hatch",
		iconSourceFile = "assets/ui/gamepass/luckhatch.png",
		iconImage = "rbxthumb://type=GamePass&id=1823292559&w=150&h=150",
		price = 199,
		color = Color3.fromRGB(128, 239, 150),
		gamepassId = 1823292559,
		sortOrder = 20,
		badge = "POPULAR",
		luckMultiplier = 1.35,
	},
	{
		id = "SupportDev",
		displayName = "SUPPORT DEV",
		description = "Support Color Simulator and receive a special heart chat tag.",
		icon = "<3",
		iconImage = "rbxthumb://type=GamePass&id=1823390286&w=150&h=150",
		price = 99,
		color = Color3.fromRGB(255, 162, 196),
		gamepassId = 1823390286,
		sortOrder = 60,
		badge = "THANK YOU",
		earlySupporterTag = true,
	},
}

local INFINITE_PACK_ITEM_ICONS = {
	coin_potion = "assets/ui/itemsui/sliced/coin_potion.png",
	coins = "assets/ui/itemsui/sliced/coins.png",
	gem = "assets/ui/itemsui/sliced/gem.png",
	gem_potion = "assets/ui/itemsui/sliced/gem_potion.png",
	luck_potion = "assets/ui/itemsui/sliced/luck_potion.png",
	mystery_potion = "assets/ui/itemsui/sliced/mystery_potion.png",
	rainbow_paint_potion = "assets/ui/itemsui/sliced/rainbow_paint_potion.png",
	speed_potion = "assets/ui/itemsui/sliced/speed_potion.png",
}

local INFINITE_PACK_REWARD_POOLS = {
	SmallFree = {
		{
			displayName = "Gem Starter",
			rewardText = "75 Gems",
			icon = "GEM",
			iconKey = "gem",
			color = Color3.fromRGB(92, 240, 150),
			rewardKind = "Gem",
			amount = 75,
			gemReward = 75,
		},
		{
			displayName = "Coin Starter",
			rewardText = "2,500 Coins",
			icon = "$",
			iconKey = "coins",
			color = Color3.fromRGB(255, 199, 87),
			rewardKind = "Coin",
			amount = 2500,
			coinReward = 2500,
		},
		{
			displayName = "Gem Pouch",
			rewardText = "125 Gems",
			icon = "GEM",
			iconKey = "gem",
			color = Color3.fromRGB(92, 240, 150),
			rewardKind = "Gem",
			amount = 125,
			gemReward = 125,
		},
	},
	SmallPaid = {
		{
			displayName = "Coin Potion",
			rewardText = "Small Coin Potion",
			icon = "2x",
			iconKey = "coin_potion",
			color = Color3.fromRGB(255, 221, 84),
			boostType = "coins",
			boostAmount = 1,
		},
		{
			displayName = "Luck Potion",
			rewardText = "Small Luck Potion",
			icon = "LU",
			iconKey = "luck_potion",
			color = Color3.fromRGB(128, 239, 150),
			boostType = "luck",
			boostAmount = 1,
		},
		{
			displayName = "Speed Potion",
			rewardText = "Small Speed Potion",
			icon = "SP",
			iconKey = "speed_potion",
			color = Color3.fromRGB(72, 210, 255),
			boostType = "speed",
			boostAmount = 1,
		},
	},
	MediumFree = {
		{
			displayName = "Gem Stack",
			rewardText = "250 Gems",
			icon = "GEM",
			iconKey = "gem",
			color = Color3.fromRGB(92, 240, 150),
			rewardKind = "Gem",
			amount = 250,
			gemReward = 250,
		},
		{
			displayName = "Coin Stack",
			rewardText = "10,000 Coins",
			icon = "$",
			iconKey = "coins",
			color = Color3.fromRGB(255, 199, 87),
			rewardKind = "Coin",
			amount = 10000,
			coinReward = 10000,
		},
	},
	MediumPaid = {
		{
			displayName = "Gem Potion",
			rewardText = "Gem Boost Potion",
			icon = "GEM",
			iconKey = "gem_potion",
			color = Color3.fromRGB(92, 240, 150),
			boostType = "gems",
			boostAmount = 1,
		},
		{
			displayName = "Rainbow Paint",
			rewardText = "Rainbow Paint Potion",
			icon = "PAINT",
			iconKey = "rainbow_paint_potion",
			color = Color3.fromRGB(255, 162, 196),
			boostType = "paint",
			boostAmount = 1,
		},
		{
			displayName = "Mystery Potion",
			rewardText = "Mystery Potion",
			icon = "???",
			iconKey = "mystery_potion",
			color = Color3.fromRGB(177, 141, 255),
			boostType = "mystery",
			boostAmount = 1,
		},
	},
	LatePaid = {
		{
			displayName = "Big Gems",
			rewardText = "2,500 Gems",
			icon = "GEM",
			iconKey = "gem",
			color = Color3.fromRGB(72, 210, 255),
			rewardKind = "Gem",
			amount = 2500,
			gemReward = 2500,
			badge = "BIG",
		},
		{
			displayName = "Coin Vault",
			rewardText = "75,000 Coins",
			icon = "$",
			iconKey = "coins",
			color = Color3.fromRGB(255, 199, 87),
			rewardKind = "Coin",
			amount = 75000,
			coinReward = 75000,
			badge = "BIG",
		},
		{
			displayName = "Exclusive Color",
			rewardText = "Exclusive Color",
			icon = "???",
			iconKey = "mystery_potion",
			color = Color3.fromRGB(255, 162, 196),
			colorReward = "ExclusiveRainbowColor",
			badge = "RARE",
		},
	},
	JackpotPaid = {
		{
			displayName = "Huge Gems",
			rewardText = "10,000 Gems",
			icon = "GEM",
			iconKey = "gem",
			color = Color3.fromRGB(72, 210, 255),
			rewardKind = "Gem",
			amount = 10000,
			gemReward = 10000,
			badge = "HUGE",
		},
		{
			displayName = "Exclusive Pet",
			rewardText = "Exclusive Pet",
			icon = "PET",
			iconKey = "mystery_potion",
			color = Color3.fromRGB(177, 141, 255),
			petReward = "ExclusiveInfinitePet",
			badge = "EXCLUSIVE",
		},
		{
			displayName = "Rainbow Pet",
			rewardText = "Rainbow Exclusive",
			icon = "RB",
			iconKey = "rainbow_paint_potion",
			color = Color3.fromRGB(255, 110, 210),
			petReward = "RainbowInfinitePet",
			badge = "TOP",
		},
	},
}

local INFINITE_PACK_SLOTS = {
	{ tier = 1, price = 0, pool = "SmallFree" },
	{ tier = 2, price = 25, pool = "SmallPaid" },
	{ tier = 3, price = 0, pool = "SmallFree" },
	{ tier = 4, price = 49, pool = "MediumPaid" },
	{ tier = 5, price = 0, pool = "MediumFree" },
	{ tier = 6, price = 149, pool = "MediumPaid" },
	{ tier = 7, price = 299, pool = "LatePaid" },
	{ tier = 8, price = 799, pool = "JackpotPaid" },
}

local function copyReward(source)
	local reward = {}
	for key, value in pairs(source) do
		reward[key] = value
	end
	return reward
end

local function infinitePackSeed()
	return tonumber(os.date("!%Y%j")) or 20260511
end

local function makeInfinitePackTiers()
	local rng = Random.new(infinitePackSeed())
	local tiers = {}
	for _, slot in ipairs(INFINITE_PACK_SLOTS) do
		local pool = INFINITE_PACK_REWARD_POOLS[slot.pool] or INFINITE_PACK_REWARD_POOLS.SmallFree
		local reward = copyReward(pool[rng:NextInteger(1, #pool)])
		reward.id = string.format("InfinitePackTier%02d", slot.tier)
		reward.tier = slot.tier
		reward.price = slot.price
		reward.productId = slot.productId or 0
		reward.free = slot.price == 0
		reward.iconImage = reward.iconImage or ""
		reward.iconSourceFile = reward.iconSourceFile or INFINITE_PACK_ITEM_ICONS[reward.iconKey]
		reward.productCategory = "InfinitePack"
		table.insert(tiers, reward)
	end
	return tiers
end

RobuxShopConfig.InfinitePack = {
	id = "InfinitePack",
	displayName = "THE FOREVER PACK!",
	description = "Claim free rewards and unlock better Robux tiers as the pack advances.",
	resetSeconds = 24 * 60 * 60,
	accentColor = Color3.fromRGB(105, 80, 255),
	tierProductCategory = "InfinitePack",
	randomSeed = infinitePackSeed(),
	tiers = makeInfinitePackTiers(),
}

RobuxShopConfig.DevProducts = {
	{
		id = "CoinBoost15",
		displayName = "COIN BOOST",
		description = "15 min 2x Coins.",
		icon = "2x",
		price = 0,
		color = Color3.fromRGB(255, 221, 84),
		productId = 0,
		sortOrder = 10,
		category = "Boosts",
		boostType = "coins",
		boostDuration = 15 * 60,
		boostMultiplier = 2,
		showInShop = true,
	},
	{
		id = "LuckBoost15",
		displayName = "LUCK BOOST",
		description = "15 min +50% Luck.",
		icon = "LU",
		price = 0,
		color = Color3.fromRGB(128, 239, 150),
		productId = 0,
		sortOrder = 20,
		category = "Boosts",
		boostType = "luck",
		boostDuration = 15 * 60,
		boostMultiplier = 1.5,
		showInShop = true,
	},
	{
		id = "HatchSpeed15",
		displayName = "HATCH SPEED",
		description = "15 min faster hatching.",
		icon = "HS",
		price = 0,
		color = Color3.fromRGB(114, 203, 255),
		productId = 0,
		sortOrder = 30,
		category = "Boosts",
		boostType = "hatchSpeed",
		boostDuration = 15 * 60,
		boostMultiplier = 1.5,
		showInShop = true,
	},
	{
		id = "GemBoost15",
		displayName = "GEM BOOST",
		description = "15 min 2x Gems.",
		icon = "GM",
		price = 0,
		color = Color3.fromRGB(92, 240, 150),
		productId = 0,
		sortOrder = 40,
		category = "Boosts",
		boostType = "gems",
		boostDuration = 15 * 60,
		boostMultiplier = 2,
		showInShop = true,
	},
	{
		id = "SmallGemPack",
		displayName = "SMALL GEM PACK",
		description = "A small bundle of Gems.",
		icon = "S",
		price = 0,
		color = Color3.fromRGB(92, 240, 150),
		productId = 0,
		sortOrder = 110,
		category = "Currency",
		gemReward = 250,
		showInShop = true,
	},
	{
		id = "MediumGemPack",
		displayName = "MEDIUM GEM PACK",
		description = "A bigger bundle of Gems.",
		icon = "M",
		price = 0,
		color = Color3.fromRGB(72, 210, 255),
		productId = 0,
		sortOrder = 120,
		category = "Currency",
		gemReward = 1000,
		showInShop = true,
	},
	{
		id = "HugeGemPack",
		displayName = "HUGE GEM PACK",
		description = "A huge bundle of Gems.",
		icon = "H",
		price = 0,
		color = Color3.fromRGB(177, 141, 255),
		productId = 0,
		sortOrder = 130,
		category = "Currency",
		gemReward = 5000,
		showInShop = true,
	},
	{
		id = "MegaCoinPack",
		displayName = "MEGA COIN PACK",
		description = "A mega pack of Coins.",
		icon = "$",
		price = 0,
		color = Color3.fromRGB(255, 221, 84),
		productId = 0,
		sortOrder = 140,
		category = "Currency",
		coinReward = 100000,
		showInShop = true,
	},
	{
		id = "Coins1k",
		displayName = "1,000 Coins",
		description = "Instantly receive 1,000 Coins.",
		icon = "1K",
		price = 49,
		color = Color3.fromRGB(255, 230, 100),
		productId = 0,
		showInShop = false,
		coinReward = 1000,
	},
	{
		id = "Coins10k",
		displayName = "10,000 Coins",
		description = "Instantly receive 10,000 Coins.",
		icon = "10K",
		price = 399,
		color = Color3.fromRGB(255, 200, 50),
		productId = 0,
		showInShop = false,
		coinReward = 10000,
		badge = "BEST VALUE",
	},
	{
		id = "Coins100k",
		displayName = "100,000 Coins",
		description = "Instantly receive 100,000 Coins.",
		icon = "100K",
		price = 999,
		color = Color3.fromRGB(220, 160, 0),
		productId = 0,
		showInShop = false,
		coinReward = 100000,
		badge = "MEGA PACK",
	},
}

function RobuxShopConfig.getGamepass(passId)
	for _, pass in ipairs(RobuxShopConfig.Gamepasses) do
		if pass.id == passId then
			return pass
		end
	end
	return nil
end

function RobuxShopConfig.getGamepassByRobloxId(gamepassId)
	gamepassId = tonumber(gamepassId)
	for _, pass in ipairs(RobuxShopConfig.Gamepasses) do
		if tonumber(pass.gamepassId) == gamepassId then
			return pass
		end
	end
	return nil
end

function RobuxShopConfig.getSortedGamepasses()
	local passes = {}
	for _, pass in ipairs(RobuxShopConfig.Gamepasses) do
		if pass.showInShop ~= false then
			table.insert(passes, pass)
		end
	end
	table.sort(passes, function(a, b)
		return (a.sortOrder or 999) < (b.sortOrder or 999)
	end)
	return passes
end

function RobuxShopConfig.getSortedDevProducts()
	local products = {}
	for _, product in ipairs(RobuxShopConfig.DevProducts or {}) do
		if product.showInShop ~= false then
			table.insert(products, product)
		end
	end
	table.sort(products, function(a, b)
		return (a.sortOrder or 999) < (b.sortOrder or 999)
	end)
	return products
end

function RobuxShopConfig.getInfinitePackTiers()
	local tiers = {}
	for _, tier in ipairs((RobuxShopConfig.InfinitePack and RobuxShopConfig.InfinitePack.tiers) or {}) do
		table.insert(tiers, tier)
	end
	table.sort(tiers, function(a, b)
		return (a.tier or 999) < (b.tier or 999)
	end)
	return tiers
end

function RobuxShopConfig.getInfinitePackTier(tierId)
	for _, tier in ipairs(RobuxShopConfig.getInfinitePackTiers()) do
		if tier.id == tierId then
			return tier
		end
	end
	return nil
end

function RobuxShopConfig.getInfinitePackTierByProductId(productId)
	productId = tonumber(productId)
	for _, tier in ipairs(RobuxShopConfig.getInfinitePackTiers()) do
		if tonumber(tier.productId) == productId then
			return tier
		end
	end
	return nil
end

return RobuxShopConfig
