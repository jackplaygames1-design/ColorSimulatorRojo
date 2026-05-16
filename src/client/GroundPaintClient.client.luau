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
local paintSweepEvent = Events:WaitForChild("PaintToolSweep")
local snapshotRemote = Events:WaitForChild("PaintFieldSnapshot")
local deltaRemote = Events:WaitForChild("PaintFieldDelta")
local readyRemote = Events:WaitForChild("PaintFieldClientReady")

local folder = Workspace:FindFirstChild("ClientGroundPaint")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "ClientGroundPaint"
	folder.Parent = Workspace
end

local localBrushEvent = Events:FindFirstChild("PaintFieldLocalBrush")
if not localBrushEvent then
	localBrushEvent = Instance.new("BindableEvent")
	localBrushEvent.Name = "PaintFieldLocalBrush"
	localBrushEvent.Parent = Events
end

local surfaces = {}
local activeStampCount = 0
local predictedStamps = {}
local nextPredictedId = 0
local lastSnapshotAttempt = 0
local snapshotRetryQueued = false
local clientReadySent = false
local requestSnapshot

local function asNumber(value, fallback)
	local n = tonumber(value)
	if n == nil then
		return fallback
	end
	return n
end

local MAX_STAMP_RADIUS = asNumber(stampConfig.MaxRadius, 18)
local MAX_MERGED_STAMP_RADIUS = asNumber(stampConfig.MaxMergedRadius, 22)
local LOCAL_STAMP_CONFIRM_WINDOW = 0.35

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
	table.clear(predictedStamps)
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

local function sendClientReady()
	if clientReadySent then
		return
	end
	clientReadySent = true
	readyRemote:FireServer()
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
	local cframe = surface.SurfaceCFrame or surface.CFrame or (surface.Part and surface.Part.CFrame)
	local size = surface.SurfaceSize or surface.Size or (surface.Part and surface.Part.Size)

	if typeof(cframe) ~= "CFrame" or typeof(size) ~= "Vector3" then
		return CFrame.new()
	end

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
		SurfaceCFrame = surfaceCFrame,
		SurfaceSize = surfaceSize,
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
			if stamp.PredictionId then
				predictedStamps[stamp.PredictionId] = nil
			end
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
		if oldestStamp.PredictionId then
			predictedStamps[oldestStamp.PredictionId] = nil
		end
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
	local removed = false
	for index = #surface.Stamps, 1, -1 do
		if surface.Stamps[index] == stamp then
			table.remove(surface.Stamps, index)
			removed = true
			break
		end
	end
	if stamp.PredictionId then
		predictedStamps[stamp.PredictionId] = nil
	end
	if stamp.Folder then
		stamp.Folder:Destroy()
	end
	if removed then
		activeStampCount = math.max(activeStampCount - 1, 0)
	end
end

local function fadeStampNow(surface, stamp, fadeTime)
	if not stamp or not stamp.Folder or not stamp.Folder.Parent then
		return
	end
	for _, part in ipairs(stamp.Parts or {}) do
		if part and part.Parent then
			TweenService
				:Create(part, TweenInfo.new(fadeTime or 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Transparency = 1,
				})
				:Play()
		end
	end
	task.delay((fadeTime or 0.35) + 0.05, function()
		removeStamp(surface, stamp)
	end)
end

local function absorbNearbyStamp(surface, localPoint, radius, source)
	radius = math.clamp(radius, 1, MAX_STAMP_RADIUS)

	for index = #surface.Stamps, 1, -1 do
		local stamp = surface.Stamps[index]
		if stamp.CenterLocal and stamp.Radius then
			local dx = stamp.CenterLocal.X - localPoint.X
			local dz = stamp.CenterLocal.Y - localPoint.Z
			local mergeDistance = math.max(radius, stamp.Radius or radius) * 0.25
			if dx * dx + dz * dz <= mergeDistance * mergeDistance then
				if source == "local" and stamp.Source == "server" then
					return radius
				end

				if source == "server" and stamp.Source == "local" then
					removeStamp(surface, stamp)
					return radius
				end

				local nextRadius = math.min(math.max(radius, (stamp.Radius or radius) + 1.25), MAX_MERGED_STAMP_RADIUS)
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
	emitter.Color = ColorSequence.new(color, color:Lerp(Color3.fromRGB(255, 255, 255), 0.35))
	emitter.LightEmission = 0.65
	emitter.Lifetime = NumberRange.new(0.18, 0.42)
	emitter.Speed = NumberRange.new(3.2, 7.2)
	emitter.SpreadAngle = Vector2.new(60, 180)
	emitter.Acceleration = Vector3.new(0, 10, 0)
	emitter.Drag = 6
	emitter.Rate = 0
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, math.clamp(radius * 0.055, 0.18, 0.65)),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Parent = anchor
	emitter:Emit(math.clamp(math.floor(radius * 1.35), 6, 20))
	Debris:AddItem(anchor, 0.8)
end

local function findLocalSurfaceAtPosition(worldPosition)
	local bestSurface = nil
	local bestDistance = math.huge

	for _, surface in pairs(surfaces) do
		local cframe = surface.SurfaceCFrame or surface.CFrame or (surface.Part and surface.Part.CFrame)
		local size = surface.SurfaceSize or surface.Size or (surface.Part and surface.Part.Size)
		if typeof(cframe) == "CFrame" and typeof(size) == "Vector3" then
			local localPoint = cframe:PointToObjectSpace(worldPosition)
			local halfX = (surface.CoverageX or size.X) * 0.5 + 5
			local halfZ = (surface.CoverageZ or size.Z) * 0.5 + 5
			if
				math.abs(localPoint.X - (surface.OffsetX or 0)) <= halfX
				and math.abs(localPoint.Z - (surface.OffsetZ or 0)) <= halfZ
			then
				local topY = size.Y * 0.5
				local distance = math.abs(localPoint.Y - topY)
				if distance < bestDistance then
					bestSurface = surface
					bestDistance = distance
				end
			end
		end
	end

	return bestSurface
end

local function fadeAndDestroyStamp(surface, stamp)
	local holdTime = math.max(
		asNumber(stamp.Duration, 5),
		asNumber(stampConfig.MinStampLifetime, 5),
		asNumber(regenConfig.DelayAfterBrush, 5)
	)
	local fadeTime = asNumber(stampConfig.FadeOutTime, 1)

	task.delay(holdTime, function()
		if not stamp.Folder or not stamp.Folder.Parent then
			return
		end
		fadeStampNow(surface, stamp, fadeTime)
	end)
end

local function fadeNearestPredictedStamp(worldPosition)
	if typeof(worldPosition) ~= "Vector3" then
		return
	end

	local bestSurface = nil
	local bestStamp = nil
	local bestDistance = math.huge
	for _, surface in pairs(surfaces) do
		local cframe = surface.SurfaceCFrame or surface.CFrame or (surface.Part and surface.Part.CFrame)
		if typeof(cframe) == "CFrame" then
			local localPoint = cframe:PointToObjectSpace(worldPosition)
			for _, stamp in ipairs(surface.Stamps or {}) do
				if stamp.Source == "local" and stamp.CenterLocal then
					local dx = stamp.CenterLocal.X - localPoint.X
					local dz = stamp.CenterLocal.Y - localPoint.Z
					local distance = dx * dx + dz * dz
					if distance < bestDistance then
						bestDistance = distance
						bestSurface = surface
						bestStamp = stamp
					end
				end
			end
		end
	end

	if bestSurface and bestStamp then
		fadeStampNow(bestSurface, bestStamp, asNumber(stampConfig.LocalPredictionFadeTime, 0.35))
	end
end

local function makeRimPieces(surface, stamp, localPoint, radius, paintColor, yOffset)
	if stampConfig.RimEnabled == false then
		return
	end

	local pieces = math.clamp(math.floor(radius * 0.8), 6, 14)
	local rimColor = paintColor:Lerp(Color3.fromRGB(0, 0, 0), 0.25)

	for i = 1, pieces do
		local angle = (math.pi * 2) * (i / pieces)
		local jitter = 0.85 + math.random() * 0.25
		local r = radius * jitter
		local localX = localPoint.X + math.cos(angle) * r
		local localZ = localPoint.Z + math.sin(angle) * r

		local piece = Instance.new("Part")
		piece.Name = "PaintRim"
		piece.Size = Vector3.new(
			math.clamp(radius * asNumber(stampConfig.RimThickness, 0.18), 0.35, 1.3),
			asNumber(stampConfig.RimHeight, 0.11),
			math.clamp(radius * 0.08, 0.2, 0.7)
		)
		piece.CFrame = getSurfaceTopCFrame(surface, localX, localZ, yOffset + 0.06) * CFrame.Angles(0, angle, 0)
		piece.Anchored = true
		piece.CanCollide = false
		piece.CanTouch = false
		piece.CanQuery = false
		piece.CastShadow = false
		piece.Material = Enum.Material.SmoothPlastic
		piece.Color = rimColor
		piece.Transparency = asNumber(stampConfig.RimTransparency, 0.18)
		piece.Parent = stamp.Folder
		table.insert(stamp.Parts, piece)
	end
end

local function makeSplatter(surface, stamp, localPoint, radius, paintColor, yOffset)
	if stampConfig.SplatterEnabled == false then
		return
	end

	local count = math.clamp(math.floor(asNumber(stampConfig.SplatterCount, 6)), 0, 16)
	for _ = 1, count do
		local angle = math.random() * math.pi * 2
		local r = radius * (0.65 + math.random() * 0.65)
		local localX = localPoint.X + math.cos(angle) * r
		local localZ = localPoint.Z + math.sin(angle) * r

		local dot = Instance.new("Part")
		dot.Name = "PaintSplatter"
		dot.Shape = Enum.PartType.Ball
		local size = math.random(8, 18) / 100
		dot.Size = Vector3.new(size, size, size)
		dot.CFrame = getSurfaceTopCFrame(surface, localX, localZ, yOffset + 0.12)
		dot.Anchored = true
		dot.CanCollide = false
		dot.CanTouch = false
		dot.CanQuery = false
		dot.CastShadow = false
		dot.Material = Enum.Material.SmoothPlastic
		dot.Color = paintColor
		dot.Transparency = 0.05
		dot.Parent = stamp.Folder
		table.insert(stamp.Parts, dot)
	end
end

local function makeDisplacedPaint(surface, stamp, localPoint, radius, paintColor, yOffset)
	if stampConfig.DisplacementEnabled == false then
		return
	end

	paintColor = typeof(paintColor) == "Color3" and paintColor or Color3.fromRGB(235, 35, 32)
	local height = math.clamp(asNumber(stampConfig.DisplacementHeight, 0.28), 0.08, 0.65)
	local transparency = math.clamp(asNumber(stampConfig.DisplacementTransparency, 0.08), 0, 0.8)
	local wallColor = paintColor:Lerp(Color3.fromRGB(0, 0, 0), 0.18)
	local edgeRadius = radius * 0.62
	local wallLength = radius * 1.55
	local wallThickness = math.clamp(radius * 0.22, 0.45, 1.35)

	local strips = {
		{
			x = 0,
			z = -edgeRadius,
			angle = 0,
			size = Vector3.new(wallLength, height, wallThickness),
		},
		{
			x = 0,
			z = edgeRadius,
			angle = math.rad(180),
			size = Vector3.new(wallLength, height, wallThickness),
		},
		{
			x = -edgeRadius,
			z = 0,
			angle = math.rad(90),
			size = Vector3.new(wallLength, height, wallThickness),
		},
		{
			x = edgeRadius,
			z = 0,
			angle = math.rad(-90),
			size = Vector3.new(wallLength, height, wallThickness),
		},
	}

	for index, strip in ipairs(strips) do
		local jitter = math.rad(math.random(-7, 7))
		local part = Instance.new("Part")
		part.Name = "PaintDisplacementLip"
		part.Size = strip.size
		part.CFrame = getSurfaceTopCFrame(
			surface,
			localPoint.X + strip.x,
			localPoint.Z + strip.z,
			yOffset + height * 0.5 + 0.03 + index * 0.003
		) * CFrame.Angles(0, strip.angle + jitter, 0)
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.Material = Enum.Material.SmoothPlastic
		part.Color = wallColor
		part.Transparency = transparency
		part.Parent = stamp.Folder
		table.insert(stamp.Parts, part)
	end

	local clumpCount = math.clamp(math.floor(asNumber(stampConfig.DisplacementClumpCount, 10)), 0, 18)
	for _ = 1, clumpCount do
		local angle = math.random() * math.pi * 2
		local r = radius * (0.48 + math.random() * 0.42)
		local clump = Instance.new("Part")
		clump.Name = "PaintDisplacementClump"
		clump.Shape = Enum.PartType.Ball
		local clumpSize = math.clamp(radius * (0.08 + math.random() * 0.06), 0.22, 0.85)
		clump.Size = Vector3.new(clumpSize * 1.25, clumpSize * 0.75, clumpSize)
		clump.CFrame = getSurfaceTopCFrame(
			surface,
			localPoint.X + math.cos(angle) * r,
			localPoint.Z + math.sin(angle) * r,
			yOffset + height + 0.05
		) * CFrame.Angles(0, angle, math.rad(math.random(-12, 12)))
		clump.Anchored = true
		clump.CanCollide = false
		clump.CanTouch = false
		clump.CanQuery = false
		clump.CastShadow = false
		clump.Material = Enum.Material.SmoothPlastic
		clump.Color = paintColor:Lerp(Color3.fromRGB(0, 0, 0), math.random(8, 24) / 100)
		clump.Transparency = math.clamp(transparency + 0.02, 0, 0.85)
		clump.Parent = stamp.Folder
		table.insert(stamp.Parts, clump)
	end
end

local function makeClearStamp(stampData)
	if type(stampData) ~= "table" or typeof(stampData.Position) ~= "Vector3" then
		warn("GroundPaintClient failed to create stamp: invalid stamp payload")
		return
	end

	local surface = surfaces[stampData.SurfaceId]
	if not surface then
		warn("GroundPaintClient failed to create stamp: missing surfaceId=" .. tostring(stampData.SurfaceId))
		return
	end

	local surfaceCFrame = surface.SurfaceCFrame or surface.CFrame or (surface.Part and surface.Part.CFrame)
	if typeof(surfaceCFrame) ~= "CFrame" then
		warn("GroundPaintClient failed to create stamp: missing cframe surfaceId=" .. tostring(stampData.SurfaceId))
		return
	end

	local localPoint = surfaceCFrame:PointToObjectSpace(stampData.Position)
	local source = stampData.Source == "local" and "local" or "server"
	local radius = math.max(asNumber(stampData.Radius, 7), 1)
	radius = math.clamp(radius, 1, MAX_STAMP_RADIUS)
	radius = absorbNearbyStamp(surface, localPoint, radius, source)
	if source == "local" then
		radius = math.clamp(radius * 0.85, 1, MAX_STAMP_RADIUS)
	end
	local ringCount = math.clamp(math.floor(asNumber(stampConfig.RingCount, 7)), 2, 11)
	if source == "local" then
		ringCount = math.clamp(ringCount, 2, 3)
	end
	local baseColor = typeof(surface.BaseSurfaceColor) == "Color3" and surface.BaseSurfaceColor
		or typeof(stampData.BaseSurfaceColor) == "Color3" and stampData.BaseSurfaceColor
		or visualConfig.BaseSurfaceColor
		or surface.BaseSurfaceColor
		or Color3.fromRGB(5, 5, 5)
	local centerTransparency =
		asNumber(stampConfig.CenterTransparency, asNumber(stampConfig.ClearCenterTransparency, 0))
	local edgeTransparency = asNumber(stampConfig.EdgeTransparency, asNumber(stampConfig.ClearEdgeTransparency, 0.65))
	if source == "local" then
		centerTransparency = math.max(centerTransparency, 0.62)
		edgeTransparency = math.max(edgeTransparency, 0.86)
	end
	local yOffset = asNumber(visualConfig.ClearStampYOffset, 0.055)

	local stampFolder = Instance.new("Folder")
	stampFolder.Name = "SoftClearStamp"
	stampFolder.Parent = surface.Folder

	local stamp = {
		Folder = stampFolder,
		Parts = {},
		CenterLocal = Vector2.new(localPoint.X, localPoint.Z),
		Radius = radius,
		Duration = asNumber(stampData.RegenDelay, asNumber(regenConfig.DelayAfterBrush, 5)),
		Position = stampData.Position,
		PredictionId = stampData.PredictionId,
		Source = source,
		CreatedAt = os.clock(),
	}

	for ring = ringCount, 1, -1 do
		local t = ring / ringCount
		local discRadius = radius * (0.35 + 0.65 * t)

		local disc = Instance.new("Part")
		disc.Name = "ClearDisc"
		disc.Shape = Enum.PartType.Block
		disc.Size = Vector3.new(discRadius * 2, 0.08, discRadius * 2)
		disc.CFrame = getSurfaceTopCFrame(surface, localPoint.X, localPoint.Z, yOffset + ring * 0.012)
			* CFrame.Angles(0, math.rad((ring % 2 == 0 and 10 or -10) + math.random(-5, 5)), 0)
		disc.Anchored = true
		disc.CanCollide = false
		disc.CanTouch = false
		disc.CanQuery = false
		disc.CastShadow = false
		disc.Material = Enum.Material.SmoothPlastic

		if ring == 1 then
			disc.Color = Color3.fromRGB(0, 0, 0)
			disc.Transparency = centerTransparency
		else
			disc.Color = baseColor
			disc.Transparency = math.clamp(edgeTransparency + (t * 0.18), 0.2, 0.82)
		end
		disc.Parent = stampFolder
		table.insert(stamp.Parts, disc)
	end
	if source ~= "local" then
		makeDisplacedPaint(surface, stamp, localPoint, radius, surface.PaintColor, yOffset)
		makeRimPieces(surface, stamp, localPoint, radius, surface.PaintColor, yOffset)
		makeSplatter(surface, stamp, localPoint, radius, surface.PaintColor, yOffset)
	end

	table.insert(surface.Stamps, stamp)
	activeStampCount += 1
	pruneSurfaceStamps(surface)
	pruneGlobalStamps()
	if source == "local" then
		if not stamp.PredictionId then
			nextPredictedId += 1
			stamp.PredictionId = "pred_" .. tostring(nextPredictedId)
		end
		predictedStamps[stamp.PredictionId] = stamp
		task.delay(LOCAL_STAMP_CONFIRM_WINDOW, function()
			local stillPredicted = predictedStamps[stamp.PredictionId]
			if stillPredicted == stamp then
				predictedStamps[stamp.PredictionId] = nil
				fadeStampNow(surface, stamp, asNumber(stampConfig.LocalPredictionFadeTime, 0.35))
			end
		end)
	else
		fadeAndDestroyStamp(surface, stamp)
	end
	emitLiftParticles(stampData.Position, surface.PaintColor, radius)
	print(
		string.format(
			"GroundPaintClient stamp: surface=%s radius=%.2f position=%s",
			tostring(stampData.SurfaceId),
			radius,
			tostring(stampData.Position)
		)
	)
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
		warn("GroundPaintClient ignored snapshot because it had surfaces but 0 valid surface geometry records.")
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
	sendClientReady()
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
		print(
			string.format(
				"GroundPaintClient delta: stamps=%d surfaces=%d",
				#(payload.Stamps or {}),
				#(payload.Surfaces or {})
			)
		)
		local missingSurface = false
		for _, stamp in ipairs(payload.Stamps or {}) do
			if type(stamp) == "table" and stamp.SurfaceId and not surfaces[stamp.SurfaceId] then
				missingSurface = true
				warn("GroundPaintClient failed to create stamp: missing surfaceId=" .. tostring(stamp.SurfaceId))
			else
				makeClearStamp(stamp)
			end
		end
		if missingSurface then
			queueSnapshotRetry(0.2)
		end
	end
end)

paintSweepEvent.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" or payload.GroundPaint ~= true then
		return
	end

	local stamps = payload.Stamps or {}
	if #stamps == 0 and type(payload.groundStamp) == "table" then
		stamps = { payload.groundStamp }
	end
	if debugConfig.PrintClientVisuals == true then
		print(string.format("GroundPaintClient PaintToolSweep response: stamps=%d", #stamps))
	end

	if #stamps == 0 then
		fadeNearestPredictedStamp(payload.Position or payload.HitPosition or payload.GroundPosition)
		return
	end

	for _, stamp in ipairs(stamps) do
		makeClearStamp(stamp)
	end
end)

if localBrushEvent:IsA("BindableEvent") then
	localBrushEvent.Event:Connect(function(payload)
		if type(payload) ~= "table" or typeof(payload.Position) ~= "Vector3" then
			return
		end

		local surface = findLocalSurfaceAtPosition(payload.Position)
		if not surface then
			if debugConfig.PrintClientVisuals == true then
				warn("GroundPaintClient local stamp missed surface at " .. tostring(payload.Position))
			end
			return
		end

		nextPredictedId += 1
		local predictionId = "pred_" .. tostring(nextPredictedId)

		makeClearStamp({
			PredictionId = predictionId,
			SurfaceId = surface.SurfaceId,
			Position = payload.Position,
			Radius = payload.Radius or 7,
			BaseSurfaceColor = surface.BaseSurfaceColor or Color3.fromRGB(5, 5, 5),
			PaintColor = surface.PaintColor,
			RegenDelay = 0.35,
			Source = "local",
		})
	end)
end

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
