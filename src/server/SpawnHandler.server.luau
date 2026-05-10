-- Keeps the first join spawn on the main/Red spawn, even if later-sector spawns exist in the baked map.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local MAP_NAME = "ColorSimulatorMap"
local FIRST_SPAWN_DELAY = 0.35
local firstSpawnHandled = {}

local function getSpawnColor(part)
	if not part or not part:IsA("BasePart") then
		return nil
	end
	local color = part:GetAttribute("AreaSpawnColor")
		or part:GetAttribute("SpawnColor")
		or part:GetAttribute("TeleportColor")
		or part:GetAttribute("ColorType")
	return typeof(color) == "string" and color or nil
end

local function isOrangeSpawn(part)
	local color = getSpawnColor(part)
	if color == "Orange" then
		return true
	end
	local name = string.lower(part.Name or "")
	local parentName = part.Parent and string.lower(part.Parent.Name or "") or ""
	return string.find(name, "orange", 1, true) ~= nil
		or string.find(parentName, "orange", 1, true) ~= nil
end

local function scoreSpawn(part)
	if not part or not part:IsA("BasePart") or isOrangeSpawn(part) then
		return nil
	end

	local score = 0
	local color = getSpawnColor(part)
	local name = string.lower(part.Name or "")
	local parentName = part.Parent and string.lower(part.Parent.Name or "") or ""

	if part:IsA("SpawnLocation") then
		score += 60
	end
	if part:GetAttribute("LobbySpawn") == true or color == "Lobby" then
		score += 120
	end
	if color == "Red" then
		score += 90
	end
	if name == "spawnlocation" then
		score += 45
	end
	if string.find(name, "lobby", 1, true) or string.find(parentName, "lobby", 1, true) then
		score += 40
	end
	if string.find(name, "redzonearrivalspawn", 1, true) then
		score += 35
	end
	if part:GetAttribute("AreaSpawn") == true or part:GetAttribute("WorldSpawn") == true or part:GetAttribute("SectorSpawn") == true then
		score += 20
	end

	return score
end

local function findFirstJoinSpawn()
	local map = Workspace:FindFirstChild(MAP_NAME)
	local roots = {}
	if map then
		table.insert(roots, map)
	end
	table.insert(roots, Workspace)

	local bestPart
	local bestScore = -math.huge
	for _, root in ipairs(roots) do
		for _, obj in ipairs(root:GetDescendants()) do
			if obj:IsA("BasePart") then
				local score = scoreSpawn(obj)
				if score and score > bestScore then
					bestScore = score
					bestPart = obj
				end
			end
		end
		if bestPart then
			return bestPart
		end
	end

	return nil
end

local function setSessionWorldToRed(player)
	player:SetAttribute("ActiveWorldColor", "Red")
	local storage = player:FindFirstChild("ColorStorage")
	local currentWorld = storage and storage:FindFirstChild("CurrentWorld")
	if currentWorld and currentWorld:IsA("StringValue") then
		currentWorld.Value = "Red"
	end
end

local function placeAtFirstJoinSpawn(player, character)
	task.wait(FIRST_SPAWN_DELAY)
	if not player.Parent or not character.Parent then
		return
	end

	setSessionWorldToRed(player)

	local root = character:FindFirstChild("HumanoidRootPart")
	local spawnPart = findFirstJoinSpawn()
	if root and spawnPart then
		character:PivotTo(spawnPart.CFrame + Vector3.new(0, 5, 0))
	end
end

Players.PlayerAdded:Connect(function(player)
	firstSpawnHandled[player] = false
	player.CharacterAdded:Connect(function(character)
		if firstSpawnHandled[player] then
			return
		end
		firstSpawnHandled[player] = true
		task.spawn(placeAtFirstJoinSpawn, player, character)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	firstSpawnHandled[player] = nil
end)
