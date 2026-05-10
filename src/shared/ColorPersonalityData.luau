local ColorPersonalityData = {}

-- Internal systems may use Pet naming, but player-facing companions are called Colors.
ColorPersonalityData.DefaultId = "Neutral"

ColorPersonalityData.Personalities = {
	Neutral = {
		Id = "Neutral",
		DisplayName = "Neutral",
		Description = "A steady Color with no special bonus.",
		Weight = 25,
		EffectType = "None",
		EffectValue = 0,
		Color = Color3.fromRGB(185, 190, 205),
		Icon = "-",
	},
	Cheerful = {
		Id = "Cheerful",
		DisplayName = "Cheerful",
		Description = "Boosts Color gained slightly.",
		Weight = 20,
		EffectType = "ColorGainMultiplier",
		EffectValue = 0.05,
		Color = Color3.fromRGB(116, 245, 42),
		Icon = "+",
	},
	Greedy = {
		Id = "Greedy",
		DisplayName = "Greedy",
		Description = "Boosts Coins from Color breaks.",
		Weight = 20,
		EffectType = "SellMultiplier",
		EffectValue = 0.05,
		Color = Color3.fromRGB(255, 226, 92),
		Icon = "$",
	},
	Speedy = {
		Id = "Speedy",
		DisplayName = "Speedy",
		Description = "Slightly increases walk speed while equipped.",
		Weight = 15,
		EffectType = "WalkSpeedBonus",
		EffectValue = 1,
		Color = Color3.fromRGB(118, 238, 244),
		Icon = ">",
	},
	Curious = {
		Id = "Curious",
		DisplayName = "Curious",
		Description = "Slightly increases pickup range.",
		Weight = 10,
		EffectType = "PickupRangeMultiplier",
		EffectValue = 0.05,
		Color = Color3.fromRGB(170, 150, 255),
		Icon = "?",
	},
	Lucky = {
		Id = "Lucky",
		DisplayName = "Lucky",
		Description = "Slightly improves hatch luck while equipped.",
		Weight = 7,
		EffectType = "LuckBonus",
		EffectValue = 0.02,
		Color = Color3.fromRGB(140, 255, 145),
		Icon = "*",
	},
	Loyal = {
		Id = "Loyal",
		DisplayName = "Loyal",
		Description = "Slightly boosts all equipped Colors.",
		Weight = 3,
		EffectType = "TotalPowerMultiplier",
		EffectValue = 0.03,
		Color = Color3.fromRGB(255, 160, 190),
		Icon = "L",
	},
	Sleepy = {
		Id = "Sleepy",
		DisplayName = "Sleepy",
		Description = "A mellow Color. Future updates may give it merge bonuses.",
		Weight = 5,
		EffectType = "None",
		EffectValue = 0,
		Color = Color3.fromRGB(185, 175, 235),
		Icon = "Z",
	},
}

ColorPersonalityData.Order = {
	"Neutral",
	"Cheerful",
	"Greedy",
	"Speedy",
	"Curious",
	"Lucky",
	"Loyal",
	"Sleepy",
}

function ColorPersonalityData.get(personalityId)
	return ColorPersonalityData.Personalities[personalityId or ColorPersonalityData.DefaultId]
		or ColorPersonalityData.Personalities[ColorPersonalityData.DefaultId]
end

function ColorPersonalityData.roll()
	local totalWeight = 0
	for _, personalityId in ipairs(ColorPersonalityData.Order) do
		local personality = ColorPersonalityData.Personalities[personalityId]
		totalWeight += personality and personality.Weight or 0
	end

	local roll = math.random() * totalWeight
	for _, personalityId in ipairs(ColorPersonalityData.Order) do
		local personality = ColorPersonalityData.Personalities[personalityId]
		roll -= personality and personality.Weight or 0
		if roll <= 0 then
			return personality
		end
	end

	return ColorPersonalityData.Personalities.Neutral
end

return ColorPersonalityData
