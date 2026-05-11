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
