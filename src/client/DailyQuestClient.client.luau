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
	return player:WaitForChild("PlayerGui"):WaitForChild("MainHUD", 30)
end

local function getWindows(mainHUD)
	local modalWindows = mainHUD and mainHUD:FindFirstChild("ModalWindows")
	return modalWindows
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

local function getQuestList(data)
	local source = type(data) == "table" and (data.Quests or data.quests) or nil
	local quests = {}
	if type(source) == "table" then
		for index = 1, 3 do
			if type(source[index]) == "table" then
				quests[index] = source[index]
			end
		end
	end
	for index = 1, 3 do
		if type(quests[index]) ~= "table" then
			quests[index] = {}
		end
	end
	return quests
end

local function hasQuestList(data)
	local source = type(data) == "table" and (data.Quests or data.quests) or nil
	return type(source) == "table"
end

local function getQuestContent(window)
	return findDeep(window, "QuestList") or findDeep(window, "Body") or findDeep(window, "Content") or window
end

local function ensureRows(window)
	local content = getQuestContent(window)
	if not content then
		return
	end
	questRows = {}
	for i = 1, 3 do
		local row = findDeep(content, "QuestRow" .. i)
		if row and row:IsA("GuiObject") then
			questRows[i] = row
		else
			warn(
				"DailyQuestClient: missing Studio-authored QuestRow"
					.. tostring(i)
					.. ". Run StudioMenuWindowsBuilder.UpdateZorkWindows()."
			)
		end
	end
end

local function updateRow(row, quest, index)
	local progress = tonumber(quest.progress) or 0
	local target = math.max(1, tonumber(quest.target) or 1)
	local complete = progress >= target
	local claimed = quest.claimed == true
	local rewardAmount = tonumber(quest.rewardAmount or quest.reward) or 0
	local rewardCurrency = tostring(quest.rewardCurrency or "Gems")

	setText(
		findDeep(row, "IconText"),
		tostring(quest.iconText or (index == 1 and "BRUSH" or index == 2 and "COINS" or "EGG"))
	)
	setText(findDeep(row, "QuestTitle") or findDeep(row, "Name"), tostring(quest.title or "Daily Quest"))
	setText(findDeep(row, "QuestDesc") or findDeep(row, "Description"), tostring(quest.description or ""))
	setText(findDeep(row, "ProgressText"), tostring(progress) .. " / " .. tostring(target))
	setText(findDeep(row, "RewardText"), "REWARD\n+" .. tostring(rewardAmount) .. " " .. rewardCurrency)

	local fill = findDeep(row, "ProgressFill")
	if fill and fill:IsA("GuiObject") then
		fill.Size = UDim2.fromScale(math.clamp(progress / target, 0, 1), 1)
	end

	local claim = findDeep(row, "ClaimButton") or findDeep(row, "BuyButton")
	if not claim or not claim:IsA("TextButton") then
		return
	end

	claim:SetAttribute("QuestIndex", index)
	claim:SetAttribute("Claimable", false)
	claim:SetAttribute("Claiming", false)

	if claimed then
		claim.Text = "CLAIMED"
		claim.BackgroundColor3 = COLORS.Disabled
		claim.Active = false
		claim.AutoButtonColor = false
	elseif complete then
		claim.Text = "CLAIM"
		claim.BackgroundColor3 = COLORS.Cyan
		claim.Active = true
		claim.AutoButtonColor = true
		claim:SetAttribute("Claimable", true)
	else
		claim.Text = "IN PROGRESS"
		claim.BackgroundColor3 = COLORS.Disabled
		claim.Active = false
		claim.AutoButtonColor = false
	end

	if not claim:GetAttribute("ClaimHooked") then
		claim:SetAttribute("ClaimHooked", true)

		claim.MouseButton1Click:Connect(function()
			if not claim:GetAttribute("Claimable") then
				return
			end

			if claim:GetAttribute("Claiming") then
				return
			end

			local questIndex = claim:GetAttribute("QuestIndex")
			if not questIndex then
				return
			end

			claim:SetAttribute("Claiming", true)
			claim.Active = false
			claim.AutoButtonColor = false
			claim.Text = "..."

			remote:FireServer("Claim", questIndex)
		end)
	end
end

local function render(window, data)
	if not window then
		return
	end
	data = type(data) == "table" and data or {}
	questData = data

	local content = getQuestContent(window)
	local binderList = content and content:FindFirstChild("BinderList")
	if binderList and binderList:IsA("GuiObject") then
		binderList.Visible = false
	end

	ensureRows(window)

	if data.resetIn ~= nil then
		setText(findDeep(window, "TimerText"), "NEW QUESTS IN " .. formatTime(data.resetIn))
		setText(findDeep(window, "ResetText"), "Resets in: " .. formatTime(data.resetIn))
	end

	if not hasQuestList(data) then
		return
	end

	local quests = getQuestList(data)
	for index = 1, 3 do
		local quest = quests[index]
		local row = questRows[index]
		if row then
			row.Visible = true
			updateRow(row, quest, index)
		end
	end
end

local mainHUD = getMainHUD()
local windows = mainHUD and getWindows(mainHUD)
local dailyWindow = windows and windows:WaitForChild("DailyQuestsWindow", 30)

local function openGui()
	if dailyWindow then
		dailyWindow.Visible = true
		render(dailyWindow, questData or {})
	end
	remote:FireServer("Get")
end

local function closeGui()
	if dailyWindow then
		dailyWindow.Visible = false
	end
end

remote.OnClientEvent:Connect(function(action, data)
	if action == "Open" or action == "Update" or action == "Locked" then
		if dailyWindow then
			render(dailyWindow, data)
		end
	end
end)

UIManager.register("DailyQuests", openGui, closeGui, function()
	return dailyWindow and dailyWindow.Visible == true
end)

local dailyQuestButton = ReplicatedStorage:WaitForChild("HudButton_DAILYQUESTS", 10)
if dailyQuestButton then
	dailyQuestButton.Event:Connect(function()
		if dailyWindow and dailyWindow.Visible then
			remote:FireServer("Get")
		end
	end)
end

if dailyWindow then
	render(dailyWindow, {})
	dailyWindow:GetPropertyChangedSignal("Visible"):Connect(function()
		if dailyWindow.Visible then
			render(dailyWindow, questData or {})
			remote:FireServer("Get")
		end
	end)
	remote:FireServer("Get")
else
	warn("DailyQuestClient: missing PlayerGui.MainHUD.ModalWindows.DailyQuestsWindow")
end
