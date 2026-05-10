-- Server-authoritative world/zone travel for the editable WorldsWindow UI.
-- Clients may only request a locationId; this script validates unlock state and teleports safely.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ColorData = require(ReplicatedStorage:WaitForChild("ColorData"))
local Events = ReplicatedStorage:WaitForChild("Events")

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
	SpawnWorld = {
		DisplayName = "Spawn World",
		SpawnNames = { "StartSectorSpawn", "SpawnWorldSpawn", "RedWastelandsSpawn", "RedZoneSpawn", "SpawnLocation" },
		AlwaysUnlocked = true,
		CurrentWorld = "Red",
	},
	RedWastelands = {
		DisplayName = "Red Wastelands",
		SpawnNames = { "RedWastelandsSpawn", "RedZoneSpawn", "StartSectorSpawn", "SpawnLocation" },
		AlwaysUnlocked = true,
		CurrentWorld = "Red",
	},
	InsidePipes = {
		DisplayName = "Inside the Pipes",
		SpawnNames = { "InsidePipesSpawn", "PipeExitSpawn", "MutationZoneSpawn" },
		AlwaysUnlocked = true,
		CurrentWorld = "Red",
	},
	OrangeSector = {
		DisplayName = "Orange Sector",
		SpawnNames = { "OrangeSectorSpawn", "OrangeZoneSpawn", "OrangeSpawn" },
		RequiredColor = "Orange",
		CurrentWorld = "Orange",
	},
	FutureSector = {
		DisplayName = "Future Sector",
		SpawnNames = {},
		Locked = true,
	},
}

local function fireResult(player, success, locationId, message)
	travelResult:FireClient(player, {
		Success = success,
		LocationId = locationId,
		Message = message,
	})
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

	local valuesFolder = player:FindFirstChild("Values") or player:FindFirstChild("Data") or player:FindFirstChild("PlayerData")
	if valuesFolder then
		local unlockedValue = valuesFolder:FindFirstChild("UnlockedColors")
		if unlockedValue and unlockedValue:IsA("StringValue") then
			return ColorData.getUnlockedColorSet(unlockedValue.Value)
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
		if data.CurrentWorld == colorName or data.ActiveWorldColor == colorName or data.HighestUnlockedWorld == colorName then
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

local function canTravel(player, config)
	if config.Locked then
		return false, "Locked"
	end
	if config.AlwaysUnlocked then
		return true
	end
	if config.RequiredColor then
		if isColorUnlocked(player, config.RequiredColor) then
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
		end
		fireResult(player, true, locationId, "Traveled to " .. config.DisplayName)
	else
		fireResult(player, false, locationId, message or "Travel failed")
	end
end)

Players.PlayerRemoving:Connect(function(player)
	cooldownByPlayer[player] = nil
end)
