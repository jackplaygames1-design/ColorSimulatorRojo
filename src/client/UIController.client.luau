-- Controls the editor-built UI under PlayerGui.ClientUIRoot.MainHUD.
-- This script intentionally does not create, replace, or style full windows.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local WARNED = {}

local WINDOW_ALIASES = {
	Inventory = { "InventoryWindow" },
	Shop = { "ShopWindow", "MarketWindow" },
	Upgrades = { "UpgradesWindow", "RankWindow" },
	Settings = { "SettingsWindow" },
	Trade = { "TradeWindow", "TradingWindow" },
	Worlds = { "WorldsWindow", "WorldWindow" },
	DailyQuests = { "DailyQuestsWindow", "DailyQuestWindow" },
}

local BUTTON_ALIASES = {
	Inventory = { "InventoryButton", "MenuButton", "MenuHamburgerButton" },
	Shop = { "ShopButton", "MarketButton", "StoreButton" },
	Upgrades = { "UpgradesButton", "UpgradeButton", "RankButton", "RanksButton" },
	Settings = { "SettingsButton", "GearButton" },
	Trade = { "TradeButton", "TradingButton" },
	Worlds = { "WorldsButton", "WorldButton", "WorldGlobeButton" },
	DailyQuests = { "DailyQuestsButton", "DailyQuestButton", "QuestsButton", "QuestButton" },
}

local MENU_KEYS = { "Inventory", "Settings", "Trade", "Upgrades", "Shop", "Worlds", "DailyQuests" }
local SIDE_KEYS = { "Settings", "Trade", "Upgrades", "Shop", "Worlds", "DailyQuests" }
local LEGACY_GENERATED_LAYER_NAMES = {
	EquipmentShopUI = true,
	GamepassUI = true,
	WorldUI = true,
	SocialPanelsUI = true,
	CodesUI = true,
	DailyQuestGui = true,
	-- This layer is only meant to appear during the shop fade. If it stays
	-- visible while idle, it sits above the handmade buttons and eats clicks.
	ShopTransitionUI = true,
}
local activeKey = nil
local dockOpen = false
local windows = {}
local buttons = {}
local buttonRows = {}
local lastPressAt = {}

local function warnOnce(key, message)
	if WARNED[key] then
		return
	end
	WARNED[key] = true
	warn(message)
end

local function findFirstByNames(parent, names)
	if not parent then
		return nil
	end
	for _, name in ipairs(names) do
		local found = parent:FindFirstChild(name, true)
		if found then
			return found
		end
	end
	return nil
end

local function findButtonInRows(key)
	local aliases = BUTTON_ALIASES[key]
	for _, row in ipairs(buttonRows) do
		local found = findFirstByNames(row, aliases)
		if found and found:IsA("GuiObject") then
			return found
		end
	end
	return nil
end

local function debounce(label)
	local now = os.clock()
	if lastPressAt[label] and now - lastPressAt[label] < 0.12 then
		return false
	end
	lastPressAt[label] = now
	return true
end

local function connectPress(guiObject, callback, label)
	if not guiObject then
		return
	end
	local function run()
		if debounce(label) then
			callback()
		end
	end
	if guiObject:IsA("GuiButton") then
		guiObject.Active = true
		guiObject.Activated:Connect(run)
		guiObject.MouseButton1Click:Connect(run)
	elseif guiObject:IsA("GuiObject") then
		guiObject.Active = true
		guiObject.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				run()
			end
		end)
	else
		warnOnce("not-clickable-" .. tostring(label), "UIController: " .. tostring(label) .. " is not clickable.")
	end
end

local function connectButtonContainer(guiObject, callback, label)
	if not guiObject then
		return
	end

	local connected = false
	if guiObject:IsA("GuiButton") then
		connectPress(guiObject, callback, label)
		connected = true
	end

	for _, descendant in ipairs(guiObject:GetDescendants()) do
		if descendant:IsA("GuiButton") then
			connectPress(descendant, callback, label)
			print("[UIController] wired nested button:", label, descendant:GetFullName())
			connected = true
		end
	end

	if not connected then
		connectPress(guiObject, callback, label)
	end
end

local function getMenuBlur()
	local blur = Lighting:FindFirstChild("MenuBlur")
	if blur and blur:IsA("BlurEffect") then
		return blur
	end
	if blur then
		warnOnce("bad-menublur", "UIController: Lighting.MenuBlur exists but is not a BlurEffect.")
	end
	return nil
end

local function setDockOpen(open)
	dockOpen = open
	-- The editor-built button row owns visibility and layout.
	-- Keep every physical button exactly as placed in Studio.
	print("[UIController] dock open:", open)
end

local dimBackground = nil
local menuBlur = nil
local root = nil

local function updateDim()
	local anyOpen = activeKey ~= nil
	if dimBackground and dimBackground:IsA("GuiObject") then
		dimBackground.Visible = anyOpen
	end
	if menuBlur then
		menuBlur.Enabled = anyOpen
	end
end

local function closeAllWindows()
	for _, window in pairs(windows) do
		if window and window:IsA("GuiObject") then
			window.Visible = false
		end
	end
	activeKey = nil
	updateDim()
end

local function hideLegacyGeneratedLayers(root)
	for _, child in ipairs(root:GetChildren()) do
		if LEGACY_GENERATED_LAYER_NAMES[child.Name] and child:IsA("GuiObject") then
			child.Visible = false
		end
	end
end

local function openWindow(key)
	local window = windows[key]
	if not window then
		warnOnce("missing-window-open-" .. key, "UIController: missing window for " .. key .. ". Add it under MainHUD.Windows.")
		return
	end
	closeAllWindows()
	activeKey = key
	window.Visible = true
	updateDim()
	print("[UIController] opened window:", key, window:GetFullName())
end

local function toggleWindow(key)
	if activeKey == key then
		closeAllWindows()
	else
		openWindow(key)
	end
end

local function openInventory()
	closeAllWindows()

	local inventoryLayer = root:FindFirstChild("InventoryUI")
	if inventoryLayer and inventoryLayer:IsA("GuiObject") then
		inventoryLayer.Visible = true
	end

	local openInventoryBindable = ReplicatedStorage:FindFirstChild("HudOpenInventory")
	if openInventoryBindable and openInventoryBindable:IsA("BindableEvent") then
		openInventoryBindable:Fire({ from = "UIController", defaultTab = "Colors" })
		return
	end

	toggleWindow("Inventory")
end

local function connectCloseButton(key, window)
	local closeButton = window and window:FindFirstChild("CloseButton", true)
	if not closeButton then
		warnOnce("missing-close-" .. key, "UIController: " .. key .. " window is missing CloseButton.")
		return
	end
	connectPress(closeButton, function()
		if activeKey == key then
			closeAllWindows()
		else
			window.Visible = false
		end
		if key == "Inventory" then
			setDockOpen(false)
		end
		print("[UIController] close clicked:", key)
	end, key .. ".CloseButton")
end

local function wireTabs(window)
	local tabs = window and window:FindFirstChild("Tabs", true)
	if not tabs then
		return
	end

	local contentRoot = window:FindFirstChild("Content", true) or window:FindFirstChild("Pages", true)
	if not contentRoot then
		return
	end

	local pages = {}
	for _, child in ipairs(contentRoot:GetChildren()) do
		if child:IsA("GuiObject") then
			local normalized = child.Name:gsub("Page$", ""):gsub("Frame$", ""):lower()
			pages[normalized] = child
		end
	end

	local function showPage(tabName)
		local normalized = tabName:gsub("Tab$", ""):gsub("Button$", ""):lower()
		for key, page in pairs(pages) do
			page.Visible = key == normalized
		end
		print("[UIController] tab selected:", window.Name, tabName)
	end

	for _, tab in ipairs(tabs:GetDescendants()) do
		if tab:IsA("GuiButton") then
			connectPress(tab, function()
				showPage(tab.Name)
			end, window.Name .. "." .. tab.Name)
		end
	end
end

print("[UIController] loading")

root = playerGui:WaitForChild("ClientUIRoot", 15)
if not root or not root:IsA("ScreenGui") then
	warn("UIController: missing PlayerGui.ClientUIRoot. No windows were controlled.")
	return
end

local mainHud = root:WaitForChild("MainHUD", 15)
if not mainHud or not mainHud:IsA("GuiObject") then
	warn("UIController: missing PlayerGui.ClientUIRoot.MainHUD. No windows were controlled.")
	return
end

local windowsFolder = mainHud:WaitForChild("Windows", 15)
if not windowsFolder then
	warn("UIController: missing PlayerGui.ClientUIRoot.MainHUD.Windows. Add physical window Frames in Studio.")
	return
end

dimBackground = mainHud:FindFirstChild("DimBackground")
if not dimBackground then
	warnOnce("missing-dim", "UIController: missing MainHUD.DimBackground. Windows will still toggle, but no dim will show.")
elseif not dimBackground:IsA("GuiObject") then
	warnOnce("bad-dim", "UIController: MainHUD.DimBackground is not a GuiObject.")
	dimBackground = nil
end
menuBlur = getMenuBlur()

local bottomRow = mainHud:FindFirstChild("BottomRow")
local leftButtons = mainHud:FindFirstChild("LeftButtons")
local mainButtonsRow = mainHud:FindFirstChild("ButtonsRow")
local legacyButtonsRow = root:FindFirstChild("ButtonsRow")
local bottomMenu = root:FindFirstChild("BottomMenu")
local nestedButtonsRow = bottomMenu and bottomMenu:FindFirstChild("ButtonsRow")
for _, row in ipairs({ bottomRow, leftButtons, mainButtonsRow, legacyButtonsRow, nestedButtonsRow }) do
	if row and row:IsA("GuiObject") then
		table.insert(buttonRows, row)
	end
end

if #buttonRows == 0 then
	warnOnce("missing-bottomrow", "UIController: missing MainHUD.BottomRow/LeftButtons/ButtonsRow. Window buttons were not wired.")
end

for key, aliases in pairs(WINDOW_ALIASES) do
	local window = findFirstByNames(windowsFolder, aliases)
	if window and window:IsA("GuiObject") then
		windows[key] = window
		window.Visible = false
		connectCloseButton(key, window)
		wireTabs(window)
	else
		warnOnce("missing-window-" .. key, "UIController: missing MainHUD.Windows." .. aliases[1])
	end
end

for _, key in ipairs(MENU_KEYS) do
	local button = findButtonInRows(key)
	if button and button:IsA("GuiObject") then
		buttons[key] = button
		print("[UIController] wired button:", key, button:GetFullName())
	else
		warnOnce("missing-button-" .. key, "UIController: missing physical button for " .. key .. ".")
	end
end

dockOpen = true
closeAllWindows()
hideLegacyGeneratedLayers(root)
if dimBackground then
	connectPress(dimBackground, function()
		closeAllWindows()
	end, "DimBackground")
end

if buttons.Inventory then
	connectButtonContainer(buttons.Inventory, function()
		print("[UIController] Inventory clicked")
		openInventory()
	end, "InventoryButton")
end

for _, key in ipairs(SIDE_KEYS) do
	if buttons[key] then
		connectButtonContainer(buttons[key], function()
			print("[UIController] " .. key .. " clicked")
			toggleWindow(key)
		end, key .. "Button")
	end
end

root.ChildAdded:Connect(function(child)
	if LEGACY_GENERATED_LAYER_NAMES[child.Name] then
		if child:IsA("GuiObject") then
			child.Visible = false
			warnOnce("hid-generated-" .. child.Name, "UIController: hid legacy generated layer " .. child.Name .. ".")
		end
	end
end)

UserInputService.InputBegan:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local position = input.UserInputType == Enum.UserInputType.MouseButton1 and UserInputService:GetMouseLocation() or input.Position
	local objects = playerGui:GetGuiObjectsAtPosition(position.X, position.Y)
	print("[UIController] click at", position.X, position.Y, "objects:", #objects)
	for index = 1, math.min(#objects, 8) do
		local object = objects[index]
		print("[UIController] under click", index, object:GetFullName(), object.ClassName, "visible=" .. tostring(object.Visible), "z=" .. tostring(object.ZIndex))
	end
end)

print("[UIController] ready")
