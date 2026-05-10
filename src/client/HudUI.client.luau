-- Legacy generated HUD disabled.
-- The active HUD/menu/currency must be handmade under PlayerGui.ClientUIRoot.
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local root = playerGui:WaitForChild("ClientUIRoot", 8)
if root then
	playerGui:SetAttribute("StudioMainHUDPresent", true)
	root:SetAttribute("UsesPhysicalMainHUD", true)
	print("HudUI: legacy generated HUD disabled; using handmade ClientUIRoot.")
else
	warn("HudUI: legacy generated HUD disabled, but PlayerGui.ClientUIRoot was not found.")
end
