# Physical UI Migration

Goal: player-facing UI should live as real Studio/Rojo instances under `StarterGui > ColorSimulatorUI`, with client scripts only wiring events, updating text/images, and cloning explicit row/card templates.

Current first rule:

- `ColorSimulatorUI` is the live root.
- `MainHUD.LeftButtons` is handmade and must stay physical.
- Runtime scripts should not replace, delete, or recreate handmade UI.

Immediate completed guardrails:

- `ClientUIRoot` adopts an existing `ColorSimulatorUI` instead of destroying it for missing version attributes.
- `HudUI` exits early when a physical `MainHUD.LeftButtons` exists, so the old generated left HUD is not built on top of it.
- `StudioHUDHookup` connects existing `InventoryButton`, `ShopButton`, `WorldButton`, and `CodesButton` instead of recreating them.
- `PhysicalMenuUI` now uses a Studio-made `MenuButton` and `PhysicalMenuUI` panel. Create/edit the panel in Studio with:
  `require(game.ReplicatedStorage.PhysicalMenuUIBuilder).Build()`

Convert these screens next, one at a time:

- `InventoryUI.client.luau`: build a physical `InventoryUI` panel and item card templates.
- `ShopUI.client.luau`: build a physical `EquipmentShopUI` panel and brush/upgrade card templates.
- `WorldUI.client.luau`: build a physical `WorldUI` panel with Red/Orange entries only.
- `EggShopUI.client.luau`: build a physical `EggShopUI` panel and hatch result templates.
- `CodesUI.client.luau`: build a physical `CodesUI` panel.
- `DailyQuestClient.client.luau`: build a physical `DailyQuestGui` panel and quest row template.
- `GroupRewardsUI.client.luau`: build a physical `GroupRewardsGui` panel.
- `MutationStationUI.client.luau`: build a physical `MutationStationGui` panel and explanation overlay.
- `GamepassUI.client.luau`: build a physical `GamepassUI` panel and hide broken product entries.

Per-screen rules:

- Do not create visible panels with `Instance.new` in client scripts.
- Find screen objects by name under `PlayerGui > ColorSimulatorUI`.
- Keep one hidden template for repeated rows/cards, then clone that template for data-driven lists.
- Warn once if a required physical object is missing.
- Never hard crash because a Studio object is missing.
- Leave dynamic text, images, visibility, animations, and button hookups in scripts.
