-- Disabled: no PlayerGui UI should be created or restyled at runtime.
if true then
	return
end

-- Light readability pass for player-facing UI text.
-- Keeps the simulator style, but stops small outlined labels from turning into blobs.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SAFE_GLOW_COLORS = {
	Color3.fromRGB(105, 226, 232), -- soft cyan
	Color3.fromRGB(164, 143, 238), -- soft lavender
	Color3.fromRGB(255, 201, 112), -- warm gold
	Color3.fromRGB(125, 224, 154), -- soft mint
	Color3.fromRGB(244, 147, 184), -- soft rose
}

local SAFE_HOVER_COLORS = {
	Color3.fromRGB(88, 255, 231),
	Color3.fromRGB(255, 218, 92),
	Color3.fromRGB(125, 255, 158),
	Color3.fromRGB(185, 155, 255),
	Color3.fromRGB(255, 136, 198),
}

local hoverOriginals = setmetatable({}, { __mode = "k" })
local DARK_STROKE = Color3.fromRGB(8, 14, 32)

local function luminance(color)
	return color.R * 0.2126 + color.G * 0.7152 + color.B * 0.0722
end

local function colorDistance(a, b)
	local dr = a.R - b.R
	local dg = a.G - b.G
	local db = a.B - b.B
	return math.sqrt(dr * dr + dg * dg + db * db)
end

local function getParentBackground(gui)
	local parent = gui.Parent
	while parent do
		if parent:IsA("GuiObject") and parent.BackgroundTransparency < 0.92 then
			return parent.BackgroundColor3
		end
		parent = parent.Parent
	end
	return Color3.fromRGB(255, 255, 255)
end

local function chooseGlowColor(gui)
	local seedText = tostring(gui.Name) .. "|" .. tostring(gui.Text)
	local seed = 0
	for i = 1, #seedText do
		seed += string.byte(seedText, i) * i
	end

	local textColor = gui.TextColor3
	local bgColor = getParentBackground(gui)
	local bestColor = SAFE_GLOW_COLORS[1]
	local bestScore = -math.huge
	for i, color in ipairs(SAFE_GLOW_COLORS) do
		local candidate = SAFE_GLOW_COLORS[((seed + i - 1) % #SAFE_GLOW_COLORS) + 1]
		local score = colorDistance(candidate, textColor) * 0.55
			+ colorDistance(candidate, bgColor) * 0.45
			- math.abs(luminance(candidate) - 0.72) * 0.28
		if score > bestScore then
			bestScore = score
			bestColor = candidate
		end
	end

	return bestColor
end

local function chooseHoverColor(gui)
	local seedText = tostring(gui.Name) .. "|" .. tostring(gui.Text)
	local seed = 0
	for i = 1, #seedText do
		seed += string.byte(seedText, i) * i
	end

	local bgColor = getParentBackground(gui)
	local bestColor = SAFE_HOVER_COLORS[1]
	local bestScore = -math.huge
	for i = 1, #SAFE_HOVER_COLORS do
		local candidate = SAFE_HOVER_COLORS[((seed + i - 1) % #SAFE_HOVER_COLORS) + 1]
		local lum = luminance(candidate)
		local score = colorDistance(candidate, bgColor) - math.abs(lum - 0.78) * 0.35
		if score > bestScore then
			bestScore = score
			bestColor = candidate
		end
	end

	return bestColor
end

local function getTextConstraint(gui)
	for _, child in ipairs(gui:GetChildren()) do
		if child:IsA("UITextSizeConstraint") then
			return child
		end
	end
	return nil
end

local function needsStrongReadableText(gui)
	if gui:GetAttribute("ForceReadableText") then
		return true
	end
	if gui:IsA("TextButton") then
		return gui.Text ~= nil and gui.Text ~= ""
	end

	local text = string.upper(tostring(gui.Text or ""))
	return string.find(text, "RELEASE", 1, true)
		or string.find(text, "CODE:", 1, true)
		or string.find(text, "HIDE", 1, true)
end

local function applyStrongReadableText(gui)
	gui:SetAttribute("NoTextGlow", true)
	gui.Font = Enum.Font.GothamBlack
	gui.TextColor3 = Color3.fromRGB(255, 255, 255)
	gui.TextStrokeColor3 = DARK_STROKE
	gui.TextStrokeTransparency = 0

	if gui:IsA("TextButton") or gui:GetAttribute("ForceReadableText") then
		gui.TextScaled = true
		local constraint = getTextConstraint(gui)
		if not constraint then
			constraint = Instance.new("UITextSizeConstraint")
			constraint.Parent = gui
		end
		constraint.MinTextSize = math.max(constraint.MinTextSize, 10)
		constraint.MaxTextSize = math.max(constraint.MaxTextSize, 18)
	end
end

local function shouldGlowText(gui)
	if gui:GetAttribute("NoTextGlow") or gui:GetAttribute("ReadabilityGlow") then
		return false
	end
	if gui:IsA("TextButton") or gui:IsA("TextBox") then
		return false
	end
	if gui.Text == nil or gui.Text == "" then
		return false
	end
	if gui.TextTransparency > 0.35 then
		return false
	end
	if gui.AbsoluteSize.X < 18 or gui.AbsoluteSize.Y < 10 then
		return false
	end
	local visibleTextSize = gui.TextScaled and gui.AbsoluteSize.Y or gui.TextSize
	if visibleTextSize < 20 then
		return false
	end
	return gui.Font == Enum.Font.LuckiestGuy or gui.TextScaled
end

local function ensureTextGlow(gui)
	if not shouldGlowText(gui) then
		local old = gui:FindFirstChild("SoftReadableGlow")
		if old then
			old:Destroy()
		end
		return
	end

	local glow = gui:FindFirstChild("SoftReadableGlow")
	if not glow then
		glow = Instance.new("TextLabel")
		glow.Name = "SoftReadableGlow"
		glow:SetAttribute("ReadabilityGlow", true)
		glow.BackgroundTransparency = 1
		glow.BorderSizePixel = 0
		glow.Active = false
		glow.Selectable = false
		glow.Parent = gui
	end

	local glowColor = chooseGlowColor(gui)
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.new(0.5, 0, 0.5, 0)
	glow.Size = UDim2.new(1, 0, 1, 0)
	glow.Font = gui.Font
	glow.Text = gui.Text
	glow.TextSize = gui.TextSize
	glow.TextScaled = gui.TextScaled
	glow.TextWrapped = gui.TextWrapped
	glow.TextXAlignment = gui.TextXAlignment
	glow.TextYAlignment = gui.TextYAlignment
	glow.RichText = gui.RichText
	glow.TextColor3 = glowColor
	glow.TextTransparency = 0.78
	glow.TextStrokeColor3 = glowColor:Lerp(Color3.new(1, 1, 1), 0.18)
	glow.TextStrokeTransparency = 0.9
	glow.ZIndex = math.max(1, gui.ZIndex - 1)

	local constraint = getTextConstraint(gui)
	local glowConstraint = getTextConstraint(glow)
	if constraint then
		if not glowConstraint then
			glowConstraint = Instance.new("UITextSizeConstraint")
			glowConstraint.Parent = glow
		end
		glowConstraint.MinTextSize = constraint.MinTextSize
		glowConstraint.MaxTextSize = constraint.MaxTextSize + 2
	elseif glowConstraint then
		glowConstraint:Destroy()
	end
end

local function hasAncestorNamed(instance, name)
	local current = instance.Parent
	while current do
		if current.Name == name then
			return true
		end
		current = current.Parent
	end
	return false
end

local function rememberOriginal(instance, propertyName, value)
	local props = hoverOriginals[instance]
	if not props then
		props = {}
		hoverOriginals[instance] = props
	end
	if props[propertyName] == nil then
		props[propertyName] = value
	end
end

local function tweenColor(instance, propertyName, color)
	TweenService:Create(instance, TweenInfo.new(0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		[propertyName] = color,
	}):Play()
end

local function shouldTintIconPart(obj)
	if not obj:IsA("GuiObject") then
		return false
	end
	if not hasAncestorNamed(obj, "Icon") then
		return false
	end
	return obj.BackgroundTransparency < 1 and luminance(obj.BackgroundColor3) > 0.48
end

local function applyButtonHover(button, hovering)
	if button:GetAttribute("NoReadableHover") or button:GetAttribute("ForceReadableText") then
		return
	end

	local hoverColor = chooseHoverColor(button)

	local function applyText(obj)
		if obj:GetAttribute("ReadabilityGlow") then
			return
		end
		if obj:IsA("TextLabel") or obj:IsA("TextButton") then
			if obj.Text ~= "" and obj.TextTransparency < 0.6 then
				rememberOriginal(obj, "TextColor3", obj.TextColor3)
				tweenColor(obj, "TextColor3", hovering and hoverColor or hoverOriginals[obj].TextColor3)
			end
		end
	end

	applyText(button)
	for _, obj in ipairs(button:GetDescendants()) do
		applyText(obj)

		if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
			rememberOriginal(obj, "ImageColor3", obj.ImageColor3)
			tweenColor(obj, "ImageColor3", hovering and hoverColor or hoverOriginals[obj].ImageColor3)
		elseif shouldTintIconPart(obj) then
			rememberOriginal(obj, "BackgroundColor3", obj.BackgroundColor3)
			tweenColor(obj, "BackgroundColor3", hovering and hoverColor or hoverOriginals[obj].BackgroundColor3)
		end
	end
end

local function setupHoverColor(button)
	if not button:IsA("TextButton") or button:GetAttribute("ReadableHoverWatched") then
		return
	end
	if button:GetAttribute("NoReadableHover") or button:GetAttribute("ForceReadableText") then
		return
	end
	button:SetAttribute("ReadableHoverWatched", true)

	button.MouseEnter:Connect(function()
		applyButtonHover(button, true)
	end)

	button.MouseLeave:Connect(function()
		applyButtonHover(button, false)
	end)
end

local function improveText(gui)
	if gui:GetAttribute("ReadabilityGlow") then
		return
	end
	if not (gui:IsA("TextLabel") or gui:IsA("TextButton") or gui:IsA("TextBox")) then
		return
	end

	if gui:IsA("TextButton") then
		setupHoverColor(gui)
	end

	if needsStrongReadableText(gui) then
		applyStrongReadableText(gui)
		return
	end

	local textLum = luminance(gui.TextColor3)
	local strokeLum = luminance(gui.TextStrokeColor3)
	local smallControl = (gui:IsA("TextButton") or gui:IsA("TextBox")) and gui.AbsoluteSize.Y <= 42

	if gui.TextStrokeTransparency < 1 then
		if (smallControl and textLum < 0.62) or (textLum < 0.5 and strokeLum > 0.78) then
			gui.TextStrokeTransparency = 1
		else
			gui.TextStrokeTransparency = math.max(gui.TextStrokeTransparency, 0.35)
		end
	end

	if gui.Font == Enum.Font.LuckiestGuy and gui.TextSize > 0 and gui.TextSize <= 14 then
		gui.Font = Enum.Font.GothamBold
	end

	if gui.TextSize > 0 then
		if gui:IsA("TextButton") or gui:IsA("TextBox") then
			gui.TextSize = math.max(gui.TextSize, 13)
		else
			gui.TextSize = math.max(gui.TextSize, 12)
		end
	end

	if gui.TextScaled then
		local constraint = getTextConstraint(gui)
		if not constraint then
			constraint = Instance.new("UITextSizeConstraint")
			constraint.Parent = gui
		end
		constraint.MinTextSize = math.max(constraint.MinTextSize, 12)
		if constraint.MaxTextSize <= 0 then
			constraint.MaxTextSize = math.max(gui.TextSize, 18)
		end
	end

	ensureTextGlow(gui)

	if not gui:GetAttribute("ReadabilityWatched") then
		gui:SetAttribute("ReadabilityWatched", true)
		gui:GetPropertyChangedSignal("Text"):Connect(function()
			ensureTextGlow(gui)
		end)
		gui:GetPropertyChangedSignal("TextColor3"):Connect(function()
			ensureTextGlow(gui)
		end)
		gui:GetPropertyChangedSignal("TextTransparency"):Connect(function()
			ensureTextGlow(gui)
		end)
		gui:GetPropertyChangedSignal("Visible"):Connect(function()
			ensureTextGlow(gui)
		end)
	end
end

for _, obj in ipairs(playerGui:GetDescendants()) do
	improveText(obj)
end

playerGui.DescendantAdded:Connect(function(obj)
	task.defer(improveText, obj)
end)
