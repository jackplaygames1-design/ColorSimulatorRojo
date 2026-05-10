local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RobuxShopConfig = require(ReplicatedStorage:WaitForChild("RobuxShopConfig"))

local GamepassBenefits = {}
local ownershipCache = {}
local Events = ReplicatedStorage:WaitForChild("Events")
local playerDataDirtyEvent = Events:FindFirstChild("PlayerDataDirty")
if not playerDataDirtyEvent then
	playerDataDirtyEvent = Instance.new("BindableEvent")
	playerDataDirtyEvent.Name = "PlayerDataDirty"
	playerDataDirtyEvent.Parent = Events
end

local function getCache(player)
	ownershipCache[player] = ownershipCache[player] or {}
	return ownershipCache[player]
end

local function getGrantFolder(player)
	return player and player:FindFirstChild("GamepassGrants")
end

local function hasGrantedPass(player, passId)
	local folder = getGrantFolder(player)
	local value = folder and folder:FindFirstChild(tostring(passId))
	return value and value:IsA("BoolValue") and value.Value == true
end

local function setPassAttributes(player, pass, owns)
	if not player or not pass then
		return
	end

	player:SetAttribute("Pass_" .. pass.id, owns == true)
	if pass.id == "VIP" then
		player:SetAttribute("IsVIP", owns == true)
	end
	if (pass.id == "SupportDev" or pass.earlySupporterTag == true) and owns == true then
		player:SetAttribute("EarlySupporter", true)
	end
end

local function hasRealId(pass)
	return pass and tonumber(pass.gamepassId) and tonumber(pass.gamepassId) > 0
end

function GamepassBenefits.owns(player, passId)
	if not player then
		return false
	end

	local pass = RobuxShopConfig.getGamepass(passId)
	if hasGrantedPass(player, passId) then
		local cache = getCache(player)
		cache[passId] = true
		setPassAttributes(player, pass, true)
		return true
	end

	if not hasRealId(pass) then
		return player:GetAttribute("Pass_" .. tostring(passId)) == true
	end

	local cache = getCache(player)
	if cache[passId] ~= nil then
		return cache[passId]
	end

	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.gamepassId)
	end)

	cache[passId] = ok and owns == true
	setPassAttributes(player, pass, cache[passId])
	return cache[passId]
end

function GamepassBenefits.invalidate(player, passId)
	if not player then
		return
	end
	local cache = getCache(player)
	cache[passId] = nil
end

function GamepassBenefits.refreshPlayer(player)
	if not player then
		return
	end

	for _, pass in ipairs(RobuxShopConfig.Gamepasses or {}) do
		local owns = GamepassBenefits.owns(player, pass.id)
		setPassAttributes(player, pass, owns)
	end
	player:SetAttribute("IsVIP", GamepassBenefits.owns(player, "VIP"))
	if GamepassBenefits.owns(player, "SupportDev") then
		player:SetAttribute("EarlySupporter", true)
	end
end

function GamepassBenefits.grant(player, passId)
	if not player then
		return false
	end

	local pass = RobuxShopConfig.getGamepass(passId)
	if not pass then
		warn("GamepassBenefits: cannot grant unknown pass " .. tostring(passId))
		return false
	end

	local folder = getGrantFolder(player)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "GamepassGrants"
		folder.Parent = player
	end

	local value = folder:FindFirstChild(pass.id)
	if not value then
		value = Instance.new("BoolValue")
		value.Name = pass.id
		value.Parent = folder
	end

	value.Value = true
	local cache = getCache(player)
	cache[pass.id] = true
	setPassAttributes(player, pass, true)
	playerDataDirtyEvent:Fire(player, "gamepass-grants")
	return true
end

function GamepassBenefits.grantAll(player)
	if not player then
		return false, {}
	end

	local granted = {}
	for _, pass in ipairs(RobuxShopConfig.Gamepasses or {}) do
		if GamepassBenefits.grant(player, pass.id) then
			table.insert(granted, pass.id)
		end
	end

	GamepassBenefits.refreshPlayer(player)
	return #granted > 0, granted
end

function GamepassBenefits.getCoinMultiplier(player)
	local multiplier = 1
	if GamepassBenefits.owns(player, "DoubleCoins") then
		multiplier *= 2
	end
	return multiplier
end

function GamepassBenefits.getLuckMultiplier(player)
	local multiplier = 1
	if GamepassBenefits.owns(player, "LuckyHatch") then
		multiplier *= 1.35
	end
	if GamepassBenefits.owns(player, "VIP") then
		multiplier *= 1.1
	end
	return multiplier
end

function GamepassBenefits.getExtraEquippedColorSlots(player)
	local extra = 0
	if GamepassBenefits.owns(player, "Plus3Colors") then
		extra += 3
	end
	if GamepassBenefits.owns(player, "VIP") then
		extra += 1
	end
	return extra
end

function GamepassBenefits.hasAutoSell(player)
	return false
end

Players.PlayerAdded:Connect(function(player)
	for _, pass in ipairs(RobuxShopConfig.Gamepasses or {}) do
		player:SetAttribute("Pass_" .. pass.id, false)
	end
	player:SetAttribute("IsVIP", false)
	player:SetAttribute("EarlySupporter", false)
	task.defer(function()
		GamepassBenefits.refreshPlayer(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	ownershipCache[player] = nil
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamepassId, wasPurchased)
	if not wasPurchased then
		return
	end

	local pass = RobuxShopConfig.getGamepassByRobloxId(gamepassId)
	if not pass then
		return
	end

	local cache = getCache(player)
	cache[pass.id] = true
	setPassAttributes(player, pass, true)

	print("GamepassBenefits: " .. player.Name .. " unlocked " .. pass.id)
end)

if RunService:IsStudio() then
	ReplicatedStorage:SetAttribute("GamepassBenefitsReady", true)
end

return GamepassBenefits
