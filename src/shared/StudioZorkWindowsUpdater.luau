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

local function runBuilderMethod(methodName)
	if not RunService:IsStudio() then
		warn("StudioZorkWindowsUpdater can only run in Roblox Studio.")
		return
	end

	local builderModule = ReplicatedStorage:WaitForChild("StudioMenuWindowsBuilder")
	local builder = requireFresh(builderModule)
	local method = builder and builder[methodName]
	if type(method) ~= "function" then
		warn(
			"StudioZorkWindowsUpdater could not find StudioMenuWindowsBuilder."
				.. tostring(methodName)
				.. ". Reconnect Rojo and try again."
		)
		return
	end

	method()
end

function Updater.Update()
	runBuilderMethod("UpdateZorkWindows")
end

function Updater.UpdateUpgrades()
	runBuilderMethod("UpdateUpgradesWindow")
end

function Updater.UpdateWorlds()
	runBuilderMethod("UpdateWorldsWindow")
end

function Updater.UpdateAll()
	runBuilderMethod("UpdateZorkWindows")
	runBuilderMethod("UpdateUpgradesWindow")
	runBuilderMethod("UpdateWorldsWindow")
end

Updater.UpdateZorkWindows = Updater.Update
Updater.UpdateUpgradesWindow = Updater.UpdateUpgrades
Updater.UpdateWorldsWindow = Updater.UpdateWorlds

return Updater
