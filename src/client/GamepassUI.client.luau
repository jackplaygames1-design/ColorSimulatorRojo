-- GamepassUI.client.luau
if true then
	warn("GamepassUI disabled; editable MainHUD.ModalWindows.Windows.ShopWindow is bound by EditorWindowBinder.")
	return
end

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local ClientUIRoot = require(ReplicatedStorage:WaitForChild("ClientUIRoot"))
local RobuxShopConfig = require(ReplicatedStorage:WaitForChild("RobuxShopConfig"))
local UIManager = require(ReplicatedStorage:WaitForChild("UIManager"))
local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))

local DARK = UITheme.Colors.OutlineDark
local WHITE = UITheme.Colors.TextWhite
local CYAN = UITheme.Colors.PrimaryCyan
local GREEN = UITheme.Colors.PrimaryGreen
local RED = UITheme.Colors.ErrorRed
local PANEL = UITheme.Colors.PanelCream
local TEXT_DARK = Color3.fromRGB(66, 52, 86)
local TEXT_BODY = Color3.fromRGB(90, 82, 110)
local PANEL_WIDTH = 780
local PANEL_HEIGHT = 600

local PASS_THEME = {
	AutoSell = {
		accent = Color3.fromRGB(255, 199, 87),
		button = Color3.fromRGB(255, 174, 72),
		icon = Color3.fromRGB(255, 211, 112),
	},
	Plus3Colors = {
		accent = Color3.fromRGB(114, 203, 255),
		button = Color3.fromRGB(88, 174, 255),
		icon = Color3.fromRGB(155, 224, 255),
	},
	DoubleCoins = {
		accent = Color3.fromRGB(255, 221, 84),
		button = Color3.fromRGB(255, 196, 54),
		icon = Color3.fromRGB(255, 230, 128),
	},
	VIP = {
		accent = Color3.fromRGB(193, 155, 255),
		button = Color3.fromRGB(177, 141, 255),
		icon = Color3.fromRGB(215, 190, 255),
	},
	LuckyHatch = {
		accent = Color3.fromRGB(128, 239, 150),
		button = Color3.fromRGB(91, 228, 126),
		icon = Color3.fromRGB(178, 250, 190),
	},
	SupportDev = {
		accent = Color3.fromRGB(255, 162, 196),
		button = Color3.fromRGB(255, 105, 165),
		icon = Color3.fromRGB(255, 207, 225),
	},
}

local ownedPasses = {}

local screenGui = ClientUIRoot.GetLayer(player.PlayerGui, "GamepassUI")

local overlay = UITheme.CreateDimOverlay(screenGui, 50)

local panel = Instance.new("Frame")
panel.Name = "GamepassPanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Size = UDim2.new(0, PANEL_WIDTH, 0, PANEL_HEIGHT)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.BackgroundColor3 = PANEL
panel.BorderSizePixel = 0
panel.Visible = false
panel.ZIndex = 60
panel.Parent = screenGui
UITheme.ApplyResponsiveScale(panel, PANEL_WIDTH, PANEL_HEIGHT, 0.72, 28)
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 24)
local panelStroke = Instance.new("UIStroke")
panelStroke.Color = DARK
panelStroke.Thickness = 5
panelStroke.Parent = panel
local panelShadow = Instance.new("Frame")
panelShadow.Name = "PanelShadow"
panelShadow.AnchorPoint = Vector2.new(0.5, 0.5)
panelShadow.Size = UDim2.new(0, PANEL_WIDTH, 0, PANEL_HEIGHT)
panelShadow.Position = UDim2.new(0.5, 7, 0.5, 7)
panelShadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
panelShadow.BackgroundTransparency = 0.78
panelShadow.BorderSizePixel = 0
panelShadow.ZIndex = 59
panelShadow.Visible = false
panelShadow.Parent = screenGui
UITheme.ApplyResponsiveScale(panelShadow, PANEL_WIDTH, PANEL_HEIGHT, 0.72, 28)
Instance.new("UICorner", panelShadow).CornerRadius = UDim.new(0, 24)

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 72)
header.BackgroundColor3 = CYAN
header.BorderSizePixel = 0
header.Parent = panel
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 24)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -92, 1, 0)
title.Position = UDim2.new(0, 26, 0, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.LuckiestGuy
title.TextSize = 33
title.TextColor3 = WHITE
title.TextStrokeTransparency = 0.25
title.TextStrokeColor3 = DARK
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "GAMEPASSES"
title:SetAttribute("NoTextGlow", true)
title.Parent = header
UITheme.ApplyTextSizeConstraint(title, 24, 34)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 44, 0, 44)
closeBtn.Position = UDim2.new(1, -60, 0.5, -22)
closeBtn.BackgroundColor3 = RED
closeBtn.AutoButtonColor = false
closeBtn.Font = Enum.Font.LuckiestGuy
closeBtn.TextSize = 25
closeBtn.TextColor3 = WHITE
closeBtn.TextStrokeTransparency = 0
closeBtn.TextStrokeColor3 = DARK
closeBtn.Text = "X"
closeBtn:SetAttribute("NoTextGlow", true)
closeBtn.Parent = header
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 14)
local closeStroke = Instance.new("UIStroke")
closeStroke.Color = DARK
closeStroke.Thickness = 4
closeStroke.Parent = closeBtn

local backBtn = Instance.new("TextButton")
backBtn.Size = UDim2.new(0, 44, 0, 44)
backBtn.Position = UDim2.new(0, 16, 0.5, -22)
backBtn.BackgroundColor3 = UITheme.Colors.PanelCream
backBtn.AutoButtonColor = false
backBtn.Font = Enum.Font.LuckiestGuy
backBtn.TextSize = 27
backBtn.TextColor3 = DARK
backBtn.TextStrokeTransparency = 1
backBtn.Text = "<"
backBtn.Visible = false
backBtn:SetAttribute("NoTextGlow", true)
backBtn.Parent = header
Instance.new("UICorner", backBtn).CornerRadius = UDim.new(0, 14)
local backStroke = Instance.new("UIStroke")
backStroke.Color = DARK
backStroke.Thickness = 4
backStroke.Parent = backBtn

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -44, 0, 42)
status.Position = UDim2.new(0, 22, 0, 84)
status.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
status.BackgroundTransparency = 0.08
status.BorderSizePixel = 0
status.Font = Enum.Font.GothamBold
status.TextSize = 15
status.TextColor3 = TEXT_BODY
status.TextXAlignment = Enum.TextXAlignment.Left
status.Text = "Support the game and unlock permanent perks."
status:SetAttribute("NoTextGlow", true)
status.ZIndex = 61
status.Parent = panel
Instance.new("UICorner", status).CornerRadius = UDim.new(0, 14)
local statusStroke = Instance.new("UIStroke")
statusStroke.Color = Color3.fromRGB(224, 210, 246)
statusStroke.Thickness = 2
statusStroke.Parent = status
local statusPad = Instance.new("UIPadding")
statusPad.PaddingLeft = UDim.new(0, 14)
statusPad.PaddingRight = UDim.new(0, 14)
statusPad.Parent = status

local list = Instance.new("ScrollingFrame")
list.Size = UDim2.new(1, -40, 1, -146)
list.Position = UDim2.new(0, 20, 0, 134)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.ScrollBarImageColor3 = Color3.fromRGB(112, 96, 146)
list.CanvasSize = UDim2.new(0, 0, 0, 0)
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.ZIndex = 61
list.Parent = panel

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 16)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local listPadding = Instance.new("UIPadding")
listPadding.PaddingTop = UDim.new(0, 16)
listPadding.PaddingBottom = UDim.new(0, 18)
listPadding.PaddingLeft = UDim.new(0, 16)
listPadding.PaddingRight = UDim.new(0, 16)
listPadding.Parent = list

local function formatPrice(price)
	return tostring(tonumber(price) or 0) .. " ROBUX"
end

local function applyModalLayer()
	panel.ZIndex = 60
	for _, obj in ipairs(panel:GetDescendants()) do
		if obj:IsA("GuiObject") and obj.ZIndex < 61 then
			obj.ZIndex = 61
		end
	end
	closeBtn.ZIndex = 70
end

local function checkOwned(pass)
	local grantedAttribute = player:GetAttribute("Pass_" .. tostring(pass.id))
	if grantedAttribute == true then
		ownedPasses[pass.id] = true
		return true
	end

	if not pass.gamepassId or pass.gamepassId <= 0 then
		ownedPasses[pass.id] = false
		return false
	end

	if ownedPasses[pass.id] ~= nil then
		return ownedPasses[pass.id]
	end

	local ok, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.gamepassId)
	end)
	ownedPasses[pass.id] = ok and result == true
	return ownedPasses[pass.id]
end

local function clearCards()
	for _, child in ipairs(list:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function addCorner(parent, radius)
	Instance.new("UICorner", parent).CornerRadius = UDim.new(0, radius)
end

local function addStroke(parent, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Parent = parent
	return stroke
end

local function makeIconLabel(parent, text, size, position, textSize, color, strokeColor)
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.LuckiestGuy
	label.Text = text
	label.TextSize = textSize
	label.TextColor3 = color or WHITE
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = strokeColor or DARK
	label.TextScaled = false
	label.ZIndex = 65
	label:SetAttribute("NoTextGlow", true)
	label.Parent = parent
	return label
end

local function makeRoundedIconPart(parent, name, size, position, color, radius, zIndex)
	local part = Instance.new("Frame")
	part.Name = name
	part.Size = size
	part.Position = position
	part.BackgroundColor3 = color
	part.BorderSizePixel = 0
	part.ZIndex = zIndex or 64
	part.Parent = parent
	addCorner(part, radius)
	return part
end

local function makeCircle(parent, name, size, position, color, zIndex)
	local circle = makeRoundedIconPart(parent, name, size, position, color, 999, zIndex)
	addStroke(circle, DARK, 3)
	local shine = makeRoundedIconPart(
		circle,
		"Shine",
		UDim2.fromScale(0.32, 0.22),
		UDim2.fromScale(0.17, 0.14),
		Color3.fromRGB(255, 255, 255),
		999,
		(zIndex or 64) + 1
	)
	shine.BackgroundTransparency = 0.22
	return circle
end

local function createGamepassIcon(parent, pass, accent)
	local block = Instance.new("Frame")
	block.Name = pass.id .. "Icon"
	block.Size = UDim2.new(0, 96, 0, 96)
	block.Position = UDim2.new(0, 18, 0.5, -48)
	block.BackgroundColor3 = (PASS_THEME[pass.id] and PASS_THEME[pass.id].icon or accent):Lerp(WHITE, 0.16)
	block.BorderSizePixel = 0
	block.ClipsDescendants = true
	block.ZIndex = 64
	block.Parent = parent
	addCorner(block, 18)
	addStroke(block, DARK, 3)

	local glow = Instance.new("Frame")
	glow.Name = "IconGlow"
	glow.Size = UDim2.new(1, 10, 1, 10)
	glow.Position = UDim2.new(0, -5, 0, -5)
	glow.BackgroundColor3 = accent
	glow.BackgroundTransparency = 0.82
	glow.BorderSizePixel = 0
	glow.ZIndex = 63
	glow.Parent = parent
	addCorner(glow, 22)

	if pass.iconImage and tostring(pass.iconImage) ~= "" then
		local image = Instance.new("ImageLabel")
		image.Size = UDim2.new(1, -10, 1, -10)
		image.Position = UDim2.new(0, 5, 0, 5)
		image.BackgroundTransparency = 1
		image.Image = tostring(pass.iconImage)
		image.ScaleType = Enum.ScaleType.Fit
		image.ZIndex = 65
		image.Parent = block
		return block
	end

	local id = pass.id
	if id == "AutoSell" then
		local bucket = makeRoundedIconPart(
			block,
			"PaintBucket",
			UDim2.new(0, 50, 0, 48),
			UDim2.new(0, 14, 0, 34),
			Color3.fromRGB(247, 249, 255),
			10
		)
		addStroke(bucket, DARK, 3)
		makeRoundedIconPart(
			bucket,
			"PaintRed",
			UDim2.new(0.25, 0, 0, 16),
			UDim2.new(0, 0, 0, 0),
			Color3.fromRGB(255, 80, 100),
			5,
			65
		)
		makeRoundedIconPart(
			bucket,
			"PaintBlue",
			UDim2.new(0.25, 0, 0, 16),
			UDim2.new(0.25, 0, 0, 0),
			Color3.fromRGB(64, 178, 255),
			5,
			65
		)
		makeRoundedIconPart(
			bucket,
			"PaintGreen",
			UDim2.new(0.25, 0, 0, 16),
			UDim2.new(0.5, 0, 0, 0),
			Color3.fromRGB(78, 225, 92),
			5,
			65
		)
		makeRoundedIconPart(
			bucket,
			"PaintYellow",
			UDim2.new(0.25, 0, 0, 16),
			UDim2.new(0.75, 0, 0, 0),
			Color3.fromRGB(255, 224, 70),
			5,
			65
		)
		makeCircle(block, "Coin", UDim2.new(0, 28, 0, 28), UDim2.new(0, 55, 0, 54), Color3.fromRGB(255, 218, 74), 66)
		makeIconLabel(
			block,
			"$",
			UDim2.new(0, 28, 0, 28),
			UDim2.new(0, 55, 0, 54),
			20,
			Color3.fromRGB(255, 255, 190),
			Color3.fromRGB(174, 111, 20)
		)
	elseif id == "Plus3Colors" then
		makeCircle(block, "RedColor", UDim2.new(0, 36, 0, 36), UDim2.new(0, 12, 0, 21), Color3.fromRGB(255, 83, 92), 64)
		makeCircle(
			block,
			"GreenColor",
			UDim2.new(0, 36, 0, 36),
			UDim2.new(0, 42, 0, 26),
			Color3.fromRGB(82, 230, 84),
			64
		)
		makeCircle(
			block,
			"BlueColor",
			UDim2.new(0, 36, 0, 36),
			UDim2.new(0, 26, 0, 52),
			Color3.fromRGB(77, 177, 255),
			64
		)
		makeIconLabel(block, "+3", UDim2.new(1, 0, 0, 34), UDim2.new(0, 0, 1, -38), 31, WHITE, DARK)
	elseif id == "DoubleCoins" then
		makeCircle(
			block,
			"CoinBack",
			UDim2.new(0, 36, 0, 36),
			UDim2.new(0, 12, 0, 43),
			Color3.fromRGB(255, 194, 45),
			64
		)
		makeCircle(block, "CoinMid", UDim2.new(0, 42, 0, 42), UDim2.new(0, 36, 0, 38), Color3.fromRGB(255, 218, 74), 65)
		makeIconLabel(
			block,
			"2x",
			UDim2.new(1, 0, 0, 52),
			UDim2.new(0, 0, 0, 8),
			39,
			Color3.fromRGB(255, 247, 168),
			DARK
		)
	elseif id == "VIP" then
		local crownBase = makeRoundedIconPart(
			block,
			"CrownBase",
			UDim2.new(0, 56, 0, 18),
			UDim2.new(0, 18, 0, 62),
			Color3.fromRGB(255, 198, 35),
			7
		)
		addStroke(crownBase, DARK, 3)
		makeCircle(
			block,
			"CrownLeft",
			UDim2.new(0, 22, 0, 22),
			UDim2.new(0, 13, 0, 28),
			Color3.fromRGB(255, 226, 65),
			64
		)
		makeCircle(
			block,
			"CrownCenter",
			UDim2.new(0, 28, 0, 28),
			UDim2.new(0, 32, 0, 17),
			Color3.fromRGB(255, 226, 65),
			65
		)
		makeCircle(
			block,
			"CrownRight",
			UDim2.new(0, 22, 0, 22),
			UDim2.new(0, 57, 0, 28),
			Color3.fromRGB(255, 226, 65),
			64
		)
		makeIconLabel(
			block,
			"VIP",
			UDim2.new(1, 0, 0, 34),
			UDim2.new(0, 0, 1, -36),
			27,
			Color3.fromRGB(255, 255, 180),
			DARK
		)
	elseif id == "LuckyHatch" then
		local egg = makeRoundedIconPart(
			block,
			"Egg",
			UDim2.new(0, 48, 0, 58),
			UDim2.new(0, 22, 0, 20),
			Color3.fromRGB(255, 249, 240),
			999
		)
		addStroke(egg, DARK, 3)
		makeRoundedIconPart(
			egg,
			"EggPink",
			UDim2.new(0.4, 0, 0.6, 0),
			UDim2.new(0, 0, 0, 0),
			Color3.fromRGB(255, 82, 176),
			999,
			65
		)
		makeRoundedIconPart(
			egg,
			"EggBlue",
			UDim2.new(0.4, 0, 0.6, 0),
			UDim2.new(0.28, 0, 0, 0),
			Color3.fromRGB(82, 198, 255),
			999,
			65
		)
		makeRoundedIconPart(
			egg,
			"EggGreen",
			UDim2.new(0.44, 0, 0.6, 0),
			UDim2.new(0.58, 0, 0, 0),
			Color3.fromRGB(90, 232, 90),
			999,
			65
		)
		makeIconLabel(
			block,
			"*",
			UDim2.new(0, 32, 0, 32),
			UDim2.new(0, 52, 0, 14),
			32,
			Color3.fromRGB(255, 234, 78),
			DARK
		)
	elseif id == "SupportDev" then
		makeIconLabel(
			block,
			"<3",
			UDim2.new(1, 0, 0, 52),
			UDim2.new(0, 0, 0, 21),
			38,
			Color3.fromRGB(255, 86, 136),
			DARK
		)
		makeCircle(
			block,
			"SparkLeft",
			UDim2.new(0, 16, 0, 16),
			UDim2.new(0, 15, 0, 18),
			Color3.fromRGB(255, 225, 235),
			64
		)
		makeCircle(
			block,
			"SparkRight",
			UDim2.new(0, 14, 0, 14),
			UDim2.new(0, 67, 0, 70),
			Color3.fromRGB(255, 225, 235),
			64
		)
	else
		makeIconLabel(block, tostring(pass.icon or ""), UDim2.new(1, 0, 1, 0), UDim2.fromOffset(0, 0), 34, WHITE, DARK)
	end

	return block
end

local function buildPassCard(pass, order)
	local owned = checkOwned(pass)
	local theme = PASS_THEME[pass.id] or {}
	local accent = theme.accent or pass.color or GREEN
	local buttonColor = theme.button or accent
	local needsId = not pass.gamepassId or pass.gamepassId <= 0

	local card = Instance.new("Frame")
	card.Name = pass.id .. "Card"
	card.LayoutOrder = order
	card.Size = UDim2.new(1, 0, 0, 128)
	card.BackgroundColor3 = WHITE:Lerp(accent, 0.05)
	card.BorderSizePixel = 0
	card.ZIndex = 61
	card.Parent = list
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 18)
	local stroke = Instance.new("UIStroke")
	stroke.Color = owned and GREEN or DARK
	stroke.Thickness = owned and 4 or 3
	stroke.Parent = card

	local accentStrip = Instance.new("Frame")
	accentStrip.Name = "AccentStrip"
	accentStrip.Size = UDim2.new(0, 9, 1, -18)
	accentStrip.Position = UDim2.new(0, 8, 0, 9)
	accentStrip.BackgroundColor3 = accent
	accentStrip.BorderSizePixel = 0
	accentStrip.ZIndex = 62
	accentStrip.Parent = card
	Instance.new("UICorner", accentStrip).CornerRadius = UDim.new(0, 8)

	local highlight = Instance.new("Frame")
	highlight.Name = "GlossHighlight"
	highlight.Size = UDim2.new(1, -34, 0, 30)
	highlight.Position = UDim2.new(0, 17, 0, 10)
	highlight.BackgroundColor3 = WHITE
	highlight.BackgroundTransparency = 0.68
	highlight.BorderSizePixel = 0
	highlight.ZIndex = 62
	highlight.Parent = card
	Instance.new("UICorner", highlight).CornerRadius = UDim.new(0, 14)

	createGamepassIcon(card, pass, accent)

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -300, 0, 30)
	name.Position = UDim2.new(0, 130, 0, 18)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.LuckiestGuy
	name.TextSize = 25
	name.TextColor3 = TEXT_DARK
	name.TextStrokeTransparency = 1
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Text = pass.displayName
	name:SetAttribute("NoTextGlow", true)
	name.ZIndex = 65
	name.Parent = card
	UITheme.ApplyTextSizeConstraint(name, 18, 26)

	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(1, -300, 0, 38)
	desc.Position = UDim2.new(0, 130, 0, 50)
	desc.BackgroundTransparency = 1
	desc.Font = Enum.Font.GothamBold
	desc.TextSize = 14
	desc.TextWrapped = true
	desc.TextColor3 = TEXT_BODY
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextYAlignment = Enum.TextYAlignment.Top
	desc.Text = pass.description
	desc:SetAttribute("NoTextGlow", true)
	desc.ZIndex = 65
	desc.Parent = card

	local tag = Instance.new("TextLabel")
	tag.Size = UDim2.new(0, 128, 0, 24)
	tag.Position = UDim2.new(0, 130, 1, -34)
	tag.BackgroundColor3 = accent:Lerp(WHITE, 0.34)
	tag.BorderSizePixel = 0
	tag.Font = Enum.Font.GothamBlack
	tag.TextSize = 11
	tag.TextColor3 = TEXT_DARK
	tag.TextStrokeTransparency = 1
	tag.Text = tostring(pass.badge or "PERMANENT")
	tag.TextXAlignment = Enum.TextXAlignment.Center
	tag:SetAttribute("NoTextGlow", true)
	tag.ZIndex = 65
	tag.Parent = card
	Instance.new("UICorner", tag).CornerRadius = UDim.new(0, 12)
	local tagStroke = Instance.new("UIStroke")
	tagStroke.Color = accent:Lerp(DARK, 0.18)
	tagStroke.Thickness = 2
	tagStroke.Transparency = 0.2
	tagStroke.Parent = tag

	local buy = Instance.new("TextButton")
	buy.Size = UDim2.new(0, 144, 0, 58)
	buy.Position = UDim2.new(1, -164, 0.5, -29)
	buy.BackgroundColor3 = owned and GREEN or (needsId and Color3.fromRGB(205, 210, 225) or buttonColor)
	buy.AutoButtonColor = not owned and not needsId
	buy.Font = Enum.Font.GothamBold
	buy.Text = ""
	buy.ZIndex = 65
	buy.Parent = card
	Instance.new("UICorner", buy).CornerRadius = UDim.new(0, 16)
	local buyStroke = Instance.new("UIStroke")
	buyStroke.Color = DARK
	buyStroke.Thickness = 4
	buyStroke.Parent = buy

	local buyTop = Instance.new("TextLabel")
	buyTop.Name = "BuyTop"
	buyTop.Size = UDim2.new(1, -10, 0, owned and 58 or 24)
	buyTop.Position = UDim2.new(0, 5, 0, owned and 0 or 7)
	buyTop.BackgroundTransparency = 1
	buyTop.Font = Enum.Font.LuckiestGuy
	buyTop.TextSize = owned and 19 or 18
	buyTop.TextColor3 = WHITE
	buyTop.TextStrokeTransparency = 0.55
	buyTop.TextStrokeColor3 = DARK
	buyTop.Text = owned and "OWNED" or (needsId and "SET ID" or "BUY")
	buyTop.ZIndex = 66
	buyTop:SetAttribute("NoTextGlow", true)
	buyTop.Parent = buy
	UITheme.ApplyTextSizeConstraint(buyTop, 13, owned and 20 or 18)

	if not owned then
		local price = Instance.new("TextLabel")
		price.Name = "Price"
		price.Size = UDim2.new(1, -10, 0, 24)
		price.Position = UDim2.new(0, 5, 0, 29)
		price.BackgroundTransparency = 1
		price.Font = Enum.Font.GothamBlack
		price.TextSize = 14
		price.TextColor3 = WHITE
		price.TextStrokeTransparency = 0.72
		price.TextStrokeColor3 = DARK
		price.Text = needsId and "CONFIGURE" or formatPrice(pass.price)
		price.ZIndex = 66
		price:SetAttribute("NoTextGlow", true)
		price.Parent = buy
		UITheme.ApplyTextSizeConstraint(price, 10, 14)
	end

	buy.MouseButton1Click:Connect(function()
		if owned then
			status.Text = "You already own " .. pass.displayName
			status.TextColor3 = Color3.fromRGB(35, 130, 55)
			return
		end
		if needsId then
			status.Text = "Add the real Roblox gamepass ID for " .. pass.displayName
			status.TextColor3 = RED
			return
		end
		status.Text = "Opening Roblox purchase prompt..."
		status.TextColor3 = TEXT_BODY
		MarketplaceService:PromptGamePassPurchase(player, pass.gamepassId)
	end)

	buy.MouseButton1Down:Connect(function()
		if owned or needsId then
			return
		end
		TweenService:Create(buy, TweenInfo.new(0.08), {
			Size = UDim2.new(0, 136, 0, 54),
			Position = UDim2.new(1, -160, 0.5, -27),
		}):Play()
	end)

	buy.MouseButton1Up:Connect(function()
		TweenService:Create(buy, TweenInfo.new(0.16, Enum.EasingStyle.Back), {
			Size = UDim2.new(0, 144, 0, 58),
			Position = UDim2.new(1, -164, 0.5, -29),
		}):Play()
	end)

	card.MouseEnter:Connect(function()
		TweenService:Create(card, TweenInfo.new(0.12), {
			BackgroundColor3 = WHITE:Lerp(accent, 0.1),
		}):Play()
	end)

	card.MouseLeave:Connect(function()
		TweenService:Create(card, TweenInfo.new(0.12), {
			BackgroundColor3 = WHITE:Lerp(accent, 0.05),
		}):Play()
	end)
end

local function refresh()
	clearCards()
	local passes = RobuxShopConfig.getSortedGamepasses and RobuxShopConfig.getSortedGamepasses()
		or (RobuxShopConfig.Gamepasses or {})
	for index, pass in ipairs(passes) do
		buildPassCard(pass, index)
	end
	list.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 48)
	applyModalLayer()
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(purchasingPlayer, gamepassId, wasPurchased)
	if purchasingPlayer ~= player then
		return
	end
	for _, pass in ipairs(RobuxShopConfig.Gamepasses or {}) do
		if pass.gamepassId == gamepassId then
			if wasPurchased then
				ownedPasses[pass.id] = true
				status.Text = "Thank you! " .. pass.displayName .. " unlocked."
				status.TextColor3 = Color3.fromRGB(35, 130, 55)
			else
				status.Text = "Purchase canceled."
				status.TextColor3 = Color3.fromRGB(100, 105, 125)
			end
			refresh()
			break
		end
	end
end)

local isOpen = false
local openedFromMenu = false
local function toggleGamepass(open, context)
	isOpen = open
	if open then
		openedFromMenu = context and context.from == "Menu" or false
		backBtn.Visible = openedFromMenu
		title.Position = openedFromMenu and UDim2.new(0, 72, 0, 0) or UDim2.new(0, 26, 0, 0)
		title.Size = openedFromMenu and UDim2.new(1, -138, 1, 0) or UDim2.new(1, -92, 1, 0)
		refresh()
		overlay.Visible = true
		overlay.BackgroundTransparency = 1
		panel.Visible = true
		panelShadow.Visible = true
		panel.Size = UDim2.new(0, 80, 0, 80)
		panel.Position = UDim2.fromScale(0.5, 0.5)
		panelShadow.Size = panel.Size
		panelShadow.Position = UDim2.new(0.5, 7, 0.5, 7)
		TweenService:Create(overlay, TweenInfo.new(0.18), {
			BackgroundTransparency = 0.4,
		}):Play()
		TweenService:Create(panel, TweenInfo.new(0.28, Enum.EasingStyle.Back), {
			Size = UDim2.new(0, PANEL_WIDTH, 0, PANEL_HEIGHT),
			Position = UDim2.fromScale(0.5, 0.5),
		}):Play()
		TweenService:Create(panelShadow, TweenInfo.new(0.28, Enum.EasingStyle.Back), {
			Size = UDim2.new(0, PANEL_WIDTH, 0, PANEL_HEIGHT),
			Position = UDim2.new(0.5, 7, 0.5, 7),
		}):Play()
	else
		openedFromMenu = false
		backBtn.Visible = false
		if context and context.immediate then
			panel.Visible = false
			panelShadow.Visible = false
			overlay.Visible = false
			overlay.BackgroundTransparency = 1
			return
		end
		TweenService:Create(overlay, TweenInfo.new(0.16), {
			BackgroundTransparency = 1,
		}):Play()
		TweenService:Create(panel, TweenInfo.new(0.16), {
			Size = UDim2.new(0, 0, 0, 0),
			Position = UDim2.fromScale(0.5, 0.5),
		}):Play()
		TweenService:Create(panelShadow, TweenInfo.new(0.16), {
			Size = UDim2.new(0, 0, 0, 0),
			Position = UDim2.new(0.5, 7, 0.5, 7),
		}):Play()
		task.delay(0.16, function()
			if not isOpen then
				panel.Visible = false
				panelShadow.Visible = false
				overlay.Visible = false
			end
		end)
	end
end

backBtn.MouseButton1Click:Connect(function()
	if openedFromMenu then
		UIManager.open("Menu")
	end
end)

closeBtn.MouseButton1Click:Connect(function()
	UIManager.close("Gamepass")
end)

overlay.MouseButton1Click:Connect(function()
	UIManager.close("Gamepass")
end)

UIManager.register("Gamepass", function(context)
	toggleGamepass(true, context)
end, function(context)
	toggleGamepass(false, context)
end, function()
	return isOpen
end)

local gamepassBtn = ReplicatedStorage:WaitForChild("HudButton_GAMEPASS", 10)
if gamepassBtn then
	gamepassBtn.Event:Connect(function()
		UIManager.toggle("Gamepass")
	end)
end

for _, pass in ipairs(RobuxShopConfig.Gamepasses or {}) do
	player:GetAttributeChangedSignal("Pass_" .. tostring(pass.id)):Connect(function()
		ownedPasses[pass.id] = nil
		if isOpen then
			refresh()
		end
	end)
end
