-- Kills old duplicate runtime UI roots so only the editable Studio UI stays on screen.
-- Tutorial UI is intentionally allowed until the handmade tutorial replacement exists.
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local CURRENT_ROOT = "ClientUIRoot"

local LEGACY_SCREEN_GUI_NAMES = {
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
}

local ALLOWED_RUNTIME_SCREEN_GUI_NAMES = {
	TutorialUI = true,
	TutorialGui = true,
	TouchGui = true,
	Chat = true,
	BubbleChat = true,
	Freecam = true,
}

local warned = {}
local function warnOnce(name)
	if warned[name] then return end
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
