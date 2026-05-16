-- Client-only beauty renderer for the server-owned ground paint field.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local GameBalance = require(ReplicatedStorage:WaitForChild("GameBalance"))

local config = GameBalance.GroundPaint or {}
if config.Enabled == false or (config.Visual and config.Visual.Enabled == false) then
	return
end

local visualConfig = config.Visual or {}
local stampConfig = visualConfig.BrushStamp or {}
local thicknessConfig = visualConfig.Thickness or {}
local regenConfig = config.Regen or {}
local debugConfig = config.Debug or {}

local Events = ReplicatedStorage:WaitForChild("Events")
local snapshotRemote = Events:WaitForChild("PaintFieldSnapshot")
local deltaRemote = Events:WaitForChild("PaintFieldDelta")

local folder = Workspace:FindFirstChild("ClientGroundPaint")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "ClientGroundPaint"
	folder.Parent = Workspace
end

local surfaces = {}
local activeStampCount = 0
local lastSnapshotAttempt = 0
local snapshotRetryQueued = false
local requestSnapshot

local function asNumber(value, fallback)
	local n = tonumber(value)
	if n == nil then
		return fallback
	end
	return n
end

local function getMaterial(value)
	if typeof(value) == "EnumItem" then
		return value
	end
	return Enum.Material.SmoothPlastic
end

local function configurePaintPart(part, color, transparency, material)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Color = color
	part.Material = material or getMaterial(visualConfig.PaintMaterial)
	part.Transparency = transparency
	part.Reflectance = asNumber(visualConfig.PaintReflectance, 0.03)
end

local function destroySurface(surface)
	if not surface then
		return
	end
	for _, part in ipairs(surface.Coats or {}) do
		part:Destroy()
	end
	for _, part in ipairs(surface.Lips or {}) do
		part:Destroy()
	end
	for _, part in ipairs(surface.Glow or {}) do
		part:Destroy()
	end
	for _, stamp in ipairs(surface.Stamps or {}) do
		if stamp.Folder then
			stamp.Folder:Destroy()
		end
	end
	if surface.Folder then
		surface.Folder:Destroy()
	end
end

local function clearVisuals()
	for _, surface in pairs(surfaces) do
		destroySurface(surface)
	end
	table.clear(surfaces)
	folder:ClearAllChildren()
	activeStampCount = 0
end

local function hasAnySurface()
	return next(surfaces) ~= nil
end

local function queueSnapshotRetry(delaySeconds)
	if snapshotRetryQueued then
		return
	end
	snapshotRetryQueued = true
	task.delay(delaySeconds or 1.25, function()
		snapshotRetryQueued = false
		if requestSnapshot then
			requestSnapshot(true)
		end
	end)
end

local function getPlaneGrid(maxPlanes, coverageX, coverageZ)
	maxPlanes = math.max(1, math.floor(maxPlanes or 16))
	local aspect = math.max(coverageX, 1) / math.max(coverageZ, 1)
	local xCount = math.clamp(math.ceil(math.sqrt(maxPlanes * aspect)), 1, maxPlanes)
	local zCount = math.clamp(math.ceil(maxPlanes / xCount), 1, maxPlanes)
	while xCount * zCount > maxPlanes do
		if xCount >= zCount and xCount > 1 then
			xCount -= 1
		elseif zCount > 1 then
			zCount -= 1
		else
			break
		end
	end
	return xCount, zCount
end

local function getSurfaceTopCFrame(surface, localX, localZ, yOffset)
	local size = surface.Size or (surface.Part and surface.Part.Size) or Vector3.new(1, 1, 1)
	local cframe = surface.CFrame or (surface.Part and surface.Part.CFrame) or CFrame.new()
	local topY = size.Y * 0.5 + yOffset
	return cframe * CFrame.new(localX, topY, localZ)
end

local function makeCoatPlanes(surface)
	local xCount, zCount = getPlaneGrid(visualConfig.MaxCoatPlanesPerSurface, surface.CoverageX, surface.CoverageZ)
	local segmentX = surface.CoverageX / xCount
	local segmentZ = surface.CoverageZ / zCount
	local yOffset = asNumber(visualConfig.PaintYOffset, 0.035)
	local paintTransparency = asNumber(visualConfig.PaintTransparency, 0.06)
	local material = getMaterial(visualConfig.PaintMaterial)

	for z = 1, zCount do
		for x = 1, xCount do
			local localX = -surface.CoverageX * 0.5 + segmentX * (x - 0.5) + surface.OffsetX
			local localZ = -surface.CoverageZ * 0.5 + segmentZ * (z - 0.5) + surface.OffsetZ

			local coat = Instance.new("Part")
			coat.Name = "PaintCoat"
			coat.Size = Vector3.new(math.max(segmentX + 0.08, 0.5), 0.18, math.max(segmentZ + 0.08, 0.5))
			coat.CFrame = getSurfaceTopCFrame(surface, localX, localZ, yOffset)
			configurePaintPart(coat, surface.PaintColor, paintTransparency, material)
			coat.Parent = surface.Folder
			table.insert(surface.Coats, coat)

			if visualConfig.UseNeonGlow == true then
				local glow = Instance.new("Part")
				glow.Name = "PaintGlow"
				glow.Size = Vector3.new(coat.Size.X, 0.025, coat.Size.Z)
				glow.CFrame = getSurfaceTopCFrame(surface, localX, localZ, asNumber(visualConfig.GlowYOffset, 0.045))
				configurePaintPart(
					glow,
					surface.PaintColor,
					asNumber(visualConfig.GlowTransparency, 0.55),
					Enum.Material.Neon
				)
				glow.Parent = surface.Folder
				table.insert(surface.Glow, glow)
			end
		end
	end
end

local function darken(color, amount)
	return color:Lerp(Color3.fromRGB(0, 0, 0), math.clamp(amount or 0.22, 0, 1))
end

local function makeThicknessLips(surface)
	if thicknessConfig.Enabled == false or thicknessConfig.SideLipEnabled == false then
		return
	end

	local lipColor = darken(surface.PaintColor, asNumber(thicknessConfig.EdgeDarken, 0.22))
	local yOffset = asNumber(visualConfig.PaintYOffset, 0.035) - 0.015
	local lipHeight = 0.11
	local lipThickness = 0.25
	local definitions = {
		{
			Size = Vector3.new(surface.CoverageX, lipHeight, lipThickness),
			Offset = Vector3.new(surface.OffsetX, 0, surface.OffsetZ - surface.CoverageZ * 0.5),
		},
		{
			Size = Vector3.new(surface.CoverageX, lipHeight, lipThickness),
			Offset = Vector3.new(surface.OffsetX, 0, surface.OffsetZ + surface.CoverageZ * 0.5),
		},
		{
			Size = Vector3.new(lipThickness, lipHeight, surface.CoverageZ),
			Offset = Vector3.new(surface.OffsetX - surface.CoverageX * 0.5, 0, surface.OffsetZ),
		},
		{
			Size = Vector3.new(lipThickness, lipHeight, surface.CoverageZ),
			Offset = Vector3.new(surface.OffsetX + surface.CoverageX * 0.5, 0, surface.OffsetZ),
		},
	}

	for _, definition in ipairs(definitions) do
		local lip = Instance.new("Part")
		lip.Name = "PaintThicknessLip"
		lip.Size = definition.Size
		lip.CFrame = getSurfaceTopCFrame(surface, definition.Offset.X, definition.Offset.Z, yOffset)
		configurePaintPart(
			lip,
			lipColor,
			asNumber(visualConfig.PaintTransparency, 0.06) + 0.04,
			Enum.Material.SmoothPlastic
		)
		lip.Parent = surface.Folder
		table.insert(surface.Lips, lip)
	end
end

local function upsertSurface(data)
	if type(data) ~= "table" then
		return false
	end

	local part = typeof(data.Part) == "Instance" and data.Part:IsA("BasePart") and data.Part or nil
	local surfaceCFrame = typeof(data.SurfaceCFrame) == "CFrame" and data.SurfaceCFrame or (part and part.CFrame)
	local surfaceSize = typeof(data.SurfaceSize) == "Vector3" and data.SurfaceSize or (part and part.Size)
	if typeof(surfaceCFrame) ~= "CFrame" or typeof(surfaceSize) ~= "Vector3" then
		return false
	end

	local oldSurface = surfaces[data.SurfaceId]
	if oldSurface then
		destroySurface(oldSurface)
	end

	local surfaceFolder = Instance.new("Folder")
	surfaceFolder.Name = tostring(data.SurfaceId)
	surfaceFolder.Parent = folder

	local surface = {
		SurfaceId = data.SurfaceId,
		Part = part,
		CFrame = surfaceCFrame,
		Size = surfaceSize,
		PartPath = data.PartPath,
		ColorType = data.ColorType,
		PaintColor = typeof(data.PaintColor) == "Color3" and data.PaintColor or Color3.fromRGB(255, 0, 0),
		BaseSurfaceColor = typeof(data.BaseSurfaceColor) == "Color3" and data.BaseSurfaceColor
			or (visualConfig.BaseSurfaceColor or Color3.fromRGB(8, 8, 8)),
		CoverageX = asNumber(data.CoverageX, surfaceSize.X),
		CoverageZ = asNumber(data.CoverageZ, surfaceSize.Z),
		OffsetX = asNumber(data.OffsetX, 0),
		OffsetZ = asNumber(data.OffsetZ, 0),
		Folder = surfaceFolder,
		Coats = {},
		Lips = {},
		Glow = {},
		Stamps = {},
	}

	surfaces[surface.SurfaceId] = surface
	makeCoatPlanes(surface)
	makeThicknessLips(surface)
	return #(surface.Coats or {}) > 0
end

local function getCoatPartCount()
	local count = 0
	for _, surface in pairs(surfaces) do
		count += #(surface.Coats or {})
	end
	return count
end

local function colorToDebugString(color)
	return string.format(
		"rgb(%d,%d,%d)",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
end

local function pruneSurfaceStamps(surface)
	local limit = math.max(1, math.floor(asNumber(visualConfig.MaxActiveClearStampsPerSurface, 90)))
	while #surface.Stamps > limit do
		local stamp = table.remove(surface.Stamps, 1)
		if stamp and stamp.Folder then
			stamp.Folder:Destroy()
			activeStampCount = math.max(activeStampCount - 1, 0)
		end
	end
end

local function pruneGlobalStamps()
	local limit = math.max(1, math.floor(asNumber(visualConfig.MaxActiveClearStamps, 260)))
	while activeStampCount > limit do
		local oldestSurface = nil
		local oldestStamp = nil
		local oldestIndex = nil
		for _, surface in pairs(surfaces) do
			for index, stamp in ipairs(surface.Stamps) do
				if not oldestStamp or stamp.CreatedAt < oldestStamp.CreatedAt then
					oldestSurface = surface
					oldestStamp = stamp
					oldestIndex = index
				end
			end
		end
		if not oldestSurface or not oldestIndex then
			break
		end
		table.remove(oldestSurface.Stamps, oldestIndex)
		if oldestStamp.Folder then
			oldestStamp.Folder:Destroy()
		end
		activeStampCount = math.max(activeStampCount - 1, 0)
	end
end

local function removeStamp(surface, stamp)
	if not surface or not stamp then
		return
	end
	for index = #surface.Stamps, 1, -1 do
		if surface.Stamps[index] == stamp then
			table.remove(surface.Stamps, index)
			break
		end
	end
	if stamp.Folder then
		stamp.Folder:Destroy()
	end
	activeStampCount = math.max(activeStampCount - 1, 0)
end

local function absorbNearbyStamp(surface, localPoint, radius)
	for _, stamp in ipairs(surface.Stamps) do
		if stamp.CenterLocal and stamp.Radius then
			local dx = stamp.CenterLocal.X - localPoint.X
			local dz = stamp.CenterLocal.Y - localPoint.Z
			local mergeDistance = math.max(radius, stamp.Radius) * 0.35
			if dx * dx + dz * dz <= mergeDistance * mergeDistance then
				local nextRadius = math.max(radius, stamp.Radius * 1.08)
				removeStamp(surface, stamp)
				return nextRadius
			end
		end
	end
	return radius
end

local function emitLiftParticles(position, color, radius)
	local anchor = Instance.new("Part")
	anchor.Name = "GroundPaintLiftParticles"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.CFrame = CFrame.new(position + Vector3.new(0, 0.12, 0))
	anchor.Parent = folder

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Lift"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color, Color3.fromRGB(255, 255, 255))
	emitter.LightEmission = 0.65
	emitter.Lifetime = NumberRange.new(0.22, 0.55)
	emitter.Speed = NumberRange.new(2.2, 5.8)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, math.clamp(radius * 0.07, 0.25, 0.9)),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Parent = anchor
	emitter:Emit(math.clamp(math.floor(radius * 1.8), 8, 28))
	Debris:AddItem(anchor, 0.8)
end

local function fadeAndDestroyStamp(surface, stamp)
	local holdTime = math.max(asNumber(stampConfig.MinStampLifetime, 5), asNumber(regenConfig.DelayAfterBrush, 5))
	local fadeTime = asNumber(stampConfig.FadeOutTime, 1)

	task.delay(holdTime, function()
		if not stamp.Folder or not stamp.Folder.Parent then
			return
		end
		for _, part in ipairs(stamp.Parts) do
			if part and part.Parent then
				TweenService:Create(part, TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Transparency = 1,
				}):Play()
			end
		end
		task.delay(fadeTime + 0.05, function()
			if stamp.Folder then
				stamp.Folder:Destroy()
			end
			activeStampCount = math.max(activeStampCount - 1, 0)
			for index = #surface.Stamps, 1, -1 do
				if surface.Stamps[index] == stamp then
					table.remove(surface.Stamps, index)
					break
				end
			end
		end)
	end)
end

local function makeClearStamp(stampData)
	if type(stampData) ~= "table" or typeof(stampData.Position) ~= "Vector3" then
		return
	end

	local surface = surfaces[stampData.SurfaceId]
	if not surface then
		return
	end

	local surfaceCFrame = surface.CFrame or (surface.Part and surface.Part.CFrame)
	if typeof(surfaceCFrame) ~= "CFrame" then
		return
	end

	local localPoint = surfaceCFrame:PointToObjectSpace(stampData.Position)
	local radius = math.max(asNumber(stampData.Radius, 7), 1)
	radius = absorbNearbyStamp(surface, localPoint, radius)
	local ringCount = math.clamp(math.floor(asNumber(stampConfig.RingCount, 7)), 2, 11)
	local baseColor = typeof(surface.BaseSurfaceColor) == "Color3" and surface.BaseSurfaceColor
		or typeof(stampData.BaseSurfaceColor) == "Color3" and stampData.BaseSurfaceColor
		or visualConfig.BaseSurfaceColor
		or surface.BaseSurfaceColor
		or Color3.fromRGB(5, 5, 5)
	local centerTransparency =
		asNumber(stampConfig.CenterTransparency, asNumber(stampConfig.ClearCenterTransparency, 0))
	local edgeTransparency = asNumber(stampConfig.EdgeTransparency, asNumber(stampConfig.ClearEdgeTransparency, 0.65))
	local yOffset = asNumber(visualConfig.ClearStampYOffset, 0.055)

	local stampFolder = Instance.new("Folder")
	stampFolder.Name = "SoftClearStamp"
	stampFolder.Parent = surface.Folder

	local stamp = {
		Folder = stampFolder,
		Parts = {},
		CenterLocal = Vector2.new(localPoint.X, localPoint.Z),
		Radius = radius,
		CreatedAt = os.clock(),
	}

	for ring = ringCount, 1, -1 do
		local alpha = ring / ringCount
		local disc = Instance.new("Part")
		disc.Name = "ClearDisc"
		disc.Shape = Enum.PartType.Ball
		disc.Size = Vector3.new(radius * 2 * alpha, 0.06, radius * 2 * alpha)
		disc.CFrame = getSurfaceTopCFrame(surface, localPoint.X, localPoint.Z, yOffset + ring * 0.003)
		disc.Anchored = true
		disc.CanCollide = false
		disc.CanTouch = false
		disc.CanQuery = false
		disc.CastShadow = false
		disc.Material = Enum.Material.SmoothPlastic
		disc.Color = baseColor
		disc.Transparency = (ring == 1) and centerTransparency
			or math.clamp(edgeTransparency + (alpha * 0.12), centerTransparency, 0.82)
		disc.Parent = stampFolder
		table.insert(stamp.Parts, disc)
	end

	table.insert(surface.Stamps, stamp)
	activeStampCount += 1
	pruneSurfaceStamps(surface)
	pruneGlobalStamps()
	fadeAndDestroyStamp(surface, stamp)
	emitLiftParticles(stampData.Position, surface.PaintColor, radius)
end

local function applySnapshot(payload)
	local incoming = payload.Surfaces or {}
	local validSurfaces = {}
	for _, surfaceData in ipairs(incoming) do
		local hasReplicatedPart = type(surfaceData) == "table"
			and typeof(surfaceData.Part) == "Instance"
			and surfaceData.Part:IsA("BasePart")
			and surfaceData.Part.Parent ~= nil
		local hasGeometry = type(surfaceData) == "table"
			and typeof(surfaceData.SurfaceCFrame) == "CFrame"
			and typeof(surfaceData.SurfaceSize) == "Vector3"
		if type(surfaceData) == "table" and surfaceData.SurfaceId ~= nil and (hasReplicatedPart or hasGeometry) then
			table.insert(validSurfaces, surfaceData)
		else
			warn(
				"GroundPaintClient invalid snapshot surface:",
				type(surfaceData) == "table" and surfaceData.SurfaceId or nil,
				type(surfaceData) == "table" and surfaceData.Part or nil,
				type(surfaceData) == "table" and surfaceData.PartPath or nil
			)
		end
	end

	if #incoming > 0 and #validSurfaces == 0 then
		warn("GroundPaintClient ignored snapshot because it had surfaces but 0 valid replicated parts.")
		queueSnapshotRetry(1.25)
		return
	end

	if #incoming == 0 then
		if debugConfig.PrintClientVisuals == true then
			print("GroundPaintClient snapshot empty; keeping visuals and retrying.")
		end
		queueSnapshotRetry(1.25)
		return
	end

	clearVisuals()
	for _, surfaceData in ipairs(validSurfaces) do
		upsertSurface(surfaceData)
	end

	if debugConfig.PrintClientVisuals == true then
		local surfaceCount = #validSurfaces
		local coatParts = getCoatPartCount()
		print(string.format("GroundPaintClient snapshot: surfaces=%d coatParts=%d", surfaceCount, coatParts))
		for _, surface in pairs(surfaces) do
			print(
				string.format(
					"GroundPaintClient surface: id=%s color=%s transparency=%.3f yOffset=%.3f coverage=%.1fx%.1f coats=%d",
					tostring(surface.SurfaceId),
					colorToDebugString(surface.PaintColor),
					asNumber(visualConfig.PaintTransparency, 0.06),
					asNumber(visualConfig.PaintYOffset, 0.035),
					surface.CoverageX,
					surface.CoverageZ,
					#(surface.Coats or {})
				)
			)
		end
	end
end

requestSnapshot = function(force)
	if force ~= true and os.clock() - lastSnapshotAttempt < 1 then
		return
	end
	lastSnapshotAttempt = os.clock()

	task.spawn(function()
		local ok, payload = pcall(function()
			return snapshotRemote:InvokeServer()
		end)
		if ok and type(payload) == "table" and payload.Type == "Snapshot" then
			applySnapshot(payload)
		end
	end)
end

deltaRemote.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end

	if payload.Type == "Snapshot" then
		applySnapshot(payload)
	elseif payload.Type == "SurfaceAdded" then
		for _, surfaceData in ipairs(payload.Surfaces or {}) do
			upsertSurface(surfaceData)
		end
	elseif payload.Type == "Delta" then
		local missingSurface = false
		for _, stamp in ipairs(payload.Stamps or {}) do
			if type(stamp) == "table" and stamp.SurfaceId and not surfaces[stamp.SurfaceId] then
				missingSurface = true
			else
				makeClearStamp(stamp)
			end
		end
		if missingSurface then
			queueSnapshotRetry(0.2)
		end
	end
end)

RunService.Heartbeat:Connect(function()
	for surfaceId, surface in pairs(surfaces) do
		if surface.Part and not surface.Part.Parent then
			destroySurface(surface)
			surfaces[surfaceId] = nil
		end
	end
end)

print("GroundPaintClient ready")
requestSnapshot(true)
task.delay(1.25, function()
	requestSnapshot(true)
end)
task.delay(3, function()
	if not hasAnySurface() then
		requestSnapshot(true)
	end
end)
