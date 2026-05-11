local UpgradeIconConfig = {
	-- Roblox ImageLabels need uploaded asset ids, not Windows file paths.
	-- Upload each PNG below in Studio, then paste the resulting id as:
	-- Image = "rbxassetid://1234567890"
	Icons = {
		walk_speed = {
			Image = "",
			SourceFile = "assets/ui/upgradeicons/sliced/walk_speed.png",
		},
		inventory_size = {
			Image = "",
			SourceFile = "assets/ui/upgradeicons/sliced/inventory_size.png",
		},
		player_power = {
			Image = "",
			SourceFile = "assets/ui/upgradeicons/sliced/player_power.png",
		},
		luck = {
			Image = "",
			SourceFile = "assets/ui/upgradeicons/sliced/luck.png",
		},
		gem_capacity = {
			Image = "",
			SourceFile = "assets/ui/upgradeicons/sliced/gem_capacity.png",
		},
		health = {
			Image = "",
			SourceFile = "assets/ui/upgradeicons/sliced/health.png",
		},
		brush_power = {
			Image = "",
			SourceFile = "assets/ui/upgradeicons/sliced/brush_power.png",
		},
		brush_size = {
			Image = "",
			SourceFile = "assets/ui/upgradeicons/sliced/brush_size.png",
		},
		paint_capacity = {
			Image = "",
			SourceFile = "assets/ui/upgradeicons/sliced/paint_capacity.png",
		},
		paint_speed = {
			Image = "",
			SourceFile = "assets/ui/upgradeicons/sliced/paint_speed.png",
		},
		splash_range = {
			Image = "",
			SourceFile = "assets/ui/upgradeicons/sliced/splash_range.png",
		},
		crit_chance = {
			Image = "",
			SourceFile = "assets/ui/upgradeicons/sliced/crit_chance.png",
		},
		coin_multiplier = {
			Image = "",
			SourceFile = "assets/ui/upgradeicons/sliced/coin_multiplier.png",
		},
		coin_capacity = {
			Image = "",
			SourceFile = "assets/ui/upgradeicons/sliced/coin_capacity.png",
		},
		sell_value = {
			Image = "",
			SourceFile = "assets/ui/upgradeicons/sliced/sell_value.png",
		},
		gem_multiplier = {
			Image = "",
			SourceFile = "assets/ui/upgradeicons/sliced/gem_multiplier.png",
		},
		gem_value = {
			Image = "",
			SourceFile = "assets/ui/upgradeicons/sliced/gem_value.png",
		},
		passive_income = {
			Image = "",
			SourceFile = "assets/ui/upgradeicons/sliced/passive_income.png",
		},
	},

	ByUpgradeId = {
		WalkSpeed = "walk_speed",
		PetSlots = "inventory_size",
		InventorySize = "inventory_size",
		PlayerPower = "player_power",
		Luck = "luck",
		ColorLuck = "luck",
		GemLuck = "luck",
		GemCapacity = "gem_capacity",
		Health = "health",
		BrushPower = "brush_power",
		BrushSize = "brush_size",
		PaintCapacity = "paint_capacity",
		PaintSpeed = "paint_speed",
		PickupRange = "splash_range",
		BrushRange = "splash_range",
		CritChance = "crit_chance",
		ColorMultiplier = "coin_multiplier",
		CoinMultiplier = "coin_multiplier",
		CoinBoost = "coin_multiplier",
		CoinCapacity = "coin_capacity",
		SellValue = "sell_value",
		GemMultiplier = "gem_multiplier",
		GemBoost = "gem_multiplier",
		GemValue = "gem_value",
		PassiveIncome = "passive_income",
		HatchSpeed = "paint_speed",
	},

	ByCardName = {
		["Walk Speed"] = "walk_speed",
		["Inventory Size"] = "inventory_size",
		["Color Slots"] = "inventory_size",
		["Player Power"] = "player_power",
		["Luck"] = "luck",
		["Gem Luck"] = "luck",
		["Gem Capacity"] = "gem_capacity",
		["Health"] = "health",
		["Brush Power"] = "brush_power",
		["Brush Size"] = "brush_size",
		["Paint Capacity"] = "paint_capacity",
		["Paint Speed"] = "paint_speed",
		["Hatch Speed"] = "paint_speed",
		["Splash Range"] = "splash_range",
		["Pickup Range"] = "splash_range",
		["Crit Chance"] = "crit_chance",
		["Coin Multiplier"] = "coin_multiplier",
		["Coin Boost"] = "coin_multiplier",
		["Coin Value"] = "coin_multiplier",
		["Coin Capacity"] = "coin_capacity",
		["Sell Value"] = "sell_value",
		["Gem Multiplier"] = "gem_multiplier",
		["Gem Value"] = "gem_value",
		["Passive Income"] = "passive_income",
	},
}

return UpgradeIconConfig
