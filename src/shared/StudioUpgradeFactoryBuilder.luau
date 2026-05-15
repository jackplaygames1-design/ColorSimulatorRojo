-- Studio-only builder for Sector 3: Upgrade Factory.
-- Run after your map exists:
-- require(game.ReplicatedStorage.StudioUpgradeFactoryBuilder).Build()

local Workspace = game:GetService("Workspace")

local StudioUpgradeFactoryBuilder = {}

local MAP_NAME = "ColorSimulatorMap"
local SECTOR_ID = "UpgradeFactory"
local SECTOR_NAME = "Upgrade Factory"
local ORIGIN = Vector3.new(0, 0, 520)

local COLORS = {
	floor = Color3.fromRGB(42, 58, 78),
	panel = Color3.fromRGB(55, 88, 115),
	cyan = Color3.fromRGB(72, 235, 255),
	blue = Color3.fromRGB(68, 135, 255),
	purple = Color3.fromRGB(155, 95, 255),
	gem = Color3.fromRGB(55, 255, 185),
	dark = Color3.fromRGB(24, 29, 43),
	white = Color3.fromRGB(235, 250, 255),
}

local function getMap()
	local map = Workspace:FindFirstChild(MAP_NAME)
	if not map then
		map = Instance.new("Folder")
		map.Name = MAP_NAME
		map.Parent = Workspace
	end
	return map
end

local function clearOld(parent)
	local old = parent:FindFirstChild(SECTOR_ID)
	if old then
		old:Destroy()
	end
end

local function folder(parent, name)
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end

local function part(parent, name, size, position, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = position
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function neon(parent, name, size, position, color)
	local p = part(parent, name, size, position, color, Enum.Material.Neon)
	p.CanCollide = false
	p.CastShadow = false
	return p
end

local function label(parentPart, text, offset, width, height)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(width or 260, height or 70)
	gui.StudsOffset = offset or Vector3.new(0, 8, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parentPart

	local txt = Instance.new("TextLabel")
	txt.BackgroundTransparency = 1
	txt.Size = UDim2.fromScale(1, 1)
	txt.Font = Enum.Font.LuckiestGuy
	txt.Text = text
	txt.TextScaled = true
	txt.TextColor3 = Color3.new(1, 1, 1)
	txt.TextStrokeColor3 = Color3.fromRGB(20, 24, 36)
	txt.TextStrokeTransparency = 0
	txt.Parent = gui
	return gui
end

local function addPrompt(target, name, action, objectText)
	local prompt = target:FindFirstChild(name)
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = name
		prompt.Parent = target
	end
	prompt.ActionText = action
	prompt.ObjectText = objectText
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("UpgradeFactoryPrompt", true)
	prompt:SetAttribute("SectorId", SECTOR_ID)
	return prompt
end

local function makeCrystal(parent, basePos, name, color, scale)
	scale = scale or 1
	local core = neon(
		parent,
		name .. "Crystal",
		Vector3.new(5 * scale, 10 * scale, 5 * scale),
		basePos + Vector3.new(0, 7 * scale, 0),
		color
	)
	core.Shape = Enum.PartType.Ball
	core:SetAttribute("UpgradeFactoryDecor", true)
	local light = Instance.new("PointLight")
	light.Name = "CrystalGlow"
	light.Color = color
	light.Brightness = 2.5
	light.Range = 24 * scale
	light.Shadows = false
	light.Parent = core
	return core
end

local function makeMachine(parent, center)
	local machine = folder(parent, "UpgradeStation")
	local base = part(
		machine,
		"UpgradeStationBase",
		Vector3.new(42, 5, 28),
		center + Vector3.new(0, 2.5, 0),
		COLORS.dark,
		Enum.Material.Metal
	)
	base:SetAttribute("UpgradeStation", true)
	base:SetAttribute("SectorId", SECTOR_ID)

	local console = part(
		machine,
		"UpgradeConsole",
		Vector3.new(16, 10, 10),
		center + Vector3.new(0, 9, -8),
		COLORS.panel,
		Enum.Material.Metal
	)
	console:SetAttribute("UpgradeStation", true)
	console:SetAttribute("SectorId", SECTOR_ID)
	label(console, "UPGRADE\nSTATION", Vector3.new(0, 8, 0), 210, 80)
	addPrompt(console, "UpgradeStationPrompt", "Open", "Upgrade Station")

	makeCrystal(machine, center + Vector3.new(0, 0, 8), "Center", COLORS.gem, 1.15)

	local tubes = {
		{ "Brush Power", -22, COLORS.cyan },
		{ "Walk Speed", -7, COLORS.blue },
		{ "Color Luck", 7, COLORS.purple },
		{ "Gem Boost", 22, COLORS.gem },
	}
	for _, data in ipairs(tubes) do
		local tube = neon(
			machine,
			data[1]:gsub("%s+", "") .. "Tube",
			Vector3.new(4, 16, 4),
			center + Vector3.new(data[2], 9, 13),
			data[3]
		)
		tube.Shape = Enum.PartType.Cylinder
		tube.CFrame = CFrame.new(tube.Position) * CFrame.Angles(0, 0, math.rad(90))
		label(tube, data[1], Vector3.new(0, 5, 0), 140, 42)
	end

	return machine
end

function StudioUpgradeFactoryBuilder.Build()
	local map = getMap()
	local sectors = folder(map, "Sectors")
	clearOld(sectors)

	local sector = folder(sectors, SECTOR_ID)
	sector:SetAttribute("SectorId", SECTOR_ID)
	sector:SetAttribute("DisplayName", SECTOR_NAME)
	sector:SetAttribute("UnlocksFeature", "Upgrades")
	sector:SetAttribute("RequiredPreviousSector", "InsidePipes")
	sector:SetAttribute("LockedByDefault", true)

	local floor =
		part(sector, "UpgradeFactoryFloor", Vector3.new(240, 1, 220), ORIGIN, COLORS.floor, Enum.Material.Metal)
	floor:SetAttribute("ColorZone", true)
	floor:SetAttribute("SectorId", SECTOR_ID)
	floor:SetAttribute("UnlocksFeature", "Upgrades")
	label(floor, "SECTOR 3\nUPGRADE FACTORY", Vector3.new(0, 12, 0), 320, 88)

	part(
		sector,
		"BackWall",
		Vector3.new(240, 55, 8),
		ORIGIN + Vector3.new(0, 27.5, 110),
		COLORS.panel,
		Enum.Material.Metal
	)
	part(
		sector,
		"LeftWall",
		Vector3.new(8, 55, 220),
		ORIGIN + Vector3.new(-120, 27.5, 0),
		COLORS.panel,
		Enum.Material.Metal
	)
	part(
		sector,
		"RightWall",
		Vector3.new(8, 55, 220),
		ORIGIN + Vector3.new(120, 27.5, 0),
		COLORS.panel,
		Enum.Material.Metal
	)

	local gate = part(
		sector,
		"UpgradeFactoryGate",
		Vector3.new(64, 42, 8),
		ORIGIN + Vector3.new(0, 21, -110),
		COLORS.dark,
		Enum.Material.Metal
	)
	gate.Transparency = 0.08
	gate:SetAttribute("AreaGate", true)
	gate:SetAttribute("SectorId", SECTOR_ID)
	gate:SetAttribute("UnlocksFeature", "Upgrades")
	label(gate, "UPGRADE FACTORY\nUNLOCKS UPGRADES", Vector3.new(0, 29, 0), 340, 90)
	addPrompt(gate, "UpgradeFactoryGatePrompt", "Unlock", "Upgrade Factory")

	for i = -2, 2 do
		neon(
			sector,
			"GateGlow" .. tostring(i),
			Vector3.new(4, 34, 2),
			ORIGIN + Vector3.new(i * 11, 21, -114),
			i % 2 == 0 and COLORS.cyan or COLORS.purple
		)
	end

	for i = 1, 10 do
		local x = -100 + (i - 1) * 22
		neon(
			sector,
			"FloorWire" .. i,
			Vector3.new(4, 0.25, 170),
			ORIGIN + Vector3.new(x, 1.1, 8),
			i % 2 == 0 and COLORS.blue or COLORS.cyan
		)
	end

	makeMachine(sector, ORIGIN + Vector3.new(0, 0, 20))
	makeCrystal(sector, ORIGIN + Vector3.new(-78, 0, 58), "LeftBattery", COLORS.blue, 0.8)
	makeCrystal(sector, ORIGIN + Vector3.new(78, 0, 58), "RightBattery", COLORS.purple, 0.8)

	print(
		"StudioUpgradeFactoryBuilder: built Sector 3 Upgrade Factory at Workspace."
			.. MAP_NAME
			.. ".Sectors."
			.. SECTOR_ID
	)
	return sector
end

StudioUpgradeFactoryBuilder.BuildUpgradeFactory = StudioUpgradeFactoryBuilder.Build

return StudioUpgradeFactoryBuilder
