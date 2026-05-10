local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local PhysicalCurrencyHUDBuilder = {}

local DARK = Color3.fromRGB(35, 42, 55)
local STROKE_DARK = Color3.fromRGB(9, 14, 22)
local GOLD = Color3.fromRGB(255, 205, 52)
local EMERALD = Color3.fromRGB(45, 235, 185)

local function canBuild()
	if not RunService:IsStudio() then
		warn("PhysicalCurrencyHUDBuilder: can only edit StarterGui in Studio.")
		return false
	end
	return true
end

local function findOrCreate(parent, className, name)
	local child = parent:FindFirstChild(name)
	if child and child.ClassName == className then
		return child
	end
	if child then
		warn("PhysicalCurrencyHUDBuilder: " .. child:GetFullName() .. " is not a " .. className .. ". Leaving it untouched.")
		return nil
	end

	child = Instance.new(className)
	child.Name = name
	child.Parent = parent
	return child
end

local function ensureCorner(parent, radius)
	local corner = parent:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

local function ensureStroke(parent, color)
	local stroke = parent:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 3
	stroke.Transparency = 0
	stroke.Parent = parent
	return stroke
end

local function setupCurrencyFrame(parent, name, strokeColor, layoutOrder)
	local frame = findOrCreate(parent, "Frame", name)
	if not frame then
		return nil
	end

	frame.LayoutOrder = layoutOrder
	frame.Size = UDim2.new(0, 155, 0, 48)
	frame.BackgroundColor3 = DARK
	frame.BackgroundTransparency = 0.05
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = false
	ensureCorner(frame, 14)
	ensureStroke(frame, strokeColor)

	local icon = findOrCreate(frame, "ImageLabel", "Icon")
	if icon then
		icon.Size = UDim2.new(0, 42, 0, 42)
		icon.Position = UDim2.new(0, 5, 0.5, -21)
		icon.BackgroundTransparency = 1
		icon.BorderSizePixel = 0
		icon.ScaleType = Enum.ScaleType.Fit
		icon.ZIndex = frame.ZIndex + 1
	end

	local amount = findOrCreate(frame, "TextLabel", "Amount")
	if amount then
		amount.Size = UDim2.new(1, -54, 1, 0)
		amount.Position = UDim2.new(0, 52, 0, 0)
		amount.BackgroundTransparency = 1
		amount.BorderSizePixel = 0
		amount.Font = Enum.Font.GothamBlack
		amount.Text = "0"
		amount.TextColor3 = Color3.fromRGB(255, 255, 255)
		amount.TextScaled = true
		amount.TextXAlignment = Enum.TextXAlignment.Left
		amount.TextYAlignment = Enum.TextYAlignment.Center
		amount.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		amount.TextStrokeTransparency = 0
		amount.ZIndex = frame.ZIndex + 1

		local sizeConstraint = amount:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
		sizeConstraint.MinTextSize = 12
		sizeConstraint.MaxTextSize = 26
		sizeConstraint.Parent = amount
	end

	return frame
end

function PhysicalCurrencyHUDBuilder.Build()
	if not canBuild() then
		return nil
	end

	local screen = StarterGui:FindFirstChild("ColorSimulatorUI")
	if not screen then
		screen = Instance.new("ScreenGui")
		screen.Name = "ColorSimulatorUI"
		screen.Parent = StarterGui
	end
	screen.Enabled = true
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = false
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local mainHud = screen:FindFirstChild("MainHUD")
	if not mainHud then
		mainHud = Instance.new("Frame")
		mainHud.Name = "MainHUD"
		mainHud.BackgroundTransparency = 1
		mainHud.Size = UDim2.fromScale(1, 1)
		mainHud.Parent = screen
	end
	mainHud.Visible = true
	mainHud.BackgroundTransparency = 1

	local bar = findOrCreate(mainHud, "Frame", "CurrencyBar")
	if not bar then
		return nil
	end
	bar.AnchorPoint = Vector2.new(0, 0)
	bar.Position = UDim2.new(0, 18, 0, 18)
	bar.Size = UDim2.new(0, 340, 0, 54)
	bar.BackgroundTransparency = 1
	bar.BorderSizePixel = 0
	bar.ClipsDescendants = false

	local layout = bar:FindFirstChildOfClass("UIListLayout") or Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 10)
	layout.Parent = bar

	setupCurrencyFrame(bar, "CoinsFrame", GOLD, 1)
	setupCurrencyFrame(bar, "GemsFrame", EMERALD, 2)

	print("PhysicalCurrencyHUDBuilder: built StarterGui.ColorSimulatorUI.MainHUD.CurrencyBar")
	return bar
end

return PhysicalCurrencyHUDBuilder
