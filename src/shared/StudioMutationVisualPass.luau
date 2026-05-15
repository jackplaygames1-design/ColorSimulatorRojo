local Workspace = game:GetService("Workspace")

local StudioMutationVisualPass = {}

local SOURCE_NAME = "PetAppearanceStudio"
local GLITCH_COLORS = {
	Color3.fromRGB(255, 35, 105),
	Color3.fromRGB(65, 225, 255),
	Color3.fromRGB(170, 80, 255),
	Color3.fromRGB(40, 255, 120),
}

local function hash(text)
	text = tostring(text or "Color")
	local value = 0
	for i = 1, #text do
		value = (value + string.byte(text, i) * i) % 9973
	end
	return value
end

local function getPrimary(model)
	if model.PrimaryPart then
		return model.PrimaryPart
	end
	local core = model:FindFirstChild("Core", true)
	if core and core:IsA("BasePart") then
		model.PrimaryPart = core
		return core
	end
	local first = model:FindFirstChildWhichIsA("BasePart", true)
	if first then
		model.PrimaryPart = first
		return first
	end
	return nil
end

local function clearGenerated(model)
	for _, obj in ipairs(model:GetDescendants()) do
		if obj:GetAttribute("StudioMutationPolish") == true then
			obj:Destroy()
		end
	end
end

local function mark(obj)
	obj:SetAttribute("StudioMutationPolish", true)
	obj:SetAttribute("PreviewOnly", true)
	return obj
end

local function makePart(parent, name, shape, size, cf, color, material, transparency)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape or Enum.PartType.Block
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material or Enum.Material.Neon
	part.Transparency = transparency or 0
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	mark(part)
	part.Parent = parent
	return part
end

local function makeEmitter(parent, name, colorA, colorB, rate, speedMin, speedMax)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = name
	emitter.Color = ColorSequence.new(colorA, colorB or colorA)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Rate = rate
	emitter.Lifetime = NumberRange.new(0.25, 0.9)
	emitter.Speed = NumberRange.new(speedMin or 1, speedMax or 4)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-220, 220)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.06),
		NumberSequenceKeypoint.new(0.25, 0.24),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.02),
		NumberSequenceKeypoint.new(0.65, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	mark(emitter)
	emitter.Parent = parent
	return emitter
end

local function makeBeam(primary, index, color)
	local a0 = Instance.new("Attachment")
	a0.Name = "PolishGlitchBeamA" .. index
	a0.Position = Vector3.new(math.sin(index * 1.7) * 1.15, -0.55 + index * 0.26, math.cos(index) * 1.15)
	mark(a0)
	a0.Parent = primary

	local a1 = Instance.new("Attachment")
	a1.Name = "PolishGlitchBeamB" .. index
	a1.Position = Vector3.new(math.cos(index * 2.2) * 1.7, 0.8 - index * 0.16, math.sin(index * 1.2) * 1.7)
	mark(a1)
	a1.Parent = primary

	local beam = Instance.new("Beam")
	beam.Name = "PolishGlitchBeam" .. index
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Color = ColorSequence.new(color)
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Width0 = 0.09
	beam.Width1 = 0.015
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.03),
		NumberSequenceKeypoint.new(0.55, 0.32),
		NumberSequenceKeypoint.new(1, 1),
	})
	mark(beam)
	beam.Parent = primary
	return beam
end

local function addUniqueColorAccent(model, primary)
	local h = hash(model:GetAttribute("PetId") or model.Name)
	local cf = primary.CFrame
	local base = primary.Color
	local accent = base:Lerp(Color3.fromRGB(255, 255, 255), 0.45)
	local style = (h % 6) + 1

	if style == 1 then
		makePart(
			model,
			"UniqueOrbitRing",
			Enum.PartType.Cylinder,
			Vector3.new(0.045, 2.65, 2.65),
			cf * CFrame.Angles(0, 0, math.rad(90)),
			accent,
			Enum.Material.Neon,
			0.22
		)
	elseif style == 2 then
		makePart(
			model,
			"UniqueCrownA",
			Enum.PartType.Block,
			Vector3.new(0.2, 0.48, 0.2),
			cf * CFrame.new(-0.45, 1.05, 0),
			accent,
			Enum.Material.Neon,
			0.04
		)
		makePart(
			model,
			"UniqueCrownB",
			Enum.PartType.Block,
			Vector3.new(0.2, 0.66, 0.2),
			cf * CFrame.new(0, 1.22, 0),
			accent,
			Enum.Material.Neon,
			0.04
		)
		makePart(
			model,
			"UniqueCrownC",
			Enum.PartType.Block,
			Vector3.new(0.2, 0.48, 0.2),
			cf * CFrame.new(0.45, 1.05, 0),
			accent,
			Enum.Material.Neon,
			0.04
		)
	elseif style == 3 then
		makePart(
			model,
			"UniqueSideGemL",
			Enum.PartType.Ball,
			Vector3.new(0.34, 0.34, 0.34),
			cf * CFrame.new(-1.2, 0.12, 0),
			accent,
			Enum.Material.Neon,
			0.04
		)
		makePart(
			model,
			"UniqueSideGemR",
			Enum.PartType.Ball,
			Vector3.new(0.34, 0.34, 0.34),
			cf * CFrame.new(1.2, 0.12, 0),
			accent,
			Enum.Material.Neon,
			0.04
		)
	elseif style == 4 then
		makePart(
			model,
			"UniqueSlashA",
			Enum.PartType.Block,
			Vector3.new(0.08, 1.8, 0.08),
			cf * CFrame.new(-0.35, 0, -0.9) * CFrame.Angles(0, 0, math.rad(-24)),
			accent,
			Enum.Material.Neon,
			0.1
		)
		makePart(
			model,
			"UniqueSlashB",
			Enum.PartType.Block,
			Vector3.new(0.08, 1.3, 0.08),
			cf * CFrame.new(0.42, 0, -0.9) * CFrame.Angles(0, 0, math.rad(-24)),
			accent,
			Enum.Material.Neon,
			0.1
		)
	elseif style == 5 then
		makePart(
			model,
			"UniqueBottomGlow",
			Enum.PartType.Cylinder,
			Vector3.new(0.045, 2.35, 2.35),
			cf * CFrame.new(0, -0.95, 0) * CFrame.Angles(0, 0, math.rad(90)),
			accent,
			Enum.Material.Neon,
			0.3
		)
	else
		makePart(
			model,
			"UniqueSparkA",
			Enum.PartType.Ball,
			Vector3.new(0.22, 0.22, 0.22),
			cf * CFrame.new(-0.72, 0.72, 0.82),
			Color3.fromRGB(255, 255, 255),
			Enum.Material.Neon,
			0.04
		)
		makePart(
			model,
			"UniqueSparkB",
			Enum.PartType.Ball,
			Vector3.new(0.18, 0.18, 0.18),
			cf * CFrame.new(0.82, -0.2, 0.88),
			accent,
			Enum.Material.Neon,
			0.04
		)
	end
end

local function addCorruptedPolish(model, primary)
	local cf = primary.CFrame
	local light = primary:FindFirstChild("PolishCorruptedLight") or Instance.new("PointLight")
	light.Name = "PolishCorruptedLight"
	light.Color = Color3.fromRGB(255, 35, 105)
	light.Brightness = 3.5
	light.Range = 16
	light.Shadows = false
	mark(light)
	light.Parent = primary

	makeEmitter(primary, "RGBPixelTearParticles", GLITCH_COLORS[1], GLITCH_COLORS[2], 28, 1.8, 5)
	makeEmitter(primary, "PurpleStaticParticles", GLITCH_COLORS[3], GLITCH_COLORS[4], 16, 0.8, 3.5)

	for i = 1, 4 do
		makeBeam(primary, i, GLITCH_COLORS[((i - 1) % #GLITCH_COLORS) + 1])
	end

	for i = 1, 8 do
		local angle = (math.pi * 2 / 8) * i
		local radius = 1.35 + (i % 3) * 0.18
		local color = GLITCH_COLORS[((i - 1) % #GLITCH_COLORS) + 1]
		makePart(
			model,
			"FloatingGlitchPixel" .. i,
			Enum.PartType.Block,
			Vector3.new(0.12 + i * 0.008, 0.35 + (i % 2) * 0.18, 0.08),
			cf
				* CFrame.new(math.cos(angle) * radius, -0.55 + i * 0.18, math.sin(angle) * radius)
				* CFrame.Angles(math.rad(i * 17), math.rad(i * 31), math.rad(i * 11)),
			color,
			Enum.Material.Neon,
			0.03
		)
	end

	makePart(
		model,
		"PolishOffsetErrorRing",
		Enum.PartType.Cylinder,
		Vector3.new(0.05, 2.55, 2.55),
		cf * CFrame.Angles(math.rad(-18), math.rad(40), math.rad(90)),
		GLITCH_COLORS[2],
		Enum.Material.Neon,
		0.24
	)
end

local function addLightPolish(primary)
	makeEmitter(
		primary,
		"SoftSparklePolish",
		Color3.fromRGB(255, 255, 210),
		Color3.fromRGB(255, 230, 105),
		14,
		0.7,
		2.8
	)
end

local function addDarkPolish(primary)
	makeEmitter(primary, "DarkMistPolish", Color3.fromRGB(38, 10, 75), Color3.fromRGB(120, 45, 190), 10, 0.2, 1.2)
end

local function polishModel(model)
	if not model:IsA("Model") then
		return false
	end
	local primary = getPrimary(model)
	if not primary then
		return false
	end

	clearGenerated(model)
	addUniqueColorAccent(model, primary)

	local mutationId = tostring(model:GetAttribute("MutationId") or model.Name)
	local mutationType = tostring(model:GetAttribute("MutationType") or "")
	local lower = string.lower(mutationId .. " " .. mutationType .. " " .. model.Name)

	if
		string.find(lower, "glitch")
		or string.find(lower, "corrupt")
		or string.find(lower, "error")
		or string.find(lower, "virus")
		or string.find(lower, "rift")
		or string.find(lower, "anomaly")
	then
		addCorruptedPolish(model, primary)
	elseif
		string.find(lower, "glimmer")
		or string.find(lower, "light")
		or string.find(lower, "angel")
		or string.find(lower, "prism")
	then
		addLightPolish(primary)
	elseif
		string.find(lower, "shadow")
		or string.find(lower, "dark")
		or string.find(lower, "void")
		or string.find(lower, "abyss")
	then
		addDarkPolish(primary)
	end

	return true
end

function StudioMutationVisualPass.Apply()
	local source = Workspace:FindFirstChild(SOURCE_NAME)
	if not source then
		warn(
			"StudioMutationVisualPass: Workspace."
				.. SOURCE_NAME
				.. " was not found. Run StudioPetAppearanceBuilder.Build() first."
		)
		return 0
	end

	local count = 0
	for _, obj in ipairs(source:GetDescendants()) do
		if obj:IsA("Model") and getPrimary(obj) then
			if polishModel(obj) then
				count += 1
			end
		end
	end

	print(
		"StudioMutationVisualPass: polished "
			.. tostring(count)
			.. " Studio color models with unique accents and mutation particles."
	)
	return count
end

StudioMutationVisualPass.Run = StudioMutationVisualPass.Apply

return StudioMutationVisualPass
