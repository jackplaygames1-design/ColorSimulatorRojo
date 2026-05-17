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
local spawnFailWarnings = {}
local initializedZones = {}
local lastActiveLogAt = {}

local INITIAL_RED_MIX = {
	{ TypeId = "ColorSpill", Count = 15 },
	{ TypeId = "ColorClump", Count = 8 },
	{ TypeId = "ColorCrate", Count = 6 },
	{ TypeId = "ColorChest", Count = 4 },
	{ TypeId = "HugeColorChest", Count = 1 },
}

local function warnMissing(key, message)
	if missingAuthoringWarnings[key] then
		return
	end
	missingAuthoringWarnings[key] = true
	warn(message)
end

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if folder and folder:IsA("Folder") then
		return folder
	end
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function ensurePart(parent, name)
	local part = parent:FindFirstChild(name)
	if part and part:IsA("BasePart") then
		return part
	end
	if part then
		part:Destroy()
	end
	part = Instance.new("Part")
	part.Name = name
	part.Parent = parent
	return part
end

local function ensureFallbackFloor(zoneFolder, zoneDefinition)
	local floorFolder = ensureFolder(zoneFolder, "Floor")
	local existing = floorFolder:FindFirstChild("BaseFloor")
	local wasCreated = not (existing and existing:IsA("BasePart"))
	local floor = ensurePart(floorFolder, "BaseFloor")
	if not wasCreated and floor:GetAttribute("RuntimeFallbackSectorFloor") ~= true then
		return floor
	end
	floor.Anchored = true
	floor.CanCollide = true
	floor.CanTouch = false
	floor.CanQuery = true
	floor.Material = Enum.Material.SmoothPlastic
	floor.Color = zoneDefinition.BaseFloorColor or zoneDefinition.AccentColor or Color3.fromRGB(235, 35, 32)
	floor.Transparency = 0
	floor.Size = zoneDefinition.FloorSize or Vector3.new(307, 0.22, 314)
	floor.CFrame = zoneDefinition.SpawnAreaCFrame * CFrame.new(0, -1.84, 0)
	floor:SetAttribute("ZoneId", zoneDefinition.ZoneId)
	floor:SetAttribute("ColorType", zoneDefinition.ColorType)
	floor:SetAttribute("GroundPaintIgnore", true)
	floor:SetAttribute("RuntimeFallbackSectorFloor", true)
	return floor
end

local function getOrCreateZone(zoneDefinition)
	local zonesRoot = Workspace:FindFirstChild("Zones")
	if not zonesRoot then
		warnMissing("ZonesRoot", "[BreakableSpawner] Missing Workspace.Zones, creating fallback Zones folder.")
		zonesRoot = Instance.new("Folder")
		zonesRoot.Name = "Zones"
		zonesRoot.Parent = Workspace
	end

	local folderName = zoneDefinition.FolderName or zoneDefinition.ZoneId
	local zoneFolder = zonesRoot:FindFirstChild(folderName)
	if not zoneFolder or not zoneFolder:IsA("Folder") then
		warnMissing(
			"Zone:" .. tostring(folderName),
			("[BreakableSpawner] Missing Workspace.Zones.%s, creating fallback zone folder."):format(
				tostring(folderName)
			)
		)
		if zoneFolder then
			zoneFolder:Destroy()
		end
		zoneFolder = Instance.new("Folder")
		zoneFolder.Name = folderName
		zoneFolder.Parent = zonesRoot
	end

	ensureFallbackFloor(zoneFolder, zoneDefinition)

	local spawnArea = zoneFolder:FindFirstChild(zoneDefinition.SpawnAreaName)
	local createdSpawnArea = false
	if not spawnArea or not spawnArea:IsA("BasePart") then
		warnMissing(
			"SpawnArea:" .. tostring(folderName),
			("[BreakableSpawner] Missing %s.%s, creating fallback BreakableSpawnArea."):format(
				zoneFolder:GetFullName(),
				tostring(zoneDefinition.SpawnAreaName)
			)
		)
		if spawnArea then
			spawnArea:Destroy()
		end
		spawnArea = Instance.new("Part")
		spawnArea.Name = zoneDefinition.SpawnAreaName
		spawnArea.Parent = zoneFolder
		spawnArea:SetAttribute("RuntimeFallbackBreakableSpawnArea", true)
		createdSpawnArea = true
	end
	if createdSpawnArea or spawnArea:GetAttribute("RuntimeFallbackBreakableSpawnArea") == true then
		spawnArea.Anchored = true
		spawnArea.CanCollide = false
		spawnArea.CanTouch = false
		spawnArea.CanQuery = false
		spawnArea.Transparency = 1
		spawnArea.Size = zoneDefinition.SpawnAreaSize or Vector3.new(180, 4, 180)
		spawnArea.CFrame = zoneDefinition.SpawnAreaCFrame
		spawnArea.Color = zoneDefinition.AccentColor or Color3.fromRGB(235, 35, 32)
	end

	local breakables = ensureFolder(zoneFolder, zoneDefinition.BreakablesFolderName)

	zoneFolder:SetAttribute("ZoneId", zoneDefinition.ZoneId)
	zoneFolder:SetAttribute("WorldZoneId", zoneDefinition.WorldZoneId)
	zoneFolder:SetAttribute("LocationId", zoneDefinition.LocationId)
	zoneFolder:SetAttribute("ColorType", zoneDefinition.ColorType)
	spawnArea:SetAttribute("ZoneId", zoneDefinition.WorldZoneId or zoneDefinition.ZoneId)
	spawnArea:SetAttribute("ColorType", zoneDefinition.ColorType)

	if not initializedZones[zoneDefinition.ZoneId] then
		initializedZones[zoneDefinition.ZoneId] = true
		print(("[BreakableSpawner] %s initialized."):format(tostring(zoneDefinition.ZoneId)))
	end
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
		local origin = getRandomPointInArea(area)
		local result = raycastGround(origin, ignore)
		if result and result.Instance and hasSpacing(folder, result.Position, spacing) then
			local spawnHeight = tonumber(definition.SpawnHeight) or 1.2
			return CFrame.new(result.Position + Vector3.new(0, spawnHeight, 0))
				* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		end
	end

	local key = tostring(folder:GetFullName()) .. ":" .. tostring(definition.AssetName)
	if not spawnFailWarnings[key] then
		spawnFailWarnings[key] = true
		warn(
			"[BreakableSpawner] Raycast/spacing failed for "
				.. tostring(definition.AssetName)
				.. "; using fallback ground position."
		)
	end
	local half = area.Size * 0.5
	local localX = rng:NextNumber(-half.X, half.X)
	local localZ = rng:NextNumber(-half.Z, half.Z)
	local world = area.CFrame:PointToWorldSpace(Vector3.new(localX, -half.Y + 2, localZ))
	local spawnHeight = tonumber(definition.SpawnHeight) or 1.2
	return CFrame.new(world + Vector3.new(0, spawnHeight, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
end

local function spawnType(zoneDefinition, area, folder, typeId)
	local definition = BreakableDefinitions.Get(typeId)
	if not definition then
		return nil
	end
	local cframe = findSpawnCFrame(area, folder, definition)
	if not cframe then
		warn("[BreakableSpawner] No spawn CFrame for " .. tostring(typeId) .. " in " .. tostring(zoneDefinition.ZoneId))
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
	if model and (not config.Debug or config.Debug.PrintSpawns ~= false) then
		print(
			("[BreakableSpawner] Spawned %s at %s."):format(
				tostring(typeId),
				tostring(model.PrimaryPart and model.PrimaryPart.Position or cframe.Position)
			)
		)
	end
	return model
end

local function spawnInitialMix(zoneDefinition, area, folder)
	if zoneDefinition.ZoneId ~= "RedSector" or getActiveCount(folder) > 0 then
		return
	end

	local maxActive = math.min(tonumber(zoneDefinition.MaxActiveBreakables) or 35, 35)
	local spawned = 0
	local attempts = 0
	for _, entry in ipairs(INITIAL_RED_MIX) do
		for _ = 1, entry.Count do
			if spawned >= maxActive then
				break
			end
			attempts += 1
			if spawnType(zoneDefinition, area, folder, entry.TypeId) then
				spawned += 1
			end
		end
	end

	while spawned < maxActive do
		attempts += 1
		local typeId = BreakableDefinitions.GetWeightedRandom(rng)
		if spawnType(zoneDefinition, area, folder, typeId) then
			spawned += 1
		else
			break
		end
	end

	print(
		("[BreakableSpawner] RedSector initial fill: %d/%d active after %d attempts."):format(
			spawned,
			maxActive,
			attempts
		)
	)
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
	local zoneDefinition = ZoneDefinitions.Get(zoneId)
	local _, area, folder = getOrCreateZone(zoneDefinition)
	if area and folder then
		spawnInitialMix(zoneDefinition, area, folder)
	end
end

task.spawn(function()
	task.wait(1)
	while true do
		for _, zoneId in ipairs(ZoneDefinitions.Order) do
			local zoneDefinition = ZoneDefinitions.Get(zoneId)
			local _, area, folder = getOrCreateZone(zoneDefinition)
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
			if zoneId == "RedSector" and os.clock() - (lastActiveLogAt[zoneId] or 0) >= 5 then
				lastActiveLogAt[zoneId] = os.clock()
				print(("[BreakableSpawner] Active breakables: %d/%d."):format(getActiveCount(folder), maxActive))
			end
		end
		task.wait(tonumber(config.Spawner and config.Spawner.TickInterval) or 1)
	end
end)

print("BreakableSpawnerService ready")
