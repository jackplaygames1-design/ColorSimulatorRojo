-- Binds editable Studio Core RNG UI. This script never creates ScreenGuis or
-- replacement UI; missing objects are reported with their expected names.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ClientUIRoot = require(ReplicatedStorage:WaitForChild("ClientUIRoot"))
local CoreDefinitions = require(ReplicatedStorage:WaitForChild("CoreDefinitions"))
local MutationDefinitions = require(ReplicatedStorage:WaitForChild("MutationDefinitions"))
local RarityDefinitions = require(ReplicatedStorage:WaitForChild("RarityDefinitions"))

local Events = ReplicatedStorage:WaitForChild("Events")
local coreRollRequest = Events:WaitForChild("CoreRollRequest")
local coreRollResult = Events:WaitForChild("CoreRollResult")
local coreRollAnnouncement = Events:WaitForChild("CoreRollAnnouncement")
local coreRollState = Events:WaitForChild("CoreRollState")

local RED_CORE_ID = "RedCore"
local core = CoreDefinitions.Get(RED_CORE_ID)
local warned = {}
local rollBusy = false
local currentCurrencyAmount = 0
local mutationsUnlocked = player:GetAttribute("MutationsUnlocked") == true
local oddsOpen = false

local coreGui = playerGui:WaitForChild("CoreRNGGui", 10)
local mainHud = playerGui:FindFirstChild("MainHUD") or coreGui or ClientUIRoot.GetRoot(playerGui)
local modalRoot = mainHud and mainHud:FindFirstChild("ModalWindows")
local windowsRoot = modalRoot and (modalRoot:FindFirstChild("Windows") or modalRoot)

local function warnOnce(key, message)
	if warned[key] then
		return
	end
	warned[key] = true
	warn(message)
end

local function findDescendantByNames(parent, names)
	if not parent then
		return nil
	end
	for _, name in ipairs(names) do
		local found = parent:FindFirstChild(name, true)
		if found then
			return found
		end
	end
	return nil
end

local function findWindow(name)
	local found = windowsRoot and windowsRoot:FindFirstChild(name, true)
	if found and found:IsA("GuiObject") then
		return found
	end
	found = mainHud and mainHud:FindFirstChild(name, true)
	if found and found:IsA("GuiObject") then
		return found
	end
	found = coreGui and coreGui:FindFirstChild(name, true)
	if found and found:IsA("GuiObject") then
		return found
	end
	return nil
end

local coreWindow = findWindow("CoreRollWindow")
local hatchReveal = findWindow("HatchReveal") or findWindow("CoreHatchReveal")

if not coreWindow then
	warnOnce(
		"missing-core-window",
		"CoreRollClient: missing editable MainHUD CoreRollWindow. Add CoreNameLabel, FoundLabel, CostLabel, RollButton, AutoButton, OddsButton, OddsPanel."
	)
end
if not hatchReveal then
	warnOnce(
		"missing-hatch-reveal",
		"CoreRollClient: missing editable MainHUD HatchReveal. Add DarkOverlay, RarityLabel, ColorNameLabel, MutationLabel, GlitchedLabel, ResultViewport or ResultImage."
	)
end

local ui = {
	coreName = findDescendantByNames(coreWindow, { "CoreNameLabel", "CoreName", "Title", "NameLabel" }),
	found = findDescendantByNames(coreWindow, { "FoundLabel", "FoundText", "CollectionLabel" }),
	cost = findDescendantByNames(coreWindow, { "CostLabel", "CostText", "PriceLabel" }),
	status = findDescendantByNames(coreWindow, { "StatusLabel", "MessageLabel", "HintLabel" }),
	rollButton = findDescendantByNames(coreWindow, { "RollButton", "Roll", "OpenButton" }),
	autoButton = findDescendantByNames(coreWindow, { "AutoButton", "Auto" }),
	oddsButton = findDescendantByNames(coreWindow, { "OddsButton", "Odds" }),
	oddsPanel = findDescendantByNames(coreWindow, { "OddsPanel", "OddsWindow", "OddsFrame" }),

	revealRarity = findDescendantByNames(hatchReveal, { "RarityLabel", "RarityText", "Rarity" }),
	revealName = findDescendantByNames(hatchReveal, { "ColorNameLabel", "ResultName", "ColorName", "NameLabel" }),
	revealMutation = findDescendantByNames(hatchReveal, { "MutationLabel", "MutationText", "Mutation" }),
	revealGlitched = findDescendantByNames(hatchReveal, { "GlitchedLabel", "GlitchedText", "Glitched" }),
}

local function setText(object, value)
	if object and (object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox")) then
		object.Text = tostring(value or "")
	end
end

local function setGuiVisible(object, visible)
	if object and object:IsA("GuiObject") then
		object.Visible = visible == true
	end
end

local function setButtonText(button, value)
	if not button then
		return
	end
	local label = findDescendantByNames(button, { "TextLabel", "Label", "Title", "ButtonText", "Name" })
	if label and label ~= button then
		setText(label, value)
		if button:IsA("TextButton") then
			button.Text = ""
		end
	else
		setText(button, value)
	end
end

local function connectButton(button, callback)
	if not button or not button:IsA("GuiButton") then
		return
	end
	button.MouseButton1Click:Connect(function()
		local originalSize = button.Size
		TweenService:Create(button, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(
				originalSize.X.Scale,
				math.floor(originalSize.X.Offset * 0.96),
				originalSize.Y.Scale,
				math.floor(originalSize.Y.Offset * 0.96)
			),
		}):Play()
		task.delay(0.07, function()
			if button and button.Parent then
				TweenService:Create(button, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					Size = originalSize,
				}):Play()
			end
		end)
		callback()
	end)
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

local function updateCoreStaticText()
	setText(ui.coreName, core.DisplayName or "RED CORE")
	setText(ui.found, core.FoundText or "8 / 14 Found")
	setText(ui.cost, "Cost: " .. CoreDefinitions.FormatCost(core))
	setButtonText(ui.rollButton, "ROLL")
	setButtonText(ui.autoButton, "AUTO")
	setButtonText(ui.oddsButton, "ODDS")
end

local function updateStatus(message)
	if message and tostring(message) ~= "" then
		setText(ui.status, message)
	elseif ui.status then
		setText(ui.status, "Red: " .. formatNumber(currentCurrencyAmount))
	end
end

local function populateOddsPanel()
	if not ui.oddsPanel or not ui.oddsPanel:IsA("GuiObject") then
		return
	end

	local lines = { "ODDS" }
	for _, row in ipairs(CoreDefinitions.GetOddsRows(RED_CORE_ID)) do
		table.insert(lines, row.Rarity .. " - 1 in " .. tostring(row.OneIn))
	end
	if mutationsUnlocked == true then
		table.insert(lines, "")
		table.insert(lines, "POSSIBLE MUTATIONS")
		for _, row in ipairs(CoreDefinitions.GetMutationRows()) do
			table.insert(lines, row.DisplayName)
		end
	end

	local labels = {}
	for _, descendant in ipairs(ui.oddsPanel:GetDescendants()) do
		if descendant:IsA("TextLabel") or descendant:IsA("TextButton") or descendant:IsA("TextBox") then
			table.insert(labels, descendant)
		end
	end
	table.sort(labels, function(a, b)
		if a.LayoutOrder ~= b.LayoutOrder then
			return a.LayoutOrder < b.LayoutOrder
		end
		return a.Name < b.Name
	end)

	if #labels == 0 then
		if ui.oddsPanel:IsA("TextLabel") or ui.oddsPanel:IsA("TextButton") or ui.oddsPanel:IsA("TextBox") then
			setText(ui.oddsPanel, table.concat(lines, "\n"))
		else
			warnOnce(
				"missing-odds-labels",
				"CoreRollClient: OddsPanel needs editable TextLabels for odds rows; no runtime labels were created."
			)
		end
		return
	end

	for index, label in ipairs(labels) do
		setText(label, lines[index] or "")
	end
end

local function getCorePart()
	local coreId = tostring(core.CoreId or RED_CORE_ID)
	local fallbackEggId = tostring(core.FallbackEggId or "")
	local bestPart = nil
	local bestScore = -math.huge
	for _, descendant in ipairs(workspace:GetDescendants()) do
		local candidatePart = nil
		local score = -math.huge
		if descendant:IsA("BasePart") then
			candidatePart = descendant
			if descendant:GetAttribute("CoreId") == coreId then
				score = 100
			elseif fallbackEggId ~= "" and descendant:GetAttribute("EggId") == fallbackEggId then
				score = 80
			elseif string.lower(descendant.Name) == string.lower(coreId) then
				score = 70
			elseif fallbackEggId ~= "" and string.lower(descendant.Name) == string.lower(fallbackEggId) then
				score = 55
			elseif
				string.find(string.lower(descendant.Name), "core", 1, true)
				and string.find(string.lower(descendant.Name), "red", 1, true)
			then
				score = 40
			end
		elseif descendant:IsA("Model") then
			if descendant:GetAttribute("CoreId") == coreId then
				candidatePart = descendant.PrimaryPart or descendant:FindFirstChildWhichIsA("BasePart", true)
				score = 95
			elseif fallbackEggId ~= "" and descendant:GetAttribute("EggId") == fallbackEggId then
				candidatePart = descendant.PrimaryPart or descendant:FindFirstChildWhichIsA("BasePart", true)
				score = 75
			end
		end
		if candidatePart and score > bestScore then
			bestPart = candidatePart
			bestScore = score
		end
	end
	return bestPart
end

local function getRootPart()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function updateCoreWindowVisibility()
	if not coreWindow then
		return
	end
	local corePart = getCorePart()
	if not corePart then
		warnOnce("missing-core-part", 'CoreRollClient: add CoreId="RedCore" to the editable Red Core model/part.')
		updateStatus("Red Core part is not tagged; showing Core UI for testing.")
		setGuiVisible(coreWindow, true)
		return
	end

	local root = getRootPart()
	local visible = false
	if root then
		visible = (root.Position - corePart.Position).Magnitude <= (tonumber(core.InteractionRadius) or 28)
	end
	setGuiVisible(coreWindow, visible)
	if not visible then
		setGuiVisible(ui.oddsPanel, false)
		oddsOpen = false
	end
end

local function setRevealText(result)
	local rarity = tostring(result.Rarity or "Common")
	local rarityData = RarityDefinitions.Get(rarity)
	setText(ui.revealRarity, string.upper(rarity))
	if ui.revealRarity and rarityData then
		ui.revealRarity.TextColor3 = rarityData.DisplayColor
	end
	setText(ui.revealName, string.upper(tostring(result.ColorName or "Color")))
	local mutation = MutationDefinitions.Get(result.Mutation)
	if mutation then
		setText(ui.revealMutation, string.upper(mutation.DisplayName) .. " MUTATION")
		if ui.revealMutation then
			ui.revealMutation.TextColor3 = mutation.TextColor
		end
	else
		setText(ui.revealMutation, "")
	end
	if result.IsGlitched == true and mutation then
		setText(ui.revealGlitched, "GLITCHED\n" .. string.upper(mutation.DisplayName))
	else
		setText(ui.revealGlitched, "")
	end
end

local function tweenTextPop(label, scale)
	if not label or not label:IsA("GuiObject") then
		return
	end
	local originalSize = label.Size
	TweenService:Create(label, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(
			originalSize.X.Scale * scale,
			originalSize.X.Offset,
			originalSize.Y.Scale * scale,
			originalSize.Y.Offset
		),
	}):Play()
	task.delay(0.12, function()
		if label and label.Parent then
			TweenService:Create(label, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = originalSize,
			}):Play()
		end
	end)
end

local function playReveal(payload)
	if not hatchReveal then
		return
	end
	local result = payload and payload.Result
	if type(result) ~= "table" then
		return
	end

	task.spawn(function()
		setGuiVisible(hatchReveal, true)
		setRevealText({
			Rarity = "Opening...",
			ColorName = "",
			Mutation = "None",
			IsGlitched = false,
		})
		task.wait(0.22)

		local rarity = tostring(result.Rarity or "Common")
		local intensity = (RarityDefinitions.Get(rarity) and RarityDefinitions.Get(rarity).RevealIntensity) or 1
		local spinTime = math.clamp(0.35 + intensity * 0.23, 0.55, 2.2)
		local rarities = RarityDefinitions.Order
		local startAt = os.clock()
		while os.clock() - startAt < spinTime do
			local rarityName = rarities[math.random(1, #rarities)]
			setText(ui.revealRarity, string.upper(rarityName))
			if ui.revealRarity then
				ui.revealRarity.TextColor3 = RarityDefinitions.GetDisplayColor(rarityName)
			end
			task.wait(0.08)
		end

		setRevealText(result)
		tweenTextPop(ui.revealRarity, 1.08)
		tweenTextPop(ui.revealName, 1.06)
		task.wait(0.42 + intensity * 0.08)

		local mutation = MutationDefinitions.Get(result.Mutation)
		if mutation then
			setText(ui.revealMutation, string.upper(mutation.DisplayName) .. " MUTATION")
			tweenTextPop(ui.revealMutation, 1.08)
			task.wait(result.IsGlitched and 0.45 or 0.25)
		end

		if result.IsGlitched == true and mutation then
			for _ = 1, 8 do
				setText(ui.revealGlitched, "GLITCHED\n" .. string.upper(mutation.DisplayName))
				if ui.revealGlitched then
					ui.revealGlitched.TextColor3 = Color3.fromRGB(math.random(150, 255), math.random(40, 160), 255)
				end
				task.wait(0.045)
				setText(ui.revealGlitched, "")
				task.wait(0.035)
			end
			setText(ui.revealGlitched, "GLITCHED\n" .. string.upper(mutation.DisplayName))
			task.wait(0.75)
		else
			task.wait(0.75)
		end

		setGuiVisible(hatchReveal, false)
	end)
end

local function sendChatMessage(payload)
	local text = type(payload) == "table" and tostring(payload.Text or "") or tostring(payload or "")
	if text == "" then
		return
	end

	local success = pcall(function()
		local channel = TextChatService.TextChannels and TextChatService.TextChannels:FindFirstChild("RBXGeneral")
		if channel then
			channel:DisplaySystemMessage('<font color="#ff4545">' .. text .. "</font>")
		else
			error("No TextChatService channel")
		end
	end)
	if not success then
		pcall(function()
			StarterGui:SetCore("ChatMakeSystemMessage", {
				Text = text,
				Color = Color3.fromRGB(255, 85, 95),
			})
		end)
	end
end

updateCoreStaticText()
populateOddsPanel()
setGuiVisible(coreWindow, false)
setGuiVisible(hatchReveal, false)
setGuiVisible(ui.oddsPanel, false)

connectButton(ui.rollButton, function()
	if rollBusy then
		return
	end
	rollBusy = true
	updateStatus("Rolling...")
	coreRollRequest:FireServer(RED_CORE_ID)
	task.delay(0.7, function()
		rollBusy = false
	end)
end)

connectButton(ui.autoButton, function()
	updateStatus("Auto rolling is coming soon.")
end)

connectButton(ui.oddsButton, function()
	oddsOpen = not oddsOpen
	setGuiVisible(ui.oddsPanel, oddsOpen)
end)

coreRollState.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	currentCurrencyAmount = tonumber(payload.Amount) or currentCurrencyAmount
	if payload.MutationsUnlocked ~= nil then
		mutationsUnlocked = payload.MutationsUnlocked == true
		populateOddsPanel()
	end
	updateStatus(payload.Message)
end)

player:GetAttributeChangedSignal("MutationsUnlocked"):Connect(function()
	mutationsUnlocked = player:GetAttribute("MutationsUnlocked") == true
	populateOddsPanel()
end)

coreRollResult.OnClientEvent:Connect(function(success, payload)
	rollBusy = false
	if success ~= true then
		updateStatus(type(payload) == "table" and payload.Message or "Roll failed.")
		return
	end
	updateStatus("Stored in inventory.")
	playReveal(payload)
end)

coreRollAnnouncement.OnClientEvent:Connect(sendChatMessage)

task.spawn(function()
	while player.Parent do
		updateCoreWindowVisibility()
		task.wait(0.25)
	end
end)

print("CoreRollClient ready")
