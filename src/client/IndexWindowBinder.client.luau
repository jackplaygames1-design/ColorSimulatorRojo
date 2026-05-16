-- Binds the editable Collection Index window to discovered colors, gear, and places.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ClientUIRoot = require(ReplicatedStorage:WaitForChild("ClientUIRoot"))
local ColorData = require(ReplicatedStorage:WaitForChild("ColorData"))
local GameBalance = require(ReplicatedStorage:WaitForChild("GameBalance"))
local PetData = require(ReplicatedStorage:WaitForChild("PetData"))
local ToolData = require(ReplicatedStorage:WaitForChild("ToolData"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local inventoryRequest = remotes:WaitForChild("InventoryRequest")
local inventoryAction = remotes:WaitForChild("InventoryAction")
local events = ReplicatedStorage:WaitForChild("Events")
local hatchEvent = events:WaitForChild("HatchEgg")
local petsLoadedEvent = events:WaitForChild("PetsLoaded")

local OUTLINE = Color3.fromRGB(35, 38, 45)
local TEXT_DARK = Color3.fromRGB(38, 36, 52)
local MUTED = Color3.fromRGB(92, 98, 116)
local BLUE = Color3.fromRGB(86, 218, 241)
local GREEN = Color3.fromRGB(90, 230, 72)
local RED = Color3.fromRGB(236, 43, 62)
local CARD = Color3.fromRGB(255, 255, 255)
local LOCKED_CARD = Color3.fromRGB(236, 240, 248)
local PAGE_SIZE = 24

local RARITY_COLORS = {
	Common = Color3.fromRGB(168, 184, 202),
	Uncommon = Color3.fromRGB(85, 214, 112),
	Rare = Color3.fromRGB(70, 160, 255),
	Epic = Color3.fromRGB(176, 104, 255),
	Legendary = Color3.fromRGB(255, 194, 55),
	Secret = Color3.fromRGB(255, 92, 210),
	Brush = Color3.fromRGB(91, 218, 241),
}

local CATEGORY_LABELS = {
	Pets = "Pets",
	Gear = "Gear",
	Places = "Places",
}

local FILTER_LABELS = {
	All = "ALL",
	Found = "OWNED",
	Missing = "???",
}

local currentCategory = "Pets"
local currentFilter = "All"
local currentPage = 1
local currentSearch = ""
local inventoryData = { Colors = {}, Brushes = {}, Potions = {}, Items = {} }
local inventoryLoading = false
local pendingRefresh = false
local connectionsBound = false
local lastPressAt = {}

local mainHud = ClientUIRoot.GetRoot(playerGui)
if not mainHud then
	warn("IndexWindowBinder: missing MainHUD")
	return
end

local modalRoot = mainHud:FindFirstChild("ModalWindows")
if not modalRoot then
	modalRoot = Instance.new("Folder")
	modalRoot.Name = "ModalWindows"
	modalRoot.Parent = mainHud
end
local modalWindows = modalRoot:FindFirstChild("Windows") or modalRoot

local indexWindow
local ui = {}
local cardSlots = {}

local function formatNumber(value)
	if GameBalance and GameBalance.formatNumber then
		return GameBalance.formatNumber(value)
	end
	value = tonumber(value) or 0
	if value >= 1000000 then
		return string.format("%.1fM", value / 1000000):gsub("%.0M", "M")
	elseif value >= 1000 then
		return string.format("%.1fK", value / 1000):gsub("%.0K", "K")
	end
	return tostring(math.floor(value))
end

local function splitCsv(value)
	local out = {}
	for _, item in ipairs(string.split(tostring(value or ""), ",")) do
		if item ~= "" then
			out[item] = true
		end
	end
	return out
end

local function playUI(soundName)
	local soundEvent = ReplicatedStorage:FindFirstChild("ColorSimulatorPlaySound")
	if soundEvent and soundEvent:IsA("BindableEvent") then
		soundEvent:Fire("UI", soundName)
	end
end

local function debounce(key)
	local now = os.clock()
	if lastPressAt[key] and now - lastPressAt[key] < 0.12 then
		return false
	end
	lastPressAt[key] = now
	return true
end

local function applyCorner(instance, radius)
	local corner = instance:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 16)
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

local function ensureClass(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA(className) then
		return existing
	end
	if existing then
		if existing:IsA("GuiObject") then
			existing.Visible = false
		end
		existing.Name = name .. "_Legacy"
	end
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance
end

local function markEditable(object, role)
	if object then
		object:SetAttribute("EditableIndexUI", true)
		if role and role ~= "" then
			object:SetAttribute("IndexUIRole", role)
		end
	end
	return object
end

local function text(parent, name, value, position, size, textSize, alignment)
	local label = ensureClass(parent, "TextLabel", name)
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = Enum.Font.GothamBlack
	label.Text = value
	label.TextColor3 = TEXT_DARK
	label.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.35
	label.TextSize = textSize or 18
	label.TextWrapped = true
	label.TextXAlignment = alignment or Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	markEditable(label, name)
	return label
end

local function button(parent, name, value, position, size, color)
	local btn = ensureClass(parent, "TextButton", name)
	btn.AutoButtonColor = true
	btn.BorderSizePixel = 0
	btn.Position = position
	btn.Size = size
	btn.BackgroundColor3 = color or BLUE
	btn.Font = Enum.Font.GothamBlack
	btn.Text = value
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.TextStrokeColor3 = OUTLINE
	btn.TextStrokeTransparency = 0
	btn.TextWrapped = true
	applyCorner(btn, 12)
	applyStroke(btn, OUTLINE, 2)
	markEditable(btn, name)
	return btn
end

local function panel(parent, name, position, size, color, radius, strokeThickness)
	local frame = ensureClass(parent, "Frame", name)
	frame.BorderSizePixel = 0
	frame.Position = position
	frame.Size = size
	frame.BackgroundColor3 = color or CARD
	applyCorner(frame, radius or 16)
	applyStroke(frame, OUTLINE, strokeThickness or 2)
	markEditable(frame, name)
	return frame
end

local function textbox(parent, name, placeholder, position, size)
	local box = ensureClass(parent, "TextBox", name)
	box.ClearTextOnFocus = false
	box.Font = Enum.Font.GothamBlack
	box.PlaceholderText = placeholder
	box.PlaceholderColor3 = Color3.fromRGB(130, 138, 158)
	box.Text = box.Text or ""
	box.TextColor3 = TEXT_DARK
	box.TextSize = 22
	box.TextXAlignment = Enum.TextXAlignment.Center
	box.BackgroundColor3 = CARD
	box.BorderSizePixel = 0
	box.Position = position
	box.Size = size
	applyCorner(box, 16)
	applyStroke(box, OUTLINE, 3)
	markEditable(box, name)
	return box
end

local function makeCard(parent, name, order)
	local card = button(parent, name, "", UDim2.fromOffset(0, 0), UDim2.fromOffset(126, 126), CARD)
	card.Text = ""
	card.LayoutOrder = order
	card.ClipsDescendants = true
	card:SetAttribute("IndexCardSlot", true)

	local shadow = panel(card, "IconShadow", UDim2.fromScale(0.18, 0.64), UDim2.fromScale(0.64, 0.14), OUTLINE, 999, 0)
	shadow.BackgroundTransparency = 0.82

	local icon = panel(card, "IconFrame", UDim2.fromScale(0.16, 0.08), UDim2.fromScale(0.68, 0.58), BLUE, 14, 3)
	icon.ZIndex = card.ZIndex + 2
	local iconText = text(
		icon,
		"IconText",
		"??",
		UDim2.fromScale(0.05, 0.05),
		UDim2.fromScale(0.9, 0.9),
		30,
		Enum.TextXAlignment.Center
	)
	iconText.TextYAlignment = Enum.TextYAlignment.Center
	iconText.TextColor3 = Color3.fromRGB(255, 255, 255)
	iconText.TextStrokeColor3 = OUTLINE
	iconText.TextStrokeTransparency = 0
	iconText.ZIndex = icon.ZIndex + 1

	local lockOverlay =
		panel(icon, "LockOverlay", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), Color3.fromRGB(32, 37, 48), 14, 0)
	lockOverlay.BackgroundTransparency = 0.32
	lockOverlay.ZIndex = icon.ZIndex + 2
	local lockText =
		text(lockOverlay, "LockText", "?", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 32, Enum.TextXAlignment.Center)
	lockText.TextYAlignment = Enum.TextYAlignment.Center
	lockText.TextColor3 = Color3.fromRGB(255, 255, 255)
	lockText.ZIndex = lockOverlay.ZIndex + 1

	local nameLabel = text(
		card,
		"NameLabel",
		"???",
		UDim2.fromScale(0.08, 0.69),
		UDim2.fromScale(0.84, 0.14),
		15,
		Enum.TextXAlignment.Center
	)
	nameLabel.TextScaled = true
	local nameLimit = nameLabel:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
	nameLimit.MinTextSize = 9
	nameLimit.MaxTextSize = 15
	nameLimit.Parent = nameLabel

	local status = text(
		card,
		"StatusLabel",
		"Not Found",
		UDim2.fromScale(0.08, 0.84),
		UDim2.fromScale(0.84, 0.12),
		12,
		Enum.TextXAlignment.Center
	)
	status.TextColor3 = MUTED
	status.TextScaled = true
	local statusLimit = status:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
	statusLimit.MinTextSize = 8
	statusLimit.MaxTextSize = 12
	statusLimit.Parent = status

	local badge = panel(card, "CollectedBadge", UDim2.fromScale(0.56, 0.07), UDim2.fromScale(0.34, 0.16), GREEN, 10, 2)
	badge.ZIndex = card.ZIndex + 4
	local badgeText =
		text(badge, "BadgeText", "OWNED", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 10, Enum.TextXAlignment.Center)
	badgeText.TextYAlignment = Enum.TextYAlignment.Center
	badgeText.TextColor3 = Color3.fromRGB(255, 255, 255)
	badgeText.TextStrokeColor3 = OUTLINE
	badgeText.TextStrokeTransparency = 0.25
	badgeText.ZIndex = badge.ZIndex + 1

	return card
end

local function createRuntimeWindow()
	local window = panel(
		modalWindows,
		"IndexWindow",
		UDim2.fromScale(0.5, 0.47),
		UDim2.fromScale(0.76, 0.72),
		Color3.fromRGB(240, 249, 255),
		28,
		5
	)
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Visible = false
	window.ClipsDescendants = false
	window:SetAttribute("ResponsiveWindow", true)
	window:SetAttribute("EditableIndexUI", true)
	window:SetAttribute("OpenedByIndexStation", true)
	window:SetAttribute("DesktopWidthScale", 0.76)
	window:SetAttribute("DesktopHeightScale", 0.72)
	local scale = window:FindFirstChild("ResponsiveScale") or Instance.new("UIScale")
	scale.Name = "ResponsiveScale"
	scale.Parent = window

	local title = text(
		window,
		"Title",
		"COLLECTION!",
		UDim2.fromScale(0.05, -0.11),
		UDim2.fromScale(0.9, 0.14),
		50,
		Enum.TextXAlignment.Center
	)
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextStrokeColor3 = OUTLINE
	title.TextStrokeTransparency = 0

	local close = button(window, "CloseButton", "X", UDim2.new(1, -78, 0, -42), UDim2.fromOffset(70, 70), RED)
	close.TextSize = 48
	close:SetAttribute("NoTextGlow", true)

	local content = panel(
		window,
		"Content",
		UDim2.fromScale(0.03, 0.06),
		UDim2.fromScale(0.94, 0.88),
		Color3.fromRGB(252, 254, 255),
		22,
		2
	)
	content.ClipsDescendants = false

	local badge = panel(
		content,
		"CollectionBadge",
		UDim2.fromScale(0.02, -0.055),
		UDim2.fromScale(0.095, 0.145),
		Color3.fromRGB(221, 251, 255),
		16,
		4
	)
	badge.Rotation = -8
	badge.ZIndex = content.ZIndex + 4
	local badgeIcon = text(
		badge,
		"BadgeIcon",
		"IX",
		UDim2.fromScale(0.06, 0.06),
		UDim2.fromScale(0.88, 0.88),
		32,
		Enum.TextXAlignment.Center
	)
	badgeIcon.TextYAlignment = Enum.TextYAlignment.Center
	badgeIcon.TextColor3 = Color3.fromRGB(44, 165, 255)
	badgeIcon.ZIndex = badge.ZIndex + 1

	local sidebar = panel(
		content,
		"CategoryTabs",
		UDim2.fromScale(0.025, 0.12),
		UDim2.fromScale(0.24, 0.64),
		Color3.fromRGB(247, 250, 255),
		16,
		2
	)
	sidebar.BackgroundTransparency = 1
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.Name = "CategoryTabLayout"
	tabLayout.FillDirection = Enum.FillDirection.Vertical
	tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	tabLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	tabLayout.Padding = UDim.new(0, 10)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = sidebar
	for order, tabInfo in ipairs({
		{ "PetsTab", "Pets", "Pets" },
		{ "GearTab", "Gear", "Gear" },
		{ "PlacesTab", "Places", "Places" },
	}) do
		local tab = button(
			sidebar,
			tabInfo[1],
			tabInfo[2],
			UDim2.fromOffset(0, 0),
			UDim2.new(1, -16, 0, 58),
			order == 1 and BLUE or Color3.fromRGB(232, 237, 248)
		)
		tab.LayoutOrder = order
		tab.TextSize = 25
		tab.TextColor3 = order == 1 and Color3.fromRGB(255, 255, 255) or TEXT_DARK
		tab:SetAttribute("IndexCategory", tabInfo[3])
	end

	local rewards = content:FindFirstChild("RewardsButton")
	if rewards and rewards:IsA("GuiObject") then
		rewards.Visible = false
		rewards:SetAttribute("IndexCategory", nil)
	end

	local topFilters =
		panel(content, "TopFilters", UDim2.fromScale(0.34, 0.035), UDim2.fromScale(0.32, 0.075), CARD, 20, 3)
	topFilters.ClipsDescendants = true
	local filterLayout = Instance.new("UIListLayout")
	filterLayout.Name = "FilterLayout"
	filterLayout.FillDirection = Enum.FillDirection.Horizontal
	filterLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	filterLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	filterLayout.Padding = UDim.new(0, 8)
	filterLayout.SortOrder = Enum.SortOrder.LayoutOrder
	filterLayout.Parent = topFilters
	for order, filterInfo in ipairs({
		{ "AllFilter", "ALL", "All" },
		{ "FoundFilter", "OWNED", "Found" },
		{ "MissingFilter", "???", "Missing" },
	}) do
		local filter = button(
			topFilters,
			filterInfo[1],
			filterInfo[2],
			UDim2.fromOffset(0, 0),
			UDim2.fromOffset(92, 38),
			order == 1 and BLUE or CARD
		)
		filter.LayoutOrder = order
		filter.TextSize = 16
		filter.TextColor3 = order == 1 and Color3.fromRGB(255, 255, 255) or TEXT_DARK
		filter:SetAttribute("IndexFilter", filterInfo[3])
	end

	textbox(content, "SearchBox", "Search", UDim2.fromScale(0.69, 0.035), UDim2.fromScale(0.25, 0.075))

	local grid = ensureClass(content, "ScrollingFrame", "GridPanel")
	grid.Position = UDim2.fromScale(0.29, 0.14)
	grid.Size = UDim2.fromScale(0.67, 0.7)
	grid.BackgroundColor3 = CARD
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 7
	grid.ScrollBarImageColor3 = Color3.fromRGB(110, 120, 145)
	grid.ScrollingDirection = Enum.ScrollingDirection.Y
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.fromOffset(0, 0)
	grid.ClipsDescendants = true
	applyCorner(grid, 18)
	markEditable(grid, "GridPanel")
	local gridPadding = Instance.new("UIPadding")
	gridPadding.Name = "GridPadding"
	gridPadding.PaddingTop = UDim.new(0, 12)
	gridPadding.PaddingBottom = UDim.new(0, 20)
	gridPadding.PaddingLeft = UDim.new(0, 12)
	gridPadding.PaddingRight = UDim.new(0, 12)
	gridPadding.Parent = grid
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.Name = "IndexGridLayout"
	gridLayout.CellSize = UDim2.fromOffset(126, 126)
	gridLayout.CellPadding = UDim2.fromOffset(20, 18)
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid
	local template = makeCard(grid, "IndexCardTemplate", 0)
	template.Visible = false
	for index = 1, 48 do
		local slot = makeCard(grid, "IndexSlot" .. tostring(index), index)
		slot.Visible = false
	end

	local emptyText = text(
		content,
		"EmptyText",
		"Nothing found.",
		UDim2.fromScale(0.32, 0.43),
		UDim2.fromScale(0.58, 0.08),
		24,
		Enum.TextXAlignment.Center
	)
	emptyText.Visible = false

	local footer = panel(content, "PageControls", UDim2.fromScale(0.47, 0.86), UDim2.fromScale(0.22, 0.08), CARD, 18, 3)
	local pageBack = button(
		footer,
		"PageBack",
		"<",
		UDim2.fromScale(0.03, 0.12),
		UDim2.fromScale(0.22, 0.76),
		Color3.fromRGB(232, 237, 248)
	)
	pageBack.TextColor3 = TEXT_DARK
	pageBack.TextSize = 26
	local pageLabel = text(
		footer,
		"PageLabel",
		"1",
		UDim2.fromScale(0.28, 0),
		UDim2.fromScale(0.44, 1),
		24,
		Enum.TextXAlignment.Center
	)
	pageLabel.TextYAlignment = Enum.TextYAlignment.Center
	local pageNext = button(
		footer,
		"PageNext",
		">",
		UDim2.fromScale(0.75, 0.12),
		UDim2.fromScale(0.22, 0.76),
		Color3.fromRGB(232, 237, 248)
	)
	pageNext.TextColor3 = TEXT_DARK
	pageNext.TextSize = 26

	local counter = text(
		content,
		"CollectedCounter",
		"0/0",
		UDim2.fromScale(0.76, 0.845),
		UDim2.fromScale(0.2, 0.095),
		38,
		Enum.TextXAlignment.Center
	)
	counter.TextColor3 = Color3.fromRGB(63, 214, 245)
	counter.TextStrokeColor3 = OUTLINE
	counter.TextStrokeTransparency = 0
	local counterLabel = text(
		content,
		"CollectedLabel",
		"Collected",
		UDim2.fromScale(0.76, 0.795),
		UDim2.fromScale(0.2, 0.045),
		21,
		Enum.TextXAlignment.Center
	)
	counterLabel.TextYAlignment = Enum.TextYAlignment.Center

	return window
end

local function getIndexWindow()
	indexWindow = modalWindows:FindFirstChild("IndexWindow")
	if not indexWindow then
		indexWindow = createRuntimeWindow()
	end
	return indexWindow
end

local function findDescendant(root, name)
	return root and root:FindFirstChild(name, true)
end

local function collectUi()
	local window = getIndexWindow()
	if not window or not window:IsA("GuiObject") then
		return false
	end

	ui.window = window
	ui.content = findDescendant(window, "Content")
	ui.categoryTabs = findDescendant(window, "CategoryTabs")
	ui.topFilters = findDescendant(window, "TopFilters")
	ui.searchBox = findDescendant(window, "SearchBox")
	ui.gridPanel = findDescendant(window, "GridPanel")
	ui.emptyText = findDescendant(window, "EmptyText")
	ui.pageBack = findDescendant(window, "PageBack")
	ui.pageNext = findDescendant(window, "PageNext")
	ui.pageLabel = findDescendant(window, "PageLabel")
	ui.collectedCounter = findDescendant(window, "CollectedCounter")
	ui.closeButton = findDescendant(window, "CloseButton")

	table.clear(cardSlots)
	if ui.gridPanel then
		for _, child in ipairs(ui.gridPanel:GetChildren()) do
			if
				child:IsA("GuiObject")
				and child:GetAttribute("IndexCardSlot") == true
				and child.Name ~= "IndexCardTemplate"
			then
				table.insert(cardSlots, child)
			end
		end
		table.sort(cardSlots, function(a, b)
			if a.LayoutOrder ~= b.LayoutOrder then
				return a.LayoutOrder < b.LayoutOrder
			end
			return a.Name < b.Name
		end)
	end

	return true
end

local function setText(object, value)
	if object and (object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox")) then
		object.Text = tostring(value or "")
	end
end

local function setCardText(card, childName, value)
	setText(findDescendant(card, childName), value)
end

local function setButtonVisual(buttonObject, selected, selectedColor)
	if not buttonObject or not buttonObject:IsA("GuiObject") then
		return
	end
	buttonObject.BackgroundColor3 = selected and (selectedColor or BLUE) or CARD
	if buttonObject:IsA("TextButton") then
		buttonObject.TextColor3 = selected and Color3.fromRGB(255, 255, 255) or TEXT_DARK
		buttonObject.AutoButtonColor = not selected
	end
end

local function firstLetters(value, fallback)
	value = tostring(value or "")
	local words = {}
	for word in string.gmatch(value, "%w+") do
		table.insert(words, word)
		if #words >= 2 then
			break
		end
	end
	if #words >= 2 then
		return string.upper(string.sub(words[1], 1, 1) .. string.sub(words[2], 1, 1))
	elseif #words == 1 then
		return string.upper(string.sub(words[1], 1, 2))
	end
	return fallback or "??"
end

local function addUniquePet(entries, seen, petId, order)
	petId = tostring(petId or "")
	if petId == "" or seen[petId] then
		return
	end
	local pet = PetData.Pets[petId]
	if not pet then
		return
	end
	seen[petId] = true
	table.insert(entries, {
		id = petId,
		category = "Pets",
		name = pet.displayName or petId,
		meta = pet.rarity or "Color",
		iconText = firstLetters(pet.displayName or petId, "CO"),
		color = pet.cardColor or pet.accentColor or pet.iconColor or pet.color or RARITY_COLORS[pet.rarity or "Common"],
		rarity = pet.rarity or "Common",
		sortOrder = order or 9999,
	})
end

local function getIndexValue(name)
	local folder = player:FindFirstChild("IndexData")
	local valueObject = folder and folder:FindFirstChild(name)
	return valueObject and valueObject.Value or ""
end

local function getDiscoveredPetSet()
	local discovered = splitCsv(getIndexValue("DiscoveredPets"))
	for _, item in ipairs(inventoryData.Colors or {}) do
		local petId = item.PetId or item.petId
		if not petId and item.Id then
			petId = tostring(item.Id):match("([^|]+)") or tostring(item.Id)
		end
		if petId and petId ~= "" then
			discovered[tostring(petId)] = true
		end
	end
	return discovered
end

local function getDiscoveredGearSet()
	local discovered = splitCsv(getIndexValue("DiscoveredGear"))
	for _, item in ipairs(inventoryData.Brushes or {}) do
		local id = item.Id or item.id
		if id and id ~= "" then
			discovered[tostring(id)] = true
		end
	end
	discovered.StarterBrush = true
	return discovered
end

local function getDiscoveredWorldSet()
	local storage = player:FindFirstChild("ColorStorage")
	local unlockedValue = storage and storage:FindFirstChild("UnlockedColors")
	local discovered = splitCsv(getIndexValue("DiscoveredPlaces"))
	for colorType in pairs(splitCsv(unlockedValue and unlockedValue.Value or "Red")) do
		discovered[colorType] = true
	end
	discovered.Red = true
	return discovered
end

local function buildPetEntries()
	local entries = {}
	local seen = {}
	local order = 1
	for _, eggId in ipairs(PetData.EggOrder or {}) do
		local egg = PetData.Eggs and PetData.Eggs[eggId]
		for _, roll in ipairs((egg and egg.pets) or {}) do
			addUniquePet(entries, seen, roll.petId, order)
			order += 1
		end
	end
	for petId in pairs(PetData.Pets or {}) do
		addUniquePet(entries, seen, petId, order)
		order += 1
	end

	local owned = getDiscoveredPetSet()
	for _, entry in ipairs(entries) do
		entry.discovered = owned[entry.id] == true
		entry.status = entry.discovered and "Collected" or "Not Found"
	end
	table.sort(entries, function(a, b)
		if a.sortOrder ~= b.sortOrder then
			return a.sortOrder < b.sortOrder
		end
		return a.name < b.name
	end)
	return entries
end

local function buildGearEntries()
	local owned = getDiscoveredGearSet()
	local entries = {}
	for index, toolId in ipairs(ToolData.Order or {}) do
		local tool = ToolData.Tools[toolId]
		if tool then
			local discovered = owned[tool.Id] == true
			table.insert(entries, {
				id = tool.Id,
				category = "Gear",
				name = tool.DisplayName or tool.Id,
				meta = tool.Rarity or "Gear",
				iconText = tool.ShortName or firstLetters(tool.DisplayName or tool.Id, "GE"),
				color = tool.AccentColor or tool.PaintColor or RARITY_COLORS[tool.Rarity or "Brush"] or BLUE,
				rarity = tool.Rarity or "Gear",
				status = discovered and "Owned" or "Not Found",
				discovered = discovered,
				sortOrder = tonumber(tool.SortOrder) or index,
			})
		end
	end
	return entries
end

local function buildPlaceEntries()
	local unlocked = getDiscoveredWorldSet()
	local entries = {}
	for index, world in ipairs(ColorData.Worlds or {}) do
		local colorType = world.primaryColor or world.id
		local colorInfo = ColorData.Colors and ColorData.Colors[colorType]
		local discovered = unlocked[colorType] == true
		table.insert(entries, {
			id = colorType,
			category = "Places",
			name = world.DisplayName or world.name or tostring(colorType),
			meta = "Sector " .. tostring(index),
			iconText = tostring(index),
			color = (colorInfo and colorInfo.color) or Color3.fromRGB(180, 210, 255),
			rarity = "Place",
			status = discovered and "Unlocked" or (formatNumber(world.unlockCost or world.UnlockCost or 0) .. " Coins"),
			discovered = discovered,
			sortOrder = index,
		})
	end
	return entries
end

local function getCatalog()
	local pets = buildPetEntries()
	local gear = buildGearEntries()
	local places = buildPlaceEntries()
	return {
		Pets = pets,
		Gear = gear,
		Places = places,
	}
end

local function entryMatches(entry)
	if currentFilter == "Found" and not entry.discovered then
		return false
	elseif currentFilter == "Missing" and entry.discovered then
		return false
	end
	if currentSearch == "" then
		return true
	end
	local search = string.lower(currentSearch)
	return string.find(string.lower(entry.name or ""), search, 1, true) ~= nil
		or string.find(string.lower(entry.meta or ""), search, 1, true) ~= nil
		or string.find(string.lower(entry.id or ""), search, 1, true) ~= nil
end

local function getFilteredEntries(catalog)
	local entries = {}
	for _, entry in ipairs(catalog[currentCategory] or {}) do
		if entryMatches(entry) then
			table.insert(entries, entry)
		end
	end
	table.sort(entries, function(a, b)
		if (a.discovered and 1 or 0) ~= (b.discovered and 1 or 0) and currentFilter == "All" then
			return a.discovered
		end
		if (a.sortOrder or 0) ~= (b.sortOrder or 0) then
			return (a.sortOrder or 0) < (b.sortOrder or 0)
		end
		return tostring(a.name) < tostring(b.name)
	end)
	return entries
end

local function setCardEntry(card, entry)
	if not entry then
		card.Visible = false
		return
	end

	card.Visible = true
	card.BackgroundColor3 = entry.discovered and CARD or LOCKED_CARD
	card:SetAttribute("IndexItemId", entry.id)
	card:SetAttribute("IndexItemCategory", currentCategory)
	card:SetAttribute("IndexItemDiscovered", entry.discovered == true)

	local icon = findDescendant(card, "IconFrame")
	if icon and icon:IsA("GuiObject") then
		icon.BackgroundColor3 = entry.discovered and (entry.color or BLUE) or Color3.fromRGB(170, 178, 194)
	end

	local lockOverlay = findDescendant(card, "LockOverlay")
	if lockOverlay and lockOverlay:IsA("GuiObject") then
		lockOverlay.Visible = not entry.discovered
	end

	local badge = findDescendant(card, "CollectedBadge")
	if badge and badge:IsA("GuiObject") then
		badge.Visible = entry.discovered == true
	end

	local visibleEntry = entry.discovered == true
	setCardText(card, "IconText", visibleEntry and entry.iconText or "?")
	setCardText(card, "NameLabel", visibleEntry and entry.name or "???")
	setCardText(card, "StatusLabel", visibleEntry and (entry.meta or entry.status) or "Not Found")
	local statusLabel = findDescendant(card, "StatusLabel")
	if statusLabel and statusLabel:IsA("TextLabel") then
		statusLabel.TextColor3 = entry.discovered and (RARITY_COLORS[entry.rarity] or MUTED) or MUTED
	end
end

local function updateTabVisuals()
	if ui.categoryTabs then
		for _, child in ipairs(ui.categoryTabs:GetChildren()) do
			if child:IsA("GuiObject") and child:GetAttribute("IndexCategory") then
				local selected = child:GetAttribute("IndexCategory") == currentCategory
				setButtonVisual(child, selected, BLUE)
				if child:IsA("TextButton") then
					child.Text = CATEGORY_LABELS[child:GetAttribute("IndexCategory")] or child.Text
				end
			end
		end
	end

	if ui.topFilters then
		for _, child in ipairs(ui.topFilters:GetChildren()) do
			if child:IsA("GuiObject") and child:GetAttribute("IndexFilter") then
				local selected = child:GetAttribute("IndexFilter") == currentFilter
				setButtonVisual(child, selected, BLUE)
				if child:IsA("TextButton") then
					child.Text = FILTER_LABELS[child:GetAttribute("IndexFilter")] or child.Text
				end
			end
		end
	end
end

local function render()
	if not collectUi() then
		return
	end
	updateTabVisuals()

	local catalog = getCatalog()
	local categoryEntries = catalog[currentCategory] or {}
	local entries = getFilteredEntries(catalog)
	local totalPages = math.max(1, math.ceil(#entries / PAGE_SIZE))
	currentPage = math.clamp(currentPage, 1, totalPages)
	local startIndex = (currentPage - 1) * PAGE_SIZE + 1

	for slotIndex, card in ipairs(cardSlots) do
		if slotIndex <= PAGE_SIZE then
			setCardEntry(card, entries[startIndex + slotIndex - 1])
		else
			card.Visible = false
		end
	end

	if ui.emptyText and ui.emptyText:IsA("GuiObject") then
		ui.emptyText.Visible = #entries == 0
	end
	setText(ui.pageLabel, tostring(currentPage))
	setText(ui.collectedCounter, tostring(countDiscovered(categoryEntries)) .. "/" .. tostring(#categoryEntries))

	if ui.pageBack and ui.pageBack:IsA("GuiButton") then
		ui.pageBack.Active = currentPage > 1
		ui.pageBack.AutoButtonColor = currentPage > 1
	end
	if ui.pageNext and ui.pageNext:IsA("GuiButton") then
		ui.pageNext.Active = currentPage < totalPages
		ui.pageNext.AutoButtonColor = currentPage < totalPages
	end
end

local function requestInventory()
	if inventoryLoading then
		pendingRefresh = true
		return
	end
	inventoryLoading = true
	task.spawn(function()
		local ok, result = pcall(function()
			return inventoryRequest:InvokeServer("GetInventory")
		end)
		if ok and type(result) == "table" then
			inventoryData = result
		end
		inventoryLoading = false
		render()
		if pendingRefresh then
			pendingRefresh = false
			requestInventory()
		end
	end)
end

local function restyleForViewport()
	if not collectUi() then
		return
	end
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local minAxis = math.min(viewport.X, viewport.Y)
	local maxAxis = math.max(viewport.X, viewport.Y)
	local mobile = UserInputService.TouchEnabled and (minAxis <= 1024 or maxAxis <= 1280)
	local phone = UserInputService.TouchEnabled and minAxis <= 720
	local portrait = viewport.Y >= viewport.X
	local topInset, bottomInset = GuiService:GetGuiInset()
	local scale = ui.window:FindFirstChild("ResponsiveScale")
	local scaleValue = 1
	if scale and scale:IsA("UIScale") then
		if mobile then
			local margin = portrait and 10 or 16
			local safeWidth = math.max(1, viewport.X - topInset.X - bottomInset.X - margin * 2)
			local safeHeight = math.max(1, viewport.Y - topInset.Y - bottomInset.Y - margin * 2)
			scaleValue = math.clamp(math.min(safeWidth / 860, safeHeight / 700), portrait and 0.56 or 0.54, 0.9)
		end
		scale.Scale = scaleValue
	end
	ui.window.AnchorPoint = Vector2.new(0.5, 0.5)
	if mobile then
		local margin = portrait and 10 or 16
		local left = topInset.X + margin
		local top = topInset.Y + margin
		local safeWidth = math.max(1, viewport.X - topInset.X - bottomInset.X - margin * 2)
		local safeHeight = math.max(1, viewport.Y - topInset.Y - bottomInset.Y - margin * 2)
		local targetWidth = math.floor(safeWidth * (phone and 1 or 0.94))
		local targetHeight = math.floor(safeHeight * (phone and 1 or 0.86))
		ui.window.Position = UDim2.fromOffset(math.floor(left + safeWidth * 0.5), math.floor(top + safeHeight * 0.5))
		ui.window.Size = UDim2.fromOffset(math.floor(targetWidth / scaleValue), math.floor(targetHeight / scaleValue))
		if ui.closeButton and ui.closeButton:IsA("GuiObject") then
			ui.closeButton.Position = UDim2.new(1, -58, 0, -30)
			ui.closeButton.Size = UDim2.fromOffset(54, 54)
			if ui.closeButton:IsA("TextButton") then
				ui.closeButton.TextSize = 36
			end
		end
	else
		ui.window.Position = UDim2.new(0.5, 0, 0.5, math.floor((topInset.Y - bottomInset.Y) * 0.12))
		ui.window.Size = UDim2.fromScale(0.76, 0.72)
		if ui.closeButton and ui.closeButton:IsA("GuiObject") then
			ui.closeButton.Position = UDim2.new(1, -78, 0, -42)
			ui.closeButton.Size = UDim2.fromOffset(70, 70)
			if ui.closeButton:IsA("TextButton") then
				ui.closeButton.TextSize = 48
			end
		end
	end
end

local function closeIndex()
	if not collectUi() then
		return
	end
	if ui.window.Visible then
		ui.window.Visible = false
		playUI("Close")
	end
end

local function openIndex()
	if not collectUi() then
		return
	end
	for _, child in ipairs(modalWindows:GetChildren()) do
		if child:IsA("GuiObject") and child ~= ui.window then
			child.Visible = false
		end
	end
	restyleForViewport()
	ui.window.Visible = true
	ui.window.Size = ui.window.Size
	playUI("Open")
	requestInventory()
	render()
	local scale = ui.window:FindFirstChild("ResponsiveScale")
	if scale and scale:IsA("UIScale") then
		local baseScale = scale.Scale
		scale.Scale = baseScale * 0.94
		TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = baseScale,
		}):Play()
	end
end

local function connectButton(object, callback, key)
	if not object or not object:IsA("GuiObject") then
		return
	end
	object.Active = true
	if object:IsA("GuiButton") then
		object.Activated:Connect(function()
			if debounce(key) then
				playUI("Click")
				callback()
			end
		end)
	else
		object.InputBegan:Connect(function(input)
			if
				(
					input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch
				) and debounce(key)
			then
				playUI("Click")
				callback()
			end
		end)
	end
end

local function bindConnections()
	if connectionsBound or not collectUi() then
		return
	end
	connectionsBound = true

	if ui.categoryTabs then
		for _, child in ipairs(ui.categoryTabs:GetChildren()) do
			if child:IsA("GuiObject") and child:GetAttribute("IndexCategory") then
				connectButton(child, function()
					currentCategory = tostring(child:GetAttribute("IndexCategory") or "Pets")
					currentPage = 1
					render()
				end, "category-" .. child.Name)
			end
		end
	end

	if ui.topFilters then
		for _, child in ipairs(ui.topFilters:GetChildren()) do
			if child:IsA("GuiObject") and child:GetAttribute("IndexFilter") then
				connectButton(child, function()
					currentFilter = tostring(child:GetAttribute("IndexFilter") or "All")
					currentPage = 1
					render()
				end, "filter-" .. child.Name)
			end
		end
	end

	if ui.searchBox and ui.searchBox:IsA("TextBox") then
		ui.searchBox:GetPropertyChangedSignal("Text"):Connect(function()
			currentSearch = tostring(ui.searchBox.Text or "")
			currentPage = 1
			render()
		end)
	end

	connectButton(ui.pageBack, function()
		currentPage = math.max(1, currentPage - 1)
		render()
	end, "page-back")
	connectButton(ui.pageNext, function()
		currentPage += 1
		render()
	end, "page-next")
	connectButton(ui.closeButton, closeIndex, "close")

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not (ui.window and ui.window.Visible) then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			closeIndex()
		end
	end)

	inventoryAction.OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and type(payload.Inventory) == "table" then
			inventoryData = payload.Inventory
			render()
		else
			requestInventory()
		end
	end)
	hatchEvent.OnClientEvent:Connect(function()
		task.delay(0.35, requestInventory)
	end)
	petsLoadedEvent.OnClientEvent:Connect(requestInventory)

	local colorStorage = player:WaitForChild("ColorStorage", 20)
	local unlockedColors = colorStorage and colorStorage:WaitForChild("UnlockedColors", 10)
	if unlockedColors then
		unlockedColors:GetPropertyChangedSignal("Value"):Connect(render)
	end
	local paintTools = player:WaitForChild("PaintTools", 20)
	local ownedTools = paintTools and paintTools:WaitForChild("Owned", 10)
	if ownedTools then
		ownedTools:GetPropertyChangedSignal("Value"):Connect(requestInventory)
	end
	local indexData = player:WaitForChild("IndexData", 20)
	if indexData then
		for _, valueName in ipairs({ "DiscoveredPets", "DiscoveredGear", "DiscoveredPlaces" }) do
			local valueObject = indexData:WaitForChild(valueName, 10)
			if valueObject and valueObject:IsA("StringValue") then
				valueObject:GetPropertyChangedSignal("Value"):Connect(render)
			end
		end
	end

	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(restyleForViewport)
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		if Workspace.CurrentCamera then
			Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(restyleForViewport)
		end
		restyleForViewport()
	end)

	mainHud:GetAttributeChangedSignal("RequestedWindow"):Connect(function()
		local requested = tostring(mainHud:GetAttribute("RequestedWindow") or "")
		if requested == "Index" or requested == "IndexWindow" or requested == "Collection" then
			openIndex()
		end
	end)
	mainHud:GetAttributeChangedSignal("RequestedWindowNonce"):Connect(function()
		local requested = tostring(mainHud:GetAttribute("RequestedWindow") or "")
		if requested == "Index" or requested == "IndexWindow" or requested == "Collection" then
			openIndex()
		end
	end)
end

local function isIndexPrompt(prompt)
	if not prompt then
		return false
	end
	if prompt:GetAttribute("IndexStationPrompt") == true then
		return true
	end
	if prompt.Name == "IndexPrompt" then
		return true
	end
	local objectText = string.lower(tostring(prompt.ObjectText or ""))
	return string.find(objectText, "collection index", 1, true) ~= nil
end

ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeringPlayer)
	if triggeringPlayer ~= player or not isIndexPrompt(prompt) then
		return
	end
	openIndex()
end)

bindConnections()
requestInventory()
render()

print("IndexWindowBinder: editable Collection Index ready.")
