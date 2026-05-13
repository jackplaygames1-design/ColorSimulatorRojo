-- Binds the Studio-authored SettingsWindow cards without creating replacement UI.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Events = ReplicatedStorage:WaitForChild("Events")
local requestSetSettingEvent = Events:WaitForChild("RequestSetSetting")
local settingsUpdatedEvent = Events:WaitForChild("SettingsUpdated")
local SettingsData = require(ReplicatedStorage:WaitForChild("SettingsData"))

local CARD_CONFIG = {
	MusicCard = {
		title = "Music",
		description = "Background music.",
		settingKey = "Music",
		default = true,
	},
	SFXCard = {
		title = "Sound Effects",
		description = "Sound effects.",
		settingKey = "SFX",
		default = true,
	},
	GraphicsQualityCard = {
		title = "Graphics Quality",
		description = "Studio placeholder slider.",
		status = "3",
		buttonText = "",
		disabled = true,
	},
	DamageNumbersCard = {
		title = "Show Damage Numbers",
		description = "Popup feedback while collecting.",
		settingKey = "Popups",
		default = true,
	},
	TradeRequestsCard = {
		title = "Trade Requests",
		description = "Allow incoming trade requests.",
		settingKey = "TradeRequests",
		default = true,
	},
	HidePetsCard = {
		title = "Pet Hide Mode",
		description = "Hide pet visuals on your client.",
		settingKey = "HidePets",
		default = false,
	},
	AutoHatchCard = {
		title = "Auto Hatch",
		description = "Auto hatch preference.",
		settingKey = "AutoHatch",
		default = false,
	},
	CameraShakeCard = {
		title = "Camera Shake",
		description = "Camera feedback while playing.",
		settingKey = "CameraShake",
		default = true,
	},
	LowDetailCard = {
		title = "Low Detail FX",
		description = "Reduce visual effects.",
		settingKey = "LowFX",
		default = false,
	},
}

local CARD_ORDER = {
	"MusicCard",
	"SFXCard",
	"GraphicsQualityCard",
	"DamageNumbersCard",
	"TradeRequestsCard",
	"HidePetsCard",
	"AutoHatchCard",
	"CameraShakeCard",
	"LowDetailCard",
}

local SCROLL_ORDER = {}
for index, cardName in ipairs(CARD_ORDER) do
	SCROLL_ORDER[cardName] = index * 10
end

local mainHud = playerGui:WaitForChild("MainHUD", 15)
if not mainHud then
	warn("EditableSettingsBinder: missing PlayerGui.MainHUD")
	return
end

local modalWindows = mainHud and mainHud:WaitForChild("ModalWindows", 10)
local settingsWindow = modalWindows and modalWindows:WaitForChild("SettingsWindow", 10)
local content = settingsWindow and settingsWindow:WaitForChild("Content", 10)
if not content then
	warn("EditableSettingsBinder: missing PlayerGui.MainHUD.ModalWindows.SettingsWindow.Content")
	return
end

local connections = {}

local function findText(parent, name)
	local object = parent and parent:FindFirstChild(name, true)
	return object and object:IsA("TextLabel") and object or nil
end

local function findButton(parent)
	local button = parent and parent:FindFirstChild("ToggleButton", true)
		or parent and parent:FindFirstChild("ActionButton", true)
		or parent and parent:FindFirstChild("BuyButton", true)
	return button and button:IsA("GuiButton") and button or nil
end

local function getSettingValue(settingKey, defaultValue)
	local settingsFolder = player:FindFirstChild("Settings")
	local value = settingsFolder and settingsFolder:FindFirstChild(settingKey)
	if value and value:IsA("BoolValue") then
		return value.Value
	end
	return defaultValue == true
end

local function setButtonEnabled(button, enabled)
	if not button then
		return
	end
	button.Active = enabled
	button.Selectable = enabled
	button.AutoButtonColor = enabled
	pcall(function()
		button.Interactable = enabled
	end)
	if not enabled then
		button.BackgroundColor3 = Color3.fromRGB(170, 180, 205)
	end
end

local function setToggleVisual(button, enabled)
	if not button then
		return
	end
	button.BackgroundColor3 = enabled and Color3.fromRGB(84, 225, 112) or Color3.fromRGB(235, 58, 58)
end

local function connectButton(button, callback)
	if not button or button:GetAttribute("EditableSettingsBound") then
		return
	end
	button:SetAttribute("EditableSettingsBound", true)
	button.Activated:Connect(callback)
end

local function openWindow(windowName)
	mainHud:SetAttribute("RequestedWindow", windowName)
	mainHud:SetAttribute("RequestedWindowNonce", os.clock())
end

local function configureRowsScroll(scroll)
	scroll.Active = true
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ClipsDescendants = true
	scroll.ScrollBarThickness = 8
	scroll.ScrollBarImageColor3 = Color3.fromRGB(104, 115, 136)
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.ScrollingEnabled = true
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.fromOffset(0, 0)

	local layout = scroll:FindFirstChildOfClass("UIListLayout") or Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	local padding = scroll:FindFirstChildOfClass("UIPadding") or Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 4)
	padding.PaddingRight = UDim.new(0, 4)
	padding.Parent = scroll
end

local function makeActionRow(scroll)
	local actionRow = scroll:FindFirstChild("ActionButtonsRow")
	if not actionRow or not actionRow:IsA("Frame") then
		actionRow = Instance.new("Frame")
		actionRow.Name = "ActionButtonsRow"
		actionRow.BackgroundTransparency = 1
		actionRow.BorderSizePixel = 0
		actionRow.Parent = scroll
	end

	actionRow.LayoutOrder = 900
	actionRow.Size = UDim2.new(1, -16, 0, 48)
	actionRow.ClipsDescendants = false

	local layout = actionRow:FindFirstChildOfClass("UIListLayout") or Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 14)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = actionRow

	return actionRow
end

local function moveActionButton(scroll, rowsContainer, buttonName, order)
	local button = rowsContainer:FindFirstChild(buttonName) or content:FindFirstChild(buttonName)
	if not button or not button:IsA("GuiButton") then
		return
	end
	if button:IsDescendantOf(scroll) then
		return
	end

	local actionRow = makeActionRow(scroll)
	button.Parent = actionRow
	button.LayoutOrder = order
	button.Position = UDim2.fromOffset(0, 0)
	button.Size = UDim2.new(0.5, -10, 0, 38)
end

local function findRowsContainer()
	local namedRows = content:FindFirstChild("SettingsRows", true)
	if namedRows and namedRows:IsA("GuiObject") then
		return namedRows
	end

	for _, cardName in ipairs(CARD_ORDER) do
		local card = content:FindFirstChild(cardName, true)
		local parent = card and card.Parent
		if parent and parent ~= content and parent:IsA("GuiObject") then
			return parent
		end
	end

	return nil
end

local function ensureScrollableSettingsRows()
	local rowsContainer = findRowsContainer()
	if not rowsContainer then
		return
	end

	local scroll
	if rowsContainer:IsA("ScrollingFrame") then
		scroll = rowsContainer
	else
		rowsContainer.ClipsDescendants = true
		scroll = rowsContainer:FindFirstChild("RowsScroll")
		if not scroll or not scroll:IsA("ScrollingFrame") then
			scroll = Instance.new("ScrollingFrame")
			scroll.Name = "RowsScroll"
			scroll.Parent = rowsContainer
		end

		scroll.Position = UDim2.fromScale(0, 0)
		scroll.Size = UDim2.fromScale(1, 1)
		scroll.ZIndex = rowsContainer.ZIndex + 1

		for cardName, order in pairs(SCROLL_ORDER) do
			local card = rowsContainer:FindFirstChild(cardName)
			if card and card:IsA("GuiObject") then
				card.Parent = scroll
				card.LayoutOrder = order
				card.Position = UDim2.fromOffset(0, 0)
			end
		end
	end

	configureRowsScroll(scroll)

	for cardName, order in pairs(SCROLL_ORDER) do
		local card = scroll:FindFirstChild(cardName)
		if card and card:IsA("GuiObject") then
			card.LayoutOrder = order
		end
	end

	moveActionButton(scroll, rowsContainer, "ApplyButton", 1)
	moveActionButton(scroll, rowsContainer, "ResetButton", 2)
end

local function applyCard(cardName)
	local config = CARD_CONFIG[cardName]
	local card = content:FindFirstChild(cardName, true)
	if not config or not card or not card:IsA("GuiObject") then
		return
	end

	local nameLabel = findText(card, "Name")
	local description = findText(card, "Description")
	local status = findText(card, "Price") or findText(card, "Status")
	local button = findButton(card)

	if nameLabel then
		nameLabel.Text = config.title
	end
	if description then
		description.Text = config.description
	end

	if config.settingKey then
		local enabled = getSettingValue(config.settingKey, config.default)
		if status then
			status.Text = enabled and "ON" or "OFF"
		end
		if button then
			button.Text = enabled and "ON" or "OFF"
			setButtonEnabled(button, true)
			setToggleVisual(button, enabled)
			connectButton(button, function()
				requestSetSettingEvent:FireServer(
					config.settingKey,
					not getSettingValue(config.settingKey, config.default)
				)
			end)
		end
	else
		if status then
			status.Text = config.status or ""
		end
		if button then
			button.Text = config.buttonText or ""
			setButtonEnabled(button, config.disabled ~= true)
			if config.openWindow then
				connectButton(button, function()
					openWindow(config.openWindow)
				end)
			end
		end
	end
end

local function render()
	for _, cardName in ipairs(CARD_ORDER) do
		applyCard(cardName)
	end
end

local function connectActionButton(name, callback)
	local button = content:FindFirstChild(name, true)
	if button and button:IsA("GuiButton") then
		connectButton(button, callback)
	end
end

ensureScrollableSettingsRows()

connectActionButton("ApplyButton", render)
connectActionButton("ResetButton", function()
	for key, defaultValue in pairs(SettingsData.Defaults) do
		requestSetSettingEvent:FireServer(key, defaultValue)
	end
end)

local function hookSettingsFolder(folder)
	if connections.settingsChildAdded then
		connections.settingsChildAdded:Disconnect()
	end
	connections.settingsChildAdded = folder.ChildAdded:Connect(function(child)
		if child:IsA("BoolValue") then
			connections[child] = child:GetPropertyChangedSignal("Value"):Connect(render)
			render()
		end
	end)

	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("BoolValue") and not connections[child] then
			connections[child] = child:GetPropertyChangedSignal("Value"):Connect(render)
		end
	end
end

local settingsFolder = player:FindFirstChild("Settings")
if settingsFolder then
	hookSettingsFolder(settingsFolder)
end

player.ChildAdded:Connect(function(child)
	if child.Name == "Settings" then
		hookSettingsFolder(child)
		render()
	end
end)

settingsUpdatedEvent.OnClientEvent:Connect(render)
render()

print("[EditableSettingsBinder] SettingsWindow cards bound to existing Studio UI.")
