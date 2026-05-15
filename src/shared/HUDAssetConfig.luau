local HUDAssetConfig = {
	UseImageAssets = false,
	Images = {
		GemIcon = "",
		CoinIcon = "",
		ShopButton = "",
		WorldButton = "",
		MenuButton = "",
		NotificationBadge = "",
		NextWorldBarEmpty = "",
		NextWorldBarFill = "",
		SmallEmptyPill = "",
		GemCounterBlank = "",
		CoinCounterBlank = "",
	},
}

-- Physical Studio-made MainHUD.LeftButtons icon mapping.
-- Roblox ImageButtons need uploaded asset ids, not Windows file paths.
-- Upload the PNGs below in Studio, then paste each resulting id as:
-- "rbxassetid://1234567890"
HUDAssetConfig.PhysicalButtonImages = {
	InventoryButton = {
		Image = "",
		SourceFile = "assets/ui/sliced_clean_hud/icons_may9_transparent_128/inventory_backpack.png",
	},
	ShopButton = {
		Image = "",
		SourceFile = "assets/ui/sliced_clean_hud/icons_may9_transparent_128/shop_bag.png",
	},
	WorldButton = {
		Image = "",
		SourceFile = "assets/ui/sliced_clean_hud/icons_may9_transparent_128/world_globe.png",
	},
	CodesButton = {
		Image = "",
		SourceFile = "assets/ui/sliced_clean_hud/icons_may9_transparent_128/codes_ticket.png",
	},
}

HUDAssetConfig.CurrencyImages = {
	Coins = {
		Image = "",
		SourceFile = "assets/ui/sliced_clean_hud/icons_may9_transparent_128/coins.png",
	},
	Gems = {
		Image = "",
		SourceFile = "assets/ui/sliced_clean_hud/icons_may9_transparent_128/gems.png",
	},
}

return HUDAssetConfig
