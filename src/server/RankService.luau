local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RankDefinitions = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RankDefinitions"))

local Events = ReplicatedStorage:WaitForChild("Events")

local function ensureRemoteEvent(name)
	local existing = Events:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = Events
	return remote
end

local function ensureBindableEvent(name)
	local existing = Events:FindFirstChild(name)
	if existing and existing:IsA("BindableEvent") then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local event = Instance.new("BindableEvent")
	event.Name = name
	event.Parent = Events
	return event
end

local rankDataUpdated = ensureRemoteEvent("RankDataUpdated")
local rankUpRequest = ensureRemoteEvent("RankUpRequest")
local rankUpResult = ensureRemoteEvent("RankUpResult")
local rebirthRequest = ensureRemoteEvent("RebirthRequest")
local rebirthResult = ensureRemoteEvent("RebirthResult")
local rankMenuOpened = ensureRemoteEvent("RankMenuOpened")

local playerDataDirtyEvent = ensureBindableEvent("PlayerDataDirty")
local tutorialColorEquippedEvent = ensureBindableEvent("TutorialColorEquipped")

local RankService = {}

local watchedPlayers = {}

local function clampRank(rankLevel)
	return math.clamp(math.floor(tonumber(rankLevel) or 1), 1, RankDefinitions.MaxRank)
end

local function getRankInfo(rankLevel)
	return RankDefinitions.GetRank(rankLevel)
end

local function getXPRequired(rankLevel)
	return math.max(0, math.floor(tonumber(getRankInfo(rankLevel).XPRequired) or 0))
end

local function getQuestsRequired(rankLevel)
	return math.max(1, math.floor(tonumber(getRankInfo(rankLevel).QuestsRequired) or 10))
end

local function decodeProgress(value)
	if type(value) == "table" then
		local copy = {}
		for key, amount in pairs(value) do
			copy[tostring(key)] = math.max(0, math.floor(tonumber(amount) or 0))
		end
		return copy
	end

	value = tostring(value or "")
	if value == "" then
		return {}
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(value)
	end)
	if not ok or type(decoded) ~= "table" then
		return {}
	end
	return decodeProgress(decoded)
end

local function encodeProgress(progress)
	local ok, encoded = pcall(function()
		return HttpService:JSONEncode(type(progress) == "table" and progress or {})
	end)
	return ok and encoded or "{}"
end

local function getValue(folder, name)
	local value = folder and folder:FindFirstChild(name)
	return value and value:IsA("ValueBase") and value or nil
end

local function getOrCreateInt(folder, name, defaultValue)
	local value = getValue(folder, name)
	if value and not value:IsA("IntValue") then
		value:Destroy()
		value = nil
	end
	if not value then
		value = Instance.new("IntValue")
		value.Name = name
		value.Parent = folder
	end
	value.Value = math.max(0, math.floor(tonumber(value.Value) or tonumber(defaultValue) or 0))
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
	if value.Value == "" and defaultValue then
		value.Value = tostring(defaultValue)
	end
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
		getOrCreateString(folder, "RankName", getRankInfo(1).Name),
		getOrCreateString(folder, "RankIcon", getRankInfo(1).Icon),
		getOrCreateInt(folder, "CompletedRankQuests", 0),
		getOrCreateString(folder, "RankQuestProgress", "{}"),
		getOrCreateInt(folder, "Rebirths", 0)
end

local function getRebirths(player, folder)
	local leaderstats = player and player:FindFirstChild("leaderstats")
	local stat = leaderstats and leaderstats:FindFirstChild("Rebirths")
	if stat and stat:IsA("ValueBase") then
		return math.max(0, math.floor(tonumber(stat.Value) or 0))
	end
	local rankRebirths = folder and folder:FindFirstChild("Rebirths")
	return math.max(0, math.floor(tonumber(rankRebirths and rankRebirths.Value) or 0))
end

local function countCompletedQuests(rankLevel, progress)
	local completed = 0
	for _, quest in ipairs(RankDefinitions.GetQuests(rankLevel)) do
		local amount = math.max(0, math.floor(tonumber(progress[quest.Id]) or 0))
		if amount >= (tonumber(quest.Target) or 1) then
			completed += 1
		end
	end
	return completed
end

local function buildQuestRows(rankLevel, progress)
	local rows = {}
	for index, quest in ipairs(RankDefinitions.GetQuests(rankLevel)) do
		local amount = math.max(0, math.floor(tonumber(progress[quest.Id]) or 0))
		local target = math.max(1, math.floor(tonumber(quest.Target) or 1))
		table.insert(rows, {
			Index = index,
			Id = quest.Id,
			Text = quest.Text,
			Progress = math.min(amount, target),
			Target = target,
			Completed = amount >= target,
		})
	end
	return rows
end

local function getRequirementsMet(rankLevel, rankXP, completed)
	return rankXP >= getXPRequired(rankLevel) and completed >= getQuestsRequired(rankLevel)
end

local function getRebirthMultiplier(base, rebirths)
	rebirths = math.max(0, math.floor(tonumber(rebirths) or 0))
	return math.pow(tonumber(base) or 1, rebirths)
end

local function getPassive(rankLevel, name)
	local info = getRankInfo(rankLevel)
	return tonumber(info.Passives and info.Passives[name]) or 1
end

local function syncAttributes(player, rankLevel, rankXP, totalXP, progress, rebirths)
	rankLevel = clampRank(rankLevel)
	local info = getRankInfo(rankLevel)
	local completed = countCompletedQuests(rankLevel, progress)
	local xpRequired = getXPRequired(rankLevel)
	local requirementsMet = getRequirementsMet(rankLevel, rankXP, completed)

	player:SetAttribute("RankLevel", rankLevel)
	player:SetAttribute("RankName", info.Name)
	player:SetAttribute("CurrentRank", info.Name)
	player:SetAttribute("Rank", info.Name)
	player:SetAttribute("RankIcon", info.Icon)
	player:SetAttribute("RankXP", math.max(0, math.floor(tonumber(rankXP) or 0)))
	player:SetAttribute("Experience", math.max(0, math.floor(tonumber(rankXP) or 0)))
	player:SetAttribute("RankTotalXP", math.max(0, math.floor(tonumber(totalXP) or 0)))
	player:SetAttribute("NextRankXP", xpRequired)
	player:SetAttribute("RankXPRequired", xpRequired)
	player:SetAttribute("RankMaxRank", RankDefinitions.MaxRank)
	player:SetAttribute("RankIsMaxed", rankLevel >= RankDefinitions.MaxRank)
	player:SetAttribute("RankCompletedQuests", completed)
	player:SetAttribute("RankQuestsRequired", getQuestsRequired(rankLevel))
	player:SetAttribute("RankUpAvailable", rankLevel < RankDefinitions.MaxRank and requirementsMet)
	player:SetAttribute("RebirthAvailable", rankLevel >= RankDefinitions.MaxRank and requirementsMet)
	player:SetAttribute("Rebirths", rebirths)
	player:SetAttribute("RankCoinBonusPercent", math.floor((RankService.GetRewardMultiplier(player) - 1) * 100 + 0.5))
	player:SetAttribute("RankLuckBonusPercent", math.floor((RankService.GetLuckMultiplier(player) - 1) * 100 + 0.5))
	player:SetAttribute(
		"RankPetDamageBonusPercent",
		math.floor((RankService.GetPetDamageMultiplier(player) - 1) * 100 + 0.5)
	)
	player:SetAttribute("RankExtraEquipSlots", 0)
end

local function buildPayload(player)
	local folder, rankValue, xpValue, totalValue, requiredValue, nameValue, iconValue, completedValue, progressValue =
		getRankValues(player, false)
	if not folder then
		return nil
	end
	local rankLevel = clampRank(rankValue.Value)
	local progress = decodeProgress(progressValue.Value)
	local completed = countCompletedQuests(rankLevel, progress)
	local rebirths = getRebirths(player, folder)
	return {
		RankLevel = rankLevel,
		RankName = getRankInfo(rankLevel).Name,
		RankIcon = getRankInfo(rankLevel).Icon,
		RankXP = math.max(0, math.floor(tonumber(xpValue.Value) or 0)),
		RankTotalXP = math.max(0, math.floor(tonumber(totalValue.Value) or 0)),
		RankXPRequired = getXPRequired(rankLevel),
		CompletedRankQuests = completed,
		QuestsRequired = getQuestsRequired(rankLevel),
		Quests = buildQuestRows(rankLevel, progress),
		RankUpAvailable = rankLevel < RankDefinitions.MaxRank
			and getRequirementsMet(rankLevel, xpValue.Value, completed),
		RebirthAvailable = rankLevel >= RankDefinitions.MaxRank
			and getRequirementsMet(rankLevel, xpValue.Value, completed),
		Rebirths = rebirths,
		MaxRank = RankDefinitions.MaxRank,
		Passives = getRankInfo(rankLevel).Passives,
		NextPassives = getRankInfo(math.min(rankLevel + 1, RankDefinitions.MaxRank)).Passives,
	}
end

local function updateFolder(player, rankLevel, rankXP, totalXP, progress, rebirths)
	local folder, rankValue, xpValue, totalValue, requiredValue, nameValue, iconValue, completedValue, progressValue, rebirthValue =
		getRankValues(player, true)
	if not folder then
		return nil
	end

	rankLevel = clampRank(rankLevel)
	local xpRequired = getXPRequired(rankLevel)
	rankXP = math.clamp(math.floor(tonumber(rankXP) or 0), 0, xpRequired)
	totalXP = math.max(0, math.floor(tonumber(totalXP) or 0))
	progress = decodeProgress(progress)
	rebirths = math.max(0, math.floor(tonumber(rebirths) or getRebirths(player, folder)))

	rankValue.Value = rankLevel
	xpValue.Value = rankXP
	totalValue.Value = totalXP
	requiredValue.Value = xpRequired
	nameValue.Value = getRankInfo(rankLevel).Name
	iconValue.Value = getRankInfo(rankLevel).Icon
	completedValue.Value = countCompletedQuests(rankLevel, progress)
	progressValue.Value = encodeProgress(progress)
	rebirthValue.Value = rebirths

	local leaderstats = player:FindFirstChild("leaderstats")
	local rebirthStat = leaderstats and leaderstats:FindFirstChild("Rebirths")
	if rebirthStat and rebirthStat:IsA("ValueBase") then
		rebirthStat.Value = rebirths
	end

	syncAttributes(player, rankLevel, rankXP, totalXP, progress, rebirths)
	rankDataUpdated:FireClient(player, buildPayload(player))
	return folder
end

local function dirty(player, reason)
	playerDataDirtyEvent:Fire(player, reason or "rank")
end

function RankService.NormalizeData(data)
	data = type(data) == "table" and data or {}
	local rankLevel = clampRank(data.RankLevel or data.CurrentRankLevel or data.Level)
	local rankXP = math.max(0, math.floor(tonumber(data.RankXP or data.XP or data.Experience) or 0))
	local totalXP = math.max(0, math.floor(tonumber(data.RankTotalXP or data.TotalXP) or rankXP))
	local progress = decodeProgress(data.RankQuestProgress)
	return {
		RankLevel = rankLevel,
		RankXP = math.clamp(rankXP, 0, getXPRequired(rankLevel)),
		RankTotalXP = totalXP,
		RankQuestProgress = encodeProgress(progress),
		CompletedRankQuests = countCompletedQuests(rankLevel, progress),
		Rebirths = math.max(0, math.floor(tonumber(data.Rebirths) or 0)),
	}
end

function RankService.GetInfo(rankLevel)
	return getRankInfo(rankLevel)
end

function RankService.GetXPRequired(rankLevel)
	return getXPRequired(rankLevel)
end

function RankService.SyncPlayerAttributes(player)
	local folder, rankValue, xpValue, totalValue, requiredValue, nameValue, iconValue, completedValue, progressValue =
		getRankValues(player, false)
	if not folder then
		syncAttributes(player, 1, 0, 0, {}, 0)
		return
	end
	local rankLevel = clampRank(rankValue.Value)
	local progress = decodeProgress(progressValue.Value)
	requiredValue.Value = getXPRequired(rankLevel)
	nameValue.Value = getRankInfo(rankLevel).Name
	iconValue.Value = getRankInfo(rankLevel).Icon
	completedValue.Value = countCompletedQuests(rankLevel, progress)
	syncAttributes(player, rankLevel, xpValue.Value, totalValue.Value, progress, getRebirths(player, folder))
end

function RankService.ApplyToFolder(player, folder, rankData)
	if not player or not folder then
		return
	end
	local normalized = RankService.NormalizeData(rankData)
	updateFolder(
		player,
		normalized.RankLevel,
		normalized.RankXP,
		normalized.RankTotalXP,
		decodeProgress(normalized.RankQuestProgress),
		normalized.Rebirths
	)
end

local function progressQuest(player, matcher, amount)
	amount = math.max(0, math.floor(tonumber(amount) or 0))
	if not player or amount <= 0 then
		return false
	end

	local folder, rankValue, xpValue, totalValue, _requiredValue, _nameValue, _iconValue, _completedValue, progressValue =
		getRankValues(player, true)
	if not folder then
		return false
	end

	local rankLevel = clampRank(rankValue.Value)
	local progress = decodeProgress(progressValue.Value)
	local changed = false
	for _, quest in ipairs(RankDefinitions.GetQuests(rankLevel)) do
		if matcher(quest) then
			local target = math.max(1, math.floor(tonumber(quest.Target) or 1))
			local old = math.max(0, math.floor(tonumber(progress[quest.Id]) or 0))
			local nextValue = math.min(target, old + amount)
			if nextValue ~= old then
				progress[quest.Id] = nextValue
				changed = true
			end
		end
	end

	if changed then
		updateFolder(player, rankLevel, xpValue.Value, totalValue.Value, progress, getRebirths(player, folder))
		dirty(player, "rank-quest")
	end
	return changed
end

function RankService.AwardXP(player, amount, reason)
	amount = math.max(0, math.floor((tonumber(amount) or 0) + 0.5))
	if not player or amount <= 0 then
		return false
	end

	local folder, rankValue, xpValue, totalValue, _requiredValue, _nameValue, _iconValue, _completedValue, progressValue =
		getRankValues(player, true)
	if not folder then
		return false
	end

	local rankLevel = clampRank(rankValue.Value)
	local required = getXPRequired(rankLevel)
	local oldXP = math.max(0, math.floor(tonumber(xpValue.Value) or 0))
	local added = math.max(0, math.min(required, oldXP + amount) - oldXP)
	local totalXP = math.max(0, math.floor(tonumber(totalValue.Value) or 0)) + amount
	local progress = decodeProgress(progressValue.Value)
	if added > 0 then
		for _, quest in ipairs(RankDefinitions.GetQuests(rankLevel)) do
			if quest.Kind == "RankXP" then
				local target = math.max(1, math.floor(tonumber(quest.Target) or 1))
				progress[quest.Id] =
					math.min(target, math.max(0, math.floor(tonumber(progress[quest.Id]) or 0)) + added)
			end
		end
	end

	updateFolder(player, rankLevel, oldXP + added, totalXP, progress, getRebirths(player, folder))
	dirty(player, reason or "rank-xp")
	return true
end

function RankService.AwardFromRewards(player, coins, gems, reason)
	coins = math.max(0, math.floor(tonumber(coins) or 0))
	gems = math.max(0, math.floor(tonumber(gems) or 0))
	if coins > 0 then
		progressQuest(player, function(quest)
			return quest.Kind == "Coins"
		end, coins)
	end
	if gems > 0 then
		progressQuest(player, function(quest)
			return quest.Kind == "Gems"
		end, gems)
	end
	local xp = coins * (RankDefinitions.XP.Coins or 0.1) + gems * (RankDefinitions.XP.Gems or 2)
	if xp > 0 then
		return RankService.AwardXP(player, xp, reason or "rank-rewards")
	end
	return false
end

function RankService.AwardFromCoins(player, coinAmount, reason)
	return RankService.AwardFromRewards(player, coinAmount, 0, reason or "rank-coins")
end

function RankService.AwardForHatch(player, eggId, hatchCost)
	return RankService.RecordHatch(player, "Common")
end

function RankService.AwardForWorldUnlock(_player, _world)
	return false
end

function RankService.AwardForDailyQuest(_player)
	return false
end

function RankService.RecordBreakableBroken(player, breakableType)
	progressQuest(player, function(quest)
		return quest.Kind == "BreakableAny"
	end, 1)
	progressQuest(player, function(quest)
		return quest.Kind == "BreakableType" and quest.BreakableType == breakableType
	end, 1)
end

function RankService.RecordHatch(player, rarity)
	progressQuest(player, function(quest)
		return quest.Kind == "Hatch"
	end, 1)
	progressQuest(player, function(quest)
		return quest.Kind == "HatchRarityAtLeast" and RankDefinitions.IsRarityAtLeast(rarity, quest.Rarity)
	end, 1)
end

function RankService.RecordColorEquipped(player)
	progressQuest(player, function(quest)
		return quest.Kind == "EquipColor"
	end, 1)
end

function RankService.RecordRankMenuOpened(player)
	progressQuest(player, function(quest)
		return quest.Kind == "OpenRank"
	end, 1)
end

function RankService.GetRewardMultiplier(player)
	local rankLevel = player and tonumber(player:GetAttribute("RankLevel")) or 1
	local rebirths = player and tonumber(player:GetAttribute("Rebirths")) or 0
	return getPassive(rankLevel, "RewardMultiplier")
		* getRebirthMultiplier(RankDefinitions.Rebirth.RewardMultiplier, rebirths)
end

function RankService.GetCoinMultiplier(player)
	return RankService.GetRewardMultiplier(player)
end

function RankService.GetGemMultiplier(player)
	return RankService.GetRewardMultiplier(player)
end

function RankService.GetLuckMultiplier(player)
	local rankLevel = player and tonumber(player:GetAttribute("RankLevel")) or 1
	local rebirths = player and tonumber(player:GetAttribute("Rebirths")) or 0
	return getPassive(rankLevel, "EggLuckMultiplier")
		* getRebirthMultiplier(RankDefinitions.Rebirth.EggLuckMultiplier, rebirths)
end

function RankService.GetEggLuckMultiplier(player)
	return RankService.GetLuckMultiplier(player)
end

function RankService.GetMutationChanceMultiplier(player)
	local rankLevel = player and tonumber(player:GetAttribute("RankLevel")) or 1
	return getPassive(rankLevel, "MutationChanceMultiplier")
end

function RankService.GetPetDamageMultiplier(player)
	local rankLevel = player and tonumber(player:GetAttribute("RankLevel")) or 1
	local rebirths = player and tonumber(player:GetAttribute("Rebirths")) or 0
	return getPassive(rankLevel, "PetDamageMultiplier")
		* getRebirthMultiplier(RankDefinitions.Rebirth.PetDamageMultiplier, rebirths)
end

function RankService.GetExtraEquippedColorSlots(_player)
	return 0
end

local function addLeaderstat(player, name, amount)
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 then
		return 0
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild(name)
	if value and value:IsA("ValueBase") then
		value.Value += amount
		return amount
	end
	return 0
end

function RankService.TryRankUp(player)
	local payload = buildPayload(player)
	if not payload or payload.RankLevel >= RankDefinitions.MaxRank or payload.RankUpAvailable ~= true then
		rankUpResult:FireClient(player, false, {
			Message = "Complete Rank XP and all 10 quests first.",
			RankData = payload,
		})
		return false
	end

	local oldRank = payload.RankLevel
	local newRank = oldRank + 1
	local newInfo = getRankInfo(newRank)
	addLeaderstat(player, "Coins", newInfo.RewardCoins)
	addLeaderstat(player, "Gems", newInfo.RewardGems)
	updateFolder(player, newRank, 0, payload.RankTotalXP, {}, payload.Rebirths)
	dirty(player, "rank-up")
	rankUpResult:FireClient(player, true, {
		OldRank = oldRank,
		OldRankName = payload.RankName,
		NewRank = newRank,
		NewRankName = newInfo.Name,
		RewardCoins = newInfo.RewardCoins,
		RewardGems = newInfo.RewardGems,
		Passives = newInfo.Passives,
		RankData = buildPayload(player),
	})
	return true
end

function RankService.TryRebirth(player)
	local payload = buildPayload(player)
	if not payload or payload.RebirthAvailable ~= true then
		rebirthResult:FireClient(player, false, {
			Message = "Reach Rank 5 and complete every requirement first.",
			RankData = payload,
		})
		return false
	end

	local rebirths = payload.Rebirths + 1
	updateFolder(player, 1, 0, payload.RankTotalXP, {}, rebirths)
	dirty(player, "rebirth")
	rebirthResult:FireClient(player, true, {
		Rebirths = rebirths,
		RankData = buildPayload(player),
	})
	return true
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
	rankDataUpdated:FireClient(player, buildPayload(player))
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
		syncAttributes(player, 1, 0, 0, {}, 0)
	end
end

rankUpRequest.OnServerEvent:Connect(function(player)
	RankService.TryRankUp(player)
end)

rebirthRequest.OnServerEvent:Connect(function(player)
	RankService.TryRebirth(player)
end)

rankMenuOpened.OnServerEvent:Connect(function(player)
	RankService.RecordRankMenuOpened(player)
	rankDataUpdated:FireClient(player, buildPayload(player))
end)

tutorialColorEquippedEvent.Event:Connect(function(player)
	RankService.RecordColorEquipped(player)
end)

Players.PlayerAdded:Connect(watchPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	task.defer(watchPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
	watchedPlayers[player] = nil
end)

RankService.MaxRank = RankDefinitions.MaxRank

return RankService
