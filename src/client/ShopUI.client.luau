-- Equipment shop for paintbrushes and rollers.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local UIManager = require(ReplicatedStorage:WaitForChild("UIManager"))
local ToolData = require(ReplicatedStorage:WaitForChild("ToolData"))
local ColorData = require(ReplicatedStorage:WaitForChild("ColorData"))
local UpgradeData = require(ReplicatedStorage:WaitForChild("UpgradeData"))
local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))
local ClientUIRoot = require(ReplicatedStorage:WaitForChild("ClientUIRoot"))

local Events = ReplicatedStorage:WaitForChild("Events")
local purchaseEvent = Events:WaitForChild("PurchasePaintTool")
local equipEvent = Events:WaitForChild("EquipPaintTool")
local tutorialActionEvent = Events:WaitForChild("TutorialAction", 10)
local purchaseUpgradeEvent = Events:WaitForChild("PurchaseUpgrade")
local markTutorialProgressEvent = Events:WaitForChild("MarkTutorialProgress")
local dailyQuestRemote = ReplicatedStorage:WaitForChild("DailyQuestRemote", 10)

local openBrushShopEvent = ReplicatedStorage:FindFirstChild("OpenBrushShop")
if not openBrushShopEvent then
	openBrushShopEvent = Instance.new("BindableEvent")
	openBrushShopEvent.Name = "OpenBrushShop"
	openBrushShopEvent.Parent = ReplicatedStorage
end

local colorStorage = player:WaitForChild("ColorStorage", 10)
local unlockedColorsValue = colorStorage and colorStorage:WaitForChild("UnlockedColors", 10)
local currentWorldValue = colorStorage and colorStorage:WaitForChild("CurrentWorld", 10)

local DARK = Color3.fromRGB(35, 38, 45)
local WHITE = Color3.fromRGB(255, 255, 255)
local CYAN = Color3.fromRGB(118, 238, 244)
local GREEN = Color3.fromRGB(116, 245, 42)
local RED = Color3.fromRGB(255, 24, 96)
local YELLOW = Color3.fromRGB(255, 235, 105)
local LAVENDER = Color3.fromRGB(232, 234, 250)
local PANEL_WIDTH = 700
local PANEL_HEIGHT = 540
local ZORK_DIALOGUE_LINES = {
	"zzt. hey there. i'm zork.",
	"i sell brushes. better brushes clean color faster.",
	"colors can hatch with traits. traits are small passive bonuses.",
	"bring coins, pick the brush that fits your sector, and keep moving.",
}
local ZORK_ORANGE_INTERIOR_LINES = {
	"zzt. welcome to the inside of the orange sector.",
	"orange is where progression starts getting serious: tougher spills, better tools, and better eggs.",
	"the mutation core wakes up in here. unlock it and future colors can hatch as rare mutated versions.",
	"mutations show on hatch results and inventory cards, so you will know when you hit something special.",
	"take the pipe when you want to head back up.",
}
local ZORK_QUEST_LINES = {
	"zzt. quests? yeah. i track three jobs for you every day.",
	"finish them before the daily reset and you can claim Gems.",
	"clean spills, collect powers, break gems, earn coins, buy brushes. simple work. good rewards.",
	"open the daily quest button anytime to check progress or claim.",
}

local screenGui = ClientUIRoot.GetLayer(player.PlayerGui, "EquipmentShopUI")

local overlay = UITheme.CreateDimOverlay(screenGui, 50)

local panel = Instance.new("Frame")
panel.Name = "EquipmentShopPanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Size = UDim2.new(0, PANEL_WIDTH, 0, PANEL_HEIGHT)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.BackgroundColor3 = WHITE
panel.BorderSizePixel = 0
panel.Visible = false
panel.ZIndex = 60
panel.Parent = screenGui
UITheme.ApplyResponsiveScale(panel, PANEL_WIDTH, PANEL_HEIGHT, 0.74, 28)
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 24)
local panelStroke = Instance.new("UIStroke")
panelStroke.Color = DARK
panelStroke.Thickness = 5
panelStroke.Parent = panel

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 66)
header.BackgroundColor3 = CYAN
header.BorderSizePixel = 0
header.Parent = panel
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 24)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -82, 1, 0)
title.Position = UDim2.new(0, 22, 0, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.LuckiestGuy
title.TextSize = 31
title.TextColor3 = WHITE
title.TextStrokeTransparency = 0
title.TextStrokeColor3 = DARK
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "BRUSH SHOP"
title.Parent = header

local currentTab = "Brushes"
local pendingUpgradeId = nil
local pendingPurchaseTicket = 0
local activeShopColor = nil
local dialogueOpen = false
local dialogueToken = 0
local activeDialoguePrompt = nil
local openShopForColor

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 44, 0, 44)
closeBtn.Position = UDim2.new(1, -58, 0.5, -22)
closeBtn.BackgroundColor3 = RED
closeBtn.AutoButtonColor = false
closeBtn.Font = Enum.Font.LuckiestGuy
closeBtn.TextSize = 25
closeBtn.TextColor3 = WHITE
closeBtn.TextStrokeTransparency = 0
closeBtn.TextStrokeColor3 = DARK
closeBtn.Text = "X"
closeBtn.Parent = header
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 14)
local closeStroke = Instance.new("UIStroke")
closeStroke.Color = DARK
closeStroke.Thickness = 4
closeStroke.Parent = closeBtn

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -36, 0, 32)
status.Position = UDim2.new(0, 18, 0, 74)
status.BackgroundTransparency = 1
status.Font = Enum.Font.GothamBold
status.TextSize = 14
status.TextColor3 = Color3.fromRGB(80, 84, 104)
status.TextXAlignment = Enum.TextXAlignment.Left
status.Text = "Buy better brushes to collect Color faster."
status.Parent = panel

local tabRow = Instance.new("Frame")
tabRow.Size = UDim2.new(1, -34, 0, 38)
tabRow.Position = UDim2.new(0, 17, 0, 108)
tabRow.BackgroundTransparency = 1
tabRow.Parent = panel

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
tabLayout.Padding = UDim.new(0, 10)
tabLayout.Parent = tabRow

local function makeTabButton(tabName)
	local button = Instance.new("TextButton")
	button.Name = tabName .. "Tab"
	button.Size = UDim2.new(0, 136, 0, 34)
	button.BackgroundColor3 = LAVENDER
	button.AutoButtonColor = false
	button.Font = Enum.Font.LuckiestGuy
	button.TextSize = 17
	button.TextColor3 = WHITE
	button.TextStrokeTransparency = 0
	button.TextStrokeColor3 = DARK
	button.Text = string.upper(tabName)
	button.Parent = tabRow
	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 12)
	local stroke = Instance.new("UIStroke")
	stroke.Color = DARK
	stroke.Thickness = 3
	stroke.Parent = button
	return button
end

local brushesTab = makeTabButton("Brushes")
local upgradesTab = makeTabButton("Upgrades")
upgradesTab.Visible = false

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -34, 1, -166)
scroll.Position = UDim2.new(0, 17, 0, 154)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 6
scroll.ScrollBarImageColor3 = DARK
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.Parent = panel

local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.new(0, 314, 0, 172)
grid.CellPadding = UDim2.new(0, 14, 0, 14)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = scroll
grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	scroll.CanvasSize = UDim2.new(0, 0, 0, grid.AbsoluteContentSize.Y + 18)
end)

local pad = Instance.new("UIPadding")
pad.PaddingLeft = UDim.new(0, 4)
pad.PaddingTop = UDim.new(0, 4)
pad.PaddingBottom = UDim.new(0, 8)
pad.Parent = scroll

local function formatNum(value)
	value = tonumber(value) or 0
	if value >= 1000000 then
		return string.format("%.1fM", value / 1000000)
	elseif value >= 1000 then
		return string.format("%.1fK", value / 1000)
	end
	return tostring(value)
end

local function getToolValues()
	local folder = player:FindFirstChild("PaintTools")
	return folder and folder:FindFirstChild("Owned"), folder and folder:FindFirstChild("Equipped")
end

local function getOwnedSet()
	local ownedValue = getToolValues()
	local set = { StarterBrush = true }
	local csv = ownedValue and ownedValue.Value or "StarterBrush"
	for _, toolId in ipairs(string.split(csv, ",")) do
		if toolId ~= "" then
			set[toolId] = true
		end
	end
	return set
end

local function getEquippedToolId()
	local _, equippedValue = getToolValues()
	return equippedValue and equippedValue.Value ~= "" and equippedValue.Value or "StarterBrush"
end

local function isToolUnlocked(tool)
	local requiredColor = tool.RequiredColor or "Red"
	if requiredColor == "Red" then
		return true
	end
	return unlockedColorsValue and ColorData.isColorUnlocked(unlockedColorsValue.Value, requiredColor)
end

local function getToolWorldName(tool)
	local world = ColorData.getWorldByColor(tool.RequiredColor or "Red")
	return world and world.name or "Starter Field"
end

local function getCurrentShopColor()
	local colorType = activeShopColor
		or (currentWorldValue and currentWorldValue.Value)
		or player:GetAttribute("ActiveWorldColor")
		or "Red"
	local world = ColorData.getWorldByColor(colorType)
	return world and world.primaryColor or "Red"
end

local function getPromptColor(prompt)
	local instance = prompt
	while instance do
		local colorType = instance:GetAttribute("ColorType")
			or instance:GetAttribute("AreaColor")
			or instance:GetAttribute("ShopColor")
			or instance:GetAttribute("WorldColor")
		if colorType and ColorData.getWorldByColor(colorType) then
			return ColorData.getWorldByColor(colorType).primaryColor
		end

		local zoneId = instance:GetAttribute("ZoneId")
		if zoneId then
			for _, world in ipairs(ColorData.Worlds or {}) do
				if world.ZoneId == zoneId then
					return world.primaryColor
				end
			end
		end
		instance = instance.Parent
	end
	return getCurrentShopColor()
end

local function hasSeenTraitsTutorial()
	local folder = player:FindFirstChild("TutorialProgress")
	local seen = folder and folder:FindFirstChild("SeenTraitsTutorial")
	return seen and seen.Value == true
end

local function shouldShowTraitsTutorial(colorType)
	if hasSeenTraitsTutorial() then
		return false
	end
	local worldIndex = ColorData.getWorldIndex(colorType) or 1
	return worldIndex >= 2
end

local function clearCards()
	for _, child in ipairs(scroll:GetChildren()) do
		if not child:IsA("UIGridLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function applyModalLayer()
	panel.ZIndex = 60
	for _, obj in ipairs(panel:GetDescendants()) do
		if obj:IsA("GuiObject") and obj.ZIndex < 61 then
			obj.ZIndex = 61
		end
	end
	closeBtn.ZIndex = 70
end

local refresh

local dialogueGui = Instance.new("Frame")
dialogueGui.Name = "ZorkDialogue"
dialogueGui.AnchorPoint = Vector2.new(0.5, 1)
dialogueGui.Size = UDim2.new(0, 580, 0, 208)
dialogueGui.Position = UDim2.new(0.5, 0, 1, -188)
dialogueGui.BackgroundColor3 = Color3.fromRGB(20, 23, 31)
dialogueGui.BorderSizePixel = 0
dialogueGui.Visible = false
dialogueGui.ZIndex = 210
dialogueGui.Parent = screenGui
UITheme.ApplyResponsiveScale(dialogueGui, 580, 208, 0.78, 24)
Instance.new("UICorner", dialogueGui).CornerRadius = UDim.new(0, 12)
local dialogueStroke = Instance.new("UIStroke")
dialogueStroke.Color = CYAN
dialogueStroke.Thickness = 4
dialogueStroke.Parent = dialogueGui

local dialogueName = Instance.new("TextLabel")
dialogueName.Size = UDim2.new(0, 150, 0, 30)
dialogueName.Position = UDim2.new(0, 18, 0, 14)
dialogueName.BackgroundTransparency = 1
dialogueName.Font = Enum.Font.GothamBlack
dialogueName.TextSize = 22
dialogueName.TextColor3 = Color3.fromRGB(176, 246, 250)
dialogueName.TextXAlignment = Enum.TextXAlignment.Left
dialogueName.Text = "Zork"
dialogueName.ZIndex = 211
dialogueName.Parent = dialogueGui

local dialogueRole = Instance.new("TextLabel")
dialogueRole.Size = UDim2.new(1, -190, 0, 24)
dialogueRole.Position = UDim2.new(0, 116, 0, 18)
dialogueRole.BackgroundTransparency = 1
dialogueRole.Font = Enum.Font.GothamBold
dialogueRole.TextSize = 13
dialogueRole.TextColor3 = Color3.fromRGB(160, 170, 184)
dialogueRole.TextXAlignment = Enum.TextXAlignment.Left
dialogueRole.Text = "Brush Merchant"
dialogueRole.ZIndex = 211
dialogueRole.Parent = dialogueGui

local dialogueText = Instance.new("TextLabel")
dialogueText.Size = UDim2.new(1, -36, 0, 92)
dialogueText.Position = UDim2.new(0, 18, 0, 54)
dialogueText.BackgroundTransparency = 1
dialogueText.Font = Enum.Font.GothamBold
dialogueText.TextSize = 18
dialogueText.TextColor3 = WHITE
dialogueText.TextWrapped = true
dialogueText.TextXAlignment = Enum.TextXAlignment.Left
dialogueText.TextYAlignment = Enum.TextYAlignment.Top
dialogueText.Text = ""
dialogueText.ZIndex = 211
dialogueText.Parent = dialogueGui

local dialogueNext = Instance.new("TextButton")
dialogueNext.Size = UDim2.new(0, 142, 0, 44)
dialogueNext.Position = UDim2.new(1, -160, 1, -58)
dialogueNext.BackgroundColor3 = CYAN
dialogueNext.AutoButtonColor = false
dialogueNext.Font = Enum.Font.LuckiestGuy
dialogueNext.TextSize = 17
dialogueNext.TextColor3 = WHITE
dialogueNext.TextStrokeTransparency = 0
dialogueNext.TextStrokeColor3 = DARK
dialogueNext.Text = "NEXT"
dialogueNext.ZIndex = 211
dialogueNext.Parent = dialogueGui
UITheme.ApplyTouchTarget(dialogueNext, 44)
Instance.new("UICorner", dialogueNext).CornerRadius = UDim.new(0, 10)
local nextStroke = Instance.new("UIStroke")
nextStroke.Color = DARK
nextStroke.Thickness = 3
nextStroke.Parent = dialogueNext

local dialogueSkip = Instance.new("TextButton")
dialogueSkip.Size = UDim2.new(0, 98, 0, 44)
dialogueSkip.Position = UDim2.new(1, -390, 1, -58)
dialogueSkip.BackgroundColor3 = Color3.fromRGB(62, 68, 82)
dialogueSkip.AutoButtonColor = false
dialogueSkip.Font = Enum.Font.LuckiestGuy
dialogueSkip.TextSize = 16
dialogueSkip.TextColor3 = WHITE
dialogueSkip.TextStrokeTransparency = 0.35
dialogueSkip.TextStrokeColor3 = DARK
dialogueSkip.Text = "SHOP"
dialogueSkip.ZIndex = 211
dialogueSkip.Parent = dialogueGui
UITheme.ApplyTouchTarget(dialogueSkip, 44)
Instance.new("UICorner", dialogueSkip).CornerRadius = UDim.new(0, 10)

local dialogueQuest = Instance.new("TextButton")
dialogueQuest.Size = UDim2.new(0, 116, 0, 44)
dialogueQuest.Position = UDim2.new(1, -282, 1, -58)
dialogueQuest.BackgroundColor3 = YELLOW
dialogueQuest.AutoButtonColor = false
dialogueQuest.Font = Enum.Font.LuckiestGuy
dialogueQuest.TextSize = 16
dialogueQuest.TextColor3 = WHITE
dialogueQuest.TextStrokeTransparency = 0.2
dialogueQuest.TextStrokeColor3 = DARK
dialogueQuest.Text = "QUESTS"
dialogueQuest.ZIndex = 211
dialogueQuest.Parent = dialogueGui
UITheme.ApplyTouchTarget(dialogueQuest, 44)
Instance.new("UICorner", dialogueQuest).CornerRadius = UDim.new(0, 10)
local questStroke = Instance.new("UIStroke")
questStroke.Color = DARK
questStroke.Thickness = 3
questStroke.Parent = dialogueQuest

local function updateDialogueLayoutForViewport()
	local viewport = UITheme.GetViewportSize()
	local compact = UITheme.IsTouchDevice() or viewport.X < 900 or viewport.Y < 650
	if compact then
		dialogueGui.AnchorPoint = Vector2.new(0.5, 0)
		dialogueGui.Position = UDim2.new(0.5, 0, 0, 84)
		dialogueGui.Size = UDim2.new(0, 560, 0, 208)
	else
		dialogueGui.AnchorPoint = Vector2.new(0.5, 1)
		dialogueGui.Position = UDim2.new(0.5, 0, 1, -188)
		dialogueGui.Size = UDim2.new(0, 580, 0, 208)
	end
end

updateDialogueLayoutForViewport()
local function hookDialogueCamera()
	local currentCamera = workspace.CurrentCamera
	if currentCamera then
		currentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateDialogueLayoutForViewport)
	end
end
hookDialogueCamera()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	task.defer(function()
		updateDialogueLayoutForViewport()
		hookDialogueCamera()
	end)
end)

local zorkVoice = Instance.new("Sound")
zorkVoice.Name = "ZorkVoiceBlip"
zorkVoice.SoundId = "rbxasset://sounds/electronicpingshort.wav"
zorkVoice.Volume = 0.18
zorkVoice.PlaybackSpeed = 1.45
zorkVoice.Parent = SoundService

local function playZorkBlip(index)
	zorkVoice.PlaybackSpeed = 1.28 + ((index % 5) * 0.08)
	zorkVoice.TimePosition = 0
	zorkVoice:Play()
end

local function hideDialogue()
	dialogueToken += 1
	dialogueOpen = false
	dialogueGui.Visible = false
	dialogueText.Text = ""
	if activeDialoguePrompt and activeDialoguePrompt.Parent then
		activeDialoguePrompt.Enabled = true
	end
	activeDialoguePrompt = nil
end

local function openShopAfterDialogue(colorType)
	hideDialogue()
	openShopForColor(colorType)
end

local function openDailyQuestsAfterDialogue()
	hideDialogue()
	if dailyQuestRemote then
		dailyQuestRemote:FireServer("UnlockFromZork")
	end
end

local function showZorkDialogue(colorType, options)
	options = options or {}
	if dialogueOpen then
		return
	end
	if options.prompt and options.prompt:IsA("ProximityPrompt") then
		activeDialoguePrompt = options.prompt
		activeDialoguePrompt.Enabled = false
	end
	dialogueOpen = true
	dialogueToken += 1
	local token = dialogueToken
	local lineIndex = 1
	local isOrangeInterior = options.orangeInterior == true
	local lines = isOrangeInterior and ZORK_ORANGE_INTERIOR_LINES or ZORK_DIALOGUE_LINES
	local typeTicket = 0
	local finishAction = isOrangeInterior and hideDialogue or function()
		openShopAfterDialogue(colorType)
	end
	local finishButtonText = isOrangeInterior and "DONE" or "OPEN"
	local typing = false
	local fullLine = ""
	local requestedAdvance = false

	dialogueGui.Visible = true
	dialogueText.Text = ""
	dialogueNext.Text = "NEXT"
	dialogueSkip.Visible = not isOrangeInterior
	dialogueQuest.Visible = true

	local function startLines(newLines, newFinishAction, newFinishButtonText)
		lines = newLines
		finishAction = newFinishAction
		finishButtonText = newFinishButtonText or "OPEN"
		lineIndex = 1
		dialogueNext.Text = "NEXT"
		typeTicket += 1
		local activeTypeTicket = typeTicket
		task.spawn(function()
			if token == dialogueToken and activeTypeTicket == typeTicket then
				typing = false
				requestedAdvance = false
				fullLine = ""
				local currentLine = lines[lineIndex] or ""
				dialogueText.Text = ""
				typing = true
				fullLine = currentLine
				for i = 1, #currentLine do
					if token ~= dialogueToken or activeTypeTicket ~= typeTicket then
						return
					end
					if requestedAdvance then
						dialogueText.Text = currentLine
						break
					end
					dialogueText.Text = string.sub(currentLine, 1, i)
					local char = string.sub(currentLine, i, i)
					if char ~= " " and char ~= "\n" then
						playZorkBlip(i)
					end
					task.wait(0.028)
				end
				typing = false
				dialogueNext.Text = lineIndex >= #lines and finishButtonText or "NEXT"
			end
		end)
	end

	local function typeLine()
		if token ~= dialogueToken then
			return
		end
		typeTicket += 1
		local activeTypeTicket = typeTicket
		typing = true
		requestedAdvance = false
		fullLine = lines[lineIndex] or ""
		dialogueText.Text = ""
		for i = 1, #fullLine do
			if token ~= dialogueToken or activeTypeTicket ~= typeTicket then
				return
			end
			if requestedAdvance then
				dialogueText.Text = fullLine
				break
			end
			dialogueText.Text = string.sub(fullLine, 1, i)
			local char = string.sub(fullLine, i, i)
			if char ~= " " and char ~= "\n" then
				playZorkBlip(i)
			end
			task.wait(0.028)
		end
		typing = false
		dialogueNext.Text = lineIndex >= #lines and finishButtonText or "NEXT"
	end

	local function advance()
		if token ~= dialogueToken then
			return
		end
		if typing then
			requestedAdvance = true
			dialogueText.Text = fullLine
			return
		end
		if lineIndex >= #lines then
			finishAction()
			return
		end
		lineIndex += 1
		task.spawn(typeLine)
	end

	local nextConnection
	local skipConnection
	nextConnection = dialogueNext.Activated:Connect(function()
		if token ~= dialogueToken then
			if nextConnection then nextConnection:Disconnect() end
			return
		end
		advance()
	end)
	skipConnection = dialogueSkip.Activated:Connect(function()
		if token ~= dialogueToken then
			if skipConnection then skipConnection:Disconnect() end
			return
		end
		openShopAfterDialogue(colorType)
	end)
	local questConnection
	questConnection = dialogueQuest.Activated:Connect(function()
		if token ~= dialogueToken then
			if questConnection then questConnection:Disconnect() end
			return
		end
		dialogueSkip.Visible = false
		startLines(ZORK_QUEST_LINES, openDailyQuestsAfterDialogue, "OPEN")
	end)

	task.spawn(typeLine)
end

local function getUpgradeLevel(upgradeId)
	local folder = player:FindFirstChild("Upgrades")
	if not folder then
		return 0
	end

	local levelValue = folder:FindFirstChild(upgradeId .. "_Level")
	return levelValue and levelValue.Value or 0
end

local function updateTabs()
	brushesTab.BackgroundColor3 = currentTab == "Brushes" and CYAN or LAVENDER
	title.Text = "BRUSH SHOP"
end

local function setDefaultStatus()
	local world = ColorData.getWorldByColor(getCurrentShopColor())
	status.Text = "Brushes for " .. tostring(world and world.name or "this sector") .. "."
	status.TextColor3 = Color3.fromRGB(80, 84, 104)
end

local function buildCard(tool, layoutOrder)
	local ownedSet = getOwnedSet()
	local owned = ownedSet[tool.Id] == true
	local equipped = owned and getEquippedToolId() == tool.Id
	local rarityColor = ToolData.RarityColors[tool.Rarity or "Common"] or CYAN
	local unlocked = isToolUnlocked(tool)

	local card = Instance.new("Frame")
	card.LayoutOrder = layoutOrder
	card.BackgroundColor3 = equipped and Color3.fromRGB(236, 255, 252) or Color3.fromRGB(250, 255, 255)
	card.BorderSizePixel = 0
	card.Parent = scroll
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 18)
	local stroke = Instance.new("UIStroke")
	stroke.Color = equipped and rarityColor or DARK
	stroke.Thickness = equipped and 5 or 3
	stroke.Parent = card

	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.new(0, 86, 1, 0)
	icon.BackgroundColor3 = rarityColor:Lerp(WHITE, 0.25)
	icon.Font = Enum.Font.LuckiestGuy
	icon.TextSize = 38
	icon.TextColor3 = WHITE
	icon.TextStrokeTransparency = 0
	icon.TextStrokeColor3 = DARK
	icon.Text = tool.ShortName or "BR"
	icon.Parent = card
	Instance.new("UICorner", icon).CornerRadius = UDim.new(0, 18)

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -104, 0, 28)
	name.Position = UDim2.new(0, 98, 0, 14)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.LuckiestGuy
	name.TextSize = 20
	name.TextScaled = true
	name.TextColor3 = DARK
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Text = tool.DisplayName
	name.Parent = card
	UITheme.ApplyTextSizeConstraint(name, 12, 20)

	local rarity = Instance.new("TextLabel")
	rarity.Size = UDim2.new(1, -104, 0, 18)
	rarity.Position = UDim2.new(0, 98, 0, 43)
	rarity.BackgroundTransparency = 1
	rarity.Font = Enum.Font.GothamBold
	rarity.TextSize = 11
	rarity.TextColor3 = rarityColor
	rarity.TextXAlignment = Enum.TextXAlignment.Left
	rarity.Text = tostring(tool.Rarity or "Common") .. " | " .. getToolWorldName(tool)
	rarity.Parent = card

	local stats = Instance.new("TextLabel")
	stats.Size = UDim2.new(1, -104, 0, 36)
	stats.Position = UDim2.new(0, 98, 0, 66)
	stats.BackgroundTransparency = 1
	stats.Font = Enum.Font.GothamBold
	stats.TextSize = 12
	stats.TextColor3 = Color3.fromRGB(80, 84, 104)
	stats.TextXAlignment = Enum.TextXAlignment.Left
	stats.TextYAlignment = Enum.TextYAlignment.Top
	stats.TextWrapped = true
	stats.Text = "Range " .. tostring(tool.Range) .. " | Power x" .. tostring(tool.PowerMultiplier)
	stats.Parent = card

	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(1, -104, 0, 38)
	desc.Position = UDim2.new(0, 98, 0, 96)
	desc.BackgroundTransparency = 1
	desc.Font = Enum.Font.Gotham
	desc.TextSize = 11
	desc.TextColor3 = Color3.fromRGB(80, 84, 104)
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextYAlignment = Enum.TextYAlignment.Top
	desc.TextWrapped = true
	desc.Text = tool.Description or ""
	desc.Parent = card

	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0, 178, 0, 28)
	button.Position = UDim2.new(0, 98, 1, -36)
	button.BackgroundColor3 = not unlocked and LAVENDER or equipped and LAVENDER or (owned and GREEN or YELLOW)
	button.AutoButtonColor = false
	button.Font = Enum.Font.LuckiestGuy
	button.TextSize = 14
	button.TextColor3 = WHITE
	button.TextStrokeTransparency = 0
	button.TextStrokeColor3 = DARK
	button.Text = not unlocked and ("UNLOCK " .. string.upper(tostring(tool.RequiredColor or ""))) or equipped and "EQUIPPED" or (owned and "EQUIP" or ("BUY " .. formatNum(tool.Cost) .. " COINS"))
	button.Parent = card
	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 10)
	local buttonStroke = Instance.new("UIStroke")
	buttonStroke.Color = DARK
	buttonStroke.Thickness = 3
	buttonStroke.Parent = button

	button.MouseButton1Click:Connect(function()
		if not unlocked then
			status.Text = "Unlock " .. getToolWorldName(tool) .. " to buy this brush."
			status.TextColor3 = RED
		elseif equipped then
			status.Text = tool.DisplayName .. " is already equipped."
			status.TextColor3 = Color3.fromRGB(80, 84, 104)
		elseif owned then
			equipEvent:FireServer(tool.Id, true)
		else
			purchaseEvent:FireServer(tool.Id)
		end
	end)
end

local function buildUpgradeCard(upg, layoutOrder)
	local level = getUpgradeLevel(upg.id)
	local maxLevel = #upg.levels
	local maxed = level >= maxLevel
	local pending = pendingUpgradeId == upg.id
	local nextLevel = math.min(level + 1, maxLevel)
	local cost = not maxed and upg.levels[nextLevel].cost or 0

	local card = Instance.new("Frame")
	card.LayoutOrder = layoutOrder
	card.BackgroundColor3 = Color3.fromRGB(246, 244, 255)
	card.BorderSizePixel = 0
	card.Parent = scroll
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 18)
	local stroke = Instance.new("UIStroke")
	stroke.Color = DARK
	stroke.Thickness = 3
	stroke.Parent = card

	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.new(0, 86, 1, 0)
	icon.BackgroundColor3 = UITheme.Colors.PrimaryPurple
	icon.Font = Enum.Font.LuckiestGuy
	icon.TextSize = 30
	icon.TextColor3 = WHITE
	icon.TextStrokeTransparency = 0
	icon.TextStrokeColor3 = DARK
	icon.Text = upg.icon or "UP"
	icon.Parent = card
	Instance.new("UICorner", icon).CornerRadius = UDim.new(0, 18)

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -210, 0, 28)
	name.Position = UDim2.new(0, 98, 0, 14)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.LuckiestGuy
	name.TextSize = 20
	name.TextScaled = true
	name.TextColor3 = DARK
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Text = upg.displayName
	name.Parent = card
	UITheme.ApplyTextSizeConstraint(name, 12, 20)

	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(1, -210, 0, 22)
	desc.Position = UDim2.new(0, 98, 0, 44)
	desc.BackgroundTransparency = 1
	desc.Font = Enum.Font.GothamBold
	desc.TextSize = 12
	desc.TextColor3 = Color3.fromRGB(80, 84, 104)
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextTruncate = Enum.TextTruncate.AtEnd
	desc.Text = upg.description or ""
	desc.Parent = card

	local value = Instance.new("TextLabel")
	value.Size = UDim2.new(1, -210, 0, 22)
	value.Position = UDim2.new(0, 98, 0, 68)
	value.BackgroundTransparency = 1
	value.Font = Enum.Font.GothamBold
	value.TextSize = 12
	value.TextColor3 = Color3.fromRGB(65, 80, 130)
	value.TextXAlignment = Enum.TextXAlignment.Left
	value.Text = "Level " .. level .. "/" .. maxLevel .. " | " .. UpgradeData.getValueDisplay(upg.id, level)
	value.Parent = card

	local nextText = Instance.new("TextLabel")
	nextText.Size = UDim2.new(1, -210, 0, 22)
	nextText.Position = UDim2.new(0, 98, 0, 92)
	nextText.BackgroundTransparency = 1
	nextText.Font = Enum.Font.GothamBold
	nextText.TextSize = 12
	nextText.TextColor3 = maxed and Color3.fromRGB(90, 150, 95) or Color3.fromRGB(130, 100, 40)
	nextText.TextXAlignment = Enum.TextXAlignment.Left
	nextText.Text = maxed and "MAXED" or ("Next: " .. UpgradeData.getValueDisplay(upg.id, nextLevel) .. " | " .. UpgradeData.formatNumber(cost) .. " Coins")
	nextText.Parent = card

	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0, 112, 0, 42)
	button.Position = UDim2.new(1, -128, 0.5, -21)
	button.BackgroundColor3 = (maxed or pending) and LAVENDER or GREEN
	button.AutoButtonColor = not maxed and not pending
	button.Active = not maxed and not pending
	button.Font = Enum.Font.LuckiestGuy
	button.TextSize = 18
	button.TextColor3 = WHITE
	button.TextStrokeTransparency = 0
	button.TextStrokeColor3 = DARK
	button.Text = maxed and "MAX" or pending and "BUYING" or "BUY"
	button.Parent = card
	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 12)
	local buttonStroke = Instance.new("UIStroke")
	buttonStroke.Color = DARK
	buttonStroke.Thickness = 3
	buttonStroke.Parent = button

	button.MouseButton1Click:Connect(function()
		if maxed or pendingUpgradeId then
			return
		end
		pendingUpgradeId = upg.id
		pendingPurchaseTicket += 1
		local ticket = pendingPurchaseTicket
		status.Text = "Buying " .. upg.displayName .. "..."
		status.TextColor3 = Color3.fromRGB(80, 84, 104)
		purchaseUpgradeEvent:FireServer(upg.id)
		refresh()

		task.delay(8, function()
			if pendingUpgradeId == upg.id and pendingPurchaseTicket == ticket then
				pendingUpgradeId = nil
				status.Text = "Purchase failed. Try again."
				status.TextColor3 = RED
				refresh()
			end
		end)
	end)
end

function refresh()
	clearCards()
	currentTab = "Brushes"
	updateTabs()
	grid.CellSize = UDim2.new(0, 314, 0, 172)
	for index, tool in ipairs(ToolData.GetBrushesForWorldColor(getCurrentShopColor())) do
		buildCard(tool, index)
	end
	scroll.CanvasSize = UDim2.new(0, 0, 0, grid.AbsoluteContentSize.Y + 18)
	applyModalLayer()
end

local isOpen = false
local function toggleShop(open)
	isOpen = open
	if open then
		refresh()
		setDefaultStatus()
		overlay.Visible = true
		overlay.BackgroundTransparency = 1
		panel.Visible = true
		panel.Size = UDim2.new(0, 80, 0, 80)
		panel.Position = UDim2.fromScale(0.5, 0.5)
		TweenService:Create(overlay, TweenInfo.new(0.18), {
			BackgroundTransparency = 0.4,
		}):Play()
		TweenService:Create(panel, TweenInfo.new(0.28, Enum.EasingStyle.Back), {
			Size = UDim2.new(0, PANEL_WIDTH, 0, PANEL_HEIGHT),
			Position = UDim2.fromScale(0.5, 0.5),
		}):Play()
	else
		TweenService:Create(overlay, TweenInfo.new(0.16), {
			BackgroundTransparency = 1,
		}):Play()
		TweenService:Create(panel, TweenInfo.new(0.16), {
			Size = UDim2.new(0, 0, 0, 0),
			Position = UDim2.fromScale(0.5, 0.5),
		}):Play()
		task.wait(0.16)
		panel.Visible = false
		overlay.Visible = false
	end
end

local tutorialOpen = false
local function showTraitsTutorial(onDone)
	if tutorialOpen then
		return
	end
	tutorialOpen = true

	local tutorialOverlay = UITheme.CreateDimOverlay(screenGui, 95)
	tutorialOverlay.Visible = true
	tutorialOverlay.BackgroundTransparency = 0.35

	local tutorialPanel = Instance.new("Frame")
	tutorialPanel.Name = "TraitsUnlockedTutorial"
	tutorialPanel.AnchorPoint = Vector2.new(0.5, 0.5)
	tutorialPanel.Size = UDim2.new(0, 520, 0, 260)
	tutorialPanel.Position = UDim2.fromScale(0.5, 0.5)
	tutorialPanel.BackgroundColor3 = WHITE
	tutorialPanel.BorderSizePixel = 0
	tutorialPanel.ZIndex = 100
	tutorialPanel.Parent = screenGui
	UITheme.ApplyResponsiveScale(tutorialPanel, 520, 260, 0.72, 24)
	Instance.new("UICorner", tutorialPanel).CornerRadius = UDim.new(0, 22)
	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = DARK
	panelStroke.Thickness = 5
	panelStroke.Parent = tutorialPanel

	local tutorialHeader = Instance.new("Frame")
	tutorialHeader.Size = UDim2.new(1, 0, 0, 62)
	tutorialHeader.BackgroundColor3 = CYAN
	tutorialHeader.BorderSizePixel = 0
	tutorialHeader.ZIndex = 101
	tutorialHeader.Parent = tutorialPanel
	Instance.new("UICorner", tutorialHeader).CornerRadius = UDim.new(0, 22)

	local tutorialTitle = Instance.new("TextLabel")
	tutorialTitle.Size = UDim2.new(1, -34, 1, 0)
	tutorialTitle.Position = UDim2.new(0, 17, 0, 0)
	tutorialTitle.BackgroundTransparency = 1
	tutorialTitle.Font = Enum.Font.LuckiestGuy
	tutorialTitle.TextSize = 28
	tutorialTitle.TextColor3 = WHITE
	tutorialTitle.TextStrokeTransparency = 0
	tutorialTitle.TextStrokeColor3 = DARK
	tutorialTitle.TextXAlignment = Enum.TextXAlignment.Left
	tutorialTitle.Text = "TRAITS UNLOCKED!"
	tutorialTitle.ZIndex = 102
	tutorialTitle.Parent = tutorialHeader

	local body = Instance.new("TextLabel")
	body.Size = UDim2.new(1, -44, 0, 104)
	body.Position = UDim2.new(0, 22, 0, 84)
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.GothamBold
	body.TextSize = 17
	body.TextColor3 = Color3.fromRGB(58, 62, 78)
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
body.Text = "Colors can hatch with Traits. Traits are small passive bonuses like faster brushing, better Coin rewards, higher jumps, or extra luck.\n\nMutations unlock at the Mutation Core inside Orange Sector."
	body.ZIndex = 101
	body.Parent = tutorialPanel

	local function finish()
		markTutorialProgressEvent:FireServer("SeenTraitsTutorial")
		local folder = player:FindFirstChild("TutorialProgress")
		local seen = folder and folder:FindFirstChild("SeenTraitsTutorial")
		if seen then
			seen.Value = true
		end
		tutorialOpen = false
		tutorialOverlay:Destroy()
		tutorialPanel:Destroy()
		if onDone then
			onDone()
		end
	end

	local continueButton = Instance.new("TextButton")
	continueButton.Size = UDim2.new(0, 156, 0, 42)
	continueButton.Position = UDim2.new(1, -188, 1, -60)
	continueButton.BackgroundColor3 = GREEN
	continueButton.AutoButtonColor = false
	continueButton.Font = Enum.Font.LuckiestGuy
	continueButton.TextSize = 18
	continueButton.TextColor3 = WHITE
	continueButton.TextStrokeTransparency = 0
	continueButton.TextStrokeColor3 = DARK
	continueButton.Text = "CONTINUE"
	continueButton.ZIndex = 102
	continueButton.Parent = tutorialPanel
	Instance.new("UICorner", continueButton).CornerRadius = UDim.new(0, 12)
	local continueStroke = Instance.new("UIStroke")
	continueStroke.Color = DARK
	continueStroke.Thickness = 3
	continueStroke.Parent = continueButton
	continueButton.MouseButton1Click:Connect(finish)

	local skip = Instance.new("TextButton")
	skip.Size = UDim2.new(0, 108, 0, 42)
	skip.Position = UDim2.new(1, -310, 1, -60)
	skip.BackgroundColor3 = LAVENDER
	skip.AutoButtonColor = false
	skip.Font = Enum.Font.LuckiestGuy
	skip.TextSize = 18
	skip.TextColor3 = DARK
	skip.Text = "SKIP"
	skip.ZIndex = 102
	skip.Parent = tutorialPanel
	Instance.new("UICorner", skip).CornerRadius = UDim.new(0, 12)
	local skipStroke = Instance.new("UIStroke")
	skipStroke.Color = DARK
	skipStroke.Thickness = 3
	skipStroke.Parent = skip
	skip.MouseButton1Click:Connect(finish)
end

function openShopForColor(colorType)
	activeShopColor = ColorData.getWorldByColor(colorType) and ColorData.getWorldByColor(colorType).primaryColor or getCurrentShopColor()
	currentTab = "Brushes"
	local function open()
		toggleShop(true)
		if tutorialActionEvent and tutorialActionEvent:IsA("RemoteEvent") then
			tutorialActionEvent:FireServer("BrushShopOpened")
		end
	end
	if shouldShowTraitsTutorial(activeShopColor) then
		showTraitsTutorial(open)
	else
		open()
	end
end

brushesTab.MouseButton1Click:Connect(function()
	if currentTab ~= "Brushes" then
		currentTab = "Brushes"
		refresh()
		setDefaultStatus()
	end
end)

upgradesTab.MouseButton1Click:Connect(function()
	currentTab = "Brushes"
	refresh()
	setDefaultStatus()
end)

closeBtn.MouseButton1Click:Connect(function()
	toggleShop(false)
end)

overlay.MouseButton1Click:Connect(function()
	toggleShop(false)
end)

purchaseEvent.OnClientEvent:Connect(function(success, _toolId, message)
	refresh()
	status.Text = message or (success and "Brush purchased." or "Could not buy brush.")
	status.TextColor3 = success and Color3.fromRGB(35, 130, 55) or RED
end)

equipEvent.OnClientEvent:Connect(function(success, _toolId, message)
	refresh()
	status.Text = message or (success and "Brush equipped." or "Could not equip brush.")
	status.TextColor3 = success and Color3.fromRGB(35, 130, 55) or RED
end)

purchaseUpgradeEvent.OnClientEvent:Connect(function(success, upgradeId, valueOrMessage)
	if pendingUpgradeId == upgradeId then
		pendingUpgradeId = nil
	end
	if currentTab ~= "Upgrades" then
		return
	end
	refresh()
	if success then
		local upg = UpgradeData.getUpgrade(upgradeId)
		local level = tonumber(valueOrMessage) or getUpgradeLevel(upgradeId)
		status.Text = (upg and upg.displayName or upgradeId) .. " upgraded to level " .. level .. "."
		status.TextColor3 = Color3.fromRGB(35, 130, 55)
	else
		status.Text = tostring(valueOrMessage or "Could not buy upgrade.")
		status.TextColor3 = RED
	end
end)

task.defer(function()
	local folder = player:WaitForChild("PaintTools", 10)
	if folder then
		local owned = folder:WaitForChild("Owned", 10)
		local equipped = folder:WaitForChild("Equipped", 10)
		if owned then owned:GetPropertyChangedSignal("Value"):Connect(refresh) end
		if equipped then equipped:GetPropertyChangedSignal("Value"):Connect(refresh) end
	end
end)

task.defer(function()
	local folder = player:WaitForChild("Upgrades", 10)
	if folder then
		folder.ChildAdded:Connect(refresh)
		folder.ChildRemoved:Connect(refresh)
		for _, child in ipairs(folder:GetChildren()) do
			if child:IsA("IntValue") or child:IsA("NumberValue") then
				child.Changed:Connect(refresh)
			end
		end
		folder.ChildAdded:Connect(function(child)
			if child:IsA("IntValue") or child:IsA("NumberValue") then
				child.Changed:Connect(refresh)
			end
		end)
	end
end)

if unlockedColorsValue then
	unlockedColorsValue:GetPropertyChangedSignal("Value"):Connect(refresh)
end
if currentWorldValue then
	currentWorldValue:GetPropertyChangedSignal("Value"):Connect(refresh)
end

UIManager.register("Shop", function()
	activeShopColor = getCurrentShopColor()
	toggleShop(true)
end, function() toggleShop(false) end, function() return isOpen end)

local shopBtn = ReplicatedStorage:WaitForChild("HudButton_SHOP", 10)
if shopBtn then
	shopBtn.Event:Connect(function() UIManager.toggle("Shop") end)
end

openBrushShopEvent.Event:Connect(function()
	openShopForColor(getCurrentShopColor())
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt:GetAttribute("ShopExitPrompt") or prompt.Name == "ExitShopPrompt" then
		return
	end

	if prompt:GetAttribute("CombinedShopPrompt")
		or prompt:GetAttribute("BrushShopPrompt")
		or prompt.ObjectText == "Shop"
		or prompt.ObjectText == "Brush Shop"
	then
		local colorType = getPromptColor(prompt)
		if prompt:GetAttribute("BrushNpcDialogue") then
			local orangeInterior = player:GetAttribute("InsideSectorInterior") == true
				or prompt:FindFirstAncestor("OrangeSectorInterior") ~= nil
			showZorkDialogue(colorType, {
				orangeInterior = orangeInterior and colorType == "Orange",
				prompt = prompt,
			})
		else
			openShopForColor(colorType)
		end
	end
end)
