local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Events = ReplicatedStorage:WaitForChild("Events")
local playerDataDirtyEvent = Events:FindFirstChild("PlayerDataDirty")
if not playerDataDirtyEvent then
	playerDataDirtyEvent = Instance.new("BindableEvent")
	playerDataDirtyEvent.Name = "PlayerDataDirty"
	playerDataDirtyEvent.Parent = Events
end

local RankService = {}

local MAX_RANK = 5
local PASSIVE_XP_INTERVAL = 30
local PASSIVE_XP_AMOUNT = 8
local COIN_XP_DIVISOR = 35
local MAX_COIN_XP_PER_AWARD = 300

local RANKS = {
	[1] = {
		Name = "RANK I",
		Icon = "I",
		XPToNext = 2500,
		CoinMultiplier = 1.10,
		LuckMultiplier = 1.05,
		ExtraEquipSlots = 1,
	},
	[2] = {
		Name = "RANK II",
		Icon = "II",
		XPToNext = 6500,
		CoinMultiplier = 1.15,
		LuckMultiplier = 1.08,
		ExtraEquipSlots = 1,
	},
	[3] = {
		Name = "RANK III",
		Icon = "III",
		XPToNext = 15000,
		CoinMultiplier = 1.22,
		LuckMultiplier = 1.12,
		ExtraEquipSlots = 2,
	},
	[4] = {
		Name = "RANK IV",
		Icon = "IV",
		XPToNext = 35000,
		CoinMultiplier = 1.30,
		LuckMultiplier = 1.16,
		ExtraEquipSlots = 2,
	},
	[5] = {
		Name = "RANK V",
		Icon = "V",
		XPToNext = 0,
		CoinMultiplier = 1.40,
		LuckMultiplier = 1.20,
		ExtraEquipSlots = 3,
	},
}

local watchedPlayers = {}

local function clampRank(rankLevel)
	return math.clamp(math.floor(tonumber(rankLevel) or 1), 1, MAX_RANK)
end

local function getRankInfo(rankLevel)
	return RANKS[clampRank(rankLevel)] or RANKS[1]
end

local function getXPRequired(rankLevel)
	if clampRank(rankLevel) >= MAX_RANK then
		return 0
	end
	return math.max(1, math.floor(tonumber(getRankInfo(rankLevel).XPToNext) or 1))
end

local function getValue(folder, name)
	local value = folder and folder:FindFirstChild(name)
	return value and value:IsA("ValueBase") and value or nil
end

local function getOrCreateInt(folder, name, defaultValue)
	local value = getValue(folder, name)
	local created = false
	if value and not value:IsA("IntValue") then
		value:Destroy()
		value = nil
	end
	if not value then
		value = Instance.new("IntValue")
		value.Name = name
		value.Parent = folder
		created = true
	end
	value.Value = math.max(0, math.floor((not created and tonumber(value.Value)) or tonumber(defaultValue) or 0))
	return value
end

local function getOrCreateString(folder, name, defaultValue)
	local value = getValue(folder, name)
	if value and not value:IsA("StringValue") then
		value:Destroy()
		value = nil
	end
	if not value then
		value = Instance.new("StringValue")
		value.Name = name
		value.Parent = folder
	end
	value.Value = tostring(value.Value ~= "" and value.Value or defaultValue or "")
	return value
end

local function getRankFolder(player, createIfReady)
	local folder = player and player:FindFirstChild("RankData")
	if not folder and createIfReady and player and player:GetAttribute("DataManagerReady") == true then
		folder = Instance.new("Folder")
		folder.Name = "RankData"
		folder.Parent = player
	end
	return folder
end

local function getRankValues(player, createIfReady)
	local folder = getRankFolder(player, createIfReady)
	if not folder then
		return nil
	end

	return folder,
		getOrCreateInt(folder, "RankLevel", 1),
		getOrCreateInt(folder, "RankXP", 0),
		getOrCreateInt(folder, "RankTotalXP", 0),
		getOrCreateInt(folder, "RankXPRequired", getXPRequired(1)),
		getOrCreateString(folder, "RankName", RANKS[1].Name)
end

local function bonusPercent(multiplier)
	return math.max(0, math.floor(((tonumber(multiplier) or 1) - 1) * 100 + 0.5))
end

local function syncAttributes(player, rankLevel, rankXP, totalXP)
	rankLevel = clampRank(rankLevel)
	local info = getRankInfo(rankLevel)
	local required = getXPRequired(rankLevel)
	if rankLevel >= MAX_RANK then
		rankXP = 0
	end

	player:SetAttribute("RankLevel", rankLevel)
	player:SetAttribute("RankName", info.Name)
	player:SetAttribute("CurrentRank", info.Name)
	player:SetAttribute("Rank", info.Name)
	player:SetAttribute("RankIcon", info.Icon)
	player:SetAttribute("RankXP", math.max(0, math.floor(tonumber(rankXP) or 0)))
	player:SetAttribute("Experience", math.max(0, math.floor(tonumber(rankXP) or 0)))
	player:SetAttribute("RankTotalXP", math.max(0, math.floor(tonumber(totalXP) or 0)))
	player:SetAttribute("NextRankXP", required)
	player:SetAttribute("RankXPRequired", required)
	player:SetAttribute("RankMaxRank", MAX_RANK)
	player:SetAttribute("RankIsMaxed", rankLevel >= MAX_RANK)
	player:SetAttribute("RankCoinMultiplier", info.CoinMultiplier)
	player:SetAttribute("RankLuckMultiplier", info.LuckMultiplier)
	player:SetAttribute("RankCoinBonusPercent", bonusPercent(info.CoinMultiplier))
	player:SetAttribute("RankLuckBonusPercent", bonusPercent(info.LuckMultiplier))
	player:SetAttribute("RankExtraEquipSlots", info.ExtraEquipSlots)
end

function RankService.NormalizeData(data)
	data = type(data) == "table" and data or {}
	local rankLevel = clampRank(data.RankLevel or data.CurrentRankLevel or data.Level)
	local rankXP = math.max(0, math.floor(tonumber(data.RankXP or data.XP or data.Experience) or 0))
	local totalXP = math.max(0, math.floor(tonumber(data.RankTotalXP or data.TotalXP) or rankXP))

	while rankLevel < MAX_RANK do
		local required = getXPRequired(rankLevel)
		if rankXP < required then
			break
		end
		rankXP -= required
		rankLevel += 1
	end

	if rankLevel >= MAX_RANK then
		rankLevel = MAX_RANK
		rankXP = 0
	end

	return {
		RankLevel = rankLevel,
		RankXP = rankXP,
		RankTotalXP = totalXP,
	}
end

function RankService.GetInfo(rankLevel)
	return getRankInfo(rankLevel)
end

function RankService.GetXPRequired(rankLevel)
	return getXPRequired(rankLevel)
end

function RankService.SyncPlayerAttributes(player)
	local folder, rankValue, xpValue, totalValue, requiredValue, nameValue = getRankValues(player, false)
	if not folder then
		syncAttributes(player, 1, 0, 0)
		return
	end

	local normalized = RankService.NormalizeData({
		RankLevel = rankValue.Value,
		RankXP = xpValue.Value,
		RankTotalXP = totalValue.Value,
	})
	rankValue.Value = normalized.RankLevel
	xpValue.Value = normalized.RankXP
	totalValue.Value = normalized.RankTotalXP
	requiredValue.Value = getXPRequired(normalized.RankLevel)
	nameValue.Value = getRankInfo(normalized.RankLevel).Name
	syncAttributes(player, normalized.RankLevel, normalized.RankXP, normalized.RankTotalXP)
end

function RankService.ApplyToFolder(player, folder, rankData)
	if not player or not folder then
		return
	end

	local normalized = RankService.NormalizeData(rankData)
	getOrCreateInt(folder, "RankLevel", normalized.RankLevel).Value = normalized.RankLevel
	getOrCreateInt(folder, "RankXP", normalized.RankXP).Value = normalized.RankXP
	getOrCreateInt(folder, "RankTotalXP", normalized.RankTotalXP).Value = normalized.RankTotalXP
	getOrCreateInt(folder, "RankXPRequired", getXPRequired(normalized.RankLevel)).Value =
		getXPRequired(normalized.RankLevel)
	getOrCreateString(folder, "RankName", getRankInfo(normalized.RankLevel).Name).Value =
		getRankInfo(normalized.RankLevel).Name
	syncAttributes(player, normalized.RankLevel, normalized.RankXP, normalized.RankTotalXP)
end

function RankService.AwardXP(player, amount, reason)
	amount = math.max(0, math.floor(tonumber(amount) or 0))
	if not player or amount <= 0 then
		return false
	end

	local folder, rankValue, xpValue, totalValue, requiredValue, nameValue = getRankValues(player, true)
	if not folder then
		return false
	end

	local oldRank = clampRank(rankValue.Value)
	local rankLevel = oldRank
	local rankXP = math.max(0, math.floor(tonumber(xpValue.Value) or 0))
	local totalXP = math.max(0, math.floor(tonumber(totalValue.Value) or 0)) + amount

	if rankLevel < MAX_RANK then
		rankXP += amount
		while rankLevel < MAX_RANK do
			local required = getXPRequired(rankLevel)
			if rankXP < required then
				break
			end
			rankXP -= required
			rankLevel += 1
		end
	end

	if rankLevel >= MAX_RANK then
		rankLevel = MAX_RANK
		rankXP = 0
	end

	rankValue.Value = rankLevel
	xpValue.Value = rankXP
	totalValue.Value = totalXP
	requiredValue.Value = getXPRequired(rankLevel)
	nameValue.Value = getRankInfo(rankLevel).Name
	syncAttributes(player, rankLevel, rankXP, totalXP)

	playerDataDirtyEvent:Fire(player, rankLevel > oldRank and "rank-up" or (reason or "rank"))
	return true
end

function RankService.AwardFromCoins(player, coinAmount, reason)
	local coins = math.max(0, math.floor(tonumber(coinAmount) or 0))
	if coins <= 0 then
		return false
	end

	local xp = math.clamp(math.floor(coins / COIN_XP_DIVISOR), 1, MAX_COIN_XP_PER_AWARD)
	return RankService.AwardXP(player, xp, reason or "rank-coins")
end

function RankService.AwardForHatch(player, eggId, hatchCost)
	local costBonus = math.clamp(math.floor((tonumber(hatchCost) or 0) / 60), 0, 250)
	return RankService.AwardXP(player, 125 + costBonus, "rank-hatch-" .. tostring(eggId or "egg"))
end

function RankService.AwardForWorldUnlock(player, world)
	local unlockCost = tonumber(world and world.unlockCost) or 0
	local xp = 900 + math.clamp(math.floor(unlockCost / 120), 0, 2500)
	return RankService.AwardXP(player, xp, "rank-world")
end

function RankService.AwardForDailyQuest(player)
	return RankService.AwardXP(player, 350, "rank-daily-quest")
end

function RankService.GetCoinMultiplier(player)
	local rankLevel = player and tonumber(player:GetAttribute("RankLevel")) or 1
	return tonumber(getRankInfo(rankLevel).CoinMultiplier) or 1
end

function RankService.GetLuckMultiplier(player)
	local rankLevel = player and tonumber(player:GetAttribute("RankLevel")) or 1
	return tonumber(getRankInfo(rankLevel).LuckMultiplier) or 1
end

function RankService.GetExtraEquippedColorSlots(player)
	local rankLevel = player and tonumber(player:GetAttribute("RankLevel")) or 1
	return math.max(0, math.floor(tonumber(getRankInfo(rankLevel).ExtraEquipSlots) or 0))
end

local function watchRankFolder(player, folder)
	if not folder or folder:GetAttribute("RankServiceWatched") == true then
		return
	end
	folder:SetAttribute("RankServiceWatched", true)

	local function bindValue(value)
		if value:IsA("ValueBase") then
			value:GetPropertyChangedSignal("Value"):Connect(function()
				RankService.SyncPlayerAttributes(player)
			end)
		end
	end

	for _, child in ipairs(folder:GetChildren()) do
		bindValue(child)
	end
	folder.ChildAdded:Connect(function(child)
		bindValue(child)
		RankService.SyncPlayerAttributes(player)
	end)
	RankService.SyncPlayerAttributes(player)
end

local function watchPlayer(player)
	if watchedPlayers[player] then
		return
	end
	watchedPlayers[player] = true
	player.ChildAdded:Connect(function(child)
		if child.Name == "RankData" then
			watchRankFolder(player, child)
		end
	end)

	local existing = player:FindFirstChild("RankData")
	if existing then
		watchRankFolder(player, existing)
	else
		syncAttributes(player, 1, 0, 0)
	end
end

Players.PlayerAdded:Connect(watchPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	task.defer(watchPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
	watchedPlayers[player] = nil
end)

task.spawn(function()
	while true do
		task.wait(PASSIVE_XP_INTERVAL)
		for _, player in ipairs(Players:GetPlayers()) do
			if player:GetAttribute("DataManagerReady") == true then
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if humanoid and humanoid.Health > 0 then
					RankService.AwardXP(player, PASSIVE_XP_AMOUNT, "rank-active-play")
				end
			end
		end
	end
end)

RankService.MaxRank = MAX_RANK

return RankService
