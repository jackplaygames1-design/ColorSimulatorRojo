local ColorTraitData = {}

ColorTraitData.DefaultId = "Neutral"

ColorTraitData.Traits = {
	Neutral = {
		Id = "Neutral",
		DisplayName = "Neutral",
		Description = "No special bonus.",
		Weight = 25,
		Effects = {},
		SortOrder = 1,
		TextColor = Color3.fromRGB(185, 190, 205),
		Icon = "-",
	},
	Swift = {
		Id = "Swift",
		DisplayName = "Swift",
		Description = "Slightly increases movement speed.",
		Weight = 16,
		Effects = { WalkSpeedBonus = 1.5 },
		SortOrder = 2,
		TextColor = Color3.fromRGB(118, 238, 244),
		Icon = ">",
	},
	Bouncy = {
		Id = "Bouncy",
		DisplayName = "Bouncy",
		Description = "Slightly increases jump power.",
		Weight = 12,
		Effects = { JumpPowerBonus = 6 },
		SortOrder = 3,
		TextColor = Color3.fromRGB(170, 150, 255),
		Icon = "^",
	},
	Quick = {
		Id = "Quick",
		DisplayName = "Quick",
		Description = "Brushes slightly faster.",
		Weight = 14,
		Effects = { BrushCooldownMultiplier = 0.95 },
		SortOrder = 4,
		TextColor = Color3.fromRGB(255, 170, 72),
		Icon = "Q",
	},
	Wide = {
		Id = "Wide",
		DisplayName = "Wide",
		Description = "Increases brush range.",
		Weight = 12,
		Effects = { BrushRangeMultiplier = 1.08 },
		SortOrder = 5,
		TextColor = Color3.fromRGB(91, 230, 235),
		Icon = "+",
	},
	Bright = {
		Id = "Bright",
		DisplayName = "Bright",
		Description = "Collects slightly more Color.",
		Weight = 12,
		Effects = { ColorGainMultiplier = 1.06 },
		SortOrder = 6,
		TextColor = Color3.fromRGB(255, 75, 200),
		Icon = "*",
	},
	Greedy = {
		Id = "Greedy",
		DisplayName = "Greedy",
		Description = "Sells Color for slightly more Coins.",
		Weight = 10,
		Effects = { SellCoinsMultiplier = 1.06 },
		SortOrder = 7,
		TextColor = Color3.fromRGB(255, 210, 64),
		Icon = "$",
	},
	Lucky = {
		Id = "Lucky",
		DisplayName = "Lucky",
		Description = "Slightly improves hatch luck.",
		Weight = 6,
		Effects = { HatchLuckBonus = 0.03 },
		SortOrder = 8,
		TextColor = Color3.fromRGB(91, 228, 126),
		Icon = "%",
	},
	SuperLucky = {
		Id = "SuperLucky",
		DisplayName = "Super Lucky",
		Description = "Massively improves hatch luck.",
		Weight = 0,
		Effects = { HatchLuckBonus = 1.5 },
		SortOrder = 9,
		TextColor = Color3.fromRGB(255, 235, 90),
		Icon = "%",
	},
	Charged = {
		Id = "Charged",
		DisplayName = "Charged",
		Description = "Sometimes zaps nearby Color blobs while brushing.",
		Weight = 3,
		Effects = {
			LightningProcChance = 0.08,
			LightningTargets = 1,
			LightningRange = 28,
			LightningCooldown = 4,
		},
		SortOrder = 9,
		TextColor = Color3.fromRGB(107, 218, 255),
		Icon = "Z",
	},
}

ColorTraitData.Order = {
	"Neutral",
	"Swift",
	"Bouncy",
	"Quick",
	"Wide",
	"Bright",
	"Greedy",
	"Lucky",
	"SuperLucky",
	"Charged",
}

function ColorTraitData.normalize(traitId)
	if ColorTraitData.Traits[traitId or ""] then
		return traitId
	end
	return ColorTraitData.DefaultId
end

function ColorTraitData.get(traitId)
	return ColorTraitData.Traits[ColorTraitData.normalize(traitId)]
end

function ColorTraitData.roll()
	local totalWeight = 0
	for _, traitId in ipairs(ColorTraitData.Order) do
		local trait = ColorTraitData.Traits[traitId]
		totalWeight += trait and trait.Weight or 0
	end

	local roll = math.random() * totalWeight
	for _, traitId in ipairs(ColorTraitData.Order) do
		local trait = ColorTraitData.Traits[traitId]
		roll -= trait and trait.Weight or 0
		if roll <= 0 then
			return trait
		end
	end

	return ColorTraitData.Traits.Neutral
end

return ColorTraitData
