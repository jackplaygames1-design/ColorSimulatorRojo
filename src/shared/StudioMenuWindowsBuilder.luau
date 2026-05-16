-- Studio-only helper for creating editable menu window shells in StarterGui.
-- Run from the Studio command bar in edit mode:
-- require(game.ReplicatedStorage.StudioMenuWindowsBuilder).Build()
-- Settings-only refresh:
-- require(game.ReplicatedStorage.StudioMenuWindowsBuilder).UpdateSettingsWindow()
-- Codes-only refresh:
-- require(game.ReplicatedStorage.StudioMenuWindowsBuilder).UpdateCodesWindow()
-- Shop-only refresh:
-- require(game.ReplicatedStorage.StudioMenuWindowsBuilder).UpdateShopWindow()
-- Upgrades icon refresh:
-- require(game.ReplicatedStorage.StudioMenuWindowsBuilder).ApplyUpgradeIcons()
-- Gamepass icon refresh:
-- require(game.ReplicatedStorage.StudioMenuWindowsBuilder).ApplyGamepassIcons()
-- Worlds-only refresh:
-- require(game.ReplicatedStorage.StudioMenuWindowsBuilder).UpdateWorldsWindow()
-- Index-only refresh:
-- require(game.ReplicatedStorage.StudioMenuWindowsBuilder).UpdateIndexWindow()
-- Zork/tutorial windows refresh:
-- require(game.ReplicatedStorage.StudioMenuWindowsBuilder).UpdateZorkWindows()
-- Power-up toast refresh:
-- require(game.ReplicatedStorage.StudioMenuWindowsBuilder).UpdatePowerUpToastUI()
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Builder = {}

local function requireFresh(module)
	local clone = module:Clone()
	clone.Parent = module.Parent
	local ok, result = pcall(require, clone)
	clone:Destroy()
	if ok then
		return result
	end
	warn("StudioMenuWindowsBuilder: fresh require failed for " .. module.Name .. ": " .. tostring(result))
	return require(module)
end

local RobuxShopConfig = requireFresh(ReplicatedStorage:WaitForChild("RobuxShopConfig"))
local ColorData = requireFresh(ReplicatedStorage:WaitForChild("ColorData"))
local GameBalance = requireFresh(ReplicatedStorage:WaitForChild("GameBalance"))
local ToolData = requireFresh(ReplicatedStorage:WaitForChild("ToolData"))
local UpgradeData = requireFresh(ReplicatedStorage:WaitForChild("UpgradeData"))
local UpgradeIconConfig = requireFresh(ReplicatedStorage:WaitForChild("UpgradeIconConfig"))
local GamepassIconConfig = requireFresh(ReplicatedStorage:WaitForChild("GamepassIconConfig"))
local UITheme = requireFresh(ReplicatedStorage:WaitForChild("UITheme"))

local OUTLINE = Color3.fromRGB(35, 38, 45)
local TEXT_DARK = Color3.fromRGB(38, 36, 52)
local TAB_INACTIVE = Color3.fromRGB(232, 238, 248)
local CYAN = Color3.fromRGB(76, 214, 224)
local GREEN = Color3.fromRGB(84, 225, 112)
local MUTED = Color3.fromRGB(92, 98, 116)
local DISABLED = Color3.fromRGB(170, 180, 205)
local PANEL = Color3.fromRGB(244, 248, 252)
local STANDARD_WINDOW_POSITION = UDim2.fromScale(0.5, 0.47)
local STANDARD_WINDOW_SIZE = UDim2.fromScale(0.72, 0.72)
local STANDARD_CLOSE_POSITION = UDim2.new(1, -78, 0, -42)
local STANDARD_CLOSE_SIZE = UDim2.fromOffset(70, 70)
local INVENTORY_CARD_POOL_SIZE = 96
local MENU_ACCENTS = (UITheme and UITheme.MenuAccents) or {}
local MENU_PANELS = (UITheme and UITheme.MenuPanels) or {}

local makeResponsiveWindow

local function getMenuAccent(name)
	return MENU_ACCENTS[name] or MENU_ACCENTS.Default or CYAN
end

local function tintTowardWhite(color, amount)
	return (color or CYAN):Lerp(Color3.fromRGB(255, 255, 255), amount or 0.82)
end

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

local FALLBACK_INFINITE_PACK = {
	displayName = "THE FOREVER PACK!",
	tiers = {
		{
			id = "InfinitePackTier01",
			tier = 1,
			rewardText = "250 Gems",
			icon = "GEM",
			price = 0,
			free = true,
			color = Color3.fromRGB(92, 240, 150),
			rewardKind = "Gem",
			amount = 250,
			iconKey = "Gems",
			gemReward = 250,
		},
		{
			id = "InfinitePackTier02",
			tier = 2,
			rewardText = "3x Coin Potion",
			icon = "2x",
			price = 50,
			color = Color3.fromRGB(255, 221, 84),
		},
		{
			id = "InfinitePackTier03",
			tier = 3,
			rewardText = "2x Luck Potion",
			icon = "LU",
			price = 0,
			free = true,
			color = Color3.fromRGB(128, 239, 150),
		},
		{
			id = "InfinitePackTier04",
			tier = 4,
			rewardText = "Exclusive Color",
			icon = "???",
			price = 100,
			color = Color3.fromRGB(255, 162, 196),
		},
		{
			id = "InfinitePackTier05",
			tier = 5,
			rewardText = "25,000 Coins",
			icon = "$",
			price = 0,
			free = true,
			color = Color3.fromRGB(255, 199, 87),
			rewardKind = "Coin",
			amount = 25000,
			iconKey = "Coins",
			coinReward = 25000,
		},
		{
			id = "InfinitePackTier06",
			tier = 6,
			rewardText = "Exclusive Pet",
			icon = "PET",
			price = 250,
			color = Color3.fromRGB(177, 141, 255),
		},
	},
}

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
	stroke.Color = color or OUTLINE
	stroke.Thickness = thickness or 3
	stroke.Parent = instance
	return stroke
end

local function text(parent, name, value, position, size, textSize)
	local label, created = findOrCreate(parent, "TextLabel", name)
	if created then
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.TextColor3 = TEXT_DARK
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
		btn.TextStrokeColor3 = OUTLINE
		btn.TextStrokeTransparency = 0
	end
	btn.Text = value
	btn.Position = position
	btn.Size = size
	btn.BackgroundColor3 = color or GREEN
	btn.BorderSizePixel = 0
	applyCorner(btn, 12)
	applyStroke(btn, OUTLINE, 2)
	return btn
end

local function applyBigXText(guiObject, zIndex)
	local function styleText(textObject)
		textObject.Text = "X"
		textObject.TextColor3 = Color3.fromRGB(255, 255, 255)
		textObject.TextSize = 48
		textObject.TextScaled = false
		textObject.TextStrokeColor3 = OUTLINE
		textObject.TextStrokeTransparency = 0
		textObject.TextXAlignment = Enum.TextXAlignment.Center
		textObject.TextYAlignment = Enum.TextYAlignment.Center
		textObject.ZIndex = zIndex or textObject.ZIndex
		textObject.Font = Enum.Font.GothamBlack
		pcall(function()
			textObject.FontFace =
				Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy, Enum.FontStyle.Normal)
		end)
	end

	if guiObject:IsA("TextButton") or guiObject:IsA("TextLabel") then
		styleText(guiObject)
		local runtimeText = guiObject:FindFirstChild("RuntimeText")
		if runtimeText and runtimeText:IsA("GuiObject") then
			runtimeText.Visible = false
		end
		local closeIcon = guiObject:FindFirstChild("CloseIcon")
		if closeIcon and closeIcon:IsA("GuiObject") then
			closeIcon.Visible = false
		end
		return
	end

	local runtimeText = guiObject:FindFirstChild("RuntimeText")
	if runtimeText and runtimeText:IsA("GuiObject") then
		runtimeText:Destroy()
	end

	local closeIcon = guiObject:FindFirstChild("CloseIcon")
	if not closeIcon or not closeIcon:IsA("TextLabel") then
		if closeIcon then
			closeIcon:Destroy()
		end
		closeIcon = Instance.new("TextLabel")
		closeIcon.Name = "CloseIcon"
		closeIcon.BackgroundTransparency = 1
		closeIcon.BorderSizePixel = 0
		closeIcon.Position = UDim2.fromScale(0, 0)
		closeIcon.Size = UDim2.fromScale(1, 1)
		closeIcon.Parent = guiObject
	end
	closeIcon.Visible = true
	styleText(closeIcon)
end

local function styleCloseButton(closeButton, position, size, zIndex)
	closeButton.Position = position
	closeButton.Size = size
	closeButton.BackgroundColor3 = Color3.fromRGB(188, 21, 28)
	closeButton.BorderSizePixel = 0
	closeButton.ZIndex = zIndex or closeButton.ZIndex
	closeButton:SetAttribute("NoTextGlow", true)
	if closeButton:IsA("GuiButton") then
		closeButton.AutoButtonColor = true
	end
	applyCorner(closeButton, 14)
	applyStroke(closeButton, OUTLINE, 2)
	applyBigXText(closeButton, (zIndex or closeButton.ZIndex) + 1)
	return closeButton
end

local function textBox(parent, name, placeholder, position, size)
	local existing = parent:FindFirstChild(name)
	if existing and not existing:IsA("TextBox") then
		existing.Name = name .. "Legacy"
		if existing:IsA("GuiObject") then
			existing.Visible = false
		end
		existing = nil
	end

	local box = existing or Instance.new("TextBox")
	box.Name = name
	box.ClearTextOnFocus = false
	box.Font = Enum.Font.GothamBlack
	box.PlaceholderText = placeholder
	box.PlaceholderColor3 = Color3.fromRGB(130, 138, 158)
	box.Text = ""
	box.TextColor3 = Color3.fromRGB(38, 36, 52)
	box.TextSize = 24
	box.TextXAlignment = Enum.TextXAlignment.Center
	box.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	box.BorderSizePixel = 0
	box.Position = position
	box.Size = size
	box.Parent = parent
	applyCorner(box, 16)
	applyStroke(box, Color3.fromRGB(35, 38, 45), 3)
	return box
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
	local tabs =
		frame(window, "Tabs", UDim2.fromOffset(22, 68), UDim2.new(1, -44, 0, 40), Color3.fromRGB(255, 255, 255))
	tabs.BackgroundTransparency = 1
	local layout = tabs:FindFirstChildOfClass("UIListLayout") or Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = tabs

	for index, tabName in ipairs(names) do
		local tab = button(
			tabs,
			tabName .. "Tab",
			tabName,
			UDim2.fromOffset(0, 0),
			UDim2.fromOffset(118, 34),
			index == 1 and Color3.fromRGB(82, 219, 225) or Color3.fromRGB(232, 238, 248)
		)
		tab.LayoutOrder = index
		tab.TextColor3 = index == 1 and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(38, 36, 52)
	end
	return tabs
end

local function makeWindow(windowsFolder, name, title, tabs)
	local window =
		frame(windowsFolder, name, STANDARD_WINDOW_POSITION, STANDARD_WINDOW_SIZE, Color3.fromRGB(255, 255, 255))
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Visible = false
	window.ClipsDescendants = false
	applyCorner(window, 24)
	applyStroke(window, Color3.fromRGB(35, 38, 45), 4)

	text(window, "Title", title, UDim2.fromOffset(24, 14), UDim2.new(1, -112, 0, 42), 30)
	styleCloseButton(
		button(window, "CloseButton", "X", STANDARD_CLOSE_POSITION, STANDARD_CLOSE_SIZE, Color3.fromRGB(188, 21, 28)),
		STANDARD_CLOSE_POSITION,
		STANDARD_CLOSE_SIZE,
		window.ZIndex + 3
	)
	if tabs and #tabs > 0 then
		makeTabs(window, tabs)
	end

	local content = frame(
		window,
		"Content",
		UDim2.fromOffset(22, tabs and 122 or 82),
		UDim2.new(1, -44, 1, tabs and -148 or -108),
		Color3.fromRGB(244, 248, 252)
	)
	content.ClipsDescendants = false
	makeResponsiveWindow(window, content)
	return window, content
end

local function makeInventory(windowsFolder)
	local window, content =
		makeWindow(windowsFolder, "InventoryWindow", "INVENTORY", { "Colors", "Brushes", "Potions", "Items" })
	window.Size = STANDARD_WINDOW_SIZE
	window.Position = STANDARD_WINDOW_POSITION
	content.Size = UDim2.new(1, -44, 1, -148)
	local tabs = window:FindFirstChild("Tabs")
	if tabs then
		local layout = tabs:FindFirstChildOfClass("UIListLayout")
		if layout then
			layout.Padding = UDim.new(0, 8)
		end
		for index, tabName in ipairs({ "Colors", "Brushes", "Potions", "Items" }) do
			local tab = tabs:FindFirstChild(tabName .. "Tab")
			if tab and tab:IsA("GuiObject") then
				tab.LayoutOrder = index
				tab.Size = UDim2.new(0.25, -8, 1, -4)
			end
		end
	end

	local grid = frame(
		content,
		"ItemGrid",
		UDim2.fromOffset(12, 12),
		UDim2.new(0.66, -20, 1, -24),
		Color3.fromRGB(246, 249, 255)
	)
	local details = frame(
		content,
		"DetailsPanel",
		UDim2.new(0.68, 0, 0, 12),
		UDim2.new(0.32, -12, 1, -24),
		Color3.fromRGB(239, 246, 255)
	)
	frame(details, "BigPreview", UDim2.fromOffset(16, 16), UDim2.new(1, -32, 0, 90), Color3.fromRGB(255, 255, 255))
	text(details, "SelectedName", "Select an Item", UDim2.fromOffset(16, 118), UDim2.new(1, -32, 0, 30), 20).TextXAlignment =
		Enum.TextXAlignment.Center
	text(details, "SelectedRarity", "", UDim2.fromOffset(16, 150), UDim2.new(1, -32, 0, 22), 14).TextXAlignment =
		Enum.TextXAlignment.Center
	text(
		details,
		"SelectedDescription",
		"Choose a card to see details.",
		UDim2.fromOffset(16, 178),
		UDim2.new(1, -32, 0, 46),
		13
	).TextXAlignment =
		Enum.TextXAlignment.Left
	local stats =
		frame(details, "StatsBox", UDim2.fromOffset(16, 230), UDim2.new(1, -32, 0, 34), Color3.fromRGB(255, 255, 255))
	text(stats, "StatsText", "", UDim2.fromOffset(10, 6), UDim2.new(1, -20, 1, -12), 12)
	for i = 1, 12 do
		local x = ((i - 1) % 4) * 124 + 14
		local y = math.floor((i - 1) / 4) * 114 + 14
		local slot =
			frame(grid, "Slot" .. i, UDim2.fromOffset(x, y), UDim2.fromOffset(112, 102), Color3.fromRGB(235, 239, 246))
		local icon =
			frame(slot, "Icon", UDim2.fromOffset(8, 8), UDim2.new(1, -16, 0, 54), Color3.fromRGB(225, 235, 248))
		text(icon, "IconText", "IMG", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 18).TextXAlignment =
			Enum.TextXAlignment.Center
		text(slot, "ItemName", "Item", UDim2.new(0, 6, 1, -36), UDim2.new(1, -12, 0, 18), 12).TextXAlignment =
			Enum.TextXAlignment.Center
		text(slot, "ItemMeta", "", UDim2.new(0, 6, 1, -18), UDim2.new(1, -12, 0, 14), 10).TextXAlignment =
			Enum.TextXAlignment.Center
	end
	button(
		details,
		"EquipButton",
		"EQUIP",
		UDim2.new(0, 16, 1, -116),
		UDim2.new(1, -32, 0, 32),
		Color3.fromRGB(84, 225, 112)
	)
	button(
		details,
		"LockButton",
		"LOCK",
		UDim2.new(0, 16, 1, -76),
		UDim2.new(1, -32, 0, 32),
		Color3.fromRGB(88, 174, 255)
	)
	button(
		details,
		"DeleteButton",
		"DELETE",
		UDim2.new(0, 16, 1, -36),
		UDim2.new(1, -32, 0, 32),
		Color3.fromRGB(220, 46, 58)
	)
	return window
end

local function getUpgradeIconSpec(cardName, upgradeId)
	local iconKey = nil
	if upgradeId and UpgradeIconConfig.ByUpgradeId then
		iconKey = UpgradeIconConfig.ByUpgradeId[upgradeId]
	end
	if not iconKey and cardName and UpgradeIconConfig.ByCardName then
		iconKey = UpgradeIconConfig.ByCardName[cardName]
	end
	if not iconKey then
		return nil, nil
	end
	local spec = UpgradeIconConfig.Icons and UpgradeIconConfig.Icons[iconKey]
	return iconKey, spec
end

local function getUpgradeCardName(card)
	local nameLabel = card and card:FindFirstChild("Name", true)
	if nameLabel and (nameLabel:IsA("TextLabel") or nameLabel:IsA("TextButton")) then
		return tostring(nameLabel.Text or "")
	end
	local fallback = tostring(card and card.Name or "")
	fallback = fallback:gsub("Card$", "")
	fallback = fallback:gsub("(%l)(%u)", "%1 %2")
	return fallback
end

local function applyUpgradeIconToCard(card, cardName, upgradeId)
	if not card or not card:IsA("GuiObject") then
		return
	end

	local iconKey, spec = getUpgradeIconSpec(cardName or getUpgradeCardName(card), upgradeId)
	if not spec then
		return
	end

	card:SetAttribute("UpgradeIconKey", iconKey)
	card:SetAttribute("ExpectedUpgradeIconFile", spec.SourceFile or "")

	local iconFrame = card:FindFirstChild("Icon", true)
	if not iconFrame or not iconFrame:IsA("GuiObject") then
		return
	end
	iconFrame:SetAttribute("UpgradeIconKey", iconKey)
	iconFrame:SetAttribute("ExpectedUpgradeIconFile", spec.SourceFile or "")

	local iconImage = iconFrame:FindFirstChild("IconImage")
	if not iconImage or not iconImage:IsA("ImageLabel") then
		iconImage = Instance.new("ImageLabel")
		iconImage.Name = "IconImage"
		iconImage.Parent = iconFrame
	end
	iconImage.BackgroundTransparency = 1
	iconImage.BorderSizePixel = 0
	iconImage.Position = UDim2.fromOffset(2, 2)
	iconImage.Size = UDim2.new(1, -4, 1, -4)
	iconImage.ScaleType = Enum.ScaleType.Fit
	iconImage.ZIndex = iconFrame.ZIndex + 1
	iconImage:SetAttribute("UpgradeIconKey", iconKey)
	iconImage:SetAttribute("ExpectedUpgradeIconFile", spec.SourceFile or "")
	iconImage.Image = tostring(spec.Image or "")
	iconImage.Visible = iconImage.Image ~= ""

	local iconText = iconFrame:FindFirstChild("IconText")
	if iconText and iconText:IsA("TextLabel") then
		iconText.Visible = iconImage.Image == ""
		iconText.ZIndex = iconFrame.ZIndex + 2
	end
end

local function applyUpgradeIconsToWindow(upgradesWindow)
	if not upgradesWindow then
		return 0
	end

	local applied = 0
	for _, descendant in ipairs(upgradesWindow:GetDescendants()) do
		if descendant:IsA("GuiObject") and string.match(descendant.Name, "Card$") then
			local before = descendant:GetAttribute("UpgradeIconKey")
			applyUpgradeIconToCard(descendant)
			if
				descendant:GetAttribute("UpgradeIconKey") ~= before
				or descendant:GetAttribute("UpgradeIconKey") ~= nil
			then
				applied += 1
			end
		end
	end
	return applied
end

local DAILY_QUEST_PREVIEWS = {
	{
		iconText = "BRUSH",
		title = "CLEAN COLOR SPILLS",
		description = "Clean 40 color spills.",
		progress = "0 / 40",
		reward = "REWARD\n+20 Gems",
	},
	{
		iconText = "COINS",
		title = "EARN COINS",
		description = "Earn 1,000 coins.",
		progress = "0 / 1000",
		reward = "REWARD\n+25 Gems",
	},
	{
		iconText = "EGG",
		title = "HATCH COLORS",
		description = "Hatch 3 colors from eggs.",
		progress = "0 / 3",
		reward = "REWARD\n+30 Gems",
	},
}

local function clearContent(content)
	for _, child in ipairs(content:GetChildren()) do
		if
			child:IsA("GuiObject")
			or child:IsA("UIGridLayout")
			or child:IsA("UIListLayout")
			or child:IsA("UIPadding")
		then
			child:Destroy()
		end
	end
end

local function makeDailyQuestRows(content)
	clearContent(content)
	content.ClipsDescendants = false

	local list = frame(content, "QuestList", UDim2.fromOffset(14, 14), UDim2.new(1, -28, 1, -28), PANEL)
	list.ClipsDescendants = false
	list.BackgroundColor3 = Color3.fromRGB(246, 249, 255)
	applyCorner(list, 20)
	applyStroke(list, OUTLINE, 3)

	for index, quest in ipairs(DAILY_QUEST_PREVIEWS) do
		local y = 16 + ((index - 1) * 88)
		local row = frame(
			list,
			"QuestRow" .. tostring(index),
			UDim2.fromOffset(18, y),
			UDim2.new(1, -36, 0, 74),
			Color3.fromRGB(250, 252, 255)
		)
		row.ClipsDescendants = false
		applyCorner(row, 16)
		applyStroke(row, Color3.fromRGB(239, 244, 251), 2)

		local icon =
			frame(row, "Icon", UDim2.fromOffset(16, 11), UDim2.fromOffset(126, 52), Color3.fromRGB(235, 242, 250))
		icon.ClipsDescendants = true
		applyCorner(icon, 14)
		local iconStroke = icon:FindFirstChildOfClass("UIStroke")
		if iconStroke then
			iconStroke:Destroy()
		end
		local iconText = text(icon, "IconText", quest.iconText, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 34)
		iconText.TextScaled = true
		iconText.TextXAlignment = Enum.TextXAlignment.Center
		iconText.TextStrokeTransparency = 1

		local title = text(row, "QuestTitle", quest.title, UDim2.fromOffset(156, 8), UDim2.new(0.48, -16, 0, 22), 17)
		title.TextScaled = true
		title.TextStrokeTransparency = 1

		local desc =
			text(row, "QuestDesc", quest.description, UDim2.fromOffset(156, 29), UDim2.new(0.48, -16, 0, 18), 13)
		desc.Font = Enum.Font.GothamMedium
		desc.TextColor3 = MUTED
		desc.TextStrokeTransparency = 1
		desc.TextTruncate = Enum.TextTruncate.AtEnd

		local bar = frame(
			row,
			"ProgressBarBg",
			UDim2.fromOffset(156, 51),
			UDim2.new(0.48, -16, 0, 14),
			Color3.fromRGB(231, 235, 241)
		)
		bar.ClipsDescendants = true
		applyCorner(bar, 10)
		applyStroke(bar, Color3.fromRGB(190, 196, 208), 2)
		local fill = frame(bar, "ProgressFill", UDim2.fromScale(0, 0), UDim2.fromScale(0, 1), CYAN)
		fill.ClipsDescendants = true
		applyCorner(fill, 10)
		local fillStroke = fill:FindFirstChildOfClass("UIStroke")
		if fillStroke then
			fillStroke:Destroy()
		end
		local progressText = text(bar, "ProgressText", quest.progress, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 12)
		progressText.TextXAlignment = Enum.TextXAlignment.Center
		progressText.TextStrokeTransparency = 1

		local reward = text(row, "RewardText", quest.reward, UDim2.new(0.66, 0, 0, 16), UDim2.new(0.14, 0, 0, 42), 11)
		reward.BackgroundTransparency = 0
		reward.BackgroundColor3 = Color3.fromRGB(236, 240, 246)
		reward.TextScaled = true
		reward.TextWrapped = true
		reward.TextXAlignment = Enum.TextXAlignment.Center
		reward.TextStrokeTransparency = 1
		applyCorner(reward, 14)

		local claim =
			button(row, "ClaimButton", "IN PROGRESS", UDim2.new(0.82, 0, 0, 20), UDim2.new(0.16, 0, 0, 34), DISABLED)
		claim.TextScaled = true
		claim.AutoButtonColor = false
	end

	local timer =
		text(list, "TimerText", "NEW QUESTS IN 24h 00m", UDim2.new(0, 18, 1, -56), UDim2.new(1, -36, 0, 40), 26)
	timer.BackgroundTransparency = 0
	timer.BackgroundColor3 = Color3.fromRGB(232, 238, 247)
	timer.TextColor3 = Color3.fromRGB(112, 118, 132)
	timer.TextScaled = true
	timer.TextXAlignment = Enum.TextXAlignment.Center
	timer.TextStrokeTransparency = 1
	applyCorner(timer, 16)
end

local function makeUpgradeCardGrid(content)
	for _, child in ipairs(content:GetChildren()) do
		if child:IsA("GuiObject") and (child.Name:match("Card$") or child.Name == "UpgradeGrid") then
			child:Destroy()
		end
	end

	local existingGrid = content:FindFirstChild("UpgradeGrid")
	if existingGrid and not existingGrid:IsA("ScrollingFrame") then
		existingGrid:Destroy()
		existingGrid = nil
	end
	local grid = existingGrid or Instance.new("ScrollingFrame")
	grid.Name = "UpgradeGrid"
	grid.Position = UDim2.fromOffset(12, 12)
	grid.Size = UDim2.new(1, -24, 1, -24)
	grid.BorderSizePixel = 0
	grid.Parent = content
	applyCorner(grid, 14)
	applyStroke(grid, OUTLINE, 2)
	grid.ScrollingDirection = Enum.ScrollingDirection.Y
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.fromOffset(0, 0)
	grid.BackgroundColor3 = Color3.fromRGB(246, 249, 255)
	grid.ClipsDescendants = true
	grid.ScrollBarThickness = 8
	grid.ScrollBarImageColor3 = MUTED

	for _, child in ipairs(grid:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	for index, upgrade in ipairs(UpgradeData.Upgrades or {}) do
		local column = (index - 1) % 3
		local row = math.floor((index - 1) / 3)
		local card = frame(
			grid,
			upgrade.id .. "Card",
			UDim2.fromOffset(14 + column * 236, 14 + row * 130),
			UDim2.fromOffset(222, 118),
			Color3.fromRGB(255, 255, 255)
		)
		card:SetAttribute("UpgradeId", upgrade.id)
		card:SetAttribute("UpgradeCategory", upgrade.category or "")
		card.Visible = upgrade.category == "Player"

		local icon =
			frame(card, "Icon", UDim2.fromOffset(10, 10), UDim2.fromOffset(58, 58), Color3.fromRGB(225, 244, 255))
		text(
			icon,
			"IconText",
			upgrade.icon or upgrade.displayName:sub(1, 2):upper(),
			UDim2.fromScale(0, 0),
			UDim2.fromScale(1, 1),
			18
		).TextXAlignment =
			Enum.TextXAlignment.Center
		applyUpgradeIconToCard(card, upgrade.displayName, upgrade.id)

		text(card, "Name", upgrade.displayName, UDim2.fromOffset(78, 8), UDim2.new(1, -88, 0, 28), 17)
		text(
			card,
			"Description",
			"Lv. 0/" .. tostring(#(upgrade.levels or {})) .. " - " .. tostring(upgrade.description or ""),
			UDim2.fromOffset(78, 38),
			UDim2.new(1, -88, 0, 34),
			12
		)
		text(
			card,
			"Level",
			"Lv. 0/" .. tostring(#(upgrade.levels or {})),
			UDim2.fromOffset(78, 64),
			UDim2.new(1, -88, 0, 18),
			11
		)
		local nextData = UpgradeData.getNextLevelData(upgrade.id, 0)
		local currencyName = nextData and (nextData.currency or upgrade.currency or "Gems") or "Gems"
		local priceText = nextData and (UpgradeData.formatNumber(nextData.cost) .. " " .. currencyName) or "MAX"
		text(card, "Price", priceText, UDim2.fromOffset(10, 76), UDim2.fromOffset(90, 28), 13)
		text(
			card,
			"CurrentValue",
			"Now: " .. UpgradeData.getValueDisplay(upgrade.id, 0),
			UDim2.fromOffset(102, 72),
			UDim2.fromOffset(104, 16),
			10
		)
		text(
			card,
			"NextValue",
			nextData and ("Next: " .. UpgradeData.getValueDisplay(upgrade.id, 1)) or "Maxed",
			UDim2.fromOffset(102, 88),
			UDim2.fromOffset(104, 16),
			10
		)
		button(
			card,
			"BuyButton",
			nextData and "BUY" or "MAX",
			UDim2.new(1, -110, 1, -42),
			UDim2.fromOffset(96, 32),
			Color3.fromRGB(84, 225, 112)
		)
	end

	local rows = math.ceil(#(UpgradeData.Upgrades or {}) / 3)
	grid.CanvasSize = UDim2.fromOffset(0, math.max(1, rows) * 130 + 28)
end

local function makeUpgradesWindow(windowsFolder)
	local window, content = makeWindow(windowsFolder, "UpgradesWindow", "UPGRADES", { "Player", "Colors", "Rank" })
	makeUpgradeCardGrid(content)
	return window
end

local function makeSettingsGrid(content)
	local cards = {
		{
			name = "MusicCard",
			icon = "MU",
			title = "Music",
			description = "Background music.",
			status = "ON",
			buttonText = "TURN OFF",
		},
		{
			name = "SFXCard",
			icon = "SF",
			title = "SFX",
			description = "Sound effects.",
			status = "ON",
			buttonText = "TURN OFF",
		},
		{
			name = "HidePetsCard",
			icon = "HI",
			title = "Hide Pets",
			description = "Pet visibility option coming soon.",
			status = "SOON",
			buttonText = "SOON",
		},
		{
			name = "LowDetailCard",
			icon = "LO",
			title = "Low Detail",
			description = "Reduce visual effects.",
			status = "OFF",
			buttonText = "TURN ON",
		},
		{
			name = "AutoDeleteCard",
			icon = "AU",
			title = "Auto Delete",
			description = "Auto-delete rules coming soon.",
			status = "SOON",
			buttonText = "SOON",
		},
		{
			name = "CodesCard",
			icon = "CO",
			title = "Codes",
			description = "Open code redemption.",
			status = "WINDOW",
			buttonText = "OPEN",
		},
	}

	for index, item in ipairs(cards) do
		local x = ((index - 1) % 3) * 238 + 14
		local y = math.floor((index - 1) / 3) * 132 + 14
		local card =
			frame(content, item.name, UDim2.fromOffset(x, y), UDim2.fromOffset(222, 118), Color3.fromRGB(255, 255, 255))
		local icon =
			frame(card, "Icon", UDim2.fromOffset(10, 10), UDim2.fromOffset(58, 58), Color3.fromRGB(225, 244, 255))
		text(icon, "IconText", item.icon, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 18).TextXAlignment =
			Enum.TextXAlignment.Center
		text(card, "Name", item.title, UDim2.fromOffset(78, 8), UDim2.new(1, -88, 0, 28), 17)
		text(card, "Description", item.description, UDim2.fromOffset(78, 38), UDim2.new(1, -88, 0, 34), 12)
		text(card, "Price", item.status, UDim2.fromOffset(10, 76), UDim2.fromOffset(90, 28), 13)
		button(
			card,
			"BuyButton",
			item.buttonText,
			UDim2.new(1, -110, 1, -42),
			UDim2.fromOffset(96, 32),
			Color3.fromRGB(84, 225, 112)
		)
	end
end

local function hideUnusedCodeContent(content)
	local keep = {
		CodeBox = true,
		CodePrompt = true,
		InfoPanel = true,
		InfoText = true,
		RecentRewards = true,
		RedeemButton = true,
		StatusText = true,
	}

	for _, child in ipairs(content:GetChildren()) do
		if child:IsA("GuiObject") and not keep[child.Name] then
			child.Visible = false
		end
	end
end

local function makeCodeRewardSlot(parent, index, title, body)
	local slot = frame(
		parent,
		"RewardSlot" .. tostring(index),
		UDim2.fromOffset((index - 1) * 192, 0),
		UDim2.fromOffset(176, 62),
		Color3.fromRGB(255, 255, 255)
	)
	slot.LayoutOrder = index
	slot.BackgroundTransparency = 0
	text(slot, "GiftLabel", "GIFT", UDim2.fromOffset(10, 0), UDim2.fromOffset(54, 62), 15).TextXAlignment =
		Enum.TextXAlignment.Center
	text(slot, "RewardTitle", title, UDim2.fromOffset(66, 10), UDim2.new(1, -76, 0, 22), 13)
	text(slot, "RewardBody", body, UDim2.fromOffset(66, 34), UDim2.new(1, -76, 0, 18), 11)
end

local function makeCodesContent(content)
	hideUnusedCodeContent(content)

	content.BackgroundColor3 = Color3.fromRGB(246, 249, 255)
	content.ClipsDescendants = false

	local prompt = text(content, "CodePrompt", "ENTER A CODE", UDim2.fromOffset(34, 22), UDim2.new(1, -68, 0, 46), 32)
	prompt.TextXAlignment = Enum.TextXAlignment.Center
	prompt.TextStrokeTransparency = 0.25

	local box = textBox(content, "CodeBox", "TYPE CODE HERE", UDim2.fromOffset(54, 92), UDim2.new(1, -238, 0, 58))
	box.TextSize = 23

	local redeem = button(
		content,
		"RedeemButton",
		"REDEEM",
		UDim2.new(1, -170, 0, 92),
		UDim2.fromOffset(116, 58),
		Color3.fromRGB(82, 219, 225)
	)
	redeem.TextSize = 22

	local infoPanel =
		frame(content, "InfoPanel", UDim2.fromOffset(54, 172), UDim2.new(1, -108, 0, 76), Color3.fromRGB(234, 239, 248))
	infoPanel.BackgroundTransparency = 0
	applyStroke(infoPanel, Color3.fromRGB(211, 219, 232), 2)

	local infoAccent =
		frame(infoPanel, "Accent", UDim2.fromOffset(18, 14), UDim2.fromOffset(7, 48), Color3.fromRGB(88, 140, 255))
	applyCorner(infoAccent, 8)
	local info = text(
		infoPanel,
		"InfoText",
		"Follow socials or join the community for exclusive codes.",
		UDim2.fromOffset(44, 12),
		UDim2.new(1, -66, 0, 26),
		15
	)
	info.TextStrokeTransparency = 1
	local status = text(
		infoPanel,
		"StatusText",
		"Try RELEASE, COLOR, or PET.",
		UDim2.fromOffset(44, 38),
		UDim2.new(1, -66, 0, 24),
		13
	)
	status.Font = Enum.Font.GothamBold
	status.TextColor3 = Color3.fromRGB(88, 96, 120)
	status.TextStrokeTransparency = 1

	local recentTitle =
		text(content, "RecentTitle", "RECENT REWARDS", UDim2.fromOffset(54, 266), UDim2.new(1, -108, 0, 28), 18)
	recentTitle.TextXAlignment = Enum.TextXAlignment.Center

	local rewards = frame(
		content,
		"RecentRewards",
		UDim2.fromOffset(54, 306),
		UDim2.new(1, -108, 0, 66),
		Color3.fromRGB(246, 249, 255)
	)
	rewards.BackgroundTransparency = 1
	for _, child in ipairs(rewards:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	makeCodeRewardSlot(rewards, 1, "RELEASE", "Coins")
	makeCodeRewardSlot(rewards, 2, "COLOR", "Color")
	makeCodeRewardSlot(rewards, 3, "PET", "Starter Color")
end

local SHOP_TABS = { "Featured", "Gamepasses", "Boosts", "Currency" }

local function getGamepass(passId)
	return RobuxShopConfig.getGamepass(passId)
end

local function getProductsForCategory(categoryName)
	local products = {}
	for _, product in ipairs(RobuxShopConfig.getSortedDevProducts()) do
		if tostring(product.category or "") == categoryName then
			table.insert(products, product)
		end
	end
	return products
end

local function getInfinitePack()
	local pack = RobuxShopConfig.InfinitePack
	if pack and type(pack.tiers) == "table" and #pack.tiers > 0 then
		return pack
	end
	return FALLBACK_INFINITE_PACK
end

local function getInfinitePackTiers()
	if RobuxShopConfig.getInfinitePackTiers then
		local tiers = RobuxShopConfig.getInfinitePackTiers()
		if #tiers > 0 then
			return tiers
		end
	end

	local tiers = {}
	for _, tier in ipairs(getInfinitePack().tiers or {}) do
		table.insert(tiers, tier)
	end
	table.sort(tiers, function(a, b)
		return (a.tier or 999) < (b.tier or 999)
	end)
	return tiers
end

local function setGuiBase(guiObject, zIndex)
	guiObject.BorderSizePixel = 0
	guiObject.ZIndex = zIndex
	if guiObject:IsA("TextLabel") or guiObject:IsA("TextButton") or guiObject:IsA("TextBox") then
		guiObject.TextWrapped = true
	end
end

local function makeScale(parent, name)
	local scale = parent:FindFirstChild(name)
	if not scale or not scale:IsA("UIScale") then
		scale = Instance.new("UIScale")
		scale.Name = name
		scale.Parent = parent
	end
	scale.Scale = 1
	return scale
end

local function makeShopText(parent, name, value, position, size, textSize, color, zIndex)
	local label = text(parent, name, value, position, size, textSize)
	label.TextColor3 = color or TEXT_DARK
	label.TextStrokeTransparency = 1
	label.TextScaled = false
	label.ZIndex = zIndex or 1005
	return label
end

local function makeShopButton(parent, name, value, position, size, color, zIndex)
	local shopButton = button(parent, name, value, position, size, color or GREEN)
	shopButton.AutoButtonColor = false
	shopButton.TextScaled = false
	shopButton.TextSize = 15
	shopButton.TextWrapped = true
	shopButton.ZIndex = zIndex or 1006
	makeScale(shopButton, "ButtonScale")
	return shopButton
end

local function makeBadge(parent, textValue, position, size, zIndex)
	local badge = frame(parent, "Badge", position, size, Color3.fromRGB(255, 221, 84))
	badge.ZIndex = zIndex or 1006
	applyCorner(badge, 12)
	applyStroke(badge, OUTLINE, 2)
	local badgeText = makeShopText(
		badge,
		"Text",
		textValue,
		UDim2.fromScale(0, 0),
		UDim2.fromScale(1, 1),
		13,
		TEXT_DARK,
		badge.ZIndex + 1
	)
	badgeText.Font = Enum.Font.GothamBlack
	badgeText.TextXAlignment = Enum.TextXAlignment.Center
	badgeText.TextScaled = true
	return badge
end

local function clearGeneratedChildren(parent)
	for _, child in ipairs(parent:GetChildren()) do
		if child:GetAttribute("StudioShopGenerated") == true then
			child:Destroy()
		end
	end
end

local function clearShopPage(parent)
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("GuiObject") or child:IsA("UIGridLayout") or child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

local function clearLegacyContentChildren(content)
	local keep = {
		FeaturedPage = true,
		GamepassesPage = true,
		BoostsPage = true,
		CurrencyPage = true,
	}
	for _, child in ipairs(content:GetChildren()) do
		if
			(child:IsA("GuiObject") and not keep[child.Name])
			or child:IsA("UIGridLayout")
			or child:IsA("UIListLayout")
			or child:IsA("UIPadding")
		then
			child:Destroy()
		end
	end
end

local function prepShopWindow(shopWindow)
	shopWindow.AnchorPoint = Vector2.new(0.5, 0.5)
	shopWindow.Position = STANDARD_WINDOW_POSITION
	shopWindow.Size = STANDARD_WINDOW_SIZE
	shopWindow.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	shopWindow.BorderSizePixel = 0
	shopWindow.ClipsDescendants = false
	shopWindow.ZIndex = 1000
	applyCorner(shopWindow, 24)
	applyStroke(shopWindow, OUTLINE, 4)

	local title = text(shopWindow, "Title", "ROBUX SHOP", UDim2.fromOffset(26, 16), UDim2.new(1, -120, 0, 46), 32)
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = TEXT_DARK
	title.TextStrokeTransparency = 1
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 1002

	local closeButton = shopWindow:FindFirstChild("CloseButton")
	if not closeButton or not closeButton:IsA("GuiButton") then
		closeButton = button(
			shopWindow,
			"CloseButton",
			"X",
			STANDARD_CLOSE_POSITION,
			STANDARD_CLOSE_SIZE,
			Color3.fromRGB(188, 21, 28)
		)
	end
	styleCloseButton(closeButton, STANDARD_CLOSE_POSITION, STANDARD_CLOSE_SIZE, 1003)

	return shopWindow
end

local function makeShopTabs(shopWindow)
	local tabs =
		frame(shopWindow, "Tabs", UDim2.fromOffset(26, 76), UDim2.new(1, -52, 0, 48), Color3.fromRGB(255, 255, 255))
	tabs.BackgroundTransparency = 1
	tabs.ZIndex = 1002

	local oldBundles = tabs:FindFirstChild("BundlesTab")
	if oldBundles then
		oldBundles.Name = "FeaturedTab"
	end
	local oldPotions = tabs:FindFirstChild("PotionsTab")
	if oldPotions then
		oldPotions.Name = "BoostsTab"
	end

	local layout = tabs:FindFirstChildOfClass("UIListLayout") or Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = tabs

	for index, tabName in ipairs(SHOP_TABS) do
		local tab = button(
			tabs,
			tabName .. "Tab",
			tabName,
			UDim2.fromOffset(0, 0),
			UDim2.fromOffset(150, 38),
			index == 1 and CYAN or TAB_INACTIVE
		)
		tab.LayoutOrder = index
		tab.AutoButtonColor = false
		tab.TextScaled = false
		tab.TextSize = 20
		tab.Font = Enum.Font.GothamBlack
		tab.TextColor3 = index == 1 and Color3.fromRGB(255, 255, 255) or TEXT_DARK
		tab.ZIndex = 1003
		applyCorner(tab, 14)
		applyStroke(tab, OUTLINE, 2)
	end

	return tabs
end

local function makeShopPages(shopWindow)
	local content = frame(
		shopWindow,
		"Content",
		UDim2.fromOffset(26, 136),
		UDim2.new(1, -52, 1, -164),
		Color3.fromRGB(244, 248, 252)
	)
	content.BorderSizePixel = 0
	content.ClipsDescendants = true
	content.ZIndex = 1001
	applyCorner(content, 18)
	applyStroke(content, OUTLINE, 3)
	clearLegacyContentChildren(content)

	for index, pageName in ipairs({ "FeaturedPage", "GamepassesPage", "BoostsPage", "CurrencyPage" }) do
		local page =
			frame(content, pageName, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), Color3.fromRGB(244, 248, 252))
		page.BackgroundTransparency = 1
		page.ZIndex = 1002
		page.Visible = index == 1
		clearShopPage(page)
	end

	return content
end

local function makeIconCircle(parent, name, iconTextValue, color, position, size, zIndex)
	local circle = frame(parent, name, position, size, color)
	circle.ZIndex = zIndex or 1004
	applyCorner(circle, 99)
	applyStroke(circle, OUTLINE, 2)
	makeScale(circle, "IconScale")

	local iconLabel = makeShopText(
		circle,
		"IconText",
		iconTextValue,
		UDim2.fromScale(0, 0),
		UDim2.fromScale(1, 1),
		26,
		Color3.fromRGB(255, 255, 255),
		circle.ZIndex + 1
	)
	iconLabel.Font = Enum.Font.GothamBlack
	iconLabel.TextXAlignment = Enum.TextXAlignment.Center
	iconLabel.TextScaled = true
	iconLabel.TextStrokeTransparency = 0
	iconLabel.TextStrokeColor3 = OUTLINE

	local iconImage = circle:FindFirstChild("IconImage")
	if not iconImage or not iconImage:IsA("ImageLabel") then
		iconImage = Instance.new("ImageLabel")
		iconImage.Name = "IconImage"
		iconImage.Parent = circle
	end
	iconImage.BackgroundTransparency = 1
	iconImage.BorderSizePixel = 0
	iconImage.Position = UDim2.fromOffset(2, 2)
	iconImage.Size = UDim2.new(1, -4, 1, -4)
	iconImage.ScaleType = Enum.ScaleType.Fit
	iconImage.ZIndex = circle.ZIndex + 2
	iconImage.Image = ""
	iconImage.Visible = false
	return circle
end

local function getShopIconSpec(item)
	if type(item) ~= "table" then
		return nil
	end

	local iconKey = item.iconKey or (GamepassIconConfig.ByShopItemId and GamepassIconConfig.ByShopItemId[item.id])
	return iconKey and GamepassIconConfig.Icons and GamepassIconConfig.Icons[iconKey] or nil
end

local function applyShopIcon(iconCircle, item)
	if not iconCircle or not iconCircle:IsA("GuiObject") then
		return
	end

	local spec = getShopIconSpec(item)
	local iconImage = iconCircle:FindFirstChild("IconImage")
	local image = spec and tostring(spec.Image or "") or tostring(item and item.iconImage or "")
	if iconImage and iconImage:IsA("ImageLabel") then
		iconImage.Image = image
		iconImage.Visible = image ~= ""
		iconImage:SetAttribute("GamepassIconKey", item and item.iconKey or "")
		iconImage:SetAttribute(
			"ExpectedGamepassIconFile",
			spec and spec.SourceFile or item and item.iconSourceFile or ""
		)
	end

	local iconText = iconCircle:FindFirstChild("IconText")
	if iconText and iconText:IsA("TextLabel") then
		iconText.Text = tostring(item and item.icon or iconText.Text or "?")
		iconText.Visible = image == ""
	end

	iconCircle:SetAttribute("GamepassIconKey", item and item.iconKey or "")
	iconCircle:SetAttribute("ExpectedGamepassIconFile", spec and spec.SourceFile or item and item.iconSourceFile or "")
end

local function applyGamepassIconsToWindow(shopWindow)
	if not shopWindow then
		return 0
	end

	local applied = 0
	for _, descendant in ipairs(shopWindow:GetDescendants()) do
		if descendant:IsA("GuiObject") then
			local shopItemId = descendant:GetAttribute("ShopItemId")
			local shopItemKind = descendant:GetAttribute("ShopItemKind")
			local pass = shopItemKind == "Gamepass" and shopItemId and RobuxShopConfig.getGamepass(tostring(shopItemId))
			local tier = shopItemKind == "InfinitePackTier"
				and shopItemId
				and RobuxShopConfig.getInfinitePackTier
				and RobuxShopConfig.getInfinitePackTier(tostring(shopItemId))
			local item = pass or tier
			if item then
				local iconCircle = descendant:FindFirstChild("IconCircle", true)
					or descendant:FindFirstChild("RewardBox", true)
				if iconCircle and iconCircle:IsA("GuiObject") then
					applyShopIcon(iconCircle, item)
					applied += 1
				end
			end
		end
	end
	return applied
end

local function scrollingFrame(parent, name, position, size)
	local existing = parent:FindFirstChild(name)
	if existing and not existing:IsA("ScrollingFrame") then
		existing:Destroy()
		existing = nil
	end

	local scroller = existing or Instance.new("ScrollingFrame")
	scroller.Name = name
	scroller.Position = position
	scroller.Size = size
	scroller.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	scroller.BorderSizePixel = 0
	scroller.ScrollBarThickness = 6
	scroller.ScrollingDirection = Enum.ScrollingDirection.X
	scroller.ScrollingEnabled = true
	scroller.CanvasPosition = Vector2.new(0, 0)
	scroller.Parent = parent
	applyCorner(scroller, 14)
	applyStroke(scroller, OUTLINE, 2)
	return scroller
end

local function makeInfinitePackTierCard(parent, tier, layoutOrder)
	local card = frame(
		parent,
		tier.id .. "Card",
		UDim2.fromScale(0, 0),
		UDim2.fromOffset(96, 118),
		Color3.fromRGB(255, 255, 255)
	)
	card:SetAttribute("StudioShopGenerated", true)
	card:SetAttribute("ShopItemId", tier.id)
	card:SetAttribute("ShopItemKind", "InfinitePackTier")
	card.LayoutOrder = layoutOrder
	card.ZIndex = 1005
	makeScale(card, "CardScale")
	applyCorner(card, 12)
	applyStroke(card, OUTLINE, 2)

	local rewardBox = frame(card, "IconCircle", UDim2.fromOffset(9, 8), UDim2.fromOffset(78, 62), tier.color or CYAN)
	rewardBox.ZIndex = 1006
	applyCorner(rewardBox, 10)
	applyStroke(rewardBox, OUTLINE, 2)
	local iconImage = Instance.new("ImageLabel")
	iconImage.Name = "IconImage"
	iconImage.BackgroundTransparency = 1
	iconImage.BorderSizePixel = 0
	iconImage.Position = UDim2.fromOffset(2, 2)
	iconImage.Size = UDim2.new(1, -4, 1, -4)
	iconImage.ScaleType = Enum.ScaleType.Fit
	iconImage.ZIndex = 1008
	iconImage.Image = ""
	iconImage.Visible = false
	iconImage.Parent = rewardBox
	local icon = makeShopText(
		rewardBox,
		"IconText",
		tostring(tier.icon or "?"),
		UDim2.fromScale(0, 0),
		UDim2.fromScale(1, 1),
		22,
		Color3.fromRGB(255, 255, 255),
		1007
	)
	icon.Font = Enum.Font.GothamBlack
	icon.TextXAlignment = Enum.TextXAlignment.Center
	icon.TextScaled = true
	icon.TextStrokeTransparency = 0
	icon.TextStrokeColor3 = OUTLINE
	applyShopIcon(rewardBox, tier)

	local reward = makeShopText(
		card,
		"RewardLabel",
		tostring(tier.rewardText or tier.displayName or ""),
		UDim2.fromOffset(7, 72),
		UDim2.fromOffset(82, 18),
		10,
		TEXT_DARK,
		1007
	)
	reward.Font = Enum.Font.GothamBold
	reward.TextXAlignment = Enum.TextXAlignment.Center
	reward.TextWrapped = true

	local buttonText = tier.free and "FREE" or tostring(tier.price or 0) .. " R$"
	local buy = makeShopButton(
		card,
		"BuyButton",
		buttonText,
		UDim2.fromOffset(9, 90),
		UDim2.fromOffset(78, 24),
		tier.free and GREEN or Color3.fromRGB(118, 235, 80),
		1007
	)
	buy.TextSize = tier.free and 18 or 15
end

local function makeInfinitePackPanel(featuredPage)
	local pack = getInfinitePack()
	local tiers = getInfinitePackTiers()
	if not pack or #tiers == 0 then
		warn("StudioMenuWindowsBuilder: InfinitePack has no tiers; Featured pack panel skipped.")
		return
	end

	local panel = frame(
		featuredPage,
		"InfinitePackPanel",
		UDim2.fromOffset(16, 12),
		UDim2.new(1, -32, 0, 214),
		Color3.fromRGB(184, 246, 255)
	)
	panel:SetAttribute("StudioShopGenerated", true)
	panel.BorderSizePixel = 0
	panel.ClipsDescendants = true
	panel.ZIndex = 1003
	applyCorner(panel, 18)
	applyStroke(panel, OUTLINE, 3)

	local rainbow =
		frame(panel, "RainbowBand", UDim2.new(-0.05, 0, 0, 54), UDim2.new(1.1, 0, 0, 64), Color3.fromRGB(255, 122, 188))
	rainbow:SetAttribute("StudioShopGenerated", true)
	rainbow.BackgroundTransparency = 0.38
	rainbow.Rotation = -7
	rainbow.ZIndex = 1004
	local rainbowStroke = rainbow:FindFirstChildOfClass("UIStroke")
	if rainbowStroke then
		rainbowStroke:Destroy()
	end

	local title = makeShopText(
		panel,
		"Title",
		tostring(pack.displayName or "THE INFINITE PACK!"),
		UDim2.new(0, 210, 0, 12),
		UDim2.new(1, -230, 0, 40),
		32,
		TEXT_DARK,
		1006
	)
	title.Font = Enum.Font.GothamBlack
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.TextScaled = true
	title.TextStrokeTransparency = 0
	title.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)

	local reset = makeShopText(
		panel,
		"ResetLabel",
		"Resets in 23:59:59",
		UDim2.fromOffset(18, 14),
		UDim2.fromOffset(190, 34),
		22,
		TEXT_DARK,
		1006
	)
	reset.Font = Enum.Font.GothamBlack
	reset.TextScaled = true
	reset.TextStrokeTransparency = 0
	reset.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)

	local track = scrollingFrame(panel, "TierTrack", UDim2.fromOffset(14, 62), UDim2.new(1, -28, 0, 138))
	track:SetAttribute("StudioShopGenerated", true)
	track.ZIndex = 1005
	track.ScrollingEnabled = false
	track.ScrollBarThickness = 0
	track.CanvasSize = UDim2.fromOffset((#tiers * 134) + 60, 0)

	local list = track:FindFirstChildOfClass("UIListLayout") or Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Left
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = track

	for index, tier in ipairs(tiers) do
		makeInfinitePackTierCard(track, tier, index * 2)
		if index < #tiers then
			local arrow = makeShopText(
				track,
				"Arrow" .. tostring(index),
				"->",
				UDim2.fromScale(0, 0),
				UDim2.fromOffset(18, 118),
				26,
				OUTLINE,
				1007
			)
			arrow:SetAttribute("StudioShopGenerated", true)
			arrow.LayoutOrder = (index * 2) + 1
			arrow.TextXAlignment = Enum.TextXAlignment.Center
			arrow.TextScaled = true
		end
	end
end

local function makeInfiniteHero(featuredPage)
	local pass = getGamepass("InfinitePass")
	if not pass then
		return
	end

	local card =
		frame(featuredPage, "InfinitePassHeroCard", UDim2.fromOffset(16, 12), UDim2.new(1, -32, 0, 126), pass.color)
	card:SetAttribute("StudioShopGenerated", true)
	card:SetAttribute("ShopItemId", pass.id)
	card:SetAttribute("ShopItemKind", "Gamepass")
	card.BorderSizePixel = 0
	card.ClipsDescendants = true
	card.ZIndex = 1003
	makeScale(card, "CardScale")
	applyCorner(card, 20)
	applyStroke(card, Color3.fromRGB(72, 235, 255), 4)

	local glow =
		frame(card, "Glow", UDim2.new(-0.05, 0, -0.2, 0), UDim2.new(1.1, 0, 1.4, 0), Color3.fromRGB(72, 235, 255))
	glow.BackgroundTransparency = 0.72
	glow.ZIndex = 1004
	applyCorner(glow, 30)

	for index, circle in ipairs({
		{ "GlowCircle1", UDim2.new(0.18, 0, -0.35, 0), UDim2.fromOffset(170, 170), Color3.fromRGB(255, 255, 255) },
		{ "GlowCircle2", UDim2.new(0.58, 0, 0.45, 0), UDim2.fromOffset(130, 130), Color3.fromRGB(72, 235, 255) },
		{ "GlowCircle3", UDim2.new(0.82, 0, -0.18, 0), UDim2.fromOffset(120, 120), Color3.fromRGB(177, 141, 255) },
	}) do
		local glowCircle = frame(card, circle[1], circle[2], circle[3], circle[4])
		glowCircle:SetAttribute("StudioShopGenerated", true)
		glowCircle.BackgroundTransparency = 0.75
		glowCircle.ZIndex = 1004 + index
		applyCorner(glowCircle, 99)
	end

	local shimmer = frame(
		card,
		"ShimmerBar",
		UDim2.new(-0.18, 0, -0.35, 0),
		UDim2.new(0, 48, 1.75, 0),
		Color3.fromRGB(255, 255, 255)
	)
	shimmer.Rotation = -18
	shimmer.BackgroundTransparency = 0.7
	shimmer.ZIndex = 1004
	local shimmerStroke = shimmer:FindFirstChildOfClass("UIStroke")
	if shimmerStroke then
		shimmerStroke:Destroy()
	end

	makeIconCircle(
		card,
		"IconCircle",
		pass.icon or "∞",
		Color3.fromRGB(30, 35, 70),
		UDim2.new(0, 18, 0.5, -42),
		UDim2.fromOffset(84, 84),
		1005
	)
	local heroIcon = card:FindFirstChild("IconCircle")
	if heroIcon and heroIcon:IsA("GuiObject") then
		heroIcon.Position = UDim2.new(0, 18, 0.5, -36)
		heroIcon.Size = UDim2.fromOffset(72, 72)
	end
	local title = makeShopText(
		card,
		"Title",
		"INFINITE PASS",
		UDim2.fromOffset(104, 14),
		UDim2.new(0.48, 0, 0, 30),
		24,
		Color3.fromRGB(255, 255, 255),
		1006
	)
	title.TextScaled = true
	local description = makeShopText(
		card,
		"Description",
		"The ultimate permanent upgrade.",
		UDim2.fromOffset(104, 46),
		UDim2.new(0.48, 0, 0, 22),
		16,
		Color3.fromRGB(230, 245, 255),
		1006
	)
	description.Font = Enum.Font.GothamBold
	description.TextScaled = true
	local perks = makeShopText(
		card,
		"Perks",
		"∞ Infinite color capacity\n+5 equipped Colors\nDaily gems\nExclusive aura",
		UDim2.fromOffset(112, 84),
		UDim2.new(0.48, 0, 0, 60),
		14,
		Color3.fromRGB(255, 255, 255),
		1006
	)
	perks.TextYAlignment = Enum.TextYAlignment.Top
	perks.Position = UDim2.fromOffset(104, 70)
	perks.Size = UDim2.new(0.5, 0, 0, 48)
	perks.TextSize = 12

	makeBadge(card, pass.badge or "BEST VALUE", UDim2.new(1, -150, 0, 14), UDim2.fromOffset(130, 28), 1006)
	local price = makeShopText(
		card,
		"PriceLabel",
		tostring(pass.price or 999) .. " R$",
		UDim2.new(1, -190, 0, 50),
		UDim2.fromOffset(170, 30),
		22,
		Color3.fromRGB(255, 255, 255),
		1006
	)
	price.TextScaled = true
	price.TextXAlignment = Enum.TextXAlignment.Center
	local buy = makeShopButton(
		card,
		"BuyButton",
		"BUY " .. tostring(pass.price or 999) .. " R$",
		UDim2.new(1, -190, 1, -42),
		UDim2.fromOffset(170, 32),
		GREEN,
		1007
	)
	buy.TextSize = 20
end

local function makeNormalGamepassCard(parent, pass, layoutOrder, compact)
	local cardSize = compact and UDim2.fromOffset(138, 64) or UDim2.fromOffset(225, 80)
	local card = frame(parent, pass.id .. "Card", UDim2.fromScale(0, 0), cardSize, Color3.fromRGB(255, 255, 255))
	card:SetAttribute("StudioShopGenerated", true)
	card:SetAttribute("ShopItemId", pass.id)
	card:SetAttribute("ShopItemKind", "Gamepass")
	card.LayoutOrder = layoutOrder
	card.ZIndex = 1003
	makeScale(card, "CardScale")
	applyCorner(card, 16)
	applyStroke(card, OUTLINE, 2)

	local iconColor = (pass.color or CYAN):Lerp(Color3.fromRGB(255, 255, 255), 0.35)
	local iconCircle = makeIconCircle(
		card,
		"IconCircle",
		tostring(pass.icon or "?"),
		iconColor,
		compact and UDim2.fromOffset(7, 8) or UDim2.fromOffset(10, 10),
		compact and UDim2.fromOffset(42, 42) or UDim2.fromOffset(50, 50),
		1004
	)
	applyShopIcon(iconCircle, pass)

	local title = makeShopText(
		card,
		"Title",
		tostring(pass.displayName or pass.id),
		compact and UDim2.fromOffset(54, 7) or UDim2.fromOffset(72, 8),
		compact and UDim2.new(1, -60, 0, 20) or UDim2.new(1, -82, 0, 22),
		compact and 12 or 16,
		TEXT_DARK,
		1005
	)
	title.TextScaled = false
	local description = makeShopText(
		card,
		"Description",
		tostring(pass.description or ""),
		UDim2.fromOffset(72, 30),
		UDim2.new(1, -82, 0, 22),
		10,
		TEXT_DARK,
		1005
	)
	description.Font = Enum.Font.GothamBold
	description.TextWrapped = true
	description.Visible = not compact
	local price = makeShopText(
		card,
		"PriceLabel",
		tostring(pass.price or 0) .. " R$",
		UDim2.new(0, 12, 1, -34),
		UDim2.fromOffset(82, 24),
		16,
		TEXT_DARK,
		1005
	)
	price.Visible = false
	price.TextXAlignment = Enum.TextXAlignment.Center
	local buy = makeShopButton(
		card,
		"BuyButton",
		"BUY",
		compact and UDim2.new(1, -78, 1, -24) or UDim2.new(1, -112, 1, -28),
		compact and UDim2.fromOffset(68, 18) or UDim2.fromOffset(102, 22),
		GREEN,
		1005
	)
	buy.TextSize = compact and 10 or 12
	buy:SetAttribute("DefaultText", "BUY R$ " .. tostring(pass.price or 0))
	if pass.badge and pass.badge ~= "" then
		local badge = makeBadge(
			card,
			tostring(pass.badge),
			compact and UDim2.new(0, 8, 1, -22) or UDim2.new(0, 10, 1, -28),
			compact and UDim2.fromOffset(58, 18) or UDim2.fromOffset(92, 22),
			1006
		)
		badge.BackgroundTransparency = 0.05
	end
end

local function makeSmallCards(featuredPage)
	local holder = frame(
		featuredPage,
		"SmallCards",
		UDim2.fromOffset(16, 238),
		UDim2.new(1, -32, 1, -250),
		Color3.fromRGB(244, 248, 252)
	)
	holder:SetAttribute("StudioShopGenerated", true)
	holder.BackgroundTransparency = 1
	holder.ZIndex = 1002

	local grid = holder:FindFirstChildOfClass("UIGridLayout") or Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(138, 64)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.FillDirectionMaxCells = 5
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.VerticalAlignment = Enum.VerticalAlignment.Top
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = holder

	local layoutOrder = 0
	for _, passId in ipairs({ "VIP", "DoubleCoins", "LuckyHatch", "Plus3Colors", "SupportDev" }) do
		local pass = getGamepass(passId)
		if pass then
			layoutOrder += 1
			makeNormalGamepassCard(holder, pass, layoutOrder, true)
		end
	end
end

local function makeProductCard(parent, product, layoutOrder)
	local card = frame(
		parent,
		product.id .. "Card",
		UDim2.fromScale(0, 0),
		UDim2.fromOffset(225, 112),
		Color3.fromRGB(255, 255, 255)
	)
	card:SetAttribute("StudioShopGenerated", true)
	card:SetAttribute("ShopItemId", product.id)
	card:SetAttribute("ShopItemKind", "Product")
	card.LayoutOrder = layoutOrder
	card.ZIndex = 1003
	makeScale(card, "CardScale")
	applyCorner(card, 16)
	applyStroke(card, OUTLINE, 2)
	local iconColor = (product.color or CYAN):Lerp(Color3.fromRGB(255, 255, 255), 0.35)
	makeIconCircle(
		card,
		"IconCircle",
		tostring(product.icon or "?"),
		iconColor,
		UDim2.fromOffset(12, 14),
		UDim2.fromOffset(58, 58),
		1004
	)
	makeShopText(
		card,
		"Title",
		tostring(product.displayName or product.id),
		UDim2.fromOffset(80, 12),
		UDim2.new(1, -90, 0, 26),
		18,
		TEXT_DARK,
		1005
	).TextScaled =
		true
	makeShopText(
		card,
		"Description",
		tostring(product.description or ""),
		UDim2.fromOffset(80, 42),
		UDim2.new(1, -90, 0, 32),
		12,
		TEXT_DARK,
		1005
	)
	makeShopText(
		card,
		"PriceLabel",
		"COMING SOON",
		UDim2.new(0, 12, 1, -34),
		UDim2.fromOffset(96, 24),
		14,
		TEXT_DARK,
		1005
	).TextScaled =
		true
	makeShopButton(
		card,
		"BuyButton",
		"COMING SOON",
		UDim2.new(1, -124, 1, -40),
		UDim2.fromOffset(112, 30),
		Color3.fromRGB(170, 180, 205),
		1005
	)
end

local function makeGridPage(page, holderName, items, kind)
	local holder =
		frame(page, holderName, UDim2.fromOffset(16, 14), UDim2.new(1, -32, 1, -28), Color3.fromRGB(244, 248, 252))
	holder:SetAttribute("StudioShopGenerated", true)
	holder.BackgroundTransparency = 1
	holder.ZIndex = 1002
	local grid = holder:FindFirstChildOfClass("UIGridLayout") or Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(225, 112)
	grid.CellPadding = UDim2.fromOffset(12, 12)
	grid.FillDirectionMaxCells = 3
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.VerticalAlignment = Enum.VerticalAlignment.Top
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = holder

	for index, item in ipairs(items) do
		if kind == "Gamepass" then
			makeNormalGamepassCard(holder, item, index)
		else
			makeProductCard(holder, item, index)
		end
	end
end

local function makeFeaturedShopContent(content)
	local featuredPage = content:FindFirstChild("FeaturedPage")
	if not featuredPage or not featuredPage:IsA("Frame") then
		return
	end
	clearGeneratedChildren(featuredPage)
	makeInfinitePackPanel(featuredPage)
	makeSmallCards(featuredPage)

	local gamepassesPage = content:FindFirstChild("GamepassesPage")
	if gamepassesPage and gamepassesPage:IsA("Frame") then
		clearGeneratedChildren(gamepassesPage)
		local passes = {}
		for _, pass in ipairs(RobuxShopConfig.getSortedGamepasses()) do
			table.insert(passes, pass)
		end
		makeGridPage(gamepassesPage, "GamepassCards", passes, "Gamepass")
	end

	local boostsPage = content:FindFirstChild("BoostsPage")
	if boostsPage and boostsPage:IsA("Frame") then
		clearGeneratedChildren(boostsPage)
		makeGridPage(boostsPage, "BoostCards", getProductsForCategory("Boosts"), "Product")
	end

	local currencyPage = content:FindFirstChild("CurrencyPage")
	if currencyPage and currencyPage:IsA("Frame") then
		clearGeneratedChildren(currencyPage)
		makeGridPage(currencyPage, "CurrencyCards", getProductsForCategory("Currency"), "Product")
	end
end

local function makeShopWindow(windowsFolder)
	local shopWindow = windowsFolder:FindFirstChild("ShopWindow")
	if not shopWindow or not shopWindow:IsA("GuiObject") then
		shopWindow = frame(
			windowsFolder,
			"ShopWindow",
			UDim2.fromScale(0.5, 0.5),
			UDim2.fromOffset(820, 500),
			Color3.fromRGB(255, 255, 255)
		)
	end

	prepShopWindow(shopWindow)
	makeShopTabs(shopWindow)
	local content = makeShopPages(shopWindow)
	makeFeaturedShopContent(content)
	return shopWindow
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
	text(icon, "IconText", "VIP", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 20).TextXAlignment =
		Enum.TextXAlignment.Center

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
	text(card, "Price", "R$ 0", UDim2.new(1, -130, 0, 14), UDim2.fromOffset(112, 24), 14).TextXAlignment =
		Enum.TextXAlignment.Center
	button(
		card,
		"BuyButton",
		"BUY",
		UDim2.new(1, -130, 1, -48),
		UDim2.fromOffset(112, 34),
		Color3.fromRGB(84, 225, 112)
	)

	if created then
		print("StudioMenuWindowsBuilder: created ShopWindow.Templates.ShopCardTemplate")
	end
end

local WORLD_TELEPORTS = {
	{
		id = "OriginSector",
		title = "Origin Sector",
		description = "Main spawn and starter area.",
		icon = "OR",
		color = Color3.fromRGB(220, 50, 50),
	},
	{
		id = "RedWastelands",
		title = "Red Wastelands",
		description = "Fast travel to the red cleanup field.",
		icon = "RW",
		color = Color3.fromRGB(220, 50, 50),
	},
	{
		id = "ZorkShop",
		title = "Zork Shop",
		description = "Visit Zork once to unlock this teleport.",
		icon = "ZS",
		color = Color3.fromRGB(255, 199, 87),
		requiresTeleportUnlock = true,
	},
	{
		id = "OrangeSector",
		title = "Orange Sector",
		description = "Unlocked after buying Orange Sector.",
		icon = "OR",
		color = Color3.fromRGB(240, 130, 30),
		requiredColor = "Orange",
	},
	{
		id = "InsidePipes",
		title = "Inside the Pipes",
		description = "Visit the pipe entrance first to unlock this teleport.",
		icon = "PI",
		color = Color3.fromRGB(76, 214, 224),
		requiredColor = "Orange",
		requiresTeleportUnlock = true,
	},
}

local function clearWorldsContent(content)
	for _, child in ipairs(content:GetChildren()) do
		if
			child:IsA("GuiObject")
			or child:IsA("UIGridLayout")
			or child:IsA("UIListLayout")
			or child:IsA("UIPadding")
		then
			child:Destroy()
		end
	end
end

local function worldAccent(colorType)
	local config = ColorData.Colors and ColorData.Colors[colorType]
	return config and config.color or CYAN
end

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

local function prepWorldsWindow(worldsWindow)
	worldsWindow.AnchorPoint = Vector2.new(0.5, 0.5)
	worldsWindow.Position = STANDARD_WINDOW_POSITION
	worldsWindow.Size = STANDARD_WINDOW_SIZE
	worldsWindow.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	worldsWindow.BorderSizePixel = 0
	worldsWindow.ClipsDescendants = false
	worldsWindow.ZIndex = 1000
	applyCorner(worldsWindow, 24)
	applyStroke(worldsWindow, OUTLINE, 4)

	local title = text(worldsWindow, "Title", "SECTOR SELECT", UDim2.fromOffset(28, 16), UDim2.new(1, -124, 0, 46), 32)
	title.TextScaled = true
	title.TextStrokeTransparency = 1
	title.ZIndex = 1002

	styleCloseButton(
		button(
			worldsWindow,
			"CloseButton",
			"X",
			STANDARD_CLOSE_POSITION,
			STANDARD_CLOSE_SIZE,
			Color3.fromRGB(188, 21, 28)
		),
		STANDARD_CLOSE_POSITION,
		STANDARD_CLOSE_SIZE,
		1004
	)
end

local function makeWorldsTabs(worldsWindow)
	local tabs =
		frame(worldsWindow, "Tabs", UDim2.fromOffset(26, 78), UDim2.new(1, -52, 0, 50), Color3.fromRGB(255, 255, 255))
	tabs.BackgroundTransparency = 1
	tabs.ZIndex = 1002
	for _, child in ipairs(tabs:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local layout = tabs:FindFirstChildOfClass("UIListLayout") or Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = tabs

	for index, tabConfig in ipairs({
		{ key = "Sectors", text = "Sectors" },
		{ key = "Teleports", text = "Teleports" },
	}) do
		local tab = button(
			tabs,
			tabConfig.key .. "Tab",
			tabConfig.text,
			UDim2.fromOffset(0, 0),
			UDim2.fromOffset(180, 38),
			index == 1 and CYAN or TAB_INACTIVE
		)
		tab.LayoutOrder = index
		tab.TextScaled = true
		tab.TextColor3 = index == 1 and Color3.fromRGB(255, 255, 255) or TEXT_DARK
		tab.ZIndex = 1003
	end
end

local function makeWorldHeader(parent)
	local header =
		frame(parent, "HeaderPanel", UDim2.fromOffset(14, 12), UDim2.new(1, -28, 0, 92), Color3.fromRGB(230, 250, 255))
	header:SetAttribute("StudioWorldsGenerated", true)
	header.ZIndex = 1003
	applyCorner(header, 18)
	applyStroke(header, OUTLINE, 3)

	local current = text(
		header,
		"CurrentSectorLabel",
		"Current: Start Sector",
		UDim2.fromOffset(20, 10),
		UDim2.new(0.48, 0, 0, 30),
		22
	)
	current.TextScaled = true
	current.TextStrokeTransparency = 1
	current.ZIndex = 1004

	local hint = text(
		header,
		"HintLabel",
		"Unlock sectors to travel, hatch new Colors, and find new zones.",
		UDim2.fromOffset(20, 44),
		UDim2.new(0.58, 0, 0, 28),
		13
	)
	hint.Font = Enum.Font.GothamBold
	hint.TextColor3 = MUTED
	hint.TextStrokeTransparency = 1
	hint.ZIndex = 1004

	local progress = text(
		header,
		"ProgressLabel",
		"1 / 2 sectors unlocked",
		UDim2.new(1, -244, 0, 12),
		UDim2.fromOffset(220, 26),
		18
	)
	progress.TextXAlignment = Enum.TextXAlignment.Right
	progress.TextScaled = true
	progress.TextStrokeTransparency = 1
	progress.ZIndex = 1004

	local track = frame(
		header,
		"ProgressTrack",
		UDim2.new(1, -244, 0, 54),
		UDim2.fromOffset(220, 18),
		Color3.fromRGB(211, 221, 236)
	)
	track.ZIndex = 1004
	applyCorner(track, 999)
	local trackStroke = track:FindFirstChildOfClass("UIStroke")
	if trackStroke then
		trackStroke:Destroy()
	end

	local fill = frame(track, "ProgressFill", UDim2.fromScale(0, 0), UDim2.fromScale(0.5, 1), GREEN)
	fill.ZIndex = 1005
	applyCorner(fill, 999)
	local fillStroke = fill:FindFirstChildOfClass("UIStroke")
	if fillStroke then
		fillStroke:Destroy()
	end
end

local function makeWorldSectorCard(parent, world)
	local colorType = world.primaryColor or world.id
	local accent = worldAccent(colorType)
	local maxPlayable = tonumber((GameBalance.Progression or {}).MaxPlayableSectorIndex) or math.huge
	local worldIndex = tonumber(world.WorldIndex or ColorData.getWorldIndex(colorType)) or 1
	local playable = worldIndex <= maxPlayable
	local staticCurrent = colorType == "Red"
	local staticCost = tonumber(world.UnlockCost or world.unlockCost) or 0
	local card = frame(
		parent,
		tostring(colorType) .. "SectorCard",
		UDim2.fromScale(0, 0),
		UDim2.fromOffset(744, 206),
		Color3.fromRGB(255, 255, 255)
	)
	card:SetAttribute("StudioWorldsGenerated", true)
	card:SetAttribute("WorldColor", colorType)
	card.LayoutOrder = worldIndex
	card.ZIndex = 1004
	applyCorner(card, 16)
	applyStroke(card, OUTLINE, 2)

	local accentBand = frame(card, "AccentBand", UDim2.fromScale(0, 0), UDim2.new(0, 16, 1, 0), accent)
	accentBand.ZIndex = 1005
	local accentStroke = accentBand:FindFirstChildOfClass("UIStroke")
	if accentStroke then
		accentStroke:Destroy()
	end

	local icon = frame(
		card,
		"IconCircle",
		UDim2.fromOffset(34, 34),
		UDim2.fromOffset(118, 118),
		accent:Lerp(Color3.fromRGB(255, 255, 255), 0.18)
	)
	icon.ZIndex = 1005
	applyCorner(icon, 24)
	applyStroke(icon, OUTLINE, 3)
	local iconText = text(icon, "IconText", worldIconText(colorType), UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 42)
	iconText.TextXAlignment = Enum.TextXAlignment.Center
	iconText.TextScaled = true
	iconText.TextColor3 = Color3.fromRGB(255, 255, 255)
	iconText.TextStrokeColor3 = OUTLINE
	iconText.TextStrokeTransparency = 0
	iconText.ZIndex = 1006

	local name = text(
		card,
		"Name",
		tostring(world.DisplayName or world.name or colorType),
		UDim2.fromOffset(178, 24),
		UDim2.new(1, -332, 0, 40),
		28
	)
	name.TextScaled = true
	name.TextStrokeTransparency = 1
	name.ZIndex = 1005

	local meta = text(
		card,
		"Meta",
		"Power x" .. tostring(world.rewardMultiplier or 1) .. " | " .. tostring(#(world.EggIds or {})) .. " eggs",
		UDim2.fromOffset(180, 68),
		UDim2.new(1, -360, 0, 24),
		15
	)
	meta.Font = Enum.Font.GothamBold
	meta.TextColor3 = MUTED
	meta.TextStrokeTransparency = 1
	meta.ZIndex = 1005

	local defaultRequirement = staticCurrent and "You are here now."
		or (not playable and "Coming in a future update.")
		or ("Unlock for " .. formatNumber(staticCost) .. " Coins.")
	local requirement =
		text(card, "Requirement", defaultRequirement, UDim2.fromOffset(180, 98), UDim2.new(1, -360, 0, 26), 15)
	requirement.Font = Enum.Font.GothamBold
	requirement.TextColor3 = MUTED
	requirement.TextStrokeTransparency = 1
	requirement.ZIndex = 1005

	local statusText = staticCurrent and "CURRENT" or (playable and (formatNumber(staticCost) .. " COINS") or "SOON")
	local statusColor = staticCurrent and GREEN or (playable and Color3.fromRGB(255, 218, 74) or DISABLED)
	local statusTextColor = staticCurrent and Color3.fromRGB(255, 255, 255) or TEXT_DARK
	local status = text(card, "Status", statusText, UDim2.fromOffset(180, 134), UDim2.fromOffset(142, 30), 14)
	status.BackgroundTransparency = 0
	status.BackgroundColor3 = statusColor
	status.TextColor3 = statusTextColor
	status.TextXAlignment = Enum.TextXAlignment.Center
	status.TextScaled = true
	status.TextStrokeTransparency = 1
	status.ZIndex = 1005
	applyCorner(status, 999)
	applyStroke(status, OUTLINE, 2)

	local actionText = staticCurrent and "CURRENT" or (playable and "UNLOCK" or "SOON")
	local actionColor = playable and GREEN or DISABLED
	local action =
		button(card, "TeleportButton", actionText, UDim2.new(1, -190, 0.5, -26), UDim2.fromOffset(160, 52), actionColor)
	action:SetAttribute("WorldColor", colorType)
	action.TextScaled = true
	action.ZIndex = 1006

	local scrollHint = text(
		card,
		"ScrollHint",
		"Scroll sideways to browse sectors",
		UDim2.new(1, -260, 1, -36),
		UDim2.fromOffset(230, 22),
		12
	)
	scrollHint.Font = Enum.Font.GothamBold
	scrollHint.TextColor3 = MUTED
	scrollHint.TextXAlignment = Enum.TextXAlignment.Right
	scrollHint.TextStrokeTransparency = 1
	scrollHint.ZIndex = 1005
end

local function makeSectorsPage(content)
	local page = frame(content, "SectorsPage", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), PANEL)
	page:SetAttribute("StudioWorldsGenerated", true)
	page.BackgroundTransparency = 1
	page.ZIndex = 1002
	local pageStroke = page:FindFirstChildOfClass("UIStroke")
	if pageStroke then
		pageStroke:Destroy()
	end
	makeWorldHeader(page)

	local carousel = scrollingFrame(page, "SectorCarousel", UDim2.fromOffset(14, 116), UDim2.new(1, -28, 1, -130))
	carousel:SetAttribute("StudioWorldsGenerated", true)
	carousel:SetAttribute("CardStep", 768)
	carousel.BackgroundColor3 = Color3.fromRGB(246, 249, 255)
	carousel.ScrollBarThickness = 8
	carousel.ScrollingDirection = Enum.ScrollingDirection.X
	carousel.ZIndex = 1003
	carousel.CanvasSize = UDim2.fromOffset((#(ColorData.Worlds or {}) * 768) + 36, 0)

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 14)
	padding.PaddingBottom = UDim.new(0, 14)
	padding.PaddingLeft = UDim.new(0, 18)
	padding.PaddingRight = UDim.new(0, 18)
	padding.Parent = carousel

	local layout = carousel:FindFirstChildOfClass("UIListLayout") or Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 24)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = carousel

	for _, world in ipairs(ColorData.Worlds or {}) do
		makeWorldSectorCard(carousel, world)
	end
end

local function makeTeleportCard(parent, teleport, layoutOrder)
	local card = frame(
		parent,
		tostring(teleport.id) .. "TeleportCard",
		UDim2.fromScale(0, 0),
		UDim2.fromOffset(358, 118),
		Color3.fromRGB(255, 255, 255)
	)
	card:SetAttribute("StudioWorldsGenerated", true)
	card:SetAttribute("LocationId", teleport.id)
	card.LayoutOrder = layoutOrder
	card.ZIndex = 1004
	applyCorner(card, 16)
	applyStroke(card, OUTLINE, 2)

	local icon = frame(
		card,
		"IconCircle",
		UDim2.fromOffset(12, 14),
		UDim2.fromOffset(64, 64),
		teleport.color:Lerp(Color3.fromRGB(255, 255, 255), 0.16)
	)
	icon.ZIndex = 1005
	applyCorner(icon, 16)
	applyStroke(icon, OUTLINE, 2)
	local iconText = text(icon, "IconText", teleport.icon, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 20)
	iconText.TextXAlignment = Enum.TextXAlignment.Center
	iconText.TextScaled = true
	iconText.TextColor3 = Color3.fromRGB(255, 255, 255)
	iconText.TextStrokeColor3 = OUTLINE
	iconText.TextStrokeTransparency = 0
	iconText.ZIndex = 1006

	local name = text(card, "Name", teleport.title, UDim2.fromOffset(88, 10), UDim2.new(1, -104, 0, 28), 18)
	name.TextScaled = true
	name.TextStrokeTransparency = 1
	name.ZIndex = 1005

	local description =
		text(card, "Description", teleport.description, UDim2.fromOffset(88, 40), UDim2.new(1, -104, 0, 34), 12)
	description.Font = Enum.Font.GothamBold
	description.TextColor3 = MUTED
	description.TextStrokeTransparency = 1
	description.ZIndex = 1005

	local status = text(card, "Status", "LOCKED", UDim2.fromOffset(12, 84), UDim2.fromOffset(112, 24), 12)
	status.BackgroundTransparency = 0
	status.BackgroundColor3 = TAB_INACTIVE
	status.TextColor3 = TEXT_DARK
	status.TextXAlignment = Enum.TextXAlignment.Center
	status.TextScaled = true
	status.TextStrokeTransparency = 1
	status.ZIndex = 1005
	applyCorner(status, 999)
	applyStroke(status, OUTLINE, 2)

	local action = button(card, "TeleportButton", "GO", UDim2.new(1, -122, 1, -36), UDim2.fromOffset(108, 28), GREEN)
	action:SetAttribute("LocationId", teleport.id)
	action.TextScaled = true
	action.ZIndex = 1006
end

local function makeTeleportsPage(content)
	local page = frame(content, "TeleportsPage", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), PANEL)
	page:SetAttribute("StudioWorldsGenerated", true)
	page.BackgroundTransparency = 1
	page.Visible = false
	page.ZIndex = 1002
	local pageStroke = page:FindFirstChildOfClass("UIStroke")
	if pageStroke then
		pageStroke:Destroy()
	end

	local header =
		frame(page, "HeaderPanel", UDim2.fromOffset(14, 12), UDim2.new(1, -28, 0, 76), Color3.fromRGB(248, 252, 255))
	header:SetAttribute("StudioWorldsGenerated", true)
	header.ZIndex = 1003
	applyCorner(header, 18)
	applyStroke(header, OUTLINE, 3)
	local title = text(header, "HeaderTitle", "FAST TRAVEL", UDim2.fromOffset(20, 10), UDim2.new(0.42, 0, 0, 30), 24)
	title.TextScaled = true
	title.TextStrokeTransparency = 1
	title.ZIndex = 1004
	local subtitle = text(
		header,
		"HeaderSubtitle",
		"Unlocked locations stay editable and update while you play.",
		UDim2.fromOffset(20, 42),
		UDim2.new(0.75, 0, 0, 22),
		13
	)
	subtitle.Font = Enum.Font.GothamBold
	subtitle.TextColor3 = MUTED
	subtitle.TextStrokeTransparency = 1
	subtitle.ZIndex = 1004

	local grid = scrollingFrame(page, "TeleportGrid", UDim2.fromOffset(14, 100), UDim2.new(1, -28, 1, -114))
	grid:SetAttribute("StudioWorldsGenerated", true)
	grid.BackgroundColor3 = Color3.fromRGB(246, 249, 255)
	grid.ScrollBarThickness = 7
	grid.ZIndex = 1003
	grid.CanvasSize = UDim2.fromOffset(0, 420)

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = grid

	local layout = grid:FindFirstChildOfClass("UIGridLayout") or Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(358, 118)
	layout.CellPadding = UDim2.fromOffset(12, 12)
	layout.FillDirectionMaxCells = 2
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	for index, teleport in ipairs(WORLD_TELEPORTS) do
		makeTeleportCard(grid, teleport, index)
	end
end

local function makeWorldsWindow(windowsFolder)
	local worldsWindow = windowsFolder:FindFirstChild("WorldsWindow")
	if not worldsWindow or not worldsWindow:IsA("GuiObject") then
		worldsWindow = frame(
			windowsFolder,
			"WorldsWindow",
			UDim2.fromScale(0.5, 0.46),
			UDim2.fromOffset(860, 540),
			Color3.fromRGB(255, 255, 255)
		)
	end
	worldsWindow.Visible = false
	prepWorldsWindow(worldsWindow)
	makeWorldsTabs(worldsWindow)

	local content = worldsWindow:FindFirstChild("Content")
	if not content or not content:IsA("GuiObject") then
		content = frame(worldsWindow, "Content", UDim2.fromOffset(26, 140), UDim2.new(1, -52, 1, -166), PANEL)
	end
	content.Position = UDim2.fromOffset(26, 140)
	content.Size = UDim2.new(1, -52, 1, -166)
	content.BackgroundColor3 = PANEL
	content.ClipsDescendants = true
	content.ZIndex = 1001
	applyCorner(content, 18)
	applyStroke(content, OUTLINE, 3)
	clearWorldsContent(content)
	makeSectorsPage(content)
	makeTeleportsPage(content)
	return worldsWindow
end

local function makeBrushShopWindow(windowsFolder)
	local window, content = makeWindow(windowsFolder, "BrushShopWindow", "ZORK BRUSH SHOP", {})
	window.Size = UDim2.fromOffset(760, 430)
	window.Position = UDim2.fromScale(0.5, 0.45)

	local header = text(
		content,
		"IntroText",
		"Sector brushes. Buy once, then equip or unequip.",
		UDim2.fromOffset(18, 12),
		UDim2.new(1, -36, 0, 28),
		15
	)
	header.Font = Enum.Font.GothamBold
	header.TextColor3 = MUTED
	header.TextStrokeTransparency = 1

	local existingGrid = content:FindFirstChild("ToolGrid")
	if existingGrid and not existingGrid:IsA("ScrollingFrame") then
		existingGrid:Destroy()
		existingGrid = nil
	end

	local grid = existingGrid or Instance.new("ScrollingFrame")
	grid.Name = "ToolGrid"
	grid.Position = UDim2.fromOffset(14, 52)
	grid.Size = UDim2.new(1, -28, 1, -66)
	grid.BackgroundColor3 = Color3.fromRGB(246, 249, 255)
	grid.BorderSizePixel = 0
	grid.ClipsDescendants = true
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.fromOffset(0, 0)
	grid.ScrollBarThickness = 8
	grid.ScrollBarImageColor3 = MUTED
	grid.ScrollingDirection = Enum.ScrollingDirection.Y
	grid.Parent = content
	applyCorner(grid, 18)
	applyStroke(grid, Color3.fromRGB(35, 38, 45), 2)

	for _, child in ipairs(grid:GetChildren()) do
		if child:IsA("UIGridLayout") then
			child:Destroy()
		end
	end
	local layout = grid:FindFirstChildOfClass("UIListLayout") or Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 12)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	local padding = grid:FindFirstChildOfClass("UIPadding") or Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 14)
	padding.PaddingBottom = UDim.new(0, 14)
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingRight = UDim.new(0, 14)
	padding.Parent = grid

	local template =
		frame(grid, "ToolCardTemplate", UDim2.fromScale(0, 0), UDim2.new(1, -28, 0, 112), Color3.fromRGB(255, 255, 255))
	template.Visible = false
	local icon =
		frame(template, "Icon", UDim2.fromOffset(12, 14), UDim2.fromOffset(70, 70), Color3.fromRGB(225, 244, 255))
	text(icon, "IconText", "BR", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 18).TextXAlignment =
		Enum.TextXAlignment.Center
	text(template, "Name", "Starter Brush", UDim2.fromOffset(94, 10), UDim2.new(1, -248, 0, 24), 18)
	local desc =
		text(template, "Description", "Editable brush card.", UDim2.fromOffset(94, 36), UDim2.new(1, -278, 0, 30), 12)
	desc.Font = Enum.Font.GothamBold
	desc.TextColor3 = MUTED
	desc.TextStrokeTransparency = 1
	text(template, "Stats", "Power x1.00  Range 9", UDim2.fromOffset(94, 66), UDim2.new(1, -278, 0, 18), 11)
	text(template, "Price", "FREE", UDim2.fromOffset(94, 86), UDim2.fromOffset(120, 20), 13)
	text(template, "Status", "OWNED", UDim2.new(1, -232, 0, 26), UDim2.fromOffset(104, 24), 12).TextXAlignment =
		Enum.TextXAlignment.Center
	button(template, "BuyButton", "EQUIP", UDim2.new(1, -118, 0.5, -16), UDim2.fromOffset(96, 32), GREEN)

	for _, child in ipairs(grid:GetChildren()) do
		if child:IsA("GuiObject") and child ~= template then
			child:Destroy()
		end
	end

	for index, tool in ipairs(ToolData.GetBrushesForWorldColor("Red")) do
		local card = template:Clone()
		card.Name = tool.Id .. "Card"
		card:SetAttribute("BrushShopStudioCard", true)
		card:SetAttribute("ToolId", tool.Id)
		card.LayoutOrder = index
		card.Visible = true
		card.Parent = grid

		local name = card:FindFirstChild("Name", true)
		if name and name:IsA("TextLabel") then
			name.Text = tool.DisplayName
		end
		local description = card:FindFirstChild("Description", true)
		if description and description:IsA("TextLabel") then
			description.Text = tool.Description or tool.PassiveDescription or ""
		end
		local stats = card:FindFirstChild("Stats", true)
		if stats and stats:IsA("TextLabel") then
			stats.Text =
				string.format("Power x%.2f  Range %d", tonumber(tool.PowerMultiplier) or 1, tonumber(tool.Range) or 0)
		end
		local price = card:FindFirstChild("Price", true)
		if price and price:IsA("TextLabel") then
			price.Text = tool.Cost == 0 and "FREE" or tostring(tool.Cost) .. " Coins"
		end
		local status = card:FindFirstChild("Status", true)
		if status and status:IsA("TextLabel") then
			status.Text = tool.Rarity or "Brush"
		end
		local iconText = card:FindFirstChild("IconText", true)
		if iconText and iconText:IsA("TextLabel") then
			iconText.Text = tool.ShortName or string.sub(tool.DisplayName, 1, 2):upper()
		end
		local buyButton = card:FindFirstChild("BuyButton", true)
		if buyButton and buyButton:IsA("TextButton") then
			buyButton.Text = tool.Cost == 0 and "CLAIM" or "BUY"
		end
	end
	return window
end

local function makeDailyQuestsWindow(windowsFolder)
	local window, content = makeWindow(windowsFolder, "DailyQuestsWindow", "DAILY QUESTS", {})
	window.Size = UDim2.fromOffset(780, 430)
	window.Position = UDim2.fromScale(0.5, 0.45)

	local intro = text(
		content,
		"IntroText",
		"Daily jobs from Zork. Finish them, then come back here to claim gems.",
		UDim2.fromOffset(18, 12),
		UDim2.new(1, -36, 0, 28),
		15
	)
	intro.Font = Enum.Font.GothamBold
	intro.TextColor3 = MUTED
	intro.TextStrokeTransparency = 1

	local listHost = frame(content, "Body", UDim2.fromOffset(14, 52), UDim2.new(1, -28, 1, -66), PANEL)
	listHost.BackgroundTransparency = 1
	local bodyStroke = listHost:FindFirstChildOfClass("UIStroke")
	if bodyStroke then
		bodyStroke:Destroy()
	end
	makeDailyQuestRows(listHost)
	return window
end

local function makeZorkDialogueWindow(windowsFolder)
	local window = frame(
		windowsFolder,
		"ZorkDialogueWindow",
		UDim2.fromScale(0.5, 0.58),
		UDim2.fromOffset(620, 260),
		Color3.fromRGB(255, 255, 255)
	)
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Visible = false
	applyCorner(window, 24)
	applyStroke(window, OUTLINE, 4)
	text(window, "Title", "ZORK", UDim2.fromOffset(24, 16), UDim2.new(1, -104, 0, 36), 28)
	styleCloseButton(
		button(
			window,
			"CloseButton",
			"X",
			UDim2.new(1, -64, 0, 14),
			UDim2.fromOffset(46, 42),
			Color3.fromRGB(188, 21, 28)
		),
		UDim2.new(1, -70, 0, 14),
		UDim2.fromOffset(52, 48),
		window.ZIndex + 3
	)

	local content = frame(window, "Content", UDim2.fromOffset(22, 70), UDim2.new(1, -44, 1, -92), PANEL)
	local name = text(content, "SpeakerName", "Zork", UDim2.fromOffset(18, 12), UDim2.fromOffset(150, 28), 22)
	name.TextStrokeTransparency = 1
	local role = text(
		content,
		"SpeakerRole",
		"Brush Merchant + Daily Quests",
		UDim2.fromOffset(170, 18),
		UDim2.new(1, -188, 0, 20),
		13
	)
	role.Font = Enum.Font.GothamBold
	role.TextColor3 = MUTED
	role.TextStrokeTransparency = 1
	local body =
		text(content, "Body", "Editable Zork dialogue.", UDim2.fromOffset(18, 52), UDim2.new(1, -36, 0, 76), 17)
	body.Font = Enum.Font.GothamBold
	body.TextWrapped = true
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextStrokeTransparency = 1
	button(content, "ShopButton", "BRUSH SHOP", UDim2.new(0, 18, 1, -48), UDim2.fromOffset(180, 34), GREEN)
	button(content, "QuestsButton", "DAILY QUESTS", UDim2.new(0, 212, 1, -48), UDim2.fromOffset(180, 34), CYAN)
	return window
end

local function makeTutorialWindow(windowsFolder)
	local window, content = makeWindow(windowsFolder, "TutorialWindow", "TUTORIAL", {})
	window.Size = UDim2.fromOffset(700, 420)
	window.Position = UDim2.fromScale(0.5, 0.47)

	local stepLabel = text(content, "StepLabel", "1 / 3", UDim2.new(1, -96, 0, 12), UDim2.fromOffset(76, 24), 14)
	stepLabel.TextXAlignment = Enum.TextXAlignment.Right
	stepLabel.Font = Enum.Font.GothamBold
	stepLabel.TextColor3 = MUTED
	stepLabel.TextStrokeTransparency = 1

	local steps = findOrCreate(content, "Folder", "Steps")
	for index, data in ipairs({
		{ "Step1", "Move Around", "Use the brush to clean Color spills and earn coins." },
		{ "Step2", "Hatch Colors", "Spend coins at eggs to hatch living Colors." },
		{ "Step3", "Visit Zork", "Talk to Zork for starter brushes and daily quests." },
	}) do
		local step =
			frame(steps, data[1], UDim2.fromOffset(18, 44), UDim2.new(1, -36, 1, -104), Color3.fromRGB(255, 255, 255))
		step.LayoutOrder = index
		step.Visible = index == 1
		text(step, "Heading", data[2], UDim2.fromOffset(22, 18), UDim2.new(1, -44, 0, 34), 24)
		local body = text(step, "Body", data[3], UDim2.fromOffset(22, 62), UDim2.new(1, -44, 0, 88), 18)
		body.Font = Enum.Font.GothamBold
		body.TextWrapped = true
		body.TextYAlignment = Enum.TextYAlignment.Top
		body.TextStrokeTransparency = 1
	end
	button(content, "BackButton", "BACK", UDim2.new(0, 18, 1, -46), UDim2.fromOffset(140, 32), DISABLED)
	button(content, "NextButton", "NEXT", UDim2.new(1, -158, 1, -46), UDim2.fromOffset(140, 32), GREEN)
	return window
end

local function getSettingsContent()
	local root = StarterGui:FindFirstChild("ClientUIRoot")
	local mainHud = root and root:FindFirstChild("MainHUD")
	local modalWindows = mainHud and mainHud:FindFirstChild("ModalWindows")
	local windowsFolder = modalWindows and modalWindows:FindFirstChild("Windows")
	local settingsWindow = windowsFolder and windowsFolder:FindFirstChild("SettingsWindow")
	return settingsWindow and settingsWindow:FindFirstChild("Content")
end

local function getWindowContent(windowName)
	local root = StarterGui:FindFirstChild("ClientUIRoot")
	local mainHud = root and root:FindFirstChild("MainHUD")
	local modalWindows = mainHud and mainHud:FindFirstChild("ModalWindows")
	local windowsFolder = modalWindows and modalWindows:FindFirstChild("Windows")
	local window = windowsFolder and windowsFolder:FindFirstChild(windowName)
		or StarterGui:FindFirstChild(windowName, true)
	if not window or not window:IsA("GuiObject") then
		return nil
	end

	local content = window:FindFirstChild("Content") or window:FindFirstChild("Content", true)
	if content and content:IsA("GuiObject") then
		return content
	end

	return frame(window, "Content", UDim2.fromOffset(22, 82), UDim2.new(1, -44, 1, -108), Color3.fromRGB(244, 248, 252))
end

function Builder.UpdateSettingsWindow()
	if not RunService:IsStudio() then
		warn("StudioMenuWindowsBuilder.UpdateSettingsWindow can only run in Roblox Studio.")
		return
	end
	if RunService:IsRunning() then
		warn("StudioMenuWindowsBuilder.UpdateSettingsWindow should be run in edit mode, not during Play.")
		return
	end

	local content = getSettingsContent()
	if not content then
		warn(
			"StudioMenuWindowsBuilder.UpdateSettingsWindow could not find StarterGui.ClientUIRoot.MainHUD.ModalWindows.Windows.SettingsWindow.Content."
		)
		return
	end

	makeSettingsGrid(content)
	print("StudioMenuWindowsBuilder: updated SettingsWindow card text.")
end

function Builder.UpdateCodesWindow()
	if not RunService:IsStudio() then
		warn("StudioMenuWindowsBuilder.UpdateCodesWindow can only run in Roblox Studio.")
		return
	end
	if RunService:IsRunning() then
		warn("StudioMenuWindowsBuilder.UpdateCodesWindow should be run in edit mode, not during Play.")
		return
	end

	local content = getWindowContent("CodesWindow")
	if not content then
		warn("StudioMenuWindowsBuilder.UpdateCodesWindow could not find a CodesWindow under StarterGui.")
		return
	end

	makeCodesContent(content)
	print("StudioMenuWindowsBuilder: updated CodesWindow layout.")
end

function Builder.UpdateShopWindow()
	if not RunService:IsStudio() then
		warn("StudioMenuWindowsBuilder.UpdateShopWindow can only run in Roblox Studio.")
		return
	end
	if RunService:IsRunning() then
		warn("StudioMenuWindowsBuilder.UpdateShopWindow should be run in edit mode, not during Play.")
		return
	end

	local mainHud = StarterGui:FindFirstChild("MainHUD")
	local modalWindows = mainHud and mainHud:FindFirstChild("ModalWindows")
	local windowsFolder = modalWindows
	local root = StarterGui:FindFirstChild("ClientUIRoot")
	if not windowsFolder then
		local legacyMainHud = root and root:FindFirstChild("MainHUD")
		local legacyModalWindows = legacyMainHud and legacyMainHud:FindFirstChild("ModalWindows")
		windowsFolder = legacyModalWindows and legacyModalWindows:FindFirstChild("Windows")
	end
	local existingShopWindow = StarterGui:FindFirstChild("ShopWindow", true)
	if not windowsFolder and existingShopWindow and existingShopWindow.Parent then
		windowsFolder = existingShopWindow.Parent
	end
	if not windowsFolder then
		warn(
			"StudioMenuWindowsBuilder.UpdateShopWindow could not find a ShopWindow or Windows folder under StarterGui."
		)
		return
	end

	makeShopWindow(windowsFolder)
	print("StudioMenuWindowsBuilder: updated ShopWindow Featured shop layout.")
end

function Builder.ApplyUpgradeIcons()
	if not RunService:IsStudio() then
		warn("StudioMenuWindowsBuilder.ApplyUpgradeIcons can only run in Roblox Studio.")
		return
	end
	if RunService:IsRunning() then
		warn("StudioMenuWindowsBuilder.ApplyUpgradeIcons should be run in edit mode, not during Play.")
		return
	end

	local root = StarterGui:FindFirstChild("ClientUIRoot")
	local upgradesWindow = root and root:FindFirstChild("UpgradesWindow", true)
	if not upgradesWindow or not upgradesWindow:IsA("GuiObject") then
		warn("StudioMenuWindowsBuilder.ApplyUpgradeIcons could not find StarterGui.ClientUIRoot...UpgradesWindow.")
		return
	end

	local applied = applyUpgradeIconsToWindow(upgradesWindow)
	print("StudioMenuWindowsBuilder: applied upgrade icon slots to " .. tostring(applied) .. " cards.")
end

function Builder.UpdateUpgradesWindow()
	if not RunService:IsStudio() then
		warn("StudioMenuWindowsBuilder.UpdateUpgradesWindow can only run in Roblox Studio.")
		return
	end
	if RunService:IsRunning() then
		warn("StudioMenuWindowsBuilder.UpdateUpgradesWindow should be run in edit mode, not during Play.")
		return
	end

	local root = StarterGui:FindFirstChild("ClientUIRoot")
	local mainHud = root and root:FindFirstChild("MainHUD")
	local modalWindows = mainHud and mainHud:FindFirstChild("ModalWindows")
	local windowsFolder = modalWindows and modalWindows:FindFirstChild("Windows")
	local existingUpgradesWindow = StarterGui:FindFirstChild("UpgradesWindow", true)
	if not windowsFolder and existingUpgradesWindow and existingUpgradesWindow.Parent then
		windowsFolder = existingUpgradesWindow.Parent
	end
	if not windowsFolder then
		warn(
			"StudioMenuWindowsBuilder.UpdateUpgradesWindow could not find an UpgradesWindow or Windows folder under StarterGui."
		)
		return
	end

	makeUpgradesWindow(windowsFolder)
	print("StudioMenuWindowsBuilder: updated UpgradesWindow with Studio-authored upgrade cards.")
end

function Builder.ApplyGamepassIcons()
	if not RunService:IsStudio() then
		warn("StudioMenuWindowsBuilder.ApplyGamepassIcons can only run in Roblox Studio.")
		return
	end
	if RunService:IsRunning() then
		warn("StudioMenuWindowsBuilder.ApplyGamepassIcons should be run in edit mode, not during Play.")
		return
	end

	local root = StarterGui:FindFirstChild("ClientUIRoot")
	local shopWindow = root and root:FindFirstChild("ShopWindow", true)
	if not shopWindow or not shopWindow:IsA("GuiObject") then
		warn("StudioMenuWindowsBuilder.ApplyGamepassIcons could not find StarterGui.ClientUIRoot...ShopWindow.")
		return
	end

	local applied = applyGamepassIconsToWindow(shopWindow)
	print("StudioMenuWindowsBuilder: applied gamepass icon slots to " .. tostring(applied) .. " cards.")
end

function Builder.UpdateWorldsWindow()
	if not RunService:IsStudio() then
		warn("StudioMenuWindowsBuilder.UpdateWorldsWindow can only run in Roblox Studio.")
		return
	end
	if RunService:IsRunning() then
		warn("StudioMenuWindowsBuilder.UpdateWorldsWindow should be run in edit mode, not during Play.")
		return
	end

	local mainHud = StarterGui:FindFirstChild("MainHUD")
	local modalWindows = mainHud and mainHud:FindFirstChild("ModalWindows")
	local windowsFolder = modalWindows
	local root = StarterGui:FindFirstChild("ClientUIRoot")
	if not windowsFolder then
		local legacyMainHud = root and root:FindFirstChild("MainHUD")
		local legacyModalWindows = legacyMainHud and legacyMainHud:FindFirstChild("ModalWindows")
		windowsFolder = legacyModalWindows and legacyModalWindows:FindFirstChild("Windows")
	end
	local existingWorldsWindow = StarterGui:FindFirstChild("WorldsWindow", true)
	if not windowsFolder and existingWorldsWindow and existingWorldsWindow.Parent then
		windowsFolder = existingWorldsWindow.Parent
	end
	if not windowsFolder then
		warn(
			"StudioMenuWindowsBuilder.UpdateWorldsWindow could not find a WorldsWindow or Windows folder under StarterGui."
		)
		return
	end

	makeWorldsWindow(windowsFolder)
	print("StudioMenuWindowsBuilder: updated WorldsWindow sector select layout.")
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
	local dim = findOrCreate(mainHud, "Frame", "DimBackground")
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	dim.BackgroundTransparency = 0.45
	dim.ZIndex = 10
	dim.Visible = false

	local modalWindows = findOrCreate(mainHud, "Folder", "ModalWindows")
	local windowsFolder = findOrCreate(modalWindows, "Folder", "Windows")
	makeInventory(windowsFolder)
	makeShopWindow(windowsFolder)
	makeZorkDialogueWindow(windowsFolder)
	makeBrushShopWindow(windowsFolder)
	makeUpgradesWindow(windowsFolder)
	local _, settingsContent = makeWindow(windowsFolder, "SettingsWindow", "SETTINGS", {})
	makeSettingsGrid(settingsContent)
	local _, codesContent = makeWindow(windowsFolder, "CodesWindow", "CODES", {})
	makeCodesContent(codesContent)
	local _, tradeContent = makeWindow(windowsFolder, "TradeWindow", "TRADE", {})
	text(tradeContent, "ComingSoon", "Trading is coming soon!", UDim2.fromScale(0, 0.35), UDim2.fromScale(1, 0.18), 28).TextXAlignment =
		Enum.TextXAlignment.Center
	makeWorldsWindow(windowsFolder)
	local _, questsContent = makeWindow(windowsFolder, "DailyQuestsWindow", "DAILY QUESTS", {})
	makeDailyQuestRows(questsContent)
	makeTutorialWindow(windowsFolder)

	print("StudioMenuWindowsBuilder: editable UI created at StarterGui.ClientUIRoot.MainHUD.ModalWindows.Windows")
end

local function canBuildConceptMenus(commandName)
	if not RunService:IsStudio() then
		warn("StudioMenuWindowsBuilder." .. commandName .. " can only run in Roblox Studio.")
		return false
	end
	if RunService:IsRunning() then
		warn("StudioMenuWindowsBuilder." .. commandName .. " should be run in edit mode, not during Play.")
		return false
	end
	return true
end

local function ensureClass(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing and not existing:IsA(className) then
		if existing:IsA("GuiObject") then
			existing.Visible = false
		end
		existing.Name = name .. "_Legacy"
		existing = nil
	end
	if existing then
		return existing
	end

	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance
end

local function clearChildren(parent)
	for _, child in ipairs(parent:GetChildren()) do
		child:Destroy()
	end
end

local function ensureUiScale(parent, name, scaleValue)
	local scale = parent:FindFirstChild(name)
	if scale and not scale:IsA("UIScale") then
		scale:Destroy()
		scale = nil
	end
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = name
		scale.Parent = parent
	end
	scale.Scale = scaleValue or 1
	return scale
end

local function ensureAspectRatio(parent, aspectRatio)
	local constraint = parent:FindFirstChild("ResponsiveAspect")
	if constraint and not constraint:IsA("UIAspectRatioConstraint") then
		constraint:Destroy()
		constraint = nil
	end
	if not constraint then
		constraint = Instance.new("UIAspectRatioConstraint")
		constraint.Name = "ResponsiveAspect"
		constraint.Parent = parent
	end
	constraint.AspectRatio = aspectRatio or 1.55
	constraint.AspectType = Enum.AspectType.ScaleWithParentSize
	constraint.DominantAxis = Enum.DominantAxis.Width
	return constraint
end

local function ensurePadding(parent, name, padding)
	local pad = parent:FindFirstChild(name)
	if pad and not pad:IsA("UIPadding") then
		pad:Destroy()
		pad = nil
	end
	if not pad then
		pad = Instance.new("UIPadding")
		pad.Name = name
		pad.Parent = parent
	end
	pad.PaddingTop = UDim.new(0, padding or 0)
	pad.PaddingBottom = UDim.new(0, padding or 0)
	pad.PaddingLeft = UDim.new(0, padding or 0)
	pad.PaddingRight = UDim.new(0, padding or 0)
	return pad
end

makeResponsiveWindow = function(window, content)
	window:SetAttribute("ResponsiveWindow", true)
	window:SetAttribute("DesktopWidthScale", 0.72)
	window:SetAttribute("DesktopHeightScale", 0.72)
	window:SetAttribute("MobilePortraitWidthScale", 0.94)
	window:SetAttribute("MobilePortraitHeightScale", 0.78)
	window:SetAttribute("MobileLandscapeWidthScale", 0.78)
	window:SetAttribute("MobileLandscapeHeightScale", 0.82)
	ensureUiScale(window, "ResponsiveScale", 1)
	ensureAspectRatio(window, 1.55)
	if content and content:IsA("GuiObject") then
		content:SetAttribute("ResponsiveContent", true)
		ensurePadding(content, "ResponsivePadding", 0)
	end
end

local function conceptLabel(parent, name, value, position, size, textSize, alignment)
	local label = text(parent, name, value, position, size, textSize)
	label.TextXAlignment = alignment or Enum.TextXAlignment.Left
	label.TextWrapped = true
	return label
end

local function conceptButton(parent, name, value, position, size, color)
	local btn = button(parent, name, value, position, size, color)
	btn.TextSize = math.min(btn.TextSize, 24)
	return btn
end

local function imageButton(parent, name, position, size, color)
	local existing = parent:FindFirstChild(name)
	local migratedChildren = {}
	local migratedText = ""
	if existing and not existing:IsA("ImageButton") then
		if existing:IsA("TextButton") or existing:IsA("TextLabel") or existing:IsA("TextBox") then
			migratedText = existing.Text
		end
		for _, child in ipairs(existing:GetChildren()) do
			table.insert(migratedChildren, child)
		end
		if existing:IsA("GuiObject") then
			existing.Visible = false
		end
		existing.Parent = nil
		existing = nil
	end

	local btn = existing or Instance.new("ImageButton")
	btn.Name = name
	btn.AutoButtonColor = true
	btn.Image = ""
	btn.ScaleType = Enum.ScaleType.Fit
	btn.BackgroundColor3 = color or Color3.fromRGB(45, 167, 255)
	btn.BorderSizePixel = 0
	btn.Position = position
	btn.Size = size
	btn.Parent = parent
	for _, child in ipairs(migratedChildren) do
		child.Parent = btn
	end
	if migratedText ~= "" and not btn:FindFirstChild("Label") then
		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.Text = migratedText
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextStrokeColor3 = OUTLINE
		label.TextStrokeTransparency = 0
		label.TextScaled = true
		label.TextWrapped = true
		label.Position = UDim2.fromOffset(4, 4)
		label.Size = UDim2.new(1, -8, 1, -8)
		label.Parent = btn
	end
	applyCorner(btn, 12)
	applyStroke(btn, OUTLINE, 2)
	return btn
end

local function conceptPanel(parent, name, position, size, color, radius, strokeThickness)
	local panel = frame(parent, name, position, size, color or Color3.fromRGB(255, 255, 255))
	applyCorner(panel, radius or 18)
	applyStroke(panel, OUTLINE, strokeThickness or 2)
	return panel
end

local function conceptScrollingPanel(parent, name, position, size, color, radius, strokeThickness)
	local panel = ensureClass(parent, "ScrollingFrame", name)
	panel.Position = position
	panel.Size = size
	panel.BackgroundColor3 = color or Color3.fromRGB(255, 255, 255)
	panel.BackgroundTransparency = 0
	panel.BorderSizePixel = 0
	panel.ClipsDescendants = true
	panel.ScrollBarThickness = 6
	panel.ScrollBarImageColor3 = MUTED
	panel.ScrollingDirection = Enum.ScrollingDirection.Y
	panel.ScrollingEnabled = true
	panel.AutomaticCanvasSize = Enum.AutomaticSize.Y
	panel.CanvasSize = UDim2.fromOffset(0, 0)
	applyCorner(panel, radius or 18)
	applyStroke(panel, OUTLINE, strokeThickness or 2)
	return panel
end

local function conceptWindow(modalWindows, name, title)
	local window = ensureClass(modalWindows, "Frame", name)
	clearChildren(window)
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = STANDARD_WINDOW_POSITION
	window.Size = STANDARD_WINDOW_SIZE
	local accent = getMenuAccent(name)
	window.BackgroundColor3 = MENU_PANELS.Shell or tintTowardWhite(accent, 0.72)
	window.BorderSizePixel = 0
	window.ClipsDescendants = false
	window.Visible = false
	applyCorner(window, 28)
	applyStroke(window, OUTLINE, 5)

	local accentStrip = frame(window, "AccentStrip", UDim2.fromScale(0.04, 0.018), UDim2.fromScale(0.92, 0.035), accent)
	accentStrip.BorderSizePixel = 0
	accentStrip.ZIndex = window.ZIndex + 1
	applyCorner(accentStrip, 14)

	local titleLabel =
		conceptLabel(window, "Title", title, UDim2.fromScale(0.05, -0.11), UDim2.fromScale(0.9, 0.14), 58)
	titleLabel.AnchorPoint = Vector2.new(0, 0)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Center
	titleLabel.TextStrokeColor3 = OUTLINE
	titleLabel.TextStrokeTransparency = 0
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)

	styleCloseButton(
		conceptButton(
			window,
			"CloseButton",
			"X",
			STANDARD_CLOSE_POSITION,
			STANDARD_CLOSE_SIZE,
			Color3.fromRGB(216, 24, 32)
		),
		STANDARD_CLOSE_POSITION,
		STANDARD_CLOSE_SIZE,
		window.ZIndex + 3
	)

	local content = conceptPanel(
		window,
		"Content",
		UDim2.fromScale(0.03, 0.06),
		UDim2.fromScale(0.94, 0.88),
		MENU_PANELS.Content or tintTowardWhite(accent, 0.86),
		22,
		2
	)
	content.ClipsDescendants = false
	content:SetAttribute("MenuAccentR", math.floor(accent.R * 255))
	content:SetAttribute("MenuAccentG", math.floor(accent.G * 255))
	content:SetAttribute("MenuAccentB", math.floor(accent.B * 255))
	makeResponsiveWindow(window, content)
	return window, content
end

local function makeCurrencySlot(parent, name, icon, order)
	local slot =
		conceptPanel(parent, name, UDim2.fromOffset(0, 0), UDim2.fromOffset(128, 42), Color3.fromRGB(31, 41, 58), 12, 0)
	slot.LayoutOrder = order
	slot.BackgroundTransparency = 0.08
	local iconLabel = conceptLabel(slot, "Icon", icon, UDim2.fromOffset(8, 0), UDim2.fromOffset(66, 42), 22)
	iconLabel.TextScaled = true
	iconLabel.TextXAlignment = Enum.TextXAlignment.Left
	local iconLimit = iconLabel:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
	iconLimit.MinTextSize = 12
	iconLimit.MaxTextSize = 22
	iconLimit.Parent = iconLabel
	local amount = conceptLabel(slot, "Amount", "0", UDim2.fromOffset(80, 0), UDim2.new(1, -86, 1, 0), 20)
	amount.TextScaled = true
	amount.TextXAlignment = Enum.TextXAlignment.Left
	amount.TextColor3 = Color3.fromRGB(255, 255, 255)
	amount.TextStrokeColor3 = OUTLINE
	amount.TextStrokeTransparency = 0
	local amountLimit = amount:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
	amountLimit.MinTextSize = 12
	amountLimit.MaxTextSize = 20
	amountLimit.Parent = amount
	return slot
end

local function buildCurrencyBar(mainHud)
	local currencyBar = ensureClass(mainHud, "Frame", "CurrencyBar")
	clearChildren(currencyBar)
	currencyBar.AnchorPoint = Vector2.new(0, 0)
	currencyBar.Position = UDim2.new(0, 8, 0.5, 8)
	currencyBar.Size = UDim2.fromOffset(136, 100)
	currencyBar.BackgroundTransparency = 1
	currencyBar.Visible = true

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = currencyBar

	makeCurrencySlot(currencyBar, "GemsFrame", "GEMS", 1)
	makeCurrencySlot(currencyBar, "CoinsFrame", "COINS", 2)
end

local BOTTOM_BUTTON_ICONS = {
	InventoryButton = {
		SourceFile = "assets/ui/upgradeicons/sliced/inventory_size.png",
	},
	MenuButton = {
		Label = "MENU",
		SourceFile = "assets/ui/menu_hamburger.png",
	},
	RankButton = {
		Label = "RANK",
		SourceFile = "assets/ui/rank_badge.png",
	},
	SettingsButton = {
		Label = "SET",
		SourceFile = "assets/ui/settings_gear.png",
	},
	ShopButton = {
		Label = "SHOP",
		SourceFile = "assets/ui/market_shop.png",
	},
	TradeButton = {
		Label = "TRADE",
		SourceFile = "assets/ui/trading_arrows.png",
	},
	WorldsButton = {
		Label = "WORLD",
		SourceFile = "assets/ui/market_shop.png",
	},
}

local function isRenderableImage(image)
	image = tostring(image or "")
	return image:match("^rbxassetid://%d+") ~= nil or image:match("^http") ~= nil
end

local function getExistingBottomButtonImages(bottomButtons)
	local images = {}
	if not bottomButtons then
		return images
	end

	for _, child in ipairs(bottomButtons:GetChildren()) do
		if child:IsA("ImageButton") or child:IsA("ImageLabel") then
			local image = tostring(child.Image or "")
			if isRenderableImage(image) then
				images[child.Name] = image
			end
		end
	end
	return images
end

local function getBottomButtonLabel(name, fallback)
	local spec = BOTTOM_BUTTON_ICONS[name] or {}
	return tostring(spec.Label or fallback or name)
end

local function getBottomButtonImage(name, existingImages)
	local existing = existingImages and existingImages[name]
	if isRenderableImage(existing) then
		return existing
	end

	local spec = BOTTOM_BUTTON_ICONS[name] or {}
	if isRenderableImage(spec.Image) then
		return tostring(spec.Image)
	end
	return ""
end

-- Roblox ImageButtons need uploaded asset IDs to render in game.
-- Local PNG paths are kept as editable metadata for whoever uploads/replaces them in Studio.
local function getBottomButtonSourceFile(name)
	local spec = BOTTOM_BUTTON_ICONS[name] or {}
	return tostring(spec.SourceFile or "")
end

local function applyBottomButtonIcon(btn, name, label, existingImages)
	if not btn or not btn:IsA("ImageButton") then
		return
	end

	local image = getBottomButtonImage(name, existingImages)
	local sourceFile = getBottomButtonSourceFile(name)

	btn.Image = image
	btn.ScaleType = Enum.ScaleType.Fit
	btn.ImageTransparency = image == "" and 1 or 0
	btn:SetAttribute("Label", label)
	btn:SetAttribute("ExpectedIconFile", sourceFile)

	local textLabel = btn:FindFirstChild("Label")
	if textLabel and textLabel:IsA("TextLabel") then
		textLabel.Text = image == "" and getBottomButtonLabel(name, label) or ""
		textLabel.Visible = image == ""
	end
end

local function makeBottomButton(parent, name, label, order, color, existingImages)
	local btn = imageButton(parent, name, UDim2.fromOffset(0, 0), UDim2.fromOffset(68, 68), color)
	btn.LayoutOrder = order
	btn.ZIndex = 5001
	local textLabel = btn:FindFirstChild("Label")
	if not textLabel or not textLabel:IsA("TextLabel") then
		if textLabel then
			textLabel:Destroy()
		end
		textLabel = Instance.new("TextLabel")
		textLabel.Name = "Label"
		textLabel.BackgroundTransparency = 1
		textLabel.Font = Enum.Font.GothamBlack
		textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		textLabel.TextStrokeColor3 = OUTLINE
		textLabel.TextStrokeTransparency = 0
		textLabel.Parent = btn
	end
	textLabel.Text = label
	textLabel.TextSize = 17
	textLabel.TextScaled = true
	textLabel.TextWrapped = true
	textLabel.Size = UDim2.new(1, -8, 1, -8)
	textLabel.Position = UDim2.fromOffset(4, 4)
	textLabel.ZIndex = btn.ZIndex + 1
	applyBottomButtonIcon(btn, name, label, existingImages)
	return btn
end

local function buildBottomButtons(mainHud)
	local bottomButtons = ensureClass(mainHud, "Frame", "BottomButtons")
	local existingImages = getExistingBottomButtonImages(bottomButtons)
	clearChildren(bottomButtons)
	bottomButtons.AnchorPoint = Vector2.new(0.5, 1)
	bottomButtons.Position = UDim2.new(0.5, 0, 1, -24)
	bottomButtons.Size = UDim2.fromOffset(540, 78)
	bottomButtons.BackgroundTransparency = 1
	bottomButtons.Visible = true
	bottomButtons.ZIndex = 5000
	bottomButtons:SetAttribute("ResponsiveHudButtons", true)
	ensureUiScale(bottomButtons, "ResponsiveScale", 1)

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = bottomButtons

	makeBottomButton(bottomButtons, "RankButton", "RANK", 1, Color3.fromRGB(45, 167, 255), existingImages)
	makeBottomButton(bottomButtons, "TradeButton", "TRADE", 2, Color3.fromRGB(45, 167, 255), existingImages)
	makeBottomButton(bottomButtons, "MenuButton", "MENU", 3, Color3.fromRGB(24, 138, 232), existingImages)
	makeBottomButton(bottomButtons, "ShopButton", "SHOP", 4, Color3.fromRGB(45, 167, 255), existingImages)
	makeBottomButton(bottomButtons, "WorldsButton", "WORLD", 5, Color3.fromRGB(45, 167, 255), existingImages)
	makeBottomButton(bottomButtons, "SettingsButton", "SET", 6, Color3.fromRGB(45, 167, 255), existingImages)
end

local function convertExistingBottomButtons(mainHud)
	local bottomButtons = mainHud:FindFirstChild("BottomButtons")
	if not bottomButtons or not bottomButtons:IsA("GuiObject") then
		warn("StudioMenuWindowsBuilder: missing StarterGui.MainHUD.BottomButtons.")
		return
	end

	local legacyInventoryButton = bottomButtons:FindFirstChild("InventoryButton")
	if legacyInventoryButton then
		legacyInventoryButton:Destroy()
	end

	for _, name in ipairs({
		"MenuButton",
		"RankButton",
		"SettingsButton",
		"ShopButton",
		"TradeButton",
		"WorldsButton",
	}) do
		local existing = bottomButtons:FindFirstChild(name)
		if existing and existing:IsA("GuiObject") then
			local converted =
				imageButton(bottomButtons, name, existing.Position, existing.Size, existing.BackgroundColor3)
			converted.LayoutOrder = existing.LayoutOrder
			converted.AnchorPoint = existing.AnchorPoint
			converted.Visible = existing.Visible
			converted.ZIndex = existing.ZIndex
			local existingImages = getExistingBottomButtonImages(bottomButtons)
			applyBottomButtonIcon(converted, name, tostring(existing:GetAttribute("Label") or name), existingImages)
		end
	end
end

local function buildShopTransitionOverlay(mainHud)
	local overlay = ensureClass(mainHud, "Frame", "ShopTransitionOverlay")
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.Position = UDim2.fromScale(0, 0)
	overlay.BackgroundTransparency = 1
	overlay.BorderSizePixel = 0
	overlay.Visible = false
	overlay.Active = false
	overlay.ZIndex = 10000

	local fade = ensureClass(overlay, "Frame", "ShopFade")
	fade.Size = UDim2.fromScale(1, 1)
	fade.Position = UDim2.fromScale(0, 0)
	fade.BackgroundColor3 = Color3.fromRGB(5, 7, 12)
	fade.BackgroundTransparency = 1
	fade.BorderSizePixel = 0
	fade.Visible = false
	fade.Active = false
	fade.ZIndex = 10000
end

local function buildPowerUpToast(mainHud)
	local toast = ensureClass(mainHud, "Frame", "PowerUpToast")
	clearChildren(toast)
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, -90)
	toast.Size = UDim2.fromOffset(420, 76)
	toast.BackgroundColor3 = Color3.fromRGB(24, 29, 42)
	toast.BackgroundTransparency = 0.04
	toast.BorderSizePixel = 0
	toast.Visible = false
	toast.ZIndex = 6800
	toast:SetAttribute("EditablePowerUpToast", true)
	toast:SetAttribute("Purpose", "Wild color and power-up pickup message")
	applyCorner(toast, 18)
	applyStroke(toast, CYAN, 3)

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.Name = "ResponsiveSizeLimit"
	sizeLimit.MinSize = Vector2.new(280, 64)
	sizeLimit.MaxSize = Vector2.new(520, 88)
	sizeLimit.Parent = toast

	local scale = Instance.new("UIScale")
	scale.Name = "ResponsiveScale"
	scale.Scale = 1
	scale.Parent = toast

	local accent = frame(toast, "Accent", UDim2.fromScale(0, 0), UDim2.fromScale(0.025, 1), CYAN)
	accent.BorderSizePixel = 0
	accent.ZIndex = toast.ZIndex + 1

	local icon = frame(toast, "Icon", UDim2.fromOffset(18, 12), UDim2.fromOffset(52, 52), Color3.fromRGB(118, 238, 244))
	icon.ZIndex = toast.ZIndex + 1
	applyCorner(icon, 16)
	applyStroke(icon, OUTLINE, 2)
	local iconText = text(icon, "IconText", "UP", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 18)
	iconText.TextScaled = true
	iconText.TextXAlignment = Enum.TextXAlignment.Center
	iconText.TextColor3 = Color3.fromRGB(255, 255, 255)
	iconText.TextStrokeColor3 = OUTLINE
	iconText.TextStrokeTransparency = 0
	iconText.ZIndex = toast.ZIndex + 2

	local title = text(toast, "Title", "Power Up", UDim2.fromOffset(84, 10), UDim2.new(1, -108, 0, 28), 22)
	title.TextScaled = true
	title.TextStrokeColor3 = OUTLINE
	title.TextStrokeTransparency = 0.15
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.ZIndex = toast.ZIndex + 1
	local titleLimit = Instance.new("UITextSizeConstraint")
	titleLimit.Name = "TitleTextLimit"
	titleLimit.MinTextSize = 14
	titleLimit.MaxTextSize = 22
	titleLimit.Parent = title

	local body = text(toast, "Body", "Active for 45s", UDim2.fromOffset(84, 42), UDim2.new(1, -108, 0, 22), 14)
	body.Font = Enum.Font.GothamBold
	body.TextScaled = true
	body.TextColor3 = Color3.fromRGB(205, 232, 255)
	body.TextStrokeTransparency = 1
	body.ZIndex = toast.ZIndex + 1
	local bodyLimit = Instance.new("UITextSizeConstraint")
	bodyLimit.Name = "BodyTextLimit"
	bodyLimit.MinTextSize = 10
	bodyLimit.MaxTextSize = 15
	bodyLimit.Parent = body
end

local function makeInventoryTab(parent, name, label, order, selected)
	local selectedColor = name == "BrushesTab" and Color3.fromRGB(78, 214, 255) or Color3.fromRGB(28, 134, 255)
	local tab = conceptButton(
		parent,
		name,
		label,
		UDim2.fromOffset(0, 0),
		UDim2.new(1, -22, 0, 76),
		selected and selectedColor or Color3.fromRGB(238, 247, 255)
	)
	tab.LayoutOrder = order
	tab.TextColor3 = selected and Color3.fromRGB(255, 255, 255) or TEXT_DARK
	tab.TextStrokeTransparency = selected and 0 or 0.55
	tab.TextScaled = true
	tab.TextWrapped = true
	local textLimit = tab:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
	textLimit.MinTextSize = 14
	textLimit.MaxTextSize = 24
	textLimit.Parent = tab
	return tab
end

local function makeInventoryCard(parent, name, order)
	local card = conceptButton(
		parent,
		name,
		"",
		UDim2.fromOffset(0, 0),
		UDim2.fromOffset(120, 120),
		MENU_PANELS.Card or Color3.fromRGB(247, 250, 255)
	)
	card.LayoutOrder = order
	card:SetAttribute("InventoryCardSlot", true)
	card.Text = ""
	card.ClipsDescendants = true

	local accentBar = frame(card, "AccentBar", UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.06), CYAN)
	accentBar.BorderSizePixel = 0
	accentBar.ZIndex = card.ZIndex + 1

	local preview = conceptPanel(
		card,
		"Preview",
		UDim2.fromScale(0.12, 0.1),
		UDim2.fromScale(0.76, 0.58),
		Color3.fromRGB(236, 245, 255),
		12,
		0
	)
	local viewport = ensureClass(preview, "ViewportFrame", "PreviewViewport")
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundTransparency = 1
	viewport.Position = UDim2.fromScale(0, 0)
	conceptLabel(
		preview,
		"IconText",
		"IMG",
		UDim2.fromScale(0, 0),
		UDim2.fromScale(1, 1),
		18,
		Enum.TextXAlignment.Center
	)

	local itemName = conceptLabel(
		card,
		"ItemName",
		"",
		UDim2.fromScale(0.08, 0.7),
		UDim2.fromScale(0.84, 0.15),
		14,
		Enum.TextXAlignment.Center
	)
	itemName.TextYAlignment = Enum.TextYAlignment.Center
	itemName.TextScaled = true
	local nameLimit = itemName:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
	nameLimit.MinTextSize = 10
	nameLimit.MaxTextSize = 15
	nameLimit.Parent = itemName
	local meta = conceptLabel(
		card,
		"ItemMeta",
		"",
		UDim2.fromScale(0.08, 0.84),
		UDim2.fromScale(0.84, 0.13),
		12,
		Enum.TextXAlignment.Center
	)
	meta.TextColor3 = MUTED
	meta.TextScaled = true
	local metaLimit = meta:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
	metaLimit.MinTextSize = 9
	metaLimit.MaxTextSize = 13
	metaLimit.Parent = meta
	return card
end

local function buildInventoryWindow(modalWindows)
	local _, content = conceptWindow(modalWindows, "InventoryWindow", "INVENTORY")

	local tabs = conceptPanel(
		content,
		"Tabs",
		UDim2.fromScale(0.02, 0.05),
		UDim2.fromScale(0.16, 0.88),
		Color3.fromRGB(232, 244, 255),
		16,
		2
	)
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Vertical
	tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	tabLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	tabLayout.Padding = UDim.new(0, 14)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabs
	makeInventoryTab(tabs, "ColorsTab", "COLORS", 1, true)
	makeInventoryTab(tabs, "BrushesTab", "GEAR", 2, false)
	makeInventoryTab(tabs, "PotionsTab", "BOOSTS", 3, false)
	makeInventoryTab(tabs, "ItemsTab", "ITEMS", 4, false)

	local search =
		textBox(content, "SearchBox", "Search inventory...", UDim2.fromScale(0.22, 0.05), UDim2.fromScale(0.39, 0.08))
	search.TextSize = 20
	search.BackgroundColor3 = MENU_PANELS.Search or Color3.fromRGB(238, 248, 255)
	applyStroke(search, Color3.fromRGB(126, 207, 255), 2)
	conceptButton(
		content,
		"SortButton",
		"Newest",
		UDim2.fromScale(0.64, 0.05),
		UDim2.fromScale(0.14, 0.08),
		Color3.fromRGB(232, 244, 255)
	).TextColor3 =
		TEXT_DARK

	local grid = ensureClass(content, "ScrollingFrame", "GridPanel")
	grid.Position = UDim2.fromScale(0.21, 0.17)
	grid.Size = UDim2.fromScale(0.57, 0.7)
	grid.BackgroundColor3 = Color3.fromRGB(239, 247, 255)
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 8
	grid.CanvasSize = UDim2.fromScale(0, 0)
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	applyCorner(grid, 16)
	applyStroke(grid, Color3.fromRGB(215, 225, 240), 2)

	clearChildren(grid)
	applyCorner(grid, 16)
	applyStroke(grid, Color3.fromRGB(215, 225, 240), 2)
	local gridPadding = Instance.new("UIPadding")
	gridPadding.Name = "GridPadding"
	gridPadding.PaddingTop = UDim.new(0, 14)
	gridPadding.PaddingBottom = UDim.new(0, 56)
	gridPadding.PaddingLeft = UDim.new(0, 14)
	gridPadding.PaddingRight = UDim.new(0, 14)
	gridPadding.Parent = grid
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.Name = "ItemGridLayout"
	gridLayout.CellSize = UDim2.fromOffset(120, 120)
	gridLayout.CellPadding = UDim2.fromOffset(12, 12)
	gridLayout.FillDirection = Enum.FillDirection.Horizontal
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid
	local template = makeInventoryCard(grid, "ItemCardTemplate", 0)
	template.Visible = false
	for index = 1, INVENTORY_CARD_POOL_SIZE do
		local slot = makeInventoryCard(grid, "PreviewSlot" .. tostring(index), index)
		slot.Visible = false
	end
	local emptyText = conceptLabel(
		content,
		"EmptyText",
		"No items yet.",
		UDim2.fromScale(0.21, 0.44),
		UDim2.fromScale(0.57, 0.08),
		20,
		Enum.TextXAlignment.Center
	)
	emptyText.Visible = false
	local footer = conceptPanel(
		content,
		"Footer",
		UDim2.fromScale(0.23, 0.88),
		UDim2.fromScale(0.53, 0.055),
		Color3.fromRGB(239, 246, 255),
		12,
		0
	)
	conceptLabel(
		footer,
		"CapacityText",
		"Colors: 0 / 75",
		UDim2.fromScale(0, 0),
		UDim2.fromScale(1, 1),
		14,
		Enum.TextXAlignment.Center
	)

	local details = ensureClass(content, "ScrollingFrame", "DetailsPanel")
	details.Position = UDim2.fromScale(0.8, 0.05)
	details.Size = UDim2.fromScale(0.18, 0.82)
	details.BackgroundColor3 = Color3.fromRGB(232, 244, 255)
	details.BorderSizePixel = 0
	details.ScrollBarThickness = 8
	details.ScrollBarImageColor3 = MUTED
	details.ScrollingDirection = Enum.ScrollingDirection.Y
	details.ScrollingEnabled = true
	details.CanvasSize = UDim2.fromScale(0, 1.15)
	details.AutomaticCanvasSize = Enum.AutomaticSize.Y
	applyCorner(details, 18)
	applyStroke(details, OUTLINE, 2)
	conceptLabel(
		details,
		"DetailsTitle",
		"ITEM DETAILS",
		UDim2.fromScale(0, 0.02),
		UDim2.fromScale(1, 0.08),
		18,
		Enum.TextXAlignment.Center
	)
	local bigPreview = conceptPanel(
		details,
		"BigPreview",
		UDim2.fromScale(0.18, 0.12),
		UDim2.fromScale(0.64, 0.26),
		Color3.fromRGB(236, 245, 255),
		14,
		0
	)
	local bigViewport = ensureClass(bigPreview, "ViewportFrame", "PreviewViewport")
	bigViewport.Size = UDim2.fromScale(1, 1)
	bigViewport.BackgroundTransparency = 1
	conceptLabel(
		bigPreview,
		"IconText",
		"IMG",
		UDim2.fromScale(0, 0),
		UDim2.fromScale(1, 1),
		22,
		Enum.TextXAlignment.Center
	)
	conceptLabel(
		details,
		"ItemName",
		"Select an Item",
		UDim2.fromScale(0.08, 0.4),
		UDim2.fromScale(0.84, 0.08),
		22,
		Enum.TextXAlignment.Center
	)
	conceptLabel(
		details,
		"RarityLabel",
		"",
		UDim2.fromScale(0.08, 0.49),
		UDim2.fromScale(0.84, 0.06),
		16,
		Enum.TextXAlignment.Center
	).TextColor3 =
		Color3.fromRGB(31, 122, 226)
	conceptLabel(
		details,
		"SelectedDescription",
		"Choose a card to see details.",
		UDim2.fromScale(0.08, 0.57),
		UDim2.fromScale(0.84, 0.1),
		14,
		Enum.TextXAlignment.Center
	)
	local statsBox = conceptPanel(
		details,
		"StatsBox",
		UDim2.fromScale(0.08, 0.66),
		UDim2.fromScale(0.84, 0.18),
		Color3.fromRGB(247, 252, 255),
		12,
		1
	)
	conceptLabel(
		statsBox,
		"StatsText",
		"",
		UDim2.fromScale(0.06, 0.05),
		UDim2.fromScale(0.88, 0.9),
		12,
		Enum.TextXAlignment.Center
	)
	local statsText = statsBox:FindFirstChild("StatsText")
	if statsText and statsText:IsA("TextLabel") then
		statsText.TextScaled = true
		statsText.TextYAlignment = Enum.TextYAlignment.Top
		local limit = statsText:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
		limit.MinTextSize = 8
		limit.MaxTextSize = 13
		limit.Parent = statsText
	end
	conceptButton(
		details,
		"EquipButton",
		"EQUIP",
		UDim2.fromScale(0.08, 0.86),
		UDim2.fromScale(0.84, 0.08),
		Color3.fromRGB(73, 218, 57)
	)
	conceptButton(
		details,
		"LockButton",
		"LOCK",
		UDim2.fromScale(0.08, 0.95),
		UDim2.fromScale(0.4, 0.07),
		Color3.fromRGB(30, 150, 255)
	)
	conceptButton(
		details,
		"DeleteButton",
		"DELETE",
		UDim2.fromScale(0.52, 0.95),
		UDim2.fromScale(0.4, 0.07),
		Color3.fromRGB(236, 43, 38)
	)
end

local function markIndexEditable(object, role)
	if object then
		object:SetAttribute("EditableIndexUI", true)
		if role and role ~= "" then
			object:SetAttribute("IndexUIRole", role)
		end
	end
	return object
end

local function makeIndexCategoryButton(parent, name, textValue, order, color)
	local tab = conceptButton(parent, name, textValue, UDim2.fromOffset(0, 0), UDim2.new(1, -16, 0, 58), color)
	tab.LayoutOrder = order
	tab.TextSize = 25
	tab.TextColor3 = order == 1 and Color3.fromRGB(255, 255, 255) or TEXT_DARK
	tab:SetAttribute("IndexCategory", string.gsub(name, "Tab$", ""))
	markIndexEditable(tab, "CategoryTab")
	return tab
end

local function makeIndexTopFilter(parent, name, textValue, order)
	local filter = conceptButton(
		parent,
		name,
		textValue,
		UDim2.fromOffset(0, 0),
		UDim2.fromOffset(92, 38),
		order == 1 and Color3.fromRGB(80, 222, 236) or Color3.fromRGB(255, 255, 255)
	)
	filter.LayoutOrder = order
	filter.TextSize = 16
	filter.TextColor3 = order == 1 and Color3.fromRGB(255, 255, 255) or TEXT_DARK
	filter:SetAttribute("IndexFilter", string.gsub(name, "Filter$", ""))
	markIndexEditable(filter, "TopFilter")
	return filter
end

local function makeIndexCard(parent, name, order)
	local card = conceptButton(
		parent,
		name,
		"",
		UDim2.fromOffset(0, 0),
		UDim2.fromOffset(128, 128),
		Color3.fromRGB(255, 255, 255)
	)
	card.LayoutOrder = order
	card.Text = ""
	card.ClipsDescendants = true
	card:SetAttribute("IndexCardSlot", true)
	markIndexEditable(card, "GridCard")

	local shadow = frame(card, "IconShadow", UDim2.fromScale(0.18, 0.64), UDim2.fromScale(0.64, 0.14), OUTLINE)
	shadow.BackgroundTransparency = 0.82
	shadow.ZIndex = card.ZIndex + 1
	applyCorner(shadow, 999)
	markIndexEditable(shadow, "IconShadow")

	local icon = conceptPanel(
		card,
		"IconFrame",
		UDim2.fromScale(0.16, 0.08),
		UDim2.fromScale(0.68, 0.58),
		Color3.fromRGB(118, 219, 255),
		14,
		3
	)
	icon.ZIndex = card.ZIndex + 2
	markIndexEditable(icon, "IconFrame")

	local iconText = conceptLabel(
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
	markIndexEditable(iconText, "IconText")

	local lockOverlay = conceptPanel(
		icon,
		"LockOverlay",
		UDim2.fromScale(0, 0),
		UDim2.fromScale(1, 1),
		Color3.fromRGB(32, 37, 48),
		14,
		0
	)
	lockOverlay.BackgroundTransparency = 0.32
	lockOverlay.ZIndex = icon.ZIndex + 2
	markIndexEditable(lockOverlay, "LockOverlay")
	local lockText = conceptLabel(
		lockOverlay,
		"LockText",
		"?",
		UDim2.fromScale(0, 0),
		UDim2.fromScale(1, 1),
		32,
		Enum.TextXAlignment.Center
	)
	lockText.TextYAlignment = Enum.TextYAlignment.Center
	lockText.TextColor3 = Color3.fromRGB(255, 255, 255)
	lockText.ZIndex = lockOverlay.ZIndex + 1
	markIndexEditable(lockText, "LockText")

	local nameLabel = conceptLabel(
		card,
		"NameLabel",
		"???",
		UDim2.fromScale(0.08, 0.69),
		UDim2.fromScale(0.84, 0.14),
		15,
		Enum.TextXAlignment.Center
	)
	nameLabel.TextScaled = true
	nameLabel.TextYAlignment = Enum.TextYAlignment.Center
	local nameLimit = nameLabel:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
	nameLimit.MinTextSize = 9
	nameLimit.MaxTextSize = 15
	nameLimit.Parent = nameLabel
	markIndexEditable(nameLabel, "NameLabel")

	local status = conceptLabel(
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
	markIndexEditable(status, "StatusLabel")

	local badge = conceptPanel(
		card,
		"CollectedBadge",
		UDim2.fromScale(0.56, 0.07),
		UDim2.fromScale(0.34, 0.16),
		Color3.fromRGB(93, 231, 88),
		10,
		2
	)
	badge.ZIndex = card.ZIndex + 4
	markIndexEditable(badge, "CollectedBadge")
	local badgeText = conceptLabel(
		badge,
		"BadgeText",
		"OWNED",
		UDim2.fromScale(0, 0),
		UDim2.fromScale(1, 1),
		10,
		Enum.TextXAlignment.Center
	)
	badgeText.TextYAlignment = Enum.TextYAlignment.Center
	badgeText.TextColor3 = Color3.fromRGB(255, 255, 255)
	badgeText.TextStrokeColor3 = OUTLINE
	badgeText.TextStrokeTransparency = 0.25
	badgeText.ZIndex = badge.ZIndex + 1
	markIndexEditable(badgeText, "BadgeText")

	return card
end

local function buildIndexWindow(modalWindows)
	local window, content = conceptWindow(modalWindows, "IndexWindow", "COLLECTION!")
	window:SetAttribute("EditableIndexUI", true)
	window:SetAttribute("OpenedByIndexStation", true)
	window:SetAttribute("DesktopWidthScale", 0.76)
	window:SetAttribute("DesktopHeightScale", 0.72)
	content.BackgroundColor3 = Color3.fromRGB(252, 254, 255)
	content.ClipsDescendants = false
	markIndexEditable(content, "Content")

	local title = window:FindFirstChild("Title")
	if title and title:IsA("TextLabel") then
		title.Text = "COLLECTION!"
		title.TextSize = 50
		markIndexEditable(title, "Title")
	end

	local badge = conceptPanel(
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
	markIndexEditable(badge, "CollectionBadge")
	local badgeIcon = conceptLabel(
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
	markIndexEditable(badgeIcon, "BadgeIcon")

	local sidebar = conceptPanel(
		content,
		"CategoryTabs",
		UDim2.fromScale(0.025, 0.12),
		UDim2.fromScale(0.24, 0.64),
		Color3.fromRGB(247, 250, 255),
		16,
		2
	)
	sidebar.BackgroundTransparency = 1
	markIndexEditable(sidebar, "CategoryTabs")
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.Name = "CategoryTabLayout"
	tabLayout.FillDirection = Enum.FillDirection.Vertical
	tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	tabLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	tabLayout.Padding = UDim.new(0, 10)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = sidebar
	makeIndexCategoryButton(sidebar, "PetsTab", "Pets", 1, Color3.fromRGB(91, 225, 242))
	makeIndexCategoryButton(sidebar, "GearTab", "Gear", 2, Color3.fromRGB(232, 237, 248))
	makeIndexCategoryButton(sidebar, "PlacesTab", "Places", 3, Color3.fromRGB(232, 237, 248))

	local legacyRewardButton = content:FindFirstChild("RewardsButton")
	if legacyRewardButton and legacyRewardButton:IsA("GuiObject") then
		legacyRewardButton.Visible = false
		legacyRewardButton:SetAttribute("IndexCategory", nil)
	end

	local topFilters = conceptPanel(
		content,
		"TopFilters",
		UDim2.fromScale(0.34, 0.035),
		UDim2.fromScale(0.32, 0.075),
		Color3.fromRGB(255, 255, 255),
		20,
		3
	)
	topFilters.ClipsDescendants = true
	markIndexEditable(topFilters, "TopFilters")
	local filterLayout = Instance.new("UIListLayout")
	filterLayout.Name = "FilterLayout"
	filterLayout.FillDirection = Enum.FillDirection.Horizontal
	filterLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	filterLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	filterLayout.Padding = UDim.new(0, 8)
	filterLayout.SortOrder = Enum.SortOrder.LayoutOrder
	filterLayout.Parent = topFilters
	makeIndexTopFilter(topFilters, "AllFilter", "ALL", 1)
	makeIndexTopFilter(topFilters, "FoundFilter", "OWNED", 2)
	makeIndexTopFilter(topFilters, "MissingFilter", "???", 3)

	local search = textBox(content, "SearchBox", "Search", UDim2.fromScale(0.69, 0.035), UDim2.fromScale(0.25, 0.075))
	search.TextSize = 22
	search.TextXAlignment = Enum.TextXAlignment.Center
	search.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	applyStroke(search, OUTLINE, 3)
	markIndexEditable(search, "SearchBox")

	local grid = ensureClass(content, "ScrollingFrame", "GridPanel")
	clearChildren(grid)
	grid.Position = UDim2.fromScale(0.29, 0.14)
	grid.Size = UDim2.fromScale(0.67, 0.7)
	grid.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	grid.BackgroundTransparency = 0
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 7
	grid.ScrollBarImageColor3 = Color3.fromRGB(110, 120, 145)
	grid.ScrollingDirection = Enum.ScrollingDirection.Y
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.fromOffset(0, 0)
	grid.ClipsDescendants = true
	applyCorner(grid, 18)
	applyStroke(grid, Color3.fromRGB(218, 224, 236), 0)
	markIndexEditable(grid, "GridPanel")
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
	gridLayout.FillDirection = Enum.FillDirection.Horizontal
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid
	local template = makeIndexCard(grid, "IndexCardTemplate", 0)
	template.Visible = false
	for index = 1, 48 do
		local slot = makeIndexCard(grid, "IndexSlot" .. tostring(index), index)
		slot.Visible = false
	end

	local emptyText = conceptLabel(
		content,
		"EmptyText",
		"Nothing found.",
		UDim2.fromScale(0.32, 0.43),
		UDim2.fromScale(0.58, 0.08),
		24,
		Enum.TextXAlignment.Center
	)
	emptyText.Visible = false
	markIndexEditable(emptyText, "EmptyText")

	local footer = conceptPanel(
		content,
		"PageControls",
		UDim2.fromScale(0.47, 0.86),
		UDim2.fromScale(0.22, 0.08),
		Color3.fromRGB(255, 255, 255),
		18,
		3
	)
	markIndexEditable(footer, "PageControls")
	local pageBack = conceptButton(
		footer,
		"PageBack",
		"<",
		UDim2.fromScale(0.03, 0.12),
		UDim2.fromScale(0.22, 0.76),
		Color3.fromRGB(232, 237, 248)
	)
	pageBack.TextColor3 = TEXT_DARK
	pageBack.TextSize = 26
	markIndexEditable(pageBack, "PageBack")
	local pageLabel = conceptLabel(
		footer,
		"PageLabel",
		"1",
		UDim2.fromScale(0.28, 0),
		UDim2.fromScale(0.44, 1),
		24,
		Enum.TextXAlignment.Center
	)
	pageLabel.TextYAlignment = Enum.TextYAlignment.Center
	markIndexEditable(pageLabel, "PageLabel")
	local pageNext = conceptButton(
		footer,
		"PageNext",
		">",
		UDim2.fromScale(0.75, 0.12),
		UDim2.fromScale(0.22, 0.76),
		Color3.fromRGB(232, 237, 248)
	)
	pageNext.TextColor3 = TEXT_DARK
	pageNext.TextSize = 26
	markIndexEditable(pageNext, "PageNext")

	local counter = conceptLabel(
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
	counter.TextYAlignment = Enum.TextYAlignment.Center
	markIndexEditable(counter, "CollectedCounter")
	local counterLabel = conceptLabel(
		content,
		"CollectedLabel",
		"Collected",
		UDim2.fromScale(0.76, 0.795),
		UDim2.fromScale(0.2, 0.045),
		21,
		Enum.TextXAlignment.Center
	)
	counterLabel.TextYAlignment = Enum.TextYAlignment.Center
	markIndexEditable(counterLabel, "CollectedLabel")
end

local function makeSettingsRow(parent, name, label, description, order, defaultText)
	local rowColors = {
		Color3.fromRGB(232, 255, 241),
		Color3.fromRGB(232, 247, 255),
		Color3.fromRGB(246, 239, 255),
		Color3.fromRGB(255, 242, 232),
	}
	local row = conceptPanel(
		parent,
		name,
		UDim2.fromOffset(0, 0),
		UDim2.new(1, -12, 0, 64),
		rowColors[((order - 1) % #rowColors) + 1],
		12,
		1
	)
	row.LayoutOrder = order
	row.ClipsDescendants = true
	conceptLabel(row, "Name", label, UDim2.fromScale(0.04, 0.12), UDim2.fromScale(0.58, 0.34), 18)
	local desc =
		conceptLabel(row, "Description", description, UDim2.fromScale(0.04, 0.5), UDim2.fromScale(0.58, 0.34), 12)
	desc.TextColor3 = MUTED
	local status = conceptLabel(
		row,
		"Status",
		defaultText or "ON",
		UDim2.fromScale(0.66, 0.2),
		UDim2.fromScale(0.08, 0.6),
		18,
		Enum.TextXAlignment.Center
	)
	status.Visible = false
	local toggle = conceptButton(
		row,
		"ToggleButton",
		defaultText or "ON",
		UDim2.fromScale(0.75, 0.18),
		UDim2.fromScale(0.21, 0.64),
		Color3.fromRGB(73, 218, 57)
	)
	toggle.TextSize = 16
	return row
end

local function buildSettingsWindow(modalWindows)
	local window, content = conceptWindow(modalWindows, "SettingsWindow", "SETTINGS")
	window.Size = STANDARD_WINDOW_SIZE
	content.ClipsDescendants = true

	local rows = conceptScrollingPanel(
		content,
		"SettingsRows",
		UDim2.fromScale(0.05, 0.08),
		UDim2.fromScale(0.9, 0.84),
		Color3.fromRGB(250, 252, 255),
		16,
		0
	)
	rows.BackgroundTransparency = 1
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Vertical
	rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rowLayout.Padding = UDim.new(0, 10)
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Parent = rows
	makeSettingsRow(rows, "MusicCard", "Music", "Background music.", 1, "ON")
	makeSettingsRow(rows, "SFXCard", "Sound Effects", "Sound feedback.", 2, "ON")
	makeSettingsRow(rows, "DamageNumbersCard", "Damage Numbers", "Popup feedback while collecting.", 3, "ON")
	makeSettingsRow(rows, "TradeRequestsCard", "Trade Requests", "Allow incoming trade requests.", 4, "ON")
	makeSettingsRow(rows, "HidePetsCard", "Hide Pets", "Hide pet visuals on your client.", 5, "OFF")
	makeSettingsRow(rows, "AutoHatchCard", "Auto Hatch", "Auto hatch preference.", 6, "OFF")
	makeSettingsRow(rows, "CameraShakeCard", "Camera Shake", "Camera feedback while playing.", 7, "ON")
	makeSettingsRow(rows, "LowDetailCard", "Low Detail FX", "Reduce visual effects.", 8, "OFF")
end

local function makeTradeSlot(parent, name, order, role)
	local slot = conceptButton(
		parent,
		name,
		"",
		UDim2.fromOffset(0, 0),
		UDim2.fromOffset(118, 86),
		Color3.fromRGB(255, 255, 255)
	)
	slot.LayoutOrder = order
	slot:SetAttribute("TradeSlotRole", role)
	slot.Text = ""
	conceptLabel(
		slot,
		"Name",
		"",
		UDim2.fromScale(0.08, 0.16),
		UDim2.fromScale(0.84, 0.36),
		14,
		Enum.TextXAlignment.Center
	)
	conceptLabel(
		slot,
		"Meta",
		"",
		UDim2.fromScale(0.08, 0.5),
		UDim2.fromScale(0.84, 0.2),
		11,
		Enum.TextXAlignment.Center
	).TextColor3 =
		MUTED
	if role == "MyOffer" then
		conceptButton(
			slot,
			"AddButton",
			"ADD",
			UDim2.fromScale(0.16, 0.72),
			UDim2.fromScale(0.68, 0.22),
			Color3.fromRGB(73, 218, 57)
		).TextSize =
			12
	end
	return slot
end

local function makeTradeList(parent, name, listName, title, position, size)
	local panel = conceptPanel(parent, name, position, size, Color3.fromRGB(250, 252, 255), 16, 2)
	panel.ClipsDescendants = true
	conceptLabel(
		panel,
		"Title",
		title,
		UDim2.fromScale(0.04, 0.025),
		UDim2.fromScale(0.92, 0.075),
		18,
		Enum.TextXAlignment.Center
	)
	local list = conceptScrollingPanel(
		panel,
		listName,
		UDim2.fromScale(0.05, 0.12),
		UDim2.fromScale(0.9, 0.68),
		Color3.fromRGB(255, 255, 255),
		14,
		1
	)
	list.BackgroundTransparency = 0
	return panel, list
end

local function buildTradeWindow(modalWindows)
	local window, content = conceptWindow(modalWindows, "TradeWindow", "TRADING")
	window.Size = STANDARD_WINDOW_SIZE
	window.Position = STANDARD_WINDOW_POSITION
	content.ClipsDescendants = true
	conceptLabel(
		content,
		"Status",
		"Choose a player to trade.",
		UDim2.fromScale(0.06, 0.025),
		UDim2.fromScale(0.88, 0.06),
		18,
		Enum.TextXAlignment.Center
	).TextColor3 =
		Color3.fromRGB(31, 122, 226)

	local playersPanel = conceptPanel(
		content,
		"PlayersPanel",
		UDim2.fromScale(0.04, 0.12),
		UDim2.fromScale(0.22, 0.66),
		Color3.fromRGB(250, 252, 255),
		16,
		2
	)
	playersPanel.ClipsDescendants = true
	conceptLabel(playersPanel, "Title", "PLAYERS", UDim2.fromScale(0.07, 0.03), UDim2.fromScale(0.86, 0.08), 16)
	local playersList = conceptScrollingPanel(
		playersPanel,
		"PlayersList",
		UDim2.fromScale(0.07, 0.13),
		UDim2.fromScale(0.86, 0.78),
		Color3.fromRGB(255, 255, 255),
		12,
		1
	)
	local playerLayout = Instance.new("UIListLayout")
	playerLayout.Padding = UDim.new(0, 8)
	playerLayout.SortOrder = Enum.SortOrder.LayoutOrder
	playerLayout.Parent = playersList
	for index = 1, 4 do
		local row = conceptButton(
			playersList,
			"PlayerSlot" .. tostring(index),
			"",
			UDim2.fromOffset(0, 0),
			UDim2.new(1, -8, 0, 44),
			Color3.fromRGB(245, 249, 255)
		)
		row.LayoutOrder = index
		row:SetAttribute("TradeSlotRole", "Player")
		conceptLabel(row, "Name", "", UDim2.fromScale(0.05, 0.1), UDim2.fromScale(0.56, 0.8), 12)
		conceptButton(
			row,
			"TradeButton",
			"TRADE",
			UDim2.fromScale(0.62, 0.18),
			UDim2.fromScale(0.34, 0.64),
			Color3.fromRGB(73, 218, 57)
		).TextSize =
			11
	end

	local colorsList = conceptScrollingPanel(
		content,
		"ColorsList",
		UDim2.fromScale(0, 1.1),
		UDim2.fromOffset(1, 1),
		Color3.fromRGB(255, 255, 255),
		12,
		1
	)
	colorsList.Visible = false
	local colorLayout = Instance.new("UIListLayout")
	colorLayout.Padding = UDim.new(0, 8)
	colorLayout.SortOrder = Enum.SortOrder.LayoutOrder
	colorLayout.Parent = colorsList
	for index = 1, 6 do
		local row = conceptButton(
			colorsList,
			"ColorSlot" .. tostring(index),
			"",
			UDim2.fromOffset(0, 0),
			UDim2.new(1, -8, 0, 44),
			Color3.fromRGB(245, 249, 255)
		)
		row.LayoutOrder = index
		row:SetAttribute("TradeSlotRole", "Color")
		conceptLabel(row, "Name", "", UDim2.fromScale(0.05, 0.08), UDim2.fromScale(0.54, 0.5), 12)
		conceptLabel(row, "Meta", "", UDim2.fromScale(0.05, 0.55), UDim2.fromScale(0.54, 0.34), 10).TextColor3 = MUTED
		conceptButton(
			row,
			"AddButton",
			"ADD",
			UDim2.fromScale(0.62, 0.18),
			UDim2.fromScale(0.34, 0.64),
			Color3.fromRGB(73, 218, 57)
		).TextSize =
			11
	end

	local yourPanel, myOfferList = makeTradeList(
		content,
		"YourOfferPanel",
		"MyOfferList",
		"YOUR OFFER",
		UDim2.fromScale(0.3, 0.12),
		UDim2.fromScale(0.28, 0.66)
	)
	local myGrid = Instance.new("UIGridLayout")
	myGrid.CellSize = UDim2.fromScale(0.46, 0.29)
	myGrid.CellPadding = UDim2.fromScale(0.04, 0.04)
	myGrid.SortOrder = Enum.SortOrder.LayoutOrder
	myGrid.Parent = myOfferList
	for index = 1, 6 do
		makeTradeSlot(myOfferList, "MyOfferSlot" .. tostring(index), index, "MyOffer")
	end
	conceptLabel(
		yourPanel,
		"MyOfferGems",
		"Gems: 0",
		UDim2.fromScale(0.08, 0.83),
		UDim2.fromScale(0.84, 0.08),
		18,
		Enum.TextXAlignment.Center
	)

	local theirPanel, theirOfferList = makeTradeList(
		content,
		"TheirOfferPanel",
		"TheirOfferList",
		"THEIR OFFER",
		UDim2.fromScale(0.68, 0.12),
		UDim2.fromScale(0.28, 0.66)
	)
	local theirGrid = Instance.new("UIGridLayout")
	theirGrid.CellSize = UDim2.fromScale(0.46, 0.29)
	theirGrid.CellPadding = UDim2.fromScale(0.04, 0.04)
	theirGrid.SortOrder = Enum.SortOrder.LayoutOrder
	theirGrid.Parent = theirOfferList
	for index = 1, 6 do
		makeTradeSlot(theirOfferList, "TheirOfferSlot" .. tostring(index), index, "TheirOffer")
	end
	conceptLabel(
		theirPanel,
		"TheirOfferGems",
		"Gems: 0",
		UDim2.fromScale(0.08, 0.83),
		UDim2.fromScale(0.84, 0.08),
		18,
		Enum.TextXAlignment.Center
	)

	conceptLabel(
		content,
		"SwapIcon",
		"FOR",
		UDim2.fromScale(0.59, 0.38),
		UDim2.fromScale(0.08, 0.08),
		18,
		Enum.TextXAlignment.Center
	).TextColor3 =
		Color3.fromRGB(31, 122, 226)

	local footer = conceptPanel(
		content,
		"TradeFooter",
		UDim2.fromScale(0.04, 0.81),
		UDim2.fromScale(0.92, 0.14),
		Color3.fromRGB(255, 255, 255),
		14,
		1
	)
	footer.BackgroundTransparency = 0.1
	conceptButton(
		footer,
		"AcceptButton",
		"ACCEPT",
		UDim2.fromScale(0.56, 0.18),
		UDim2.fromScale(0.18, 0.64),
		Color3.fromRGB(73, 218, 57)
	)
	conceptButton(
		footer,
		"CancelButton",
		"CANCEL",
		UDim2.fromScale(0.76, 0.18),
		UDim2.fromScale(0.18, 0.64),
		Color3.fromRGB(236, 43, 38)
	)
	local gemBox = textBox(footer, "GemBox", "Gems", UDim2.fromScale(0.19, 0.18), UDim2.fromScale(0.14, 0.64))
	gemBox.TextSize = 16
	conceptButton(
		footer,
		"SetGemsButton",
		"SET",
		UDim2.fromScale(0.34, 0.18),
		UDim2.fromScale(0.08, 0.64),
		Color3.fromRGB(80, 214, 224)
	).TextSize =
		12
	conceptLabel(
		footer,
		"GemsLabel",
		"Gems: 0",
		UDim2.fromScale(0.04, 0.2),
		UDim2.fromScale(0.14, 0.6),
		15,
		Enum.TextXAlignment.Center
	)
	conceptLabel(
		footer,
		"MyReady",
		"NOT READY",
		UDim2.fromScale(0.44, 0.16),
		UDim2.fromScale(0.1, 0.3),
		13,
		Enum.TextXAlignment.Center
	)
	conceptLabel(
		footer,
		"TheirReady",
		"NOT READY",
		UDim2.fromScale(0.44, 0.54),
		UDim2.fromScale(0.1, 0.3),
		13,
		Enum.TextXAlignment.Center
	)
end

local function buildRankWindow(modalWindows)
	local _, content = conceptWindow(modalWindows, "RankWindow", "RANKS")
	conceptLabel(
		content,
		"CurrentRankHeader",
		"CURRENT RANK",
		UDim2.fromScale(0.28, 0.02),
		UDim2.fromScale(0.44, 0.08),
		24,
		Enum.TextXAlignment.Center
	).TextColor3 =
		Color3.fromRGB(90, 140, 210)
	local badge = conceptPanel(
		content,
		"RankBadge",
		UDim2.fromScale(0.15, 0.17),
		UDim2.fromScale(0.22, 0.26),
		Color3.fromRGB(239, 248, 255),
		22,
		4
	)
	conceptLabel(
		badge,
		"RankIconText",
		"I",
		UDim2.fromScale(0, 0),
		UDim2.fromScale(1, 1),
		64,
		Enum.TextXAlignment.Center
	).TextColor3 =
		Color3.fromRGB(28, 134, 255)
	conceptLabel(
		content,
		"RankName",
		"RANK I",
		UDim2.fromScale(0.43, 0.2),
		UDim2.fromScale(0.4, 0.16),
		54,
		Enum.TextXAlignment.Center
	)

	conceptLabel(
		content,
		"ProgressTitle",
		"Progress to Next Rank",
		UDim2.fromScale(0.2, 0.48),
		UDim2.fromScale(0.6, 0.07),
		22,
		Enum.TextXAlignment.Center
	)
	local bar = conceptPanel(
		content,
		"ProgressBar",
		UDim2.fromScale(0.15, 0.57),
		UDim2.fromScale(0.7, 0.055),
		Color3.fromRGB(255, 255, 255),
		18,
		2
	)
	local fill = conceptPanel(
		bar,
		"ProgressFill",
		UDim2.fromScale(0, 0),
		UDim2.fromScale(0.68, 1),
		Color3.fromRGB(24, 164, 245),
		18,
		0
	)
	fill.BorderSizePixel = 0
	conceptLabel(content, "ProgressLabel", "0 / 2,500 XP", UDim2.fromScale(0.15, 0.63), UDim2.fromScale(0.3, 0.06), 20)
	conceptLabel(
		content,
		"ProgressPercent",
		"0%",
		UDim2.fromScale(0.7, 0.63),
		UDim2.fromScale(0.15, 0.06),
		24,
		Enum.TextXAlignment.Right
	).TextColor3 =
		Color3.fromRGB(31, 122, 226)

	conceptLabel(
		content,
		"PerksTitle",
		"Unlocked Perks",
		UDim2.fromScale(0.2, 0.74),
		UDim2.fromScale(0.6, 0.06),
		22,
		Enum.TextXAlignment.Center
	)
	local perks = ensureClass(content, "ScrollingFrame", "Perks")
	perks.Position = UDim2.fromScale(0.18, 0.82)
	perks.Size = UDim2.fromScale(0.64, 0.12)
	perks.BackgroundColor3 = Color3.fromRGB(248, 252, 255)
	perks.BorderSizePixel = 0
	perks.ScrollBarThickness = 4
	perks.ScrollBarImageColor3 = MUTED
	perks.ScrollingDirection = Enum.ScrollingDirection.X
	perks.AutomaticCanvasSize = Enum.AutomaticSize.X
	perks.CanvasSize = UDim2.fromOffset(0, 0)
	perks.ClipsDescendants = true
	applyCorner(perks, 16)
	applyStroke(perks, OUTLINE, 0)
	perks.BackgroundTransparency = 1
	ensurePadding(perks, "ResponsivePadding", 6)
	local perkLayout = Instance.new("UIListLayout")
	perkLayout.FillDirection = Enum.FillDirection.Horizontal
	perkLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	perkLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	perkLayout.Padding = UDim.new(0, 18)
	perkLayout.Parent = perks
	for index, info in ipairs({
		{ "PerkCoins", "+10% Coins" },
		{ "PerkLuck", "+5% Hatch Luck" },
		{ "PerkSlots", "+1 Equip Slot" },
	}) do
		local card = conceptPanel(
			perks,
			"PerkCard" .. tostring(index),
			UDim2.fromOffset(0, 0),
			UDim2.fromOffset(190, 74),
			Color3.fromRGB(255, 255, 255),
			14,
			1
		)
		card.LayoutOrder = index
		conceptLabel(
			card,
			info[1],
			info[2],
			UDim2.fromScale(0.08, 0.16),
			UDim2.fromScale(0.84, 0.68),
			18,
			Enum.TextXAlignment.Center
		)
	end
end

local function buildPlaceholderWindow(modalWindows, name, title)
	if modalWindows:FindFirstChild(name) then
		return
	end
	local _, content = conceptWindow(modalWindows, name, title)
	conceptLabel(
		content,
		"Placeholder",
		"This editable window is ready for Studio layout.",
		UDim2.fromScale(0.1, 0.42),
		UDim2.fromScale(0.8, 0.16),
		24,
		Enum.TextXAlignment.Center
	)
end

function Builder.UpdateShopTransitionOverlay()
	if not canBuildConceptMenus("UpdateShopTransitionOverlay") then
		return
	end

	local mainHud = StarterGui:FindFirstChild("MainHUD")
	if not mainHud or not mainHud:IsA("ScreenGui") then
		warn("StudioMenuWindowsBuilder: missing StarterGui.MainHUD for ShopTransitionOverlay.")
		return
	end

	buildShopTransitionOverlay(mainHud)
	print("StudioMenuWindowsBuilder: updated editable StarterGui.MainHUD.ShopTransitionOverlay.")
end

function Builder.UpdatePowerUpToastUI()
	if not canBuildConceptMenus("UpdatePowerUpToastUI") then
		return
	end

	local mainHud = StarterGui:FindFirstChild("MainHUD")
	if not mainHud or not mainHud:IsA("ScreenGui") then
		warn("StudioMenuWindowsBuilder: missing StarterGui.MainHUD for PowerUpToast.")
		return
	end

	buildPowerUpToast(mainHud)
	print("StudioMenuWindowsBuilder: updated editable StarterGui.MainHUD.PowerUpToast.")
end

function Builder.UpdateBottomButtons()
	if not canBuildConceptMenus("UpdateBottomButtons") then
		return
	end

	local mainHud = StarterGui:FindFirstChild("MainHUD")
	if not mainHud or not mainHud:IsA("ScreenGui") then
		warn("StudioMenuWindowsBuilder: missing StarterGui.MainHUD for BottomButtons.")
		return
	end

	convertExistingBottomButtons(mainHud)
	print("StudioMenuWindowsBuilder: updated editable StarterGui.MainHUD.BottomButtons as ImageButtons.")
end

function Builder.UpdateSettingsWindow()
	if not canBuildConceptMenus("UpdateSettingsWindow") then
		return
	end

	local mainHud = StarterGui:FindFirstChild("MainHUD")
	if not mainHud or not mainHud:IsA("ScreenGui") then
		warn("StudioMenuWindowsBuilder: missing StarterGui.MainHUD for SettingsWindow.")
		return
	end

	local modalWindows = ensureClass(mainHud, "Folder", "ModalWindows")
	buildSettingsWindow(modalWindows)
	print("StudioMenuWindowsBuilder: updated editable StarterGui.MainHUD.ModalWindows.SettingsWindow.")
end

Builder.UpdateSettingsTab = Builder.UpdateSettingsWindow

function Builder.UpdateTradeWindow()
	if not canBuildConceptMenus("UpdateTradeWindow") then
		return
	end

	local mainHud = StarterGui:FindFirstChild("MainHUD")
	if not mainHud or not mainHud:IsA("ScreenGui") then
		warn("StudioMenuWindowsBuilder: missing StarterGui.MainHUD for TradeWindow.")
		return
	end

	local modalWindows = ensureClass(mainHud, "Folder", "ModalWindows")
	buildTradeWindow(modalWindows)
	print("StudioMenuWindowsBuilder: updated editable StarterGui.MainHUD.ModalWindows.TradeWindow.")
end

Builder.UpdateTradingWindow = Builder.UpdateTradeWindow

function Builder.UpdateIndexWindow()
	if not canBuildConceptMenus("UpdateIndexWindow") then
		return
	end

	local mainHud = StarterGui:FindFirstChild("MainHUD")
	if not mainHud or not mainHud:IsA("ScreenGui") then
		warn("StudioMenuWindowsBuilder: missing StarterGui.MainHUD for IndexWindow.")
		return
	end

	local modalWindows = ensureClass(mainHud, "Folder", "ModalWindows")
	buildIndexWindow(modalWindows)
	print("StudioMenuWindowsBuilder: updated editable StarterGui.MainHUD.ModalWindows.IndexWindow.")
end

Builder.BuildIndexWindow = Builder.UpdateIndexWindow
Builder.UpdateCollectionWindow = Builder.UpdateIndexWindow

local function ensurePhysicalDialogueChild(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA(className) then
		return existing, false
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
	return instance, true
end

local function setDialogueTextDefaults(label, created, value, position, size, textSize, alignment)
	if not created then
		return
	end
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = Enum.Font.GothamBlack
	label.Text = value
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = textSize
	label.TextStrokeColor3 = Color3.fromRGB(13, 16, 24)
	label.TextStrokeTransparency = 0.25
	label.TextWrapped = true
	label.TextXAlignment = alignment or Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
end

local function setDialogueOptionDefaults(optionButton, created, value, color)
	optionButton:SetAttribute("UseDialogueOptionColor", true)
	if not created then
		return
	end
	optionButton.BackgroundColor3 = color
	optionButton.BorderSizePixel = 0
	optionButton.AutoButtonColor = true
	optionButton.Font = Enum.Font.GothamBlack
	optionButton.Text = value
	optionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	optionButton.TextSize = 13
	optionButton.TextScaled = false
	optionButton.TextStrokeColor3 = Color3.fromRGB(13, 16, 24)
	optionButton.TextStrokeTransparency = 0.25
	optionButton.TextTruncate = Enum.TextTruncate.AtEnd
	applyCorner(optionButton, 10)
	applyStroke(optionButton, Color3.fromRGB(13, 16, 24), 2)
end

local function buildNpcDialogueUI(mainHud)
	local root, rootCreated = ensurePhysicalDialogueChild(mainHud, "Frame", "ZorkDialogueUI")
	root:SetAttribute("EditableNpcDialogueUI", true)
	root:SetAttribute("ClientBoundBy", "NpcDialogueClient.client.luau")
	root:SetAttribute("WorldOffsetY", root:GetAttribute("WorldOffsetY") or 5.8)
	if rootCreated then
		root.AnchorPoint = Vector2.new(0.5, 1)
		root.Position = UDim2.fromScale(0.5, 0.5)
		root.Size = UDim2.fromOffset(620, 330)
		root.BackgroundTransparency = 1
		root.BorderSizePixel = 0
		root.Visible = true
		root.ZIndex = 900
	end

	local panel, panelCreated = ensurePhysicalDialogueChild(root, "Frame", "Panel")
	if panelCreated then
		panel.AnchorPoint = Vector2.new(0.5, 0.5)
		panel.Position = UDim2.fromScale(0.5, 0.5)
		panel.Size = UDim2.new(1, -10, 1, -10)
		panel.BackgroundColor3 = Color3.fromRGB(24, 27, 36)
		panel.BackgroundTransparency = 0.04
		panel.BorderSizePixel = 0
		panel.ZIndex = root.ZIndex + 10
	end
	applyCorner(panel, 18)
	local panelStroke = applyStroke(panel, Color3.fromRGB(76, 214, 224), 4)
	panelStroke:SetAttribute("UseNpcAccent", true)

	local accent, accentCreated = ensurePhysicalDialogueChild(panel, "Frame", "AccentBar")
	if accentCreated then
		accent.Position = UDim2.fromOffset(0, 0)
		accent.Size = UDim2.new(0, 12, 1, 0)
		accent.BackgroundColor3 = Color3.fromRGB(76, 214, 224)
		accent.BorderSizePixel = 0
		accent.ZIndex = panel.ZIndex + 1
	end
	accent:SetAttribute("UseNpcAccent", true)
	applyCorner(accent, 18)

	local speakerName, nameCreated = ensurePhysicalDialogueChild(panel, "TextLabel", "SpeakerName")
	setDialogueTextDefaults(speakerName, nameCreated, "Zork", UDim2.fromOffset(30, 16), UDim2.new(0.48, 0, 0, 34), 28)
	if nameCreated then
		speakerName.TextYAlignment = Enum.TextYAlignment.Center
		speakerName.ZIndex = panel.ZIndex + 2
	end

	local speakerRole, roleCreated = ensurePhysicalDialogueChild(panel, "TextLabel", "SpeakerRole")
	setDialogueTextDefaults(
		speakerRole,
		roleCreated,
		"Brush Merchant + Quest Keeper",
		UDim2.new(0.52, 0, 0, 22),
		UDim2.new(0.42, 0, 0, 24),
		14,
		Enum.TextXAlignment.Right
	)
	if roleCreated then
		speakerRole.Font = Enum.Font.GothamBold
		speakerRole.TextColor3 = Color3.fromRGB(176, 188, 204)
		speakerRole.TextYAlignment = Enum.TextYAlignment.Center
		speakerRole.ZIndex = panel.ZIndex + 2
	end

	local bodyButton, bodyButtonCreated = ensurePhysicalDialogueChild(panel, "TextButton", "BodyButton")
	if bodyButtonCreated then
		bodyButton.Position = UDim2.fromScale(0, 0)
		bodyButton.Size = UDim2.fromScale(1, 1)
		bodyButton.BackgroundTransparency = 1
		bodyButton.BorderSizePixel = 0
		bodyButton.AutoButtonColor = false
		bodyButton.Text = ""
		bodyButton.ZIndex = panel.ZIndex + 1
	end

	local bodyText, bodyTextCreated = ensurePhysicalDialogueChild(bodyButton, "TextLabel", "BodyText")
	setDialogueTextDefaults(
		bodyText,
		bodyTextCreated,
		"If you need better paint power, I sell brushes. If you need extra rewards, I keep daily quests warmed up.",
		UDim2.fromOffset(28, 58),
		UDim2.new(1, -56, 0, 104),
		19
	)
	if bodyTextCreated then
		bodyText.Font = Enum.Font.GothamBold
		bodyText.ZIndex = panel.ZIndex + 4
	end

	local options, optionsCreated = ensurePhysicalDialogueChild(panel, "Frame", "Options")
	if optionsCreated then
		options.BackgroundTransparency = 1
		options.Position = UDim2.fromOffset(28, 180)
		options.Size = UDim2.new(1, -56, 0, 118)
		options.ZIndex = panel.ZIndex + 10
	end
	local grid = options:FindFirstChildOfClass("UIGridLayout")
	if not grid then
		grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.fromOffset(268, 32)
		grid.CellPadding = UDim2.fromOffset(10, 8)
		grid.FillDirectionMaxCells = 2
		grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
		grid.VerticalAlignment = Enum.VerticalAlignment.Top
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = options
	end

	local template, templateCreated = ensurePhysicalDialogueChild(options, "TextButton", "OptionTemplate")
	template.Visible = false
	template.LayoutOrder = 0
	template.ZIndex = options.ZIndex + 2
	setDialogueOptionDefaults(template, templateCreated, "Option", Color3.fromRGB(55, 216, 54))

	local previewOptions = {
		{ "Show me brushes", Color3.fromRGB(55, 216, 54) },
		{ "Daily quests", Color3.fromRGB(240, 198, 49) },
		{ "How do quests work?", Color3.fromRGB(76, 214, 224) },
		{ "Who are you?", Color3.fromRGB(76, 214, 224) },
		{ "Bye", Color3.fromRGB(236, 72, 92) },
	}
	for index, option in ipairs(previewOptions) do
		local preview, previewCreated = ensurePhysicalDialogueChild(options, "TextButton", "PreviewOption" .. index)
		preview:SetAttribute("DialoguePreviewOption", true)
		if previewCreated then
			preview.Visible = true
			preview.LayoutOrder = index
			preview.ZIndex = options.ZIndex + 2
		end
		setDialogueOptionDefaults(preview, previewCreated, option[1], option[2])
	end

	local pointer, pointerCreated = ensurePhysicalDialogueChild(panel, "Frame", "Pointer")
	if pointerCreated then
		pointer.AnchorPoint = Vector2.new(0.5, 0)
		pointer.Position = UDim2.new(0.5, 0, 1, -12)
		pointer.Size = UDim2.fromOffset(26, 26)
		pointer.BackgroundColor3 = Color3.fromRGB(24, 27, 36)
		pointer.BorderSizePixel = 0
		pointer.Rotation = 45
		pointer.ZIndex = panel.ZIndex - 1
	end

	return root
end

function Builder.UpdateNpcDialogueUI()
	if not canBuildConceptMenus("UpdateNpcDialogueUI") then
		return
	end

	local mainHud = ensureClass(StarterGui, "ScreenGui", "MainHUD")
	mainHud.ResetOnSpawn = false
	mainHud.IgnoreGuiInset = true
	mainHud.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	mainHud.DisplayOrder = math.max(mainHud.DisplayOrder, 100)
	mainHud.Enabled = true

	buildNpcDialogueUI(mainHud)
	print("StudioMenuWindowsBuilder: updated editable StarterGui.MainHUD.ZorkDialogueUI.")
end

Builder.UpdateZorkDialogueUI = Builder.UpdateNpcDialogueUI
Builder.BuildNpcDialogueUI = Builder.UpdateNpcDialogueUI
Builder.BuildZorkDialogueUI = Builder.UpdateNpcDialogueUI

function Builder.UpdateZorkWindows()
	if not canBuildConceptMenus("UpdateZorkWindows") then
		return
	end

	local legacyRoot = StarterGui:FindFirstChild("ClientUIRoot")
	if legacyRoot and legacyRoot:IsA("ScreenGui") then
		legacyRoot.Enabled = false
	end

	local mainHud = ensureClass(StarterGui, "ScreenGui", "MainHUD")
	mainHud.ResetOnSpawn = false
	mainHud.IgnoreGuiInset = true
	mainHud.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	mainHud.DisplayOrder = math.max(mainHud.DisplayOrder, 100)
	mainHud.Enabled = true

	buildNpcDialogueUI(mainHud)
	local windowsFolder = ensureClass(mainHud, "Folder", "ModalWindows")
	makeBrushShopWindow(windowsFolder)
	makeDailyQuestsWindow(windowsFolder)
	print(
		"StudioMenuWindowsBuilder: updated editable StarterGui.MainHUD ZorkDialogueUI, BrushShopWindow, and DailyQuestsWindow."
	)
end

Builder.BuildZorkWindows = Builder.UpdateZorkWindows
Builder.BuildZorkShopUI = Builder.UpdateZorkWindows
Builder.BuildBrushShopUI = Builder.UpdateZorkWindows
Builder.BuildDailyQuestsUI = Builder.UpdateZorkWindows

function Builder.UpdateCloseButtons()
	if not canBuildConceptMenus("UpdateCloseButtons") then
		return
	end

	local updated = 0
	for _, descendant in ipairs(StarterGui:GetDescendants()) do
		if descendant.Name == "CloseButton" and descendant:IsA("GuiButton") then
			styleCloseButton(
				descendant,
				STANDARD_CLOSE_POSITION,
				STANDARD_CLOSE_SIZE,
				math.max(descendant.ZIndex, 1003)
			)
			updated += 1
		end
	end
	print("StudioMenuWindowsBuilder: updated " .. tostring(updated) .. " editable close button(s).")
end

Builder.FixCloseButtons = Builder.UpdateCloseButtons

local function tutorialText(parent, name, value, position, size, textSize, color, alignment)
	local label = text(parent, name, value, position, size, textSize)
	label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 1
	label.TextScaled = true
	label.TextWrapped = true
	label.TextXAlignment = alignment or Enum.TextXAlignment.Left
	local sizeLimit = label:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
	sizeLimit.MinTextSize = 10
	sizeLimit.MaxTextSize = textSize or 18
	sizeLimit.Parent = label
	return label
end

function Builder.BuildTutorialGui()
	if not canBuildConceptMenus("BuildTutorialGui") then
		return
	end

	local tutorialGui = findOrCreate(StarterGui, "ScreenGui", "TutorialGui")
	clearChildren(tutorialGui)
	tutorialGui.ResetOnSpawn = false
	tutorialGui.IgnoreGuiInset = true
	tutorialGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	tutorialGui.DisplayOrder = 99950
	tutorialGui.Enabled = false

	local root =
		frame(tutorialGui, "TutorialRoot", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), Color3.fromRGB(3, 4, 7))
	root.Active = false
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.ZIndex = 1

	local topGlow = frame(root, "TopGlow", UDim2.fromScale(0, 0), UDim2.new(1, 0, 0, 4), CYAN)
	topGlow.BackgroundTransparency = 0.72
	topGlow.BorderSizePixel = 0
	topGlow.ZIndex = 4

	local panel =
		frame(root, "QuestPanel", UDim2.new(0, 24, 0.38, -95), UDim2.fromOffset(370, 210), Color3.fromRGB(7, 9, 15))
	panel.BackgroundTransparency = 0.06
	panel.BorderSizePixel = 0
	panel.ZIndex = 20
	applyCorner(panel, 8)
	applyStroke(panel, CYAN, 2)

	local accent = frame(panel, "AccentBar", UDim2.fromScale(0, 0), UDim2.new(0, 7, 1, 0), CYAN)
	accent.BorderSizePixel = 0
	accent.ZIndex = 21
	applyCorner(accent, 8)

	tutorialText(panel, "Header", "TUTORIAL QUEST", UDim2.fromOffset(22, 14), UDim2.new(1, -116, 0, 24), 16, CYAN).ZIndex =
		22
	tutorialText(
		panel,
		"QuestTitle",
		"Quest 1: Paint a color spill",
		UDim2.fromOffset(22, 44),
		UDim2.new(1, -44, 0, 34),
		24,
		Color3.fromRGB(255, 255, 255)
	).ZIndex =
		22
	local body = tutorialText(
		panel,
		"QuestBody",
		"Walk to a glowing color spill and paint it down with your brush.",
		UDim2.fromOffset(22, 84),
		UDim2.new(1, -44, 0, 52),
		16,
		Color3.fromRGB(214, 230, 255)
	)
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.ZIndex = 22

	local objective = tutorialText(
		panel,
		"ObjectiveLabel",
		"Paint 1 color spill",
		UDim2.new(0, 22, 1, -62),
		UDim2.new(1, -168, 0, 32),
		14,
		GREEN,
		Enum.TextXAlignment.Center
	)
	objective.BackgroundColor3 = Color3.fromRGB(3, 4, 7)
	objective.BackgroundTransparency = 0.05
	objective.BorderSizePixel = 0
	objective.TextYAlignment = Enum.TextYAlignment.Center
	objective.ZIndex = 22
	applyCorner(objective, 8)

	tutorialText(
		panel,
		"ProgressLabel",
		"0 / 1  -  1/6",
		UDim2.new(0, 22, 1, -26),
		UDim2.new(1, -44, 0, 18),
		12,
		Color3.fromRGB(194, 224, 255)
	).ZIndex =
		22
	tutorialText(
		panel,
		"StatusLabel",
		"Active tutorial quest",
		UDim2.new(1, -126, 0, 15),
		UDim2.fromOffset(102, 20),
		11,
		Color3.fromRGB(194, 224, 255),
		Enum.TextXAlignment.Right
	).ZIndex =
		22

	button(panel, "SkipButton", "SKIP", UDim2.new(1, -124, 1, -62), UDim2.fromOffset(100, 32), DISABLED).ZIndex = 23

	local spotlight =
		frame(root, "Spotlight", UDim2.fromOffset(0, 0), UDim2.fromOffset(120, 120), Color3.fromRGB(5, 9, 16))
	spotlight.BackgroundTransparency = 1
	spotlight.Visible = false
	spotlight.ZIndex = 80
	local ring = frame(spotlight, "TargetRing", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), CYAN)
	ring.BackgroundTransparency = 0.84
	ring.ZIndex = 81
	applyCorner(ring, 10)
	applyStroke(ring, CYAN, 3)
	local hint = tutorialText(
		spotlight,
		"Hint",
		"",
		UDim2.new(0.5, -170, 1, 10),
		UDim2.fromOffset(340, 38),
		14,
		Color3.fromRGB(232, 244, 255),
		Enum.TextXAlignment.Center
	)
	hint.BackgroundColor3 = Color3.fromRGB(7, 9, 15)
	hint.BackgroundTransparency = 0.08
	hint.BorderSizePixel = 0
	hint.TextYAlignment = Enum.TextYAlignment.Center
	hint.ZIndex = 82
	applyCorner(hint, 10)
	applyStroke(hint, CYAN, 2)

	print("StudioMenuWindowsBuilder: built editable quest-style StarterGui.TutorialGui.")
	print("Edit path: StarterGui > TutorialGui > TutorialRoot > QuestPanel")
end

Builder.UpdateTutorialGui = Builder.BuildTutorialGui
Builder.BuildTutorialUI = Builder.BuildTutorialGui

function Builder.BuildConceptMenus()
	if not canBuildConceptMenus("BuildConceptMenus") then
		return
	end

	local legacyRoot = StarterGui:FindFirstChild("ClientUIRoot")
	if legacyRoot and legacyRoot:IsA("ScreenGui") then
		legacyRoot.Enabled = false
	end

	local mainHud = ensureClass(StarterGui, "ScreenGui", "MainHUD")
	mainHud.ResetOnSpawn = false
	mainHud.IgnoreGuiInset = true
	mainHud.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	mainHud.DisplayOrder = math.max(mainHud.DisplayOrder, 100)
	mainHud.Enabled = true

	buildCurrencyBar(mainHud)
	buildBottomButtons(mainHud)
	buildShopTransitionOverlay(mainHud)
	buildPowerUpToast(mainHud)
	buildNpcDialogueUI(mainHud)

	local modalWindows = ensureClass(mainHud, "Folder", "ModalWindows")
	buildInventoryWindow(modalWindows)
	buildSettingsWindow(modalWindows)
	buildTradeWindow(modalWindows)
	buildRankWindow(modalWindows)
	buildIndexWindow(modalWindows)
	makeShopWindow(modalWindows)
	makeWorldsWindow(modalWindows)
	makeBrushShopWindow(modalWindows)
	makeDailyQuestsWindow(modalWindows)

	print("StudioMenuWindowsBuilder: built editable concept menus at StarterGui.MainHUD.")
	print("Command: require(game.ReplicatedStorage.StudioMenuWindowsBuilder).BuildConceptMenus()")
end

Builder.BuildMainHUD = Builder.BuildConceptMenus
Builder.UpdateConceptMenus = Builder.BuildConceptMenus
Builder.Build = Builder.BuildConceptMenus

return Builder
