-- Hooks baked sector pipe/interior parts. This script does not build map geometry.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ColorData = require(ReplicatedStorage:WaitForChild("ColorData"))
local Events = ReplicatedStorage:WaitForChild("Events")
local transitionEvent = Events:FindFirstChild("ShopTransition")
local travelResultEvent = Events:FindFirstChild("TravelToLocationResult")
local dataDirtyEvent = Events:FindFirstChild("PlayerDataDirty")

local COOLDOWN = 1.2
local FADE_IN_TIME = 0.18
local SAFE_LANDING_HEIGHT = 6
local POST_TELEPORT_TOUCH_GRACE = 2.5
local locks = {}
local teleportTokens = {}
local hooked = {}
local AUTO_PIPE_NAMES = {
	pipe = true,
	orangesectorpipe = true,
	orangeinteriorexitpipe = true,
}

local function getCharacterRoot(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function beginTeleportGrace(player)
	local token = (teleportTokens[player] or 0) + 1
	teleportTokens[player] = token
	player:SetAttribute("IsTeleporting", true)

	task.delay(1, function()
		if player.Parent and teleportTokens[player] == token then
			player:SetAttribute("IsTeleporting", false)
		end
	end)
end

local function suppressPipeTouchBounce(player)
	local token = (teleportTokens[player] or 0) + 1
	teleportTokens[player] = token
	player:SetAttribute("IsTeleporting", true)
	player:SetAttribute("SectorInteriorTouchGraceUntil", os.clock() + POST_TELEPORT_TOUCH_GRACE)

	task.delay(POST_TELEPORT_TOUCH_GRACE, function()
		if player.Parent and teleportTokens[player] == token then
			player:SetAttribute("IsTeleporting", false)
			player:SetAttribute("SectorInteriorTouchGraceUntil", nil)
		end
	end)
end

local function isPipeTouchSuppressed(player)
	if not player then
		return true
	end
	if player:GetAttribute("IsTeleporting") == true then
		return true
	end
	local graceUntil = tonumber(player:GetAttribute("SectorInteriorTouchGraceUntil"))
	return graceUntil ~= nil and os.clock() < graceUntil
end

local function setRootCFrame(player, cframe)
	local character = player.Character
	local root = getCharacterRoot(player)
	if not character or not root then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Sit = false
		humanoid.PlatformStand = false
	end
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	character:PivotTo(cframe)
	root.CFrame = cframe
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	task.defer(function()
		if root and root.Parent then
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
	end)
	return true
end

local function getSafeLandingCFrame(player, desiredCFrame)
	local character = player.Character
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = character and { character } or {}

	local origin = desiredCFrame.Position + Vector3.new(0, 90, 0)
	local result = Workspace:Raycast(origin, Vector3.new(0, -260, 0), rayParams)
	if not result then
		return desiredCFrame
	end

	local normal = result.Normal
	if normal.Y < 0.65 then
		return desiredCFrame
	end

	local _, yaw, _ = desiredCFrame:ToOrientation()
	local pos = result.Position + Vector3.new(0, SAFE_LANDING_HEIGHT, 0)
	return CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
end

local function getPlayerFromTouchedPart(part)
	local character = part and part.Parent
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end
	return Players:GetPlayerFromCharacter(character)
end

local function unlockTeleport(player, locationId, displayName)
	local storage = player and player:FindFirstChild("ColorStorage")
	local teleports = storage and storage:FindFirstChild("UnlockedTeleports")
	if not teleports or not teleports:IsA("StringValue") then
		return
	end

	local set = {}
	for _, existing in ipairs(string.split(teleports.Value or "", ",")) do
		if existing ~= "" then
			set[existing] = true
		end
	end
	set.OriginSector = true
	if set[locationId] then
		return
	end
	set[locationId] = true

	local ordered = {}
	for _, id in ipairs({ "OriginSector", "RedWastelands", "ZorkShop", "OrangeSector", "InsidePipes", "GreenSector" }) do
		if set[id] then
			table.insert(ordered, id)
		end
	end
	teleports.Value = table.concat(ordered, ",")
	if dataDirtyEvent and dataDirtyEvent:IsA("BindableEvent") then
		dataDirtyEvent:Fire(player, "unlocked-teleport")
	end
	if travelResultEvent and travelResultEvent:IsA("RemoteEvent") then
		travelResultEvent:FireClient(player, {
			Success = true,
			LocationId = locationId,
			DisplayName = displayName or locationId,
			UnlockedTeleport = true,
			Message = (displayName or locationId) .. " teleport unlocked.",
			UnlockedTeleports = teleports.Value,
		})
	end
end

local function findPartByAttribute(attributeName, colorType, destinationName)
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("BasePart") and obj:GetAttribute(attributeName) == true then
			local objColor = obj:GetAttribute("SectorColor")
				or obj:GetAttribute("ColorType")
				or obj:GetAttribute("AreaColor")
			local nameMatches = not destinationName or obj:FindFirstAncestor(destinationName) ~= nil
			if objColor == colorType and nameMatches then
				return obj
			end
		end
	end
	return nil
end

local function getModelBounds(container)
	if not container then
		return nil, nil
	end
	if container:IsA("Model") then
		return container:GetBoundingBox()
	end
	if container:IsA("Folder") or container:IsA("BasePart") then
		local minPoint = Vector3.new(math.huge, math.huge, math.huge)
		local maxPoint = Vector3.new(-math.huge, -math.huge, -math.huge)
		local found = false
		for _, obj in ipairs(container:GetDescendants()) do
			if obj:IsA("BasePart") then
				local half = obj.Size * 0.5
				local low = obj.Position - half
				local high = obj.Position + half
				minPoint =
					Vector3.new(math.min(minPoint.X, low.X), math.min(minPoint.Y, low.Y), math.min(minPoint.Z, low.Z))
				maxPoint = Vector3.new(
					math.max(maxPoint.X, high.X),
					math.max(maxPoint.Y, high.Y),
					math.max(maxPoint.Z, high.Z)
				)
				found = true
			end
		end
		if container:IsA("BasePart") then
			local half = container.Size * 0.5
			local low = container.Position - half
			local high = container.Position + half
			minPoint =
				Vector3.new(math.min(minPoint.X, low.X), math.min(minPoint.Y, low.Y), math.min(minPoint.Z, low.Z))
			maxPoint =
				Vector3.new(math.max(maxPoint.X, high.X), math.max(maxPoint.Y, high.Y), math.max(maxPoint.Z, high.Z))
			found = true
		end
		if not found then
			return nil, nil
		end
		local center = (minPoint + maxPoint) * 0.5
		return CFrame.new(center), maxPoint - minPoint
	end
	return nil, nil
end

local function getObjectPosition(object)
	if object:IsA("BasePart") then
		return object.Position
	end
	if object:IsA("Model") then
		return object:GetPivot().Position
	end
	local part = object:FindFirstChildWhichIsA("BasePart", true)
	return part and part.Position or Vector3.zero
end

local function isInsideBounds(position, boundsCFrame, boundsSize, margin)
	if not boundsCFrame or not boundsSize then
		return false
	end
	local localPoint = boundsCFrame:PointToObjectSpace(position)
	local half = boundsSize * 0.5 + Vector3.new(margin, margin, margin)
	return math.abs(localPoint.X) <= half.X and math.abs(localPoint.Y) <= half.Y and math.abs(localPoint.Z) <= half.Z
end

local function getInteriorContainer(destinationName)
	destinationName = destinationName or "OrangeSectorInterior"
	local direct = Workspace:FindFirstChild(destinationName, true)
	if direct then
		return direct
	end
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if
			obj:GetAttribute("SectorInterior") == true
			and (obj:GetAttribute("SectorColor") == "Orange" or obj:GetAttribute("ColorType") == "Orange")
		then
			return obj
		end
	end
	return nil
end

local function getLargestHorizontalPart(container)
	local best = nil
	local bestArea = -math.huge
	if not container then
		return nil
	end
	for _, obj in ipairs(container:GetDescendants()) do
		if obj:IsA("BasePart") then
			local size = obj.Size
			local flat = size.Y <= math.max(1, math.min(size.X, size.Z) * 0.25)
			local area = size.X * size.Z
			if flat and area > bestArea then
				best = obj
				bestArea = area
			end
		end
	end
	return best
end

local function getPipeParts(pipeObject)
	local parts = {}
	if pipeObject:IsA("BasePart") then
		table.insert(parts, pipeObject)
	else
		for _, descendant in ipairs(pipeObject:GetDescendants()) do
			if descendant:IsA("BasePart") then
				table.insert(parts, descendant)
			end
		end
	end
	return parts
end

local function configurePipeObject(pipeObject)
	local lowered = string.lower(pipeObject.Name or "")
	if not AUTO_PIPE_NAMES[lowered] and not string.match(lowered, "pipe") then
		return
	end
	if pipeObject:FindFirstAncestor("PetAppearanceStudio") then
		return
	end

	local colorType = pipeObject:GetAttribute("SectorColor") or pipeObject:GetAttribute("ColorType") or "Orange"
	if colorType ~= "Orange" then
		return
	end

	local destinationName = pipeObject:GetAttribute("SectorInteriorDestination") or "OrangeSectorInterior"
	local interior = getInteriorContainer(destinationName)
	local boundsCFrame, boundsSize = getModelBounds(interior)
	local insideInterior = pipeObject:FindFirstAncestor(destinationName) ~= nil
		or isInsideBounds(getObjectPosition(pipeObject), boundsCFrame, boundsSize, 20)

	for _, part in ipairs(getPipeParts(pipeObject)) do
		if not part:GetAttribute("SectorInteriorEntrance") and not part:GetAttribute("SectorInteriorExit") then
			if insideInterior then
				part:SetAttribute("SectorInteriorExit", true)
			else
				part:SetAttribute("SectorInteriorEntrance", true)
				part:SetAttribute("SectorInteriorDestination", destinationName)
			end
		end
		part:SetAttribute("SectorColor", colorType)
		part:SetAttribute("ColorType", colorType)
		part.CanTouch = true
		part.CanQuery = true
	end
end

local function findInteriorSpawn(trigger)
	local colorType = trigger:GetAttribute("SectorColor") or trigger:GetAttribute("ColorType") or "Orange"
	local destinationName = trigger:GetAttribute("SectorInteriorDestination")
	local spawn = findPartByAttribute("SectorInteriorSpawn", colorType, destinationName)
	if spawn then
		return spawn
	end
	local interior = getInteriorContainer(destinationName)
	for _, name in ipairs({ "OrangeInteriorSpawn", "InteriorSpawn", "Spawn", "StartPad" }) do
		local named = interior and interior:FindFirstChild(name, true)
		if named and named:IsA("BasePart") then
			return named
		end
	end
	return getLargestHorizontalPart(interior)
end

local function findExteriorReturn(trigger)
	local colorType = trigger:GetAttribute("SectorColor") or trigger:GetAttribute("ColorType") or "Orange"
	local destination = findPartByAttribute("SectorInteriorExteriorReturn", colorType)
	if destination then
		return destination
	end
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if
			obj:IsA("BasePart")
			and obj:GetAttribute("SectorInteriorEntrance") == true
			and (obj:GetAttribute("SectorColor") or obj:GetAttribute("ColorType") or "Orange") == colorType
		then
			return obj
		end
	end
	return nil
end

local function destinationCFrame(part, lookTarget)
	local pos = part.Position + Vector3.new(0, math.max(4, part.Size.Y * 0.5 + 3), 0)
	if lookTarget then
		return CFrame.lookAt(pos, Vector3.new(lookTarget.Position.X, pos.Y, lookTarget.Position.Z))
	end
	return CFrame.new(pos)
end

local function exteriorReturnCFrame(part, lookTarget)
	if part:GetAttribute("SectorInteriorEntrance") ~= true then
		return destinationCFrame(part, lookTarget)
	end
	local distance = math.max(part.Size.Z * 1.35 + 20, 34)
	local pos = part.CFrame:PointToWorldSpace(Vector3.new(0, math.max(8, part.Size.Y * 0.5 + 8), -distance))
	if lookTarget then
		return CFrame.lookAt(pos, Vector3.new(part.Position.X, pos.Y, part.Position.Z))
	end
	return CFrame.new(pos)
end

local function normalizePipeExitSpawn(part)
	part.Name = "PipeExitSpawn"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = true
	part.Transparency = 1
	part:SetAttribute("PipeExitSpawn", true)
	return part
end

local function ensurePipeExitSpawn(trigger)
	local existing = Workspace:FindFirstChild("PipeExitSpawn")
	if existing and existing:IsA("BasePart") then
		return normalizePipeExitSpawn(existing)
	end

	local exteriorReturn = findExteriorReturn(trigger)
	local exitCFrame
	if exteriorReturn then
		exitCFrame = exteriorReturnCFrame(exteriorReturn, trigger)
	else
		exitCFrame = trigger.CFrame + Vector3.new(0, math.max(8, trigger.Size.Y * 0.5 + 8), -34)
		warn(
			"SectorInteriorHandler: missing SectorInteriorExteriorReturn for "
				.. trigger:GetFullName()
				.. "; creating fallback PipeExitSpawn."
		)
	end

	local marker = Instance.new("Part")
	marker.Size = Vector3.new(8, 1, 8)
	marker.CFrame = exitCFrame
	marker.Parent = Workspace
	return normalizePipeExitSpawn(marker)
end

local function playTransition(player, callback)
	if isPipeTouchSuppressed(player) then
		return
	end
	local now = os.clock()
	if locks[player] and now - locks[player] < COOLDOWN then
		return
	end
	locks[player] = now
	beginTeleportGrace(player)

	if transitionEvent and transitionEvent:IsA("RemoteEvent") then
		transitionEvent:FireClient(player, "FadeIn")
	end
	task.delay(FADE_IN_TIME, function()
		if not player.Parent then
			return
		end
		callback()
		suppressPipeTouchBounce(player)
		task.delay(0.08, function()
			if player.Parent and transitionEvent and transitionEvent:IsA("RemoteEvent") then
				transitionEvent:FireClient(player, "FadeOut")
			end
		end)
	end)
end

local function enterInterior(player, trigger)
	local colorType = trigger:GetAttribute("SectorColor") or trigger:GetAttribute("ColorType") or "Orange"
	local storage = player:FindFirstChild("ColorStorage")
	local unlocked = storage and storage:FindFirstChild("UnlockedColors")
	if unlocked and not ColorData.isColorUnlocked(unlocked.Value, colorType) then
		return
	end

	local spawn = findInteriorSpawn(trigger)
	if not spawn then
		warn("SectorInteriorHandler: missing SectorInteriorSpawn for " .. trigger:GetFullName())
		return
	end
	playTransition(player, function()
		local ok = setRootCFrame(player, getSafeLandingCFrame(player, destinationCFrame(spawn, trigger)))
		if ok then
			if colorType then
				player:SetAttribute("ActiveWorldColor", colorType)
			end
			player:SetAttribute("InsideSectorInterior", true)
			player:SetAttribute("VisitedMutationSectorInterior", true)
			unlockTeleport(player, "InsidePipes", "Inside the Pipes")
		end
	end)
end

local function exitInterior(player, trigger)
	local destination = ensurePipeExitSpawn(trigger)
	playTransition(player, function()
		local ok = setRootCFrame(player, destination.CFrame + Vector3.new(0, 4, 0))
		if ok then
			player:SetAttribute("InsideSectorInterior", false)
		end
	end)
end

local function hookTrigger(part)
	if hooked[part] then
		return
	end
	local isEntrance = part:GetAttribute("SectorInteriorEntrance") == true
	local isExit = part:GetAttribute("SectorInteriorExit") == true
	if not isEntrance and not isExit then
		return
	end

	hooked[part] = true
	local function use(player)
		if isEntrance then
			enterInterior(player, part)
		else
			exitInterior(player, part)
		end
	end

	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("ProximityPrompt") then
			child.Triggered:Connect(use)
		end
	end
	part.ChildAdded:Connect(function(child)
		if child:IsA("ProximityPrompt") then
			child.Triggered:Connect(use)
		end
	end)

	part.Touched:Connect(function(hit)
		local player = getPlayerFromTouchedPart(hit)
		if player then
			use(player)
		end
	end)
end

local function hookExisting()
	for _, obj in ipairs(Workspace:GetDescendants()) do
		configurePipeObject(obj)
		if obj:IsA("BasePart") then
			hookTrigger(obj)
		end
	end
end

hookExisting()
Workspace.DescendantAdded:Connect(function(obj)
	configurePipeObject(obj)
	if obj:IsA("BasePart") then
		hookTrigger(obj)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	locks[player] = nil
	teleportTokens[player] = nil
end)
