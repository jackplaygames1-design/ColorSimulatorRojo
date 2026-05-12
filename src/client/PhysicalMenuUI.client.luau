-- Legacy runtime menu generation is intentionally disabled.
-- The handmade PlayerGui.MainHUD.BottomButtons is wired by WindowButtonController.client.luau.
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local root = playerGui:WaitForChild("MainHUD", 5)
if root and root:FindFirstChild("BottomButtons") and root:FindFirstChild("ModalWindows") then
	print("PhysicalMenuUI: handmade MainHUD.BottomButtons detected; legacy runtime menu disabled.")
else
	warn("PhysicalMenuUI: legacy runtime menu disabled; add/edit StarterGui.MainHUD.BottomButtons in Studio.")
end
