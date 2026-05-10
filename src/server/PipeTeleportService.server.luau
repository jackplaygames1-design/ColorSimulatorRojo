-- Server-safe pipe teleporting.
-- Fixes players dying when moving between Inside the Pipes and Orange Sector.
-- This script does not create UI and never kills the player; it only moves them to safe marker parts.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local TELEPORT_COOLDOWN_SECONDS = 2
local TELEPORT_GRACE_SECONDS = 1.25
local DEFAULT_OFFSET = Vector3.new(0, 5, 0)

local cooldownByPlayer = {}

local DESTINATION_ALIASES = {
	OrangeSector = { "OrangeSectorSpawn", "OrangeZoneSpawn", "OrangeSpawn" },
	InsidePipes = { "PipeExitSpawn", "InsidePipesSpawn", "MutationZoneSpawn" },
	RedWastelands = { "RedWastelandsSpawn", "RedZoneSpawn", "StartSectorSpawn", "SpawnLocation" },
	OriginSector = { "OriginSectorSpawn", "StartSectorSpawn", "SpawnWorldSpawn", "SpawnLocation" },
	SpawnWorld = { "OriginSectorSpawn", "StartSectorSpawn", "SpawnWorldSpawn", "SpawnLocation" },
}

local TRIGGER_NAME_DESTINATION = {
	PipeTrigger = "InsidePipes",
	PipeToInside = "InsidePipes",
	PipeToPipes = "InsidePipes",
	PipeToMutation = "InsidePipes",
	OrangePipeEnter = "InsidePipes",
	MutationPipeEnter = "InsidePipes",

	PipeExitTrigger = "OrangeSector",
	PipeReturnTrigger = "OrangeSector",
	PipeBackTrigger = "OrangeSector",
	PipeToOrange = "OrangeSector",
	BackToOrangePipe = "OrangeSector",
	OrangePipeExit = "OrangeSector",
}

local function findSpawnByNames(names)
	for _, name in ipairs(names or {}) do
		local found = workspace:FindFirstChild(name, true)
		if found and found:IsA("BasePart") then
			return found
		end
	end
	return nil
end

local function resolveDestinationPart(trigger)
	local explicitName = trigger:GetAttribute("PipeDestinationName")
		or trigger:GetAttribute("DestinationPartName")
		or trigger:GetAttribute("DestinationName")
	if type(explicitName) == "string" and explicitName ~= "" then
		local found = workspace:FindFirstChild(explicitName, true)
		if found and found:IsA("BasePart") then
			return found
		end
		warn("PipeTeleportService: missing explicit destination part:", explicitName)
		return nil
	end

	local destinationId = trigger:GetAttribute("PipeDestination")
		or trigger:GetAttribute("Destination")
		or trigger:GetAttribute("TravelLocation")
		or TRIGGER_NAME_DESTINATION[trigger.Name]

	if type(destinationId) == "string" and DESTINATION_ALIASES[destinationId] then
		return findSpawnByNames(DESTINATION_ALIASES[destinationId])
	end

	-- Name fallback for common pipe trigger names.
	local lowered = string.lower(trigger.Name)
	if lowered:find("orange") or lowered:find("return") or lowered:find("back") or lowered:find("exit") then
		return findSpawnByNames(DESTINATION_ALIASES.OrangeSector)
	end
	if lowered:find("pipe") or lowered:find("mutation") or lowered:find("inside") then
		return findSpawnByNames(DESTINATION_ALIASES.InsidePipes)
	end

	return nil
end

local function getPlayerFromHit(hit)
	local character = hit and hit:FindFirstAncestorOfClass("Model")
	if not character then
		return nil, nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil, nil
	end

	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return nil, nil
	end

	return player, character
end

local function safeTeleport(player, character, destinationPart)
	local now = os.clock()
	if cooldownByPlayer[player] and now - cooldownByPlayer[player] < TELEPORT_COOLDOWN_SECONDS then
		return
	end
	cooldownByPlayer[player] = now

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	player:SetAttribute("IsTeleporting", true)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.CFrame = destinationPart.CFrame + DEFAULT_OFFSET

	task.delay(TELEPORT_GRACE_SECONDS, function()
		if player and player.Parent then
			player:SetAttribute("IsTeleporting", false)
		end
	end)
end

local function hookPipeTrigger(trigger)
	if not trigger:IsA("BasePart") then
		return
	end
	if trigger:GetAttribute("PipeTeleportHooked") == true then
		return
	end

	local destinationPart = resolveDestinationPart(trigger)
	if not destinationPart then
		-- Do not spam warnings for random map parts. Only warn likely pipe triggers.
		if string.lower(trigger.Name):find("pipe") then
			warn("PipeTeleportService: no destination for pipe trigger:", trigger:GetFullName())
		end
		return
	end

	trigger:SetAttribute("PipeTeleportHooked", true)
	trigger.CanTouch = true
	trigger.Touched:Connect(function(hit)
		local player, character = getPlayerFromHit(hit)
		if not player or not character then
			return
		end
		-- Re-resolve each time so moving the spawn marker in Studio updates behavior.
		local currentDestination = resolveDestinationPart(trigger) or destinationPart
		safeTeleport(player, character, currentDestination)
	end)

	print("PipeTeleportService: hooked", trigger:GetFullName(), "->", destinationPart:GetFullName())
end

local function shouldTryHook(part)
	if not part:IsA("BasePart") then
		return false
	end
	if part:GetAttribute("PipeTeleport") == true or part:GetAttribute("PipeDestination") ~= nil or part:GetAttribute("PipeDestinationName") ~= nil then
		return true
	end
	if CollectionService:HasTag(part, "PipeTeleport") or CollectionService:HasTag(part, "PipeTrigger") then
		return true
	end
	local lowered = string.lower(part.Name)
	return lowered:find("pipe") and (lowered:find("trigger") or lowered:find("enter") or lowered:find("exit") or lowered:find("return") or lowered:find("back") or lowered:find("orange") or lowered:find("inside"))
end

local function scanWorkspace()
	for _, obj in ipairs(workspace:GetDescendants()) do
		if shouldTryHook(obj) then
			hookPipeTrigger(obj)
		end
	end
end

scanWorkspace()
workspace.DescendantAdded:Connect(function(obj)
	task.defer(function()
		if obj.Parent and shouldTryHook(obj) then
			hookPipeTrigger(obj)
		end
	end)
end)

for _, tagName in ipairs({ "PipeTeleport", "PipeTrigger" }) do
	for _, obj in ipairs(CollectionService:GetTagged(tagName)) do
		hookPipeTrigger(obj)
	end
	CollectionService:GetInstanceAddedSignal(tagName):Connect(hookPipeTrigger)
end

Players.PlayerRemoving:Connect(function(player)
	cooldownByPlayer[player] = nil
end)
