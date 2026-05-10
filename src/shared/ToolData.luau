-- Paint tools collect world Color. Add future brush/roller skins here.
local ToolData = {}

local STARTER_BRUSH_ID = "StarterBrush"
local warnedInvalidBrushIds = {}

-- TODO: Keep PassiveId/PassiveEnabled as data-only placeholders until each effect
-- has a small server-authoritative implementation pass.
ToolData.Tools = {
	-- Starter Field tools
	StarterBrush = {
		Id = "StarterBrush",
		DisplayName = "Starter Brush",
		ShortName = "BR",
		Rarity = "Common",
		Description = "Basic starter brush.",
		Cost = 0,
		World = "Start Sector",
		SortOrder = 1,
		RequiredColor = "Red",
		Range = 9,
		Width = 7,
		Cooldown = 0.45,
		PowerMultiplier = 1.00,
		GemDamage = 1.00,
		CollectPowerMultiplier = 1.00,
		SweepWidthMultiplier = 1.00,
		UseSpeedMultiplier = 1.00,
		PickupRadiusMultiplier = 1.00,
		PassiveId = "None",
		PassiveDescription = "Basic starter brush.",
		PassiveEnabled = false,
		VisualType = "Brush",
		HandleColor = Color3.fromRGB(255, 213, 125),
		HeadColor = Color3.fromRGB(110, 235, 245),
		PaintColor = Color3.fromRGB(255, 92, 164),
		MaxTargets = 8,
		MaxServerRange = 24,
	},
	SoftBrush = {
		Id = "SoftBrush",
		DisplayName = "Soft Brush",
		ShortName = "SB",
		Rarity = "Common",
		Description = "Slightly easier Color pickup.",
		Cost = 150,
		World = "Start Sector",
		SortOrder = 2,
		RequiredColor = "Red",
		Range = 9,
		Width = 7,
		Cooldown = 0.45,
		PowerMultiplier = 1.10,
		CollectPowerMultiplier = 1.10,
		SweepWidthMultiplier = 1.00,
		UseSpeedMultiplier = 1.05,
		PickupRadiusMultiplier = 1.15,
		PassiveId = "SoftTouch",
		PassiveDescription = "Slightly easier Color pickup.",
		PassiveEnabled = true,
		VisualType = "Brush",
		HandleColor = Color3.fromRGB(255, 206, 145),
		HeadColor = Color3.fromRGB(255, 160, 190),
		PaintColor = Color3.fromRGB(255, 104, 150),
		MaxTargets = 9,
		MaxServerRange = 25,
	},
	WideRoller = {
		Id = "WideRoller",
		DisplayName = "Wide Roller",
		ShortName = "WR",
		Rarity = "Uncommon",
		Description = "Wider collection area.",
		Cost = 350,
		World = "Start Sector",
		SortOrder = 3,
		RequiredColor = "Red",
		Range = 9,
		Width = 7,
		Cooldown = 0.45,
		PowerMultiplier = 1.25,
		CollectPowerMultiplier = 1.25,
		SweepWidthMultiplier = 1.40,
		UseSpeedMultiplier = 1.05,
		PickupRadiusMultiplier = 1.15,
		PassiveId = "WideSweep",
		PassiveDescription = "Wider collection area.",
		PassiveEnabled = true,
		VisualType = "Roller",
		HandleColor = Color3.fromRGB(255, 210, 126),
		HeadColor = Color3.fromRGB(116, 245, 170),
		PaintColor = Color3.fromRGB(118, 238, 244),
		MaxTargets = 10,
		MaxServerRange = 26,
	},
	SplashBrush = {
		Id = "SplashBrush",
		DisplayName = "Splash Brush",
		ShortName = "SP",
		Rarity = "Uncommon",
		Description = "A punchier brush with extra reach and power.",
		Cost = 900,
		World = "Start Sector",
		SortOrder = 4,
		RequiredColor = "Red",
		Range = 9,
		Width = 7,
		Cooldown = 0.45,
		PowerMultiplier = 1.40,
		CollectPowerMultiplier = 1.40,
		SweepWidthMultiplier = 1.15,
		UseSpeedMultiplier = 1.12,
		PickupRadiusMultiplier = 1.18,
		PassiveId = "SplashPop",
		PassiveDescription = "Future small splash burst effect.",
		PassiveEnabled = false,
		VisualType = "Brush",
		HandleColor = Color3.fromRGB(255, 235, 145),
		HeadColor = Color3.fromRGB(255, 130, 188),
		PaintColor = Color3.fromRGB(255, 78, 126),
		MaxTargets = 11,
		MaxServerRange = 27,
	},

	-- Orange Sector tools
	OrangeBrush = {
		Id = "OrangeBrush",
		DisplayName = "Orange Brush",
		ShortName = "OB",
		Rarity = "Rare",
		Description = "A bright brush tuned for Orange Sector.",
		Cost = 1800,
		World = "Orange Sector",
		SortOrder = 5,
		RequiredColor = "Orange",
		Range = 9,
		Width = 7,
		Cooldown = 0.45,
		PowerMultiplier = 1.55,
		CollectPowerMultiplier = 1.55,
		SweepWidthMultiplier = 1.15,
		UseSpeedMultiplier = 1.16,
		PickupRadiusMultiplier = 1.22,
		PassiveId = "CitrusPull",
		PassiveDescription = "Future light Orange Sector pickup effect.",
		PassiveEnabled = false,
		VisualType = "Brush",
		HandleColor = Color3.fromRGB(255, 160, 70),
		HeadColor = Color3.fromRGB(255, 216, 112),
		PaintColor = Color3.fromRGB(255, 130, 45),
		MaxTargets = 12,
		MaxServerRange = 29,
	},
	GroveRoller = {
		Id = "GroveRoller",
		DisplayName = "Grove Roller",
		ShortName = "GR",
		Rarity = "Rare",
		Description = "A wider roller for Orange Sector.",
		Cost = 4200,
		World = "Orange Sector",
		SortOrder = 6,
		RequiredColor = "Orange",
		Range = 9,
		Width = 7,
		Cooldown = 0.45,
		PowerMultiplier = 1.85,
		CollectPowerMultiplier = 1.85,
		SweepWidthMultiplier = 1.55,
		UseSpeedMultiplier = 1.12,
		PickupRadiusMultiplier = 1.26,
		PassiveId = "GroveSweep",
		PassiveDescription = "Future short grove sweep trail.",
		PassiveEnabled = false,
		VisualType = "Roller",
		HandleColor = Color3.fromRGB(245, 140, 60),
		HeadColor = Color3.fromRGB(255, 180, 70),
		PaintColor = Color3.fromRGB(255, 116, 35),
		MaxTargets = 14,
		MaxServerRange = 30,
	},

	-- Blue Sector tools
	BlueBrush = {
		Id = "BlueBrush",
		DisplayName = "Blue Brush",
		ShortName = "BB",
		Rarity = "Rare",
		Description = "Future light magnet effect.",
		Cost = 2800,
		World = "Blue Sector",
		SortOrder = 5,
		RequiredColor = "Blue",
		Range = 9,
		Width = 7,
		Cooldown = 0.45,
		PowerMultiplier = 1.70,
		CollectPowerMultiplier = 1.70,
		SweepWidthMultiplier = 1.20,
		UseSpeedMultiplier = 1.20,
		PickupRadiusMultiplier = 1.25,
		PassiveId = "WaterPull",
		PassiveDescription = "Future light magnet effect.",
		PassiveEnabled = false,
		VisualType = "Brush",
		HandleColor = Color3.fromRGB(80, 130, 230),
		HeadColor = Color3.fromRGB(120, 210, 255),
		PaintColor = Color3.fromRGB(70, 145, 255),
		MaxTargets = 12,
		MaxServerRange = 29,
	},
	TideRoller = {
		Id = "TideRoller",
		DisplayName = "Tide Roller",
		ShortName = "TR",
		Rarity = "Rare",
		Description = "Future short collection trail.",
		Cost = 6200,
		World = "Blue Sector",
		SortOrder = 6,
		RequiredColor = "Blue",
		Range = 9,
		Width = 7,
		Cooldown = 0.45,
		PowerMultiplier = 2.00,
		CollectPowerMultiplier = 2.00,
		SweepWidthMultiplier = 1.60,
		UseSpeedMultiplier = 1.15,
		PickupRadiusMultiplier = 1.28,
		PassiveId = "TideTrail",
		PassiveDescription = "Future short collection trail.",
		PassiveEnabled = false,
		VisualType = "Roller",
		HandleColor = Color3.fromRGB(72, 145, 255),
		HeadColor = Color3.fromRGB(118, 238, 244),
		PaintColor = Color3.fromRGB(56, 110, 230),
		MaxTargets = 14,
		MaxServerRange = 30,
	},

	-- Yellow Sector tools
	SunBrush = {
		Id = "SunBrush",
		DisplayName = "Sun Brush",
		ShortName = "SU",
		Rarity = "Rare",
		Description = "Future chance to double pickup.",
		Cost = 18000,
		World = "Yellow Sector",
		SortOrder = 7,
		RequiredColor = "Yellow",
		Range = 9,
		Width = 7,
		Cooldown = 0.45,
		PowerMultiplier = 2.40,
		CollectPowerMultiplier = 2.40,
		SweepWidthMultiplier = 1.25,
		UseSpeedMultiplier = 1.30,
		PickupRadiusMultiplier = 1.30,
		PassiveId = "SunlitColor",
		PassiveDescription = "Future chance to double pickup.",
		PassiveEnabled = false,
		VisualType = "Brush",
		HandleColor = Color3.fromRGB(255, 198, 92),
		HeadColor = Color3.fromRGB(255, 235, 105),
		PaintColor = Color3.fromRGB(255, 178, 70),
		MaxTargets = 15,
		MaxServerRange = 31,
	},
	DesertRoller = {
		Id = "DesertRoller",
		DisplayName = "Desert Roller",
		ShortName = "DR",
		Rarity = "Epic",
		Description = "Future speed build-up while collecting.",
		Cost = 42000,
		World = "Yellow Sector",
		SortOrder = 8,
		RequiredColor = "Yellow",
		Range = 9,
		Width = 7,
		Cooldown = 0.45,
		PowerMultiplier = 2.90,
		CollectPowerMultiplier = 2.90,
		SweepWidthMultiplier = 1.80,
		UseSpeedMultiplier = 1.22,
		PickupRadiusMultiplier = 1.32,
		PassiveId = "HeatMomentum",
		PassiveDescription = "Future speed build-up while collecting.",
		PassiveEnabled = false,
		VisualType = "Roller",
		HandleColor = Color3.fromRGB(255, 220, 110),
		HeadColor = Color3.fromRGB(255, 178, 70),
		PaintColor = Color3.fromRGB(255, 238, 120),
		MaxTargets = 17,
		MaxServerRange = 33,
	},

	-- Green Sector tools
	LeafBrush = {
		Id = "LeafBrush",
		DisplayName = "Leaf Brush",
		ShortName = "LB",
		Rarity = "Epic",
		Description = "Future small movement bonus.",
		Cost = 110000,
		World = "Green Sector",
		SortOrder = 9,
		RequiredColor = "Green",
		Range = 9,
		Width = 7,
		Cooldown = 0.45,
		PowerMultiplier = 3.50,
		CollectPowerMultiplier = 3.50,
		SweepWidthMultiplier = 1.32,
		UseSpeedMultiplier = 1.38,
		PickupRadiusMultiplier = 1.35,
		PassiveId = "NaturesBoost",
		PassiveDescription = "Future small movement bonus.",
		PassiveEnabled = false,
		VisualType = "Brush",
		HandleColor = Color3.fromRGB(120, 190, 90),
		HeadColor = Color3.fromRGB(116, 232, 158),
		PaintColor = Color3.fromRGB(56, 210, 105),
		MaxTargets = 18,
		MaxServerRange = 34,
	},
	VineRoller = {
		Id = "VineRoller",
		DisplayName = "Vine Roller",
		ShortName = "VR",
		Rarity = "Epic",
		Description = "Future side collection bonus.",
		Cost = 260000,
		World = "Green Sector",
		SortOrder = 10,
		RequiredColor = "Green",
		Range = 9,
		Width = 7,
		Cooldown = 0.45,
		PowerMultiplier = 4.20,
		CollectPowerMultiplier = 4.20,
		SweepWidthMultiplier = 2.00,
		UseSpeedMultiplier = 1.28,
		PickupRadiusMultiplier = 1.40,
		PassiveId = "VineReach",
		PassiveDescription = "Future side collection bonus.",
		PassiveEnabled = false,
		VisualType = "Roller",
		HandleColor = Color3.fromRGB(85, 160, 90),
		HeadColor = Color3.fromRGB(125, 230, 105),
		PaintColor = Color3.fromRGB(52, 175, 95),
		MaxTargets = 20,
		MaxServerRange = 36,
	},

	-- Purple Sector tools
	CrystalBrush = {
		Id = "CrystalBrush",
		DisplayName = "Crystal Brush",
		ShortName = "CB",
		Rarity = "Epic",
		Description = "Future critical pickup chance.",
		Cost = 620000,
		World = "Purple Sector",
		SortOrder = 11,
		RequiredColor = "Purple",
		Range = 9,
		Width = 7,
		Cooldown = 0.45,
		PowerMultiplier = 5.00,
		CollectPowerMultiplier = 5.00,
		SweepWidthMultiplier = 1.40,
		UseSpeedMultiplier = 1.45,
		PickupRadiusMultiplier = 1.45,
		PassiveId = "CrystalCrit",
		PassiveDescription = "Future critical pickup chance.",
		PassiveEnabled = false,
		VisualType = "Brush",
		HandleColor = Color3.fromRGB(110, 75, 170),
		HeadColor = Color3.fromRGB(202, 176, 255),
		PaintColor = Color3.fromRGB(178, 95, 255),
		MaxTargets = 22,
		MaxServerRange = 38,
	},
	AmethystRoller = {
		Id = "AmethystRoller",
		DisplayName = "Amethyst Roller",
		ShortName = "AR",
		Rarity = "Legendary",
		Description = "Future mutation luck bonus.",
		Cost = 1400000,
		World = "Purple Sector",
		SortOrder = 12,
		RequiredColor = "Purple",
		Range = 9,
		Width = 7,
		Cooldown = 0.45,
		PowerMultiplier = 6.00,
		CollectPowerMultiplier = 6.00,
		SweepWidthMultiplier = 2.15,
		UseSpeedMultiplier = 1.34,
		PickupRadiusMultiplier = 1.50,
		PassiveId = "AmethystPulse",
		PassiveDescription = "Future mutation luck bonus.",
		PassiveEnabled = false,
		VisualType = "Roller",
		HandleColor = Color3.fromRGB(140, 80, 210),
		HeadColor = Color3.fromRGB(185, 120, 255),
		PaintColor = Color3.fromRGB(215, 190, 255),
		MaxTargets = 24,
		MaxServerRange = 40,
	},

	-- Neon Sector tools
	NeonBrush = {
		Id = "NeonBrush",
		DisplayName = "Neon Brush",
		ShortName = "NB",
		Rarity = "Legendary",
		Description = "Future speed burst effect.",
		Cost = 3200000,
		World = "Neon Sector",
		SortOrder = 13,
		RequiredColor = "Neon",
		Range = 9,
		Width = 7,
		Cooldown = 0.45,
		PowerMultiplier = 7.20,
		CollectPowerMultiplier = 7.20,
		SweepWidthMultiplier = 1.50,
		UseSpeedMultiplier = 1.58,
		PickupRadiusMultiplier = 1.55,
		PassiveId = "NeonCharge",
		PassiveDescription = "Future speed burst effect.",
		PassiveEnabled = false,
		VisualType = "Brush",
		HandleColor = Color3.fromRGB(48, 52, 64),
		HeadColor = Color3.fromRGB(155, 218, 255),
		PaintColor = Color3.fromRGB(0, 255, 200),
		MaxTargets = 26,
		MaxServerRange = 42,
	},
	LaserRoller = {
		Id = "LaserRoller",
		DisplayName = "Laser Roller",
		ShortName = "LR",
		Rarity = "Legendary",
		Description = "Future forward beam collection.",
		Cost = 7200000,
		World = "Neon Sector",
		SortOrder = 14,
		RequiredColor = "Neon",
		Range = 9,
		Width = 7,
		Cooldown = 0.45,
		PowerMultiplier = 8.80,
		CollectPowerMultiplier = 8.80,
		SweepWidthMultiplier = 2.30,
		UseSpeedMultiplier = 1.42,
		PickupRadiusMultiplier = 1.60,
		PassiveId = "LaserLine",
		PassiveDescription = "Future forward beam collection.",
		PassiveEnabled = false,
		VisualType = "Roller",
		HandleColor = Color3.fromRGB(35, 40, 55),
		HeadColor = Color3.fromRGB(30, 255, 145),
		PaintColor = Color3.fromRGB(0, 180, 255),
		MaxTargets = 30,
		MaxServerRange = 45,
	},

	-- Rainbow Sector tools
	PrismBrush = {
		Id = "PrismBrush",
		DisplayName = "Prism Brush",
		ShortName = "PB",
		Rarity = "Legendary",
		Description = "Future bonus pickup split effect.",
		Cost = 15000000,
		World = "Rainbow Sector",
		SortOrder = 15,
		RequiredColor = "Rainbow",
		Range = 9,
		Width = 7,
		Cooldown = 0.45,
		PowerMultiplier = 10.50,
		CollectPowerMultiplier = 10.50,
		SweepWidthMultiplier = 1.65,
		UseSpeedMultiplier = 1.72,
		PickupRadiusMultiplier = 1.65,
		PassiveId = "PrismSplit",
		PassiveDescription = "Future bonus pickup split effect.",
		PassiveEnabled = false,
		VisualType = "Brush",
		HandleColor = Color3.fromRGB(255, 235, 145),
		HeadColor = Color3.fromRGB(202, 176, 255),
		PaintColor = Color3.fromRGB(255, 130, 188),
		MaxTargets = 34,
		MaxServerRange = 48,
	},
	PrismRoller = {
		Id = "PrismRoller",
		DisplayName = "Prism Roller",
		ShortName = "PR",
		Rarity = "Legendary",
		Description = "Future endgame rainbow pulse.",
		Cost = 30000000,
		World = "Rainbow Sector",
		SortOrder = 16,
		RequiredColor = "Rainbow",
		Range = 9,
		Width = 7,
		Cooldown = 0.45,
		PowerMultiplier = 13.00,
		CollectPowerMultiplier = 13.00,
		SweepWidthMultiplier = 2.60,
		UseSpeedMultiplier = 1.50,
		PickupRadiusMultiplier = 1.75,
		PassiveId = "RainbowSurge",
		PassiveDescription = "Future endgame rainbow pulse.",
		PassiveEnabled = false,
		VisualType = "Roller",
		HandleColor = Color3.fromRGB(255, 235, 145),
		HeadColor = Color3.fromRGB(255, 255, 255),
		PaintColor = Color3.fromRGB(255, 150, 230),
		MaxTargets = 40,
		MaxServerRange = 52,
	},
}

ToolData.Order = {
	"StarterBrush", "SoftBrush", "WideRoller", "SplashBrush",
	"OrangeBrush", "GroveRoller",
	"BlueBrush", "TideRoller",
	"SunBrush", "DesertRoller",
	"LeafBrush", "VineRoller",
	"CrystalBrush", "AmethystRoller",
	"NeonBrush", "LaserRoller",
	"PrismBrush", "PrismRoller",
}

ToolData.RarityColors = {
	Common = Color3.fromRGB(185, 190, 205),
	Uncommon = Color3.fromRGB(116, 232, 158),
	Rare = Color3.fromRGB(118, 184, 255),
	Epic = Color3.fromRGB(202, 176, 255),
	Legendary = Color3.fromRGB(255, 218, 110),
}

local function warnInvalidBrushIdOnce(brushId)
	local key = tostring(brushId)
	if warnedInvalidBrushIds[key] then
		return
	end
	warnedInvalidBrushIds[key] = true
	warn("ToolData: invalid brush id '" .. key .. "'; using Starter Brush.")
end

local function getMultiplier(tool, fieldName, fallback)
	local value = tonumber(tool and tool[fieldName])
	if value and value > 0 then
		return value
	end
	return fallback
end

function ToolData.GetBrush(brushId)
	local tool = ToolData.Tools[brushId or ""]
	if tool then
		return tool
	end

	if brushId ~= nil and brushId ~= "" then
		warnInvalidBrushIdOnce(brushId)
	end
	return ToolData.Tools[STARTER_BRUSH_ID]
end

function ToolData.GetStarterBrush()
	return ToolData.Tools[STARTER_BRUSH_ID]
end

function ToolData.GetOrderedBrushes()
	local tools = {}
	for _, toolId in ipairs(ToolData.Order) do
		local tool = ToolData.Tools[toolId]
		if tool then
			table.insert(tools, tool)
		end
	end
	return tools
end

function ToolData.GetBrushesForWorldColor(colorType)
	local worldBrushIds = nil
	local colorData = rawget(_G, "__ColorSimulatorColorData")
	if not colorData then
		local ok, module = pcall(function()
			return require(script.Parent:WaitForChild("ColorData"))
		end)
		if ok then
			colorData = module
		end
	end

	local world = colorData and colorData.getWorldByColor and colorData.getWorldByColor(colorType or "Red")
	worldBrushIds = world and world.BrushIds

	if type(worldBrushIds) == "table" then
		local brushes = {}
		for _, brushId in ipairs(worldBrushIds) do
			local tool = ToolData.Tools[brushId]
			if tool then
				table.insert(brushes, tool)
			end
		end
		return brushes
	end

	local brushes = {}
	for _, toolId in ipairs(ToolData.Order) do
		local tool = ToolData.Tools[toolId]
		if tool and (tool.RequiredColor or "Red") == (colorType or "Red") then
			table.insert(brushes, tool)
		end
	end
	return brushes
end

function ToolData.GetEffectiveStats(brushId)
	local tool = ToolData.GetBrush(brushId)
	local collectPower = getMultiplier(tool, "CollectPowerMultiplier", getMultiplier(tool, "PowerMultiplier", 1))
	local sweepWidth = getMultiplier(tool, "SweepWidthMultiplier", 1)
	local useSpeed = getMultiplier(tool, "UseSpeedMultiplier", 1)
	local pickupRadius = getMultiplier(tool, "PickupRadiusMultiplier", 1)
	local gemDamage = getMultiplier(tool, "GemDamage", math.max(1, collectPower))

	local passiveEnabled = tool.PassiveEnabled == true

	return {
		Id = tool.Id,
		CollectPowerMultiplier = collectPower,
		GemDamage = gemDamage,
		SweepWidthMultiplier = sweepWidth,
		UseSpeedMultiplier = useSpeed,
		PickupRadiusMultiplier = pickupRadius,
		PassiveId = passiveEnabled and (tool.PassiveId or "None") or "None",
		PassiveDescription = passiveEnabled and (tool.PassiveDescription or "") or "",
		PassiveEnabled = passiveEnabled,
	}
end

function ToolData.get(toolId)
	return ToolData.GetBrush(toolId)
end

function ToolData.isValid(toolId)
	return ToolData.Tools[toolId or ""] ~= nil
end

function ToolData.getOrderedTools()
	return ToolData.GetOrderedBrushes()
end

return ToolData
