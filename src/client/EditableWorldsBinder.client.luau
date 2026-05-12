-- Binds the Studio-authored WorldsWindow. This script does not create cards or windows at runtime.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ColorData = require(ReplicatedStorage:WaitForChild("ColorData"))
local GameBalance = require(ReplicatedStorage:WaitForChild("GameBalance"))

local Events = ReplicatedStorage:WaitForChild("Events")
local unlockAreaEvent = Events:WaitForChild("UnlockArea", 20)
local requestTravelToSectorEvent = Events:WaitForChild("RequestTravelToSector", 20)
local requestTravelToLocationEvent = Events:WaitForChild("RequestTravelToLocation", 20)
local travelResultEvent = Events:WaitForChild("TravelToLocationResult", 20)

local OUTLINE = Color3.fromRGB(35, 38, 45)
local TEXT_DARK = Color3.fromRGB(38, 36, 52)
local MUTED = Color3.fromRGB(92, 98, 116)
local GREEN = Color3.fromRGB(84, 225, 112)
local CYAN = Color3.fromRGB(76, 214, 224)
local DISABLED = Color3.fromRGB(170, 180, 205)
local TAB_INACTIVE = Color3.fromRGB(232, 238, 248)
local LOCKED_RED = Color3.fromRGB(220, 72, 92)
local GOLD = Color3.fromRGB(255, 218, 74)

local TELEPORTS = {
	OriginSector = {
		statusWhenReady = "READY",
		requiredColor = nil,
		requiresTeleportUnlock = false,
		alwaysUnlocked = true,
		worldColor = "Red",
	},
	RedWastelands = {
		statusWhenReady = "READY",
		requiredColor = nil,
		requiresTeleportUnlock = false,
		alwaysUnlocked = true,
		worldColor = "Red",
	},
	ZorkShop = {
		statusWhenReady = "READY",
		requiredColor = nil,
		requiresTeleportUnlock = false,
		alwaysUnlocked = true,
		worldColor = "Red",
	},
	OrangeSector = {
		statusWhenReady = "READY",
		requiredColor = "Orange",
		requiresTeleportUnlock = false,
		worldColor = "Orange",
	},
	GreenSector = {
		statusWhenReady = "READY",
		requiredColor = "Green",
		requiresTeleportUnlock = false,
		worldColor = "Green",
	},
	InsidePipes = {
		statusWhenReady = "READY",
		requiredColor = "Orange",
		requiresTeleportUnlock = true,
		worldColor = "Orange",
	},
}

local activePage = "Sectors"
local statusMessage = ""

local function mainHUD()
	return playerGui:WaitForChild("MainHUD", 30)
end

local function windowsFolder(main)
	local modal = main and main:FindFirstChild("ModalWindows")
	return modal
end

local main = mainHUD()
local windows = windowsFolder(main)
local worldsWindow = windows and windows:WaitForChild("WorldsWindow", 30)
if not worldsWindow then
	warn("EditableWorldsBinder: missing PlayerGui.MainHUD.ModalWindows.WorldsWindow")
	return
end

local content = worldsWindow:WaitForChild("Content", 10)
if not content then
	warn("EditableWorldsBinder: missing PlayerGui.MainHUD.ModalWindows.WorldsWindow.Content")
	return
end

local function formatNumber(value)
	if GameBalance and GameBalance.formatNumber then
		return GameBalance.formatNumber(value)
	end
	return tostring(math.floor(tonumber(value) or 0))
end

local function maxPlayableIndex()
	local progression = GameBalance.Progression or {}
	return tonumber(progression.MaxPlayableSectorIndex) or #(ColorData.Worlds or {})
end

local function findText(parent, name)
	local object = parent and parent:FindFirstChild(name, true)
	if object and (object:IsA("TextLabel") or object:IsA("TextButton")) then
		return object
	end
	return nil
end

local function findButton(parent, name)
	local object = parent and parent:FindFirstChild(name, true)
	return object and object:IsA("GuiButton") and object or nil
end

local function setText(parent, name, value)
	local label = findText(parent, name)
	if label then
		label.Text = tostring(value or "")
	end
	return label
end

local function getColorStorage()
	return player:FindFirstChild("ColorStorage")
end

local function getUnlockedColorSet()
	local storage = getColorStorage()
	local unlockedValue = storage and storage:FindFirstChild("UnlockedColors")
	local csv = unlockedValue and unlockedValue.Value or player:GetAttribute("UnlockedColors") or "Red"
	local set = ColorData.getUnlockedColorSet(csv)
	set.Red = true
	return set
end

local function getCurrentWorld()
	local storage = getColorStorage()
	local currentValue = storage and storage:FindFirstChild("CurrentWorld")
	local colorType = currentValue and currentValue.Value or player:GetAttribute("ActiveWorldColor") or "Red"
	return ColorData.getWorldByColor(colorType) and colorType or "Red"
end

local function getHighestVisibleWorldIndex(unlocked)
	local highestUnlocked = 1
	for _, world in ipairs(ColorData.Worlds or {}) do
		local colorType = world.primaryColor or world.id
		if unlocked[colorType] == true then
			local index = tonumber(world.WorldIndex or ColorData.getWorldIndex(colorType)) or 1
			highestUnlocked = math.max(highestUnlocked, index)
		end
	end
	return math.min(highestUnlocked + 1, maxPlayableIndex())
end

local function focusCurrentSector()
	local carousel = content:FindFirstChild("SectorCarousel", true)
	if not carousel or not carousel:IsA("ScrollingFrame") then
		return
	end

	local currentColor = getCurrentWorld()
	local world = ColorData.getWorldByColor(currentColor)
	local worldIndex = tonumber(world and (world.WorldIndex or ColorData.getWorldIndex(currentColor))) or 1
	local cardStep = tonumber(carousel:GetAttribute("CardStep")) or 768
	carousel.CanvasPosition = Vector2.new(math.max(0, (worldIndex - 1) * cardStep), 0)
end

local function updateSectorCarouselWindow(unlocked)
	local carousel = content:FindFirstChild("SectorCarousel", true)
	if not carousel or not carousel:IsA("ScrollingFrame") then
		return
	end

	local visibleLimit = getHighestVisibleWorldIndex(unlocked)
	local visibleCount = 0
	for _, world in ipairs(ColorData.Worlds or {}) do
		local colorType = world.primaryColor or world.id
		local worldIndex = tonumber(world.WorldIndex or ColorData.getWorldIndex(colorType)) or 1
		local card = carousel:FindFirstChild(tostring(colorType) .. "SectorCard")
		if card and card:IsA("GuiObject") then
			local visible = worldIndex <= visibleLimit
			card.Visible = visible
			card.Size = visible and UDim2.fromOffset(744, 206) or UDim2.fromOffset(0, 206)
			if visible then
				visibleCount += 1
			end
		end
	end

	local cardStep = tonumber(carousel:GetAttribute("CardStep")) or 768
	carousel.CanvasSize = UDim2.fromOffset(math.max(cardStep, (visibleCount * cardStep) + 36), 0)
end

local function getCoins()
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")
	return coins and tonumber(coins.Value) or 0
end

local function getUnlockedTeleportSet()
	local storage = getColorStorage()
	local value = storage and storage:FindFirstChild("UnlockedTeleports")
	local csv = value and value.Value or player:GetAttribute("UnlockedTeleports") or "OriginSector"
	local set = { OriginSector = true, RedWastelands = true, ZorkShop = true }
	for _, locationId in ipairs(string.split(tostring(csv or ""), ",")) do
		if locationId ~= "" then
			set[locationId] = true
		end
	end
	return set
end

local function isWorldPlayable(world)
	local index = tonumber(world and (world.WorldIndex or ColorData.getWorldIndex(world.primaryColor or world.id)))
		or math.huge
	return index <= maxPlayableIndex()
end

local function canUnlockWorld(world, unlocked)
	local colorType = world.primaryColor or world.id
	if not isWorldPlayable(world) or unlocked[colorType] == true then
		return false
	end
	local previous = ColorData.getPreviousWorld(colorType)
	if previous and unlocked[previous.primaryColor] ~= true then
		return false
	end
	return getCoins() >= (tonumber(world.UnlockCost or world.unlockCost) or 0)
end

local function setGuiEnabled(button, enabled)
	if not button then
		return
	end
	button.Active = enabled
	button.Selectable = enabled
	button.AutoButtonColor = enabled
	pcall(function()
		button.Interactable = enabled
	end)
end

local function setStatus(status, textValue, color, textColor)
	if not status then
		return
	end
	status.Text = textValue
	status.BackgroundColor3 = color
	status.TextColor3 = textColor or Color3.fromRGB(255, 255, 255)
end

local function setStroke(card, color, thickness)
	local stroke = card and card:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = color or OUTLINE
		stroke.Thickness = thickness or 2
	end
end

local function worldAccent(colorType)
	local config = ColorData.Colors and ColorData.Colors[colorType]
	return config and config.color or CYAN
end

local function requestWorldAction(button)
	local colorType = button:GetAttribute("WorldColor")
	local world = colorType and ColorData.getWorldByColor(colorType)
	if not world then
		return
	end

	local unlocked = getUnlockedColorSet()
	if unlocked[colorType] == true then
		if requestTravelToSectorEvent and requestTravelToSectorEvent:IsA("RemoteEvent") then
			requestTravelToSectorEvent:FireServer(colorType)
		end
	elseif canUnlockWorld(world, unlocked) and unlockAreaEvent and unlockAreaEvent:IsA("RemoteEvent") then
		unlockAreaEvent:FireServer("unlock", colorType)
	end
end

local function bindWorldButton(button)
	if not button or button:GetAttribute("EditableWorldButtonBound") == true then
		return
	end
	button:SetAttribute("EditableWorldButtonBound", true)
	button.Activated:Connect(function()
		requestWorldAction(button)
	end)
end

local function updateWorldCard(world)
	local colorType = world.primaryColor or world.id
	local card = content:FindFirstChild(tostring(colorType) .. "SectorCard", true)
	if not card or not card:IsA("GuiObject") then
		return
	end

	local unlocked = getUnlockedColorSet()
	local current = getCurrentWorld()
	local worldIndex = tonumber(world.WorldIndex or ColorData.getWorldIndex(colorType)) or 1
	if worldIndex > getHighestVisibleWorldIndex(unlocked) then
		card.Visible = false
		card.Size = UDim2.fromOffset(0, 206)
		return
	end
	card.Visible = true
	card.Size = UDim2.fromOffset(744, 206)

	local isUnlocked = unlocked[colorType] == true
	local isCurrent = current == colorType
	local playable = isWorldPlayable(world)
	local canUnlock = canUnlockWorld(world, unlocked)
	local accent = worldAccent(colorType)
	local cost = tonumber(world.UnlockCost or world.unlockCost) or 0
	local button = findButton(card, "TeleportButton")
	local status = findText(card, "Status")

	card:SetAttribute("WorldColor", colorType)
	setText(card, "Name", world.DisplayName or world.name or colorType)
	setText(
		card,
		"Meta",
		"Power x" .. tostring(world.rewardMultiplier or 1) .. " | " .. tostring(#(world.EggIds or {})) .. " eggs"
	)

	if not playable then
		setText(card, "Requirement", "Coming in a future update.")
		setStatus(status, "SOON", DISABLED, TEXT_DARK)
		setStroke(card, DISABLED, 2)
		if button then
			button.Text = "SOON"
			button.BackgroundColor3 = DISABLED
			setGuiEnabled(button, false)
		end
	elseif isCurrent then
		setText(card, "Requirement", "You are here now.")
		setStatus(status, "CURRENT", GREEN)
		setStroke(card, GREEN, 4)
		if button then
			button.Text = "CURRENT"
			button.BackgroundColor3 = GREEN
			setGuiEnabled(button, false)
		end
	elseif isUnlocked then
		setText(card, "Requirement", "Unlocked and ready to travel.")
		setStatus(status, "UNLOCKED", CYAN)
		setStroke(card, accent, 3)
		if button then
			button.Text = "GO"
			button.BackgroundColor3 = GREEN
			button:SetAttribute("WorldColor", colorType)
			setGuiEnabled(button, true)
			bindWorldButton(button)
		end
	elseif canUnlock then
		setText(card, "Requirement", "Unlock for " .. formatNumber(cost) .. " Coins.")
		setStatus(status, "READY", GOLD, TEXT_DARK)
		setStroke(card, GOLD, 3)
		if button then
			button.Text = "UNLOCK"
			button.BackgroundColor3 = GREEN
			button:SetAttribute("WorldColor", colorType)
			setGuiEnabled(button, true)
			bindWorldButton(button)
		end
	else
		setText(card, "Requirement", "Need " .. formatNumber(cost) .. " Coins.")
		setStatus(status, "LOCKED", LOCKED_RED)
		setStroke(card, OUTLINE, 2)
		if button then
			button.Text = "LOCKED"
			button.BackgroundColor3 = DISABLED
			button:SetAttribute("WorldColor", colorType)
			setGuiEnabled(button, false)
			bindWorldButton(button)
		end
	end
end

local function requestTeleport(button)
	local locationId = button:GetAttribute("LocationId")
	if not locationId or locationId == "" then
		return
	end
	if requestTravelToLocationEvent and requestTravelToLocationEvent:IsA("RemoteEvent") then
		requestTravelToLocationEvent:FireServer(locationId)
	end
end

local function bindTeleportButton(button)
	if not button or button:GetAttribute("EditableTeleportButtonBound") == true then
		return
	end
	button:SetAttribute("EditableTeleportButtonBound", true)
	button.Activated:Connect(function()
		requestTeleport(button)
	end)
end

local function updateTeleportCard(locationId, config)
	local card = content:FindFirstChild(tostring(locationId) .. "TeleportCard", true)
	if not card or not card:IsA("GuiObject") then
		return
	end

	local currentWorld = getCurrentWorld()
	if config.worldColor and config.worldColor ~= currentWorld then
		card.Visible = false
		card.Size = UDim2.fromOffset(0, 0)
		return false
	end

	local unlockedColors = getUnlockedColorSet()
	local unlockedTeleports = getUnlockedTeleportSet()
	local requiredColorReady = not config.requiredColor or unlockedColors[config.requiredColor] == true
	local teleportReady = config.alwaysUnlocked
		or not config.requiresTeleportUnlock
		or unlockedTeleports[locationId] == true
	local ready = requiredColorReady and teleportReady
	local button = findButton(card, "TeleportButton")
	local status = findText(card, "Status")

	if not ready then
		card.Visible = false
		card.Size = UDim2.fromOffset(0, 0)
		if button then
			setGuiEnabled(button, false)
		end
		return false
	end

	card.Visible = true
	card.Size = UDim2.fromOffset(358, 118)
	setStatus(status, config.statusWhenReady or "READY", GREEN)
	setStroke(card, GREEN, 3)
	if button then
		button.Text = "GO"
		button.BackgroundColor3 = GREEN
		button:SetAttribute("LocationId", locationId)
		setGuiEnabled(button, true)
		bindTeleportButton(button)
	end

	return true
end

local function updateTeleportCards()
	local visibleCount = 0
	for locationId, config in pairs(TELEPORTS) do
		if updateTeleportCard(locationId, config) then
			visibleCount += 1
		end
	end

	local grid = content:FindFirstChild("TeleportGrid", true)
	if grid and grid:IsA("ScrollingFrame") then
		local rows = math.max(1, math.ceil(visibleCount / 2))
		grid.CanvasSize = UDim2.fromOffset(0, (rows * 130) + 24)
	end
end

local function updateHeader()
	local header = content:FindFirstChild("HeaderPanel", true)
	local currentWorld = ColorData.getWorldByColor(getCurrentWorld()) or ColorData.Worlds[1]
	local unlocked = getUnlockedColorSet()
	local playableCount = 0
	local unlockedCount = 0
	for _, world in ipairs(ColorData.Worlds or {}) do
		if isWorldPlayable(world) then
			playableCount += 1
			if unlocked[world.primaryColor or world.id] == true then
				unlockedCount += 1
			end
		end
	end

	setText(
		header,
		"CurrentSectorLabel",
		"Current: " .. tostring(currentWorld and (currentWorld.DisplayName or currentWorld.name) or "Start Sector")
	)
	setText(header, "ProgressLabel", tostring(unlockedCount) .. " / " .. tostring(playableCount) .. " sectors unlocked")
	local status = findText(header, "HintLabel")
	if status and statusMessage ~= "" then
		status.Text = statusMessage
		status.TextColor3 = MUTED
	end

	local fill = header and header:FindFirstChild("ProgressFill", true)
	if fill and fill:IsA("GuiObject") then
		fill.Size = UDim2.fromScale(math.clamp(unlockedCount / math.max(playableCount, 1), 0, 1), 1)
	end
end

local function setPageVisible(pageName, visible)
	local page = content:FindFirstChild(pageName)
	if page and page:IsA("GuiObject") then
		page.Visible = visible
	end
end

local function renderTabs()
	local tabs = worldsWindow:FindFirstChild("Tabs", true)
	if not tabs then
		return
	end
	for _, pageName in ipairs({ "Sectors", "Teleports" }) do
		local tab = tabs:FindFirstChild(pageName .. "Tab", true)
		if tab and tab:IsA("GuiButton") then
			local active = activePage == pageName
			tab.BackgroundColor3 = active and CYAN or TAB_INACTIVE
			if tab:IsA("TextButton") then
				tab.TextColor3 = active and Color3.fromRGB(255, 255, 255) or TEXT_DARK
			end
		end
	end
end

local function render()
	local unlocked = getUnlockedColorSet()
	updateSectorCarouselWindow(unlocked)
	updateHeader()
	for _, world in ipairs(ColorData.Worlds or {}) do
		updateWorldCard(world)
	end
	updateTeleportCards()
	setPageVisible("SectorsPage", activePage == "Sectors")
	setPageVisible("TeleportsPage", activePage == "Teleports")
	renderTabs()
end

local function bindTabs()
	local tabs = worldsWindow:FindFirstChild("Tabs", true)
	if not tabs then
		return
	end
	for _, pageName in ipairs({ "Sectors", "Teleports" }) do
		local tab = tabs:FindFirstChild(pageName .. "Tab", true)
		if tab and tab:IsA("GuiButton") and tab:GetAttribute("EditableWorldsTabBound") ~= true then
			tab:SetAttribute("EditableWorldsTabBound", true)
			tab.Activated:Connect(function()
				activePage = pageName
				render()
			end)
		end
	end
end

local function watchValue(value)
	if value and value:IsA("ValueBase") then
		value:GetPropertyChangedSignal("Value"):Connect(render)
	end
end

local colorStorage = player:WaitForChild("ColorStorage", 30)
if colorStorage then
	watchValue(colorStorage:FindFirstChild("UnlockedColors"))
	watchValue(colorStorage:FindFirstChild("CurrentWorld"))
	watchValue(colorStorage:FindFirstChild("UnlockedTeleports"))
	colorStorage.ChildAdded:Connect(function(child)
		if child:IsA("ValueBase") then
			watchValue(child)
			render()
		end
	end)
end

local leaderstats = player:WaitForChild("leaderstats", 30)
local coins = leaderstats and leaderstats:FindFirstChild("Coins")
watchValue(coins)

if unlockAreaEvent and unlockAreaEvent:IsA("RemoteEvent") then
	unlockAreaEvent.OnClientEvent:Connect(function(kind, colorType, message)
		if type(message) == "string" then
			statusMessage = message
		elseif kind == "unlocked" then
			statusMessage = tostring(colorType) .. " Sector unlocked."
		end
		render()
	end)
end

if requestTravelToSectorEvent and requestTravelToSectorEvent:IsA("RemoteEvent") then
	requestTravelToSectorEvent.OnClientEvent:Connect(function(success, _colorType, message)
		statusMessage = tostring(message or (success and "Traveling." or "Travel failed."))
		render()
	end)
end

if travelResultEvent and travelResultEvent:IsA("RemoteEvent") then
	travelResultEvent.OnClientEvent:Connect(function(result)
		if type(result) == "table" then
			statusMessage = tostring(result.Message or "")
		end
		render()
	end)
end

worldsWindow:GetPropertyChangedSignal("Visible"):Connect(function()
	if worldsWindow.Visible then
		render()
		focusCurrentSector()
	end
end)

bindTabs()
render()

print("[EditableWorldsBinder] WorldsWindow bound to existing Studio UI.")
