-- Server-owned area unlocks using the existing ColorStorage.UnlockedColors value.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ColorData = require(ReplicatedStorage:WaitForChild("ColorData"))
local GameBalance = require(ReplicatedStorage:WaitForChild("GameBalance"))

local Events = ReplicatedStorage:WaitForChild("Events")
local unlockEvent = Events:WaitForChild("UnlockArea")
local requestTravelToSectorEvent = Events:WaitForChild("RequestTravelToSector")
local travelResultEvent = Events:FindFirstChild("TravelToLocationResult")
local dataDirtyEvent = Events:FindFirstChild("PlayerDataDirty")
local tutorialWorldTraveledEvent = Events:FindFirstChild("TutorialWorldTraveled")
if not tutorialWorldTraveledEvent then
	tutorialWorldTraveledEvent = Instance.new("BindableEvent")
	tutorialWorldTraveledEvent.Name = "TutorialWorldTraveled"
	tutorialWorldTraveledEvent.Parent = Events
end

local cooldowns = {}
local lastReturnAt = {}
local returnInFlight = {}
local teleportLocks = {}
local teleportGraceTokens = {}
local COOLDOWN = 2
local TELEPORT_LOCK_TIME = 1.25
local STARTUP_RETURN_DELAY = 2.8
local DESTINATION_WAIT_TIME = 7
local MAP_NAME = "ColorSimulatorMap"
local GATES_FOLDER_NAME = "Gates"
local INTERACTION_ZONE_NAME = "GateInteractionZone"
local RUNTIME_WORLD_BUILDING_ENABLED = GameBalance.FeatureFlags and GameBalance.FeatureFlags.RuntimeWorldBuildingEnabled == true
local RETURN_TO_WORLD_ON_SPAWN = GameBalance.Map and GameBalance.Map.ReturnToCurrentWorldOnSpawn == true
local PROGRESSION_CONFIG = GameBalance.Progression or {}
local MAX_PLAYABLE_SECTOR_INDEX = tonumber(PROGRESSION_CONFIG.MaxPlayableSectorIndex) or math.huge
local DEFAULT_UNLOCKED_SECTOR_INDEX = tonumber(PROGRESSION_CONFIG.DefaultUnlockedSectorIndex) or 1
local destinationCache = {}
local unexpectedUnlockWarnings = {}

local function isSectorPlayable(colorType)
	local index = ColorData.getWorldIndex(colorType)
	return index ~= nil and index <= MAX_PLAYABLE_SECTOR_INDEX
end

local function getLockedSectorMessage(world)
	return (world and world.name or "This Sector") .. " is locked for now."
end

local function warnUnexpectedUnlockValuesOnce(player)
	local key = tostring(player and player.UserId or "server")
	if unexpectedUnlockWarnings[key] then
		return
	end
	unexpectedUnlockWarnings[key] = true
	warn("UnlockArea request ignored unexpected client value fields. Server calculates costs and progression.")
end

local function formatCoins(value)
	return GameBalance.formatNumber(value) .. " Coins"
end

local function markDataDirty(player, reason)
	local event = dataDirtyEvent
	if not event or not event.Parent then
		event = Events:FindFirstChild("PlayerDataDirty")
		dataDirtyEvent = event
	end

	if event and event:IsA("BindableEvent") then
		event:Fire(player, reason or "area-unlock")
	end
end

local function useCooldown(player)
	local now = os.clock()
	if cooldowns[player] and now - cooldowns[player] < COOLDOWN then
		return false
	end
	cooldowns[player] = now
	return true
end

local function getStorage(player)
	local storage = player:FindFirstChild("ColorStorage")
	local stats = player:FindFirstChild("leaderstats")
	if not storage or not stats then
		return nil
	end

	local unlocked = storage:FindFirstChild("UnlockedColors")
	local coins = stats:FindFirstChild("Coins")
	if not unlocked or not coins then
		return nil
	end

	return unlocked, coins
end

local function setCurrentWorld(player, colorType, reason)
	local world = ColorData.getWorldByColor(colorType)
	if not world or not isSectorPlayable(world.primaryColor) then
		return
	end

	player:SetAttribute("ActiveWorldColor", world.primaryColor)
	local storage = player:FindFirstChild("ColorStorage")
	local currentWorld = storage and storage:FindFirstChild("CurrentWorld")
	if currentWorld and currentWorld:IsA("StringValue") and currentWorld.Value ~= world.primaryColor then
		currentWorld.Value = world.primaryColor
	end
	markDataDirty(player, reason or "current-world")
end

local function appendUnlockedColor(unlockedValue, colorType)
	local set = ColorData.getUnlockedColorSet(unlockedValue.Value)
	if set[colorType] then
		return
	end

	local ordered = {}
	for _, world in ipairs(ColorData.Worlds) do
		if set[world.primaryColor] or world.primaryColor == colorType then
			table.insert(ordered, world.primaryColor)
		end
	end

	unlockedValue.Value = table.concat(ordered, ",")
end

local function appendUnlockedTeleport(player, locationId)
	local storage = player and player:FindFirstChild("ColorStorage")
	local teleports = storage and storage:FindFirstChild("UnlockedTeleports")
	if not teleports or not teleports:IsA("StringValue") then
		return false
	end

	local set = {}
	for _, existing in ipairs(string.split(teleports.Value or "", ",")) do
		if existing ~= "" then
			set[existing] = true
		end
	end
	set.OriginSector = true
	if set[locationId] then
		return false
	end
	set[locationId] = true

	local ordered = {}
	for _, id in ipairs({ "OriginSector", "RedWastelands", "ZorkShop", "OrangeSector", "InsidePipes", "GreenSector" }) do
		if set[id] then
			table.insert(ordered, id)
		end
	end
	teleports.Value = table.concat(ordered, ",")
	markDataDirty(player, "unlocked-teleport")
	return true
end

local function ensureDefaultUnlockedSectors(player)
	local unlockedValue = player:FindFirstChild("ColorStorage")
		and player.ColorStorage:FindFirstChild("UnlockedColors")
	if not unlockedValue then
		return
	end

	local before = unlockedValue.Value
	for index, world in ipairs(ColorData.Worlds or {}) do
		if index > DEFAULT_UNLOCKED_SECTOR_INDEX or index > MAX_PLAYABLE_SECTOR_INDEX then
			break
		end
		appendUnlockedColor(unlockedValue, world.primaryColor)
	end

	if unlockedValue.Value ~= before then
		markDataDirty(player, "default-unlocked-sectors")
	end
end

local function getBasePart(instance)
	if not instance then
		return nil
	end
	if instance:IsA("BasePart") then
		return instance
	end
	if instance:IsA("Model") then
		return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
	end
	return instance:FindFirstChildWhichIsA("BasePart", true)
end

local function getWorldFromGateName(gateName)
	local normalized = string.lower((gateName or ""):gsub("%s+", ""))
	for _, world in ipairs(ColorData.Worlds) do
		local color = string.lower(world.primaryColor)
		local id = string.lower(world.id)
		if normalized == color .. "gate" or normalized == id .. "gate" then
			return world
		end
	end
	return nil
end

local function isGateCandidate(gate)
	if not gate then
		return false
	end
	if gate:GetAttribute("AreaGate")
		or gate:GetAttribute("GateColor")
		or gate:GetAttribute("UnlockColor")
		or gate:GetAttribute("ColorType")
	then
		return true
	end

	local normalized = string.lower((gate.Name or ""):gsub("%s+", ""))
	return normalized:sub(-4) == "gate"
end

local function getWorldFromGate(gate)
	if not gate then
		return nil
	end

	local colorType = gate:GetAttribute("GateColor")
		or gate:GetAttribute("UnlockColor")
		or gate:GetAttribute("ColorType")
	local world = ColorData.getWorldByColor(colorType)
	if world then
		return world
	end

	return getWorldFromGateName(gate.Name)
end

local function applyGateAttributes(part, world)
	part:SetAttribute("AreaGate", true)
	part:SetAttribute("GateColor", world.primaryColor)
	part:SetAttribute("UnlockColor", world.primaryColor)
	part:SetAttribute("ColorType", world.primaryColor)
end

local function isBakedEditableMap()
	local mapConfig = GameBalance.Map or {}
	if mapConfig.UseBakedMap == false then
		return false
	end

	local map = workspace:FindFirstChild(MAP_NAME)
	return map
		and (map:GetAttribute("BakedEditableMap") == true or map:FindFirstChild("Lobby") or map:FindFirstChild("RedZone"))
end

local function shouldPreserveGateVisuals(part)
	return isBakedEditableMap() and part:GetAttribute("GeneratedBy") == "StudioZoneBuilder"
end

local function styleGatePart(part, world)
	local worldColor = ColorData.Colors[world.primaryColor] and ColorData.Colors[world.primaryColor].color or Color3.fromRGB(120, 220, 255)
	part.Material = Enum.Material.SmoothPlastic
	part.Color = worldColor:Lerp(Color3.fromRGB(30, 34, 42), 0.45)
	part.Transparency = math.min(part.Transparency, 0.18)
	part.Reflectance = 0.04
	part.CanCollide = true
end

local function makeGateVisualPart(root, name, size, offset, color, material)
	local part = root:FindFirstChild(name)
	if not part then
		part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.Parent = root
	end

	part.Size = size
	part.CFrame = root.CFrame * CFrame.new(offset)
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Transparency = 0
	part:SetAttribute("GateDecor", true)
	part:SetAttribute("ColorType", root:GetAttribute("ColorType"))
	return part
end

local function ensureSurfaceText(sign, face, suffix, world)
	local surface = sign:FindFirstChild("GateSignSurface" .. suffix)
	if not surface then
		surface = Instance.new("SurfaceGui")
		surface.Name = "GateSignSurface" .. suffix
		surface.Face = face
		surface.LightInfluence = 0
		surface.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		surface.CanvasSize = Vector2.new(420, 140)
		surface.Parent = sign

		local backing = Instance.new("Frame")
		backing.Name = "Backing"
		backing.Size = UDim2.new(1, 0, 1, 0)
		backing.BackgroundColor3 = Color3.fromRGB(24, 27, 34)
		backing.BackgroundTransparency = 0.12
		backing.BorderSizePixel = 0
		backing.Parent = surface
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = backing
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(225, 234, 246)
		stroke.Transparency = 0.45
		stroke.Thickness = 2
		stroke.Parent = backing

		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.BackgroundTransparency = 1
		title.Size = UDim2.new(1, -34, 0, 54)
		title.Position = UDim2.new(0, 17, 0, 18)
		title.Font = Enum.Font.GothamBold
		title.TextSize = 24
		title.TextColor3 = Color3.fromRGB(242, 248, 255)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Text = world.name
		title.Parent = backing

		local status = Instance.new("TextLabel")
		status.Name = "Status"
		status.BackgroundTransparency = 1
		status.Size = UDim2.new(1, -34, 0, 38)
		status.Position = UDim2.new(0, 17, 0, 74)
		status.Font = Enum.Font.GothamMedium
		status.TextSize = 18
		status.TextColor3 = Color3.fromRGB(255, 216, 122)
		status.TextXAlignment = Enum.TextXAlignment.Left
		status.Text = "Unlock " .. formatCoins(world.unlockCost)
		status.Parent = backing
	end
end

local function ensureGateVisuals(part, world)
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("BillboardGui") and (child.Name == "GateBillboard" or child.Name == "Label") then
			child:Destroy()
		end
	end

	local worldColor = ColorData.Colors[world.primaryColor] and ColorData.Colors[world.primaryColor].color or Color3.fromRGB(120, 220, 255)
	local width = math.max(12, part.Size.X)
	local height = math.max(12, part.Size.Y)
	local depth = math.max(1, part.Size.Z)
	local frontZ = -(depth / 2 + 0.16)
	local frameColor = Color3.fromRGB(24, 27, 34)
	local glowColor = worldColor:Lerp(Color3.fromRGB(245, 255, 255), 0.18)

	local top = makeGateVisualPart(part, "GateVisualTopFrame", Vector3.new(width + 3, 1.4, 0.7), Vector3.new(0, height / 2 + 0.7, frontZ), frameColor)
	local left = makeGateVisualPart(part, "GateVisualLeftFrame", Vector3.new(1.4, height + 2.8, 0.7), Vector3.new(-width / 2 - 0.7, 0, frontZ), frameColor)
	local right = makeGateVisualPart(part, "GateVisualRightFrame", Vector3.new(1.4, height + 2.8, 0.7), Vector3.new(width / 2 + 0.7, 0, frontZ), frameColor)
	local glowLeft = makeGateVisualPart(part, "GateVisualLeftGlow", Vector3.new(0.45, height - 5, 0.5), Vector3.new(-width / 2 + 2.2, 0, frontZ - 0.08), glowColor, Enum.Material.Neon)
	local glowRight = makeGateVisualPart(part, "GateVisualRightGlow", Vector3.new(0.45, height - 5, 0.5), Vector3.new(width / 2 - 2.2, 0, frontZ - 0.08), glowColor, Enum.Material.Neon)
	local statusLight = makeGateVisualPart(part, "GateVisualStatusLight", Vector3.new(1.4, 1.4, 0.6), Vector3.new(width / 2 - 3.2, height / 2 - 3.2, frontZ - 0.12), Color3.fromRGB(255, 120, 120), Enum.Material.Neon)
	local sign = makeGateVisualPart(part, "GateVisualSign", Vector3.new(math.min(22, width - 6), 6.2, 0.55), Vector3.new(0, math.min(6, height * 0.16), frontZ - 0.2), Color3.fromRGB(24, 27, 34))

	for _, visual in ipairs({ top, left, right, glowLeft, glowRight, statusLight, sign }) do
		visual:SetAttribute("GateVisualRole", visual.Name)
	end

	ensureSurfaceText(sign, Enum.NormalId.Front, "Front", world)
	ensureSurfaceText(sign, Enum.NormalId.Back, "Back", world)
end

local function ensureGateInteraction(part, world)
	local zone = part:FindFirstChild(INTERACTION_ZONE_NAME)
	if not zone then
		zone = Instance.new("Part")
		zone.Name = INTERACTION_ZONE_NAME
		zone.Parent = part
	end

	local width = math.max(24, part.Size.X + 24)
	local height = 14
	local depth = 26
	local gateDepth = math.max(1, part.Size.Z)
	zone.Anchored = true
	zone.CanCollide = false
	zone.CanTouch = false
	zone.CanQuery = false
	zone.CastShadow = false
	zone.Transparency = 1
	zone.Size = Vector3.new(width, height, depth)
	zone.CFrame = part.CFrame * CFrame.new(0, -part.Size.Y / 2 + height / 2 + 2, -(gateDepth / 2 + depth / 2 + 4))
	zone:SetAttribute("GateInteraction", true)
	zone:SetAttribute("GateColor", world.primaryColor)
	zone:SetAttribute("UnlockColor", world.primaryColor)
	zone:SetAttribute("ColorType", world.primaryColor)
	return zone
end

local function ensureGatePrompt(part, world)
	if not RUNTIME_WORLD_BUILDING_ENABLED then
		local existingPrompt = part:FindFirstChild("GatePrompt", true)
		if existingPrompt and existingPrompt:IsA("ProximityPrompt") then
			existingPrompt.ActionText = "Unlock"
			existingPrompt.ObjectText = world.name
			existingPrompt.RequiresLineOfSight = false
			existingPrompt:SetAttribute("UnlockColor", world.primaryColor)
			return existingPrompt
		end
		return nil
	end

	local promptParent = ensureGateInteraction(part, world)
	local existingPrompt = part:FindFirstChild("GatePrompt")
	if existingPrompt and existingPrompt.Parent ~= promptParent then
		existingPrompt.Parent = promptParent
	end

	local prompt = promptParent:FindFirstChild("GatePrompt")
	local created = false
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "GatePrompt"
		prompt.Parent = promptParent
		created = true
	end

	prompt.ActionText = "Unlock " .. world.name
	prompt.ObjectText = world.name .. " - " .. formatCoins(world.unlockCost)
	prompt.HoldDuration = 0.1
	prompt.MaxActivationDistance = 30
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt:SetAttribute("AreaGatePrompt", true)

	if created then
		print("Gate prompt created for " .. part.Name)
	end
	return prompt
end

local function configureGate(gate)
	local part = getBasePart(gate)
	if not part or part:GetAttribute("GateDecor") or part:GetAttribute("GateInteraction") then
		return nil
	end
	if not isGateCandidate(part) and not isGateCandidate(gate) then
		return nil
	end

	local world = getWorldFromGate(part) or getWorldFromGate(gate)
	if not world then
		warn("Missing zone data for gate " .. gate.Name)
		return nil
	end

	applyGateAttributes(part, world)
	part:SetAttribute("AreaGateConfigured", true)
	if RUNTIME_WORLD_BUILDING_ENABLED and not shouldPreserveGateVisuals(part) then
		styleGatePart(part, world)
		ensureGateVisuals(part, world)
	end
	return ensureGatePrompt(part, world)
end

local function isSectorDestinationCandidate(instance, colorType)
	if not instance then
		return false
	end
	if colorType == "Red" and instance:GetAttribute("DistantSectorColumn") == true then
		return false
	end
	local sectorColor = instance:GetAttribute("SectorColor")
		or instance:GetAttribute("ColorType")
		or instance:GetAttribute("AreaColor")
	return sectorColor == colorType
		and (instance:GetAttribute("SectorAnchor") == true
			or instance:GetAttribute("DistantSectorColumn") == true)
end

local function getObjectColor(instance)
	if not instance then
		return nil
	end
	local attrColor = instance:GetAttribute("AreaSpawnColor")
		or instance:GetAttribute("TeleportColor")
		or instance:GetAttribute("SectorColor")
		or instance:GetAttribute("ColorType")
		or instance:GetAttribute("AreaColor")
	if attrColor then
		return attrColor
	end

	local loweredName = string.lower(instance.Name or "")
	for _, world in ipairs(ColorData.Worlds or {}) do
		local color = world.primaryColor
		if typeof(color) == "string" and string.find(loweredName, string.lower(color)) then
			return color
		end
	end
	return nil
end

local function isPlayableDestinationFloor(part, colorType)
	if not part or not part:IsA("BasePart") then
		return false
	end

	if part:GetAttribute("EggStation") == true or part:GetAttribute("BrushShop") == true or part:GetAttribute("ShopStation") == true then
		return false
	end
	if part:GetAttribute("DistantSectorColumn") == true or part:GetAttribute("SectorAnchor") == true then
		return false
	end

	local partColor = getObjectColor(part)
	if partColor ~= colorType then
		return false
	end

	if part:GetAttribute("PlayableSectorFloor") == true or part:GetAttribute("ColorZone") == true then
		return true
	end

	local size = part.Size
	local horizontalArea = size.X * size.Z
	local smallestHorizontal = math.max(1, math.min(size.X, size.Z))
	return size.X >= 35 and size.Z >= 35 and horizontalArea >= 1600 and size.Y <= smallestHorizontal * 0.28
end

local function getPlayableFloorScore(part, colorType)
	local size = part.Size
	local score = size.X * size.Z
	local loweredName = string.lower(part.Name or "")
	local loweredColor = string.lower(tostring(colorType or ""))
	if part:GetAttribute("PlayableSectorFloor") == true then
		score += 1000000
	end
	if part:GetAttribute("AreaSpawn") == true or part:GetAttribute("WorldSpawn") == true then
		score += 500000
	end
	if loweredColor ~= "" and (string.find(loweredName, loweredColor .. "zone") or string.find(loweredName, loweredColor .. "floor")) then
		score += 250000
	end
	return score
end

local function findBestPlayableFloor(root, colorType)
	if not root then
		return nil
	end

	if root:IsA("BasePart") and isPlayableDestinationFloor(root, colorType) then
		return root
	end

	local bestPart = nil
	local bestScore = -math.huge
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("BasePart") and isPlayableDestinationFloor(descendant, colorType) then
			local score = getPlayableFloorScore(descendant, colorType)
			if score > bestScore then
				bestPart = descendant
				bestScore = score
			end
		end
	end

	return bestPart
end

local function isNamedSpawnDestination(part)
	if not part or not part:IsA("BasePart") then
		return false
	end

	local loweredName = string.lower(part.Name or "")
	return part:IsA("SpawnLocation")
		or loweredName == "spawnpoint"
		or loweredName == "spawnlocation"
		or loweredName == "sectorspawn"
		or loweredName == "arrivalspawn"
		or loweredName == "travelspawn"
		or part:GetAttribute("AreaSpawn") == true
		or part:GetAttribute("WorldSpawn") == true
		or part:GetAttribute("SectorSpawn") == true
end

local function getAncestorColor(instance)
	local current = instance
	while current and current ~= workspace do
		local colorType = getObjectColor(current)
		if colorType then
			return colorType
		end
		current = current.Parent
	end
	return nil
end

local function isSectorSpawnForColor(part, colorType, rootColor)
	if not isNamedSpawnDestination(part) then
		return false
	end
	if part:GetAttribute("EggStation") == true or part:GetAttribute("BrushShop") == true or part:GetAttribute("ShopStation") == true then
		return false
	end

	local partColor = getObjectColor(part) or getAncestorColor(part) or rootColor
	return partColor == colorType
end

local function getSpawnDestinationScore(part)
	local loweredName = string.lower(part.Name or "")
	local score = 0
	if part:IsA("SpawnLocation") then
		score += 10000
	end
	if loweredName == "spawnlocation" then
		score += 8000
	end
	if part:GetAttribute("AreaSpawn") == true or part:GetAttribute("WorldSpawn") == true or part:GetAttribute("SectorSpawn") == true then
		score += 5000
	end
	if loweredName == "sectorspawn" or loweredName == "arrivalspawn" or loweredName == "travelspawn" then
		score += 3000
	end
	score -= math.abs(part.Position.Y) * 0.001
	return score
end

local function findBestSectorSpawn(root, colorType)
	if not root then
		return nil
	end

	local rootColor = getObjectColor(root)
	if root:IsA("BasePart") and isSectorSpawnForColor(root, colorType, rootColor) then
		return root
	end

	local bestPart = nil
	local bestScore = -math.huge
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("BasePart") and isSectorSpawnForColor(descendant, colorType, rootColor) then
			local score = getSpawnDestinationScore(descendant)
			if score > bestScore then
				bestPart = descendant
				bestScore = score
			end
		end
	end

	return bestPart
end

local function cacheDestination(cacheKey, destination)
	destinationCache[cacheKey] = destination
	return destination
end

local function findSectorDestination(colorType)
	local map = workspace:FindFirstChild(MAP_NAME)
	local distantSectors = map and map:FindFirstChild("DistantSectors")
	if colorType == "Orange" then
		local sector1 = (distantSectors and distantSectors:FindFirstChild("sector1", true))
			or workspace:FindFirstChild("sector1", true)
		local sectorSpawn = findBestSectorSpawn(sector1, colorType)
		if sectorSpawn then
			return cacheDestination("sector:" .. tostring(colorType), sectorSpawn)
		end
		local playableFloor = findBestPlayableFloor(sector1, colorType)
		if playableFloor then
			return cacheDestination("sector:" .. tostring(colorType), playableFloor)
		end
	end

	local namedSectorSpawn = distantSectors and findBestSectorSpawn(distantSectors, colorType)
	if namedSectorSpawn then
		return cacheDestination("sector:" .. tostring(colorType), namedSectorSpawn)
	end

	local cached = destinationCache["sector:" .. tostring(colorType)]
	if cached and cached.Parent then
		if cached:IsA("BasePart") and isNamedSpawnDestination(cached) then
			return cached
		end
		local playableCached = findBestPlayableFloor(cached, colorType)
		if playableCached then
			return cacheDestination("sector:" .. tostring(colorType), playableCached)
		end
		if cached:IsA("BasePart") and isPlayableDestinationFloor(cached, colorType) then
			return cached
		end
	end

	local playableSectorFloor = distantSectors and findBestPlayableFloor(distantSectors, colorType)
	if playableSectorFloor then
		return cacheDestination("sector:" .. tostring(colorType), playableSectorFloor)
	end

	local roots = {}
	if distantSectors then
		table.insert(roots, distantSectors)
	end
	table.insert(roots, workspace)

	local seen = {}
	for _, root in ipairs(roots) do
		for _, obj in ipairs(root:GetDescendants()) do
			if not seen[obj] and (obj:IsA("Model") or obj:IsA("BasePart")) and isSectorDestinationCandidate(obj, colorType) then
				seen[obj] = true
				local sectorSpawn = findBestSectorSpawn(obj, colorType)
				if sectorSpawn then
					return cacheDestination("sector:" .. tostring(colorType), sectorSpawn)
				end
				local playableFloor = findBestPlayableFloor(obj, colorType)
				return cacheDestination("sector:" .. tostring(colorType), playableFloor or obj)
			end
		end
	end

	return nil
end

local function findStartSectorDestination()
	local cached = destinationCache["start-sector"]
	if cached and cached.Parent then
		return cached
	end

	local map = workspace:FindFirstChild(MAP_NAME)
	local spawnFolder = map and map:FindFirstChild("ColorSimSpawn")
	local spawnLocation = spawnFolder and spawnFolder:FindFirstChild("SpawnLocation")
	if spawnLocation and spawnLocation:IsA("BasePart") then
		destinationCache["start-sector"] = spawnLocation
		return spawnLocation
	end

	local redWastelands = map and map:FindFirstChild("RedWastelands")
	local redFloor = redWastelands and redWastelands:FindFirstChild("RedFloor1")
	if redFloor and redFloor:IsA("BasePart") then
		destinationCache["start-sector"] = redFloor
		return redFloor
	end

	local namedRedFloor = workspace:FindFirstChild("RedFloor1", true)
	if namedRedFloor and namedRedFloor:IsA("BasePart") then
		destinationCache["start-sector"] = namedRedFloor
		return namedRedFloor
	end

	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("SpawnLocation") then
			local spawnColor = obj:GetAttribute("AreaSpawnColor")
				or obj:GetAttribute("SpawnColor")
				or obj:GetAttribute("TeleportColor")
				or obj:GetAttribute("ColorType")
			if spawnColor == nil or spawnColor == "Red" then
				destinationCache["start-sector"] = obj
				return obj
			end
		end
	end

	return nil
end

local function findAreaDestination(colorType)
	if colorType == "Red" then
		local startDestination = findStartSectorDestination()
		if startDestination then
			return startDestination
		end
	else
		local cached = destinationCache[colorType]
		if cached and cached.Parent then
			return cached
		end
	end

	local sectorDestination = findSectorDestination(colorType)
	if sectorDestination then
		return sectorDestination
	end

	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("BasePart") then
			local areaSpawnColor = obj:GetAttribute("AreaSpawnColor")
			local spawnColorAttribute = obj:GetAttribute("SpawnColor")
			local teleportColor = obj:GetAttribute("TeleportColor")
			local spawnColor = typeof(areaSpawnColor) == "string" and areaSpawnColor
				or typeof(spawnColorAttribute) == "string" and spawnColorAttribute
				or typeof(teleportColor) == "string" and teleportColor

			if obj:GetAttribute("AreaSpawn") or obj:GetAttribute("WorldSpawn") or obj:GetAttribute("ColorZone") then
				spawnColor = spawnColor or obj:GetAttribute("ColorType")
			end

			if spawnColor == colorType then
				destinationCache[colorType] = obj
				return obj
			end
		end
	end

	local names = {
		colorType .. "Spawn",
		colorType .. "AreaSpawn",
		colorType .. "WorldSpawn",
		colorType .. "Zone",
		colorType .. "Area",
	}

	for _, name in ipairs(names) do
		local found = workspace:FindFirstChild(name, true)
		local part = getBasePart(found)
		if part then
			destinationCache[colorType] = part
			return part
		end
	end

	return nil
end

local function getSpawnLandingCFrame(part)
	local lookVector = part.CFrame.LookVector
	local flatLook = Vector3.new(lookVector.X, 0, lookVector.Z)
	if flatLook.Magnitude < 0.05 then
		flatLook = Vector3.new(0, 0, -1)
	end

	local position = part.CFrame:PointToWorldSpace(Vector3.new(0, part.Size.Y * 0.5 + 5, 0))
	return CFrame.lookAt(position, position + flatLook.Unit)
end

local function getPartLandingCFrame(part)
	local lookVector = part.CFrame.LookVector
	if math.abs(lookVector.Y) > 0.8 then
		lookVector = Vector3.new(0, 0, -1)
	end

	local origin = part.CFrame:PointToWorldSpace(Vector3.new(0, part.Size.Y * 0.5 + 80, 0))
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = { part }

	local result = workspace:Raycast(origin, Vector3.new(0, -220, 0), raycastParams)
	local position = (result and result.Position or part.CFrame:PointToWorldSpace(Vector3.new(0, part.Size.Y * 0.5, 0))) + Vector3.new(0, 6, 0)
	local flatLook = Vector3.new(lookVector.X, 0, lookVector.Z)
	if flatLook.Magnitude < 0.05 then
		flatLook = Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(position, position + flatLook.Unit)
end

local function getDestinationCFrame(destination)
	if not destination then
		return nil
	end

	if destination:IsA("BasePart") and isNamedSpawnDestination(destination) then
		return getSpawnLandingCFrame(destination)
	end

	if destination:IsA("BasePart") and isPlayableDestinationFloor(destination, getObjectColor(destination)) then
		return getPartLandingCFrame(destination)
	end

	if destination:IsA("Model") then
		local colorType = getObjectColor(destination)
		local sectorSpawn = findBestSectorSpawn(destination, colorType)
		if sectorSpawn then
			return getSpawnLandingCFrame(sectorSpawn)
		end
		local playableFloor = findBestPlayableFloor(destination, colorType)
		if playableFloor then
			return getPartLandingCFrame(playableFloor)
		end

		local cf, size = destination:GetBoundingBox()
		local topY = cf.Position.Y + size.Y * 0.5
		local position = Vector3.new(cf.Position.X, topY + 8, cf.Position.Z)
		return CFrame.lookAt(position, cf.Position)
	end

	if destination:IsA("BasePart")
		and (destination:GetAttribute("SectorAnchor") == true or destination:GetAttribute("DistantSectorColumn") == true)
	then
		local topY = destination.Position.Y + destination.Size.Y * 0.5
		local position = Vector3.new(destination.Position.X, topY + 8, destination.Position.Z)
		return CFrame.lookAt(position, destination.Position)
	end

	if destination:IsA("BasePart") then
		return getPartLandingCFrame(destination)
	end

	local part = getBasePart(destination)
	return part and getPartLandingCFrame(part) or nil
end

local function getOrCreateMap()
	local map = workspace:FindFirstChild(MAP_NAME)
	if not map and RUNTIME_WORLD_BUILDING_ENABLED then
		map = Instance.new("Folder")
		map.Name = MAP_NAME
		map.Parent = workspace
	end
	return map
end

local function findPartForColor(colorType, predicate)
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("BasePart") and predicate(obj) then
			local objColor = obj:GetAttribute("ColorType")
				or obj:GetAttribute("AreaColor")
				or obj:GetAttribute("SellColor")
				or obj:GetAttribute("TeleportColor")
			if objColor == colorType then
				return obj
			end
		end
	end
	return nil
end

local function createFallbackSpawn(colorType)
	if not RUNTIME_WORLD_BUILDING_ENABLED then
		return nil
	end

	local world = ColorData.getWorldByColor(colorType)
	if not world then
		return nil
	end

	local zone = findPartForColor(colorType, function(part)
		return part:GetAttribute("ColorZone") == true
	end)
	local station = zone
		or findPartForColor(colorType, function(part)
			return part:GetAttribute("SellZone")
				or part:GetAttribute("SellLocation")
				or part:GetAttribute("BrushShop")
				or part:GetAttribute("UpgradeStation")
				or part:GetAttribute("EggId")
		end)

	local basePosition
	if zone then
		basePosition = zone.Position + Vector3.new(
			-math.min(math.max(zone.Size.X * 0.32, 42), 110),
			zone.Size.Y * 0.5 + 0.75,
			-math.min(math.max(zone.Size.Z * 0.32, 42), 110)
		)
	elseif station then
		basePosition = station.Position + Vector3.new(0, math.max(station.Size.Y * 0.5 + 1, 3), -18)
	elseif colorType == "Red" then
		basePosition = Vector3.new(0, 1, 0)
	else
		return nil
	end

	local map = getOrCreateMap()
	local folder = map:FindFirstChild("RuntimeWorldSpawns")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "RuntimeWorldSpawns"
		folder.Parent = map
	end

	local spawn = folder:FindFirstChild(colorType .. "RuntimeSpawn")
	if not spawn then
		spawn = Instance.new("Part")
		spawn.Name = colorType .. "RuntimeSpawn"
		spawn.Size = Vector3.new(22, 1, 22)
		spawn.Anchored = true
		spawn.CanCollide = true
		spawn.CanTouch = false
		spawn.TopSurface = Enum.SurfaceType.Smooth
		spawn.BottomSurface = Enum.SurfaceType.Smooth
		spawn.Parent = folder
	end

	local colorInfo = ColorData.Colors[colorType]
	spawn.CFrame = CFrame.new(basePosition)
	spawn.Color = colorInfo and colorInfo.color:Lerp(Color3.fromRGB(255, 255, 255), 0.28) or Color3.fromRGB(118, 238, 244)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn:SetAttribute("AreaSpawn", true)
	spawn:SetAttribute("WorldSpawn", true)
	spawn:SetAttribute("AreaSpawnColor", colorType)
	spawn:SetAttribute("SpawnColor", colorType)
	spawn:SetAttribute("TeleportColor", colorType)
	spawn:SetAttribute("ColorType", colorType)
	destinationCache[colorType] = spawn
	warn("AreaUnlockHandler: created fallback spawn for " .. tostring(colorType) .. ".")
	return spawn
end

local function waitForAreaDestination(colorType, timeoutSeconds)
	local deadline = os.clock() + (timeoutSeconds or 0)
	repeat
		local destination = findAreaDestination(colorType)
		if destination then
			return destination
		end
		task.wait(0.2)
	until os.clock() >= deadline

	return createFallbackSpawn(colorType) or findAreaDestination(colorType)
end

local function waitForRoot(player, timeoutSeconds)
	local deadline = os.clock() + (timeoutSeconds or 0)
	repeat
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			return root
		end
		task.wait(0.1)
	until os.clock() >= deadline
	return nil
end

local function restoreCharacterMovement(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		root.Anchored = false
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
	if humanoid then
		humanoid.PlatformStand = false
		humanoid.Sit = false
		humanoid.AutoRotate = true
		if humanoid.WalkSpeed <= 0 then
			humanoid.WalkSpeed = 44
		end
	end
end

local function beginTeleportGrace(player)
	local token = (teleportGraceTokens[player] or 0) + 1
	teleportGraceTokens[player] = token
	player:SetAttribute("IsTeleporting", true)

	task.delay(1, function()
		if player.Parent and teleportGraceTokens[player] == token then
			player:SetAttribute("IsTeleporting", false)
		end
	end)
end

local function teleportCharacterSafely(player, destinationCFrame)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not root or not destinationCFrame then
		return false
	end

	beginTeleportGrace(player)
	restoreCharacterMovement(player)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	character:PivotTo(destinationCFrame)

	if humanoid then
		humanoid.PlatformStand = false
		humanoid.Sit = false
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end

	task.delay(0.1, function()
		if player.Parent and player.Character == character and root.Parent then
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			if humanoid and humanoid.Parent then
				humanoid.PlatformStand = false
				humanoid.Sit = false
			end
		end
	end)

	return true
end

local function sendState(player)
	local unlockedValue = player:FindFirstChild("ColorStorage")
		and player.ColorStorage:FindFirstChild("UnlockedColors")
	local currentWorld = player:FindFirstChild("ColorStorage")
		and player.ColorStorage:FindFirstChild("CurrentWorld")
	unlockEvent:FireClient(
		player,
		"state",
		unlockedValue and unlockedValue.Value or "Red",
		ColorData.Worlds,
		currentWorld and currentWorld.Value or player:GetAttribute("ActiveWorldColor") or "Red"
	)
end

local function teleportToWorld(player, world)
	local now = os.clock()
	if teleportLocks[player] and now - teleportLocks[player] < TELEPORT_LOCK_TIME then
		return false
	end
	teleportLocks[player] = now

	if not isSectorPlayable(world.primaryColor) then
		unlockEvent:FireClient(player, "error", world.primaryColor, getLockedSectorMessage(world))
		restoreCharacterMovement(player)
		return false
	end

	local startedAt = os.clock()
	local root = waitForRoot(player, 3)
	local destination = waitForAreaDestination(world.primaryColor, DESTINATION_WAIT_TIME)
	if not root or not destination then
		warn("Missing spawn point for " .. world.primaryColor .. " (" .. world.name .. ")")
		unlockEvent:FireClient(player, "error", world.primaryColor, "Sector travel failed. Try again.")
		restoreCharacterMovement(player)
		return false
	end

	print("Traveling to " .. world.name)
	setCurrentWorld(player, world.primaryColor, "current-world")
	local destinationCFrame = getDestinationCFrame(destination)
	if not destinationCFrame then
		unlockEvent:FireClient(player, "error", world.primaryColor, "Sector travel failed. Try again.")
		restoreCharacterMovement(player)
		return false
	end
	if not teleportCharacterSafely(player, destinationCFrame) then
		unlockEvent:FireClient(player, "error", world.primaryColor, "Sector travel failed. Try again.")
		restoreCharacterMovement(player)
		return false
	end
	local populateRequest = ServerScriptService:FindFirstChild("RequestPopulateColorZone")
	if populateRequest and populateRequest:IsA("BindableEvent") then
		populateRequest:Fire(world.primaryColor)
	end
	unlockEvent:FireClient(player, "teleported", world.primaryColor, world)
	if tutorialWorldTraveledEvent and tutorialWorldTraveledEvent:IsA("BindableEvent") then
		tutorialWorldTraveledEvent:Fire(player, world.primaryColor, world)
	end
	local elapsed = os.clock() - startedAt
	print("SectorTravel: " .. player.Name .. " -> " .. tostring(world.primaryColor) .. " in " .. string.format("%.2f", elapsed) .. "s")
	print("Sector travel completed: " .. tostring(world.primaryColor) .. " in " .. string.format("%.3f", elapsed) .. "s")
	if elapsed > 0.5 then
		warn("SectorTravel slow: " .. tostring(world.primaryColor) .. " took " .. string.format("%.2f", elapsed) .. "s")
	end
	return true
end

local function tryUnlockWorld(player, world)
	local unlockedValue, coins = getStorage(player)
	if not unlockedValue then
		unlockEvent:FireClient(player, "error", world.primaryColor, "Data is not ready.")
		return false
	end

	if not isSectorPlayable(world.primaryColor) then
		unlockEvent:FireClient(player, "error", world.primaryColor, getLockedSectorMessage(world))
		sendState(player)
		return false
	end

	if ColorData.isColorUnlocked(unlockedValue.Value, world.primaryColor) then
		sendState(player)
		return true
	end

	local previousWorld = ColorData.getPreviousWorld(world.primaryColor)
	if previousWorld and not ColorData.isColorUnlocked(unlockedValue.Value, previousWorld.primaryColor) then
		print("Missing prerequisite for " .. player.Name .. ": " .. previousWorld.name)
		unlockEvent:FireClient(player, "error", world.primaryColor, "Unlock " .. previousWorld.name .. " first.")
		return false
	end

	if coins.Value < world.unlockCost then
		print("Not enough Coins: " .. player.Name .. " needs " .. tostring(world.unlockCost) .. " for " .. world.name)
		unlockEvent:FireClient(player, "error", world.primaryColor, "Need " .. formatCoins(world.unlockCost) .. " to unlock " .. world.name)
		return false
	end

	coins.Value -= world.unlockCost
	appendUnlockedColor(unlockedValue, world.primaryColor)
	setCurrentWorld(player, world.primaryColor, "current-world")
	local teleportLocationId = world.primaryColor == "Orange" and "OrangeSector"
		or world.primaryColor == "Green" and "GreenSector"
		or nil
	local unlockedTeleport = teleportLocationId and appendUnlockedTeleport(player, teleportLocationId)
	markDataDirty(player, "unlocked-" .. world.primaryColor)
	print("Unlocked " .. world.name .. " for " .. tostring(world.unlockCost) .. " Coins")
	unlockEvent:FireClient(player, "unlocked", world.primaryColor, world)
	if unlockedTeleport and travelResultEvent and travelResultEvent:IsA("RemoteEvent") then
		travelResultEvent:FireClient(player, {
			Success = true,
			LocationId = teleportLocationId,
			DisplayName = world.name,
			UnlockedTeleport = true,
			Message = world.name .. " teleport unlocked.",
		})
	end
	sendState(player)
	return true
end

local function handleUnlockRequest(player, actionOrColor, maybeColor, ...)
	if select("#", ...) > 0 then
		warnUnexpectedUnlockValuesOnce(player)
	end

	if not useCooldown(player) then
		return
	end

	local action = "unlock"
	local colorType = actionOrColor
	if maybeColor ~= nil then
		action = tostring(actionOrColor)
		colorType = maybeColor
	end

	local world = ColorData.getWorldByColor(colorType)
	if not world then
		warn("Missing zone data for " .. tostring(colorType))
		unlockEvent:FireClient(player, "error", colorType, "Unknown area.")
		return
	end

	local unlockedValue, coins = getStorage(player)
	if not unlockedValue then
		unlockEvent:FireClient(player, "error", colorType, "Data is not ready.")
		return
	end

	if action == "teleport" then
		if not isSectorPlayable(world.primaryColor) then
			unlockEvent:FireClient(player, "error", colorType, getLockedSectorMessage(world))
			sendState(player)
			return
		end
		if not ColorData.isColorUnlocked(unlockedValue.Value, world.primaryColor) then
			unlockEvent:FireClient(player, "error", colorType, "Unlock " .. world.name .. " first.")
			return
		end

		print("Already unlocked, teleporting")
		teleportToWorld(player, world)
		return
	elseif action ~= "unlock" then
		unlockEvent:FireClient(player, "error", colorType, "Unknown action.")
		return
	end

	if tryUnlockWorld(player, world) then
		teleportToWorld(player, world)
	end
end

unlockEvent.OnServerEvent:Connect(handleUnlockRequest)

local function normalizeSectorRequest(sectorId)
	local raw = tostring(sectorId or "")
	local compact = string.lower(raw:gsub("%s+", ""):gsub("_", ""):gsub("-", ""))
	compact = compact:gsub("sector$", ""):gsub("area$", ""):gsub("world$", "")
	for _, world in ipairs(ColorData.Worlds or {}) do
		local candidates = {
			world.id,
			world.primaryColor,
			world.ZoneId,
			world.DisplayName,
			world.name,
		}
		for _, candidate in ipairs(candidates) do
			if candidate then
				local normalized = string.lower(tostring(candidate):gsub("%s+", ""):gsub("_", ""):gsub("-", ""))
				normalized = normalized:gsub("sector$", ""):gsub("area$", ""):gsub("world$", "")
				if compact == normalized then
					return world
				end
			end
		end
	end
	return nil
end

requestTravelToSectorEvent.OnServerEvent:Connect(function(player, sectorId)
	local world = normalizeSectorRequest(sectorId)
	if not world then
		warn("RequestTravelToSector rejected unknown sector: " .. tostring(sectorId))
		requestTravelToSectorEvent:FireClient(player, false, sectorId, "Unknown sector.")
		return
	end

	local unlockedValue = player:FindFirstChild("ColorStorage")
		and player.ColorStorage:FindFirstChild("UnlockedColors")
	if not unlockedValue then
		requestTravelToSectorEvent:FireClient(player, false, world.primaryColor, "Data is not ready.")
		return
	end

	if not isSectorPlayable(world.primaryColor) then
		requestTravelToSectorEvent:FireClient(player, false, world.primaryColor, getLockedSectorMessage(world))
		return
	end

	if not ColorData.isColorUnlocked(unlockedValue.Value, world.primaryColor) then
		warn("[AreaUnlockHandler] " .. player.Name .. " requested locked sector travel to " .. tostring(world.primaryColor))
		requestTravelToSectorEvent:FireClient(player, false, world.primaryColor, "Unlock " .. world.name .. " first.")
		return
	end

	if teleportToWorld(player, world) then
		requestTravelToSectorEvent:FireClient(player, true, world.primaryColor, "Traveling to " .. world.name)
	else
		requestTravelToSectorEvent:FireClient(player, false, world.primaryColor, "Sector travel failed. Try again.")
	end
end)

local function hookGatePrompt(prompt)
	if not prompt:IsA("ProximityPrompt") or not prompt:GetAttribute("AreaGatePrompt") then
		return
	end
	if prompt:GetAttribute("AreaGatePromptHooked") then
		return
	end
	prompt:SetAttribute("AreaGatePromptHooked", true)

	prompt.Triggered:Connect(function(player)
		if not useCooldown(player) then
			return
		end

		local gate = prompt.Parent
		local world = getWorldFromGate(gate)
		if not world then
			warn("Missing zone data for gate prompt " .. prompt:GetFullName())
			return
		end

		print(player.Name .. " requested gate " .. gate.Name .. " -> " .. world.primaryColor)
		local unlockedValue = player:FindFirstChild("ColorStorage")
			and player.ColorStorage:FindFirstChild("UnlockedColors")
		local alreadyUnlocked = unlockedValue and ColorData.isColorUnlocked(unlockedValue.Value, world.primaryColor)
		if alreadyUnlocked then
			print("Already unlocked, teleporting")
			teleportToWorld(player, world)
		elseif tryUnlockWorld(player, world) then
			print("Unlock successful")
			teleportToWorld(player, world)
		end
	end)
end

local function configureExistingGates()
	local map = workspace:FindFirstChild(MAP_NAME)
	local gatesFolder = map and map:FindFirstChild(GATES_FOLDER_NAME)
	if not gatesFolder then
		warn("Missing " .. MAP_NAME .. "." .. GATES_FOLDER_NAME .. " folder for Sector gates")
		return
	end

	for _, gate in ipairs(gatesFolder:GetDescendants()) do
		local prompt = configureGate(gate)
		if prompt then
			hookGatePrompt(prompt)
		end
	end
end

for _, obj in ipairs(workspace:GetDescendants()) do
	hookGatePrompt(obj)
end
workspace.DescendantAdded:Connect(hookGatePrompt)
task.defer(configureExistingGates)

workspace.DescendantAdded:Connect(function(obj)
	local map = workspace:FindFirstChild(MAP_NAME)
	local gatesFolder = map and map:FindFirstChild(GATES_FOLDER_NAME)
	if gatesFolder and obj:IsDescendantOf(gatesFolder) then
		task.defer(function()
			local prompt = configureGate(obj)
			if prompt then
				hookGatePrompt(prompt)
			end
		end)
	end
end)

local function returnToCurrentWorld(player)
	if returnInFlight[player] then
		return
	end
	local now = os.clock()
	if lastReturnAt[player] and now - lastReturnAt[player] < 1.5 then
		return
	end
	returnInFlight[player] = true

	local storage = player:FindFirstChild("ColorStorage")
	if not storage then
		storage = player:WaitForChild("ColorStorage", 10)
	end
	if not storage then
		returnInFlight[player] = nil
		return
	end

	local currentWorld = storage:FindFirstChild("CurrentWorld")
	local unlockedValue = storage:FindFirstChild("UnlockedColors")
	local world = ColorData.getWorldByColor(currentWorld and currentWorld.Value or "Red")
	if world and isSectorPlayable(world.primaryColor) and ColorData.isColorUnlocked(unlockedValue and unlockedValue.Value or "Red", world.primaryColor) then
		if teleportToWorld(player, world) then
			lastReturnAt[player] = now
		end
	end
	returnInFlight[player] = nil
end

Players.PlayerAdded:Connect(function(player)
	if RETURN_TO_WORLD_ON_SPAWN then
		player.CharacterAdded:Connect(function()
			task.delay(STARTUP_RETURN_DELAY, function()
				if player.Parent then
					returnToCurrentWorld(player)
				end
			end)
		end)
	end

	player:WaitForChild("ColorStorage", 10)
	task.wait(0.5)
	ensureDefaultUnlockedSectors(player)
	sendState(player)
	if RETURN_TO_WORLD_ON_SPAWN then
		task.delay(STARTUP_RETURN_DELAY, function()
			returnToCurrentWorld(player)
		end)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	cooldowns[player] = nil
	lastReturnAt[player] = nil
	returnInFlight[player] = nil
	teleportLocks[player] = nil
	teleportGraceTokens[player] = nil
end)
