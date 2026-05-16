local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ColorData = require(ReplicatedStorage:WaitForChild("ColorData"))
local GameBalance = require(ReplicatedStorage:WaitForChild("GameBalance"))

local GroundPaintService = {}

local config = GameBalance.GroundPaint or {}
local STARTED = false
local SURFACE_FOLDER_NAME = "GroundPaintRuntime"
local UPDATE_REMOTE_NAME = "GroundPaintUpdate"

local CELL_SIZE = tonumber(config.CellSize) or 10
local MAX_CELLS_PER_SURFACE = tonumber(config.MaxCellsPerSurface) or 1800
local FULL_COVERAGE = tonumber(config.FullCoverage) or 1
local EMPTY_COVERAGE = tonumber(config.EmptyCoverage) or 0
local START_COVERAGE = math.clamp(tonumber(config.StartCoverage) or FULL_COVERAGE, EMPTY_COVERAGE, FULL_COVERAGE)
local REGEN_PER_SECOND = tonumber(config.RegenPerSecond) or 0.18
local REGEN_DELAY = tonumber(config.RegenDelayAfterBrush) or 0.35
local SERVER_DELTA_HZ = math.max(tonumber(config.ServerDeltaHz) or 10, 1)
local CLIENT_SEND_HZ = math.max(tonumber(config.ClientSendHz) or 12, 1)
local REWARD_PER_UNIT = tonumber(config.RewardPerCoverageUnit) or 1
local SURFACE_INSET = math.max(tonumber(config.SurfaceInset) or 0, 0)
local VISUAL_HEIGHT_OFFSET = tonumber(config.VisualHeightOffset) or 0.08
local DEBUG_LOGS = config.Debug == true

local paintUpdateEvent
local surfaces = {}
local surfacesById = {}
local surfaceByPart = {}
local pendingClientChanges = {}
local nextSurfaceId = 0
local regenAccumulator = 0
local sendAccumulator = 0

local function getEventsFolder()
	local events = ReplicatedStorage:FindFirstChild("Events")
	if not events then
		events = Instance.new("Folder")
		events.Name = "Events"
		events.Parent = ReplicatedStorage
	end
	return events
end

local function getUpdateRemote()
	if paintUpdateEvent and paintUpdateEvent.Parent then
		return paintUpdateEvent
	end

	local events = getEventsFolder()
	paintUpdateEvent = events:FindFirstChild(UPDATE_REMOTE_NAME)
	if not paintUpdateEvent then
		paintUpdateEvent = Instance.new("RemoteEvent")
		paintUpdateEvent.Name = UPDATE_REMOTE_NAME
		paintUpdateEvent.Parent = events
	end
	return paintUpdateEvent
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
	return info and info.color or Color3.fromRGB(220, 50, 50)
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
		end
		for colorType in pairs(ColorData.Colors or {}) do
			if loweredName:find(string.lower(colorType), 1, true) then
				return colorType
			end
		end
		current = current.Parent
	end

	return nil
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

local function looksLikeGroundSurface(part)
	if not part:IsA("BasePart") then
		return false
	end
	if
		part:GetAttribute("NoColorSpawn") == true
		or part:GetAttribute("NoContamination") == true
		or part:GetAttribute("DecorativeOnly") == true
		or part:GetAttribute("BreakableType") ~= nil
		or part:GetAttribute("GemDeposit") == true
		or part:GetAttribute("EggStation") == true
		or part:GetAttribute("ShopStation") == true
		or part:IsA("SpawnLocation")
		or hasBlockedSurfaceName(part)
	then
		return false
	end

	local colorType = resolveSurfaceColor(part)
	if not colorType then
		return false
	end
	if GameBalance.GroundPaint and GameBalance.GroundPaint.AllowColors then
		if GameBalance.GroundPaint.AllowColors[colorType] == false then
			return false
		end
	end

	local horizontalArea = part.Size.X * part.Size.Z
	local largeFlatSurface = horizontalArea >= 1600
		and part.Size.X >= 35
		and part.Size.Z >= 35
		and part.Size.Y <= math.max(8, math.min(part.Size.X, part.Size.Z) * 0.3)
	return largeFlatSurface
		and (
			part:GetAttribute("PlayableSectorFloor") == true
			or part:GetAttribute("ColorZone") == true
			or part:GetAttribute("ZoneFloor") == true
			or hasSurfaceName(part)
		)
end

local function calculateGrid(part)
	local coverageX = math.max(8, part.Size.X - SURFACE_INSET * 2)
	local coverageZ = math.max(8, part.Size.Z - SURFACE_INSET * 2)
	local xCount = math.max(1, math.floor(coverageX / CELL_SIZE + 0.5))
	local zCount = math.max(1, math.floor(coverageZ / CELL_SIZE + 0.5))

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

local function markCellDirty(surface, index, coverage)
	local roundedCoverage = math.floor(math.clamp(coverage, EMPTY_COVERAGE, FULL_COVERAGE) * 1000 + 0.5) / 1000
	pendingClientChanges[surface.Id] = pendingClientChanges[surface.Id] or {}
	pendingClientChanges[surface.Id][index] = roundedCoverage
end

local function setCellCoverage(surface, index, coverage)
	coverage = math.clamp(coverage, EMPTY_COVERAGE, FULL_COVERAGE)
	local previous = surface.Coverage[index]
	if not previous or math.abs(previous - coverage) >= 0.003 then
		surface.Coverage[index] = coverage
		markCellDirty(surface, index, coverage)
	else
		surface.Coverage[index] = coverage
	end
end

local function styleBaseFloor(part, colorType)
	if part:GetAttribute("GroundPaintOriginalColor") == nil then
		part:SetAttribute("GroundPaintOriginalColor", part.Color)
	end
	part.Color = Color3.fromRGB(5, 5, 5)

	part.Material = Enum.Material.SmoothPlastic

	part:SetAttribute("GroundPaintSurface", true)
	part:SetAttribute("ColorType", colorType)
	part:SetAttribute("PlayableSectorFloor", true)
end

local function buildSurface(part)
	if surfaceByPart[part] or not looksLikeGroundSurface(part) then
		return nil
	end

	local colorType = resolveSurfaceColor(part)
	if not colorType then
		return nil
	end

	local coverageX, coverageZ, xCount, zCount = calculateGrid(part)
	local totalCells = xCount * zCount
	if totalCells <= 0 then
		return nil
	end

	nextSurfaceId += 1
	local id = "gp_" .. tostring(nextSurfaceId)
	local surface = {
		Id = id,
		Part = part,
		ColorType = colorType,
		Color = getColorInfo(colorType),
		CoverageX = coverageX,
		CoverageZ = coverageZ,
		XCount = xCount,
		ZCount = zCount,
		CellSizeX = coverageX / xCount,
		CellSizeZ = coverageZ / zCount,
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
	getSurfaceFolder()

	if DEBUG_LOGS then
		print(
			string.format(
				"GroundPaint: built %s surface %s with %d cells.",
				tostring(colorType),
				part:GetFullName(),
				totalCells
			)
		)
	end

	return surface
end

local function buildSnapshotForSurface(surface)
	return {
		SurfaceId = surface.Id,
		Part = surface.Part,
		ColorType = surface.ColorType,
		Color = surface.Color,
		CoverageX = surface.CoverageX,
		CoverageZ = surface.CoverageZ,
		XCount = surface.XCount,
		ZCount = surface.ZCount,
		CellSizeX = surface.CellSizeX,
		CellSizeZ = surface.CellSizeZ,
		OffsetX = surface.OffsetX,
		OffsetZ = surface.OffsetZ,
		VisualHeightOffset = VISUAL_HEIGHT_OFFSET,
		FullPaintTransparency = tonumber(config.FullPaintTransparency) or 0.12,
		ClearedTransparency = tonumber(config.ClearedTransparency) or 1,
		Coverage = surface.Coverage,
	}
end

local function sendSnapshot(player)
	local payload = {
		Type = "Snapshot",
		MaxVisibleCells = tonumber(config.MaxVisibleCellsPerClient) or 2500,
		Surfaces = {},
	}

	for _, surface in ipairs(surfaces) do
		if surface.Part and surface.Part.Parent then
			table.insert(payload.Surfaces, buildSnapshotForSurface(surface))
		end
	end

	getUpdateRemote():FireClient(player, payload)
end

local function flushClientChanges()
	if next(pendingClientChanges) == nil then
		return
	end

	local updates = {}
	for surfaceId, map in pairs(pendingClientChanges) do
		local changes = {}
		for index, coverage in pairs(map) do
			table.insert(changes, { index, coverage })
		end
		if #changes > 0 then
			table.insert(updates, {
				SurfaceId = surfaceId,
				Changes = changes,
			})
		end
	end

	table.clear(pendingClientChanges)
	if #updates > 0 then
		getUpdateRemote():FireAllClients({
			Type = "Delta",
			Surfaces = updates,
		})
	end
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
	local topY = surface.Part.Size.Y * 0.5 + VISUAL_HEIGHT_OFFSET
	return (surface.Part.CFrame * CFrame.new(localX, topY, localZ)).Position
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

local function brushSurface(surface, worldPosition, radius, power, sourcePlayer)
	if not surface or not surface.Part or not surface.Part.Parent then
		return nil
	end
	if sourcePlayer and not canPlayerAccessSurface(sourcePlayer, surface) then
		return nil
	end

	radius = math.max(tonumber(radius) or tonumber(config.BaseBrushRadius) or 5.5, 1)
	power = math.max(tonumber(power) or tonumber(config.BaseBrushPower) or 0.24, 0.01)

	local now = os.clock()
	local localPoint = surface.Part.CFrame:PointToObjectSpace(worldPosition)
	local radiusSq = radius * radius
	local removed = 0
	local cellsChanged = 0
	local positions = {}

	for index = 1, surface.TotalCells do
		local coverage = surface.Coverage[index] or START_COVERAGE
		if coverage > EMPTY_COVERAGE + 0.001 then
			local localX, localZ = getCellLocalPosition(surface, index)
			local dx = localX - localPoint.X
			local dz = localZ - localPoint.Z
			local distSq = dx * dx + dz * dz
			if distSq <= radiusSq then
				local distance = math.sqrt(distSq)
				local falloff = math.clamp(1 - (distance / math.max(radius, 0.01)) * 0.55, 0.2, 1)
				local amount = math.min(coverage - EMPTY_COVERAGE, power * falloff)
				if amount > 0.001 then
					setCellCoverage(surface, index, coverage - amount)
					surface.LastBrushAt[index] = now
					removed += amount
					cellsChanged += 1
					if #positions < 8 then
						table.insert(positions, getCellWorldPosition(surface, index))
					end
				end
			end
		end
	end

	if removed <= 0 then
		return nil
	end

	return {
		SurfaceId = surface.Id,
		ColorType = surface.ColorType,
		Position = worldPosition,
		Units = removed,
		CellsChanged = cellsChanged,
		RewardUnits = removed * REWARD_PER_UNIT,
		Positions = positions,
	}
end

function GroundPaintService.Brush(player, worldPosition, radius, power)
	if config.Enabled == false or typeof(worldPosition) ~= "Vector3" then
		return nil
	end

	local surface = findSurfaceAtPosition(worldPosition)
	if not surface then
		return nil
	end
	return brushSurface(surface, worldPosition, radius, power, player)
end

function GroundPaintService.CollectNearestPaint(player, origin, range, radius, power)
	if config.Enabled == false or typeof(origin) ~= "Vector3" then
		return nil
	end

	range = math.max(tonumber(range) or 16, 1)
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
				for index = 1, surface.TotalCells do
					if (surface.Coverage[index] or 0) > EMPTY_COVERAGE + 0.04 then
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

	if not bestSurface or not bestIndex then
		return nil
	end

	return brushSurface(bestSurface, getCellWorldPosition(bestSurface, bestIndex), radius, power, player)
end

function GroundPaintService.GetPaintRewardUnits(result)
	return result and math.max(0, tonumber(result.RewardUnits) or tonumber(result.Units) or 0) or 0
end

local function regenStep(dt)
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

local function buildAllSurfaces()
	local legacyFolder = Workspace:FindFirstChild("GroundContamination")
	if legacyFolder then
		for _, child in ipairs(legacyFolder:GetChildren()) do
			if
				child:GetAttribute("GeneratedGroundContamination") == true
				or child:GetAttribute("GroundContamination") == true
			then
				child:Destroy()
			end
		end
	end
	local legacyRuntime = Workspace:FindFirstChild("RuntimeColorBlobs", true)
	if legacyRuntime then
		legacyRuntime:Destroy()
	end

	for _, child in ipairs(getSurfaceFolder():GetChildren()) do
		child:Destroy()
	end

	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("BasePart") then
			buildSurface(obj)
		end
	end
end

function GroundPaintService.Start()
	if STARTED or config.Enabled == false then
		return
	end
	STARTED = true
	getUpdateRemote()
	getSurfaceFolder()

	task.defer(function()
		task.wait(1)
		buildAllSurfaces()
		for _, player in ipairs(Players:GetPlayers()) do
			sendSnapshot(player)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		task.defer(function()
			task.wait(2)
			sendSnapshot(player)
		end)
	end)

	Workspace.DescendantAdded:Connect(function(obj)
		if obj:IsA("BasePart") then
			task.defer(function()
				task.wait(0.1)
				local surface = buildSurface(obj)
				if surface then
					getUpdateRemote():FireAllClients({
						Type = "SurfaceAdded",
						Surfaces = { buildSnapshotForSurface(surface) },
					})
				end
			end)
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		regenAccumulator += dt
		sendAccumulator += dt

		local regenStepTime = 1 / SERVER_DELTA_HZ
		while regenAccumulator >= regenStepTime do
			regenAccumulator -= regenStepTime
			regenStep(regenStepTime)
		end

		if sendAccumulator >= 1 / CLIENT_SEND_HZ then
			sendAccumulator = 0
			flushClientChanges()
		end
	end)
end

return GroundPaintService
