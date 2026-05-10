-- ModuleScript in ReplicatedStorage named "StudioZoneBuilder".
-- Run in Studio edit mode from the command bar:
-- require(game.ReplicatedStorage.StudioZoneBuilder).BuildEditableStarterMap()
--
-- Legacy full-world builder:
-- require(game.ReplicatedStorage.StudioZoneBuilder).build()
--
-- This creates editable Workspace parts for each world. It does not run by itself.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local ColorData = require(ReplicatedStorage:WaitForChild("ColorData"))
local PetData = require(ReplicatedStorage:WaitForChild("PetData"))
local UpdateLogData = require(ReplicatedStorage:WaitForChild("UpdateLogData"))
local GroupRewardsConfig = require(ReplicatedStorage:WaitForChild("GroupRewardsConfig"))

local StudioZoneBuilder = {}

local MAP_NAME = "ColorSimulatorMap"
local ZONE_SIZE = Vector3.new(300, 1, 300)
local ZONE_SPACING = 430
local WALL_HEIGHT = 170
local WALL_THICKNESS = 28
local GATE_WIDTH = 48
local GATE_HEIGHT = 44
local GATE_DEPTH = 8
local GATE_SURFACE_OFFSET = 0.25
local GATE_INTERACTION_DISTANCE = 30
local GATE_INTERACTION_ZONE_NAME = "GateInteractionZone"
local COMPACT_ZONE_SPACING = 365
local BIG_WORLD_SIZE = 420
local BIG_WORLD_GAP = 10
local currentOptions = {}

local THEME = {
	Red = {
		color = Color3.fromRGB(210, 82, 82),
		material = Enum.Material.SmoothPlastic,
		accent = Color3.fromRGB(150, 70, 70),
	},
	Blue = {
		color = Color3.fromRGB(72, 132, 210),
		material = Enum.Material.Sand,
		accent = Color3.fromRGB(80, 125, 170),
	},
	Yellow = {
		color = Color3.fromRGB(215, 190, 76),
		material = Enum.Material.Sand,
		accent = Color3.fromRGB(155, 135, 70),
	},
	Green = {
		color = Color3.fromRGB(82, 175, 95),
		material = Enum.Material.Grass,
		accent = Color3.fromRGB(70, 125, 78),
	},
	Purple = {
		color = Color3.fromRGB(132, 82, 185),
		material = Enum.Material.Slate,
		accent = Color3.fromRGB(105, 70, 145),
	},
	Neon = {
		color = Color3.fromRGB(46, 170, 150),
		material = Enum.Material.SmoothPlastic,
		accent = Color3.fromRGB(30, 115, 108),
	},
	Rainbow = {
		color = Color3.fromRGB(178, 190, 215),
		material = Enum.Material.SmoothPlastic,
		accent = Color3.fromRGB(135, 110, 165),
	},
}

local EGG_BY_WORLD = {
	Red = "ColorEgg",
	Blue = "BlueEgg",
	Yellow = "YellowEgg",
	Green = "GreenEgg",
	Purple = "PurpleEgg",
	Neon = "NeonEgg",
	Rainbow = "RainbowEgg",
}

local WALL_PANEL_COLORS = {
	Color3.fromRGB(255, 75, 95),
	Color3.fromRGB(255, 210, 75),
	Color3.fromRGB(85, 230, 125),
	Color3.fromRGB(85, 190, 255),
	Color3.fromRGB(180, 95, 255),
	Color3.fromRGB(255, 110, 220),
	Color3.fromRGB(95, 245, 235),
}

local TEST_PLAZA_COLORS = {
	grass = Color3.fromRGB(92, 184, 88),
	grassDark = Color3.fromRGB(45, 130, 70),
	path = Color3.fromRGB(218, 176, 122),
	pathEdge = Color3.fromRGB(190, 148, 105),
	stone = Color3.fromRGB(196, 210, 224),
	dark = Color3.fromRGB(35, 42, 58),
	blue = Color3.fromRGB(70, 135, 215),
	cyan = Color3.fromRGB(115, 214, 220),
	purple = Color3.fromRGB(148, 100, 214),
	yellow = Color3.fromRGB(236, 196, 82),
	orange = Color3.fromRGB(218, 142, 58),
	green = Color3.fromRGB(98, 196, 120),
	pink = Color3.fromRGB(232, 120, 184),
	red = Color3.fromRGB(232, 76, 78),
	white = Color3.fromRGB(218, 230, 242),
}

local SOFT_NEON_WHITE = Color3.fromRGB(175, 245, 238)

local function clearExistingMap()
	local existing = workspace:FindFirstChild(MAP_NAME)
	if existing then
		existing:Destroy()
	end
end

local function makeFolder(parent, name)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function makePart(parent, name, size, position, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Parent = parent
	return part
end

local function makeBillboard(parent, text, offset, size)
	if not currentOptions.showLabels then
		return nil
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = size or UDim2.new(0, 260, 0, 70)
	billboard.StudsOffset = offset or Vector3.new(0, 8, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(35, 38, 45)
	label.Text = text
	label.Parent = billboard
end

local function makeWallPanel(parent, name, size, position, color)
	local panel = makePart(parent, name, size, position, color, Enum.Material.Neon)
	panel.CanCollide = false
	panel.CastShadow = false
	panel:SetAttribute("WallColorBlock", true)
	return panel
end

local function makeWallPanels(parent, colorType, center, theme)
	local halfX = ZONE_SIZE.X / 2
	local halfZ = ZONE_SIZE.Z / 2
	local wallSpecs = {
		{ name = "North", axis = "X", z = -halfZ + 0.65 },
		{ name = "South", axis = "X", z = halfZ - 0.65 },
		{ name = "West", axis = "Z", x = -halfX + 0.65 },
		{ name = "East", axis = "Z", x = halfX - 0.65 },
	}

	for wallIndex, spec in ipairs(wallSpecs) do
		for i = 1, 12 do
			local lane = (i - 6.5) * 22
			local height = 16 + ((i + wallIndex) % 4) * 8
			local width = 14 + ((i * 3 + wallIndex) % 5) * 7
			local y = 20 + ((i * 17 + wallIndex * 11) % 115)
			local paletteColor = WALL_PANEL_COLORS[((i + wallIndex + (ColorData.getWorldIndex(colorType) or 1)) - 1) % #WALL_PANEL_COLORS + 1]
			local color = paletteColor:Lerp(theme.color, 0.25)
			local size
			local position

			if spec.axis == "X" then
				size = Vector3.new(width, height, 1.2)
				position = center + Vector3.new(lane, y, spec.z)
			else
				size = Vector3.new(1.2, height, width)
				position = center + Vector3.new(spec.x, y, lane)
			end

			makeWallPanel(parent, colorType .. spec.name .. "ColorBlock" .. i, size, position, color)
		end
	end
end

local function makeZoneDecor(parent, colorType, center, theme)
	local ringColor = theme.accent
	local halfX = ZONE_SIZE.X / 2
	local halfZ = ZONE_SIZE.Z / 2

	local wallColor = ringColor:Lerp(Color3.fromRGB(245, 248, 255), 0.28)
	local north = makePart(parent, colorType .. "NorthWall", Vector3.new(ZONE_SIZE.X + WALL_THICKNESS * 2, WALL_HEIGHT, WALL_THICKNESS), center + Vector3.new(0, WALL_HEIGHT / 2, -halfZ - WALL_THICKNESS / 2), wallColor, Enum.Material.SmoothPlastic)
	local south = makePart(parent, colorType .. "SouthWall", Vector3.new(ZONE_SIZE.X + WALL_THICKNESS * 2, WALL_HEIGHT, WALL_THICKNESS), center + Vector3.new(0, WALL_HEIGHT / 2, halfZ + WALL_THICKNESS / 2), wallColor, Enum.Material.SmoothPlastic)
	local west = makePart(parent, colorType .. "WestWall", Vector3.new(WALL_THICKNESS, WALL_HEIGHT, ZONE_SIZE.Z + WALL_THICKNESS * 2), center + Vector3.new(-halfX - WALL_THICKNESS / 2, WALL_HEIGHT / 2, 0), wallColor, Enum.Material.SmoothPlastic)
	local east = makePart(parent, colorType .. "EastWall", Vector3.new(WALL_THICKNESS, WALL_HEIGHT, ZONE_SIZE.Z + WALL_THICKNESS * 2), center + Vector3.new(halfX + WALL_THICKNESS / 2, WALL_HEIGHT / 2, 0), wallColor, Enum.Material.SmoothPlastic)
	for _, wall in ipairs({ north, south, west, east }) do
		wall.Transparency = 0
		wall.CastShadow = false
		wall:SetAttribute("WorldBarrier", true)
		wall:SetAttribute("ColorType", colorType)
	end

	makePart(parent, colorType .. "NorthTrim", Vector3.new(ZONE_SIZE.X, 3, 4), center + Vector3.new(0, 2.5, -halfZ), ringColor, Enum.Material.SmoothPlastic).Transparency = 0.08
	makePart(parent, colorType .. "SouthTrim", Vector3.new(ZONE_SIZE.X, 3, 4), center + Vector3.new(0, 2.5, halfZ), ringColor, Enum.Material.SmoothPlastic).Transparency = 0.08
	makePart(parent, colorType .. "WestTrim", Vector3.new(4, 3, ZONE_SIZE.Z), center + Vector3.new(-halfX, 2.5, 0), ringColor, Enum.Material.SmoothPlastic).Transparency = 0.08
	makePart(parent, colorType .. "EastTrim", Vector3.new(4, 3, ZONE_SIZE.Z), center + Vector3.new(halfX, 2.5, 0), ringColor, Enum.Material.SmoothPlastic).Transparency = 0.08

	makeWallPanels(parent, colorType, center, theme)
end

local function makeEgg(parent, world, center, theme)
	local eggId = EGG_BY_WORLD[world.primaryColor]
	local eggData = eggId and PetData.Eggs[eggId]
	if not eggData then
		return
	end

	local eggOffset = world.primaryColor == "Red" and Vector3.new(62, 8.5, 82) or Vector3.new(88, 7.5, -96)
	local egg = makePart(parent, eggId, Vector3.new(12, 15, 12), center + eggOffset, eggData.color or theme.accent, Enum.Material.SmoothPlastic)
	egg.Shape = Enum.PartType.Ball
	egg:SetAttribute("EggId", eggId)
	egg:SetAttribute("ColorType", world.primaryColor)
	egg:SetAttribute("AreaColor", world.primaryColor)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EggShopPrompt"
	prompt.ActionText = "Hatch"
	prompt.ObjectText = "Egg"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt:SetAttribute("EggShopPrompt", true)
	prompt.Parent = egg

	makeBillboard(egg, eggData.displayName or eggId, Vector3.new(0, 8, 0), UDim2.new(0, 220, 0, 52))
end

local function getFlatDirection(fromCenter, toCenter)
	local delta = Vector3.new(toCenter.X - fromCenter.X, 0, toCenter.Z - fromCenter.Z)
	if delta.Magnitude < 0.001 then
		return Vector3.new(1, 0, 0)
	end
	return delta.Unit
end

local function getZoneHalfExtentAlong(zone, direction)
	if not zone then
		return ZONE_SIZE.X / 2
	end

	return math.abs(direction.X) * zone.Size.X / 2 + math.abs(direction.Z) * zone.Size.Z / 2
end

local function getWallGateCFrame(previousZone, currentZone, height, depth)
	height = height or GATE_HEIGHT
	depth = depth or GATE_DEPTH

	local previousCenter = previousZone and previousZone.Position or Vector3.zero
	local currentCenter = currentZone and currentZone.Position or previousCenter + Vector3.new(ZONE_SPACING, 0, 0)
	local direction = getFlatDirection(previousCenter, currentCenter)
	local halfExtent = getZoneHalfExtentAlong(previousZone, direction)
	local groundY = previousCenter.Y + ((previousZone and previousZone.Size.Y or ZONE_SIZE.Y) / 2)
	local position = Vector3.new(previousCenter.X, groundY + height / 2, previousCenter.Z)
		+ direction * (halfExtent + depth / 2 + GATE_SURFACE_OFFSET)

	return CFrame.lookAt(position, position - direction), direction
end

local function setPartLocal(part, rootCFrame, size, localOffset, color, material)
	if not part then
		return
	end

	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Size = size
	part.CFrame = rootCFrame * CFrame.new(localOffset)
	if color then
		part.Color = color
	end
	if material then
		part.Material = material
	end
end

local function ensureGateInteractionZone(gate, world, gateWidth, gateHeight, gateDepth)
	local zone = gate:FindFirstChild(GATE_INTERACTION_ZONE_NAME)
	if not zone then
		zone = Instance.new("Part")
		zone.Name = GATE_INTERACTION_ZONE_NAME
		zone.Parent = gate
	end

	local width = math.max(24, gateWidth + 24)
	local height = 14
	local depth = 26
	zone.Anchored = true
	zone.CanCollide = false
	zone.CanTouch = false
	zone.CanQuery = false
	zone.CastShadow = false
	zone.Transparency = 1
	zone.Size = Vector3.new(width, height, depth)
	zone.CFrame = gate.CFrame * CFrame.new(0, -gateHeight / 2 + height / 2 + 2, -(gateDepth / 2 + depth / 2 + 4))
	zone:SetAttribute("GateInteraction", true)
	zone:SetAttribute("GateColor", world.primaryColor)
	zone:SetAttribute("UnlockColor", world.primaryColor)
	zone:SetAttribute("ColorType", world.primaryColor)
	return zone
end

local function ensureGatePrompt(gate, world, gateWidth, gateHeight, gateDepth)
	local zone = ensureGateInteractionZone(gate, world, gateWidth, gateHeight, gateDepth)
	local existingPrompt = gate:FindFirstChild("GatePrompt")
	if existingPrompt and existingPrompt.Parent ~= zone then
		existingPrompt.Parent = zone
	end

	local prompt = zone:FindFirstChild("GatePrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "GatePrompt"
		prompt.Parent = zone
	end

	prompt.ActionText = "Unlock"
	prompt.ObjectText = world.name .. " - " .. tostring(world.unlockCost) .. " Coins"
	prompt.HoldDuration = 0.1
	prompt.MaxActivationDistance = GATE_INTERACTION_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt:SetAttribute("AreaGatePrompt", true)
	return prompt
end

local function makeSpawn(parent, world, center, theme)
	local spawn = makePart(parent, world.primaryColor .. "Spawn", Vector3.new(18, 1, 18), center + Vector3.new(-105, 1, -105), theme.accent, Enum.Material.SmoothPlastic)
	spawn:SetAttribute("AreaSpawn", true)
	spawn:SetAttribute("AreaSpawnColor", world.primaryColor)
	spawn:SetAttribute("SpawnColor", world.primaryColor)
	spawn:SetAttribute("TeleportColor", world.primaryColor)
	spawn:SetAttribute("ColorType", world.primaryColor)
	makeBillboard(spawn, "SPAWN", Vector3.new(0, 5, 0), UDim2.new(0, 120, 0, 42))
	return spawn
end

local function makeGate(parent, world, previousCenter, currentCenter, previousZone, currentZone)
	local worldColor = ColorData.Colors[world.primaryColor] and ColorData.Colors[world.primaryColor].color or Color3.fromRGB(120, 220, 255)
	local fallbackPreviousZone = previousZone or { Position = previousCenter, Size = ZONE_SIZE }
	local fallbackCurrentZone = currentZone or { Position = currentCenter, Size = ZONE_SIZE }
	local gateCFrame = getWallGateCFrame(fallbackPreviousZone, fallbackCurrentZone, GATE_HEIGHT, GATE_DEPTH)
	local gate = makePart(parent, world.primaryColor .. "Gate", Vector3.new(GATE_WIDTH, GATE_HEIGHT, GATE_DEPTH), gateCFrame.Position, worldColor:Lerp(Color3.fromRGB(35, 38, 45), 0.45), Enum.Material.SmoothPlastic)
	gate.CFrame = gateCFrame
	gate.Transparency = 0.18
	gate:SetAttribute("AreaGate", true)
	gate:SetAttribute("GateColor", world.primaryColor)
	gate:SetAttribute("UnlockColor", world.primaryColor)
	gate:SetAttribute("ColorType", world.primaryColor)

	ensureGatePrompt(gate, world, GATE_WIDTH, GATE_HEIGHT, GATE_DEPTH)

	local frameColor = Color3.fromRGB(35, 38, 65)
	local leftPost = makePart(parent, world.primaryColor .. "GateLeftPost", Vector3.new(7, GATE_HEIGHT + 8, GATE_DEPTH + 2), gateCFrame.Position, frameColor, Enum.Material.SmoothPlastic)
	local rightPost = makePart(parent, world.primaryColor .. "GateRightPost", Vector3.new(7, GATE_HEIGHT + 8, GATE_DEPTH + 2), gateCFrame.Position, frameColor, Enum.Material.SmoothPlastic)
	local topBeam = makePart(parent, world.primaryColor .. "GateTopBeam", Vector3.new(GATE_WIDTH + 10, 7, GATE_DEPTH + 2), gateCFrame.Position, frameColor, Enum.Material.SmoothPlastic)
	setPartLocal(leftPost, gateCFrame, leftPost.Size, Vector3.new(-GATE_WIDTH / 2 - 3.5, 0, 0), frameColor, Enum.Material.SmoothPlastic)
	setPartLocal(rightPost, gateCFrame, rightPost.Size, Vector3.new(GATE_WIDTH / 2 + 3.5, 0, 0), frameColor, Enum.Material.SmoothPlastic)
	setPartLocal(topBeam, gateCFrame, topBeam.Size, Vector3.new(0, GATE_HEIGHT / 2 + 3.5, 0), frameColor, Enum.Material.SmoothPlastic)
	for _, part in ipairs({ leftPost, rightPost, topBeam }) do
		part:SetAttribute("GateDecor", true)
		part:SetAttribute("ColorType", world.primaryColor)
	end

	for i = 1, 3 do
		local stripeSize = Vector3.new(2, 30 - i * 4, GATE_DEPTH + 1)
		local stripeOffset = Vector3.new((i - 2) * 11, 0, -GATE_DEPTH / 2 - 0.45)
		local stripe = makePart(parent, world.primaryColor .. "GateGlow" .. i, stripeSize, gateCFrame.Position, worldColor:Lerp(Color3.fromRGB(255, 255, 255), i * 0.18), Enum.Material.Neon)
		setPartLocal(stripe, gateCFrame, stripeSize, stripeOffset, worldColor:Lerp(Color3.fromRGB(255, 255, 255), i * 0.18), Enum.Material.Neon)
		stripe.Transparency = 0.35 + i * 0.12
		stripe.CanCollide = false
		stripe:SetAttribute("GateDecor", true)
		stripe:SetAttribute("ColorType", world.primaryColor)
	end

	return gate
end

local function makeSellZone(parent, world, center, index)
	local colorType = world.primaryColor
	local sell = makePart(parent, "World" .. tostring(index) .. "_Sell", Vector3.new(24, 1, 24), center + Vector3.new(-34, 1, 74), Color3.fromRGB(88, 190, 72), Enum.Material.SmoothPlastic)
	sell:SetAttribute("SellZone", true)
	sell:SetAttribute("SellLocation", true)
	sell:SetAttribute("ColorType", colorType)
	sell:SetAttribute("AreaColor", colorType)
	sell:SetAttribute("SellColor", colorType)
	makeBillboard(sell, "SELL", Vector3.new(0, 5, 0), UDim2.new(0, 130, 0, 46))
	return sell
end

local function clearLightingEffects()
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:GetAttribute("ColorSimulatorSky") then
			child:Destroy()
		end
	end
end

function StudioZoneBuilder.applySky()
	clearLightingEffects()

	Lighting.Brightness = 3
	Lighting.ClockTime = 14
	Lighting.ExposureCompensation = 0.1
	Lighting.EnvironmentDiffuseScale = 0.45
	Lighting.EnvironmentSpecularScale = 0.65
	Lighting.Ambient = Color3.fromRGB(150, 165, 210)
	Lighting.OutdoorAmbient = Color3.fromRGB(190, 205, 235)
	Lighting.FogColor = Color3.fromRGB(190, 210, 245)
	Lighting.FogStart = 650
	Lighting.FogEnd = 1800

	local sky = Instance.new("Sky")
	sky.Name = "ColorSimulatorPastelSky"
	sky.SkyboxBk = "rbxassetid://6444884337"
	sky.SkyboxDn = "rbxassetid://6444884785"
	sky.SkyboxFt = "rbxassetid://6444884337"
	sky.SkyboxLf = "rbxassetid://6444884337"
	sky.SkyboxRt = "rbxassetid://6444884337"
	sky.SkyboxUp = "rbxassetid://6412503613"
	sky.SunAngularSize = 8
	sky.MoonAngularSize = 0
	sky.StarCount = 0
	sky:SetAttribute("ColorSimulatorSky", true)
	sky.Parent = Lighting

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "ColorSimulatorAtmosphere"
	atmosphere.Color = Color3.fromRGB(185, 210, 255)
	atmosphere.Decay = Color3.fromRGB(255, 180, 225)
	atmosphere.Density = 0.22
	atmosphere.Offset = 0.15
	atmosphere.Glare = 0.1
	atmosphere.Haze = 1.2
	atmosphere:SetAttribute("ColorSimulatorSky", true)
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Name = "ColorSimulatorBloom"
	bloom.Intensity = 0.35
	bloom.Size = 24
	bloom.Threshold = 1.2
	bloom:SetAttribute("ColorSimulatorSky", true)
	bloom.Parent = Lighting

	local colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Name = "ColorSimulatorColor"
	colorCorrection.Brightness = 0.02
	colorCorrection.Contrast = 0.08
	colorCorrection.Saturation = 0.18
	colorCorrection.TintColor = Color3.fromRGB(255, 245, 255)
	colorCorrection:SetAttribute("ColorSimulatorSky", true)
	colorCorrection.Parent = Lighting

	print("StudioZoneBuilder: applied colorful sky and lighting.")
end

function StudioZoneBuilder.build(options)
	options = options or {}
	currentOptions = options

	if RunService:IsRunning() and not options.allowDuringPlay then
		warn("StudioZoneBuilder: run this in Studio edit mode, not while the game is playing.")
		return nil
	end

	local existing = workspace:FindFirstChild(MAP_NAME)
	if existing and not options.overwrite then
		warn("StudioZoneBuilder: " .. MAP_NAME .. " already exists. Use .build({ overwrite = true }) to rebuild it.")
		return existing
	end

	if options.overwrite then
		clearExistingMap()
	end

	local map = Instance.new("Folder")
	map.Name = MAP_NAME
	map.Parent = workspace

	local zones = makeFolder(map, "Zones")
	local spawns = makeFolder(map, "Spawns")
	local eggs = makeFolder(map, "Eggs")
	local gates = makeFolder(map, "Gates")
	local decor = makeFolder(map, "BuildDecor")

	if options.applySky ~= false then
		StudioZoneBuilder.applySky()
	end

	local previousCenter = nil
	local previousZone = nil
	for index, world in ipairs(ColorData.Worlds) do
		local colorType = world.primaryColor
		local theme = THEME[colorType] or {
			color = ColorData.Colors[colorType] and ColorData.Colors[colorType].color or Color3.new(1, 1, 1),
			material = Enum.Material.SmoothPlastic,
			accent = Color3.new(1, 1, 1),
		}

		local buildSpacing = tonumber(options.spacing) or ZONE_SPACING
		local center = Vector3.new((index - 1) * buildSpacing, 0, 0)
		local zone = makePart(zones, colorType .. "Zone", ZONE_SIZE, center, theme.color, theme.material)
		zone.Transparency = 0
		zone:SetAttribute("ColorZone", true)
		zone:SetAttribute("ColorType", colorType)
		zone:SetAttribute("WorldId", world.id)
		zone:SetAttribute("WorldName", world.name)
		zone:SetAttribute("RewardMultiplier", world.rewardMultiplier or math.max(1, world.breakableHealth / 10))
		zone:SetAttribute("BlobCount", world.blobCount or 32)

		makeBillboard(zone, string.upper(world.name), Vector3.new(0, 10, 0))
		makeZoneDecor(decor, colorType, center, theme)
		makeSpawn(spawns, world, center, theme)
		makeEgg(eggs, world, center, theme)

		makeSellZone(zones, world, center, index)
		if index > 1 and previousCenter then
			makeGate(gates, world, previousCenter, center, previousZone, zone)
		end

		previousCenter = center
		previousZone = zone
	end

	print("StudioZoneBuilder: created " .. MAP_NAME .. " with editable zones, gates, spawns, eggs, and sell zone.")
	return map
end

function StudioZoneBuilder.toneDownExisting()
	local map = workspace:FindFirstChild(MAP_NAME)
	if not map then
		warn("StudioZoneBuilder: no " .. MAP_NAME .. " found to tone down.")
		return nil
	end

	for _, obj in ipairs(map:GetDescendants()) do
		if obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
			obj:Destroy()
		elseif obj:IsA("BasePart") then
			local colorType = obj:GetAttribute("ColorType")
			local theme = colorType and THEME[colorType]

			if obj:GetAttribute("ColorZone") and theme then
				obj.Color = theme.color
				obj.Material = theme.material
				obj.Transparency = 0
			elseif obj:GetAttribute("AreaGate") then
				obj.Color = Color3.fromRGB(75, 82, 105)
				obj.Material = Enum.Material.Glass
				obj.Transparency = 0.25
			elseif obj:GetAttribute("AreaSpawn") and theme then
				obj.Color = theme.accent
				obj.Material = Enum.Material.SmoothPlastic
				obj.Transparency = 0
			elseif obj:GetAttribute("EggId") then
				obj.Material = Enum.Material.SmoothPlastic
				obj.Transparency = 0
			elseif obj.Name == "SellZone" then
				obj.Color = Color3.fromRGB(88, 190, 72)
				obj.Material = Enum.Material.SmoothPlastic
				obj.Transparency = 0
			elseif obj:GetAttribute("WorldBarrier") and theme then
				obj.Color = theme.accent:Lerp(Color3.fromRGB(245, 248, 255), 0.28)
				obj.Material = Enum.Material.SmoothPlastic
				obj.Transparency = 0
			elseif string.find(obj.Name, "Border") or string.find(obj.Name, "Trim") or string.find(obj.Name, "BuildMarker") then
				if theme then
					obj.Color = theme.accent
				end
				obj.Material = Enum.Material.SmoothPlastic
				obj.Transparency = string.find(obj.Name, "Trim") and 0.08 or 0.25
			end
		end
	end

	print("StudioZoneBuilder: toned down " .. MAP_NAME .. " and removed builder labels.")
	return map
end

function StudioZoneBuilder.coolifyExisting()
	local map = workspace:FindFirstChild(MAP_NAME)
	if not map then
		warn("StudioZoneBuilder: no " .. MAP_NAME .. " found. Run .build({ overwrite = true }) first.")
		return nil
	end

	local decor = map:FindFirstChild("BuildDecor")
	if not decor then
		decor = Instance.new("Folder")
		decor.Name = "BuildDecor"
		decor.Parent = map
	end

	for _, obj in ipairs(map:GetDescendants()) do
		if obj:IsA("BasePart") and (string.find(obj.Name, "BuildMarker") or obj:GetAttribute("WallColorBlock")) then
			obj:Destroy()
		end
	end

	for _, zone in ipairs(map:GetDescendants()) do
		if zone:IsA("BasePart") and zone:GetAttribute("ColorZone") then
			local colorType = zone:GetAttribute("ColorType") or "Red"
			local theme = THEME[colorType] or {
				color = ColorData.Colors[colorType] and ColorData.Colors[colorType].color or Color3.new(1, 1, 1),
				material = Enum.Material.SmoothPlastic,
				accent = Color3.new(1, 1, 1),
			}
			makeWallPanels(decor, colorType, zone.Position, theme)
		end
	end

	print("StudioZoneBuilder: removed floor markers and added wall color blocks.")
	return map
end

local function makeBlock(parent, name, size, cframe, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Parent = parent
	return part
end

local function makeTestLabel(parent, text, subtitle, offset, size)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "BlockoutLabel"
	billboard.Size = size or UDim2.new(0, 280, 0, subtitle and 80 or 54)
	billboard.StudsOffset = offset or Vector3.new(0, 6, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 220
	billboard.Parent = parent

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, subtitle and 42 or 54)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.LuckiestGuy
	title.TextScaled = true
	title.TextColor3 = TEST_PLAZA_COLORS.white
	title.TextStrokeTransparency = 0
	title.TextStrokeColor3 = TEST_PLAZA_COLORS.dark
	title.Text = text
	title.Parent = billboard

	if subtitle then
		local sub = Instance.new("TextLabel")
		sub.Size = UDim2.new(1, 0, 0, 24)
		sub.Position = UDim2.new(0, 0, 0, 44)
		sub.BackgroundTransparency = 1
		sub.Font = Enum.Font.GothamBold
		sub.TextSize = 15
		sub.TextColor3 = Color3.fromRGB(230, 245, 255)
		sub.TextStrokeTransparency = 0.12
		sub.TextStrokeColor3 = TEST_PLAZA_COLORS.dark
		sub.Text = subtitle
		sub.Parent = billboard
	end

	return billboard
end

local function makeCylinder(parent, name, radius, height, cframe, color, material)
	local part = makeBlock(parent, name, Vector3.new(radius * 2, height, radius * 2), cframe, color, material)
	part.Shape = Enum.PartType.Cylinder
	part.CFrame = cframe * CFrame.Angles(0, 0, math.rad(90))
	return part
end

local function makeTree(parent, name, position, scale)
	scale = scale or 1
	local trunk = makeBlock(parent, name .. "Trunk", Vector3.new(4 * scale, 18 * scale, 4 * scale), CFrame.new(position + Vector3.new(0, 9 * scale, 0)), Color3.fromRGB(132, 86, 45), Enum.Material.Wood)
	trunk:SetAttribute("TestPlazaDecor", true)
	local leaves = makeBlock(parent, name .. "Leaves", Vector3.new(18 * scale, 14 * scale, 18 * scale), CFrame.new(position + Vector3.new(0, 24 * scale, 0)), TEST_PLAZA_COLORS.grassDark, Enum.Material.SmoothPlastic)
	leaves:SetAttribute("TestPlazaDecor", true)
	local top = makeBlock(parent, name .. "TopLeaves", Vector3.new(14 * scale, 10 * scale, 14 * scale), CFrame.new(position + Vector3.new(0, 34 * scale, 0)), TEST_PLAZA_COLORS.green, Enum.Material.SmoothPlastic)
	top:SetAttribute("TestPlazaDecor", true)
	return leaves
end

local function plazaOffset(origin, spread, x, y, z)
	spread = spread or 1
	return origin + Vector3.new(x * spread, y, z * spread)
end

local function makeShopBlockout(parent, origin, colorType, spread)
	colorType = colorType or "Test"
	local base = makeBlock(parent, "ShopBuildingBase", Vector3.new(78, 7, 46), CFrame.new(plazaOffset(origin, spread, 92, 3.5, -42)), TEST_PLAZA_COLORS.blue, Enum.Material.SmoothPlastic)
	base:SetAttribute("BrushShop", true)
	base:SetAttribute("ColorType", colorType)
	makeBlock(parent, "ShopCounter", Vector3.new(66, 9, 8), CFrame.new(plazaOffset(origin, spread, 92, 11, -62)), TEST_PLAZA_COLORS.dark, Enum.Material.SmoothPlastic)
	makeBlock(parent, "ShopBackWall", Vector3.new(72, 30, 6), CFrame.new(plazaOffset(origin, spread, 92, 21, -24)), TEST_PLAZA_COLORS.dark, Enum.Material.SmoothPlastic)
	makeBlock(parent, "ShopAwning", Vector3.new(84, 7, 24), CFrame.new(plazaOffset(origin, spread, 92, 32, -46)), Color3.fromRGB(70, 170, 255), Enum.Material.SmoothPlastic)
	for i = -2, 2 do
		makeBlock(parent, "ShopAwningStripe" .. tostring(i), Vector3.new(10, 7.5, 25), CFrame.new(plazaOffset(origin, spread, 92 + i * 16, 32.2, -46)), i % 2 == 0 and TEST_PLAZA_COLORS.white or TEST_PLAZA_COLORS.blue, Enum.Material.SmoothPlastic)
	end
	local sign = makeBlock(parent, "ShopSign", Vector3.new(58, 16, 4), CFrame.new(plazaOffset(origin, spread, 92, 48, -58)), TEST_PLAZA_COLORS.dark, Enum.Material.SmoothPlastic)
	makeTestLabel(sign, "SHOP", "UPGRADES & MORE", Vector3.new(0, 3, 0), UDim2.new(0, 240, 0, 76))
	return base
end

local function makeEggAreaBlockout(parent, origin, colorType, spread)
	colorType = colorType or "Test"
	local base = makeCylinder(parent, "EggAreaRoundBase", 46, 5, CFrame.new(plazaOffset(origin, spread, -28, 2.5, -54)), TEST_PLAZA_COLORS.purple, Enum.Material.SmoothPlastic)
	base:SetAttribute("ColorType", colorType)
	local pedestal = makeCylinder(parent, "StarterTestEggPedestal", 18, 6, CFrame.new(plazaOffset(origin, spread, -28, 8, -54)), Color3.fromRGB(205, 160, 255), Enum.Material.SmoothPlastic)
	local egg = makeBlock(parent, "TestPlazaStarterEgg", Vector3.new(22, 30, 22), CFrame.new(plazaOffset(origin, spread, -28, 28, -54)), Color3.fromRGB(180, 100, 255), Enum.Material.SmoothPlastic)
	egg.Shape = Enum.PartType.Ball
	egg:SetAttribute("EggId", "ColorEgg")
	egg:SetAttribute("ColorType", colorType)
	egg:SetAttribute("AreaColor", colorType)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EggShopPrompt"
	prompt.ActionText = "Hatch"
	prompt.ObjectText = "Egg"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 18
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt:SetAttribute("EggShopPrompt", true)
	prompt.Parent = egg
	makeTestLabel(egg, "EGG AREA", "HATCH COLORS", Vector3.new(0, 21, 0), UDim2.new(0, 260, 0, 80))
	makeBlock(parent, "EggAreaArchLeft", Vector3.new(6, 34, 6), CFrame.new(plazaOffset(origin, spread, -55, 20, -54)), TEST_PLAZA_COLORS.purple, Enum.Material.SmoothPlastic)
	makeBlock(parent, "EggAreaArchRight", Vector3.new(6, 34, 6), CFrame.new(plazaOffset(origin, spread, -1, 20, -54)), TEST_PLAZA_COLORS.purple, Enum.Material.SmoothPlastic)
	makeBlock(parent, "EggAreaArchTop", Vector3.new(60, 8, 7), CFrame.new(plazaOffset(origin, spread, -28, 39, -54)), TEST_PLAZA_COLORS.purple, Enum.Material.SmoothPlastic)
	return egg
end

local function makeSellBlockout(parent, origin, colorType, spread)
	colorType = colorType or "Test"
	local pad = makeCylinder(parent, "TestSellZone", 34, 4, CFrame.new(plazaOffset(origin, spread, -120, 3, -10)), TEST_PLAZA_COLORS.yellow, Enum.Material.Neon)
	pad:SetAttribute("SellZone", true)
	pad:SetAttribute("SellLocation", true)
	pad:SetAttribute("ColorType", colorType)
	pad:SetAttribute("AreaColor", colorType)
	pad:SetAttribute("SellColor", colorType)
	pad:SetAttribute("ColorType", colorType)
	makeBlock(parent, "SellSignPosts", Vector3.new(54, 6, 5), CFrame.new(plazaOffset(origin, spread, -120, 22, -32)), TEST_PLAZA_COLORS.orange, Enum.Material.SmoothPlastic)
	local sign = makeBlock(parent, "SellColorSign", Vector3.new(70, 18, 5), CFrame.new(plazaOffset(origin, spread, -120, 35, -32)), TEST_PLAZA_COLORS.orange, Enum.Material.SmoothPlastic)
	makeTestLabel(sign, "SELL COLOR", nil, Vector3.new(0, 3, 0), UDim2.new(0, 260, 0, 62))
	for i = 1, 5 do
		makeCylinder(parent, "CoinStack" .. i, 5, 4 + i * 2, CFrame.new(plazaOffset(origin, spread, -158 + i * 8, 3 + i, 15)), TEST_PLAZA_COLORS.yellow, Enum.Material.SmoothPlastic)
	end
	return pad
end

local function makePortalBlockout(parent, origin, colorType, spread)
	colorType = colorType or "Test"
	local currentIndex = ColorData.getWorldIndex(colorType) or 1
	local targetWorld = ColorData.Worlds[currentIndex + 1] or ColorData.Worlds[currentIndex] or ColorData.Worlds[1]
	local targetColorType = targetWorld and targetWorld.primaryColor or colorType
	local targetColor = ColorData.Colors[targetColorType] and ColorData.Colors[targetColorType].color or TEST_PLAZA_COLORS.cyan
	local floor = makeBlock(parent, "NextWorldStairs", Vector3.new(80, 5, 38), CFrame.new(plazaOffset(origin, spread, 154, 2.5, 34)), TEST_PLAZA_COLORS.stone, Enum.Material.SmoothPlastic)
	floor:SetAttribute("AreaGate", true)
	floor:SetAttribute("GateColor", targetColorType)
	floor:SetAttribute("UnlockColor", targetColorType)
	floor:SetAttribute("ColorType", targetColorType)
	local portal = makeBlock(parent, "RainbowRealmPortal", Vector3.new(48, 60, 7), CFrame.new(plazaOffset(origin, spread, 154, 35, 56)), targetColor:Lerp(TEST_PLAZA_COLORS.white, 0.16), Enum.Material.Neon)
	portal.Transparency = 0.28
	makeBlock(parent, "PortalLeftStackRed", Vector3.new(13, 22, 13), CFrame.new(plazaOffset(origin, spread, 119, 13, 56)), TEST_PLAZA_COLORS.red, Enum.Material.SmoothPlastic)
	makeBlock(parent, "PortalLeftStackYellow", Vector3.new(13, 22, 13), CFrame.new(plazaOffset(origin, spread, 119, 35, 56)), TEST_PLAZA_COLORS.yellow, Enum.Material.SmoothPlastic)
	makeBlock(parent, "PortalLeftStackGreen", Vector3.new(13, 22, 13), CFrame.new(plazaOffset(origin, spread, 119, 57, 56)), TEST_PLAZA_COLORS.green, Enum.Material.SmoothPlastic)
	makeBlock(parent, "PortalRightStackBlue", Vector3.new(13, 22, 13), CFrame.new(plazaOffset(origin, spread, 189, 13, 56)), TEST_PLAZA_COLORS.blue, Enum.Material.SmoothPlastic)
	makeBlock(parent, "PortalRightStackPurple", Vector3.new(13, 22, 13), CFrame.new(plazaOffset(origin, spread, 189, 35, 56)), TEST_PLAZA_COLORS.purple, Enum.Material.SmoothPlastic)
	makeBlock(parent, "PortalRightStackWhite", Vector3.new(13, 22, 13), CFrame.new(plazaOffset(origin, spread, 189, 57, 56)), TEST_PLAZA_COLORS.white, Enum.Material.SmoothPlastic)
	local sign = makeBlock(parent, "NextWorldSign", Vector3.new(74, 20, 5), CFrame.new(plazaOffset(origin, spread, 154, 81, 56)), TEST_PLAZA_COLORS.dark, Enum.Material.SmoothPlastic)
	makeTestLabel(sign, "NEXT SECTOR", targetWorld and string.upper(targetWorld.name) or "SOON", Vector3.new(0, 2, 0), UDim2.new(0, 280, 0, 80))
	return portal
end

local function makeRainbowSlide(parent, origin, spread)
	local colors = {
		TEST_PLAZA_COLORS.red,
		Color3.fromRGB(255, 145, 45),
		TEST_PLAZA_COLORS.yellow,
		TEST_PLAZA_COLORS.green,
		TEST_PLAZA_COLORS.cyan,
		TEST_PLAZA_COLORS.blue,
		TEST_PLAZA_COLORS.purple,
	}
	for i, color in ipairs(colors) do
		local stripe = makeBlock(parent, "RainbowSlideStripe" .. i, Vector3.new(7, 3, 92), CFrame.new(plazaOffset(origin, spread, -179 + i * 7, 18 + i * 0.4, -92)) * CFrame.Angles(math.rad(-16), 0, 0), color, Enum.Material.SmoothPlastic)
		stripe:SetAttribute("TestPlazaDecor", true)
	end
	makeBlock(parent, "RainbowSlideLeftWall", Vector3.new(8, 18, 98), CFrame.new(plazaOffset(origin, spread, -178, 23, -92)) * CFrame.Angles(math.rad(-16), 0, 0), TEST_PLAZA_COLORS.white, Enum.Material.SmoothPlastic)
	makeBlock(parent, "RainbowSlideRightWall", Vector3.new(8, 18, 98), CFrame.new(plazaOffset(origin, spread, -124, 23, -92)) * CFrame.Angles(math.rad(-16), 0, 0), TEST_PLAZA_COLORS.white, Enum.Material.SmoothPlastic)
end

local function makePaintPuddle(parent, name, position, color, size, colorType)
	local puddle = makeBlock(parent, name, Vector3.new(size.X, 1.1, size.Z), CFrame.new(position), color, Enum.Material.Neon)
	puddle.Shape = Enum.PartType.Ball
	puddle:SetAttribute("BreakableType", "PaintBlob")
	puddle:SetAttribute("ColorType", colorType or "Test")
	puddle:SetAttribute("RewardMultiplier", 1)
	puddle:SetAttribute("PaintPuddleVersion", "test-blockout")
	return puddle
end

local function makeFence(parent, origin, spread)
	for i = -5, 5 do
		makeBlock(parent, "FrontFencePost" .. i, Vector3.new(4, 9, 4), CFrame.new(plazaOffset(origin, spread, i * 32, 5, 155)), TEST_PLAZA_COLORS.white, Enum.Material.SmoothPlastic)
		makeBlock(parent, "BackFencePost" .. i, Vector3.new(4, 9, 4), CFrame.new(plazaOffset(origin, spread, i * 32, 5, -155)), TEST_PLAZA_COLORS.white, Enum.Material.SmoothPlastic)
	end
	for i = -4, 4 do
		makeBlock(parent, "LeftFencePost" .. i, Vector3.new(4, 9, 4), CFrame.new(plazaOffset(origin, spread, -205, 5, i * 32)), TEST_PLAZA_COLORS.white, Enum.Material.SmoothPlastic)
		makeBlock(parent, "RightFencePost" .. i, Vector3.new(4, 9, 4), CFrame.new(plazaOffset(origin, spread, 205, 5, i * 32)), TEST_PLAZA_COLORS.white, Enum.Material.SmoothPlastic)
	end
end

local function buildPlazaBlockout(options)
	options = options or {}
	currentOptions = options

	if RunService:IsRunning() and not options.allowDuringPlay then
		warn("StudioZoneBuilder: run plaza builders in Studio edit mode so the parts stay editable.")
		return nil
	end

	local map = workspace:FindFirstChild(MAP_NAME)
	if options.replaceMainMap then
		clearExistingMap()
		map = nil
	end
	if not map then
		map = Instance.new("Folder")
		map.Name = MAP_NAME
		map.Parent = workspace
	end

	local folderName = options.folderName or "TestWorldBlockout"
	local existing = map:FindFirstChild(folderName)
	if existing then
		if options.overwrite == false then
			warn("StudioZoneBuilder: " .. folderName .. " already exists. Pass { overwrite = true } to rebuild it.")
			return existing
		end
		existing:Destroy()
	end

	local root = Instance.new("Folder")
	root.Name = folderName
	root.Parent = map

	local colorType = options.colorType or "Test"
	local worldId = options.worldId or colorType
	local worldName = options.worldName or "Test Plaza"
	local spawnName = options.spawnName or "TestSpawn"
	local zoneName = options.zoneName or "TestZone"
	local spread = tonumber(options.spread) or 1
	local origin = Vector3.new(tonumber(options.xOffset) or 0, 0, tonumber(options.zOffset) or 520)
	local zone = makeBlock(root, zoneName, Vector3.new(430 * spread, 2, 330 * spread), CFrame.new(origin), TEST_PLAZA_COLORS.grass, Enum.Material.Grass)
	zone:SetAttribute("ColorZone", true)
	zone:SetAttribute("ColorType", colorType)
	zone:SetAttribute("WorldId", worldId)
	zone:SetAttribute("WorldName", worldName)
	zone:SetAttribute("RewardMultiplier", 1)
	zone:SetAttribute("BlobCount", options.blobCount or 36)

	local spawn = makeBlock(root, spawnName, Vector3.new(54, 2, 46), CFrame.new(plazaOffset(origin, spread, 0, 2, 118)), TEST_PLAZA_COLORS.stone, Enum.Material.SmoothPlastic)
	spawn:SetAttribute("AreaSpawn", true)
	spawn:SetAttribute("AreaSpawnColor", colorType)
	spawn:SetAttribute("TeleportColor", colorType)
	spawn:SetAttribute("ColorType", colorType)
	makeTestLabel(spawn, "WELCOME TO", "COLOR PLAZA!", Vector3.new(0, 8, 0), UDim2.new(0, 330, 0, 88))

	for _, path in ipairs({
		{ name = "PathSpawnToCenter", size = Vector3.new(32, 0.6, 150), pos = Vector3.new(0, 1.35, 45), rot = 0 },
		{ name = "PathCenterToSell", size = Vector3.new(32, 0.6, 132), pos = Vector3.new(-70, 1.36, 14), rot = 45 },
		{ name = "PathCenterToEgg", size = Vector3.new(30, 0.6, 106), pos = Vector3.new(-20, 1.37, -20), rot = -22 },
		{ name = "PathCenterToShop", size = Vector3.new(30, 0.6, 120), pos = Vector3.new(46, 1.38, -20), rot = 38 },
		{ name = "PathCenterToPortal", size = Vector3.new(30, 0.6, 130), pos = Vector3.new(92, 1.39, 44), rot = -52 },
	}) do
		makeBlock(root, path.name, path.size, CFrame.new(plazaOffset(origin, spread, path.pos.X, path.pos.Y, path.pos.Z)) * CFrame.Angles(0, math.rad(path.rot), 0), TEST_PLAZA_COLORS.path, Enum.Material.SmoothPlastic)
	end

	local centerSign = makeBlock(root, "WelcomeArchSign", Vector3.new(92, 18, 5), CFrame.new(plazaOffset(origin, spread, 0, 31, 82)), TEST_PLAZA_COLORS.blue, Enum.Material.SmoothPlastic)
	makeTestLabel(centerSign, "WELCOME TO", "COLOR PLAZA!", Vector3.new(0, 1, 0), UDim2.new(0, 330, 0, 88))
	makeBlock(root, "WelcomeArchLeftPost", Vector3.new(6, 34, 6), CFrame.new(plazaOffset(origin, spread, -49, 17, 82)), TEST_PLAZA_COLORS.purple, Enum.Material.SmoothPlastic)
	makeBlock(root, "WelcomeArchRightPost", Vector3.new(6, 34, 6), CFrame.new(plazaOffset(origin, spread, 49, 17, 82)), TEST_PLAZA_COLORS.purple, Enum.Material.SmoothPlastic)

	makeSellBlockout(root, origin, colorType, spread)
	makeEggAreaBlockout(root, origin, colorType, spread)
	makeShopBlockout(root, origin, colorType, spread)
	makePortalBlockout(root, origin, colorType, spread)
	makeRainbowSlide(root, origin, spread)
	makeFence(root, origin, spread)

	local howTo = makeBlock(root, "HowToPlaySign", Vector3.new(44, 30, 5), CFrame.new(plazaOffset(origin, spread, 135, 18, 118)) * CFrame.Angles(0, math.rad(-20), 0), Color3.fromRGB(120, 78, 42), Enum.Material.Wood)
	makeTestLabel(howTo, "HOW TO PLAY", "COLLECT  SELL  HATCH  UPGRADE", Vector3.new(0, 2, 0), UDim2.new(0, 260, 0, 86))

	for i, pos in ipairs({
		Vector3.new(-180, 0, 110), Vector3.new(-168, 0, 58), Vector3.new(-192, 0, -22), Vector3.new(-104, 0, -128),
		Vector3.new(-70, 0, -128), Vector3.new(2, 0, -136), Vector3.new(64, 0, -122), Vector3.new(132, 0, -108),
		Vector3.new(188, 0, -42), Vector3.new(196, 0, 100), Vector3.new(102, 0, 134), Vector3.new(-112, 0, 136),
	}) do
		makeTree(root, "BlockoutTree" .. i, plazaOffset(origin, spread, pos.X, pos.Y, pos.Z), i % 3 == 0 and 1.2 or 1)
	end

	local puddleColors = { TEST_PLAZA_COLORS.red, TEST_PLAZA_COLORS.cyan, TEST_PLAZA_COLORS.yellow, TEST_PLAZA_COLORS.purple, TEST_PLAZA_COLORS.pink }
	for i = 1, 28 do
		local angle = math.rad(i * 47)
		local radius = 30 + (i % 5) * 18
		local x = math.cos(angle) * radius + ((i % 4) - 2) * 18
		local z = math.sin(angle) * radius + ((i % 3) - 1) * 16
		local pos = plazaOffset(origin, spread, x, 2.3, z)
		makePaintPuddle(root, "EditableColorPuddle" .. i, pos, puddleColors[((i - 1) % #puddleColors) + 1], Vector3.new(7 + (i % 3) * 2, 1, 6 + (i % 4)), colorType)
	end

	for i, pos in ipairs({ Vector3.new(-72, 2.5, 134), Vector3.new(76, 2.5, 137) }) do
		makeBlock(root, "BenchSeat" .. i, Vector3.new(34, 3, 8), CFrame.new(plazaOffset(origin, spread, pos.X, pos.Y, pos.Z)), Color3.fromRGB(156, 92, 48), Enum.Material.Wood)
		makeBlock(root, "BenchBack" .. i, Vector3.new(34, 10, 3), CFrame.new(plazaOffset(origin, spread, pos.X, pos.Y + 5, pos.Z + 6)), Color3.fromRGB(120, 72, 42), Enum.Material.Wood)
	end

	print("StudioZoneBuilder: created editable " .. folderName .. ". Refine it under Workspace > ColorSimulatorMap > " .. folderName .. ".")
	return root
end

function StudioZoneBuilder.buildTestPlaza(options)
	options = options or {}
	options.folderName = options.folderName or "TestWorldBlockout"
	options.colorType = options.colorType or "Test"
	options.worldId = options.worldId or "Test"
	options.worldName = options.worldName or "Test Plaza"
	options.zoneName = options.zoneName or "TestZone"
	options.spawnName = options.spawnName or "TestSpawn"
	options.zOffset = options.zOffset or 520
	options.spread = options.spread or 1.15
	return buildPlazaBlockout(options)
end

StudioZoneBuilder.buildTestWorld = StudioZoneBuilder.buildTestPlaza

function StudioZoneBuilder.buildMainPlaza(options)
	options = options or {}
	options.folderName = options.folderName or "StarterFieldPlaza"
	options.colorType = options.colorType or "Red"
	options.worldId = options.worldId or "Red"
	options.worldName = options.worldName or "Starter Field"
	options.zoneName = options.zoneName or "RedZone"
	options.spawnName = options.spawnName or "SpawnPad"
	options.zOffset = options.zOffset or 0
	options.spread = options.spread or 1.25
	options.replaceMainMap = options.replaceMainMap ~= false
	return buildPlazaBlockout(options)
end

StudioZoneBuilder.buildStarterPlaza = StudioZoneBuilder.buildMainPlaza

local findFirstPart

function StudioZoneBuilder.restoreMissingWorlds(options)
	options = options or {}
	currentOptions = options

	if RunService:IsRunning() and not options.allowDuringPlay then
		warn("StudioZoneBuilder: run restoreMissingWorlds in Studio edit mode so the parts stay editable.")
		return nil
	end

	local map = workspace:FindFirstChild(MAP_NAME)
	if not map then
		warn("StudioZoneBuilder: no " .. MAP_NAME .. " found. Build or keep your starter plaza first.")
		return nil
	end

	local zones = map:FindFirstChild("Zones") or makeFolder(map, "Zones")
	local spawns = map:FindFirstChild("Spawns") or makeFolder(map, "Spawns")
	local eggs = map:FindFirstChild("Eggs") or makeFolder(map, "Eggs")
	local gates = map:FindFirstChild("Gates") or makeFolder(map, "Gates")
	local decor = map:FindFirstChild("BuildDecor") or makeFolder(map, "BuildDecor")

	local spacing = tonumber(options.spacing) or ZONE_SPACING
	local direction = Vector3.new(1, 0, 0)
	local redZone = findFirstPart(map, function(part)
		return part:GetAttribute("ColorZone") and part:GetAttribute("ColorType") == "Red"
	end)
	local origin = redZone and redZone.Position or Vector3.zero

	for index, world in ipairs(ColorData.Worlds) do
		local colorType = world.primaryColor
		local existingZone = findFirstPart(map, function(part)
			return part:GetAttribute("ColorZone") and part:GetAttribute("ColorType") == colorType
		end)
		local center = existingZone and existingZone.Position or (origin + direction * ((index - 1) * spacing))
		local theme = THEME[colorType] or {
			color = ColorData.Colors[colorType] and ColorData.Colors[colorType].color or Color3.new(1, 1, 1),
			material = Enum.Material.SmoothPlastic,
			accent = Color3.new(1, 1, 1),
		}

		if index > 1 then
			if not existingZone then
				local zone = makePart(zones, colorType .. "Zone", ZONE_SIZE, center, theme.color, theme.material)
				zone.Transparency = 0
				zone:SetAttribute("ColorZone", true)
				zone:SetAttribute("ColorType", colorType)
				zone:SetAttribute("WorldId", world.id)
				zone:SetAttribute("WorldName", world.name)
				zone:SetAttribute("RewardMultiplier", world.rewardMultiplier or math.max(1, world.breakableHealth / 10))
				zone:SetAttribute("BlobCount", world.blobCount or 32)
				makeZoneDecor(decor, colorType, center, theme)
				makeSpawn(spawns, world, center, theme)
				makeEgg(eggs, world, center, theme)
				existingZone = zone
			end
		end

		local existingSell = findFirstPart(map, function(part)
			if not (part:GetAttribute("SellZone") or part:GetAttribute("SellLocation")) then
				return false
			end
			local sellColor = part:GetAttribute("ColorType") or part:GetAttribute("AreaColor") or part:GetAttribute("SellColor")
			return sellColor == colorType or (colorType == "Red" and sellColor == nil)
		end)
		if not existingSell and existingZone then
			makeSellZone(zones, world, center, index)
		end
	end

	for index, world in ipairs(ColorData.Worlds) do
		if index > 1 then
			local existingGate = findFirstPart(map, function(part)
				return part:GetAttribute("AreaGate")
					and (part:GetAttribute("GateColor") == world.primaryColor or part:GetAttribute("UnlockColor") == world.primaryColor)
					and not part:GetAttribute("GateDecor")
					and not part:GetAttribute("GateInteraction")
			end)
			if not existingGate then
				local previousWorld = ColorData.Worlds[index - 1]
				local previousZone = findFirstPart(map, function(part)
					return part:GetAttribute("ColorZone") and part:GetAttribute("ColorType") == previousWorld.primaryColor
				end)
				local currentZone = findFirstPart(map, function(part)
					return part:GetAttribute("ColorZone") and part:GetAttribute("ColorType") == world.primaryColor
				end)
				if previousZone and currentZone then
					makeGate(gates, world, previousZone.Position, currentZone.Position, previousZone, currentZone)
				end
			end
		end
	end

	StudioZoneBuilder.refreshWorldPortals({ align = true })
	print("StudioZoneBuilder: restored missing worlds after the current Starter Field.")
	return map
end

function findFirstPart(root, predicate)
	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("BasePart") and predicate(obj) then
			return obj
		end
	end
	return nil
end

local function makeFlatPath(parent, name, fromPosition, toPosition, width, color)
	local delta = Vector3.new(toPosition.X - fromPosition.X, 0, toPosition.Z - fromPosition.Z)
	local length = delta.Magnitude
	if length < 8 then
		return nil
	end

	local midpoint = Vector3.new(
		(fromPosition.X + toPosition.X) * 0.5,
		math.max(fromPosition.Y, toPosition.Y) + 0.35,
		(fromPosition.Z + toPosition.Z) * 0.5
	)
	local path = makeBlock(parent, name, Vector3.new(width, 0.7, length), CFrame.new(midpoint, midpoint + delta), color, Enum.Material.SmoothPlastic)
	path:SetAttribute("SpawnCleanupDecor", true)
	path.CanCollide = false

	local left = makeBlock(parent, name .. "LeftTrim", Vector3.new(2.5, 1.1, length), path.CFrame * CFrame.new(-(width / 2 + 1.25), 0.25, 0), SOFT_NEON_WHITE, Enum.Material.SmoothPlastic)
	left:SetAttribute("SpawnCleanupDecor", true)
	left.CanCollide = false
	left.Transparency = 0.18
	local right = makeBlock(parent, name .. "RightTrim", Vector3.new(2.5, 1.1, length), path.CFrame * CFrame.new(width / 2 + 1.25, 0.25, 0), SOFT_NEON_WHITE, Enum.Material.SmoothPlastic)
	right:SetAttribute("SpawnCleanupDecor", true)
	right.CanCollide = false
	right.Transparency = 0.18

	return path
end

local function makeQuietStationLabel(parent, title, subtitle, offset)
	local billboard = makeTestLabel(parent, title, subtitle, offset or Vector3.new(0, 6, 0), UDim2.new(0, 180, 0, subtitle and 54 or 38))
	billboard.Name = "QuietStationLabel"
	billboard.MaxDistance = 105
	billboard.Enabled = false
	billboard:SetAttribute("ProximityWorldLabel", true)
	billboard:SetAttribute("ShowDistance", 58)
	billboard:SetAttribute("HideDistance", 68)

	for _, child in ipairs(billboard:GetChildren()) do
		if child:IsA("TextLabel") then
			child.TextSize = child.Name == "Subtitle" and 12 or 22
			child.TextScaled = false
			child.TextStrokeTransparency = 0.08
		end
	end

	return billboard
end

local function addProximityLabel(target, title, subtitle, offset)
	if not target or not target:IsA("BasePart") then
		return nil
	end

	for _, child in ipairs(target:GetChildren()) do
		if child:IsA("BillboardGui") and (child.Name == "ProximityStationLabel" or child.Name == "QuietStationLabel") then
			child:Destroy()
		end
	end

	local label = makeQuietStationLabel(target, title, subtitle, offset or Vector3.new(0, 7, 0))
	label.Name = "ProximityStationLabel"
	return label
end

local function makeStationMarker(parent, name, position, color, title, subtitle)
	local pad = makeBlock(parent, name .. "Pad", Vector3.new(58, 1.2, 38), CFrame.new(position + Vector3.new(0, 0.55, 0)), color, Enum.Material.SmoothPlastic)
	pad:SetAttribute("SpawnCleanupDecor", true)
	pad.CanCollide = false

	local trim = makeBlock(parent, name .. "GlowTrim", Vector3.new(66, 1.3, 46), CFrame.new(position + Vector3.new(0, 0.4, 0)), color:Lerp(TEST_PLAZA_COLORS.white, 0.2), Enum.Material.SmoothPlastic)
	trim:SetAttribute("SpawnCleanupDecor", true)
	trim.CanCollide = false
	trim.Transparency = 0.72

	makeQuietStationLabel(pad, title, subtitle, Vector3.new(0, 7, 0))
	return pad
end

local function moveBreakablesIntoStarterClusters(root, origin, colorType)
	local blobs = {}
	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("BasePart")
			and obj:GetAttribute("BreakableType")
			and (not colorType or obj:GetAttribute("ColorType") == colorType)
			and not obj:GetAttribute("SpawnCleanupDecor")
		then
			table.insert(blobs, obj)
		end
	end

	local clusters = {
		origin + Vector3.new(-54, 1.8, 54),
		origin + Vector3.new(58, 1.8, 52),
		origin + Vector3.new(4, 1.8, -58),
	}

	for i, blob in ipairs(blobs) do
		local cluster = clusters[((i - 1) % #clusters) + 1]
		local ringIndex = math.floor((i - 1) / #clusters)
		local angle = math.rad((i * 137) % 360)
		local radius = 10 + (ringIndex % 5) * 5
		blob.Position = cluster + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		blob:SetAttribute("SpawnCleanupClustered", true)
	end

	return #blobs
end

function StudioZoneBuilder.cleanStarterSpawn(options)
	options = options or {}
	currentOptions = options

	if RunService:IsRunning() and not options.allowDuringPlay then
		warn("StudioZoneBuilder: run cleanStarterSpawn in Studio edit mode so the parts stay editable.")
		return nil
	end

	local map = workspace:FindFirstChild(MAP_NAME)
	if not map then
		warn("StudioZoneBuilder: no " .. MAP_NAME .. " found.")
		return nil
	end

	local existing = map:FindFirstChild("StarterSpawnCleanup")
	if existing then
		if options.overwrite == false then
			warn("StudioZoneBuilder: StarterSpawnCleanup already exists. Pass { overwrite = true } to rebuild it.")
			return existing
		end
		existing:Destroy()
	end

	local root = Instance.new("Folder")
	root.Name = "StarterSpawnCleanup"
	root.Parent = map

	if options.hideOldLabels ~= false then
		for _, obj in ipairs(map:GetDescendants()) do
			if obj:IsA("BillboardGui")
				and (obj.Name == "BlockoutLabel" or obj.Name == "ZoneLabel" or obj.Name == "EggLabel" or obj.Name == "SellLabel")
				and not obj:IsDescendantOf(root)
			then
				obj.Enabled = false
			end
		end
	end

	local spawn = findFirstPart(map, function(part)
		return part:GetAttribute("AreaSpawnColor") == "Red"
			or part:GetAttribute("TeleportColor") == "Red"
			or part.Name == "SpawnPad"
	end)
	local zone = findFirstPart(map, function(part)
		return part:GetAttribute("ColorZone") and part:GetAttribute("ColorType") == "Red"
	end)
	local sell = findFirstPart(map, function(part)
		return part:GetAttribute("SellZone") and (not part:GetAttribute("ColorType") or part:GetAttribute("ColorType") == "Red")
	end)
	local egg = findFirstPart(map, function(part)
		return part:GetAttribute("EggId") and ((part:GetAttribute("ColorType") or part:GetAttribute("AreaColor")) == "Red" or part:GetAttribute("EggId") == "ColorEgg")
	end)
	local shop = findFirstPart(map, function(part)
		return part:GetAttribute("BrushShop") and (not part:GetAttribute("ColorType") or part:GetAttribute("ColorType") == "Red")
	end)

	local origin = spawn and spawn.Position or (zone and zone.Position + Vector3.new(0, 2, 95)) or Vector3.new(0, 2, 95)
	local center = zone and (zone.Position + Vector3.new(0, 2.2, 0)) or (origin + Vector3.new(0, 0, -82))

	if spawn then addProximityLabel(spawn, "SPAWN", nil) end
	if sell then addProximityLabel(sell, "SELL", "Cash out") end
	if egg then addProximityLabel(egg, "EGG", "Hatch") end
	if shop then addProximityLabel(shop, "SHOP", nil) end

	local clustered = 0

	print("StudioZoneBuilder: added proximity text to Starter spawn stations.")
	return root
end

StudioZoneBuilder.cleanupStarterSpawn = StudioZoneBuilder.cleanStarterSpawn

function StudioZoneBuilder.addProximityStationText(options)
	options = options or {}
	local map = workspace:FindFirstChild(MAP_NAME)
	if not map then
		warn("StudioZoneBuilder: no " .. MAP_NAME .. " found.")
		return 0
	end

	if options.removeGeneratedStuff ~= false then
		StudioZoneBuilder.removeGeneratedSpawnStuff()
	end

	local spawn = findFirstPart(map, function(part)
		return part:GetAttribute("AreaSpawnColor") == "Red"
			or part:GetAttribute("TeleportColor") == "Red"
			or part.Name == "SpawnPad"
	end)
	local sell = findFirstPart(map, function(part)
		return part:GetAttribute("SellZone") and (not part:GetAttribute("ColorType") or part:GetAttribute("ColorType") == "Red")
	end)
	local egg = findFirstPart(map, function(part)
		return part:GetAttribute("EggId") and ((part:GetAttribute("ColorType") or part:GetAttribute("AreaColor")) == "Red" or part:GetAttribute("EggId") == "ColorEgg")
	end)
	local shop = findFirstPart(map, function(part)
		return part:GetAttribute("BrushShop") and (not part:GetAttribute("ColorType") or part:GetAttribute("ColorType") == "Red")
	end)

	local added = 0
	if spawn and addProximityLabel(spawn, "SPAWN", nil) then added += 1 end
	if sell and addProximityLabel(sell, "SELL", "Cash out") then added += 1 end
	if egg and addProximityLabel(egg, "EGG", "Hatch") then added += 1 end
	if shop and addProximityLabel(shop, "SHOP", nil) then added += 1 end

	print("StudioZoneBuilder: added " .. tostring(added) .. " proximity station labels.")
	return added
end

StudioZoneBuilder.addStationText = StudioZoneBuilder.addProximityStationText

function StudioZoneBuilder.hideSpawnText(options)
	options = options or {}
	local map = workspace:FindFirstChild(MAP_NAME)
	if not map then
		warn("StudioZoneBuilder: no " .. MAP_NAME .. " found.")
		return 0
	end

	local hidden = 0
	for _, obj in ipairs(map:GetDescendants()) do
		if obj:IsA("BillboardGui")
			and (obj.Name == "BlockoutLabel" or obj.Name == "ZoneLabel" or obj.Name == "EggLabel" or obj.Name == "SellLabel")
			and (options.includeCleanupLabels or obj.Name ~= "QuietStationLabel")
		then
			obj.Enabled = false
			hidden += 1
		end
	end

	print("StudioZoneBuilder: hid " .. tostring(hidden) .. " spawn labels.")
	return hidden
end

function StudioZoneBuilder.softSpawnColors(options)
	options = options or {}
	local map = workspace:FindFirstChild(MAP_NAME)
	if not map then
		warn("StudioZoneBuilder: no " .. MAP_NAME .. " found.")
		return 0
	end

	local softened = 0
	local cleanupFolder = map:FindFirstChild("StarterSpawnCleanup")
	for _, obj in ipairs(map:GetDescendants()) do
		if obj:IsA("BasePart") and (obj:GetAttribute("SpawnCleanupDecor") or (cleanupFolder and obj:IsDescendantOf(cleanupFolder))) then
			if obj.Material == Enum.Material.Neon then
				obj.Material = Enum.Material.SmoothPlastic
				obj.Transparency = math.max(obj.Transparency, 0.12)
			end

			if obj.Name:find("Trim") or obj.Name:find("GuideLight") then
				obj.Color = SOFT_NEON_WHITE
				obj.Transparency = math.max(obj.Transparency, 0.18)
			elseif obj.Name:find("Path") then
				obj.Color = TEST_PLAZA_COLORS.path
			elseif obj.Name:find("Glow") then
				obj.Transparency = math.max(obj.Transparency, 0.72)
			end

			softened += 1
		end
	end

	local lighting = game:GetService("Lighting")
	lighting.Brightness = math.min(lighting.Brightness, 2)
	lighting.ExposureCompensation = math.min(lighting.ExposureCompensation, -0.1)

	print("StudioZoneBuilder: softened " .. tostring(softened) .. " bright spawn parts.")
	return softened
end

function StudioZoneBuilder.removeGeneratedSpawnStuff(options)
	options = options or {}
	local map = workspace:FindFirstChild(MAP_NAME)
	if not map then
		warn("StudioZoneBuilder: no " .. MAP_NAME .. " found.")
		return 0
	end

	local removed = 0
	local generatedNamePrefixes = {
		Clean = true,
		Path = true,
		WelcomeArch = true,
		BlockoutTree = true,
		FrontFence = true,
		BackFence = true,
		LeftFence = true,
		RightFence = true,
		Bench = true,
		CoinStack = true,
		RainbowSlide = true,
		EggAreaArch = true,
		ShopAwningStripe = true,
	}
	local generatedExactNames = {
		EggAreaRoundBase = true,
		StarterTestEggPedestal = true,
		SellSignPosts = true,
		SellColorSign = true,
		ShopCounter = true,
		ShopBackWall = true,
		ShopAwning = true,
		ShopSign = true,
		HowToPlaySign = true,
		NextWorldStairs = true,
		NextWorldSign = true,
	}
	local function isGeneratedDecor(obj)
		if obj:GetAttribute("SpawnCleanupDecor")
			or obj:GetAttribute("TestPlazaDecor")
			or obj:GetAttribute("StarterFieldDecor")
			or obj:GetAttribute("SellZoneDecor")
		then
			return true
		end
		if obj:GetAttribute("ColorZone")
			or obj:GetAttribute("AreaSpawn")
			or obj:GetAttribute("SellZone")
			or obj:GetAttribute("EggId")
			or obj:GetAttribute("BrushShop")
			or obj:GetAttribute("AreaGate")
			or obj:GetAttribute("GateDecor")
			or obj:GetAttribute("GateInteraction")
			or obj:GetAttribute("BreakableType")
		then
			return false
		end
		if generatedExactNames[obj.Name] then
			return true
		end
		for prefix in pairs(generatedNamePrefixes) do
			if string.sub(obj.Name, 1, #prefix) == prefix then
				return true
			end
		end
		return false
	end

	local cleanupFolder = map:FindFirstChild("StarterSpawnCleanup")
	if cleanupFolder then
		cleanupFolder:Destroy()
		removed += 1
	end

	for _, obj in ipairs(map:GetDescendants()) do
		if (obj:IsA("BasePart") and isGeneratedDecor(obj))
			or (obj:IsA("BillboardGui")
				and (obj.Name == "QuietStationLabel"
				or obj.Name == "BlockoutLabel"
				or obj.Name == "ProximityStationLabel"
				or obj.Name == "SellZoneLabel"
				or obj:GetAttribute("StarterFieldLabel")))
		then
			obj:Destroy()
			removed += 1
		end
	end

	print("StudioZoneBuilder: removed " .. tostring(removed) .. " generated cleanup parts/labels.")
	return removed
end

function StudioZoneBuilder.keepMainSpawnOnly(options)
	options = options or {}
	local map = workspace:FindFirstChild(MAP_NAME)
	if not map then
		warn("StudioZoneBuilder: no " .. MAP_NAME .. " found.")
		return 0
	end

	local keepFolderName = options.keepFolderName or "StarterFieldPlaza"
	local removed = 0
	local generatedLayerNames = {
		StarterSpawnCleanup = true,
		TestWorldBlockout = true,
		TestPlaza = true,
		TestWorld = true,
	}

	for _, child in ipairs(map:GetChildren()) do
		if child:IsA("Folder") and child.Name ~= keepFolderName and generatedLayerNames[child.Name] then
			child:Destroy()
			removed += 1
		end
	end

	local main = map:FindFirstChild(keepFolderName)
	if main then
		local seenNames = {}
		for _, obj in ipairs(main:GetDescendants()) do
			if (obj:IsA("BasePart") and obj:GetAttribute("SpawnCleanupDecor"))
				or (obj:IsA("BillboardGui") and obj.Name == "QuietStationLabel")
			then
				obj:Destroy()
				removed += 1
			elseif obj:IsA("BasePart") then
				local colorType = obj:GetAttribute("ColorType")
				local dedupeKey
				if obj:GetAttribute("ColorZone") and colorType == "Red" then
					dedupeKey = "RedColorZone"
				elseif obj:GetAttribute("AreaSpawn") and (obj:GetAttribute("AreaSpawnColor") == "Red" or obj:GetAttribute("TeleportColor") == "Red") then
					dedupeKey = "RedSpawn"
				elseif obj:GetAttribute("SellZone") and (not colorType or colorType == "Red") then
					dedupeKey = "RedSellZone"
				elseif obj:GetAttribute("BrushShop") and (not colorType or colorType == "Red") then
					dedupeKey = "RedBrushShop"
				elseif obj:GetAttribute("EggId") == "ColorEgg" then
					dedupeKey = "StarterEgg"
				end

				if dedupeKey then
					if seenNames[dedupeKey] then
						obj:Destroy()
						removed += 1
					else
						seenNames[dedupeKey] = true
					end
				end
			end
		end
	end

	StudioZoneBuilder.hideSpawnText()
	StudioZoneBuilder.softSpawnColors()
	print("StudioZoneBuilder: kept " .. keepFolderName .. " as the main spawn and removed " .. tostring(removed) .. " extra generated pieces.")
	return removed
end

function StudioZoneBuilder.repackExisting(spacing)
	local map = workspace:FindFirstChild(MAP_NAME)
	if not map then
		warn("StudioZoneBuilder: no " .. MAP_NAME .. " found. Run .build({ overwrite = true }) first.")
		return nil
	end

	spacing = tonumber(spacing) or ZONE_SPACING

	for index, world in ipairs(ColorData.Worlds) do
		local colorType = world.primaryColor
		local center = Vector3.new((index - 1) * spacing, 0, 0)

		for _, obj in ipairs(map:GetDescendants()) do
			if obj:IsA("BasePart") then
				local objColor = obj:GetAttribute("ColorType")
				local isWorldObject = objColor == colorType
				if isWorldObject then
					local worldIndex = ColorData.getWorldIndex(colorType) or index
					local oldCenter = Vector3.new((worldIndex - 1) * ZONE_SPACING, 0, 0)
					local offset = obj.Position - oldCenter
					obj.Position = center + offset
				end
			end
		end
	end

	print("StudioZoneBuilder: repacked worlds to " .. tostring(spacing) .. " studs apart.")
	return map
end

local findZoneForWorld

local function getLayoutDirection(map)
	local firstWorld = ColorData.Worlds[1]
	local secondWorld = ColorData.Worlds[2]
	local firstZone = firstWorld and findZoneForWorld(map, firstWorld.primaryColor)
	local secondZone = secondWorld and findZoneForWorld(map, secondWorld.primaryColor)
	if firstZone and secondZone then
		return getFlatDirection(firstZone.Position, secondZone.Position)
	end
	return Vector3.new(1, 0, 0)
end

local function getObjectWorldColor(obj)
	local colorType = obj:GetAttribute("ColorType")
	if colorType and ColorData.getWorldByColor(colorType) then
		return colorType
	end

	local spawnColor = obj:GetAttribute("AreaSpawnColor")
		or obj:GetAttribute("SpawnColor")
		or obj:GetAttribute("TeleportColor")
	if spawnColor and ColorData.getWorldByColor(spawnColor) then
		return spawnColor
	end

	local gateColor = obj:GetAttribute("GateColor") or obj:GetAttribute("UnlockColor")
	if gateColor and ColorData.getWorldByColor(gateColor) then
		return gateColor
	end

	if obj.Name == "SellZone" then
		return "Red"
	end

	for _, world in ipairs(ColorData.Worlds) do
		if obj.Name == world.primaryColor .. "Zone"
			or obj.Name == world.primaryColor .. "Spawn"
			or string.sub(obj.Name, 1, #world.primaryColor) == world.primaryColor
		then
			return world.primaryColor
		end
	end

	return nil
end

local function getTheme(colorType)
	return THEME[colorType] or {
		color = ColorData.Colors[colorType] and ColorData.Colors[colorType].color or Color3.new(1, 1, 1),
		material = Enum.Material.SmoothPlastic,
		accent = Color3.new(1, 1, 1),
	}
end

local function getWorldPositionOffset(position, center)
	return Vector3.new(position.X - center.X, 0, position.Z - center.Z)
end

local function scaleOffset(offset, scale)
	return Vector3.new(offset.X * scale, 0, offset.Z * scale)
end

local function isWorldStructurePart(obj, colorType)
	return obj:GetAttribute("ColorZone")
		or obj:GetAttribute("WorldBarrier")
		or obj.Name == colorType .. "NorthTrim"
		or obj.Name == colorType .. "SouthTrim"
		or obj.Name == colorType .. "WestTrim"
		or obj.Name == colorType .. "EastTrim"
		or obj:GetAttribute("AreaGate")
		or obj:GetAttribute("GateDecor")
		or obj:GetAttribute("GateInteraction")
end

local function resizeWallPart(wall, center, worldSize, colorType, side)
	if not wall then
		return
	end

	local theme = getTheme(colorType)
	local half = worldSize / 2
	local wallColor = theme.accent:Lerp(Color3.fromRGB(245, 248, 255), 0.28)
	wall.Anchored = true
	wall.Material = Enum.Material.SmoothPlastic
	wall.Color = wallColor
	wall.Transparency = 0
	wall.CastShadow = false
	wall:SetAttribute("WorldBarrier", true)
	wall:SetAttribute("ColorType", colorType)

	if side == "North" then
		wall.Size = Vector3.new(worldSize + WALL_THICKNESS * 2, WALL_HEIGHT, WALL_THICKNESS)
		wall.Position = center + Vector3.new(0, WALL_HEIGHT / 2, -half - WALL_THICKNESS / 2)
	elseif side == "South" then
		wall.Size = Vector3.new(worldSize + WALL_THICKNESS * 2, WALL_HEIGHT, WALL_THICKNESS)
		wall.Position = center + Vector3.new(0, WALL_HEIGHT / 2, half + WALL_THICKNESS / 2)
	elseif side == "West" then
		wall.Size = Vector3.new(WALL_THICKNESS, WALL_HEIGHT, worldSize + WALL_THICKNESS * 2)
		wall.Position = center + Vector3.new(-half - WALL_THICKNESS / 2, WALL_HEIGHT / 2, 0)
	elseif side == "East" then
		wall.Size = Vector3.new(WALL_THICKNESS, WALL_HEIGHT, worldSize + WALL_THICKNESS * 2)
		wall.Position = center + Vector3.new(half + WALL_THICKNESS / 2, WALL_HEIGHT / 2, 0)
	end
end

local function resizeTrimPart(trim, center, worldSize, colorType, side)
	if not trim then
		return
	end

	local theme = getTheme(colorType)
	local half = worldSize / 2
	trim.Anchored = true
	trim.Material = Enum.Material.SmoothPlastic
	trim.Color = theme.accent
	trim.Transparency = 0.08
	trim:SetAttribute("ColorType", colorType)

	if side == "North" then
		trim.Size = Vector3.new(worldSize, 3, 4)
		trim.Position = center + Vector3.new(0, 2.5, -half)
	elseif side == "South" then
		trim.Size = Vector3.new(worldSize, 3, 4)
		trim.Position = center + Vector3.new(0, 2.5, half)
	elseif side == "West" then
		trim.Size = Vector3.new(4, 3, worldSize)
		trim.Position = center + Vector3.new(-half, 2.5, 0)
	elseif side == "East" then
		trim.Size = Vector3.new(4, 3, worldSize)
		trim.Position = center + Vector3.new(half, 2.5, 0)
	end
end

local function applyWorldShell(map, colorType, center, worldSize)
	local zone = findZoneForWorld(map, colorType)
	if zone then
		local theme = getTheme(colorType)
		zone.Size = Vector3.new(worldSize, zone.Size.Y, worldSize)
		zone.Position = center
		zone.Color = theme.color
		zone.Material = theme.material
		zone.Transparency = 0
	end

	for _, side in ipairs({ "North", "South", "West", "East" }) do
		local wall = map:FindFirstChild(colorType .. side .. "Wall", true)
		if wall and wall:IsA("BasePart") then
			resizeWallPart(wall, center, worldSize, colorType, side)
		end

		local trim = map:FindFirstChild(colorType .. side .. "Trim", true)
		if trim and trim:IsA("BasePart") then
			resizeTrimPart(trim, center, worldSize, colorType, side)
		end
	end
end

function StudioZoneBuilder.compactExistingWorlds(options)
	options = options or {}

	local map = workspace:FindFirstChild(MAP_NAME)
	if not map then
		warn("StudioZoneBuilder: no " .. MAP_NAME .. " found. Run .build({ overwrite = true }) first.")
		return nil
	end

	local spacing = tonumber(options.spacing) or COMPACT_ZONE_SPACING
	local minSpacing = ZONE_SIZE.X + WALL_THICKNESS * 2 + 8
	if spacing < minSpacing then
		warn("StudioZoneBuilder: spacing " .. tostring(spacing) .. " is too tight for the zone walls; using " .. tostring(minSpacing) .. " instead.")
		spacing = minSpacing
	end
	local direction = getLayoutDirection(map)
	local firstWorld = ColorData.Worlds[1]
	local firstZone = firstWorld and findZoneForWorld(map, firstWorld.primaryColor)
	local origin = firstZone and firstZone.Position or Vector3.zero
	local moved = 0

	for index, world in ipairs(ColorData.Worlds) do
		local zone = findZoneForWorld(map, world.primaryColor)
		if zone then
			local targetCenter = origin + direction * ((index - 1) * spacing)
			local delta = targetCenter - zone.Position
			if delta.Magnitude > 0.001 then
				for _, obj in ipairs(map:GetDescendants()) do
					if obj:IsA("BasePart") and getObjectWorldColor(obj) == world.primaryColor then
						obj.CFrame += delta
						moved += 1
					end
				end
			end
		else
			warn("StudioZoneBuilder: missing zone for " .. world.name .. "; skipped compacting that world.")
		end
	end

	StudioZoneBuilder.alignExistingGatesToWalls({
		width = options.gateWidth,
		height = options.gateHeight,
		depth = options.gateDepth,
	})

	print("StudioZoneBuilder: compacted worlds to " .. tostring(spacing) .. " studs apart and moved " .. tostring(moved) .. " parts.")
	return map
end

StudioZoneBuilder.compactWorlds = StudioZoneBuilder.compactExistingWorlds

function StudioZoneBuilder.makeWorldsBigAndClose(options)
	options = options or {}

	local map = workspace:FindFirstChild(MAP_NAME)
	if not map then
		warn("StudioZoneBuilder: no " .. MAP_NAME .. " found. Run .build({ overwrite = true }) first.")
		return nil
	end

	local worldSize = tonumber(options.worldSize or options.size) or BIG_WORLD_SIZE
	local gap = tonumber(options.gap) or BIG_WORLD_GAP
	local minSize = 320
	if worldSize < minSize then
		warn("StudioZoneBuilder: worldSize " .. tostring(worldSize) .. " is small; using " .. tostring(minSize) .. " instead.")
		worldSize = minSize
	end

	local spacing = tonumber(options.spacing) or (worldSize + WALL_THICKNESS * 2 + gap)
	local minSpacing = worldSize + WALL_THICKNESS * 2 + 2
	if spacing < minSpacing then
		warn("StudioZoneBuilder: spacing " .. tostring(spacing) .. " overlaps world walls; using " .. tostring(minSpacing) .. " instead.")
		spacing = minSpacing
	end

	local direction = getLayoutDirection(map)
	local firstWorld = ColorData.Worlds[1]
	local firstZone = firstWorld and findZoneForWorld(map, firstWorld.primaryColor)
	local origin = firstZone and firstZone.Position or Vector3.zero
	local moved = 0

	for index, world in ipairs(ColorData.Worlds) do
		local colorType = world.primaryColor
		local zone = findZoneForWorld(map, colorType)
		if zone then
			local oldCenter = zone.Position
			local oldSize = math.max(1, math.max(zone.Size.X, zone.Size.Z))
			local scale = worldSize / oldSize
			local targetCenter = origin + direction * ((index - 1) * spacing)

			for _, obj in ipairs(map:GetDescendants()) do
				if obj:IsA("BasePart") and getObjectWorldColor(obj) == colorType and not isWorldStructurePart(obj, colorType) then
					local offset = getWorldPositionOffset(obj.Position, oldCenter)
					local newOffset = scaleOffset(offset, scale)
					local y = obj.Position.Y
					obj.Position = Vector3.new(targetCenter.X + newOffset.X, y, targetCenter.Z + newOffset.Z)
					if obj:GetAttribute("AreaSpawn") then
						obj.Size = Vector3.new(math.max(18, obj.Size.X * scale), obj.Size.Y, math.max(18, obj.Size.Z * scale))
					elseif obj.Name == "SellZone" then
						obj.Size = Vector3.new(math.max(24, obj.Size.X * scale), obj.Size.Y, math.max(24, obj.Size.Z * scale))
					end
					moved += 1
				end
			end

			applyWorldShell(map, colorType, targetCenter, worldSize)
		else
			warn("StudioZoneBuilder: missing zone for " .. world.name .. "; skipped big close layout.")
		end
	end

	StudioZoneBuilder.alignExistingGatesToWalls({
		width = options.gateWidth,
		height = options.gateHeight,
		depth = options.gateDepth,
	})

	print("StudioZoneBuilder: made worlds " .. tostring(worldSize) .. " studs wide with " .. tostring(spacing) .. " stud center spacing; moved " .. tostring(moved) .. " parts.")
	return map
end

StudioZoneBuilder.bigCloseWorlds = StudioZoneBuilder.makeWorldsBigAndClose
StudioZoneBuilder.packBigWorlds = StudioZoneBuilder.makeWorldsBigAndClose

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

function findZoneForWorld(map, colorType)
	for _, obj in ipairs(map:GetDescendants()) do
		if obj:IsA("BasePart")
			and obj:GetAttribute("ColorZone")
			and (obj:GetAttribute("ColorType") == colorType or obj.Name == colorType .. "Zone")
		then
			return obj
		end
	end
	return nil
end

local function findSpawnForWorld(map, colorType)
	for _, obj in ipairs(map:GetDescendants()) do
		if obj:IsA("BasePart") then
			local spawnColor = obj:GetAttribute("AreaSpawnColor")
				or obj:GetAttribute("SpawnColor")
				or obj:GetAttribute("TeleportColor")
			if obj:GetAttribute("AreaSpawn") and (spawnColor == colorType or obj:GetAttribute("ColorType") == colorType) then
				return obj
			end
		end
	end

	local found = map:FindFirstChild(colorType .. "Spawn", true)
	return found and found:IsA("BasePart") and found or nil
end

local function clampToZone(zone, position, margin)
	if not zone then
		return position
	end

	margin = margin or 36
	local minX = zone.Position.X - zone.Size.X / 2 + margin
	local maxX = zone.Position.X + zone.Size.X / 2 - margin
	local minZ = zone.Position.Z - zone.Size.Z / 2 + margin
	local maxZ = zone.Position.Z + zone.Size.Z / 2 - margin

	return Vector3.new(
		math.clamp(position.X, minX, maxX),
		position.Y,
		math.clamp(position.Z, minZ, maxZ)
	)
end

local function getNearSpawnGateCFrame(previousZone, currentZone, spawn, distance, sideOffset, height)
	height = height or GATE_HEIGHT
	distance = distance or 48
	sideOffset = sideOffset or 18

	local previousCenter = previousZone and previousZone.Position or Vector3.zero
	local currentCenter = currentZone and currentZone.Position or previousCenter + Vector3.new(ZONE_SPACING, 0, 0)
	local direction = getFlatDirection(previousCenter, currentCenter)
	local lateral = Vector3.new(-direction.Z, 0, direction.X)
	local anchor = spawn and spawn.Position or previousCenter
	local groundY = anchor.Y + ((spawn and spawn.Size.Y or ZONE_SIZE.Y) / 2)
	local position = Vector3.new(anchor.X, groundY + height / 2, anchor.Z)
		+ direction * distance
		+ lateral * sideOffset

	position = clampToZone(previousZone, position, 42)
	return CFrame.lookAt(position, position - direction)
end

local function findGatePart(gatesFolder, world)
	local exact = gatesFolder:FindFirstChild(world.primaryColor .. "Gate", true)
	if exact and exact:IsA("BasePart") then
		return exact
	end

	for _, obj in ipairs(gatesFolder:GetDescendants()) do
		if obj:IsA("BasePart")
			and not obj:GetAttribute("GateDecor")
			and not obj:GetAttribute("GateInteraction")
			and getWorldFromGate(obj) == world
		then
			return obj
		end
	end

	return nil
end

local function findGateDecor(gatesFolder, colorType, suffix)
	local found = gatesFolder:FindFirstChild(colorType .. suffix, true)
	return found and found:IsA("BasePart") and found or nil
end

local function placeGateAssembly(gatesFolder, gate, world, gateCFrame, gateWidth, gateHeight, gateDepth)
	local worldColor = ColorData.Colors[world.primaryColor] and ColorData.Colors[world.primaryColor].color or Color3.fromRGB(120, 220, 255)
	local frameColor = Color3.fromRGB(35, 38, 65)

	gate.Name = world.primaryColor .. "Gate"
	gate.Anchored = true
	gate.Size = Vector3.new(gateWidth, gateHeight, gateDepth)
	gate.CFrame = gateCFrame
	gate.Material = Enum.Material.SmoothPlastic
	gate.Color = worldColor:Lerp(Color3.fromRGB(35, 38, 45), 0.45)
	gate.Transparency = 0.18
	gate.CanCollide = true
	gate:SetAttribute("AreaGate", true)
	gate:SetAttribute("GateColor", world.primaryColor)
	gate:SetAttribute("UnlockColor", world.primaryColor)
	gate:SetAttribute("ColorType", world.primaryColor)
	for _, child in ipairs(gate:GetChildren()) do
		if child:IsA("BillboardGui") or child:IsA("SurfaceGui") then
			child:Destroy()
		end
	end

	ensureGatePrompt(gate, world, gateWidth, gateHeight, gateDepth)

	local leftPost = findGateDecor(gatesFolder, world.primaryColor, "GateLeftPost")
	local rightPost = findGateDecor(gatesFolder, world.primaryColor, "GateRightPost")
	local topBeam = findGateDecor(gatesFolder, world.primaryColor, "GateTopBeam")
	setPartLocal(leftPost, gateCFrame, Vector3.new(7, gateHeight + 8, gateDepth + 2), Vector3.new(-gateWidth / 2 - 3.5, 0, 0), frameColor, Enum.Material.SmoothPlastic)
	setPartLocal(rightPost, gateCFrame, Vector3.new(7, gateHeight + 8, gateDepth + 2), Vector3.new(gateWidth / 2 + 3.5, 0, 0), frameColor, Enum.Material.SmoothPlastic)
	setPartLocal(topBeam, gateCFrame, Vector3.new(gateWidth + 10, 7, gateDepth + 2), Vector3.new(0, gateHeight / 2 + 3.5, 0), frameColor, Enum.Material.SmoothPlastic)

	for i = 1, 3 do
		local stripe = findGateDecor(gatesFolder, world.primaryColor, "GateGlow" .. i)
		if stripe then
			local stripeColor = worldColor:Lerp(Color3.fromRGB(255, 255, 255), i * 0.18)
			setPartLocal(stripe, gateCFrame, Vector3.new(2, 30 - i * 4, gateDepth + 1), Vector3.new((i - 2) * 11, 0, -gateDepth / 2 - 0.45), stripeColor, Enum.Material.Neon)
			stripe.Transparency = 0.35 + i * 0.12
		end
	end
end

function StudioZoneBuilder.alignExistingGatesToWalls(options)
	options = options or {}

	local map = workspace:FindFirstChild(MAP_NAME)
	if not map then
		warn("StudioZoneBuilder: no " .. MAP_NAME .. " found. Run .build({ overwrite = true }) first.")
		return nil
	end

	local gatesFolder = map:FindFirstChild("Gates")
	if not gatesFolder then
		warn("StudioZoneBuilder: no Gates folder found.")
		return map
	end

	local aligned = 0
	for index, world in ipairs(ColorData.Worlds) do
		if index > 1 then
			local previousWorld = ColorData.Worlds[index - 1]
			local previousZone = findZoneForWorld(map, previousWorld.primaryColor)
			local currentZone = findZoneForWorld(map, world.primaryColor)
			local gate = findGatePart(gatesFolder, world)

			if not previousZone or not currentZone then
				warn("StudioZoneBuilder: missing zone for " .. world.name .. "; skipped gate alignment.")
			elseif not gate then
				warn("StudioZoneBuilder: missing gate part for " .. world.name .. "; skipped.")
			else
				local gateWidth = tonumber(options.width) or GATE_WIDTH
				local gateHeight = tonumber(options.height) or GATE_HEIGHT
				local gateDepth = tonumber(options.depth) or GATE_DEPTH
				local gateCFrame = getWallGateCFrame(previousZone, currentZone, gateHeight, gateDepth)
				local worldColor = ColorData.Colors[world.primaryColor] and ColorData.Colors[world.primaryColor].color or Color3.fromRGB(120, 220, 255)
				local frameColor = Color3.fromRGB(35, 38, 65)

				gate.Name = world.primaryColor .. "Gate"
				gate.Anchored = true
				gate.Size = Vector3.new(gateWidth, gateHeight, gateDepth)
				gate.CFrame = gateCFrame
				gate.Material = Enum.Material.SmoothPlastic
				gate.Color = worldColor:Lerp(Color3.fromRGB(35, 38, 45), 0.45)
				gate.Transparency = 0.18
				gate.CanCollide = true
				gate:SetAttribute("AreaGate", true)
				gate:SetAttribute("GateColor", world.primaryColor)
				gate:SetAttribute("UnlockColor", world.primaryColor)
				gate:SetAttribute("ColorType", world.primaryColor)
				for _, child in ipairs(gate:GetChildren()) do
					if child:IsA("BillboardGui") or child:IsA("SurfaceGui") then
						child:Destroy()
					end
				end

				ensureGatePrompt(gate, world, gateWidth, gateHeight, gateDepth)

				local leftPost = findGateDecor(gatesFolder, world.primaryColor, "GateLeftPost")
				local rightPost = findGateDecor(gatesFolder, world.primaryColor, "GateRightPost")
				local topBeam = findGateDecor(gatesFolder, world.primaryColor, "GateTopBeam")
				setPartLocal(leftPost, gateCFrame, Vector3.new(7, gateHeight + 8, gateDepth + 2), Vector3.new(-gateWidth / 2 - 3.5, 0, 0), frameColor, Enum.Material.SmoothPlastic)
				setPartLocal(rightPost, gateCFrame, Vector3.new(7, gateHeight + 8, gateDepth + 2), Vector3.new(gateWidth / 2 + 3.5, 0, 0), frameColor, Enum.Material.SmoothPlastic)
				setPartLocal(topBeam, gateCFrame, Vector3.new(gateWidth + 10, 7, gateDepth + 2), Vector3.new(0, gateHeight / 2 + 3.5, 0), frameColor, Enum.Material.SmoothPlastic)

				for i = 1, 3 do
					local stripe = findGateDecor(gatesFolder, world.primaryColor, "GateGlow" .. i)
					if stripe then
						local stripeColor = worldColor:Lerp(Color3.fromRGB(255, 255, 255), i * 0.18)
						setPartLocal(stripe, gateCFrame, Vector3.new(2, 30 - i * 4, gateDepth + 1), Vector3.new((i - 2) * 11, 0, -gateDepth / 2 - 0.45), stripeColor, Enum.Material.Neon)
						stripe.Transparency = 0.35 + i * 0.12
					end
				end

				aligned += 1
				print("StudioZoneBuilder: aligned " .. gate.Name .. " against the wall.")
			end
		end
	end

	print("StudioZoneBuilder: aligned " .. tostring(aligned) .. " gates against their walls.")
	return map
end

function StudioZoneBuilder.refreshWorldPortals(options)
	options = options or {}
	local map = workspace:FindFirstChild(MAP_NAME)
	if not map then
		warn("StudioZoneBuilder: no " .. MAP_NAME .. " found.")
		return nil
	end

	local gatesFolder = map:FindFirstChild("Gates")
	if gatesFolder and options.align ~= false then
		StudioZoneBuilder.alignExistingGatesToWalls(options)
	end

	local refreshed = 0
	for _, gate in ipairs(map:GetDescendants()) do
		if gate:IsA("BasePart")
			and gate:GetAttribute("AreaGate")
			and not gate:GetAttribute("GateDecor")
			and not gate:GetAttribute("GateInteraction")
		then
			local targetColor = gate:GetAttribute("GateColor") or gate:GetAttribute("UnlockColor") or gate:GetAttribute("ColorType")
			local world = ColorData.getWorldByColor(targetColor)
			if world then
				local worldColor = ColorData.Colors[world.primaryColor] and ColorData.Colors[world.primaryColor].color or Color3.fromRGB(120, 220, 255)
				gate.Color = worldColor:Lerp(Color3.fromRGB(35, 38, 45), 0.35)
				gate.Material = Enum.Material.SmoothPlastic
				gate.Transparency = 0.16
				refreshed += 1
			end
		end
	end

	print("StudioZoneBuilder: refreshed " .. tostring(refreshed) .. " world portals using each next zone color.")
	return map
end

function StudioZoneBuilder.placeExistingGatesNearSpawns(options)
	options = options or {}

	local map = workspace:FindFirstChild(MAP_NAME)
	if not map then
		warn("StudioZoneBuilder: no " .. MAP_NAME .. " found. Run .build({ overwrite = true }) first.")
		return nil
	end

	local gatesFolder = map:FindFirstChild("Gates")
	if not gatesFolder then
		warn("StudioZoneBuilder: no Gates folder found.")
		return map
	end

	local gateWidth = tonumber(options.width) or GATE_WIDTH
	local gateHeight = tonumber(options.height) or GATE_HEIGHT
	local gateDepth = tonumber(options.depth) or GATE_DEPTH
	local distance = tonumber(options.distance) or 44
	local sideOffset = tonumber(options.sideOffset) or 18
	local placed = 0

	for index, world in ipairs(ColorData.Worlds) do
		if index > 1 then
			local previousWorld = ColorData.Worlds[index - 1]
			local previousZone = findZoneForWorld(map, previousWorld.primaryColor)
			local currentZone = findZoneForWorld(map, world.primaryColor)
			local previousSpawn = findSpawnForWorld(map, previousWorld.primaryColor)
			local gate = findGatePart(gatesFolder, world)

			if not previousZone or not currentZone then
				warn("StudioZoneBuilder: missing zone for " .. world.name .. "; skipped quick gate placement.")
			elseif not gate then
				warn("StudioZoneBuilder: missing gate part for " .. world.name .. "; skipped.")
			else
				local gateCFrame = getNearSpawnGateCFrame(previousZone, currentZone, previousSpawn, distance, sideOffset, gateHeight)
				placeGateAssembly(gatesFolder, gate, world, gateCFrame, gateWidth, gateHeight, gateDepth)
				placed += 1
				print("StudioZoneBuilder: placed " .. gate.Name .. " near " .. previousWorld.name .. " spawn.")
			end
		end
	end

	print("StudioZoneBuilder: placed " .. tostring(placed) .. " gates near their previous-world spawns.")
	return map
end

StudioZoneBuilder.placeGatesNearSpawns = StudioZoneBuilder.placeExistingGatesNearSpawns
StudioZoneBuilder.quickPlaceGates = StudioZoneBuilder.placeExistingGatesNearSpawns

function StudioZoneBuilder.upgradeExistingGates()
	local map = workspace:FindFirstChild(MAP_NAME)
	if not map then
		warn("StudioZoneBuilder: no " .. MAP_NAME .. " found. Run .build({ overwrite = true }) first.")
		return nil
	end

	local gatesFolder = map:FindFirstChild("Gates")
	if not gatesFolder then
		warn("StudioZoneBuilder: no Gates folder found.")
		return map
	end

	for _, gate in ipairs(gatesFolder:GetChildren()) do
		if gate:IsA("BasePart") and gate:GetAttribute("AreaGate") then
			local colorType = gate:GetAttribute("GateColor") or gate:GetAttribute("ColorType")
			local world = ColorData.getWorldByColor(colorType)
			if world then
				local worldColor = ColorData.Colors[world.primaryColor] and ColorData.Colors[world.primaryColor].color or Color3.fromRGB(120, 220, 255)
				gate.Size = Vector3.new(38, 34, 8)
				gate.Material = Enum.Material.Neon
				gate.Color = worldColor:Lerp(Color3.fromRGB(255, 255, 255), 0.25)
				gate.Transparency = 0.12
				gate.CanCollide = false

				ensureGatePrompt(gate, world, gate.Size.X, gate.Size.Y, gate.Size.Z)
			end
		end
	end

	print("StudioZoneBuilder: upgraded existing gates with prompts.")
	return map
end

local EDITABLE_BUILDER_ID = "StudioZoneBuilder"
local EDITABLE_MAP_ATTRIBUTE = "BakedEditableMap"

local EDITABLE_COLORS = {
	dark = Color3.fromRGB(34, 31, 42),
	cream = Color3.fromRGB(255, 246, 224),
	creamPath = Color3.fromRGB(255, 236, 194),
	lobbyGrass = Color3.fromRGB(116, 216, 130),
	lobbyGreen = Color3.fromRGB(72, 176, 108),
	redFloor = Color3.fromRGB(234, 76, 88),
	redSoft = Color3.fromRGB(255, 122, 145),
	redDeep = Color3.fromRGB(164, 38, 54),
	cyan = Color3.fromRGB(91, 230, 235),
	blue = Color3.fromRGB(88, 174, 255),
	yellow = Color3.fromRGB(255, 218, 74),
	gold = Color3.fromRGB(255, 192, 46),
	green = Color3.fromRGB(91, 228, 126),
	purple = Color3.fromRGB(177, 141, 255),
	pink = Color3.fromRGB(255, 105, 165),
	orange = Color3.fromRGB(255, 174, 72),
	white = Color3.fromRGB(255, 255, 255),
}

local function canRunEditableBuilder(actionName)
	if not RunService:IsStudio() then
		warn("StudioZoneBuilder." .. actionName .. " can only be used in Roblox Studio.")
		return false
	end
	if RunService:IsRunning() then
		warn("StudioZoneBuilder." .. actionName .. " should be run from the Studio Command Bar in edit mode, not during Play.")
		return false
	end
	return true
end

local function markEditable(instance, zoneId)
	if not instance then
		return instance
	end
	instance.Archivable = true
	instance:SetAttribute("GeneratedBy", EDITABLE_BUILDER_ID)
	instance:SetAttribute("EditablePlaceholder", true)
	if zoneId then
		instance:SetAttribute("ZoneId", zoneId)
	end
	return instance
end

local function getOrCreateEditableFolder(parent, name, zoneId)
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		markEditable(existing, zoneId)
		return existing
	end
	if existing then
		warn("StudioZoneBuilder: " .. parent:GetFullName() .. "." .. name .. " already exists and is not a Folder.")
		return nil
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return markEditable(folder, zoneId)
end

local function getOrCreateEditableMap()
	local map = workspace:FindFirstChild(MAP_NAME)
	if not map then
		map = Instance.new("Folder")
		map.Name = MAP_NAME
		map.Parent = workspace
	end

	map.Archivable = true
	map:SetAttribute(EDITABLE_MAP_ATTRIBUTE, true)
	map:SetAttribute("UseBakedMap", true)
	map:SetAttribute("GeneratedBy", EDITABLE_BUILDER_ID)

	local folders = {
		"Lobby",
		"RedZone",
		"BlueZone",
		"GreenZone",
		"PurpleZone",
		"Gates",
		"Spawns",
		"Stations",
		"Decorations",
		"ColorBlobSpawns",
	}

	for _, folderName in ipairs(folders) do
		getOrCreateEditableFolder(map, folderName, folderName)
	end

	return map
end

local function getOrCreateEditablePart(parent, name, className, size, cframe, color, material, zoneId, options)
	options = options or {}
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("BasePart") then
		markEditable(existing, zoneId)
		return existing
	end
	if existing then
		warn("StudioZoneBuilder: " .. parent:GetFullName() .. "." .. name .. " already exists and is not a BasePart.")
		return nil
	end

	local part = Instance.new(className or "Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = options.canCollide ~= false
	part.CanTouch = options.canTouch == true
	part.CanQuery = options.canQuery ~= false
	part.CastShadow = options.castShadow == true
	part.Transparency = options.transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent

	if part:IsA("SpawnLocation") then
		part.Neutral = true
		part.Duration = 0
		part.AllowTeamChangeOnTouch = false
	end

	return markEditable(part, zoneId)
end

local function setAttributes(instance, attributes)
	for key, value in pairs(attributes or {}) do
		instance:SetAttribute(key, value)
	end
end

local function ensurePrompt(parent, name, actionText, objectText, maxDistance)
	local prompt = parent:FindFirstChild(name)
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = name
		prompt.Parent = parent
	end
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = maxDistance or 16
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	return markEditable(prompt, parent:GetAttribute("ZoneId"))
end

local function ensureEditableBillboard(parent, name, title, subtitle, offset, titleColor)
	local billboard = parent:FindFirstChild(name)
	if not billboard then
		billboard = Instance.new("BillboardGui")
		billboard.Name = name
		billboard.Parent = parent
	end

	billboard.Size = UDim2.fromOffset(260, subtitle and 82 or 58)
	billboard.StudsOffset = offset or Vector3.new(0, 6, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 120
	billboard.Enabled = true
	billboard.LightInfluence = 0
	markEditable(billboard, parent:GetAttribute("ZoneId"))

	local frame = billboard:FindFirstChild("Backing")
	if not frame then
		frame = Instance.new("Frame")
		frame.Name = "Backing"
		frame.Parent = billboard
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 14)
		corner.Parent = frame
		local stroke = Instance.new("UIStroke")
		stroke.Name = "Outline"
		stroke.Parent = frame
	end
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = EDITABLE_COLORS.cream
	frame.BackgroundTransparency = 0.04
	frame.BorderSizePixel = 0
	local stroke = frame:FindFirstChild("Outline")
	if stroke then
		stroke.Color = EDITABLE_COLORS.dark
		stroke.Thickness = 3
	end

	local titleLabel = frame:FindFirstChild("Title")
	if not titleLabel then
		titleLabel = Instance.new("TextLabel")
		titleLabel.Name = "Title"
		titleLabel.Parent = frame
	end
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.new(1, -18, 0, subtitle and 44 or 52)
	titleLabel.Position = UDim2.new(0, 9, 0, 4)
	titleLabel.Font = Enum.Font.LuckiestGuy
	titleLabel.TextScaled = true
	titleLabel.TextColor3 = titleColor or EDITABLE_COLORS.dark
	titleLabel.TextStrokeColor3 = EDITABLE_COLORS.dark
	titleLabel.TextStrokeTransparency = titleColor and 0.12 or 1
	titleLabel.Text = title
	titleLabel.TextXAlignment = Enum.TextXAlignment.Center
	titleLabel.TextYAlignment = Enum.TextYAlignment.Center
	local titleConstraint = titleLabel:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
	titleConstraint.MaxTextSize = 26
	titleConstraint.MinTextSize = 12
	titleConstraint.Parent = titleLabel

	local subLabel = frame:FindFirstChild("Subtitle")
	if subtitle then
		if not subLabel then
			subLabel = Instance.new("TextLabel")
			subLabel.Name = "Subtitle"
			subLabel.Parent = frame
		end
		subLabel.BackgroundTransparency = 1
		subLabel.Size = UDim2.new(1, -24, 0, 28)
		subLabel.Position = UDim2.new(0, 12, 0, 48)
		subLabel.Font = Enum.Font.GothamBold
		subLabel.TextSize = 15
		subLabel.TextColor3 = EDITABLE_COLORS.dark
		subLabel.Text = subtitle
		subLabel.TextXAlignment = Enum.TextXAlignment.Center
		subLabel.TextYAlignment = Enum.TextYAlignment.Center
	elseif subLabel then
		subLabel:Destroy()
	end
end

local function makeDecorationOrb(parent, name, cframe, color, zoneId)
	local orb = getOrCreateEditablePart(
		parent,
		name,
		"Part",
		Vector3.new(5, 5, 5),
		cframe,
		color,
		Enum.Material.Neon,
		zoneId,
		{ canCollide = false, canTouch = false }
	)
	if orb then
		orb.Shape = Enum.PartType.Ball
		setAttributes(orb, { Decoration = true })
	end
	return orb
end

local function makePaintTree(parent, name, baseCFrame, trunkColor, leafColor, zoneId)
	local trunk = getOrCreateEditablePart(
		parent,
		name .. "_Trunk",
		"Part",
		Vector3.new(3, 14, 3),
		baseCFrame * CFrame.new(0, 7, 0),
		trunkColor,
		Enum.Material.Wood,
		zoneId
	)
	if trunk then
		setAttributes(trunk, { Decoration = true })
	end
	makeDecorationOrb(parent, name .. "_BlobTop", baseCFrame * CFrame.new(0, 16, 0), leafColor, zoneId)
	makeDecorationOrb(parent, name .. "_BlobSideA", baseCFrame * CFrame.new(-4, 14, 1), leafColor:Lerp(EDITABLE_COLORS.white, 0.12), zoneId)
	makeDecorationOrb(parent, name .. "_BlobSideB", baseCFrame * CFrame.new(4, 14, -1), leafColor:Lerp(EDITABLE_COLORS.dark, 0.08), zoneId)
end

local function makeFlatArrow(parent, name, cframe, length, color, zoneId)
	local shaft = getOrCreateEditablePart(
		parent,
		name .. "_Shaft",
		"Part",
		Vector3.new(5, 0.25, length),
		cframe,
		color,
		Enum.Material.Neon,
		zoneId,
		{ canCollide = false, transparency = 0.2 }
	)
	if shaft then
		setAttributes(shaft, { Decoration = true })
	end

	local head = getOrCreateEditablePart(
		parent,
		name .. "_Head",
		"Part",
		Vector3.new(13, 0.3, 13),
		cframe * CFrame.new(0, 0, -length / 2 - 4) * CFrame.Angles(0, math.rad(45), 0),
		color,
		Enum.Material.Neon,
		zoneId,
		{ canCollide = false, transparency = 0.12 }
	)
	if head then
		setAttributes(head, { Decoration = true })
	end
end

function StudioZoneBuilder.BuildEditableLobby()
	if not canRunEditableBuilder("BuildEditableLobby") then
		return nil
	end

	local map = getOrCreateEditableMap()
	local lobby = map:FindFirstChild("Lobby")
	local decorations = map:FindFirstChild("Decorations")
	local lobbyDecor = getOrCreateEditableFolder(lobby, "LobbyDecorations", "Lobby")

	local floor = getOrCreateEditablePart(
		lobby,
		"LobbyFloor",
		"Part",
		Vector3.new(150, 1, 120),
		CFrame.new(-240, 0, 0),
		EDITABLE_COLORS.lobbyGrass,
		Enum.Material.Grass,
		"Lobby"
	)
	if floor then
		setAttributes(floor, { LobbyFloor = true })
	end

	local plaza = getOrCreateEditablePart(
		lobby,
		"LobbyPlaza",
		"Part",
		Vector3.new(82, 0.35, 62),
		CFrame.new(-240, 0.72, 0),
		EDITABLE_COLORS.creamPath,
		Enum.Material.SmoothPlastic,
		"Lobby"
	)
	if plaza then
		plaza.Transparency = math.min(plaza.Transparency, 0.02)
		setAttributes(plaza, { Decoration = true })
	end

	local spawn = getOrCreateEditablePart(
		lobby,
		"LobbySpawnPad",
		"SpawnLocation",
		Vector3.new(28, 1, 28),
		CFrame.new(-240, 1.35, 22),
		EDITABLE_COLORS.cyan,
		Enum.Material.Neon,
		"Lobby"
	)
	if spawn then
		setAttributes(spawn, { LobbySpawn = true, AreaSpawn = true, AreaSpawnColor = "Lobby", SpawnColor = "Lobby" })
	end

	local welcome = getOrCreateEditablePart(
		lobby,
		"WelcomeSign",
		"Part",
		Vector3.new(44, 18, 2),
		CFrame.new(-240, 10, 50),
		EDITABLE_COLORS.dark,
		Enum.Material.SmoothPlastic,
		"Lobby"
	)
	if welcome then
		ensureEditableBillboard(welcome, "WelcomeLabel", "WELCOME", "Start here", Vector3.new(0, 12, 0), EDITABLE_COLORS.cyan)
	end

	local info = getOrCreateEditablePart(
		lobby,
		"HowToPlayBoard",
		"Part",
		Vector3.new(54, 17, 2),
		CFrame.new(-298, 9.5, -12) * CFrame.Angles(0, math.rad(24), 0),
		EDITABLE_COLORS.purple,
		Enum.Material.SmoothPlastic,
		"Lobby"
	)
	if info then
		ensureEditableBillboard(info, "HowToPlayLabel", "HOW TO PLAY", "Collect, sell, hatch, upgrade", Vector3.new(0, 12, 0), EDITABLE_COLORS.white)
	end

	local updateBoard = getOrCreateEditablePart(
		lobby,
		"UpdateBoard",
		"Part",
		Vector3.new(20, 11, 0.6),
		CFrame.lookAt(Vector3.new(-188, 7.5, 4), Vector3.new(-240, 7.5, 22)),
		EDITABLE_COLORS.dark,
		Enum.Material.SmoothPlastic,
		"Lobby"
	)
	if updateBoard then
		setAttributes(updateBoard, {
			BoardType = "Updates",
			UpdateBoardFace = "Front",
		})
	end

	local path = getOrCreateEditablePart(
		lobby,
		"LobbyPath_ToRedZone",
		"Part",
		Vector3.new(34, 0.3, 96),
		CFrame.new(-240, 0.9, -88),
		EDITABLE_COLORS.creamPath,
		Enum.Material.SmoothPlastic,
		"Lobby",
		{ canCollide = false }
	)
	if path then
		setAttributes(path, { Decoration = true })
	end

	local portal = getOrCreateEditablePart(
		lobby,
		"RedZonePortal",
		"Part",
		Vector3.new(42, 24, 5),
		CFrame.new(-240, 13, -145),
		EDITABLE_COLORS.redSoft,
		Enum.Material.Neon,
		"Lobby",
		{ canCollide = false, canTouch = true, transparency = 0.12 }
	)
	if portal then
		setAttributes(portal, {
			LobbyRedZonePortal = true,
			PortalTarget = "Red",
			TeleportColor = "Red",
			ColorType = "Red",
		})
		local prompt = ensurePrompt(portal, "RedZonePortalPrompt", "Enter", "Red Zone", 22)
		if prompt then
			prompt:SetAttribute("LobbyRedZonePortalPrompt", true)
		end
		ensureEditableBillboard(portal, "RedZonePortalLabel", "ENTER RED ZONE", "Start collecting Color", Vector3.new(0, 17, 0), EDITABLE_COLORS.white)
	end

	local glow = getOrCreateEditablePart(
		lobby,
		"RedZonePortalGlow",
		"Part",
		Vector3.new(58, 1, 22),
		CFrame.new(-240, 1.1, -138),
		EDITABLE_COLORS.redSoft,
		Enum.Material.Neon,
		"Lobby",
		{ canCollide = false, transparency = 0.45 }
	)
	if glow then
		setAttributes(glow, { Decoration = true })
	end

	makePaintTree(lobbyDecor, "LobbyPaintTree_001", CFrame.new(-306, 1, 42), EDITABLE_COLORS.dark, EDITABLE_COLORS.cyan, "Lobby")
	makePaintTree(lobbyDecor, "LobbyPaintTree_002", CFrame.new(-176, 1, 36), EDITABLE_COLORS.dark, EDITABLE_COLORS.green, "Lobby")
	makeDecorationOrb(lobbyDecor, "LobbyPaintOrb_001", CFrame.new(-286, 4, -54), EDITABLE_COLORS.pink, "Lobby")
	makeDecorationOrb(lobbyDecor, "LobbyPaintOrb_002", CFrame.new(-196, 4, -58), EDITABLE_COLORS.yellow, "Lobby")

	if decorations then
		markEditable(decorations, "Decorations")
	end

	print("StudioZoneBuilder: editable Lobby is ready under Workspace.ColorSimulatorMap.Lobby.")
	return map
end

function StudioZoneBuilder.BuildEditableRedZone()
	if not canRunEditableBuilder("BuildEditableRedZone") then
		return nil
	end

	local map = getOrCreateEditableMap()
	local redZone = map:FindFirstChild("RedZone")
	local gates = map:FindFirstChild("Gates")
	local stations = map:FindFirstChild("Stations")
	local globalSpawns = map:FindFirstChild("ColorBlobSpawns")
	local decorations = map:FindFirstChild("Decorations")
	local blobSpawns = getOrCreateEditableFolder(redZone, "ColorBlobSpawns", "RedZone")
	local redDecor = getOrCreateEditableFolder(redZone, "Decorations", "RedZone")
	local redWorld = ColorData.getWorldByColor("Red")
	local orangeWorld = ColorData.getWorldByColor("Orange")

	local floor = getOrCreateEditablePart(
		redZone,
		"RedZoneFloor",
		"Part",
		Vector3.new(220, 1, 220),
		CFrame.new(0, 0, 0),
		EDITABLE_COLORS.redFloor,
		Enum.Material.SmoothPlastic,
		"RedZone"
	)
	if floor then
		setAttributes(floor, { ZoneFloor = true, ColorType = "Red" })
	end

	local collection = getOrCreateEditablePart(
		redZone,
		"RedZoneCollectionField",
		"Part",
		Vector3.new(124, 0.45, 86),
		CFrame.new(0, 1.0, -10),
		EDITABLE_COLORS.redSoft,
		Enum.Material.SmoothPlastic,
		"RedZone",
		{ canCollide = false, transparency = 0.08 }
	)
	if collection then
		setAttributes(collection, {
			ColorZone = true,
			ColorType = "Red",
			WorldId = redWorld and redWorld.id or "Red",
			WorldName = redWorld and redWorld.name or "Starter Field",
			BlobCount = redWorld and redWorld.blobCount or 82,
			RewardMultiplier = redWorld and redWorld.rewardMultiplier or 1,
		})
	end

	local pathMain = getOrCreateEditablePart(
		redZone,
		"RedZonePath_Main",
		"Part",
		Vector3.new(36, 0.3, 190),
		CFrame.new(0, 1.22, 0),
		EDITABLE_COLORS.creamPath,
		Enum.Material.SmoothPlastic,
		"RedZone",
		{ canCollide = false }
	)
	if pathMain then
		setAttributes(pathMain, { Decoration = true })
	end

	local arrival = getOrCreateEditablePart(
		redZone,
		"RedZoneArrivalSpawn",
		"Part",
		Vector3.new(32, 1, 24),
		CFrame.new(0, 1.35, 92),
		EDITABLE_COLORS.cyan,
		Enum.Material.Neon,
		"RedZone"
	)
	if arrival then
		arrival.CanCollide = true
		setAttributes(arrival, {
			AreaSpawn = true,
			AreaSpawnColor = "Red",
			SpawnColor = "Red",
			TeleportColor = "Red",
			ColorType = "Red",
			LobbyPortalArrival = true,
		})
		ensureEditableBillboard(arrival, "RedZoneArrivalLabel", "RED AREA", "Brush the paint", Vector3.new(0, 6, 0), EDITABLE_COLORS.cyan)
	end

	local walls = {
		{ "RedZoneWall_North", Vector3.new(226, 20, 5), CFrame.new(0, 10.5, -112.5) },
		{ "RedZoneWall_South", Vector3.new(226, 20, 5), CFrame.new(0, 10.5, 112.5) },
		{ "RedZoneWall_West", Vector3.new(5, 20, 226), CFrame.new(-112.5, 10.5, 0) },
		{ "RedZoneWall_East", Vector3.new(5, 20, 226), CFrame.new(112.5, 10.5, 0) },
	}
	for _, wallInfo in ipairs(walls) do
		local wall = getOrCreateEditablePart(
			redZone,
			wallInfo[1],
			"Part",
			wallInfo[2],
			wallInfo[3],
			EDITABLE_COLORS.redDeep,
			Enum.Material.SmoothPlastic,
			"RedZone",
			{ transparency = 0.08 }
		)
		if wall then
			setAttributes(wall, { Boundary = true, ColorType = "Red" })
		end
	end

	local function disableLegacyRedStation(name)
		local station = redZone:FindFirstChild(name)
		if not station then
			return
		end
		for _, obj in ipairs(station:GetDescendants()) do
			if obj:IsA("ProximityPrompt") or obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
				obj.Enabled = false
			end
		end
		if station:IsA("BasePart") then
			station.CanTouch = false
			station.CanCollide = false
			station.Transparency = math.max(station.Transparency, 0.9)
		end
	end

	for _, stationName in ipairs({
		"RedZoneSellStation",
		"RedZoneStarterEggStation",
		"RedZoneStarterEgg",
		"RedZoneShopStand",
		"RedZoneUpgradeStand",
	}) do
		disableLegacyRedStation(stationName)
	end

	local legacyBlueGate = gates and gates:FindFirstChild("RedZoneBlueGate")
	if legacyBlueGate and not gates:FindFirstChild("RedZoneOrangeGate") then
		legacyBlueGate.Name = "RedZoneOrangeGate"
	end

	local orangeGate = getOrCreateEditablePart(
		gates,
		"RedZoneOrangeGate",
		"Part",
		Vector3.new(44, 32, 7),
		CFrame.new(0, 16, -111),
		EDITABLE_COLORS.orange,
		Enum.Material.Neon,
		"RedZone",
		{ canCollide = true, canTouch = false, transparency = 0.12 }
	)
	if orangeGate then
		setAttributes(orangeGate, {
			AreaGate = true,
			GateColor = "Orange",
			UnlockColor = "Orange",
			ColorType = "Orange",
			PreviousZoneId = "RedZone",
		})
		ensureEditableBillboard(orangeGate, "OrangeGateLabel", "NEXT AREA", orangeWorld and orangeWorld.name or "Orange Grove", Vector3.new(0, 23, 0), EDITABLE_COLORS.orange)
	end

	local spawnPoints = {
		Vector3.new(-48, 1.7, -42),
		Vector3.new(-28, 1.7, -46),
		Vector3.new(-8, 1.7, -48),
		Vector3.new(12, 1.7, -46),
		Vector3.new(34, 1.7, -42),
		Vector3.new(50, 1.7, -24),
		Vector3.new(36, 1.7, -8),
		Vector3.new(18, 1.7, 6),
		Vector3.new(-4, 1.7, 8),
		Vector3.new(-26, 1.7, 6),
		Vector3.new(-46, 1.7, -8),
		Vector3.new(-54, 1.7, -26),
		Vector3.new(-20, 1.7, -24),
		Vector3.new(20, 1.7, -24),
		Vector3.new(0, 1.7, -66),
		Vector3.new(0, 1.7, 26),
	}
	for index, position in ipairs(spawnPoints) do
		local marker = getOrCreateEditablePart(
			blobSpawns,
			string.format("RedZoneColorBlobSpawn_%03d", index),
			"Part",
			Vector3.new(7, 0.35, 7),
			CFrame.new(position),
			EDITABLE_COLORS.orange,
			Enum.Material.Neon,
			"RedZone",
			{ canCollide = false, canTouch = false, transparency = 0.55 }
		)
		if marker then
			setAttributes(marker, {
				SpawnType = "ColorBlob",
				ColorBlobSpawn = true,
				ColorType = "Red",
				ZoneId = "RedZone",
			})
		end
	end
	if globalSpawns then
		markEditable(globalSpawns, "ColorBlobSpawns")
	end
	if stations then
		markEditable(stations, "Stations")
	end
	if decorations then
		markEditable(decorations, "Decorations")
	end

	makeFlatArrow(redDecor, "RedZoneArrow_ArrivalToCollect", CFrame.new(0, 1.55, 56), 42, EDITABLE_COLORS.cyan, "RedZone")
	makeFlatArrow(redDecor, "RedZoneArrow_CollectToGate", CFrame.new(0, 1.55, -48), 72, EDITABLE_COLORS.orange, "RedZone")
	makePaintTree(redDecor, "RedPaintTree_001", CFrame.new(-92, 1, -78), EDITABLE_COLORS.dark, EDITABLE_COLORS.redSoft, "RedZone")
	makePaintTree(redDecor, "RedPaintTree_002", CFrame.new(92, 1, -72), EDITABLE_COLORS.dark, EDITABLE_COLORS.pink, "RedZone")
	makeDecorationOrb(redDecor, "RedCrystal_001", CFrame.new(-92, 5, 70), EDITABLE_COLORS.redSoft, "RedZone")
	makeDecorationOrb(redDecor, "RedCrystal_002", CFrame.new(92, 5, 72), EDITABLE_COLORS.orange, "RedZone")

	print("StudioZoneBuilder: editable Red Zone is ready under Workspace.ColorSimulatorMap.RedZone.")
	return map
end

function StudioZoneBuilder.BuildEditableZone(zoneId)
	local normalized = tostring(zoneId or ""):lower()
	if normalized == "lobby" then
		return StudioZoneBuilder.BuildEditableLobby()
	elseif normalized == "red" or normalized == "redzone" then
		return StudioZoneBuilder.BuildEditableRedZone()
	end

	if not canRunEditableBuilder("BuildEditableZone") then
		return nil
	end
	warn("StudioZoneBuilder: BuildEditableZone currently supports Lobby and RedZone. Requested: " .. tostring(zoneId))
	return getOrCreateEditableMap()
end

function StudioZoneBuilder.BuildEditableStarterMap()
	if not canRunEditableBuilder("BuildEditableStarterMap") then
		return nil
	end

	local map = getOrCreateEditableMap()
	StudioZoneBuilder.BuildEditableLobby()
	StudioZoneBuilder.BuildEditableRedZone()
	print("StudioZoneBuilder: full editable starter map is ready. Move/edit parts in Workspace.ColorSimulatorMap, then save the place.")
	return map
end

function StudioZoneBuilder.ClearGeneratedPreviewMap()
	if not canRunEditableBuilder("ClearGeneratedPreviewMap") then
		return nil
	end

	local map = workspace:FindFirstChild(MAP_NAME)
	if not map then
		warn("StudioZoneBuilder: no " .. MAP_NAME .. " found to clear.")
		return nil
	end

	local removable = {}
	for _, obj in ipairs(map:GetDescendants()) do
		if obj:GetAttribute("GeneratedBy") == EDITABLE_BUILDER_ID and obj:GetAttribute("EditablePlaceholder") == true then
			table.insert(removable, obj)
		end
	end

	table.sort(removable, function(a, b)
		return #a:GetDescendants() > #b:GetDescendants()
	end)

	local removed = 0
	for _, obj in ipairs(removable) do
		if obj.Parent and obj ~= map then
			obj:Destroy()
			removed += 1
		end
	end

	print("StudioZoneBuilder: cleared " .. tostring(removed) .. " generated editable placeholder objects. Untagged manual objects were left alone.")
	return map
end

function StudioZoneBuilder.RebuildEditableMap()
	if not canRunEditableBuilder("RebuildEditableMap") then
		return nil
	end

	StudioZoneBuilder.ClearGeneratedPreviewMap()
	return StudioZoneBuilder.BuildEditableStarterMap()
end

local function getUpdateBoardCandidates(map)
	local candidates = {}
	local seen = {}

	local function add(candidate)
		if candidate and not seen[candidate] then
			seen[candidate] = true
			table.insert(candidates, candidate)
		end
	end

	local lobby = map and map:FindFirstChild("Lobby")
	add(lobby and lobby:FindFirstChild("UpdateBoard"))
	add(map and map:FindFirstChild("UpdateBoard"))
	add(workspace:FindFirstChild("UpdateBoard", true))
	add(workspace:FindFirstChild("Board", true))

	local ok, selection = pcall(function()
		return game:GetService("Selection")
	end)
	if ok and selection then
		for _, selected in ipairs(selection:Get()) do
			if selected.Name == "Board" or selected.Name == "UpdateBoard" or selected:GetAttribute("BoardType") == "Updates" then
				add(selected)
			end
		end
	end

	if map then
		for _, obj in ipairs(map:GetDescendants()) do
			if obj.Name == "UpdateBoard" or (obj.Name == "Board" and obj:GetAttribute("BoardType") == "Updates") then
				add(obj)
			end
		end
	end

	return candidates
end

local function getJoinGroupBoardCandidates(map)
	local candidates = {}
	local seen = {}

	local function add(candidate)
		if candidate and not seen[candidate] then
			seen[candidate] = true
			table.insert(candidates, candidate)
		end
	end

	local lobby = map and map:FindFirstChild("Lobby")
	add(lobby and lobby:FindFirstChild("JOINGROUP"))
	add(lobby and lobby:FindFirstChild("JoinGroupBoard"))
	add(map and map:FindFirstChild("JOINGROUP", true))
	add(map and map:FindFirstChild("JoinGroupBoard", true))
	add(workspace:FindFirstChild("JOINGROUP", true))
	add(workspace:FindFirstChild("JoinGroupBoard", true))

	local ok, selection = pcall(function()
		return game:GetService("Selection")
	end)
	if ok and selection then
		for _, selected in ipairs(selection:Get()) do
			local name = string.lower(selected.Name or "")
			if name == "joingroup" or name == "joingroupboard" or selected:GetAttribute("BoardType") == "JoinGroup" then
				add(selected)
			end
		end
	end

	if map then
		for _, obj in ipairs(map:GetDescendants()) do
			local name = string.lower(obj.Name or "")
			if name == "joingroup" or name == "joingroupboard" or obj:GetAttribute("BoardType") == "JoinGroup" then
				add(obj)
			end
		end
	end

	return candidates
end

local function getUpdateBoardDisplayPart(board)
	if not board then
		return nil
	end
	if board:IsA("BasePart") then
		return board
	end

	for _, name in ipairs({ "BoardScreen", "Board", "Screen", "Display", "Panel", "UpdateBoard" }) do
		local found = board:FindFirstChild(name, true)
		if found and found:IsA("BasePart") then
			return found
		end
	end

	local best = nil
	local bestArea = -math.huge
	for _, obj in ipairs(board:GetDescendants()) do
		if obj:IsA("BasePart") then
			local area = obj.Size.X * obj.Size.Y
			if area > bestArea then
				bestArea = area
				best = obj
			end
		end
	end
	return best
end

local function getBoardFace(screen, attributeName)
	local faceName = screen:GetAttribute(attributeName or "BoardFace")
	local face = Enum.NormalId.Front
	if type(faceName) == "string" then
		for _, enumItem in ipairs(Enum.NormalId:GetEnumItems()) do
			if enumItem.Name == faceName then
				face = enumItem
				break
			end
		end
	end
	return face
end

local function findUpdateBoardSpawnTarget(map)
	local lobby = map and map:FindFirstChild("Lobby")
	local lobbySpawn = lobby and lobby:FindFirstChild("LobbySpawnPad", true)
	if lobbySpawn and lobbySpawn:IsA("BasePart") then
		return lobbySpawn.Position
	end

	local mapSpawn = map and map:FindFirstChildWhichIsA("SpawnLocation", true)
	if mapSpawn then
		return mapSpawn.Position
	end

	local workspaceSpawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if workspaceSpawn then
		return workspaceSpawn.Position
	end

	local lobbyPart = lobby and lobby:FindFirstChildWhichIsA("BasePart", true)
	if lobbyPart then
		return lobbyPart.Position
	end

	return Vector3.new(-240, 1, 22)
end

local function removeOldUpdateBoardUi(board)
	for _, obj in ipairs(board:GetDescendants()) do
		if (obj:IsA("BillboardGui")
				and (obj.Name == "UpdateLabel"
				or obj.Name == "UpdateBoardLabel"
				or obj.Name == "UpdateBoardBillboard"
				or obj:GetAttribute("UpdateBoardLabel") == true))
			or (obj:IsA("SurfaceGui") and obj.Name == "UpdateBoardSurfaceGui")
		then
			obj:Destroy()
		end
	end
end

local function removeOldJoinGroupBoardUi(board)
	for _, obj in ipairs(board:GetDescendants()) do
		if (obj:IsA("BillboardGui")
				and (obj.Name == "JoinGroupLabel"
				or obj.Name == "JoinGroupBoardLabel"
				or obj:GetAttribute("JoinGroupBoardLabel") == true))
			or (obj:IsA("SurfaceGui") and obj.Name == "JoinGroupBoardSurfaceGui")
		then
			obj:Destroy()
		end
	end
end

local function addBoardText(parent, name, text, position, size, textSize, color, font, alignment)
	local label = Instance.new("TextLabel")
	local maxTextSize = textSize or 18
	local readableColor = color or Color3.fromRGB(255, 255, 255)
	if readableColor.R * 0.2126 + readableColor.G * 0.7152 + readableColor.B * 0.0722 < 0.45 then
		readableColor = Color3.fromRGB(255, 255, 255)
	end
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = font or Enum.Font.GothamBold
	label.TextSize = maxTextSize
	label.TextScaled = true
	label.TextColor3 = readableColor
	label.TextStrokeColor3 = Color3.fromRGB(8, 14, 32)
	label.TextStrokeTransparency = 0
	label.TextXAlignment = alignment or Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextWrapped = true
	label.Text = text
	label.ZIndex = 2
	label.Parent = parent

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = 10
	constraint.MaxTextSize = maxTextSize
	constraint.Parent = label
	return label
end

local function addBoardPanel(parent, name, position, size, backgroundColor, strokeColor)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Position = position
	frame.Size = size
	frame.BackgroundColor3 = backgroundColor
	frame.BorderSizePixel = 0
	frame.Parent = parent
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 18)

	local strokeObj = Instance.new("UIStroke")
	strokeObj.Color = strokeColor
	strokeObj.Thickness = 5
	strokeObj.Transparency = 0.08
	strokeObj.Parent = frame

	return frame
end

local function bakeUpdateBoardSurface(screen)
	local face = getBoardFace(screen, "UpdateBoardFace")

	local surface = Instance.new("SurfaceGui")
	surface.Name = "UpdateBoardSurfaceGui"
	surface.Face = face
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 55
	surface.LightInfluence = 0
	surface.Brightness = 1.4
	surface.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	surface.Parent = screen

	local root = Instance.new("Frame")
	root.Name = "UpdateBoardRoot"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Color3.fromRGB(16, 18, 26)
	root.BorderSizePixel = 0
	root.Parent = surface

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(22, 27, 42)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(35, 24, 36)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 20, 28)),
	})
	gradient.Rotation = 20
	gradient.Parent = root

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(118, 238, 244)
	stroke.Thickness = 8
	stroke.Transparency = 0.08
	stroke.Parent = root

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Position = UDim2.new(0.035, 0, 0.035, 0)
	header.Size = UDim2.new(0.93, 0, 0.18, 0)
	header.BackgroundColor3 = Color3.fromRGB(118, 238, 244)
	header.BorderSizePixel = 0
	header.Parent = root
	Instance.new("UICorner", header).CornerRadius = UDim.new(0, 18)

	addBoardText(header, "Title", "COLOR SIMULATOR", UDim2.new(0.035, 0, 0.1, 0), UDim2.new(0.62, 0, 0.72, 0), 50, Color3.fromRGB(255, 255, 255), Enum.Font.LuckiestGuy)
	local versionText = string.format("%s  |  %s", tostring(UpdateLogData.CurrentVersion), tostring(UpdateLogData.Status))
	addBoardText(header, "Version", versionText, UDim2.new(0.62, 0, 0.22, 0), UDim2.new(0.34, 0, 0.48, 0), 22, Color3.fromRGB(35, 38, 45), Enum.Font.GothamBlack, Enum.TextXAlignment.Right)

	addBoardText(root, "LatestTitle", tostring(UpdateLogData.Latest.Title), UDim2.new(0.06, 0, 0.235, 0), UDim2.new(0.88, 0, 0.07, 0), 32, Color3.fromRGB(255, 235, 105), Enum.Font.GothamBlack)
	addBoardText(root, "LatestSubtitle", tostring(UpdateLogData.Latest.Subtitle), UDim2.new(0.06, 0, 0.305, 0), UDim2.new(0.88, 0, 0.07, 0), 20, Color3.fromRGB(232, 239, 255), Enum.Font.GothamBold)

	local changesText = ""
	for _, change in ipairs(UpdateLogData.Latest.Changes or {}) do
		changesText = changesText .. "- " .. tostring(change) .. "\n"
	end
	local changesPanel = addBoardPanel(root, "ChangesPanel", UDim2.new(0.05, 0, 0.395, 0), UDim2.new(0.42, 0, 0.32, 0), Color3.fromRGB(31, 33, 48), Color3.fromRGB(118, 238, 244))
	addBoardText(changesPanel, "ChangesTitle", "WHAT'S LIVE", UDim2.new(0.05, 0, 0.06, 0), UDim2.new(0.9, 0, 0.13, 0), 21, Color3.fromRGB(118, 238, 244), Enum.Font.GothamBlack)
	addBoardText(changesPanel, "Changes", changesText, UDim2.new(0.05, 0, 0.22, 0), UDim2.new(0.9, 0, 0.72, 0), 17, Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold)

	local howToText = ""
	for _, step in ipairs(UpdateLogData.HowToPlay or {}) do
		howToText = howToText .. "- " .. tostring(step) .. "\n"
	end
	local howToPanel = addBoardPanel(root, "HowToPanel", UDim2.new(0.5, 0, 0.395, 0), UDim2.new(0.22, 0, 0.32, 0), Color3.fromRGB(37, 28, 42), Color3.fromRGB(255, 235, 105))
	addBoardText(howToPanel, "HowToTitle", "HOW TO PLAY", UDim2.new(0.07, 0, 0.06, 0), UDim2.new(0.86, 0, 0.13, 0), 19, Color3.fromRGB(255, 235, 105), Enum.Font.GothamBlack)
	addBoardText(howToPanel, "HowTo", howToText, UDim2.new(0.07, 0, 0.22, 0), UDim2.new(0.86, 0, 0.72, 0), 15, Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold)

	local comingSoonText = "COMING SOON\n"
	for _, item in ipairs(UpdateLogData.ComingSoon or {}) do
		comingSoonText = comingSoonText .. "- " .. tostring(item) .. "\n"
	end
	local soonPanel = addBoardPanel(root, "ComingSoonPanel", UDim2.new(0.75, 0, 0.395, 0), UDim2.new(0.2, 0, 0.32, 0), Color3.fromRGB(23, 34, 42), Color3.fromRGB(176, 246, 250))
	addBoardText(soonPanel, "ComingSoon", comingSoonText, UDim2.new(0.08, 0, 0.08, 0), UDim2.new(0.84, 0, 0.86, 0), 15, Color3.fromRGB(176, 246, 250), Enum.Font.GothamBold)

	local codeText = "CODE: " .. tostring(UpdateLogData.FeaturedCode.Code) .. "  -  " .. tostring(UpdateLogData.FeaturedCode.Reward)
	addBoardText(root, "Code", codeText, UDim2.new(0.06, 0, 0.745, 0), UDim2.new(0.88, 0, 0.055, 0), 24, Color3.fromRGB(116, 245, 42), Enum.Font.GothamBlack, Enum.TextXAlignment.Center)

	local liveText = "PLAYTEST FOCUS: " .. table.concat(UpdateLogData.PlaytestFocus or {}, "  |  ")
	addBoardText(root, "PlaytestFocus", liveText, UDim2.new(0.06, 0, 0.81, 0), UDim2.new(0.88, 0, 0.045, 0), 18, Color3.fromRGB(255, 225, 170), Enum.Font.GothamBlack, Enum.TextXAlignment.Center)
	addBoardText(root, "Footer", tostring(UpdateLogData.Footer) .. "  -  Updated " .. tostring(UpdateLogData.LastUpdated), UDim2.new(0.06, 0, 0.89, 0), UDim2.new(0.88, 0, 0.075, 0), 17, Color3.fromRGB(205, 210, 225), Enum.Font.GothamBold, Enum.TextXAlignment.Center)

	return surface
end

local function bakeJoinGroupBoardSurface(screen)
	local face = getBoardFace(screen, "JoinGroupBoardFace")

	local surface = Instance.new("SurfaceGui")
	surface.Name = "JoinGroupBoardSurfaceGui"
	surface.Face = face
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 60
	surface.LightInfluence = 0
	surface.Brightness = 1.55
	surface.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	surface.Parent = screen

	local root = Instance.new("Frame")
	root.Name = "JoinGroupBoardRoot"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Color3.fromRGB(17, 22, 31)
	root.BorderSizePixel = 0
	root.Parent = surface

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(16, 30, 48)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(18, 42, 54)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(35, 22, 50)),
	})
	gradient.Rotation = -15
	gradient.Parent = root

	local rootStroke = Instance.new("UIStroke")
	rootStroke.Color = Color3.fromRGB(116, 245, 42)
	rootStroke.Thickness = 8
	rootStroke.Transparency = 0.05
	rootStroke.Parent = root

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Position = UDim2.new(0.04, 0, 0.04, 0)
	header.Size = UDim2.new(0.92, 0, 0.22, 0)
	header.BackgroundColor3 = Color3.fromRGB(116, 245, 42)
	header.BorderSizePixel = 0
	header.Parent = root
	Instance.new("UICorner", header).CornerRadius = UDim.new(0, 18)

	addBoardText(header, "Title", "JOIN THE GROUP", UDim2.new(0.04, 0, 0.06, 0), UDim2.new(0.92, 0, 0.52, 0), 46, Color3.fromRGB(255, 255, 255), Enum.Font.LuckiestGuy, Enum.TextXAlignment.Center)
	addBoardText(header, "Subtitle", tostring(GroupRewardsConfig.GroupName), UDim2.new(0.04, 0, 0.6, 0), UDim2.new(0.92, 0, 0.28, 0), 22, Color3.fromRGB(23, 31, 35), Enum.Font.GothamBlack, Enum.TextXAlignment.Center)

	local rewardPanel = addBoardPanel(root, "RewardPanel", UDim2.new(0.06, 0, 0.31, 0), UDim2.new(0.42, 0, 0.42, 0), Color3.fromRGB(25, 35, 45), Color3.fromRGB(116, 245, 42))
	local luckPercent = math.floor(((tonumber(GroupRewardsConfig.LuckMultiplier) or 1) - 1) * 100 + 0.5)
	local coinPercent = math.floor(((tonumber(GroupRewardsConfig.CoinMultiplier) or 1) - 1) * 100 + 0.5)
	local rewardsText = string.format(
		"+%d%% Luck\n+%d%% Coins\n%d Gems every day",
		luckPercent,
		coinPercent,
		tonumber(GroupRewardsConfig.DailyGemReward) or 100
	)
	addBoardText(rewardPanel, "RewardsTitle", "GROUP REWARDS", UDim2.new(0.07, 0, 0.07, 0), UDim2.new(0.86, 0, 0.17, 0), 27, Color3.fromRGB(116, 245, 42), Enum.Font.GothamBlack, Enum.TextXAlignment.Center)
	addBoardText(rewardPanel, "Rewards", rewardsText, UDim2.new(0.07, 0, 0.31, 0), UDim2.new(0.86, 0, 0.58, 0), 30, Color3.fromRGB(255, 255, 255), Enum.Font.LuckiestGuy, Enum.TextXAlignment.Center)

	local howPanel = addBoardPanel(root, "HowPanel", UDim2.new(0.52, 0, 0.31, 0), UDim2.new(0.42, 0, 0.42, 0), Color3.fromRGB(28, 30, 48), Color3.fromRGB(118, 238, 244))
	addBoardText(howPanel, "HowTitle", "HOW TO CLAIM", UDim2.new(0.07, 0, 0.07, 0), UDim2.new(0.86, 0, 0.17, 0), 27, Color3.fromRGB(118, 238, 244), Enum.Font.GothamBlack, Enum.TextXAlignment.Center)
	addBoardText(howPanel, "How", "- Join the Roblox group\n- Rejoin or wait a moment\n- Open Group Rewards\n- Claim your daily Gems", UDim2.new(0.07, 0, 0.3, 0), UDim2.new(0.86, 0, 0.6, 0), 22, Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold, Enum.TextXAlignment.Left)

	addBoardText(root, "Footer", "Group bonuses are real gameplay boosts and stack with other rewards.", UDim2.new(0.06, 0, 0.78, 0), UDim2.new(0.88, 0, 0.07, 0), 22, Color3.fromRGB(255, 235, 105), Enum.Font.GothamBlack, Enum.TextXAlignment.Center)
	addBoardText(root, "Url", "Community ID: " .. tostring(GroupRewardsConfig.GROUP_ID), UDim2.new(0.06, 0, 0.88, 0), UDim2.new(0.88, 0, 0.055, 0), 17, Color3.fromRGB(205, 235, 245), Enum.Font.GothamBold, Enum.TextXAlignment.Center)

	return surface
end

function StudioZoneBuilder.RepairUpdateBoard()
	if not canRunEditableBuilder("RepairUpdateBoard") then
		return nil
	end

	local map = getOrCreateEditableMap()
	local lobby = map:FindFirstChild("Lobby") or getOrCreateEditableFolder(map, "Lobby", "Lobby")
	local candidates = getUpdateBoardCandidates(map)
	local board = candidates[1]
	local createdBoard = false
	if not board then
		board = getOrCreateEditablePart(
			lobby,
			"UpdateBoard",
			"Part",
			Vector3.new(20, 11, 0.6),
			CFrame.new(-188, 7.5, 4),
			EDITABLE_COLORS.dark,
			Enum.Material.SmoothPlastic,
			"Lobby"
		)
		createdBoard = true
		print("StudioZoneBuilder: created editable UpdateBoard placeholder.")
	end

	if #candidates > 1 then
		local paths = {}
		for _, duplicate in ipairs(candidates) do
			table.insert(paths, duplicate:GetFullName())
		end
		warn("StudioZoneBuilder: duplicate UpdateBoards found. Kept " .. board:GetFullName() .. ". Duplicates: " .. table.concat(paths, " | "))
	end

	local screen = getUpdateBoardDisplayPart(board)
	if not screen then
		warn("StudioZoneBuilder: UpdateBoard has no BasePart display.")
		return board
	end

	local target = findUpdateBoardSpawnTarget(map)
	local boardPosition = target + Vector3.new(26, 6.5, -16)
	if screen.Name == "Board" then
		screen.Name = "UpdateBoard"
	end
	screen.Size = Vector3.new(20, 11, 0.6)
	if createdBoard then
		screen.CFrame = CFrame.lookAt(boardPosition, Vector3.new(target.X, boardPosition.Y, target.Z))
	end
	screen.Color = EDITABLE_COLORS.dark
	screen.Material = Enum.Material.SmoothPlastic
	screen.Anchored = true
	screen.CanCollide = true
	screen.Archivable = true
	screen:SetAttribute("BoardType", "Updates")
	screen:SetAttribute("UpdateBoardFace", "Front")
	screen:SetAttribute("GeneratedBy", "UpdateBoardHandler")
	screen:SetAttribute("EditablePlaceholder", true)
	markEditable(screen, "Lobby")
	removeOldUpdateBoardUi(board)
	bakeUpdateBoardSurface(screen)

	print("StudioZoneBuilder: repaired and baked UpdateBoard to 20 x 11 x 0.6 studs, facing the lobby spawn.")
	return board
end

function StudioZoneBuilder.RepairGroupRewardBoard()
	if not canRunEditableBuilder("RepairGroupRewardBoard") then
		return nil
	end

	local map = getOrCreateEditableMap()
	local lobby = map:FindFirstChild("Lobby") or getOrCreateEditableFolder(map, "Lobby", "Lobby")
	local candidates = getJoinGroupBoardCandidates(map)
	local board = candidates[1]
	local createdBoard = false
	if not board then
		board = getOrCreateEditablePart(
			lobby,
			"JOINGROUP",
			"Part",
			Vector3.new(16, 9, 0.55),
			CFrame.new(-188, 7, 22),
			Color3.fromRGB(18, 22, 32),
			Enum.Material.SmoothPlastic,
			"Lobby"
		)
		createdBoard = true
		print("StudioZoneBuilder: created editable JOINGROUP board placeholder.")
	end

	if #candidates > 1 then
		local paths = {}
		for _, duplicate in ipairs(candidates) do
			table.insert(paths, duplicate:GetFullName())
		end
		warn("StudioZoneBuilder: duplicate Join Group boards found. Kept " .. board:GetFullName() .. ". Duplicates: " .. table.concat(paths, " | "))
	end

	local screen = getUpdateBoardDisplayPart(board)
	if not screen then
		warn("StudioZoneBuilder: Join Group board has no BasePart display.")
		return board
	end

	local target = findUpdateBoardSpawnTarget(map)
	local boardPosition = target + Vector3.new(26, 6.25, 8)
	if screen.Name ~= "JOINGROUP" then
		screen.Name = "JOINGROUP"
	end
	screen.Size = Vector3.new(16, 9, 0.55)
	if createdBoard then
		screen.CFrame = CFrame.lookAt(boardPosition, Vector3.new(target.X, boardPosition.Y, target.Z))
	end
	screen.Color = Color3.fromRGB(18, 22, 32)
	screen.Material = Enum.Material.SmoothPlastic
	screen.Anchored = true
	screen.CanCollide = true
	screen.Archivable = true
	screen:SetAttribute("BoardType", "JoinGroup")
	screen:SetAttribute("JoinGroupBoardFace", "Front")
	screen:SetAttribute("GeneratedBy", "StudioZoneBuilder")
	screen:SetAttribute("EditablePlaceholder", true)
	markEditable(screen, "Lobby")
	removeOldJoinGroupBoardUi(board)
	bakeJoinGroupBoardSurface(screen)

	print("StudioZoneBuilder: repaired and baked JOINGROUP board with group rewards info.")
	return board
end

function StudioZoneBuilder.RepairLobbyBoards()
	local updateBoard = StudioZoneBuilder.RepairUpdateBoard()
	local groupBoard = StudioZoneBuilder.RepairGroupRewardBoard()
	return {
		UpdateBoard = updateBoard,
		JoinGroupBoard = groupBoard,
	}
end

local DISTANT_SECTOR_COLUMN_COLORS = {
	Color3.fromRGB(88, 24, 34),
	Color3.fromRGB(116, 34, 38),
	Color3.fromRGB(152, 62, 42),
	Color3.fromRGB(62, 70, 84),
	Color3.fromRGB(36, 42, 54),
	Color3.fromRGB(172, 84, 42),
}

local function findDistantColumnOrigin(map)
	local candidates = {
		map and map:FindFirstChild("LobbyFloor1", true),
		map and map:FindFirstChild("RedFloor1", true),
		map and map:FindFirstChild("SpawnLocation", true),
		workspace:FindFirstChildWhichIsA("SpawnLocation", true),
	}

	for _, candidate in ipairs(candidates) do
		if candidate and candidate:IsA("BasePart") then
			return candidate.Position
		end
	end

	return Vector3.new(0, 0, 0)
end

local function clearDistantSectorColumnFolder(folder)
	local removed = 0
	for _, child in ipairs(folder:GetChildren()) do
		if child:GetAttribute("GeneratedBy") == EDITABLE_BUILDER_ID
			and child:GetAttribute("DistantSectorColumn") == true
		then
			child:Destroy()
			removed += 1
		end
	end
	return removed
end

local function makeDistantSectorColumn(folder, name, position, diameter, topY, bottomY, color, sectorColor, isSectorAnchor)
	local height = math.max(300, topY - bottomY)
	local centerY = bottomY + height * 0.5
	local part = getOrCreateEditablePart(
		folder,
		name,
		"Part",
		Vector3.new(diameter, height, diameter),
		CFrame.new(position.X, centerY, position.Z),
		color,
		Enum.Material.Slate,
		"DistantSectors",
		{
			canCollide = true,
			canTouch = false,
			canQuery = true,
			castShadow = false,
			transparency = 0,
		}
	)
	if not part then
		return nil
	end

	part.Shape = Enum.PartType.Cylinder
	part.Reflectance = 0.025
	part:SetAttribute("ColorZone", false)
	part:SetAttribute("ColorBlobSpawn", false)
	part:SetAttribute("DistantSectorColumn", true)
	part:SetAttribute("DecorativeOnly", not isSectorAnchor)
	part:SetAttribute("SectorAnchor", isSectorAnchor == true)
	part:SetAttribute("TopY", topY)
	part:SetAttribute("BottomY", bottomY)
	if sectorColor then
		part:SetAttribute("SectorColor", sectorColor)
	end
	return part
end

function StudioZoneBuilder.ClearEditableDistantSectorColumns()
	if not canRunEditableBuilder("ClearEditableDistantSectorColumns") then
		return nil
	end

	local map = workspace:FindFirstChild(MAP_NAME)
	local folder = map and map:FindFirstChild("DistantSectors")
	if not folder then
		warn("StudioZoneBuilder: no DistantSectors folder found.")
		return nil
	end

	local removed = clearDistantSectorColumnFolder(folder)
	print("StudioZoneBuilder: cleared " .. tostring(removed) .. " editable distant Sector columns.")
	return folder
end

function StudioZoneBuilder.BuildEditableDistantSectorColumns(options)
	if not canRunEditableBuilder("BuildEditableDistantSectorColumns") then
		return nil
	end

	options = options or {}
	local map = getOrCreateEditableMap()
	local folder = getOrCreateEditableFolder(map, "DistantSectors", "DistantSectors")
	if not folder then
		return nil
	end

	if options.clear ~= false then
		clearDistantSectorColumnFolder(folder)
	end

	local origin = findDistantColumnOrigin(map)
	local baseY = origin.Y
	local bottomY = tonumber(options.bottomY) or (baseY - 24000)
	local rows = {
		{ z = -520, xStart = -1180, count = 9, gap = 280 },
		{ z = -870, xStart = -1480, count = 11, gap = 300 },
		{ z = -1260, xStart = -1780, count = 13, gap = 320 },
		{ z = -1680, xStart = -2100, count = 15, gap = 340 },
	}
	local topOffsets = {
		-900, -620, -360, -140, 80, 260, 560, 920,
		1320, 1880, 2550, 3400, 4700, 6200,
	}
	local diameters = { 150, 190, 240, 290, 360, 440, 520 }

	local made = 0
	for rowIndex, row in ipairs(rows) do
		for columnIndex = 1, row.count do
			local n = (rowIndex - 1) * 20 + columnIndex
			local x = row.xStart + (columnIndex - 1) * row.gap
			local wave = math.sin(n * 1.73) * 0.5 + math.cos(n * 0.61) * 0.5
			local topY = baseY + topOffsets[(n % #topOffsets) + 1] + wave * 220
			local diameter = diameters[(n % #diameters) + 1]
			local color = DISTANT_SECTOR_COLUMN_COLORS[(n % #DISTANT_SECTOR_COLUMN_COLORS) + 1]
			local part = makeDistantSectorColumn(
				folder,
				string.format("DecorColumn_Row%02d_%02d", rowIndex, columnIndex),
				origin + Vector3.new(x, 0, row.z),
				diameter,
				topY,
				bottomY - rowIndex * 650,
				color,
				nil,
				false
			)
			if part then
				made += 1
			end
		end
	end

	local anchors = {
		{
			name = "SectorColumn_StartSectorCore",
			offset = Vector3.new(-520, 0, -520),
			diameter = 620,
			topY = baseY + 220,
			color = Color3.fromRGB(145, 36, 38),
			sectorColor = "Red",
		},
		{
			name = "SectorColumn_OrangeSectorLocked",
			offset = Vector3.new(860, 0, -900),
			diameter = 720,
			topY = baseY + 1350,
			color = Color3.fromRGB(192, 82, 34),
			sectorColor = "Orange",
		},
	}

	for _, spec in ipairs(anchors) do
		local part = makeDistantSectorColumn(
			folder,
			spec.name,
			origin + spec.offset,
			spec.diameter,
			spec.topY,
			bottomY - 1600,
			spec.color,
			spec.sectorColor,
			true
		)
		if part then
			made += 1
		end
	end

	print("StudioZoneBuilder: built " .. tostring(made) .. " editable distant Sector columns in Workspace.ColorSimulatorMap.DistantSectors. Move/scale/recolor them freely, then save the place.")
	return folder
end

local function applyEditableSectorAnchorAttributes(instance, config)
	instance:SetAttribute("DistantSectorColumn", true)
	instance:SetAttribute("SectorAnchor", true)
	instance:SetAttribute("DecorativeOnly", false)
	instance:SetAttribute("SectorName", config.displayName)
	instance:SetAttribute("SectorColor", config.sectorColor)
	instance:SetAttribute("SectorIndex", config.sectorIndex)
	instance:SetAttribute("SectorLocked", config.locked == true)
	instance:SetAttribute("ColorZone", false)
	instance:SetAttribute("ColorBlobSpawn", false)
	instance:SetAttribute("AreaGate", false)
	instance:SetAttribute("GateInteraction", false)
	instance:SetAttribute("ColorType", config.sectorColor)
	return markEditable(instance, "DistantSectors")
end

function StudioZoneBuilder.SetupEditableSectorModel(modelName, config)
	if not canRunEditableBuilder("SetupEditableSectorModel") then
		return nil
	end

	modelName = tostring(modelName or "sector1")
	config = config or {}
	config.displayName = config.displayName or "Orange Sector"
	config.sectorColor = config.sectorColor or "Orange"
	config.sectorIndex = tonumber(config.sectorIndex) or 2
	config.locked = config.locked ~= false

	local map = getOrCreateEditableMap()
	local distantSectors = getOrCreateEditableFolder(map, "DistantSectors", "DistantSectors")
	local model = workspace:FindFirstChild(modelName) or map:FindFirstChild(modelName, true)
	if not model then
		warn("StudioZoneBuilder: could not find model or part named " .. modelName)
		return nil
	end

	model.Parent = distantSectors
	applyEditableSectorAnchorAttributes(model, config)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = true
			descendant.CanTouch = false
			descendant.CanQuery = true
			applyEditableSectorAnchorAttributes(descendant, config)
		end
	end

	print("StudioZoneBuilder: set up " .. modelName .. " as locked " .. config.displayName .. " in Workspace.ColorSimulatorMap.DistantSectors.")
	return model
end

function StudioZoneBuilder.SetupSector1()
	return StudioZoneBuilder.SetupEditableSectorModel("sector1", {
		displayName = "Orange Sector",
		sectorColor = "Orange",
		sectorIndex = 2,
		locked = true,
	})
end

function StudioZoneBuilder.BuildDistantSectorColumns(options)
	return StudioZoneBuilder.BuildEditableDistantSectorColumns(options)
end

function StudioZoneBuilder.BuildEditableDistantSectorCollums(options)
	return StudioZoneBuilder.BuildEditableDistantSectorColumns(options)
end

function StudioZoneBuilder.BuildDistantSectorCollums(options)
	return StudioZoneBuilder.BuildEditableDistantSectorColumns(options)
end

function StudioZoneBuilder.BuildEditableDistantSectors(options)
	return StudioZoneBuilder.BuildEditableDistantSectorColumns(options)
end

function StudioZoneBuilder.BuildDistantSectors(options)
	return StudioZoneBuilder.BuildEditableDistantSectorColumns(options)
end

function StudioZoneBuilder.BuildEditableSectors(options)
	return StudioZoneBuilder.BuildEditableDistantSectorColumns(options)
end

function StudioZoneBuilder.BuildSectors(options)
	return StudioZoneBuilder.BuildEditableDistantSectorColumns(options)
end

function StudioZoneBuilder.ClearDistantSectorColumns()
	return StudioZoneBuilder.ClearEditableDistantSectorColumns()
end

function StudioZoneBuilder.ClearEditableDistantSectorCollums()
	return StudioZoneBuilder.ClearEditableDistantSectorColumns()
end

function StudioZoneBuilder.ClearDistantSectorCollums()
	return StudioZoneBuilder.ClearEditableDistantSectorColumns()
end

function StudioZoneBuilder.ClearEditableDistantSectors()
	return StudioZoneBuilder.ClearEditableDistantSectorColumns()
end

function StudioZoneBuilder.ClearDistantSectors()
	return StudioZoneBuilder.ClearEditableDistantSectorColumns()
end

StudioZoneBuilder.repairUpdateBoard = StudioZoneBuilder.RepairUpdateBoard
StudioZoneBuilder.repairUpdateboard = StudioZoneBuilder.RepairUpdateBoard
StudioZoneBuilder.BuildUpdateBoard = StudioZoneBuilder.RepairUpdateBoard
StudioZoneBuilder.buildUpdateBoard = StudioZoneBuilder.RepairUpdateBoard
StudioZoneBuilder.UpdateBoard = StudioZoneBuilder.RepairUpdateBoard
StudioZoneBuilder.updateBoard = StudioZoneBuilder.RepairUpdateBoard
StudioZoneBuilder.RepairBoard = StudioZoneBuilder.RepairUpdateBoard
StudioZoneBuilder.repairBoard = StudioZoneBuilder.RepairUpdateBoard
StudioZoneBuilder.BuildBoard = StudioZoneBuilder.RepairUpdateBoard
StudioZoneBuilder.buildBoard = StudioZoneBuilder.RepairUpdateBoard
StudioZoneBuilder.RepairGroupBoard = StudioZoneBuilder.RepairGroupRewardBoard
StudioZoneBuilder.repairGroupBoard = StudioZoneBuilder.RepairGroupRewardBoard
StudioZoneBuilder.BuildGroupBoard = StudioZoneBuilder.RepairGroupRewardBoard
StudioZoneBuilder.buildGroupBoard = StudioZoneBuilder.RepairGroupRewardBoard
StudioZoneBuilder.RepairJoinGroupBoard = StudioZoneBuilder.RepairGroupRewardBoard
StudioZoneBuilder.repairJoinGroupBoard = StudioZoneBuilder.RepairGroupRewardBoard
StudioZoneBuilder.BuildJoinGroupBoard = StudioZoneBuilder.RepairGroupRewardBoard
StudioZoneBuilder.buildJoinGroupBoard = StudioZoneBuilder.RepairGroupRewardBoard
StudioZoneBuilder.UpdateLobbyBoards = StudioZoneBuilder.RepairLobbyBoards
StudioZoneBuilder.updateLobbyBoards = StudioZoneBuilder.RepairLobbyBoards
StudioZoneBuilder.BuildLobbyBoards = StudioZoneBuilder.RepairLobbyBoards
StudioZoneBuilder.buildLobbyBoards = StudioZoneBuilder.RepairLobbyBoards

return StudioZoneBuilder
