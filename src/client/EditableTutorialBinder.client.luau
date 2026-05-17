-- Bind-only controller for the Studio-authored StarterGui.TutorialGui.
-- The tutorial is a quest tracker: all visible panels/buttons stay editable in Studio.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local ClientUIRoot = require(ReplicatedStorage:WaitForChild("ClientUIRoot"))

local STARTED_ATTRIBUTE = "EditableTutorialBinderStarted"
if playerGui:GetAttribute(STARTED_ATTRIBUTE) then
	return
end
playerGui:SetAttribute(STARTED_ATTRIBUTE, true)

local tutorialGui = playerGui:WaitForChild("TutorialGui", 20)
if not tutorialGui or not tutorialGui:IsA("ScreenGui") then
	warn("EditableTutorialBinder: missing PlayerGui.TutorialGui")
	return
end

local function getQuestPanel(candidate)
	return candidate and candidate:IsA("GuiObject") and candidate:FindFirstChild("QuestPanel") or nil
end

local function scoreTutorialRoot(candidate)
	local panelCandidate = getQuestPanel(candidate)
	if not (candidate and candidate:IsA("GuiObject") and panelCandidate and panelCandidate:IsA("GuiObject")) then
		return -math.huge
	end

	local score = 1
	local title = panelCandidate:FindFirstChild("QuestTitle")
	if title and title:IsA("TextLabel") and string.find(title.Text, "Break", 1, true) then
		score += 10
	end
	if candidate:GetAttribute("RuntimeTutorialRoot") == true then
		score -= 10
	end
	return score
end

local function selectSingleTutorialRoot()
	local roots = {}
	for _, child in ipairs(tutorialGui:GetChildren()) do
		if child.Name == "TutorialRoot" then
			table.insert(roots, child)
		end
	end

	if #roots == 0 then
		return nil
	end

	local selected = roots[1]
	local selectedScore = scoreTutorialRoot(selected)
	for _, candidate in ipairs(roots) do
		local score = scoreTutorialRoot(candidate)
		if score > selectedScore then
			selected = candidate
			selectedScore = score
		end
	end

	for _, candidate in ipairs(roots) do
		if candidate ~= selected then
			candidate:Destroy()
		end
	end

	return selected
end

local root = selectSingleTutorialRoot() or tutorialGui:WaitForChild("TutorialRoot", 10)
local panel = root and root:FindFirstChild("QuestPanel")
local titleLabel = panel and panel:FindFirstChild("QuestTitle")
local bodyLabel = panel and panel:FindFirstChild("QuestBody")
local objectiveLabel = panel and panel:FindFirstChild("ObjectiveLabel")
local progressLabel = panel and panel:FindFirstChild("ProgressLabel")
local statusLabel = panel and panel:FindFirstChild("StatusLabel")
local skipButton = panel and panel:FindFirstChild("SkipButton")
local spotlight = root and root:FindFirstChild("Spotlight")

if not (root and root:IsA("GuiObject") and panel and panel:IsA("GuiObject")) then
	warn("EditableTutorialBinder: TutorialGui is missing TutorialRoot.QuestPanel")
	return
end

local Events = ReplicatedStorage:WaitForChild("Events")
local hatchEvent = Events:WaitForChild("HatchEgg")
local coreRollResult = Events:WaitForChild("CoreRollResult")
local markTutorialProgressEvent = Events:WaitForChild("MarkTutorialProgress")
local rankDataUpdated = Events:WaitForChild("RankDataUpdated")
local rankMenuOpened = Events:WaitForChild("RankMenuOpened")
local tutorialBreakableProgress = Events:WaitForChild("TutorialBreakableProgress")

local mainHud: Instance? = nil
local modalWindows: Instance? = nil
local closed = false
local currentQuest = 1

local state = {
	colorSpillsBroken = 0,
	hatched = 0,
	colorEquipped = false,
	breakablesBroken = 0,
	rankOpened = false,
	rankXpEarned = 0,
	inventoryOpened = false,
}

local QUESTS = {
	{
		id = "spill",
		title = "Clean Up a Color Spill",
		body = "Break a red Color Spill. Your equipped colors will help mine nearby breakables.",
		objective = "Break 1 Color Spill",
		target = "",
		spotlight = "",
		progress = function()
			return math.min(state.colorSpillsBroken, 1), 1
		end,
		complete = function()
			return state.colorSpillsBroken >= 1
		end,
	},
	{
		id = "hatch",
		title = "Hatch a Color",
		body = "Go to the Red Core and roll one Color. New Colors go to your inventory.",
		objective = "Hatch 1 Color",
		target = "",
		spotlight = "",
		progress = function()
			return math.min(state.hatched, 1), 1
		end,
		complete = function()
			return state.hatched >= 1
		end,
	},
	{
		id = "inventory",
		title = "Equip Your Color",
		body = "Open Inventory and manually equip a Color so it can mine breakables.",
		objective = "Equip 1 Color",
		target = "BottomButtons.MenuButton",
		spotlight = "Open the menu, then choose Inventory.",
		progress = function()
			return state.colorEquipped and 1 or 0, 1
		end,
		complete = function()
			return state.colorEquipped
		end,
	},
	{
		id = "mine",
		title = "Let Your Colors Mine",
		body = "Stay near breakables and let your equipped colors keep cleaning the sector.",
		objective = "Break 5 color breakables",
		target = "",
		spotlight = "",
		progress = function()
			return math.min(state.breakablesBroken, 5), 5
		end,
		complete = function()
			return state.breakablesBroken >= 5
		end,
	},
	{
		id = "rank",
		title = "Open Your Rank",
		body = "Ranks track XP, quests, passives, and future rebirth progress.",
		objective = "Open the Rank menu",
		target = "BottomButtons.RankButton",
		spotlight = "Open Rank to see your XP and 10 rank quests.",
		progress = function()
			return state.rankOpened and 1 or 0, 1
		end,
		complete = function()
			return state.rankOpened
		end,
	},
	{
		id = "rankxp",
		title = "Earn Rank XP",
		body = "Collect Coins and Gems from breakables to earn Rank XP.",
		objective = "Earn 100 Rank XP",
		target = "",
		spotlight = "",
		progress = function()
			return math.min(state.rankXpEarned, 100), 100
		end,
		complete = function()
			return state.rankXpEarned >= 100
		end,
	},
}

local function setText(instance, value)
	if instance and (instance:IsA("TextLabel") or instance:IsA("TextButton")) then
		instance.Text = value
	end
end

local function findByPath(parent, path)
	local current = parent
	for segment in string.gmatch(path, "[^%.]+") do
		if not current then
			return nil
		end
		current = current:FindFirstChild(segment)
	end
	return current
end

local function findHighlightTarget(path)
	path = tostring(path or "")
	if path == "" then
		return nil
	end

	local exact = findByPath(playerGui, path)
	if exact then
		return exact
	end

	if mainHud then
		local hudTarget = findByPath(mainHud, path)
		if hudTarget then
			return hudTarget
		end
	end

	return playerGui:FindFirstChild(path, true)
end

local function setSpotlightVisible(visible)
	if spotlight and spotlight:IsA("GuiObject") then
		spotlight.Visible = visible
	end
end

local originalPanelPosition = panel and panel:IsA("GuiObject") and panel.Position or UDim2.new(0, 24, 0.38, -95)
local function avoidCoreRollOverlap()
	if not (mainHud and panel and panel:IsA("GuiObject")) then
		return
	end
	local coreWindow = mainHud:FindFirstChild("CoreRollWindow", true)
	if coreWindow and coreWindow:IsA("GuiObject") and coreWindow.Visible then
		panel.AnchorPoint = Vector2.new(1, 0)
		panel.Position = UDim2.new(1, -24, 0, 92)
		panel.Size = UDim2.fromOffset(330, 178)
		panel.ZIndex = math.min(panel.ZIndex, 120)
	else
		panel.AnchorPoint = Vector2.new(0, 0)
		panel.Position = originalPanelPosition
		panel.Size = UDim2.fromOffset(370, 210)
	end
end

local function refreshSpotlight(quest)
	if not (spotlight and spotlight:IsA("GuiObject")) then
		return
	end

	local target = findHighlightTarget(quest.target)
	if not (target and target:IsA("GuiObject") and target.Visible) then
		setSpotlightVisible(false)
		return
	end

	local targetSize = target.AbsoluteSize
	if targetSize.X <= 2 or targetSize.Y <= 2 then
		setSpotlightVisible(false)
		return
	end

	local padding = 12
	local rootPosition = root.AbsolutePosition
	local targetPosition = target.AbsolutePosition
	spotlight.Position =
		UDim2.fromOffset(targetPosition.X - rootPosition.X - padding, targetPosition.Y - rootPosition.Y - padding)
	spotlight.Size = UDim2.fromOffset(targetSize.X + padding * 2, targetSize.Y + padding * 2)

	local hint = spotlight:FindFirstChild("Hint")
	setText(hint, quest.spotlight)
	setSpotlightVisible(true)
end

local function markProgress(key)
	key = tostring(key or "")
	if key == "" then
		return
	end

	markTutorialProgressEvent:FireServer(key)
	local folder = player:FindFirstChild("TutorialProgress")
	local value = folder and folder:FindFirstChild(key)
	if value and value:IsA("BoolValue") then
		value.Value = true
	end
end

local function closeTutorial(progressKey)
	if closed then
		return
	end
	closed = true
	setSpotlightVisible(false)
	if progressKey then
		markProgress(progressKey)
	end
	tutorialGui.Enabled = false
end

local function refresh()
	if closed then
		return
	end

	local quest = QUESTS[currentQuest]
	avoidCoreRollOverlap()
	if not quest then
		setText(titleLabel, "Tutorial complete")
		setText(
			bodyLabel,
			"You know the loop now. Paint, hatch, equip Colors, unlock sectors, and visit Zork for direction."
		)
		setText(objectiveLabel, "Complete")
		setText(progressLabel, tostring(#QUESTS) .. " / " .. tostring(#QUESTS))
		setText(statusLabel, "Entering sector...")
		setSpotlightVisible(false)
		task.delay(1.4, function()
			closeTutorial("IntroTutorialCompleted")
		end)
		return
	end

	local done, total = quest.progress()
	setText(titleLabel, quest.title)
	setText(bodyLabel, quest.body)
	setText(objectiveLabel, quest.objective)
	setText(progressLabel, tostring(done) .. " / " .. tostring(total))
	setText(statusLabel, "Step " .. tostring(currentQuest) .. " / " .. tostring(#QUESTS))
	refreshSpotlight(quest)
end

local function advanceIfReady()
	if closed then
		return
	end

	while currentQuest <= #QUESTS and QUESTS[currentQuest].complete() do
		currentQuest += 1
	end
	refresh()
end

local function connect(guiObject, callback)
	if guiObject and guiObject:IsA("GuiButton") then
		guiObject.Activated:Connect(callback)
	end
end

local function progressValueIsTrue(folder, name)
	local value = folder and folder:FindFirstChild(name)
	return value and value:IsA("BoolValue") and value.Value == true
end

local function waitForLoadingComplete()
	if playerGui:GetAttribute("ColorSimulatorLoadingComplete") == true then
		return
	end

	local finished = false
	local connection = playerGui:GetAttributeChangedSignal("ColorSimulatorLoadingComplete"):Connect(function()
		finished = playerGui:GetAttribute("ColorSimulatorLoadingComplete") == true
	end)

	local startedAt = os.clock()
	while not finished and os.clock() - startedAt < 30 do
		task.wait(0.1)
	end
	connection:Disconnect()
end

local function noteWindowOpened(windowName)
	windowName = tostring(windowName or "")
	if windowName == "" then
		return
	end

	if string.find(windowName, "Inventory") then
		state.inventoryOpened = true
	elseif string.find(windowName, "Rank") or string.find(windowName, "Rebirth") then
		state.rankOpened = true
		rankMenuOpened:FireServer()
	end
	advanceIfReady()
end

local function bindVisibleWindow(name, key)
	if not modalWindows then
		return
	end

	local window = modalWindows:FindFirstChild(name)
	if not (window and window:IsA("GuiObject")) then
		return
	end

	if window.Visible then
		state[key] = true
		if key == "rankOpened" then
			rankMenuOpened:FireServer()
		end
	end

	window:GetPropertyChangedSignal("Visible"):Connect(function()
		if window.Visible then
			state[key] = true
			if key == "rankOpened" then
				rankMenuOpened:FireServer()
			end
			advanceIfReady()
		end
	end)
end

local function bindWorldDialogue()
	if not mainHud then
		return
	end

	local dialogue = mainHud:FindFirstChild("ZorkDialogueUI", true)
	if dialogue and dialogue:IsA("GuiObject") then
		if dialogue.Visible then
			state.zorkTalked = true
		end
		dialogue:GetPropertyChangedSignal("Visible"):Connect(function()
			if dialogue.Visible then
				state.zorkTalked = true
				advanceIfReady()
			end
		end)
	end
end

tutorialBreakableProgress.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	local breakableType = tostring(payload.BreakableType or "")
	state.breakablesBroken += 1
	if breakableType == "ColorSpill" then
		state.colorSpillsBroken += 1
	end
	advanceIfReady()
end)

hatchEvent.OnClientEvent:Connect(function(successOrPayload)
	if successOrPayload == false then
		return
	end
	state.hatched += 1
	advanceIfReady()
end)

coreRollResult.OnClientEvent:Connect(function(success)
	if success == false then
		return
	end
	state.hatched += 1
	advanceIfReady()
end)

rankDataUpdated.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	state.rankXpEarned = math.max(state.rankXpEarned, math.floor(tonumber(payload.RankXP) or 0))
	advanceIfReady()
end)

local function updateEquippedTutorialState()
	local petFolder = player:FindFirstChild("PetData")
	local equipped = petFolder and petFolder:FindFirstChild("Equipped")
	if equipped and equipped:IsA("StringValue") and equipped.Value ~= "" then
		state.colorEquipped = true
		advanceIfReady()
	end
end

local function bindEquippedTutorialState()
	local petFolder = player:FindFirstChild("PetData")
	if not petFolder then
		return
	end
	local equipped = petFolder:FindFirstChild("Equipped")
	if equipped and equipped:IsA("StringValue") then
		equipped:GetPropertyChangedSignal("Value"):Connect(updateEquippedTutorialState)
		updateEquippedTutorialState()
	end
	petFolder.ChildAdded:Connect(function(child)
		if child.Name == "Equipped" and child:IsA("StringValue") then
			child:GetPropertyChangedSignal("Value"):Connect(updateEquippedTutorialState)
			updateEquippedTutorialState()
		end
	end)
end

player.ChildAdded:Connect(function(child)
	if child.Name == "PetData" then
		bindEquippedTutorialState()
	end
end)
bindEquippedTutorialState()

connect(skipButton, function()
	closeTutorial("IntroTutorialSkipped")
end)

local function showIfNeeded()
	waitForLoadingComplete()
	mainHud = ClientUIRoot.GetRoot(playerGui)
	local modalRoot = mainHud and mainHud:FindFirstChild("ModalWindows")
	modalWindows = modalRoot and (modalRoot:FindFirstChild("Windows") or modalRoot)
	local progress = player:WaitForChild("TutorialProgress", 20)

	if
		progressValueIsTrue(progress, "IntroTutorialCompleted") or progressValueIsTrue(progress, "IntroTutorialSkipped")
	then
		tutorialGui.Enabled = false
		return
	end

	if mainHud then
		mainHud:GetAttributeChangedSignal("RequestedWindow"):Connect(function()
			noteWindowOpened(mainHud:GetAttribute("RequestedWindow"))
		end)
		mainHud:GetAttributeChangedSignal("RequestedWindowNonce"):Connect(function()
			noteWindowOpened(mainHud:GetAttribute("RequestedWindow"))
		end)
	end

	bindVisibleWindow("InventoryWindow", "inventoryOpened")
	bindVisibleWindow("RankWindow", "rankOpened")

	closed = false
	currentQuest = 1
	tutorialGui.Enabled = true
	root.Visible = true
	panel.Visible = true
	advanceIfReady()
	task.defer(refresh)
end

tutorialGui.Enabled = false
task.spawn(showIfNeeded)
