local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("GroupRewardsConfig"))

local GroupRewardsService = {}

local events = ReplicatedStorage:WaitForChild("Events")
local remote = events:FindFirstChild("GroupRewards")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "GroupRewards"
	remote.Parent = events
end

local noticeEvent = events:FindFirstChild("WildBuffNotice")
local dataDirtyEvent = events:FindFirstChild("PlayerDataDirty")

local membershipCache = {}
local initialized = false

local function todayKey()
	return os.date("!%Y-%m-%d")
end

local function secondsUntilReset()
	return 86400 - (os.time() % 86400)
end

local function getGroupFolder(player)
	local folder = player:FindFirstChild("GroupRewards")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "GroupRewards"
		folder.Parent = player
	end

	local lastClaim = folder:FindFirstChild("LastDailyGemClaim")
	if not lastClaim then
		lastClaim = Instance.new("StringValue")
		lastClaim.Name = "LastDailyGemClaim"
		lastClaim.Value = ""
		lastClaim.Parent = folder
	end

	return folder, lastClaim
end

local function markDirty(player, reason)
	if not dataDirtyEvent or not dataDirtyEvent.Parent then
		dataDirtyEvent = events:FindFirstChild("PlayerDataDirty")
	end
	if dataDirtyEvent and dataDirtyEvent:IsA("BindableEvent") then
		dataDirtyEvent:Fire(player, reason or "group-rewards")
	end
end

local function showNotice(player, message, color)
	if noticeEvent and noticeEvent:IsA("RemoteEvent") then
		noticeEvent:FireClient(player, {
			type = "message",
			message = message,
			color = color or Color3.fromRGB(118, 238, 244),
		})
	end
end

local function isForcedMember(player)
	if not RunService:IsStudio() then
		return false
	end
	local attr = Config.Testing and Config.Testing.ForceMembershipAttribute or "ForceGroupMember"
	return player:GetAttribute(attr) == true
end

local function queryMembership(player)
	if isForcedMember(player) then
		return true
	end

	local groupId = tonumber(Config.GROUP_ID) or 0
	if groupId <= 0 then
		return false
	end

	local ok, result = pcall(function()
		return player:IsInGroup(groupId)
	end)
	if not ok then
		warn("GroupRewards: IsInGroup failed for " .. player.Name .. ": " .. tostring(result))
		return false
	end
	return result == true
end

function GroupRewardsService.RefreshMembership(player)
	if not player then
		return false
	end
	local isMember = queryMembership(player)
	membershipCache[player.UserId] = isMember
	player:SetAttribute("IsColorSimulatorGroupMember", isMember)
	player:SetAttribute("GroupLuckMultiplier", isMember and Config.LuckMultiplier or 1)
	player:SetAttribute("GroupCoinMultiplier", isMember and Config.CoinMultiplier or 1)
	return isMember
end

function GroupRewardsService.IsGroupMember(player)
	if not player then
		return false
	end
	local cached = membershipCache[player.UserId]
	if cached == nil then
		cached = GroupRewardsService.RefreshMembership(player)
	end
	return cached == true
end

function GroupRewardsService.GetLuckMultiplier(player)
	return GroupRewardsService.IsGroupMember(player) and Config.LuckMultiplier or 1
end

function GroupRewardsService.GetCoinMultiplier(player)
	return GroupRewardsService.IsGroupMember(player) and Config.CoinMultiplier or 1
end

function GroupRewardsService.CanClaimDaily(player)
	if not GroupRewardsService.IsGroupMember(player) then
		return false
	end
	local _, lastClaim = getGroupFolder(player)
	return lastClaim.Value ~= todayKey()
end

function GroupRewardsService.MakeState(player)
	local _, lastClaim = getGroupFolder(player)
	local isMember = GroupRewardsService.IsGroupMember(player)
	local canClaim = isMember and lastClaim.Value ~= todayKey()
	return {
		groupId = Config.GROUP_ID,
		groupName = Config.GroupName,
		groupUrl = Config.GroupUrl,
		isMember = isMember,
		luckPercent = math.floor(((Config.LuckMultiplier or 1) - 1) * 100 + 0.5),
		coinPercent = math.floor(((Config.CoinMultiplier or 1) - 1) * 100 + 0.5),
		dailyGems = Config.DailyGemReward,
		canClaim = canClaim,
		claimedToday = isMember and not canClaim,
		resetIn = secondsUntilReset(),
		lastDailyClaim = lastClaim.Value,
	}
end

local function fireState(player, action)
	remote:FireClient(player, action or "State", GroupRewardsService.MakeState(player))
end

function GroupRewardsService.ClaimDaily(player)
	if not player or not player.Parent then
		return false, "Player not ready."
	end
	if not GroupRewardsService.IsGroupMember(player) then
		return false, "Join the Color Simulator group first."
	end

	local _, lastClaim = getGroupFolder(player)
	if lastClaim.Value == todayKey() then
		return false, "You already claimed today."
	end

	local stats = player:FindFirstChild("leaderstats")
	local gems = stats and stats:FindFirstChild("Gems")
	if not gems then
		return false, "Gems are still loading."
	end

	local amount = math.max(0, math.floor(tonumber(Config.DailyGemReward) or 100))
	gems.Value += amount
	lastClaim.Value = todayKey()
	markDirty(player, "group-rewards")
	showNotice(player, "Claimed " .. tostring(amount) .. " Gems!", Color3.fromRGB(90, 255, 120))
	fireState(player, "State")
	return true, "Claimed " .. tostring(amount) .. " Gems!"
end

local function setupPlayer(player)
	local wasMember = GroupRewardsService.RefreshMembership(player)
	player:WaitForChild("leaderstats", 20)
	player:WaitForChild("GroupRewards", 20)
	getGroupFolder(player)
	fireState(player, "State")

	if wasMember then
		task.delay(2, function()
			if not player.Parent then
				return
			end
			showNotice(player, "Group Bonus Active: +5% Luck, +5% Coins", Color3.fromRGB(118, 238, 244))
			if GroupRewardsService.CanClaimDaily(player) then
				showNotice(player, "Daily reward ready!", Color3.fromRGB(90, 255, 120))
			end
		end)
	end

	local resetAttr = Config.Testing and Config.Testing.ResetDailyAttribute or "ResetGroupDaily"
	player:GetAttributeChangedSignal(resetAttr):Connect(function()
		if RunService:IsStudio() and player:GetAttribute(resetAttr) == true then
			local _, lastClaim = getGroupFolder(player)
			lastClaim.Value = ""
			player:SetAttribute(resetAttr, nil)
			markDirty(player, "group-rewards")
			fireState(player, "State")
		end
	end)

	local forceAttr = Config.Testing and Config.Testing.ForceMembershipAttribute or "ForceGroupMember"
	player:GetAttributeChangedSignal(forceAttr):Connect(function()
		if RunService:IsStudio() then
			GroupRewardsService.RefreshMembership(player)
			fireState(player, "State")
		end
	end)
end

function GroupRewardsService.Init()
	if initialized then
		return
	end
	initialized = true

	remote.OnServerEvent:Connect(function(player, action)
		action = tostring(action or "Get")
		if action == "Get" then
			fireState(player, "State")
		elseif action == "ClaimDaily" then
			local ok, message = GroupRewardsService.ClaimDaily(player)
			if not ok then
				showNotice(player, message or "Group reward is not ready.", Color3.fromRGB(255, 216, 122))
				fireState(player, "State")
			end
		elseif action == "Refresh" then
			GroupRewardsService.RefreshMembership(player)
			fireState(player, "State")
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		task.defer(setupPlayer, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		membershipCache[player.UserId] = nil
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		task.defer(setupPlayer, player)
	end
end

return GroupRewardsService
