-- Retired runtime window builder.
-- UIController.client.luau owns the handmade StarterGui.ClientUIRoot.MainHUD UI.
-- Keep this file as a harmless compatibility shim so old Rojo/Studio copies do not
-- keep generating full menu windows at runtime.
print("ManualMenuHookup: disabled; UIController uses editor-built MainHUD windows.")
