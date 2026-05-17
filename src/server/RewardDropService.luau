local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RankService = require(script.Parent:WaitForChild("RankService"))
local RewardDefinitions = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RewardDefinitions"))

local Events = ReplicatedStorage:WaitForChild("Events")
local collectEvent = Events:WaitForChild("CollectColor")
local rewardVfxEvent = Events:WaitForChild("BreakableRewardVFX")
local petBreakRewardEvent = Events:WaitForChild("PetBreakReward")

local RewardDropService = {}
local rng = Random.new()
local REWARD_COLORS = {
	Red = Color3.fromRGB(255, 50, 55),
	Orange = Color3.fromRGB(255, 132, 28),
	Green = Color3.fromRGB(70, 220, 90),
}

local function findNumberValue(parent, name)
	if not parent then
		return nil
	end
	local value = parent:FindFirstChild(name)
	if value and value:IsA("ValueBase") and typeof(value.Value) == "number" then
		return value
	end
	return nil
end

local function ensureIntValue(parent, name)
	local existing = findNumberValue(parent, name)
	if existing then
		return existing
	end
	local value = Instance.new("IntValue")
	value.Name = name
	value.Value = 0
	value.Parent = parent
	return value
end

local function addLeaderstat(player, name, amount)
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 then
		return 0
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return 0
	end
	local value = ensureIntValue(leaderstats, name)
	value.Value += amount
	return amount
end

local function addColorCurrency(player, colorType, amount)
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 then
		return 0
	end
	local currencies = player:FindFirstChild("ColorCurrencies")
	if not currencies then
		currencies = Instance.new("Folder")
		currencies.Name = "ColorCurrencies"
		currencies.Parent = player
	end
	local value = ensureIntValue(currencies, colorType)
	value.Value += amount
	return amount
end

local function addItemPlaceholder(player, itemId, amount)
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 then
		return 0
	end
	local folder = player:FindFirstChild("ItemInventory")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "ItemInventory"
		folder.Parent = player
	end
	local value = ensureIntValue(folder, tostring(itemId or "ItemPlaceholder"))
	value.Value += amount
	return amount
end

local function scaleReward(amount, multiplier)
	return math.max(0, math.floor((tonumber(amount) or 0) * math.max(tonumber(multiplier) or 1, 0) + 0.5))
end

function RewardDropService.RollAndGrant(player, breakableDefinition, worldPosition, colorType, rewardMultiplier)
	if not player or not player.Parent then
		return nil
	end
	colorType = tostring(colorType or "Red")
	rewardMultiplier = math.max(tonumber(rewardMultiplier) or 1, 0)
	local rewards = RewardDefinitions.Roll(breakableDefinition and breakableDefinition.RewardTable, rng)
	local rewardRankMultiplier = RankService.GetRewardMultiplier(player)
	local granted = {
		Coins = addLeaderstat(player, "Coins", scaleReward(rewards.Coins, rewardMultiplier * rewardRankMultiplier)),
		Gems = addLeaderstat(player, "Gems", scaleReward(rewards.Gems, rewardMultiplier * rewardRankMultiplier)),
		ColorType = colorType,
		ColorAmount = addColorCurrency(player, colorType, scaleReward(rewards.Red, rewardMultiplier)),
		Items = {},
	}
	granted[colorType] = granted.ColorAmount
	if colorType ~= "Red" then
		granted.Red = 0
	else
		granted.Red = granted.ColorAmount
	end

	if granted.Coins > 0 or granted.Gems > 0 then
		RankService.AwardFromRewards(player, granted.Coins, granted.Gems, "rank-breakable-rewards")
	end
	for _, item in ipairs(rewards.Items or {}) do
		local amount = addItemPlaceholder(player, item.ItemId, item.Amount)
		if amount > 0 then
			table.insert(granted.Items, {
				ItemId = item.ItemId,
				Amount = amount,
			})
		end
	end

	rewardVfxEvent:FireClient(player, {
		Position = worldPosition,
		ColorType = colorType,
		Color = REWARD_COLORS[colorType] or REWARD_COLORS.Red,
		Rewards = granted,
		BreakableType = breakableDefinition and breakableDefinition.AssetName,
	})
	if granted.Coins > 0 then
		collectEvent:FireClient(player, true, granted.Coins, "Coins")
		petBreakRewardEvent:FireClient(player, {
			Amount = granted.Coins,
			ColorType = colorType,
			Position = worldPosition,
		})
	end
	return granted
end

function RewardDropService.GetPlayers()
	return Players:GetPlayers()
end

return RewardDropService
