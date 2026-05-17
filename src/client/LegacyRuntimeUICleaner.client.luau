-- Kills old duplicate runtime UI roots so only the editable Studio UI stays on screen.
-- Runtime tutorial UI is also removed; the current TutorialGui is Studio-authored.
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local CURRENT_ROOT = "MainHUD"

local LEGACY_SCREEN_GUI_NAMES = {
	ClientUIRoot = true,
	ColorSimulatorUI = true,
	InventoryUI = true,
	InventoryGui = true,
	OldInventoryUI = true,
	MainInventoryUI = true,
	DailyQuestGui = true,
	DailyQuestUI = true,
	ZorkDailyQuestGui = true,
	EquipmentShopUI = true,
	ShopUI = true,
	WorldUI = true,
	WorldsUI = true,
	CodesUI = true,
	SettingsUI = true,
	UpgradesUI = true,
	TradeUI = true,
	GamepassGui = true,
	PetInventoryUI = true,
	SocialPanelUI = true,
	SocialPanelsUI = true,
	MutationHatchVFX = true,
	TutorialUI = true,
}

local ALLOWED_RUNTIME_SCREEN_GUI_NAMES = {
	TouchGui = true,
	Chat = true,
	BubbleChat = true,
	Freecam = true,
	TutorialGui = true,
}

local RUNTIME_LAYER_NAMES = {
	AdminAnnouncementUI = true,
	CodesUI = true,
	CollectFeedbackUI = true,
	CoreJuiceUI = true,
	EquipmentShopUI = true,
	GamepassUI = true,
	GroupRewardsGui = true,
	InventoryUI = true,
	LiveLeaderboardUI = true,
	MutationStationGui = true,
	PaintToolFeedbackUI = true,
	PetMergeToastUI = true,
	ShopTransitionUI = true,
	SocialPanelsUI = true,
	WildBuffToastUI = true,
	WorldUI = true,
}

local warned = {}
local function warnOnce(name)
	if warned[name] then
		return
	end
	warned[name] = true
	warn("LegacyRuntimeUICleaner: removed duplicate runtime UI -> " .. name)
end

local function shouldRemove(gui)
	if not gui:IsA("ScreenGui") then
		return false
	end
	if gui.Name == CURRENT_ROOT then
		return false
	end
	if ALLOWED_RUNTIME_SCREEN_GUI_NAMES[gui.Name] then
		return false
	end
	if gui:GetAttribute("AllowRuntimeUI") == true then
		return false
	end
	if gui:GetAttribute("LegacyUI") == true then
		return true
	end
	return LEGACY_SCREEN_GUI_NAMES[gui.Name] == true
end

local function getTutorialRootScore(root)
	if not (root and root:IsA("GuiObject") and root.Name == "TutorialRoot") then
		return -math.huge
	end
	local panel = root:FindFirstChild("QuestPanel")
	if not (panel and panel:IsA("GuiObject")) then
		return -math.huge
	end

	local score = 1
	local title = panel:FindFirstChild("QuestTitle")
	if title and title:IsA("TextLabel") and string.find(title.Text, "Break", 1, true) then
		score += 10
	end
	if root:GetAttribute("RuntimeTutorialRoot") == true then
		score -= 10
	end
	return score
end

local function cleanTutorialRoots()
	local tutorialGui = playerGui:FindFirstChild("TutorialGui")
	if not (tutorialGui and tutorialGui:IsA("ScreenGui")) then
		return
	end

	local roots = {}
	for _, child in ipairs(tutorialGui:GetChildren()) do
		if child.Name == "TutorialRoot" then
			table.insert(roots, child)
		end
	end
	if #roots <= 1 then
		return
	end

	local selected = roots[1]
	local selectedScore = getTutorialRootScore(selected)
	for _, root in ipairs(roots) do
		local score = getTutorialRootScore(root)
		if score > selectedScore then
			selected = root
			selectedScore = score
		end
	end

	for _, root in ipairs(roots) do
		if root ~= selected then
			warnOnce("TutorialGui." .. root.Name)
			root:Destroy()
		end
	end
end

local function clean()
	for _, child in ipairs(playerGui:GetChildren()) do
		if shouldRemove(child) then
			warnOnce(child.Name)
			child:Destroy()
		end
	end
	local root = playerGui:FindFirstChild(CURRENT_ROOT)
	if root then
		for _, child in ipairs(root:GetChildren()) do
			if child:IsA("GuiObject") and RUNTIME_LAYER_NAMES[child.Name] then
				warnOnce(child.Name)
				child:Destroy()
			end
		end
		for _, descendant in ipairs(root:GetDescendants()) do
			if descendant:IsA("GuiObject") and descendant.Name == "RuntimeText" then
				warnOnce(descendant.Name)
				descendant:Destroy()
			end
		end
	end
	cleanTutorialRoots()
end

clean()
playerGui.ChildAdded:Connect(function(child)
	if child:IsA("ScreenGui") then
		task.defer(function()
			if child.Parent == playerGui and shouldRemove(child) then
				warnOnce(child.Name)
				child:Destroy()
			end
		end)
	end
	if child.Name == "TutorialGui" then
		task.defer(cleanTutorialRoots)
	end
end)

-- Safety sweep for old UI that appears after delayed scripts.
task.spawn(function()
	while player.Parent do
		clean()
		task.wait(2)
	end
end)
