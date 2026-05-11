-- Binds baked Zork prompts to editable Studio windows.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Events = ReplicatedStorage:WaitForChild("Events")
local dailyQuestRemote = Events:FindFirstChild("DailyQuestRemote")

local root = playerGui:WaitForChild("ClientUIRoot", 15)
if not root then
	warn("ZorkDialogueBinder: missing ClientUIRoot")
	return
end

local mainHud = root:WaitForChild("MainHUD", 15)
local windowsFolder = mainHud
	and mainHud:WaitForChild("ModalWindows", 10)
	and mainHud.ModalWindows:WaitForChild("Windows", 10)

if not windowsFolder then
	warn("ZorkDialogueBinder: missing editable windows folder")
	return
end

local window = windowsFolder:FindFirstChild("ZorkDialogueWindow")
if not window or not window:IsA("GuiObject") then
	warn("ZorkDialogueBinder: add editable ZorkDialogueWindow with StudioMenuWindowsBuilder.")
	return
end

local body = window:FindFirstChild("Body", true)
local speakerName = window:FindFirstChild("SpeakerName", true)
local speakerRole = window:FindFirstChild("SpeakerRole", true)
local shopButton = window:FindFirstChild("ShopButton", true)
local questsButton = window:FindFirstChild("QuestsButton", true)
local closeButton = window:FindFirstChild("CloseButton", true)

local function setText(instance, value)
	if instance and (instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox")) then
		instance.Text = value
	end
end

local function requestWindow(windowName)
	root:SetAttribute("RequestedWindow", windowName)
	root:SetAttribute("RequestedWindowNonce", os.clock())
end

local function openDialogue(colorType)
	local firstSector = colorType == nil or colorType == "" or colorType == "Red"

	setText(speakerName, "Zork")
	setText(speakerRole, firstSector and "Brush Merchant + Daily Quests" or "Daily Quest Keeper")
	setText(
		body,
		firstSector
				and "zzt. hey, i'm Zork.\n\nI sell starter brushes for the first sector, and I keep daily quests ready when you need gems."
			or "zzt. this brush shop is only for the first sector.\n\nI can still help you check daily quests."
	)

	if shopButton and shopButton:IsA("GuiObject") then
		shopButton.Visible = firstSector
		shopButton.Active = firstSector
	end
	if questsButton and questsButton:IsA("GuiObject") then
		questsButton.Visible = true
		questsButton.Active = true
	end

	requestWindow("ZorkDialogueWindow")
end

local function closeDialogue()
	window.Visible = false
end

local function connectButton(guiObject, callback)
	if not guiObject or guiObject:GetAttribute("ZorkDialogueBound") == true then
		return
	end
	guiObject:SetAttribute("ZorkDialogueBound", true)
	if guiObject:IsA("GuiButton") then
		guiObject.Activated:Connect(callback)
	end
	for _, child in ipairs(guiObject:GetDescendants()) do
		if child:IsA("GuiButton") then
			child.Activated:Connect(callback)
		end
	end
end

connectButton(closeButton, closeDialogue)
connectButton(shopButton, function()
	closeDialogue()
	requestWindow("BrushShopWindow")
end)
connectButton(questsButton, function()
	if dailyQuestRemote then
		dailyQuestRemote:FireServer("UnlockFromZork")
	end
	closeDialogue()
	requestWindow("DailyQuestsWindow")
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeringPlayer)
	if triggeringPlayer ~= player then
		return
	end
	if not (prompt:GetAttribute("BrushNpcDialogue") == true or prompt:GetAttribute("BrushShopPrompt") == true) then
		return
	end

	openDialogue(tostring(prompt:GetAttribute("ShopColor") or prompt:GetAttribute("ColorType") or "Red"))
end)

print("[ZorkDialogueBinder] editable Zork dialogue ready.")
