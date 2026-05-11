-- Script in ServerScriptService named "UpgradeHandler"
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UpgradeData = require(ReplicatedStorage:WaitForChild("UpgradeData"))

local Events         = ReplicatedStorage:WaitForChild("Events")
local purchaseEvent  = Events:WaitForChild("PurchaseUpgrade")
local LEGACY_PURCHASE_HANDLER_ENABLED = false

-- Store upgrade levels per player
local playerUpgrades = {}
local warnedUnexpectedRequests = {}

local function warnUnexpectedOnce(player, upgradeId)
	local key = tostring(player and player.UserId) .. ":" .. tostring(upgradeId)
	if warnedUnexpectedRequests[key] then
		return
	end
	warnedUnexpectedRequests[key] = true
	warn("Upgrade purchase ignored unexpected client value fields for " .. tostring(upgradeId))
end

local function respond(player, success, upgradeId, valueOrMessage)
	purchaseEvent:FireClient(player, success == true, upgradeId, valueOrMessage)
end

local function getUpgradeValue(upgradeId, level, default)
	level = tonumber(level) or 0
	local upgrade = UpgradeData and UpgradeData.getUpgrade and UpgradeData.getUpgrade(upgradeId)
	if type(upgrade) ~= "table" then
		return default
	end

	local baseValue = upgrade.baseValue
	if baseValue == nil then
		baseValue = default
	end

	if level <= 0 then
		return baseValue
	end

	local levelData = upgrade.levels and upgrade.levels[level]
	if levelData and levelData.value ~= nil then
		return levelData.value
	end
	return baseValue
end

-- ========================
--   APPLY UPGRADE EFFECTS
-- ========================
local function applyUpgrades(player)
	local upgrades = playerUpgrades[player]
	if not upgrades then return end

	local char = player.Character

	-- Walk Speed
	local speedLevel = upgrades["WalkSpeed"] or 0
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.WalkSpeed = getUpgradeValue("WalkSpeed", speedLevel, 44)
		end
	end

	-- Pet Slots — stored as a value so PetHandler can read it
	local petSlotsLevel = upgrades["PetSlots"] or 0
	local petFolder = player:FindFirstChild("PetData")
	if petFolder then
		local slotVal = petFolder:FindFirstChild("MaxSlots")
		if not slotVal then
			slotVal = Instance.new("IntValue")
			slotVal.Name   = "MaxSlots"
			slotVal.Parent = petFolder
		end
		slotVal.Value = getUpgradeValue("PetSlots", petSlotsLevel, 3)
	end

	-- Other upgrades (PickupRange, ColorMultiplier, HatchSpeed)
	-- stored as values so client/other scripts can read them
	local upgradeFolder = player:FindFirstChild("Upgrades")
	if not upgradeFolder then
		upgradeFolder = Instance.new("Folder")
		upgradeFolder.Name   = "Upgrades"
		upgradeFolder.Parent = player
	end

	local function setUpgradeValue(id, default)
		local existing = upgradeFolder:FindFirstChild(id)
		if not existing then
			existing = Instance.new("NumberValue")
			existing.Name   = id
			existing.Parent = upgradeFolder
		end
		local level = upgrades[id] or 0
		existing.Value = getUpgradeValue(id, level, default)
	end

	setUpgradeValue("PickupRange",      8)
	setUpgradeValue("ColorMultiplier",  1.0)
	setUpgradeValue("HatchSpeed",       1.0)
	setUpgradeValue("WalkSpeed",        44)
	setUpgradeValue("PetSlots",         3)
end

-- ========================
--   LOAD UPGRADE LEVELS FROM SAVED DATA
-- ========================
local function loadUpgrades(player)
	playerUpgrades[player] = {}

	local upgradeFolder = player:FindFirstChild("Upgrades")
	if upgradeFolder then
		for _, upg in ipairs(UpgradeData.Upgrades) do
			local val = upgradeFolder:FindFirstChild(upg.id .. "_Level")
			if val then
				playerUpgrades[player][upg.id] = val.Value
			else
				playerUpgrades[player][upg.id] = 0
			end
		end
	else
		for _, upg in ipairs(UpgradeData.Upgrades) do
			playerUpgrades[player][upg.id] = 0
		end
	end
end

-- ========================
--   SAVE UPGRADE LEVELS
-- ========================
local function saveUpgrades(player)
	local upgrades = playerUpgrades[player]
	if not upgrades then return end

	local upgradeFolder = player:FindFirstChild("Upgrades")
	if not upgradeFolder then
		upgradeFolder = Instance.new("Folder")
		upgradeFolder.Name   = "Upgrades"
		upgradeFolder.Parent = player
	end

	for id, level in pairs(upgrades) do
		local existing = upgradeFolder:FindFirstChild(id .. "_Level")
		if not existing then
			existing = Instance.new("IntValue")
			existing.Name   = id .. "_Level"
			existing.Parent = upgradeFolder
		end
		existing.Value = level
	end
end

-- ========================
--   PURCHASE UPGRADE
-- ========================
local function handlePurchase(player, upgradeId, ...)
	if select("#", ...) > 0 then
		warnUnexpectedOnce(player, upgradeId)
	end

	upgradeId = tostring(upgradeId or "")
	print("Upgrade purchase requested: " .. upgradeId)

	local upgrades = playerUpgrades[player]
	if not upgrades then
		respond(player, false, upgradeId, "Player data is not ready.")
		print("Upgrade purchase failed: data missing")
		return
	end

	local upg = UpgradeData.getUpgrade(upgradeId)
	if not upg then
		respond(player, false, upgradeId, "Invalid upgrade.")
		print("Upgrade purchase failed: invalid upgrade")
		return
	end

	local currentLevel = upgrades[upgradeId] or 0
	local maxLevel     = #upg.levels

	if currentLevel >= maxLevel then
		respond(player, false, upgradeId, "Already max level!")
		print("Upgrade purchase failed: maxed")
		return
	end

	local nextLevel = currentLevel + 1
	local cost      = upg.levels[nextLevel].cost

	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		respond(player, false, upgradeId, "Player stats are not ready.")
		print("Upgrade purchase failed: stats missing")
		return
	end
	local coins = stats:FindFirstChild("Coins")
	if not coins or coins.Value < cost then
		respond(player, false, upgradeId, "Not enough coins!")
		print("Upgrade purchase failed: not enough coins")
		return
	end

	-- Deduct coins, level up, apply, save
	coins.Value = coins.Value - cost
	upgrades[upgradeId] = nextLevel

	applyUpgrades(player)
	saveUpgrades(player)

	respond(player, true, upgradeId, nextLevel)
	print("Upgrade purchase success")
	print(player.Name .. " upgraded " .. upgradeId .. " to level " .. nextLevel)
end

if LEGACY_PURCHASE_HANDLER_ENABLED then
	purchaseEvent.OnServerEvent:Connect(function(player, upgradeId, ...)
		local ok, err = pcall(handlePurchase, player, upgradeId, ...)
		if not ok then
			warn("Upgrade purchase failed: " .. tostring(err))
			respond(player, false, upgradeId, "Purchase failed. Try again.")
		end
	end)
end

-- ========================
--   PLAYER SETUP
-- ========================
if LEGACY_PURCHASE_HANDLER_ENABLED then
	Players.PlayerAdded:Connect(function(player)
		-- Wait for DataManager to load player data first
		local upgradeFolder = player:WaitForChild("Upgrades", 10)

		loadUpgrades(player)

		-- Apply on spawn and re-apply on respawn
		local function onCharacterAdded(char)
			task.wait(0.5)
			applyUpgrades(player)
		end

		player.CharacterAdded:Connect(onCharacterAdded)
		if player.Character then
			onCharacterAdded(player.Character)
		end
	end)
end

if LEGACY_PURCHASE_HANDLER_ENABLED then
	Players.PlayerRemoving:Connect(function(player)
		saveUpgrades(player)
		playerUpgrades[player] = nil
	end)
end

-- Expose for other scripts
return {
	getPlayerUpgradeLevel = function(player, id)
		return playerUpgrades[player] and playerUpgrades[player][id] or 0
	end
}
