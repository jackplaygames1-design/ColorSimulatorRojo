-- Run once from the Studio Command Bar in edit mode:
-- require(game.ReplicatedStorage.PhysicalMenuUIBuilder).Build()
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local PhysicalMenuUIBuilder = {}
local PhysicalCurrencyHUDBuilder

local function canBuild()
	if not RunService:IsStudio() then
		warn("PhysicalMenuUIBuilder.Build can only run in Roblox Studio.")
		return false
	end
	if RunService:IsRunning() then
		warn("PhysicalMenuUIBuilder.Build should be run from the Studio Command Bar in edit mode, not during Play.")
		return false
	end
	return true
end

local function findOrCreate(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing, false
	end
	if existing then
		warn("PhysicalMenuUIBuilder: " .. name .. " exists but is " .. existing.ClassName .. "; leaving it alone.")
		return existing, false
	end

	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance, true
end

local function addCorner(parent, radius)
	if parent:FindFirstChildOfClass("UICorner") then
		return
	end
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius or UDim.new(0, 18)
	corner.Parent = parent
end

local function addStroke(parent, color, thickness)
	if parent:FindFirstChildOfClass("UIStroke") then
		return
	end
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Color3.fromRGB(36, 32, 44)
	stroke.Thickness = thickness or 3
	stroke.Parent = parent
end

local function addLabel(parent, name, text)
	local label, created = findOrCreate(parent, "TextLabel", name)
	if created then
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.LuckiestGuy
		label.TextSize = 22
		label.TextColor3 = Color3.fromRGB(255, 247, 235)
		label.TextStrokeTransparency = 0.12
		label.TextStrokeColor3 = Color3.fromRGB(60, 52, 72)
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.Active = false
	end
	label.Text = text
	return label
end

local function setupMenuTile(parent, name, labelText, layoutOrder, color)
	local button, created = findOrCreate(parent, "TextButton", name)
	if created then
		button.Size = UDim2.new(0, 150, 0, 94)
		button.BackgroundColor3 = color
		button.AutoButtonColor = false
		button.Text = ""
		button.Active = true
		button.Selectable = true
		addCorner(button, UDim.new(0, 18))
		addStroke(button, Color3.fromRGB(36, 32, 44), 3)

		local highlight = Instance.new("Frame")
		highlight.Name = "TopHighlight"
		highlight.Size = UDim2.new(1, -12, 0, 30)
		highlight.Position = UDim2.new(0, 6, 0, 6)
		highlight.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		highlight.BackgroundTransparency = 0.78
		highlight.BorderSizePixel = 0
		highlight.Active = false
		highlight.Parent = button
		addCorner(highlight, UDim.new(0, 14))
	end
	button.LayoutOrder = layoutOrder
	addLabel(button, "Label", labelText)
	return button
end

local function setupMenuButton(mainHud)
	local existing = mainHud:FindFirstChild("MenuButton", true)
	if existing and existing:IsA("GuiButton") then
		return existing
	end

	local button = Instance.new("ImageButton")
	button.Name = "MenuButton"
	button.Size = UDim2.new(0, 86, 0, 86)
	button.Position = UDim2.new(0.5, -43, 1, -112)
	button.BackgroundTransparency = 1
	button.AutoButtonColor = false
	button.ScaleType = Enum.ScaleType.Fit
	button.Active = true
	button.Selectable = true
	button.Parent = mainHud
	return button
end

function PhysicalMenuUIBuilder.Build()
	if not canBuild() then
		return nil
	end

	local screen = StarterGui:FindFirstChild("ScreenGui")
	if not screen then
		screen = StarterGui:FindFirstChild("ColorSimulatorUI")
	end
	if not screen then
		screen = Instance.new("ScreenGui")
		screen.Name = "ScreenGui"
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

	setupMenuButton(mainHud)

	local menu, createdMenu = findOrCreate(screen, "Frame", "PhysicalMenuUI")
	if createdMenu then
		menu.Visible = false
		menu.BackgroundTransparency = 1
		menu.Size = UDim2.fromScale(1, 1)
		menu.Position = UDim2.fromScale(0, 0)
		menu.ZIndex = 55
	end

local backdrop, createdBackdrop = findOrCreate(menu, "Frame", "Backdrop")
if createdBackdrop then
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	backdrop.BackgroundTransparency = 0.45
	backdrop.BorderSizePixel = 0
	backdrop.ZIndex = 55
	backdrop.Active = false
	backdrop.Selectable = false
end

	local panel, createdPanel = findOrCreate(menu, "Frame", "Panel")
	if createdPanel then
		panel.AnchorPoint = Vector2.new(0.5, 0.5)
		panel.Position = UDim2.fromScale(0.5, 0.5)
		panel.Size = UDim2.new(0, 420, 0, 310)
		panel.BackgroundColor3 = Color3.fromRGB(255, 247, 235)
		panel.ZIndex = 60
		addCorner(panel, UDim.new(0, 24))
		addStroke(panel, Color3.fromRGB(36, 32, 44), 5)
	end

	local header, createdHeader = findOrCreate(panel, "Frame", "Header")
	if createdHeader then
		header.Size = UDim2.new(1, 0, 0, 66)
		header.BackgroundColor3 = Color3.fromRGB(118, 238, 244)
		header.BorderSizePixel = 0
		header.ZIndex = 61
		addCorner(header, UDim.new(0, 20))
	end
	local title = addLabel(header, "Title", "MENU")
	title.TextSize = 32
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Position = UDim2.new(0, 22, 0, 0)
	title.Size = UDim2.new(1, -90, 1, 0)

	local closeButton, createdClose = findOrCreate(header, "TextButton", "CloseButton")
	if createdClose then
		closeButton.AnchorPoint = Vector2.new(1, 0.5)
		closeButton.Position = UDim2.new(1, -16, 0.5, 0)
		closeButton.Size = UDim2.new(0, 44, 0, 44)
		closeButton.BackgroundColor3 = Color3.fromRGB(255, 24, 96)
		closeButton.AutoButtonColor = false
		closeButton.Text = "X"
		closeButton.Font = Enum.Font.LuckiestGuy
		closeButton.TextSize = 22
		closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		closeButton.TextStrokeTransparency = 0.12
		closeButton.ZIndex = 62
		addCorner(closeButton, UDim.new(0, 14))
		addStroke(closeButton, Color3.fromRGB(36, 32, 44), 3)
	end

	local grid, createdGrid = findOrCreate(panel, "Frame", "Grid")
	if createdGrid then
		grid.BackgroundTransparency = 1
		grid.Position = UDim2.new(0, 22, 0, 88)
		grid.Size = UDim2.new(1, -44, 1, -110)
		grid.ZIndex = 61
	end
	if not grid:FindFirstChildOfClass("UIGridLayout") then
		local layout = Instance.new("UIGridLayout")
		layout.CellSize = UDim2.new(0, 170, 0, 82)
		layout.CellPadding = UDim2.new(0, 18, 0, 16)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.VerticalAlignment = Enum.VerticalAlignment.Top
		layout.Parent = grid
	end

	setupMenuTile(grid, "MenuBtn_INVENTORY", "INVENTORY", 1, Color3.fromRGB(246, 196, 138))
	setupMenuTile(grid, "MenuBtn_GROUP", "GROUP", 2, Color3.fromRGB(150, 238, 162))
	setupMenuTile(grid, "MenuBtn_SETTINGS", "SETTINGS", 3, Color3.fromRGB(214, 211, 239))
	setupMenuTile(grid, "MenuBtn_GAMEPASS", "MARKET", 4, Color3.fromRGB(246, 227, 99))

	print("PhysicalMenuUIBuilder: PhysicalMenuUI is ready in StarterGui." .. screen.Name .. ". Edit it in Studio, then save.")
	return menu
end

function PhysicalMenuUIBuilder.BuildCurrencyHUD()
	if not PhysicalCurrencyHUDBuilder then
		PhysicalCurrencyHUDBuilder = require(script.Parent:WaitForChild("PhysicalCurrencyHUDBuilder"))
	end
	return PhysicalCurrencyHUDBuilder.Build()
end

return PhysicalMenuUIBuilder
