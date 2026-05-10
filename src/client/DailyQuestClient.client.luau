-- StarterPlayerScripts/Client/DailyQuestClient
if true then
	warn("DailyQuestClient UI disabled; EditorWindowBinder binds MainHUD.ModalWindows.Windows.DailyQuestsWindow.")
	return
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("DailyQuestRemote")
local ClientUIRoot = require(ReplicatedStorage:WaitForChild("ClientUIRoot"))
local UIManager = require(ReplicatedStorage:WaitForChild("UIManager"))
local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))

local DARK = Color3.fromRGB(35, 38, 45)
local WHITE = Color3.fromRGB(255, 255, 255)
local CYAN = Color3.fromRGB(118, 238, 244)
local RED = Color3.fromRGB(255, 24, 96)
local GREEN = Color3.fromRGB(116, 245, 42)
local CREAM = Color3.fromRGB(255, 249, 239)

local gui = ClientUIRoot.GetLayer(player:WaitForChild("PlayerGui"), "DailyQuestGui")
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
frame.Name = "DailyQuestPanel"
frame.Size = UDim2.fromOffset(460, 360)
frame.Position = UDim2.fromScale(0.5, 0.5)
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.BackgroundColor3 = CREAM
frame.BorderSizePixel = 0
frame.ZIndex = 81
frame.Parent = gui
UITheme.ApplyResponsiveScale(frame, 460, 360, 0.76, 28)
local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 22)
frameCorner.Parent = frame
local frameStroke = Instance.new("UIStroke")
frameStroke.Color = DARK
frameStroke.Thickness = 5
frameStroke.Parent = frame

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 62)
header.BackgroundColor3 = CYAN
header.BorderSizePixel = 0
header.ZIndex = 82
header.Parent = frame
local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 22)
headerCorner.Parent = header

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, -78, 1, 0)
title.Position = UDim2.fromOffset(20, 0)
title.Font = Enum.Font.LuckiestGuy
title.TextSize = 26
title.TextColor3 = WHITE
title.TextStrokeTransparency = 0
title.TextStrokeColor3 = DARK
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "ZORK'S DAILY QUESTS"
title.ZIndex = 83
title.Parent = header

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(42, 42)
close.Position = UDim2.new(1, -54, 0.5, -21)
close.BackgroundColor3 = RED
close.AutoButtonColor = false
close.Font = Enum.Font.LuckiestGuy
close.TextSize = 22
close.TextColor3 = WHITE
close.TextStrokeTransparency = 0
close.TextStrokeColor3 = DARK
close.Text = "X"
close.ZIndex = 84
close.Parent = header
UITheme.ApplyTouchTarget(close, 44)
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 13)
closeCorner.Parent = close
local closeStroke = Instance.new("UIStroke")
closeStroke.Color = DARK
closeStroke.Thickness = 3
closeStroke.Parent = close

local resetLabel = Instance.new("TextLabel")
resetLabel.BackgroundTransparency = 1
resetLabel.Size = UDim2.new(1, -36, 0, 28)
resetLabel.Position = UDim2.fromOffset(18, 72)
resetLabel.Font = Enum.Font.GothamBold
resetLabel.TextSize = 14
resetLabel.TextColor3 = Color3.fromRGB(80, 84, 104)
resetLabel.TextXAlignment = Enum.TextXAlignment.Left
resetLabel.Text = "Resets in: --"
resetLabel.ZIndex = 82
resetLabel.Parent = frame

local list = Instance.new("Frame")
list.BackgroundTransparency = 1
list.Size = UDim2.new(1, -36, 1, -112)
list.Position = UDim2.fromOffset(18, 102)
list.ZIndex = 82
list.Parent = frame

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 10)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local function formatTime(seconds)
	seconds = math.max(0, tonumber(seconds) or 0)
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	return string.format("%02dh %02dm", hours, minutes)
end

local function clearQuestCards()
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

local function render(data)
	if not data then
		return
	end

	resetLabel.Text = "Resets in: " .. formatTime(data.resetIn)
	clearQuestCards()

	for index, quest in ipairs(data.quests or {}) do
		local complete = (tonumber(quest.progress) or 0) >= (tonumber(quest.target) or 1)

		local card = Instance.new("Frame")
		card.Name = "QuestCard_" .. tostring(index)
		card.Size = UDim2.new(1, 0, 0, 74)
		card.BackgroundColor3 = Color3.fromRGB(247, 252, 255)
		card.BorderSizePixel = 0
		card.LayoutOrder = index
		card.ZIndex = 82
		card.Parent = list
		local cardCorner = Instance.new("UICorner")
		cardCorner.CornerRadius = UDim.new(0, 12)
		cardCorner.Parent = card
		local cardStroke = Instance.new("UIStroke")
		cardStroke.Color = complete and GREEN or DARK
		cardStroke.Thickness = complete and 3 or 2
		cardStroke.Parent = card

		local questTitle = Instance.new("TextLabel")
		questTitle.BackgroundTransparency = 1
		questTitle.Size = UDim2.new(1, -132, 0, 22)
		questTitle.Position = UDim2.fromOffset(12, 7)
		questTitle.Font = Enum.Font.LuckiestGuy
		questTitle.TextSize = 17
		questTitle.TextColor3 = DARK
		questTitle.TextXAlignment = Enum.TextXAlignment.Left
		questTitle.Text = tostring(quest.title or "Quest")
		questTitle.ZIndex = 83
		questTitle.Parent = card

		local desc = Instance.new("TextLabel")
		desc.BackgroundTransparency = 1
		desc.Size = UDim2.new(1, -132, 0, 18)
		desc.Position = UDim2.fromOffset(12, 31)
		desc.Font = Enum.Font.GothamBold
		desc.TextSize = 12
		desc.TextColor3 = Color3.fromRGB(82, 86, 104)
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.Text = tostring(quest.description or "")
		desc.ZIndex = 83
		desc.Parent = card

		local progressText = Instance.new("TextLabel")
		progressText.BackgroundTransparency = 1
		progressText.Size = UDim2.new(1, -132, 0, 18)
		progressText.Position = UDim2.fromOffset(12, 51)
		progressText.Font = Enum.Font.GothamBold
		progressText.TextSize = 12
		progressText.TextColor3 = Color3.fromRGB(30, 132, 158)
		progressText.TextXAlignment = Enum.TextXAlignment.Left
		progressText.Text = tostring(quest.progress or 0) .. "/" .. tostring(quest.target or 1)
			.. " | Reward: " .. tostring(quest.reward or 0) .. " Gems"
		progressText.ZIndex = 83
		progressText.Parent = card

		local claimButton = Instance.new("TextButton")
		claimButton.Size = UDim2.fromOffset(104, 42)
		claimButton.Position = UDim2.new(1, -116, 0.5, -21)
		claimButton.BackgroundColor3 = complete and GREEN or Color3.fromRGB(174, 181, 198)
		claimButton.AutoButtonColor = complete and not quest.claimed
		claimButton.Font = Enum.Font.LuckiestGuy
		claimButton.TextSize = 14
		claimButton.TextColor3 = WHITE
		claimButton.TextStrokeTransparency = 0
		claimButton.TextStrokeColor3 = DARK
		claimButton.ZIndex = 84
		claimButton.Parent = card
		UITheme.ApplyTouchTarget(claimButton, 44)
		local buttonCorner = Instance.new("UICorner")
		buttonCorner.CornerRadius = UDim.new(0, 10)
		buttonCorner.Parent = claimButton
		local buttonStroke = Instance.new("UIStroke")
		buttonStroke.Color = DARK
		buttonStroke.Thickness = 2
		buttonStroke.Parent = claimButton

		if quest.claimed then
			claimButton.Text = "CLAIMED"
			claimButton.Active = false
			claimButton.BackgroundColor3 = Color3.fromRGB(116, 126, 146)
		elseif complete then
			claimButton.Text = "CLAIM"
			claimButton.MouseButton1Click:Connect(function()
				claimButton.Text = "..."
				claimButton.Active = false
				remote:FireServer("Claim", index)
			end)
		else
			claimButton.Text = "IN PROGRESS"
			claimButton.Active = false
		end
	end
end

local function closeGui()
	gui.Visible = false
end

local function openGui()
	remote:FireServer("Get")
end

close.MouseButton1Click:Connect(closeGui)
dim.MouseButton1Click:Connect(closeGui)

remote.OnClientEvent:Connect(function(action, data)
	if action == "Open" then
		gui.Visible = true
		render(data)
	elseif action == "Update" then
		render(data)
	elseif action == "Locked" then
		gui.Visible = false
	end
end)

UIManager.register("DailyQuests", openGui, closeGui, function()
	return gui.Visible == true
end)

local dailyQuestButton = ReplicatedStorage:WaitForChild("HudButton_DAILYQUESTS", 10)
if dailyQuestButton then
	dailyQuestButton.Event:Connect(openGui)
end
