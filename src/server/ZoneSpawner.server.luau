-- Script in ServerScriptService named "ZoneSpawner"
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ColorData = require(ReplicatedStorage:WaitForChild("ColorData"))
local GameBalance = require(ReplicatedStorage:WaitForChild("GameBalance"))

local featureFlags = GameBalance.FeatureFlags or {}
if featureFlags.RuntimeColorPopulationEnabled == false then
	warn("ZoneSpawner: runtime color population disabled.")
	return
end

local SPAWN_CONFIG = {
	PaintBlob = 0.66,
	PaintGlob = 0.25,
	PaintBoulder = 0.09,
}

local PUDDLE_VERSION = "paint-puddle-v8"
local MAP_NAME = "ColorSimulatorMap"
local RUNTIME_BLOB_FOLDER_NAME = "RuntimeColorBlobs"
local COLLECTOR_BASE_TRANSPARENCY = 0.985
local CLUSTER_COUNT_MULTIPLIER = 1
local DEBUG_LOGS = false
local SPAWN_RETRY_LIMIT = 28
local DEFAULT_EXCLUSION_PADDING = 8
local EGG_EXCLUSION_PADDING = 34
local SHOP_EXCLUSION_PADDING = 10
local PROGRESSION_CONFIG = GameBalance.Progression or {}
local MAX_PLAYABLE_SECTOR_INDEX = tonumber(PROGRESSION_CONFIG.MaxPlayableSectorIndex) or math.huge
local objectHealth = {}
local lastPopulatedAt = {}
local populateRequest = ServerScriptService:FindFirstChild("RequestPopulateColorZone")
if not populateRequest then
	populateRequest = Instance.new("BindableEvent")
	populateRequest.Name = "RequestPopulateColorZone"
	populateRequest.Parent = ServerScriptService
end

local function getMapConfig()
	return GameBalance.Map or {}
end

local function getZonePopulationConfig()
	return GameBalance.ZonePopulation or {}
end

local function isSectorPlayable(colorType)
	local index = ColorData.getWorldIndex(colorType)
	return index ~= nil and index <= MAX_PLAYABLE_SECTOR_INDEX
end

local function isPointInside(part, worldPosition, margin)
	local localPoint = part.CFrame:PointToObjectSpace(worldPosition)
	local half = part.Size * 0.5 + Vector3.new(margin, margin, margin)
	return math.abs(localPoint.X) <= half.X and math.abs(localPoint.Y) <= half.Y and math.abs(localPoint.Z) <= half.Z
end

local function inferPlayableSectorColorFromName(part)
	if not part or not part:IsA("BasePart") then
		return nil
	end

	local partName = string.lower(part.Name or "")
	local parentName = part.Parent and string.lower(part.Parent.Name or "") or ""
	local namedAsSurface = string.find(partName, "floor")
		or string.find(partName, "ground")
		or string.find(partName, "zone")
		or string.find(partName, "area")
		or string.find(partName, "sector")
		or string.find(parentName, "floor")
		or string.find(parentName, "zone")
		or string.find(parentName, "area")
		or string.find(parentName, "sector")

	if not namedAsSurface then
		return nil
	end

	for _, world in ipairs(ColorData.Worlds or {}) do
		local color = world.primaryColor
		if color then
			local loweredColor = string.lower(color)
			if string.find(partName, loweredColor, 1, true) or string.find(parentName, loweredColor, 1, true) then
				return color
			end
		end
	end

	return nil
end

local function hasProtectedEggAncestor(part)
	local current = part
	while current do
		local name = string.lower(current.Name or "")
		if
			string.find(name, "egg", 1, true)
			or current:GetAttribute("EggStation") == true
			or current:GetAttribute("TutorialEgg") == true
			or current:GetAttribute("BakedTutorialEgg") == true
			or current:GetAttribute("EggId") ~= nil
		then
			return true
		end
		current = current.Parent
	end
	return false
end

local function hasNoSpawnNameOrAttribute(part)
	if not part or not part:IsA("BasePart") then
		return false
	end
	if part:IsA("SpawnLocation") then
		return true
	end
	if
		part:GetAttribute("AreaSpawn") == true
		or part:GetAttribute("WorldSpawn") == true
		or part:GetAttribute("SectorSpawn") == true
		or part:GetAttribute("LobbySpawn") == true
		or part:GetAttribute("NoColorSpawn") == true
		or part:GetAttribute("SafeZone") == true
		or part:GetAttribute("TeleportLocation") == true
		or part:GetAttribute("PipeTeleport") == true
		or part:GetAttribute("SectorInteriorEntrance") == true
		or part:GetAttribute("SectorInteriorExit") == true
	then
		return true
	end

	local current = part
	while current do
		local name = string.lower(current.Name or "")
		if
			string.find(name, "spawn", 1, true)
			or string.find(name, "teleport", 1, true)
			or string.find(name, "safe", 1, true)
			or string.find(name, "tutorial", 1, true)
			or string.find(name, "pipe", 1, true)
			or string.find(name, "portal", 1, true)
			or string.find(name, "gate", 1, true)
		then
			return true
		end
		current = current.Parent
	end
	return false
end

local function shouldNeverBeColorZone(part)
	if not part or not part:IsA("BasePart") then
		return false
	end
	local partName = string.lower(part.Name or "")
	local parentName = part.Parent and string.lower(part.Parent.Name or "") or ""
	local floorishName = string.find(partName, "floor", 1, true)
		or string.find(partName, "ground", 1, true)
		or string.find(partName, "zone", 1, true)
		or string.find(partName, "area", 1, true)
		or string.find(parentName, "floor", 1, true)
		or string.find(parentName, "ground", 1, true)
		or string.find(parentName, "zone", 1, true)
		or string.find(parentName, "area", 1, true)
	local namedPlayableSectorColor = inferPlayableSectorColorFromName(part)
	local playableSectorFloor = part:GetAttribute("PlayableSectorFloor") == true
	local playableNamedSectorFloor = floorishName
		and namedPlayableSectorColor
		and isSectorPlayable(namedPlayableSectorColor)

	if
		part:IsA("SpawnLocation")
		or part.Name == "SpawnEgg"
		or part:FindFirstAncestor("SpawnEgg") ~= nil
		or part:FindFirstAncestor("PetAppearanceStudio") ~= nil
		or part:GetAttribute("BreakableType") ~= nil
		or part:GetAttribute("PaintPuddleVersion") ~= nil
		or part:GetAttribute("GemDeposit") == true
		or part:GetAttribute("WildColor") == true
		or part:FindFirstAncestor("DynamicGameplay") ~= nil
		or hasProtectedEggAncestor(part)
		or part:GetAttribute("EggStation") == true
		or part:GetAttribute("EggId") ~= nil
		or part:GetAttribute("TutorialEgg") == true
		or part:GetAttribute("BrushShop") == true
		or part:GetAttribute("CombinedShop") == true
		or part:GetAttribute("ShopStation") == true
		or part:GetAttribute("ShopEntrance") == true
		or part:GetAttribute("MutationStation") == true
		or part:GetAttribute("MutationUnlockStation") == true
		or part:GetAttribute("FeatureUnlock") == "Mutations"
		or part:GetAttribute("SectorInterior") == true
		or part:GetAttribute("MutationUnlockArea") == true
		or part:GetAttribute("DecorativeOnly") == true
		or part:GetAttribute("AreaSpawn") == true
		or part:GetAttribute("WorldSpawn") == true
		or part:GetAttribute("LobbySpawn") == true
		or part:GetAttribute("AreaGate") == true
		or part:GetAttribute("GateInteraction") == true
		or part:GetAttribute("ColorBlobSpawn") == true
		or hasNoSpawnNameOrAttribute(part)
	then
		return true
	end
	if playableSectorFloor or playableNamedSectorFloor then
		return false
	end

	if part:GetAttribute("DistantSectorColumn") == true or part:GetAttribute("SectorAnchor") == true then
		return true
	end

	local map = workspace:FindFirstChild(MAP_NAME)
	local shop = map and map:FindFirstChild("Shop")
	local distantSectors = map and map:FindFirstChild("DistantSectors")
	return (shop ~= nil and part:IsDescendantOf(shop))
		or (
			distantSectors ~= nil
			and part:IsDescendantOf(distantSectors)
			and part:GetAttribute("PlayableSectorFloor") ~= true
			and not namedPlayableSectorColor
		)
end

local function looksLikeZoneSurface(part)
	if part:GetAttribute("PlayableSectorFloor") == true then
		return true
	end
	local partName = string.lower(part.Name or "")
	local parentName = part.Parent and string.lower(part.Parent.Name or "") or ""
	if
		string.find(partName, "pipe", 1, true)
		or string.find(parentName, "pipe", 1, true)
		or partName == "core"
		or partName == "glowshell"
		or partName == "highlight"
		or string.find(partName, "floatcore", 1, true)
	then
		return false
	end
	local horizontalArea = part.Size.X * part.Size.Z
	local largeFlatSurface = horizontalArea >= 1600
		and part.Size.X >= 35
		and part.Size.Z >= 35
		and part.Size.Y <= math.max(8, math.min(part.Size.X, part.Size.Z) * 0.3)
	local namedSurface = string.find(partName, "floor")
		or string.find(partName, "ground")
		or string.find(partName, "zone")
		or string.find(partName, "area")
		or string.find(partName, "sector")
		or string.find(parentName, "floor")
		or string.find(parentName, "zone")
		or string.find(parentName, "area")
		or string.find(parentName, "sector")
	return largeFlatSurface or namedSurface
end

local function inferColorFromMapPart(part)
	local attrColor = part:GetAttribute("ColorType")
		or part:GetAttribute("WorldColor")
		or part:GetAttribute("AreaColor")
	if ColorData.getWorldByColor(attrColor) and looksLikeZoneSurface(part) then
		return attrColor
	end

	local partName = string.lower(part.Name or "")
	local parentName = part.Parent and string.lower(part.Parent.Name or "") or ""
	local looksLikeFloor = string.find(partName, "floor")
		or string.find(partName, "ground")
		or string.find(partName, "zone")
		or string.find(partName, "area")
	for _, world in ipairs(ColorData.Worlds or {}) do
		local color = world.primaryColor
		local loweredColor = string.lower(color)
		if looksLikeFloor and (string.find(partName, loweredColor) or string.find(parentName, loweredColor)) then
			return color
		end
	end

	return nil
end

local function getZoneScore(part)
	local area = math.max(1, part.Size.X * part.Size.Z)
	if part:GetAttribute("PlayableSectorFloor") == true then
		area *= 10
	end
	if part:GetAttribute("ColorZone") == true then
		area *= 2
	end
	return area
end

local function configureColorZonePart(part)
	if shouldNeverBeColorZone(part) then
		if part:GetAttribute("ColorZone") == true then
			part:SetAttribute("ColorZone", false)
		end
		return nil
	end
	if not looksLikeZoneSurface(part) then
		if part:GetAttribute("ColorZone") == true then
			part:SetAttribute("ColorZone", false)
		end
		return nil
	end

	local colorType = inferColorFromMapPart(part)
	if not colorType then
		return nil
	end

	if part:GetAttribute("ColorZone") ~= true then
		part:SetAttribute("ColorZone", true)
	end
	if part:GetAttribute("ColorType") ~= colorType then
		part:SetAttribute("ColorType", colorType)
	end
	if inferPlayableSectorColorFromName(part) == colorType and part:GetAttribute("PlayableSectorFloor") ~= true then
		part:SetAttribute("PlayableSectorFloor", true)
	end
	return colorType
end

local function shouldClearGeneratedMapOnStart()
	return getMapConfig().ClearGeneratedMapOnStart == true
end

local function isBakedEditableMap(map)
	return map
		and (
			map:GetAttribute("BakedEditableMap") == true
			or map:FindFirstChild("Lobby")
			or map:FindFirstChild("RedZone")
		)
end

local function getRuntimeBlobParent()
	local map = workspace:FindFirstChild(MAP_NAME)
	if not map then
		return workspace
	end

	local folder = map:FindFirstChild(RUNTIME_BLOB_FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = RUNTIME_BLOB_FOLDER_NAME
		folder:SetAttribute("RuntimeGenerated", true)
		folder.Parent = map
	end
	return folder
end

local function getVisualColor(colorType)
	if colorType == "Rainbow" then
		return Color3.fromHSV(math.random(), 0.72, 1)
	end

	local colorInfo = ColorData.Colors[colorType]
	return colorInfo and colorInfo.color or Color3.new(1, 1, 1)
end

local function getBaseVisualColor(colorType)
	if colorType == "Rainbow" then
		return Color3.fromRGB(215, 180, 255)
	end

	local colorInfo = ColorData.Colors[colorType]
	return colorInfo and colorInfo.color or Color3.new(1, 1, 1)
end

local function getVariedThemeColor(colorType)
	if colorType == "Rainbow" then
		return getVisualColor(colorType)
	end

	local base = getVisualColor(colorType)
	local hue, saturation, value = base:ToHSV()
	hue = (hue + math.random(-3, 3) / 100) % 1
	saturation = math.clamp(saturation + math.random(8, 18) / 100, 0.72, 0.96)
	value = math.clamp(value + math.random(10, 22) / 100, 0.88, 1)

	return Color3.fromHSV(hue, saturation, value)
end

local function getStoredColor(part, colorType)
	local stored = part and part:GetAttribute("SpawnColor")
	if typeof(stored) == "Color3" then
		return stored
	end
	return getBaseVisualColor(colorType)
end

local function randomPositionInZone(zonePart)
	local size = zonePart.Size
	local cf = zonePart.CFrame
	local rx = math.random() * size.X - size.X / 2
	local rz = math.random() * size.Z - size.Z / 2
	local ry = size.Y / 2
	return cf:PointToWorldSpace(Vector3.new(rx, ry, rz))
end

local function isRuntimeBlobPart(part)
	return part
		and part:IsA("BasePart")
		and part:GetAttribute("BreakableType") ~= nil
		and part:GetAttribute("PaintPuddleVersion") == PUDDLE_VERSION
end

local function isProtectedSpawnBlocker(part, zone)
	if not part or not part:IsA("BasePart") or part == zone or isRuntimeBlobPart(part) then
		return false
	end
	if shouldNeverBeColorZone(part) then
		return true
	end
	if part:GetAttribute("ColorZone") == true or part:GetAttribute("ColorBlobSpawn") == true then
		return false
	end

	if
		part:IsA("SpawnLocation")
		or hasNoSpawnNameOrAttribute(part)
		or part:GetAttribute("NoColorSpawn") == true
		or part:GetAttribute("SafeZone") == true
		or part:GetAttribute("TeleportLocation") == true
		or part:GetAttribute("PipeTeleport") == true
		or part:GetAttribute("SectorInteriorEntrance") == true
		or part:GetAttribute("SectorInteriorExit") == true
		or part:GetAttribute("AreaSpawn") == true
		or part:GetAttribute("WorldSpawn") == true
		or part:GetAttribute("SectorSpawn") == true
		or part:GetAttribute("LobbySpawn") == true
		or part.Name == "SpawnEgg"
		or part.Name == "ShopEntrance"
		or part.Name == "Door"
		or part.Name == "Entrance"
		or part:FindFirstAncestor("SpawnEgg") ~= nil
		or hasProtectedEggAncestor(part)
		or part:GetAttribute("EggStation") == true
		or part:GetAttribute("TutorialEgg") == true
		or part:GetAttribute("BrushShop") == true
		or part:GetAttribute("CombinedShop") == true
		or part:GetAttribute("ShopStation") == true
		or part:GetAttribute("ShopEntrance") == true
	then
		return true
	end

	local map = workspace:FindFirstChild(MAP_NAME)
	local shop = map and map:FindFirstChild("Shop")
	if shop and part:IsDescendantOf(shop) then
		return true
	end

	if map and part:IsDescendantOf(map) and not part:GetAttribute("ColorZone") then
		local ancestor = part.Parent
		while ancestor and ancestor ~= map do
			local name = string.lower(ancestor.Name or "")
			if
				string.find(name, "shop", 1, true)
				or string.find(name, "egg", 1, true)
				or string.find(name, "spawn", 1, true)
			then
				return true
			end
			ancestor = ancestor.Parent
		end
	end

	return false
end

local function collectSpawnExclusions(zone)
	local exclusions = {}
	for _, obj in ipairs(workspace:GetDescendants()) do
		if isProtectedSpawnBlocker(obj, zone) then
			table.insert(exclusions, obj)
		end
	end
	return exclusions
end

local function getExclusionPadding(part, defaultPadding)
	if
		part.Name == "SpawnEgg"
		or part:FindFirstAncestor("SpawnEgg") ~= nil
		or hasProtectedEggAncestor(part)
		or part:GetAttribute("EggStation") == true
		or part:GetAttribute("TutorialEgg") == true
	then
		return EGG_EXCLUSION_PADDING
	end
	if
		part:GetAttribute("BrushShop") == true
		or part:GetAttribute("CombinedShop") == true
		or part:GetAttribute("ShopStation") == true
		or part:GetAttribute("ShopEntrance") == true
		or part:FindFirstAncestor("Shop") ~= nil
	then
		return SHOP_EXCLUSION_PADDING
	end
	return defaultPadding or DEFAULT_EXCLUSION_PADDING
end

local function isPositionInsidePartFootprint(position, part, padding)
	local localPoint = part.CFrame:PointToObjectSpace(position)
	return math.abs(localPoint.X) <= part.Size.X * 0.5 + padding
		and math.abs(localPoint.Z) <= part.Size.Z * 0.5 + padding
end

local function isPositionAllowed(position, exclusions, padding)
	for _, part in ipairs(exclusions or {}) do
		if part.Parent and isPositionInsidePartFootprint(position, part, getExclusionPadding(part, padding)) then
			return false
		end
	end
	return true
end

local function getSpawnPosition(zone, forcedPosition, exclusions)
	if forcedPosition and isPositionAllowed(forcedPosition, exclusions, DEFAULT_EXCLUSION_PADDING) then
		return forcedPosition
	end

	for _ = 1, SPAWN_RETRY_LIMIT do
		local candidate = randomPositionInZone(zone)
		if isPositionAllowed(candidate, exclusions, DEFAULT_EXCLUSION_PADDING) then
			return candidate
		end
	end

	return nil
end

local function markerMatchesZone(marker, zone, colorType)
	local markerColor = marker:GetAttribute("ColorType") or marker:GetAttribute("AreaColor")
	if markerColor and markerColor ~= colorType then
		return false
	end

	local markerZoneId = marker:GetAttribute("ZoneId")
	if
		markerZoneId
		and markerZoneId ~= zone.Name
		and markerZoneId ~= colorType
		and markerZoneId ~= colorType .. "Zone"
	then
		return false
	end

	return marker:GetAttribute("SpawnType") == "ColorBlob" or marker:GetAttribute("ColorBlobSpawn") == true
end

local function getSpawnMarkers(zone, colorType)
	local map = workspace:FindFirstChild(MAP_NAME)
	if not map then
		return {}
	end

	local roots = {}
	if zone.Parent then
		table.insert(roots, zone.Parent)
	end
	local globalSpawns = map:FindFirstChild("ColorBlobSpawns")
	if globalSpawns then
		table.insert(roots, globalSpawns)
	end
	table.insert(roots, map)

	local markers = {}
	local seen = {}
	for _, root in ipairs(roots) do
		for _, obj in ipairs(root:GetDescendants()) do
			if obj:IsA("BasePart") and not seen[obj] and markerMatchesZone(obj, zone, colorType) then
				seen[obj] = true
				table.insert(markers, obj)
			end
		end
	end

	return markers
end

local function randomPositionAtMarker(marker, zone)
	local size = marker.Size
	local rx = (math.random() - 0.5) * math.max(size.X, 4)
	local rz = (math.random() - 0.5) * math.max(size.Z, 4)
	local point = marker.CFrame:PointToWorldSpace(Vector3.new(rx, 0, rz))
	local zoneSurfaceY = zone.Position.Y + zone.Size.Y / 2
	return Vector3.new(point.X, math.max(point.Y, zoneSurfaceY), point.Z)
end

local function getPuddleSize(baseSize)
	local spreadX = math.random(158, 202) / 100
	local spreadZ = math.random(138, 184) / 100
	local thickness = math.random(38, 56) / 100
	return Vector3.new(
		math.max(1.15, baseSize.X * spreadX),
		math.max(0.35, baseSize.Y * thickness),
		math.max(1.15, baseSize.Z * spreadZ)
	)
end

local function setPuddleDetailsVisible(part, visible)
	for _, child in ipairs(part:GetDescendants()) do
		if child:IsA("BasePart") and child:GetAttribute("PuddleDetail") then
			child.Transparency = visible and (child:GetAttribute("VisibleTransparency") or 0) or 1
		end
	end
end

local function addPuddlePiece(root, name, localCFrame, size, color, transparency, material)
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Shape = Enum.PartType.Ball
	piece.Size = size
	piece.CFrame = root.CFrame * localCFrame
	piece.Color = color
	piece.Transparency = transparency or 0
	piece.Material = material or root.Material
	piece.Anchored = true
	piece.CanCollide = false
	piece.CanTouch = false
	piece.CanQuery = false
	piece.CastShadow = false
	piece.Massless = true
	piece:SetAttribute("PuddleDetail", true)
	piece:SetAttribute("VisibleTransparency", piece.Transparency)
	piece.Parent = root

	return piece
end

local function addPuddleDetails(part)
	local baseColor = part.Color
	local baseSize = part.Size
	local darker = baseColor:Lerp(Color3.fromRGB(60, 48, 68), 0.1)
	local lighter = baseColor:Lerp(Color3.new(1, 1, 1), 0.22)
	local glossy = baseColor:Lerp(Color3.new(1, 1, 1), 0.48)
	local yTop = baseSize.Y * 0.34

	addPuddlePiece(
		part,
		"PuddleSoftShadow",
		CFrame.new(0, -baseSize.Y * 0.58, 0),
		Vector3.new(baseSize.X * 1.2, math.max(0.08, baseSize.Y * 0.2), baseSize.Z * 1.18),
		Color3.fromRGB(75, 28, 58),
		0.72,
		Enum.Material.SmoothPlastic
	)

	local lobeCount = math.random(3, 4)
	for i = 1, lobeCount do
		local angle = (math.pi * 2 / lobeCount) * i + math.random(-45, 45) / 100
		local offset = Vector3.new(
			math.cos(angle) * baseSize.X * math.random(24, 48) / 100,
			-baseSize.Y * 0.06,
			math.sin(angle) * baseSize.Z * math.random(22, 44) / 100
		)
		local lobeSize = Vector3.new(
			baseSize.X * math.random(58, 82) / 100,
			math.max(0.24, baseSize.Y * math.random(64, 90) / 100),
			baseSize.Z * math.random(54, 78) / 100
		)
		local lobeColor = (i % 2 == 0) and lighter or darker:Lerp(baseColor, 0.72)
		addPuddlePiece(
			part,
			"PuddleLobe",
			CFrame.new(offset) * CFrame.Angles(0, angle, 0),
			lobeSize,
			lobeColor,
			0,
			part.Material
		)
	end

	addPuddlePiece(
		part,
		"PuddleGloss",
		CFrame.new(-baseSize.X * 0.16, yTop, -baseSize.Z * 0.08) * CFrame.Angles(0, math.rad(math.random(-24, 24)), 0),
		Vector3.new(baseSize.X * 0.36, math.max(0.1, baseSize.Y * 0.2), baseSize.Z * 0.12),
		glossy,
		0.16,
		Enum.Material.Neon
	)

	addPuddlePiece(
		part,
		"PuddleGlossDot",
		CFrame.new(baseSize.X * 0.18, yTop + 0.02, baseSize.Z * 0.14),
		Vector3.new(baseSize.X * 0.13, math.max(0.1, baseSize.Y * 0.18), baseSize.Z * 0.13),
		glossy,
		0.08,
		Enum.Material.Neon
	)

	for i = 1, math.random(2, 3) do
		local angle = math.random() * math.pi * 2
		local distance = math.random(66, 112) / 100
		local splashSize = math.random(18, 31) / 100
		addPuddlePiece(
			part,
			"PuddleSplash",
			CFrame.new(
				math.cos(angle) * baseSize.X * distance,
				-baseSize.Y * 0.06,
				math.sin(angle) * baseSize.Z * distance
			),
			Vector3.new(baseSize.X * splashSize * 1.3, math.max(0.08, baseSize.Y * 0.18), baseSize.X * splashSize),
			baseColor:Lerp(Color3.new(1, 1, 1), math.random(8, 26) / 100),
			0,
			part.Material
		)
	end
end

local function spawnObject(zone, breakableType, colorType, forcedPosition, exclusions)
	local data = ColorData.Breakables[breakableType]
	if not data then
		return
	end
	local world = ColorData.getWorldByColor(colorType)
	local configuredRewardMult = world and tonumber(world.rewardMultiplier)
	local zoneRewardMult = tonumber(zone:GetAttribute("RewardMultiplier"))
	local rewardMult = configuredRewardMult
		or zoneRewardMult
		or (world and math.max(1, world.breakableHealth / 10))
		or 1
	if configuredRewardMult and zoneRewardMult then
		rewardMult = math.min(zoneRewardMult, configuredRewardMult)
	end

	local part = Instance.new("Part")
	part.Name = breakableType
	part.Shape = Enum.PartType.Ball
	local sizeScale = math.random(104, 128) / 100
	part.Size = getPuddleSize(data.size * sizeScale)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = GameBalance.Collection and GameBalance.Collection.AllowTouchCollectionFallback == true
	part.CanQuery = true
	part.CastShadow = false
	part.Material = math.random() < 0.22 and Enum.Material.Neon or Enum.Material.SmoothPlastic

	part.Color = getVariedThemeColor(colorType)

	part:SetAttribute("BreakableType", breakableType)
	part:SetAttribute("ColorType", colorType)
	part:SetAttribute("ClusterSize", data.clusterSize or breakableType)
	part:SetAttribute("BaseColorReward", data.baseReward or data.rewardMin or 1)
	part:SetAttribute("RewardMultiplier", rewardMult)
	part:SetAttribute("SpawnColor", part.Color)
	part:SetAttribute("OriginalSize", part.Size)
	part:SetAttribute("PaintPuddleVersion", PUDDLE_VERSION)
	part:SetAttribute("CollectorBaseTransparency", COLLECTOR_BASE_TRANSPARENCY)
	part:SetAttribute("ClusterOnlyVisual", true)

	local pos = getSpawnPosition(zone, forcedPosition, exclusions)
	if not pos then
		return nil
	end
	part.CFrame = CFrame.new(pos + Vector3.new(0, part.Size.Y / 2, 0))
		* CFrame.Angles(0, math.rad(math.random(0, 359)), 0)
	part:SetAttribute("IdleBaseCFrame", part.CFrame)
	addPuddleDetails(part)
	part.Transparency = COLLECTOR_BASE_TRANSPARENCY

	part.Parent = getRuntimeBlobParent()
	objectHealth[part] = data.health
	return part
end

local function countExistingActiveBlobs(colorType, zone)
	local count = 0
	local parent = getRuntimeBlobParent()
	for _, obj in ipairs(parent:GetChildren()) do
		if
			obj:IsA("BasePart")
			and obj:GetAttribute("BreakableType")
			and obj:GetAttribute("ColorType") == colorType
			and obj:GetAttribute("PaintPuddleVersion") == PUDDLE_VERSION
			and not obj:GetAttribute("IsCollected")
			and (not zone or isPointInside(zone, obj.Position, 4))
		then
			count += 1
		end
	end
	return count
end

local function removeOldBreakables()
	local removed = 0
	for _, obj in ipairs(workspace:GetDescendants()) do
		if
			obj:IsA("BasePart")
			and obj:GetAttribute("BreakableType")
			and obj:GetAttribute("PaintPuddleVersion") ~= PUDDLE_VERSION
		then
			obj:Destroy()
			removed += 1
		end
	end

	if DEBUG_LOGS and removed > 0 then
		print("ZoneSpawner: removed " .. tostring(removed) .. " old Color blobs before spawning updated puddles.")
	end
end

local function removeInvalidRuntimeBreakables(zone, colorType)
	local removed = 0
	local exclusions = collectSpawnExclusions(zone)
	local parent = getRuntimeBlobParent()
	for _, obj in ipairs(parent:GetChildren()) do
		if isRuntimeBlobPart(obj) and isPointInside(zone, obj.Position, 4) then
			local objColorType = obj:GetAttribute("ColorType")
			if
				objColorType ~= colorType or not isPositionAllowed(obj.Position, exclusions, DEFAULT_EXCLUSION_PADDING)
			then
				objectHealth[obj] = nil
				obj:Destroy()
				removed += 1
			end
		end
	end
	if DEBUG_LOGS and removed > 0 then
		print("ZoneSpawner: removed " .. tostring(removed) .. " misplaced or blocked Color blobs.")
	end
	return removed
end

local function scheduleRespawn(part, breakableType, colorType, delay)
	part:SetAttribute("Respawning", true)
	task.wait(delay)
	if part and part.Parent then
		local data = ColorData.Breakables[breakableType]
		if data then
			objectHealth[part] = data.health
			part.Transparency = part:GetAttribute("CollectorBaseTransparency") or COLLECTOR_BASE_TRANSPARENCY
			part.CanCollide = false
			part.CanQuery = true
			part:SetAttribute("IsCollected", false)
			setPuddleDetailsVisible(part, true)

			local ci = ColorData.Colors[colorType]
			if ci then
				local visualColor = getStoredColor(part, colorType)
				part.Color = visualColor
				local light = part:FindFirstChildOfClass("PointLight")
				if light then
					light.Color = visualColor
				end
			end

			local origSize = part:GetAttribute("OriginalSize") or data.size
			part.Size = Vector3.new(0.1, 0.1, 0.1)
			for i = 1, 8 do
				task.wait(0.04)
				if part and part.Parent then
					part.Size = origSize * (i / 8)
				end
			end
			if part and part.Parent then
				part.Size = origSize
			end
		end
	end
	if part and part.Parent then
		part:SetAttribute("Respawning", false)
	end
end

local function watchObject(part)
	local breakableType = part:GetAttribute("BreakableType")
	local colorType = part:GetAttribute("ColorType")
	if not breakableType or not colorType then
		return
	end

	part:GetPropertyChangedSignal("Transparency"):Connect(function()
		setPuddleDetailsVisible(part, part.Transparency < 1)
		if part.Transparency >= 1 and not part:GetAttribute("Respawning") then
			scheduleRespawn(part, breakableType, colorType, 4)
		end
	end)
end

local function populateZone(zone)
	local startedAt = os.clock()
	local colorType = zone:GetAttribute("ColorType") or "Red"
	if not isSectorPlayable(colorType) then
		return
	end
	if DEBUG_LOGS then
		print("Populating zone: " .. zone.Name .. " (" .. colorType .. ")")
	end

	local spawned = 0
	local world = ColorData.getWorldByColor(colorType)
	local configuredCount = world and world.blobCount or 44
	local requestedCount =
		math.floor(math.max(tonumber(zone:GetAttribute("BlobCount")) or 0, configuredCount) * CLUSTER_COUNT_MULTIPLIER)
	local populationConfig = getZonePopulationConfig()
	local maxBlobsPerZone = tonumber(populationConfig.MaxBlobsPerZone) or 80
	local targetCount = math.min(requestedCount, maxBlobsPerZone)
	if requestedCount > maxBlobsPerZone then
		warn(
			"ZoneSpawner warning: requested "
				.. tostring(requestedCount)
				.. " blobs, clamped to "
				.. tostring(maxBlobsPerZone)
		)
	end

	removeInvalidRuntimeBreakables(zone, colorType)
	local existingCount = countExistingActiveBlobs(colorType, zone)
	local repopulateCooldown = tonumber(populationConfig.RepopulateCooldown) or 20
	if existingCount >= targetCount then
		lastPopulatedAt[zone] = lastPopulatedAt[zone] or os.clock()
		print(
			"ZoneSpawner: populated "
				.. zone.Name
				.. " with 0 blobs in "
				.. string.format("%.2f", os.clock() - startedAt)
				.. "s; existing="
				.. tostring(existingCount)
				.. "/"
				.. tostring(targetCount)
		)
		return
	end
	if lastPopulatedAt[zone] and os.clock() - lastPopulatedAt[zone] < repopulateCooldown then
		if DEBUG_LOGS then
			print(
				"ZoneSpawner: skipped "
					.. zone.Name
					.. " repopulation during cooldown; existing="
					.. tostring(existingCount)
					.. "/"
					.. tostring(targetCount)
			)
		end
		return
	end
	lastPopulatedAt[zone] = os.clock()

	local remainingToSpawn = math.max(0, targetCount - existingCount)
	local spawnMarkers = getSpawnMarkers(zone, colorType)
	local spawnExclusions = collectSpawnExclusions(zone)
	local spawnIndex = 0
	local spawnedSinceYield = 0
	local spawnBatchSize = math.max(1, tonumber(populationConfig.SpawnBatchSize) or 10)
	local spawnBatchDelay = tonumber(populationConfig.SpawnBatchDelay) or 0.03
	local orderedTypes = { "PaintBlob", "PaintGlob", "PaintBoulder" }
	for index, breakableType in ipairs(orderedTypes) do
		local ratio = SPAWN_CONFIG[breakableType] or 0
		local count = math.floor(remainingToSpawn * ratio)
		if index == #orderedTypes then
			count = remainingToSpawn - spawned
		end
		for i = 1, count do
			if spawned >= remainingToSpawn then
				break
			end
			spawnIndex += 1
			local marker = (#spawnMarkers > 0) and spawnMarkers[((spawnIndex - 1) % #spawnMarkers) + 1] or nil
			local forcedPosition = marker and randomPositionAtMarker(marker, zone) or nil
			local part = spawnObject(zone, breakableType, colorType, forcedPosition, spawnExclusions)
			if part then
				watchObject(part)
				spawned = spawned + 1
				spawnedSinceYield += 1
				if spawnedSinceYield >= spawnBatchSize then
					spawnedSinceYield = 0
					task.wait(spawnBatchDelay)
				end
			end
		end
	end
	local elapsed = os.clock() - startedAt
	print(
		"ZoneSpawner: populated "
			.. zone.Name
			.. " with "
			.. spawned
			.. " blobs in "
			.. string.format("%.2f", elapsed)
			.. "s; existing="
			.. tostring(existingCount)
			.. ", target="
			.. tostring(targetCount)
			.. ", markers="
			.. tostring(#spawnMarkers)
	)
	if elapsed > 0.5 then
		warn("ZoneSpawner: population took over 0.5s for " .. zone.Name .. "; work was batched over frames.")
	end
end

local function findZoneByColor(colorType)
	local best = nil
	local bestScore = -math.huge
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("BasePart") then
			local zoneColor = configureColorZonePart(obj)
			if
				obj:GetAttribute("ColorZone") and (obj:GetAttribute("ColorType") == colorType or zoneColor == colorType)
			then
				local score = getZoneScore(obj)
				if score > bestScore then
					best = obj
					bestScore = score
				end
			end
		end
	end
	return best
end

populateRequest.Event:Connect(function(colorType)
	local zone = findZoneByColor(colorType)
	if not zone then
		warn("ZoneSpawner: populate request failed; missing zone for " .. tostring(colorType))
		return
	end

	task.spawn(function()
		populateZone(zone)
	end)
end)

local function requestPopulateForColor(colorType)
	if not colorType or colorType == "" or not isSectorPlayable(colorType) then
		return
	end

	local zone = findZoneByColor(colorType)
	if zone then
		task.spawn(populateZone, zone)
	end
end

local function requestPopulateForPlayer(player)
	if not player or not player.Parent then
		return
	end

	local storage = player:FindFirstChild("ColorStorage")
	local currentWorld = storage and storage:FindFirstChild("CurrentWorld")
	local activeColor = player:GetAttribute("ActiveWorldColor") or (currentWorld and currentWorld.Value)
	requestPopulateForColor(activeColor)
end

task.wait(2)

if shouldClearGeneratedMapOnStart() then
	removeOldBreakables()
end

local foundZones = 0
local populationConfig = getZonePopulationConfig()
local populateAllOnStartup = populationConfig.PopulateAllZonesOnStartup == true
for _, obj in ipairs(workspace:GetDescendants()) do
	if obj:IsA("BasePart") and configureColorZonePart(obj) then
		foundZones = foundZones + 1
		local colorType = obj:GetAttribute("ColorType")
		if populateAllOnStartup or colorType == "Red" then
			populateZone(obj)
		end
	end
end

local function hookPlayer(player)
	task.delay(2, function()
		requestPopulateForPlayer(player)
	end)

	player:GetAttributeChangedSignal("ActiveWorldColor"):Connect(function()
		requestPopulateForPlayer(player)
	end)

	task.spawn(function()
		local storage = player:WaitForChild("ColorStorage", 20)
		local currentWorld = storage and storage:FindFirstChild("CurrentWorld")
		if currentWorld and currentWorld:IsA("StringValue") then
			currentWorld:GetPropertyChangedSignal("Value"):Connect(function()
				requestPopulateForPlayer(player)
			end)
			requestPopulateForPlayer(player)
		end
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	hookPlayer(player)
end

Players.PlayerAdded:Connect(hookPlayer)

workspace.DescendantAdded:Connect(function(obj)
	if obj:IsA("BasePart") and obj:GetAttribute("BreakableType") then
		if obj:GetAttribute("PaintPuddleVersion") ~= PUDDLE_VERSION then
			if not shouldClearGeneratedMapOnStart() then
				return
			end
			task.defer(function()
				if obj and obj.Parent and obj:GetAttribute("PaintPuddleVersion") ~= PUDDLE_VERSION then
					obj:Destroy()
				end
			end)
			return
		end
		watchObject(obj)
	end
end)

task.spawn(function()
	while true do
		task.wait(8)
		for _, player in ipairs(Players:GetPlayers()) do
			local activeColor = player:GetAttribute("ActiveWorldColor")
			local storage = player:FindFirstChild("ColorStorage")
			local currentWorld = storage and storage:FindFirstChild("CurrentWorld")
			activeColor = activeColor or (currentWorld and currentWorld.Value)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local zone = activeColor and activeColor ~= "Red" and findZoneByColor(activeColor) or nil
			if root then
				for _, obj in ipairs(workspace:GetDescendants()) do
					if obj:IsA("BasePart") then
						local zoneColor = configureColorZonePart(obj)
						if
							obj:GetAttribute("ColorZone") == true
							and zoneColor
							and zoneColor ~= "Red"
							and isPointInside(obj, root.Position, 12)
						then
							if not zone or getZoneScore(obj) > getZoneScore(zone) then
								zone = obj
							end
						end
					end
				end
			end
			if zone then
				local colorType = zone:GetAttribute("ColorType")
				if colorType and isSectorPlayable(colorType) then
					task.spawn(populateZone, zone)
				end
			elseif activeColor and activeColor ~= "Red" then
				zone = findZoneByColor(activeColor)
				if zone then
					task.spawn(populateZone, zone)
				end
			end
		end
	end
end)

if DEBUG_LOGS then
	print("ZoneSpawner ready! Found " .. foundZones .. " zones.")
end
