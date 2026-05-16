-- Removes Roblox's default loading overlay early so the Studio-authored LoadingGui can be seen.
-- This does not build UI at runtime; LoadingGui remains editable under StarterGui.
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local loadingGui = playerGui:FindFirstChild("LoadingGui") or playerGui:WaitForChild("LoadingGui", 6)
if loadingGui and loadingGui:IsA("ScreenGui") then
	loadingGui.IgnoreGuiInset = true
	loadingGui.DisplayOrder = math.max(loadingGui.DisplayOrder, 100000)
	loadingGui.Enabled = true
	playerGui:SetAttribute("ColorSimulatorLoadingGuiShownEarly", true)
end
