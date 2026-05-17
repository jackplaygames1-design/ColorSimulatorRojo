-- Binds the Studio-authored RankWindow bones. If optional rank controls are
-- missing, this creates clearly named placeholders inside the existing UI so
-- they can be copied into Studio and edited later.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local ClientUIRoot = require(ReplicatedStorage:WaitForChild("ClientUIRoot"))
local Events = ReplicatedStorage:WaitForChild("Events")
local rankDataUpdated = Events:WaitForChild("RankDataUpdated")
local rankUpRequest = Events:WaitForChild("RankUpRequest")
local rankUpResult = Events:WaitForChild("RankUpResult")
local rebirthRequest = Events:WaitForChild("RebirthRequest")
local rebirthResult = Events:WaitForChild("RebirthResult")
local rankMenuOpened = Events:WaitForChild("RankMenuOpened")

local ROOT_PATH = "PlayerGui.MainHUD.ModalWindows.RankWindow"
local warned = {}

local function warnOnce(path)
	if warned[path] then
		return
	end
	warned[path] = true
	warn("EditableRankBinder: missing " .. path)
end

local function findDescendant(parent, name, className, path)
	local object = parent and parent:FindFirstChild(name, true)
	if not object then
		warnOnce(path or (ROOT_PATH .. "." .. name))
		return nil
	end
	if className and not object:IsA(className) then
		warn("EditableRankBinder: " .. (path or object:GetFullName()) .. " must be a " .. className)
		return nil
	end
	return object
end

local mainHud = ClientUIRoot.GetRoot(playerGui)
if not mainHud then
	warnOnce("PlayerGui.MainHUD")
	return
end

local modalWindows = mainHud:WaitForChild("ModalWindows", 20)
if not modalWindows then
	warnOnce("PlayerGui.MainHUD.ModalWindows")
	return
end
modalWindows = modalWindows:FindFirstChild("Windows") or modalWindows

local rankWindow = modalWindows:WaitForChild("RankWindow", 20)
if not rankWindow or not rankWindow:IsA("GuiObject") then
	warnOnce(ROOT_PATH)
	return
end

local content = rankWindow:FindFirstChild("Content")
if not content then
	warnOnce(ROOT_PATH .. ".Content")
	return
end

local ui = {
	RankName = findDescendant(content, "RankName", "TextLabel", ROOT_PATH .. ".Content.RankName"),
	RankIconText = findDescendant(content, "RankIconText", "TextLabel", ROOT_PATH .. ".Content.RankIconText"),
	ProgressTitle = findDescendant(content, "ProgressTitle", "TextLabel", ROOT_PATH .. ".Content.ProgressTitle"),
	ProgressLabel = findDescendant(content, "ProgressLabel", "TextLabel", ROOT_PATH .. ".Content.ProgressLabel"),
	ProgressPercent = findDescendant(content, "ProgressPercent", "TextLabel", ROOT_PATH .. ".Content.ProgressPercent"),
	ProgressFill = findDescendant(content, "ProgressFill", "GuiObject", ROOT_PATH .. ".Content.ProgressFill"),
	PerkCoins = findDescendant(content, "PerkCoins", "TextLabel", ROOT_PATH .. ".Content.PerkCoins"),
	PerkLuck = findDescendant(content, "PerkLuck", "TextLabel", ROOT_PATH .. ".Content.PerkLuck"),
	PerkSlots = findDescendant(content, "PerkSlots", "TextLabel", ROOT_PATH .. ".Content.PerkSlots"),
}

local latestPayload = nil
local rankHudButton = mainHud:FindFirstChild("RankButton", true)
local rankHudLabel = rankHudButton and rankHudButton:FindFirstChild("Label", true)

local function ensureFrame(parent, name, position, size, color)
	local frame = parent:FindFirstChild(name)
	if frame and frame:IsA("Frame") then
		return frame
	end
	frame = Instance.new("Frame")
	frame.Name = name
	frame.Position = position
	frame.Size = size
	frame.BackgroundColor3 = color or Color3.fromRGB(12, 14, 20)
	frame.BorderSizePixel = 0
	frame.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 45, 52)
	stroke.Thickness = 1
	stroke.Transparency = 0.25
	stroke.Parent = frame
	return frame
end

local function ensureText(parent, name, position, size, textSize)
	local label = parent:FindFirstChild(name)
	if label and label:IsA("TextLabel") then
		return label
	end
	label = Instance.new("TextLabel")
	label.Name = name
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(245, 248, 255)
	label.TextScaled = true
	label.TextWrapped = true
	label.TextSize = textSize or 16
	label.Parent = parent
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize = 9
	limit.MaxTextSize = textSize or 16
	limit.Parent = label
	return label
end

local function ensureButton(parent, name, position, size, text)
	local button = parent:FindFirstChild(name)
	if button and button:IsA("TextButton") then
		return button
	end
	button = Instance.new("TextButton")
	button.Name = name
	button.Position = position
	button.Size = size
	button.BackgroundColor3 = Color3.fromRGB(170, 18, 22)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBlack
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextScaled = true
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 55, 62)
	stroke.Thickness = 2
	stroke.Parent = button
	return button
end

local questPanel = ensureFrame(content, "RankQuestPanel", UDim2.fromScale(0.04, 0.72), UDim2.fromScale(0.92, 0.2))
local questTitle =
	ensureText(questPanel, "QuestPanelTitle", UDim2.fromScale(0.03, 0.025), UDim2.fromScale(0.94, 0.08), 18)
questTitle.Text = "RANK QUESTS"
questTitle.TextColor3 = Color3.fromRGB(255, 72, 78)
questTitle.TextXAlignment = Enum.TextXAlignment.Left
local questText = ensureText(questPanel, "QuestListText", UDim2.fromScale(0.03, 0.06), UDim2.fromScale(0.94, 0.88), 13)
questText.TextXAlignment = Enum.TextXAlignment.Left
questText.TextYAlignment = Enum.TextYAlignment.Top
questText.TextScaled = false
questText.TextSize = 15
questText.Font = Enum.Font.GothamBold
local rankUpButton =
	ensureButton(content, "RankUpButton", UDim2.fromScale(0.16, 0.93), UDim2.fromScale(0.3, 0.055), "RANK UP")
local rebirthButton =
	ensureButton(content, "RebirthButton", UDim2.fromScale(0.54, 0.93), UDim2.fromScale(0.3, 0.055), "REBIRTH")

local rankModal = mainHud:FindFirstChild("RankUpModal")
if not (rankModal and rankModal:IsA("Frame")) then
	rankModal =
		ensureFrame(mainHud, "RankUpModal", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), Color3.fromRGB(0, 0, 0))
	rankModal.BackgroundTransparency = 0.18
	rankModal.Visible = false
	rankModal.ZIndex = 9000
end
local rankModalCard =
	ensureFrame(rankModal, "Card", UDim2.fromScale(0.28, 0.24), UDim2.fromScale(0.44, 0.5), Color3.fromRGB(9, 10, 15))
rankModalCard.ZIndex = 9001
local modalTitle = ensureText(rankModalCard, "Title", UDim2.fromScale(0.05, 0.08), UDim2.fromScale(0.9, 0.16), 36)
modalTitle.Font = Enum.Font.GothamBlack
modalTitle.TextColor3 = Color3.fromRGB(255, 55, 62)
local modalBody = ensureText(rankModalCard, "Body", UDim2.fromScale(0.08, 0.28), UDim2.fromScale(0.84, 0.42), 18)
local modalContinue =
	ensureButton(rankModalCard, "ContinueButton", UDim2.fromScale(0.26, 0.78), UDim2.fromScale(0.48, 0.13), "CONTINUE")

local originalLayouts = {}

local function getViewportSize()
	local camera = Workspace.CurrentCamera
	return camera and camera.ViewportSize or Vector2.new(1280, 720)
end

local function isMobileLayout()
	local viewport = getViewportSize()
	local minAxis = math.min(viewport.X, viewport.Y)
	local maxAxis = math.max(viewport.X, viewport.Y)
	return UserInputService.TouchEnabled and (minAxis <= 1024 or maxAxis <= 1280)
end

local function captureOriginalLayout(object)
	if not object or originalLayouts[object] then
		return
	end
	originalLayouts[object] = {
		Position = object.Position,
		Size = object.Size,
		TextSize = object:IsA("TextLabel") and object.TextSize or nil,
		TextScaled = object:IsA("TextLabel") and object.TextScaled or nil,
	}
end

local function restoreOriginalLayout(object)
	local original = object and originalLayouts[object]
	if not original then
		return
	end
	object.Position = original.Position
	object.Size = original.Size
	if object:IsA("TextLabel") then
		object.TextScaled = original.TextScaled
		object.TextSize = original.TextSize
	end
end

local function setGuiLayout(object, position, size)
	if object and object:IsA("GuiObject") then
		object.Position = position
		object.Size = size
	end
end

local function applyQuestFocusedLayout()
	local header = content:FindFirstChild("CurrentRankHeader", true)
	local badge = content:FindFirstChild("RankBadge", true)
	local progressBar = content:FindFirstChild("ProgressBar", true)
	local perksTitle = content:FindFirstChild("PerksTitle", true)
	local perks = content:FindFirstChild("Perks", true)

	setGuiLayout(header, UDim2.fromScale(0.055, 0.02), UDim2.fromScale(0.42, 0.055))
	setGuiLayout(badge, UDim2.fromScale(0.055, 0.085), UDim2.fromScale(0.15, 0.18))
	setGuiLayout(ui.RankIconText, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1))
	setGuiLayout(ui.RankName, UDim2.fromScale(0.225, 0.095), UDim2.fromScale(0.36, 0.09))
	setGuiLayout(ui.ProgressTitle, UDim2.fromScale(0.6, 0.07), UDim2.fromScale(0.32, 0.055))
	setGuiLayout(progressBar, UDim2.fromScale(0.58, 0.145), UDim2.fromScale(0.36, 0.05))
	setGuiLayout(ui.ProgressLabel, UDim2.fromScale(0.58, 0.205), UDim2.fromScale(0.18, 0.045))
	setGuiLayout(ui.ProgressPercent, UDim2.fromScale(0.76, 0.205), UDim2.fromScale(0.18, 0.045))

	setGuiLayout(questPanel, UDim2.fromScale(0.055, 0.31), UDim2.fromScale(0.89, 0.49))
	setGuiLayout(questTitle, UDim2.fromScale(0.03, 0.025), UDim2.fromScale(0.94, 0.08))
	setGuiLayout(questText, UDim2.fromScale(0.03, 0.12), UDim2.fromScale(0.94, 0.84))

	setGuiLayout(perksTitle, UDim2.fromScale(0.055, 0.815), UDim2.fromScale(0.34, 0.045))
	setGuiLayout(perks, UDim2.fromScale(0.055, 0.86), UDim2.fromScale(0.55, 0.105))
	setGuiLayout(rankUpButton, UDim2.fromScale(0.64, 0.86), UDim2.fromScale(0.14, 0.07))
	setGuiLayout(rebirthButton, UDim2.fromScale(0.8, 0.86), UDim2.fromScale(0.14, 0.07))

	if header and header:IsA("TextLabel") then
		header.TextXAlignment = Enum.TextXAlignment.Left
	end
	if ui.RankName then
		ui.RankName.TextXAlignment = Enum.TextXAlignment.Left
		ui.RankName.TextScaled = true
	end
	if ui.ProgressTitle then
		ui.ProgressTitle.TextXAlignment = Enum.TextXAlignment.Center
	end
end

local function applyMobileRankLayout()
	applyQuestFocusedLayout()
	for _, object in ipairs({ ui.PerkCoins, ui.PerkLuck, ui.PerkSlots }) do
		captureOriginalLayout(object)
	end

	if not isMobileLayout() then
		for _, object in ipairs({ ui.PerkCoins, ui.PerkLuck, ui.PerkSlots }) do
			restoreOriginalLayout(object)
		end
		return
	end

	local perkWidth = 0.31
	local yOffset = -72
	for index, object in ipairs({ ui.PerkCoins, ui.PerkLuck, ui.PerkSlots }) do
		if object then
			object.Size = UDim2.new(perkWidth, -8, 0, 54)
			object.Position = UDim2.new(0.025 + (index - 1) * 0.325, 0, 1, yOffset)
			if object:IsA("TextLabel") then
				object.TextScaled = true
			end
		end
	end
end

local function setText(object, value)
	if object and (object:IsA("TextLabel") or object:IsA("TextButton")) then
		object.Text = tostring(value or "")
	end
end

local function formatNumber(value)
	value = math.floor(tonumber(value) or 0)
	local text = tostring(value)
	while true do
		local nextText, replacements = string.gsub(text, "^(-?%d+)(%d%d%d)", "%1,%2")
		text = nextText
		if replacements == 0 then
			break
		end
	end
	return text
end

local setProgressFill

local function formatMultiplier(multiplier, label)
	local bonus = math.floor(((tonumber(multiplier) or 1) - 1) * 100 + 0.5)
	return bonus > 0 and ("+" .. tostring(bonus) .. "% " .. label) or ("No " .. label)
end

local function formatPassives(passives)
	passives = type(passives) == "table" and passives or {}
	local rows = {
		formatMultiplier(passives.PetDamageMultiplier, "Pet Mining Damage"),
		formatMultiplier(passives.RewardMultiplier, "Coins/Gems From Breakables"),
		formatMultiplier(passives.EggLuckMultiplier, "Egg RNG Luck"),
	}
	local mutation = math.floor(((tonumber(passives.MutationChanceMultiplier) or 1) - 1) * 100 + 0.5)
	if mutation > 0 then
		table.insert(rows, "+" .. tostring(mutation) .. "% Mutation Chance")
	end
	return table.concat(rows, "\n")
end

local function setButtonEnabled(button, enabled, text)
	if not button then
		return
	end
	button.Active = enabled == true
	button.AutoButtonColor = enabled == true
	button.BackgroundColor3 = enabled and Color3.fromRGB(190, 22, 28) or Color3.fromRGB(46, 50, 60)
	button.TextTransparency = enabled and 0 or 0.35
	if text then
		button.Text = text
	end
end

local function setRankHudText(text)
	if rankHudLabel and rankHudLabel:IsA("TextLabel") then
		rankHudLabel.Text = text
		rankHudLabel.Visible = true
		rankHudLabel.TextWrapped = true
		rankHudLabel.TextScaled = true
	elseif rankHudButton and rankHudButton:IsA("TextButton") then
		rankHudButton.Text = text
	end
end

local function summarizeQuests(quests)
	local rows = {}
	for _, quest in ipairs(type(quests) == "table" and quests or {}) do
		local prefix = quest.Completed and "[x] " or "[ ] "
		table.insert(
			rows,
			string.format(
				"%s%d. %s  %s/%s",
				prefix,
				tonumber(quest.Index) or #rows + 1,
				tostring(quest.Text or "Quest"),
				formatNumber(quest.Progress),
				formatNumber(quest.Target)
			)
		)
	end
	return table.concat(rows, "\n")
end

local function updateFromPayload(payload, replayProgress)
	if type(payload) ~= "table" then
		return false
	end
	latestPayload = payload
	applyMobileRankLayout()

	local rankLevel = tonumber(payload.RankLevel) or 1
	local rankName = tostring(payload.RankName or ("Rank " .. tostring(rankLevel)))
	local xp = tonumber(payload.RankXP) or 0
	local required = math.max(tonumber(payload.RankXPRequired) or 0, 0)
	local completed = tonumber(payload.CompletedRankQuests) or 0
	local questsRequired = math.max(tonumber(payload.QuestsRequired) or 10, 1)
	local isMaxRank = rankLevel >= (tonumber(payload.MaxRank) or 5)
	local progress = required <= 0 and 1 or math.clamp(xp / math.max(1, required), 0, 1)

	setText(ui.RankName, "Rank " .. tostring(rankLevel) .. " - " .. rankName)
	setText(ui.RankIconText, tostring(payload.RankIcon or rankLevel))
	setText(ui.ProgressTitle, isMaxRank and "Max Rank" or "Rank Progress")
	setText(ui.ProgressLabel, formatNumber(xp) .. " / " .. formatNumber(required) .. " XP")
	setText(ui.ProgressPercent, "Quests " .. tostring(completed) .. " / " .. tostring(questsRequired))
	setText(ui.PerkCoins, formatMultiplier((payload.Passives or {}).RewardMultiplier, "Rewards"))
	setText(ui.PerkLuck, formatMultiplier((payload.Passives or {}).EggLuckMultiplier, "Hatch Luck"))
	setText(ui.PerkSlots, formatMultiplier((payload.Passives or {}).PetDamageMultiplier, "Pet Damage"))
	setText(questText, summarizeQuests(payload.Quests))
	setProgressFill(progress, replayProgress == true)

	if payload.RebirthAvailable == true then
		setRankHudText("REBIRTH\nREADY")
	elseif rankHudButton then
		setRankHudText(
			string.format(
				"RANK %d\n%s/%s XP\nQ %d/%d",
				rankLevel,
				formatNumber(xp),
				formatNumber(required),
				completed,
				questsRequired
			)
		)
	end

	setButtonEnabled(rankUpButton, payload.RankUpAvailable == true, payload.RankUpAvailable and "RANK UP" or "LOCKED")
	setButtonEnabled(
		rebirthButton,
		payload.RebirthAvailable == true,
		payload.RebirthAvailable and "REBIRTH" or ("REBIRTHS: " .. tostring(payload.Rebirths or 0))
	)
	return true
end

local function findValue(names)
	local rankData = player:FindFirstChild("RankData")
	local leaderstats = player:FindFirstChild("leaderstats")
	for _, name in ipairs(names) do
		local rankValue = rankData and rankData:FindFirstChild(name)
		if rankValue and rankValue:IsA("ValueBase") then
			return rankValue.Value
		end
		local value = leaderstats and leaderstats:FindFirstChild(name)
		if value and value:IsA("ValueBase") then
			return value.Value
		end
		local attribute = player:GetAttribute(name)
		if attribute ~= nil then
			return attribute
		end
	end
	return nil
end

local activeProgressTween = nil

setProgressFill = function(progress, replayFromStart)
	if not ui.ProgressFill then
		return
	end

	local targetSize = UDim2.fromScale(progress, 1)
	if activeProgressTween then
		activeProgressTween:Cancel()
		activeProgressTween = nil
	end

	if rankWindow.Visible then
		if replayFromStart then
			ui.ProgressFill.Size = UDim2.fromScale(0, 1)
		end
		activeProgressTween = TweenService:Create(
			ui.ProgressFill,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = targetSize }
		)
		activeProgressTween:Play()
	else
		ui.ProgressFill.Size = targetSize
	end
end

local function update(replayProgress)
	if latestPayload and updateFromPayload(latestPayload, replayProgress) then
		return
	end
	applyMobileRankLayout()
	local rankName = findValue({ "RankName", "Rank", "CurrentRank" }) or "RANK I"
	local rankLevel = tonumber(findValue({ "RankLevel", "Level" })) or 1
	local xp = tonumber(findValue({ "RankXP", "XP", "Experience" })) or 0
	local nextXp = tonumber(findValue({ "NextRankXP", "RankXPRequired", "XPRequired" })) or 2500
	local maxRank = tonumber(findValue({ "RankMaxRank" })) or 5
	local isMaxed = findValue({ "RankIsMaxed" }) == true or rankLevel >= maxRank or nextXp <= 0
	local iconText = findValue({ "RankIcon" }) or rankLevel
	local coinBonus = tonumber(findValue({ "RankCoinBonusPercent" })) or 10
	local luckBonus = tonumber(findValue({ "RankLuckBonusPercent" })) or 5
	local slots = tonumber(findValue({ "RankExtraEquipSlots" })) or 1

	nextXp = math.max(0, nextXp)
	local progress = isMaxed and 1 or math.clamp(xp / math.max(1, nextXp), 0, 1)
	setText(ui.RankName, tostring(rankName))
	setText(ui.RankIconText, tostring(iconText))
	setText(ui.ProgressTitle, isMaxed and "Max Rank Reached" or "Progress to Next Rank")
	setText(ui.ProgressLabel, isMaxed and "MAX RANK" or (formatNumber(xp) .. " / " .. formatNumber(nextXp) .. " XP"))
	setText(ui.ProgressPercent, tostring(math.floor(progress * 100 + 0.5)) .. "%")
	setText(ui.PerkCoins, "+" .. tostring(coinBonus) .. "% Coins")
	setText(ui.PerkLuck, "+" .. tostring(luckBonus) .. "% Hatch Luck")
	setText(ui.PerkSlots, "+" .. tostring(slots) .. " Equip Slot" .. (slots == 1 and "" or "s"))
	setProgressFill(progress, replayProgress == true)
end

local function showModal(title, body)
	modalTitle.Text = title
	modalBody.Text = body
	rankModal.Visible = true
	rankModal.BackgroundTransparency = 1
	rankModalCard.Position = UDim2.fromScale(0.28, 0.28)
	TweenService:Create(rankModal, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.18,
	}):Play()
	TweenService:Create(rankModalCard, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0.28, 0.24),
	}):Play()
end

local function requestRankData()
	rankMenuOpened:FireServer()
end

local function connectValue(value)
	if value and value:IsA("ValueBase") then
		value.Changed:Connect(update)
	end
end

local function connectLeaderstats()
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end
	for _, child in ipairs(leaderstats:GetChildren()) do
		connectValue(child)
	end
	leaderstats.ChildAdded:Connect(function(child)
		connectValue(child)
		update()
	end)
end

local function connectRankData()
	local rankData = player:FindFirstChild("RankData")
	if not rankData then
		return
	end
	for _, child in ipairs(rankData:GetChildren()) do
		connectValue(child)
	end
	rankData.ChildAdded:Connect(function(child)
		connectValue(child)
		update()
	end)
end

player.ChildAdded:Connect(function(child)
	if child.Name == "leaderstats" then
		connectLeaderstats()
		update()
	elseif child.Name == "RankData" then
		connectRankData()
		update()
	end
end)

for _, attributeName in ipairs({
	"RankName",
	"Rank",
	"CurrentRank",
	"RankLevel",
	"Level",
	"RankXP",
	"XP",
	"Experience",
	"RankIcon",
	"NextRankXP",
	"RankXPRequired",
	"XPRequired",
	"RankMaxRank",
	"RankIsMaxed",
	"RankCoinBonusPercent",
	"RankLuckBonusPercent",
	"RankExtraEquipSlots",
}) do
	player:GetAttributeChangedSignal(attributeName):Connect(update)
end

rankWindow:GetPropertyChangedSignal("Visible"):Connect(function()
	update(rankWindow.Visible)
	if rankWindow.Visible then
		requestRankData()
	end
end)
rankWindow:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyMobileRankLayout)
local camera = Workspace.CurrentCamera
if camera then
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyMobileRankLayout)
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	local currentCamera = Workspace.CurrentCamera
	if currentCamera then
		currentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applyMobileRankLayout)
	end
	applyMobileRankLayout()
end)

connectLeaderstats()
connectRankData()
update()

rankDataUpdated.OnClientEvent:Connect(function(payload)
	updateFromPayload(payload, rankWindow.Visible)
end)

rankUpButton.Activated:Connect(function()
	rankUpRequest:FireServer()
end)

rebirthButton.Activated:Connect(function()
	rebirthRequest:FireServer()
end)

modalContinue.Activated:Connect(function()
	rankModal.Visible = false
end)

rankUpResult.OnClientEvent:Connect(function(success, result)
	result = type(result) == "table" and result or {}
	if result.RankData then
		updateFromPayload(result.RankData, true)
	end
	if not success then
		showModal("KEEP GOING!", tostring(result.Message or "Complete Rank XP and all 10 quests first."))
		return
	end
	local body = string.format(
		"%s -> %s\n\nRewards\n+%s Coins\n+%s Gems\n\nNew Passives\n%s",
		tostring(result.OldRankName or "Previous Rank"),
		tostring(result.NewRankName or "New Rank"),
		formatNumber(result.RewardCoins),
		formatNumber(result.RewardGems),
		formatPassives(result.Passives)
	)
	showModal("YOU'VE RANKED UP!", body)
end)

rebirthResult.OnClientEvent:Connect(function(success, result)
	result = type(result) == "table" and result or {}
	if result.RankData then
		updateFromPayload(result.RankData, true)
	end
	if not success then
		showModal("REBIRTH LOCKED", tostring(result.Message or "Reach Rank 5 and complete every requirement first."))
		return
	end
	showModal("REBIRTH COMPLETE!", "Permanent bonuses increased.\n\nRebirths: " .. formatNumber(result.Rebirths or 0))
end)

if rankWindow.Visible then
	requestRankData()
end

print("[EditableRankBinder] RankWindow bound to existing Studio UI.")
