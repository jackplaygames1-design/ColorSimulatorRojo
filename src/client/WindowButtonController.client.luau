-- Bind-only controller for the Studio-authored MainHUD.
-- Expected editable hierarchy:
-- PlayerGui.MainHUD
--   CurrencyBar
--   BottomButtons
--   ModalWindows
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ROOT_PATH = "PlayerGui.MainHUD"
local BUTTONS_PATH = ROOT_PATH .. ".BottomButtons"
local WINDOWS_PATH = ROOT_PATH .. ".ModalWindows"

local BUTTON_TO_WINDOW = {
	ShopButton = "ShopWindow",
	WorldsButton = "WorldsWindow",
	TradeButton = "TradeWindow",
	RankButton = "RankWindow",
	SettingsButton = "SettingsWindow",
}

local SIDE_BUTTON_NAMES = {
	"ShopButton",
	"WorldsButton",
	"TradeButton",
	"RankButton",
	"SettingsButton",
}

local warned = {}
local windows = {}
local allModalWindows = {}
local buttons = {}
local menuExpanded = false
local activeWindowName = nil
local lastPressAt = {}

local function warnOnce(key, message)
	if warned[key] then
		return
	end
	warned[key] = true
	warn(message)
end

local function missing(path)
	warnOnce("missing-" .. path, "WindowButtonController: missing " .. path)
end

local function getChild(parent, name, path, className)
	local child = parent and parent:FindFirstChild(name)
	if not child then
		missing(path)
		return nil
	end
	if className and not child:IsA(className) then
		warnOnce("bad-" .. path, "WindowButtonController: " .. path .. " must be a " .. className)
		return nil
	end
	return child
end

local function findButton(parent, name, path)
	local object = getChild(parent, name, path, "GuiObject")
	if object and (object:IsA("GuiButton") or object:FindFirstChildWhichIsA("GuiButton", true)) then
		return object
	end
	if object then
		warnOnce("bad-button-" .. path, "WindowButtonController: " .. path .. " needs a GuiButton or button child")
	end
	return object
end

local function debounce(key)
	local now = os.clock()
	if lastPressAt[key] and now - lastPressAt[key] < 0.12 then
		return false
	end
	lastPressAt[key] = now
	return true
end

local function playUI(soundName)
	local soundEvent = ReplicatedStorage:FindFirstChild("ColorSimulatorPlaySound")
	if soundEvent and soundEvent:IsA("BindableEvent") then
		soundEvent:Fire("UI", soundName)
	end
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
		return
	end

	guiObject.Active = true
	guiObject.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			run()
		end
	end)

	for _, descendant in ipairs(guiObject:GetDescendants()) do
		if descendant:IsA("GuiButton") then
			descendant.Active = true
			descendant.Activated:Connect(run)
		end
	end
end

local mainHud = playerGui:WaitForChild("MainHUD", 20)
if not mainHud then
	missing(ROOT_PATH)
	return
end

local currencyBar = getChild(mainHud, "CurrencyBar", ROOT_PATH .. ".CurrencyBar", "GuiObject")
local bottomButtons = getChild(mainHud, "BottomButtons", BUTTONS_PATH, "GuiObject")
local modalWindows = getChild(mainHud, "ModalWindows", WINDOWS_PATH)

if not bottomButtons or not modalWindows then
	return
end

if currencyBar then
	currencyBar.Visible = true
end
bottomButtons.Visible = true

local menuButton = findButton(bottomButtons, "MenuButton", BUTTONS_PATH .. ".MenuButton")
if not menuButton then
	return
end
buttons.MenuButton = menuButton
menuButton.Visible = true
menuButton.Active = true

local legacyInventoryButton = bottomButtons:FindFirstChild("InventoryButton")
if legacyInventoryButton and legacyInventoryButton:IsA("GuiObject") then
	legacyInventoryButton.Visible = false
	legacyInventoryButton.Active = false
end

for _, buttonName in ipairs(SIDE_BUTTON_NAMES) do
	buttons[buttonName] = findButton(bottomButtons, buttonName, BUTTONS_PATH .. "." .. buttonName)
end

for _, child in ipairs(modalWindows:GetChildren()) do
	if child:IsA("GuiObject") then
		allModalWindows[child.Name] = child
		child.Visible = false
	end
end

for _, windowName in pairs(BUTTON_TO_WINDOW) do
	local window = allModalWindows[windowName]
	if window then
		windows[windowName] = window
	else
		missing(WINDOWS_PATH .. "." .. windowName)
	end
end
if allModalWindows.InventoryWindow then
	windows.InventoryWindow = allModalWindows.InventoryWindow
else
	missing(WINDOWS_PATH .. ".InventoryWindow")
end

local function setSideButtonsVisible(visible)
	for _, buttonName in ipairs(SIDE_BUTTON_NAMES) do
		local button = buttons[buttonName]
		if button then
			button.Visible = visible
			button.Active = visible
		end
	end
end

local function setMenuExpanded(expanded)
	menuExpanded = expanded == true
	setSideButtonsVisible(menuExpanded or activeWindowName ~= nil)
	bottomButtons.Visible = true
	menuButton.Visible = true
	menuButton.Active = true
	if currencyBar then
		currencyBar.Visible = true
	end
end

local function closeAllWindows()
	for _, window in pairs(allModalWindows) do
		window.Visible = false
	end
	activeWindowName = nil
	playUI("Close")
	setMenuExpanded(false)
end

local function openWindow(windowName)
	local window = allModalWindows[windowName]
	if not window then
		missing(WINDOWS_PATH .. "." .. windowName)
		return
	end

	for _, other in pairs(allModalWindows) do
		other.Visible = false
	end
	window.Visible = true
	activeWindowName = windowName
	playUI("Open")
	setMenuExpanded(true)
end

local function toggleWindow(windowName)
	local window = allModalWindows[windowName]
	if window and window.Visible and activeWindowName == windowName then
		closeAllWindows()
	else
		openWindow(windowName)
	end
end

connectPress(menuButton, function()
	playUI("Click")
	toggleWindow("InventoryWindow")
end, "MenuButton")

for buttonName, windowName in pairs(BUTTON_TO_WINDOW) do
	local button = buttons[buttonName]
	if button then
		connectPress(button, function()
			playUI("Click")
			toggleWindow(windowName)
		end, buttonName)
	end
end

for windowName, window in pairs(allModalWindows) do
	local closeButton = window:FindFirstChild("CloseButton", true)
	if closeButton and closeButton:IsA("GuiObject") then
		connectPress(closeButton, closeAllWindows, windowName .. ".CloseButton")
	end

	window:GetPropertyChangedSignal("Visible"):Connect(function()
		if window.Visible then
			activeWindowName = windowName
			for otherName, other in pairs(allModalWindows) do
				if otherName ~= windowName then
					other.Visible = false
				end
			end
			setMenuExpanded(true)
		elseif activeWindowName == windowName then
			activeWindowName = nil
			for otherName, other in pairs(allModalWindows) do
				if other.Visible then
					activeWindowName = otherName
					break
				end
			end
			setMenuExpanded(menuExpanded)
		end
	end)
end

local function openRequestedWindow()
	local requested = tostring(mainHud:GetAttribute("RequestedWindow") or "")
	if requested == "" then
		return
	end
	local windowName = requested:match("Window$") and requested or (requested .. "Window")
	openWindow(windowName)
end

mainHud:GetAttributeChangedSignal("RequestedWindow"):Connect(openRequestedWindow)
mainHud:GetAttributeChangedSignal("RequestedWindowNonce"):Connect(openRequestedWindow)

setMenuExpanded(false)

print("WindowButtonController: bound editable PlayerGui.MainHUD workflow.")
