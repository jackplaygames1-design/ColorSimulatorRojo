-- Session-only contaminated ground overlays for active brushing.
-- UI stays editable in StarterGui; this script only creates world gameplay visuals.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ColorData = require(ReplicatedStorage:WaitForChild("ColorData"))
local GameBalance = require(ReplicatedStorage:WaitForChild("GameBalance"))

local config = GameBalance.Contamination or {}
if config.Enabled == false then
	return
end

local TILE_SIZE = tonumber(config.TileSize) or 34
local MAX_CELLS_PER_ZONE = tonumber(config.MaxCellsPerZone) or 96
local HEIGHT_OFFSET = tonumber(config.HeightOffset) or 0.055
local BASE_TRANSPARENCY = tonumber(config.BaseTransparency) or 0.24
local BASE_REWARD = tonumber(config.BaseReward) or 4
local REWARD_MULTIPLIER = tonumber(config.RewardMultiplier) or 0.35
local SPAWN_EXCLUSION_PADDING = tonumber(config.SpawnExclusionPadding) or 48

local generatedFolder = Workspace:FindFirstChild("GroundContamination")
if not generatedFolder then
	generatedFolder = Instance.new("Folder")
	generatedFolder.Name = "GroundContamination"
	generatedFolder.Parent = Workspace
end

for _, child in ipairs(generatedFolder:GetChildren()) do
	if child:GetAttribute("GeneratedGroundContamination") == true then
		child:Destroy()
	end
end

local safeNameFragments = {}
for _, fragment in ipairs(config.SafeNameFragments or {}) do
	table.insert(safeNameFragments, string.lower(tostring(fragment)))
end

local generatedByZone = {}
local spawnBlockers = {}

local function hasNameFragment(instance, fragments)
	local current = instance
	while current and current ~= Workspace do
		local name = string.lower(current.Name)
		for _, fragment in ipairs(fragments) do
			if name:find(fragment, 1, true) then
				return true
			end
		end
		current = current.Parent
	end
	return false
end

local function isSpawnBlocker(part)
	if not part:IsA("BasePart") then
		return false
	end
	if part:IsA("SpawnLocation") then
		return true
	end
	if part:GetAttribute("NoColorSpawn") == true or part:GetAttribute("NoContamination") == true then
		return true
	end
	local name = string.lower(part.Name)
	return name:find("spawn", 1, true) ~= nil
		or name:find("safe", 1, true) ~= nil
		or name:find("teleport", 1, true) ~= nil
		or name:find("portal", 1, true) ~= nil
end

local function refreshSpawnBlockers()
	table.clear(spawnBlockers)
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("BasePart") and isSpawnBlocker(obj) then
			table.insert(spawnBlockers, obj)
		end
	end
end

local function isPointNearBlocker(worldPosition)
	for _, blocker in ipairs(spawnBlockers) do
		if blocker.Parent then
			local localPoint = blocker.CFrame:PointToObjectSpace(worldPosition)
			local half = blocker.Size * 0.5 + Vector3.new(SPAWN_EXCLUSION_PADDING, 24, SPAWN_EXCLUSION_PADDING)
			if math.abs(localPoint.X) <= half.X and math.abs(localPoint.Z) <= half.Z then
				return true
			end
		end
	end
	return false
end

local function isZoneAllowed(zone, colorType)
	if zone:GetAttribute("ContaminationAllowed") == true then
		return true
	end
	if zone:GetAttribute("ContaminationAllowed") == false or zone:GetAttribute("NoContamination") == true then
		return false
	end
	if zone:GetAttribute("ColorZone") ~= true then
		return false
	end
	if isSpawnBlocker(zone) then
		return false
	end
	if hasNameFragment(zone, safeNameFragments) then
		return false
	end
	if not colorType or not (config.AllowColors or {})[colorType] then
		return false
	end

	local worldIndex = ColorData.getWorldIndex and ColorData.getWorldIndex(colorType)
	local maxPlayableIndex = tonumber(GameBalance.Progression and GameBalance.Progression.MaxPlayableSectorIndex)
	if worldIndex and maxPlayableIndex and worldIndex > maxPlayableIndex then
		return false
	end
	return true
end

local function getColor(colorType)
	local info = ColorData.Colors[colorType]
	if info and info.color then
		return info.color
	end
	return Color3.fromRGB(255, 70, 70)
end

local function getRegenDelay(colorType)
	local byColor = config.RegenDelayByColor or {}
	return tonumber(byColor[colorType]) or tonumber(config.DefaultRegenDelay) or 8
end

local function makeCell(zone, colorType, localX, localZ, cellSizeX, cellSizeZ, index)
	local topY = zone.Size.Y * 0.5 + HEIGHT_OFFSET
	local cframe = zone.CFrame * CFrame.new(localX, topY, localZ)
	local worldPosition = cframe.Position
	if isPointNearBlocker(worldPosition) then
		return nil
	end

	local cell = Instance.new("Part")
	cell.Name = string.format("%s_Contamination_%03d", tostring(colorType), index)
	cell.Anchored = true
	cell.CanCollide = false
	cell.CanTouch = false
	cell.CanQuery = true
	cell.CastShadow = false
	cell.Material = Enum.Material.Neon
	cell.Color = getColor(colorType):Lerp(Color3.new(1, 1, 1), 0.08)
	cell.Transparency = BASE_TRANSPARENCY
	cell.Size = Vector3.new(math.max(cellSizeX, 4), 0.08, math.max(cellSizeZ, 4))
	cell.CFrame = cframe

	cell:SetAttribute("GeneratedGroundContamination", true)
	cell:SetAttribute("GroundContamination", true)
	cell:SetAttribute("ContaminationCell", true)
	cell:SetAttribute("BreakableType", "GroundContamination")
	cell:SetAttribute("ColorType", colorType)
	cell:SetAttribute("SourceZoneName", zone.Name)
	cell:SetAttribute("OriginalSize", cell.Size)
	cell:SetAttribute("CollectorBaseTransparency", BASE_TRANSPARENCY)
	cell:SetAttribute("ContaminationRegenDelay", getRegenDelay(colorType))
	cell:SetAttribute("BaseColorReward", BASE_REWARD)
	cell:SetAttribute("RewardMultiplier", REWARD_MULTIPLIER)
	cell:SetAttribute("NoTouchCollect", true)
	cell.Parent = generatedFolder
	return cell
end

local function populateZone(zone)
	if generatedByZone[zone] or not zone:IsA("BasePart") then
		return
	end

	local colorType = zone:GetAttribute("ColorType")
	if not isZoneAllowed(zone, colorType) then
		return
	end

	if zone.Size.X < 10 or zone.Size.Z < 10 then
		return
	end

	refreshSpawnBlockers()
	generatedByZone[zone] = true

	local xCount = math.max(1, math.ceil(zone.Size.X / TILE_SIZE))
	local zCount = math.max(1, math.ceil(zone.Size.Z / TILE_SIZE))
	while xCount * zCount > MAX_CELLS_PER_ZONE do
		if xCount >= zCount and xCount > 1 then
			xCount -= 1
		elseif zCount > 1 then
			zCount -= 1
		else
			break
		end
	end

	local cellSizeX = zone.Size.X / xCount
	local cellSizeZ = zone.Size.Z / zCount
	local created = 0

	for x = 1, xCount do
		local localX = -zone.Size.X * 0.5 + cellSizeX * (x - 0.5)
		for z = 1, zCount do
			local localZ = -zone.Size.Z * 0.5 + cellSizeZ * (z - 0.5)
			if makeCell(zone, colorType, localX, localZ, cellSizeX, cellSizeZ, created + 1) then
				created += 1
			end
		end
	end

	if created > 0 then
		print(
			string.format(
				"GroundContamination: generated %d %s cells for %s.",
				created,
				tostring(colorType),
				zone:GetFullName()
			)
		)
	end
end

task.defer(function()
	task.wait(1.5)
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("BasePart") then
			populateZone(obj)
		end
	end
end)

Workspace.DescendantAdded:Connect(function(obj)
	if obj:IsA("BasePart") then
		if isSpawnBlocker(obj) then
			table.insert(spawnBlockers, obj)
		end
		task.defer(populateZone, obj)
	end
end)
