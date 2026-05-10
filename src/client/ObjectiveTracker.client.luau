-- Guided tutorial UI. Server-owned values decide progress; this client only presents
-- the guide, highlights targets, and requests safe tutorial actions.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local ClientUIRoot = require(ReplicatedStorage:WaitForChild("ClientUIRoot"))
local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))
local UIManager = require(ReplicatedStorage:WaitForChild("UIManager"))

local Events = ReplicatedStorage:WaitForChild("Events")
local tutorialActionEvent = Events:WaitForChild("TutorialAction")

local objectiveFolder = player:WaitForChild("TutorialObjectives", 15)
if not objectiveFolder then
	return
end

local tutorialActive = ReplicatedStorage:FindFirstChild("TutorialWelcomeActive")
if not tutorialActive then
	tutorialActive = Instance.new("BoolValue")
	tutorialActive.Name = "TutorialWelcomeActive"
	tutorialActive.Value = false
	tutorialActive.Parent = ReplicatedStorage
end

local function getObjectiveContainer()
	local root = ClientUIRoot.GetRoot(player.PlayerGui)
	local hud = root and (root:FindFirstChild("HUD") or root:WaitForChild("HUD", 8))
	local container = hud and hud:FindFirstChild("ObjectiveContainer")
	if not container then
		container = root and root:FindFirstChild("ObjectiveContainer")
	end
	if not container and root then
		container = Instance.new("Frame")
		container.Name = "ObjectiveContainer"
		container.Size = UDim2.fromScale(1, 1)
		container.BackgroundTransparency = 1
		container.BorderSizePixel = 0
		container.Active = false
		container.Parent = root
	end
	if not container then
		return nil
	end

	for _, child in ipairs(container:GetChildren()) do
		if child.Name == "TutorialGuideRoot" then
			child:Destroy()
		end
	end
	return container
end

local screenGui = getObjectiveContainer()
if not screenGui then
	return
end
screenGui.Visible = true

local guideRoot = Instance.new("Frame")
guideRoot.Name = "TutorialGuideRoot"
guideRoot.Size = UDim2.fromScale(1, 1)
guideRoot.BackgroundTransparency = 1
guideRoot.BorderSizePixel = 0
guideRoot.Active = false
guideRoot.Visible = false
guideRoot.ZIndex = 90
guideRoot.Parent = screenGui

local dimOverlay = Instance.new("Frame")
dimOverlay.Name = "TutorialDimOverlay"
dimOverlay.Size = UDim2.fromScale(1, 1)
dimOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
dimOverlay.BackgroundTransparency = 1
dimOverlay.BorderSizePixel = 0
dimOverlay.Active = false
dimOverlay.Visible = false
dimOverlay.ZIndex = 90
dimOverlay.Parent = guideRoot

local shadow = Instance.new("Frame")
shadow.Name = "TutorialPanelShadow"
shadow.AnchorPoint = Vector2.new(1, 0)
shadow.Size = UDim2.new(0, 400, 0, 180)
shadow.Position = UDim2.new(1, -18, 0, 86)
shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
shadow.BackgroundTransparency = 0.82
shadow.BorderSizePixel = 0
shadow.Visible = false
shadow.ZIndex = 91
shadow.Parent = guideRoot
UITheme.ApplyCorner(shadow, UDim.new(0, 14))

local panel = Instance.new("Frame")
panel.Name = "TutorialPanel"
panel.AnchorPoint = Vector2.new(1, 0)
panel.Size = UDim2.fromOffset(390, 190)
panel.AutomaticSize = Enum.AutomaticSize.None
panel.Position = UDim2.new(1, -24, 0, 80)
panel.BackgroundColor3 = Color3.fromRGB(255, 249, 238)
panel.BorderSizePixel = 0
panel.ClipsDescendants = false
panel.Visible = false
panel.ZIndex = 92
panel.Parent = guideRoot
UITheme.ApplyCorner(panel, UDim.new(0, 14))
UITheme.ApplyStroke(panel, Color3.fromRGB(35, 38, 45), 3)

local panelSizeConstraint = Instance.new("UISizeConstraint")
panelSizeConstraint.MinSize = Vector2.new(320, 0)
panelSizeConstraint.MaxSize = Vector2.new(400, 1000)
panelSizeConstraint.Parent = panel

local panelScale = Instance.new("UIScale")
panelScale.Name = "PanelTweenScale"
panelScale.Scale = 0.96
panelScale.Parent = panel

local shadowScale = Instance.new("UIScale")
shadowScale.Name = "ShadowTweenScale"
shadowScale.Scale = 0.96
shadowScale.Parent = shadow

local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 16)
pad.PaddingBottom = UDim.new(0, 16)
pad.PaddingLeft = UDim.new(0, 18)
pad.PaddingRight = UDim.new(0, 18)
pad.Parent = panel
pad:Destroy()

local panelLayout = Instance.new("UIListLayout")
panelLayout.FillDirection = Enum.FillDirection.Vertical
panelLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
panelLayout.VerticalAlignment = Enum.VerticalAlignment.Top
panelLayout.SortOrder = Enum.SortOrder.LayoutOrder
panelLayout.Padding = UDim.new(0, 8)
panelLayout.Parent = panel
panelLayout:Destroy()

local topRow = Instance.new("Frame")
topRow.Name = "TopRow"
topRow.Size = UDim2.new(1, 0, 0, 30)
topRow.BackgroundTransparency = 1
topRow.LayoutOrder = 1
topRow.ZIndex = 93
topRow.Parent = panel

local stepText = Instance.new("TextLabel")
stepText.Name = "StepText"
stepText.Size = UDim2.new(1, -132, 1, 0)
stepText.BackgroundTransparency = 1
stepText.Font = Enum.Font.GothamBlack
stepText.TextSize = 14
stepText.TextColor3 = Color3.fromRGB(91, 94, 110)
stepText.TextXAlignment = Enum.TextXAlignment.Left
stepText.TextYAlignment = Enum.TextYAlignment.Center
stepText.Text = "STEP 1 / 12"
stepText.ZIndex = 93
stepText:SetAttribute("NoTextGlow", true)
stepText.Parent = topRow

local skipButton = Instance.new("TextButton")
skipButton.Name = "SkipTutorialButton"
skipButton.AnchorPoint = Vector2.new(1, 0.5)
skipButton.Size = UDim2.new(0, 120, 0, 30)
skipButton.Position = UDim2.new(1, 0, 0.5, 0)
skipButton.BackgroundColor3 = Color3.fromRGB(232, 234, 241)
skipButton.BorderSizePixel = 0
skipButton.Font = Enum.Font.GothamBlack
skipButton.TextSize = 12
skipButton.TextColor3 = Color3.fromRGB(57, 61, 75)
skipButton.Text = "Skip Tutorial"
skipButton.ZIndex = 94
skipButton:SetAttribute("NoTextGlow", true)
skipButton.Parent = topRow
UITheme.ApplyCorner(skipButton, UDim.new(0, 8))
UITheme.ApplyStroke(skipButton, Color3.fromRGB(150, 154, 168), 1)

local titleText = Instance.new("TextLabel")
titleText.Name = "TitleText"
titleText.Size = UDim2.new(1, 0, 0, 0)
titleText.AutomaticSize = Enum.AutomaticSize.Y
titleText.BackgroundTransparency = 1
titleText.Font = Enum.Font.GothamBlack
titleText.TextSize = 23
titleText.TextColor3 = Color3.fromRGB(32, 35, 45)
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.TextYAlignment = Enum.TextYAlignment.Top
titleText.TextWrapped = true
titleText.Text = "Welcome"
titleText.TextTruncate = Enum.TextTruncate.None
titleText.LayoutOrder = 2
titleText.ZIndex = 93
titleText:SetAttribute("NoTextGlow", true)
titleText.Parent = panel
UITheme.ApplyTextSizeConstraint(titleText, 18, 23)

local instructionText = Instance.new("TextLabel")
instructionText.Name = "InstructionText"
instructionText.Size = UDim2.new(1, 0, 0, 0)
instructionText.AutomaticSize = Enum.AutomaticSize.Y
instructionText.BackgroundTransparency = 1
instructionText.Font = Enum.Font.GothamMedium
instructionText.TextSize = 15
instructionText.TextColor3 = Color3.fromRGB(52, 56, 70)
instructionText.TextXAlignment = Enum.TextXAlignment.Left
instructionText.TextYAlignment = Enum.TextYAlignment.Top
instructionText.TextWrapped = true
instructionText.Text = ""
instructionText.LayoutOrder = 3
instructionText.ZIndex = 93
instructionText:SetAttribute("NoTextGlow", true)
instructionText.Parent = panel
UITheme.ApplyTextSizeConstraint(instructionText, 13, 15)

local hintText = Instance.new("TextLabel")
hintText.Name = "HintText"
hintText.Size = UDim2.new(1, 0, 0, 0)
hintText.AutomaticSize = Enum.AutomaticSize.Y
hintText.BackgroundTransparency = 1
hintText.Font = Enum.Font.GothamBold
hintText.TextSize = 14
hintText.TextColor3 = Color3.fromRGB(112, 75, 74)
hintText.TextXAlignment = Enum.TextXAlignment.Left
hintText.TextYAlignment = Enum.TextYAlignment.Top
hintText.TextWrapped = true
hintText.Text = ""
hintText.Visible = false
hintText.LayoutOrder = 4
hintText.ZIndex = 93
hintText:SetAttribute("NoTextGlow", true)
hintText.Parent = panel
UITheme.ApplyTextSizeConstraint(hintText, 12, 14)

local counterRow = Instance.new("Frame")
counterRow.Name = "ProgressContainer"
counterRow.Size = UDim2.new(1, 0, 0, 22)
counterRow.BackgroundTransparency = 1
counterRow.Visible = false
counterRow.LayoutOrder = 5
counterRow.ZIndex = 93
counterRow.Parent = panel

local progressCounter = Instance.new("TextLabel")
progressCounter.Name = "ProgressCounter"
progressCounter.Size = UDim2.new(1, 0, 1, 0)
progressCounter.BackgroundTransparency = 1
progressCounter.Font = Enum.Font.GothamBlack
progressCounter.TextSize = 14
progressCounter.TextColor3 = Color3.fromRGB(57, 61, 75)
progressCounter.TextXAlignment = Enum.TextXAlignment.Left
progressCounter.TextYAlignment = Enum.TextYAlignment.Center
progressCounter.Text = ""
progressCounter.ZIndex = 93
progressCounter:SetAttribute("NoTextGlow", true)
progressCounter.Parent = counterRow
UITheme.ApplyTextSizeConstraint(progressCounter, 12, 14)

local progressBack = Instance.new("Frame")
progressBack.Name = "ProgressBack"
progressBack.Size = UDim2.new(1, 0, 0, 14)
progressBack.BackgroundColor3 = Color3.fromRGB(224, 229, 238)
progressBack.BorderSizePixel = 0
progressBack.ClipsDescendants = true
progressBack.Visible = false
progressBack.LayoutOrder = 6
progressBack.ZIndex = 93
progressBack.Parent = panel
UITheme.ApplyCorner(progressBack, UDim.new(0, 7))

local progressFill = Instance.new("Frame")
progressFill.Name = "ProgressFill"
progressFill.Size = UDim2.fromScale(0, 1)
progressFill.BackgroundColor3 = Color3.fromRGB(255, 74, 90)
progressFill.BorderSizePixel = 0
progressFill.ZIndex = 94
progressFill.Parent = progressBack
UITheme.ApplyCorner(progressFill, UDim.new(0, 7))

local remainingCounter = Instance.new("TextLabel")
remainingCounter.Name = "RemainingCounter"
remainingCounter.Size = UDim2.new(1, 0, 0, 0)
remainingCounter.BackgroundTransparency = 1
remainingCounter.Text = ""
remainingCounter.Visible = false
remainingCounter.Parent = panel

local buttonRow = Instance.new("Frame")
buttonRow.Name = "ButtonRow"
buttonRow.Size = UDim2.new(1, 0, 0, 38)
buttonRow.BackgroundTransparency = 1
buttonRow.Visible = false
buttonRow.LayoutOrder = 7
buttonRow.ZIndex = 93
buttonRow.Parent = panel

local buttonLayout = Instance.new("UIListLayout")
buttonLayout.FillDirection = Enum.FillDirection.Horizontal
buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
buttonLayout.VerticalAlignment = Enum.VerticalAlignment.Center
buttonLayout.SortOrder = Enum.SortOrder.LayoutOrder
buttonLayout.Parent = buttonRow

local primaryButton = Instance.new("TextButton")
primaryButton.Name = "TutorialPrimaryButton"
primaryButton.Size = UDim2.new(0, 130, 0, 38)
primaryButton.BackgroundColor3 = Color3.fromRGB(255, 78, 95)
primaryButton.BorderSizePixel = 0
primaryButton.Font = Enum.Font.GothamBlack
primaryButton.TextSize = 15
primaryButton.TextColor3 = Color3.fromRGB(255, 255, 255)
primaryButton.Text = "Next"
primaryButton.Visible = true
primaryButton.ZIndex = 94
primaryButton:SetAttribute("NoTextGlow", true)
primaryButton.Parent = buttonRow
UITheme.ApplyCorner(primaryButton, UDim.new(0, 9))
UITheme.ApplyStroke(primaryButton, Color3.fromRGB(35, 38, 45), 2)
UITheme.ApplyTextSizeConstraint(primaryButton, 12, 15)

local toast = Instance.new("TextLabel")
toast.Name = "TutorialToast"
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Size = UDim2.new(0, 330, 0, 34)
toast.Position = UDim2.new(0.5, 0, 0, 192)
toast.BackgroundColor3 = Color3.fromRGB(35, 38, 45)
toast.BackgroundTransparency = 1
toast.BorderSizePixel = 0
toast.Font = Enum.Font.GothamBlack
toast.TextSize = 15
toast.TextColor3 = Color3.fromRGB(255, 255, 255)
toast.TextTransparency = 1
toast.Text = ""
toast.Visible = false
toast.ZIndex = 110
toast:SetAttribute("NoTextGlow", true)
toast.Parent = guideRoot
UITheme.ApplyCorner(toast, UDim.new(0, 10))
UITheme.ApplyStroke(toast, Color3.fromRGB(255, 255, 255), 1)

local values = {
	TutorialCompleted = objectiveFolder:WaitForChild("TutorialCompleted", 10),
	Stage = objectiveFolder:WaitForChild("Stage", 10),
	StepIndex = objectiveFolder:WaitForChild("StepIndex", 10),
	StepCount = objectiveFolder:WaitForChild("StepCount", 10),
	ObjectiveText = objectiveFolder:WaitForChild("ObjectiveText", 10),
	InstructionText = objectiveFolder:WaitForChild("InstructionText", 10),
	HintText = objectiveFolder:WaitForChild("HintText", 10),
	ButtonText = objectiveFolder:WaitForChild("ButtonText", 10),
	Progress = objectiveFolder:WaitForChild("Progress", 10),
	ProgressGoal = objectiveFolder:WaitForChild("ProgressGoal", 10),
	ProgressLabel = objectiveFolder:WaitForChild("ProgressLabel", 10),
	RemainingLabel = objectiveFolder:WaitForChild("RemainingLabel", 10),
	TargetType = objectiveFolder:WaitForChild("TargetType", 10),
	TargetName = objectiveFolder:WaitForChild("TargetName", 10),
	TargetObject = objectiveFolder:WaitForChild("TargetObject", 10),
	LastRewardMessage = objectiveFolder:WaitForChild("LastRewardMessage", 10),
}

local TARGET_UI_NAMES = {
	CoinsRow = { "CoinsRow", "CoinPill" },
	GemsRow = { "GemsRow", "GemPill" },
	MenuButton = { "MenuButton", "CenterMenuButton" },
	WorldButton = { "WorldButton", "WorldImageButton" },
	ShopButton = { "ShopButton", "ShopImageButton" },
	WorldRow_Orange = { "WorldUnlockButton_Orange", "WorldTeleportButton_Orange", "WorldRow_Orange" },
}

local TOUR_DEFS = {
	{
		label = "Coins",
		names = { "CoinsRow", "CoinPill" },
		text = "Earn coins by cleaning patches.\nUse coins to hatch Colors from eggs.",
	},
	{
		label = "Gems",
		names = { "GemsRow", "GemPill" },
		text = "Break randomly spawned gems to collect gems.\nUse gems to buy character and Color upgrades.",
	},
	{
		label = "Colors",
		names = { "MenuBtn_INVENTORY", "MenuButton" },
		text = "View and equip your Colors.",
	},
	{
		label = "Upgrades",
		names = { "MenuBtn_UPGRADES", "UpgradeButton", "UpgradesButton" },
		text = "Spend gems to upgrade your character and your Colors.",
	},
	{
		label = "Sectors",
		names = { "WorldButton", "WorldImageButton", "MenuBtn_WORLD" },
		text = "Open the Sector menu and view unlocked Sectors.",
	},
	{
		label = "Shop",
		names = { "ShopButton", "ShopImageButton", "MenuBtn_GAMEPASS", "MenuBtn_SHOP" },
		text = "Buy boosts, gamepasses, or special items.",
	},
	{
		label = "Index",
		names = { "MenuBtn_INDEX", "IndexButton" },
		text = "View Colors or eggs you have discovered.",
	},
	{
		label = "Settings",
		names = { "MenuBtn_SETTINGS", "SettingsButton" },
		text = "Change music, sounds, and other options.",
	},
	{
		label = "Codes",
		names = { "MenuBtn_CODES", "CodesButton" },
		text = "Redeem codes for rewards.",
	},
}

local activeStage = nil
local tourItems = {}
local tourIndex = 1
local lastRewardMessage = ""
local rewardToken = 0
local highlightFrame = nil
local highlightToken = 0
local markerGui = nil
local markerToken = 0
local stageEffectToken = 0
local panelVisible = false

local function getText(name, defaultValue)
	local value = values[name]
	return value and tostring(value.Value) or defaultValue or ""
end

local function getNumber(name, defaultValue)
	local value = values[name]
	return value and tonumber(value.Value) or defaultValue or 0
end

local function getBool(name)
	local value = values[name]
	return value and value.Value == true
end

local function isTutorialComplete()
	return getBool("TutorialCompleted")
end

local function isGuiVisible(gui)
	if not gui or not gui:IsA("GuiObject") or not gui.Visible then
		return false
	end
	local current = gui.Parent
	while current and current ~= player.PlayerGui do
		if current:IsA("GuiObject") and current.Visible == false then
			return false
		end
		current = current.Parent
	end
	return gui.AbsoluteSize.X > 4 and gui.AbsoluteSize.Y > 4
end

local function findVisibleGui(names)
	for _, name in ipairs(names or {}) do
		for _, obj in ipairs(player.PlayerGui:GetDescendants()) do
			if obj:IsA("GuiObject") and obj.Name == name and isGuiVisible(obj) then
				return obj
			end
		end
	end
	return nil
end

local function cleanupHighlight()
	highlightToken += 1
	if highlightFrame then
		highlightFrame:Destroy()
		highlightFrame = nil
	end
end

local function cleanupMarker()
	markerToken += 1
	if markerGui then
		markerGui:Destroy()
		markerGui = nil
	end
end

local function cleanupGuidance()
	cleanupHighlight()
	cleanupMarker()
	dimOverlay.Visible = false
end

local function createUiHighlight(target)
	cleanupHighlight()
	if not target or not target.Parent then
		return
	end

	highlightToken += 1
	local token = highlightToken
	local frame = Instance.new("Frame")
	frame.Name = "TutorialUiHighlight"
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.ZIndex = 112
	frame.Parent = guideRoot
	UITheme.ApplyCorner(frame, UDim.new(0, 12))
	local stroke = UITheme.ApplyStroke(frame, Color3.fromRGB(255, 242, 106), 4)
	stroke.Transparency = 0.05
	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = frame
	highlightFrame = frame

	task.spawn(function()
		while token == highlightToken and frame.Parent and target.Parent do
			local size = target.AbsoluteSize
			local pos = target.AbsolutePosition
			frame.Position = UDim2.fromOffset(pos.X - 8, pos.Y - 8)
			frame.Size = UDim2.fromOffset(size.X + 16, size.Y + 16)
			task.wait()
		end
	end)

	task.spawn(function()
		while token == highlightToken and frame.Parent do
			TweenService:Create(scale, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Scale = 1.05,
			}):Play()
			TweenService:Create(stroke, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Transparency = 0.32,
			}):Play()
			task.wait(0.55)
			TweenService:Create(scale, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Scale = 1,
			}):Play()
			TweenService:Create(stroke, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Transparency = 0.05,
			}):Play()
			task.wait(0.55)
		end
	end)
end

local function createWorldMarker(target, label)
	cleanupMarker()
	if not target or not target:IsA("BasePart") or not target.Parent then
		return
	end

	markerToken += 1
	local token = markerToken
	local gui = Instance.new("BillboardGui")
	gui.Name = "TutorialWorldMarker"
	gui.Adornee = target
	gui.AlwaysOnTop = true
	gui.Size = UDim2.new(0, 150, 0, 70)
	gui.StudsOffset = Vector3.new(0, 4.2, 0)
	gui.MaxDistance = 180
	gui.Parent = target
	markerGui = gui

	local arrow = Instance.new("TextLabel")
	arrow.Name = "Arrow"
	arrow.Size = UDim2.new(1, 0, 0, 32)
	arrow.BackgroundTransparency = 1
	arrow.Font = Enum.Font.GothamBlack
	arrow.TextSize = 28
	arrow.TextColor3 = Color3.fromRGB(255, 245, 105)
	arrow.TextStrokeTransparency = 0
	arrow.TextStrokeColor3 = Color3.fromRGB(30, 32, 38)
	arrow.Text = "V"
	arrow.Parent = gui

	local text = Instance.new("TextLabel")
	text.Name = "Label"
	text.Size = UDim2.new(1, 0, 0, 24)
	text.Position = UDim2.new(0, 0, 0, 32)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBlack
	text.TextSize = 13
	text.TextColor3 = Color3.fromRGB(255, 255, 255)
	text.TextStrokeTransparency = 0
	text.TextStrokeColor3 = Color3.fromRGB(30, 32, 38)
	text.Text = label or "Go here"
	text.Parent = gui

	task.spawn(function()
		while token == markerToken and gui.Parent do
			TweenService:Create(gui, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				StudsOffset = Vector3.new(0, 4.8, 0),
			}):Play()
			task.wait(0.55)
			TweenService:Create(gui, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				StudsOffset = Vector3.new(0, 4.2, 0),
			}):Play()
			task.wait(0.55)
		end
	end)
end

local function getRoot()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function findNearestRedSpill()
	local root = getRoot()
	local origin = root and root.Position or Vector3.zero
	local best
	local bestDistance = math.huge
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("BasePart")
			and obj:GetAttribute("BreakableType")
			and obj:GetAttribute("ColorType") == "Red"
			and obj:GetAttribute("ColorZone") ~= true
			and obj:GetAttribute("IsCollected") ~= true
			and obj.Transparency < 1
		then
			local distance = (obj.Position - origin).Magnitude
			if distance < bestDistance then
				bestDistance = distance
				best = obj
			end
		end
	end
	return best
end

local function rebuildTourItems()
	tourItems = {}
	for _, def in ipairs(TOUR_DEFS) do
		if findVisibleGui(def.names) then
			table.insert(tourItems, def)
		end
	end
	if #tourItems == 0 then
		table.insert(tourItems, {
			label = "Menu",
			names = { "MenuButton" },
			text = "Use the main buttons to open useful menus.",
		})
	end
	tourIndex = math.clamp(tourIndex, 1, math.max(#tourItems, 1))
end

local function showReward(message)
	if not message or message == "" or message == lastRewardMessage or isTutorialComplete() then
		return
	end
	lastRewardMessage = message
	rewardToken += 1
	local token = rewardToken
	toast.Text = message
	toast.Visible = true
	toast.BackgroundTransparency = 1
	toast.TextTransparency = 1
	TweenService:Create(toast, TweenInfo.new(0.16), {
		BackgroundTransparency = 0.08,
		TextTransparency = 0,
	}):Play()
	task.delay(1.35, function()
		if token ~= rewardToken then
			return
		end
		TweenService:Create(toast, TweenInfo.new(0.18), {
			BackgroundTransparency = 1,
			TextTransparency = 1,
		}):Play()
		task.wait(0.18)
		if token == rewardToken then
			toast.Visible = false
		end
	end)
end

local PANEL_MAX_WIDTH = 390
local PANEL_MIN_WIDTH = 320
local PANEL_PADDING_X = 18
local PANEL_PADDING_TOP = 16
local PANEL_PADDING_BOTTOM = 16
local PANEL_GAP = 8

local function getPanelWidth()
	local rootWidth = math.max(guideRoot.AbsoluteSize.X, 360)
	return math.clamp(rootWidth - 48, PANEL_MIN_WIDTH, PANEL_MAX_WIDTH)
end

local function updatePanelPlacement()
	local viewport = UITheme.GetViewportSize()
	local compact = UITheme.IsTouchDevice() or viewport.X < 900 or viewport.Y < 620
	local rightMargin = compact and 14 or 24
	local topMargin = compact and 64 or 80
	panel.Position = UDim2.new(1, -rightMargin, 0, topMargin)
	shadow.Position = UDim2.new(1, -(rightMargin - 6), 0, topMargin + 6)
end

local function getTextHeight(label, text, minHeight)
	local width = math.max(getPanelWidth() - PANEL_PADDING_X * 2, 120)
	local bounds = TextService:GetTextSize(
		(text and text ~= "") and text or " ",
		label.TextSize,
		label.Font,
		Vector2.new(width, math.huge)
	)
	return math.max(minHeight or 20, math.ceil(bounds.Y) + 2)
end

local function layoutPanel(showProgress, showButton)
	updatePanelPlacement()
	local panelWidth = getPanelWidth()
	local contentWidth = panelWidth - PANEL_PADDING_X * 2
	local y = PANEL_PADDING_TOP

	topRow.Position = UDim2.fromOffset(PANEL_PADDING_X, y)
	topRow.Size = UDim2.fromOffset(contentWidth, 30)
	y += 30 + PANEL_GAP

	local titleHeight = getTextHeight(titleText, titleText.Text, 28)
	titleText.Position = UDim2.fromOffset(PANEL_PADDING_X, y)
	titleText.Size = UDim2.fromOffset(contentWidth, titleHeight)
	y += titleHeight + PANEL_GAP

	local instructionHeight = getTextHeight(instructionText, instructionText.Text, 22)
	instructionText.Position = UDim2.fromOffset(PANEL_PADDING_X, y)
	instructionText.Size = UDim2.fromOffset(contentWidth, instructionHeight)
	y += instructionHeight

	if hintText.Visible then
		y += PANEL_GAP
		local hintHeight = getTextHeight(hintText, hintText.Text, 20)
		hintText.Position = UDim2.fromOffset(PANEL_PADDING_X, y)
		hintText.Size = UDim2.fromOffset(contentWidth, hintHeight)
		y += hintHeight
	end

	if showProgress then
		y += PANEL_GAP
		counterRow.Position = UDim2.fromOffset(PANEL_PADDING_X, y)
		counterRow.Size = UDim2.fromOffset(contentWidth, 22)
		y += 22 + 6
		progressBack.Position = UDim2.fromOffset(PANEL_PADDING_X, y)
		progressBack.Size = UDim2.fromOffset(contentWidth, 14)
		y += 14
	end

	if showButton then
		y += PANEL_GAP
		buttonRow.Position = UDim2.fromOffset(PANEL_PADDING_X, y)
		buttonRow.Size = UDim2.fromOffset(contentWidth, 38)
		y += 38
	end

	local height = math.clamp(y + PANEL_PADDING_BOTTOM, 120, 320)
	panel.Size = UDim2.fromOffset(panelWidth, height)
	shadow.Size = UDim2.fromOffset(panelWidth, height)
end

local function syncShadowToPanel()
	local size = panel.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return
	end
	shadow.Size = UDim2.fromOffset(size.X, size.Y)
end

panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(syncShadowToPanel)
panel:GetPropertyChangedSignal("AbsolutePosition"):Connect(syncShadowToPanel)
local function hookTutorialCamera()
	local currentCamera = workspace.CurrentCamera
	if currentCamera then
		currentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			updatePanelPlacement()
			syncShadowToPanel()
		end)
	end
end
hookTutorialCamera()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	task.defer(function()
		updatePanelPlacement()
		syncShadowToPanel()
		hookTutorialCamera()
	end)
end)

local function setPanelVisible(visible)
	if panelVisible == visible then
		guideRoot.Visible = visible
		panel.Visible = visible
		shadow.Visible = visible
		tutorialActive.Value = visible
		syncShadowToPanel()
		return
	end
	panelVisible = visible
	guideRoot.Visible = visible
	panel.Visible = visible
	shadow.Visible = visible
	tutorialActive.Value = visible
	if visible then
		syncShadowToPanel()
		panel.BackgroundTransparency = 1
		shadow.BackgroundTransparency = 1
		panelScale.Scale = 0.96
		shadowScale.Scale = 0.96
		TweenService:Create(panel, TweenInfo.new(0.18), { BackgroundTransparency = 0 }):Play()
		TweenService:Create(shadow, TweenInfo.new(0.18), { BackgroundTransparency = 0.72 }):Play()
		TweenService:Create(panelScale, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		TweenService:Create(shadowScale, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	else
		cleanupGuidance()
	end
end

local function setProgressBar(progress, goal, shouldShow)
	goal = math.max(tonumber(goal) or 1, 1)
	progress = math.clamp(tonumber(progress) or 0, 0, goal)
	progressBack.Visible = shouldShow
	if shouldShow then
		TweenService:Create(progressFill, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
			Size = UDim2.fromScale(progress / goal, 1),
		}):Play()
	else
		progressFill.Size = UDim2.fromScale(0, 1)
	end
end

local function updateGuidance()
	cleanupGuidance()
	local stage = getText("Stage", "Welcome")
	if isTutorialComplete() then
		return
	end

	if stage == "CleanSpills" then
		createWorldMarker(findNearestRedSpill(), "Clean this")
		return
	elseif stage == "CollectGems" then
		local objectValue = values.TargetObject
		local target = objectValue and objectValue.Value
		createWorldMarker(target, "Break gem")
		return
	elseif stage == "HatchFirstColor" then
		local objectValue = values.TargetObject
		local target = objectValue and objectValue.Value
		createWorldMarker(target, "Egg area")
		return
	elseif stage == "VisitShop" or stage == "OpenBrushShop" or stage == "AskDailyQuests" then
		local objectValue = values.TargetObject
		local target = objectValue and objectValue.Value
		createWorldMarker(target, stage == "VisitShop" and "Shop" or "Talk to Zork")
		return
	end

	local targetName = getText("TargetName", "")
	if stage == "LearnUI" then
		local def = tourItems[tourIndex]
		if def then
			local gui = findVisibleGui(def.names)
			if gui then
				createUiHighlight(gui)
			end
		end
		return
	end

	local names = TARGET_UI_NAMES[targetName]
	if names then
		local gui = findVisibleGui(names)
		if gui then
			createUiHighlight(gui)
		end
	end
end

local function applyStageEffects(stage)
	stageEffectToken += 1
	local token = stageEffectToken
	if stage == "EquipColor" then
		task.delay(0.35, function()
			if token ~= stageEffectToken or getText("Stage", "") ~= "EquipColor" then
				return
			end
			if UIManager.isRegistered("Inventory") then
				UIManager.open("Inventory", { from = "Tutorial", defaultTab = "Colors" })
			end
		end)
	elseif stage == "LearnUI" then
		if UIManager.isRegistered("Inventory") then
			UIManager.close("Inventory")
		end
		if UIManager.isRegistered("Menu") then
			UIManager.open("Menu")
		end
		task.defer(function()
			if token ~= stageEffectToken or getText("Stage", "") ~= "LearnUI" then
				return
			end
			rebuildTourItems()
			updateGuidance()
		end)
	elseif stage == "OpenWorlds" then
		if UIManager.isRegistered("Menu") then
			UIManager.close("Menu")
		end
		if UIManager.isRegistered("World") then
			UIManager.close("World")
		end
	elseif stage == "VisitShop" or stage == "OpenBrushShop" or stage == "AskDailyQuests" then
		if UIManager.isRegistered("World") then
			UIManager.close("World")
		end
	end
end

local function refresh()
	if isTutorialComplete() then
		setPanelVisible(false)
		return
	end

	local stage = getText("Stage", "Welcome")
	if activeStage ~= stage then
		activeStage = stage
		tourIndex = 1
		if stage == "LearnUI" then
			rebuildTourItems()
		end
		applyStageEffects(stage)
	end

	setPanelVisible(true)

	local stepIndex = getNumber("StepIndex", 1)
	local stepCount = math.max(getNumber("StepCount", 12), 1)
	local progress = getNumber("Progress", 0)
	local goal = math.max(getNumber("ProgressGoal", 1), 1)
	local instruction = getText("InstructionText", "")
	local title = getText("ObjectiveText", "Welcome")
	local hint = getText("HintText", "")
	local button = getText("ButtonText", "")
	local progressLabel = getText("ProgressLabel", "")

	if stage == "LearnUI" then
		local def = tourItems[tourIndex]
		if def then
			instruction = def.text
			hint = def.label
			button = tourIndex >= #tourItems and "Next" or "Next"
		end
	end

	stepText.Text = "STEP " .. tostring(stepIndex) .. " / " .. tostring(stepCount)
	titleText.Text = title
	instructionText.Text = instruction
	hintText.Text = hint
	hintText.Visible = hint ~= ""

	local showProgress = stage == "CleanSpills" or stage == "CollectGems"
	setProgressBar(progress, goal, showProgress)

	progressCounter.Text = progressLabel ~= "" and progressLabel or ("Progress: " .. tostring(progress) .. " / " .. tostring(goal))
	counterRow.Visible = showProgress
	remainingCounter.Visible = false

	primaryButton.Text = button
	buttonRow.Visible = button ~= ""
	primaryButton.Visible = button ~= ""
	skipButton.Visible = stage ~= "TutorialComplete"
	layoutPanel(showProgress, button ~= "")
	task.defer(syncShadowToPanel)
	updateGuidance()

	showReward(getText("LastRewardMessage", ""))
end

primaryButton.Activated:Connect(function()
	local stage = getText("Stage", "Welcome")
	if stage == "Welcome" then
		tutorialActionEvent:FireServer("StartTutorial")
	elseif stage == "EarnCoins" then
		tutorialActionEvent:FireServer("CoinsStepDone")
	elseif stage == "UseGems" then
		tutorialActionEvent:FireServer("GemsStepDone")
	elseif stage == "LearnUI" then
		if tourIndex < #tourItems then
			tourIndex += 1
			refresh()
		else
			tutorialActionEvent:FireServer("UITourDone")
		end
	elseif stage == "TutorialComplete" then
		tutorialActionEvent:FireServer("FinishTutorial")
		setPanelVisible(false)
	end
end)

skipButton.Activated:Connect(function()
	tutorialActionEvent:FireServer("SkipTutorial")
	setPanelVisible(false)
end)

for _, value in pairs(values) do
	if value then
		value:GetPropertyChangedSignal("Value"):Connect(refresh)
	end
end
player.CharacterAdded:Connect(function()
	task.wait(0.4)
	refresh()
end)

task.spawn(function()
	while guideRoot.Parent do
		task.wait(0.85)
		if guideRoot.Visible and (getText("Stage", "") == "CleanSpills" or getText("Stage", "") == "CollectGems") then
			updateGuidance()
		end
	end
end)

task.defer(refresh)
