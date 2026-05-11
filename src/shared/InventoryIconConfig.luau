local InventoryIconConfig = {
	-- Upload the full sheet to Roblox and paste the id here to use ImageRect slices.
	-- Example: "rbxassetid://1234567890"
	SheetImage = "",
	SheetSourceFile = "assets/ui/inventoryicons/ChatGPT Image May 10, 2026, 08_55_05 PM.png",

	Icons = {
		Inspect = {
			SourceFile = "assets/ui/inventoryicons/sliced/inspect.png",
			RectOffset = Vector2.new(60, 220),
			RectSize = Vector2.new(300, 310),
			Image = "",
		},
		Tag = {
			SourceFile = "assets/ui/inventoryicons/sliced/tag.png",
			RectOffset = Vector2.new(405, 220),
			RectSize = Vector2.new(300, 310),
			Image = "",
		},
		Sparkle = {
			SourceFile = "assets/ui/inventoryicons/sliced/sparkle.png",
			RectOffset = Vector2.new(748, 220),
			RectSize = Vector2.new(300, 310),
			Image = "",
		},
		Stats = {
			SourceFile = "assets/ui/inventoryicons/sliced/stats.png",
			RectOffset = Vector2.new(1090, 220),
			RectSize = Vector2.new(300, 310),
			Image = "",
		},
		Equip = {
			SourceFile = "assets/ui/inventoryicons/sliced/equip.png",
			RectOffset = Vector2.new(218, 596),
			RectSize = Vector2.new(300, 310),
			Image = "",
		},
		Lock = {
			SourceFile = "assets/ui/inventoryicons/sliced/lock.png",
			RectOffset = Vector2.new(562, 596),
			RectSize = Vector2.new(300, 310),
			Image = "",
		},
		Delete = {
			SourceFile = "assets/ui/inventoryicons/sliced/delete.png",
			RectOffset = Vector2.new(912, 596),
			RectSize = Vector2.new(300, 310),
			Image = "",
		},
	},

	TabIcons = {
		Colors = "Sparkle",
		Brushes = "Tag",
		Potions = "Stats",
		Items = "Inspect",
	},

	DetailButtonIcons = {
		EquipButton = "Equip",
		UseButton = "Equip",
		PrimaryButton = "Equip",
		LockButton = "Lock",
		DeleteButton = "Delete",
	},
}

return InventoryIconConfig
