-- Legacy generated HUD disabled.
-- The active HUD/menu/currency must be handmade under PlayerGui.MainHUD.
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local root = playerGui:WaitForChild("MainHUD", 8)
if root then
	playerGui:SetAttribute("StudioMainHUDPresent", true)
	root:SetAttribute("UsesPhysicalMainHUD", true)
	print("HudUI: legacy generated HUD disabled; using handmade MainHUD.")
else
	warn("HudUI: legacy generated HUD disabled, but PlayerGui.MainHUD was not found.")
end
