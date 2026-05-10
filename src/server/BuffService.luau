local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuffService = {}

BuffService.Enabled = true

BuffService.Definitions = {
	CoinsRush = {
		DisplayName = "Coins Rush",
		Duration = 45,
		Color = Color3.fromRGB(255, 214, 55),
		Effects = {
			SellCoinsMultiplier = 2.0,
		},
	},
	SpeedRush = {
		DisplayName = "Speed Rush",
		Duration = 45,
		Color = Color3.fromRGB(136, 255, 70),
		Effects = {
			WalkSpeedMultiplier = 1.3,
		},
	},
	BrushFrenzy = {
		DisplayName = "Brush Frenzy",
		Duration = 45,
		Color = Color3.fromRGB(70, 225, 255),
		Effects = {
			ColorGainMultiplier = 1.25,
			BrushRangeMultiplier = 1.25,
		},
	},
	LuckyAura = {
		DisplayName = "Lucky Aura",
		Duration = 45,
		Color = Color3.fromRGB(180, 105, 255),
		Effects = {
			HatchLuckMultiplier = 1.25,
		},
	},
	GemSurge = {
		DisplayName = "Gem Surge",
		Duration = 30,
		Color = Color3.fromRGB(255, 255, 255),
		Effects = {
			GemRewardMultiplier = 2.0,
			GemDamageMultiplier = 2.0,
		},
	},
}

local events = ReplicatedStorage:FindFirstChild("Events")
if not events then
	events = Instance.new("Folder")
	events.Name = "Events"
	events.Parent = ReplicatedStorage
end

local noticeEvent = events:FindFirstChild("WildBuffNotice")
if not noticeEvent then
	noticeEvent = Instance.new("RemoteEvent")
	noticeEvent.Name = "WildBuffNotice"
	noticeEvent.Parent = events
end

local activeBuffs = {}
local buffChanged = Instance.new("BindableEvent")
BuffService.BuffChanged = buffChanged

local function now()
	return os.clock()
end

local function getPlayerBuffs(player)
	local buffs = activeBuffs[player]
	if not buffs then
		buffs = {}
		activeBuffs[player] = buffs
	end
	return buffs
end

local function ensureBuffFolder(player)
	local folder = player:FindFirstChild("WildBuffs")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "WildBuffs"
		folder.Parent = player
	end
	return folder
end

local function syncBuffValue(player, buffId, expiresAt)
	local folder = ensureBuffFolder(player)
	local value = folder:FindFirstChild(buffId)
	if expiresAt and expiresAt > now() then
		if not value then
			value = Instance.new("NumberValue")
			value.Name = buffId
			value.Parent = folder
		end
		value.Value = expiresAt
	elseif value then
		value:Destroy()
	end
end

local function pruneExpired(player)
	local buffs = activeBuffs[player]
	if not buffs then
		return false
	end

	local changed = false
	local t = now()
	for buffId, expiresAt in pairs(buffs) do
		if expiresAt <= t then
			buffs[buffId] = nil
			syncBuffValue(player, buffId, nil)
			changed = true
		end
	end
	if changed then
		buffChanged:Fire(player)
	end
	return changed
end

function BuffService.GetDefinition(buffId)
	return BuffService.Definitions[buffId]
end

function BuffService.Grant(player, buffId, durationOverride)
	if not BuffService.Enabled or not player or not player:IsDescendantOf(Players) then
		return false
	end

	local definition = BuffService.GetDefinition(buffId)
	if not definition then
		warn("BuffService: unknown buff " .. tostring(buffId))
		return false
	end

	local duration = math.max(1, tonumber(durationOverride or definition.Duration) or 1)
	local expiresAt = now() + duration
	local buffs = getPlayerBuffs(player)
	buffs[buffId] = expiresAt
	syncBuffValue(player, buffId, expiresAt)
	buffChanged:Fire(player)

	noticeEvent:FireClient(player, {
		type = "buff",
		id = buffId,
		name = definition.DisplayName or buffId,
		duration = duration,
		expiresAt = expiresAt,
		color = definition.Color,
	})
	return true
end

function BuffService.GetActiveBuffs(player)
	pruneExpired(player)
	local result = {}
	local buffs = activeBuffs[player]
	if not buffs then
		return result
	end

	for buffId, expiresAt in pairs(buffs) do
		local definition = BuffService.GetDefinition(buffId)
		if definition then
			result[buffId] = {
				ExpiresAt = expiresAt,
				Remaining = math.max(0, expiresAt - now()),
				Definition = definition,
			}
		end
	end
	return result
end

function BuffService.HasBuff(player, buffId)
	pruneExpired(player)
	local buffs = activeBuffs[player]
	return buffs and buffs[buffId] and buffs[buffId] > now() or false
end

function BuffService.GetEffects(player)
	local effects = {}
	local buffs = BuffService.GetActiveBuffs(player)
	for _, state in pairs(buffs) do
		local definition = state.Definition
		for key, value in pairs(definition.Effects or {}) do
			if string.find(key, "Multiplier") then
				effects[key] = (effects[key] or 1) * (tonumber(value) or 1)
			else
				effects[key] = (effects[key] or 0) + (tonumber(value) or 0)
			end
		end
	end
	return effects
end

function BuffService.GetMultiplier(player, key)
	local effects = BuffService.GetEffects(player)
	return tonumber(effects[key]) or 1
end

Players.PlayerRemoving:Connect(function(player)
	activeBuffs[player] = nil
end)

task.spawn(function()
	while true do
		task.wait(0.5)
		for _, player in ipairs(Players:GetPlayers()) do
			pruneExpired(player)
		end
	end
end)

return BuffService

