-- Shared UI styling helpers for Color Simulator.
local RunService = game:GetService("RunService")

local UserInputService = nil
if RunService:IsClient() then
	local ok, service = pcall(function()
		return game:GetService("UserInputService")
	end)
	if ok then
		UserInputService = service
	end
end

local Theme = {}

local function getFont(name, fallback)
	local ok, font = pcall(function()
		return Enum.Font[name]
	end)
	return (ok and font) or fallback
end

Theme.Colors = {
	BackgroundDim = Color3.fromRGB(0, 0, 0),
	PanelCream = Color3.fromRGB(255, 250, 238),
	PanelWhite = Color3.fromRGB(255, 255, 255),
	PanelLavender = Color3.fromRGB(238, 226, 255),
	PanelBlueSoft = Color3.fromRGB(225, 244, 255),
	PanelPinkSoft = Color3.fromRGB(255, 226, 239),
	PanelYellowSoft = Color3.fromRGB(255, 245, 190),
	PanelGreenSoft = Color3.fromRGB(224, 255, 232),

	OutlineDark = Color3.fromRGB(34, 31, 42),
	OutlineSoft = Color3.fromRGB(78, 68, 105),
	TextDark = Color3.fromRGB(42, 37, 56),
	TextMuted = Color3.fromRGB(116, 101, 139),
	TextWhite = Color3.fromRGB(255, 255, 255),

	PrimaryCyan = Color3.fromRGB(91, 230, 235),
	PrimaryCyanDark = Color3.fromRGB(35, 180, 196),
	PrimaryPurple = Color3.fromRGB(177, 141, 255),
	PrimaryPurpleDark = Color3.fromRGB(122, 89, 210),
	PrimaryPink = Color3.fromRGB(255, 105, 165),
	PrimaryPinkDark = Color3.fromRGB(219, 67, 124),
	PrimaryYellow = Color3.fromRGB(255, 218, 74),
	PrimaryYellowDark = Color3.fromRGB(228, 168, 35),
	PrimaryGreen = Color3.fromRGB(91, 228, 126),
	PrimaryGreenDark = Color3.fromRGB(48, 178, 83),
	PrimaryBlue = Color3.fromRGB(88, 174, 255),
	PrimaryBlueDark = Color3.fromRGB(42, 116, 220),
	PrimaryOrange = Color3.fromRGB(255, 174, 72),
	PrimaryOrangeDark = Color3.fromRGB(216, 112, 38),
	ErrorRed = Color3.fromRGB(255, 91, 104),
	ErrorRedDark = Color3.fromRGB(196, 47, 65),

	CoinGold = Color3.fromRGB(255, 210, 64),
	DiamondBlue = Color3.fromRGB(107, 218, 255),
	ColorPink = Color3.fromRGB(255, 75, 200),
}

Theme.RarityColors = {
	Common = Color3.fromRGB(220, 220, 220),
	Uncommon = Color3.fromRGB(92, 224, 117),
	Rare = Color3.fromRGB(80, 154, 255),
	Epic = Color3.fromRGB(183, 91, 255),
	Legendary = Color3.fromRGB(255, 196, 54),
	Mythic = Color3.fromRGB(255, 78, 126),
	Secret = Color3.fromRGB(60, 55, 85),
	Event = Color3.fromRGB(255, 135, 42),
}

Theme.Sizes = {
	CornerSmall = UDim.new(0, 8),
	CornerMedium = UDim.new(0, 14),
	CornerLarge = UDim.new(0, 22),
	CornerHuge = UDim.new(0, 30),
}

Theme.Strokes = {
	StrokeThin = 2,
	StrokeMedium = 3,
	StrokeThick = 4,
	StrokeHuge = 5,
}

Theme.Spacing = {
	PaddingSmall = 6,
	PaddingMedium = 10,
	PaddingLarge = 16,
	PaddingHuge = 24,
}

Theme.Fonts = {
	Titles = getFont("FredokaOne", Enum.Font.GothamBlack),
	Buttons = getFont("FredokaOne", Enum.Font.GothamBold),
	Body = Enum.Font.GothamMedium,
	Small = Enum.Font.Gotham,
}

function Theme.ApplyCorner(instance, size)
	local corner = instance:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	corner.CornerRadius = size or Theme.Sizes.CornerMedium
	corner.Parent = instance
	return corner
end

function Theme.ApplyStroke(instance, color, thickness)
	local stroke = instance:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	stroke.Color = color or Theme.Colors.OutlineDark
	stroke.Thickness = thickness or Theme.Strokes.StrokeMedium
	stroke.Parent = instance
	return stroke
end

function Theme.ApplyPadding(instance, padding)
	local pad = instance:FindFirstChildOfClass("UIPadding") or Instance.new("UIPadding")
	padding = padding or Theme.Spacing.PaddingMedium
	pad.PaddingTop = UDim.new(0, padding)
	pad.PaddingBottom = UDim.new(0, padding)
	pad.PaddingLeft = UDim.new(0, padding)
	pad.PaddingRight = UDim.new(0, padding)
	pad.Parent = instance
	return pad
end

function Theme.ApplyTextSizeConstraint(instance, minSize, maxSize)
	local constraint = instance:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = minSize or 10
	constraint.MaxTextSize = maxSize or instance.TextSize or 18
	constraint.Parent = instance
	return constraint
end

function Theme.GetViewportSize()
	local camera = workspace.CurrentCamera
	return camera and camera.ViewportSize or Vector2.new(1280, 720)
end

function Theme.IsTouchDevice()
	return UserInputService and UserInputService.TouchEnabled == true
end

function Theme.ApplyTouchTarget(instance, minSize)
	local size = minSize or 44
	local constraint = instance:FindFirstChild("TouchTargetConstraint")
	if not constraint then
		constraint = Instance.new("UISizeConstraint")
		constraint.Name = "TouchTargetConstraint"
		constraint.Parent = instance
	end
	constraint.MinSize = Vector2.new(size, size)
	return constraint
end

function Theme.ApplyResponsiveScale(instance, baseWidth, baseHeight, minScale, margin)
	local scale = instance:FindFirstChild("ResponsiveScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "ResponsiveScale"
		scale.Parent = instance
	end

	baseWidth = baseWidth or 600
	baseHeight = baseHeight or 400
	minScale = minScale or 0.7
	margin = margin or 28

	local function updateScale()
		local viewport = Theme.GetViewportSize()
		local touch = Theme.IsTouchDevice()
		local effectiveMargin = touch and math.max(margin, 36) or margin
		local minimum = touch and math.max(minScale, 0.72) or minScale
		local fitWidth = math.max(viewport.X - effectiveMargin * 2, 280) / baseWidth
		local fitHeight = math.max(viewport.Y - effectiveMargin * 2, 220) / baseHeight
		local fitScale = math.min(fitWidth, fitHeight, 1)

		-- If the viewport is tighter than our preferred minimum, fit the panel
		-- instead of letting it overflow off-screen.
		scale.Scale = fitScale < minimum and fitScale or math.clamp(fitScale, minimum, 1)
	end

	updateScale()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(updateScale)

	return scale
end

function Theme.ApplyShadow(parent)
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.new(1, 0, 1, 0)
	shadow.Position = UDim2.new(0, 6, 0, 6)
	shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	shadow.BackgroundTransparency = 0.75
	shadow.BorderSizePixel = 0
	shadow.ZIndex = math.max((parent.ZIndex or 1) - 1, 0)
	shadow.Parent = parent.Parent
	Theme.ApplyCorner(
		shadow,
		parent:FindFirstChildOfClass("UICorner") and parent:FindFirstChildOfClass("UICorner").CornerRadius
			or Theme.Sizes.CornerLarge
	)
	return shadow
end

function Theme.MakeButtonStyle(button, color, darkerColor)
	button.BackgroundColor3 = color or Theme.Colors.PrimaryCyan
	button.AutoButtonColor = false
	button.Font = Theme.Fonts.Buttons
	button.TextColor3 = Theme.Colors.TextWhite
	button.TextStrokeTransparency = 0
	button.TextStrokeColor3 = Theme.Colors.OutlineDark
	Theme.ApplyCorner(button, Theme.Sizes.CornerMedium)
	Theme.ApplyStroke(button, darkerColor or Theme.Colors.OutlineDark, Theme.Strokes.StrokeMedium)
	return button
end

function Theme.FormatNumber(value)
	value = tonumber(value) or 0
	if math.abs(value) >= 1000000000 then
		return string.format("%.2fB", value / 1000000000):gsub("%.00", "")
	elseif math.abs(value) >= 1000000 then
		return string.format("%.2fM", value / 1000000):gsub("%.00", "")
	elseif math.abs(value) >= 1000 then
		return string.format("%.1fK", value / 1000):gsub("%.0K", "K")
	end
	return tostring(math.floor(value))
end

function Theme.CreateDimOverlay(parent, zIndex)
	local overlay = Instance.new("Frame")
	overlay.Name = "DimOverlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Theme.Colors.BackgroundDim
	overlay.BackgroundTransparency = 0.4
	overlay.BorderSizePixel = 0
	overlay.Active = false
	overlay.Selectable = false
	overlay.Visible = false
	overlay.ZIndex = zIndex or 50
	overlay.Parent = parent
	return overlay
end

return Theme
