-- Removes Roblox's default loading overlay early so the editable LoadingGui can be seen.
-- The first-frame copy comes from ReplicatedFirst.LoadingGui, not generated UI.
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

ReplicatedFirst:RemoveDefaultLoadingScreen()

task.spawn(function()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local loadingGui = playerGui:FindFirstChild("LoadingGui")
	local template = ReplicatedFirst:FindFirstChild("LoadingGui")
	if not loadingGui and template and template:IsA("ScreenGui") then
		loadingGui = template:Clone()
		loadingGui.Name = "LoadingGui"
		loadingGui.Parent = playerGui
	end
	loadingGui = loadingGui or playerGui:WaitForChild("LoadingGui", 2)
	if loadingGui and loadingGui:IsA("ScreenGui") then
		loadingGui.IgnoreGuiInset = true
		loadingGui.DisplayOrder = math.max(loadingGui.DisplayOrder, 100000)
		loadingGui.Enabled = true
		playerGui:SetAttribute("ColorSimulatorLoadingGuiShownEarly", true)
	end
end)
