-- Server-authoritative upgrade purchases.
-- Uses existing ReplicatedStorage.Events.PurchaseUpgrade remote.
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

local function getCurrencyValue(player, currencyName)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return nil
	end

	local value = leaderstats:FindFirstChild(currencyName)
	if not value and currencyName == "Gems" then
		value = leaderstats:FindFirstChild("Diamonds")
	end
	return value
end

local function getOrCreateUpgradesFolder(player)
	local folder = player:FindFirstChild("Upgrades") or player:WaitForChild("Upgrades", 10)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Upgrades"
		folder.Parent = player
	end
	return folder
end

local function getOrCreateLevelValue(player, upgradeId)
	local canonicalId = UpgradeData.getCanonicalId(upgradeId)
	if not canonicalId then
		return nil
	end

	local folder = getOrCreateUpgradesFolder(player)
	local value = folder:FindFirstChild(canonicalId .. "_Level")
	if not value then
		value = Instance.new("IntValue")
		value.Name = canonicalId .. "_Level"
		value.Value = 0
		value.Parent = folder
	elseif not value:IsA("IntValue") then
		warn("UpgradeService: invalid level value object for", player.Name, canonicalId)
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

local function setNumberValue(player, name, value)
	local folder = getOrCreateUpgradesFolder(player)
	local existing = folder:FindFirstChild(name)
	if existing and not (existing:IsA("NumberValue") or existing:IsA("IntValue")) then
		warn("UpgradeService: cannot apply upgrade value over non-number child", name)
		return
	end

	if not existing then
		existing = Instance.new("NumberValue")
		existing.Name = name
		existing.Parent = folder
	end
	existing.Value = tonumber(value) or 0
end

local function setIntValue(parent, name, value)
	if not parent then
		return
	end

	local existing = parent:FindFirstChild(name)
	if existing and not existing:IsA("IntValue") then
		return
	end

	if not existing then
		existing = Instance.new("IntValue")
		existing.Name = name
		existing.Parent = parent
	end
	existing.Value = math.floor(tonumber(value) or 0)
end

local function applyWalkSpeed(player, value)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = value
	end
end

local function applyHealth(player, value)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.MaxHealth = value
		humanoid.Health = math.min(math.max(humanoid.Health, 1), value)
	end
end

local function applyUpgradeAttributes(player, upgradeId, level)
	local canonicalId = UpgradeData.getCanonicalId(upgradeId)
	local upgrade = canonicalId and UpgradeData.getUpgrade(canonicalId)
	if not upgrade then
		return
	end

	local value = UpgradeData.getValue(canonicalId, level) or upgrade.baseValue
	setNumberValue(player, canonicalId, value)
	player:SetAttribute("Upgrade_" .. canonicalId .. "_Level", level)
	player:SetAttribute("Upgrade_" .. canonicalId .. "_Value", value)

	if canonicalId == "WalkSpeed" then
		applyWalkSpeed(player, value)
	elseif canonicalId == "PetSlots" then
		player:SetAttribute("MaxEquippedPets", value)
		player:SetAttribute("Upgrade_InventorySize_Value", value)
		setNumberValue(player, "InventorySize", value)
		setIntValue(player:FindFirstChild("PetData"), "MaxSlots", value)
	elseif canonicalId == "PickupRange" then
		player:SetAttribute("PickupRange", value)
	elseif canonicalId == "ColorMultiplier" then
		player:SetAttribute("ColorMultiplier", value)
		player:SetAttribute("CoinMultiplier", value)
		setNumberValue(player, "CoinMultiplier", value)
	elseif canonicalId == "PaintSpeed" then
		local hatchMultiplier = math.clamp(1 / math.max(value, 0.01), 0.1, 1)
		player:SetAttribute("PaintSpeedMultiplier", value)
		player:SetAttribute("HatchSpeedMultiplier", hatchMultiplier)
		setNumberValue(player, "HatchSpeed", hatchMultiplier)
	elseif canonicalId == "Luck" then
		player:SetAttribute("HatchLuckMultiplier", value)
		setNumberValue(player, "HatchLuckMultiplier", value)
	elseif canonicalId == "GemCapacity" then
		player:SetAttribute("GemCapacity", value)
	elseif canonicalId == "Health" then
		player:SetAttribute("MaxHealth", value)
		applyHealth(player, value)
	elseif canonicalId == "PlayerPower" then
		player:SetAttribute("PlayerPowerMultiplier", value)
	elseif canonicalId == "BrushPower" then
		player:SetAttribute("BrushPowerMultiplier", value)
	elseif canonicalId == "BrushSize" then
		player:SetAttribute("BrushSizeMultiplier", value)
	elseif canonicalId == "PaintCapacity" then
		player:SetAttribute("PaintCapacity", value)
	elseif canonicalId == "CritChance" then
		player:SetAttribute("CritChance", value)
	elseif canonicalId == "CoinCapacity" then
		player:SetAttribute("CoinCapacity", value)
	elseif canonicalId == "SellValue" then
		player:SetAttribute("SellValueMultiplier", value)
	elseif canonicalId == "GemMultiplier" then
		player:SetAttribute("GemMultiplier", value)
	elseif canonicalId == "GemValue" then
		player:SetAttribute("GemValueMultiplier", value)
	elseif canonicalId == "PassiveIncome" then
		player:SetAttribute("PassiveIncome", value)
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
	purchaseUpgradeEvent:FireClient(player, success == true, upgradeId, message)
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

	local canonicalId = UpgradeData.getCanonicalId(upgradeId)
	local upgrade = canonicalId and UpgradeData.getUpgrade(canonicalId)
	if not upgrade then
		fireState(player, false, upgradeId, "Invalid upgrade")
		return
	end

	local levelValue = getOrCreateLevelValue(player, canonicalId)
	if not levelValue then
		fireState(player, false, canonicalId, "Upgrade data missing")
		return
	end

	local currentLevel = math.max(0, tonumber(levelValue.Value) or 0)
	local nextLevel = currentLevel + 1
	local nextData = upgrade.levels[nextLevel]
	if not nextData then
		fireState(player, false, canonicalId, "Max level")
		return
	end

	local currencyName = nextData.currency or upgrade.currency or "Gems"
	local currency = getCurrencyValue(player, currencyName)
	if not currency then
		fireState(player, false, canonicalId, currencyName .. " not loaded")
		return
	end

	local cost = math.max(0, math.floor(tonumber(nextData.cost) or 0))
	if currency.Value < cost then
		fireState(player, false, canonicalId, "Not enough " .. currencyName)
		return
	end

	currency.Value -= cost
	levelValue.Value = nextLevel
	applyUpgradeAttributes(player, canonicalId, nextLevel)
	markDirty(player, "UpgradePurchase:" .. canonicalId)
	fireState(player, true, canonicalId, "Upgraded " .. upgrade.displayName)
end

purchaseUpgradeEvent.OnServerEvent:Connect(purchaseUpgrade)

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.15)
		applyAllUpgradeAttributes(player)
	end)

	player.ChildAdded:Connect(function(child)
		if child.Name == "PetData" or child.Name == "ColorStorage" or child.Name == "Upgrades" then
			task.defer(function()
				applyAllUpgradeAttributes(player)
			end)
		end
	end)

	task.spawn(function()
		player:WaitForChild("leaderstats", 15)
		getOrCreateUpgradesFolder(player)
		applyAllUpgradeAttributes(player)
		fireState(player, true, nil, "Loaded")
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	purchaseCooldown[player] = nil
end)
