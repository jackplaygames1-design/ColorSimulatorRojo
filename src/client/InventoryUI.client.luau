-- LocalScript in StarterPlayerScripts named "InventoryUI"
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

local player    = Players.LocalPlayer
local PetData   = require(ReplicatedStorage:WaitForChild("PetData"))
local ColorData = require(ReplicatedStorage:WaitForChild("ColorData"))
local GameBalance = require(ReplicatedStorage:WaitForChild("GameBalance"))
local ItemsData = require(ReplicatedStorage:WaitForChild("ItemsData"))
local ToolData  = require(ReplicatedStorage:WaitForChild("ToolData"))
local UITheme   = require(ReplicatedStorage:WaitForChild("UITheme"))
local ClientUIRoot = require(ReplicatedStorage:WaitForChild("ClientUIRoot"))
local UIManager = require(ReplicatedStorage:WaitForChild("UIManager"))
local Modules = ReplicatedStorage:WaitForChild("Modules")
local PetDefinitions = require(Modules:WaitForChild("PetDefinitions"))
local PetModelUtil = require(Modules:WaitForChild("PetModelUtil"))

local Events          = ReplicatedStorage:WaitForChild("Events")
local petsLoadedEvent = Events:WaitForChild("PetsLoaded")
local equipEvent      = Events:WaitForChild("EquipPet")
local mergeEvent      = Events:WaitForChild("MergePet")
local useEvent        = Events:WaitForChild("UseItem")
local equipPaintToolEvent = Events:WaitForChild("EquipPaintTool")

local openInventoryBindable = ReplicatedStorage:FindFirstChild("HudOpenInventory")
if not openInventoryBindable then
	openInventoryBindable = Instance.new("BindableEvent")
	openInventoryBindable.Name = "HudOpenInventory"
	openInventoryBindable.Parent = ReplicatedStorage
end

local paintToolState = ReplicatedStorage:FindFirstChild("PaintToolEquippedState")
if not paintToolState then
	paintToolState = Instance.new("BoolValue")
	paintToolState.Name = "PaintToolEquippedState"
	paintToolState.Value = true
	paintToolState.Parent = ReplicatedStorage
end

local paintToolEquipChanged = ReplicatedStorage:FindFirstChild("PaintToolEquipChanged")
if not paintToolEquipChanged then
	paintToolEquipChanged = Instance.new("BindableEvent")
	paintToolEquipChanged.Name = "PaintToolEquipChanged"
	paintToolEquipChanged.Parent = ReplicatedStorage
end

local paintToolsFolder = player:WaitForChild("PaintTools", 10)
local ownedPaintToolsValue = paintToolsFolder and paintToolsFolder:WaitForChild("Owned", 10)
local equippedPaintToolValue = paintToolsFolder and paintToolsFolder:WaitForChild("Equipped", 10)
local INVENTORY_VERSION = "Inventory_SINGLE_SOURCE_v2"
local printedInventoryVersion = false
local warnedLegacyInventoryOpen = false

-- ========================
--   THEME
-- ========================
local THEME = {
	bg        = Color3.fromRGB(255, 255, 255),
	panel     = Color3.fromRGB(255, 255, 255),
	stroke    = Color3.fromRGB(35, 38, 45),
	titleBg   = UITheme.Colors.PrimaryPurple,
	titleText = Color3.fromRGB(30, 36, 48),
	tabActive = UITheme.Colors.PrimaryPurple,
	tabInact  = UITheme.Colors.PanelLavender,
	cardBg    = Color3.fromRGB(255, 255, 255),
	subtext   = Color3.fromRGB(80, 84, 104),
	searchBg  = Color3.fromRGB(255, 255, 255),
	green     = UITheme.Colors.PrimaryGreen,
	red       = UITheme.Colors.ErrorRed,
	yellow    = UITheme.Colors.PrimaryYellow,
	pink      = Color3.fromRGB(255, 112, 218),
	aqua      = Color3.fromRGB(122, 242, 248),
	lavender  = Color3.fromRGB(222, 220, 255),
	controlText = Color3.fromRGB(50, 45, 86),
	controlTextSoft = Color3.fromRGB(84, 78, 132),
	buttonText = Color3.fromRGB(255, 255, 255),
}

local RARITY_COLOR = {
	Common    = Color3.fromRGB(180, 180, 180),
	Uncommon  = Color3.fromRGB(80,  200, 80),
	Rare      = Color3.fromRGB(80,  120, 255),
	Epic      = Color3.fromRGB(180, 60,  255),
	Legendary = Color3.fromRGB(255, 200, 0),
	Mythic    = Color3.fromRGB(255, 60,  60),
	Event     = Color3.fromRGB(255, 140, 0),
}

local TIER_COLOR = {
	Normal    = Color3.fromRGB(200, 200, 200),
	Gilded    = Color3.fromRGB(255, 200, 50),
	Royal     = Color3.fromRGB(180, 60,  255),
	Celestial = Color3.fromRGB(100, 220, 255),
}

local TIER_ICON = { Normal = "", Gilded = "*", Royal = "R", Celestial = "C" }
local PANEL_WIDTH = 760
local PANEL_HEIGHT = 580
local WINDOW_BUTTON_Z = 130

-- ========================
--   STATE
-- ========================
local allPets      = {}
local equippedPets = {}
local favorites    = {}
local newItems     = {}
local playerItems  = {}
local lastPetStateAt = 0
local colorStorage = player:WaitForChild("ColorStorage", 10)
local unlockedColorsValue = colorStorage and colorStorage:WaitForChild("UnlockedColors", 10)
local petFolder = player:WaitForChild("PetData", 10)
local petInventoryValue = petFolder and petFolder:WaitForChild("Inventory", 10)
local petEquippedValue = petFolder and petFolder:WaitForChild("Equipped", 10)

local currentTab    = "Colors"
local searchText    = ""
local currentSort   = "Power"
local currentFilter = "All"
local isOpen        = false
local openedFromMenu = false
local lastInventoryOpenedAt = 0

-- ========================
--   SCREEN GUI
-- ========================
local screenGui = ClientUIRoot.GetLayer(player.PlayerGui, "InventoryUI")
screenGui.ZIndex = 80
local toggleInventory
local queuedInventoryOpen = false
local queuedInventoryOpenContext = nil
local queuedInventoryClose = false
local queuedInventoryCloseContext = nil

UIManager.register("Inventory",
	function(context)
		if toggleInventory then
			toggleInventory(true, context)
		else
			queuedInventoryOpen = true
			queuedInventoryOpenContext = context
			queuedInventoryClose = false
		end
	end,
	function(context)
		if toggleInventory then
			toggleInventory(false, context)
		else
			queuedInventoryClose = true
			queuedInventoryCloseContext = context
			queuedInventoryOpen = false
		end
	end,
	function() return isOpen end
)

openInventoryBindable.Event:Connect(function(context)
	context = type(context) == "table" and context or { from = "HUD", defaultTab = "Brushes" }
	print("InventoryUI direct open received")
	if toggleInventory then
		toggleInventory(true, context)
	else
		queuedInventoryOpen = true
		queuedInventoryOpenContext = context
		queuedInventoryClose = false
	end
end)

local overlay = Instance.new("Frame")
overlay.Size             = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.new(0, 0, 0)
overlay.BackgroundTransparency = 0.4
overlay.BorderSizePixel  = 0
overlay.ZIndex           = 50
overlay.Visible          = false
overlay.Parent           = screenGui

local panel = Instance.new("Frame")
panel.AnchorPoint      = Vector2.new(0.5, 0.5)
panel.Size             = UDim2.new(0, PANEL_WIDTH, 0, PANEL_HEIGHT)
panel.Position         = UDim2.fromScale(0.5, 0.5)
panel.BackgroundColor3 = THEME.panel
panel.BorderSizePixel  = 0
panel.Visible          = false
panel.ZIndex           = 60
panel.Parent           = screenGui
UITheme.ApplyResponsiveScale(panel, PANEL_WIDTH, PANEL_HEIGHT, 0.72, 28)
local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 28)
panelCorner.Parent       = panel
local panelStroke = Instance.new("UIStroke")
panelStroke.Color     = THEME.stroke
panelStroke.Thickness = 5
panelStroke.Parent    = panel

-- ========================
--   HEADER
-- ========================
local header = Instance.new("Frame")
header.Size             = UDim2.new(1, 0, 0, 64)
header.BackgroundColor3 = THEME.titleBg
header.BorderSizePixel  = 0
header.ZIndex           = 42
header.Parent           = panel
local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 28)
headerCorner.Parent       = header
local headerStroke = Instance.new("UIStroke")
headerStroke.Color     = Color3.new(1, 1, 1)
headerStroke.Thickness = 0
headerStroke.Parent    = header

local titleL = Instance.new("TextLabel")
titleL.Size                   = UDim2.new(1, -116, 1, 0)
titleL.Position               = UDim2.new(0, 22, 0, 0)
titleL.BackgroundTransparency = 1
titleL.Font                   = Enum.Font.LuckiestGuy
titleL.TextSize               = 28
titleL.TextColor3             = Color3.new(1, 1, 1)
titleL.TextStrokeTransparency = 0
titleL.TextStrokeColor3       = THEME.stroke
titleL.TextXAlignment         = Enum.TextXAlignment.Left
titleL.Text                   = "INVENTORY"
titleL.ZIndex                 = 64
titleL.Parent                 = header

local backBtn = Instance.new("TextButton")
backBtn.Size             = UDim2.new(0, 42, 0, 42)
backBtn.Position         = UDim2.new(0, 12, 0.5, -21)
backBtn.BackgroundColor3 = UITheme.Colors.PanelCream
backBtn.AutoButtonColor  = false
backBtn.Font             = Enum.Font.LuckiestGuy
backBtn.TextSize         = 26
backBtn.TextColor3       = THEME.stroke
backBtn.TextStrokeTransparency = 1
backBtn.Text             = "<"
backBtn.Visible          = false
backBtn.ZIndex           = 65
backBtn.Parent           = header
local backBtnCorner = Instance.new("UICorner")
backBtnCorner.CornerRadius = UDim.new(0, 14)
backBtnCorner.Parent       = backBtn
local backBtnStroke = Instance.new("UIStroke")
backBtnStroke.Color     = THEME.stroke
backBtnStroke.Thickness = 4
backBtnStroke.Parent    = backBtn

local closeBtn = Instance.new("TextButton")
closeBtn.Name             = "InventoryCloseButton"
closeBtn.Size             = UDim2.new(0, 42, 0, 42)
closeBtn.Position         = UDim2.new(1, -52, 0.5, -21)
closeBtn.BackgroundColor3 = THEME.red
closeBtn.AutoButtonColor  = false
closeBtn.Active           = true
closeBtn.Selectable       = true
closeBtn.Font             = Enum.Font.LuckiestGuy
closeBtn.TextSize         = 22
closeBtn.TextColor3       = Color3.new(1, 1, 1)
closeBtn.TextStrokeTransparency = 0
closeBtn.TextStrokeColor3 = THEME.stroke
closeBtn.Text             = "X"
closeBtn.ZIndex           = WINDOW_BUTTON_Z
closeBtn:SetAttribute("NoTextGlow", true)
closeBtn.Parent           = header
local closeBtnCorner = Instance.new("UICorner")
closeBtnCorner.CornerRadius = UDim.new(0, 14)
closeBtnCorner.Parent       = closeBtn
local closeBtnStroke = Instance.new("UIStroke")
closeBtnStroke.Color     = THEME.stroke
closeBtnStroke.Thickness = 4
closeBtnStroke.Parent    = closeBtn

-- ========================
--   SEARCH + SORT + FILTER
-- ========================
local toolRow = Instance.new("Frame")
toolRow.Size             = UDim2.new(1, -24, 0, 38)
toolRow.Position         = UDim2.new(0, 12, 0, 70)
toolRow.BackgroundTransparency = 1
toolRow.ZIndex           = 42
toolRow.Parent           = panel
local toolLayout = Instance.new("UIListLayout")
toolLayout.FillDirection     = Enum.FillDirection.Horizontal
toolLayout.VerticalAlignment = Enum.VerticalAlignment.Center
toolLayout.Padding           = UDim.new(0, 8)
toolLayout.Parent            = toolRow

local searchBox = Instance.new("TextBox")
searchBox.Size             = UDim2.new(0, 240, 0, 34)
searchBox.BackgroundColor3 = THEME.searchBg
searchBox.BorderSizePixel  = 0
searchBox.Font             = Enum.Font.GothamBold
searchBox.TextSize         = 15
searchBox.TextColor3       = THEME.controlText
searchBox.TextStrokeTransparency = 1
searchBox.PlaceholderText  = "Search..."
searchBox.PlaceholderColor3 = THEME.controlTextSoft
searchBox.Text             = ""
searchBox.ClipsDescendants = false
searchBox:SetAttribute("NoTextGlow", true)
searchBox.ZIndex           = 43
searchBox.Parent           = toolRow
local searchPadding = Instance.new("UIPadding")
searchPadding.PaddingLeft = UDim.new(0, 12)
searchPadding.PaddingRight = UDim.new(0, 10)
searchPadding.Parent = searchBox
local searchCorner = Instance.new("UICorner")
searchCorner.CornerRadius = UDim.new(0, 10)
searchCorner.Parent       = searchBox
local searchStroke = Instance.new("UIStroke")
searchStroke.Color     = THEME.stroke
searchStroke.Thickness = 4
searchStroke.Parent    = searchBox

local SORT_OPTIONS = {"Power","Name","Rarity","Stack","Newest"}
local sortIdx = 1

local sortBtn = Instance.new("TextButton")
sortBtn.Size             = UDim2.new(0, 148, 0, 34)
sortBtn.BackgroundColor3 = THEME.searchBg
sortBtn.AutoButtonColor  = false
sortBtn.Font             = Enum.Font.GothamBold
sortBtn.TextSize         = 15
sortBtn.TextColor3       = THEME.controlText
sortBtn.TextStrokeTransparency = 1
sortBtn.TextStrokeColor3 = Color3.new(1, 1, 1)
sortBtn.Text             = "Sort: Power V"
sortBtn.ClipsDescendants = false
sortBtn:SetAttribute("NoTextGlow", true)
sortBtn.ZIndex           = 43
sortBtn.Parent           = toolRow
local sortCorner = Instance.new("UICorner")
sortCorner.CornerRadius = UDim.new(0, 10)
sortCorner.Parent       = sortBtn
local sortStroke2 = Instance.new("UIStroke")
sortStroke2.Color     = THEME.stroke
sortStroke2.Thickness = 3
sortStroke2.Parent    = sortBtn

local FILTER_OPTIONS = {"All","Equipped","Unequipped","Favorites","Common","Uncommon","Rare","Epic","Legendary"}
local filterIdx = 1

local filterBtn = Instance.new("TextButton")
filterBtn.Size             = UDim2.new(0, 156, 0, 34)
filterBtn.BackgroundColor3 = THEME.searchBg
filterBtn.AutoButtonColor  = false
filterBtn.Font             = Enum.Font.GothamBold
filterBtn.TextSize         = 15
filterBtn.TextColor3       = THEME.controlText
filterBtn.TextStrokeTransparency = 1
filterBtn.TextStrokeColor3 = Color3.new(1, 1, 1)
filterBtn.Text             = "Filter: All V"
filterBtn.ClipsDescendants = false
filterBtn:SetAttribute("NoTextGlow", true)
filterBtn.ZIndex           = 43
filterBtn.Parent           = toolRow
local filterCorner = Instance.new("UICorner")
filterCorner.CornerRadius = UDim.new(0, 10)
filterCorner.Parent       = filterBtn
local filterStroke2 = Instance.new("UIStroke")
filterStroke2.Color     = THEME.stroke
filterStroke2.Thickness = 3
filterStroke2.Parent    = filterBtn

-- ========================
--   TAB BAR
-- ========================
local TABS = {"Colors","Brushes"}
local TAB_ICONS = {
	Colors      = "COLORS",
	Brushes     = "BRUSHES",
}

local tabBar = Instance.new("Frame")
tabBar.Size             = UDim2.new(1, -24, 0, 42)
tabBar.Position         = UDim2.new(0, 12, 0, 114)
tabBar.BackgroundColor3 = THEME.searchBg
tabBar.BorderSizePixel  = 0
tabBar.ZIndex           = 42
tabBar.Parent           = panel
local tabBarCorner = Instance.new("UICorner")
tabBarCorner.CornerRadius = UDim.new(0, 14)
tabBarCorner.Parent       = tabBar
local tabBarStroke = Instance.new("UIStroke")
tabBarStroke.Color     = THEME.stroke
tabBarStroke.Thickness = 4
tabBarStroke.Parent    = tabBar
local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection       = Enum.FillDirection.Horizontal
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
tabLayout.VerticalAlignment   = Enum.VerticalAlignment.Center
tabLayout.Padding             = UDim.new(0, 5)
tabLayout.Parent              = tabBar
local tabPad = Instance.new("UIPadding")
tabPad.PaddingLeft  = UDim.new(0, 6)
tabPad.PaddingRight = UDim.new(0, 6)
tabPad.Parent       = tabBar

-- ========================
--   ACTION BAR
-- ========================
local actionBar = Instance.new("Frame")
actionBar.Size             = UDim2.new(1, -24, 0, 34)
actionBar.Position         = UDim2.new(0, 12, 0, 162)
actionBar.BackgroundTransparency = 1
actionBar.ZIndex           = 42
actionBar.Parent           = panel
local actionLayout = Instance.new("UIListLayout")
actionLayout.FillDirection     = Enum.FillDirection.Horizontal
actionLayout.VerticalAlignment = Enum.VerticalAlignment.Center
actionLayout.Padding           = UDim.new(0, 6)
actionLayout.Parent            = actionBar

local function makeActionBtn(text, bg, tc)
	local b = Instance.new("TextButton")
	b.AutomaticSize    = Enum.AutomaticSize.X
	b.Size             = UDim2.new(0, 0, 0, 28)
	b.BackgroundColor3 = bg
	b.AutoButtonColor  = false
	b.Font             = Enum.Font.GothamBold
	b.TextSize         = 14
	b.TextColor3       = Color3.new(1, 1, 1)
	b.TextStrokeTransparency = 0.45
	b.TextStrokeColor3 = THEME.stroke
	b.Text             = "  " .. text .. "  "
	b.ZIndex           = 43
	b.Parent           = actionBar
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent       = b
	local s = Instance.new("UIStroke")
	s.Color     = THEME.stroke
	s.Thickness = 3
	s.Parent    = b
	return b
end

local equipBestBtn  = makeActionBtn("EQUIP BEST",     THEME.green,   Color3.new(1,1,1))
local unequipAllBtn = makeActionBtn("UNEQUIP ALL",    THEME.red,     Color3.new(1,1,1))

-- ========================
--   CONTENT SCROLL
-- ========================
local contentScroll = Instance.new("ScrollingFrame")
contentScroll.Size                 = UDim2.new(1, -24, 1, -210)
contentScroll.Position             = UDim2.new(0, 12, 0, 202)
contentScroll.BackgroundTransparency = 0
contentScroll.BackgroundColor3 = Color3.fromRGB(250, 255, 255)
contentScroll.BorderSizePixel      = 0
contentScroll.ScrollBarThickness   = 6
contentScroll.ScrollBarImageColor3 = THEME.stroke
contentScroll.CanvasSize           = UDim2.new(0, 0, 0, 0)
contentScroll.ZIndex               = 42
contentScroll.Parent               = panel
local contentCorner = Instance.new("UICorner")
contentCorner.CornerRadius = UDim.new(0, 18)
contentCorner.Parent = contentScroll
local contentStroke = Instance.new("UIStroke")
contentStroke.Color = THEME.stroke
contentStroke.Thickness = 4
contentStroke.Parent = contentScroll

local contentGrid = Instance.new("UIGridLayout")
contentGrid.CellSize    = UDim2.new(0, 148, 0, 190)
contentGrid.CellPadding = UDim2.new(0, 10, 0, 10)
contentGrid.Parent      = contentScroll
local contentPad = Instance.new("UIPadding")
contentPad.PaddingLeft   = UDim.new(0, 8)
contentPad.PaddingTop    = UDim.new(0, 8)
contentPad.PaddingRight  = UDim.new(0, 8)
contentPad.PaddingBottom = UDim.new(0, 8)
contentPad.Parent        = contentScroll

local emptyLayer = Instance.new("Frame")
emptyLayer.Size = contentScroll.Size
emptyLayer.Position = contentScroll.Position
emptyLayer.BackgroundTransparency = 1
emptyLayer.BorderSizePixel = 0
emptyLayer.ZIndex = 46
emptyLayer.Parent = panel

local emptyLabel = Instance.new("TextLabel")
emptyLabel.Size                   = UDim2.new(1, -40, 0, 60)
emptyLabel.AnchorPoint            = Vector2.new(0.5, 0.5)
emptyLabel.Position               = UDim2.fromScale(0.5, 0.5)
emptyLabel.BackgroundTransparency = 1
emptyLabel.Font                   = Enum.Font.LuckiestGuy
emptyLabel.TextSize               = 24
emptyLabel.TextScaled             = true
emptyLabel.TextXAlignment         = Enum.TextXAlignment.Center
emptyLabel.TextYAlignment         = Enum.TextYAlignment.Center
emptyLabel.TextColor3             = THEME.subtext
emptyLabel.Text                   = "Nothing here yet!"
emptyLabel.Visible                = false
emptyLabel.Active                 = false
emptyLabel.TextWrapped            = true
emptyLabel:SetAttribute("NoTextGlow", true)
emptyLabel.ZIndex                 = 46
emptyLabel.Parent                 = emptyLayer
local emptyTextConstraint = Instance.new("UITextSizeConstraint")
emptyTextConstraint.MaxTextSize = 30
emptyTextConstraint.Parent = emptyLabel

local function isComingSoonInventoryTab(tabName)
	return false
end

local function setEmptyPlaceholder(text, isComingSoon)
	emptyLabel.Text = text
	emptyLabel.TextColor3 = isComingSoon and Color3.fromRGB(255, 248, 226) or THEME.subtext
	emptyLabel.TextStrokeColor3 = THEME.stroke
	emptyLabel.TextStrokeTransparency = isComingSoon and 0 or 1
	emptyLabel.TextSize = isComingSoon and 34 or 24
	emptyTextConstraint.MaxTextSize = isComingSoon and 42 or 30
	emptyLabel.Visible = true
end

local function updateEmptyLabelLayout()
	emptyLayer.Size = contentScroll.Size
	emptyLayer.Position = contentScroll.Position
	emptyLabel.Size = UDim2.new(1, -40, 0, 60)
	emptyLabel.Position = UDim2.fromScale(0.5, 0.5)
end

local detailPanel = Instance.new("Frame")
detailPanel.Name = "ColorDetailPanel"
detailPanel.Size = UDim2.new(0, 520, 0, 470)
detailPanel.AnchorPoint = Vector2.new(0.5, 0.5)
detailPanel.Position = UDim2.new(0.5, 0, 0.5, 0)
detailPanel.BackgroundColor3 = UITheme.Colors.PanelCream
detailPanel.BorderSizePixel = 0
detailPanel.Visible = false
detailPanel.ZIndex = 120
detailPanel.Parent = screenGui
UITheme.ApplyCorner(detailPanel, UITheme.Sizes.CornerLarge)
UITheme.ApplyStroke(detailPanel, THEME.stroke, 5)

local detailHeader = Instance.new("Frame")
detailHeader.Size = UDim2.new(1, 0, 0, 62)
detailHeader.BackgroundColor3 = UITheme.Colors.PrimaryPurple
detailHeader.BorderSizePixel = 0
detailHeader.ZIndex = 121
detailHeader.Parent = detailPanel
UITheme.ApplyCorner(detailHeader, UITheme.Sizes.CornerLarge)

local detailTitle = Instance.new("TextLabel")
detailTitle.Size = UDim2.new(1, -76, 1, 0)
detailTitle.Position = UDim2.new(0, 20, 0, 0)
detailTitle.BackgroundTransparency = 1
detailTitle.Font = Enum.Font.LuckiestGuy
detailTitle.TextSize = 26
detailTitle.TextScaled = true
detailTitle.TextColor3 = Color3.new(1, 1, 1)
detailTitle.TextStrokeTransparency = 0
detailTitle.TextStrokeColor3 = THEME.stroke
detailTitle.TextXAlignment = Enum.TextXAlignment.Left
detailTitle.Text = "COLOR DETAILS"
detailTitle.ZIndex = 122
detailTitle.Parent = detailHeader
local detailTitleSize = Instance.new("UITextSizeConstraint")
detailTitleSize.MinTextSize = 15
detailTitleSize.MaxTextSize = 26
detailTitleSize.Parent = detailTitle

local detailCloseBtn = Instance.new("TextButton")
detailCloseBtn.Size = UDim2.new(0, 42, 0, 42)
detailCloseBtn.Position = UDim2.new(1, -54, 0.5, -21)
detailCloseBtn.BackgroundColor3 = THEME.red
detailCloseBtn.AutoButtonColor = false
detailCloseBtn.Font = Enum.Font.LuckiestGuy
detailCloseBtn.TextSize = 22
detailCloseBtn.TextColor3 = Color3.new(1, 1, 1)
detailCloseBtn.TextStrokeTransparency = 0
detailCloseBtn.TextStrokeColor3 = THEME.stroke
detailCloseBtn.Text = "X"
detailCloseBtn.ZIndex = 123
detailCloseBtn.Parent = detailHeader
UITheme.ApplyCorner(detailCloseBtn, UITheme.Sizes.CornerMedium)
UITheme.ApplyStroke(detailCloseBtn, THEME.stroke, 4)

local detailPreview = Instance.new("Frame")
detailPreview.Size = UDim2.new(0, 172, 0, 172)
detailPreview.Position = UDim2.new(0, 22, 0, 84)
detailPreview.BackgroundColor3 = UITheme.Colors.PanelWhite
detailPreview.BorderSizePixel = 0
detailPreview.ZIndex = 121
detailPreview.Parent = detailPanel
UITheme.ApplyCorner(detailPreview, UITheme.Sizes.CornerLarge)
UITheme.ApplyStroke(detailPreview, THEME.stroke, 4)

local detailAura = Instance.new("Frame")
detailAura.Size = UDim2.new(0, 118, 0, 118)
detailAura.AnchorPoint = Vector2.new(0.5, 0.5)
detailAura.Position = UDim2.new(0.5, 0, 0.45, 0)
detailAura.BackgroundColor3 = UITheme.Colors.PrimaryCyan
detailAura.BackgroundTransparency = 0.72
detailAura.BorderSizePixel = 0
detailAura.ZIndex = 122
detailAura.Parent = detailPreview
UITheme.ApplyCorner(detailAura, UDim.new(1, 0))

local detailOrb = Instance.new("Frame")
detailOrb.Size = UDim2.new(0, 86, 0, 86)
detailOrb.AnchorPoint = Vector2.new(0.5, 0.5)
detailOrb.Position = UDim2.new(0.5, 0, 0.45, 0)
detailOrb.BackgroundColor3 = UITheme.Colors.ColorPink
detailOrb.BorderSizePixel = 0
detailOrb.ZIndex = 123
detailOrb.Parent = detailPreview
UITheme.ApplyCorner(detailOrb, UDim.new(1, 0))
UITheme.ApplyStroke(detailOrb, THEME.stroke, 4)

local detailStack = Instance.new("TextLabel")
detailStack.Size = UDim2.new(1, -16, 0, 28)
detailStack.Position = UDim2.new(0, 8, 1, -38)
detailStack.BackgroundTransparency = 1
detailStack.Font = Enum.Font.LuckiestGuy
detailStack.TextSize = 17
detailStack.TextColor3 = THEME.titleText
detailStack.TextStrokeTransparency = 0.75
detailStack.TextXAlignment = Enum.TextXAlignment.Center
detailStack.Text = "x1"
detailStack.ZIndex = 123
detailStack.Parent = detailPreview

local detailName = Instance.new("TextLabel")
detailName.Size = UDim2.new(1, -224, 0, 36)
detailName.Position = UDim2.new(0, 214, 0, 86)
detailName.BackgroundTransparency = 1
detailName.Font = Enum.Font.LuckiestGuy
detailName.TextSize = 25
detailName.TextScaled = true
detailName.TextColor3 = THEME.titleText
detailName.TextXAlignment = Enum.TextXAlignment.Left
detailName.Text = "Color"
detailName.ZIndex = 121
detailName.Parent = detailPanel
local detailNameSize = Instance.new("UITextSizeConstraint")
detailNameSize.MinTextSize = 14
detailNameSize.MaxTextSize = 25
detailNameSize.Parent = detailName

local detailMeta = Instance.new("TextLabel")
detailMeta.Size = UDim2.new(1, -224, 0, 24)
detailMeta.Position = UDim2.new(0, 214, 0, 124)
detailMeta.BackgroundTransparency = 1
detailMeta.Font = Enum.Font.GothamBold
detailMeta.TextSize = 14
detailMeta.TextColor3 = THEME.subtext
detailMeta.TextXAlignment = Enum.TextXAlignment.Left
detailMeta.Text = "Common - Normal"
detailMeta.ZIndex = 121
detailMeta.Parent = detailPanel

local detailPower = Instance.new("TextLabel")
detailPower.Size = UDim2.new(1, -224, 0, 34)
detailPower.Position = UDim2.new(0, 214, 0, 154)
detailPower.BackgroundColor3 = UITheme.Colors.PanelYellowSoft
detailPower.BorderSizePixel = 0
detailPower.Font = Enum.Font.LuckiestGuy
detailPower.TextSize = 19
detailPower.TextColor3 = THEME.titleText
detailPower.TextXAlignment = Enum.TextXAlignment.Center
detailPower.Text = "POWER 0"
detailPower.ZIndex = 121
detailPower.Parent = detailPanel
UITheme.ApplyCorner(detailPower, UITheme.Sizes.CornerMedium)
UITheme.ApplyStroke(detailPower, THEME.stroke, 3)

local detailTrait = Instance.new("TextLabel")
detailTrait.Size = UDim2.new(1, -44, 0, 58)
detailTrait.Position = UDim2.new(0, 22, 0, 276)
detailTrait.BackgroundColor3 = UITheme.Colors.PanelBlueSoft
detailTrait.BorderSizePixel = 0
detailTrait.Font = Enum.Font.GothamBold
detailTrait.TextSize = 13
detailTrait.TextWrapped = true
detailTrait.TextColor3 = THEME.titleText
detailTrait.TextXAlignment = Enum.TextXAlignment.Left
detailTrait.TextYAlignment = Enum.TextYAlignment.Center
detailTrait.Text = ""
detailTrait.ZIndex = 121
detailTrait.Parent = detailPanel
UITheme.ApplyCorner(detailTrait, UITheme.Sizes.CornerMedium)
UITheme.ApplyStroke(detailTrait, UITheme.Colors.PrimaryBlueDark, 2)
UITheme.ApplyPadding(detailTrait, 10)

local detailMutation = Instance.new("TextLabel")
detailMutation.Size = UDim2.new(1, -44, 0, 58)
detailMutation.Position = UDim2.new(0, 22, 0, 342)
detailMutation.BackgroundColor3 = UITheme.Colors.PanelPinkSoft
detailMutation.BorderSizePixel = 0
detailMutation.Font = Enum.Font.GothamBold
detailMutation.TextSize = 13
detailMutation.TextWrapped = true
detailMutation.TextColor3 = THEME.titleText
detailMutation.TextXAlignment = Enum.TextXAlignment.Left
detailMutation.TextYAlignment = Enum.TextYAlignment.Center
detailMutation.Text = ""
detailMutation.ZIndex = 121
detailMutation.Parent = detailPanel
UITheme.ApplyCorner(detailMutation, UITheme.Sizes.CornerMedium)
UITheme.ApplyStroke(detailMutation, UITheme.Colors.PrimaryPinkDark, 2)
UITheme.ApplyPadding(detailMutation, 10)

local detailStats = Instance.new("TextLabel")
detailStats.Size = UDim2.new(1, -224, 0, 62)
detailStats.Position = UDim2.new(0, 214, 0, 202)
detailStats.BackgroundTransparency = 1
detailStats.Font = Enum.Font.GothamBold
detailStats.TextSize = 13
detailStats.TextWrapped = true
detailStats.TextColor3 = THEME.subtext
detailStats.TextXAlignment = Enum.TextXAlignment.Left
detailStats.TextYAlignment = Enum.TextYAlignment.Top
detailStats.Text = ""
detailStats.ZIndex = 121
detailStats.Parent = detailPanel

local detailEquipBtn = Instance.new("TextButton")
detailEquipBtn.Size = UDim2.new(0, 140, 0, 38)
detailEquipBtn.Position = UDim2.new(1, -162, 1, -52)
detailEquipBtn.BackgroundColor3 = THEME.green
detailEquipBtn.AutoButtonColor = false
detailEquipBtn.Font = Enum.Font.LuckiestGuy
detailEquipBtn.TextSize = 17
detailEquipBtn.TextColor3 = Color3.new(1, 1, 1)
detailEquipBtn.TextStrokeTransparency = 0
detailEquipBtn.TextStrokeColor3 = THEME.stroke
detailEquipBtn.Text = "EQUIP"
detailEquipBtn.ZIndex = 122
detailEquipBtn.Parent = detailPanel
UITheme.ApplyCorner(detailEquipBtn, UITheme.Sizes.CornerMedium)
UITheme.ApplyStroke(detailEquipBtn, THEME.stroke, 4)

local selectedDetailEntry = nil

local function getHighestUnlockedWorldIndex()
	local unlocked = ColorData.getUnlockedColorSet(unlockedColorsValue and unlockedColorsValue.Value or "Red")
	local highest = 1
	for index, world in ipairs(ColorData.Worlds or {}) do
		if unlocked[world.primaryColor] then
			highest = index
		end
	end
	return highest
end

local function isFeatureUnlocked(featureName)
	if featureName == "Mutations" or featureName == "Mutation" then
		local progress = player:FindFirstChild("TutorialProgress")
		local unlocked = progress and progress:FindFirstChild("MutationsUnlocked")
		return unlocked and unlocked:IsA("BoolValue") and unlocked.Value == true
	end

	local requiredIndex = GameBalance.getFeatureUnlockWorldIndex
		and GameBalance.getFeatureUnlockWorldIndex(featureName)
		or 1
	return getHighestUnlockedWorldIndex() >= requiredIndex
end

local function getFeatureUnlockText(featureName)
	if GameBalance.getFeatureUnlockText then
		return GameBalance.getFeatureUnlockText(featureName)
	end
	return "Unlocks later"
end

-- ========================
--   FEEDBACK POPUP (defined FIRST so card builders can use it)
-- ========================
local function showItemFeedback(success, message, color)
	local popColor = color
		or (success and Color3.fromRGB(100,210,130) or Color3.fromRGB(255,130,150))

	local popup = Instance.new("Frame")
	popup.Size             = UDim2.new(0, 340, 0, 68)
	popup.Position         = UDim2.new(0.5, -170, 0, -80)
	popup.BackgroundColor3 = Color3.fromRGB(255,248,252)
	popup.BorderSizePixel  = 0
	popup.ZIndex           = 300
	popup.Parent           = screenGui
	local popCorner = Instance.new("UICorner")
	popCorner.CornerRadius = UDim.new(0, 16)
	popCorner.Parent       = popup
	local popStroke = Instance.new("UIStroke")
	popStroke.Color     = popColor
	popStroke.Thickness = 3
	popStroke.Parent    = popup

	local strip = Instance.new("Frame")
	strip.Size             = UDim2.new(0, 58, 1, 0)
	strip.BackgroundColor3 = popColor
	strip.BorderSizePixel  = 0
	strip.ZIndex           = 301
	strip.Parent           = popup
	local sCorner = Instance.new("UICorner")
	sCorner.CornerRadius = UDim.new(0, 16)
	sCorner.Parent       = strip

	local iconL = Instance.new("TextLabel")
	iconL.Size                   = UDim2.new(0, 58, 1, 0)
	iconL.BackgroundTransparency = 1
	iconL.Font                   = Enum.Font.LuckiestGuy
	iconL.TextSize               = 28
	iconL.TextColor3             = Color3.new(1,1,1)
	iconL.Text                   = success and "OK" or "NO"
	iconL.ZIndex                 = 302
	iconL.Parent                 = popup

	local msgL = Instance.new("TextLabel")
	msgL.Size                   = UDim2.new(1,-68,1,0)
	msgL.Position               = UDim2.new(0,64,0,0)
	msgL.BackgroundTransparency = 1
	msgL.Font                   = Enum.Font.GothamBold
	msgL.TextSize               = 13
	msgL.TextWrapped            = true
	msgL.TextXAlignment         = Enum.TextXAlignment.Left
	msgL.TextColor3             = THEME.titleText
	msgL.Text                   = message
	msgL.ZIndex                 = 302
	msgL.Parent                 = popup

	TweenService:Create(popup, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
		Position = UDim2.new(0.5,-170,0,80)
	}):Play()
	task.wait(2.5)
	TweenService:Create(popup, TweenInfo.new(0.2), {
		Position = UDim2.new(0.5,-170,0,-80)
	}):Play()
	task.wait(0.2)
	if popup and popup.Parent then popup:Destroy() end
end

-- ========================
--   HELPERS
-- ========================
local refreshContent
local showColorDetails

local function getEntryKey(entry)
	if typeof(entry) == "table" then
		return entry.variantKey or entry.petId
	end
	return entry
end

local function parsePetInventoryValue(value)
	local entries = {}
	if not value or value == "" then
		return entries
	end

	for _, encoded in ipairs(string.split(value, ",")) do
		local segments = string.split(encoded, ":")
		local variantKey
		local petId
		local stackIndex
		if tonumber(segments[2]) then
			petId = segments[1]
			stackIndex = 2
		else
			variantKey = segments[1]
			petId = segments[2]
			stackIndex = 3
		end

		if petId and petId ~= "" then
			local stackAmount = tonumber(segments[stackIndex]) or 1
			local traitId = PetData.normalizeTraitId(segments[stackIndex + 1])
			local shinyStr = segments[stackIndex + 2] or "normal"
			local personalityId = PetData.normalizePersonalityId(segments[stackIndex + 3] or "Neutral")
			local mutationId = PetData.normalizeMutationId(segments[stackIndex + 4] or "None")
			variantKey = variantKey or PetData.makeVariantKey(petId, personalityId, mutationId, traitId)

			local entry = PetData.buildPetEntry(
				petId,
				math.max(1, stackAmount),
				shinyStr == "shiny" or shinyStr == "true",
				personalityId,
				mutationId,
				traitId
			)
			if entry then
				entry.variantKey = variantKey
				entry.effectivePower = entry.finalPower
				table.insert(entries, entry)
			end
		end
	end

	return entries
end

local function parseEquippedValue(value)
	local equipped = {}
	if not value or value == "" then
		return equipped
	end

	for _, variantKey in ipairs(string.split(value, ",")) do
		if variantKey ~= "" then
			table.insert(equipped, variantKey)
		end
	end
	return equipped
end

local function resetHiddenColorFiltersForNewItems()
	if currentFilter == "Equipped" or currentFilter == "Favorites" then
		currentFilter = "All"
		filterIdx = 1
		filterBtn.Text = "Filter: All V"
	end
end

local function applyPetState(inventory, equipped)
	inventory = inventory or {}
	equipped = equipped or {}

	if #inventory == 0 and #allPets > 0 and os.clock() - lastPetStateAt < 1.5 then
		if isOpen then refreshContent() end
		warn("InventoryUI: ignored a transient empty Color inventory update.")
		return
	end

	local prevIds = {}
	for _, entry in ipairs(allPets) do
		prevIds[getEntryKey(entry)] = true
	end

	allPets = inventory
	equippedPets = equipped
	lastPetStateAt = os.clock()

	local hasNewItem = false
	for _, entry in ipairs(allPets) do
		local key = getEntryKey(entry)
		if not prevIds[key] then
			newItems[key] = true
			hasNewItem = true
		end
	end

	if hasNewItem then
		resetHiddenColorFiltersForNewItems()
	end

	if isOpen then refreshContent() end
	if detailPanel.Visible and selectedDetailEntry then
		local selectedKey = getEntryKey(selectedDetailEntry)
		for _, entry in ipairs(allPets) do
			if getEntryKey(entry) == selectedKey then
				showColorDetails(entry)
				break
			end
		end
	end
end

local function refreshPetsFromReplicatedValues()
	if not petInventoryValue then
		return
	end

	applyPetState(
		parsePetInventoryValue(petInventoryValue.Value),
		parseEquippedValue(petEquippedValue and petEquippedValue.Value or "")
	)
end

local function getEntryPower(entry)
	return entry.effectivePower or entry.finalPower or 0
end

local function isEquipped(entryOrKey)
	local key = getEntryKey(entryOrKey)
	for _, id in ipairs(equippedPets) do
		if id == key then return true end
		if typeof(entryOrKey) == "table" and type(id) == "string" then
			local parts = string.split(id, "|")
			if #parts >= 3 and parts[1] == entryOrKey.petId then
				local mutationMatches = PetData.normalizeMutationId(parts[3]) == PetData.normalizeMutationId(entryOrKey.mutationId)
				local traitMatches = PetData.normalizeTraitId(parts[2]) == PetData.normalizeTraitId(entryOrKey.traitId)
					or (PetData.normalizeTraitId(parts[2]) == "Neutral" and PetData.normalizeTraitId(entryOrKey.traitId) == "Neutral")
				if mutationMatches and traitMatches then
					return true
				end
			elseif id == entryOrKey.petId then
				return true
			end
		end
	end
	return false
end

local function clearEquippedOnlyView()
	if currentFilter == "Equipped" then
		currentFilter = "All"
		filterIdx = 1
		filterBtn.Text = "Filter: All V"
	end
end

local function getMaxSlots()
	local pf = player:FindFirstChild("PetData")
	if pf then
		local v = pf:FindFirstChild("MaxSlots")
		if v then return v.Value end
	end
	return 3
end

local function getOwnedPaintToolSet()
	local set = { StarterBrush = true }
	local csv = ownedPaintToolsValue and ownedPaintToolsValue.Value or "StarterBrush"
	for _, toolId in ipairs(string.split(csv, ",")) do
		if toolId ~= "" then
			set[toolId] = true
		end
	end
	return set
end

local function getEquippedPaintToolId()
	return equippedPaintToolValue and equippedPaintToolValue.Value ~= "" and equippedPaintToolValue.Value or "StarterBrush"
end

local function setItemQuantity(itemId, quantity)
	if not itemId then
		return
	end

	quantity = tonumber(quantity) or 0
	if quantity <= 0 then
		playerItems[itemId] = nil
	else
		playerItems[itemId] = quantity
	end
end

local function applyModalLayer()
	panel.ZIndex = 60
	for _, obj in ipairs(panel:GetDescendants()) do
		if obj:IsA("GuiObject") and obj.ZIndex < 61 then
			obj.ZIndex = 61
		end
	end
	emptyLabel.ZIndex = 66
end

local function formatMultiplier(value)
	value = tonumber(value) or 1
	return "x" .. string.format("%.2f", value)
end

function showColorDetails(entry)
	if not entry then
		return
	end

	selectedDetailEntry = entry
	local pet = PetData.Pets[entry.petId] or {
		displayName = "Unknown Color",
		rarity = "Unknown",
		color = entry.baseColor or entry.auraColor or Color3.fromRGB(170, 180, 205),
	}
	local rarityColor = RARITY_COLOR[entry.rarity] or THEME.titleText
	local hasMutation = entry.hasMutation == true
	local definition = PetDefinitions.Get(entry.petId)
	local iconColor = definition and definition.IconColor or pet.color
	local accentColor = definition and definition.AccentColor or rarityColor
	local auraColor = hasMutation and (entry.auraColor or rarityColor) or accentColor
	local equipped = isEquipped(entry)

	detailTitle.Text = hasMutation and "MUTATED COLOR" or "COLOR DETAILS"
	detailHeader.BackgroundColor3 = hasMutation and auraColor or UITheme.Colors.PrimaryPurple
	detailOrb.BackgroundColor3 = iconColor
	detailAura.BackgroundColor3 = auraColor
	detailAura.BackgroundTransparency = hasMutation and 0.58 or 0.82
	detailStack.Text = "x" .. PetData.formatStack(entry.stackAmount or 1)

	detailName.Text = tostring(entry.displayName or pet.displayName)
	detailName.TextColor3 = hasMutation and auraColor or THEME.titleText
	detailMeta.Text = tostring(entry.rarity or pet.rarity) .. " - " .. tostring(entry.currentStackTier or "Normal")
	detailMeta.TextColor3 = rarityColor
	detailPower.Text = "POWER " .. tostring(getEntryPower(entry))

	local traitName = tostring(entry.traitName or entry.personalityName or "Neutral")
	local traitDescription = tostring(entry.traitDescription or entry.personalityDescription or "No special bonus.")
	if isFeatureUnlocked("Traits") then
		detailTrait.Visible = true
		detailTrait.Text = "TRAIT: " .. traitName .. "\n" .. traitDescription
		detailTrait.BackgroundColor3 = (entry.traitTextColor or entry.personalityColor or UITheme.Colors.PrimaryBlue):Lerp(Color3.new(1, 1, 1), 0.72)
	else
		detailTrait.Visible = false
	end

	local mutationName = hasMutation and tostring(entry.mutationName or "Mutation") or "Normal"
	local mutationDescription = hasMutation and tostring(entry.mutationDescription or "Special mutation bonus.") or "No mutation on this Color."
	if hasMutation then
		detailMutation.Visible = true
		detailMutation.Text = tostring(entry.mutationType or "Mutation") .. " MUTATION: " .. mutationName .. "\n" .. mutationDescription
		detailMutation.BackgroundColor3 = hasMutation
			and auraColor:Lerp(Color3.new(1, 1, 1), 0.68)
			or UITheme.Colors.PanelLavender
	else
		detailMutation.Visible = false
	end

	local statLines = {
		"Color Gain: " .. formatMultiplier(entry.colorMult or 1),
		"Sell Value: " .. formatMultiplier(entry.coinMult or 1),
	}
	if isFeatureUnlocked("Traits") then
		table.insert(statLines, "Trait: " .. traitName)
	end
	if hasMutation then
		table.insert(statLines, "Mutation: " .. mutationName)
	end
	detailStats.Text = table.concat(statLines, "\n")

	detailEquipBtn.Text = equipped and "UNEQUIP" or "EQUIP"
	detailEquipBtn.BackgroundColor3 = equipped and THEME.red or THEME.green

	detailPanel.Visible = true
	detailPanel.Size = UDim2.new(0, 480, 0, 430)
	TweenService:Create(detailPanel, TweenInfo.new(0.18, Enum.EasingStyle.Back), {
		Size = UDim2.new(0, 520, 0, 470),
	}):Play()
end

detailCloseBtn.MouseButton1Click:Connect(function()
	detailPanel.Visible = false
	selectedDetailEntry = nil
end)

detailEquipBtn.MouseButton1Click:Connect(function()
	local entry = selectedDetailEntry
	if not entry then
		return
	end

	local variantKey = getEntryKey(entry)
	if isEquipped(entry) then
		equipEvent:FireServer("unequip", variantKey)
	else
		equipEvent:FireServer("equip", variantKey)
	end
	detailPanel.Visible = false
	selectedDetailEntry = nil
end)

-- ========================
--   BUILD PET CARD
-- ========================
local function buildPetCard(entry)
	local pet = PetData.Pets[entry.petId] or {
		displayName = "Unknown Color",
		rarity = "Unknown",
		color = entry.baseColor or entry.auraColor or Color3.fromRGB(170, 180, 205),
	}
	local tierName    = entry.currentStackTier or "Normal"
	local tierColor   = TIER_COLOR[tierName]   or Color3.fromRGB(200,200,200)
	local rarityColor = RARITY_COLOR[entry.rarity] or Color3.fromRGB(160,160,160)
	local isTierUp    = tierName ~= "Normal"
	local variantKey  = getEntryKey(entry)
	local hasMutation = entry.hasMutation == true
	local definition = PetDefinitions.Get(entry.petId)
	local iconColor = definition and definition.IconColor or pet.color
	local cardColor = definition and definition.CardColor or THEME.cardBg
	local accentColor = definition and definition.AccentColor or rarityColor
	local useRainbowGradient = definition and definition.UseRainbowGradient == true
	local mainColor   = hasMutation and (entry.auraColor or rarityColor) or (isTierUp and tierColor or accentColor)
	local equipped    = isEquipped(entry)
	local mergeInfo   = PetData.getMergeInfo(entry.stackAmount)
	local canMerge    = mergeInfo.canMerge == true
	local mergeUnlocked = isFeatureUnlocked("Merge")
	local showMergeButton = mergeUnlocked and canMerge
	local traitsUnlocked = isFeatureUnlocked("Traits")
	local mutationsUnlocked = isFeatureUnlocked("Mutations")

	local card = Instance.new("TextButton")
	card.Size             = UDim2.new(0,148,0,190)
	card.BackgroundColor3 = (isTierUp or hasMutation)
		and entry.auraColor:Lerp(Color3.new(1,1,1),0.85)
		or  cardColor
	card.AutoButtonColor  = false
	card.Text             = ""
	card.BorderSizePixel  = 0
	card.ZIndex           = 44
	card.Parent           = contentScroll
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0,16)
	cc.Parent       = card
	local cs = Instance.new("UIStroke")
	cs.Color     = equipped and mainColor or THEME.stroke
	cs.Thickness = equipped and 5 or 3
	cs.Parent    = card

	local cardH = Instance.new("Frame")
	cardH.Size             = UDim2.new(1,0,0,70)
	cardH.BackgroundColor3 = mainColor:Lerp(Color3.new(1,1,1),0.35)
	cardH.BorderSizePixel  = 0
	cardH.ZIndex           = 45
	cardH.Parent           = card
	Instance.new("UICorner").Parent = cardH
	if useRainbowGradient then
		local headerGradient = Instance.new("UIGradient")
		headerGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 76, 98)),
			ColorSequenceKeypoint.new(0.18, Color3.fromRGB(255, 160, 52)),
			ColorSequenceKeypoint.new(0.36, Color3.fromRGB(255, 232, 80)),
			ColorSequenceKeypoint.new(0.54, Color3.fromRGB(80, 230, 130)),
			ColorSequenceKeypoint.new(0.72, Color3.fromRGB(80, 215, 255)),
			ColorSequenceKeypoint.new(0.9, Color3.fromRGB(160, 105, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 125, 220)),
		})
		headerGradient.Rotation = 18
		headerGradient.Parent = cardH
	end

	local petBall = Instance.new("Frame")
	petBall.Size             = UDim2.new(0,62,0,62)
	petBall.Position         = UDim2.new(0.5,-31,0.5,-31)
	petBall.BackgroundColor3 = (hasMutation or entry.isShiny) and (entry.auraColor or iconColor) or iconColor
	petBall.BorderSizePixel  = 0
	petBall.BackgroundTransparency = 0
	petBall.ZIndex           = 46
	petBall.Parent           = cardH
	local pbc = Instance.new("UICorner")
	pbc.CornerRadius = UDim.new(0.5,0)
	pbc.Parent       = petBall
	local pbs = Instance.new("UIStroke")
	pbs.Color     = Color3.new(1,1,1)
	pbs.Thickness = 2.5
	pbs.Parent    = petBall

	local preview = Instance.new("ViewportFrame")
	preview.Name = "PetModelPreview"
	preview.Size = UDim2.new(1, 10, 1, 10)
	preview.Position = UDim2.new(0, -5, 0, -5)
	preview.BackgroundTransparency = 1
	preview.Ambient = Color3.fromRGB(210, 220, 255)
	preview.LightColor = Color3.fromRGB(255, 255, 245)
	preview.LightDirection = Vector3.new(-0.4, -0.7, -0.3)
	preview.ZIndex = 48
	preview.Parent = petBall
	local previewModel = PetModelUtil.MountViewport(preview, entry.petId, {
		targetSize = 3.2,
		cameraY = 0.45,
		cameraZ = 6.4,
		fieldOfView = 30,
	})
	if previewModel then
		petBall.BackgroundTransparency = 1
		pbs.Transparency = 0.25
	end

	if TIER_ICON[tierName] ~= "" then
		local ti = Instance.new("TextLabel")
		ti.Size                   = UDim2.new(1,0,1,0)
		ti.BackgroundTransparency = 1
		ti.Font                   = Enum.Font.LuckiestGuy
		ti.TextSize               = 22
		ti.TextColor3             = tierColor
		ti.TextStrokeTransparency = 0.2
		ti.TextStrokeColor3       = Color3.new(0,0,0)
		ti.Text                   = TIER_ICON[tierName]
		ti.ZIndex                 = 47
		ti.Parent                 = petBall
	end

	if equipped then
		local eb = Instance.new("TextLabel")
		eb.Size             = UDim2.new(0,44,0,18)
		eb.Position         = UDim2.new(0,4,0,4)
		eb.BackgroundColor3 = THEME.green
		eb.BorderSizePixel  = 0
		eb.Font             = Enum.Font.LuckiestGuy
		eb.TextSize         = 10
		eb.TextColor3       = Color3.new(1,1,1)
		eb.TextStrokeTransparency = 0
		eb.TextStrokeColor3 = THEME.stroke
		eb.Text             = "ON"
		eb.ZIndex           = 47
		eb.Parent           = card
		Instance.new("UICorner").Parent = eb
	end

	if hasMutation then
		local mutationBadge = Instance.new("TextLabel")
		mutationBadge.Size = UDim2.new(0, 86, 0, 20)
		mutationBadge.Position = UDim2.new(0, 4, 0, 48)
		mutationBadge.BackgroundColor3 = entry.mutationTypeColor or entry.auraColor or mainColor
		mutationBadge.BorderSizePixel = 0
		mutationBadge.Font = Enum.Font.LuckiestGuy
		mutationBadge.TextSize = 10
		mutationBadge.TextColor3 = Color3.new(1, 1, 1)
		mutationBadge.TextStrokeTransparency = 0.35
		mutationBadge.TextStrokeColor3 = THEME.stroke
		mutationBadge.Text = string.upper(tostring(entry.mutationType or "MUTATED"))
		mutationBadge.ZIndex = 49
		mutationBadge.Parent = card
		Instance.new("UICorner").Parent = mutationBadge
		local mutationBadgeStroke = Instance.new("UIStroke")
		mutationBadgeStroke.Color = Color3.new(1, 1, 1)
		mutationBadgeStroke.Thickness = 1.5
		mutationBadgeStroke.Transparency = 0.15
		mutationBadgeStroke.Parent = mutationBadge
	end

	if newItems[variantKey] then
		local nb = Instance.new("TextLabel")
		nb.Size             = UDim2.new(0,36,0,18)
		nb.Position         = UDim2.new(1,-40,0,4)
		nb.BackgroundColor3 = Color3.fromRGB(255,80,80)
		nb.BorderSizePixel  = 0
		nb.Font             = Enum.Font.LuckiestGuy
		nb.TextSize         = 10
		nb.TextColor3       = Color3.new(1,1,1)
		nb.Text             = "NEW"
		nb.ZIndex           = 48
		nb.Parent           = card
		Instance.new("UICorner").Parent = nb
	end

	local sb = Instance.new("TextLabel")
	sb.Size             = UDim2.new(0,52,0,20)
	sb.Position         = UDim2.new(1,-58,0,46)
	sb.BackgroundColor3 = isTierUp and tierColor or rarityColor
	sb.BorderSizePixel  = 0
	sb.Font             = Enum.Font.LuckiestGuy
	sb.TextSize         = 12
	sb.TextColor3       = Color3.new(1,1,1)
	sb.TextStrokeTransparency = 0.4
	sb.TextStrokeColor3 = Color3.new(0,0,0)
	sb.Text             = "x"..PetData.formatStack(entry.stackAmount or 1)
	sb.ZIndex           = 47
	sb.Parent           = card
	Instance.new("UICorner").Parent = sb

	local nl = Instance.new("TextLabel")
	nl.Size                   = UDim2.new(1,-8,0,20)
	nl.Position               = UDim2.new(0,4,0,74)
	nl.BackgroundTransparency = 1
	nl.Font                   = Enum.Font.LuckiestGuy
	nl.TextSize               = 12
	nl.TextScaled             = true
	nl.TextColor3             = isTierUp and tierColor or THEME.titleText
	nl.Text                   = entry.displayName or pet.displayName
	nl.ZIndex                 = 45
	nl.Parent                 = card
	UITheme.ApplyTextSizeConstraint(nl, 10, 14)

	local rl = Instance.new("TextLabel")
	rl.Size                   = UDim2.new(1,-8,0,13)
	rl.Position               = UDim2.new(0,4,0,95)
	rl.BackgroundTransparency = 1
	rl.Font                   = Enum.Font.GothamBold
	rl.TextSize               = 10
	rl.TextColor3             = rarityColor
	rl.Text                   = entry.rarity
	rl.ZIndex                 = 45
	rl.Parent                 = card

	local pl = Instance.new("TextLabel")
	pl.Size                   = UDim2.new(1,-8,0,13)
	pl.Position               = UDim2.new(0,4,0,109)
	pl.BackgroundTransparency = 1
	pl.Font                   = Enum.Font.GothamBold
	pl.TextSize               = 10
	pl.TextColor3             = THEME.subtext
	pl.Text                   = "Power "..getEntryPower(entry)
	pl.ZIndex                 = 45
	pl.Parent                 = card

	if traitsUnlocked then
		local traitL = Instance.new("TextLabel")
		traitL.Size                   = UDim2.new(1,-8,0,13)
		traitL.Position               = UDim2.new(0,4,0,123)
		traitL.BackgroundTransparency = 1
		traitL.Font                   = Enum.Font.GothamBold
		traitL.TextSize               = 10
		traitL.TextColor3             = entry.traitTextColor or entry.personalityColor or THEME.titleText
		traitL.Text                   = "Trait: " .. tostring(entry.traitName or entry.personalityName or "Neutral")
		traitL.ZIndex                 = 45
		traitL.Parent                 = card
	end

	if hasMutation then
		local mutationL = Instance.new("TextLabel")
		mutationL.Size                   = UDim2.new(1,-8,0,13)
		mutationL.Position               = UDim2.new(0,4,0,137)
		mutationL.BackgroundTransparency = 1
		mutationL.Font                   = Enum.Font.GothamBold
		mutationL.TextSize               = 10
		mutationL.TextColor3             = entry.auraColor or THEME.yellow
		mutationL.Text                   = tostring(entry.mutationName or "Mutation")
		mutationL.ZIndex                 = 45
		mutationL.Parent                 = card
	end

	-- Progress bar to next tier
	local nextTierIdx = nil
	for i, tier in ipairs(PetData.StackTiers) do
		if tier.name == tierName and i < #PetData.StackTiers then
			nextTierIdx = i + 1 break
		end
	end
	if nextTierIdx then
		local nt   = PetData.StackTiers[nextTierIdx]
		local pt   = PetData.StackTiers[nextTierIdx-1]
		local prog = math.clamp(((entry.stackAmount or 1)-pt.minStack)/(nt.minStack-pt.minStack),0,1)
		local pgBg = Instance.new("Frame")
		pgBg.Size             = UDim2.new(1,-10,0,6)
		pgBg.Position         = UDim2.new(0,5,0,153)
		pgBg.BackgroundColor3 = Color3.new(1,1,1)
		pgBg.BackgroundTransparency = 0.4
		pgBg.BorderSizePixel  = 0
		pgBg.ZIndex           = 45
		pgBg.Parent           = card
		Instance.new("UICorner").Parent = pgBg
		local pgF = Instance.new("Frame")
		pgF.Size             = UDim2.new(prog,0,1,0)
		pgF.BackgroundColor3 = TIER_COLOR[nt.name] or rarityColor
		pgF.BorderSizePixel  = 0
		pgF.ZIndex           = 46
		pgF.Parent           = pgBg
		Instance.new("UICorner").Parent = pgF
		local pgL = Instance.new("TextLabel")
		pgL.Size                   = UDim2.new(1,-8,0,12)
		pgL.Position               = UDim2.new(0,4,0,161)
		pgL.BackgroundTransparency = 1
		pgL.Font                   = Enum.Font.Gotham
		pgL.TextSize               = 9
		pgL.TextColor3             = TIER_COLOR[nt.name] or rarityColor
		pgL.TextXAlignment         = Enum.TextXAlignment.Left
		pgL.Text                   = nt.name.." @ x"..PetData.formatStack(nt.minStack)
		pgL.ZIndex                 = 45
		pgL.Parent                 = card
	end

	local btnBg = equipped and THEME.red or THEME.green
	local btnTc = equipped and Color3.fromRGB(140,20,40)   or Color3.fromRGB(15,90,30)

	if showMergeButton then
		local mergeBtn = Instance.new("TextButton")
		mergeBtn.Size             = UDim2.new(0.5, -7, 0, 22)
		mergeBtn.Position         = UDim2.new(0, 5, 1, -26)
		mergeBtn.BackgroundColor3 = THEME.yellow
		mergeBtn.AutoButtonColor  = false
		mergeBtn.Font             = Enum.Font.LuckiestGuy
		mergeBtn.TextSize         = 12
		mergeBtn.TextColor3       = Color3.new(1,1,1)
		mergeBtn.TextStrokeTransparency = 0
		mergeBtn.TextStrokeColor3 = THEME.stroke
		mergeBtn.Text             = "MERGE"
		mergeBtn.ZIndex           = 46
		mergeBtn.Parent           = card
		local mergeCorner = Instance.new("UICorner")
		mergeCorner.CornerRadius = UDim.new(0,8)
		mergeCorner.Parent       = mergeBtn
		local mergeStroke = Instance.new("UIStroke")
		mergeStroke.Color     = THEME.stroke
		mergeStroke.Thickness = 3
		mergeStroke.Parent    = mergeBtn

		mergeBtn.MouseButton1Click:Connect(function()
			newItems[variantKey] = nil
			mergeEvent:FireServer(variantKey)
		end)
	end

	local eqBtn = Instance.new("TextButton")
	eqBtn.Size             = showMergeButton and UDim2.new(0.5,-7,0,22) or UDim2.new(1,-10,0,22)
	eqBtn.Position         = showMergeButton and UDim2.new(0.5,2,1,-26) or UDim2.new(0,5,1,-26)
	eqBtn.BackgroundColor3 = btnBg
	eqBtn.AutoButtonColor  = false
	eqBtn.Font             = Enum.Font.LuckiestGuy
	eqBtn.TextSize         = 12
	eqBtn.TextColor3       = Color3.new(1,1,1)
	eqBtn.TextStrokeTransparency = 0
	eqBtn.TextStrokeColor3 = THEME.stroke
	eqBtn.Text             = equipped and "UNEQUIP" or "EQUIP"
	eqBtn.ZIndex           = 46
	eqBtn.Parent           = card
	local eqc = Instance.new("UICorner")
	eqc.CornerRadius = UDim.new(0,8)
	eqc.Parent       = eqBtn
	local eqs = Instance.new("UIStroke")
	eqs.Color     = THEME.stroke
	eqs.Thickness = 3
	eqs.Parent    = eqBtn

	eqBtn.MouseButton1Click:Connect(function()
		newItems[variantKey] = nil
		if equipped then
			clearEquippedOnlyView()
			equipEvent:FireServer("unequip", variantKey)
		else
			equipEvent:FireServer("equip", variantKey)
		end
	end)

	card.MouseEnter:Connect(function()
		TweenService:Create(card, TweenInfo.new(0.12, Enum.EasingStyle.Back), {
			BackgroundColor3 = card.BackgroundColor3:Lerp(Color3.new(1, 1, 1), 0.08)
		}):Play()
	end)
	card.MouseLeave:Connect(function()
		TweenService:Create(card, TweenInfo.new(0.12), {
			BackgroundColor3 = (isTierUp or hasMutation)
				and entry.auraColor:Lerp(Color3.new(1,1,1),0.85)
				or THEME.cardBg
		}):Play()
	end)
	card.MouseButton1Click:Connect(function()
		showColorDetails(entry)
	end)
end

-- ========================
--   BUILD ITEM CARD
-- ========================
local function buildItemCard(itemId, quantity)
	local item = ItemsData.Items[itemId]
	if not item then return end
	local rarityColor = RARITY_COLOR[item.rarity] or Color3.fromRGB(160,160,160)

	local card = Instance.new("Frame")
	card.Size             = UDim2.new(0,140,0,165)
	card.BackgroundColor3 = THEME.cardBg
	card.BorderSizePixel  = 0
	card.ZIndex           = 44
	card.Parent           = contentScroll
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0,16)
	cc.Parent       = card
	local cs = Instance.new("UIStroke")
	cs.Color     = THEME.stroke
	cs.Thickness = 3
	cs.Parent    = card

	local cardH = Instance.new("Frame")
	cardH.Size             = UDim2.new(1,0,0,70)
	cardH.BackgroundColor3 = rarityColor:Lerp(Color3.new(1,1,1),0.4)
	cardH.BorderSizePixel  = 0
	cardH.ZIndex           = 45
	cardH.Parent           = card
	Instance.new("UICorner").Parent = cardH

	local iconL = Instance.new("TextLabel")
	iconL.Size                   = UDim2.new(1,0,1,0)
	iconL.BackgroundTransparency = 1
	iconL.Font                   = Enum.Font.LuckiestGuy
	iconL.TextSize               = 38
	iconL.TextColor3             = Color3.new(1,1,1)
	iconL.TextStrokeTransparency = 0.2
	iconL.Text                   = item.icon
	iconL.ZIndex                 = 46
	iconL.Parent                 = cardH

	local qb = Instance.new("TextLabel")
	qb.Size             = UDim2.new(0,52,0,20)
	qb.Position         = UDim2.new(0,4,0,4)
	qb.BackgroundColor3 = rarityColor
	qb.BorderSizePixel  = 0
	qb.Font             = Enum.Font.LuckiestGuy
	qb.TextSize         = 12
	qb.TextColor3       = Color3.new(1,1,1)
	qb.TextStrokeTransparency = 0.4
	qb.Text             = "x"..ItemsData.formatNum(quantity)
	qb.ZIndex           = 47
	qb.Name             = "QtyBadge"
	qb.Parent           = card
	Instance.new("UICorner").Parent = qb

	local nl = Instance.new("TextLabel")
	nl.Size                   = UDim2.new(1,-8,0,20)
	nl.Position               = UDim2.new(0,4,0,74)
	nl.BackgroundTransparency = 1
	nl.Font                   = Enum.Font.LuckiestGuy
	nl.TextSize               = 12
	nl.TextScaled             = true
	nl.TextColor3             = THEME.titleText
	nl.Text                   = item.displayName
	nl.ZIndex                 = 45
	nl.Parent                 = card
	UITheme.ApplyTextSizeConstraint(nl, 10, 14)

	local rl = Instance.new("TextLabel")
	rl.Size                   = UDim2.new(1,-8,0,13)
	rl.Position               = UDim2.new(0,4,0,95)
	rl.BackgroundTransparency = 1
	rl.Font                   = Enum.Font.GothamBold
	rl.TextSize               = 10
	rl.TextColor3             = rarityColor
	rl.Text                   = item.rarity
	rl.ZIndex                 = 45
	rl.Parent                 = card

	local dl = Instance.new("TextLabel")
	dl.Size                   = UDim2.new(1,-8,0,30)
	dl.Position               = UDim2.new(0,4,0,109)
	dl.BackgroundTransparency = 1
	dl.Font                   = Enum.Font.Gotham
	dl.TextSize               = 9
	dl.TextWrapped            = true
	dl.TextColor3             = THEME.subtext
	dl.TextXAlignment         = Enum.TextXAlignment.Left
	dl.TextYAlignment         = Enum.TextYAlignment.Top
	dl.Text                   = item.description
	dl.ZIndex                 = 45
	dl.Parent                 = card

	local btnBg = item.usable
		and THEME.green
		or  THEME.lavender
	local btnTc = item.usable
		and Color3.fromRGB(15,90,30)
		or  Color3.fromRGB(130,130,150)

	local useBtn = Instance.new("TextButton")
	useBtn.Size             = item.boostType and UDim2.new(0,40,0,22) or UDim2.new(1,-10,0,22)
	useBtn.Position         = UDim2.new(0,5,1,-26)
	useBtn.BackgroundColor3 = btnBg
	useBtn.AutoButtonColor  = false
	useBtn.Font             = Enum.Font.LuckiestGuy
	useBtn.TextSize         = 12
	useBtn.TextColor3       = Color3.new(1,1,1)
	useBtn.TextStrokeTransparency = 0
	useBtn.TextStrokeColor3 = THEME.stroke
	useBtn.Text             = item.usable and "USE" or "LOCKED"
	useBtn.ZIndex           = 46
	useBtn.Parent           = card
	local ubc = Instance.new("UICorner")
	ubc.CornerRadius = UDim.new(0,8)
	ubc.Parent       = useBtn
	local ubs = Instance.new("UIStroke")
	ubs.Color     = THEME.stroke
	ubs.Thickness = 3
	ubs.Parent    = useBtn

	if item.usable then
		local function requestUse(amount)
			local qty = playerItems[itemId] or 0
			if qty <= 0 then
				showItemFeedback(false, "No "..item.displayName.." left!")
				return
			end
			amount = math.clamp(math.floor(tonumber(amount) or 1), 1, qty)
			setItemQuantity(itemId, qty - amount)
			qb.Text = "x"..ItemsData.formatNum(playerItems[itemId] or 0)
			useEvent:FireServer(itemId, amount)
			if (playerItems[itemId] or 0) <= 0 and isOpen then
				refreshContent()
			end
		end

		useBtn.MouseButton1Click:Connect(function()
			requestUse(1)
		end)

		useBtn.MouseEnter:Connect(function()
			TweenService:Create(useBtn, TweenInfo.new(0.1), {
				BackgroundColor3 = Color3.fromRGB(160,235,175)
			}):Play()
		end)
		useBtn.MouseLeave:Connect(function()
			TweenService:Create(useBtn, TweenInfo.new(0.1), {
				BackgroundColor3 = btnBg
			}):Play()
		end)

		if item.boostType then
			local function makeSmallUseButton(text, x, amountGetter)
				local button = Instance.new("TextButton")
				button.Size             = UDim2.new(0,40,0,22)
				button.Position         = UDim2.new(0,x,1,-26)
				button.BackgroundColor3 = THEME.green
				button.AutoButtonColor  = false
				button.Font             = Enum.Font.LuckiestGuy
				button.TextSize         = 11
				button.TextColor3       = Color3.new(1,1,1)
				button.TextStrokeTransparency = 0
				button.TextStrokeColor3 = THEME.stroke
				button.Text             = text
				button.ZIndex           = 46
				button.Parent           = card
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0,8)
				corner.Parent       = button
				local stroke = Instance.new("UIStroke")
				stroke.Color     = THEME.stroke
				stroke.Thickness = 3
				stroke.Parent    = button

				button.MouseButton1Click:Connect(function()
					requestUse(amountGetter())
				end)
				button.MouseEnter:Connect(function()
					TweenService:Create(button, TweenInfo.new(0.1), {
						BackgroundColor3 = Color3.fromRGB(160,235,175)
					}):Play()
				end)
				button.MouseLeave:Connect(function()
					TweenService:Create(button, TweenInfo.new(0.1), {
						BackgroundColor3 = THEME.green
					}):Play()
				end)
			end

			makeSmallUseButton("x5", 50, function()
				return math.min(5, playerItems[itemId] or 0)
			end)
			makeSmallUseButton("ALL", 95, function()
				return playerItems[itemId] or 0
			end)
		end
	end
end

local function buildPaintToolCard(tool)
	local equipped = getEquippedPaintToolId() == tool.Id
	local rarityColor = ToolData.RarityColors[tool.Rarity or "Common"] or Color3.fromRGB(120, 245, 255)

	local card = Instance.new("Frame")
	card.Size             = UDim2.new(0,300,0,190)
	card.BackgroundColor3 = equipped and Color3.fromRGB(232, 255, 252) or THEME.cardBg
	card.BorderSizePixel  = 0
	card.ZIndex           = 44
	card.Parent           = contentScroll
	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0,16)
	cardCorner.Parent = card
	local cs = Instance.new("UIStroke")
	cs.Color     = equipped and rarityColor or THEME.stroke
	cs.Thickness = equipped and 5 or 3
	cs.Parent    = card

	local cardH = Instance.new("Frame")
	cardH.Size             = UDim2.new(0,94,1,0)
	cardH.BackgroundColor3 = rarityColor:Lerp(Color3.new(1,1,1),0.28)
	cardH.BorderSizePixel  = 0
	cardH.ZIndex           = 45
	cardH.Parent           = card
	Instance.new("UICorner").Parent = cardH

	local iconL = Instance.new("TextLabel")
	iconL.Size                   = UDim2.new(1,0,1,0)
	iconL.BackgroundTransparency = 1
	iconL.Font                   = Enum.Font.LuckiestGuy
	iconL.TextSize               = 38
	iconL.TextColor3             = Color3.fromRGB(255, 255, 255)
	iconL.TextStrokeTransparency = 0
	iconL.TextStrokeColor3       = THEME.stroke
	iconL.Text                   = tool.ShortName or "BR"
	iconL.ZIndex                 = 46
	iconL.Parent                 = cardH

	local equippedBadge = Instance.new("TextLabel")
	equippedBadge.Size             = UDim2.new(0,64,0,20)
	equippedBadge.Position         = UDim2.new(0,104,0,10)
	equippedBadge.BackgroundColor3 = equipped and THEME.green or THEME.lavender
	equippedBadge.BorderSizePixel  = 0
	equippedBadge.Font             = Enum.Font.LuckiestGuy
	equippedBadge.TextSize         = 11
	equippedBadge.TextColor3       = Color3.new(1,1,1)
	equippedBadge.TextStrokeTransparency = 0.4
	equippedBadge.Text             = equipped and "EQUIPPED" or "OWNED"
	equippedBadge.ZIndex           = 47
	equippedBadge.Parent           = card
	Instance.new("UICorner").Parent = equippedBadge

	local nl = Instance.new("TextLabel")
	nl.Size                   = UDim2.new(1,-112,0,24)
	nl.Position               = UDim2.new(0,104,0,36)
	nl.BackgroundTransparency = 1
	nl.Font                   = Enum.Font.LuckiestGuy
	nl.TextSize               = 18
	nl.TextScaled             = true
	nl.TextColor3             = THEME.titleText
	nl.Text                   = tool.DisplayName or tool.Id
	nl.ZIndex                 = 45
	nl.Parent                 = card
	UITheme.ApplyTextSizeConstraint(nl, 11, 18)

	local rl = Instance.new("TextLabel")
	rl.Size                   = UDim2.new(1,-112,0,16)
	rl.Position               = UDim2.new(0,104,0,62)
	rl.BackgroundTransparency = 1
	rl.Font                   = Enum.Font.GothamBold
	rl.TextSize               = 10
	rl.TextColor3             = rarityColor
	rl.Text                   = tostring(tool.Rarity or "Tool") .. " Tool"
	rl.ZIndex                 = 45
	rl.Parent                 = card

	local dl = Instance.new("TextLabel")
	dl.Size                   = UDim2.new(1,-112,0,54)
	dl.Position               = UDim2.new(0,104,0,84)
	dl.BackgroundTransparency = 1
	dl.Font                   = Enum.Font.Gotham
	dl.TextSize               = 12
	dl.TextWrapped            = true
	dl.TextColor3             = THEME.subtext
	dl.TextXAlignment         = Enum.TextXAlignment.Left
	dl.TextYAlignment         = Enum.TextYAlignment.Top
	dl.Text                   = tool.Description or "Collects Color from paint."
	dl.ZIndex                 = 45
	dl.Parent                 = card

	local equipBtn = Instance.new("TextButton")
	equipBtn.Size             = UDim2.new(0,170,0,30)
	equipBtn.Position         = UDim2.new(0,104,1,-42)
	equipBtn.BackgroundColor3 = equipped and THEME.red or THEME.green
	equipBtn.AutoButtonColor  = false
	equipBtn.Font             = Enum.Font.LuckiestGuy
	equipBtn.TextSize         = 14
	equipBtn.TextColor3       = Color3.new(1,1,1)
	equipBtn.TextStrokeTransparency = 0
	equipBtn.TextStrokeColor3 = THEME.stroke
	equipBtn.Text             = equipped and "UNEQUIP" or "EQUIP"
	equipBtn.ZIndex           = 46
	equipBtn.Parent           = card
	local equipCorner = Instance.new("UICorner")
	equipCorner.CornerRadius = UDim.new(0,8)
	equipCorner.Parent = equipBtn
	local equipStroke = Instance.new("UIStroke")
	equipStroke.Color = THEME.stroke
	equipStroke.Thickness = 3
	equipStroke.Parent = equipBtn

	equipBtn.MouseButton1Click:Connect(function()
		if equipped then
			paintToolState.Value = false
			paintToolEquipChanged:Fire(false)
			equipPaintToolEvent:FireServer(tool.Id, false)
		else
			paintToolState.Value = true
			paintToolEquipChanged:Fire(true)
			equipPaintToolEvent:FireServer(tool.Id, true)
		end
		refreshContent()
	end)
end

-- ========================
--   SORT / FILTER PETS
-- ========================
local function sortPets(pets)
	local sorted = table.clone(pets)
	local tO = {Celestial=1,Royal=2,Gilded=3,Normal=4}
	local rO = {Legendary=1,Epic=2,Rare=3,Uncommon=4,Common=5}
	table.sort(sorted, function(a, b)
		if currentSort == "Power" then
			return getEntryPower(a) > getEntryPower(b)
		elseif currentSort == "Name" then
			return (a.displayName or "") < (b.displayName or "")
		elseif currentSort == "Rarity" then
			return (rO[a.rarity] or 9) < (rO[b.rarity] or 9)
		elseif currentSort == "Stack" then
			return (a.stackAmount or 0) > (b.stackAmount or 0)
		else
			return (tO[a.currentStackTier] or 4) < (tO[b.currentStackTier] or 4)
		end
	end)
	return sorted
end

local function filterPets(pets)
	local result = {}
	for _, entry in ipairs(pets) do
		local pass = true
		if searchText ~= "" and not (entry.displayName or ""):lower():find(searchText,1,true) then
			pass = false
		end
		if currentFilter == "Equipped"   and not isEquipped(entry)        then pass = false end
		if currentFilter == "Unequipped" and isEquipped(entry)            then pass = false end
		if currentFilter == "Favorites"  and not favorites[getEntryKey(entry)] then pass = false end
		if currentFilter == "Common"     and entry.rarity ~= "Common"     then pass = false end
		if currentFilter == "Uncommon"   and entry.rarity ~= "Uncommon"   then pass = false end
		if currentFilter == "Rare"       and entry.rarity ~= "Rare"       then pass = false end
		if currentFilter == "Epic"       and entry.rarity ~= "Epic"       then pass = false end
		if currentFilter == "Legendary"  and entry.rarity ~= "Legendary"  then pass = false end
		if pass then table.insert(result, entry) end
	end
	return result
end

-- ========================
--   REFRESH CONTENT
-- ========================
function refreshContent()
	for _, c in ipairs(contentScroll:GetChildren()) do
		if not c:IsA("UIGridLayout") and not c:IsA("UIPadding") and not c:IsA("UICorner") and not c:IsA("UIStroke") then
			c:Destroy()
		end
	end

	local count = 0

	if isComingSoonInventoryTab(currentTab) then
		setEmptyPlaceholder("COMING SOON", true)
		updateEmptyLabelLayout()
		contentScroll.CanvasPosition = Vector2.new(0, 0)
		contentScroll.CanvasSize = UDim2.new(0, 0, 0, 50)
		applyModalLayer()
		return
	end

	if currentTab == "Colors" then
		local filtered = filterPets(allPets)
		local sorted   = sortPets(filtered)
		for _, e in ipairs(sorted) do buildPetCard(e) count=count+1 end

	elseif currentTab == "Brushes" then
		local ownedTools = getOwnedPaintToolSet()
		for _, toolId in ipairs(ToolData.Order) do
			local tool = ToolData.Tools[toolId]
			if tool and ownedTools[toolId] then
				if searchText == "" or string.find(string.lower(tool.DisplayName or toolId), searchText, 1, true) then
					buildPaintToolCard(tool)
					count += 1
				end
			end
		end

	else
		for id, qty in pairs(playerItems) do
			local item = ItemsData.Items[id]
			if item and qty > 0 and item.category == currentTab then
				if searchText=="" or item.displayName:lower():find(searchText,1,true) then
					buildItemCard(id, qty) count=count+1
				end
			end
		end
	end
	if count == 0 then
		setEmptyPlaceholder("Nothing here yet!", false)
	else
		emptyLabel.Visible = false
	end
	updateEmptyLabelLayout()
	contentScroll.CanvasPosition = count == 0 and Vector2.new(0, 0) or contentScroll.CanvasPosition

	local padX = contentGrid.CellPadding.X.Offset
	local padY = contentGrid.CellPadding.Y.Offset
	local cellX = math.max(1, contentGrid.CellSize.X.Offset)
	local cellY = math.max(1, contentGrid.CellSize.Y.Offset)
	local availableX = math.max(1, contentScroll.AbsoluteSize.X - contentPad.PaddingLeft.Offset - contentPad.PaddingRight.Offset)
	local columns = math.max(1, math.floor((availableX + padX) / (cellX + padX)))
	local rows = math.ceil(count / columns)
	local canvasHeight = rows > 0 and (rows * cellY + math.max(0, rows - 1) * padY + contentPad.PaddingTop.Offset + contentPad.PaddingBottom.Offset) or 50
	contentScroll.CanvasSize = UDim2.new(0, 0, 0, math.max(canvasHeight, 50))
	applyModalLayer()
end

contentScroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	if isOpen then
		refreshContent()
	else
		updateEmptyLabelLayout()
	end
end)

if ownedPaintToolsValue then
	ownedPaintToolsValue:GetPropertyChangedSignal("Value"):Connect(function()
		if currentTab == "Brushes" then
			refreshContent()
		end
	end)
end

if equippedPaintToolValue then
	equippedPaintToolValue:GetPropertyChangedSignal("Value"):Connect(function()
		if currentTab == "Brushes" then
			refreshContent()
		end
	end)
end

if unlockedColorsValue then
	unlockedColorsValue:GetPropertyChangedSignal("Value"):Connect(function()
		if isOpen then
			refreshContent()
		end
		if detailPanel.Visible and selectedDetailEntry then
			showColorDetails(selectedDetailEntry)
		end
	end)
end

mergeEvent.OnClientEvent:Connect(function(success, _, result)
	if success then
		showItemFeedback(true, "Merged Color!")
	else
		showItemFeedback(false, tostring(result or "Could not merge."))
	end
end)

-- ========================
--   TAB BUTTONS
-- ========================
local tabBtns = {}

local function setTab(name)
	if not tabBtns[name] then
		name = "Colors"
	end
	currentTab = name
	if name == "Brushes" then
		contentGrid.CellSize = UDim2.new(0, 300, 0, 190)
	else
		contentGrid.CellSize = UDim2.new(0, 148, 0, 190)
	end

	for n, b in pairs(tabBtns) do
		if n == name then
			b.BackgroundColor3 = THEME.tabActive
			b.TextColor3       = THEME.buttonText
			b.TextStrokeColor3 = THEME.stroke
			b.TextStrokeTransparency = 0.18
		else
			b.BackgroundColor3 = THEME.tabInact
			b.TextColor3       = THEME.buttonText
			b.TextStrokeColor3 = THEME.stroke
			b.TextStrokeTransparency = 0.18
		end
	end
	actionBar.Visible = name == "Colors"
	refreshContent()
end

for _, tabName in ipairs(TABS) do
	local b = Instance.new("TextButton")
	b.Size             = UDim2.new(0,118,0,32)
	b.BackgroundColor3 = THEME.tabInact
	b.AutoButtonColor  = false
	b.Font             = Enum.Font.GothamBold
	b.TextSize         = 14
	b.TextColor3       = THEME.buttonText
	b.TextStrokeTransparency = 0.18
	b.TextStrokeColor3 = THEME.stroke
	b.Text             = TAB_ICONS[tabName] or tabName:upper()
	b:SetAttribute("NoTextGlow", true)
	b.ZIndex           = 43
	b.Parent           = tabBar
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0,10)
	bc.Parent       = b
	local bs = Instance.new("UIStroke")
	bs.Color     = THEME.stroke
	bs.Thickness = 3
	bs.Parent    = b
	tabBtns[tabName] = b
	b.MouseButton1Click:Connect(function() setTab(tabName) end)
end

-- ========================
--   SEARCH + SORT + FILTER HOOKS
-- ========================
searchBox:GetPropertyChangedSignal("Text"):Connect(function()
	searchText = searchBox.Text:lower()
	refreshContent()
end)

sortBtn.MouseButton1Click:Connect(function()
	sortIdx = (sortIdx % #SORT_OPTIONS) + 1
	currentSort = SORT_OPTIONS[sortIdx]
	sortBtn.Text = "Sort: "..currentSort.." V"
	refreshContent()
end)

filterBtn.MouseButton1Click:Connect(function()
	filterIdx = (filterIdx % #FILTER_OPTIONS) + 1
	currentFilter = FILTER_OPTIONS[filterIdx]
	filterBtn.Text = "Filter: "..currentFilter.." V"
	refreshContent()
end)

-- ========================
--   ACTION BUTTON HOOKS
-- ========================
equipBestBtn.MouseButton1Click:Connect(function()
	local maxSlots = getMaxSlots()
	local sorted = table.clone(allPets)
	table.sort(sorted, function(a, b)
		local aPower = a.effectivePower or a.finalPower or 0
		local bPower = b.effectivePower or b.finalPower or 0
		if aPower == bPower then
			return (a.stackAmount or 0) > (b.stackAmount or 0)
		end
		return aPower > bPower
	end)
	for _, id in ipairs(table.clone(equippedPets)) do
		equipEvent:FireServer("unequip", id)
		task.wait(0.05)
	end
	for i = 1, math.min(maxSlots, #sorted) do
		equipEvent:FireServer("equip", getEntryKey(sorted[i]))
		task.wait(0.05)
	end
end)

unequipAllBtn.MouseButton1Click:Connect(function()
	clearEquippedOnlyView()
	for _, id in ipairs(table.clone(equippedPets)) do
		equipEvent:FireServer("unequip", id)
		task.wait(0.05)
	end
end)

-- ========================
--   OPEN / CLOSE
-- ========================
function toggleInventory(open, context)
	isOpen = open
	if open then
		lastInventoryOpenedAt = os.clock()
		print("Opening NEW Inventory UI:", screenGui:GetFullName())
		if not printedInventoryVersion then
			printedInventoryVersion = true
			print("InventoryUI Loaded: " .. INVENTORY_VERSION)
		end
		screenGui:SetAttribute("InventoryVersion", INVENTORY_VERSION)
		if context ~= nil then
			openedFromMenu = context.from == "Menu"
		end
		if context and context.defaultTab and tabBtns[context.defaultTab] then
			currentTab = context.defaultTab
		elseif currentTab == "Colors" and #allPets == 0 and tabBtns.Brushes then
			currentTab = "Brushes"
		end
		backBtn.Visible = openedFromMenu
		titleL.Position = openedFromMenu and UDim2.new(0, 66, 0, 0) or UDim2.new(0, 22, 0, 0)
		titleL.Size = openedFromMenu and UDim2.new(1, -170, 1, 0) or UDim2.new(1, -116, 1, 0)
		overlay.Visible          = true
		panel.Visible            = true
		overlay.BackgroundTransparency = 1
		panel.Size     = UDim2.new(0,80,0,80)
		panel.Position = UDim2.fromScale(0.5, 0.5)
		TweenService:Create(overlay, TweenInfo.new(0.25), {
			BackgroundTransparency = 0.4
		}):Play()
		TweenService:Create(panel, TweenInfo.new(0.35, Enum.EasingStyle.Back), {
			Size     = UDim2.new(0, PANEL_WIDTH, 0, PANEL_HEIGHT),
			Position = UDim2.fromScale(0.5, 0.5),
		}):Play()
		setTab(currentTab)
	else
		openedFromMenu = false
		backBtn.Visible = false
		detailPanel.Visible = false
		selectedDetailEntry = nil
		if context and context.immediate then
			panel.Visible = false
			overlay.Visible = false
			overlay.BackgroundTransparency = 1
			return
		end
		TweenService:Create(overlay, TweenInfo.new(0.2), {
			BackgroundTransparency = 1
		}):Play()
		TweenService:Create(panel, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			Size     = UDim2.new(0,60,0,60),
			Position = UDim2.fromScale(0.5, 0.5),
		}):Play()
		task.wait(0.2)
		panel.Visible   = false
		overlay.Visible = false
	end
end

backBtn.MouseButton1Click:Connect(function()
	if openedFromMenu then
		UIManager.open("Menu")
	end
end)

local inventoryCloseToken = 0
local function requestInventoryClose()
	if not isOpen then
		return
	end

	inventoryCloseToken += 1
	local token = inventoryCloseToken
	UIManager.close("Inventory")

	task.defer(function()
		if token == inventoryCloseToken and isOpen then
			toggleInventory(false)
		end
	end)
end

closeBtn.Activated:Connect(requestInventoryClose)
closeBtn.MouseButton1Click:Connect(requestInventoryClose)
overlay.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if os.clock() - lastInventoryOpenedAt < 0.45 then
			return
		end
		requestInventoryClose()
	end
end)

-- ========================
--   SERVER EVENTS
-- ========================
useEvent.OnClientEvent:Connect(function(resultType, arg1, arg2, extra)
	if resultType == "sync" then
		table.clear(playerItems)
		if type(arg1) == "table" then
			for itemId, quantity in pairs(arg1) do
				if quantity and quantity > 0 then
					playerItems[itemId] = quantity
				end
			end
		end
		if isOpen then refreshContent() end

	elseif resultType == "update" then
		setItemQuantity(arg1, arg2)
		if isOpen then refreshContent() end

	elseif resultType == "used" then
		setItemQuantity(arg1, arg2)
		showItemFeedback(true, (extra and extra.message) or "Item used!")
		if isOpen then refreshContent() end

	elseif resultType == "boosted" then
		setItemQuantity(arg1, arg2)
		if extra then
			local remaining = (extra.expiresAt or 0) - os.time()
			local mins = math.floor(remaining/60)
			local secs = remaining % 60
			local ts   = mins > 0 and (mins.."m "..secs.."s") or (secs.."s")
			local item = ItemsData.Items[arg1]
			showItemFeedback(true,
				(item and item.displayName or "Boost").." active for "..ts.."!",
				Color3.fromRGB(100,200,255)
			)
		end
		if isOpen then refreshContent() end

	elseif resultType == "boostExpired" then
		showItemFeedback(false,
			tostring(arg1):gsub("(%l)(%u)","%1 %2").." boost expired!",
			Color3.fromRGB(255,160,100)
		)

	elseif resultType == "error" then
		showItemFeedback(false, arg2 or "Something went wrong!")
	end
end)

petsLoadedEvent.OnClientEvent:Connect(function(inventory, equipped)
	applyPetState(inventory, equipped)
end)

if petInventoryValue then
	petInventoryValue:GetPropertyChangedSignal("Value"):Connect(refreshPetsFromReplicatedValues)
end
if petEquippedValue then
	petEquippedValue:GetPropertyChangedSignal("Value"):Connect(refreshPetsFromReplicatedValues)
end
task.defer(refreshPetsFromReplicatedValues)

-- ========================
--   HOOK INVENTORY BUTTON
-- ========================
UIManager.register("Inventory",
	function(context)
		toggleInventory(true, context)
	end,
	function(context) toggleInventory(false, context) end,
	function() return isOpen end
)

local function warnLegacyInventoryBlocked()
	if warnedLegacyInventoryOpen then
		return
	end
	warnedLegacyInventoryOpen = true
	warn("WARNING: Legacy inventory attempted to open; blocked.")
end

for _, legacyKey in ipairs({ "Pets", "PetInventory", "Bag", "Colors" }) do
	UIManager.register(legacyKey,
		function()
			warnLegacyInventoryBlocked()
			toggleInventory(true)
		end,
		function() toggleInventory(false) end,
		function() return isOpen end
	)
end

local _invBtn = ReplicatedStorage:WaitForChild("HudButton_INVENTORY", 10)
if _invBtn then
	_invBtn.Event:Connect(function()
		UIManager.toggle("Inventory")
	end)
end

-- Start
setTab("Colors")
if queuedInventoryOpen then
	task.defer(toggleInventory, true, queuedInventoryOpenContext)
elseif queuedInventoryClose then
	task.defer(toggleInventory, false, queuedInventoryCloseContext)
end
