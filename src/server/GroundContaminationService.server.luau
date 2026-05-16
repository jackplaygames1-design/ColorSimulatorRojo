-- Boots the data-driven ground paint coat. Legacy physical contamination parts are disabled.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameBalance = require(ReplicatedStorage:WaitForChild("GameBalance"))

local config = GameBalance.GroundPaint or {}
if config.Enabled == false then
	return
end

require(script.Parent:WaitForChild("GroundPaintService")).Start()
