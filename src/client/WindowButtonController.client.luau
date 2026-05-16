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

local BUTTON_TO_WINDOW = {
	ShopButton = "ShopWindow",
	WorldsButton = "WorldsWindow",
	TradeButton = "TradeWindow",
	RankButton = "RankWindow",
	SettingsButton = "SettingsWindow",
}

local WINDOW_ALIASES = {
	InventoryWindow = { "InventoryWindow" },
	ShopWindow = { "ShopWindow" },
	WorldsWindow = { "WorldsWindow", "WorldWindow" },
	TradeWindow = { "TradeWindow" },
	RankWindow = { "RankWindow", "RanksWindow" },
	SettingsWindow = { "SettingsWindow" },
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

local MODAL_WINDOW_SIZE = UDim2.fromScale(0.72, 0.72)
local MODAL_WINDOW_POSITION = UDim2.fromScale(0.5, 0.47)
local CLOSE_BUTTON_POSITION = UDim2.new(1, -78, 0, -42)
local CLOSE_BUTTON_SIZE = UDim2.fromOffset(70, 70)
local MOBILE_CLOSE_BUTTON_POSITION = UDim2.new(1, -62, 0, -32)
local MOBILE_CLOSE_BUTTON_SIZE = UDim2.fromOffset(58, 58)
local MODAL_ZINDEX = 1000
local CURRENCY_ZINDEX = 900
local BOTTOM_BUTTON_ZINDEX = 5000
local MOBILE_BOTTOM_ZINDEX = 5500

local BUTTON_LABELS = {
	MenuButton = "MENU",
	RankButton = "RANK",
	SettingsButton = "SET",
	ShopButton = "SHOP",
	TradeButton = "TRADE",
	WorldsButton = "WORLD",
}

local STANDARD_WINDOW_NAMES = {
	BrushShopWindow = true,
	CodesWindow = true,
	DailyQuestsWindow = true,
	InventoryWindow = true,
	RankWindow = true,
	RanksWindow = true,
	ShopWindow = true,
	TutorialWindow = true,
	TradeWindow = true,
	UpgradesWindow = true,
	SettingsWindow = true,
	WorldWindow = true,
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

local function findFirstButton(parent, names, path)
	for _, name in ipairs(names) do
		local button = findButton(parent, name, path .. "." .. name)
		if button then
			return button, name
		end
	end
	return nil, names[1]
end

local function waitForDirectChild(parent, childName, timeout)
	local child = parent and parent:FindFirstChild(childName)
	if child then
		return child
	end
	if parent then
		return parent:WaitForChild(childName, timeout)
	end
	return nil
end

local function findMainHud()
	local direct = waitForDirectChild(playerGui, "MainHUD", 3)
	if direct and direct:IsA("ScreenGui") then
		return direct, "PlayerGui.MainHUD"
	end

	local legacyRoot = waitForDirectChild(playerGui, "ClientUIRoot", 20)
	if legacyRoot then
		local legacyHud = waitForDirectChild(legacyRoot, "MainHUD", 5)
		if legacyHud and legacyHud:IsA("GuiObject") then
			return legacyHud, "PlayerGui.ClientUIRoot.MainHUD"
		end
	end

	return nil, ROOT_PATH
end

local function findBottomButtons(mainHud, rootPath)
	local bottom = getChild(mainHud, "BottomButtons", rootPath .. ".BottomButtons", "GuiObject")
	if bottom then
		return bottom, rootPath .. ".BottomButtons"
	end
	bottom = getChild(mainHud, "BottomRow", rootPath .. ".BottomRow", "GuiObject")
	if bottom then
		return bottom, rootPath .. ".BottomRow"
	end
	return nil, rootPath .. ".BottomButtons"
end

local function findWindowContainer(mainHud, rootPath)
	local modal = getChild(mainHud, "ModalWindows", rootPath .. ".ModalWindows")
	if not modal then
		return nil, rootPath .. ".ModalWindows"
	end

	local windowsFolder = modal:FindFirstChild("Windows")
	if windowsFolder then
		return windowsFolder, rootPath .. ".ModalWindows.Windows"
	end
	return modal, rootPath .. ".ModalWindows"
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
	local minAxis = math.min(viewport.X, viewport.Y)
	local maxAxis = math.max(viewport.X, viewport.Y)
	return UserInputService.TouchEnabled and (minAxis <= 1024 or maxAxis <= 1280)
end

local function isPhoneLayout()
	local viewport = getViewportSize()
	return UserInputService.TouchEnabled and math.min(viewport.X, viewport.Y) <= 720
end

local function getSafeFrame(margin)
	local viewport = getViewportSize()
	local topLeftInset, bottomRightInset = GuiService:GetGuiInset()
	local left = topLeftInset.X + margin
	local top = topLeftInset.Y + margin
	local width = math.max(1, viewport.X - topLeftInset.X - bottomRightInset.X - margin * 2)
	local height = math.max(1, viewport.Y - topLeftInset.Y - bottomRightInset.Y - margin * 2)
	return left, top, width, height
end

local function ensureTouchTarget(guiObject, minSize)
	if not (guiObject and guiObject:IsA("GuiObject")) then
		return
	end

	local constraint = guiObject:FindFirstChild("RuntimeTouchTarget")
	if constraint and not constraint:IsA("UISizeConstraint") then
		constraint:Destroy()
		constraint = nil
	end

	if not constraint then
		constraint = Instance.new("UISizeConstraint")
		constraint.Name = "RuntimeTouchTarget"
		constraint.Parent = guiObject
	end

	constraint.MinSize = Vector2.new(minSize, minSize)
end

local function findResponsiveScale(parent)
	if not parent then
		return nil
	end
	local scale = parent:FindFirstChild("ResponsiveScale")
	if scale and scale:IsA("UIScale") then
		return scale
	end
	scale = parent:FindFirstChild("RuntimeMobileScale")
	if scale and scale:IsA("UIScale") then
		return scale
	end
	return nil
end

local function hasRenderableImage(image)
	image = tostring(image or "")
	return image:match("^rbxassetid://%d+") ~= nil or image:match("^http") ~= nil
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
	ensureTouchTarget(closeButton, mobile and 52 or 44)
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

	local closeIcon = closeButton:FindFirstChild("CloseIcon")
	if not closeIcon or not closeIcon:IsA("TextLabel") then
		return
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
		local limit = icon:FindFirstChildOfClass("UITextSizeConstraint")
		if limit then
			limit.MinTextSize = 12
			limit.MaxTextSize = 22
		end
	end

	local amount = slot:FindFirstChild("Amount")
	if amount and amount:IsA("TextLabel") then
		amount.Position = UDim2.fromOffset(80, 0)
		amount.Size = UDim2.new(1, -86, 1, 0)
		amount.TextScaled = true
		amount.TextXAlignment = Enum.TextXAlignment.Left
		amount.ZIndex = slot.ZIndex + 1
		local limit = amount:FindFirstChildOfClass("UITextSizeConstraint")
		if limit then
			limit.MinTextSize = 12
			limit.MaxTextSize = 20
		end
	end
end

local function styleCurrencyBar()
	if not currencyBar then
		return
	end

	currencyBar.AnchorPoint = Vector2.new(0, 0)
	if isMobileLayout() then
		local topLeftInset = GuiService:GetGuiInset()
		currencyBar.Position = UDim2.fromOffset(topLeftInset.X + 8, topLeftInset.Y + 8)
		currencyBar.Size = UDim2.fromOffset(128, 92)
	else
		currencyBar.Position = UDim2.new(0, 8, 0.5, 8)
		currencyBar.Size = UDim2.fromOffset(136, 100)
	end
	currencyBar.BackgroundTransparency = 1
	currencyBar.ClipsDescendants = false
	currencyBar.ZIndex = math.max(currencyBar.ZIndex, CURRENCY_ZINDEX)

	for _, child in ipairs(currencyBar:GetChildren()) do
		if child:IsA("GuiObject") then
			if child.Name == "ColorFrame" or child.Name == "ColorsFrame" or child.Name == "PaintFrame" then
				child.Visible = false
				child:SetAttribute("DeprecatedNoBackpackCurrency", true)
			else
				styleCurrencySlot(child)
			end
		end
	end
end

local function styleBottomButtonVisual(button)
	if not button or not button:IsA("ImageButton") then
		return
	end

	local hasImage = hasRenderableImage(button.Image)
	button.ImageTransparency = hasImage and 0 or 1
	button.ScaleType = Enum.ScaleType.Fit
	ensureTouchTarget(button, isMobileLayout() and 52 or 44)

	local label = button:FindFirstChild("Label")
	if label and label:IsA("TextLabel") then
		label.Text = hasImage and "" or tostring(button:GetAttribute("Label") or BUTTON_LABELS[button.Name] or "")
		label.Visible = not hasImage
		label.TextScaled = true
		label.TextWrapped = true
	end
end

local function styleBottomButtonVisuals()
	if not bottomButtons then
		return
	end
	for _, child in ipairs(bottomButtons:GetChildren()) do
		styleBottomButtonVisual(child)
	end
end

local function styleBottomButtons()
	local scale = findResponsiveScale(bottomButtons)
	if isPhoneLayout() and activeWindowName ~= nil then
		bottomButtons.Visible = false
		return
	end

	bottomButtons.Visible = true
	if isMobileLayout() then
		local viewport = getViewportSize()
		local portrait = viewport.Y >= viewport.X
		local bottomOffset = getBottomInset() + (portrait and 116 or 78)
		local targetWidth = math.floor(math.min(viewport.X * (portrait and 0.88 or 0.58), portrait and 390 or 440))
		bottomButtons.AnchorPoint = Vector2.new(0.5, 1)
		bottomButtons.Position = UDim2.new(0.5, 0, 1, -bottomOffset)
		bottomButtons.Size = UDim2.fromOffset(targetWidth, portrait and 66 or 62)
		bottomButtons.BackgroundTransparency = 1
		bottomButtons.ClipsDescendants = false
		bottomButtons.ZIndex = math.max(bottomButtons.ZIndex, MOBILE_BOTTOM_ZINDEX)
		if scale then
			scale.Scale = portrait and 0.82 or 0.88
		end
		raiseGuiObjectTree(bottomButtons, MOBILE_BOTTOM_ZINDEX)
		styleBottomButtonVisuals()
		return
	end

	if scale then
		scale.Scale = 1
	end
	bottomButtons.AnchorPoint = Vector2.new(0.5, 1)
	bottomButtons.Position = UDim2.new(0.5, 0, 1, -24)
	bottomButtons.Size = UDim2.fromOffset(540, 78)
	bottomButtons.BackgroundTransparency = 1
	bottomButtons.ClipsDescendants = false
	bottomButtons.ZIndex = math.max(bottomButtons.ZIndex, BOTTOM_BUTTON_ZINDEX)
	raiseGuiObjectTree(bottomButtons, BOTTOM_BUTTON_ZINDEX)
	styleBottomButtonVisuals()
end

local function styleScrollableAreas(root, mobile)
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("ScrollingFrame") then
			descendant.ScrollingEnabled = true
			descendant.ScrollBarThickness = mobile and 5 or math.max(descendant.ScrollBarThickness, 6)
			descendant.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
			descendant.ScrollingDirection = Enum.ScrollingDirection.XY
		end
	end
end

local function styleModalWindow(windowName, window)
	if
		not (
			window
			and window:IsA("GuiObject")
			and (
				STANDARD_WINDOW_NAMES[windowName]
				or window:GetAttribute("ResponsiveWindow") == true
				or windowName:match("Window$") ~= nil
			)
		)
	then
		return
	end

	window.AnchorPoint = Vector2.new(0.5, 0.5)
	local mobile = isMobileLayout()
	window:SetAttribute("MobileLayoutActive", mobile)
	local scale = findResponsiveScale(window)
	if mobile then
		local viewport = getViewportSize()
		local portrait = viewport.Y >= viewport.X
		local margin = portrait and 10 or 16
		local left, top, safeWidth, safeHeight = getSafeFrame(margin)
		local scaleValue = math.clamp(math.min(safeWidth / 900, safeHeight / 720), portrait and 0.56 or 0.54, 0.92)
		local widthScale = portrait and (window:GetAttribute("MobilePortraitWidthScale") or 0.94)
			or (window:GetAttribute("MobileLandscapeWidthScale") or 0.78)
		local heightScale = portrait and (window:GetAttribute("MobilePortraitHeightScale") or 0.78)
			or (window:GetAttribute("MobileLandscapeHeightScale") or 0.82)
		if isPhoneLayout() then
			widthScale = math.max(widthScale, portrait and 1 or 0.9)
			heightScale = math.max(heightScale, portrait and 1 or 0.92)
		end
		local width = math.floor(math.min(safeWidth * widthScale, safeWidth))
		local height = math.floor(math.min(safeHeight * heightScale, safeHeight))
		if scale then
			scale.Scale = scaleValue
		end
		window.Position = UDim2.fromOffset(math.floor(left + safeWidth * 0.5), math.floor(top + safeHeight * 0.5))
		window.Size = UDim2.fromOffset(math.floor(width / scaleValue), math.floor(height / scaleValue))
	else
		if scale then
			scale.Scale = 1
		end
		window.Position = MODAL_WINDOW_POSITION
		window.Size = UDim2.fromScale(
			window:GetAttribute("DesktopWidthScale") or MODAL_WINDOW_SIZE.X.Scale,
			window:GetAttribute("DesktopHeightScale") or MODAL_WINDOW_SIZE.Y.Scale
		)
	end
	window.ClipsDescendants = false
	window.ZIndex = math.max(window.ZIndex, MODAL_ZINDEX)

	local closeButton = window:FindFirstChild("CloseButton", true)
	if closeButton and closeButton:IsA("GuiObject") then
		styleCloseIcon(closeButton)
	end
	styleScrollableAreas(window, mobile)
end

local function restyleAll()
	styleBottomButtons()
	styleCurrencyBar()
	for windowName, window in pairs(allModalWindows) do
		styleModalWindow(windowName, window)
	end
end

local function resolveWindow(windowName)
	for _, alias in ipairs(WINDOW_ALIASES[windowName] or { windowName }) do
		local window = allModalWindows[alias]
		if window then
			return window, alias
		end
	end
	return nil, windowName
end

local function looksLikeInventoryMenuButton(object)
	if not (object and object:IsA("GuiObject")) then
		return false
	end
	return object.Name == "MenuButton" or object.Name == "InventoryButton" or object.Name == "ItemsButton"
end

local mainHud, actualRootPath = findMainHud()
if not mainHud then
	missing(actualRootPath)
	return
end

currencyBar = getChild(mainHud, "CurrencyBar", actualRootPath .. ".CurrencyBar", "GuiObject")
local actualButtonsPath = nil
bottomButtons, actualButtonsPath = findBottomButtons(mainHud, actualRootPath)
local modalWindows = nil
local actualWindowsPath = nil
modalWindows, actualWindowsPath = findWindowContainer(mainHud, actualRootPath)

if not bottomButtons or not modalWindows then
	return
end

if currencyBar then
	currencyBar.Visible = true
	styleCurrencyBar()
end
bottomButtons.Visible = true
styleBottomButtons()

local menuButton = findFirstButton(bottomButtons, { "MenuButton", "InventoryButton", "ItemsButton" }, actualButtonsPath)
if not menuButton then
	return
end
buttons.MenuButton = menuButton
menuButton.Visible = true
menuButton.Active = true

for _, buttonName in ipairs(SIDE_BUTTON_NAMES) do
	buttons[buttonName] = findButton(bottomButtons, buttonName, actualButtonsPath .. "." .. buttonName)
end

for _, child in ipairs(modalWindows:GetChildren()) do
	if child:IsA("GuiObject") then
		allModalWindows[child.Name] = child
		styleModalWindow(child.Name, child)
		child.Visible = false
	end
end

for _, windowName in pairs(BUTTON_TO_WINDOW) do
	local window = resolveWindow(windowName)
	if window then
		windows[windowName] = window
	else
		missing(actualWindowsPath .. "." .. windowName)
	end
end
local inventoryWindow = resolveWindow("InventoryWindow")
if inventoryWindow then
	windows.InventoryWindow = inventoryWindow
else
	missing(actualWindowsPath .. ".InventoryWindow")
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
	local phoneModalOpen = isPhoneLayout() and activeWindowName ~= nil
	setSideButtonsVisible((menuExpanded or activeWindowName ~= nil) and not phoneModalOpen)
	bottomButtons.Visible = not phoneModalOpen
	menuButton.Visible = not phoneModalOpen
	menuButton.Active = not phoneModalOpen
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
	local window, resolvedName = resolveWindow(windowName)
	if not window then
		missing(actualWindowsPath .. "." .. windowName)
		return
	end

	for _, other in pairs(allModalWindows) do
		other.Visible = false
	end
	window.Visible = true
	activeWindowName = resolvedName
	playUI("Open")
	setMenuExpanded(true)
end

local function toggleWindow(windowName)
	local window, resolvedName = resolveWindow(windowName)
	if window and window.Visible and activeWindowName == resolvedName then
		closeAllWindows()
	else
		openWindow(windowName)
	end
end

local function bindInventoryMenuButton(button)
	if not button or button:GetAttribute("WindowButtonControllerInventoryBound") == true then
		return
	end
	button:SetAttribute("WindowButtonControllerInventoryBound", true)
	button.Visible = true
	button.Active = true
	connectPress(button, function()
		playUI("Click")
		if not menuExpanded and activeWindowName == nil then
			setMenuExpanded(true)
		end
		toggleWindow("InventoryWindow")
	end, "InventoryMenuButton")
end

bindInventoryMenuButton(menuButton)
for _, descendant in ipairs(mainHud:GetDescendants()) do
	if looksLikeInventoryMenuButton(descendant) then
		bindInventoryMenuButton(descendant)
	end
end

mainHud.DescendantAdded:Connect(function(descendant)
	if looksLikeInventoryMenuButton(descendant) then
		task.defer(function()
			if descendant.Parent then
				bindInventoryMenuButton(descendant)
			end
		end)
	end
end)

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
mainHud:GetAttributeChangedSignal("HatchSpotlightClosedMenusAt"):Connect(function()
	closeAllWindows()
	setMenuExpanded(false)
end)

setMenuExpanded(false)

print("WindowButtonController: bound editable " .. actualRootPath .. " workflow.")
