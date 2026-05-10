-- Script in ServerScriptService named "ItemsHandler"
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemsData = require(ReplicatedStorage:WaitForChild("ItemsData"))

local Events    = ReplicatedStorage:WaitForChild("Events")
local useEvent  = Events:WaitForChild("UseItem")

-- Track active boosts per player
-- { [player] = { [boostType] = expiresAt } }
local activeBoosts = {}

-- Track inventory per player
-- { [player] = { [itemId] = quantity } }
local playerInventory = {}

-- Cooldowns to prevent spam
local cooldowns = {}
local COOLDOWN  = 0.5

local MATERIAL_ITEMS = {}
local START_CLEARED_CATEGORIES = {
	Items = true,
	Boosts = true,
	Materials = true,
}

for itemId, item in pairs(ItemsData.Items) do
	if item.category == "Materials" then
		MATERIAL_ITEMS[itemId] = true
	end
end

local function getInventory(player)
	if not playerInventory[player] then
		playerInventory[player] = {}
	end
	return playerInventory[player]
end

local function getBoosts(player)
	if not activeBoosts[player] then
		activeBoosts[player] = {}
	end
	return activeBoosts[player]
end

-- ========================
--   GIVE ITEM TO PLAYER
--   Called by other scripts (e.g. dev products, rewards)
-- ========================
local function giveItem(player, itemId, quantity)
	if MATERIAL_ITEMS[itemId] then
		print("ItemsHandler: material item grant ignored for now -> " .. tostring(itemId))
		return
	end

	quantity = quantity or 1
	local inv = getInventory(player)
	inv[itemId] = (inv[itemId] or 0) + quantity

	-- Notify client
	useEvent:FireClient(player, "update", itemId, inv[itemId])
	print(player.Name .. " received " .. quantity .. "x " .. itemId)
end

local function clearMaterials(inv)
	for itemId in pairs(MATERIAL_ITEMS) do
		inv[itemId] = nil
	end
end

local function clearStartClearedItems(inv)
	for itemId, item in pairs(ItemsData.Items) do
		if START_CLEARED_CATEGORIES[item.category] then
			inv[itemId] = nil
		end
	end
end

local function clearFolderChildren(folder)
	if not folder then
		return
	end

	for _, child in ipairs(folder:GetChildren()) do
		child:Destroy()
	end
end

local function clearActiveBoostInstances(player)
	clearFolderChildren(player:FindFirstChild("Boosts"))
	clearFolderChildren(player:FindFirstChild("ItemFlags"))
end

-- ========================
--   APPLY BOOST EFFECT
-- ========================
local function applyBoost(player, boostType, duration)
	local boosts = getBoosts(player)
	local now    = os.time()

	-- Stack with existing boost time
	local current = boosts[boostType] or now
	boosts[boostType] = math.max(current, now) + duration

	-- Store in player folder so other scripts can read it
	local boostFolder = player:FindFirstChild("Boosts")
	if not boostFolder then
		boostFolder = Instance.new("Folder")
		boostFolder.Name   = "Boosts"
		boostFolder.Parent = player
	end

	local val = boostFolder:FindFirstChild(boostType)
	if not val then
		val = Instance.new("NumberValue")
		val.Name   = boostType
		val.Parent = boostFolder
	end
	val.Value = boosts[boostType]

	print(player.Name .. " boost applied: " .. boostType .. " until " .. boosts[boostType])
end

-- ========================
--   USE ITEM LOGIC
-- ========================
local function useItem(player, itemId, requestedAmount)
	local item = ItemsData.Items[itemId]
	if not item then
		useEvent:FireClient(player, "error", itemId, "Unknown item!")
		return
	end

	if not item.usable then
		useEvent:FireClient(player, "error", itemId, "This item can't be used!")
		return
	end

	local inv = getInventory(player)
	if not inv[itemId] or inv[itemId] <= 0 then
		useEvent:FireClient(player, "error", itemId, "You don't have any " .. item.displayName .. "!")
		return
	end

	-- Deduct one
	local amount = 1
	if item.boostType and item.boostDuration then
		amount = math.clamp(math.floor(tonumber(requestedAmount) or 1), 1, inv[itemId])
	end

	inv[itemId] = inv[itemId] - amount
	if inv[itemId] <= 0 then inv[itemId] = nil end

	-- Apply effect
	if item.boostType and item.boostDuration then
		applyBoost(player, item.boostType, item.boostDuration * amount)

		-- Tell client: item used successfully + boost info
		useEvent:FireClient(player, "boosted", itemId, inv[itemId] or 0, {
			boostType    = item.boostType,
			boostDuration = item.boostDuration * amount,
			usedAmount = amount,
			expiresAt    = (activeBoosts[player] or {})[item.boostType],
		})

	elseif itemId == "TripleHatchTicket" then
		-- Store flag for egg shop to read
		local flagFolder = player:FindFirstChild("ItemFlags")
		if not flagFolder then
			flagFolder = Instance.new("Folder")
			flagFolder.Name   = "ItemFlags"
			flagFolder.Parent = player
		end
		local flag = flagFolder:FindFirstChild("TripleHatch")
		if not flag then
			flag = Instance.new("IntValue")
			flag.Name   = "TripleHatch"
			flag.Parent = flagFolder
		end
		flag.Value = (flag.Value or 0) + 1

		useEvent:FireClient(player, "used", itemId, inv[itemId] or 0, {
			message = "Triple Hatch activated! Next 3 hatches are free!"
		})

	elseif itemId == "RainbowKey" then
		-- Give a big coin reward as placeholder for chest
		local stats = player:FindFirstChild("leaderstats")
		if stats then
			local coins = stats:FindFirstChild("Coins")
			if coins then
				local reward = math.random(5000, 15000)
				coins.Value  = coins.Value + reward
				useEvent:FireClient(player, "used", itemId, inv[itemId] or 0, {
					message = "Rainbow Chest opened! +" .. reward .. " Coins!"
				})
			end
		end

	elseif itemId == "MysteryCrate" then
		-- Random item reward
		local possibleRewards = {
			{ itemId = "LuckPotion",  qty = 1 },
			{ itemId = "CoinPotion",  qty = 1 },
			{ itemId = "SpeedPotion", qty = 1 },
			{ itemId = "RangePotion", qty = 1 },
		}
		local reward = possibleRewards[math.random(1, #possibleRewards)]
		giveItem(player, reward.itemId, reward.qty)

		useEvent:FireClient(player, "used", itemId, inv[itemId] or 0, {
			message = "Mystery Crate opened! Got " .. reward.qty .. "x " .. (ItemsData.Items[reward.itemId] and ItemsData.Items[reward.itemId].displayName or reward.itemId) .. "!"
		})

	else
		-- Generic usable
		useEvent:FireClient(player, "used", itemId, inv[itemId] or 0, {
			message = item.displayName .. " used!"
		})
	end
end

-- ========================
--   LISTEN FOR USE REQUESTS
-- ========================
useEvent.OnServerEvent:Connect(function(player, itemId, requestedAmount)
	local now = tick()
	if cooldowns[player] and (now - cooldowns[player]) < COOLDOWN then return end
	cooldowns[player] = now

	useItem(player, itemId, requestedAmount)
end)

-- ========================
--   BOOST EXPIRY CHECKER
-- ========================
task.spawn(function()
	while true do
		task.wait(5)
		local now = os.time()
		for player, boosts in pairs(activeBoosts) do
			for boostType, expiresAt in pairs(boosts) do
				if now >= expiresAt then
					boosts[boostType] = nil

					-- Clear from player folder
					local boostFolder = player:FindFirstChild("Boosts")
					if boostFolder then
						local val = boostFolder:FindFirstChild(boostType)
						if val then val.Value = 0 end
					end

					-- Notify client boost expired
					useEvent:FireClient(player, "boostExpired", boostType)
					print(player.Name .. " boost expired: " .. boostType)
				end
			end
		end
	end
end)

local function setupPlayer(player)
	playerInventory[player] = {}
	activeBoosts[player]    = {}
	task.defer(function()
		local inv = getInventory(player)
		clearStartClearedItems(inv)
		clearMaterials(inv)
		clearActiveBoostInstances(player)
		useEvent:FireClient(player, "sync", inv)
	end)
end

-- ========================
--   PLAYER SETUP / CLEANUP
-- ========================
Players.PlayerAdded:Connect(setupPlayer)

for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end

Players.PlayerRemoving:Connect(function(player)
	playerInventory[player] = nil
	activeBoosts[player]    = nil
	cooldowns[player]       = nil
end)

-- Expose for other scripts
return {
	giveItem   = giveItem,
	applyBoost = applyBoost,
	getBoosts  = function(player) return getBoosts(player) end,
}
