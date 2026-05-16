local BreakableDefinitions = {}

BreakableDefinitions.Types = {
	ColorSpill = {
		DisplayName = "Color Spill",
		AssetName = "ColorSpill",
		MaxHealth = 50,
		SpawnWeight = 55,
		RespawnTime = 4,
		RewardTable = "SmallColorReward",
		SpawnRadius = 4,
		Footprint = 4,
		SpawnHeight = 0.14,
	},
	ColorClump = {
		DisplayName = "Color Clump",
		AssetName = "ColorClump",
		MaxHealth = 150,
		SpawnWeight = 25,
		RespawnTime = 6,
		RewardTable = "MediumColorReward",
		SpawnRadius = 5,
		Footprint = 5,
		SpawnHeight = 1.6,
	},
	ColorCrate = {
		DisplayName = "Color Crate",
		AssetName = "ColorCrate",
		MaxHealth = 400,
		SpawnWeight = 13,
		RespawnTime = 10,
		RewardTable = "CrateReward",
		SpawnRadius = 7,
		Footprint = 8,
		SpawnHeight = 2.25,
	},
	ColorChest = {
		DisplayName = "Color Chest",
		AssetName = "ColorChest",
		MaxHealth = 1200,
		SpawnWeight = 5,
		RespawnTime = 18,
		RewardTable = "ChestReward",
		SpawnRadius = 9,
		Footprint = 10,
		SpawnHeight = 2,
	},
	HugeColorChest = {
		DisplayName = "Huge Color Chest",
		AssetName = "HugeColorChest",
		MaxHealth = 5000,
		SpawnWeight = 1.5,
		RespawnTime = 45,
		RewardTable = "HugeChestReward",
		SpawnRadius = 13,
		Footprint = 16,
		SpawnHeight = 3.6,
	},
	GiantColorCoreChest = {
		DisplayName = "Giant Color Core Chest",
		AssetName = "GiantColorCoreChest",
		MaxHealth = 25000,
		SpawnWeight = 0.2,
		RespawnTime = 120,
		RewardTable = "GiantCoreReward",
		AnnounceOnSpawn = true,
		SpawnRadius = 18,
		Footprint = 22,
		SpawnHeight = 1,
	},
}

BreakableDefinitions.Order = {
	"ColorSpill",
	"ColorClump",
	"ColorCrate",
	"ColorChest",
	"HugeColorChest",
	"GiantColorCoreChest",
}

function BreakableDefinitions.Get(typeId)
	return BreakableDefinitions.Types[tostring(typeId or "")]
end

function BreakableDefinitions.GetWeightedRandom(random)
	random = random or Random.new()
	local totalWeight = 0
	for _, typeId in ipairs(BreakableDefinitions.Order) do
		local definition = BreakableDefinitions.Types[typeId]
		totalWeight += tonumber(definition.SpawnWeight) or 0
	end
	if totalWeight <= 0 then
		return "ColorSpill", BreakableDefinitions.Types.ColorSpill
	end

	local roll = random:NextNumber(0, totalWeight)
	local running = 0
	for _, typeId in ipairs(BreakableDefinitions.Order) do
		local definition = BreakableDefinitions.Types[typeId]
		running += tonumber(definition.SpawnWeight) or 0
		if roll <= running then
			return typeId, definition
		end
	end

	return "ColorSpill", BreakableDefinitions.Types.ColorSpill
end

return BreakableDefinitions
