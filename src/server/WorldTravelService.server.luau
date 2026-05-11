-- Server-authoritative world/zone travel for the editable WorldsWindow UI.
-- Clients may only request a locationId; this script validates unlock state and teleports safely.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ColorData = require(ReplicatedStorage:WaitForChild("ColorData"))
local Events = ReplicatedStorage:WaitForChild("Events")
local dataDirtyEvent = Events:FindFirstChild("PlayerDataDirty")

local requestTravel = Events:FindFirstChild("RequestTravelToLocation")
if not requestTravel then
	requestTravel = Instance.new("RemoteEvent")
	requestTravel.Name = "RequestTravelToLocation"
	requestTravel.Parent = Events
end

local travelResult = Events:FindFirstChild("TravelToLocationResult")
if not travelResult then
	travelResult = Instance.new("RemoteEvent")
	travelResult.Name = "TravelToLocationResult"
	travelResult.Parent = Events
end

local COOLDOWN_SECONDS = 1.5
local cooldownByPlayer = {}

local LOCATION_CONFIG = {
	OriginSector = {
		DisplayName = "Origin Sector",
		SpawnNames = { "OriginSectorSpawn", "StartSectorSpawn", "SpawnWorldSpawn", "SpawnLocation" },
		AlwaysUnlocked = true,
		CurrentWorld = "Red",
		AutoUnlockTeleport = true,
	},
	RedWastelands = {
		DisplayName = "Red Wastelands",
		SpawnNames = { "RedWastelandsSpawn", "RedZoneSpawn", "StartSectorSpawn", "SpawnLocation" },
		AlwaysUnlocked = true,
		CurrentWorld = "Red",
		AutoUnlockTeleport = true,
	},
	ZorkShop = {
		DisplayName = "Zork Shop",
		SpawnNames = { "ZorkShopSpawn", "ShopEntranceSpawn", "StartSectorSpawn", "SpawnLocation" },
		AlwaysUnlocked = true,
		CurrentWorld = "Red",
		AutoUnlockTeleport = true,
	},
	InsidePipes = {
		DisplayName = "Inside the Pipes",
		SpawnNames = { "InsidePipesSpawn", "OrangeInteriorSpawn", "MutationZoneSpawn" },
		RequiredColor = "Orange",
		CurrentWorld = "Orange",
		RequiresTeleportUnlock = true,
	},
	OrangeSector = {
		DisplayName = "Orange Sector",
		SpawnNames = { "OrangeSectorSpawn", "OrangeZoneSpawn", "OrangeSpawn" },
		RequiredColor = "Orange",
		CurrentWorld = "Orange",
		AutoUnlockTeleport = true,
	},
	FutureSector = {
		DisplayName = "Future Sector",
		SpawnNames = {},
		Locked = true,
	},
}

for locationId, config in pairs(LOCATION_CONFIG) do
	config.LocationId = locationId
end

local LOCATION_ID_ALIASES = {
	SpawnWorld = "OriginSector",
	StartSector = "OriginSector",
	RedArea = "RedWastelands",
	Shop = "ZorkShop",
	Zork = "ZorkShop",
	Pipes = "InsidePipes",
	OrangePipes = "InsidePipes",
}

local function resolveLocationId(locationId)
	return LOCATION_ID_ALIASES[locationId] or locationId
end

local function fireResult(player, success, locationId, message, extra)
	local payload = {
		Success = success,
		LocationId = locationId,
		Message = message,
	}
	if type(extra) == "table" then
		for key, value in pairs(extra) do
			payload[key] = value
		end
	end
	travelResult:FireClient(player, {
		Success = payload.Success,
		LocationId = payload.LocationId,
		Message = payload.Message,
		UnlockedTeleport = payload.UnlockedTeleport,
		DisplayName = payload.DisplayName,
		UnlockedTeleports = payload.UnlockedTeleports,
	})
end

local function markDataDirty(player, reason)
	local event = dataDirtyEvent
	if not event or not event.Parent then
		event = Events:FindFirstChild("PlayerDataDirty")
		dataDirtyEvent = event
	end
	if event and event:IsA("BindableEvent") then
		event:Fire(player, reason or "world-travel")
	end
end

local function findSpawn(spawnNames)
	for _, spawnName in ipairs(spawnNames or {}) do
		local found = workspace:FindFirstChild(spawnName, true)
		if found and found:IsA("BasePart") then
			return found
		end
	end
	return nil
end

local function listContains(list, value)
	if type(list) ~= "table" then
		return false
	end
	for _, item in ipairs(list) do
		if item == value then
			return true
		end
	end
	return false
end

local function getPlayerDataFromDataManager(player)
	-- DataManager is a Script in this project, not a ModuleScript. If a future
	-- build exposes a module/profile accessor, this handles it safely without
	-- breaking the current server.
	local dataManager = ServerScriptService:FindFirstChild("DataManager")
	if not dataManager or not dataManager:IsA("ModuleScript") then
		return nil
	end

	local ok, manager = pcall(require, dataManager)
	if not ok then
		warn("WorldTravelService: failed to require DataManager:", manager)
		return nil
	end

	if type(manager.GetProfile) == "function" then
		local profile = manager:GetProfile(player)
		return profile and profile.Data
	end
	if type(manager.Profiles) == "table" and manager.Profiles[player] then
		return manager.Profiles[player].Data
	end
	return nil
end

local function getUnlockedColorsFromAttributes(player)
	local csv = player:GetAttribute("UnlockedColors")
	if type(csv) == "string" then
		return ColorData.getUnlockedColorSet(csv)
	end

	for _, folderName in ipairs({ "ColorStorage", "Values", "Data", "PlayerData" }) do
		local valuesFolder = player:FindFirstChild(folderName)
		if valuesFolder then
			local unlockedValue = valuesFolder:FindFirstChild("UnlockedColors")
			if unlockedValue and unlockedValue:IsA("StringValue") then
				return ColorData.getUnlockedColorSet(unlockedValue.Value)
			end
		end
	end

	return nil
end

local function isColorUnlocked(player, colorName)
	if not colorName or colorName == "Red" then
		return true
	end

	local data = getPlayerDataFromDataManager(player)
	if data then
		if listContains(data.UnlockedColors, colorName) then
			return true
		end
		if
			data.CurrentWorld == colorName
			or data.ActiveWorldColor == colorName
			or data.HighestUnlockedWorld == colorName
		then
			return true
		end
	end

	local unlockedSet = getUnlockedColorsFromAttributes(player)
	if unlockedSet and unlockedSet[colorName] == true then
		return true
	end

	-- Studio/dev fallback: if the world config itself says this is the next ready
	-- sector but no player data is exposed, deny rather than allowing progression exploits.
	return false
end

local function getUnlockedTeleportSet(player)
	local storage = player:FindFirstChild("ColorStorage")
	local value = storage and storage:FindFirstChild("UnlockedTeleports")
	local set = { OriginSector = true }
	if value and value:IsA("StringValue") then
		for _, locationId in ipairs(string.split(value.Value, ",")) do
			if locationId ~= "" then
				set[locationId] = true
			end
		end
	end
	return set, value
end

local function serializeTeleports(set)
	local ordered = {}
	for locationId in pairs(LOCATION_CONFIG) do
		if set[locationId] then
			table.insert(ordered, locationId)
		end
	end
	table.sort(ordered)
	return table.concat(ordered, ",")
end

local function unlockTeleport(player, locationId)
	local set, value = getUnlockedTeleportSet(player)
	if set[locationId] then
		return false, value and value.Value or serializeTeleports(set)
	end
	set[locationId] = true
	local serialized = serializeTeleports(set)
	if value and value:IsA("StringValue") then
		value.Value = serialized
	end
	player:SetAttribute("UnlockedTeleports", serialized)
	markDataDirty(player, "unlocked-teleport")
	return true, serialized
end

local function isTeleportUnlocked(player, locationId)
	local set = getUnlockedTeleportSet(player)
	return set[locationId] == true
end

local function setCurrentWorld(player, colorType)
	if not colorType then
		return
	end
	local world = ColorData.getWorldByColor(colorType)
	if not world or not isColorUnlocked(player, world.primaryColor) then
		return
	end

	player:SetAttribute("ActiveWorldColor", world.primaryColor)
	local storage = player:FindFirstChild("ColorStorage")
	local currentWorld = storage and storage:FindFirstChild("CurrentWorld")
	if currentWorld and currentWorld:IsA("StringValue") and currentWorld.Value ~= world.primaryColor then
		currentWorld.Value = world.primaryColor
	end
	markDataDirty(player, "current-world")
end

local function canTravel(player, config)
	if config.Locked then
		return false, "Locked"
	end
	if config.AlwaysUnlocked then
		return true
	end
	if config.RequiredColor then
		if isColorUnlocked(player, config.RequiredColor) then
			if config.RequiresTeleportUnlock and not isTeleportUnlocked(player, config.LocationId) then
				return false, "Visit " .. config.DisplayName .. " first to unlock its teleport."
			end
			return true
		end
		return false, config.DisplayName .. " is locked"
	end
	return true
end

local function safelyTeleport(player, spawnPart)
	local character = player.Character
	if not character then
		return false, "Character not loaded"
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false, "HumanoidRootPart missing"
	end

	player:SetAttribute("IsTeleporting", true)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.CFrame = spawnPart.CFrame + Vector3.new(0, 5, 0)

	task.delay(1, function()
		if player and player.Parent then
			player:SetAttribute("IsTeleporting", false)
		end
	end)

	return true
end

requestTravel.OnServerEvent:Connect(function(player, locationId)
	if typeof(locationId) ~= "string" then
		return
	end
	locationId = resolveLocationId(locationId)

	local now = os.clock()
	if cooldownByPlayer[player] and now - cooldownByPlayer[player] < COOLDOWN_SECONDS then
		return
	end
	cooldownByPlayer[player] = now

	local config = LOCATION_CONFIG[locationId]
	if not config then
		warn("WorldTravelService: invalid location", player.Name, locationId)
		fireResult(player, false, locationId, "Invalid location")
		return
	end

	local allowed, reason = canTravel(player, config)
	if not allowed then
		warn("WorldTravelService: blocked locked travel", player.Name, locationId, reason)
		fireResult(player, false, locationId, reason or "Locked")
		return
	end

	local spawnPart = findSpawn(config.SpawnNames)
	if not spawnPart then
		warn("WorldTravelService: missing spawn part for", locationId)
		fireResult(player, false, locationId, "Missing spawn")
		return
	end

	local success, message = safelyTeleport(player, spawnPart)
	if success then
		player:SetAttribute("LastTravelLocation", locationId)
		if config.CurrentWorld then
			player:SetAttribute("RequestedWorld", config.CurrentWorld)
			setCurrentWorld(player, config.CurrentWorld)
		end
		local unlockedNow = false
		local unlockedTeleports
		if config.AutoUnlockTeleport then
			unlockedNow, unlockedTeleports = unlockTeleport(player, locationId)
		else
			local _, currentTeleports = getUnlockedTeleportSet(player)
			unlockedTeleports = currentTeleports and currentTeleports.Value
		end
		fireResult(player, true, locationId, "Traveled to " .. config.DisplayName, {
			DisplayName = config.DisplayName,
			UnlockedTeleport = unlockedNow,
			UnlockedTeleports = unlockedTeleports,
		})
	else
		fireResult(player, false, locationId, message or "Travel failed")
	end
end)

Players.PlayerRemoving:Connect(function(player)
	cooldownByPlayer[player] = nil
end)
