-- Upgrades are currently locked while the system is being reworked.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIManager = require(ReplicatedStorage:WaitForChild("UIManager"))

UIManager.register("Upgrades", function() end, function() end, function()
	return false
end)
