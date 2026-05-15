-- Bind-only controller for the Studio-authored MainHUD.
-- Expected editable hierarchy:
-- PlayerGui.MainHUD
--   CurrencyBar
--   BottomButtons
--   ModalWindows
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

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
local currencyBar = nil
local bottomButtons = nil
local menuExpanded = false
local activeWindowName = nil
local lastPressAt = {}

local MODAL_WINDOW_SIZE = UDim2.fromScale(0.76, 0.68)
local MODAL_WINDOW_POSITION = UDim2.fromScale(0.5, 0.47)
local CLOSE_BUTTON_POSITION = UDim2.new(1, -78, 0, -42)
local CLOSE_BUTTON_SIZE = UDim2.fromOffset(70, 70)
local MOBILE_CLOSE_BUTTON_POSITION = UDim2.new(1, -62, 0, -32)
local MOBILE_CLOSE_BUTTON_SIZE = UDim2.fromOffset(58, 58)
local MODAL_ZINDEX = 1000
local CURRENCY_ZINDEX = 900
local BOTTOM_BUTTON_ZINDEX = 5000
local MOBILE_BOTTOM_ZINDEX = 5500

local STANDARD_WINDOW_NAMES = {
	InventoryWindow = true,
	ShopWindow = true,
	TradeWindow = true,
	RankWindow = true,
	SettingsWindow = true,
	WorldsWindow = true,
}

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

local function getViewportSize()
	local camera = Workspace.CurrentCamera
	return camera and camera.ViewportSize or Vector2.new(1280, 720)
end

local function getBottomInset()
	local _, bottomRight = GuiService:GetGuiInset()
	return math.max(0, bottomRight.Y)
end

local function isMobileLayout()
	local viewport = getViewportSize()
	return UserInputService.TouchEnabled
		and not UserInputService.KeyboardEnabled
		and math.min(viewport.X, viewport.Y) <= 900
end

local function getOrCreateScale(parent, name)
	local scale = parent and parent:FindFirstChild(name)
	if scale and scale:IsA("UIScale") then
		return scale
	end
	if scale then
		scale:Destroy()
	end
	scale = Instance.new("UIScale")
	scale.Name = name
	scale.Parent = parent
	return scale
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

local function styleCloseIcon(closeButton)
	if not closeButton or not closeButton:IsA("GuiObject") then
		return
	end

	local mobile = isMobileLayout()
	closeButton.Position = mobile and MOBILE_CLOSE_BUTTON_POSITION or CLOSE_BUTTON_POSITION
	closeButton.Size = mobile and MOBILE_CLOSE_BUTTON_SIZE or CLOSE_BUTTON_SIZE
	closeButton.BackgroundColor3 = Color3.fromRGB(216, 24, 32)
	closeButton.BorderSizePixel = 0
	closeButton.ZIndex = math.max(closeButton.ZIndex, MODAL_ZINDEX + 4)
	closeButton:SetAttribute("NoTextGlow", true)
	if closeButton:IsA("TextButton") then
		closeButton.Text = "X"
		closeButton.TextScaled = false
		closeButton.TextSize = mobile and 40 or 48
		closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		closeButton.TextStrokeColor3 = Color3.fromRGB(27, 42, 53)
		closeButton.TextStrokeTransparency = 0
		closeButton.Font = Enum.Font.GothamBlack
		pcall(function()
			closeButton.FontFace =
				Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy, Enum.FontStyle.Normal)
		end)
		local oldIcon = closeButton:FindFirstChild("CloseIcon")
		if oldIcon and oldIcon:IsA("GuiObject") then
			oldIcon.Visible = false
		end
		return
	end

	local runtimeText = closeButton:FindFirstChild("RuntimeText")
	if runtimeText and runtimeText:IsA("GuiObject") then
		runtimeText:Destroy()
	end

	local closeIcon = closeButton:FindFirstChild("CloseIcon")
	if not closeIcon or not closeIcon:IsA("TextLabel") then
		if closeIcon then
			closeIcon:Destroy()
		end
		closeIcon = Instance.new("TextLabel")
		closeIcon.Name = "CloseIcon"
		closeIcon.BackgroundTransparency = 1
		closeIcon.BorderSizePixel = 0
		closeIcon.Position = UDim2.fromScale(0, 0)
		closeIcon.Size = UDim2.fromScale(1, 1)
		closeIcon.Parent = closeButton
	end
	closeIcon.Visible = true
	closeIcon.Text = "X"
	closeIcon.TextScaled = false
	closeIcon.TextSize = mobile and 40 or 48
	closeIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeIcon.TextStrokeColor3 = Color3.fromRGB(27, 42, 53)
	closeIcon.TextStrokeTransparency = 0
	closeIcon.TextXAlignment = Enum.TextXAlignment.Center
	closeIcon.TextYAlignment = Enum.TextYAlignment.Center
	closeIcon.Font = Enum.Font.GothamBlack
	closeIcon.ZIndex = closeButton.ZIndex + 1
	pcall(function()
		closeIcon.FontFace =
			Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy, Enum.FontStyle.Normal)
	end)
end

local function raiseGuiObjectTree(root, baseZIndex)
	if not root or not root:IsA("GuiObject") then
		return
	end
	root.ZIndex = math.max(root.ZIndex, baseZIndex)
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("GuiObject") then
			descendant.ZIndex = math.max(descendant.ZIndex, baseZIndex + 1)
		end
	end
end

local function styleCurrencySlot(slot)
	if not slot or not slot:IsA("GuiObject") then
		return
	end

	slot.Size = UDim2.fromOffset(128, 42)
	slot.ClipsDescendants = false
	slot.ZIndex = math.max(slot.ZIndex, CURRENCY_ZINDEX + 1)

	local icon = slot:FindFirstChild("Icon")
	if icon and icon:IsA("TextLabel") then
		icon.Position = UDim2.fromOffset(8, 0)
		icon.Size = UDim2.fromOffset(66, 42)
		icon.TextScaled = true
		icon.TextXAlignment = Enum.TextXAlignment.Left
		icon.ZIndex = slot.ZIndex + 1
		local limit = icon:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
		limit.MinTextSize = 12
		limit.MaxTextSize = 22
		limit.Parent = icon
	end

	local amount = slot:FindFirstChild("Amount")
	if amount and amount:IsA("TextLabel") then
		amount.Position = UDim2.fromOffset(80, 0)
		amount.Size = UDim2.new(1, -86, 1, 0)
		amount.TextScaled = true
		amount.TextXAlignment = Enum.TextXAlignment.Left
		amount.ZIndex = slot.ZIndex + 1
		local limit = amount:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
		limit.MinTextSize = 12
		limit.MaxTextSize = 20
		limit.Parent = amount
	end
end

local function styleCurrencyBar()
	if not currencyBar then
		return
	end

	currencyBar.AnchorPoint = Vector2.new(0, 0)
	currencyBar.Position = UDim2.new(0, 8, 0.5, 8)
	currencyBar.Size = UDim2.fromOffset(136, 150)
	currencyBar.BackgroundTransparency = 1
	currencyBar.ClipsDescendants = false
	currencyBar.ZIndex = math.max(currencyBar.ZIndex, CURRENCY_ZINDEX)

	for _, child in ipairs(currencyBar:GetChildren()) do
		if child:IsA("GuiObject") then
			styleCurrencySlot(child)
		end
	end
end

local function styleBottomButtons()
	local scale = getOrCreateScale(bottomButtons, "RuntimeMobileScale")
	if isMobileLayout() then
		local viewport = getViewportSize()
		local portrait = viewport.Y >= viewport.X
		local bottomOffset = getBottomInset() + (portrait and 148 or 104)
		local targetWidth = math.floor(math.min(viewport.X * (portrait and 0.86 or 0.56), portrait and 390 or 440))
		bottomButtons.AnchorPoint = Vector2.new(0.5, 1)
		bottomButtons.Position = UDim2.new(0.5, 0, 1, -bottomOffset)
		bottomButtons.Size = UDim2.fromOffset(targetWidth, portrait and 64 or 62)
		bottomButtons.BackgroundTransparency = 1
		bottomButtons.ClipsDescendants = false
		bottomButtons.ZIndex = math.max(bottomButtons.ZIndex, MOBILE_BOTTOM_ZINDEX)
		scale.Scale = portrait and 0.78 or 0.84
		raiseGuiObjectTree(bottomButtons, MOBILE_BOTTOM_ZINDEX)
		return
	end

	scale.Scale = 1
	bottomButtons.AnchorPoint = Vector2.new(0.5, 1)
	bottomButtons.Position = UDim2.new(0.5, 0, 1, -24)
	bottomButtons.Size = UDim2.fromOffset(540, 78)
	bottomButtons.BackgroundTransparency = 1
	bottomButtons.ClipsDescendants = false
	bottomButtons.ZIndex = math.max(bottomButtons.ZIndex, BOTTOM_BUTTON_ZINDEX)
	raiseGuiObjectTree(bottomButtons, BOTTOM_BUTTON_ZINDEX)
end

local function styleModalWindow(windowName, window)
	if not (window and window:IsA("GuiObject") and STANDARD_WINDOW_NAMES[windowName]) then
		return
	end

	window.AnchorPoint = Vector2.new(0.5, 0.5)
	local mobile = isMobileLayout()
	window:SetAttribute("MobileLayoutActive", mobile)
	if windowName == "InventoryWindow" then
		window:SetAttribute("AllowRuntimeInventoryLayout", mobile)
	end

	local scale = getOrCreateScale(window, "RuntimeMobileScale")
	if mobile then
		local viewport = getViewportSize()
		local portrait = viewport.Y >= viewport.X
		local topInset = GuiService:GetGuiInset()
		local scaleValue = math.clamp(math.min(viewport.X / 900, viewport.Y / 720), 0.58, 0.9)
		local width = math.floor(viewport.X * (portrait and 0.94 or 0.78))
		local height = math.floor(viewport.Y * (portrait and 0.76 or 0.82))
		scale.Scale = scaleValue
		window.Position = UDim2.new(0.5, 0, 0.5, math.floor((topInset.Y - getBottomInset()) * 0.18))
		window.Size = UDim2.fromOffset(math.floor(width / scaleValue), math.floor(height / scaleValue))
	else
		scale.Scale = 1
		window.Position = MODAL_WINDOW_POSITION
		window.Size = MODAL_WINDOW_SIZE
	end
	window.ClipsDescendants = false
	window.ZIndex = math.max(window.ZIndex, MODAL_ZINDEX)

	local closeButton = window:FindFirstChild("CloseButton", true)
	if closeButton and closeButton:IsA("GuiObject") then
		styleCloseIcon(closeButton)
	end
end

local function restyleAll()
	styleBottomButtons()
	styleCurrencyBar()
	for windowName, window in pairs(allModalWindows) do
		styleModalWindow(windowName, window)
	end
end

local mainHud = playerGui:WaitForChild("MainHUD", 20)
if not mainHud then
	missing(ROOT_PATH)
	return
end

currencyBar = getChild(mainHud, "CurrencyBar", ROOT_PATH .. ".CurrencyBar", "GuiObject")
bottomButtons = getChild(mainHud, "BottomButtons", BUTTONS_PATH, "GuiObject")
local modalWindows = getChild(mainHud, "ModalWindows", WINDOWS_PATH)

if not bottomButtons or not modalWindows then
	return
end

if currencyBar then
	currencyBar.Visible = true
	styleCurrencyBar()
end
bottomButtons.Visible = true
styleBottomButtons()

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
		styleModalWindow(child.Name, child)
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
		styleCloseIcon(closeButton)
		connectPress(closeButton, closeAllWindows, windowName .. ".CloseButton")
	end

	window:GetPropertyChangedSignal("Visible"):Connect(function()
		styleModalWindow(windowName, window)
		styleBottomButtons()
		styleCurrencyBar()
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

local function watchViewportChanges()
	local function connectCamera(camera)
		if not camera then
			return
		end
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(restyleAll)
	end

	connectCamera(Workspace.CurrentCamera)
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		connectCamera(Workspace.CurrentCamera)
		restyleAll()
	end)
end
watchViewportChanges()

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
