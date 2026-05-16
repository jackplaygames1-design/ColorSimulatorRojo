-- Studio-only helper for authoring editable egg hatch prompts in Workspace.
-- Run from Studio edit mode:
-- require(game.ReplicatedStorage.StudioEggPromptBuilder).Update()
-- Editable MainHUD layer:
-- require(game.ReplicatedStorage.StudioEggPromptBuilder).BuildUI()
-- Both:
-- require(game.ReplicatedStorage.StudioEggPromptBuilder).BuildAll()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local PetData = require(ReplicatedStorage:WaitForChild("PetData"))

local Builder = {}

local DARK = Color3.fromRGB(44, 47, 58)
local WHITE = Color3.fromRGB(255, 255, 255)
local SPAWN_EGG_NAME = "SpawnEgg"
local SPAWN_EGG_ID = "ColorEgg"
local SPAWN_EGG_COLOR = "Red"
local SPAWN_TEMPLATE_EGG_ID = "OrangeEgg"
local MAX_HATCH_EFFECT_SPARKS = 96

local function formatNumber(value)
	value = tonumber(value) or 0
	if value >= 1000000 then
		return string.format("%.1fM", value / 1000000):gsub("%.0M", "M")
	elseif value >= 1000 then
		return string.format("%.1fK", value / 1000):gsub("%.0K", "K")
	end
	return tostring(math.floor(value))
end

local function findOrCreate(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance
end

local function canEditInStudio(actionName)
	if not RunService:IsStudio() then
		warn("StudioEggPromptBuilder." .. actionName .. " can only run in Roblox Studio.")
		return false
	end
	if RunService:IsRunning() then
		warn("StudioEggPromptBuilder." .. actionName .. " should be run in edit mode, not during Play.")
		return false
	end
	return true
end

local function applyCorner(instance, radius)
	local corner = instance:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
	return corner
end

local function applyStroke(instance, color, thickness)
	local stroke = instance:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Parent = instance
	return stroke
end

local function text(parent, name, value, position, size, font, textColor)
	local label = findOrCreate(parent, "TextLabel", name)
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = font
	label.Text = value
	label.TextColor3 = textColor
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent
	return label
end

local function findEggId(instance)
	local current = instance
	while current and current ~= Workspace do
		local eggId = current:GetAttribute("EggId")
		if eggId and PetData.Eggs[eggId] then
			return eggId
		end
		current = current.Parent
	end
	return nil
end

local function isDebugAppearanceObject(obj)
	return obj and obj:FindFirstAncestor("PetAppearanceStudio") ~= nil
end

local function getBestPart(root)
	if root:IsA("BasePart") then
		return root
	end
	if root:IsA("Model") then
		local promptPart = root:FindFirstChild("EggPromptPart", true)
		return root.PrimaryPart
			or (promptPart and promptPart:IsA("BasePart") and promptPart or nil)
			or root:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function getObjectPivot(object)
	if object:IsA("Model") then
		return object:GetPivot()
	elseif object:IsA("BasePart") then
		return object.CFrame
	end
	return CFrame.new()
end

local function clearGeneratedOrPreviewGui(object)
	for _, descendant in ipairs(object:GetDescendants()) do
		if
			descendant:GetAttribute("PreviewOnly") == true
			or descendant.Name == "PreviewLabel"
			or descendant.Name == "EggOptions"
		then
			descendant:Destroy()
		end
	end
end

local function applyEggAttributes(object, eggId, colorType, tutorialEgg)
	if object:IsA("Model") then
		object:SetAttribute("EggId", eggId)
		object:SetAttribute("ColorType", colorType)
		object:SetAttribute("AreaColor", colorType)
		object:SetAttribute("EggStation", true)
		if tutorialEgg then
			object:SetAttribute("TutorialEgg", true)
			object:SetAttribute("BakedTutorialEgg", true)
		end
	end

	for _, descendant in ipairs(object:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant:SetAttribute("EggId", eggId)
			descendant:SetAttribute("ColorType", colorType)
			descendant:SetAttribute("AreaColor", colorType)
			descendant:SetAttribute("EggStation", true)
			descendant:SetAttribute("ColorZone", false)
			descendant:SetAttribute("ColorBlobSpawn", false)
			descendant.CanCollide = true
			descendant.CanTouch = false
			descendant.CanQuery = true
			if tutorialEgg then
				descendant:SetAttribute("TutorialEgg", true)
				descendant:SetAttribute("BakedTutorialEgg", true)
			end
		end
	end

	if object:IsA("BasePart") then
		object:SetAttribute("EggId", eggId)
		object:SetAttribute("ColorType", colorType)
		object:SetAttribute("AreaColor", colorType)
		object:SetAttribute("EggStation", true)
		object:SetAttribute("ColorZone", false)
		object:SetAttribute("ColorBlobSpawn", false)
		object.CanCollide = true
		object.CanTouch = false
		object.CanQuery = true
		if tutorialEgg then
			object:SetAttribute("TutorialEgg", true)
			object:SetAttribute("BakedTutorialEgg", true)
		end
	end
end

local function ensureEggPrompt(holder)
	local prompt = holder:FindFirstChild("EggShopPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "EggShopPrompt"
		prompt.Parent = holder
	end
	prompt.ActionText = "Hatch"
	prompt.ObjectText = "Egg"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = math.max(prompt.MaxActivationDistance, 18)
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt:SetAttribute("EggShopPrompt", true)
	return prompt
end

local function getPetAppearanceEggTemplate(eggId)
	local source = Workspace:FindFirstChild("PetAppearanceStudio")
	local eggFolder = source and source:FindFirstChild(eggId)
	local eggModel = eggFolder and eggFolder:FindFirstChild("EggModel")
	if eggModel and (eggModel:IsA("Model") or eggModel:IsA("BasePart")) then
		return eggModel
	end

	local petModels = ReplicatedStorage:FindFirstChild("PetModels")
	local eggModels = petModels and petModels:FindFirstChild("EggModels")
	local published = eggModels and eggModels:FindFirstChild(eggId)
	if published and (published:IsA("Model") or published:IsA("BasePart")) then
		return published
	end

	return nil
end

local function getSpawnEggTemplate()
	return getPetAppearanceEggTemplate(SPAWN_TEMPLATE_EGG_ID) or getPetAppearanceEggTemplate(SPAWN_EGG_ID)
end

local function cloneAsModel(template)
	local clone = template:Clone()
	if clone:IsA("Model") then
		return clone
	end

	local model = Instance.new("Model")
	model.Name = template.Name
	clone.Parent = model
	model.PrimaryPart = clone
	return model
end

local function findSpawnEggObject()
	local direct = Workspace:FindFirstChild(SPAWN_EGG_NAME, true)
	if direct and (direct:IsA("Model") or direct:IsA("BasePart")) and not isDebugAppearanceObject(direct) then
		return direct
	end

	for _, obj in ipairs(Workspace:GetDescendants()) do
		if
			(obj:IsA("Model") or obj:IsA("BasePart"))
			and not isDebugAppearanceObject(obj)
			and (obj:GetAttribute("TutorialEgg") == true or obj:GetAttribute("BakedTutorialEgg") == true)
		then
			return obj
		end
	end

	for _, obj in ipairs(Workspace:GetDescendants()) do
		if
			(obj:IsA("Model") or obj:IsA("BasePart"))
			and not isDebugAppearanceObject(obj)
			and obj:GetAttribute("EggId") == SPAWN_EGG_ID
		then
			return obj
		end
	end

	return nil
end

local function replaceSpawnEggModel()
	local existing = findSpawnEggObject()
	local template = getSpawnEggTemplate()
	if not existing or not template then
		return nil, false
	end

	local parent = existing.Parent
	local pivot = getObjectPivot(existing)
	local replacement = cloneAsModel(template)
	replacement.Name = SPAWN_EGG_NAME
	clearGeneratedOrPreviewGui(replacement)
	applyEggAttributes(replacement, SPAWN_EGG_ID, SPAWN_EGG_COLOR, true)
	replacement.Parent = parent

	local primary = getBestPart(replacement)
	if primary then
		replacement.PrimaryPart = primary
		replacement:PivotTo(pivot)
		ensureEggPrompt(primary)
	end

	existing:Destroy()
	return primary, true
end

local function isEggRoot(obj)
	if not (obj:IsA("Model") or obj:IsA("BasePart")) then
		return false
	end
	if obj.Name == "PetAppearanceStudio" or obj:FindFirstAncestor("PetAppearanceStudio") then
		return false
	end
	if obj:IsA("BasePart") then
		local modelAncestor = obj:FindFirstAncestorWhichIsA("Model")
		if modelAncestor and findEggId(modelAncestor) then
			return false
		end
	end
	if obj:GetAttribute("EggPromptAuthored") == true then
		return true
	end
	return findEggId(obj) ~= nil and (obj:GetAttribute("EggStation") == true or obj:GetAttribute("EggId") ~= nil)
end

local function setPromptText(parent, name, value)
	local label = parent and parent:FindFirstChild(name, true)
	if label and (label:IsA("TextLabel") or label:IsA("TextButton") or label:IsA("TextBox")) then
		label.Text = tostring(value or "")
	end
end

local function updatePromptTexts(gui, eggId)
	local egg = PetData.Eggs[eggId]
	local displayName = egg and egg.displayName or tostring(eggId or "Egg")
	local costText = egg and (formatNumber(egg.cost or 0) .. " Coins") or ""

	setPromptText(gui, "Title", string.upper(displayName))
	setPromptText(gui, "MainTitle", "EGG")
	setPromptText(gui, "Cost", costText)
	setPromptText(gui, "Key", "E")

	local openOption = gui and gui:FindFirstChild("OpenOption", true)
	setPromptText(openOption, "Label", "HATCH")
end

local function ensureTextSizeLimit(label, minSize, maxSize)
	local sizeLimit = label:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
	sizeLimit.MinTextSize = minSize
	sizeLimit.MaxTextSize = maxSize
	sizeLimit.Parent = label
	return sizeLimit
end

local function configureHatchText(parent, name, value, position, size, textSize, color)
	local label = findOrCreate(parent, "TextLabel", name)
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.LuckiestGuy
	label.TextSize = textSize
	label.TextScaled = true
	label.TextColor3 = color or WHITE
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = DARK
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Text = value
	label.ZIndex = math.max(label.ZIndex, 911)
	ensureTextSizeLimit(label, 10, textSize)
	return label
end

local function configureHatchAnimationUi(layer)
	local overlay = findOrCreate(layer, "Frame", "HatchOverlay")
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.Position = UDim2.fromScale(0, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(12, 16, 24)
	overlay.BackgroundTransparency = 0.02
	overlay.BorderSizePixel = 0
	overlay.Visible = false
	overlay.ZIndex = 850
	overlay:SetAttribute("EditableHatchAnimation", true)
	overlay:SetAttribute("UsesDefaultHatchLayout", true)

	local hatchEgg = findOrCreate(overlay, "Frame", "HatchEgg")
	hatchEgg.Size = UDim2.fromOffset(140, 180)
	hatchEgg.AnchorPoint = Vector2.new(0.5, 0.5)
	hatchEgg.Position = UDim2.fromScale(0.5, 0.46)
	hatchEgg.BackgroundColor3 = Color3.fromRGB(255, 236, 220)
	hatchEgg.BorderSizePixel = 0
	hatchEgg.Visible = false
	hatchEgg.ZIndex = 900
	hatchEgg:SetAttribute("UsesDefaultHatchLayout", true)
	applyCorner(hatchEgg, 999)
	applyStroke(hatchEgg, WHITE, 5)

	local viewport = findOrCreate(overlay, "ViewportFrame", "HatchViewport")
	viewport.Size = UDim2.fromOffset(360, 300)
	viewport.AnchorPoint = Vector2.new(0.5, 0.5)
	viewport.Position = UDim2.fromScale(0.5, 0.45)
	viewport.BackgroundTransparency = 1
	viewport.Visible = false
	viewport.ZIndex = 900
	viewport:SetAttribute("UsesDefaultHatchLayout", true)

	local world = findOrCreate(viewport, "WorldModel", "HatchWorld")
	world.Parent = viewport
	local camera = findOrCreate(viewport, "Camera", "HatchCamera")
	camera.CFrame = CFrame.new(0, 1.2, 8) * CFrame.Angles(math.rad(-7), 0, 0)
	camera.FieldOfView = 34
	viewport.CurrentCamera = camera

	local hatchText = configureHatchText(
		overlay,
		"HatchText",
		"HATCHING...",
		UDim2.fromScale(0.5, 0.65),
		UDim2.fromOffset(420, 64),
		34,
		WHITE
	)
	hatchText.AnchorPoint = Vector2.new(0.5, 0.5)
	hatchText.TextXAlignment = Enum.TextXAlignment.Center
	hatchText.ZIndex = 905
	hatchText:SetAttribute("UsesDefaultHatchLayout", true)

	local rarityFlash = findOrCreate(overlay, "Frame", "RarityFlash")
	rarityFlash.Size = UDim2.fromScale(1, 1)
	rarityFlash.Position = UDim2.fromScale(0, 0)
	rarityFlash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	rarityFlash.BackgroundTransparency = 1
	rarityFlash.BorderSizePixel = 0
	rarityFlash.Visible = false
	rarityFlash.ZIndex = 890
	rarityFlash:SetAttribute("EditableHatchEffect", true)
	rarityFlash:SetAttribute("UsesDefaultHatchLayout", true)

	local rarityBanner = configureHatchText(
		overlay,
		"RarityBanner",
		"RARE HATCH!",
		UDim2.fromScale(0.5, 0.18),
		UDim2.fromOffset(520, 72),
		42,
		Color3.fromRGB(255, 220, 80)
	)
	rarityBanner.AnchorPoint = Vector2.new(0.5, 0.5)
	rarityBanner.TextXAlignment = Enum.TextXAlignment.Center
	rarityBanner.Visible = false
	rarityBanner.ZIndex = 930
	rarityBanner:SetAttribute("EditableHatchEffect", true)

	local cutsceneBackdrop = findOrCreate(overlay, "Frame", "RngCutsceneBackdrop")
	cutsceneBackdrop.Size = UDim2.fromScale(1, 1)
	cutsceneBackdrop.Position = UDim2.fromScale(0, 0)
	cutsceneBackdrop.BackgroundColor3 = Color3.fromRGB(6, 8, 15)
	cutsceneBackdrop.BackgroundTransparency = 1
	cutsceneBackdrop.BorderSizePixel = 0
	cutsceneBackdrop.Visible = false
	cutsceneBackdrop.ZIndex = 886
	cutsceneBackdrop:SetAttribute("EditableHatchCutscene", true)
	cutsceneBackdrop:SetAttribute("UsesDefaultHatchLayout", true)

	local cutsceneShockwave = findOrCreate(overlay, "Frame", "RngCutsceneShockwave")
	cutsceneShockwave.AnchorPoint = Vector2.new(0.5, 0.5)
	cutsceneShockwave.Size = UDim2.fromOffset(80, 80)
	cutsceneShockwave.Position = UDim2.fromScale(0.5, 0.45)
	cutsceneShockwave.BackgroundColor3 = WHITE
	cutsceneShockwave.BackgroundTransparency = 1
	cutsceneShockwave.BorderSizePixel = 0
	cutsceneShockwave.Visible = false
	cutsceneShockwave.ZIndex = 913
	cutsceneShockwave:SetAttribute("EditableHatchCutscene", true)
	cutsceneShockwave:SetAttribute("UsesDefaultHatchLayout", true)
	applyCorner(cutsceneShockwave, 999)
	local cutsceneShockwaveStroke = applyStroke(cutsceneShockwave, WHITE, 5)
	cutsceneShockwaveStroke.Transparency = 1

	local cutsceneTitle = configureHatchText(
		overlay,
		"RngCutsceneTitle",
		"INSANE HATCH!",
		UDim2.fromScale(0.5, 0.23),
		UDim2.fromOffset(760, 84),
		58,
		WHITE
	)
	cutsceneTitle.AnchorPoint = Vector2.new(0.5, 0.5)
	cutsceneTitle.TextXAlignment = Enum.TextXAlignment.Center
	cutsceneTitle.Visible = false
	cutsceneTitle.ZIndex = 935
	cutsceneTitle:SetAttribute("EditableHatchCutscene", true)

	local cutsceneSubtitle = configureHatchText(
		overlay,
		"RngCutsceneSubtitle",
		"A rare Color is breaking out",
		UDim2.fromScale(0.5, 0.31),
		UDim2.fromOffset(660, 48),
		28,
		Color3.fromRGB(230, 240, 255)
	)
	cutsceneSubtitle.AnchorPoint = Vector2.new(0.5, 0.5)
	cutsceneSubtitle.Font = Enum.Font.GothamBlack
	cutsceneSubtitle.TextXAlignment = Enum.TextXAlignment.Center
	cutsceneSubtitle.TextStrokeTransparency = 0.35
	cutsceneSubtitle.Visible = false
	cutsceneSubtitle.ZIndex = 935
	cutsceneSubtitle:SetAttribute("EditableHatchCutscene", true)

	local effectBurst = findOrCreate(overlay, "Frame", "EffectBurst")
	effectBurst.Size = UDim2.fromScale(1, 1)
	effectBurst.Position = UDim2.fromScale(0, 0)
	effectBurst.BackgroundTransparency = 1
	effectBurst.BorderSizePixel = 0
	effectBurst.Visible = true
	effectBurst.ZIndex = 912
	effectBurst:SetAttribute("EditableHatchEffect", true)
	effectBurst:SetAttribute("UsesDefaultHatchLayout", true)
	for index = 1, MAX_HATCH_EFFECT_SPARKS do
		local spark = findOrCreate(effectBurst, "Frame", "Spark" .. tostring(index))
		spark.AnchorPoint = Vector2.new(0.5, 0.5)
		spark.Size = UDim2.fromOffset(10, 10)
		spark.Position = UDim2.fromScale(0.5, 0.46)
		spark.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		spark.BackgroundTransparency = 1
		spark.BorderSizePixel = 0
		spark.Visible = false
		spark.ZIndex = 912
		spark:SetAttribute("EditableHatchEffect", true)
		applyCorner(spark, 999)
	end

	local stopAuto = findOrCreate(overlay, "TextButton", "StopAutoHatch")
	stopAuto.AnchorPoint = Vector2.new(0.5, 0.5)
	stopAuto.Size = UDim2.fromOffset(170, 44)
	stopAuto.Position = UDim2.fromScale(0.5, 0.76)
	stopAuto.BackgroundColor3 = Color3.fromRGB(255, 120, 145)
	stopAuto.BorderSizePixel = 0
	stopAuto.AutoButtonColor = false
	stopAuto.Font = Enum.Font.LuckiestGuy
	stopAuto.TextSize = 17
	stopAuto.TextColor3 = WHITE
	stopAuto.TextStrokeTransparency = 0
	stopAuto.TextStrokeColor3 = DARK
	stopAuto.Text = "STOP AUTO"
	stopAuto.Visible = false
	stopAuto.ZIndex = 920
	stopAuto:SetAttribute("UsesDefaultHatchLayout", true)
	applyCorner(stopAuto, 14)
	applyStroke(stopAuto, DARK, 3)

	local resultCard = findOrCreate(overlay, "Frame", "HatchResultCard")
	resultCard.Size = UDim2.fromOffset(380, 160)
	resultCard.AnchorPoint = Vector2.new(0.5, 0.5)
	resultCard.Position = UDim2.fromScale(0.5, 0.82)
	resultCard.BackgroundColor3 = Color3.fromRGB(255, 248, 252)
	resultCard.BorderSizePixel = 0
	resultCard.Visible = false
	resultCard.ZIndex = 910
	resultCard:SetAttribute("UsesDefaultHatchLayout", true)
	applyCorner(resultCard, 18)
	applyStroke(resultCard, WHITE, 3)

	configureHatchText(
		resultCard,
		"ResultName",
		"Color",
		UDim2.fromOffset(14, 12),
		UDim2.new(1, -28, 0, 38),
		24,
		Color3.fromRGB(80, 60, 130)
	).Visible =
		false
	local resultRarity = configureHatchText(
		resultCard,
		"ResultRarity",
		"Common",
		UDim2.fromOffset(14, 48),
		UDim2.new(1, -28, 0, 26),
		16,
		Color3.fromRGB(80, 60, 130)
	)
	resultRarity.Font = Enum.Font.GothamBold
	resultRarity.TextWrapped = true
	resultRarity.Visible = false
	configureHatchText(
		resultCard,
		"ResultStats",
		"0  POWER | EQUIP MANUALLY",
		UDim2.fromOffset(14, 80),
		UDim2.new(1, -28, 0, 32),
		24,
		Color3.fromRGB(235, 54, 54)
	).Visible =
		false

	local resultOdds = configureHatchText(
		resultCard,
		"ResultOdds",
		"Color odds: 0%",
		UDim2.new(0, 14, 1, -38),
		UDim2.new(1, -28, 0, 30),
		14,
		Color3.fromRGB(66, 78, 110)
	)
	resultOdds.Font = Enum.Font.GothamBlack
	resultOdds.TextWrapped = true
	resultOdds.TextStrokeTransparency = 0.75
	resultOdds.Visible = false
	resultOdds:SetAttribute("EditableHatchOdds", true)
end

local function configureOption(parent, name, x, width, keyText, actionText, color)
	local option = findOrCreate(parent, "Frame", name)
	option.Position = UDim2.fromOffset(x, 113)
	option.Size = UDim2.fromOffset(width, 42)
	option.BackgroundColor3 = color
	option.BorderSizePixel = 0
	option.Parent = parent
	applyCorner(option, 12)
	applyStroke(option, DARK, 2)

	local key =
		text(option, "Key", keyText, UDim2.new(0, 7, 0.5, -15), UDim2.fromOffset(30, 30), Enum.Font.LuckiestGuy, DARK)
	key.BackgroundTransparency = 0.1
	key.BackgroundColor3 = WHITE
	key.TextSize = 18
	applyCorner(key, 99)

	local label = text(
		option,
		"Label",
		actionText,
		UDim2.fromOffset(39, 0),
		UDim2.new(1, -43, 1, 0),
		Enum.Font.LuckiestGuy,
		WHITE
	)
	label.TextScaled = true
	label.TextStrokeTransparency = 0.35
	label.TextStrokeColor3 = DARK
	label.TextXAlignment = Enum.TextXAlignment.Left
	local labelSize = label:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
	labelSize.MinTextSize = 12
	labelSize.MaxTextSize = 18
	labelSize.Parent = label
end

local function configurePrompt(holder, eggId, sourceGui)
	local egg = PetData.Eggs[eggId]
	local displayName = egg and egg.displayName or "Egg"
	local costText = egg and (formatNumber(egg.cost or 0) .. " Coins") or ""

	local existing = holder:FindFirstChild("EggOptions")
	local gui
	if sourceGui and sourceGui.Parent ~= holder then
		if existing then
			existing:Destroy()
		end
		gui = sourceGui:Clone()
		gui.Name = "EggOptions"
		gui.Parent = holder
	else
		gui = findOrCreate(holder, "BillboardGui", "EggOptions")
	end
	gui.AlwaysOnTop = true
	gui.Enabled = false
	gui.LightInfluence = 0
	gui.MaxDistance = 60
	gui.Size = UDim2.fromOffset(380, 260)
	if not sourceGui then
		gui.StudsOffsetWorldSpace = Vector3.new(0, math.max(8, holder.Size.Y * 0.5 + 4.5), 0)
	end
	gui:SetAttribute("EggOptionGui", true)
	gui:SetAttribute("EggPromptAuthored", true)

	if sourceGui then
		updatePromptTexts(gui, eggId)
		holder:SetAttribute("EggPromptAuthored", true)
		ensureEggPrompt(holder)
		return true, gui
	end

	local panel = findOrCreate(gui, "Frame", "Panel")
	panel.Size = UDim2.fromScale(1, 1)
	panel.Position = UDim2.fromScale(0, 0)
	panel.BackgroundColor3 = Color3.fromRGB(255, 248, 236)
	panel.BackgroundTransparency = 0.05
	panel.BorderSizePixel = 0
	panel.ClipsDescendants = true
	applyCorner(panel, 18)
	applyStroke(panel, DARK, 4)

	local titleLabel = text(
		panel,
		"Title",
		string.upper(displayName),
		UDim2.fromOffset(12, 10),
		UDim2.new(1, -24, 0, 30),
		Enum.Font.LuckiestGuy,
		Color3.fromRGB(78, 58, 130)
	)
	titleLabel.TextScaled = true
	titleLabel.TextStrokeTransparency = 0.55
	titleLabel.TextStrokeColor3 = WHITE
	local titleSize = titleLabel:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
	titleSize.MinTextSize = 14
	titleSize.MaxTextSize = 22
	titleSize.Parent = titleLabel

	local mainLabel = text(
		panel,
		"MainTitle",
		"EGG",
		UDim2.fromOffset(12, 42),
		UDim2.new(1, -24, 0, 42),
		Enum.Font.LuckiestGuy,
		Color3.fromRGB(255, 218, 74)
	)
	mainLabel.TextScaled = true
	mainLabel.TextStrokeTransparency = 0
	mainLabel.TextStrokeColor3 = DARK
	local mainSize = mainLabel:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
	mainSize.MinTextSize = 22
	mainSize.MaxTextSize = 42
	mainSize.Parent = mainLabel

	local costLabel = text(
		panel,
		"Cost",
		costText,
		UDim2.fromOffset(12, 84),
		UDim2.new(1, -24, 0, 20),
		Enum.Font.GothamBold,
		Color3.fromRGB(88, 92, 112)
	)
	costLabel.TextSize = 14

	local previewTitle = text(
		panel,
		"PreviewTitle",
		"POSSIBLE COLORS",
		UDim2.fromOffset(18, 108),
		UDim2.new(1, -36, 0, 20),
		Enum.Font.LuckiestGuy,
		Color3.fromRGB(78, 58, 130)
	)
	previewTitle.TextSize = 14
	previewTitle.TextXAlignment = Enum.TextXAlignment.Left

	local previewGrid = findOrCreate(panel, "Frame", "PreviewGrid")
	previewGrid.Position = UDim2.fromOffset(18, 131)
	previewGrid.Size = UDim2.new(1, -36, 0, 58)
	previewGrid.BackgroundTransparency = 1
	previewGrid.BorderSizePixel = 0
	previewGrid:SetAttribute("EggPreviewGrid", true)
	local gridLayout = previewGrid:FindFirstChildOfClass("UIGridLayout") or Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.fromOffset(62, 56)
	gridLayout.CellPadding = UDim2.fromOffset(8, 0)
	gridLayout.FillDirection = Enum.FillDirection.Horizontal
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = previewGrid
	for index = 1, 5 do
		local slot = findOrCreate(previewGrid, "Frame", "PreviewSlot" .. tostring(index))
		slot.LayoutOrder = index
		slot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		slot.BackgroundTransparency = 0.08
		slot.BorderSizePixel = 0
		slot.Visible = true
		slot:SetAttribute("EggPreviewSlot", true)
		applyCorner(slot, 12)
		applyStroke(slot, Color3.fromRGB(190, 205, 225), 2)

		local dot = findOrCreate(slot, "Frame", "ColorDot")
		dot.Size = UDim2.fromOffset(20, 20)
		dot.Position = UDim2.new(0.5, -10, 0, 6)
		dot.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
		dot.BorderSizePixel = 0
		applyCorner(dot, 999)

		local chance = text(
			slot,
			"Chance",
			"0%",
			UDim2.fromOffset(4, 28),
			UDim2.new(1, -8, 0, 16),
			Enum.Font.GothamBold,
			Color3.fromRGB(78, 58, 130)
		)
		chance.TextSize = 10

		local state = text(
			slot,
			"State",
			"???",
			UDim2.fromOffset(4, 42),
			UDim2.new(1, -8, 0, 12),
			Enum.Font.GothamBold,
			Color3.fromRGB(60, 70, 90)
		)
		state.TextSize = 8

		local locked = findOrCreate(slot, "Frame", "LockedShade")
		locked.Size = UDim2.fromScale(1, 1)
		locked.Position = UDim2.fromScale(0, 0)
		locked.BackgroundColor3 = Color3.fromRGB(20, 24, 35)
		locked.BackgroundTransparency = 0.48
		locked.BorderSizePixel = 0
		locked.Visible = true
		applyCorner(locked, 12)
	end

	configureOption(panel, "OpenOption", 41, 146, "E", "HATCH", Color3.fromRGB(116, 218, 230))
	configureOption(panel, "AutoOption", 198, 142, "R", "AUTO", Color3.fromRGB(176, 134, 244))
	local openOption = panel:FindFirstChild("OpenOption")
	if openOption then
		openOption.Position = UDim2.fromOffset(41, 203)
	end
	local autoOption = panel:FindFirstChild("AutoOption")
	if autoOption then
		autoOption.Position = UDim2.fromOffset(198, 203)
	end

	holder:SetAttribute("EggPromptAuthored", true)
	ensureEggPrompt(holder)
	return true, gui
end

local function getEggHolders()
	local holders = {}
	local seen = {}
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if isEggRoot(obj) then
			local holder = getBestPart(obj)
			local eggId = holder and findEggId(holder)
			if holder and eggId and not seen[holder] then
				seen[holder] = true
				table.insert(holders, {
					holder = holder,
					eggId = eggId,
				})
			end
		end
	end
	return holders
end

local function findRedPromptTemplate(holders)
	for _, entry in ipairs(holders) do
		if entry.eggId == SPAWN_EGG_ID or entry.holder:GetAttribute("AreaColor") == SPAWN_EGG_COLOR then
			local _, gui = configurePrompt(entry.holder, entry.eggId)
			if gui then
				return gui
			end
		end
	end
	return nil
end

function Builder.Update()
	if not canEditInStudio("Update") then
		return
	end

	local _, replacedSpawn = replaceSpawnEggModel()
	local holders = getEggHolders()
	local redPromptTemplate = findRedPromptTemplate(holders)

	local updated = 0
	for _, entry in ipairs(holders) do
		local sourceGui = redPromptTemplate and entry.holder ~= redPromptTemplate.Parent and redPromptTemplate or nil
		if configurePrompt(entry.holder, entry.eggId, sourceGui) then
			updated += 1
		end
	end

	print(
		"StudioEggPromptBuilder: "
			.. (replacedSpawn and "replaced spawn egg; " or "")
			.. "synced editable EggOptions prompts on "
			.. tostring(updated)
			.. " eggs."
	)
end

Builder.UpdateEggPrompts = Builder.Update
Builder.SyncEggPrompts = Builder.Update

function Builder.BuildUI()
	if not canEditInStudio("BuildUI") then
		return
	end

	local mainHud = StarterGui:FindFirstChild("MainHUD")
	if not mainHud then
		mainHud = Instance.new("ScreenGui")
		mainHud.Name = "MainHUD"
		mainHud.ResetOnSpawn = false
		mainHud.IgnoreGuiInset = true
		mainHud.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		mainHud.DisplayOrder = 100
		mainHud.Parent = StarterGui
	elseif not mainHud:IsA("ScreenGui") then
		warn("StudioEggPromptBuilder: StarterGui.MainHUD exists but is not a ScreenGui.")
		return
	end

	local layer = mainHud:FindFirstChild("EggShopUI")
	if layer and not layer:IsA("GuiObject") then
		warn("StudioEggPromptBuilder: StarterGui.MainHUD.EggShopUI exists but is not a GuiObject.")
		return
	end
	if not layer then
		layer = Instance.new("Frame")
		layer.Name = "EggShopUI"
		layer.Size = UDim2.fromScale(1, 1)
		layer.Position = UDim2.fromScale(0, 0)
		layer.BackgroundTransparency = 1
		layer.BorderSizePixel = 0
		layer.Visible = true
		layer.ZIndex = 800
		layer.Parent = mainHud
	end

	layer:SetAttribute("EditableEggHatchLayer", true)
	layer:SetAttribute("ClientBoundBy", "EggShopUI.client.luau")
	configureHatchAnimationUi(layer)
	print("StudioEggPromptBuilder: ready editable StarterGui.MainHUD.EggShopUI hatch animation layer.")
	return layer
end

function Builder.BuildAll()
	Builder.BuildUI()
	Builder.Update()
end

Builder.UpdateUI = Builder.BuildUI
Builder.BuildEggUI = Builder.BuildUI
Builder.UpdateAll = Builder.BuildAll

Builder.ReplaceSpawnEgg = function()
	if not canEditInStudio("ReplaceSpawnEgg") then
		return
	end
	local _, replaced = replaceSpawnEggModel()
	print("StudioEggPromptBuilder: " .. (replaced and "replaced SpawnEgg." or "could not find SpawnEgg/template."))
end

return Builder
