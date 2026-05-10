-- Hooks the handmade Studio HUD into the existing client UI system.
-- Expected hierarchy in PlayerGui:
-- ColorSimulatorUI/MainHUD/LeftButtons/{InventoryButton,ShopButton,WorldButton,CodesButton}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local UIManager = require(ReplicatedStorage:WaitForChild("UIManager"))
local ClientUIRoot = require(ReplicatedStorage:WaitForChild("ClientUIRoot"))
local HUDAssetConfig = require(ReplicatedStorage:WaitForChild("HUDAssetConfig"))

local UI_ROOT_NAME = "ColorSimulatorUI"
local WARNED = {}
local BUTTON_TO_WINDOW = {
	InventoryButton = "Inventory",
	ShopButton = "Gamepass",
	WorldButton = "World",
	CodesButton = "Codes",
}
local BUTTON_TO_BINDABLE = {
	InventoryButton = "HudButton_INVENTORY",
	ShopButton = "HudButton_GAMEPASS",
	WorldButton = "HudButton_WORLD",
	CodesButton = "HudButton_CODES",
}
local BUTTON_SOURCE_FILES = {
	InventoryButton = "assets/ui/sliced_clean_hud/icons_may9_transparent_128/inventory_backpack.png",
	ShopButton = "assets/ui/sliced_clean_hud/icons_may9_transparent_128/shop_bag.png",
	WorldButton = "assets/ui/sliced_clean_hud/icons_may9_transparent_128/world_globe.png",
	CodesButton = "assets/ui/sliced_clean_hud/icons_may9_transparent_128/codes_ticket.png",
}
local connectedButtons = setmetatable({}, { __mode = "k" })
local buttonScales = setmetatable({}, { __mode = "k" })
local lastActivatedAt = setmetatable({}, { __mode = "k" })
local openWindow

local function warnOnce(key, message)
	if WARNED[key] then
		return
	end
	WARNED[key] = true
	warn(message)
end

local function getActiveRoot()
	return ClientUIRoot.GetRoot(playerGui) or playerGui:FindFirstChild(UI_ROOT_NAME)
end

local function hasLeftButtons(mainHud)
	local leftButtons = mainHud and mainHud:FindFirstChild("LeftButtons")
	return leftButtons and leftButtons:IsA("GuiObject")
end

local function hasImageAsset(guiObject)
	if guiObject:IsA("ImageButton") or guiObject:IsA("ImageLabel") then
		return type(guiObject.Image) == "string" and guiObject.Image ~= ""
	end
	return false
end

local function countButtonImageAssets(leftButtons)
	local count = 0
	for buttonName in pairs(BUTTON_TO_WINDOW) do
		local button = leftButtons:FindFirstChild(buttonName)
		if button then
			if hasImageAsset(button) then
				count += 1
			end
			for _, descendant in ipairs(button:GetDescendants()) do
				if hasImageAsset(descendant) then
					count += 1
				end
			end
		end
	end
	return count
end

local function getHudSourcePriority(mainHud)
	local screenGui = mainHud and mainHud:FindFirstAncestorOfClass("ScreenGui")
	if not screenGui then
		return 0
	end
	if screenGui.Name == "ScreenGui" then
		return 3
	end
	if screenGui.Name == UI_ROOT_NAME then
		return 2
	end
	return 1
end

local function getCandidateScore(mainHud)
	local leftButtons = mainHud and mainHud:FindFirstChild("LeftButtons")
	if not leftButtons or not leftButtons:IsA("GuiObject") then
		return -1
	end

	local imageScore = countButtonImageAssets(leftButtons) * 100
	local visibleScore = (mainHud.Visible and 10 or 0) + (leftButtons.Visible and 10 or 0)
	return imageScore + visibleScore + getHudSourcePriority(mainHud)
end

local function collectPlayerGuiMainHuds()
	local candidates = {}
	local seen = {}

	local function add(mainHud)
		if mainHud and mainHud:IsA("GuiObject") and hasLeftButtons(mainHud) and not seen[mainHud] then
			seen[mainHud] = true
			table.insert(candidates, mainHud)
		end
	end

	local screen = playerGui:FindFirstChild("ScreenGui")
	add(screen and screen:FindFirstChild("MainHUD"))

	local activeRoot = playerGui:FindFirstChild(UI_ROOT_NAME)
	add(activeRoot and activeRoot:FindFirstChild("MainHUD"))

	for _, descendant in ipairs(playerGui:GetDescendants()) do
		if descendant.Name == "MainHUD" and descendant:IsA("GuiObject") then
			add(descendant)
		end
	end

	return candidates
end

local function getBestPlayerGuiMainHud()
	local best = nil
	local bestScore = -1
	for _, candidate in ipairs(collectPlayerGuiMainHuds()) do
		local score = getCandidateScore(candidate)
		if score > bestScore then
			best = candidate
			bestScore = score
		end
	end
	return best
end

local function hideOnlyGeneratedRootDuplicate(keepMainHud)
	return keepMainHud
end

local function findPlayerGuiScreenMainHud()
	local screen = playerGui:FindFirstChild("ScreenGui")
	local mainHud = screen and screen:FindFirstChild("MainHUD")
	if mainHud and mainHud:IsA("GuiObject") then
		return mainHud, "PlayerGui.ScreenGui"
	end
	return nil, nil
end

local function findFallbackMainHud()
	local fallbackHud = findPlayerGuiScreenMainHud()
	if fallbackHud and fallbackHud:IsA("GuiObject") then
		return fallbackHud, "PlayerGui.ScreenGui"
	end

	for _, descendant in ipairs(playerGui:GetDescendants()) do
		if descendant.Name == "MainHUD" and descendant:IsA("GuiObject") then
			return descendant, "PlayerGui"
		end
	end
	return nil, nil
end

local function ensureMainHudInActiveRoot()
	local root = getActiveRoot()
	if not root then
		return nil
	end

	for _, child in ipairs(root:GetChildren()) do
		if child.Name == "MainHUD" and child:IsA("GuiObject") and hasLeftButtons(child) then
			return child
		end
	end

	local fallbackHud, sourceName = findFallbackMainHud()
	if not fallbackHud or not hasLeftButtons(fallbackHud) then
		return nil
	end

	if sourceName == "PlayerGui.ScreenGui" or fallbackHud:IsDescendantOf(playerGui) then
		return fallbackHud
	end
	return nil
end

local function findMainHud()
	local screenHud = findPlayerGuiScreenMainHud()
	if hasLeftButtons(screenHud) then
		hideOnlyGeneratedRootDuplicate(screenHud)
		return screenHud
	end

	local activeRoot = getActiveRoot()
	if activeRoot then
		for _, child in ipairs(activeRoot:GetChildren()) do
			if child.Name == "MainHUD" and child:IsA("GuiObject") and hasLeftButtons(child) then
				return child
			end
		end
	end

	local adoptedHud = ensureMainHudInActiveRoot()
	if adoptedHud then
		return adoptedHud
	end

	local fallbackHud = findFallbackMainHud()
	return fallbackHud
end

local function findMainHudWithLeftButtons()
	local mainHud = findMainHud()
	if hasLeftButtons(mainHud) then
		return mainHud
	end
	return nil
end

local function getLeftButtons()
	local mainHud = findMainHudWithLeftButtons()
	if not mainHud then
		return nil
	end

	local leftButtons = mainHud:FindFirstChild("LeftButtons")
	if leftButtons and leftButtons:IsA("GuiObject") then
		return leftButtons
	end
	return nil
end

local function collectLeftButtons()
	local leftButtonSets = {}
	local seen = {}

	local function add(leftButtons)
		if leftButtons and leftButtons:IsA("GuiObject") and not seen[leftButtons] then
			seen[leftButtons] = true
			table.insert(leftButtonSets, leftButtons)
		end
	end

	local primary = getLeftButtons()
	add(primary)

	for _, descendant in ipairs(playerGui:GetDescendants()) do
		if descendant.Name == "LeftButtons" and descendant:IsA("GuiObject") then
			local mainHud = descendant.Parent
			if mainHud and mainHud.Name == "MainHUD" and mainHud:IsA("GuiObject") then
				add(descendant)
			end
		end
	end

	return leftButtonSets
end

local function applyVisibilitySafety(leftButtons)
	local mainHud = leftButtons.Parent
	local screenGui = mainHud and mainHud:FindFirstAncestorOfClass("ScreenGui")
	if not mainHud or not screenGui then
		warnOnce("root-missing", "StudioHUDHookup: could not find ScreenGui/MainHUD ancestors for LeftButtons.")
		return
	end

	screenGui.Enabled = true
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = false
	screenGui.DisplayOrder = math.max(screenGui.DisplayOrder, 999)
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	mainHud.Visible = true
	leftButtons.Visible = true
end

local function getOrCreateScale(button)
	local scale = buttonScales[button]
	if scale and scale.Parent == button then
		return scale
	end

	scale = button:FindFirstChild("StudioHUDScale")
	if not scale or not scale:IsA("UIScale") then
		scale = Instance.new("UIScale")
		scale.Name = "StudioHUDScale"
		scale.Parent = button
	end
	scale.Scale = 1
	buttonScales[button] = scale
	return scale
end

local function getPhysicalButtonImage(buttonName)
	local config = HUDAssetConfig.PhysicalButtonImages and HUDAssetConfig.PhysicalButtonImages[buttonName]
	if type(config) == "table" and type(config.Image) == "string" and config.Image ~= "" then
		return config.Image, config.SourceFile
	end
	return nil, type(config) == "table" and config.SourceFile or BUTTON_SOURCE_FILES[buttonName]
end

local function setGuiImageIfBlank(guiObject, imageId)
	if not (guiObject:IsA("ImageButton") or guiObject:IsA("ImageLabel")) then
		return false
	end
	if type(guiObject.Image) == "string" and guiObject.Image ~= "" then
		return true
	end

	guiObject.Image = imageId
	guiObject.ImageTransparency = 0
	guiObject.ScaleType = Enum.ScaleType.Fit
	return true
end

local function applyButtonIcon(button, buttonName)
	local imageId, sourceFile = getPhysicalButtonImage(buttonName)
	button:SetAttribute("ExpectedIconFile", sourceFile or "")

	if not imageId then
		if button:IsA("ImageButton") and (type(button.Image) ~= "string" or button.Image == "") then
			warnOnce(
				"missing-physical-icon-" .. buttonName,
				"StudioHUDHookup: " .. buttonName .. " needs an uploaded Roblox image id for " .. tostring(sourceFile)
			)
		end
		return
	end

	if setGuiImageIfBlank(button, imageId) then
		return
	end

	local icon = button:FindFirstChild("Icon") or button:FindFirstChildWhichIsA("ImageLabel", true)
	if icon and setGuiImageIfBlank(icon, imageId) then
		return
	end

	warnOnce("icon-target-missing-" .. buttonName, "StudioHUDHookup: could not apply icon image to " .. buttonName)
end

local function tweenScale(button, value, duration)
	local scale = getOrCreateScale(button)
	TweenService:Create(scale, TweenInfo.new(duration or 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Scale = value,
	}):Play()
end

local function prepareButton(button)
	button.AutoButtonColor = false
	button.Active = true
	button.Selectable = true
	button.Visible = true

	for _, descendant in ipairs(button:GetDescendants()) do
		if descendant:IsA("GuiObject") and not descendant:IsA("GuiButton") then
			descendant.Active = false
			descendant.Selectable = false
		end
	end

	getOrCreateScale(button)
end

local function activateButton(button, buttonName)
	local now = os.clock()
	if lastActivatedAt[button] and now - lastActivatedAt[button] < 0.2 then
		return
	end
	lastActivatedAt[button] = now
	print("StudioHUDHookup: clicked " .. buttonName)
	openWindow(buttonName)
end

local function fireFallbackBindable(buttonName)
	local bindableName = BUTTON_TO_BINDABLE[buttonName]
	local bindable = bindableName and ReplicatedStorage:FindFirstChild(bindableName)
	if bindable and bindable:IsA("BindableEvent") then
		bindable:Fire({ from = "StudioHUD" })
		return true
	end
	return false
end

function openWindow(buttonName)
	local windowName = BUTTON_TO_WINDOW[buttonName]
	if not windowName then
		return
	end

	if UIManager.isRegistered(windowName) then
		if windowName == "Inventory" then
			local openInventoryBindable = ReplicatedStorage:FindFirstChild("HudOpenInventory")
			if openInventoryBindable and openInventoryBindable:IsA("BindableEvent") then
				openInventoryBindable:Fire({ from = "StudioHUD" })
				return
			end
		end
		local ok, err = pcall(function()
			UIManager.open(windowName, { from = "StudioHUD" })
		end)
		if not ok then
			warnOnce("window-open-" .. windowName, "StudioHUDHookup: failed to open '" .. windowName .. "': " .. tostring(err))
		end
		return
	end

	task.spawn(function()
		local startedAt = os.clock()
		while os.clock() - startedAt < 8 do
			task.wait(0.1)
			if UIManager.isRegistered(windowName) then
				if windowName == "Inventory" then
					local openInventoryBindable = ReplicatedStorage:FindFirstChild("HudOpenInventory")
					if openInventoryBindable and openInventoryBindable:IsA("BindableEvent") then
						openInventoryBindable:Fire({ from = "StudioHUD" })
						return
					end
				end
				local ok, err = pcall(function()
					UIManager.open(windowName, { from = "StudioHUD" })
				end)
				if not ok then
					warnOnce("window-open-" .. windowName, "StudioHUDHookup: failed to open '" .. windowName .. "': " .. tostring(err))
				end
				return
			end
		end

		if fireFallbackBindable(buttonName) then
			return
		end

		if windowName == "Codes" then
			warnOnce("codes-missing", "StudioHUDHookup: Codes UI is not registered yet; CodesButton is connected to this placeholder.")
		else
			warnOnce("window-missing-" .. windowName, "StudioHUDHookup: missing UI window '" .. windowName .. "'.")
		end
	end)
end

local function hookButton(leftButtons, buttonName)
	local button = leftButtons:FindFirstChild(buttonName)
	if not button then
		warnOnce("missing-" .. buttonName, "StudioHUDHookup: missing MainHUD.LeftButtons." .. buttonName)
		return
	end
	if not button:IsA("GuiButton") then
		warnOnce("not-button-" .. buttonName, "StudioHUDHookup: MainHUD.LeftButtons." .. buttonName .. " is not a GuiButton.")
		return
	end
	prepareButton(button)
	applyButtonIcon(button, buttonName)
	if connectedButtons[button] then
		return
	end

	connectedButtons[button] = true
	local isPressed = false
	local isHovering = false

	button.MouseEnter:Connect(function()
		if UserInputService.MouseEnabled then
			isHovering = true
			if not isPressed then
				tweenScale(button, 1.06, 0.1)
			end
		end
	end)

	button.MouseLeave:Connect(function()
		isHovering = false
		if not isPressed then
			tweenScale(button, 1, 0.1)
		end
	end)

	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isPressed = true
			tweenScale(button, 0.92, 0.06)
		end
	end)

	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isPressed = false
			tweenScale(button, isHovering and 1.06 or 1, 0.12)
		end
	end)

	button.Activated:Connect(function()
		tweenScale(button, 0.96, 0.05)
		task.delay(0.06, function()
			if button.Parent then
				tweenScale(button, isHovering and 1.06 or 1, 0.12)
			end
		end)
		activateButton(button, buttonName)
	end)

	button.MouseButton1Click:Connect(function()
		activateButton(button, buttonName)
	end)
end

local function hookHandmadeHud()
	local leftButtonSets = collectLeftButtons()
	if #leftButtonSets <= 0 then
		warnOnce("missing-left-buttons", "StudioHUDHookup: missing handmade HUD path MainHUD.LeftButtons.")
		return false
	end

	for _, leftButtons in ipairs(leftButtonSets) do
		applyVisibilitySafety(leftButtons)

		for buttonName in pairs(BUTTON_TO_WINDOW) do
			hookButton(leftButtons, buttonName)
		end
	end

	playerGui:SetAttribute("StudioMainHUDHooked", true)
	playerGui:SetAttribute("StudioMainHUDVisualDebug", false)
	return true
end

task.defer(function()
	local startedAt = os.clock()
	while os.clock() - startedAt < 10 do
		if hookHandmadeHud() then
			return
		end
		task.wait(0.25)
	end
	warnOnce("not-found", "StudioHUDHookup: handmade MainHUD was not found in PlayerGui.")
end)

playerGui.DescendantAdded:Connect(function(descendant)
	if descendant.Name == "MainHUD" or descendant.Name == "LeftButtons" or BUTTON_TO_WINDOW[descendant.Name] then
		task.defer(hookHandmadeHud)
	end
end)
