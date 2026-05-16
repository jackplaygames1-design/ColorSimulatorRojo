-- Client-only visual coat for server-owned ground paint data.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GameBalance = require(ReplicatedStorage:WaitForChild("GameBalance"))

local config = GameBalance.GroundPaint or {}
if config.Enabled == false then
	return
end

local player = Players.LocalPlayer
local Events = ReplicatedStorage:WaitForChild("Events")
local paintUpdateEvent = Events:WaitForChild("GroundPaintUpdate")

local folder = Workspace:FindFirstChild("ClientGroundPaint")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "ClientGroundPaint"
	folder.Parent = Workspace
end

local maxVisibleCells = tonumber(config.MaxVisibleCellsPerClient) or 2500
local surfaces = {}
local totalVisibleCells = 0
local lastRefreshAt = 0
local lastVisibilityRefreshAt = 0

local function getTransparency(coverage, surface)
	local fullTransparency = tonumber(surface.FullPaintTransparency) or tonumber(config.FullPaintTransparency) or 0.12
	local clearedTransparency = tonumber(surface.ClearedTransparency) or tonumber(config.ClearedTransparency) or 1
	return clearedTransparency + (fullTransparency - clearedTransparency) * math.clamp(coverage or 0, 0, 1)
end

local function getCellLocalPosition(surface, index)
	local zeroIndex = index - 1
	local x = zeroIndex % surface.XCount
	local z = math.floor(zeroIndex / surface.XCount)
	local localX = -surface.CoverageX * 0.5 + surface.CellSizeX * (x + 0.5) + surface.OffsetX
	local localZ = -surface.CoverageZ * 0.5 + surface.CellSizeZ * (z + 0.5) + surface.OffsetZ
	return localX, localZ
end

local function refreshCellCFrame(surface, index)
	local part = surface.Cells[index]
	local basePart = surface.Part
	if not part or not basePart or not basePart.Parent then
		return
	end

	local localX, localZ = getCellLocalPosition(surface, index)
	local topY = basePart.Size.Y * 0.5 + surface.VisualHeightOffset
	part.CFrame = basePart.CFrame * CFrame.new(localX, topY, localZ)
end

local function destroySurface(surface)
	if not surface then
		return
	end
	for _, part in pairs(surface.Cells or {}) do
		if part then
			part:Destroy()
		end
	end
	if surface.Folder then
		surface.Folder:Destroy()
	end
end

local function makeCell(surface, index, coverage)
	local basePart = surface.Part
	if not basePart or not basePart.Parent then
		return nil
	end

	local part = Instance.new("Part")
	part.Name = string.format("%s_Cell_%04d", tostring(surface.ColorType), index)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = surface.Color
	part.Transparency = getTransparency(coverage, surface)
	part.Size = Vector3.new(math.max(surface.CellSizeX * 0.98, 0.5), 0.035, math.max(surface.CellSizeZ * 0.98, 0.5))
	part.Parent = surface.Folder

	surface.Cells[index] = part
	refreshCellCFrame(surface, index)
	totalVisibleCells += 1
	return part
end

local function removeCell(surface, index)
	local part = surface.Cells[index]
	if part then
		part:Destroy()
		surface.Cells[index] = nil
		surface.VisibleCount = math.max((surface.VisibleCount or 1) - 1, 0)
		totalVisibleCells = math.max(totalVisibleCells - 1, 0)
	end
end

local function clearSurfaceCells(surface)
	for index in pairs(surface.Cells or {}) do
		removeCell(surface, index)
	end
end

local function upsertSurface(data)
	if type(data) ~= "table" or typeof(data.Part) ~= "Instance" or not data.Part:IsA("BasePart") then
		return
	end

	local oldSurface = surfaces[data.SurfaceId]
	if oldSurface then
		totalVisibleCells -= oldSurface.VisibleCount or 0
		destroySurface(oldSurface)
	end

	local surfaceFolder = Instance.new("Folder")
	surfaceFolder.Name = tostring(data.SurfaceId)
	surfaceFolder.Parent = folder

	local surface = {
		SurfaceId = data.SurfaceId,
		Part = data.Part,
		ColorType = data.ColorType,
		Color = typeof(data.Color) == "Color3" and data.Color or Color3.fromRGB(220, 50, 50),
		CoverageX = tonumber(data.CoverageX) or data.Part.Size.X,
		CoverageZ = tonumber(data.CoverageZ) or data.Part.Size.Z,
		XCount = math.max(1, math.floor(tonumber(data.XCount) or 1)),
		ZCount = math.max(1, math.floor(tonumber(data.ZCount) or 1)),
		CellSizeX = tonumber(data.CellSizeX) or tonumber(config.CellSize) or 10,
		CellSizeZ = tonumber(data.CellSizeZ) or tonumber(config.CellSize) or 10,
		OffsetX = tonumber(data.OffsetX) or 0,
		OffsetZ = tonumber(data.OffsetZ) or 0,
		VisualHeightOffset = tonumber(data.VisualHeightOffset) or tonumber(config.VisualHeightOffset) or 0.08,
		FullPaintTransparency = data.FullPaintTransparency,
		ClearedTransparency = data.ClearedTransparency,
		Coverage = data.Coverage or {},
		Cells = {},
		Folder = surfaceFolder,
		VisibleCount = 0,
	}
	surfaces[surface.SurfaceId] = surface
end

local function applyDelta(surfaceData)
	local surface = surfaceData and surfaces[surfaceData.SurfaceId]
	if not surface then
		return
	end

	for _, change in ipairs(surfaceData.Changes or {}) do
		local index = tonumber(change[1])
		local coverage = tonumber(change[2])
		if index and coverage then
			surface.Coverage[index] = coverage
			local cell = surface.Cells[index]
			if cell then
				cell.Transparency = getTransparency(coverage, surface)
			elseif coverage > 0.01 and totalVisibleCells < maxVisibleCells then
				makeCell(surface, index, coverage)
				surface.VisibleCount += 1
			end
		end
	end
end

local function getPlayerRoot()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function refreshVisibleCells()
	local root = getPlayerRoot()
	if not root then
		return
	end

	local candidates = {}
	for _, surface in pairs(surfaces) do
		if surface.Part and surface.Part.Parent then
			local localPoint = surface.Part.CFrame:PointToObjectSpace(root.Position)
			local dx = math.max(math.abs(localPoint.X - surface.OffsetX) - surface.CoverageX * 0.5, 0)
			local dz = math.max(math.abs(localPoint.Z - surface.OffsetZ) - surface.CoverageZ * 0.5, 0)
			table.insert(candidates, {
				Surface = surface,
				DistanceSq = dx * dx + dz * dz,
			})
		else
			clearSurfaceCells(surface)
			destroySurface(surface)
			surfaces[surface.SurfaceId] = nil
		end
	end

	table.sort(candidates, function(a, b)
		return a.DistanceSq < b.DistanceSq
	end)

	local selected = {}
	local budget = maxVisibleCells
	for _, candidate in ipairs(candidates) do
		if budget <= 0 then
			break
		end
		local surface = candidate.Surface
		selected[surface.SurfaceId] = true
		local totalCells = surface.XCount * surface.ZCount
		for index = 1, totalCells do
			if budget <= 0 then
				break
			end
			local coverage = surface.Coverage[index]
			if (coverage == nil or coverage > 0.01) and not surface.Cells[index] then
				makeCell(surface, index, coverage == nil and 1 or coverage)
				surface.VisibleCount += 1
			end
			if surface.Cells[index] then
				budget -= 1
			end
		end
	end

	for surfaceId, surface in pairs(surfaces) do
		if not selected[surfaceId] then
			clearSurfaceCells(surface)
		end
	end
end

local function clearVisuals()
	for _, surface in pairs(surfaces) do
		destroySurface(surface)
	end
	table.clear(surfaces)
	totalVisibleCells = 0
	folder:ClearAllChildren()
end

paintUpdateEvent.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	if tonumber(payload.MaxVisibleCells) then
		maxVisibleCells = tonumber(payload.MaxVisibleCells)
	end

	if payload.Type == "Snapshot" then
		clearVisuals()
		for _, surfaceData in ipairs(payload.Surfaces or {}) do
			upsertSurface(surfaceData)
		end
	elseif payload.Type == "SurfaceAdded" then
		for _, surfaceData in ipairs(payload.Surfaces or {}) do
			upsertSurface(surfaceData)
		end
	elseif payload.Type == "Delta" then
		for _, surfaceData in ipairs(payload.Surfaces or {}) do
			applyDelta(surfaceData)
		end
	end
end)

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now - lastVisibilityRefreshAt >= 0.75 then
		lastVisibilityRefreshAt = now
		refreshVisibleCells()
	end
	if now - lastRefreshAt < 0.5 then
		return
	end
	lastRefreshAt = now

	local root = getPlayerRoot()
	local origin = root and root.Position

	for _, surface in pairs(surfaces) do
		if not surface.Part or not surface.Part.Parent then
			totalVisibleCells -= surface.VisibleCount or 0
			destroySurface(surface)
			surfaces[surface.SurfaceId] = nil
			continue
		end

		local shouldRefresh = true
		if origin then
			shouldRefresh = (surface.Part.Position - origin).Magnitude
				<= math.max(surface.CoverageX, surface.CoverageZ) * 0.75 + 220
		end
		if shouldRefresh then
			for index in pairs(surface.Cells) do
				refreshCellCFrame(surface, index)
			end
		end
	end
end)
