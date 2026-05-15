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
end)

-- Safety sweep for old UI that appears after delayed scripts.
task.spawn(function()
	while player.Parent do
		clean()
		task.wait(2)
	end
end)
