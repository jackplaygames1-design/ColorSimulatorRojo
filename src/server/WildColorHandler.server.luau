local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local BuffService = require(script.Parent:WaitForChild("BuffService"))
local ColorData = require(ReplicatedStorage:WaitForChild("ColorData"))
local GameBalance = require(ReplicatedStorage:WaitForChild("GameBalance"))

local FEATURE_ENABLED = not (GameBalance.FeatureFlags and GameBalance.FeatureFlags.WildColorsEnabled == false)
local WILD_CONFIG = GameBalance.WildGameplay and GameBalance.WildGameplay.WildColors or {}
local ROLL_INTERVAL = WILD_CONFIG.RollInterval or 25
local SPAWN_CHANCE = WILD_CONFIG.SpawnChance or 0.20
local MAX_PER_ZONE = WILD_CONFIG.MaxPerZone or 1
local PER_COLOR_MAX = WILD_CONFIG.PerColorMax or {}
local DESPAWN_AFTER = WILD_CONFIG.DespawnAfter
if DESPAWN_AFTER == nil then
	DESPAWN_AFTER = 120
end
local COLLECT_RANGE = 10

local WILD_TYPES = {
	{
		Id = "Gold",
		BuffId = "CoinsRush",
		Color = Color3.fromRGB(255, 214, 55),
		Material = Enum.Material.Neon,
		Weight = 28,
	},
	{
		Id = "Lime",
		BuffId = "SpeedRush",
		Color = Color3.fromRGB(136, 255, 70),
		Material = Enum.Material.Neon,
		Weight = 26,
	},
	{
		Id = "Cyan",
		BuffId = "BrushFrenzy",
		Color = Color3.fromRGB(70, 225, 255),
		Material = Enum.Material.Neon,
		Weight = 24,
	},
	{
		Id = "Purple",
		BuffId = "LuckyAura",
		Color = Color3.fromRGB(180, 105, 255),
		Material = Enum.Material.Neon,
		Weight = 18,
	},
	{
		Id = "Rainbow",
		BuffId = "GemSurge",
		Color = Color3.fromRGB(255, 255, 255),
		Material = Enum.Material.Neon,
		Weight = 4,
	},
}

local rootFolder = workspace:FindFirstChild("DynamicGameplay")
if not rootFolder then
	rootFolder = Instance.new("Folder")
	rootFolder.Name = "DynamicGameplay"
	rootFolder.Parent = workspace
end

local wildFolder = rootFolder:FindFirstChild("WildColors")
if not wildFolder then
	wildFolder = Instance.new("Folder")
	wildFolder.Name = "WildColors"
	wildFolder.Parent = rootFolder
end

local activeByColor = {}
local lastRollAt = 0
local collectDebounce = {}
local zonePartCache = {}

local function reportDailyQuestProgress(player, questId, amount)
	local event = ServerStorage:FindFirstChild("DailyQuestProgress")
	if event and event:IsA("BindableEvent") then
		event:Fire(player, questId, amount)
	end
end

local function inferColorFromMapPart(part)
	local attrColor = part:GetAttribute("ColorType")
		or part:GetAttribute("WorldColor")
		or part:GetAttribute("AreaColor")
	local partName = string.lower(part.Name or "")
	local parentName = part.Parent and string.lower(part.Parent.Name or "") or ""
	local looksLikeFloor = string.find(partName, "floor")
		or string.find(partName, "ground")
		or string.find(partName, "zone")
		or string.find(partName, "area")
		or string.find(partName, "sector")
		or string.find(parentName, "floor")
		or string.find(parentName, "zone")
		or string.find(parentName, "area")
		or string.find(parentName, "sector")
	local largeFlatSurface = (part.Size.X * part.Size.Z) >= 1600
		and part.Size.X >= 35
		and part.Size.Z >= 35
		and part.Size.Y <= math.max(8, math.min(part.Size.X, part.Size.Z) * 0.3)
	local blockedName = string.find(partName, "pipe", 1, true)
		or string.find(parentName, "pipe", 1, true)
		or partName == "core"
		or partName == "glowshell"
		or partName == "highlight"
		or string.find(partName, "floatcore", 1, true)
	if
		ColorData.getWorldByColor(attrColor)
		and not blockedName
		and (part:GetAttribute("PlayableSectorFloor") == true or looksLikeFloor or largeFlatSurface)
	then
		return attrColor
	end

	for _, world in ipairs(ColorData.Worlds or {}) do
		local color = world.primaryColor
		local loweredColor = string.lower(color)
		if looksLikeFloor and (string.find(partName, loweredColor) or string.find(parentName, loweredColor)) then
			return color
		end
	end

	return nil
end

local function inferPlayableSectorColorFromName(part)
	if not part or not part:IsA("BasePart") then
		return nil
	end

	local partName = string.lower(part.Name or "")
	local parentName = part.Parent and string.lower(part.Parent.Name or "") or ""
	local namedAsSurface = string.find(partName, "floor")
		or string.find(partName, "ground")
		or string.find(partName, "zone")
		or string.find(partName, "area")
		or string.find(partName, "sector")
		or string.find(parentName, "floor")
		or string.find(parentName, "zone")
		or string.find(parentName, "area")
		or string.find(parentName, "sector")

	if not namedAsSurface then
		return nil
	end

	for _, world in ipairs(ColorData.Worlds or {}) do
		local color = world.primaryColor
		if color then
			local loweredColor = string.lower(color)
			if string.find(partName, loweredColor, 1, true) or string.find(parentName, loweredColor, 1, true) then
				return color
			end
		end
	end

	return nil
end

local function configureColorZonePart(part)
	local partName = string.lower(part.Name or "")
	local parentName = part.Parent and string.lower(part.Parent.Name or "") or ""
	if
		part:GetAttribute("BreakableType")
		or part:GetAttribute("PaintPuddleVersion")
		or part:GetAttribute("GemDeposit")
		or part:GetAttribute("WildColor")
		or part:FindFirstAncestor("DynamicGameplay") ~= nil
		or part:FindFirstAncestor("PetAppearanceStudio") ~= nil
		or part:GetAttribute("EggStation") == true
		or part:GetAttribute("TutorialEgg") == true
		or part:GetAttribute("EggId") ~= nil
		or part:GetAttribute("MutationStation") == true
		or part:GetAttribute("MutationUnlockStation") == true
		or part:GetAttribute("FeatureUnlock") == "Mutations"
		or string.find(partName, "pipe", 1, true)
		or string.find(parentName, "pipe", 1, true)
		or partName == "core"
		or partName == "glowshell"
		or partName == "highlight"
		or string.find(partName, "floatcore", 1, true)
	then
		if part:GetAttribute("ColorZone") == true then
			part:SetAttribute("ColorZone", false)
		end
		return nil
	end

	local playableSectorFloor = part:GetAttribute("PlayableSectorFloor") == true
	local namedPlayableSectorColor = inferPlayableSectorColorFromName(part)
	if
		not playableSectorFloor
		and (part:GetAttribute("DistantSectorColumn") or part:GetAttribute("SectorAnchor") or part:GetAttribute(
			"DecorativeOnly"
		) or part:FindFirstAncestor("DistantSectors") ~= nil)
		and not namedPlayableSectorColor
	then
		if part:GetAttribute("ColorZone") == true then
			part:SetAttribute("ColorZone", false)
		end
		return nil
	end

	local colorType = inferColorFromMapPart(part)
	if not colorType then
		return nil
	end

	if part:GetAttribute("ColorZone") ~= true then
		part:SetAttribute("ColorZone", true)
	end
	if part:GetAttribute("ColorType") ~= colorType then
		part:SetAttribute("ColorType", colorType)
	end
	if namedPlayableSectorColor == colorType and part:GetAttribute("PlayableSectorFloor") ~= true then
		part:SetAttribute("PlayableSectorFloor", true)
	end
	return colorType
end

local function isUnlocked(player, colorType)
	local progression = GameBalance.Progression or {}
	local maxPlayableIndex = tonumber(progression.MaxPlayableSectorIndex) or math.huge
	local index = ColorData.getWorldIndex(colorType) or math.huge
	if index > maxPlayableIndex then
		return false
	end

	local storage = player:FindFirstChild("ColorStorage")
	local unlocked = storage and storage:FindFirstChild("UnlockedColors")
	return ColorData.isColorUnlocked(unlocked and unlocked.Value or "Red", colorType)
end

local function isPointInside(part, worldPosition, margin)
	local localPoint = part.CFrame:PointToObjectSpace(worldPosition)
	local half = part.Size * 0.5 + Vector3.new(margin or 0, margin or 0, margin or 0)
	return math.abs(localPoint.X) <= half.X and math.abs(localPoint.Y) <= half.Y and math.abs(localPoint.Z) <= half.Z
end

local function isPlayerInsideColorZone(player, colorType)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end

	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("BasePart") then
			local zoneColor = configureColorZonePart(obj)
			if
				zoneColor == colorType
				and obj:GetAttribute("ColorZone") == true
				and isPointInside(obj, root.Position, 12)
			then
				return true
			end
		end
	end
	return false
end

local function isWorldActive(colorType)
	local progression = GameBalance.Progression or {}
	if colorType == (progression.StartSectorColor or "Red") and #Players:GetPlayers() > 0 then
		return true
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if isUnlocked(player, colorType) or isPlayerInsideColorZone(player, colorType) then
			return true
		end
	end
	return false
end

local function pickWildType()
	local totalWeight = 0
	for _, wildType in ipairs(WILD_TYPES) do
		totalWeight += wildType.Weight or 1
	end
	local roll = math.random() * totalWeight
	local running = 0
	for _, wildType in ipairs(WILD_TYPES) do
		running += wildType.Weight or 1
		if roll <= running then
			return wildType
		end
	end
	return WILD_TYPES[1]
end

local function getActiveList(colorType)
	local list = activeByColor[colorType]
	if not list then
		list = {}
		activeByColor[colorType] = list
	end
	for index = #list, 1, -1 do
		local model = list[index]
		if not model or not model.Parent or model:GetAttribute("Collected") == true then
			table.remove(list, index)
		end
	end
	return list
end

local function getMaxForColor(colorType)
	return math.max(0, tonumber(PER_COLOR_MAX[colorType]) or MAX_PER_ZONE)
end

local function findZonePart(colorType)
	local cached = zonePartCache[colorType]
	if cached and cached.Parent then
		return cached
	end

	local fallback = nil
	local best = nil
	local bestArea = -math.huge
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("BasePart") then
			local attrColor = configureColorZonePart(obj)
			if attrColor == colorType then
				local area = obj.Size.X * obj.Size.Z
				if obj:GetAttribute("ColorZone") and area > bestArea then
					best = obj
					bestArea = area
				end
				fallback = fallback or obj
			end
		end
	end
	if best then
		zonePartCache[colorType] = best
		return best
	end
	zonePartCache[colorType] = fallback
	return fallback
end

local function isBadSpawnNeighbor(part, zone)
	if not part or part:IsDescendantOf(wildFolder) then
		return false
	end
	if part == zone or part:GetAttribute("PlayableSectorFloor") == true or part:GetAttribute("ColorZone") == true then
		return false
	end
	if
		part:GetAttribute("SellZone")
		or part:GetAttribute("SellLocation")
		or part:GetAttribute("BrushShop")
		or part:GetAttribute("CombinedShop")
		or part:GetAttribute("ShopStation")
		or part:GetAttribute("UpgradeStation")
		or part:GetAttribute("EggStation")
		or part:GetAttribute("AreaGate")
		or part:GetAttribute("GateInteraction")
		or part:GetAttribute("DistantSectorColumn")
		or part:GetAttribute("SectorAnchor")
		or part:GetAttribute("DecorativeOnly")
	then
		return true
	end
	local name = string.lower(part.Name)
	return string.find(name, "wall")
		or string.find(name, "portal")
		or string.find(name, "gate")
		or string.find(name, "sell")
		or string.find(name, "shop")
		or string.find(name, "upgrade")
		or string.find(name, "egg")
		or string.find(name, "sector")
		or string.find(name, "column")
end

local function isSafePosition(position, zone)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { wildFolder }
	for _, part in ipairs(workspace:GetPartBoundsInRadius(position, 8, params)) do
		if isBadSpawnNeighbor(part, zone) then
			return false
		end
	end
	return true
end

local function getSpawnPosition(world)
	local zone = findZonePart(world.primaryColor)
	if not zone then
		return nil
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { wildFolder }

	for _ = 1, 38 do
		local x = (math.random() - 0.5) * math.max(8, zone.Size.X * 0.78)
		local z = (math.random() - 0.5) * math.max(8, zone.Size.Z * 0.78)
		local above = zone.CFrame:PointToWorldSpace(Vector3.new(x, zone.Size.Y * 0.5 + 45, z))
		local result = workspace:Raycast(above, Vector3.new(0, -120, 0), rayParams)
		local position = result and result.Position + Vector3.new(0, 2.6, 0)
			or zone.CFrame:PointToWorldSpace(Vector3.new(x, zone.Size.Y * 0.5 + 2.6, z))
		if isSafePosition(position, zone) then
			return position
		end
	end
	return nil
end

local function makeBurst(position, color)
	local part = Instance.new("Part")
	part.Name = "WildColorBurst"
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CFrame = CFrame.new(position)
	part.Parent = workspace

	local burst = Instance.new("ParticleEmitter")
	burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	burst.Color = ColorSequence.new(color, Color3.fromRGB(255, 255, 255))
	burst.LightEmission = 1
	burst.Lifetime = NumberRange.new(0.45, 0.9)
	burst.Speed = NumberRange.new(7, 14)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Rate = 0
	burst.Parent = part
	burst:Emit(36)
	Debris:AddItem(part, 1)
end

local function getPlayerFromHit(hit)
	local character = hit and hit.Parent
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid and character.Parent then
		character = character.Parent
		humanoid = character:FindFirstChildOfClass("Humanoid")
	end
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return Players:GetPlayerFromCharacter(character)
end

local function collectWildColor(player, model)
	if not player or not model or not model.Parent or model:GetAttribute("Collected") == true then
		return
	end
	local core = model.PrimaryPart
	local colorType = model:GetAttribute("ColorType")
	if not core or not colorType or not isUnlocked(player, colorType) then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - core.Position).Magnitude > COLLECT_RANGE then
		return
	end

	local key = tostring(player.UserId) .. ":" .. tostring(model)
	local t = os.clock()
	if collectDebounce[key] and t - collectDebounce[key] < 0.75 then
		return
	end
	collectDebounce[key] = t

	model:SetAttribute("Collected", true)
	local wildType = model:GetAttribute("WildType")
	local buffId = model:GetAttribute("BuffId")
	BuffService.Grant(player, buffId)
	makeBurst(core.Position, core.Color)
	local list = activeByColor[colorType]
	if list then
		for index = #list, 1, -1 do
			if list[index] == model then
				table.remove(list, index)
				break
			end
		end
	end
	model:Destroy()
	reportDailyQuestProgress(player, "CollectOrbs", 1)
	print("WildColor: " .. player.Name .. " collected " .. tostring(wildType) .. " in " .. tostring(colorType))
end

local function makeWildColor(world, position, wildType)
	local model = Instance.new("Model")
	model.Name = world.primaryColor .. wildType.Id .. "WildColor"
	model:SetAttribute("WildColor", true)
	model:SetAttribute("WildType", wildType.Id)
	model:SetAttribute("BuffId", wildType.BuffId)
	model:SetAttribute("ColorType", world.primaryColor)
	model:SetAttribute("Collected", false)

	local core = Instance.new("Part")
	core.Name = "Core"
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.new(2.4, 2.4, 2.4)
	core.CFrame = CFrame.new(position)
	core.Color = wildType.Color
	core.Material = wildType.Material
	core.Anchored = true
	core.CanCollide = false
	core.CanTouch = true
	core.CanQuery = true
	core.CastShadow = false
	core:SetAttribute("WildColor", true)
	core:SetAttribute("WildType", wildType.Id)
	core:SetAttribute("BuffId", wildType.BuffId)
	core:SetAttribute("ColorType", world.primaryColor)
	core.Parent = model
	model.PrimaryPart = core

	local light = Instance.new("PointLight")
	light.Name = "WildGlow"
	light.Color = wildType.Color
	light.Range = 14
	light.Brightness = 2
	light.Shadows = false
	light.Parent = core

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "WildSparkles"
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Color = ColorSequence.new(wildType.Color, Color3.fromRGB(255, 255, 255))
	sparkles.LightEmission = 0.9
	sparkles.Rate = 12
	sparkles.Lifetime = NumberRange.new(0.75, 1.4)
	sparkles.Speed = NumberRange.new(0.35, 1.2)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Parent = core

	model.Parent = wildFolder

	local tween =
		TweenService:Create(core, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			CFrame = core.CFrame * CFrame.new(0, 0.45, 0),
		})
	tween:Play()

	core.Touched:Connect(function(hit)
		local player = getPlayerFromHit(hit)
		if player then
			collectWildColor(player, model)
		end
	end)

	if DESPAWN_AFTER and DESPAWN_AFTER > 0 then
		task.delay(DESPAWN_AFTER, function()
			if model.Parent and model:GetAttribute("Collected") ~= true then
				local list = activeByColor[world.primaryColor]
				if list then
					for index = #list, 1, -1 do
						if list[index] == model then
							table.remove(list, index)
							break
						end
					end
				end
				model:Destroy()
			end
		end)
	end

	return model
end

local function trySpawnForWorld(world, force)
	local colorType = world.primaryColor
	if not isWorldActive(colorType) then
		return
	end

	local list = getActiveList(colorType)
	local maxForColor = getMaxForColor(colorType)
	if maxForColor <= 0 or #list >= maxForColor then
		return
	end

	if not force and math.random() > SPAWN_CHANCE then
		return
	end

	local spawned = 0
	for _ = #list + 1, maxForColor do
		local position = getSpawnPosition(world)
		if not position then
			break
		end
		local wildType = pickWildType()
		table.insert(list, makeWildColor(world, position, wildType))
		spawned += 1
		print("WildColor: spawned " .. tostring(wildType.Id) .. " power in " .. tostring(colorType) .. ".")
	end
end

local function requestImmediateSpawn(colorType)
	local world = ColorData.getWorldByColor(colorType)
	if world then
		trySpawnForWorld(world, true)
	end
end

Players.PlayerAdded:Connect(function(player)
	task.delay(2, function()
		if player.Parent then
			requestImmediateSpawn("Red")
			local activeColor = player:GetAttribute("ActiveWorldColor")
			if activeColor and activeColor ~= "Red" then
				requestImmediateSpawn(activeColor)
			end
		end
	end)

	player:GetAttributeChangedSignal("ActiveWorldColor"):Connect(function()
		local activeColor = player:GetAttribute("ActiveWorldColor")
		if activeColor and activeColor ~= "" then
			requestImmediateSpawn(activeColor)
		end
	end)

	task.spawn(function()
		local storage = player:WaitForChild("ColorStorage", 20)
		local currentWorld = storage and storage:FindFirstChild("CurrentWorld")
		if currentWorld and currentWorld:IsA("StringValue") then
			currentWorld:GetPropertyChangedSignal("Value"):Connect(function()
				if currentWorld.Value ~= "" then
					requestImmediateSpawn(currentWorld.Value)
				end
			end)
		end
	end)
end)

task.delay(2, function()
	if #Players:GetPlayers() > 0 then
		requestImmediateSpawn("Red")
	end
end)

task.spawn(function()
	while true do
		task.wait(1)
		if FEATURE_ENABLED and os.clock() - lastRollAt >= ROLL_INTERVAL then
			lastRollAt = os.clock()
			for _, world in ipairs(ColorData.Worlds or {}) do
				if MAX_PER_ZONE > 0 then
					trySpawnForWorld(world)
				end
			end
		end
	end
end)
