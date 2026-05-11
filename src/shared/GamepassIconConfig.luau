local GamepassIconConfig = {
	-- Roblox ImageLabels need uploaded asset ids, not Windows file paths.
	-- Upload each PNG below in Studio, then paste the resulting id as:
	-- Image = "rbxassetid://1234567890"
	Icons = {
		vip = {
			Image = "",
			SourceFile = "assets/ui/gamepass/vip.png",
		},
		double_coins = {
			Image = "",
			SourceFile = "assets/ui/gamepass/2xcoin.png",
		},
		lucky_hatch = {
			Image = "",
			SourceFile = "assets/ui/gamepass/luckhatch.png",
		},
		plus_3_colors = {
			Image = "",
			SourceFile = "assets/ui/gamepass/3pluscolors.png",
		},
		auto_sell = {
			Image = "",
			SourceFile = "assets/ui/gamepass/autosell.png",
		},
		coin_potion = {
			Image = "",
			SourceFile = "assets/ui/itemsui/sliced/coin_potion.png",
		},
		coins = {
			Image = "",
			SourceFile = "assets/ui/itemsui/sliced/coins.png",
		},
		gem = {
			Image = "",
			SourceFile = "assets/ui/itemsui/sliced/gem.png",
		},
		gem_potion = {
			Image = "",
			SourceFile = "assets/ui/itemsui/sliced/gem_potion.png",
		},
		luck_potion = {
			Image = "",
			SourceFile = "assets/ui/itemsui/sliced/luck_potion.png",
		},
		mystery_potion = {
			Image = "",
			SourceFile = "assets/ui/itemsui/sliced/mystery_potion.png",
		},
		rainbow_paint_potion = {
			Image = "",
			SourceFile = "assets/ui/itemsui/sliced/rainbow_paint_potion.png",
		},
		speed_potion = {
			Image = "",
			SourceFile = "assets/ui/itemsui/sliced/speed_potion.png",
		},
	},

	ByShopItemId = {
		AutoSell = "auto_sell",
		DoubleCoins = "double_coins",
		LuckyHatch = "lucky_hatch",
		Plus3Colors = "plus_3_colors",
		VIP = "vip",
	},
}

return GamepassIconConfig
