-- Binds the Studio-authored RankWindow bones. This script never creates UI.
local Players = game:GetService("Players")

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
	ProgressLabel = findDescendant(content, "ProgressLabel", "TextLabel", ROOT_PATH .. ".Content.ProgressLabel"),
	ProgressPercent = findDescendant(content, "ProgressPercent", "TextLabel", ROOT_PATH .. ".Content.ProgressPercent"),
	ProgressFill = findDescendant(content, "ProgressFill", "GuiObject", ROOT_PATH .. ".Content.ProgressFill"),
	PerkCoins = findDescendant(content, "PerkCoins", "TextLabel", ROOT_PATH .. ".Content.PerkCoins"),
	PerkLuck = findDescendant(content, "PerkLuck", "TextLabel", ROOT_PATH .. ".Content.PerkLuck"),
	PerkSlots = findDescendant(content, "PerkSlots", "TextLabel", ROOT_PATH .. ".Content.PerkSlots"),
}

local function setText(object, value)
	if object and (object:IsA("TextLabel") or object:IsA("TextButton")) then
		object.Text = tostring(value or "")
	end
end

local function findValue(names)
	local leaderstats = player:FindFirstChild("leaderstats")
	for _, name in ipairs(names) do
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

local function update()
	local rankName = findValue({ "RankName", "Rank", "CurrentRank" }) or "RANK I"
	local rankLevel = tonumber(findValue({ "RankLevel", "Level" })) or 1
	local xp = tonumber(findValue({ "RankXP", "XP", "Experience" })) or 0
	local nextXp = tonumber(findValue({ "NextRankXP", "RankXPRequired", "XPRequired" })) or 2500
	nextXp = math.max(1, nextXp)

	local progress = math.clamp(xp / nextXp, 0, 1)
	setText(ui.RankName, tostring(rankName))
	setText(ui.RankIconText, tostring(rankLevel))
	setText(ui.ProgressLabel, tostring(math.floor(xp)) .. " / " .. tostring(math.floor(nextXp)) .. " XP")
	setText(ui.ProgressPercent, tostring(math.floor(progress * 100 + 0.5)) .. "%")
	setText(ui.PerkCoins, "+10% Coins")
	setText(ui.PerkLuck, "+5% Hatch Luck")
	setText(ui.PerkSlots, "+1 Equip Slot")
	if ui.ProgressFill then
		ui.ProgressFill.Size = UDim2.fromScale(progress, 1)
	end
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

player.ChildAdded:Connect(function(child)
	if child.Name == "leaderstats" then
		connectLeaderstats()
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
	"NextRankXP",
	"RankXPRequired",
	"XPRequired",
}) do
	player:GetAttributeChangedSignal(attributeName):Connect(update)
end

connectLeaderstats()
update()

print("[EditableRankBinder] RankWindow bound to existing Studio UI.")
