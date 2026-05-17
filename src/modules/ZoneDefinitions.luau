local ZoneDefinitions = {}

local TEMPLATE_SIZE = Vector3.new(280, 8, 280)
local FLOOR_SIZE = Vector3.new(307, 1, 314)

local function makeSector(config)
	local colorType = config.ColorType
	return {
		ZoneId = config.ZoneId,
		WorldZoneId = config.WorldZoneId,
		LocationId = config.LocationId,
		DisplayName = config.DisplayName,
		FolderName = config.FolderName or config.ZoneId,
		ColorType = colorType,
		AccentColor = config.AccentColor,
		BaseFloorColor = config.BaseFloorColor or Color3.fromRGB(10, 10, 12),
		MaxActiveBreakables = config.MaxActiveBreakables or 80,
		HealthMultiplier = config.HealthMultiplier or 1,
		RewardMultiplier = config.RewardMultiplier or 1,
		SpawnAreaName = "BreakableSpawnArea",
		BreakablesFolderName = "Breakables",
		SpawnAreaCFrame = config.CFrame,
		SpawnAreaSize = config.SpawnAreaSize or TEMPLATE_SIZE,
		FloorSize = config.FloorSize or FLOOR_SIZE,
		SpawnAreaColor = config.AccentColor,
		SpawnPartName = config.SpawnPartName,
	}
end

ZoneDefinitions.Zones = {
	RedSector = makeSector({
		ZoneId = "RedSector",
		WorldZoneId = "StarterField",
		LocationId = "RedWastelands",
		DisplayName = "Red Sector",
		FolderName = "RedSector",
		ColorType = "Red",
		AccentColor = Color3.fromRGB(255, 45, 50),
		CFrame = CFrame.new(-400, 628, 60),
		MaxActiveBreakables = 35,
		SpawnPartName = "RedWastelandsSpawn",
	}),
	OrangeSector = makeSector({
		ZoneId = "OrangeSector",
		WorldZoneId = "OrangeGrove",
		LocationId = "OrangeSector",
		DisplayName = "Orange Sector",
		FolderName = "OrangeSector",
		ColorType = "Orange",
		AccentColor = Color3.fromRGB(255, 132, 28),
		CFrame = CFrame.new(0, 628, 60),
		MaxActiveBreakables = 85,
		HealthMultiplier = 2.5,
		RewardMultiplier = 2.5,
		SpawnPartName = "OrangeSectorSpawn",
	}),
	GreenSector = makeSector({
		ZoneId = "GreenSector",
		WorldZoneId = "GreenForest",
		LocationId = "GreenSector",
		DisplayName = "Green Sector",
		FolderName = "GreenSector",
		ColorType = "Green",
		AccentColor = Color3.fromRGB(70, 220, 90),
		CFrame = CFrame.new(400, 628, 60),
		MaxActiveBreakables = 85,
		HealthMultiplier = 5,
		RewardMultiplier = 8,
		SpawnPartName = "GreenSectorSpawn",
	}),
}

ZoneDefinitions.Order = {
	"RedSector",
	"OrangeSector",
	"GreenSector",
}

function ZoneDefinitions.Get(zoneId)
	return ZoneDefinitions.Zones[tostring(zoneId or "")] or ZoneDefinitions.Zones.RedSector
end

return ZoneDefinitions
