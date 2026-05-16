local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ColorData = require(ReplicatedStorage:WaitForChild("ColorData"))
local GameBalance = require(ReplicatedStorage:WaitForChild("GameBalance"))

local GroundPaintService = {}

local config = GameBalance.GroundPaint or {}
local regenConfig = config.Regen or {}
local brushConfig = config.Brush or {}
local petConfig = config.Pets or {}
local networkingConfig = config.Networking or {}
local visualConfig = config.Visual or {}
local debugConfig = config.Debug or {}

local STARTED = false
local SNAPSHOT_REMOTE_NAME = "PaintFieldSnapshot"
local DELTA_REMOTE_NAME = "PaintFieldDelta"
local SURFACE_FOLDER_NAME = "GroundPaintRuntime"

local CELL_SIZE = math.max(tonumber(config.CellSize) or 6, 2)
local MAX_CELLS_PER_SURFACE = math.max(1, tonumber(config.MaxLogicalCellsPerSurface) or 6500)
local MAX_CELLS_TOTAL = math.max(1, tonumber(config.MaxLogicalCellsTotal) or 50000)
local FULL_COVERAGE = tonumber(config.FullCoverage) or 1
local EMPTY_COVERAGE = tonumber(config.EmptyCoverage) or 0
local START_COVERAGE = math.clamp(tonumber(config.StartCoverage) or FULL_COVERAGE, EMPTY_COVERAGE, FULL_COVERAGE)
local SURFACE_INSET = math.max(tonumber(config.SurfaceInset) or 0, 0)
local REWARD_PER_COVERAGE_UNIT = math.max(tonumber(config.RewardPerCoverageUnit) or 10, 0)
local REGEN_ENABLED = regenConfig.Enabled ~= false
local REGEN_DELAY = math.max(tonumber(regenConfig.DelayAfterBrush) or 0.45, 0)
local REGEN_PER_SECOND = math.max(tonumber(regenConfig.CoveragePerSecond) or 0.22, 0)
local REGEN_TICK_HZ = math.max(tonumber(regenConfig.TickHz) or 8, 1)
local DELTA_HZ = math.max(tonumber(networkingConfig.DeltaHz) or 12, 1)
local MAX_DELTAS_PER_PACKET = math.max(tonumber(networkingConfig.MaxDeltasPerPacket) or 150, 1)
local SNAPSHOT_RADIUS = math.max(tonumber(networkingConfig.SnapshotRadius) or 420, 80)
local SEND_ONLY_NEARBY = networkingConfig.SendOnlyNearbyPlayers == true
local surfaceDiscoveryConfig = config.SurfaceDiscovery or {}

local DEFAULT_PREFERRED_SURFACE_NAMES = {
	"RedFloor1",
	"RedZoneFloor",
	"OrangeInteriorFloor",
	"OrangeSectorFloor",
	"GreenInteriorFloor",
	"GreenSectorFloor",
	"GreenZoneFloor",
}

local DEFAULT_BLOCKED_DISCOVERY_KEYWORDS = {
	"ceiling",
	"roof",
	"upper",
}

local snapshotRemote
local deltaRemote
local surfaces = {}
local surfacesById = {}
local surfaceByPart = {}
local nextSurfaceId = 0
local totalLogicalCells = 0
local pendingCellChanges = {}
local pendingStamps = {}
local regenAccumulator = 0
local deltaAccumulator = 0
local rewardWindows = {}

local getPaintSurfaceCandidateScore

local function getEventsFolder()
	local events = ReplicatedStorage:FindFirstChild("Events")
	if not events then
		events = Instance.new("Folder")
		events.Name = "Events"
		events.Parent = ReplicatedStorage
	end
	return events
end

local function ensureRemoteEvent(name)
	local events = getEventsFolder()
	local remote = events:FindFirstChild(name)
	if remote and not remote:IsA("RemoteEvent") then
		remote:Destroy()
		remote = nil
	end
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = events
	end
	return remote
end

local function ensureRemoteFunction(name)
	local events = getEventsFolder()
	local remote = events:FindFirstChild(name)
	if remote and not remote:IsA("RemoteFunction") then
		remote:Destroy()
		remote = nil
	end
	if not remote then
		remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = events
	end
	return remote
end

local function getSurfaceFolder()
	local folder = Workspace:FindFirstChild(SURFACE_FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = SURFACE_FOLDER_NAME
		folder.Parent = Workspace
	end
	return folder
end

local function getColorInfo(colorType)
	local info = colorType and ColorData.Colors[colorType]
	return info and info.color or Color3.fromRGB(235, 35, 32)
end

local function getZoneColorConfig(colorType, part)
	local zoneColors = config.ZoneColors or {}
	local keys = {}
	if part then
		local current = part
		while current and current ~= Workspace do
			table.insert(keys, tostring(current:GetAttribute("ZoneId") or ""))
			table.insert(keys, tostring(current:GetAttribute("WorldId") or ""))
			table.insert(keys, tostring(current:GetAttribute("AreaId") or ""))
			table.insert(keys, tostring(current.Name or ""))
			current = current.Parent
		end
	end
	table.insert(keys, tostring(colorType or ""))
	for _, key in ipairs(keys) do
		if key ~= "" and zoneColors[key] then
			return zoneColors[key]
		end
	end
	return nil
end

local function getPaintColor(colorType, part)
	local zoneConfig = getZoneColorConfig(colorType, part)
	if zoneConfig and typeof(zoneConfig.PaintColor) == "Color3" then
		return zoneConfig.PaintColor
	end
	return getColorInfo(colorType)
end

local function getBaseSurfaceColor(colorType, part)
	local zoneConfig = getZoneColorConfig(colorType, part)
	if zoneConfig and typeof(zoneConfig.BaseSurfaceColor) == "Color3" then
		return zoneConfig.BaseSurfaceColor
	end
	return visualConfig.BaseSurfaceColor or Color3.fromRGB(8, 8, 8)
end

local function getSurfaceColorAttribute(instance)
	if not instance then
		return nil
	end

	local attrColor = instance:GetAttribute("ColorType")
		or instance:GetAttribute("WorldColor")
		or instance:GetAttribute("AreaColor")
		or instance:GetAttribute("SectorColor")
		or instance:GetAttribute("SpawnColor")
	if type(attrColor) == "string" and ColorData.Colors[attrColor] then
		return attrColor
	end
	return nil
end

local function resolveSurfaceColor(part)
	local current = part
	while current and current ~= Workspace do
		local zoneConfig = getZoneColorConfig(nil, current)
		if zoneConfig and type(zoneConfig.ColorType) == "string" and ColorData.Colors[zoneConfig.ColorType] then
			return zoneConfig.ColorType
		end
		local attrColor = getSurfaceColorAttribute(current)
		if attrColor then
			return attrColor
		end
		current = current.Parent
	end

	current = part
	while current and current ~= Workspace do
		local loweredName = string.lower(current.Name or "")
		for _, world in ipairs(ColorData.Worlds or {}) do
			local colorType = world.primaryColor
			if colorType and loweredName:find(string.lower(colorType), 1, true) then
				return colorType
			end
			if world.ZoneId and loweredName:find(string.lower(world.ZoneId), 1, true) then
				return colorType
			end
		end
		current = current.Parent
	end

	return config.DefaultColorType or "Red"
end

local function hasSurfaceName(instance)
	local current = instance
	while current and current ~= Workspace do
		local name = string.lower(current.Name or "")
		if
			name:find("floor", 1, true)
			or name:find("ground", 1, true)
			or name:find("zone", 1, true)
			or name:find("area", 1, true)
			or name:find("sector", 1, true)
			or name:find("wasteland", 1, true)
			or name:find("field", 1, true)
			or name:find("grove", 1, true)
			or name:find("forest", 1, true)
		then
			return true
		end
		current = current.Parent
	end
	return false
end

local function hasBlockedSurfaceName(instance)
	local current = instance
	while current and current ~= Workspace do
		local name = string.lower(current.Name or "")
		if
			name:find("pipe", 1, true)
			or name:find("egg", 1, true)
			or name:find("shop", 1, true)
			or name:find("spawn", 1, true)
			or name:find("gate", 1, true)
			or name:find("portal", 1, true)
			or name:find("teleport", 1, true)
			or name == "core"
			or name == "glowshell"
			or name == "highlight"
			or name:find("floatcore", 1, true)
		then
			return true
		end
		current = current.Parent
	end
	return false
end

local function compactName(name)
	return string.lower(tostring(name or "")):gsub("[^%w]", "")
end

local function buildNameSet(values)
	local set = {}
	for _, value in ipairs(values or {}) do
		local key = compactName(value)
		if key ~= "" then
			set[key] = true
		end
	end
	return set
end

local preferredSurfaceNames = buildNameSet(surfaceDiscoveryConfig.PreferredNames or DEFAULT_PREFERRED_SURFACE_NAMES)
local blockedDiscoveryKeywords = surfaceDiscoveryConfig.BlockedKeywords or DEFAULT_BLOCKED_DISCOVERY_KEYWORDS

local function hasPreferredSurfaceName(part)
	local current = part
	while current and current ~= Workspace do
		if preferredSurfaceNames[compactName(current.Name)] == true then
			return true
		end
		current = current.Parent
	end
	return false
end

local function hasBlockedDiscoveryKeyword(part)
	local current = part
	while current and current ~= Workspace do
		local name = string.lower(current.Name or "")
		for _, keyword in ipairs(blockedDiscoveryKeywords) do
			local loweredKeyword = string.lower(tostring(keyword or ""))
			if loweredKeyword ~= "" and name:find(loweredKeyword, 1, true) then
				return true
			end
		end
		current = current.Parent
	end
	return false
end

local function hasDirectSurfaceName(part)
	local names = {
		string.lower(part.Name or ""),
		part.Parent and string.lower(part.Parent.Name or "") or "",
	}
	for _, name in ipairs(names) do
		if
			name:find("floor", 1, true)
			or name:find("ground", 1, true)
			or name:find("wasteland", 1, true)
			or name:find("field", 1, true)
			or name:find("grove", 1, true)
			or name:find("forest", 1, true)
		then
			return true
		end
	end
	return false
end

local function hasColorName(part)
	local current = part
	while current and current ~= Workspace do
		local name = string.lower(current.Name or "")
		for _, world in ipairs(ColorData.Worlds or {}) do
			local colorType = world.primaryColor
			local zoneId = world.ZoneId
			if colorType and name:find(string.lower(colorType), 1, true) then
				return true
			end
			if zoneId and name:find(string.lower(zoneId), 1, true) then
				return true
			end
		end
		current = current.Parent
	end
	return false
end

local function hasLargeFlatPaintGeometry(part, minArea, minSide)
	local horizontalArea = part.Size.X * part.Size.Z
	local smallestHorizontal = math.max(1, math.min(part.Size.X, part.Size.Z))
	return horizontalArea >= minArea
		and part.Size.X >= minSide
		and part.Size.Z >= minSide
		and part.Size.Y <= math.max(10, smallestHorizontal * 0.28)
end

local function isCommonPaintSurfaceBlocker(part)
	return part:GetAttribute("NoColorSpawn") == true
		or part:GetAttribute("NoContamination") == true
		or part:GetAttribute("DecorativeOnly") == true
		or part:GetAttribute("BreakableType") ~= nil
		or part:GetAttribute("GemDeposit") == true
		or part:GetAttribute("EggStation") == true
		or part:GetAttribute("ShopStation") == true
		or part:GetAttribute("GroundPaintIgnore") == true
		or part:IsA("SpawnLocation")
		or part:FindFirstAncestor("DynamicGameplay") ~= nil
		or hasBlockedSurfaceName(part)
end

local function looksLikeFallbackGroundSurface(part)
	if not part:IsA("BasePart") then
		return false
	end
	if isCommonPaintSurfaceBlocker(part) or hasBlockedDiscoveryKeyword(part) then
		return false
	end

	local horizontalArea = part.Size.X * part.Size.Z
	return horizontalArea >= 4000
		and part.Size.X >= 55
		and part.Size.Z >= 55
		and part.Size.Y <= math.max(12, math.min(part.Size.X, part.Size.Z) * 0.25)
end

getPaintSurfaceCandidateScore = function(part, allowFallback)
	if not part:IsA("BasePart") or isCommonPaintSurfaceBlocker(part) then
		return nil
	end
	if not hasLargeFlatPaintGeometry(part, 1400, 32) then
		return nil
	end

	local preferredName = hasPreferredSurfaceName(part)
	if preferredName then
		return 100000 + part.Size.X * part.Size.Z
	end

	if hasBlockedDiscoveryKeyword(part) then
		return nil
	end

	if part:GetAttribute("PlayableSectorFloor") == true then
		return 90000 + part.Size.X * part.Size.Z
	end
	if part:GetAttribute("ZoneFloor") == true then
		return 85000 + part.Size.X * part.Size.Z
	end
	if part:GetAttribute("ContaminationAllowed") == true then
		return 80000 + part.Size.X * part.Size.Z
	end

	-- Only trust GroundPaintSurface as an authored mark if this service has not
	-- already stamped a runtime id onto the part in the current Studio session.
	if part:GetAttribute("GroundPaintSurface") == true and part:GetAttribute("GroundPaintSurfaceId") == nil then
		return 75000 + part.Size.X * part.Size.Z
	end

	if allowFallback and part.CanCollide and hasDirectSurfaceName(part) and hasColorName(part) then
		return 60000 + part.Size.X * part.Size.Z
	end

	if allowFallback and part.CanCollide and looksLikeFallbackGroundSurface(part) and hasSurfaceName(part) then
		return part.Size.X * part.Size.Z
	end

	return nil
end

local function calculateGrid(part)
	local coverageX = math.max(CELL_SIZE, part.Size.X - SURFACE_INSET * 2)
	local coverageZ = math.max(CELL_SIZE, part.Size.Z - SURFACE_INSET * 2)
	local xCount = math.max(1, math.ceil(coverageX / CELL_SIZE))
	local zCount = math.max(1, math.ceil(coverageZ / CELL_SIZE))

	while xCount * zCount > MAX_CELLS_PER_SURFACE do
		if xCount >= zCount and xCount > 1 then
			xCount -= 1
		elseif zCount > 1 then
			zCount -= 1
		else
			break
		end
	end

	return coverageX, coverageZ, xCount, zCount
end

local function cleanupOldPhysicalPaint()
	if config.DisableOldGroundContaminationParts ~= false then
		local legacyFolder = Workspace:FindFirstChild("GroundContamination")
		if legacyFolder then
			for _, child in ipairs(legacyFolder:GetDescendants()) do
				if
					child:GetAttribute("GeneratedGroundContamination") == true
					or child:GetAttribute("GroundContamination") == true
					or child:GetAttribute("BreakableType") == "GroundContamination"
				then
					child:Destroy()
				end
			end
		end
	end

	if config.DisableOldZoneSpawnerColors ~= false then
		while true do
			local runtimeBlobs = Workspace:FindFirstChild("RuntimeColorBlobs", true)
			if not runtimeBlobs then
				break
			end
			runtimeBlobs:Destroy()
		end
	end
end

local function styleBaseFloor(part, colorType)
	local baseColor = getBaseSurfaceColor(colorType, part)
	if part:GetAttribute("GroundPaintOriginalColor") == nil then
		part:SetAttribute("GroundPaintOriginalColor", part.Color)
	end
	part.Color = baseColor
	part.Material = Enum.Material.SmoothPlastic
	part:SetAttribute("GroundPaintSurface", true)
	part:SetAttribute("ColorType", colorType)
	part:SetAttribute("PlayableSectorFloor", true)
end

local function getCellLocalPosition(surface, index)
	local zeroIndex = index - 1
	local x = zeroIndex % surface.XCount
	local z = math.floor(zeroIndex / surface.XCount)
	local localX = -surface.CoverageX * 0.5 + surface.CellSizeX * (x + 0.5) + surface.OffsetX
	local localZ = -surface.CoverageZ * 0.5 + surface.CellSizeZ * (z + 0.5) + surface.OffsetZ
	return localX, localZ
end

local function getCellWorldPosition(surface, index)
	local localX, localZ = getCellLocalPosition(surface, index)
	local topY = surface.Part.Size.Y * 0.5 + (tonumber(visualConfig.PaintYOffset) or 0.035)
	return (surface.Part.CFrame * CFrame.new(localX, topY, localZ)).Position
end

local function queueCellChange(surface, index)
	if not surface then
		return
	end
	local roundedCoverage = math.floor(
		math.clamp(surface.Coverage[index] or 0, EMPTY_COVERAGE, FULL_COVERAGE) * 1000 + 0.5
	) / 1000
	pendingCellChanges[surface.Id] = pendingCellChanges[surface.Id] or {}
	pendingCellChanges[surface.Id][index] = roundedCoverage
end

local function setCellCoverage(surface, index, coverage)
	coverage = math.clamp(coverage, EMPTY_COVERAGE, FULL_COVERAGE)
	local previous = surface.Coverage[index]
	if previous == nil or math.abs(previous - coverage) >= 0.003 then
		surface.Coverage[index] = coverage
		queueCellChange(surface, index)
	else
		surface.Coverage[index] = coverage
	end
end

local function buildSnapshotForSurface(surface)
	return {
		SurfaceId = surface.Id,
		Part = surface.Part,
		ColorType = surface.ColorType,
		PaintColor = surface.PaintColor,
		BaseSurfaceColor = surface.BaseSurfaceColor,
		CoverageX = surface.CoverageX,
		CoverageZ = surface.CoverageZ,
		XCount = surface.XCount,
		ZCount = surface.ZCount,
		CellSizeX = surface.CellSizeX,
		CellSizeZ = surface.CellSizeZ,
		OffsetX = surface.OffsetX,
		OffsetZ = surface.OffsetZ,
	}
end

local function logSelectedSurface(surface)
	if debugConfig.PrintSurfaceDiscovery ~= true and debugConfig.PrintClientVisuals ~= true then
		return
	end
	if not surface or not surface.Part then
		return
	end

	print(
		string.format(
			"GroundPaint surface[%s]: part=%s color=%s size=%s pos=%s transparency=%.2f canCollide=%s",
			surface.Id,
			surface.Part:GetFullName(),
			tostring(surface.ColorType),
			tostring(surface.Part.Size),
			tostring(surface.Part.Position),
			surface.Part.Transparency,
			tostring(surface.Part.CanCollide)
		)
	)
end

local function isSurfaceNearPlayer(surface, player)
	if not player or not surface or not surface.Part then
		return true
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return true
	end
	local localPoint = surface.Part.CFrame:PointToObjectSpace(root.Position)
	local dx = math.max(math.abs(localPoint.X - surface.OffsetX) - surface.CoverageX * 0.5, 0)
	local dz = math.max(math.abs(localPoint.Z - surface.OffsetZ) - surface.CoverageZ * 0.5, 0)
	return (dx * dx + dz * dz) <= SNAPSHOT_RADIUS * SNAPSHOT_RADIUS
end

local function buildSnapshot(player)
	local payload = {
		Type = "Snapshot",
		ServerTime = os.clock(),
		Surfaces = {},
	}

	for _, surface in ipairs(surfaces) do
		if surface.Part and surface.Part.Parent and isSurfaceNearPlayer(surface, player) then
			table.insert(payload.Surfaces, buildSnapshotForSurface(surface))
		end
	end

	return payload
end

local function fireSnapshotTo(player)
	if deltaRemote and player and player.Parent then
		deltaRemote:FireClient(player, buildSnapshot(player))
	end
end

local function buildSurface(part, force)
	if surfaceByPart[part] or getPaintSurfaceCandidateScore(part, force == true) == nil then
		return nil
	end

	local colorType = resolveSurfaceColor(part)
	if not colorType or not ColorData.Colors[colorType] then
		colorType = config.DefaultColorType or "Red"
	end

	local coverageX, coverageZ, xCount, zCount = calculateGrid(part)
	local totalCells = xCount * zCount
	if totalCells <= 0 or totalLogicalCells + totalCells > MAX_CELLS_TOTAL then
		return nil
	end

	nextSurfaceId += 1
	local id = "gp_" .. tostring(nextSurfaceId)
	local surface = {
		Id = id,
		Part = part,
		ColorType = colorType,
		PaintColor = getPaintColor(colorType, part),
		BaseSurfaceColor = getBaseSurfaceColor(colorType, part),
		CoverageX = coverageX,
		CoverageZ = coverageZ,
		XCount = xCount,
		ZCount = zCount,
		CellSizeX = coverageX / xCount,
		CellSizeZ = coverageZ / zCount,
		CellAreaScale = ((coverageX / xCount) * (coverageZ / zCount)) / (CELL_SIZE * CELL_SIZE),
		OffsetX = tonumber(part:GetAttribute("GroundPaintOffsetX")) or 0,
		OffsetZ = tonumber(part:GetAttribute("GroundPaintOffsetZ")) or 0,
		Coverage = table.create(totalCells, START_COVERAGE),
		LastBrushAt = table.create(totalCells, -math.huge),
		TotalCells = totalCells,
	}

	styleBaseFloor(part, colorType)
	part:SetAttribute("GroundPaintSurfaceId", id)

	table.insert(surfaces, surface)
	surfacesById[id] = surface
	surfaceByPart[part] = surface
	totalLogicalCells += totalCells

	logSelectedSurface(surface)

	return surface
end

local function collectSurfaceCandidates(allowFallback)
	local candidates = {}
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("BasePart") and not surfaceByPart[obj] then
			local score = getPaintSurfaceCandidateScore(obj, allowFallback)
			if score then
				table.insert(candidates, {
					Part = obj,
					Score = score,
					Path = obj:GetFullName(),
				})
			end
		end
	end

	table.sort(candidates, function(a, b)
		if a.Score ~= b.Score then
			return a.Score > b.Score
		end
		return a.Path < b.Path
	end)

	return candidates
end

local function buildSurfacesFromCandidates(candidates, limit)
	for _, candidate in ipairs(candidates) do
		if totalLogicalCells >= MAX_CELLS_TOTAL then
			break
		end
		buildSurface(candidate.Part, true)
		if limit and #surfaces >= limit then
			break
		end
	end
end

local function buildFallbackSurfaces()
	buildSurfacesFromCandidates(collectSurfaceCandidates(true), 6)
end

local function buildAllSurfaces()
	cleanupOldPhysicalPaint()
	table.clear(surfaces)
	table.clear(surfacesById)
	table.clear(surfaceByPart)
	table.clear(pendingCellChanges)
	table.clear(pendingStamps)
	totalLogicalCells = 0
	nextSurfaceId = 0

	for _, child in ipairs(getSurfaceFolder():GetChildren()) do
		child:Destroy()
	end

	buildSurfacesFromCandidates(collectSurfaceCandidates(false))

	if #surfaces == 0 then
		buildFallbackSurfaces()
	end
end

local function isPointOnSurface(surface, worldPosition, extraMargin)
	local localPoint = surface.Part.CFrame:PointToObjectSpace(worldPosition)
	local halfX = surface.CoverageX * 0.5 + (extraMargin or 0)
	local halfZ = surface.CoverageZ * 0.5 + (extraMargin or 0)
	return math.abs(localPoint.X - surface.OffsetX) <= halfX and math.abs(localPoint.Z - surface.OffsetZ) <= halfZ
end

local function findSurfaceAtPosition(worldPosition)
	local bestSurface = nil
	local bestYDistance = math.huge
	for _, surface in ipairs(surfaces) do
		if surface.Part and surface.Part.Parent and isPointOnSurface(surface, worldPosition, 4) then
			local localPoint = surface.Part.CFrame:PointToObjectSpace(worldPosition)
			local topY = surface.Part.Size.Y * 0.5
			local yDistance = math.abs(localPoint.Y - topY)
			if yDistance < bestYDistance then
				bestSurface = surface
				bestYDistance = yDistance
			end
		end
	end
	return bestSurface
end

local function canPlayerAccessSurface(player, surface)
	if not surface or not surface.ColorType then
		return true
	end
	local storage = player and player:FindFirstChild("ColorStorage")
	local unlocked = storage and storage:FindFirstChild("UnlockedColors")
	if unlocked and ColorData.isColorUnlocked(unlocked.Value, surface.ColorType) then
		return true
	end
	return unlocked == nil
end

local function clampRewardForPlayer(player, amount)
	local maxPerSweep = math.max(tonumber(brushConfig.MaxRewardPerSweep) or 250, 1)
	amount = math.min(amount, maxPerSweep)

	local maxPerSecond = tonumber(brushConfig.MaxRewardPerSecond)
	if not player or not maxPerSecond or maxPerSecond <= 0 then
		return amount
	end

	local now = os.clock()
	local window = rewardWindows[player]
	if not window or now - window.StartedAt >= 1 then
		window = {
			StartedAt = now,
			Used = 0,
		}
		rewardWindows[player] = window
	end

	local remaining = math.max(0, maxPerSecond - window.Used)
	local clamped = math.min(amount, remaining)
	window.Used += clamped
	return clamped
end

local function queueStamp(surface, worldPosition, radius, power, source)
	table.insert(pendingStamps, {
		SurfaceId = surface.Id,
		Position = worldPosition,
		Radius = radius,
		Power = power,
		ColorType = surface.ColorType,
		PaintColor = surface.PaintColor,
		BaseSurfaceColor = surface.BaseSurfaceColor,
		Source = source or "brush",
		Softness = tonumber((visualConfig.BrushStamp or {}).Softness) or 0.65,
	})
end

local function getCellBounds(surface, localPoint, radius)
	local minLocalX = localPoint.X - radius - surface.OffsetX
	local maxLocalX = localPoint.X + radius - surface.OffsetX
	local minLocalZ = localPoint.Z - radius - surface.OffsetZ
	local maxLocalZ = localPoint.Z + radius - surface.OffsetZ

	local minX =
		math.clamp(math.floor((minLocalX + surface.CoverageX * 0.5) / surface.CellSizeX) + 1, 1, surface.XCount)
	local maxX =
		math.clamp(math.floor((maxLocalX + surface.CoverageX * 0.5) / surface.CellSizeX) + 1, 1, surface.XCount)
	local minZ =
		math.clamp(math.floor((minLocalZ + surface.CoverageZ * 0.5) / surface.CellSizeZ) + 1, 1, surface.ZCount)
	local maxZ =
		math.clamp(math.floor((maxLocalZ + surface.CoverageZ * 0.5) / surface.CellSizeZ) + 1, 1, surface.ZCount)

	return minX, maxX, minZ, maxZ
end

local function brushSurface(surface, worldPosition, radius, power, sourcePlayer, source)
	if not surface or not surface.Part or not surface.Part.Parent then
		return nil
	end
	if sourcePlayer and not canPlayerAccessSurface(sourcePlayer, surface) then
		return nil
	end

	radius =
		math.clamp(tonumber(radius) or tonumber(brushConfig.BaseRadius) or 7, 1, tonumber(brushConfig.MaxRadius) or 42)
	power = math.clamp(tonumber(power) or tonumber(brushConfig.BasePower) or 0.28, 0.01, 1.5)

	local now = os.clock()
	local localPoint = surface.Part.CFrame:PointToObjectSpace(worldPosition)
	local radiusSq = radius * radius
	local softEdgeMultiplier = math.max(tonumber(brushConfig.SoftEdgeMultiplier) or 1.35, 0.2)
	local minX, maxX, minZ, maxZ = getCellBounds(surface, localPoint, radius * softEdgeMultiplier)
	local removedCoverageUnits = 0
	local cellsChanged = 0
	local positions = {}

	for z = minZ, maxZ do
		for x = minX, maxX do
			local index = (z - 1) * surface.XCount + x
			local coverage = surface.Coverage[index] or START_COVERAGE
			if coverage > EMPTY_COVERAGE + 0.001 then
				local localX, localZ = getCellLocalPosition(surface, index)
				local dx = localX - localPoint.X
				local dz = localZ - localPoint.Z
				local distSq = dx * dx + dz * dz
				if distSq <= radiusSq * softEdgeMultiplier * softEdgeMultiplier then
					local distance = math.sqrt(distSq)
					local normalized = distance / math.max(radius * softEdgeMultiplier, 0.001)
					local falloff = math.clamp(1 - normalized, 0, 1)
					falloff = math.clamp(falloff ^ 0.55, 0.12, 1)
					local amount = math.min(coverage - EMPTY_COVERAGE, power * falloff)
					if amount > 0.001 then
						setCellCoverage(surface, index, coverage - amount)
						surface.LastBrushAt[index] = now
						removedCoverageUnits += amount * surface.CellAreaScale
						cellsChanged += 1
						if #positions < 8 then
							table.insert(positions, getCellWorldPosition(surface, index))
						end
					end
				end
			end
		end
	end

	if removedCoverageUnits <= 0 then
		return nil
	end

	local rewardUnits = removedCoverageUnits * REWARD_PER_COVERAGE_UNIT
	rewardUnits = clampRewardForPlayer(sourcePlayer, rewardUnits)
	queueStamp(surface, worldPosition, radius, power, source)

	return {
		SurfaceId = surface.Id,
		ColorType = surface.ColorType,
		Position = worldPosition,
		Units = removedCoverageUnits,
		CellsChanged = cellsChanged,
		RewardUnits = rewardUnits,
		Positions = positions,
	}
end

function GroundPaintService.Brush(player, worldPosition, radius, power)
	if config.Enabled == false or typeof(worldPosition) ~= "Vector3" then
		return nil
	end

	local surface = findSurfaceAtPosition(worldPosition)
	if not surface then
		if debugConfig.PrintSweepRejects == true then
			warn("GroundPaintService: brush missed paint surface.")
		end
		return nil
	end
	return brushSurface(surface, worldPosition, radius, power, player, "brush")
end

function GroundPaintService.CollectNearestPaint(player, origin, range, radius, power)
	if config.Enabled == false or petConfig.Enabled == false or typeof(origin) ~= "Vector3" then
		return nil
	end

	range = math.max(tonumber(range) or tonumber(petConfig.TargetSearchRadius) or 45, 1)
	local coverageThreshold = math.clamp(tonumber(petConfig.CoverageThreshold) or 0.18, 0, 1)
	local bestSurface = nil
	local bestIndex = nil
	local bestDistanceSq = range * range

	for _, surface in ipairs(surfaces) do
		if surface.Part and surface.Part.Parent and canPlayerAccessSurface(player, surface) then
			local localOrigin = surface.Part.CFrame:PointToObjectSpace(origin)
			if
				math.abs(localOrigin.X - surface.OffsetX) <= surface.CoverageX * 0.5 + range
				and math.abs(localOrigin.Z - surface.OffsetZ) <= surface.CoverageZ * 0.5 + range
			then
				local minX, maxX, minZ, maxZ = getCellBounds(surface, localOrigin, range)
				for z = minZ, maxZ do
					for x = minX, maxX do
						local index = (z - 1) * surface.XCount + x
						if (surface.Coverage[index] or 0) > coverageThreshold then
							local localX, localZ = getCellLocalPosition(surface, index)
							local dx = localX - localOrigin.X
							local dz = localZ - localOrigin.Z
							local distSq = dx * dx + dz * dz
							if distSq < bestDistanceSq then
								bestSurface = surface
								bestIndex = index
								bestDistanceSq = distSq
							end
						end
					end
				end
			end
		end
	end

	if not bestSurface or not bestIndex then
		return nil
	end

	return brushSurface(bestSurface, getCellWorldPosition(bestSurface, bestIndex), radius, power, player, "pet")
end

function GroundPaintService.GetPaintRewardUnits(result)
	return result and math.max(0, tonumber(result.RewardUnits) or tonumber(result.Units) or 0) or 0
end

local function regenStep(dt)
	if not REGEN_ENABLED or REGEN_PER_SECOND <= 0 then
		return
	end

	local now = os.clock()
	for _, surface in ipairs(surfaces) do
		if surface.Part and surface.Part.Parent then
			for index = 1, surface.TotalCells do
				local coverage = surface.Coverage[index] or START_COVERAGE
				if
					coverage < FULL_COVERAGE - 0.001
					and now - (surface.LastBrushAt[index] or -math.huge) >= REGEN_DELAY
				then
					setCellCoverage(surface, index, math.min(FULL_COVERAGE, coverage + REGEN_PER_SECOND * dt))
				end
			end
		end
	end
end

local function isStampNearPlayer(stamp, player)
	if not SEND_ONLY_NEARBY then
		return true
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return true
	end
	return (root.Position - stamp.Position).Magnitude <= SNAPSHOT_RADIUS
end

local function buildLogicalUpdates()
	local updates = {}
	local sent = 0
	for surfaceId, map in pairs(pendingCellChanges) do
		local changes = {}
		for index, coverage in pairs(map) do
			table.insert(changes, { index, coverage })
			sent += 1
			map[index] = nil
			if sent >= MAX_DELTAS_PER_PACKET then
				break
			end
		end
		if #changes > 0 then
			table.insert(updates, {
				SurfaceId = surfaceId,
				Changes = changes,
			})
		end
		if next(map) == nil then
			pendingCellChanges[surfaceId] = nil
		end
		if sent >= MAX_DELTAS_PER_PACKET then
			break
		end
	end
	return updates
end

local function flushClientChanges()
	if next(pendingCellChanges) == nil and #pendingStamps == 0 then
		return
	end

	local logicalUpdates = buildLogicalUpdates()
	local stamps = pendingStamps
	pendingStamps = {}

	for _, player in ipairs(Players:GetPlayers()) do
		local visibleStamps = {}
		for _, stamp in ipairs(stamps) do
			if isStampNearPlayer(stamp, player) then
				table.insert(visibleStamps, stamp)
			end
		end
		if #visibleStamps > 0 or #logicalUpdates > 0 then
			deltaRemote:FireClient(player, {
				Type = "Delta",
				Surfaces = logicalUpdates,
				Stamps = visibleStamps,
				ServerTime = os.clock(),
			})
		end
	end
end

function GroundPaintService.Start()
	if STARTED or config.Enabled == false then
		return
	end
	STARTED = true
	snapshotRemote = ensureRemoteFunction(SNAPSHOT_REMOTE_NAME)
	deltaRemote = ensureRemoteEvent(DELTA_REMOTE_NAME)
	getSurfaceFolder()

	snapshotRemote.OnServerInvoke = function(player)
		return buildSnapshot(player)
	end

	task.defer(function()
		task.wait(0.75)
		buildAllSurfaces()
		if #surfaces == 0 then
			warn("GroundPaintService failed: surfaces=0 logicalCells=0; no paintable surfaces discovered.")
		elseif debugConfig.PrintBoot ~= false then
			print(string.format("GroundPaintService ready: surfaces=%d logicalCells=%d", #surfaces, totalLogicalCells))
		end
		for _, player in ipairs(Players:GetPlayers()) do
			fireSnapshotTo(player)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		task.defer(function()
			task.wait(1.5)
			fireSnapshotTo(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		rewardWindows[player] = nil
	end)

	Workspace.DescendantAdded:Connect(function(obj)
		if obj:IsA("BasePart") then
			task.defer(function()
				task.wait(0.15)
				local surface = buildSurface(obj)
				if surface and deltaRemote then
					deltaRemote:FireAllClients({
						Type = "SurfaceAdded",
						Surfaces = { buildSnapshotForSurface(surface) },
					})
				end
			end)
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		regenAccumulator += dt
		deltaAccumulator += dt

		local regenStepTime = 1 / REGEN_TICK_HZ
		while regenAccumulator >= regenStepTime do
			regenAccumulator -= regenStepTime
			regenStep(regenStepTime)
		end

		if deltaAccumulator >= 1 / DELTA_HZ then
			deltaAccumulator = 0
			flushClientChanges()
		end
	end)
end

return GroundPaintService
