-- Legacy runtime menu generation is intentionally disabled.
-- The handmade PlayerGui.ClientUIRoot.BottomMenu is wired by ManualMenuHookup.client.luau.
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local root = playerGui:WaitForChild("ClientUIRoot", 5)
if root and root:FindFirstChild("BottomMenu") and root:FindFirstChild("WindowLayer") then
	print("PhysicalMenuUI: handmade ClientUIRoot.BottomMenu detected; legacy runtime menu disabled.")
else
	warn("PhysicalMenuUI: legacy runtime menu disabled; add/edit StarterGui.ClientUIRoot.BottomMenu in Studio.")
end
