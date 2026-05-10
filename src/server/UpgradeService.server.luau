-- Server-authoritative upgrade purchases.
-- Uses existing ReplicatedStorage.Events.PurchaseUpgrade remote.
-- Client can only request an upgrade id; server validates level, cost, coins, and max level.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UpgradeData = require(ReplicatedStorage:WaitForChild("UpgradeData"))
local Events = ReplicatedStorage:WaitForChild("Events")
local purchaseUpgradeEvent = Events:WaitForChild("PurchaseUpgrade")

local upgradeUpdatedEvent = Events:FindFirstChild("UpgradeUpdated")
if not upgradeUpdatedEvent then
	upgradeUpdatedEvent = Instance.new("RemoteEvent")
	upgradeUpdatedEvent.Name = "UpgradeUpdated"
	upgradeUpdatedEvent.Parent = Events
end

local dirtyEvent = Events:FindFirstChild("PlayerDataDirty")
local purchaseCooldown = {}
local COOLDOWN_SECONDS = 0.35

local function getCoinsValue(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	return leaderstats and leaderstats:FindFirstChild("Coins")
end

local function getOrCreateUpgradesFolder(player)
	local folder = player:FindFirstChild("Upgrades")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Upgrades"
		folder.Parent = player
	end
	return folder
end

local function getOrCreateLevelValue(player, upgradeId)
	local folder = getOrCreateUpgradesFolder(player)
	local value = folder:FindFirstChild(upgradeId .. "_Level") or folder:FindFirstChild(upgradeId)
	if not value then
		value = Instance.new("IntValue")
		value.Name = upgradeId .. "_Level"
		value.Value = 0
		value.Parent = folder
	elseif not value:IsA("IntValue") then
		warn("UpgradeService: invalid upgrade value object for", player.Name, upgradeId)
		return nil
	end
	return value
end

local function getLevel(player, upgradeId)
	local value = getOrCreateLevelValue(player, upgradeId)
	return value and math.max(0, tonumber(value.Value) or 0) or 0
end

local function markDirty(player, reason)
	if dirtyEvent and dirtyEvent:IsA("BindableEvent") then
		dirtyEvent:Fire(player, reason or "UpgradePurchase")
	end
end

local function applyUpgradeAttributes(player, upgradeId, level)
	local upgrade = UpgradeData.getUpgrade(upgradeId)
	if not upgrade then return end

	local value = level == 0 and upgrade.baseValue or (upgrade.levels[level] and upgrade.levels[level].value or upgrade.baseValue)
	player:SetAttribute("Upgrade_" .. upgradeId .. "_Level", level)
	player:SetAttribute("Upgrade_" .. upgradeId .. "_Value", value)

	if upgradeId == "WalkSpeed" then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = value
		end
	elseif upgradeId == "PetSlots" then
		player:SetAttribute("MaxEquippedPets", value)
	elseif upgradeId == "PickupRange" then
		player:SetAttribute("PickupRange", value)
	elseif upgradeId == "ColorMultiplier" then
		player:SetAttribute("ColorMultiplier", value)
		player:SetAttribute("CoinMultiplier", value)
	elseif upgradeId == "HatchSpeed" then
		player:SetAttribute("HatchSpeedMultiplier", value)
	end
end

local function applyAllUpgradeAttributes(player)
	for _, upgrade in ipairs(UpgradeData.Upgrades) do
		applyUpgradeAttributes(player, upgrade.id, getLevel(player, upgrade.id))
	end
end

local function fireState(player, success, upgradeId, message)
	local state = {}
	for _, upgrade in ipairs(UpgradeData.Upgrades) do
		state[upgrade.id] = getLevel(player, upgrade.id)
	end

	upgradeUpdatedEvent:FireClient(player, {
		Success = success == true,
		UpgradeId = upgradeId,
		Message = message,
		Levels = state,
	})
end

local function purchaseUpgrade(player, upgradeId)
	if typeof(upgradeId) ~= "string" then
		return
	end

	local now = os.clock()
	if purchaseCooldown[player] and now - purchaseCooldown[player] < COOLDOWN_SECONDS then
		return
	end
	purchaseCooldown[player] = now

	local upgrade = UpgradeData.getUpgrade(upgradeId)
	if not upgrade then
		fireState(player, false, upgradeId, "Invalid upgrade")
		return
	end

	local levelValue = getOrCreateLevelValue(player, upgradeId)
	if not levelValue then
		fireState(player, false, upgradeId, "Upgrade data missing")
		return
	end

	local currentLevel = math.max(0, tonumber(levelValue.Value) or 0)
	local nextLevel = currentLevel + 1
	local nextData = upgrade.levels[nextLevel]
	if not nextData then
		fireState(player, false, upgradeId, "Max level")
		return
	end

	local coins = getCoinsValue(player)
	if not coins then
		fireState(player, false, upgradeId, "Coins not loaded")
		return
	end

	local cost = math.max(0, math.floor(tonumber(nextData.cost) or 0))
	if coins.Value < cost then
		fireState(player, false, upgradeId, "Not enough coins")
		return
	end

	coins.Value -= cost
	levelValue.Value = nextLevel
	applyUpgradeAttributes(player, upgradeId, nextLevel)
	markDirty(player, "UpgradePurchase:" .. upgradeId)
	fireState(player, true, upgradeId, "Upgraded " .. upgrade.displayName)
end

purchaseUpgradeEvent.OnServerEvent:Connect(purchaseUpgrade)

Players.PlayerAdded:Connect(function(player)
	getOrCreateUpgradesFolder(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.15)
		applyAllUpgradeAttributes(player)
	end)
	task.defer(function()
		applyAllUpgradeAttributes(player)
		fireState(player, true, nil, "Loaded")
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	purchaseCooldown[player] = nil
end)
