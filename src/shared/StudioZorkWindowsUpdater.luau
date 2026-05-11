-- Studio command-bar helper that bypasses Roblox's ModuleScript require cache.
-- Run from Studio edit mode:
-- require(game.ReplicatedStorage.StudioZorkWindowsUpdater).Update()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Updater = {}

local function requireFresh(module)
	local clone = module:Clone()
	clone.Name = module.Name .. "_FreshZorkUpdate"
	clone.Parent = module.Parent

	local ok, result = pcall(require, clone)
	clone:Destroy()

	if not ok then
		error(result, 2)
	end

	return result
end

function Updater.Update()
	if not RunService:IsStudio() then
		warn("StudioZorkWindowsUpdater.Update can only run in Roblox Studio.")
		return
	end

	local builderModule = ReplicatedStorage:WaitForChild("StudioMenuWindowsBuilder")
	local builder = requireFresh(builderModule)
	local updateZorkWindows = builder and builder.UpdateZorkWindows
	if type(updateZorkWindows) ~= "function" then
		warn(
			"StudioZorkWindowsUpdater.Update could not find StudioMenuWindowsBuilder.UpdateZorkWindows. Reconnect Rojo and try again."
		)
		return
	end

	updateZorkWindows()
end

Updater.UpdateZorkWindows = Updater.Update

return Updater
