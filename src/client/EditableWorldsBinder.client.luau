-- Binds the Studio-authored WorldsWindow. This script does not create cards or windows at runtime.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ClientUIRoot = require(ReplicatedStorage:WaitForChild("ClientUIRoot"))
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
local PANEL = Color3.fromRGB(246, 249, 255)

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
		statusWhenLocked = "VISIT FIRST",
		requiredColor = nil,
		requiresTeleportUnlock = true,
		showWhenLocked = true,
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
	return ClientUIRoot.GetRoot(playerGui)
end

local function windowsFolder(main)
	local modal = main and main:FindFirstChild("ModalWindows")
	return modal and (modal:FindFirstChild("Windows") or modal)
end

local main = mainHUD()
local windows = windowsFolder(main)
local worldsWindow = windows and windows:WaitForChild("WorldsWindow", 30)
if not worldsWindow then
	warn("EditableWorldsBinder: missing editable WorldsWindow")
	return
end

local content = worldsWindow:FindFirstChild("Content")
if not content or not content:IsA("GuiObject") then
	content = Instance.new("Frame")
	content.Name = "Content"
	content.Parent = worldsWindow
end
content.Position = UDim2.fromOffset(26, 140)
content.Size = UDim2.new(1, -52, 1, -166)
content.BackgroundColor3 = Color3.fromRGB(246, 249, 255)
content.BorderSizePixel = 0
content.ClipsDescendants = true
content.ZIndex = math.max(content.ZIndex, 1001)

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

local function applyCorner(instance, radius)
	local corner = instance:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 12)
	corner.Parent = instance
	return corner
end

local function applyStroke(instance, color, thickness)
	local stroke = instance:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	stroke.Color = color or OUTLINE
	stroke.Thickness = thickness or 2
	stroke.Parent = instance
	return stroke
end

local function clearGeneratedChildren(parent)
	for _, child in ipairs(parent:GetChildren()) do
		if
			child:IsA("GuiObject")
			or child:IsA("UIListLayout")
			or child:IsA("UIGridLayout")
			or child:IsA("UIPadding")
		then
			child:Destroy()
		end
	end
end

local function makeFrame(parent, name, position, size, color)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Position = position
	frame.Size = size
	frame.BackgroundColor3 = color or Color3.fromRGB(255, 255, 255)
	frame.BorderSizePixel = 0
	frame.ZIndex = 1003
	frame.Parent = parent
	applyCorner(frame, 16)
	applyStroke(frame, OUTLINE, 2)
	return frame
end

local function makeText(parent, name, value, position, size, textSize, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = Enum.Font.GothamBlack
	label.Text = value
	label.TextColor3 = color or TEXT_DARK
	label.TextSize = textSize or 18
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextStrokeTransparency = 1
	label.ZIndex = 1004
	label.Parent = parent
	return label
end

local function makeButton(parent, name, value, position, size, color)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Position = position
	button.Size = size
	button.BackgroundColor3 = color or GREEN
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = Enum.Font.GothamBlack
	button.Text = value
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 18
	button.TextScaled = true
	button.TextStrokeColor3 = OUTLINE
	button.TextStrokeTransparency = 0
	button.ZIndex = 1005
	button.Parent = parent
	applyCorner(button, 12)
	applyStroke(button, OUTLINE, 2)
	return button
end

local function makeScrollingFrame(parent, name, position, size)
	local scrollingFrame = Instance.new("ScrollingFrame")
	scrollingFrame.Name = name
	scrollingFrame.Position = position
	scrollingFrame.Size = size
	scrollingFrame.BackgroundColor3 = Color3.fromRGB(240, 245, 252)
	scrollingFrame.BorderSizePixel = 0
	scrollingFrame.ScrollBarThickness = 8
	scrollingFrame.ScrollBarImageColor3 = MUTED
	scrollingFrame.CanvasSize = UDim2.fromOffset(0, 0)
	scrollingFrame.ZIndex = 1003
	scrollingFrame.Parent = parent
	applyCorner(scrollingFrame, 16)
	applyStroke(scrollingFrame, OUTLINE, 2)
	return scrollingFrame
end

local worldAccent

local function worldIconText(colorType)
	if colorType == "Orange" then
		return "OR"
	elseif colorType == "Rainbow" then
		return "RB"
	elseif colorType == "Neon" then
		return "NE"
	end
	return string.upper(string.sub(tostring(colorType or "??"), 1, 2))
end

local GENERATED_TELEPORTS = {
	{
		id = "OriginSector",
		title = "Origin Spawn",
		description = "Start Sector spawn.",
		icon = "SP",
		color = Color3.fromRGB(245, 76, 76),
	},
	{
		id = "RedWastelands",
		title = "Red Wastelands",
		description = "Main red color field.",
		icon = "RD",
		color = Color3.fromRGB(245, 76, 76),
	},
	{
		id = "ZorkShop",
		title = "Zork Shop",
		description = "Brushes and upgrades.",
		icon = "SH",
		color = Color3.fromRGB(255, 218, 74),
	},
	{
		id = "OrangeSector",
		title = "Orange Sector",
		description = "Orange color field.",
		icon = "OR",
		color = Color3.fromRGB(245, 151, 35),
	},
	{
		id = "GreenSector",
		title = "Green Sector",
		description = "Green color field.",
		icon = "GR",
		color = Color3.fromRGB(84, 225, 112),
	},
	{
		id = "InsidePipes",
		title = "The Pipes",
		description = "Hidden pipe zone.",
		icon = "PI",
		color = Color3.fromRGB(76, 214, 224),
	},
}

local function makeTabs()
	local tabs = worldsWindow:FindFirstChild("Tabs")
	if tabs and tabs:IsA("GuiObject") then
		clearGeneratedChildren(tabs)
	else
		tabs = makeFrame(
			worldsWindow,
			"Tabs",
			UDim2.fromOffset(26, 78),
			UDim2.new(1, -52, 0, 50),
			Color3.fromRGB(255, 255, 255)
		)
	end
	tabs.BackgroundTransparency = 1
	tabs.ZIndex = 1002
	local stroke = tabs:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke:Destroy()
	end

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = tabs

	for index, pageName in ipairs({ "Sectors", "Teleports" }) do
		local tab = makeButton(
			tabs,
			pageName .. "Tab",
			pageName,
			UDim2.fromScale(0, 0),
			UDim2.fromOffset(180, 38),
			index == 1 and CYAN or TAB_INACTIVE
		)
		tab.LayoutOrder = index
		tab.TextColor3 = index == 1 and Color3.fromRGB(255, 255, 255) or TEXT_DARK
		tab.TextStrokeTransparency = index == 1 and 0 or 1
	end
end

local function makeHeader(parent)
	local header = makeFrame(
		parent,
		"HeaderPanel",
		UDim2.fromOffset(14, 12),
		UDim2.new(1, -28, 0, 92),
		Color3.fromRGB(230, 250, 255)
	)
	applyStroke(header, OUTLINE, 3)
	makeText(
		header,
		"CurrentSectorLabel",
		"Current: Start Sector",
		UDim2.fromOffset(20, 10),
		UDim2.new(0.48, 0, 0, 30),
		22
	)
	local hint = makeText(
		header,
		"HintLabel",
		"Pick your Sector, then jump to unlocked locations.",
		UDim2.fromOffset(20, 44),
		UDim2.new(0.58, 0, 0, 28),
		13,
		MUTED
	)
	hint.Font = Enum.Font.GothamBold
	local progress = makeText(
		header,
		"ProgressLabel",
		"1 / 2 sectors unlocked",
		UDim2.new(1, -244, 0, 12),
		UDim2.fromOffset(220, 26),
		18
	)
	progress.TextXAlignment = Enum.TextXAlignment.Right

	local track = makeFrame(
		header,
		"ProgressTrack",
		UDim2.new(1, -244, 0, 54),
		UDim2.fromOffset(220, 18),
		Color3.fromRGB(211, 221, 236)
	)
	applyCorner(track, 999)
	local trackStroke = track:FindFirstChildOfClass("UIStroke")
	if trackStroke then
		trackStroke:Destroy()
	end
	local fill = makeFrame(track, "ProgressFill", UDim2.fromScale(0, 0), UDim2.fromScale(0.5, 1), GREEN)
	applyCorner(fill, 999)
	local fillStroke = fill:FindFirstChildOfClass("UIStroke")
	if fillStroke then
		fillStroke:Destroy()
	end
end

local function makeWorldCard(parent, world)
	local colorType = world.primaryColor or world.id
	local accent = worldAccent(colorType)
	local worldIndex = tonumber(world.WorldIndex or ColorData.getWorldIndex(colorType)) or 1
	local card = makeFrame(
		parent,
		tostring(colorType) .. "SectorCard",
		UDim2.fromScale(0, 0),
		UDim2.fromOffset(744, 206),
		Color3.fromRGB(255, 255, 255)
	)
	card:SetAttribute("WorldColor", colorType)
	card.LayoutOrder = worldIndex

	local accentBand = makeFrame(card, "AccentBand", UDim2.fromScale(0, 0), UDim2.new(0, 16, 1, 0), accent)
	local accentStroke = accentBand:FindFirstChildOfClass("UIStroke")
	if accentStroke then
		accentStroke:Destroy()
	end

	local icon = makeFrame(
		card,
		"IconCircle",
		UDim2.fromOffset(34, 34),
		UDim2.fromOffset(118, 118),
		accent:Lerp(Color3.fromRGB(255, 255, 255), 0.18)
	)
	applyCorner(icon, 24)
	applyStroke(icon, OUTLINE, 3)
	local iconText = makeText(
		icon,
		"IconText",
		worldIconText(colorType),
		UDim2.fromScale(0, 0),
		UDim2.fromScale(1, 1),
		42,
		Color3.fromRGB(255, 255, 255)
	)
	iconText.TextXAlignment = Enum.TextXAlignment.Center
	iconText.TextScaled = true
	iconText.TextStrokeColor3 = OUTLINE
	iconText.TextStrokeTransparency = 0

	makeText(
		card,
		"Name",
		tostring(world.DisplayName or world.name or colorType),
		UDim2.fromOffset(178, 24),
		UDim2.new(1, -332, 0, 40),
		28
	)
	local meta = makeText(
		card,
		"Meta",
		"Power x" .. tostring(world.rewardMultiplier or 1) .. " | " .. tostring(#(world.EggIds or {})) .. " eggs",
		UDim2.fromOffset(180, 68),
		UDim2.new(1, -360, 0, 24),
		15,
		MUTED
	)
	meta.Font = Enum.Font.GothamBold
	local requirement = makeText(
		card,
		"Requirement",
		"Unlock for " .. formatNumber(world.UnlockCost or world.unlockCost or 0) .. " Coins.",
		UDim2.fromOffset(180, 98),
		UDim2.new(1, -360, 0, 26),
		15,
		MUTED
	)
	requirement.Font = Enum.Font.GothamBold
	local status =
		makeText(card, "Status", "LOCKED", UDim2.fromOffset(180, 134), UDim2.fromOffset(142, 30), 14, TEXT_DARK)
	status.BackgroundTransparency = 0
	status.BackgroundColor3 = TAB_INACTIVE
	status.TextXAlignment = Enum.TextXAlignment.Center
	status.TextScaled = true
	applyCorner(status, 999)
	applyStroke(status, OUTLINE, 2)

	local action =
		makeButton(card, "TeleportButton", "UNLOCK", UDim2.new(1, -190, 0.5, -26), UDim2.fromOffset(160, 52), GREEN)
	action:SetAttribute("WorldColor", colorType)
end

local function makeSectorsPage()
	local page = makeFrame(content, "SectorsPage", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), PANEL)
	page.BackgroundTransparency = 1
	local pageStroke = page:FindFirstChildOfClass("UIStroke")
	if pageStroke then
		pageStroke:Destroy()
	end
	makeHeader(page)

	local carousel = makeScrollingFrame(page, "SectorCarousel", UDim2.fromOffset(14, 116), UDim2.new(1, -28, 1, -130))
	carousel:SetAttribute("CardStep", 768)
	carousel.ScrollingDirection = Enum.ScrollingDirection.X
	carousel.CanvasSize = UDim2.fromOffset((#(ColorData.Worlds or {}) * 768) + 36, 0)

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 14)
	padding.PaddingBottom = UDim.new(0, 14)
	padding.PaddingLeft = UDim.new(0, 18)
	padding.PaddingRight = UDim.new(0, 18)
	padding.Parent = carousel

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 24)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = carousel

	for _, world in ipairs(ColorData.Worlds or {}) do
		makeWorldCard(carousel, world)
	end
end

local function makeTeleportCard(parent, teleport, layoutOrder)
	local card = makeFrame(
		parent,
		tostring(teleport.id) .. "TeleportCard",
		UDim2.fromScale(0, 0),
		UDim2.fromOffset(358, 118),
		Color3.fromRGB(255, 255, 255)
	)
	card:SetAttribute("LocationId", teleport.id)
	card.LayoutOrder = layoutOrder
	local icon = makeFrame(
		card,
		"IconCircle",
		UDim2.fromOffset(12, 14),
		UDim2.fromOffset(64, 64),
		teleport.color:Lerp(Color3.fromRGB(255, 255, 255), 0.16)
	)
	applyCorner(icon, 16)
	applyStroke(icon, OUTLINE, 2)
	local iconText = makeText(
		icon,
		"IconText",
		teleport.icon,
		UDim2.fromScale(0, 0),
		UDim2.fromScale(1, 1),
		20,
		Color3.fromRGB(255, 255, 255)
	)
	iconText.TextXAlignment = Enum.TextXAlignment.Center
	iconText.TextScaled = true
	iconText.TextStrokeColor3 = OUTLINE
	iconText.TextStrokeTransparency = 0
	makeText(card, "Name", teleport.title, UDim2.fromOffset(88, 10), UDim2.new(1, -104, 0, 28), 18)
	local description = makeText(
		card,
		"Description",
		teleport.description,
		UDim2.fromOffset(88, 40),
		UDim2.new(1, -104, 0, 34),
		12,
		MUTED
	)
	description.Font = Enum.Font.GothamBold
	local status =
		makeText(card, "Status", "LOCKED", UDim2.fromOffset(12, 84), UDim2.fromOffset(112, 24), 12, TEXT_DARK)
	status.BackgroundTransparency = 0
	status.BackgroundColor3 = TAB_INACTIVE
	status.TextXAlignment = Enum.TextXAlignment.Center
	status.TextScaled = true
	applyCorner(status, 999)
	applyStroke(status, OUTLINE, 2)
	local action =
		makeButton(card, "TeleportButton", "GO", UDim2.new(1, -122, 1, -36), UDim2.fromOffset(108, 28), GREEN)
	action:SetAttribute("LocationId", teleport.id)
end

local function makeTeleportsPage()
	local page = makeFrame(content, "TeleportsPage", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), PANEL)
	page.BackgroundTransparency = 1
	page.Visible = false
	local pageStroke = page:FindFirstChildOfClass("UIStroke")
	if pageStroke then
		pageStroke:Destroy()
	end
	local header = makeFrame(
		page,
		"HeaderPanel",
		UDim2.fromOffset(14, 12),
		UDim2.new(1, -28, 0, 76),
		Color3.fromRGB(248, 252, 255)
	)
	applyStroke(header, OUTLINE, 3)
	makeText(header, "HeaderTitle", "FAST TRAVEL", UDim2.fromOffset(20, 10), UDim2.new(0.42, 0, 0, 30), 24)
	local subtitle = makeText(
		header,
		"HeaderSubtitle",
		"Unlocked locations for your current Sector.",
		UDim2.fromOffset(20, 42),
		UDim2.new(0.75, 0, 0, 22),
		13,
		MUTED
	)
	subtitle.Font = Enum.Font.GothamBold

	local grid = makeScrollingFrame(page, "TeleportGrid", UDim2.fromOffset(14, 100), UDim2.new(1, -28, 1, -114))
	grid.CanvasSize = UDim2.fromOffset(0, 420)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = grid
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(358, 118)
	layout.CellPadding = UDim2.fromOffset(12, 12)
	layout.FillDirectionMaxCells = 2
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	for index, teleport in ipairs(GENERATED_TELEPORTS) do
		makeTeleportCard(grid, teleport, index)
	end
end

local function ensureWorldsLayout()
	if content:FindFirstChild("SectorCarousel", true) and content:FindFirstChild("TeleportGrid", true) then
		return
	end

	worldsWindow.AnchorPoint = Vector2.new(0.5, 0.5)
	worldsWindow.Position = UDim2.fromScale(0.5, 0.46)
	worldsWindow.Size = UDim2.fromOffset(860, 540)
	worldsWindow.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	worldsWindow.BorderSizePixel = 0
	worldsWindow.ClipsDescendants = false
	applyCorner(worldsWindow, 24)
	applyStroke(worldsWindow, OUTLINE, 4)

	local title = findText(worldsWindow, "Title")
		or makeText(worldsWindow, "Title", "SECTOR SELECT", UDim2.fromOffset(28, 16), UDim2.new(1, -124, 0, 46), 32)
	title.Text = "SECTOR SELECT"
	title.TextSize = 32
	title.TextScaled = true
	title.ZIndex = 1002

	clearGeneratedChildren(content)
	makeTabs()
	makeSectorsPage()
	makeTeleportsPage()
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
	local set = { OriginSector = true, RedWastelands = true }
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

function worldAccent(colorType)
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
		if config.showWhenLocked and requiredColorReady then
			card.Visible = true
			card.Size = UDim2.fromOffset(358, 118)
			setStatus(status, config.statusWhenLocked or "LOCKED", LOCKED_RED)
			setStroke(card, DISABLED, 2)
			if button then
				button.Text = "LOCKED"
				button.BackgroundColor3 = DISABLED
				button:SetAttribute("LocationId", locationId)
				setGuiEnabled(button, false)
			end
			return true
		end
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

ensureWorldsLayout()

worldsWindow:GetPropertyChangedSignal("Visible"):Connect(function()
	if worldsWindow.Visible then
		render()
		focusCurrentSector()
	end
end)

bindTabs()
render()

print("[EditableWorldsBinder] WorldsWindow bound to existing Studio UI.")
