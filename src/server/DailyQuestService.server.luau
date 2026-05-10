-- ServerScriptService/Server/DailyQuestService
-- Server-owned daily quests. Other server systems report progress through ServerStorage.DailyQuestProgress.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local NPC_NAME = "Zork"
local QUESTS_PER_DAY = 3
local ZORK_INTRO_VERSION = 3

local Events = ReplicatedStorage:FindFirstChild("Events")
if not Events then
	Events = Instance.new("Folder")
	Events.Name = "Events"
	Events.Parent = ReplicatedStorage
end

local tutorialDailyQuestsIntroducedEvent = Events:FindFirstChild("TutorialDailyQuestsIntroduced")
if not tutorialDailyQuestsIntroducedEvent then
	tutorialDailyQuestsIntroducedEvent = Instance.new("BindableEvent")
	tutorialDailyQuestsIntroducedEvent.Name = "TutorialDailyQuestsIntroduced"
	tutorialDailyQuestsIntroducedEvent.Parent = Events
end

local DailyQuestStore = DataStoreService:GetDataStore("DailyQuestData_v1")

local DailyQuestRemote = ReplicatedStorage:FindFirstChild("DailyQuestRemote")
if not DailyQuestRemote then
	DailyQuestRemote = Instance.new("RemoteEvent")
	DailyQuestRemote.Name = "DailyQuestRemote"
	DailyQuestRemote.Parent = ReplicatedStorage
end

local DailyQuestProgress = ServerStorage:FindFirstChild("DailyQuestProgress")
if not DailyQuestProgress then
	DailyQuestProgress = Instance.new("BindableEvent")
	DailyQuestProgress.Name = "DailyQuestProgress"
	DailyQuestProgress.Parent = ServerStorage
end

local DAILY_QUEST_POOL = {
	{
		Id = "CleanColorSpills",
		Title = "CLEAN COLOR SPILLS",
		Description = "Clean 40 color spills.",
		IconText = "BRUSH",
		ProgressType = "ColorSpillsCleaned",
		Target = 40,
		RewardCurrency = "Gems",
		RewardAmount = 20,
	},
	{
		Id = "EarnCoins",
		Title = "EARN COINS",
		Description = "Earn 1,000 coins.",
		IconText = "COINS",
		ProgressType = "CoinsEarned",
		Target = 1000,
		RewardCurrency = "Gems",
		RewardAmount = 25,
	},
	{
		Id = "HatchColors",
		Title = "HATCH COLORS",
		Description = "Hatch 3 colors from eggs.",
		IconText = "EGG",
		ProgressType = "ColorsHatched",
		Target = 3,
		RewardCurrency = "Gems",
		RewardAmount = 30,
	},
	{
		Id = "BreakGemDeposits",
		Title = "BREAK GEM DEPOSITS",
		Description = "Break 3 gem deposits.",
		IconText = "GEM",
		ProgressType = "GemDepositsBroken",
		Target = 3,
		RewardCurrency = "Gems",
		RewardAmount = 25,
	},
	{
		Id = "CleanRedWastelands",
		Title = "CLEAN RED WASTELANDS",
		Description = "Clean 25 spills in the Red Wastelands.",
		IconText = "RED",
		ProgressType = "RedWastelandsSpillsCleaned",
		Target = 25,
		RewardCurrency = "Gems",
		RewardAmount = 20,
	},
	{
		Id = "UseBrush",
		Title = "USE YOUR BRUSH",
		Description = "Clean with your brush 75 times.",
		IconText = "BRUSH",
		ProgressType = "BrushUses",
		Target = 75,
		RewardCurrency = "Gems",
		RewardAmount = 15,
	},
}

local profiles = {}

local QUEST_BY_ID = {}
local DEFAULT_QUEST_IDS = {
	"CleanColorSpills",
	"EarnCoins",
	"HatchColors",
}
local LEGACY_QUEST_ID_MAP = {
	CleanSpills = "CleanColorSpills",
	BreakGems = "BreakGemDeposits",
}

for _, quest in ipairs(DAILY_QUEST_POOL) do
	QUEST_BY_ID[quest.Id] = quest
end

local function getCurrentDayId()
	return math.floor(os.time() / 86400)
end

local function getSecondsUntilReset()
	return 86400 - (os.time() % 86400)
end

local function getKey(player)
	return "Player_" .. player.UserId
end

local function copyQuest(template, existing)
	local target = math.max(1, tonumber(template.Target) or 1)
	local progress = existing and math.clamp(tonumber(existing.progress or existing.Progress) or 0, 0, target) or 0
	return {
		id = template.Id,
		title = template.Title,
		description = template.Description,
		iconText = template.IconText,
		progressType = template.ProgressType,
		target = target,
		rewardCurrency = template.RewardCurrency,
		rewardAmount = math.max(0, tonumber(template.RewardAmount) or 0),
		reward = math.max(0, tonumber(template.RewardAmount) or 0),
		progress = progress,
		claimed = existing and existing.claimed == true or false,
	}
end

local function buildNewProfile(player, zorkIntroduced)
	local dayId = getCurrentDayId()
	local seed = (math.abs(player.UserId) * 97 + dayId * 1009) % 2147483647
	local rng = Random.new(seed)

	local pool = table.clone(DAILY_QUEST_POOL)
	local quests = {}
	local questIds = {}
	for _ = 1, math.min(QUESTS_PER_DAY, #pool) do
		local index = rng:NextInteger(1, #pool)
		table.insert(quests, copyQuest(pool[index]))
		table.insert(questIds, pool[index].Id)
		table.remove(pool, index)
	end
	for index = #quests + 1, QUESTS_PER_DAY do
		local template = QUEST_BY_ID[DEFAULT_QUEST_IDS[index]] or DAILY_QUEST_POOL[index]
		table.insert(quests, copyQuest(template))
		table.insert(questIds, template.Id)
	end

	return {
		dayId = dayId,
		questIds = questIds,
		quests = quests,
		zorkIntroduced = zorkIntroduced == true,
		zorkIntroVersion = zorkIntroduced == true and ZORK_INTRO_VERSION or 0,
		dirty = true,
	}
end

local function buildFallbackQuest(index)
	local template = QUEST_BY_ID[DEFAULT_QUEST_IDS[index]] or DAILY_QUEST_POOL[index] or DAILY_QUEST_POOL[1]
	return copyQuest(template)
end

local function getExactlyThreeQuests(profile)
	local quests = {}
	for index = 1, QUESTS_PER_DAY do
		local quest = profile and type(profile.quests) == "table" and profile.quests[index] or nil
		if type(quest) == "table" then
			local questId = tostring(quest.id or quest.Id or "")
			questId = LEGACY_QUEST_ID_MAP[questId] or questId
			local template = QUEST_BY_ID[questId]
			if template then
				quests[index] = copyQuest(template, quest)
			else
				quests[index] = buildFallbackQuest(index)
			end
		else
			quests[index] = buildFallbackQuest(index)
		end
	end
	return quests
end

local function hasCurrentZorkIntro(data)
	return data
		and data.zorkIntroduced == true
		and tonumber(data.zorkIntroVersion) == ZORK_INTRO_VERSION
end

local function normalizeProfile(player, data)
	if type(data) ~= "table" then
		return buildNewProfile(player)
	end
	if tonumber(data.dayId) ~= getCurrentDayId() then
		return buildNewProfile(player, hasCurrentZorkIntro(data))
	end
	if type(data.quests) ~= "table" or #data.quests ~= QUESTS_PER_DAY then
		return buildNewProfile(player, hasCurrentZorkIntro(data))
	end

	local questIds = {}
	for index, quest in ipairs(data.quests) do
		local questId = tostring(quest.id or quest.Id or "")
		questId = LEGACY_QUEST_ID_MAP[questId] or questId
		local template = QUEST_BY_ID[questId]
		if not template then
			return buildNewProfile(player, hasCurrentZorkIntro(data))
		end
		data.quests[index] = copyQuest(template, quest)
		table.insert(questIds, template.Id)
	end

	data.questIds = questIds
	data.zorkIntroduced = hasCurrentZorkIntro(data)
	data.zorkIntroVersion = data.zorkIntroduced and ZORK_INTRO_VERSION or 0
	data.dirty = false
	return data
end

local function serializeProfile(profile)
	local quests = {}
	for index, quest in ipairs(getExactlyThreeQuests(profile)) do
		quests[index] = {
			id = quest.id,
			iconText = quest.iconText,
			progressType = quest.progressType,
			title = quest.title,
			description = quest.description,
			target = quest.target,
			rewardCurrency = quest.rewardCurrency,
			rewardAmount = quest.rewardAmount,
			reward = quest.reward,
			progress = quest.progress,
			claimed = quest.claimed == true,
		}
	end
	return {
		dayId = profile.dayId,
		questIds = profile.questIds,
		quests = quests,
		zorkIntroduced = profile.zorkIntroduced == true,
		zorkIntroVersion = profile.zorkIntroduced == true and ZORK_INTRO_VERSION or 0,
	}
end

local function makeClientData(profile)
	local quests = {}
	for index, quest in ipairs(getExactlyThreeQuests(profile)) do
		quests[index] = {
			id = quest.id,
			iconText = quest.iconText,
			progressType = quest.progressType,
			title = quest.title,
			description = quest.description,
			target = quest.target,
			rewardCurrency = quest.rewardCurrency,
			rewardAmount = quest.rewardAmount,
			reward = quest.reward,
			progress = quest.progress,
			claimed = quest.claimed == true,
		}
	end
	return {
		resetIn = getSecondsUntilReset(),
		quests = quests,
		Quests = quests,
		zorkIntroduced = profile.zorkIntroduced == true,
	}
end

local function setZorkIntroduced(player, profile)
	if not profile then
		return
	end

	if profile.zorkIntroduced ~= true then
		profile.zorkIntroduced = true
		profile.zorkIntroVersion = ZORK_INTRO_VERSION
		profile.dirty = true
	end
	player:SetAttribute("DailyQuestsHudUnlocked", true)
	if tutorialDailyQuestsIntroducedEvent and tutorialDailyQuestsIntroducedEvent:IsA("BindableEvent") then
		tutorialDailyQuestsIntroducedEvent:Fire(player)
	end
end

local function saveProfile(player, force)
	local profile = profiles[player]
	if not profile then
		return false
	end
	if not force and not profile.dirty then
		return true
	end

	local dataToSave = serializeProfile(profile)
	local success, err = pcall(function()
		DailyQuestStore:UpdateAsync(getKey(player), function()
			return dataToSave
		end)
	end)

	if success then
		profile.dirty = false
		return true
	end

	warn("Daily quest save failed for " .. player.Name .. ": " .. tostring(err))
	return false
end

local function findGemValue(player)
	local foldersToCheck = {
		"leaderstats",
		"Stats",
		"Data",
		"PlayerData",
		"Currencies",
	}

	for _, folderName in ipairs(foldersToCheck) do
		local folder = player:FindFirstChild(folderName)
		if folder then
			local gems = folder:FindFirstChild("Gems")
			if gems and (gems:IsA("IntValue") or gems:IsA("NumberValue")) then
				return gems
			end
		end
	end

	local directGems = player:FindFirstChild("Gems")
	if directGems and (directGems:IsA("IntValue") or directGems:IsA("NumberValue")) then
		return directGems
	end
	return nil
end

local function addGems(player, amount)
	local gems = findGemValue(player)
	if not gems then
		local leaderstats = player:FindFirstChild("leaderstats")
		if not leaderstats then
			leaderstats = Instance.new("Folder")
			leaderstats.Name = "leaderstats"
			leaderstats.Parent = player
		end

		local existing = leaderstats:FindFirstChild("Gems")
		if existing then
			warn("Gems exists but is not an IntValue or NumberValue.")
			return false
		end

		gems = Instance.new("IntValue")
		gems.Name = "Gems"
		gems.Value = 0
		gems.Parent = leaderstats
	end

	gems.Value += math.max(0, math.floor(tonumber(amount) or 0))

	local events = ReplicatedStorage:FindFirstChild("Events")
	local dirtyEvent = events and events:FindFirstChild("PlayerDataDirty")
	if dirtyEvent and dirtyEvent:IsA("BindableEvent") then
		dirtyEvent:Fire(player, "gems")
	end
	return true
end

local function refreshDailyQuests(player)
	local profile = profiles[player]
	if not profile then
		return nil
	end

	if tonumber(profile.dayId) ~= getCurrentDayId() then
		profiles[player] = buildNewProfile(player, profile.zorkIntroduced == true)
		profile = profiles[player]
		saveProfile(player, true)
	end
	if type(profile.quests) ~= "table" or #profile.quests ~= QUESTS_PER_DAY then
		warn("DailyQuestService: repaired invalid quest list for " .. player.Name)
		profile.quests = getExactlyThreeQuests(profile)
		profile.questIds = {}
		for index, quest in ipairs(profile.quests) do
			profile.questIds[index] = quest.id
		end
		profile.dirty = true
	end
	player:SetAttribute("DailyQuestsHudUnlocked", profile.zorkIntroduced == true)

	return profile
end

local function loadProfile(player)
	local data
	local success, result = pcall(function()
		return DailyQuestStore:GetAsync(getKey(player))
	end)

	if success then
		data = result
	else
		warn("Daily quest load failed for " .. player.Name .. ": " .. tostring(result))
	end

	local profile = normalizeProfile(player, data)
	profiles[player] = profile
	player:SetAttribute("DailyQuestsHudUnlocked", profile.zorkIntroduced == true)
	DailyQuestRemote:FireClient(player, "Update", makeClientData(profile))
end

local function addQuestProgress(player, progressType, amount)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end

	local profile = profiles[player]
	if not profile then
		return
	end

	profile = refreshDailyQuests(player)
	if not profile then
		return
	end

	progressType = tostring(progressType)
	amount = math.max(1, math.floor(tonumber(amount) or 1))

	local changed = false
	for _, quest in ipairs(profile.quests) do
		if (quest.progressType == progressType or quest.id == progressType) and not quest.claimed then
			local oldProgress = quest.progress
			quest.progress = math.min(quest.target, quest.progress + amount)
			if quest.progress ~= oldProgress then
				changed = true
			end
		end
	end

	if changed then
		profile.dirty = true
		DailyQuestRemote:FireClient(player, "Update", makeClientData(profile))
	end
end

local function claimQuest(player, slot)
	local profile = profiles[player]
	if not profile then
		return
	end

	profile = refreshDailyQuests(player)
	if not profile then
		return
	end

	local quest = profile.quests[tonumber(slot)]
	if not quest or quest.claimed or quest.progress < quest.target then
		return
	end

	quest.claimed = true
	profile.dirty = true

	if not addGems(player, quest.reward) then
		quest.claimed = false
		return
	end

	saveProfile(player, true)
	DailyQuestRemote:FireClient(player, "Update", makeClientData(profile))
end

DailyQuestProgress.Event:Connect(addQuestProgress)

DailyQuestRemote.OnServerEvent:Connect(function(player, action, value)
	if action == "Get" then
		if not profiles[player] then
			loadProfile(player)
		end
		local profile = refreshDailyQuests(player)
		if profile then
			if profile.zorkIntroduced ~= true then
				player:SetAttribute("DailyQuestsHudUnlocked", false)
				DailyQuestRemote:FireClient(player, "Locked", makeClientData(profile))
				return
			end
			DailyQuestRemote:FireClient(player, "Open", makeClientData(profile))
		end
	elseif action == "UnlockFromZork" then
		if not profiles[player] then
			loadProfile(player)
		end
		local profile = refreshDailyQuests(player)
		if profile then
			setZorkIntroduced(player, profile)
			saveProfile(player, true)
			DailyQuestRemote:FireClient(player, "Open", makeClientData(profile))
		end
	elseif action == "Claim" then
		local profile = profiles[player]
		if profile and profile.zorkIntroduced == true then
			claimQuest(player, value)
		end
	end
end)

local function findZork()
	for _ = 1, 60 do
		local npc = workspace:FindFirstChild(NPC_NAME, true)
		if npc then
			return npc
		end
		task.wait(0.5)
	end
	return nil
end

local function findPromptPart(zork)
	if zork:IsA("Model") then
		return zork.PrimaryPart
			or zork:FindFirstChild("ShopPromptCore", true)
			or zork:FindFirstChild("HumanoidRootPart", true)
			or zork:FindFirstChild("Head", true)
			or zork:FindFirstChildWhichIsA("BasePart", true)
	end
	return zork:IsA("BasePart") and zork or zork:FindFirstChildWhichIsA("BasePart", true)
end

local function removeLegacyZorkQuestPrompt()
	local zork = findZork()
	if not zork then
		return
	end

	for _, descendant in ipairs(zork:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") and descendant.Name == "DailyQuestPrompt" then
			descendant:Destroy()
		end
	end
end

Players.PlayerAdded:Connect(loadProfile)

Players.PlayerRemoving:Connect(function(player)
	saveProfile(player, true)
	profiles[player] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(loadProfile, player)
end

task.spawn(removeLegacyZorkQuestPrompt)

task.spawn(function()
	while true do
		task.wait(60)
		for player in pairs(profiles) do
			saveProfile(player, false)
		end
	end
end)

game:BindToClose(function()
	for player in pairs(profiles) do
		saveProfile(player, true)
	end
end)
