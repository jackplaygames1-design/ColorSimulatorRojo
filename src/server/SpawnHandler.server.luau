-- Server-authoritative sector respawns. Roblox SpawnLocations are kept to the
-- Start/Red area only; all sector respawns are manual and validated.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ColorData = require(ReplicatedStorage:WaitForChild("ColorData"))
local GameBalance = require(ReplicatedStorage:WaitForChild("GameBalance"))

local Events = ReplicatedStorage:FindFirstChild("Events")
local dataDirtyEvent = Events and Events:FindFirstChild("PlayerDataDirty")

local MAP_NAME = "ColorSimulatorMap"
local RESPAWN_PLACE_DELAY = 0.35
local OUT_OF_BOUNDS_Y = -100
local OUT_OF_BOUNDS_CHECK_SECONDS = 0.35
local START_SECTOR_COLOR = (GameBalance.Progression and GameBalance.Progression.StartSectorColor) or "Red"
local MAX_PLAYABLE_SECTOR_INDEX = tonumber(GameBalance.Progression and GameBalance.Progression.MaxPlayableSectorIndex)
	or math.huge

local spawnTokens = {}

local function isSectorPlayable(colorType)
	local index = ColorData.getWorldIndex(colorType)
	return index ~= nil and index <= MAX_PLAYABLE_SECTOR_INDEX
end

local function compactName(value)
	return string.lower(tostring(value or "")):gsub("[%s_%-%p]", "")
end

local function isStartSectorName(name)
	local compact = compactName(name)
	return compact == "originsector"
		or compact == "origin"
		or compact == "startsector"
		or compact == "spawnworld"
		or compact == "redwastelands"
		or compact == "redwasteland"
		or compact == "redsector"
		or compact == "redzone"
end

local function getSpawnColor(part)
	if not part or not part:IsA("BasePart") then
		return nil
	end
	local color = part:GetAttribute("AreaSpawnColor")
		or part:GetAttribute("SpawnColor")
		or part:GetAttribute("TeleportColor")
		or part:GetAttribute("SectorColor")
		or part:GetAttribute("ColorType")
		or part:GetAttribute("AreaColor")
	return typeof(color) == "string" and color or nil
end

local function getObjectColor(instance)
	if not instance then
		return nil
	end
	local attrColor = instance:GetAttribute("AreaSpawnColor")
		or instance:GetAttribute("SpawnColor")
		or instance:GetAttribute("TeleportColor")
		or instance:GetAttribute("SectorColor")
		or instance:GetAttribute("ColorType")
		or instance:GetAttribute("AreaColor")
	if typeof(attrColor) == "string" then
		return attrColor
	end

	local loweredName = string.lower(instance.Name or "")
	if isStartSectorName(loweredName) then
		return START_SECTOR_COLOR
	end
	for _, world in ipairs(ColorData.Worlds or {}) do
		local color = world.primaryColor
		if typeof(color) == "string" and string.find(loweredName, string.lower(color), 1, true) then
			return color
		end
	end
	return nil
end

local function getAncestorColor(instance)
	local current = instance
	while current and current ~= Workspace do
		local colorType = getObjectColor(current)
		if colorType then
			return colorType
		end
		current = current.Parent
	end
	return nil
end

local function isNamedSpawnDestination(part)
	if not part or not part:IsA("BasePart") then
		return false
	end

	local loweredName = string.lower(part.Name or "")
	return part:IsA("SpawnLocation")
		or loweredName == "spawnpoint"
		or loweredName == "spawnlocation"
		or loweredName == "sectorspawn"
		or loweredName == "arrivalspawn"
		or loweredName == "travelspawn"
		or part:GetAttribute("AreaSpawn") == true
		or part:GetAttribute("WorldSpawn") == true
		or part:GetAttribute("SectorSpawn") == true
end

local function isStartSpawn(part)
	if not part or not part:IsA("SpawnLocation") then
		return false
	end

	local color = getSpawnColor(part) or getAncestorColor(part)
	local loweredName = string.lower(part.Name or "")
	local parentName = part.Parent and string.lower(part.Parent.Name or "") or ""
	return color == START_SECTOR_COLOR
		or color == "Lobby"
		or part:GetAttribute("LobbySpawn") == true
		or getAncestorColor(part) == START_SECTOR_COLOR
		or string.find(loweredName, "red", 1, true) ~= nil
		or string.find(loweredName, "origin", 1, true) ~= nil
		or string.find(parentName, "red", 1, true) ~= nil
		or string.find(parentName, "origin", 1, true) ~= nil
		or string.find(parentName, "colorsimspawn", 1, true) ~= nil
end

local function configureSpawnLocation(spawn)
	if not spawn:IsA("SpawnLocation") then
		return
	end

	local allowRobloxSpawn = isStartSpawn(spawn)
	spawn.Enabled = allowRobloxSpawn
	spawn.Neutral = allowRobloxSpawn
	if not allowRobloxSpawn then
		spawn.AllowTeamChangeOnTouch = false
	end
end

local function configureSpawnLocations()
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("SpawnLocation") then
			configureSpawnLocation(obj)
		end
	end
end

local function scoreSpawn(part, colorType)
	local score = 0
	local loweredName = string.lower(part.Name or "")
	if loweredName == "spawnpoint" then
		score += 30000
	end
	if part:IsA("SpawnLocation") then
		score += 20000
	end
	if loweredName == "spawnlocation" then
		score += 12000
	end
	if
		part:GetAttribute("AreaSpawn") == true
		or part:GetAttribute("WorldSpawn") == true
		or part:GetAttribute("SectorSpawn") == true
	then
		score += 9000
	end
	if loweredName == "sectorspawn" or loweredName == "arrivalspawn" or loweredName == "travelspawn" then
		score += 6000
	end
	if colorType == START_SECTOR_COLOR and isStartSpawn(part) then
		score += 50000
	end
	local current = part.Parent
	while current and current ~= Workspace do
		if isStartSectorName(current.Name) then
			score += 10000
			break
		end
		current = current.Parent
	end
	score -= math.abs(part.Position.Y) * 0.001
	return score
end

local function isSpawnForColor(part, colorType, rootColor)
	if not isNamedSpawnDestination(part) then
		return false
	end
	local partColor = getObjectColor(part) or getAncestorColor(part) or rootColor
	if colorType == START_SECTOR_COLOR and partColor == nil then
		return isStartSpawn(part)
	end
	return partColor == colorType
end

local function findBestSpawn(root, colorType)
	if not root then
		return nil
	end

	local rootColor = getObjectColor(root)
	if root:IsA("BasePart") and isSpawnForColor(root, colorType, rootColor) then
		return root
	end

	local bestPart = nil
	local bestScore = -math.huge
	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("BasePart") and isSpawnForColor(obj, colorType, rootColor) then
			local score = scoreSpawn(obj, colorType)
			if score > bestScore then
				bestPart = obj
				bestScore = score
			end
		end
	end
	return bestPart
end

local function isPlayableFloor(part, colorType)
	if not part or not part:IsA("BasePart") then
		return false
	end
	local partColor = getObjectColor(part) or getAncestorColor(part)
	if partColor ~= colorType then
		return false
	end
	if part:GetAttribute("PlayableSectorFloor") == true or part:GetAttribute("ColorZone") == true then
		return true
	end
	local size = part.Size
	return size.X >= 35 and size.Z >= 35 and size.Y <= math.max(8, math.min(size.X, size.Z) * 0.28)
end

local function findBestFloor(root, colorType)
	if not root then
		return nil
	end
	if root:IsA("BasePart") and isPlayableFloor(root, colorType) then
		return root
	end

	local bestPart = nil
	local bestScore = -math.huge
	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("BasePart") and isPlayableFloor(obj, colorType) then
			local score = obj.Size.X * obj.Size.Z
			if obj:GetAttribute("PlayableSectorFloor") == true then
				score += 1000000
			end
			if obj:GetAttribute("ColorZone") == true then
				score += 500000
			end
			if score > bestScore then
				bestPart = obj
				bestScore = score
			end
		end
	end
	return bestPart
end

local function findStartSectorDestination()
	local map = Workspace:FindFirstChild(MAP_NAME)
	local preferredStartRoots = {}
	if map then
		for _, obj in ipairs(map:GetDescendants()) do
			if (obj:IsA("Folder") or obj:IsA("Model")) and isStartSectorName(obj.Name) then
				table.insert(preferredStartRoots, obj)
			end
		end
	end

	table.sort(preferredStartRoots, function(a, b)
		local aName = compactName(a.Name)
		local bName = compactName(b.Name)
		if aName == "originsector" and bName ~= "originsector" then
			return true
		end
		if bName == "originsector" and aName ~= "originsector" then
			return false
		end
		return a:GetFullName() < b:GetFullName()
	end)

	for _, root in ipairs(preferredStartRoots) do
		local spawn = findBestSpawn(root, START_SECTOR_COLOR)
		if spawn then
			return spawn
		end
	end

	local spawnFolder = map and map:FindFirstChild("ColorSimSpawn")
	local spawnLocation = spawnFolder and spawnFolder:FindFirstChild("SpawnLocation")
	if spawnLocation and spawnLocation:IsA("BasePart") then
		return spawnLocation
	end

	local bestStartSpawn = findBestSpawn(map or Workspace, START_SECTOR_COLOR)
	if bestStartSpawn then
		return bestStartSpawn
	end

	local redFloor = Workspace:FindFirstChild("RedFloor1", true)
	if redFloor and redFloor:IsA("BasePart") then
		return redFloor
	end

	return findBestFloor(map or Workspace, START_SECTOR_COLOR)
end

local function findSectorDestination(colorType)
	if colorType == START_SECTOR_COLOR then
		return findStartSectorDestination()
	end

	local map = Workspace:FindFirstChild(MAP_NAME)
	local distantSectors = map and map:FindFirstChild("DistantSectors")
	local roots = {}
	if distantSectors then
		table.insert(roots, distantSectors)
	end
	if map then
		table.insert(roots, map)
	end
	table.insert(roots, Workspace)

	for _, root in ipairs(roots) do
		local spawn = findBestSpawn(root, colorType)
		if spawn then
			return spawn
		end
	end
	for _, root in ipairs(roots) do
		local floor = findBestFloor(root, colorType)
		if floor then
			return floor
		end
	end
	return nil
end

local function getLandingCFrame(part)
	if not part or not part:IsA("BasePart") then
		return nil
	end

	local lookVector = part.CFrame.LookVector
	local flatLook = Vector3.new(lookVector.X, 0, lookVector.Z)
	if flatLook.Magnitude < 0.05 then
		flatLook = Vector3.new(0, 0, -1)
	end
	local yOffset = isNamedSpawnDestination(part) and (part.Size.Y * 0.5 + 5) or 8
	local position = part.CFrame:PointToWorldSpace(Vector3.new(0, yOffset, 0))
	return CFrame.lookAt(position, position + flatLook.Unit)
end

local function markDataDirty(player, reason)
	if dataDirtyEvent and dataDirtyEvent:IsA("BindableEvent") then
		dataDirtyEvent:Fire(player, reason)
	end
end

local function waitForStorage(player)
	local storage = player:FindFirstChild("ColorStorage") or player:WaitForChild("ColorStorage", 10)
	local unlocked = storage and storage:FindFirstChild("UnlockedColors")
	local currentWorld = storage and storage:FindFirstChild("CurrentWorld")
	return storage, unlocked, currentWorld
end

local function setCurrentWorld(player, colorType, reason)
	player:SetAttribute("ActiveWorldColor", colorType)
	local storage = player:FindFirstChild("ColorStorage")
	local currentWorld = storage and storage:FindFirstChild("CurrentWorld")
	if currentWorld and currentWorld:IsA("StringValue") and currentWorld.Value ~= colorType then
		currentWorld.Value = colorType
		markDataDirty(player, reason or "current-world")
	end
end

local function waitForCharacterParts(character, timeoutSeconds)
	local deadline = os.clock() + (timeoutSeconds or 0)
	repeat
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and root then
			return humanoid, root
		end
		task.wait(0.05)
	until os.clock() >= deadline
	return nil, nil
end

local function getValidatedSpawnColor(player)
	local _, unlockedValue, currentWorld = waitForStorage(player)
	local requestedColor = currentWorld and currentWorld.Value
		or player:GetAttribute("ActiveWorldColor")
		or START_SECTOR_COLOR
	local world = ColorData.getWorldByColor(requestedColor)
	local unlockedCsv = unlockedValue and unlockedValue.Value or START_SECTOR_COLOR

	if not world or not isSectorPlayable(world.primaryColor) then
		warn(
			"[SpawnHandler] Invalid saved sector for "
				.. player.Name
				.. ": "
				.. tostring(requestedColor)
				.. "; using "
				.. START_SECTOR_COLOR
		)
		setCurrentWorld(player, START_SECTOR_COLOR, "invalid-respawn-sector")
		return START_SECTOR_COLOR
	end

	if not ColorData.isColorUnlocked(unlockedCsv, world.primaryColor) then
		warn(
			"[SpawnHandler] "
				.. player.Name
				.. " tried to spawn in locked sector "
				.. tostring(world.primaryColor)
				.. "; using "
				.. START_SECTOR_COLOR
		)
		setCurrentWorld(player, START_SECTOR_COLOR, "locked-respawn-sector")
		return START_SECTOR_COLOR
	end

	local destination = findSectorDestination(world.primaryColor)
	if not destination then
		warn(
			"[SpawnHandler] Missing spawn part for sector "
				.. tostring(world.primaryColor)
				.. " for "
				.. player.Name
				.. "; using "
				.. START_SECTOR_COLOR
		)
		setCurrentWorld(player, START_SECTOR_COLOR, "missing-respawn-sector-spawn")
		return START_SECTOR_COLOR
	end

	return world.primaryColor
end

local function placeAtValidatedSpawn(player, character, reason)
	local colorType = getValidatedSpawnColor(player)
	local destination = findSectorDestination(colorType)
	if not destination and colorType ~= START_SECTOR_COLOR then
		warn(
			"[SpawnHandler] Missing validated spawn for "
				.. player.Name
				.. " in "
				.. tostring(colorType)
				.. "; falling back to "
				.. START_SECTOR_COLOR
		)
		colorType = START_SECTOR_COLOR
		setCurrentWorld(player, START_SECTOR_COLOR, "missing-respawn-sector-spawn")
		destination = findSectorDestination(START_SECTOR_COLOR)
	end
	if not destination then
		warn("[SpawnHandler] Missing Start/Red spawn; cannot place " .. player.Name)
		return false
	end

	local landingCFrame = getLandingCFrame(destination)
	if not landingCFrame then
		warn("[SpawnHandler] Could not compute spawn CFrame for " .. destination:GetFullName())
		return false
	end

	local humanoid, root = waitForCharacterParts(character, 5)
	if not character or not root then
		return false
	end

	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	character:PivotTo(landingCFrame)
	if humanoid then
		humanoid.PlatformStand = false
		humanoid.Sit = false
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
	setCurrentWorld(player, colorType, reason or "validated-respawn")
	return true
end

local function monitorOutOfBounds(player, character, token)
	while player.Parent and player.Character == character and spawnTokens[player] == token do
		local root = character:FindFirstChild("HumanoidRootPart")
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if player:GetAttribute("IsTeleporting") == true then
			task.wait(OUT_OF_BOUNDS_CHECK_SECONDS)
			continue
		end
		if root and humanoid and humanoid.Health > 0 and root.Position.Y < OUT_OF_BOUNDS_Y then
			warn("[SpawnHandler] " .. player.Name .. " fell out of bounds; returning to valid sector spawn.")
			placeAtValidatedSpawn(player, character, "out-of-bounds-return")
			task.wait(1)
		end
		task.wait(OUT_OF_BOUNDS_CHECK_SECONDS)
	end
end

local function onCharacterAdded(player, character)
	local token = (spawnTokens[player] or 0) + 1
	spawnTokens[player] = token

	task.delay(RESPAWN_PLACE_DELAY, function()
		if player.Parent and player.Character == character and spawnTokens[player] == token then
			placeAtValidatedSpawn(player, character, "validated-respawn")
		end
	end)

	task.spawn(monitorOutOfBounds, player, character, token)
end

configureSpawnLocations()
Workspace.DescendantAdded:Connect(function(obj)
	if obj:IsA("SpawnLocation") then
		task.defer(configureSpawnLocation, obj)
	end
end)

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
end)

for _, player in ipairs(Players:GetPlayers()) do
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.defer(onCharacterAdded, player, player.Character)
	end
end

Players.PlayerRemoving:Connect(function(player)
	spawnTokens[player] = nil
end)
