local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BreakableDefinitions = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("BreakableDefinitions"))
local GameBalance = require(ReplicatedStorage:WaitForChild("GameBalance"))
local ZoneDefinitions = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ZoneDefinitions"))

local BreakableService = require(script.Parent:WaitForChild("BreakableService"))

local config = GameBalance.Breakables or {}
if config.Enabled == false or (GameBalance.GameMode and GameBalance.GameMode.UseBreakables == false) then
	return
end

local rng = Random.new()
local spawnQueues = {}
local missingAuthoringWarnings = {}

local function warnMissing(key, message)
	if missingAuthoringWarnings[key] then
		return
	end
	missingAuthoringWarnings[key] = true
	warn(message)
end

local function getAuthoredZone(zoneDefinition)
	local zonesRoot = Workspace:FindFirstChild("Zones")
	if not zonesRoot then
		warnMissing("ZonesRoot", "BreakableSpawner: missing editable Workspace.Zones folder.")
		return nil, nil, nil
	end

	local folderName = zoneDefinition.FolderName or zoneDefinition.ZoneId
	local zoneFolder = zonesRoot:FindFirstChild(folderName)
	if not zoneFolder or not zoneFolder:IsA("Folder") then
		warnMissing(
			"Zone:" .. tostring(folderName),
			("BreakableSpawner: missing editable Workspace.Zones.%s folder."):format(tostring(folderName))
		)
		return nil, nil, nil
	end

	local spawnArea = zoneFolder:FindFirstChild(zoneDefinition.SpawnAreaName, true)
	if not spawnArea or not spawnArea:IsA("BasePart") then
		warnMissing(
			"SpawnArea:" .. tostring(folderName),
			("BreakableSpawner: missing editable %s.%s BasePart."):format(
				zoneFolder:GetFullName(),
				tostring(zoneDefinition.SpawnAreaName)
			)
		)
		return nil, nil, nil
	end

	local breakables = zoneFolder:FindFirstChild(zoneDefinition.BreakablesFolderName)
	if not breakables or not breakables:IsA("Folder") then
		warnMissing(
			"Breakables:" .. tostring(folderName),
			("BreakableSpawner: missing editable %s.%s folder."):format(
				zoneFolder:GetFullName(),
				tostring(zoneDefinition.BreakablesFolderName)
			)
		)
		return nil, nil, nil
	end

	zoneFolder:SetAttribute("ZoneId", zoneDefinition.ZoneId)
	zoneFolder:SetAttribute("WorldZoneId", zoneDefinition.WorldZoneId)
	zoneFolder:SetAttribute("LocationId", zoneDefinition.LocationId)
	zoneFolder:SetAttribute("ColorType", zoneDefinition.ColorType)
	spawnArea:SetAttribute("ZoneId", zoneDefinition.WorldZoneId or zoneDefinition.ZoneId)
	spawnArea:SetAttribute("ColorType", zoneDefinition.ColorType)

	return zoneFolder, spawnArea, breakables
end

local function getActiveCount(folder)
	local count = 0
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Model") and child:GetAttribute("Alive") == true then
			count += 1
		end
	end
	return count
end

local function getPendingCount(zoneId)
	local queue = spawnQueues[zoneId]
	return queue and #queue or 0
end

local function getRandomPointInArea(area)
	local half = area.Size * 0.5
	local localX = rng:NextNumber(-half.X, half.X)
	local localZ = rng:NextNumber(-half.Z, half.Z)
	local top = area.CFrame:PointToWorldSpace(Vector3.new(localX, half.Y + 70, localZ))
	return top
end

local function raycastGround(origin, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore or {}
	params.IgnoreWater = true
	return Workspace:Raycast(origin, Vector3.new(0, -250, 0), params)
end

local function hasSpacing(folder, position, spacing)
	for _, child in ipairs(folder:GetChildren()) do
		local primary = child:IsA("Model") and child.PrimaryPart
		if primary and child:GetAttribute("Alive") == true then
			local other = primary.Position
			if (Vector3.new(other.X, 0, other.Z) - Vector3.new(position.X, 0, position.Z)).Magnitude < spacing then
				return false
			end
		end
	end
	return true
end

local function findSpawnCFrame(area, folder, definition)
	local attempts = tonumber(config.Spawner and config.Spawner.SpawnAttempts) or 18
	local spacing = tonumber(definition.Footprint) or tonumber(config.Spawner and config.Spawner.MinSpawnSpacing) or 6
	local ignore = { folder, area }
	for _ = 1, attempts do
		local result = raycastGround(getRandomPointInArea(area), ignore)
		if result and result.Instance and hasSpacing(folder, result.Position, spacing) then
			local spawnHeight = tonumber(definition.SpawnHeight) or 1.2
			return CFrame.new(result.Position + Vector3.new(0, spawnHeight, 0))
				* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		end
	end
	return nil
end

local function spawnType(zoneDefinition, area, folder, typeId)
	local definition = BreakableDefinitions.Get(typeId)
	if not definition then
		return nil
	end
	local cframe = findSpawnCFrame(area, folder, definition)
	if not cframe then
		return nil
	end
	local model = BreakableService.SpawnBreakable(
		typeId,
		zoneDefinition.ZoneId,
		cframe,
		folder,
		zoneDefinition.ColorType,
		zoneDefinition
	)
	if model and config.Debug and config.Debug.PrintSpawns then
		print("BreakableSpawner: spawned " .. tostring(typeId) .. " in " .. tostring(zoneDefinition.ZoneId))
	end
	return model
end

local function queueRespawn(zoneId, typeId, delaySeconds)
	spawnQueues[zoneId] = spawnQueues[zoneId] or {}
	table.insert(spawnQueues[zoneId], {
		TypeId = typeId,
		ReadyAt = os.clock() + math.max(tonumber(delaySeconds) or 5, 0),
	})
end

BreakableService.Start()

BreakableService.BreakableBroken.Event:Connect(function(_model, definition, zoneId)
	queueRespawn(zoneId or "RedSector", definition.AssetName or "ColorSpill", definition.RespawnTime or 5)
end)

for _, zoneId in ipairs(ZoneDefinitions.Order) do
	spawnQueues[zoneId] = {}
	getAuthoredZone(ZoneDefinitions.Get(zoneId))
end

task.spawn(function()
	task.wait(1)
	while true do
		for _, zoneId in ipairs(ZoneDefinitions.Order) do
			local zoneDefinition = ZoneDefinitions.Get(zoneId)
			local _, area, folder = getAuthoredZone(zoneDefinition)
			if not area or not folder then
				continue
			end
			local active = getActiveCount(folder)
			local maxActive = tonumber(zoneDefinition.MaxActiveBreakables) or 35
			local pending = getPendingCount(zoneId)

			local queue = spawnQueues[zoneId]
			if queue then
				for index = #queue, 1, -1 do
					local item = queue[index]
					if os.clock() >= item.ReadyAt and getActiveCount(folder) < maxActive then
						if spawnType(zoneDefinition, area, folder, item.TypeId) then
							table.remove(queue, index)
						end
					end
				end
			end

			active = getActiveCount(folder)
			pending = getPendingCount(zoneId)
			while active + pending < maxActive do
				local typeId = BreakableDefinitions.GetWeightedRandom(rng)
				if spawnType(zoneDefinition, area, folder, typeId) then
					active += 1
				else
					break
				end
			end
		end
		task.wait(tonumber(config.Spawner and config.Spawner.TickInterval) or 1)
	end
end)

print("BreakableSpawnerService ready")
