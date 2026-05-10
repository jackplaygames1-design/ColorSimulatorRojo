-- Single controller for the editable Studio UI:
-- PlayerGui.ClientUIRoot.MainHUD.ModalWindows.Windows
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local WINDOW_NAMES = {
	Inventory = "InventoryWindow",
	Shop = "ShopWindow",
	Settings = "SettingsWindow",
	Upgrades = "UpgradesWindow",
	Trade = "TradeWindow",
	Worlds = "WorldsWindow",
	DailyQuests = "DailyQuestsWindow",
	Codes = "CodesWindow",
}

local BOTTOM_BUTTONS = {
	Inventory = "InventoryButton",
	Shop = "ShopButton",
	Settings = "SettingsButton",
	Upgrades = "UpgradesButton",
	Trade = "TradeButton",
}

local SIDE_DOCK_BUTTON_NAMES = { "ShopButton", "SettingsButton", "UpgradesButton", "TradeButton" }
local LEFT_BUTTONS = {
	DailyQuests = "DailyQuestsButton",
	Worlds = "WorldsButton",
	Codes = "CodesButton",
}

local LEGACY_GENERATED_LAYER_NAMES = {
	InventoryUI = true,
	EquipmentShopUI = true,
	GamepassUI = true,
	ShopUI = true,
	WorldUI = true,
	SocialPanelsUI = true,
	CodesUI = true,
	DailyQuestGui = true,
}

local root = playerGui:WaitForChild("ClientUIRoot", 15)
if not root then
	warn("WindowButtonController: missing PlayerGui.ClientUIRoot")
	return
end

local mainHud = root:WaitForChild("MainHUD", 15)
if not mainHud then
	warn("WindowButtonController: missing ClientUIRoot.MainHUD")
	return
end

local modalWindows = mainHud:WaitForChild("ModalWindows", 10)
local windowsFolder = modalWindows and modalWindows:WaitForChild("Windows", 10)
if not windowsFolder then
	warn("WindowButtonController: missing MainHUD.ModalWindows.Windows")
	return
end

local bottomHud = mainHud:FindFirstChild("BottomHUD") or mainHud:FindFirstChild("ButtonsRow")
local leftHud = mainHud:FindFirstChild("LeftHUD")
local dimBackground = mainHud:FindFirstChild("DimBackground")
local menuBlur = Lighting:FindFirstChild("MenuBlur")

local DIM_BACKGROUND_ZINDEX = 10
local HUD_BUTTON_ZINDEX_FLOOR = DIM_BACKGROUND_ZINDEX + 1
local WINDOW_ZINDEX_FLOOR = 20

local windows = {}
local buttons = {}
local activeKey = nil
local dockOpen = false
local lastPressAt = {}
local warned = {}

local function warnOnce(key, message)
	if warned[key] then
		return
	end
	warned[key] = true
	warn(message)
end

local function debounce(key)
	local now = os.clock()
	if lastPressAt[key] and now - lastPressAt[key] < 0.12 then
		return false
	end
	lastPressAt[key] = now
	return true
end

local function findExactButton(scope, name)
	if not scope then
		return nil
	end
	local direct = scope:FindFirstChild(name)
	if direct and direct:IsA("GuiObject") then
		return direct
	end
	local descendant = scope:FindFirstChild(name, true)
	if descendant and descendant:IsA("GuiObject") then
		return descendant
	end
	return nil
end

local function connectPress(guiObject, callback, key)
	if not guiObject then
		return
	end

	local function run()
		if debounce(key) then
			callback()
		end
	end

	if guiObject:IsA("GuiButton") then
		guiObject.Active = true
		guiObject.Activated:Connect(run)
	else
		guiObject.Active = true
		guiObject.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				run()
			end
		end)
	end
end

local function connectButtonContainer(guiObject, callback, key)
	if not guiObject then
		return
	end

	local connected = false
	if guiObject:IsA("GuiButton") then
		connectPress(guiObject, callback, key)
		connected = true
	end

	for _, descendant in ipairs(guiObject:GetDescendants()) do
		if descendant:IsA("GuiButton") then
			connectPress(descendant, callback, key .. "." .. descendant.Name)
			connected = true
		end
	end

	if not connected then
		connectPress(guiObject, callback, key)
	end
end

local function hideLegacyGeneratedLayers()
	for _, child in ipairs(root:GetChildren()) do
		if LEGACY_GENERATED_LAYER_NAMES[child.Name] and child:IsA("GuiObject") then
			child.Visible = false
		end
	end
end

local function applyGuiZIndexFloor(guiObject, zIndexFloor)
	if guiObject:IsA("GuiObject") and guiObject.ZIndex < zIndexFloor then
		guiObject.ZIndex = zIndexFloor
	end

	for _, descendant in ipairs(guiObject:GetDescendants()) do
		if descendant:IsA("GuiObject") and descendant.ZIndex < zIndexFloor then
			descendant.ZIndex = zIndexFloor
		end
	end
end

local function prepareModalWindow(window)
	window.Active = true
	applyGuiZIndexFloor(window, WINDOW_ZINDEX_FLOOR)
end

local function prepareDimBackground()
	if not (dimBackground and dimBackground:IsA("GuiObject")) then
		return
	end

	dimBackground.ZIndex = DIM_BACKGROUND_ZINDEX
	dimBackground.Active = true
	if dimBackground:IsA("TextButton") or dimBackground:IsA("ImageButton") then
		dimBackground.AutoButtonColor = false
	end
end

local function anyWindowVisible()
	for key, window in pairs(windows) do
		if window.Visible then
			return key
		end
	end
	return nil
end

local function setDockOpen(open)
	dockOpen = open == true

	local inventoryButton = buttons.Inventory
	if inventoryButton then
		inventoryButton.Visible = true
		inventoryButton.Active = true
	end

	for _, buttonName in ipairs(SIDE_DOCK_BUTTON_NAMES) do
		local button = findExactButton(bottomHud, buttonName)
		if button then
			button.Visible = dockOpen
			button.Active = dockOpen
		else
			warnOnce("missing-bottom-" .. buttonName, "WindowButtonController: missing BottomHUD." .. buttonName)
		end
	end
end

local function updateDim()
	local open = activeKey ~= nil
	if dimBackground and dimBackground:IsA("GuiObject") then
		dimBackground.Visible = open
	end
	if menuBlur and menuBlur:IsA("BlurEffect") then
		menuBlur.Enabled = open
	end
end

local function closeAllWindows()
	for _, window in pairs(windows) do
		window.Visible = false
	end
	activeKey = nil
	updateDim()
	setDockOpen(false)
	hideLegacyGeneratedLayers()
end

local function openWindow(key)
	local window = windows[key]
	if not window then
		warnOnce("missing-window-" .. tostring(key), "WindowButtonController: missing window " .. tostring(WINDOW_NAMES[key] or key))
		return
	end

	prepareModalWindow(window)
	for _, other in pairs(windows) do
		other.Visible = false
	end
	window.Visible = true
	activeKey = key
	updateDim()
	hideLegacyGeneratedLayers()

	if BOTTOM_BUTTONS[key] then
		setDockOpen(true)
	end
end

local function openWindowByName(windowName)
	for key, mappedName in pairs(WINDOW_NAMES) do
		if mappedName == windowName or key == windowName then
			openWindow(key)
			return
		end
	end
	warnOnce("unknown-request-" .. tostring(windowName), "WindowButtonController: unknown requested window " .. tostring(windowName))
end

for key, windowName in pairs(WINDOW_NAMES) do
	local window = windowsFolder:FindFirstChild(windowName)
	if window and window:IsA("GuiObject") then
		windows[key] = window
		prepareModalWindow(window)
		window.Visible = false

		local closeButton = window:FindFirstChild("CloseButton", true)
		if closeButton and closeButton:IsA("GuiObject") then
			connectButtonContainer(closeButton, closeAllWindows, key .. ".CloseButton")
		else
			warnOnce("missing-close-" .. key, "WindowButtonController: " .. windowName .. " missing CloseButton")
		end

		window:GetPropertyChangedSignal("Visible"):Connect(function()
			if window.Visible then
				activeKey = key
				updateDim()
				if BOTTOM_BUTTONS[key] then
					setDockOpen(true)
				end
			elseif activeKey == key then
				activeKey = anyWindowVisible()
				updateDim()
				if not activeKey then
					setDockOpen(false)
				end
			end
		end)
	else
		warnOnce("missing-window-" .. key, "WindowButtonController: missing MainHUD.ModalWindows.Windows." .. windowName)
	end
end

for key, buttonName in pairs(BOTTOM_BUTTONS) do
	local button = findExactButton(bottomHud, buttonName)
	if button then
		buttons[key] = button
		applyGuiZIndexFloor(button, HUD_BUTTON_ZINDEX_FLOOR)
		connectButtonContainer(button, function()
			openWindow(key)
		end, buttonName)
	else
		warnOnce("missing-bottom-" .. buttonName, "WindowButtonController: missing BottomHUD." .. buttonName)
	end
end

for key, buttonName in pairs(LEFT_BUTTONS) do
	local button = findExactButton(leftHud or mainHud, buttonName)
	if button then
		button.Visible = true
		button.Active = true
		applyGuiZIndexFloor(button, HUD_BUTTON_ZINDEX_FLOOR)
		connectButtonContainer(button, function()
			openWindow(key)
		end, buttonName)
	else
		warnOnce("missing-left-" .. buttonName, "WindowButtonController: missing LeftHUD." .. buttonName)
	end
end

prepareDimBackground()

root:GetAttributeChangedSignal("RequestedWindow"):Connect(function()
	local requested = root:GetAttribute("RequestedWindow")
	if requested and requested ~= "" then
		openWindowByName(requested)
	end
end)

root:GetAttributeChangedSignal("RequestedWindowNonce"):Connect(function()
	local requested = root:GetAttribute("RequestedWindow")
	if requested and requested ~= "" then
		openWindowByName(requested)
	end
end)

root.ChildAdded:Connect(function(child)
	if LEGACY_GENERATED_LAYER_NAMES[child.Name] and child:IsA("GuiObject") then
		child.Visible = false
	end
end)

closeAllWindows()
setDockOpen(false)

print("[WindowButtonController] editable MainHUD windows ready.")
