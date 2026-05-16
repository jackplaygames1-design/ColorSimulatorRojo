-- Studio-only builder for editable sector interiors.
-- Command bar:
-- require(game.ReplicatedStorage.StudioSectorInteriorBuilder).BuildOrangeMutationInterior({ overwrite = true })
-- require(game.ReplicatedStorage.StudioSectorInteriorBuilder).BuildZorkOnPads()

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Builder = {}

local MAP_NAME = "ColorSimulatorMap"
local INTERIORS_FOLDER_NAME = "SectorInteriors"
local PIPES_FOLDER_NAME = "SectorPipes"
local ZORK_NAME = "Zork"

local COLORS = {
	Dark = Color3.fromRGB(17, 17, 20),
	Cyan = Color3.fromRGB(68, 218, 240),
	Orange = Color3.fromRGB(255, 132, 32),
	OrangeDark = Color3.fromRGB(172, 64, 16),
	OrangeDeep = Color3.fromRGB(98, 34, 14),
	Yellow = Color3.fromRGB(255, 216, 82),
	Green = Color3.fromRGB(125, 255, 112),
	Purple = Color3.fromRGB(145, 84, 255),
	White = Color3.fromRGB(255, 248, 232),
}

local function assertStudio()
	if not RunService:IsStudio() or RunService:IsRunning() then
		warn("StudioSectorInteriorBuilder: run this from the Studio command bar in edit mode.")
		return false
	end
	return true
end

local function getOrCreateFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end
	return folder
end

local function getMap()
	local map = Workspace:FindFirstChild(MAP_NAME)
	if not map then
		map = Instance.new("Folder")
		map.Name = MAP_NAME
		map.Parent = Workspace
	end
	return map
end

local function destroyIfOverwrite(parent, name, overwrite)
	local existing = parent:FindFirstChild(name)
	if existing and overwrite then
		existing:Destroy()
		return nil
	end
	return existing
end

local function makePart(parent, name, size, cframe, color, material, transparency)
	local part = parent:FindFirstChild(name)
	if not part then
		part = Instance.new("Part")
		part.Name = name
		part.Parent = parent
	end
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Transparency = transparency or 0
	part.Anchored = true
	part.CanCollide = true
	part.CanTouch = false
	part.CanQuery = true
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function makeCylinder(parent, name, size, cframe, color, material, transparency)
	local part = makePart(parent, name, size, cframe, color, material, transparency)
	part.Shape = Enum.PartType.Cylinder
	return part
end

local function makePrompt(parent, name, objectText, actionText, distance)
	local prompt = parent:FindFirstChild(name)
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = name
		prompt.Parent = parent
	end
	prompt.ObjectText = objectText
	prompt.ActionText = actionText
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = distance or 14
	prompt.RequiresLineOfSight = false
	return prompt
end

local function setShopAttrs(instance, colorType)
	instance:SetAttribute("BrushShop", true)
	instance:SetAttribute("CombinedShop", true)
	instance:SetAttribute("ShopStation", true)
	instance:SetAttribute("BrushNpc", true)
	instance:SetAttribute("ColorType", colorType)
	instance:SetAttribute("AreaColor", colorType)
	instance:SetAttribute("ShopColor", colorType)
end

local function setInteriorAttrs(instance, colorType)
	instance:SetAttribute("SectorInterior", true)
	instance:SetAttribute("SectorColor", colorType)
	instance:SetAttribute("ColorType", colorType)
	instance:SetAttribute("AreaColor", colorType)
	instance:SetAttribute("ColorZone", false)
	instance:SetAttribute("ColorBlobSpawn", false)
	instance:SetAttribute("DecorativeOnly", true)
end

local function addNameTag(core)
	local label = core:FindFirstChild("BrushNpcLabel")
	if not label then
		label = Instance.new("BillboardGui")
		label.Name = "BrushNpcLabel"
		label.Parent = core
	end
	label.AlwaysOnTop = true
	label.LightInfluence = 0
	label.MaxDistance = 70
	label.Size = UDim2.fromOffset(190, 58)
	label.StudsOffset = Vector3.new(0, 4.7, 0)

	local background = label:FindFirstChild("Background")
	if not background then
		background = Instance.new("Frame")
		background.Name = "Background"
		background.Parent = label
	end
	background.AnchorPoint = Vector2.new(0.5, 0.5)
	background.Position = UDim2.fromScale(0.5, 0.5)
	background.Size = UDim2.new(1, -14, 1, -8)
	background.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
	background.BackgroundTransparency = 0.18
	background.BorderSizePixel = 0
	local corner = background:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = background
	local stroke = background:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	stroke.Color = COLORS.Cyan
	stroke.Thickness = 2
	stroke.Transparency = 0.18
	stroke.Parent = background

	local name = label:FindFirstChild("Text")
	if not name then
		name = Instance.new("TextLabel")
		name.Name = "Text"
		name.Parent = label
	end
	name.Size = UDim2.new(1, -20, 0, 28)
	name.Position = UDim2.new(0, 10, 0, 6)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBlack
	name.TextSize = 20
	name.TextColor3 = COLORS.White
	name.TextStrokeTransparency = 0.35
	name.TextStrokeColor3 = COLORS.Dark
	name.Text = "Zork"

	local role = label:FindFirstChild("Role")
	if not role then
		role = Instance.new("TextLabel")
		role.Name = "Role"
		role.Parent = label
	end
	role.Size = UDim2.new(1, -20, 0, 20)
	role.Position = UDim2.new(0, 10, 0, 32)
	role.BackgroundTransparency = 1
	role.Font = Enum.Font.GothamBold
	role.TextSize = 12
	role.TextColor3 = Color3.fromRGB(170, 244, 248)
	role.TextStrokeTransparency = 0.65
	role.TextStrokeColor3 = COLORS.Dark
	role.Text = "Brush Merchant"
end

local function buildZorkAtPad(pad, colorType)
	colorType = colorType or pad:GetAttribute("ColorType") or pad:GetAttribute("SectorColor") or "Red"
	pad:SetAttribute("ZorkPad", true)
	pad:SetAttribute("ColorType", colorType)
	pad:SetAttribute("AreaColor", colorType)
	pad:SetAttribute("BrushShop", true)
	pad:SetAttribute("DecorativeOnly", true)

	local old = pad.Parent and pad.Parent:FindFirstChild(ZORK_NAME)
	if old and old:GetAttribute("BuiltFromZorkPad") == pad.Name then
		old:Destroy()
	end

	local npc = Instance.new("Model")
	npc.Name = ZORK_NAME
	npc:SetAttribute("BuiltFromZorkPad", pad.Name)
	npc.Parent = pad.Parent
	setShopAttrs(npc, colorType)

	local baseCFrame = pad.CFrame * CFrame.new(0, pad.Size.Y * 0.5 + 3.15, 0)
	local root =
		makePart(npc, "HumanoidRootPart", Vector3.new(2, 5, 2), baseCFrame, COLORS.Cyan, Enum.Material.SmoothPlastic, 1)
	root.CanCollide = false
	root.CanQuery = false
	npc.PrimaryPart = root

	local body = makePart(npc, "ColorBody", Vector3.new(3.2, 3.2, 3.2), baseCFrame, COLORS.Cyan, Enum.Material.Neon)
	body.Shape = Enum.PartType.Ball
	local core = makePart(
		npc,
		"ShopPromptCore",
		Vector3.new(3.8, 4.6, 3.8),
		baseCFrame,
		COLORS.Cyan,
		Enum.Material.SmoothPlastic,
		1
	)
	core.CanCollide = false
	local head = makePart(
		npc,
		"ColorHead",
		Vector3.new(1.7, 1.7, 1.7),
		baseCFrame * CFrame.new(0, 2.35, 0),
		COLORS.Green,
		Enum.Material.Neon
	)
	head.Shape = Enum.PartType.Ball
	local glow = makeCylinder(
		npc,
		"ColorGlow",
		Vector3.new(4.3, 0.25, 4.3),
		baseCFrame * CFrame.new(0, -1.75, 0) * CFrame.Angles(0, 0, math.rad(90)),
		COLORS.Cyan,
		Enum.Material.Neon,
		0.22
	)
	glow.CanCollide = false
	local handle = makeCylinder(
		npc,
		"BrushHandle",
		Vector3.new(0.28, 3.1, 0.28),
		baseCFrame * CFrame.new(1.75, 0.2, 0) * CFrame.Angles(0, 0, math.rad(24)),
		COLORS.Yellow,
		Enum.Material.SmoothPlastic
	)
	local bristles = makePart(
		npc,
		"BrushBristles",
		Vector3.new(0.8, 0.65, 0.8),
		baseCFrame * CFrame.new(2.35, 1.55, 0) * CFrame.Angles(0, 0, math.rad(24)),
		Color3.fromRGB(255, 85, 130),
		Enum.Material.Neon
	)
	bristles.Shape = Enum.PartType.Ball

	for _, part in ipairs({ root, body, core, head, glow, handle, bristles }) do
		part.CanCollide = false
		part.CanTouch = false
		setShopAttrs(part, colorType)
	end

	local prompt = makePrompt(core, "BrushShopPrompt", "Zork", "Talk", 14)
	prompt:SetAttribute("BrushShopPrompt", true)
	prompt:SetAttribute("CombinedShopPrompt", true)
	prompt:SetAttribute("BrushNpcDialogue", true)
	prompt:SetAttribute("NpcDialogueId", "Zork")
	prompt:SetAttribute("NpcName", "Zork")
	prompt:SetAttribute("ColorType", colorType)
	prompt:SetAttribute("ShopColor", colorType)
	addNameTag(core)
	return npc
end

function Builder.BuildZorkOnPads()
	if not assertStudio() then
		return 0
	end

	local built = 0
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if
			obj:IsA("BasePart")
			and (
				obj:GetAttribute("ZorkPad") == true
				or string.lower(obj.Name) == "zorkpad"
				or string.match(string.lower(obj.Name), "zorkpad$")
			)
		then
			buildZorkAtPad(obj)
			built += 1
		end
	end
	print("StudioSectorInteriorBuilder: baked Zork on " .. tostring(built) .. " Zork pad(s).")
	return built
end

local function findOrangeAnchor()
	local map = Workspace:FindFirstChild(MAP_NAME)
	local distant = map and map:FindFirstChild("DistantSectors")
	if distant then
		for _, obj in ipairs(distant:GetDescendants()) do
			if
				obj:IsA("BasePart")
				and (obj:GetAttribute("SectorColor") == "Orange" or obj:GetAttribute("ColorType") == "Orange")
			then
				return obj
			end
		end
	end
	local redFloor = map and map:FindFirstChild("RedFloor1", true)
	return redFloor
end

function Builder.BuildOrangeMutationInterior(options)
	if not assertStudio() then
		return nil
	end
	options = options or {}
	local overwrite = options.overwrite == true
	local map = getMap()
	local interiors = getOrCreateFolder(map, INTERIORS_FOLDER_NAME)
	local pipes = getOrCreateFolder(map, PIPES_FOLDER_NAME)
	local colorType = "Orange"

	local existingInterior = destroyIfOverwrite(interiors, "OrangeSectorInterior", overwrite)
	if existingInterior then
		warn(
			"StudioSectorInteriorBuilder: OrangeSectorInterior already exists. Pass { overwrite = true } to rebuild it."
		)
		return existingInterior
	end
	local existingPipe = pipes:FindFirstChild("OrangeSectorPipe")
	if existingPipe and overwrite then
		existingPipe:Destroy()
	elseif existingPipe then
		warn("StudioSectorInteriorBuilder: OrangeSectorPipe already exists. Pass { overwrite = true } to rebuild it.")
		return existingPipe
	end

	local anchor = findOrangeAnchor()
	local anchorPos = anchor and anchor.Position or Vector3.new(0, 0, 0)
	local pipeOrigin = anchorPos + Vector3.new(48, 8, -42)
	local interiorOrigin = options.interiorOrigin or Vector3.new(1800, -420, 1800)

	local interior = Instance.new("Folder")
	interior.Name = "OrangeSectorInterior"
	interior.Parent = interiors

	local floor = makePart(
		interior,
		"OrangeInteriorFloor",
		Vector3.new(430, 3, 430),
		CFrame.new(interiorOrigin),
		COLORS.OrangeDeep,
		Enum.Material.SmoothPlastic
	)
	floor:SetAttribute("MutationUnlockArea", true)
	setInteriorAttrs(floor, colorType)
	floor:SetAttribute("GroundPaintSurface", true)
	floor:SetAttribute("PlayableSectorFloor", true)
	floor:SetAttribute("ZoneFloor", true)
	floor:SetAttribute("ColorZone", true)
	floor:SetAttribute("DecorativeOnly", false)
	floor:SetAttribute("ZoneId", "OrangeGrove")

	local wallHeight = 180
	local wallY = interiorOrigin.Y + wallHeight * 0.5
	local walls = {
		makePart(
			interior,
			"OrangeWallNorth",
			Vector3.new(450, wallHeight, 14),
			CFrame.new(interiorOrigin.X, wallY, interiorOrigin.Z - 222),
			COLORS.Orange,
			Enum.Material.SmoothPlastic
		),
		makePart(
			interior,
			"OrangeWallSouth",
			Vector3.new(450, wallHeight, 14),
			CFrame.new(interiorOrigin.X, wallY, interiorOrigin.Z + 222),
			COLORS.OrangeDark,
			Enum.Material.SmoothPlastic
		),
		makePart(
			interior,
			"OrangeWallEast",
			Vector3.new(14, wallHeight, 450),
			CFrame.new(interiorOrigin.X + 222, wallY, interiorOrigin.Z),
			COLORS.Orange,
			Enum.Material.SmoothPlastic
		),
		makePart(
			interior,
			"OrangeWallWest",
			Vector3.new(14, wallHeight, 450),
			CFrame.new(interiorOrigin.X - 222, wallY, interiorOrigin.Z),
			COLORS.OrangeDark,
			Enum.Material.SmoothPlastic
		),
	}
	for _, wall in ipairs(walls) do
		setInteriorAttrs(wall, colorType)
	end

	for index = 1, 12 do
		local side = index % 4
		local x = interiorOrigin.X + ((index % 3) - 1) * 118
		local z = interiorOrigin.Z + (math.floor(index / 3) % 2 == 0 and -196 or 196)
		if side == 1 then
			x = interiorOrigin.X - 196
			z = interiorOrigin.Z + ((index % 4) - 1.5) * 86
		elseif side == 3 then
			x = interiorOrigin.X + 196
			z = interiorOrigin.Z + ((index % 4) - 1.5) * 86
		end
		local columnHeight = 80 + (index % 5) * 36
		local column = makePart(
			interior,
			"OrangeInteriorColumn_" .. string.format("%02d", index),
			Vector3.new(18, columnHeight, 18),
			CFrame.new(x, interiorOrigin.Y + columnHeight * 0.5, z),
			index % 2 == 0 and COLORS.Orange or COLORS.OrangeDark,
			Enum.Material.SmoothPlastic
		)
		setInteriorAttrs(column, colorType)
	end

	local spawn = makePart(
		interior,
		"OrangeInteriorSpawn",
		Vector3.new(28, 1, 28),
		CFrame.new(interiorOrigin + Vector3.new(0, 3, 172)),
		COLORS.Cyan,
		Enum.Material.Neon,
		0.12
	)
	spawn.CanCollide = false
	spawn:SetAttribute("SectorInteriorSpawn", true)
	spawn:SetAttribute("MutationUnlockArea", true)
	setInteriorAttrs(spawn, colorType)

	local zorkPad = makePart(
		interior,
		"OrangeZorkPad",
		Vector3.new(24, 1, 24),
		CFrame.new(interiorOrigin + Vector3.new(-74, 3, 80)),
		COLORS.Cyan,
		Enum.Material.Neon,
		0.08
	)
	zorkPad.CanCollide = false
	zorkPad:SetAttribute("ZorkPad", true)
	zorkPad:SetAttribute("MutationUnlockArea", true)
	setInteriorAttrs(zorkPad, colorType)
	buildZorkAtPad(zorkPad, colorType)

	local mutationStation = makePart(
		interior,
		"MutationUnlockStation",
		Vector3.new(42, 1.2, 32),
		CFrame.new(interiorOrigin + Vector3.new(78, 3, 78)),
		COLORS.Purple,
		Enum.Material.Neon,
		0.08
	)
	mutationStation.CanCollide = false
	mutationStation:SetAttribute("MutationUnlockStation", true)
	mutationStation:SetAttribute("MutationUnlockArea", true)
	mutationStation:SetAttribute("FeatureUnlock", "Mutations")
	setInteriorAttrs(mutationStation, colorType)

	local exitPipe = Instance.new("Model")
	exitPipe.Name = "OrangeInteriorExitPipe"
	exitPipe.Parent = interior
	local exitBase = interiorOrigin + Vector3.new(0, 12, 202)
	makeCylinder(
		exitPipe,
		"PipeRing",
		Vector3.new(24, 5, 24),
		CFrame.new(exitBase) * CFrame.Angles(0, 0, math.rad(90)),
		COLORS.Orange,
		Enum.Material.Neon
	)
	local exitTrigger = makePart(
		exitPipe,
		"OrangeInteriorExitTrigger",
		Vector3.new(22, 20, 10),
		CFrame.new(exitBase),
		COLORS.Cyan,
		Enum.Material.ForceField,
		0.86
	)
	exitTrigger.CanCollide = false
	exitTrigger.CanTouch = true
	exitTrigger:SetAttribute("SectorInteriorExit", true)
	exitTrigger:SetAttribute("SectorColor", colorType)
	exitTrigger:SetAttribute("ColorType", colorType)
	makePrompt(exitTrigger, "ExitSectorPrompt", "Orange Sector Pipe", "Exit", 14)

	local pipe = Instance.new("Model")
	pipe.Name = "OrangeSectorPipe"
	pipe.Parent = pipes
	local pipeCFrame = CFrame.new(pipeOrigin) * CFrame.Angles(0, math.rad(35), 0)
	makeCylinder(
		pipe,
		"PipeOuterRing",
		Vector3.new(34, 7, 34),
		pipeCFrame * CFrame.Angles(0, 0, math.rad(90)),
		COLORS.Orange,
		Enum.Material.Neon
	)
	makeCylinder(
		pipe,
		"PipeInnerDark",
		Vector3.new(25, 7.4, 25),
		pipeCFrame * CFrame.Angles(0, 0, math.rad(90)),
		COLORS.Dark,
		Enum.Material.SmoothPlastic
	)
	local trigger = makePart(
		pipe,
		"OrangeSectorPipeTrigger",
		Vector3.new(26, 24, 12),
		pipeCFrame,
		COLORS.Cyan,
		Enum.Material.ForceField,
		0.86
	)
	trigger.CanCollide = false
	trigger.CanTouch = true
	trigger:SetAttribute("SectorInteriorEntrance", true)
	trigger:SetAttribute("SectorInteriorDestination", "OrangeSectorInterior")
	trigger:SetAttribute("SectorColor", colorType)
	trigger:SetAttribute("ColorType", colorType)
	makePrompt(trigger, "EnterSectorPrompt", "Orange Sector Pipe", "Enter", 16)

	local pipeExitSpawn = makePart(
		Workspace,
		"PipeExitSpawn",
		Vector3.new(8, 1, 8),
		pipeCFrame * CFrame.new(0, 12, -56),
		COLORS.Cyan,
		Enum.Material.Neon,
		1
	)
	pipeExitSpawn.Anchored = true
	pipeExitSpawn.CanCollide = false
	pipeExitSpawn.CanTouch = false
	pipeExitSpawn.CanQuery = true
	pipeExitSpawn:SetAttribute("PipeExitSpawn", true)

	local returnAnchor = makePart(
		pipe,
		"OrangeSectorExteriorReturn",
		Vector3.new(14, 1, 14),
		pipeCFrame * CFrame.new(0, -10, -22),
		COLORS.Cyan,
		Enum.Material.Neon,
		0.35
	)
	returnAnchor.CanCollide = false
	returnAnchor:SetAttribute("SectorInteriorExteriorReturn", true)
	returnAnchor:SetAttribute("SectorColor", colorType)
	returnAnchor:SetAttribute("ColorType", colorType)

	print(
		"StudioSectorInteriorBuilder: built editable Orange Sector interior, pipe, MutationUnlockStation, ZorkPad, and baked Zork."
	)
	return interior
end

Builder.BuildSectorInteriors = Builder.BuildOrangeMutationInterior
Builder.BuildOrangeSectorInterior = Builder.BuildOrangeMutationInterior

return Builder
