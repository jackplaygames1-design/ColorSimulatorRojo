-- Server-authoritative click collection for color breakables.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local DEBUG_LOGS = RunService:IsStudio()

local ColorData = require(ReplicatedStorage:WaitForChild("ColorData"))
local ColorEffectHandler = require(script.Parent:WaitForChild("ColorEffectHandler"))
local GameBalance = require(ReplicatedStorage:WaitForChild("GameBalance"))
local GamepassBenefits = require(script.Parent:WaitForChild("GamepassBenefits"))
local GroundPaintService = require(script.Parent:WaitForChild("GroundPaintService"))
local GroupRewardsService = require(script.Parent:WaitForChild("GroupRewardsService"))
local PetData = require(ReplicatedStorage:WaitForChild("PetData"))
local RankService = require(script.Parent:WaitForChild("RankService"))

local function loadToolData()
	local module = ReplicatedStorage:WaitForChild("ToolData", 3)
	if module then
		return require(module)
	end

	warn("ColorCollectHandler: ToolData missing; using Starter Brush fallback config.")
	local fallback = {}
	fallback.Tools = {
		StarterBrush = {
			Id = "StarterBrush",
			DisplayName = "Starter Brush",
			Range = 9,
			Width = 7,
			Cooldown = 0.45,
			PowerMultiplier = 1,
			CollectPowerMultiplier = 1,
			SweepWidthMultiplier = 1,
			UseSpeedMultiplier = 1,
			PickupRadiusMultiplier = 1,
			VisualType = "Brush",
			MaxTargets = 8,
			MaxServerRange = 24,
		},
	}
	function fallback.get(toolId)
		return fallback.Tools[toolId or ""] or fallback.Tools.StarterBrush
	end
	function fallback.GetEffectiveStats(toolId)
		local tool = fallback.get(toolId)
		return {
			Id = tool.Id,
			CollectPowerMultiplier = tool.CollectPowerMultiplier or tool.PowerMultiplier or 1,
			SweepWidthMultiplier = tool.SweepWidthMultiplier or 1,
			UseSpeedMultiplier = tool.UseSpeedMultiplier or 1,
			PickupRadiusMultiplier = tool.PickupRadiusMultiplier or 1,
			PassiveId = tool.PassiveId or "None",
			PassiveDescription = tool.PassiveDescription or "",
			PassiveEnabled = tool.PassiveEnabled == true,
		}
	end
	return fallback
end

local ToolData = loadToolData()

local Events = ReplicatedStorage:WaitForChild("Events")
local collectEvent = Events:WaitForChild("CollectColor")
local paintSweepEvent = Events:FindFirstChild("PaintToolSweep")
if not paintSweepEvent then
	paintSweepEvent = Instance.new("RemoteEvent")
	paintSweepEvent.Name = "PaintToolSweep"
	paintSweepEvent.Parent = Events
end
local colorEffectVfxEvent = Events:FindFirstChild("ColorEffectVFX")
if not colorEffectVfxEvent then
	colorEffectVfxEvent = Instance.new("RemoteEvent")
	colorEffectVfxEvent.Name = "ColorEffectVFX"
	colorEffectVfxEvent.Parent = Events
end
local tutorialPatchClearedEvent = Events:FindFirstChild("TutorialPatchCleared")
if not tutorialPatchClearedEvent then
	tutorialPatchClearedEvent = Instance.new("BindableEvent")
	tutorialPatchClearedEvent.Name = "TutorialPatchCleared"
	tutorialPatchClearedEvent.Parent = Events
end

local COLLECT_RANGE = 22
local COLLECT_COOLDOWN = 0.18
local WALK_SWEEP_COOLDOWN = 0.16
local WALK_PICKUP_RANGE = 8
local WALK_MAX_TARGETS = 5
local RESPAWN_DELAY = 4
local PET_PRIORITY_SECONDS = 6

local lastCollectAt = {}
local lastSweepAt = {}
local lastWalkSweepAt = {}
local lastLightningAt = {}
local lastMagnetAt = {}
local brushStreaks = {}
local collectionWarnings = {}
local touchConnections = {}
local unexpectedClientWarnings = {}

local function reportDailyQuestProgress(player, questId, amount)
	local event = ServerStorage:FindFirstChild("DailyQuestProgress")
	if event and event:IsA("BindableEvent") then
		event:Fire(player, questId, amount)
	end
end

local function warnCollectionOnce(player, reason, detail)
	local playerKey = player and player.UserId or "server"
	local key = tostring(playerKey) .. ":" .. tostring(reason)
	if collectionWarnings[key] then
		return
	end
	collectionWarnings[key] = true
	warn("Collection ignored: " .. tostring(reason) .. (detail and (" - " .. tostring(detail)) or ""))
end

local function markPetPriorityTarget(player, part)
	if not player or typeof(part) ~= "Instance" or not part:IsA("BasePart") then
		return
	end
	part:SetAttribute("PetPriorityOwnerUserId", player.UserId)
	part:SetAttribute("PetPriorityUntil", os.clock() + PET_PRIORITY_SECONDS)
	part:SetAttribute("PetPrioritySetAt", os.clock())
end

local function warnUnexpectedClientValuesOnce(player, action)
	local key = tostring(player and player.UserId or "server") .. ":" .. tostring(action)
	if unexpectedClientWarnings[key] then
		return
	end
	unexpectedClientWarnings[key] = true
	warn(
		"Collection request ignored unexpected client value fields for "
			.. tostring(action)
			.. ". Server calculates rewards."
	)
end

local function isTouchFallbackEnabled()
	return GameBalance.Collection and GameBalance.Collection.AllowTouchCollectionFallback == true
end

local function getVisualColor(colorType)
	if colorType == "Rainbow" then
		return Color3.fromRGB(215, 180, 255)
	end

	local colorInfo = ColorData.Colors[colorType]
	return colorInfo and colorInfo.color or Color3.new(1, 1, 1)
end

local function getStoredColor(part, colorType)
	local stored = part and part:GetAttribute("SpawnColor")
	if typeof(stored) == "Color3" then
		return stored
	end
	return getVisualColor(colorType)
end

local function parseInventory(str)
	local inventory = {}
	if not str or str == "" then
		return inventory
	end

	for _, part in ipairs(string.split(str, ",")) do
		local segments = string.split(part, ":")
		local variantKey
		local petId
		local stackIndex
		if tonumber(segments[2]) then
			petId = segments[1]
			stackIndex = 2
		else
			variantKey = segments[1]
			petId = segments[2]
			stackIndex = 3
		end
		local stackAmount = tonumber(segments[stackIndex]) or 1
		local traitId = PetData.normalizeTraitId(segments[stackIndex + 1])
		local shinyStr = segments[stackIndex + 2] or "normal"
		local personalityId = PetData.normalizePersonalityId(segments[stackIndex + 3] or "Neutral")
		local mutationId = PetData.normalizeMutationId(segments[stackIndex + 4] or "None")
		variantKey = variantKey or PetData.makeVariantKey(petId, personalityId, mutationId, traitId)
		if petId and petId ~= "" then
			inventory[variantKey] = {
				petId = petId,
				stackAmount = stackAmount,
				traitId = traitId,
				isShiny = shinyStr == "shiny" or shinyStr == "true",
				personalityId = personalityId,
				mutationId = mutationId,
			}
		end
	end

	return inventory
end

local function getPetColorMultiplier(player)
	return ColorEffectHandler.GetColorGainMultiplier(player)
end

local function getPickupRange(player)
	local range = COLLECT_RANGE
	local upgrades = player:FindFirstChild("Upgrades")
	local pickupRange = upgrades and upgrades:FindFirstChild("PickupRange")
	if pickupRange then
		range = pickupRange.Value
	end

	local boostFolder = player:FindFirstChild("Boosts")
	local rangeBoost = boostFolder and boostFolder:FindFirstChild("range")
	if rangeBoost and os.time() < rangeBoost.Value then
		range *= 1.5
	end

	range *= ColorEffectHandler.CalculateEquippedColorEffects(player).BrushRangeMultiplier

	return range
end

local function getCollectMultiplier(player)
	local multiplier = getPetColorMultiplier(player)
	local upgrades = player:FindFirstChild("Upgrades")
	local playerPower = upgrades and upgrades:FindFirstChild("PlayerPower")
	if playerPower then
		multiplier *= playerPower.Value
	end

	local brushPower = upgrades and upgrades:FindFirstChild("BrushPower")
	if brushPower then
		multiplier *= brushPower.Value
	end

	return multiplier
end

local function getZoneCoinMultiplier(colorType)
	local configured = GameBalance.Sell
		and GameBalance.Sell.ColorValueMultipliers
		and GameBalance.Sell.ColorValueMultipliers[colorType]
	local world = ColorData.getWorldByColor(colorType)
	return tonumber(configured or (world and world.colorValueMultiplier)) or 1
end

local function getInstantCoinMultiplier(player, colorType)
	local multiplier = getZoneCoinMultiplier(colorType)
	multiplier *= ColorEffectHandler.GetSellCoinsMultiplier(player)

	local boostFolder = player:FindFirstChild("Boosts")
	local coinBoost = boostFolder and boostFolder:FindFirstChild("coins")
	if coinBoost and os.time() < coinBoost.Value then
		multiplier *= 2
	end

	multiplier *= GamepassBenefits.getCoinMultiplier(player)
	multiplier *= GroupRewardsService.GetCoinMultiplier(player)

	local upgrades = player:FindFirstChild("Upgrades")
	local coinMultiplier = upgrades
		and (upgrades:FindFirstChild("CoinMultiplier") or upgrades:FindFirstChild("ColorMultiplier"))
	if coinMultiplier then
		multiplier *= coinMultiplier.Value
	end

	local sellValue = upgrades and upgrades:FindFirstChild("SellValue")
	if sellValue then
		multiplier *= sellValue.Value
	end
	return multiplier
end

local function awardCoins(player, amount)
	amount = math.max(0, math.floor(tonumber(amount) or 0))
	if amount <= 0 then
		return false
	end

	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	if not coins then
		warnCollectionOnce(player, "missing player data", "leaderstats/Coins not ready")
		return false
	end

	coins.Value += amount
	RankService.AwardFromCoins(player, amount, "rank-color-coins")
	reportDailyQuestProgress(player, "CoinsEarned", amount)
	return true
end

local function getPickupUpgradeValue(player)
	local upgrades = player:FindFirstChild("Upgrades")
	local pickupRange = upgrades and upgrades:FindFirstChild("PickupRange")
	return pickupRange and pickupRange.Value or 8
end

local function getToolEffectiveStats(toolConfig)
	if ToolData.GetEffectiveStats then
		return ToolData.GetEffectiveStats(toolConfig and toolConfig.Id or "StarterBrush")
	end

	return {
		CollectPowerMultiplier = toolConfig and (toolConfig.CollectPowerMultiplier or toolConfig.PowerMultiplier) or 1,
		SweepWidthMultiplier = toolConfig and toolConfig.SweepWidthMultiplier or 1,
		UseSpeedMultiplier = toolConfig and toolConfig.UseSpeedMultiplier or 1,
		PickupRadiusMultiplier = toolConfig and toolConfig.PickupRadiusMultiplier or 1,
	}
end

local function getPaintToolRange(player, toolConfig)
	local upgradeRange = getPickupUpgradeValue(player)
	local upgradedBonus = math.max(0, upgradeRange - 8) * 0.35
	local effects = ColorEffectHandler.CalculateEquippedColorEffects(player)
	local baseRange = (toolConfig.Range or 9) + upgradedBonus
	local toolStats = getToolEffectiveStats(toolConfig)
	return math.min(
		baseRange * effects.BrushRangeMultiplier * (toolStats.PickupRadiusMultiplier or 1),
		toolConfig.MaxServerRange or 24
	)
end

local function getBaseBreakableReward(part, data)
	local reward = tonumber(part:GetAttribute("BaseColorReward"))
		or tonumber(data.baseReward)
		or tonumber(data.rewardMin)
		or 1
	return math.max(1, math.floor(reward))
end

local function ownsPaintTool(player, toolId)
	if toolId == "StarterBrush" then
		return true
	end

	local toolsFolder = player:FindFirstChild("PaintTools")
	local ownedValue = toolsFolder and toolsFolder:FindFirstChild("Owned")
	for _, ownedId in ipairs(string.split(ownedValue and ownedValue.Value or "", ",")) do
		if ownedId == toolId then
			return true
		end
	end
	return false
end

local function canUsePaintTool(player, toolConfig)
	if not toolConfig then
		return false
	end
	if not ownsPaintTool(player, toolConfig.Id) then
		return false
	end

	local requiredColor = toolConfig.RequiredColor or "Red"
	if requiredColor == "Red" then
		return true
	end

	local storage = player:FindFirstChild("ColorStorage")
	local unlocked = storage and storage:FindFirstChild("UnlockedColors")
	return unlocked and ColorData.isColorUnlocked(unlocked.Value, requiredColor)
end

local function getEquippedPaintTool(player)
	local character = player.Character
	if not character then
		return nil, nil
	end

	local toolsFolder = player:FindFirstChild("PaintTools")
	local equippedValue = toolsFolder and toolsFolder:FindFirstChild("Equipped")
	local equippedToolId = equippedValue and equippedValue.Value or "StarterBrush"
	local equippedConfig = ToolData.get(equippedToolId)
	if not canUsePaintTool(player, equippedConfig) then
		equippedConfig = ToolData.get("StarterBrush")
	end

	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") and child:GetAttribute("PaintToolId") then
			return child, equippedConfig
		end
	end

	return nil, equippedConfig
end

local function isInsideToolSweep(player, part, range, width)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not part then
		return false
	end

	local offset = part.Position - root.Position
	local distance = offset.Magnitude
	if distance > range then
		return false
	end

	local look = root.CFrame.LookVector
	local forward = distance > 0 and offset.Unit:Dot(look) or 1
	local side = math.abs(offset:Cross(look).Magnitude)
	return forward > -0.2 and side <= width
end

local function isInsideWalkPickup(player, part, range)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not part then
		return false
	end

	return (part.Position - root.Position).Magnitude <= range
end

local function isPointInsideZone(part, worldPosition, margin)
	local localPoint = part.CFrame:PointToObjectSpace(worldPosition)
	local half = part.Size * 0.5 + Vector3.new(margin or 0, margin or 0, margin or 0)
	return math.abs(localPoint.X) <= half.X and math.abs(localPoint.Y) <= half.Y and math.abs(localPoint.Z) <= half.Z
end

local function isPlayerInsideColorZone(root, colorType)
	if not root or not colorType then
		return false
	end

	for _, obj in ipairs(workspace:GetDescendants()) do
		if
			obj:IsA("BasePart")
			and obj:GetAttribute("ColorZone") == true
			and obj:GetAttribute("ColorType") == colorType
			and isPointInsideZone(obj, root.Position, 12)
		then
			return true
		end
	end
	return false
end

local function canAccessBreakableColor(player, colorType, root)
	if not colorType then
		return true
	end

	local storage = player:FindFirstChild("ColorStorage")
	local unlocked = storage and storage:FindFirstChild("UnlockedColors")
	if unlocked and ColorData.isColorUnlocked(unlocked.Value, colorType) then
		return true
	end
	if isPlayerInsideColorZone(root, colorType) then
		return true
	end
	return unlocked == nil
end

local function isGroundContamination(part)
	return part
		and part:IsA("BasePart")
		and (
			part:GetAttribute("GroundContamination") == true
			or part:GetAttribute("BreakableType") == "GroundContamination"
		)
end

local function resolveGroundBrushPosition(player, root, range, groundPayload)
	if type(groundPayload) == "table" and typeof(groundPayload.Position) == "Vector3" then
		return groundPayload.Position
	end
	if not root then
		return nil
	end

	local forwardDistance = math.clamp((tonumber(range) or 24) * 0.45, 6, 18)
	local probeOrigin = root.Position + root.CFrame.LookVector * forwardDistance + Vector3.new(0, 8, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	params.IgnoreWater = true

	local result = workspace:Raycast(probeOrigin, Vector3.new(0, -36, 0), params)
	if result then
		return result.Position
	end
	return root.Position + root.CFrame.LookVector * forwardDistance
end

local function resetBreakable(part)
	if not part or not part.Parent then
		return
	end

	local breakableType = part:GetAttribute("BreakableType")
	local colorType = part:GetAttribute("ColorType")
	local data = breakableType and ColorData.Breakables[breakableType]
	if not data then
		part:SetAttribute("Respawning", false)
		part:SetAttribute("IsCollected", false)
		return
	end

	local colorInfo = colorType and ColorData.Colors[colorType]
	if colorInfo then
		local visualColor = getStoredColor(part, colorType)
		part.Color = visualColor
		local light = part:FindFirstChildOfClass("PointLight")
		if light then
			light.Color = visualColor
		end
	end

	part.Size = part:GetAttribute("OriginalSize") or data.size
	part.Transparency = part:GetAttribute("CollectorBaseTransparency") or 0
	part.CanCollide = false
	part.CanQuery = true
	part:SetAttribute("IsCollected", false)
	part:SetAttribute("Respawning", false)
	part:SetAttribute("PetPriorityOwnerUserId", nil)
	part:SetAttribute("PetPriorityUntil", nil)
	part:SetAttribute("PetPrioritySetAt", nil)
end

local function hideAndRespawn(part)
	part:SetAttribute("IsCollected", true)
	part:SetAttribute("PetPriorityOwnerUserId", nil)
	part:SetAttribute("PetPriorityUntil", nil)
	part:SetAttribute("PetPrioritySetAt", nil)
	part.Transparency = 1
	part.CanCollide = false
	part.CanTouch = false

	for _, child in ipairs(part:GetDescendants()) do
		if child:IsA("BasePart") then
			child.Transparency = 1
			child.CanCollide = false
			child.CanTouch = false
			child.CanQuery = false
		end
	end

	if part:GetAttribute("TutorialColorPatch") or part:GetAttribute("NoRespawn") then
		part:SetAttribute("Respawning", false)
		part.CanQuery = false
		return
	end

	part:SetAttribute("Respawning", true)

	local respawnDelay = tonumber(part:GetAttribute("ContaminationRegenDelay"))
		or tonumber(part:GetAttribute("RespawnDelay"))
		or RESPAWN_DELAY
	task.delay(respawnDelay, function()
		resetBreakable(part)
	end)
end

local function canCollect(player, part, options)
	options = options or {}
	if typeof(part) ~= "Instance" or not part:IsA("BasePart") or not part:IsDescendantOf(workspace) then
		return false, "Invalid target."
	end

	local breakableType = part:GetAttribute("BreakableType")
	if not breakableType or not ColorData.Breakables[breakableType] then
		return false, "That is not color."
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return false, "You cannot collect right now."
	end

	local colorType = part:GetAttribute("ColorType")
	if not canAccessBreakableColor(player, colorType, root) then
		return false, "Area locked."
	end

	if part:GetAttribute("IsCollected") or part.Transparency >= 1 then
		return false, "Already collected."
	end

	local maxRange = options.maxRange or getPickupRange(player)
	if (root.Position - part.Position).Magnitude > maxRange then
		return false, "Too far away."
	end

	local now = os.clock()
	if not options.skipCooldown and lastCollectAt[player] and now - lastCollectAt[player] < COLLECT_COOLDOWN then
		return false, "Slow down."
	end

	if not options.skipCooldown then
		lastCollectAt[player] = now
	end
	return true
end

local function collectBreakable(player, part, options)
	options = options or {}
	local ok, message = canCollect(player, part, options)
	if not ok then
		return false, 0, message
	end

	local data = ColorData.Breakables[part:GetAttribute("BreakableType")]
	local colorType = part:GetAttribute("ColorType")
	local areaMult = tonumber(part:GetAttribute("RewardMultiplier")) or 1
	local toolMult = options.powerMultiplier or 1
	local reward = math.floor(
		getBaseBreakableReward(part, data)
			* areaMult
			* getCollectMultiplier(player)
			* toolMult
			* getInstantCoinMultiplier(player, colorType)
	)
	local upgrades = player:FindFirstChild("Upgrades")
	local critChance = upgrades and upgrades:FindFirstChild("CritChance")
	if critChance and math.random() < math.clamp(critChance.Value, 0, 0.95) then
		reward *= 2
	end
	reward = math.max(reward, 1)

	if not awardCoins(player, reward) then
		return false, 0, "Coins are not ready."
	end

	if options.source == "brush" and tutorialPatchClearedEvent then
		tutorialPatchClearedEvent:Fire(player, colorType, reward, part, options.mode or "sweep")
	end

	hideAndRespawn(part)
	reportDailyQuestProgress(player, "ColorSpillsCleaned", 1)
	if colorType == "Red" then
		reportDailyQuestProgress(player, "RedWastelandsSpillsCleaned", 1)
	end
	if options.source == "brush" then
		reportDailyQuestProgress(player, "BrushUses", 1)
	end
	return true, reward, "Coins"
end

local fireEffectVfx

local function processGroundBrush(player, toolConfig, toolStats, root, range, groundPayload)
	if not root then
		return 0, 0
	end

	local hitPosition = resolveGroundBrushPosition(player, root, range, groundPayload)
	if not hitPosition then
		return 0, 0
	end

	local maxServerRange = tonumber(toolConfig.MaxServerRange) or range or 24
	if (root.Position - hitPosition).Magnitude > maxServerRange + 12 then
		return 0, 0
	end

	local groundConfig = GameBalance.GroundPaint or {}
	local groundBrushConfig = groundConfig.Brush or {}
	local upgrades = player:FindFirstChild("Upgrades")
	local brushSize = upgrades and upgrades:FindFirstChild("BrushSize")
	local radius = tonumber(toolStats.BrushRadius)
		or tonumber(toolConfig.BrushRadius)
		or tonumber(groundBrushConfig.BaseRadius)
		or math.max(4, (tonumber(toolConfig.Width) or 7) * 0.7)
	if brushSize then
		radius *= math.max(tonumber(brushSize.Value) or 1, 0.1)
	end
	radius = math.clamp(radius, 3, tonumber(groundBrushConfig.MaxRadius) or 42)

	local basePower = tonumber(groundBrushConfig.BasePower) or 0.28
	local brushPower = tonumber(toolStats.BrushPower)
		or tonumber(toolStats.CollectPowerMultiplier)
		or tonumber(toolConfig.PowerMultiplier)
		or 1
	local rewardPower = tonumber(toolStats.BrushRewardMultiplier) or tonumber(toolConfig.BrushRewardMultiplier) or 0.38
	local paintPower = math.clamp(basePower * brushPower * math.max(rewardPower / 0.38, 0.25), 0.03, 1.25)

	local result = GroundPaintService.Brush(player, hitPosition, radius, paintPower)
	local rewardUnits = GroundPaintService.GetPaintRewardUnits(result)
	if rewardUnits <= 0 then
		return 0, 0
	end

	local colorType = result.ColorType
	local reward = math.floor(rewardUnits * getCollectMultiplier(player) * getInstantCoinMultiplier(player, colorType))
	local critChance = upgrades and upgrades:FindFirstChild("CritChance")
	if critChance and math.random() < math.clamp(critChance.Value, 0, 0.95) then
		reward *= 2
	end
	reward = math.max(reward, 1)

	if not awardCoins(player, reward) then
		return 0, 0
	end

	if tutorialPatchClearedEvent then
		tutorialPatchClearedEvent:Fire(player, colorType, reward, nil, "ground")
	end
	reportDailyQuestProgress(player, "ColorSpillsCleaned", 1)
	if colorType == "Red" then
		reportDailyQuestProgress(player, "RedWastelandsSpillsCleaned", 1)
	end
	reportDailyQuestProgress(player, "BrushUses", 1)

	if result.Positions and #result.Positions > 0 then
		fireEffectVfx(player, "BrushActive", root.Position, result.Positions, toolConfig.Id)
	end

	return math.max(1, tonumber(result.CellsChanged) or 1), reward
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
	if not humanoid then
		return nil
	end

	return Players:GetPlayerFromCharacter(character)
end

local function hookTouchCollection(part)
	if not isTouchFallbackEnabled() then
		return
	end
	if typeof(part) ~= "Instance" or not part:IsA("BasePart") then
		return
	end
	if not part:GetAttribute("BreakableType") then
		return
	end
	if touchConnections[part] then
		part.CanTouch = true
		return
	end

	part.CanTouch = true
	touchConnections[part] = part.Touched:Connect(function(hit)
		local player = getPlayerFromHit(hit)
		if not player then
			return
		end

		local ok, awarded, message = collectBreakable(player, part, {
			source = "touch",
		})
		if ok then
			collectEvent:FireClient(player, true, awarded, "Coins")
		elseif message == "Coins are not ready." then
			warnCollectionOnce(player, "missing player data", message)
		elseif message == "Invalid target." or message == "That is not color." then
			warnCollectionOnce(player, "blob invalid", message)
		end
	end)

	part.Destroying:Connect(function()
		local connection = touchConnections[part]
		if connection then
			connection:Disconnect()
		end
		touchConnections[part] = nil
	end)
end

local function getPlayerRoot(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function hasCompletedTutorial(player)
	return true
end

local function canWalkCollectDuringTutorial(_player, _candidates)
	return true
end

local function findNearbyBreakables(player, origin, range, maxTargets)
	local candidates = {}
	for _, obj in ipairs(workspace:GetDescendants()) do
		if
			obj:IsA("BasePart")
			and obj:GetAttribute("BreakableType")
			and not obj:GetAttribute("IsCollected")
			and obj.Transparency < 1
		then
			local distance = (obj.Position - origin).Magnitude
			if distance <= range then
				table.insert(candidates, { part = obj, distance = distance })
			end
		end
	end

	table.sort(candidates, function(a, b)
		return a.distance < b.distance
	end)

	local result = {}
	for _, candidate in ipairs(candidates) do
		table.insert(result, candidate.part)
		if #result >= maxTargets then
			break
		end
	end
	return result
end

function fireEffectVfx(player, effectName, fromPosition, targetPositions, mutationId)
	if #targetPositions == 0 then
		return
	end

	colorEffectVfxEvent:FireClient(player, {
		Effect = effectName,
		From = fromPosition,
		Targets = targetPositions,
		MutationId = mutationId or "None",
	})
end

local function collectProcTargets(player, targets, range, powerMultiplier, source, mode)
	local total = 0
	local collected = 0
	local positions = {}

	for _, part in ipairs(targets) do
		local position = part.Position
		local ok, awarded = collectBreakable(player, part, {
			maxRange = range,
			skipCooldown = true,
			powerMultiplier = powerMultiplier or 1,
			source = source,
			mode = mode,
		})
		if ok and awarded > 0 then
			table.insert(positions, position)
			collected += 1
			total += awarded
		end
	end

	return collected, total, positions
end

local function advanceBrushStreak(player, toolConfig, root, range)
	if not player or not toolConfig or not root then
		return 0
	end

	local now = os.clock()
	local state = brushStreaks[player]
	if not state or now - (state.lastAt or 0) > 3.25 or state.toolId ~= toolConfig.Id then
		state = { count = 0, lastAt = now, toolId = toolConfig.Id }
		brushStreaks[player] = state
	end
	state.lastAt = now
	state.count += 1

	local threshold = math.max(2, math.floor(tonumber(toolConfig.ActiveTriggerEvery) or 4))
	if state.count < threshold then
		return 0
	end
	state.count = 0

	local effectType = tostring(toolConfig.ActiveEffectType or "Sweep")
	if effectType == "Sweep" or effectType == "" then
		return 0
	end

	local bonusRange = math.min(range + 8, tonumber(toolConfig.MaxServerRange) or range)
	local bonusMultiplier = math.clamp(tonumber(toolConfig.ActiveEffectValue) or 0.35, 0.1, 1)
	local maxBonusTargets = effectType == "Chain" and 2 or 1

	if effectType == "Mark" then
		for _, target in ipairs(findNearbyBreakables(player, root.Position, bonusRange, 3)) do
			markPetPriorityTarget(player, target)
		end
		return 0
	end

	local targets = findNearbyBreakables(player, root.Position, bonusRange, maxBonusTargets)
	local _, awarded, positions = collectProcTargets(player, targets, bonusRange, bonusMultiplier, "brush", "active")
	fireEffectVfx(player, "BrushActive", root.Position, positions, toolConfig.Id)
	return awarded
end

local function tryBrushEffectProcs(player)
	local root = getPlayerRoot(player)
	if not root then
		return 0
	end

	local effects = ColorEffectHandler.CalculateEquippedColorEffects(player)
	local now = os.clock()
	local totalAwarded = 0
	local caps = GameBalance.ColorEffects or {}

	if effects.LightningProcChance > 0 then
		local cooldown = math.max(effects.LightningCooldown or 0, caps.LightningGlobalCooldown or 1)
		if
			(not lastLightningAt[player] or now - lastLightningAt[player] >= cooldown)
			and math.random() < effects.LightningProcChance
		then
			lastLightningAt[player] = now
			local range = math.min(effects.LightningRange, caps.LightningMaxRange or 55)
			local maxTargets = math.clamp(effects.LightningTargets, 1, caps.LightningMaxTargetsPerProc or 4)
			local targets = findNearbyBreakables(player, root.Position, range, maxTargets)
			local _, awarded, positions = collectProcTargets(player, targets, range)
			totalAwarded += awarded
			fireEffectVfx(player, "Lightning", root.Position, positions, effects.SourceMutationId)
		end
	end

	if effects.MagnetProcChance > 0 then
		local cooldown = caps.MagnetGlobalCooldown or 1
		if
			(not lastMagnetAt[player] or now - lastMagnetAt[player] >= cooldown)
			and math.random() < effects.MagnetProcChance
		then
			lastMagnetAt[player] = now
			local range = math.min(effects.MagnetRange, caps.MagnetMaxRange or 55)
			local maxTargets = math.clamp(effects.MagnetTargets, 1, caps.MagnetMaxTargetsPerProc or 5)
			local targets = findNearbyBreakables(player, root.Position, range, maxTargets)
			local _, awarded, positions = collectProcTargets(player, targets, range)
			totalAwarded += awarded
			fireEffectVfx(player, "Magnet", root.Position, positions, effects.SourceMutationId)
		end
	end

	return totalAwarded
end

collectEvent.OnServerEvent:Connect(function(player, part, ...)
	if select("#", ...) > 0 then
		warnUnexpectedClientValuesOnce(player, "CollectColor")
	end

	if GameBalance.Collection and GameBalance.Collection.RequireBrushToCollect then
		collectEvent:FireClient(player, false, 0, "Use your Brush to collect Color.")
		return
	end

	local ok, awarded, message = collectBreakable(player, part)
	if not ok then
		if message == "Coins are not ready." then
			warnCollectionOnce(player, "missing player data", message)
		elseif message == "Invalid target." or message == "That is not color." then
			warnCollectionOnce(player, "blob invalid", message)
		elseif message ~= "Slow down." and message ~= "Already collected." then
			warnCollectionOnce(player, "server rejected request", message)
		end
	end
	collectEvent:FireClient(player, ok, awarded, message)
end)

paintSweepEvent.OnServerEvent:Connect(function(player, toolId, candidates, mode, groundPayload, ...)
	if select("#", ...) > 0 then
		warnUnexpectedClientValuesOnce(player, "PaintToolSweep")
	end

	local tool, toolConfig = getEquippedPaintTool(player)
	if not toolConfig then
		paintSweepEvent:FireClient(player, {
			success = false,
			total = 0,
			collected = 0,
			message = "Equip your Brush first.",
		})
		return
	end

	if tool and toolId and toolConfig.Id ~= toolId then
		paintSweepEvent:FireClient(player, {
			success = false,
			total = 0,
			collected = 0,
			message = "Wrong Brush.",
		})
		return
	end

	if mode == "walk" then
		paintSweepEvent:FireClient(player, {
			success = false,
			total = 0,
			collected = 0,
			message = "Click with your Brush.",
		})
		return
	end
	mode = "sweep"

	local effects = ColorEffectHandler.CalculateEquippedColorEffects(player)
	local toolStats = getToolEffectiveStats(toolConfig)
	local useSpeedMultiplier = math.max(tonumber(toolStats.UseSpeedMultiplier) or 1, 0.01)
	local upgrades = player:FindFirstChild("Upgrades")
	local paintSpeed = upgrades and upgrades:FindFirstChild("PaintSpeed")
	if paintSpeed then
		useSpeedMultiplier *= math.max(tonumber(paintSpeed.Value) or 1, 0.01)
	end
	local groundBrushConfig = (GameBalance.GroundPaint and GameBalance.GroundPaint.Brush) or {}
	local baseSweepCooldown = toolConfig.Cooldown or 0.45
	if type(groundPayload) == "table" then
		baseSweepCooldown = tonumber(toolStats.BrushTickRate)
			or tonumber(toolConfig.BrushTickRate)
			or tonumber(groundBrushConfig.BaseCooldown)
			or baseSweepCooldown
	end
	local cooldown = ((mode == "walk" and WALK_SWEEP_COOLDOWN or baseSweepCooldown) * effects.BrushCooldownMultiplier)
		/ useSpeedMultiplier
	local minimumCooldown = mode == "walk" and 0.1
		or (type(groundPayload) == "table" and tonumber(groundBrushConfig.MinimumCooldown))
		or ((GameBalance.ColorEffects and GameBalance.ColorEffects.MinimumBrushCooldown) or 0.2)
	cooldown = math.max(cooldown, minimumCooldown)

	local now = os.clock()
	local cooldowns = mode == "walk" and lastWalkSweepAt or lastSweepAt
	if cooldowns[player] and now - cooldowns[player] < cooldown then
		return
	end
	cooldowns[player] = now

	if type(candidates) ~= "table" then
		paintSweepEvent:FireClient(player, {
			success = false,
			total = 0,
			collected = 0,
			message = "No Color in range.",
		})
		return
	end

	if mode == "walk" and not canWalkCollectDuringTutorial(player, candidates) then
		return
	end

	local range = getPaintToolRange(player, toolConfig)
	local width = (tonumber(toolConfig.Width) or 7) * (tonumber(toolStats.SweepWidthMultiplier) or 1)
	local brushSize = upgrades and upgrades:FindFirstChild("BrushSize")
	if brushSize then
		width *= math.max(tonumber(brushSize.Value) or 1, 0.1)
	end
	if mode == "walk" then
		range = math.min(WALK_PICKUP_RANGE * (tonumber(toolStats.PickupRadiusMultiplier) or 1), range)
	end
	local maxTargets = mode == "walk" and WALK_MAX_TARGETS or math.clamp(tonumber(toolConfig.MaxTargets) or 8, 1, 18)
	local collected = 0
	local total = 0
	local lastMessage = "No Color in range."
	local seen = {}
	local root = getPlayerRoot(player)

	for _, part in ipairs(candidates) do
		if collected >= maxTargets then
			break
		end
		if typeof(part) == "Instance" and not seen[part] then
			seen[part] = true
			if part:GetAttribute("GemDeposit") then
				continue
			end
			if isGroundContamination(part) then
				continue
			end
			local inRange = mode == "walk" and isInsideWalkPickup(player, part, range)
				or isInsideToolSweep(player, part, range, width)
			if inRange then
				markPetPriorityTarget(player, part)
				local ok, awarded, message = collectBreakable(player, part, {
					maxRange = range,
					skipCooldown = true,
					powerMultiplier = toolStats.CollectPowerMultiplier or toolConfig.PowerMultiplier or 1,
					source = "brush",
					mode = mode,
				})
				lastMessage = message or lastMessage
				if ok and awarded > 0 then
					collected += 1
					total += awarded
				end
			end
		end
	end

	if mode == "sweep" and root then
		local groundCollected, groundAwarded =
			processGroundBrush(player, toolConfig, toolStats, root, range, groundPayload)
		if groundCollected > 0 then
			collected += groundCollected
			total += groundAwarded
			lastMessage = "Ground cleaned."
		end
	end

	local activeAwarded = 0
	if mode == "sweep" and collected > 0 and root then
		activeAwarded = advanceBrushStreak(player, toolConfig, root, range)
	end
	local procAwarded = mode == "sweep" and tryBrushEffectProcs(player) or 0
	total += activeAwarded
	total += procAwarded

	local success = total > 0
	if DEBUG_LOGS and success then
		print(
			"PaintToolSweep: "
				.. player.Name
				.. " broke "
				.. tostring(collected)
				.. " Color blobs for "
				.. tostring(total)
				.. " Coins via "
				.. mode
		)
	end
	paintSweepEvent:FireClient(player, {
		success = success,
		total = total,
		collected = collected,
		message = success and ("+" .. tostring(total) .. " Coins") or lastMessage,
	})
	if success then
		collectEvent:FireClient(player, true, total, "Coins")
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastCollectAt[player] = nil
	lastSweepAt[player] = nil
	lastWalkSweepAt[player] = nil
	lastLightningAt[player] = nil
	lastMagnetAt[player] = nil
	brushStreaks[player] = nil
end)

if isTouchFallbackEnabled() then
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("BasePart") and obj:GetAttribute("BreakableType") then
			hookTouchCollection(obj)
		end
	end

	workspace.DescendantAdded:Connect(function(obj)
		if obj:IsA("BasePart") and obj:GetAttribute("BreakableType") then
			hookTouchCollection(obj)
		end
	end)
end
