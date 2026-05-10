-- StarterPlayerScripts/Client/DailyQuestClient
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("DailyQuestRemote")
local UIManager = require(ReplicatedStorage:WaitForChild("UIManager"))

local COLORS = {
	Outline = Color3.fromRGB(35, 38, 45),
	Text = Color3.fromRGB(31, 34, 45),
	Muted = Color3.fromRGB(112, 118, 132),
	Green = Color3.fromRGB(84, 225, 112),
	Cyan = Color3.fromRGB(88, 224, 235),
	Disabled = Color3.fromRGB(174, 181, 198),
}

local questData = nil
local questRows = {}

local function getMainHUD()
	local root = player:WaitForChild("PlayerGui"):WaitForChild("ClientUIRoot", 30)
	if not root then
		return nil
	end
	return root:WaitForChild("MainHUD", 30)
end

local function getWindows(mainHUD)
	local modalWindows = mainHUD and mainHUD:FindFirstChild("ModalWindows")
	if modalWindows and modalWindows:FindFirstChild("Windows") then
		return modalWindows.Windows
	end
	return mainHUD and mainHUD:FindFirstChild("Windows")
end

local function findDeep(parent, name)
	return parent and parent:FindFirstChild(name, true)
end

local function setText(obj, value)
	if obj and (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) then
		obj.Text = tostring(value or "")
	end
end

local function formatTime(seconds)
	seconds = math.max(0, tonumber(seconds) or 0)
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	return string.format("%02dh %02dm", hours, minutes)
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

local function makeQuestRow(parent, index)
	local row = Instance.new("Frame")
	row.Name = "QuestRow" .. index
	row.Size = UDim2.new(1, -24, 0, 94)
	row.Position = UDim2.new(0, 12, 0, 12 + ((index - 1) * 106))
	row.BackgroundColor3 = Color3.fromRGB(247, 250, 254)
	row.BorderSizePixel = 0
	row.Parent = parent
	corner(row, 18)
	stroke(row, 2)

	local icon = Instance.new("TextLabel")
	icon.Name = "IconText"
	icon.Position = UDim2.fromScale(0.02, 0.14)
	icon.Size = UDim2.fromScale(0.14, 0.72)
	icon.BackgroundColor3 = Color3.fromRGB(236, 240, 246)
	icon.BorderSizePixel = 0
	icon.Font = Enum.Font.GothamBlack
	icon.TextSize = 15
	icon.TextWrapped = true
	icon.TextColor3 = COLORS.Text
	icon.Parent = row
	corner(icon, 16)

	local title = Instance.new("TextLabel")
	title.Name = "QuestTitle"
	title.Position = UDim2.fromScale(0.19, 0.08)
	title.Size = UDim2.fromScale(0.42, 0.23)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 18
	title.TextColor3 = COLORS.Text
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextWrapped = true
	title.Parent = row

	local desc = Instance.new("TextLabel")
	desc.Name = "QuestDesc"
	desc.Position = UDim2.fromScale(0.19, 0.31)
	desc.Size = UDim2.fromScale(0.43, 0.18)
	desc.BackgroundTransparency = 1
	desc.Font = Enum.Font.GothamMedium
	desc.TextSize = 13
	desc.TextColor3 = COLORS.Muted
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextWrapped = true
	desc.Parent = row

	local bar = Instance.new("Frame")
	bar.Name = "ProgressBarBg"
	bar.Position = UDim2.fromScale(0.19, 0.61)
	bar.Size = UDim2.fromScale(0.42, 0.18)
	bar.BackgroundColor3 = Color3.fromRGB(231, 235, 241)
	bar.BorderSizePixel = 0
	bar.Parent = row
	corner(bar, 14)
	stroke(bar, 2, Color3.fromRGB(190, 196, 208))

	local fill = Instance.new("Frame")
	fill.Name = "ProgressFill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = COLORS.Cyan
	fill.BorderSizePixel = 0
	fill.Parent = bar
	corner(fill, 14)

	local progressText = Instance.new("TextLabel")
	progressText.Name = "ProgressText"
	progressText.Size = UDim2.fromScale(1, 1)
	progressText.BackgroundTransparency = 1
	progressText.Font = Enum.Font.GothamBlack
	progressText.TextSize = 13
	progressText.TextColor3 = COLORS.Text
	progressText.Parent = bar

	local reward = Instance.new("TextLabel")
	reward.Name = "RewardText"
	reward.Position = UDim2.fromScale(0.64, 0.20)
	reward.Size = UDim2.fromScale(0.13, 0.58)
	reward.BackgroundColor3 = Color3.fromRGB(236, 240, 246)
	reward.BorderSizePixel = 0
	reward.Font = Enum.Font.GothamBlack
	reward.TextSize = 12
	reward.TextWrapped = true
	reward.TextColor3 = COLORS.Text
	reward.Parent = row
	corner(reward, 16)

	local claim = Instance.new("TextButton")
	claim.Name = "ClaimButton"
	claim.Position = UDim2.fromScale(0.80, 0.28)
	claim.Size = UDim2.fromScale(0.17, 0.38)
	claim.BackgroundColor3 = COLORS.Disabled
	claim.BorderSizePixel = 0
	claim.Font = Enum.Font.GothamBlack
	claim.TextSize = 14
	claim.TextColor3 = Color3.fromRGB(255, 255, 255)
	claim.TextStrokeTransparency = 0
	claim.TextStrokeColor3 = COLORS.Outline
	claim.Parent = row
	corner(claim, 16)
	stroke(claim, 2)

	return row
end

local function getQuestContent(window)
	return findDeep(window, "QuestList") or findDeep(window, "Body") or findDeep(window, "Content") or window
end

local function ensureRows(window)
	local content = getQuestContent(window)
	if not content then return end
	for _, child in ipairs(content:GetChildren()) do
		if child:GetAttribute("EditableQuestGenerated") == true then
			child:Destroy()
		end
	end
	questRows = {}
	for i = 1, 3 do
		local row = findDeep(content, "QuestRow" .. i) or makeQuestRow(content, i)
		row:SetAttribute("EditableQuestGenerated", true)
		questRows[i] = row
	end
end

local function updateRow(row, quest, index)
	local progress = tonumber(quest.progress) or 0
	local target = math.max(1, tonumber(quest.target) or 1)
	local complete = progress >= target
	local claimed = quest.claimed == true

	setText(findDeep(row, "IconText"), index == 1 and "TASK" or index == 2 and "COINS" or "BRUSH")
	setText(findDeep(row, "QuestTitle"), tostring(quest.title or "Daily Quest"))
	setText(findDeep(row, "QuestDesc"), tostring(quest.description or ""))
	setText(findDeep(row, "ProgressText"), tostring(progress) .. " / " .. tostring(target))
	setText(findDeep(row, "RewardText"), "REWARD\nx" .. tostring(quest.reward or 0))

	local fill = findDeep(row, "ProgressFill")
	if fill and fill:IsA("GuiObject") then
		fill.Size = UDim2.fromScale(math.clamp(progress / target, 0, 1), 1)
	end

	local claim = findDeep(row, "ClaimButton")
	if claim and claim:IsA("TextButton") then
		if claimed then
			claim.Text = "CLAIMED"
			claim.BackgroundColor3 = COLORS.Disabled
			claim.Active = false
			claim.AutoButtonColor = false
		elseif complete then
			claimButton.Text = "CLAIM"
			claimButton.MouseButton1Click:Connect(function()
				claimButton.Text = "..."
				claimButton.Active = false
				remote:FireServer("Claim", index)
			end)
		else
			claimButton.Text = "LOCKED"
			claimButton.Active = false
		end
	end
end

local function render(window, data)
	if not window or not data then return end
	questData = data
	ensureRows(window)

	setText(findDeep(window, "TimerText"), "NEW QUESTS IN " .. formatTime(data.resetIn))
	setText(findDeep(window, "ResetText"), "Resets in: " .. formatTime(data.resetIn))

	for index, quest in ipairs(data.quests or {}) do
		local row = questRows[index]
		if row then
			row.Visible = true
			updateRow(row, quest, index)
		end
	end
	for index = #(data.quests or {}) + 1, #questRows do
		questRows[index].Visible = false
	end
end

local mainHUD = getMainHUD()
local windows = mainHUD and getWindows(mainHUD)
local dailyWindow = windows and windows:WaitForChild("DailyQuestsWindow", 30)

local function openGui()
	if dailyWindow then
		dailyWindow.Visible = true
	end
	remote:FireServer("Get")
end

local function closeGui()
	if dailyWindow then
		dailyWindow.Visible = false
	end
end

remote.OnClientEvent:Connect(function(action, data)
	if action == "Open" or action == "Update" then
		if dailyWindow then
			render(dailyWindow, data)
		end
	elseif action == "Locked" then
		closeGui()
	end
end)

UIManager.register("DailyQuests", openGui, closeGui, function()
	return dailyWindow and dailyWindow.Visible == true
end)

local dailyQuestButton = ReplicatedStorage:WaitForChild("HudButton_DAILYQUESTS", 10)
if dailyQuestButton then
	dailyQuestButton.Event:Connect(openGui)
end

if dailyWindow then
	remote:FireServer("Get")
else
	warn("DailyQuestClient: editable DailyQuestsWindow missing; old runtime UI creation is disabled.")
end
