local Players = game:GetService("Players")

local BuffService = require(script.Parent:WaitForChild("BuffService"))
local ColorEffectHandler = require(script.Parent:WaitForChild("ColorEffectHandler"))

local function apply(player)
	if player and player:IsDescendantOf(Players) then
		ColorEffectHandler.ApplyCharacterEffects(player)
	end
end

BuffService.BuffChanged.Event:Connect(apply)

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.25)
		apply(player)
	end)
end)

