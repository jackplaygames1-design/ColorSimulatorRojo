-- Server-owned guided tutorial. This file only tracks/tutorial-gates progress and
-- hooks existing game systems for real cleaning, rewards, hatching, equipping, and travel.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ColorData = require(ReplicatedStorage:WaitForChild("ColorData"))
local PetData = require(ReplicatedStorage:WaitForChild("PetData"))

local Events = ReplicatedStorage:WaitForChild("Events")
local dataDirtyEvent = Events:FindFirstChild("PlayerDataDirty")
local tutorialActionEvent = Events:FindFirstChild("TutorialAction")
if not tutorialActionEvent then
	tutorialActionEvent = Instance.new("RemoteEvent")
	tutorialActionEvent.Name = "TutorialAction"
	tutorialActionEvent.Parent = Events
end

local tutorialPatchClearedEvent = Events:FindFirstChild("TutorialPatchCleared")
if not tutorialPatchClearedEvent then
	tutorialPatchClearedEvent = Instance.new("BindableEvent")
	tutorialPatchClearedEvent.Name = "TutorialPatchCleared"
	tutorialPatchClearedEvent.Parent = Events
end

local tutorialGemBrokenEvent = Events:FindFirstChild("TutorialGemBroken")
if not tutorialGemBrokenEvent then
	tutorialGemBrokenEvent = Instance.new("BindableEvent")
	tutorialGemBrokenEvent.Name = "TutorialGemBroken"
	tutorialGemBrokenEvent.Parent = Events
end

local tutorialHatchSucceededEvent = Events:FindFirstChild("TutorialHatchSucceeded")
if not tutorialHatchSucceededEvent then
	tutorialHatchSucceededEvent = Instance.new("BindableEvent")
	tutorialHatchSucceededEvent.Name = "TutorialHatchSucceeded"
	tutorialHatchSucceededEvent.Parent = Events
end

local tutorialColorEquippedEvent = Events:FindFirstChild("TutorialColorEquipped")
if not tutorialColorEquippedEvent then
	tutorialColorEquippedEvent = Instance.new("BindableEvent")
	tutorialColorEquippedEvent.Name = "TutorialColorEquipped"
	tutorialColorEquippedEvent.Parent = Events
end

local tutorialWorldTraveledEvent = Events:FindFirstChild("TutorialWorldTraveled")
if not tutorialWorldTraveledEvent then
	tutorialWorldTraveledEvent = Instance.new("BindableEvent")
	tutorialWorldTraveledEvent.Name = "TutorialWorldTraveled"
	tutorialWorldTraveledEvent.Parent = Events
end

local tutorialShopEnteredEvent = Events:FindFirstChild("TutorialShopEntered")
if not tutorialShopEnteredEvent then
	tutorialShopEnteredEvent = Instance.new("BindableEvent")
	tutorialShopEnteredEvent.Name = "TutorialShopEntered"
	tutorialShopEnteredEvent.Parent = Events
end

local tutorialDailyQuestsIntroducedEvent = Events:FindFirstChild("TutorialDailyQuestsIntroduced")
if not tutorialDailyQuestsIntroducedEvent then
	tutorialDailyQuestsIntroducedEvent = Instance.new("BindableEvent")
	tutorialDailyQuestsIntroducedEvent.Name = "TutorialDailyQuestsIntroduced"
	tutorialDailyQuestsIntroducedEvent.Parent = Events
end

local RED_PATCH_GOAL = 6
local STEP_COUNT = 14
local FIRST_EGG_ID = "ColorEgg"
local SPAWN_TUTORIAL_EGG_NAME = "SpawnEgg"
local NEXT_WORLD_COLOR = "Orange"

local STAGES = {
	Welcome = {
		step = 1,
		title = "Welcome",
		instruction = "Welcome to Color Simulator!\nLet's learn how to clean zones, collect rewards, hatch Colors, upgrade, and preview new Sectors.",
		hint = "",
		progressValue = "WelcomeStarted",
		goal = 1,
		buttonText = "Start Tutorial",
	},
	MoveAround = {
		step = 2,
		title = "Move Around",
		instruction = "Use WASD or the joystick to move around.",
		hint = "Follow the guide marker when it appears.",
		progressValue = "MovedAround",
		goal = 1,
		buttonText = "",
	},
	CleanSpills = {
		step = 3,
		title = "Clean the Red Spills",
		instruction = "Walk over the small glowing red patches to clean them.",
		hint = "Only the bright red patches count.",
		progressValue = "PatchesCleared",
		goal = RED_PATCH_GOAL,
		buttonText = "",
	},
	EarnCoins = {
		step = 4,
		title = "Earn Coins",
		instruction = "Cleaning red patches gives you coins.",
		hint = "Use coins to hatch new Colors from eggs.",
		progressValue = "CoinsStepDone",
		goal = 1,
		buttonText = "Next",
	},
	CollectGems = {
		step = 5,
		title = "Collect Gems",
		instruction = "Gems randomly spawn around the map.",
		hint = "Break glowing gems to collect them.",
		progressValue = "GemsCollected",
		goal = 1,
		buttonText = "",
	},
	UseGems = {
		step = 6,
		title = "Use Gems for Upgrades",
		instruction = "Gems are used to buy upgrades for your character and your Colors.",
		hint = "Upgrades help you progress faster.",
		progressValue = "GemsStepDone",
		goal = 1,
		buttonText = "Next",
	},
	HatchFirstColor = {
		step = 7,
		title = "Hatch Your First Color",
		instruction = "Follow the arrow to the egg area.",
		hint = "Press Hatch to get your first Color.",
		progressValue = "ColorsHatched",
		goal = 1,
		buttonText = "",
	},
	EquipColor = {
		step = 8,
		title = "Equip Your Color",
		instruction = "Open the Colors menu and equip your new Color.",
		hint = "Equipped Colors help you progress faster.",
		progressValue = "EquippedColors",
		goal = 1,
		buttonText = "",
	},
	LearnUI = {
		step = 9,
		title = "Learn the UI",
		instruction = "These buttons help you play faster.\nLet's quickly go over them.",
		hint = "",
		progressValue = "UITourDone",
		goal = 1,
		buttonText = "Next",
	},
	OpenWorlds = {
		step = 10,
		title = "Open Sectors",
		instruction = "Click the Sector button to see new areas.",
		hint = "Sectors have new zones, better rewards, and new eggs.",
		progressValue = "WorldMenuOpened",
		goal = 1,
		buttonText = "",
	},
	PreviewNextWorld = {
		step = 11,
		title = "Preview Orange Sector",
		instruction = "Click Orange Sector to preview what comes next.",
		hint = "You do not need to travel there yet. Keep clearing Red Area patches first.",
		progressValue = "NextWorldPreviewed",
		goal = 1,
		buttonText = "",
	},
	VisitShop = {
		step = 12,
		title = "Meet Zork",
		instruction = "Go into the shop to meet Zork.",
		hint = "Zork sells brushes and gives daily quests.",
		progressValue = "ShopEntered",
		goal = 1,
		buttonText = "",
	},
	OpenBrushShop = {
		step = 13,
		title = "Open the Brush Shop",
		instruction = "Talk to Zork and open the brush shop.",
		hint = "Better brushes help you clean spills faster.",
		progressValue = "BrushShopOpened",
		goal = 1,
		buttonText = "",
	},
	AskDailyQuests = {
		step = 14,
		title = "Ask About Daily Quests",
		instruction = "Talk to Zork and ask about daily quests.",
		hint = "Daily quests give Gems when you finish and claim them.",
		progressValue = "DailyQuestsIntroduced",
		goal = 1,
		buttonText = "",
	},
	TutorialComplete = {
		step = 14,
		title = "Tutorial Complete",
		instruction = "Nice work!\nYou cleaned your first zone, hatched a Color, previewed Orange Sector, met Zork, opened the brush shop, and unlocked daily quests.",
		hint = "",
		progressValue = "ReadyToFinish",
		goal = 1,
		buttonText = "",
	},
}

local VALID_STAGE = {}
for key in pairs(STAGES) do
	VALID_STAGE[key] = true
end

local countedPatchesByPlayer = {}
local spawnPositions = {}

local function markDirty(player, reason)
	local event = dataDirtyEvent
	if not event or not event.Parent then
		event = Events:FindFirstChild("PlayerDataDirty")
		dataDirtyEvent = event
	end
	if event and event:IsA("BindableEvent") then
		event:Fire(player, reason)
	end
end

local function ensureValue(parent, className, name, defaultValue)
	local value = parent:FindFirstChild(name)
	local created = false
	if not value or value.ClassName ~= className then
		if value then
			value:Destroy()
		end
		value = Instance.new(className)
		value.Name = name
		value.Parent = parent
		created = true
	end
	if created and defaultValue ~= nil then
		value.Value = defaultValue
	end
	return value
end

local function getValue(folder, name)
	return folder and folder:FindFirstChild(name)
end

local function boolValue(folder, name)
	local value = getValue(folder, name)
	return value and value.Value == true
end

local function intValue(folder, name)
	local value = getValue(folder, name)
	return value and tonumber(value.Value) or 0
end

local function setBool(folder, name, newValue)
	local value = getValue(folder, name)
	if value and value.Value ~= (newValue == true) then
		value.Value = newValue == true
	end
end

local function setInt(folder, name, newValue)
	local value = getValue(folder, name)
	if value then
		value.Value = math.floor(tonumber(newValue) or 0)
	end
end

local function setMessage(folder, message)
	local value = getValue(folder, "LastRewardMessage")
	if value then
		value.Value = message or ""
	end
end

local function ensureFolder(player)
	local folder = player:FindFirstChild("TutorialObjectives")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "TutorialObjectives"
		folder.Parent = player
	end

	ensureValue(folder, "BoolValue", "TutorialCompleted", false)
	local stage = ensureValue(folder, "StringValue", "Stage", "Welcome")
	if not VALID_STAGE[stage.Value] then
		stage.Value = "Welcome"
	end
	ensureValue(folder, "IntValue", "StepIndex", 1)
	ensureValue(folder, "IntValue", "StepCount", STEP_COUNT).Value = STEP_COUNT
	ensureValue(folder, "StringValue", "ObjectiveText", STAGES.Welcome.title)
	ensureValue(folder, "StringValue", "InstructionText", STAGES.Welcome.instruction)
	ensureValue(folder, "StringValue", "HintText", STAGES.Welcome.hint)
	ensureValue(folder, "StringValue", "ButtonText", STAGES.Welcome.buttonText)
	ensureValue(folder, "IntValue", "Progress", 0)
	ensureValue(folder, "IntValue", "ProgressGoal", 1)
	ensureValue(folder, "IntValue", "PatchesCleared", 0)
	ensureValue(folder, "IntValue", "GemsCollected", 0)
	ensureValue(folder, "IntValue", "ColorsHatched", 0)
	ensureValue(folder, "IntValue", "EquippedColors", 0)
	ensureValue(folder, "StringValue", "ProgressLabel", "")
	ensureValue(folder, "StringValue", "RemainingLabel", "")
	ensureValue(folder, "StringValue", "TargetType", "")
	ensureValue(folder, "StringValue", "TargetName", "")
	ensureValue(folder, "ObjectValue", "TargetObject", nil)
	ensureValue(folder, "StringValue", "LastRewardMessage", "")

	for _, key in ipairs({
		"WelcomeStarted",
		"MovedAround",
		"CoinsStepDone",
		"GemsStepDone",
		"UITourDone",
		"WorldMenuOpened",
		"TutorialHatchCoinsGranted",
		"NextWorldPreviewed",
		"ShopEntered",
		"ShopOpened",
		"BrushShopOpened",
		"DailyQuestsIntroduced",
		"NextWorldReached",
		"ReadyToFinish",
	}) do
		ensureValue(folder, "BoolValue", key, false)
	end

	return folder
end

local function isTutorialComplete(player)
	local folder = player:FindFirstChild("TutorialObjectives")
	local completed = folder and folder:FindFirstChild("TutorialCompleted")
	return completed and completed.Value == true
end

local function getRoot(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function findRedAreaPart()
	local map = workspace:FindFirstChild("ColorSimulatorMap")
	local redWastelands = map and map:FindFirstChild("RedWastelands")
	local redFloor = redWastelands and redWastelands:FindFirstChild("RedFloor1")
	if redFloor and redFloor:IsA("BasePart") then
		return redFloor
	end

	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("BasePart") and obj:GetAttribute("TutorialRedArea") == true then
			return obj
		end
	end

	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("BasePart")
			and ((obj:GetAttribute("ColorZone") and obj:GetAttribute("ColorType") == "Red")
				or obj.Name == "RedFloor1")
		then
			return obj
		end
	end
	return nil
end

local function isRedSpillPatch(part)
	if typeof(part) ~= "Instance" or not part:IsA("BasePart") then
		return false
	end
	if part:GetAttribute("TutorialColorPatch") == true then
		return true
	end
	return part:GetAttribute("BreakableType") ~= nil
		and part:GetAttribute("ColorType") == "Red"
		and part:GetAttribute("ColorZone") ~= true
end

local function getDynamicGameplayFolder()
	local rootFolder = workspace:FindFirstChild("DynamicGameplay")
	if not rootFolder then
		rootFolder = Instance.new("Folder")
		rootFolder.Name = "DynamicGameplay"
		rootFolder.Parent = workspace
	end
	return rootFolder
end

local function getGemFolder()
	local rootFolder = getDynamicGameplayFolder()
	local folder = rootFolder:FindFirstChild("GemDeposits")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "GemDeposits"
		folder.Parent = rootFolder
	end
	return folder
end

local function findNearestGemCore(player)
	local root = getRoot(player)
	local origin = root and root.Position or Vector3.zero
	local bestCore
	local bestDistance = math.huge
	local folder = getGemFolder()
	for _, model in ipairs(folder:GetChildren()) do
		if model:IsA("Model") and model:GetAttribute("GemDeposit") == true and model:GetAttribute("Broken") ~= true then
			local colorType = model:GetAttribute("ColorType")
			local core = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
			if colorType == "Red" and core and core:GetAttribute("GemDeposit") == true then
				local distance = (core.Position - origin).Magnitude
				if distance < bestDistance then
					bestDistance = distance
					bestCore = core
				end
			end
		end
	end
	return bestCore
end

local function makeTutorialGem(player)
	local root = getRoot(player)
	local redArea = findRedAreaPart()
	local position
	if root then
		position = root.Position + root.CFrame.LookVector * 14 + Vector3.new(0, 2.8, 0)
	elseif redArea then
		position = redArea.Position + Vector3.new(0, redArea.Size.Y * 0.5 + 2.8, 0)
	else
		position = Vector3.new(0, 5, 0)
	end

	local folder = getGemFolder()
	local old = folder:FindFirstChild("TutorialGemDeposit_" .. tostring(player.UserId))
	if old then
		old:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = "TutorialGemDeposit_" .. tostring(player.UserId)
	model:SetAttribute("GemDeposit", true)
	model:SetAttribute("TutorialGem", true)
	model:SetAttribute("ColorType", "Red")
	model:SetAttribute("Health", 2)
	model:SetAttribute("MaxHealth", 2)
	model:SetAttribute("Broken", false)

	local core = Instance.new("Part")
	core.Name = "Core"
	core.Size = Vector3.new(2.4, 2.4, 2.4)
	core.CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(45), math.rad(45))
	core.Shape = Enum.PartType.Block
	core.Color = Color3.fromRGB(55, 255, 110)
	core.Material = Enum.Material.Neon
	core.Anchored = true
	core.CanCollide = false
	core.CanTouch = false
	core.CanQuery = true
	core.CastShadow = false
	core:SetAttribute("GemDeposit", true)
	core:SetAttribute("TutorialGem", true)
	core:SetAttribute("ColorType", "Red")
	core:SetAttribute("Health", 2)
	core:SetAttribute("MaxHealth", 2)
	core.Parent = model
	model.PrimaryPart = core

	local light = Instance.new("PointLight")
	light.Name = "GemGlow"
	light.Color = Color3.fromRGB(80, 255, 130)
	light.Range = 16
	light.Brightness = 2.2
	light.Shadows = false
	light.Parent = core

	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Name = "GemSparkles"
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(Color3.fromRGB(120, 255, 150), Color3.fromRGB(255, 255, 255))
	sparkle.LightEmission = 0.8
	sparkle.Rate = 10
	sparkle.Lifetime = NumberRange.new(0.75, 1.25)
	sparkle.Speed = NumberRange.new(0.3, 1.1)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Parent = core

	model.Parent = folder
	return core
end

local function setTargetObject(folder, object)
	local target = getValue(folder, "TargetObject")
	if target and target:IsA("ObjectValue") then
		target.Value = object
	end
end

local function findEggTarget()
	local spawnEgg = workspace:FindFirstChild(SPAWN_TUTORIAL_EGG_NAME, true)
	if spawnEgg and spawnEgg:IsA("BasePart") then
		spawnEgg:SetAttribute("EggId", FIRST_EGG_ID)
		spawnEgg:SetAttribute("ColorType", "Red")
		spawnEgg:SetAttribute("AreaColor", "Red")
		spawnEgg:SetAttribute("EggStation", true)
		spawnEgg:SetAttribute("TutorialEgg", true)
		spawnEgg:SetAttribute("BakedTutorialEgg", true)
		spawnEgg.CanQuery = true
		return spawnEgg
	end

	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("BasePart") and obj:GetAttribute("EggId") == FIRST_EGG_ID then
			return obj
		end
	end
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("BasePart") and string.find(string.lower(obj.Name), "egg") then
			return obj
		end
	end
	return nil
end

local function findShopTarget()
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("BasePart")
			and obj:GetAttribute("BrushNpc") == true
			and obj:GetAttribute("BrushShop") == true
		then
			return obj
		end
	end
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("BasePart")
			and (obj:GetAttribute("BrushShop") == true
				or obj:GetAttribute("CombinedShop") == true
				or obj:GetAttribute("ShopStation") == true
				or obj.Name == "Shop"
				or obj.Name == "BrushShop")
		then
			return obj
		end
	end
	return nil
end

local function ensureCoinsForFirstEgg(player, folder)
	local egg = PetData.Eggs and PetData.Eggs[FIRST_EGG_ID]
	local cost = egg and tonumber(egg.cost) or 0
	if cost <= 0 then
		return
	end
	if boolValue(folder, "TutorialHatchCoinsGranted") then
		return
	end
	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	if not coins or coins.Value >= cost then
		setBool(folder, "TutorialHatchCoinsGranted", true)
		return
	end
	coins.Value = cost
	setBool(folder, "TutorialHatchCoinsGranted", true)
	setMessage(folder, "Coins ready for your first Color.")
	markDirty(player, "tutorial-hatch-coins")
end

local function getEquippedColorCount(player)
	local petData = player:FindFirstChild("PetData")
	local equippedValue = petData and petData:FindFirstChild("Equipped")
	if not equippedValue or equippedValue.Value == "" then
		return 0
	end
	local count = 0
	for _, key in ipairs(string.split(equippedValue.Value, ",")) do
		if key ~= "" then
			count += 1
		end
	end
	return count
end

local function updateProgress(folder)
	local stageKeyValue = getValue(folder, "Stage")
	local stageKey = stageKeyValue and stageKeyValue.Value or "Welcome"
	local stage = STAGES[stageKey] or STAGES.Welcome
	local progressValue = getValue(folder, "Progress")
	local goalValue = getValue(folder, "ProgressGoal")
	local progressLabel = getValue(folder, "ProgressLabel")
	local remainingLabel = getValue(folder, "RemainingLabel")
	if not progressValue or not goalValue then
		return
	end

	local progress = 0
	if stage.progressValue == "PatchesCleared" then
		progress = math.clamp(intValue(folder, "PatchesCleared"), 0, stage.goal)
	elseif stage.progressValue == "GemsCollected" then
		progress = math.clamp(intValue(folder, "GemsCollected"), 0, stage.goal)
	elseif stage.progressValue == "ColorsHatched" then
		progress = math.clamp(intValue(folder, "ColorsHatched"), 0, stage.goal)
	elseif stage.progressValue == "EquippedColors" then
		progress = math.clamp(intValue(folder, "EquippedColors"), 0, stage.goal)
	else
		progress = boolValue(folder, stage.progressValue) and stage.goal or 0
	end

	goalValue.Value = stage.goal
	progressValue.Value = progress

	if progressLabel then
		if stageKey == "CleanSpills" or stageKey == "CollectGems" then
			progressLabel.Value = "Progress: " .. tostring(progress) .. " / " .. tostring(stage.goal)
		else
			progressLabel.Value = ""
		end
	end
	if remainingLabel then
		remainingLabel.Value = ""
	end
end

local function applyStageTarget(player, folder, stageKey)
	local targetType = getValue(folder, "TargetType")
	local targetName = getValue(folder, "TargetName")
	if targetType then
		targetType.Value = ""
	end
	if targetName then
		targetName.Value = ""
	end
	setTargetObject(folder, nil)

	if stageKey == "CleanSpills" then
		if targetType then
			targetType.Value = "World"
		end
		if targetName then
			targetName.Value = "RedSpill"
		end
	elseif stageKey == "EarnCoins" then
		if targetType then
			targetType.Value = "UI"
		end
		if targetName then
			targetName.Value = "CoinsRow"
		end
	elseif stageKey == "CollectGems" then
		local core = findNearestGemCore(player) or makeTutorialGem(player)
		if targetType then
			targetType.Value = "World"
		end
		if targetName then
			targetName.Value = "GemDeposit"
		end
		setTargetObject(folder, core)
	elseif stageKey == "UseGems" then
		if targetType then
			targetType.Value = "UI"
		end
		if targetName then
			targetName.Value = "GemsRow"
		end
	elseif stageKey == "HatchFirstColor" then
		ensureCoinsForFirstEgg(player, folder)
		if targetType then
			targetType.Value = "World"
		end
		if targetName then
			targetName.Value = "ColorEgg"
		end
		setTargetObject(folder, findEggTarget())
	elseif stageKey == "EquipColor" then
		if targetType then
			targetType.Value = "UI"
		end
		if targetName then
			targetName.Value = "MenuButton"
		end
	elseif stageKey == "LearnUI" then
		if targetType then
			targetType.Value = "UI"
		end
		if targetName then
			targetName.Value = "UITour"
		end
	elseif stageKey == "OpenWorlds" then
		if targetType then
			targetType.Value = "UI"
		end
		if targetName then
			targetName.Value = "WorldButton"
		end
	elseif stageKey == "PreviewNextWorld" then
		if targetType then
			targetType.Value = "UI"
		end
		if targetName then
			targetName.Value = "WorldRow_" .. NEXT_WORLD_COLOR
		end
	elseif stageKey == "VisitShop" then
		if targetType then
			targetType.Value = "World"
		end
		if targetName then
			targetName.Value = "BrushShop"
		end
		setTargetObject(folder, findShopTarget())
	elseif stageKey == "OpenBrushShop" or stageKey == "AskDailyQuests" then
		if targetType then
			targetType.Value = "World"
		end
		if targetName then
			targetName.Value = "Zork"
		end
		setTargetObject(folder, findShopTarget())
	else
		player:SetAttribute("TutorialFreeWorldTravel", false)
	end
end

local function setStage(player, folder, stageKey)
	local stage = STAGES[stageKey] or STAGES.Welcome
	local stageValue = getValue(folder, "Stage")
	local changed = not stageValue or stageValue.Value ~= stageKey
	if stageValue then
		stageValue.Value = stageKey
	end

	local stepIndex = getValue(folder, "StepIndex")
	local stepCount = getValue(folder, "StepCount")
	local objectiveText = getValue(folder, "ObjectiveText")
	local instructionText = getValue(folder, "InstructionText")
	local hintText = getValue(folder, "HintText")
	local buttonText = getValue(folder, "ButtonText")
	local progressGoal = getValue(folder, "ProgressGoal")

	if stepIndex then
		stepIndex.Value = stage.step
	end
	if stepCount then
		stepCount.Value = STEP_COUNT
	end
	if objectiveText then
		objectiveText.Value = stage.title
	end
	if instructionText then
		instructionText.Value = stage.instruction
	end
	if hintText then
		hintText.Value = stage.hint
	end
	if buttonText then
		buttonText.Value = stage.buttonText
	end
	if progressGoal then
		progressGoal.Value = stage.goal
	end
	if changed then
		applyStageTarget(player, folder, stageKey)
	else
		local targetObject = getValue(folder, "TargetObject")
		if stageKey == "CollectGems" and (not targetObject or not targetObject.Value or not targetObject.Value.Parent) then
			applyStageTarget(player, folder, stageKey)
		elseif stageKey == "HatchFirstColor" then
			ensureCoinsForFirstEgg(player, folder)
			if targetObject and (not targetObject.Value or not targetObject.Value.Parent) then
				setTargetObject(folder, findEggTarget())
			end
		elseif stageKey == "VisitShop" then
			if targetObject and (not targetObject.Value or not targetObject.Value.Parent) then
				setTargetObject(folder, findShopTarget())
			end
		elseif stageKey == "OpenBrushShop" or stageKey == "AskDailyQuests" then
			if targetObject and (not targetObject.Value or not targetObject.Value.Parent) then
				setTargetObject(folder, findShopTarget())
			end
		end
	end
end

local function refreshStage(player)
	local folder = ensureFolder(player)
	if isTutorialComplete(player) then
		player:SetAttribute("TutorialFreeWorldTravel", false)
		return
	end

	local currentStageValue = getValue(folder, "Stage")
	if currentStageValue and currentStageValue.Value == "TutorialComplete" then
		setStage(player, folder, "TutorialComplete")
		updateProgress(folder)
		return
	end

	local stageKey
	if not boolValue(folder, "WelcomeStarted") then
		stageKey = "Welcome"
	elseif not boolValue(folder, "MovedAround") then
		stageKey = "MoveAround"
	elseif intValue(folder, "PatchesCleared") < RED_PATCH_GOAL then
		stageKey = "CleanSpills"
	elseif not boolValue(folder, "CoinsStepDone") then
		stageKey = "EarnCoins"
	elseif intValue(folder, "GemsCollected") < 1 then
		stageKey = "CollectGems"
	elseif not boolValue(folder, "GemsStepDone") then
		stageKey = "UseGems"
	elseif intValue(folder, "ColorsHatched") < 1 then
		stageKey = "HatchFirstColor"
	elseif intValue(folder, "EquippedColors") < 1 then
		stageKey = "EquipColor"
	elseif not boolValue(folder, "UITourDone") then
		stageKey = "LearnUI"
	elseif not boolValue(folder, "WorldMenuOpened") then
		stageKey = "OpenWorlds"
	elseif not boolValue(folder, "NextWorldPreviewed") then
		stageKey = "PreviewNextWorld"
	elseif not boolValue(folder, "ShopEntered") then
		stageKey = "VisitShop"
	elseif not boolValue(folder, "BrushShopOpened") then
		stageKey = "OpenBrushShop"
	elseif not boolValue(folder, "DailyQuestsIntroduced") then
		stageKey = "AskDailyQuests"
	else
		stageKey = "TutorialComplete"
		setBool(folder, "ReadyToFinish", true)
	end

	setStage(player, folder, stageKey)
	updateProgress(folder)
end

local function completeTutorial(player, skipped)
	local folder = ensureFolder(player)
	local completed = getValue(folder, "TutorialCompleted")
	if completed then
		completed.Value = true
	end
	for _, key in ipairs({
		"WelcomeStarted",
		"MovedAround",
		"CoinsStepDone",
		"GemsStepDone",
		"UITourDone",
		"WorldMenuOpened",
		"TutorialHatchCoinsGranted",
		"NextWorldPreviewed",
		"ShopEntered",
		"ShopOpened",
		"BrushShopOpened",
		"DailyQuestsIntroduced",
		"NextWorldReached",
		"ReadyToFinish",
	}) do
		setBool(folder, key, true)
	end
	setInt(folder, "PatchesCleared", math.max(intValue(folder, "PatchesCleared"), RED_PATCH_GOAL))
	setInt(folder, "GemsCollected", math.max(intValue(folder, "GemsCollected"), 1))
	setInt(folder, "ColorsHatched", math.max(intValue(folder, "ColorsHatched"), 1))
	setInt(folder, "EquippedColors", math.max(intValue(folder, "EquippedColors"), 1))
	setStage(player, folder, "TutorialComplete")
	updateProgress(folder)
	player:SetAttribute("TutorialFreeWorldTravel", false)
	setTargetObject(folder, nil)
	setMessage(folder, skipped and "Tutorial skipped." or "Tutorial complete!")
	markDirty(player, skipped and "tutorial-skipped" or "tutorial-completed")
end

local function getCurrentStage(player)
	local folder = player:FindFirstChild("TutorialObjectives")
	local stage = folder and folder:FindFirstChild("Stage")
	return stage and stage.Value or nil
end

local function handleTutorialAction(player, action)
	if type(action) ~= "string" then
		return
	end
	local folder = ensureFolder(player)
	if action == "SkipTutorial" then
		completeTutorial(player, true)
		return
	end
	if isTutorialComplete(player) then
		return
	end

	local stage = getCurrentStage(player)
	if action == "StartTutorial" and stage == "Welcome" then
		setBool(folder, "WelcomeStarted", true)
		setMessage(folder, "")
	elseif action == "CoinsStepDone" and stage == "EarnCoins" then
		setBool(folder, "CoinsStepDone", true)
	elseif action == "GemsStepDone" and stage == "UseGems" then
		setBool(folder, "GemsStepDone", true)
	elseif action == "UITourDone" and stage == "LearnUI" then
		setBool(folder, "UITourDone", true)
	elseif action == "WorldMenuOpened" and stage == "OpenWorlds" then
		setBool(folder, "WorldMenuOpened", true)
	elseif action == "NextWorldPreviewed" and stage == "PreviewNextWorld" then
		setBool(folder, "NextWorldPreviewed", true)
		setMessage(folder, "Sector previewed. Visit the shop next.")
	elseif (action == "BrushShopOpened" or action == "ShopOpened") and stage == "OpenBrushShop" then
		setBool(folder, "BrushShopOpened", true)
		setBool(folder, "ShopOpened", true)
		setMessage(folder, "Brush shop found. Ask Zork about quests next.")
	elseif action == "DailyQuestsIntroduced" and stage == "AskDailyQuests" then
		setBool(folder, "DailyQuestsIntroduced", true)
		setMessage(folder, "Daily quests unlocked!")
		completeTutorial(player, false)
		return
	elseif action == "ShopOpened" and stage == "VisitShop" then
		setBool(folder, "ShopEntered", true)
		setBool(folder, "ShopOpened", true)
	elseif action == "FinishTutorial" and stage == "TutorialComplete" then
		completeTutorial(player, false)
		return
	end

	refreshStage(player)
	markDirty(player, "tutorial-progress")
end

tutorialActionEvent.OnServerEvent:Connect(handleTutorialAction)

tutorialPatchClearedEvent.Event:Connect(function(player, colorType, awardedCoins, part)
	if not player or not player:IsA("Player") or colorType ~= "Red" then
		return
	end

	local folder = ensureFolder(player)
	if isTutorialComplete(player) then
		return
	end
	if getCurrentStage(player) ~= "CleanSpills" then
		return
	end
	if not isRedSpillPatch(part) then
		return
	end

	local counted = countedPatchesByPlayer[player]
	if not counted then
		counted = {}
		countedPatchesByPlayer[player] = counted
	end
	if counted[part] then
		return
	end
	counted[part] = true

	local patches = getValue(folder, "PatchesCleared")
	if patches then
		patches.Value = math.clamp(patches.Value + 1, 0, RED_PATCH_GOAL)
	end

	local count = intValue(folder, "PatchesCleared")
	if count >= RED_PATCH_GOAL then
		setMessage(folder, "Red zone cleared!")
	else
		setMessage(folder, "+" .. tostring(math.floor(tonumber(awardedCoins) or 0)) .. " Coins")
	end

	refreshStage(player)
	markDirty(player, "tutorial-red-spills")
end)

tutorialGemBrokenEvent.Event:Connect(function(player, reward)
	if not player or not player:IsA("Player") or isTutorialComplete(player) then
		return
	end
	if getCurrentStage(player) ~= "CollectGems" then
		return
	end
	local folder = ensureFolder(player)
	setInt(folder, "GemsCollected", 1)
	setMessage(folder, "Gem collected!")
	refreshStage(player)
	markDirty(player, "tutorial-gem")
end)

tutorialHatchSucceededEvent.Event:Connect(function(player)
	if not player or not player:IsA("Player") or isTutorialComplete(player) then
		return
	end
	if getCurrentStage(player) ~= "HatchFirstColor" then
		return
	end
	local folder = ensureFolder(player)
	setInt(folder, "ColorsHatched", 1)
	setMessage(folder, "Color hatched!")
	refreshStage(player)
	markDirty(player, "tutorial-hatch")
end)

tutorialColorEquippedEvent.Event:Connect(function(player)
	if not player or not player:IsA("Player") or isTutorialComplete(player) then
		return
	end
	if getCurrentStage(player) ~= "EquipColor" then
		return
	end
	local folder = ensureFolder(player)
	if getEquippedColorCount(player) > 0 then
		setInt(folder, "EquippedColors", 1)
		setMessage(folder, "Color equipped!")
		refreshStage(player)
		markDirty(player, "tutorial-equip")
	end
end)

tutorialWorldTraveledEvent.Event:Connect(function(player, colorType)
	if not player or not player:IsA("Player") or isTutorialComplete(player) then
		return
	end
	if getCurrentStage(player) ~= "PreviewNextWorld" then
		return
	end
	if colorType == "Red" then
		return
	end
	local folder = ensureFolder(player)
	setBool(folder, "NextWorldPreviewed", true)
	setMessage(folder, "Sector previewed. Visit the shop next.")
	refreshStage(player)
	markDirty(player, "tutorial-world-preview")
end)

tutorialShopEnteredEvent.Event:Connect(function(player)
	if not player or not player:IsA("Player") or isTutorialComplete(player) then
		return
	end
	if getCurrentStage(player) ~= "VisitShop" then
		return
	end
	local folder = ensureFolder(player)
	setBool(folder, "ShopEntered", true)
	setMessage(folder, "Talk to Zork inside the shop.")
	refreshStage(player)
	markDirty(player, "tutorial-shop-entered")
end)

tutorialDailyQuestsIntroducedEvent.Event:Connect(function(player)
	if not player or not player:IsA("Player") or isTutorialComplete(player) then
		return
	end
	if getCurrentStage(player) ~= "AskDailyQuests" then
		return
	end
	local folder = ensureFolder(player)
	setBool(folder, "DailyQuestsIntroduced", true)
	setMessage(folder, "Daily quests unlocked!")
	completeTutorial(player, false)
end)

Players.PlayerAdded:Connect(function(player)
	ensureFolder(player)

	player.CharacterAdded:Connect(function()
		task.wait(0.25)
		local root = getRoot(player)
		if root then
			spawnPositions[player] = root.Position
		end
		if not isTutorialComplete(player) then
			refreshStage(player)
		end
	end)

	task.defer(function()
		player:WaitForChild("ColorStorage", 15)
		player:WaitForChild("leaderstats", 15)
		player:WaitForChild("PetData", 15)
		refreshStage(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	countedPatchesByPlayer[player] = nil
	spawnPositions[player] = nil
	local gem = getGemFolder():FindFirstChild("TutorialGemDeposit_" .. tostring(player.UserId))
	if gem then
		gem:Destroy()
	end
end)

task.spawn(function()
	while true do
		task.wait(0.35)
		for _, player in ipairs(Players:GetPlayers()) do
			if not isTutorialComplete(player) then
				local folder = ensureFolder(player)
				local stage = getCurrentStage(player)
				local changed = false
				local root = getRoot(player)

				if root and not spawnPositions[player] then
					spawnPositions[player] = root.Position
				end

				if stage == "MoveAround" and root and not boolValue(folder, "MovedAround") then
					local startPosition = spawnPositions[player] or root.Position
					if (root.Position - startPosition).Magnitude >= 8 then
						setBool(folder, "MovedAround", true)
						setMessage(folder, "Nice movement.")
						changed = true
					end
				elseif stage == "EquipColor" then
					if getEquippedColorCount(player) > 0 and intValue(folder, "EquippedColors") < 1 then
						setInt(folder, "EquippedColors", 1)
						setMessage(folder, "Color equipped!")
						changed = true
					end
				elseif stage == "CollectGems" then
					local targetObject = getValue(folder, "TargetObject")
					if not targetObject or not targetObject.Value or not targetObject.Value.Parent then
						applyStageTarget(player, folder, "CollectGems")
					end
				elseif stage == "HatchFirstColor" then
					ensureCoinsForFirstEgg(player, folder)
				elseif stage == "VisitShop" then
					local targetObject = getValue(folder, "TargetObject")
					if not targetObject or not targetObject.Value or not targetObject.Value.Parent then
						applyStageTarget(player, folder, "VisitShop")
					end
				elseif stage == "OpenBrushShop" or stage == "AskDailyQuests" then
					local targetObject = getValue(folder, "TargetObject")
					if not targetObject or not targetObject.Value or not targetObject.Value.Parent then
						applyStageTarget(player, folder, stage)
					end
				end

				if changed then
					refreshStage(player)
					markDirty(player, "tutorial-progress")
				end
			end
		end
	end
end)
