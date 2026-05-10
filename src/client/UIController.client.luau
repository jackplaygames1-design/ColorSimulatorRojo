-- Legacy controller disabled. WindowButtonController.client.luau is the only
-- script that opens/closes MainHUD.ModalWindows.Windows.
if true then
	warn("UIController disabled; WindowButtonController owns editable MainHUD windows.")
	return
end

-- Controls the editor-built UI under PlayerGui.ClientUIRoot.MainHUD.
-- This script intentionally does not create, replace, or style full windows.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local WARNED = {}

local WINDOW_NAMES = {
	Inventory = "InventoryWindow",
	Shop = "ShopWindow",
	Worlds = "WorldsWindow",
	DailyQuests = "DailyQuestsWindow",
	Codes = "CodesWindow",
	Upgrades = "UpgradesWindow",
	Settings = "SettingsWindow",
	Trade = "TradeWindow",
}

local WINDOW_BUTTON_NAMES = {
	Settings = "SettingsButton",
	Shop = "ShopButton",
	Upgrades = "UpgradesButton",
	Trade = "TradeButton",
}

local DOCK_TOGGLE_BUTTON_NAME = "InventoryButton"
local DOCK_BUTTON_NAMES = { "ShopButton", "UpgradesButton", "SettingsButton", "TradeButton" }
local LEGACY_GENERATED_LAYER_NAMES = {
	EquipmentShopUI = true,
	GamepassUI = true,
	ShopUI = true,
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
local lastPressAt = {}

local function warnOnce(key, message)
	if WARNED[key] then
		return
	end
	WARNED[key] = true
	warn(message)
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

local dimBackground = nil
local menuBlur = nil
local root = nil
local mainHud = nil

local function findWindowsFolder(mainHudObject)
	local modalWindows = mainHudObject:WaitForChild("ModalWindows", 10)
	if modalWindows then
		local nestedWindows = modalWindows:WaitForChild("Windows", 10)
		if nestedWindows then
			return nestedWindows
		end
		warn("UIController: missing MainHUD.ModalWindows.Windows.")
	end

	local legacyWindows = mainHudObject:FindFirstChild("Windows")
	if legacyWindows then
		warn("UIController: using legacy MainHUD.Windows. Expected MainHUD.ModalWindows.Windows.")
		return legacyWindows
	end

	return nil
end

local function setDockOpen(open)
	dockOpen = open

	if not mainHud then
		warn("[UIController] Missing MainHUD")
		return
	end

	local buttonsRow = mainHud:WaitForChild("ButtonsRow", 10)
	if not buttonsRow then
		warn("[UIController] Missing MainHUD.ButtonsRow")
		return
	end

	for _, buttonName in ipairs(DOCK_BUTTON_NAMES) do
		local button = buttonsRow:FindFirstChild(buttonName)
		if button and button:IsA("GuiObject") then
			button.Visible = open
			button.Active = open
		else
			warn("[UIController] Missing dock button:", buttonName)
		end
	end

	local inventoryButton = buttonsRow:FindFirstChild(DOCK_TOGGLE_BUTTON_NAME)
	if inventoryButton and inventoryButton:IsA("GuiObject") then
		inventoryButton.Visible = true
		inventoryButton.Active = true
	else
		warn("[UIController] Missing " .. DOCK_TOGGLE_BUTTON_NAME)
	end

	print("[UIController] dock visual state:", open)
	for _, child in ipairs(buttonsRow:GetChildren()) do
		if child:IsA("GuiObject") then
			print("[UIController] ButtonsRow child:", child.Name, child.ClassName, "visible=" .. tostring(child.Visible), "position=" .. tostring(child.Position), "size=" .. tostring(child.Size))
		else
			print("[UIController] ButtonsRow child:", child.Name, child.ClassName)
		end
	end
end

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

mainHud = root:WaitForChild("MainHUD", 15)
if not mainHud or not mainHud:IsA("GuiObject") then
	warn("UIController: missing PlayerGui.ClientUIRoot.MainHUD. No windows were controlled.")
	return
end

local windowsFolder = findWindowsFolder(mainHud)
if not windowsFolder then
	warn("UIController: missing PlayerGui.ClientUIRoot.MainHUD.ModalWindows.Windows. Add physical window Frames in Studio.")
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

local mainButtonsRow = mainHud:WaitForChild("ButtonsRow", 10)
if not mainButtonsRow or not mainButtonsRow:IsA("GuiObject") then
	warn("[UIController] Missing MainHUD.ButtonsRow")
	mainButtonsRow = nil
end

for key, windowName in pairs(WINDOW_NAMES) do
	local window = windowsFolder:FindFirstChild(windowName)
	if window and window:IsA("GuiObject") then
		windows[key] = window
		window.Visible = false
		connectCloseButton(key, window)
		wireTabs(window)
	else
		warnOnce("missing-window-" .. key, "UIController: missing MainHUD.Windows." .. windowName)
	end
end

for key, buttonName in pairs(WINDOW_BUTTON_NAMES) do
	local button = mainButtonsRow and mainButtonsRow:FindFirstChild(buttonName)
	if button and button:IsA("GuiObject") then
		buttons[key] = button
		print("[UIController] wired button:", key, button:GetFullName())
	end
end

dockOpen = false
closeAllWindows()
hideLegacyGeneratedLayers(root)
local inventoryButton = mainButtonsRow and mainButtonsRow:FindFirstChild(DOCK_TOGGLE_BUTTON_NAME)
if inventoryButton and inventoryButton:IsA("GuiObject") then
	connectButtonContainer(inventoryButton, function()
		if activeKey == "Inventory" then
			closeAllWindows()
			setDockOpen(false)
		else
			openWindow("Inventory")
			setDockOpen(true)
		end
	end, DOCK_TOGGLE_BUTTON_NAME)
end

for key, button in pairs(buttons) do
	if button then
		connectButtonContainer(button, function()
			print("[UIController] " .. key .. " clicked")
			openWindow(key)
			setDockOpen(true)
		end, WINDOW_BUTTON_NAMES[key])
	end
end

setDockOpen(false)

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
