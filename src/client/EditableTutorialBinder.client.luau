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

local root = tutorialGui:WaitForChild("TutorialRoot", 10)
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
local collectEvent = Events:WaitForChild("CollectColor")
local hatchEvent = Events:WaitForChild("HatchEgg")
local markTutorialProgressEvent = Events:WaitForChild("MarkTutorialProgress")

local mainHud: Instance? = nil
local modalWindows: Instance? = nil
local closed = false
local currentQuest = 1

local state = {
	painted = 0,
	hatched = 0,
	inventoryOpened = false,
	worldsOpened = false,
	zorkTalked = false,
}

local QUESTS = {
	{
		id = "paint",
		title = "Quest 1: Paint a color spill",
		body = "Walk to a glowing color spill and paint it down with your brush.",
		objective = "Paint 1 color spill",
		target = "",
		spotlight = "",
		progress = function()
			return math.min(state.painted, 1), 1
		end,
		complete = function()
			return state.painted >= 1
		end,
	},
	{
		id = "hatch",
		title = "Quest 2: Hatch a Color",
		body = "Go to the egg station and hatch your first living Color.",
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
		title = "Quest 3: Open Inventory",
		body = "Use Inventory to equip your best Colors, lock favorites, and manage your team.",
		objective = "Open the Inventory window",
		target = "BottomButtons.MenuButton",
		spotlight = "Open the menu, then choose Inventory.",
		progress = function()
			return state.inventoryOpened and 1 or 0, 1
		end,
		complete = function()
			return state.inventoryOpened
		end,
	},
	{
		id = "worlds",
		title = "Quest 4: Check sectors",
		body = "Worlds shows the next sectors, travel options, and where better rewards unlock.",
		objective = "Open the Worlds window",
		target = "BottomButtons.WorldsButton",
		spotlight = "Use this when you are ready for the next sector.",
		progress = function()
			return state.worldsOpened and 1 or 0, 1
		end,
		complete = function()
			return state.worldsOpened
		end,
	},
	{
		id = "zork",
		title = "Quest 5: Talk to Zork",
		body = "Zork handles brush help and daily quest direction. Visit him when you want the next goal.",
		objective = "Talk to Zork",
		target = "ZorkDialogueUI",
		spotlight = "Zork dialogue appears here after you talk to him.",
		progress = function()
			return state.zorkTalked and 1 or 0, 1
		end,
		complete = function()
			return state.zorkTalked
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
	setText(
		progressLabel,
		tostring(done) .. " / " .. tostring(total) .. "  -  " .. tostring(currentQuest) .. "/" .. tostring(#QUESTS)
	)
	setText(statusLabel, "Active tutorial quest")
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
	elseif string.find(windowName, "World") then
		state.worldsOpened = true
	elseif
		string.find(windowName, "Zork")
		or string.find(windowName, "DailyQuest")
		or string.find(windowName, "Brush")
	then
		state.zorkTalked = true
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
	end

	window:GetPropertyChangedSignal("Visible"):Connect(function()
		if window.Visible then
			state[key] = true
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

collectEvent.OnClientEvent:Connect(function(success)
	if success == false then
		return
	end
	state.painted += 1
	advanceIfReady()
end)

hatchEvent.OnClientEvent:Connect(function(successOrPayload)
	if successOrPayload == false then
		return
	end
	state.hatched += 1
	advanceIfReady()
end)

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
	bindVisibleWindow("WorldsWindow", "worldsOpened")
	bindVisibleWindow("ZorkDialogueWindow", "zorkTalked")
	bindVisibleWindow("DailyQuestsWindow", "zorkTalked")
	bindVisibleWindow("BrushShopWindow", "zorkTalked")
	bindWorldDialogue()

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
