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
local DARK_FLOOR_MATERIAL = Enum.Material.Ground

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end
	return folder
end

local function ensureZone(zoneDefinition)
	local zonesRoot = ensureFolder(Workspace, "Zones")
	local zoneFolder = ensureFolder(zonesRoot, zoneDefinition.FolderName or zoneDefinition.ZoneId)
	zoneFolder:SetAttribute("ZoneId", zoneDefinition.ZoneId)
	zoneFolder:SetAttribute("WorldZoneId", zoneDefinition.WorldZoneId)
	zoneFolder:SetAttribute("LocationId", zoneDefinition.LocationId)
	zoneFolder:SetAttribute("ColorType", zoneDefinition.ColorType)
	zoneFolder:SetAttribute("GeneratedFromSectorTemplate", true)

	local floorFolder = ensureFolder(zoneFolder, "Floor")
	local gameplayFolder = ensureFolder(zoneFolder, "Gameplay")
	ensureFolder(zoneFolder, "Decor")
	ensureFolder(zoneFolder, "Gates")
	ensureFolder(zoneFolder, "Boundaries")

	local baseFloor = floorFolder:FindFirstChild("BaseFloor")
	if not baseFloor or not baseFloor:IsA("BasePart") then
		if baseFloor then
			baseFloor:Destroy()
		end
		baseFloor = Instance.new("Part")
		baseFloor.Name = "BaseFloor"
		baseFloor.Anchored = true
		baseFloor.CanCollide = true
		baseFloor.CanTouch = false
		baseFloor.CanQuery = true
		baseFloor.Material = DARK_FLOOR_MATERIAL
		baseFloor.Color = zoneDefinition.BaseFloorColor or Color3.fromRGB(8, 8, 10)
		baseFloor.Size = zoneDefinition.FloorSize or Vector3.new(307, 1, 314)
		baseFloor.CFrame = zoneDefinition.SpawnAreaCFrame * CFrame.new(0, -4.5, 0)
		baseFloor:SetAttribute("GeneratedSectorFloor", true)
		baseFloor:SetAttribute("GroundPaintIgnore", true)
		baseFloor:SetAttribute("ZoneId", zoneDefinition.WorldZoneId or zoneDefinition.ZoneId)
		baseFloor:SetAttribute("ColorType", zoneDefinition.ColorType)
		baseFloor.Parent = floorFolder
	end

	local spawnPart = gameplayFolder:FindFirstChild(zoneDefinition.SpawnPartName or (zoneDefinition.ZoneId .. "Spawn"))
	if not spawnPart or not spawnPart:IsA("BasePart") then
		if spawnPart then
			spawnPart:Destroy()
		end
		spawnPart = Instance.new("Part")
		spawnPart.Name = zoneDefinition.SpawnPartName or (zoneDefinition.ZoneId .. "Spawn")
		spawnPart.Anchored = true
		spawnPart.CanCollide = false
		spawnPart.CanTouch = false
		spawnPart.CanQuery = false
		spawnPart.Transparency = 1
		spawnPart.Size = Vector3.new(6, 1, 6)
		spawnPart.CFrame = zoneDefinition.SpawnAreaCFrame
			* CFrame.new(0, -3.2, -((zoneDefinition.SpawnAreaSize.Z * 0.5) - 26))
		spawnPart:SetAttribute("ZoneId", zoneDefinition.WorldZoneId or zoneDefinition.ZoneId)
		spawnPart:SetAttribute("ColorType", zoneDefinition.ColorType)
		spawnPart.Parent = gameplayFolder
	end

	local spawnArea = zoneFolder:FindFirstChild(zoneDefinition.SpawnAreaName, true)
	if not spawnArea or not spawnArea:IsA("BasePart") then
		if spawnArea then
			spawnArea:Destroy()
		end
		spawnArea = Instance.new("Part")
		spawnArea.Name = zoneDefinition.SpawnAreaName
		spawnArea.Anchored = true
		spawnArea.CanCollide = false
		spawnArea.CanTouch = false
		spawnArea.CanQuery = false
		spawnArea.Transparency = 1
		spawnArea.Size = zoneDefinition.SpawnAreaSize
		spawnArea.CFrame = zoneDefinition.SpawnAreaCFrame
		spawnArea.Color = zoneDefinition.SpawnAreaColor
		spawnArea:SetAttribute("GeneratedBreakableSpawnArea", true)
		spawnArea:SetAttribute("ZoneId", zoneDefinition.WorldZoneId or zoneDefinition.ZoneId)
		spawnArea:SetAttribute("ColorType", zoneDefinition.ColorType)
		spawnArea.Parent = gameplayFolder
	end
	local breakables = ensureFolder(zoneFolder, zoneDefinition.BreakablesFolderName)
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
	ensureZone(ZoneDefinitions.Get(zoneId))
end

task.spawn(function()
	task.wait(1)
	while true do
		for _, zoneId in ipairs(ZoneDefinitions.Order) do
			local zoneDefinition = ZoneDefinitions.Get(zoneId)
			local _, area, folder = ensureZone(zoneDefinition)
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
