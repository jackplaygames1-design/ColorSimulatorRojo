-- Studio-only helper for creating editable menu window shells in StarterGui.
-- Run from the Studio command bar in edit mode:
-- require(game.ReplicatedStorage.StudioMenuWindowsBuilder).Build()
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Builder = {}

local function findOrCreate(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing, false
	end
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance, true
end

local function applyCorner(instance, radius)
	local corner = instance:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 18)
	corner.Parent = instance
	return corner
end

local function applyStroke(instance, color, thickness)
	local stroke = instance:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	stroke.Color = color or Color3.fromRGB(35, 38, 45)
	stroke.Thickness = thickness or 3
	stroke.Parent = instance
	return stroke
end

local function text(parent, name, value, position, size, textSize)
	local label, created = findOrCreate(parent, "TextLabel", name)
	if created then
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.TextColor3 = Color3.fromRGB(38, 36, 52)
		label.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
		label.TextStrokeTransparency = 0.35
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Center
	end
	label.Text = value
	label.Position = position
	label.Size = size
	label.TextSize = textSize or 22
	return label
end

local function button(parent, name, value, position, size, color)
	local btn, created = findOrCreate(parent, "TextButton", name)
	if created then
		btn.AutoButtonColor = true
		btn.Font = Enum.Font.GothamBlack
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.TextStrokeColor3 = Color3.fromRGB(35, 38, 45)
		btn.TextStrokeTransparency = 0
	end
	btn.Text = value
	btn.Position = position
	btn.Size = size
	btn.BackgroundColor3 = color or Color3.fromRGB(84, 225, 112)
	btn.BorderSizePixel = 0
	applyCorner(btn, 12)
	applyStroke(btn, Color3.fromRGB(35, 38, 45), 2)
	return btn
end

local function frame(parent, name, position, size, color)
	local f, created = findOrCreate(parent, "Frame", name)
	if created then
		f.BorderSizePixel = 0
	end
	f.Position = position
	f.Size = size
	f.BackgroundColor3 = color or Color3.fromRGB(255, 255, 255)
	applyCorner(f, 18)
	applyStroke(f, Color3.fromRGB(35, 38, 45), 2)
	return f
end

local function makeTabs(window, names)
	local tabs = frame(window, "Tabs", UDim2.fromOffset(22, 68), UDim2.new(1, -44, 0, 40), Color3.fromRGB(255, 255, 255))
	tabs.BackgroundTransparency = 1
	local layout = tabs:FindFirstChildOfClass("UIListLayout") or Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = tabs

	for index, tabName in ipairs(names) do
		local tab = button(tabs, tabName .. "Tab", tabName, UDim2.fromOffset(0, 0), UDim2.fromOffset(118, 34), index == 1 and Color3.fromRGB(82, 219, 225) or Color3.fromRGB(232, 238, 248))
		tab.LayoutOrder = index
		tab.TextColor3 = index == 1 and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(38, 36, 52)
	end
	return tabs
end

local function makeWindow(windowsFolder, name, title, tabs)
	local window = frame(windowsFolder, name, UDim2.fromScale(0.5, 0.43), UDim2.fromOffset(780, 470), Color3.fromRGB(255, 255, 255))
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Visible = false
	window.ClipsDescendants = false
	applyCorner(window, 24)
	applyStroke(window, Color3.fromRGB(35, 38, 45), 4)

	text(window, "Title", title, UDim2.fromOffset(24, 14), UDim2.new(1, -112, 0, 42), 30)
	button(window, "CloseButton", "X", UDim2.new(1, -70, 0, 14), UDim2.fromOffset(52, 48), Color3.fromRGB(188, 21, 28))
	if tabs and #tabs > 0 then
		makeTabs(window, tabs)
	end

	local content = frame(window, "Content", UDim2.fromOffset(22, tabs and 122 or 82), UDim2.new(1, -44, 1, tabs and -148 or -108), Color3.fromRGB(244, 248, 252))
	content.ClipsDescendants = false
	return window, content
end

local function makeInventory(windowsFolder)
	local window, content = makeWindow(windowsFolder, "InventoryWindow", "INVENTORY", { "Colors", "Brushes", "Potions", "Items" })
	local grid = frame(content, "ItemGrid", UDim2.fromOffset(12, 12), UDim2.new(0.62, -20, 1, -24), Color3.fromRGB(246, 249, 255))
	local details = frame(content, "DetailsPanel", UDim2.new(0.64, 0, 0, 12), UDim2.new(0.36, -12, 1, -24), Color3.fromRGB(239, 246, 255))
	text(details, "SelectLabel", "Select an Item", UDim2.fromOffset(14, 12), UDim2.new(1, -28, 0, 36), 22).TextXAlignment = Enum.TextXAlignment.Center
	for i = 1, 8 do
		local x = ((i - 1) % 4) * 104 + 14
		local y = math.floor((i - 1) / 4) * 104 + 14
		local slot = frame(grid, "Slot" .. i, UDim2.fromOffset(x, y), UDim2.fromOffset(92, 92), Color3.fromRGB(235, 239, 246))
		text(slot, "Icon", "IMG", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 18).TextXAlignment = Enum.TextXAlignment.Center
	end
	button(details, "EquipButton", "EQUIP", UDim2.new(0, 14, 1, -132), UDim2.new(1, -28, 0, 34), Color3.fromRGB(84, 225, 112))
	button(details, "LockButton", "LOCK", UDim2.new(0, 14, 1, -90), UDim2.new(1, -28, 0, 34), Color3.fromRGB(88, 174, 255))
	button(details, "DeleteButton", "DELETE", UDim2.new(0, 14, 1, -48), UDim2.new(1, -28, 0, 34), Color3.fromRGB(220, 46, 58))
	return window
end

local function makeCardGrid(content, names)
	for index, item in ipairs(names) do
		local x = ((index - 1) % 3) * 238 + 14
		local y = math.floor((index - 1) / 3) * 132 + 14
		local card = frame(content, item:gsub("%s+", "") .. "Card", UDim2.fromOffset(x, y), UDim2.fromOffset(222, 118), Color3.fromRGB(255, 255, 255))
		local icon = frame(card, "Icon", UDim2.fromOffset(10, 10), UDim2.fromOffset(58, 58), Color3.fromRGB(225, 244, 255))
		text(icon, "IconText", item:sub(1, 2):upper(), UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 18).TextXAlignment = Enum.TextXAlignment.Center
		text(card, "Name", item, UDim2.fromOffset(78, 8), UDim2.new(1, -88, 0, 28), 17)
		text(card, "Description", "Editable item card.", UDim2.fromOffset(78, 38), UDim2.new(1, -88, 0, 34), 12)
		text(card, "Price", "Price", UDim2.fromOffset(10, 76), UDim2.fromOffset(90, 28), 13)
		button(card, "BuyButton", "BUY", UDim2.new(1, -110, 1, -42), UDim2.fromOffset(96, 32), Color3.fromRGB(84, 225, 112))
	end
end

local function makeShopTemplates(shopWindow)
	local templates = findOrCreate(shopWindow, "Folder", "Templates")
	local card, created = findOrCreate(templates, "Frame", "ShopCardTemplate")
	card.Visible = false
	card.Size = UDim2.new(1, -6, 0, 116)
	card.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	card.BorderSizePixel = 0
	applyCorner(card, 12)
	applyStroke(card, Color3.fromRGB(35, 38, 45), 2)

	local icon = frame(card, "Icon", UDim2.fromOffset(12, 14), UDim2.fromOffset(72, 72), Color3.fromRGB(244, 248, 252))
	text(icon, "IconText", "VIP", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 20).TextXAlignment = Enum.TextXAlignment.Center

	local image = icon:FindFirstChild("IconImage")
	if not image then
		image = Instance.new("ImageLabel")
		image.Name = "IconImage"
		image.Parent = icon
	end
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(1, 1)
	image.Visible = false

	text(card, "Name", "Product", UDim2.fromOffset(96, 10), UDim2.new(1, -238, 0, 26), 18)
	text(card, "Description", "Description", UDim2.fromOffset(96, 38), UDim2.new(1, -238, 0, 40), 13)
	text(card, "Badge", "BADGE", UDim2.fromOffset(96, 80), UDim2.new(1, -238, 0, 22), 12)
	text(card, "Price", "R$ 0", UDim2.new(1, -130, 0, 14), UDim2.fromOffset(112, 24), 14).TextXAlignment = Enum.TextXAlignment.Center
	button(card, "BuyButton", "BUY", UDim2.new(1, -130, 1, -48), UDim2.fromOffset(112, 34), Color3.fromRGB(84, 225, 112))

	if created then
		print("StudioMenuWindowsBuilder: created ShopWindow.Templates.ShopCardTemplate")
	end
end

function Builder.Build()
	if not RunService:IsStudio() then
		warn("StudioMenuWindowsBuilder.Build can only run in Roblox Studio.")
		return
	end
	if RunService:IsRunning() then
		warn("StudioMenuWindowsBuilder.Build should be run in edit mode, not during Play.")
		return
	end

	local root = findOrCreate(StarterGui, "ScreenGui", "ClientUIRoot")
	root.ResetOnSpawn = false
	root.IgnoreGuiInset = false
	root.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	root.DisplayOrder = math.max(root.DisplayOrder, 100)

	local mainHud = frame(root, "MainHUD", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), Color3.fromRGB(255, 255, 255))
	mainHud.BackgroundTransparency = 1
	mainHud.Visible = true
	mainHud.ClipsDescendants = false

	findOrCreate(mainHud, "Frame", "CurrencyBar").BackgroundTransparency = 1
	findOrCreate(mainHud, "Frame", "BottomRow").BackgroundTransparency = 1
	local dim = findOrCreate(mainHud, "TextButton", "DimBackground")
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	dim.BackgroundTransparency = 0.45
	dim.Text = ""
	dim.Visible = false

	local modalWindows = findOrCreate(mainHud, "Folder", "ModalWindows")
	local windowsFolder = findOrCreate(modalWindows, "Folder", "Windows")
	makeInventory(windowsFolder)
	local shopWindow = makeWindow(windowsFolder, "ShopWindow", "ROBUX SHOP", { "Bundles", "Gamepasses", "Potions", "Currency" })
	makeShopTemplates(shopWindow)
	local _, upgradesContent = makeWindow(windowsFolder, "UpgradesWindow", "UPGRADES", { "Player", "Colors", "Rank" })
	makeCardGrid(upgradesContent, { "Walk Speed", "Brush Power", "Coin Boost", "Gem Luck" })
	local _, settingsContent = makeWindow(windowsFolder, "SettingsWindow", "SETTINGS", {})
	makeCardGrid(settingsContent, { "Music", "SFX", "Hide Pets", "Low Detail", "Auto Delete" })
	local _, codesContent = makeWindow(windowsFolder, "CodesWindow", "CODES", {})
	makeCardGrid(codesContent, { "CodeBox", "RedeemButton", "InfoText", "RecentRewards" })
	local _, tradeContent = makeWindow(windowsFolder, "TradeWindow", "TRADE", {})
	text(tradeContent, "ComingSoon", "Trading is coming soon!", UDim2.fromScale(0, 0.35), UDim2.fromScale(1, 0.18), 28).TextXAlignment = Enum.TextXAlignment.Center
	local _, worldsContent = makeWindow(windowsFolder, "WorldsWindow", "WORLDS", {})
	makeCardGrid(worldsContent, { "Origin Sector", "Red Wastelands", "Orange Sector", "Inside Pipes" })
	local _, questsContent = makeWindow(windowsFolder, "DailyQuestsWindow", "DAILY QUESTS", {})
	makeCardGrid(questsContent, { "Clean Color Spills", "Earn Coins", "Hatch Colors" })

	print("StudioMenuWindowsBuilder: editable UI created at StarterGui.ClientUIRoot.MainHUD.ModalWindows.Windows")
end

return Builder
