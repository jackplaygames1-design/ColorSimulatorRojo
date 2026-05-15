local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local BuffService = require(script.Parent:WaitForChild("BuffService"))
local ColorData = require(ReplicatedStorage:WaitForChild("ColorData"))
local ColorEffectHandler = require(script.Parent:WaitForChild("ColorEffectHandler"))
local GameBalance = require(ReplicatedStorage:WaitForChild("GameBalance"))
local ToolData = require(ReplicatedStorage:WaitForChild("ToolData"))

local FEATURE_ENABLED = not (GameBalance.FeatureFlags and GameBalance.FeatureFlags.GemDepositsEnabled == false)
local DEPOSIT_CONFIG = GameBalance.WildGameplay and GameBalance.WildGameplay.GemDeposits or {}
local MAX_PER_ZONE = DEPOSIT_CONFIG.MaxPerZone or 2
local PER_COLOR_MAX = DEPOSIT_CONFIG.PerColorMax or {}
local INITIAL_SPAWN_DELAY = DEPOSIT_CONFIG.InitialSpawnDelay or 8
local SPAWN_CHECK_INTERVAL = DEPOSIT_CONFIG.SpawnCheckInterval or 5
local RESPAWN_MIN = DEPOSIT_CONFIG.RespawnMin or 30
local RESPAWN_MAX = DEPOSIT_CONFIG.RespawnMax or 60
local BRUSH_MAX_RANGE = 38
local PASSIVE_RANGE = 25
local PASSIVE_INTERVAL = 0.75
local PASSIVE_DAMAGE_PER_COLOR = 1
local PASSIVE_DAMAGE_CAP = 6
local PET_PRIORITY_SECONDS = 6

local HEALTH_BY_COLOR = {
	Red = 25,
	Orange = 40,
	Blue = 60,
	Yellow = 85,
	Green = 120,
	Purple = 170,
	Neon = 240,
	Rainbow = 325,
}

local events = ReplicatedStorage:WaitForChild("Events")
local paintSweepEvent = events:WaitForChild("PaintToolSweep")
local noticeEvent = events:FindFirstChild("WildBuffNotice")
local tutorialGemBrokenEvent = events:FindFirstChild("TutorialGemBroken")
if not tutorialGemBrokenEvent then
	tutorialGemBrokenEvent = Instance.new("BindableEvent")
	tutorialGemBrokenEvent.Name = "TutorialGemBroken"
	tutorialGemBrokenEvent.Parent = events
end

local rootFolder = workspace:FindFirstChild("DynamicGameplay")
if not rootFolder then
	rootFolder = Instance.new("Folder")
	rootFolder.Name = "DynamicGameplay"
	rootFolder.Parent = workspace
end

local depositsFolder = rootFolder:FindFirstChild("GemDeposits")
if not depositsFolder then
	depositsFolder = Instance.new("Folder")
	depositsFolder.Name = "GemDeposits"
	depositsFolder.Parent = rootFolder
end

local activeByColor = {}
local nextSpawnAt = {}
local lastPassiveAt = 0
local lastBrushDamageAt = {}
local zonePartCache = {}
local syncHealthAttributes

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
	if
		not playableSectorFloor
		and (
			part:GetAttribute("DistantSectorColumn")
			or part:GetAttribute("SectorAnchor")
			or part:GetAttribute("DecorativeOnly")
			or part:FindFirstAncestor("DistantSectors") ~= nil
		)
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

local function getWorldColor(world)
	local info = ColorData.Colors[world.primaryColor]
	return info and info.color or Color3.fromRGB(82, 255, 110)
end

local function getActiveList(colorType)
	local list = activeByColor[colorType]
	if not list then
		list = {}
		activeByColor[colorType] = list
	end
	for index = #list, 1, -1 do
		local model = list[index]
		if not model or not model.Parent or model:GetAttribute("Broken") == true then
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
	if not part or part:IsDescendantOf(depositsFolder) then
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
	params.FilterDescendantsInstances = { depositsFolder }
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
	rayParams.FilterDescendantsInstances = { depositsFolder }

	for _ = 1, 42 do
		local x = (math.random() - 0.5) * math.max(8, zone.Size.X * 0.78)
		local z = (math.random() - 0.5) * math.max(8, zone.Size.Z * 0.78)
		local above = zone.CFrame:PointToWorldSpace(Vector3.new(x, zone.Size.Y * 0.5 + 45, z))
		local result = workspace:Raycast(above, Vector3.new(0, -120, 0), rayParams)
		local position = result and result.Position + Vector3.new(0, 2.2, 0)
			or zone.CFrame:PointToWorldSpace(Vector3.new(x, zone.Size.Y * 0.5 + 2.2, z))
		if isSafePosition(position, zone) then
			return position
		end
	end
	return nil
end

local function makeDeposit(world, position)
	local colorType = world.primaryColor
	local health = HEALTH_BY_COLOR[colorType] or 60
	local model = Instance.new("Model")
	model.Name = colorType .. "GemDeposit"
	model:SetAttribute("GemDeposit", true)
	model:SetAttribute("ColorType", colorType)
	model:SetAttribute("WorldName", world.name)
	model:SetAttribute("Health", health)
	model:SetAttribute("MaxHealth", health)
	model:SetAttribute("Broken", false)

	local core = Instance.new("Part")
	core.Name = "Core"
	core.Size = Vector3.new(2.2, 2.2, 2.2)
	core.CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(45), math.rad(45))
	core.Shape = Enum.PartType.Block
	core.Color = Color3.fromRGB(50, 255, 90)
	core.Material = Enum.Material.Neon
	core.Anchored = true
	core.CanCollide = false
	core.CanTouch = false
	core.CanQuery = true
	core.CastShadow = false
	core:SetAttribute("GemDeposit", true)
	core:SetAttribute("ColorType", colorType)
	core:SetAttribute("Health", health)
	core:SetAttribute("MaxHealth", health)
	core.Parent = model
	model.PrimaryPart = core

	local light = Instance.new("PointLight")
	light.Name = "GemGlow"
	light.Color = Color3.fromRGB(80, 255, 120)
	light.Range = 12
	light.Brightness = 1.8
	light.Shadows = false
	light.Parent = core

	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Name = "GemSparkles"
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(Color3.fromRGB(120, 255, 150), Color3.fromRGB(255, 255, 255))
	sparkle.LightEmission = 0.75
	sparkle.Rate = 8
	sparkle.Lifetime = NumberRange.new(0.8, 1.3)
	sparkle.Speed = NumberRange.new(0.4, 1.1)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Parent = core

	local healthGui = Instance.new("BillboardGui")
	healthGui.Name = "GemDepositHealthBar"
	healthGui.AlwaysOnTop = true
	healthGui.Size = UDim2.new(0, 82, 0, 14)
	healthGui.StudsOffset = Vector3.new(0, 3, 0)
	healthGui.MaxDistance = 100
	healthGui.Parent = core

	local barBack = Instance.new("Frame")
	barBack.Name = "BarBack"
	barBack.Size = UDim2.fromScale(1, 1)
	barBack.BackgroundColor3 = Color3.fromRGB(24, 28, 32)
	barBack.BorderSizePixel = 0
	barBack.Parent = healthGui
	local backCorner = Instance.new("UICorner")
	backCorner.CornerRadius = UDim.new(1, 0)
	backCorner.Parent = barBack
	local backStroke = Instance.new("UIStroke")
	backStroke.Color = Color3.fromRGB(255, 255, 255)
	backStroke.Thickness = 1
	backStroke.Transparency = 0.2
	backStroke.Parent = barBack

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(82, 255, 110)
	fill.BorderSizePixel = 0
	fill.Parent = barBack
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill
	syncHealthAttributes(model)

	model.Parent = depositsFolder

	local tween =
		TweenService:Create(core, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			CFrame = core.CFrame * CFrame.new(0, 0.35, 0),
		})
	tween:Play()

	return model
end

syncHealthAttributes = function(model)
	local core = model.PrimaryPart
	if core then
		local health = tonumber(model:GetAttribute("Health")) or 0
		local maxHealth = math.max(1, tonumber(model:GetAttribute("MaxHealth")) or 1)
		core:SetAttribute("Health", health)
		core:SetAttribute("MaxHealth", maxHealth)

		local healthGui = core:FindFirstChild("GemDepositHealthBar")
		local barBack = healthGui and healthGui:FindFirstChild("BarBack")
		local fill = barBack and barBack:FindFirstChild("Fill")
		if fill and fill:IsA("Frame") then
			local progress = math.clamp(health / maxHealth, 0, 1)
			fill.Size = UDim2.fromScale(progress, 1)
			fill.BackgroundColor3 = Color3.fromRGB(255, 80, 80):Lerp(Color3.fromRGB(82, 255, 110), progress)
		end
	end
end

local function markPetPriorityTarget(player, model)
	if not player or not model or not model.Parent then
		return
	end
	model:SetAttribute("PetPriorityOwnerUserId", player.UserId)
	model:SetAttribute("PetPriorityUntil", os.clock() + PET_PRIORITY_SECONDS)
	model:SetAttribute("PetPrioritySetAt", os.clock())
end

local function makeRewardPopup(position, amount)
	return
end

local function makeBurst(position)
	local part = Instance.new("Part")
	part.Name = "GemBurst"
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
	burst.Color = ColorSequence.new(Color3.fromRGB(80, 255, 120), Color3.fromRGB(255, 255, 255))
	burst.LightEmission = 1
	burst.Lifetime = NumberRange.new(0.45, 0.9)
	burst.Speed = NumberRange.new(8, 15)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Rate = 0
	burst.Parent = part
	burst:Emit(32)
	Debris:AddItem(part, 1)
end

local function breakDeposit(player, model)
	if not model or not model.Parent or model:GetAttribute("Broken") == true then
		return
	end
	model:SetAttribute("Broken", true)
	local core = model.PrimaryPart
	local position = core and core.Position or model:GetPivot().Position

	local stats = player and player:FindFirstChild("leaderstats")
	local gems = stats and stats:FindFirstChild("Gems")
	local reward = math.random(5, 10)
	reward = math.floor(reward * BuffService.GetMultiplier(player, "GemRewardMultiplier"))
	if player then
		reward =
			math.floor(reward * (ColorEffectHandler.CalculateEquippedColorEffects(player).GemRewardMultiplier or 1))
		local upgrades = player:FindFirstChild("Upgrades")
		local gemMultiplier = upgrades and upgrades:FindFirstChild("GemMultiplier")
		if gemMultiplier then
			reward = math.floor(reward * math.max(tonumber(gemMultiplier.Value) or 1, 0))
		end
		local gemValue = upgrades and upgrades:FindFirstChild("GemValue")
		if gemValue then
			reward = math.floor(reward * math.max(tonumber(gemValue.Value) or 1, 0))
		end
	end
	if gems then
		gems.Value += reward
	end
	reportDailyQuestProgress(player, "GemDepositsBroken", 1)

	if noticeEvent then
		noticeEvent:FireClient(player, {
			type = "gems",
			amount = reward,
		})
	end
	if tutorialGemBrokenEvent and tutorialGemBrokenEvent:IsA("BindableEvent") then
		tutorialGemBrokenEvent:Fire(player, reward, model)
	end
	makeRewardPopup(position, reward)
	makeBurst(position)
	model:Destroy()
end

local function damageDeposit(player, core, amount, shouldMarkPriority)
	if not FEATURE_ENABLED or not player or not core or not core.Parent then
		return false
	end
	local model = core:FindFirstAncestorWhichIsA("Model")
	if not model or model:GetAttribute("GemDeposit") ~= true or model:GetAttribute("Broken") == true then
		return false
	end
	local colorType = model:GetAttribute("ColorType")
	if not colorType or not isUnlocked(player, colorType) then
		return false
	end

	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return false
	end
	if (root.Position - core.Position).Magnitude > BRUSH_MAX_RANGE then
		return false
	end

	amount = math.max(0, tonumber(amount) or 0)
	amount *= BuffService.GetMultiplier(player, "GemDamageMultiplier")
	amount *= ColorEffectHandler.CalculateEquippedColorEffects(player).GemDamageMultiplier or 1
	local upgrades = player:FindFirstChild("Upgrades")
	local playerPower = upgrades and upgrades:FindFirstChild("PlayerPower")
	if playerPower then
		amount *= math.max(tonumber(playerPower.Value) or 1, 0)
	end
	local brushPower = upgrades and upgrades:FindFirstChild("BrushPower")
	if brushPower then
		amount *= math.max(tonumber(brushPower.Value) or 1, 0)
	end
	if amount <= 0 then
		return false
	end

	local health = math.max(0, tonumber(model:GetAttribute("Health")) or 0)
	health = math.max(0, health - amount)
	if shouldMarkPriority then
		markPetPriorityTarget(player, model)
	end
	model:SetAttribute("Health", health)
	syncHealthAttributes(model)
	core.Color = Color3.fromRGB(50, 255, 90):Lerp(
		Color3.fromRGB(255, 255, 255),
		math.clamp(1 - health / math.max(1, tonumber(model:GetAttribute("MaxHealth")) or 1), 0, 0.35)
	)
	if health <= 0 then
		breakDeposit(player, model)
	end
	return true
end

local function getToolGemDamage(player, toolId)
	local toolsFolder = player:FindFirstChild("PaintTools")
	local equippedValue = toolsFolder and toolsFolder:FindFirstChild("Equipped")
	local equippedId = equippedValue and equippedValue.Value ~= "" and equippedValue.Value or "StarterBrush"
	local tool = ToolData.get(equippedId)
	if toolId and tool and tool.Id ~= toolId then
		tool = ToolData.get(equippedId)
	end
	local stats = ToolData.GetEffectiveStats and ToolData.GetEffectiveStats(tool and tool.Id or "StarterBrush") or {}
	return math.max(1, tonumber(stats.GemDamage) or tonumber(stats.CollectPowerMultiplier) or 1)
end

paintSweepEvent.OnServerEvent:Connect(function(player, toolId, candidates, mode)
	if type(candidates) ~= "table" then
		return
	end
	local t = os.clock()
	if lastBrushDamageAt[player] and t - lastBrushDamageAt[player] < 0.18 then
		return
	end
	lastBrushDamageAt[player] = t

	local damage = getToolGemDamage(player, toolId)
	if mode == "walk" then
		damage *= 0.5
	end

	local seen = {}
	local hits = 0
	for _, part in ipairs(candidates) do
		if hits >= 4 then
			break
		end
		if
			typeof(part) == "Instance"
			and part:IsA("BasePart")
			and part:GetAttribute("GemDeposit")
			and not seen[part]
		then
			seen[part] = true
			if damageDeposit(player, part, damage, true) then
				hits += 1
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastBrushDamageAt[player] = nil
end)

local function getEquippedColorCount(player)
	local folder = player:FindFirstChild("PetData")
	local equipped = folder and folder:FindFirstChild("Equipped")
	if not equipped or equipped.Value == "" then
		return 0
	end
	local count = 0
	for _, key in ipairs(string.split(equipped.Value, ",")) do
		if key ~= "" then
			count += 1
		end
	end
	return count
end

local function findPriorityDeposit(player)
	local bestModel = nil
	local bestSetAt = -math.huge
	local now = os.clock()
	for _, list in pairs(activeByColor) do
		for _, model in ipairs(list) do
			local core = model and model.PrimaryPart
			if
				core
				and model.Parent
				and model:GetAttribute("Broken") ~= true
				and model:GetAttribute("PetPriorityOwnerUserId") == player.UserId
				and (tonumber(model:GetAttribute("PetPriorityUntil")) or 0) > now
			then
				local setAt = tonumber(model:GetAttribute("PetPrioritySetAt")) or 0
				if setAt > bestSetAt then
					bestModel = model
					bestSetAt = setAt
				end
			end
		end
	end
	return bestModel
end

local function passiveDamageTick()
	for _, player in ipairs(Players:GetPlayers()) do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local count = getEquippedColorCount(player)
		if not root or count <= 0 then
			continue
		end

		local effects = ColorEffectHandler.CalculateEquippedColorEffects(player)
		local damage = math.min(
			PASSIVE_DAMAGE_CAP * (effects.GemDamageMultiplier or 1),
			count * PASSIVE_DAMAGE_PER_COLOR * (effects.GemDamageMultiplier or 1)
		)
		local priority = findPriorityDeposit(player)
		local priorityCore = priority and priority.PrimaryPart
		if priorityCore and (root.Position - priorityCore.Position).Magnitude <= PASSIVE_RANGE then
			damageDeposit(player, priorityCore, damage, false)
			continue
		end

		for _, list in pairs(activeByColor) do
			for _, model in ipairs(list) do
				local core = model and model.PrimaryPart
				if
					core
					and model.Parent
					and model:GetAttribute("Broken") ~= true
					and (root.Position - core.Position).Magnitude <= PASSIVE_RANGE
				then
					damageDeposit(player, core, damage, false)
					break
				end
			end
		end
	end
end

local function trySpawnForWorld(world)
	local colorType = world.primaryColor
	if not isWorldActive(colorType) then
		return
	end

	local list = getActiveList(colorType)
	local maxForColor = getMaxForColor(colorType)
	if maxForColor <= 0 or #list >= maxForColor then
		return
	end

	local t = os.clock()
	if not nextSpawnAt[colorType] then
		nextSpawnAt[colorType] = t + INITIAL_SPAWN_DELAY
	end
	if t < nextSpawnAt[colorType] then
		return
	end

	local position = getSpawnPosition(world)
	if not position then
		nextSpawnAt[colorType] = t + 3
		return
	end
	nextSpawnAt[colorType] = t + math.random(RESPAWN_MIN, RESPAWN_MAX)

	local model = makeDeposit(world, position)
	table.insert(list, model)
	print("GemDeposit: spawned " .. tostring(world.primaryColor) .. " deposit on existing zone part.")
end

local function requestImmediateSpawn(colorType)
	local world = ColorData.getWorldByColor(colorType)
	if not world then
		return
	end
	nextSpawnAt[world.primaryColor] = 0
	trySpawnForWorld(world)
end

Players.PlayerAdded:Connect(function(player)
	task.delay(math.max(1, INITIAL_SPAWN_DELAY), function()
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

task.delay(math.max(1, INITIAL_SPAWN_DELAY), function()
	if #Players:GetPlayers() > 0 then
		requestImmediateSpawn("Red")
	end
end)

task.spawn(function()
	while true do
		task.wait(SPAWN_CHECK_INTERVAL)
		if FEATURE_ENABLED then
			for _, world in ipairs(ColorData.Worlds or {}) do
				trySpawnForWorld(world)
			end
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(0.2)
		local t = os.clock()
		if t - lastPassiveAt >= PASSIVE_INTERVAL then
			lastPassiveAt = t
			passiveDamageTick()
		end
	end
end)
