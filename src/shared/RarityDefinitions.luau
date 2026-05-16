local RarityDefinitions = {}

RarityDefinitions.Order = {
	"Common",
	"Uncommon",
	"Rare",
	"Epic",
	"Legendary",
	"Mythic",
	"Secret",
}

RarityDefinitions.RollOrder = {
	"Secret",
	"Mythic",
	"Legendary",
	"Epic",
	"Rare",
	"Uncommon",
	"Common",
}

RarityDefinitions.Rarities = {
	Common = {
		DisplayColor = Color3.fromRGB(205, 210, 220),
		OneIn = 2,
		BasePowerRange = { 35, 70 },
		RevealIntensity = 1,
		Announce = false,
	},
	Uncommon = {
		DisplayColor = Color3.fromRGB(96, 230, 118),
		OneIn = 6,
		BasePowerRange = { 95, 170 },
		RevealIntensity = 1.15,
		Announce = false,
	},
	Rare = {
		DisplayColor = Color3.fromRGB(76, 145, 255),
		OneIn = 20,
		BasePowerRange = { 320, 620 },
		RevealIntensity = 1.35,
		Announce = false,
	},
	Epic = {
		DisplayColor = Color3.fromRGB(190, 72, 255),
		OneIn = 80,
		BasePowerRange = { 1100, 2100 },
		RevealIntensity = 1.75,
		Announce = false,
	},
	Legendary = {
		DisplayColor = Color3.fromRGB(255, 212, 42),
		OneIn = 500,
		BasePowerRange = { 9800, 14500 },
		RevealIntensity = 2.3,
		Announce = false,
	},
	Mythic = {
		DisplayColor = Color3.fromRGB(255, 54, 245),
		OneIn = 5000,
		BasePowerRange = { 85000, 140000 },
		RevealIntensity = 3,
		Announce = true,
	},
	Secret = {
		DisplayColor = Color3.fromRGB(255, 44, 44),
		OneIn = 100000,
		BasePowerRange = { 850000, 1350000 },
		RevealIntensity = 4,
		Announce = true,
	},
}

local function getRandom(rng)
	if typeof(rng) == "Random" then
		return rng:NextNumber()
	end
	return math.random()
end

function RarityDefinitions.Get(rarity)
	return RarityDefinitions.Rarities[tostring(rarity or "")]
end

function RarityDefinitions.GetDisplayColor(rarity)
	local data = RarityDefinitions.Get(rarity)
	return data and data.DisplayColor or Color3.fromRGB(255, 255, 255)
end

function RarityDefinitions.GetOddsText(rarity)
	local data = RarityDefinitions.Get(rarity)
	if not data then
		return "1 in ?"
	end
	return "1 in " .. tostring(data.OneIn)
end

function RarityDefinitions.GetWeight(rarity)
	local data = RarityDefinitions.Get(rarity)
	local oneIn = data and tonumber(data.OneIn)
	if not oneIn or oneIn <= 0 then
		return 0
	end
	return 1 / oneIn
end

function RarityDefinitions.Roll(rng)
	local totalWeight = 0
	for _, rarity in ipairs(RarityDefinitions.Order) do
		totalWeight += RarityDefinitions.GetWeight(rarity)
	end

	local roll = getRandom(rng) * totalWeight
	local running = 0
	for _, rarity in ipairs(RarityDefinitions.Order) do
		running += RarityDefinitions.GetWeight(rarity)
		if roll <= running then
			return rarity
		end
	end

	return "Common"
end

function RarityDefinitions.RollPower(rarity, rng)
	local data = RarityDefinitions.Get(rarity) or RarityDefinitions.Rarities.Common
	local range = data.BasePowerRange or { 1, 1 }
	local minPower = math.max(1, math.floor(tonumber(range[1]) or 1))
	local maxPower = math.max(minPower, math.floor(tonumber(range[2]) or minPower))
	if typeof(rng) == "Random" then
		return rng:NextInteger(minPower, maxPower)
	end
	return math.random(minPower, maxPower)
end

function RarityDefinitions.GetOddsRows()
	local rows = {}
	for _, rarity in ipairs(RarityDefinitions.Order) do
		local data = RarityDefinitions.Rarities[rarity]
		table.insert(rows, {
			Rarity = rarity,
			OneIn = data.OneIn,
			DisplayColor = data.DisplayColor,
			Text = rarity .. " - 1 in " .. tostring(data.OneIn),
		})
	end
	return rows
end

return RarityDefinitions
