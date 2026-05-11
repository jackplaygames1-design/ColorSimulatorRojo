-- ModuleScript in ReplicatedStorage named "RobuxShopConfig"
local RobuxShopConfig = {}

-- Replace any 0 gamepassId/productId values with the real IDs from creator.roblox.com.
-- The in-game UI is safe: passes without a real ID show as "Set ID" instead of prompting.
RobuxShopConfig.Gamepasses = {
	{
		id = "InfinitePass",
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
		showInShop = true,
	},
	{
		id = "AutoSell",
		displayName = "AUTO SELL",
		description = "Legacy pass hidden while Color breaks award Coins instantly.",
		icon = "AUTO",
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

return RobuxShopConfig
