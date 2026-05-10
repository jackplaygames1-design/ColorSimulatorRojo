-- Server-owned lobby portal travel for baked/editable maps.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local MAP_NAME = "ColorSimulatorMap"
local COOLDOWN = 0.75
local cooldowns = {}

local function getRoot(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function getPlayerFromHit(hit)
	local character = hit and hit:FindFirstAncestorOfClass("Model")
	return character and Players:GetPlayerFromCharacter(character)
end

local function isPortalPart(part)
	return part:IsA("BasePart")
		and (part:GetAttribute("LobbyRedZonePortal") == true or part.Name == "RedZonePortal")
end

local function getRedZoneDestination()
	local map = Workspace:FindFirstChild(MAP_NAME)
	if not map then
		return nil
	end

	local named = map:FindFirstChild("RedZoneArrivalSpawn", true)
	if named and named:IsA("BasePart") then
		return named
	end

	for _, obj in ipairs(map:GetDescendants()) do
		if obj:IsA("BasePart") and obj:GetAttribute("LobbyPortalArrival") == true then
			return obj
		end
	end

	for _, obj in ipairs(map:GetDescendants()) do
		if obj:IsA("BasePart") then
			local spawnColor = obj:GetAttribute("AreaSpawnColor") or obj:GetAttribute("SpawnColor") or obj:GetAttribute("TeleportColor")
			if spawnColor == "Red" then
				return obj
			end
		end
	end

	return nil
end

local function useCooldown(player)
	local now = os.clock()
	if cooldowns[player] and now - cooldowns[player] < COOLDOWN then
		return false
	end
	cooldowns[player] = now
	return true
end

local function teleportToRedZone(player)
	if not useCooldown(player) then
		return
	end

	local root = getRoot(player)
	local destination = getRedZoneDestination()
	if not root or not destination then
		warn("LobbyPortalHandler: missing character root or RedZoneArrivalSpawn.")
		return
	end

	root.CFrame = destination.CFrame + Vector3.new(0, 5, 0)
	print(player.Name .. " entered Red Zone from Lobby")
end

local function hookPrompt(prompt)
	if not prompt:IsA("ProximityPrompt") then
		return
	end

	local parent = prompt.Parent
	if not parent or not isPortalPart(parent) then
		return
	end
	if prompt:GetAttribute("LobbyPortalHooked") then
		return
	end

	prompt:SetAttribute("LobbyPortalHooked", true)
	prompt.Triggered:Connect(teleportToRedZone)
end

local function hookPortal(part)
	if not isPortalPart(part) then
		return
	end
	if part:GetAttribute("LobbyPortalTouchedHooked") then
		return
	end

	part:SetAttribute("LobbyPortalTouchedHooked", true)
	part.Touched:Connect(function(hit)
		local player = getPlayerFromHit(hit)
		if player then
			teleportToRedZone(player)
		end
	end)

	for _, child in ipairs(part:GetChildren()) do
		hookPrompt(child)
	end
end

for _, obj in ipairs(Workspace:GetDescendants()) do
	if obj:IsA("BasePart") then
		hookPortal(obj)
	elseif obj:IsA("ProximityPrompt") then
		hookPrompt(obj)
	end
end

Workspace.DescendantAdded:Connect(function(obj)
	if obj:IsA("BasePart") then
		hookPortal(obj)
	elseif obj:IsA("ProximityPrompt") then
		hookPrompt(obj)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	cooldowns[player] = nil
end)
