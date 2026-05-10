-- Defensive beta cleanup: disable any old Studio/runtime ItemsHandler copies
-- that are not the Rojo-managed inert server script. This prevents legacy
-- starter item bundles from being granted before the item economy is ready.
local ServerScriptService = game:GetService("ServerScriptService")

local THIS_SCRIPT = script
local ROJO_SERVER_FOLDER_NAME = "Server"

local function isRojoManagedItemsHandler(instance)
	return instance.Name == "ItemsHandler"
		and instance:IsA("LuaSourceContainer")
		and instance.Parent
		and instance.Parent.Name == ROJO_SERVER_FOLDER_NAME
end

local function disableLegacyItemsHandler(instance)
	if instance == THIS_SCRIPT then
		return
	end
	if not instance:IsA("LuaSourceContainer") then
		return
	end
	if instance.Name ~= "ItemsHandler" then
		return
	end
	if isRojoManagedItemsHandler(instance) then
		return
	end

	if instance:IsA("BaseScript") then
		instance.Disabled = true
	end
	warn("AAA_DisableRuntimeItemGrants: disabled legacy ItemsHandler at " .. instance:GetFullName())
end

for _, descendant in ipairs(ServerScriptService:GetDescendants()) do
	disableLegacyItemsHandler(descendant)
end

ServerScriptService.DescendantAdded:Connect(function(descendant)
	task.defer(disableLegacyItemsHandler, descendant)
end)
