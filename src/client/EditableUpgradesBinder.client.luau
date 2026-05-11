-- Disabled: no upgrade cards should be created at runtime.
if true then
	return
end

-- Binds the editable Studio UpgradesWindow to the real upgrade system.
-- Does not create duplicate runtime windows; it only fills the existing editable window.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local UpgradeData = require(ReplicatedStorage:WaitForChild("UpgradeData"))
local Events = ReplicatedStorage:WaitForChild("Events")
local purchaseUpgradeEvent = Events:WaitForChild("PurchaseUpgrade")
local upgradeUpdatedEvent = Events:WaitForChild("UpgradeUpdated")

local COLORS = {
	Outline = Color3.fromRGB(35, 38, 45),
	Card = Color3.fromRGB(255, 255, 255),
	Panel = Color3.fromRGB(244, 248, 252),
	Text = Color3.fromRGB(38, 36, 52),
	Muted = Color3.fromRGB(92, 98, 116),
	Green = Color3.fromRGB(84, 225, 112),
	Blue = Color3.fromRGB(88, 224, 235),
	Yellow = Color3.fromRGB(255, 218, 74),
	Disabled = Color3.fromRGB(170, 178, 194),
}

local upgradeLevels = {}
local cardsByUpgradeId = {}

local function mainHUD()
	local root = playerGui:WaitForChild("ClientUIRoot", 30)
	return root and root:WaitForChild("MainHUD", 30)
end

local function windowsFolder(main)
	local modal = main and main:FindFirstChild("ModalWindows")
	if modal and modal:FindFirstChild("Windows") then
		return modal.Windows
	end
	return main and main:FindFirstChild("Windows")
end

local function corner(obj, radius)
	local c = obj:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 16)
	c.Parent = obj
	return c
end

local function stroke(obj, thickness, color)
	local s = obj:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	s.Thickness = thickness or 2
	s.Color = color or COLORS.Outline
	s.Parent = obj
	return s
end

local function clearGenerated(content)
	for _, child in ipairs(content:GetChildren()) do
		if child:GetAttribute("EditableUpgradeGenerated") == true then
			child:Destroy()
		end
	end
end

local function label(parent, name, text, pos, size, textSize, color, font)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Text = text or ""
	l.Position = pos
	l.Size = size
	l.BackgroundTransparency = 1
	l.Font = font or Enum.Font.GothamBold
	l.TextSize = textSize or 14
	l.TextColor3 = color or COLORS.Text
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.TextWrapped = true
	l.Parent = parent
	return l
end

local function button(parent, name, text, pos, size, color)
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = text
	b.Position = pos
	b.Size = size
	b.BackgroundColor3 = color or COLORS.Green
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBlack
	b.TextColor3 = Color3.fromRGB(255, 255, 255)
	b.TextStrokeTransparency = 0
	b.TextStrokeColor3 = COLORS.Outline
	b.TextScaled = true
	b.Parent = parent
	corner(b, 12)
	stroke(b, 2)
	return b
end

local function getContent(window)
	return window:FindFirstChild("Content", true) or window:FindFirstChild("Body", true) or window
end

local function getPlayerCoins()
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")
	return coins and coins.Value or 0
end

local function getLevel(upgradeId)
	if upgradeLevels[upgradeId] ~= nil then
		return upgradeLevels[upgradeId]
	end
	local folder = player:FindFirstChild("Upgrades")
	local value = folder and (folder:FindFirstChild(upgradeId .. "_Level") or folder:FindFirstChild(upgradeId))
	return value and value.Value or 0
end

local function getCostText(upgrade, level)
	local nextData = upgrade.levels[level + 1]
	if not nextData then
		return "MAX"
	end
	return UpgradeData.formatNumber(nextData.cost) .. " Coins"
end

local function updateCard(upgradeId)
	local card = cardsByUpgradeId[upgradeId]
	if not card then return end
	local upgrade = UpgradeData.getUpgrade(upgradeId)
	if not upgrade then return end

	local level = getLevel(upgradeId)
	local maxLevel = #(upgrade.levels or {})
	local nextData = upgrade.levels[level + 1]
	local currentText = UpgradeData.getValueDisplay(upgradeId, level)
	local nextText = nextData and UpgradeData.getValueDisplay(upgradeId, level + 1) or "MAX"
	local canAfford = nextData and getPlayerCoins() >= (tonumber(nextData.cost) or math.huge)

	local levelLabel = card:FindFirstChild("Level", true)
	if levelLabel then levelLabel.Text = "Level " .. tostring(level) .. " / " .. tostring(maxLevel) end

	local currentLabel = card:FindFirstChild("CurrentValue", true)
	if currentLabel then currentLabel.Text = "Now: " .. currentText end

	local nextLabel = card:FindFirstChild("NextValue", true)
	if nextLabel then nextLabel.Text = nextData and ("Next: " .. nextText) or "Maxed out" end

	local buy = card:FindFirstChild("BuyButton", true)
	if buy and buy:IsA("TextButton") then
		if not nextData then
			buy.Text = "MAXED"
			buy.BackgroundColor3 = COLORS.Disabled
			buy.Active = false
			buy.AutoButtonColor = false
		elseif canAfford then
			buy.Text = "BUY " .. UpgradeData.formatNumber(nextData.cost)
			buy.BackgroundColor3 = COLORS.Green
			buy.Active = true
			buy.AutoButtonColor = true
		else
			buy.Text = "NEED " .. UpgradeData.formatNumber(nextData.cost)
			buy.BackgroundColor3 = COLORS.Disabled
			buy.Active = true
			buy.AutoButtonColor = false
		end
	end
end

local function updateAllCards()
	for _, upgrade in ipairs(UpgradeData.Upgrades) do
		updateCard(upgrade.id)
	end
end

local function makeUpgradeCard(parent, upgrade, index)
	local width = 330
	local height = 140
	local col = (index - 1) % 2
	local row = math.floor((index - 1) / 2)

	local card = Instance.new("Frame")
	card.Name = upgrade.id .. "Card"
	card:SetAttribute("EditableUpgradeGenerated", true)
	card.Position = UDim2.fromOffset(16 + col * 350, 16 + row * 158)
	card.Size = UDim2.fromOffset(width, height)
	card.BackgroundColor3 = COLORS.Card
	card.BorderSizePixel = 0
	card.Parent = parent
	corner(card, 18)
	stroke(card, 3)
	cardsByUpgradeId[upgrade.id] = card

	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.Position = UDim2.fromOffset(12, 14)
	icon.Size = UDim2.fromOffset(58, 58)
	icon.BackgroundColor3 = COLORS.Blue
	icon.BorderSizePixel = 0
	icon.Font = Enum.Font.GothamBlack
	icon.Text = tostring(upgrade.icon or "UP")
	icon.TextScaled = true
	icon.TextColor3 = Color3.fromRGB(255, 255, 255)
	icon.TextStrokeTransparency = 0
	icon.TextStrokeColor3 = COLORS.Outline
	icon.Parent = card
	corner(icon, 14)
	stroke(icon, 2)

	label(card, "Name", upgrade.displayName, UDim2.fromOffset(82, 8), UDim2.new(1, -92, 0, 26), 18, COLORS.Text, Enum.Font.GothamBlack)
	label(card, "Description", upgrade.description, UDim2.fromOffset(82, 34), UDim2.new(1, -92, 0, 30), 12, COLORS.Muted)
	label(card, "Level", "Level 0", UDim2.fromOffset(14, 78), UDim2.fromOffset(120, 22), 13, COLORS.Text, Enum.Font.GothamBlack)
	label(card, "CurrentValue", "Now: -", UDim2.fromOffset(138, 72), UDim2.fromOffset(176, 22), 12, COLORS.Muted)
	label(card, "NextValue", "Next: -", UDim2.fromOffset(138, 94), UDim2.fromOffset(176, 22), 12, COLORS.Muted)

	local buy = button(card, "BuyButton", "BUY", UDim2.new(1, -116, 1, -42), UDim2.fromOffset(102, 32), COLORS.Green)
	buy.MouseButton1Click:Connect(function()
		local level = getLevel(upgrade.id)
		if not upgrade.levels[level + 1] then return end
		purchaseUpgradeEvent:FireServer(upgrade.id)
	end)

	updateCard(upgrade.id)
end

local function render(window)
	local content = getContent(window)
	if not content then return end
	clearGenerated(content)
	cardsByUpgradeId = {}

	for index, upgrade in ipairs(UpgradeData.Upgrades) do
		makeUpgradeCard(content, upgrade, index)
	end
end

local main = mainHUD()
local windows = windowsFolder(main)
local upgradesWindow = windows and windows:WaitForChild("UpgradesWindow", 30)

if upgradesWindow then
	render(upgradesWindow)
else
	warn("EditableUpgradesBinder: UpgradesWindow missing; no runtime window will be created.")
end

upgradeUpdatedEvent.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then return end
	if type(payload.Levels) == "table" then
		for upgradeId, level in pairs(payload.Levels) do
			upgradeLevels[upgradeId] = tonumber(level) or 0
		end
	end
	updateAllCards()
	if payload.Message and payload.Success == false then
		warn("Upgrade failed:", payload.Message)
	end
end)

local leaderstats = player:WaitForChild("leaderstats", 30)
local coins = leaderstats and leaderstats:FindFirstChild("Coins")
if coins then
	coins:GetPropertyChangedSignal("Value"):Connect(updateAllCards)
end

local upgradesFolder = player:WaitForChild("Upgrades", 30)
if upgradesFolder then
	upgradesFolder.ChildAdded:Connect(function(child)
		if child:IsA("IntValue") then
			child:GetPropertyChangedSignal("Value"):Connect(updateAllCards)
			updateAllCards()
		end
	end)
	for _, child in ipairs(upgradesFolder:GetChildren()) do
		if child:IsA("IntValue") then
			child:GetPropertyChangedSignal("Value"):Connect(updateAllCards)
		end
	end
end
