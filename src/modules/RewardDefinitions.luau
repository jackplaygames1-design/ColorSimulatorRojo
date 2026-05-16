local RewardDefinitions = {}

RewardDefinitions.Tables = {
	SmallColorReward = {
		Coins = { Min = 5, Max = 15 },
		Red = { Min = 1, Max = 3 },
		Gems = { Min = 0, Max = 1, Chance = 0.18 },
	},
	MediumColorReward = {
		Coins = { Min = 20, Max = 50 },
		Red = { Min = 4, Max = 10 },
		Gems = { Min = 1, Max = 3 },
	},
	CrateReward = {
		Coins = { Min = 75, Max = 150 },
		Red = { Min = 12, Max = 25 },
		Gems = { Min = 3, Max = 8 },
	},
	ChestReward = {
		Coins = { Min = 250, Max = 500 },
		Red = { Min = 40, Max = 80 },
		Gems = { Min = 10, Max = 25 },
	},
	HugeChestReward = {
		Coins = { Min = 1000, Max = 2500 },
		Red = { Min = 150, Max = 350 },
		Gems = { Min = 50, Max = 120 },
		Items = {
			{ ItemId = "PotionPlaceholder", Chance = 0.08, Min = 1, Max = 1 },
		},
	},
	GiantCoreReward = {
		Coins = { Min = 5000, Max = 15000 },
		Red = { Min = 750, Max = 2000 },
		Gems = { Min = 250, Max = 750 },
		Items = {
			{ ItemId = "PotionPlaceholder", Chance = 0.22, Min = 1, Max = 2 },
		},
	},
}

local function rollRange(random, range)
	if type(range) ~= "table" then
		return 0
	end
	local chance = tonumber(range.Chance)
	if chance and chance < 1 and random:NextNumber() > chance then
		return 0
	end
	local minValue = math.floor(tonumber(range.Min) or 0)
	local maxValue = math.floor(tonumber(range.Max) or minValue)
	if maxValue < minValue then
		maxValue = minValue
	end
	if maxValue <= minValue then
		return minValue
	end
	return random:NextInteger(minValue, maxValue)
end

function RewardDefinitions.Roll(tableId, random)
	random = random or Random.new()
	local rewardTable = RewardDefinitions.Tables[tostring(tableId or "")] or RewardDefinitions.Tables.SmallColorReward
	local rewards = {
		Coins = rollRange(random, rewardTable.Coins),
		Gems = rollRange(random, rewardTable.Gems),
		Red = rollRange(random, rewardTable.Red),
		Items = {},
	}

	for _, item in ipairs(rewardTable.Items or {}) do
		local chance = tonumber(item.Chance) or 0
		if chance > 0 and random:NextNumber() <= chance then
			table.insert(rewards.Items, {
				ItemId = tostring(item.ItemId or "ItemPlaceholder"),
				Amount = rollRange(random, item),
			})
		end
	end

	return rewards
end

return RewardDefinitions
