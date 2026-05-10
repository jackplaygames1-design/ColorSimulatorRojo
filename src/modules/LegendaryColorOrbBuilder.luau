local LegendaryColorOrbBuilder = {}

local RAINBOW_COLORS = {
	Color3.fromRGB(255, 65, 85),
	Color3.fromRGB(255, 145, 45),
	Color3.fromRGB(255, 235, 70),
	Color3.fromRGB(75, 235, 115),
	Color3.fromRGB(70, 220, 255),
	Color3.fromRGB(85, 120, 255),
	Color3.fromRGB(190, 90, 255),
}

local function markVisual(instance)
	instance:SetAttribute("NoTint", true)
	return instance
end

local function prepPart(part, color, material, transparency)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Color = color
	part.Material = material or Enum.Material.Neon
	part.Transparency = transparency or 0
	markVisual(part)
	return part
end

local function makePart(model, name, shape, size, cframe, color, material, transparency)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape or Enum.PartType.Block
	part.Size = size
	part.CFrame = cframe or CFrame.new()
	prepPart(part, color, material, transparency)
	part.Parent = model
	return part
end

local function makeWedge(model, name, size, cframe, color, transparency)
	local part = Instance.new("WedgePart")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	prepPart(part, color, Enum.Material.Neon, transparency or 0.08)
	part.Parent = model
	return part
end

local function addLight(parent, color, range, brightness)
	local light = Instance.new("PointLight")
	light.Name = "CoreGlow"
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = parent
	return light
end

local function addBeam(core, target, color, index)
	local coreAttachment = Instance.new("Attachment")
	coreAttachment.Name = "BeamCore" .. tostring(index)
	coreAttachment.Parent = core

	local targetAttachment = Instance.new("Attachment")
	targetAttachment.Name = "BeamTarget" .. tostring(index)
	targetAttachment.Parent = target

	local beam = Instance.new("Beam")
	beam.Name = "SatelliteBeam" .. tostring(index)
	beam.Attachment0 = coreAttachment
	beam.Attachment1 = targetAttachment
	beam.Color = ColorSequence.new(color, color:Lerp(Color3.new(1, 1, 1), 0.3))
	beam.LightEmission = 0.75
	beam.LightInfluence = 0.1
	beam.Width0 = 0.035
	beam.Width1 = 0.018
	beam.Transparency = NumberSequence.new(0.18, 0.48)
	beam.Segments = 4
	beam.FaceCamera = true
	beam.Parent = core
	return beam
end

local function paletteColor(def, index)
	local colors = def.SatelliteColors or (def.HasRainbowShell and RAINBOW_COLORS)
	if colors then
		return colors[((index - 1) % #colors) + 1]
	end
	return (index % 2 == 0 and def.SecondaryColor or def.MainColor)
end

local function makeHalo(model, def, name, y, diameter, color, tilt)
	local halo = makePart(
		model,
		name,
		Enum.PartType.Cylinder,
		Vector3.new(0.055, diameter, diameter),
		CFrame.new(0, y, 0) * CFrame.Angles(math.rad(tilt or 0), 0, math.rad(90)),
		color,
		Enum.Material.Neon,
		0.28
	)
	halo:SetAttribute("HaloRing", true)
	return halo
end

local function makeRingSegments(model, def, ringIndex)
	local complexity = tonumber(def.ComplexityLevel) or 1
	local segmentCount = math.max(6, 6 + complexity + ringIndex)
	local radius = 1.18 + ringIndex * 0.16 + complexity * 0.025
	local y = (ringIndex % 2 == 0 and 0.08 or -0.08) * ringIndex
	local tilt = math.rad((ringIndex - 1) * 13)

	for index = 1, segmentCount do
		local angle = (math.pi * 2) * (index - 1) / segmentCount
		local color = paletteColor(def, index + ringIndex)
		local pos = Vector3.new(math.cos(angle) * radius, y + math.sin(angle * 2) * 0.08, math.sin(angle) * radius)
		local segment = makePart(
			model,
			"OrbitSegment" .. tostring(ringIndex) .. "_" .. tostring(index),
			Enum.PartType.Block,
			Vector3.new(0.38 + complexity * 0.018, 0.075, 0.14),
			CFrame.new(pos) * CFrame.Angles(tilt, -angle, math.rad(8 + ringIndex * 3)),
			color,
			Enum.Material.Neon,
			ringIndex > 3 and 0.12 or 0.04
		)
		segment:SetAttribute("OrbitPiece", true)
	end
end

local function makePanels(model, def)
	local count = tonumber(def.PanelCount) or 0
	if count <= 0 then
		return
	end

	local complexity = tonumber(def.ComplexityLevel) or 1
	local radius = 1.34 + complexity * 0.035
	for index = 1, count do
		local angle = (math.pi * 2) * (index - 1) / count
		local y = ((index % 3) - 1) * 0.28
		local color = paletteColor(def, index)
		makePart(
			model,
			"FloatingPanel" .. tostring(index),
			Enum.PartType.Block,
			Vector3.new(0.32 + complexity * 0.015, 0.11, 0.46),
			CFrame.new(math.cos(angle) * radius, y, math.sin(angle) * radius)
				* CFrame.Angles(math.rad(15), -angle, math.rad(20 + index * 7)),
			color,
			Enum.Material.Neon,
			0.08
		)
	end
end

local function makeCrystals(model, def)
	local count = tonumber(def.CrystalCount) or 0
	if count <= 0 then
		return
	end

	local complexity = tonumber(def.ComplexityLevel) or 1
	local radius = 1.46 + complexity * 0.05
	for index = 1, count do
		local angle = (math.pi * 2) * (index - 1) / count
		local y = ((index % 4) - 1.5) * 0.32
		local color = paletteColor(def, index + 2)
		makePart(
			model,
			"CrystalShard" .. tostring(index),
			Enum.PartType.Block,
			Vector3.new(0.22, 0.46 + complexity * 0.018, 0.22),
			CFrame.new(math.cos(angle) * radius, y, math.sin(angle) * radius)
				* CFrame.Angles(math.rad(45 + index * 11), math.rad(index * 17), math.rad(45)),
			color,
			Enum.Material.Neon,
			0.03
		)
	end
end

local function makeTallSpikes(model, def)
	if not def.HasTallSpikes then
		return
	end

	makeWedge(
		model,
		"TopCrystalSpike",
		Vector3.new(0.62, 1.05, 0.48),
		CFrame.new(0, 1.72, 0) * CFrame.Angles(0, math.rad(45), math.rad(180)),
		def.SecondaryColor,
		0.04
	)
	makeWedge(
		model,
		"BottomCrystalSpike",
		Vector3.new(0.62, 1.05, 0.48),
		CFrame.new(0, -1.72, 0) * CFrame.Angles(0, math.rad(45), 0),
		def.GlowColor,
		0.04
	)
end

local function makeCaps(model, def)
	if not def.HasCaps then
		return
	end

	makePart(
		model,
		"TopRedCap",
		Enum.PartType.Cylinder,
		Vector3.new(0.18, 1.28, 1.28),
		CFrame.new(0, 1.04, 0) * CFrame.Angles(0, 0, math.rad(90)),
		def.MainColor,
		Enum.Material.Neon,
		0.06
	)
	makePart(
		model,
		"BottomRedCap",
		Enum.PartType.Cylinder,
		Vector3.new(0.18, 1.28, 1.28),
		CFrame.new(0, -1.04, 0) * CFrame.Angles(0, 0, math.rad(90)),
		def.MainColor,
		Enum.Material.Neon,
		0.06
	)
end

local function addSparkles(core, def)
	if not def.HasSparkles then
		return
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "PrismaticSparkleAttachment"
	attachment.Parent = core

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "PrismaticSparkles"
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, RAINBOW_COLORS[1]),
		ColorSequenceKeypoint.new(0.18, RAINBOW_COLORS[2]),
		ColorSequenceKeypoint.new(0.35, RAINBOW_COLORS[3]),
		ColorSequenceKeypoint.new(0.52, RAINBOW_COLORS[4]),
		ColorSequenceKeypoint.new(0.68, RAINBOW_COLORS[5]),
		ColorSequenceKeypoint.new(0.84, RAINBOW_COLORS[6]),
		ColorSequenceKeypoint.new(1, RAINBOW_COLORS[7]),
	})
	sparkles.LightEmission = 0.55
	sparkles.LightInfluence = 0.2
	sparkles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.16),
		NumberSequenceKeypoint.new(0.55, 0.08),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparkles.Speed = NumberRange.new(0.35, 1.1)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Lifetime = NumberRange.new(0.75, 1.35)
	sparkles.Rate = 8
	sparkles.Parent = attachment
end

function LegendaryColorOrbBuilder.BuildModel(definition)
	local def = definition
	local model = Instance.new("Model")
	model.Name = def.ModelName
	model:SetAttribute("PetId", def.Id)
	model:SetAttribute("DisplayName", def.DisplayName)
	model:SetAttribute("Rarity", "Legendary")
	model:SetAttribute("WorldNumber", def.WorldNumber)
	model:SetAttribute("ModelName", def.ModelName)
	model:SetAttribute("IsPetTemplate", true)
	model:SetAttribute("IsLegendaryColorOrb", true)
	model:SetAttribute("IsLegendaryColorOrbTemplate", true)

	local complexity = tonumber(def.ComplexityLevel) or 1
	local coreSize = 1.55 + math.min(complexity, 9) * 0.035
	local core = makePart(
		model,
		"Core",
		Enum.PartType.Ball,
		Vector3.new(coreSize, coreSize, coreSize),
		CFrame.new(),
		def.MainColor,
		Enum.Material.Neon,
		def.HasRainbowShell and 0.2 or 0.08
	)
	model.PrimaryPart = core

	makePart(
		model,
		"WhiteHotCore",
		Enum.PartType.Ball,
		Vector3.new(coreSize * 0.46, coreSize * 0.46, coreSize * 0.46),
		CFrame.new(0, 0, 0),
		def.CoreColor or Color3.new(1, 1, 1),
		Enum.Material.Neon,
		0
	)

	makePart(
		model,
		def.HasRainbowShell and "RainbowPrismaticShell" or "SoftGlowShell",
		Enum.PartType.Ball,
		Vector3.new(coreSize * 1.25, coreSize * 1.25, coreSize * 1.25),
		CFrame.new(),
		def.HasRainbowShell and Color3.fromRGB(190, 235, 255) or def.GlowColor,
		def.HasRainbowShell and Enum.Material.ForceField or Enum.Material.Neon,
		def.HasRainbowShell and 0.54 or 0.72
	)

	addLight(core, def.GlowColor, 7 + complexity * 0.65, 1.3 + complexity * 0.16)
	makeCaps(model, def)

	if def.HasHalo then
		makeHalo(model, def, "UpperHalo", 1.08 + complexity * 0.035, 2.25 + complexity * 0.08, def.SecondaryColor, 0)
		makeHalo(model, def, "LowerHalo", -1.08 - complexity * 0.035, 2.1 + complexity * 0.075, def.GlowColor, 0)
	end

	if def.HasRainbowShell then
		for index, color in ipairs(RAINBOW_COLORS) do
			makeHalo(model, def, "RainbowStackedHalo" .. tostring(index), -1.08 + index * 0.36, 2.55 + (index % 3) * 0.16, color, index % 2 == 0 and 8 or -8)
		end
	end

	for ringIndex = 1, tonumber(def.RingCount) or 0 do
		makeRingSegments(model, def, ringIndex)
	end
	makePanels(model, def)
	makeCrystals(model, def)
	makeTallSpikes(model, def)

	local satelliteCount = tonumber(def.SatelliteCount) or 0
	local satelliteRadius = 1.75 + complexity * 0.07
	for index = 1, satelliteCount do
		local angle = (math.pi * 2) * (index - 1) / satelliteCount
		local color = paletteColor(def, index)
		local y = math.sin(angle * 2) * (0.36 + complexity * 0.015)
		local satellite = makePart(
			model,
			"SatelliteOrb" .. tostring(index),
			Enum.PartType.Ball,
			Vector3.new(0.34 + complexity * 0.025, 0.34 + complexity * 0.025, 0.34 + complexity * 0.025),
			CFrame.new(math.cos(angle) * satelliteRadius, y, math.sin(angle) * satelliteRadius),
			color,
			Enum.Material.Neon,
			0
		)
		addLight(satellite, color, 2.8 + complexity * 0.15, 0.35 + complexity * 0.04)
		if def.HasBeamConnections then
			addBeam(core, satellite, color, index)
		end
	end

	local petAttachment = Instance.new("Attachment")
	petAttachment.Name = "PetAttachment"
	petAttachment.Parent = core

	addSparkles(core, def)
	return model
end

function LegendaryColorOrbBuilder.BuildAll(parent, definitions)
	local petModels = parent:FindFirstChild("PetModels")
	if not petModels then
		petModels = Instance.new("Folder")
		petModels.Name = "PetModels"
		petModels.Parent = parent
	end

	local folder = petModels:FindFirstChild("LegendaryColorOrbs")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "LegendaryColorOrbs"
		folder.Parent = petModels
	end

	for _, def in ipairs(definitions) do
		local existing = folder:FindFirstChild(def.ModelName)
		if existing then
			if existing:GetAttribute("IsLegendaryColorOrbTemplate") == true then
				existing:Destroy()
			else
				existing.Name = "Deprecated_" .. existing.Name
			end
		end

		local model = LegendaryColorOrbBuilder.BuildModel(def)
		model.Parent = folder
	end

	return folder
end

return LegendaryColorOrbBuilder
