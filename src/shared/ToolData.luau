-- Paint tools collect world Color. Add future brush/roller skins here.
-- Balance rule: every brush in ToolData.Order should feel clearly better than the one before it,
-- but prices scale hard enough that players still need to play before upgrading.
local ToolData = {}

local STARTER_BRUSH_ID = "StarterBrush"
local warnedInvalidBrushIds = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function makeTool(data)
	data.Range = data.Range or 9
	data.Width = data.Width or 7
	data.Cooldown = data.Cooldown or 0.45
	data.GemDamage = data.GemDamage or data.CollectPowerMultiplier or data.PowerMultiplier or 1
	data.PowerMultiplier = data.PowerMultiplier or data.CollectPowerMultiplier or 1
	data.CollectPowerMultiplier = data.CollectPowerMultiplier or data.PowerMultiplier or 1
	data.SweepWidthMultiplier = data.SweepWidthMultiplier or 1
	data.UseSpeedMultiplier = data.UseSpeedMultiplier or 1
	data.PickupRadiusMultiplier = data.PickupRadiusMultiplier or 1
	data.PassiveId = data.PassiveId or "None"
	data.PassiveDescription = data.PassiveDescription or data.Description or ""
	data.PassiveEnabled = data.PassiveEnabled == true
	data.VisualType = data.VisualType or "Brush"
	data.MaxTargets = data.MaxTargets or 8
	data.MaxServerRange = data.MaxServerRange or 24
	return data
end

ToolData.Tools = {
	-- Starter / Red Sector. These are intentionally small upgrades so the first area is not finished instantly.
	StarterBrush = makeTool({
		Id = "StarterBrush", DisplayName = "Starter Brush", ShortName = "BR", Rarity = "Common",
		Description = "Basic starter brush.", Cost = 0, World = "Start Sector", SortOrder = 1, RequiredColor = "Red",
		PowerMultiplier = 1.00, CollectPowerMultiplier = 1.00, SweepWidthMultiplier = 1.00, UseSpeedMultiplier = 1.00, PickupRadiusMultiplier = 1.00,
		PassiveDescription = "Basic starter brush.", VisualType = "Brush",
		HandleColor = rgb(255, 213, 125), HeadColor = rgb(110, 235, 245), PaintColor = rgb(255, 92, 164),
		MaxTargets = 8, MaxServerRange = 24,
	}),
	SoftBrush = makeTool({
		Id = "SoftBrush", DisplayName = "Soft Brush", ShortName = "SB", Rarity = "Common",
		Description = "A cleaner brush with slightly better pickup.", Cost = 300, World = "Start Sector", SortOrder = 2, RequiredColor = "Red",
		PowerMultiplier = 1.08, CollectPowerMultiplier = 1.08, SweepWidthMultiplier = 1.06, UseSpeedMultiplier = 1.04, PickupRadiusMultiplier = 1.08,
		PassiveId = "SoftTouch", PassiveDescription = "Slightly easier Color pickup.", PassiveEnabled = true, VisualType = "Brush",
		HandleColor = rgb(255, 206, 145), HeadColor = rgb(255, 160, 190), PaintColor = rgb(255, 104, 150),
		MaxTargets = 9, MaxServerRange = 25,
	}),
	WideRoller = makeTool({
		Id = "WideRoller", DisplayName = "Wide Roller", ShortName = "WR", Rarity = "Uncommon",
		Description = "Wider than Soft Brush with better collection power.", Cost = 850, World = "Start Sector", SortOrder = 3, RequiredColor = "Red",
		PowerMultiplier = 1.18, CollectPowerMultiplier = 1.18, SweepWidthMultiplier = 1.18, UseSpeedMultiplier = 1.08, PickupRadiusMultiplier = 1.12,
		PassiveId = "WideSweep", PassiveDescription = "Wider collection area.", PassiveEnabled = true, VisualType = "Roller",
		HandleColor = rgb(255, 210, 126), HeadColor = rgb(116, 245, 170), PaintColor = rgb(118, 238, 244),
		MaxTargets = 10, MaxServerRange = 26,
	}),
	SplashBrush = makeTool({
		Id = "SplashBrush", DisplayName = "Splash Brush", ShortName = "SP", Rarity = "Uncommon",
		Description = "The strongest Red Sector brush before Orange.", Cost = 2200, World = "Start Sector", SortOrder = 4, RequiredColor = "Red",
		PowerMultiplier = 1.32, CollectPowerMultiplier = 1.32, SweepWidthMultiplier = 1.26, UseSpeedMultiplier = 1.12, PickupRadiusMultiplier = 1.16,
		PassiveId = "SplashPop", PassiveDescription = "Future small splash burst effect.", PassiveEnabled = false, VisualType = "Brush",
		HandleColor = rgb(255, 235, 145), HeadColor = rgb(255, 130, 188), PaintColor = rgb(255, 78, 126),
		MaxTargets = 11, MaxServerRange = 27,
	}),

	-- Orange Sector.
	OrangeBrush = makeTool({
		Id = "OrangeBrush", DisplayName = "Orange Brush", ShortName = "OB", Rarity = "Rare",
		Description = "A stronger brush tuned for Orange Sector.", Cost = 6500, World = "Orange Sector", SortOrder = 5, RequiredColor = "Orange",
		PowerMultiplier = 1.52, CollectPowerMultiplier = 1.52, SweepWidthMultiplier = 1.34, UseSpeedMultiplier = 1.16, PickupRadiusMultiplier = 1.20,
		PassiveId = "CitrusPull", PassiveDescription = "Future light Orange Sector pickup effect.", PassiveEnabled = false, VisualType = "Brush",
		HandleColor = rgb(255, 160, 70), HeadColor = rgb(255, 216, 112), PaintColor = rgb(255, 130, 45),
		MaxTargets = 12, MaxServerRange = 29,
	}),
	GroveRoller = makeTool({
		Id = "GroveRoller", DisplayName = "Grove Roller", ShortName = "GR", Rarity = "Rare",
		Description = "Wider and stronger than Orange Brush.", Cost = 16000, World = "Orange Sector", SortOrder = 6, RequiredColor = "Orange",
		PowerMultiplier = 1.78, CollectPowerMultiplier = 1.78, SweepWidthMultiplier = 1.48, UseSpeedMultiplier = 1.20, PickupRadiusMultiplier = 1.24,
		PassiveId = "GroveSweep", PassiveDescription = "Future short grove sweep trail.", PassiveEnabled = false, VisualType = "Roller",
		HandleColor = rgb(245, 140, 60), HeadColor = rgb(255, 180, 70), PaintColor = rgb(255, 116, 35),
		MaxTargets = 14, MaxServerRange = 30,
	}),

	-- Blue Sector.
	BlueBrush = makeTool({
		Id = "BlueBrush", DisplayName = "Blue Brush", ShortName = "BB", Rarity = "Rare",
		Description = "Future light magnet effect.", Cost = 42000, World = "Blue Sector", SortOrder = 7, RequiredColor = "Blue",
		PowerMultiplier = 2.05, CollectPowerMultiplier = 2.05, SweepWidthMultiplier = 1.56, UseSpeedMultiplier = 1.24, PickupRadiusMultiplier = 1.28,
		PassiveId = "WaterPull", PassiveDescription = "Future light magnet effect.", PassiveEnabled = false, VisualType = "Brush",
		HandleColor = rgb(80, 130, 230), HeadColor = rgb(120, 210, 255), PaintColor = rgb(70, 145, 255),
		MaxTargets = 15, MaxServerRange = 31,
	}),
	TideRoller = makeTool({
		Id = "TideRoller", DisplayName = "Tide Roller", ShortName = "TR", Rarity = "Rare",
		Description = "A stronger wide roller for Blue Sector.", Cost = 95000, World = "Blue Sector", SortOrder = 8, RequiredColor = "Blue",
		PowerMultiplier = 2.42, CollectPowerMultiplier = 2.42, SweepWidthMultiplier = 1.70, UseSpeedMultiplier = 1.28, PickupRadiusMultiplier = 1.32,
		PassiveId = "TideTrail", PassiveDescription = "Future short collection trail.", PassiveEnabled = false, VisualType = "Roller",
		HandleColor = rgb(72, 145, 255), HeadColor = rgb(118, 238, 244), PaintColor = rgb(56, 110, 230),
		MaxTargets = 16, MaxServerRange = 32,
	}),

	-- Yellow Sector.
	SunBrush = makeTool({
		Id = "SunBrush", DisplayName = "Sun Brush", ShortName = "SU", Rarity = "Rare",
		Description = "Future chance to double pickup.", Cost = 240000, World = "Yellow Sector", SortOrder = 9, RequiredColor = "Yellow",
		PowerMultiplier = 2.86, CollectPowerMultiplier = 2.86, SweepWidthMultiplier = 1.78, UseSpeedMultiplier = 1.32, PickupRadiusMultiplier = 1.36,
		PassiveId = "SunlitColor", PassiveDescription = "Future chance to double pickup.", PassiveEnabled = false, VisualType = "Brush",
		HandleColor = rgb(255, 198, 92), HeadColor = rgb(255, 235, 105), PaintColor = rgb(255, 178, 70),
		MaxTargets = 17, MaxServerRange = 33,
	}),
	DesertRoller = makeTool({
		Id = "DesertRoller", DisplayName = "Desert Roller", ShortName = "DR", Rarity = "Epic",
		Description = "Future speed build-up while collecting.", Cost = 550000, World = "Yellow Sector", SortOrder = 10, RequiredColor = "Yellow",
		PowerMultiplier = 3.38, CollectPowerMultiplier = 3.38, SweepWidthMultiplier = 1.92, UseSpeedMultiplier = 1.36, PickupRadiusMultiplier = 1.40,
		PassiveId = "HeatMomentum", PassiveDescription = "Future speed build-up while collecting.", PassiveEnabled = false, VisualType = "Roller",
		HandleColor = rgb(255, 220, 110), HeadColor = rgb(255, 178, 70), PaintColor = rgb(255, 238, 120),
		MaxTargets = 18, MaxServerRange = 34,
	}),

	-- Green Sector.
	LeafBrush = makeTool({
		Id = "LeafBrush", DisplayName = "Leaf Brush", ShortName = "LB", Rarity = "Epic",
		Description = "Future small movement bonus.", Cost = 1300000, World = "Green Sector", SortOrder = 11, RequiredColor = "Green",
		PowerMultiplier = 4.00, CollectPowerMultiplier = 4.00, SweepWidthMultiplier = 2.00, UseSpeedMultiplier = 1.40, PickupRadiusMultiplier = 1.44,
		PassiveId = "NaturesBoost", PassiveDescription = "Future small movement bonus.", PassiveEnabled = false, VisualType = "Brush",
		HandleColor = rgb(120, 190, 90), HeadColor = rgb(116, 232, 158), PaintColor = rgb(56, 210, 105),
		MaxTargets = 19, MaxServerRange = 35,
	}),
	VineRoller = makeTool({
		Id = "VineRoller", DisplayName = "Vine Roller", ShortName = "VR", Rarity = "Epic",
		Description = "Future side collection bonus.", Cost = 3100000, World = "Green Sector", SortOrder = 12, RequiredColor = "Green",
		PowerMultiplier = 4.72, CollectPowerMultiplier = 4.72, SweepWidthMultiplier = 2.14, UseSpeedMultiplier = 1.44, PickupRadiusMultiplier = 1.48,
		PassiveId = "VineReach", PassiveDescription = "Future side collection bonus.", PassiveEnabled = false, VisualType = "Roller",
		HandleColor = rgb(85, 160, 90), HeadColor = rgb(125, 230, 105), PaintColor = rgb(52, 175, 95),
		MaxTargets = 21, MaxServerRange = 37,
	}),

	-- Purple Sector.
	CrystalBrush = makeTool({
		Id = "CrystalBrush", DisplayName = "Crystal Brush", ShortName = "CB", Rarity = "Epic",
		Description = "Future critical pickup chance.", Cost = 7500000, World = "Purple Sector", SortOrder = 13, RequiredColor = "Purple",
		PowerMultiplier = 5.58, CollectPowerMultiplier = 5.58, SweepWidthMultiplier = 2.22, UseSpeedMultiplier = 1.48, PickupRadiusMultiplier = 1.52,
		PassiveId = "CrystalCrit", PassiveDescription = "Future critical pickup chance.", PassiveEnabled = false, VisualType = "Brush",
		HandleColor = rgb(110, 75, 170), HeadColor = rgb(202, 176, 255), PaintColor = rgb(178, 95, 255),
		MaxTargets = 23, MaxServerRange = 39,
	}),
	AmethystRoller = makeTool({
		Id = "AmethystRoller", DisplayName = "Amethyst Roller", ShortName = "AR", Rarity = "Legendary",
		Description = "Future mutation luck bonus.", Cost = 17500000, World = "Purple Sector", SortOrder = 14, RequiredColor = "Purple",
		PowerMultiplier = 6.60, CollectPowerMultiplier = 6.60, SweepWidthMultiplier = 2.36, UseSpeedMultiplier = 1.52, PickupRadiusMultiplier = 1.56,
		PassiveId = "AmethystPulse", PassiveDescription = "Future mutation luck bonus.", PassiveEnabled = false, VisualType = "Roller",
		HandleColor = rgb(140, 80, 210), HeadColor = rgb(185, 120, 255), PaintColor = rgb(215, 190, 255),
		MaxTargets = 25, MaxServerRange = 41,
	}),

	-- Neon Sector.
	NeonBrush = makeTool({
		Id = "NeonBrush", DisplayName = "Neon Brush", ShortName = "NB", Rarity = "Legendary",
		Description = "Future speed burst effect.", Cost = 42000000, World = "Neon Sector", SortOrder = 15, RequiredColor = "Neon",
		PowerMultiplier = 7.80, CollectPowerMultiplier = 7.80, SweepWidthMultiplier = 2.44, UseSpeedMultiplier = 1.56, PickupRadiusMultiplier = 1.60,
		PassiveId = "NeonCharge", PassiveDescription = "Future speed burst effect.", PassiveEnabled = false, VisualType = "Brush",
		HandleColor = rgb(48, 52, 64), HeadColor = rgb(155, 218, 255), PaintColor = rgb(0, 255, 200),
		MaxTargets = 27, MaxServerRange = 43,
	}),
	LaserRoller = makeTool({
		Id = "LaserRoller", DisplayName = "Laser Roller", ShortName = "LR", Rarity = "Legendary",
		Description = "Future forward beam collection.", Cost = 100000000, World = "Neon Sector", SortOrder = 16, RequiredColor = "Neon",
		PowerMultiplier = 9.25, CollectPowerMultiplier = 9.25, SweepWidthMultiplier = 2.58, UseSpeedMultiplier = 1.60, PickupRadiusMultiplier = 1.64,
		PassiveId = "LaserLine", PassiveDescription = "Future forward beam collection.", PassiveEnabled = false, VisualType = "Roller",
		HandleColor = rgb(35, 40, 55), HeadColor = rgb(30, 255, 145), PaintColor = rgb(0, 180, 255),
		MaxTargets = 31, MaxServerRange = 46,
	}),

	-- Rainbow Sector.
	PrismBrush = makeTool({
		Id = "PrismBrush", DisplayName = "Prism Brush", ShortName = "PB", Rarity = "Legendary",
		Description = "Future bonus pickup split effect.", Cost = 240000000, World = "Rainbow Sector", SortOrder = 17, RequiredColor = "Rainbow",
		PowerMultiplier = 10.95, CollectPowerMultiplier = 10.95, SweepWidthMultiplier = 2.72, UseSpeedMultiplier = 1.64, PickupRadiusMultiplier = 1.68,
		PassiveId = "PrismSplit", PassiveDescription = "Future bonus pickup split effect.", PassiveEnabled = false, VisualType = "Brush",
		HandleColor = rgb(255, 235, 145), HeadColor = rgb(202, 176, 255), PaintColor = rgb(255, 130, 188),
		MaxTargets = 35, MaxServerRange = 49,
	}),
	PrismRoller = makeTool({
		Id = "PrismRoller", DisplayName = "Prism Roller", ShortName = "PR", Rarity = "Legendary",
		Description = "Endgame rainbow roller with the best collection stats.", Cost = 600000000, World = "Rainbow Sector", SortOrder = 18, RequiredColor = "Rainbow",
		PowerMultiplier = 13.00, CollectPowerMultiplier = 13.00, SweepWidthMultiplier = 2.90, UseSpeedMultiplier = 1.70, PickupRadiusMultiplier = 1.75,
		PassiveId = "RainbowSurge", PassiveDescription = "Future endgame rainbow pulse.", PassiveEnabled = false, VisualType = "Roller",
		HandleColor = rgb(255, 235, 145), HeadColor = rgb(255, 255, 255), PaintColor = rgb(255, 150, 230),
		MaxTargets = 40, MaxServerRange = 52,
	}),
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
	Common = rgb(185, 190, 205),
	Uncommon = rgb(116, 232, 158),
	Rare = rgb(118, 184, 255),
	Epic = rgb(202, 176, 255),
	Legendary = rgb(255, 218, 110),
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
