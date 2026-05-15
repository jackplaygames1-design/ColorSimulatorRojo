-- Disabled: no PlayerGui UI should be created at runtime.
if true then
	return
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local ClientUIRoot = require(ReplicatedStorage:WaitForChild("ClientUIRoot"))

local DARK = Color3.fromRGB(35, 38, 45)
local PANEL = Color3.fromRGB(22, 14, 20)
local WHITE = Color3.fromRGB(255, 255, 255)
local MUTED = Color3.fromRGB(218, 210, 224)
local LINE = Color3.fromRGB(80, 56, 68)

local STAT_NAMES = { "Color", "Gems", "Coins" }
local COLUMN_WIDTHS = {
	Color = 58,
	Gems = 52,
	Coins = 58,
}
local PANEL_WIDTH = 320
local STATS_WIDTH = 168
local leaderboardHidden = true

local function formatCompact(value)
	value = tonumber(value) or 0
	if value >= 1000000000 then
		return string.format("%.1fB", value / 1000000000)
	elseif value >= 1000000 then
		return string.format("%.1fM", value / 1000000)
	elseif value >= 1000 then
		return string.format("%.1fK", value / 1000)
	end
	return tostring(value)
end

local function getStat(player, statName)
	local stats = player:FindFirstChild("leaderstats")
	return stats and stats:FindFirstChild(statName)
end

local function getStatValue(player, statName)
	local stat = getStat(player, statName)
	return stat and stat.Value or 0
end

local screenGui = ClientUIRoot.GetLayer(localPlayer:WaitForChild("PlayerGui"), "LiveLeaderboardUI")

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(1, 0)
panel.Size = UDim2.new(0, PANEL_WIDTH, 0, 86)
panel.Position = UDim2.new(1, -18, 0, 132)
panel.BackgroundColor3 = PANEL
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel = 0
panel.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = panel

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(70, 38, 50)
stroke.Transparency = 0.45
stroke.Thickness = 1
stroke.Parent = panel

local toggleButton = Instance.new("TextButton")
toggleButton.Name = "ToggleButton"
toggleButton.AnchorPoint = Vector2.new(1, 0)
toggleButton.Size = UDim2.new(0, 62, 0, 34)
toggleButton.Position = UDim2.new(1, -18, 0, 92)
toggleButton.BackgroundColor3 = Color3.fromRGB(118, 238, 244)
toggleButton.AutoButtonColor = false
toggleButton.BorderSizePixel = 0
toggleButton.Font = Enum.Font.GothamBlack
toggleButton.TextScaled = true
toggleButton.TextSize = 14
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.TextStrokeColor3 = DARK
toggleButton.TextStrokeTransparency = 0
toggleButton.Text = "STATS"
toggleButton:SetAttribute("ForceReadableText", true)
toggleButton:SetAttribute("NoReadableHover", true)
toggleButton.Parent = screenGui

local toggleTextSize = Instance.new("UITextSizeConstraint")
toggleTextSize.MinTextSize = 10
toggleTextSize.MaxTextSize = 16
toggleTextSize.Parent = toggleButton

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 12)
toggleCorner.Parent = toggleButton

local toggleStroke = Instance.new("UIStroke")
toggleStroke.Color = DARK
toggleStroke.Thickness = 3
toggleStroke.Parent = toggleButton

local function applyLeaderboardVisibility()
	panel.Visible = not leaderboardHidden
	toggleButton.Text = leaderboardHidden and "STATS" or "HIDE"
	toggleButton.BackgroundColor3 = leaderboardHidden and Color3.fromRGB(16, 38, 56) or Color3.fromRGB(225, 52, 98)
end

toggleButton.MouseButton1Click:Connect(function()
	leaderboardHidden = not leaderboardHidden
	applyLeaderboardVisibility()
end)

local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, -20, 0, 28)
header.Position = UDim2.new(0, 10, 0, 6)
header.BackgroundTransparency = 1
header.Parent = panel

local peopleHeader = Instance.new("TextLabel")
peopleHeader.Size = UDim2.new(1, -270, 1, 0)
peopleHeader.BackgroundTransparency = 1
peopleHeader.Font = Enum.Font.GothamMedium
peopleHeader.TextSize = 12
peopleHeader.TextColor3 = MUTED
peopleHeader.TextXAlignment = Enum.TextXAlignment.Left
peopleHeader.Text = "Players"
peopleHeader.Parent = header

local x = 0
for _, statName in ipairs(STAT_NAMES) do
	local width = COLUMN_WIDTHS[statName]
	local label = Instance.new("TextLabel")
	label.Name = statName .. "Header"
	label.AnchorPoint = Vector2.new(1, 0)
	label.Size = UDim2.new(0, width, 1, 0)
	label.Position = UDim2.new(1, -x, 0, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 12
	label.TextColor3 = MUTED
	label.TextXAlignment = Enum.TextXAlignment.Right
	label.Text = statName
	label.Parent = header
	x += width
end
peopleHeader.Size = UDim2.new(1, -STATS_WIDTH - 18, 1, 0)

local rows = Instance.new("Frame")
rows.Name = "Rows"
rows.Size = UDim2.new(1, 0, 1, -36)
rows.Position = UDim2.new(0, 0, 0, 36)
rows.BackgroundTransparency = 1
rows.Parent = panel

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Vertical
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = rows

local rowConnections = {}
local statConnections = {}

local function disconnectList(list)
	for _, connection in ipairs(list) do
		connection:Disconnect()
	end
	table.clear(list)
end

local function sortedPlayers()
	local list = Players:GetPlayers()
	table.sort(list, function(a, b)
		local aCoins = getStatValue(a, "Coins")
		local bCoins = getStatValue(b, "Coins")
		if aCoins == bCoins then
			return a.Name < b.Name
		end
		return aCoins > bCoins
	end)
	return list
end

local function makeValueLabel(parent, statName, index)
	local width = COLUMN_WIDTHS[statName]
	local offset = 0
	for i = 1, index - 1 do
		offset += COLUMN_WIDTHS[STAT_NAMES[i]]
	end

	local label = Instance.new("TextLabel")
	label.Name = statName
	label.AnchorPoint = Vector2.new(1, 0)
	label.Size = UDim2.new(0, width, 1, 0)
	label.Position = UDim2.new(1, -offset - 10, 0, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextColor3 = WHITE
	label.TextXAlignment = Enum.TextXAlignment.Right
	label.Text = "0"
	label.Parent = parent
	return label
end

local function rebuild()
	for _, child in ipairs(rows:GetChildren()) do
		if child ~= layout then
			child:Destroy()
		end
	end

	for playerIndex, listedPlayer in ipairs(sortedPlayers()) do
		local row = Instance.new("Frame")
		row.Name = listedPlayer.Name
		row.Size = UDim2.new(1, 0, 0, 38)
		row.BackgroundColor3 = listedPlayer == localPlayer and Color3.fromRGB(58, 12, 18) or PANEL
		row.BackgroundTransparency = listedPlayer == localPlayer and 0.12 or 0.24
		row.BorderSizePixel = 0
		row.LayoutOrder = playerIndex
		row.Parent = rows

		local divider = Instance.new("Frame")
		divider.Name = "Divider"
		divider.Size = UDim2.new(1, 0, 0, 1)
		divider.Position = UDim2.new(0, 0, 1, -1)
		divider.BackgroundColor3 = LINE
		divider.BackgroundTransparency = 0.35
		divider.BorderSizePixel = 0
		divider.Parent = row

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "PlayerName"
		nameLabel.Size = UDim2.new(1, -STATS_WIDTH - 54, 1, 0)
		nameLabel.Position = UDim2.new(0, 36, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 14
		nameLabel.TextColor3 = WHITE
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.Text = listedPlayer.DisplayName
		nameLabel.Parent = row

		local icon = Instance.new("TextLabel")
		icon.Name = "Icon"
		icon.Size = UDim2.new(0, 24, 1, 0)
		icon.Position = UDim2.new(0, 10, 0, 0)
		icon.BackgroundTransparency = 1
		icon.Font = Enum.Font.GothamBold
		icon.TextSize = 16
		icon.TextColor3 = listedPlayer == localPlayer and Color3.fromRGB(255, 220, 120) or MUTED
		icon.Text = listedPlayer == localPlayer and "*" or "-"
		icon.Parent = row

		for statIndex, statName in ipairs(STAT_NAMES) do
			local valueLabel = makeValueLabel(row, statName, statIndex)
			valueLabel.Text = formatCompact(getStatValue(listedPlayer, statName))
		end
	end

	local height = 36 + math.max(1, #Players:GetPlayers()) * 38
	panel.Size = UDim2.new(0, PANEL_WIDTH, 0, math.clamp(height, 74, 120))
end

local tutorialActive = ReplicatedStorage:FindFirstChild("TutorialWelcomeActive")
if not tutorialActive then
	tutorialActive = Instance.new("BoolValue")
	tutorialActive.Name = "TutorialWelcomeActive"
	tutorialActive.Value = false
	tutorialActive.Parent = ReplicatedStorage
end
local function refreshTutorialVisibility()
	screenGui.Visible = not tutorialActive.Value
	applyLeaderboardVisibility()
end
tutorialActive:GetPropertyChangedSignal("Value"):Connect(refreshTutorialVisibility)
refreshTutorialVisibility()

local scheduled = false
local function scheduleRebuild()
	if scheduled then
		return
	end
	scheduled = true
	task.defer(function()
		scheduled = false
		rebuild()
	end)
end

local function watchPlayer(listedPlayer)
	disconnectList(rowConnections[listedPlayer] or {})
	disconnectList(statConnections[listedPlayer] or {})
	rowConnections[listedPlayer] = {}
	statConnections[listedPlayer] = {}

	local function hookStats(stats)
		disconnectList(statConnections[listedPlayer])
		table.insert(statConnections[listedPlayer], stats.ChildAdded:Connect(scheduleRebuild))
		table.insert(statConnections[listedPlayer], stats.ChildRemoved:Connect(scheduleRebuild))
		for _, statName in ipairs(STAT_NAMES) do
			local value = stats:FindFirstChild(statName)
			if value and value:IsA("ValueBase") then
				table.insert(
					statConnections[listedPlayer],
					value:GetPropertyChangedSignal("Value"):Connect(scheduleRebuild)
				)
			end
		end
		scheduleRebuild()
	end

	local stats = listedPlayer:FindFirstChild("leaderstats")
	if stats then
		hookStats(stats)
	end

	table.insert(
		rowConnections[listedPlayer],
		listedPlayer.ChildAdded:Connect(function(child)
			if child.Name == "leaderstats" then
				hookStats(child)
			end
		end)
	)
	table.insert(
		rowConnections[listedPlayer],
		listedPlayer:GetPropertyChangedSignal("DisplayName"):Connect(scheduleRebuild)
	)
end

Players.PlayerAdded:Connect(function(listedPlayer)
	watchPlayer(listedPlayer)
	scheduleRebuild()
end)

Players.PlayerRemoving:Connect(function(listedPlayer)
	disconnectList(rowConnections[listedPlayer] or {})
	disconnectList(statConnections[listedPlayer] or {})
	rowConnections[listedPlayer] = nil
	statConnections[listedPlayer] = nil
	scheduleRebuild()
end)

for _, listedPlayer in ipairs(Players:GetPlayers()) do
	watchPlayer(listedPlayer)
end
scheduleRebuild()
