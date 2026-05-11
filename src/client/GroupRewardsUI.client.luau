-- Disabled: no PlayerGui UI should be created at runtime.
if true then
	return
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local events = ReplicatedStorage:WaitForChild("Events")
local remote = events:WaitForChild("GroupRewards")
local ClientUIRoot = require(ReplicatedStorage:WaitForChild("ClientUIRoot"))
local UIManager = require(ReplicatedStorage:WaitForChild("UIManager"))
local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))

local DARK = Color3.fromRGB(35, 38, 45)
local CREAM = Color3.fromRGB(255, 249, 239)
local CYAN = Color3.fromRGB(118, 238, 244)
local GREEN = Color3.fromRGB(116, 245, 42)
local GOLD = Color3.fromRGB(255, 216, 82)
local RED = Color3.fromRGB(255, 24, 96)
local MUTED = Color3.fromRGB(95, 101, 118)

local gui = ClientUIRoot.GetLayer(player:WaitForChild("PlayerGui"), "GroupRewardsGui")
gui.Visible = false

local dim = Instance.new("TextButton")
dim.Name = "Dim"
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.fromRGB(8, 14, 20)
dim.BackgroundTransparency = 0.42
dim.BorderSizePixel = 0
dim.Text = ""
dim.AutoButtonColor = false
dim.ZIndex = 80
dim.Parent = gui

local frame = Instance.new("Frame")
frame.Name = "GroupRewardsPanel"
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Position = UDim2.fromScale(0.5, 0.5)
frame.Size = UDim2.fromOffset(430, 380)
frame.BackgroundColor3 = CREAM
frame.BorderSizePixel = 0
frame.ZIndex = 81
frame.Parent = gui
UITheme.ApplyResponsiveScale(frame, 430, 380, 0.76, 28)

local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 22)
frameCorner.Parent = frame
local frameStroke = Instance.new("UIStroke")
frameStroke.Color = DARK
frameStroke.Thickness = 5
frameStroke.Parent = frame

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 64)
header.BackgroundColor3 = CYAN
header.BorderSizePixel = 0
header.ZIndex = 82
header.Parent = frame
local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 22)
headerCorner.Parent = header

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, -80, 1, 0)
title.Position = UDim2.fromOffset(20, 0)
title.Font = Enum.Font.LuckiestGuy
title.TextSize = 28
title.TextColor3 = Color3.new(1, 1, 1)
title.TextStrokeTransparency = 0
title.TextStrokeColor3 = DARK
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "GROUP REWARDS"
title.ZIndex = 83
title.Parent = header

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(42, 42)
close.Position = UDim2.new(1, -54, 0.5, -21)
close.BackgroundColor3 = RED
close.AutoButtonColor = false
close.Font = Enum.Font.LuckiestGuy
close.TextSize = 22
close.TextColor3 = Color3.new(1, 1, 1)
close.TextStrokeTransparency = 0
close.TextStrokeColor3 = DARK
close.Text = "X"
close.ZIndex = 84
close.Parent = header
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(1, 0)
closeCorner.Parent = close
UITheme.ApplyTouchTarget(close, 44)

local content = Instance.new("Frame")
content.Name = "Content"
content.BackgroundTransparency = 1
content.Position = UDim2.fromOffset(24, 84)
content.Size = UDim2.new(1, -48, 1, -108)
content.ZIndex = 82
content.Parent = frame
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 10)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = content

local status = Instance.new("TextLabel")
status.BackgroundTransparency = 1
status.Size = UDim2.new(1, 0, 0, 50)
status.Font = Enum.Font.GothamBold
status.TextSize = 18
status.TextColor3 = DARK
status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.ZIndex = 83
status.Parent = content

local function makeLine(text, color)
	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Color3.fromRGB(245, 250, 250)
	label.BorderSizePixel = 0
	label.Size = UDim2.new(1, 0, 0, 38)
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 17
	label.TextColor3 = color or DARK
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = "  " .. text
	label.ZIndex = 83
	label.Parent = content
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Color = DARK
	stroke.Thickness = 2
	stroke.Transparency = 0.75
	stroke.Parent = label
	return label
end

local luckLine = makeLine("+5% Luck", GOLD)
local coinsLine = makeLine("+5% Coins", GOLD)
local dailyLine = makeLine("100 Gems every day", GREEN)

local info = Instance.new("TextLabel")
info.BackgroundTransparency = 1
info.Size = UDim2.new(1, 0, 0, 48)
info.Font = Enum.Font.GothamBold
info.TextSize = 15
info.TextColor3 = MUTED
info.TextWrapped = true
info.TextXAlignment = Enum.TextXAlignment.Left
info.TextYAlignment = Enum.TextYAlignment.Top
info.ZIndex = 83
info.Parent = content

local buttonRow = Instance.new("Frame")
buttonRow.BackgroundTransparency = 1
buttonRow.Size = UDim2.new(1, 0, 0, 48)
buttonRow.ZIndex = 83
buttonRow.Parent = content

local actionButton = Instance.new("TextButton")
actionButton.AnchorPoint = Vector2.new(1, 0)
actionButton.Position = UDim2.new(1, 0, 0, 0)
actionButton.Size = UDim2.fromOffset(170, 44)
actionButton.BackgroundColor3 = GREEN
actionButton.AutoButtonColor = false
actionButton.Font = Enum.Font.LuckiestGuy
actionButton.TextSize = 18
actionButton.TextColor3 = Color3.new(1, 1, 1)
actionButton.TextStrokeTransparency = 0
actionButton.TextStrokeColor3 = DARK
actionButton.ZIndex = 84
actionButton.Parent = buttonRow
local actionCorner = Instance.new("UICorner")
actionCorner.CornerRadius = UDim.new(0, 12)
actionCorner.Parent = actionButton
UITheme.ApplyTouchTarget(actionButton, 44)

local currentState = nil

local function formatTime(seconds)
	seconds = math.max(0, tonumber(seconds) or 0)
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	return string.format("%02dh %02dm", hours, minutes)
end

local function render(data)
	currentState = data or currentState
	data = currentState or {}

	if data.isMember then
		status.Text = "Thanks for joining the Color Simulator group. Your boosts are active."
		luckLine.Text = "  +" .. tostring(data.luckPercent or 5) .. "% Luck ACTIVE"
		coinsLine.Text = "  +" .. tostring(data.coinPercent or 5) .. "% Coins ACTIVE"
		dailyLine.Text = "  Claim " .. tostring(data.dailyGems or 100) .. " Gems"
		if data.canClaim then
			info.Text = "Your daily group reward is ready."
			actionButton.Text = "CLAIM"
			actionButton.BackgroundColor3 = GREEN
			actionButton.Active = true
		else
			info.Text = "Already claimed today. Resets in " .. formatTime(data.resetIn) .. "."
			actionButton.Text = "CLAIMED"
			actionButton.BackgroundColor3 = Color3.fromRGB(150, 156, 170)
			actionButton.Active = false
		end
	else
		status.Text = "Join the Color Simulator group to unlock rewards!"
		luckLine.Text = "  +5% Luck"
		coinsLine.Text = "  +5% Coins"
		dailyLine.Text = "  100 Gems every day"
		info.Text = "Search for \"Color Simulator!\" by Jacksocks on Roblox Communities, then reopen this panel."
		actionButton.Text = "JOIN GROUP"
		actionButton.BackgroundColor3 = CYAN
		actionButton.Active = true
	end
end

local function openGui()
	gui.Visible = true
	remote:FireServer("Get")
end

local function closeGui()
	gui.Visible = false
end

close.MouseButton1Click:Connect(closeGui)
dim.MouseButton1Click:Connect(closeGui)

actionButton.MouseButton1Click:Connect(function()
	if currentState and currentState.isMember then
		if currentState.canClaim then
			actionButton.Text = "..."
			actionButton.Active = false
			remote:FireServer("ClaimDaily")
		end
	else
		info.Text = "Open Roblox Communities and join \"Color Simulator!\" by Jacksocks. Then press this again after joining."
		remote:FireServer("Refresh")
	end
end)

remote.OnClientEvent:Connect(function(action, data)
	if action == "State" then
		render(data)
	elseif action == "Open" then
		gui.Visible = true
		render(data)
	end
end)

UIManager.register("GroupRewards", openGui, closeGui, function()
	return gui.Visible == true
end)

local groupButton = ReplicatedStorage:WaitForChild("HudButton_GROUPREWARDS", 10)
if groupButton then
	groupButton.Event:Connect(openGui)
end

remote:FireServer("Get")
