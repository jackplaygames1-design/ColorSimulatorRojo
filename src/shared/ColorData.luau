-- ModuleScript in ReplicatedStorage named "ColorData"
local ColorData = {}

-- All color types in the game
ColorData.Colors = {
	Red    = { color = Color3.fromRGB(220, 50,  50),  order = 1 },
	Blue   = { color = Color3.fromRGB(50,  100, 220), order = 2 },
	Yellow = { color = Color3.fromRGB(240, 210, 40),  order = 3 },
	Green  = { color = Color3.fromRGB(60,  180, 80),  order = 4 },
	Purple = { color = Color3.fromRGB(140, 60,  200), order = 5 },
	Orange = { color = Color3.fromRGB(240, 130, 30),  order = 6 },
	Pink   = { color = Color3.fromRGB(255, 160, 180), order = 7 },
	Neon   = { color = Color3.fromRGB(0,   255, 200), order = 8 },
	Rainbow= { color = Color3.fromRGB(255, 255, 255), order = 9 },
	Void   = { color = Color3.fromRGB(20,  0,   40),  order = 10 },
}

-- Mixing recipes
ColorData.MixRecipes = {
	{ ingredientA = "Red",  ingredientB = "Blue",   result = "Purple",  amountNeeded = 500 },
	{ ingredientA = "Blue", ingredientB = "Yellow", result = "Green",   amountNeeded = 500 },
	{ ingredientA = "Red",  ingredientB = "Yellow", result = "Orange",  amountNeeded = 500 },
}

-- Sectors / zones. The internal field names stay compatible with older systems.
ColorData.Worlds = {
	{
		id = "Red",
		ZoneId = "StarterField",
		DisplayName = "Start Sector",
		WorldIndex = 1,
		name = "Start Sector",
		unlockCost = 0,
		UnlockCost = 0,
		RequiredZoneId = nil,
		primaryColor = "Red",
		ColorTheme = "Red",
		EggIds = { "ColorEgg" },
		BrushIds = { "StarterBrush", "SoftBrush", "WideRoller", "SplashBrush" },
		breakableHealth = 10,
		blobCount = 82,
		rewardMultiplier = 1,
		colorValueMultiplier = 1,
		SellValueMultiplier = 1,
	},
	{
		id = "Orange",
		ZoneId = "OrangeGrove",
		DisplayName = "Orange Sector",
		WorldIndex = 2,
		name = "Orange Sector",
		unlockCost = 15000,
		UnlockCost = 15000,
		RequiredZoneId = "StarterField",
		primaryColor = "Orange",
		ColorTheme = "Orange",
		EggIds = { "OrangeEgg" },
		BrushIds = { "OrangeBrush", "GroveRoller" },
		breakableHealth = 38,
		blobCount = 86,
		rewardMultiplier = 2,
		colorValueMultiplier = 2.5,
		SellValueMultiplier = 2.5,
	},
	{
		id = "Blue",
		ZoneId = "BlueBeach",
		DisplayName = "Blue Sector",
		WorldIndex = 3,
		name = "Blue Sector",
		unlockCost = 12000,
		UnlockCost = 12000,
		RequiredZoneId = "OrangeGrove",
		primaryColor = "Blue",
		ColorTheme = "Blue",
		EggIds = { "BlueEgg" },
		BrushIds = { "BlueBrush", "TideRoller" },
		breakableHealth = 55,
		blobCount = 88,
		rewardMultiplier = 3,
		colorValueMultiplier = 5,
		SellValueMultiplier = 5,
	},
	{
		id = "Yellow",
		ZoneId = "YellowDesert",
		DisplayName = "Yellow Sector",
		WorldIndex = 4,
		name = "Yellow Sector",
		unlockCost = 45000,
		UnlockCost = 45000,
		RequiredZoneId = "BlueBeach",
		primaryColor = "Yellow",
		ColorTheme = "Yellow",
		EggIds = { "YellowEgg" },
		BrushIds = { "SunBrush", "DesertRoller" },
		breakableHealth = 140,
		blobCount = 94,
		rewardMultiplier = 7,
		colorValueMultiplier = 12,
		SellValueMultiplier = 12,
	},
	{
		id = "Green",
		ZoneId = "GreenForest",
		DisplayName = "Green Sector",
		WorldIndex = 5,
		name = "Green Sector",
		unlockCost = 150000,
		UnlockCost = 150000,
		RequiredZoneId = "YellowDesert",
		primaryColor = "Green",
		ColorTheme = "Green",
		EggIds = { "GreenEgg" },
		BrushIds = { "LeafBrush", "VineRoller" },
		breakableHealth = 320,
		blobCount = 100,
		rewardMultiplier = 18,
		colorValueMultiplier = 30,
		SellValueMultiplier = 30,
	},
	{
		id = "Purple",
		ZoneId = "PurpleCavern",
		DisplayName = "Purple Sector",
		WorldIndex = 6,
		name = "Purple Sector",
		unlockCost = 500000,
		UnlockCost = 500000,
		RequiredZoneId = "GreenForest",
		primaryColor = "Purple",
		ColorTheme = "Purple",
		EggIds = { "PurpleEgg" },
		BrushIds = { "CrystalBrush", "AmethystRoller" },
		breakableHealth = 800,
		blobCount = 106,
		rewardMultiplier = 55,
		colorValueMultiplier = 75,
		SellValueMultiplier = 75,
	},
	{
		id = "Neon",
		ZoneId = "NeonCity",
		DisplayName = "Neon Sector",
		WorldIndex = 7,
		name = "Neon Sector",
		unlockCost = 1500000,
		UnlockCost = 1500000,
		RequiredZoneId = "PurpleCavern",
		primaryColor = "Neon",
		ColorTheme = "Neon",
		EggIds = { "NeonEgg" },
		BrushIds = { "NeonBrush", "LaserRoller" },
		breakableHealth = 1800,
		blobCount = 112,
		rewardMultiplier = 150,
		colorValueMultiplier = 180,
		SellValueMultiplier = 180,
	},
	{
		id = "Rainbow",
		ZoneId = "RainbowHeaven",
		DisplayName = "Rainbow Sector",
		WorldIndex = 8,
		name = "Rainbow Sector",
		unlockCost = 5000000,
		UnlockCost = 5000000,
		RequiredZoneId = "NeonCity",
		primaryColor = "Rainbow",
		ColorTheme = "Rainbow",
		EggIds = { "RainbowEgg" },
		BrushIds = { "PrismBrush", "PrismRoller" },
		breakableHealth = 4200,
		blobCount = 120,
		rewardMultiplier = 420,
		colorValueMultiplier = 450,
		SellValueMultiplier = 450,
	},
}

function ColorData.getWorldByColor(colorType)
	for _, world in ipairs(ColorData.Worlds) do
		if world.primaryColor == colorType or world.id == colorType or world.ZoneId == colorType then
			return world
		end
	end
	return nil
end

function ColorData.getWorldIndex(colorType)
	for i, world in ipairs(ColorData.Worlds) do
		if world.primaryColor == colorType or world.id == colorType or world.ZoneId == colorType then
			return i
		end
	end
	return nil
end

function ColorData.getUnlockedColorSet(csv)
	local unlocked = {}
	if type(csv) ~= "string" then
		return unlocked
	end

	for _, colorType in ipairs(string.split(csv, ",")) do
		if colorType ~= "" then
			unlocked[colorType] = true
		end
	end

	return unlocked
end

function ColorData.isColorUnlocked(unlockedCsv, colorType)
	if not colorType or colorType == "" then
		return true
	end

	local unlocked = ColorData.getUnlockedColorSet(unlockedCsv)
	return unlocked[colorType] == true
end

function ColorData.getPreviousWorld(colorType)
	local index = ColorData.getWorldIndex(colorType)
	if not index or index <= 1 then
		return nil
	end
	return ColorData.Worlds[index - 1]
end

function ColorData.getNextLockedWorld(unlockedCsv)
	local unlocked = ColorData.getUnlockedColorSet(unlockedCsv)
	for _, world in ipairs(ColorData.Worlds) do
		if not unlocked[world.primaryColor] then
			return world
		end
	end
	return nil
end

-- Breakable object types (no rarity, just color paint)
ColorData.Breakables = {
	PaintBlob = {
		clusterSize = "Small",
		baseReward = 10,
		rewardMin = 10,
		rewardMax = 10,
		health    = 8,
		size      = Vector3.new(2, 2, 2),
	},
	PaintGlob = {
		clusterSize = "Medium",
		baseReward = 15,
		rewardMin = 15,
		rewardMax = 15,
		health    = 20,
		size      = Vector3.new(3, 3, 3),
	},
	PaintBoulder = {
		clusterSize = "Big",
		baseReward = 25,
		rewardMin = 25,
		rewardMax = 25,
		health    = 50,
		size      = Vector3.new(4.5, 4.5, 4.5),
	},
}

return ColorData
