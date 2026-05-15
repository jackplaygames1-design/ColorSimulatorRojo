-- Binds the Studio-authored RankWindow bones. This script never creates UI.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

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

local mainHud = playerGui:WaitForChild("MainHUD", 20)
if not mainHud then
	warnOnce("PlayerGui.MainHUD")
	return
end

local modalWindows = mainHud:WaitForChild("ModalWindows", 20)
if not modalWindows then
	warnOnce("PlayerGui.MainHUD.ModalWindows")
	return
end

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

local originalLayouts = {}

local function getViewportSize()
	local camera = Workspace.CurrentCamera
	return camera and camera.ViewportSize or Vector2.new(1280, 720)
end

local function isMobileLayout()
	local viewport = getViewportSize()
	return UserInputService.TouchEnabled
		and not UserInputService.KeyboardEnabled
		and math.min(viewport.X, viewport.Y) <= 900
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

local function applyMobileRankLayout()
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

local function setProgressFill(progress, replayFromStart)
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

print("[EditableRankBinder] RankWindow bound to existing Studio UI.")
