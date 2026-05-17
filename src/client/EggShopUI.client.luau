-- Focused Sector egg shop: one usable egg per Sector.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local ClientUIRoot = require(ReplicatedStorage:WaitForChild("ClientUIRoot"))
local ColorData = require(ReplicatedStorage:WaitForChild("ColorData"))
local GameBalance = require(ReplicatedStorage:WaitForChild("GameBalance"))
local PetData = require(ReplicatedStorage:WaitForChild("PetData"))
local UIManager = require(ReplicatedStorage:WaitForChild("UIManager"))
local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))
local Modules = ReplicatedStorage:WaitForChild("Modules")
local PetModelUtil = require(Modules:WaitForChild("PetModelUtil"))

local Events = ReplicatedStorage:WaitForChild("Events")
local hatchEvent = Events:WaitForChild("HatchEgg")
local hatchFocusActive = ReplicatedStorage:FindFirstChild("HatchFocusActive")
if not hatchFocusActive then
	hatchFocusActive = Instance.new("BoolValue")
	hatchFocusActive.Name = "HatchFocusActive"
	hatchFocusActive.Parent = ReplicatedStorage
end
local autoHatchActive = ReplicatedStorage:FindFirstChild("AutoHatchActive")
if not autoHatchActive then
	autoHatchActive = Instance.new("BoolValue")
	autoHatchActive.Name = "AutoHatchActive"
	autoHatchActive.Parent = ReplicatedStorage
end
local openEggShopEvent = ReplicatedStorage:FindFirstChild("OpenEggShop")
if not openEggShopEvent then
	openEggShopEvent = Instance.new("BindableEvent")
	openEggShopEvent.Name = "OpenEggShop"
	openEggShopEvent.Parent = ReplicatedStorage
end

local colorStorage = player:WaitForChild("ColorStorage")
local unlockedColors = colorStorage:WaitForChild("UnlockedColors")
local leaderstats = player:WaitForChild("leaderstats", 10)
local coinsValue = leaderstats and leaderstats:WaitForChild("Coins", 10)
local playerGui = player:WaitForChild("PlayerGui")

local function getClientSetting(key, defaultValue)
	local value = player:GetAttribute("Setting" .. key)
	return type(value) == "boolean" and value or defaultValue
end

local function getEggShopLayer()
	local layer = ClientUIRoot.GetLayer(playerGui, "EggShopUI")
	if layer then
		return layer
	end

	local mainHud = ClientUIRoot.GetRoot(playerGui)
	if not mainHud or not mainHud:IsA("GuiObject") then
		warn("EggShopUI: missing editable MainHUD; hatch UI cannot load.")
		return nil
	end

	layer = mainHud:FindFirstChild("EggShopUI")
	if layer and layer:IsA("GuiObject") then
		return layer
	end

	warn("EggShopUI: missing editable MainHUD.EggShopUI. Run StudioEggPromptBuilder.BuildUI() in Studio edit mode.")
	return nil
end

local DARK = Color3.fromRGB(35, 38, 45)
local WHITE = Color3.fromRGB(255, 255, 255)
local PANEL_BG = Color3.fromRGB(255, 248, 252)
local PANEL_STROKE = Color3.fromRGB(255, 180, 220)
local TITLE_BG = Color3.fromRGB(180, 220, 255)
local TITLE_TEXT = Color3.fromRGB(80, 60, 130)
local SUB_BG = Color3.fromRGB(245, 235, 252)
local GREEN = Color3.fromRGB(116, 220, 125)
local LOCKED = Color3.fromRGB(205, 210, 225)
local PANEL_WIDTH = 650
local PANEL_HEIGHT = 430
local CLIENT_HATCH_REQUEST_COOLDOWN = math.max(0.85, tonumber(GameBalance.FastHatchCooldown) or 1.25)

local function isLegacyEggHatchingDisabled()
	local coreConfig = GameBalance.CoreRNG or {}
	return coreConfig.Enabled ~= false and coreConfig.DisableLegacyEggHatching == true
end

local RARITY_COLOR = {
	Common = Color3.fromRGB(150, 150, 160),
	Uncommon = Color3.fromRGB(70, 190, 95),
	Rare = Color3.fromRGB(80, 130, 255),
	Epic = Color3.fromRGB(180, 80, 255),
	Legendary = Color3.fromRGB(255, 190, 50),
	Secret = Color3.fromRGB(255, 80, 140),
}

local RARITY_SCORE = {
	Common = 1,
	Uncommon = 1.35,
	Rare = 2,
	Epic = 3,
	Legendary = 4,
	Secret = 5,
}

local MAX_EFFECT_SPARKS = 96

local EGG_BY_WORLD = {}
for _, eggId in ipairs(PetData.EggOrder or {}) do
	local egg = PetData.Eggs[eggId]
	if egg and egg.areaColor then
		EGG_BY_WORLD[egg.areaColor] = eggId
	end
end

local selectedEggId = (PetData.EggOrder and PetData.EggOrder[1]) or next(PetData.Eggs)
local isOpen = false
local isHatching = false
local hatchPending = false
local hatchStartedAt = 0
local hatchToken = 0
local lastHatchRequestAt = 0
local lastHatchRequestEggId = nil
local hatchInputLockedUntil = 0
local worldRows = {}
local hiddenWorldGuis = {}
local eggOptionGuis = {}
local eggPrompts = {}
local eggParts = {}
local missingEggPromptWarnings = {}
local currentNearbyEgg = nil
local autoHatchEnabled = false
local autoHatchRunning = false
local autoHatchThread = nil
local lastAutoHatchAt = 0
local hatchOverlay = nil
local stopAutoButton = nil
local setExternalHatchUiHidden = function() end
local ownedPetIds = {}

local function updateHatchFocusState()
	local overlayVisible = hatchOverlay and hatchOverlay.Visible == true
	hatchFocusActive.Value = overlayVisible or isHatching or hatchPending or autoHatchEnabled
	autoHatchActive.Value = autoHatchEnabled == true
	setExternalHatchUiHidden(hatchFocusActive.Value == true)
	if stopAutoButton then
		stopAutoButton.Visible = autoHatchEnabled == true
	end
end

local function formatNum(value)
	value = tonumber(value) or 0
	if value >= 1000000 then
		return string.format("%.1fM", value / 1000000)
	elseif value >= 1000 then
		return string.format("%.1fK", value / 1000)
	end
	return tostring(value)
end

local function getWorldForEgg(egg)
	return egg and egg.areaColor and ColorData.getWorldByColor(egg.areaColor) or nil
end

local function isWorldPlayable(colorType)
	local worldIndex = ColorData.getWorldIndex(colorType)
	if not worldIndex then
		return false
	end
	local progression = GameBalance.Progression or {}
	local maxPlayableIndex = tonumber(progression.MaxPlayableSectorIndex) or math.huge
	return worldIndex <= maxPlayableIndex
end

local function isEggUnlocked(egg)
	return not egg.areaColor
		or (
			isWorldPlayable(egg.areaColor)
			and (egg.areaColor == "Red" or ColorData.isColorUnlocked(unlockedColors.Value, egg.areaColor))
		)
end

local function canAffordEgg(egg)
	if not egg then
		return false
	end
	local cost = math.max(0, math.floor(tonumber(egg.cost) or 0))
	if cost <= 0 then
		return true
	end
	return coinsValue and coinsValue.Value >= cost
end

local function chooseBestUnlockedEgg()
	local best = selectedEggId
	for _, eggId in ipairs(PetData.EggOrder or {}) do
		local egg = PetData.Eggs[eggId]
		if egg and isEggUnlocked(egg) and (not egg.areaColor or isWorldPlayable(egg.areaColor)) then
			best = eggId
		end
	end
	return best
end

local function getEggIdFromPart(part)
	local current = part
	while current and current ~= workspace do
		if current.Name == "PetAppearanceStudio" then
			return nil
		end
		local eggId = current:GetAttribute("EggId")
		if eggId then
			return eggId
		end
		current = current.Parent
	end
	return nil
end

local function getEggCostText(eggId)
	local egg = eggId and PetData.Eggs[eggId]
	if not egg then
		return ""
	end
	return formatNum(egg.cost or 0) .. " Coins"
end

local function formatChance(value)
	value = tonumber(value) or 0
	if value > 0 and value < 1 then
		return string.format("%.2f%%", value)
	end
	return string.format("%g%%", value)
end

local function formatRollOdds(value)
	value = tonumber(value)
	if not value or value <= 0 then
		return "Unknown odds"
	end

	local percent
	if value < 0.01 then
		percent = string.format("%.4f%%", value)
	elseif value < 1 then
		percent = string.format("%.3f%%", value):gsub("0+$", ""):gsub("%.$", "")
	else
		percent = string.format("%.2f%%", value):gsub("0+$", ""):gsub("%.$", "")
	end

	local oneIn = math.max(1, math.floor((100 / value) + 0.5))
	return percent .. " (1 in " .. formatNum(oneIn) .. ")"
end

local function parseOwnedPetsFromInventory(value)
	table.clear(ownedPetIds)
	if type(value) ~= "string" or value == "" then
		return
	end

	for _, raw in ipairs(string.split(value, ",")) do
		local segments = string.split(raw, ":")
		local petId
		if tonumber(segments[2]) then
			petId = segments[1]
		else
			petId = segments[2]
		end
		local variantPetId = PetData.splitVariantKey(petId)
		if variantPetId then
			petId = variantPetId
		end
		if petId and PetData.Pets[petId] then
			ownedPetIds[petId] = true
		end
	end
end

local function refreshOwnedPets()
	local petFolder = player:FindFirstChild("PetData")
	local inventoryValue = petFolder and petFolder:FindFirstChild("Inventory")
	parseOwnedPetsFromInventory(inventoryValue and inventoryValue.Value or "")
end

local function isPetDiscovered(petId)
	return ownedPetIds[tostring(petId or "")] == true
end

local findEggOptionsGui

local function configureEggPrompt(prompt)
	if not prompt or not prompt:IsA("ProximityPrompt") then
		return
	end

	local holder = prompt.Parent
	local hasEditableOptions = holder and findEggOptionsGui and findEggOptionsGui(holder) ~= nil
	prompt.ActionText = "Hatch"
	prompt.ObjectText = "Egg"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = math.max(prompt.MaxActivationDistance, 18)
	prompt.RequiresLineOfSight = false
	prompt.Style = hasEditableOptions and Enum.ProximityPromptStyle.Custom or Enum.ProximityPromptStyle.Default
	prompt:SetAttribute("EggShopPrompt", true)
end

local function setPromptText(parent, name, value)
	local label = parent and parent:FindFirstChild(name, true)
	if label and (label:IsA("TextLabel") or label:IsA("TextButton") or label:IsA("TextBox")) then
		label.Text = tostring(value or "")
	end
end

local function updateEggPromptPreview(gui, eggId)
	local egg = eggId and PetData.Eggs[eggId]
	local grid = gui and gui:FindFirstChild("PreviewGrid", true)
	if not egg or not grid then
		return
	end

	for index = 1, 5 do
		local slot = grid:FindFirstChild("PreviewSlot" .. tostring(index))
		local roll = egg.pets and egg.pets[index]
		local pet = roll and PetData.Pets[roll.petId]
		if slot and slot:IsA("GuiObject") then
			slot.Visible = pet ~= nil
			if pet then
				local discovered = isPetDiscovered(roll.petId)
				local rarityColor = RARITY_COLOR[pet.rarity] or TITLE_TEXT
				slot.BackgroundColor3 = discovered and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(140, 145, 160)
				slot.BackgroundTransparency = discovered and 0.05 or 0.18
				local stroke = slot:FindFirstChildOfClass("UIStroke")
				if stroke then
					stroke.Color = discovered and rarityColor or Color3.fromRGB(70, 76, 92)
					stroke.Transparency = discovered and 0 or 0.25
				end

				local dot = slot:FindFirstChild("ColorDot")
				if dot and dot:IsA("GuiObject") then
					dot.BackgroundColor3 = discovered and pet.color or pet.color:Lerp(Color3.fromRGB(20, 24, 35), 0.55)
					dot.BackgroundTransparency = discovered and 0 or 0.2
				end
				setPromptText(slot, "Chance", formatChance(roll.chance))
				setPromptText(slot, "State", discovered and string.upper(tostring(pet.rarity or "")) or "???")

				local shade = slot:FindFirstChild("LockedShade")
				if shade and shade:IsA("GuiObject") then
					shade.Visible = not discovered
				end
			end
		end
	end
end

local function refreshEggPromptPreviews()
	for part, gui in pairs(eggOptionGuis) do
		if part.Parent and gui and gui.Parent then
			updateEggPromptPreview(gui, getEggIdFromPart(part))
		end
	end
end

function findEggOptionsGui(eggPart)
	if not eggPart then
		return nil
	end

	local direct = eggPart:FindFirstChild("EggOptions")
	if direct and direct:IsA("BillboardGui") then
		return direct
	end

	local ancestor = eggPart:FindFirstAncestorWhichIsA("Model")
	local nested = ancestor and ancestor:FindFirstChild("EggOptions", true)
	if nested and nested:IsA("BillboardGui") then
		return nested
	end

	return nil
end

local function resolveEggHolder(instance)
	local current = instance
	while current and current ~= workspace do
		if current:IsA("BasePart") and getEggIdFromPart(current) then
			return current
		end
		current = current.Parent
	end

	local model = instance and instance:FindFirstAncestorWhichIsA("Model")
	local primary = model and model.PrimaryPart
	if primary and getEggIdFromPart(primary) then
		return primary
	end

	return nil
end

local function bindEggOptionsGui(eggPart)
	local holder = resolveEggHolder(eggPart)
	if not holder then
		return nil
	end

	local gui = findEggOptionsGui(holder)
	if not gui then
		local eggId = getEggIdFromPart(holder)
		if eggId and not missingEggPromptWarnings[eggId] then
			missingEggPromptWarnings[eggId] = true
			warn(
				"EggShopUI: missing editable EggOptions for "
					.. tostring(eggId)
					.. ". Run StudioEggPromptBuilder.Update() in Studio edit mode."
			)
		end
		return nil
	end

	local guiHolder = gui.Parent
	if guiHolder and guiHolder:IsA("BasePart") then
		holder = guiHolder
	end

	eggParts[holder] = true
	eggOptionGuis[holder] = gui
	local prompt = holder:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		configureEggPrompt(prompt)
	end

	local eggId = getEggIdFromPart(holder)
	local egg = eggId and PetData.Eggs[eggId]
	setPromptText(gui, "Title", string.upper(egg and egg.displayName or "Egg"))
	setPromptText(gui, "MainTitle", "EGG")
	setPromptText(gui, "Cost", getEggCostText(eggId))
	updateEggPromptPreview(gui, eggId)
	gui.Enabled = false
	gui:SetAttribute("EggOptionGui", true)
	return gui
end

local function bindEggStation(instance)
	local gui = bindEggOptionsGui(instance)
	local holder = resolveEggHolder(instance)
	if holder then
		local prompt = holder:FindFirstChildWhichIsA("ProximityPrompt", true)
		if prompt then
			configureEggPrompt(prompt)
		end
	end
	return gui
end

local function findNearestEggPart()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end

	local bestPart = nil
	local bestDistance = math.huge
	for eggPart in pairs(eggParts) do
		if not eggPart.Parent then
			eggParts[eggPart] = nil
			eggOptionGuis[eggPart] = nil
		else
			local distance = (root.Position - eggPart.Position).Magnitude
			if distance < bestDistance and distance <= 22 then
				bestDistance = distance
				bestPart = eggPart
			end
		end
	end

	return bestPart
end

local function setEggOptionsVisible(eggPart)
	local overlayVisible = hatchOverlay and hatchOverlay.Visible or false
	local shouldShowPrompt = not isOpen and not isHatching and not overlayVisible
	for part, gui in pairs(eggOptionGuis) do
		if not part.Parent then
			eggOptionGuis[part] = nil
		elseif gui and gui.Parent then
			gui.Enabled = part == eggPart and shouldShowPrompt
			if part == eggPart and shouldShowPrompt then
				updateEggPromptPreview(gui, getEggIdFromPart(part))
			end
			local autoOption = gui:FindFirstChild("Panel") and gui.Panel:FindFirstChild("AutoOption")
			local label = autoOption and autoOption:FindFirstChild("Label")
			if label then
				label.Text = autoHatchEnabled and "STOP" or "AUTO"
			end
		end
	end

	if eggPart and eggOptionGuis[eggPart] then
		eggOptionGuis[eggPart].Enabled = shouldShowPrompt
	end
end

local function setEggPromptsEnabled(enabled)
	for prompt in pairs(eggPrompts) do
		if not prompt.Parent then
			eggPrompts[prompt] = nil
		elseif prompt:IsA("ProximityPrompt") then
			prompt.Enabled = enabled == true
		end
	end
end

local screenGui = getEggShopLayer()
if not screenGui then
	return
end
if screenGui:IsA("GuiObject") then
	screenGui.Visible = true
end
local rootScreenGui = screenGui and screenGui:FindFirstAncestorOfClass("ScreenGui")
if rootScreenGui then
	rootScreenGui.Enabled = true
end
local externalGuiEnabledState = {}
local defaultPlayerGuiNames = {
	Chat = true,
	BubbleChat = true,
	TouchGui = true,
	Freecam = true,
	PlayerList = true,
}

setExternalHatchUiHidden = function(hidden)
	for _, child in ipairs(playerGui:GetChildren()) do
		if child:IsA("ScreenGui") and child ~= rootScreenGui and not defaultPlayerGuiNames[child.Name] then
			if hidden then
				if externalGuiEnabledState[child] == nil then
					externalGuiEnabledState[child] = child.Enabled
				end
				child.Enabled = false
			elseif externalGuiEnabledState[child] ~= nil then
				child.Enabled = externalGuiEnabledState[child]
				externalGuiEnabledState[child] = nil
			end
		end
	end
end

playerGui.ChildAdded:Connect(function(child)
	if hatchFocusActive.Value == true and child:IsA("ScreenGui") then
		task.defer(function()
			setExternalHatchUiHidden(true)
		end)
	end
end)

local modalBackdrop = Instance.new("TextButton")
modalBackdrop.Name = "ModalBackdrop"
modalBackdrop.Size = UDim2.fromScale(1, 1)
modalBackdrop.BackgroundColor3 = Color3.fromRGB(31, 40, 56)
modalBackdrop.BackgroundTransparency = 0.25
modalBackdrop.BorderSizePixel = 0
modalBackdrop.AutoButtonColor = false
modalBackdrop.Text = ""
modalBackdrop.Visible = false
modalBackdrop.ZIndex = 1
modalBackdrop.Parent = screenGui

local panel = Instance.new("Frame")
panel.Name = "EggShopPanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Size = UDim2.new(0, PANEL_WIDTH, 0, PANEL_HEIGHT)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.BackgroundColor3 = PANEL_BG
panel.BorderSizePixel = 0
panel.Visible = false
panel.ClipsDescendants = true
panel.ZIndex = 10
panel.Parent = screenGui
UITheme.ApplyResponsiveScale(panel, PANEL_WIDTH, PANEL_HEIGHT, 0.74, 28)
local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 22)
panelCorner.Parent = panel
local panelStroke = Instance.new("UIStroke")
panelStroke.Color = PANEL_STROKE
panelStroke.Thickness = 5
panelStroke.Parent = panel

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, -20, 0, 56)
titleBar.Position = UDim2.new(0, 10, 0, 10)
titleBar.BackgroundColor3 = TITLE_BG
titleBar.BorderSizePixel = 0
titleBar.ZIndex = 11
titleBar.Parent = panel
local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 16)
titleCorner.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -70, 1, 0)
titleLabel.Position = UDim2.new(0, 18, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.LuckiestGuy
titleLabel.TextSize = 28
titleLabel.TextColor3 = TITLE_TEXT
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Text = "EGG SHOP"
titleLabel.ZIndex = 12
titleLabel.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 40, 0, 40)
closeBtn.Position = UDim2.new(1, -50, 0.5, -20)
closeBtn.BackgroundColor3 = Color3.fromRGB(255, 130, 150)
closeBtn.Font = Enum.Font.LuckiestGuy
closeBtn.TextSize = 20
closeBtn.TextColor3 = WHITE
closeBtn.TextStrokeTransparency = 0
closeBtn.TextStrokeColor3 = DARK
closeBtn.Text = "X"
closeBtn.ZIndex = 12
closeBtn.Parent = titleBar
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 12)
closeCorner.Parent = closeBtn

local worldList = Instance.new("ScrollingFrame")
worldList.Name = "WorldList"
worldList.Size = UDim2.new(0, 190, 1, -86)
worldList.Position = UDim2.new(0, 14, 0, 76)
worldList.BackgroundColor3 = SUB_BG
worldList.BorderSizePixel = 0
worldList.ScrollBarThickness = 5
worldList.CanvasSize = UDim2.new(0, 0, 0, 0)
worldList.Visible = false
worldList.ZIndex = 11
worldList.Parent = panel
local worldCorner = Instance.new("UICorner")
worldCorner.CornerRadius = UDim.new(0, 16)
worldCorner.Parent = worldList
local worldStroke = Instance.new("UIStroke")
worldStroke.Color = Color3.fromRGB(218, 200, 240)
worldStroke.Thickness = 2
worldStroke.Parent = worldList
local worldLayout = Instance.new("UIListLayout")
worldLayout.SortOrder = Enum.SortOrder.LayoutOrder
worldLayout.Padding = UDim.new(0, 8)
worldLayout.Parent = worldList
local worldPadding = Instance.new("UIPadding")
worldPadding.PaddingTop = UDim.new(0, 10)
worldPadding.PaddingLeft = UDim.new(0, 10)
worldPadding.PaddingRight = UDim.new(0, 10)
worldPadding.Parent = worldList

local detail = Instance.new("Frame")
detail.Name = "EggDetail"
detail.Size = UDim2.new(1, -28, 1, -86)
detail.Position = UDim2.new(0, 14, 0, 76)
detail.BackgroundColor3 = WHITE
detail.BorderSizePixel = 0
detail.ZIndex = 11
detail.Parent = panel
local detailCorner = Instance.new("UICorner")
detailCorner.CornerRadius = UDim.new(0, 16)
detailCorner.Parent = detail
local detailStroke = Instance.new("UIStroke")
detailStroke.Color = DARK
detailStroke.Thickness = 3
detailStroke.Parent = detail

local eggIcon = Instance.new("Frame")
eggIcon.Size = UDim2.new(0, 150, 0, 120)
eggIcon.Position = UDim2.new(0, 18, 0, 18)
eggIcon.BackgroundColor3 = Color3.fromRGB(180, 100, 255)
eggIcon.BorderSizePixel = 0
eggIcon.ZIndex = 12
eggIcon.Parent = detail
local eggIconCorner = Instance.new("UICorner")
eggIconCorner.CornerRadius = UDim.new(0, 18)
eggIconCorner.Parent = eggIcon

local eggShape = Instance.new("Frame")
eggShape.Size = UDim2.new(0, 58, 0, 78)
eggShape.Position = UDim2.new(0.5, -29, 0.5, -39)
eggShape.BackgroundColor3 = Color3.fromRGB(255, 236, 220)
eggShape.BorderSizePixel = 0
eggShape.ZIndex = 13
eggShape.Parent = eggIcon
local eggShapeCorner = Instance.new("UICorner")
eggShapeCorner.CornerRadius = UDim.new(1, 0)
eggShapeCorner.Parent = eggShape
local eggShapeStroke = Instance.new("UIStroke")
eggShapeStroke.Color = WHITE
eggShapeStroke.Thickness = 2
eggShapeStroke.Parent = eggShape

local eggName = Instance.new("TextLabel")
eggName.Size = UDim2.new(1, -190, 0, 38)
eggName.Position = UDim2.new(0, 184, 0, 20)
eggName.BackgroundTransparency = 1
eggName.Font = Enum.Font.LuckiestGuy
eggName.TextSize = 28
eggName.TextColor3 = TITLE_TEXT
eggName.TextXAlignment = Enum.TextXAlignment.Left
eggName.Text = "Color Egg"
eggName.ZIndex = 12
eggName.Parent = detail

local worldName = Instance.new("TextLabel")
worldName.Size = UDim2.new(1, -190, 0, 24)
worldName.Position = UDim2.new(0, 184, 0, 58)
worldName.BackgroundTransparency = 1
worldName.Font = Enum.Font.GothamBold
worldName.TextSize = 14
worldName.TextColor3 = Color3.fromRGB(95, 92, 120)
worldName.TextXAlignment = Enum.TextXAlignment.Left
worldName.Text = "Start Sector"
worldName.ZIndex = 12
worldName.Parent = detail

local costLabel = Instance.new("TextLabel")
costLabel.Size = UDim2.new(1, -190, 0, 26)
costLabel.Position = UDim2.new(0, 184, 0, 86)
costLabel.BackgroundTransparency = 1
costLabel.Font = Enum.Font.LuckiestGuy
costLabel.TextSize = 18
costLabel.TextColor3 = Color3.fromRGB(220, 140, 30)
costLabel.TextXAlignment = Enum.TextXAlignment.Left
costLabel.Text = "100 Coins"
costLabel.ZIndex = 12
costLabel.Parent = detail

local hatchBtn = Instance.new("TextButton")
hatchBtn.Size = UDim2.new(0, 180, 0, 50)
hatchBtn.Position = UDim2.new(0, 184, 0, 120)
hatchBtn.BackgroundColor3 = GREEN
hatchBtn.Font = Enum.Font.LuckiestGuy
hatchBtn.TextSize = 22
hatchBtn.TextColor3 = WHITE
hatchBtn.TextStrokeTransparency = 0
hatchBtn.TextStrokeColor3 = DARK
hatchBtn.Text = "HATCH"
hatchBtn.ZIndex = 12
hatchBtn.Parent = detail
local hatchCorner = Instance.new("UICorner")
hatchCorner.CornerRadius = UDim.new(0, 14)
hatchCorner.Parent = hatchBtn
local hatchStroke = Instance.new("UIStroke")
hatchStroke.Color = DARK
hatchStroke.Thickness = 3
hatchStroke.Parent = hatchBtn

local function setHatchButtonState(unlocked)
	unlocked = unlocked ~= false
	local egg = selectedEggId and PetData.Eggs[selectedEggId]
	local affordable = unlocked and canAffordEgg(egg)
	local ready = unlocked and affordable and not isHatching and not autoHatchEnabled
	hatchBtn.Active = ready
	hatchBtn.AutoButtonColor = ready

	if isHatching then
		hatchBtn.Text = "HATCHING..."
		hatchBtn.BackgroundColor3 = Color3.fromRGB(150, 160, 170)
	elseif autoHatchEnabled then
		hatchBtn.Text = "AUTO HATCH"
		hatchBtn.BackgroundColor3 = Color3.fromRGB(150, 160, 190)
	elseif unlocked and affordable then
		hatchBtn.Text = "HATCH"
		hatchBtn.BackgroundColor3 = GREEN
	elseif unlocked then
		hatchBtn.Text = "NEED COINS"
		hatchBtn.BackgroundColor3 = LOCKED
	else
		hatchBtn.Text = "LOCKED"
		hatchBtn.BackgroundColor3 = LOCKED
	end
end

local function getSelectedEggUnlocked()
	local egg = selectedEggId and PetData.Eggs[selectedEggId]
	return egg and isEggUnlocked(egg) or false
end

local function setHatchingLocked(locked)
	isHatching = locked == true
	setEggPromptsEnabled(not isHatching)
	setHatchButtonState(getSelectedEggUnlocked())
	setEggOptionsVisible(currentNearbyEgg)
	updateHatchFocusState()
end

local petsTitle = Instance.new("TextLabel")
petsTitle.Size = UDim2.new(1, -32, 0, 24)
petsTitle.Position = UDim2.new(0, 16, 0, 188)
petsTitle.BackgroundTransparency = 1
petsTitle.Font = Enum.Font.LuckiestGuy
petsTitle.TextSize = 16
petsTitle.TextColor3 = TITLE_TEXT
petsTitle.TextXAlignment = Enum.TextXAlignment.Left
petsTitle.Text = "POSSIBLE COLORS"
petsTitle.ZIndex = 12
petsTitle.Parent = detail

local petGrid = Instance.new("ScrollingFrame")
petGrid.Size = UDim2.new(1, -32, 1, -224)
petGrid.Position = UDim2.new(0, 16, 0, 214)
petGrid.BackgroundTransparency = 1
petGrid.BorderSizePixel = 0
petGrid.ScrollBarThickness = 5
petGrid.CanvasSize = UDim2.new(0, 0, 0, 0)
petGrid.ZIndex = 12
petGrid.Parent = detail
local petGridLayout = Instance.new("UIGridLayout")
petGridLayout.CellSize = UDim2.new(0, 126, 0, 58)
petGridLayout.CellPadding = UDim2.new(0, 8, 0, 8)
petGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
petGridLayout.Parent = petGrid

local function getEditableChild(parent, className, name)
	local child = parent:FindFirstChild(name)
	if child and child:IsA(className) then
		return child, false
	end
	if child then
		if child:IsA("GuiObject") then
			child.Visible = false
		end
		child.Name = name .. "_Legacy"
	end

	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance, true
end

local function ensureCorner(instance, radius)
	local corner = instance:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
	return corner
end

local function ensureStroke(instance, color, thickness)
	local stroke = instance:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Parent = instance
	return stroke
end

local function ensureTextSizeLimit(label, minSize, maxSize)
	local sizeLimit = label:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
	sizeLimit.MinTextSize = minSize
	sizeLimit.MaxTextSize = maxSize
	sizeLimit.Parent = label
	return sizeLimit
end

hatchOverlay = getEditableChild(screenGui, "Frame", "HatchOverlay")
hatchOverlay.Visible = false
hatchOverlay:SetAttribute("EditableHatchAnimation", true)
if hatchOverlay:GetAttribute("UsesDefaultHatchLayout") ~= true then
	hatchOverlay.Size = UDim2.fromScale(1, 1)
	hatchOverlay.BackgroundColor3 = Color3.fromRGB(12, 16, 24)
	hatchOverlay.BackgroundTransparency = 0.02
	hatchOverlay.BorderSizePixel = 0
	hatchOverlay.ZIndex = 850
	hatchOverlay:SetAttribute("UsesDefaultHatchLayout", true)
end

local hatchEgg = getEditableChild(hatchOverlay, "Frame", "HatchEgg")
hatchEgg.Visible = false
if hatchEgg:GetAttribute("UsesDefaultHatchLayout") ~= true then
	hatchEgg.Size = UDim2.new(0, 140, 0, 180)
	hatchEgg.AnchorPoint = Vector2.new(0.5, 0.5)
	hatchEgg.Position = UDim2.new(0.5, 0, 0.46, 0)
	hatchEgg.BackgroundColor3 = Color3.fromRGB(255, 236, 220)
	hatchEgg.BorderSizePixel = 0
	hatchEgg.ZIndex = 900
	ensureCorner(hatchEgg, 999)
	ensureStroke(hatchEgg, WHITE, 5)
	hatchEgg:SetAttribute("UsesDefaultHatchLayout", true)
end
local hatchEggBaseSize = hatchEgg.Size
local hatchEggBasePosition = hatchEgg.Position
local hatchEggBaseRotation = hatchEgg.Rotation
local hatchEggBaseTransparency = hatchEgg.BackgroundTransparency
local hatchEggBaseColor = hatchEgg.BackgroundColor3

local function configureHatchCrack(name, position, size, rotation)
	local crack = getEditableChild(hatchEgg, "Frame", name)
	crack.Visible = false
	if crack:GetAttribute("UsesDefaultHatchLayout") ~= true then
		crack.AnchorPoint = Vector2.new(0.5, 0.5)
		crack.Position = position
		crack.Size = size
		crack.Rotation = rotation
		crack.BackgroundColor3 = Color3.fromRGB(35, 42, 62)
		crack.BorderSizePixel = 0
		crack.ZIndex = hatchEgg.ZIndex + 2
		ensureCorner(crack, 8)
		crack:SetAttribute("UsesDefaultHatchLayout", true)
	end
	return crack
end

local hatchEggCracks = {
	configureHatchCrack("Crack1", UDim2.new(0.5, -8, 0.42, 0), UDim2.new(0, 8, 0, 56), -28),
	configureHatchCrack("Crack2", UDim2.new(0.5, 14, 0.51, 0), UDim2.new(0, 8, 0, 48), 24),
	configureHatchCrack("Crack3", UDim2.new(0.5, -18, 0.57, 0), UDim2.new(0, 7, 0, 38), 42),
}

local hatchViewport = getEditableChild(hatchOverlay, "ViewportFrame", "HatchViewport")
hatchViewport.Visible = false
if hatchViewport:GetAttribute("UsesDefaultHatchLayout") ~= true then
	hatchViewport.Size = UDim2.new(0, 360, 0, 300)
	hatchViewport.AnchorPoint = Vector2.new(0.5, 0.5)
	hatchViewport.Position = UDim2.new(0.5, 0, 0.45, 0)
	hatchViewport.BackgroundTransparency = 1
	hatchViewport.ZIndex = 900
	hatchViewport:SetAttribute("UsesDefaultHatchLayout", true)
end

local hatchWorld = hatchViewport:FindFirstChild("HatchWorld")
if not hatchWorld or not hatchWorld:IsA("WorldModel") then
	if hatchWorld then
		hatchWorld:Destroy()
	end
	hatchWorld = Instance.new("WorldModel")
	hatchWorld.Name = "HatchWorld"
	hatchWorld.Parent = hatchViewport
end

local hatchCamera = hatchViewport:FindFirstChild("HatchCamera")
if not hatchCamera or not hatchCamera:IsA("Camera") then
	if hatchCamera then
		hatchCamera:Destroy()
	end
	hatchCamera = Instance.new("Camera")
	hatchCamera.Name = "HatchCamera"
	hatchCamera.Parent = hatchViewport
end
hatchCamera.CFrame = CFrame.new(0, 1.2, 8) * CFrame.Angles(math.rad(-7), 0, 0)
hatchCamera.FieldOfView = 34
hatchViewport.CurrentCamera = hatchCamera

local hatchText = getEditableChild(hatchOverlay, "TextLabel", "HatchText")
if hatchText:GetAttribute("UsesDefaultHatchLayout") ~= true then
	hatchText.Size = UDim2.new(0, 420, 0, 64)
	hatchText.AnchorPoint = Vector2.new(0.5, 0.5)
	hatchText.Position = UDim2.new(0.5, 0, 0.65, 0)
	hatchText.BackgroundTransparency = 1
	hatchText.Font = Enum.Font.LuckiestGuy
	hatchText.TextSize = 34
	hatchText.TextScaled = true
	hatchText.TextColor3 = WHITE
	hatchText.TextStrokeTransparency = 0
	hatchText.TextStrokeColor3 = DARK
	hatchText.Text = "HATCHING..."
	hatchText.ZIndex = 905
	ensureTextSizeLimit(hatchText, 18, 34)
	hatchText:SetAttribute("UsesDefaultHatchLayout", true)
end

stopAutoButton = getEditableChild(hatchOverlay, "TextButton", "StopAutoHatch")
stopAutoButton.Visible = false
if stopAutoButton:GetAttribute("UsesDefaultHatchLayout") ~= true then
	stopAutoButton.AnchorPoint = Vector2.new(0.5, 0.5)
	stopAutoButton.Size = UDim2.new(0, 170, 0, 44)
	stopAutoButton.Position = UDim2.new(0.5, 0, 0.76, 0)
	stopAutoButton.BackgroundColor3 = Color3.fromRGB(255, 120, 145)
	stopAutoButton.BorderSizePixel = 0
	stopAutoButton.AutoButtonColor = false
	stopAutoButton.Font = Enum.Font.LuckiestGuy
	stopAutoButton.TextSize = 17
	stopAutoButton.TextColor3 = WHITE
	stopAutoButton.TextStrokeTransparency = 0
	stopAutoButton.TextStrokeColor3 = DARK
	stopAutoButton.Text = "STOP AUTO"
	stopAutoButton.ZIndex = 920
	ensureCorner(stopAutoButton, 14)
	ensureStroke(stopAutoButton, DARK, 3)
	stopAutoButton:SetAttribute("UsesDefaultHatchLayout", true)
end

local resultCard = getEditableChild(hatchOverlay, "Frame", "HatchResultCard")
resultCard.Visible = false
if resultCard:GetAttribute("UsesDefaultHatchLayout") ~= true then
	resultCard.Size = UDim2.new(0, 380, 0, 160)
	resultCard.AnchorPoint = Vector2.new(0.5, 0.5)
	resultCard.Position = UDim2.new(0.5, 0, 0.82, 0)
	resultCard.BackgroundColor3 = Color3.fromRGB(255, 248, 252)
	resultCard.BorderSizePixel = 0
	resultCard.ZIndex = 910
	ensureCorner(resultCard, 18)
	resultCard:SetAttribute("UsesDefaultHatchLayout", true)
end
local resultStroke = ensureStroke(resultCard, WHITE, 3)

local resultName = getEditableChild(resultCard, "TextLabel", "ResultName")
if resultName:GetAttribute("UsesDefaultHatchLayout") ~= true then
	resultName.Size = UDim2.new(1, -28, 0, 38)
	resultName.Position = UDim2.new(0, 14, 0, 12)
	resultName.BackgroundTransparency = 1
	resultName.Font = Enum.Font.LuckiestGuy
	resultName.TextSize = 24
	resultName.TextColor3 = TITLE_TEXT
	resultName.TextXAlignment = Enum.TextXAlignment.Left
	resultName.Text = "Color"
	resultName.ZIndex = 911
	resultName:SetAttribute("UsesDefaultHatchLayout", true)
end
resultName.Visible = false

local resultRarity = getEditableChild(resultCard, "TextLabel", "ResultRarity")
if resultRarity:GetAttribute("UsesDefaultHatchLayout") ~= true then
	resultRarity.Size = UDim2.new(1, -28, 0, 26)
	resultRarity.Position = UDim2.new(0, 14, 0, 48)
	resultRarity.BackgroundTransparency = 1
	resultRarity.Font = Enum.Font.GothamBold
	resultRarity.TextSize = 16
	resultRarity.TextColor3 = TITLE_TEXT
	resultRarity.TextXAlignment = Enum.TextXAlignment.Left
	resultRarity.TextWrapped = true
	resultRarity.Text = "Common"
	resultRarity.ZIndex = 911
	resultRarity:SetAttribute("UsesDefaultHatchLayout", true)
end
resultRarity.Visible = false

local resultStats = getEditableChild(resultCard, "TextLabel", "ResultStats")
if resultStats:GetAttribute("UsesDefaultHatchLayout") ~= true then
	resultStats.Size = UDim2.new(1, -28, 0, 32)
	resultStats.Position = UDim2.new(0, 14, 0, 80)
	resultStats.BackgroundTransparency = 1
	resultStats.Font = Enum.Font.LuckiestGuy
	resultStats.TextSize = 24
	resultStats.TextColor3 = Color3.fromRGB(235, 54, 54)
	resultStats.TextStrokeTransparency = 0
	resultStats.TextStrokeColor3 = DARK
	resultStats.TextWrapped = false
	resultStats.TextXAlignment = Enum.TextXAlignment.Left
	resultStats.TextYAlignment = Enum.TextYAlignment.Center
	resultStats.Text = "0  FIST"
	resultStats.ZIndex = 911
	resultStats:SetAttribute("UsesDefaultHatchLayout", true)
end
resultStats.Visible = false

local resultOdds = getEditableChild(resultCard, "TextLabel", "ResultOdds")
if resultOdds:GetAttribute("UsesDefaultHatchLayout") ~= true then
	resultOdds.Size = UDim2.new(1, -28, 0, 30)
	resultOdds.Position = UDim2.new(0, 14, 1, -38)
	resultOdds.BackgroundTransparency = 1
	resultOdds.Font = Enum.Font.GothamBlack
	resultOdds.TextSize = 14
	resultOdds.TextScaled = true
	resultOdds.TextColor3 = Color3.fromRGB(66, 78, 110)
	resultOdds.TextStrokeTransparency = 0.75
	resultOdds.TextStrokeColor3 = WHITE
	resultOdds.TextWrapped = true
	resultOdds.TextXAlignment = Enum.TextXAlignment.Left
	resultOdds.TextYAlignment = Enum.TextYAlignment.Center
	resultOdds.Text = "Odds"
	resultOdds.ZIndex = 911
	ensureTextSizeLimit(resultOdds, 9, 14)
	resultOdds:SetAttribute("EditableHatchOdds", true)
	resultOdds:SetAttribute("UsesDefaultHatchLayout", true)
end
resultOdds.Visible = false

local rarityFlash = hatchOverlay:FindFirstChild("RarityFlash")
local rarityBanner = hatchOverlay:FindFirstChild("RarityBanner")
local cutsceneBackdrop = getEditableChild(hatchOverlay, "Frame", "RngCutsceneBackdrop")
if cutsceneBackdrop:GetAttribute("UsesDefaultHatchLayout") ~= true then
	cutsceneBackdrop.Size = UDim2.fromScale(1, 1)
	cutsceneBackdrop.Position = UDim2.fromScale(0, 0)
	cutsceneBackdrop.BackgroundColor3 = Color3.fromRGB(6, 8, 15)
	cutsceneBackdrop.BackgroundTransparency = 1
	cutsceneBackdrop.BorderSizePixel = 0
	cutsceneBackdrop.ZIndex = 886
	cutsceneBackdrop:SetAttribute("EditableHatchCutscene", true)
	cutsceneBackdrop:SetAttribute("UsesDefaultHatchLayout", true)
end
cutsceneBackdrop.Visible = false

local cutsceneShockwave = getEditableChild(hatchOverlay, "Frame", "RngCutsceneShockwave")
if cutsceneShockwave:GetAttribute("UsesDefaultHatchLayout") ~= true then
	cutsceneShockwave.AnchorPoint = Vector2.new(0.5, 0.5)
	cutsceneShockwave.Size = UDim2.fromOffset(80, 80)
	cutsceneShockwave.Position = UDim2.fromScale(0.5, 0.45)
	cutsceneShockwave.BackgroundColor3 = WHITE
	cutsceneShockwave.BackgroundTransparency = 1
	cutsceneShockwave.BorderSizePixel = 0
	cutsceneShockwave.ZIndex = 913
	ensureCorner(cutsceneShockwave, 999)
	local shockwaveStroke = ensureStroke(cutsceneShockwave, WHITE, 5)
	shockwaveStroke.Transparency = 1
	cutsceneShockwave:SetAttribute("EditableHatchCutscene", true)
	cutsceneShockwave:SetAttribute("UsesDefaultHatchLayout", true)
end
cutsceneShockwave.Visible = false

local cutsceneTitle = getEditableChild(hatchOverlay, "TextLabel", "RngCutsceneTitle")
if cutsceneTitle:GetAttribute("UsesDefaultHatchLayout") ~= true then
	cutsceneTitle.AnchorPoint = Vector2.new(0.5, 0.5)
	cutsceneTitle.Size = UDim2.fromOffset(760, 84)
	cutsceneTitle.Position = UDim2.fromScale(0.5, 0.23)
	cutsceneTitle.BackgroundTransparency = 1
	cutsceneTitle.Font = Enum.Font.LuckiestGuy
	cutsceneTitle.Text = "INSANE HATCH!"
	cutsceneTitle.TextScaled = true
	cutsceneTitle.TextColor3 = WHITE
	cutsceneTitle.TextStrokeTransparency = 0
	cutsceneTitle.TextStrokeColor3 = DARK
	cutsceneTitle.ZIndex = 935
	ensureTextSizeLimit(cutsceneTitle, 18, 58)
	cutsceneTitle:SetAttribute("EditableHatchCutscene", true)
	cutsceneTitle:SetAttribute("UsesDefaultHatchLayout", true)
end
cutsceneTitle.Visible = false

local cutsceneSubtitle = getEditableChild(hatchOverlay, "TextLabel", "RngCutsceneSubtitle")
if cutsceneSubtitle:GetAttribute("UsesDefaultHatchLayout") ~= true then
	cutsceneSubtitle.AnchorPoint = Vector2.new(0.5, 0.5)
	cutsceneSubtitle.Size = UDim2.fromOffset(660, 48)
	cutsceneSubtitle.Position = UDim2.fromScale(0.5, 0.31)
	cutsceneSubtitle.BackgroundTransparency = 1
	cutsceneSubtitle.Font = Enum.Font.GothamBlack
	cutsceneSubtitle.Text = "A rare Color is breaking out"
	cutsceneSubtitle.TextScaled = true
	cutsceneSubtitle.TextColor3 = Color3.fromRGB(230, 240, 255)
	cutsceneSubtitle.TextStrokeTransparency = 0.35
	cutsceneSubtitle.TextStrokeColor3 = DARK
	cutsceneSubtitle.ZIndex = 935
	ensureTextSizeLimit(cutsceneSubtitle, 12, 28)
	cutsceneSubtitle:SetAttribute("EditableHatchCutscene", true)
	cutsceneSubtitle:SetAttribute("UsesDefaultHatchLayout", true)
end
cutsceneSubtitle.Visible = false

local effectBurst = getEditableChild(hatchOverlay, "Frame", "EffectBurst")
if effectBurst:GetAttribute("UsesDefaultHatchLayout") ~= true then
	effectBurst.Size = UDim2.fromScale(1, 1)
	effectBurst.Position = UDim2.fromScale(0, 0)
	effectBurst.BackgroundTransparency = 1
	effectBurst.BorderSizePixel = 0
	effectBurst.Visible = true
	effectBurst.ZIndex = 912
	effectBurst:SetAttribute("EditableHatchEffect", true)
	effectBurst:SetAttribute("UsesDefaultHatchLayout", true)
end
local effectSparks = {}
if effectBurst then
	for index = 1, MAX_EFFECT_SPARKS do
		local spark = effectBurst:FindFirstChild("Spark" .. tostring(index))
		if not spark or not spark:IsA("GuiObject") then
			if spark then
				spark:Destroy()
			end
			spark = Instance.new("Frame")
			spark.Name = "Spark" .. tostring(index)
			spark.AnchorPoint = Vector2.new(0.5, 0.5)
			spark.Size = UDim2.fromOffset(10, 10)
			spark.Position = UDim2.fromScale(0.5, 0.46)
			spark.BackgroundColor3 = WHITE
			spark.BackgroundTransparency = 1
			spark.BorderSizePixel = 0
			spark.Visible = false
			spark.ZIndex = 912
			spark:SetAttribute("EditableHatchEffect", true)
			spark:SetAttribute("UsesDefaultHatchLayout", true)
			ensureCorner(spark, 999)
			spark.Parent = effectBurst
		end
		table.insert(effectSparks, spark)
	end
end

local hatchOverlayBasePosition = hatchOverlay.Position
local hatchOverlayBaseSize = hatchOverlay.Size
local activeScreenShake = 0

local function resetRngEffects(preserveCutscene)
	if preserveCutscene ~= true then
		activeScreenShake += 1
		hatchOverlay.Position = hatchOverlayBasePosition
		hatchOverlay.Size = hatchOverlayBaseSize
	end
	if rarityFlash and rarityFlash:IsA("GuiObject") then
		rarityFlash.Visible = false
		rarityFlash.BackgroundTransparency = 1
	end
	if rarityBanner and rarityBanner:IsA("TextLabel") then
		rarityBanner.Visible = false
		rarityBanner.TextTransparency = 0
		rarityBanner.TextStrokeTransparency = 0
		rarityBanner.Position = UDim2.fromScale(0.5, 0.18)
	end
	for _, spark in ipairs(effectSparks) do
		spark.Visible = false
		spark.BackgroundTransparency = 1
		spark.Position = UDim2.new(0.5, 0, 0.46, 0)
	end
	if preserveCutscene == true then
		return
	end
	if cutsceneBackdrop and cutsceneBackdrop:IsA("GuiObject") then
		cutsceneBackdrop.Visible = false
		cutsceneBackdrop.BackgroundTransparency = 1
	end
	if cutsceneShockwave and cutsceneShockwave:IsA("GuiObject") then
		cutsceneShockwave.Visible = false
		cutsceneShockwave.Size = UDim2.fromOffset(80, 80)
		cutsceneShockwave.BackgroundTransparency = 1
		local stroke = cutsceneShockwave:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Transparency = 1
		end
	end
	if cutsceneTitle and cutsceneTitle:IsA("TextLabel") then
		cutsceneTitle.Visible = false
		cutsceneTitle.TextTransparency = 0
		cutsceneTitle.TextStrokeTransparency = 0
		cutsceneTitle.Position = UDim2.fromScale(0.5, 0.23)
	end
	if cutsceneSubtitle and cutsceneSubtitle:IsA("TextLabel") then
		cutsceneSubtitle.Visible = false
		cutsceneSubtitle.TextTransparency = 0
		cutsceneSubtitle.TextStrokeTransparency = 0.35
		cutsceneSubtitle.Position = UDim2.fromScale(0.5, 0.31)
	end
end

local function getRngRevealTier(entry)
	if not entry then
		return 1
	end

	local rarity = tostring(entry.rarity or "")
	local score = RARITY_SCORE[rarity] or 1
	if entry.isShiny == true then
		score = math.max(score, 4)
	end
	if entry.hasMutation == true then
		local mutationScore = RARITY_SCORE[tostring(entry.mutationRarity or "")] or 2
		score = math.max(score, mutationScore + 1)
		if entry.mutationType == "Corrupted" then
			score += 0.75
		end
	end
	if tonumber(entry.combinedHatchChance) and entry.combinedHatchChance <= 0.025 then
		score = math.max(score, 5)
	elseif tonumber(entry.combinedHatchChance) and entry.combinedHatchChance <= 0.12 then
		score = math.max(score, 4)
	end

	if score >= 5 then
		return 5
	elseif score >= 4 then
		return 4
	elseif score >= 3 then
		return 3
	elseif score >= 2 then
		return 2
	end
	return 1
end

local function getHatchOddsText(entry)
	if not entry then
		return ""
	end

	local petOdds = tonumber(entry.hatchPetChance)
	local mutationOdds = tonumber(entry.mutationChance)
	local combinedOdds = tonumber(entry.combinedHatchChance)
	if entry.hasMutation == true and combinedOdds then
		return "Color: " .. formatRollOdds(petOdds) .. "  |  Mutation combo: " .. formatRollOdds(combinedOdds)
	end
	if petOdds then
		return "Color odds: " .. formatRollOdds(petOdds)
	end
	if mutationOdds and entry.hasMutation == true then
		return "Mutation odds: " .. formatRollOdds(mutationOdds)
	end
	return ""
end

local function shakeHatchScreen(token, tier, duration, magnitude)
	if not getClientSetting("CameraShake", true) then
		return
	end
	activeScreenShake += 1
	local shakeId = activeScreenShake
	duration = duration or (tier >= 5 and 1.15 or tier >= 4 and 0.72 or 0.32)
	magnitude = magnitude or (tier >= 5 and 26 or tier >= 4 and 14 or 7)
	local started = os.clock()

	task.spawn(function()
		while token == hatchToken and shakeId == activeScreenShake and os.clock() - started < duration do
			local decay = 1 - ((os.clock() - started) / duration)
			local offsetX = math.random(-magnitude, magnitude) * decay
			local offsetY = math.random(-magnitude, magnitude) * decay
			hatchOverlay.Position = UDim2.new(
				hatchOverlayBasePosition.X.Scale,
				hatchOverlayBasePosition.X.Offset + offsetX,
				hatchOverlayBasePosition.Y.Scale,
				hatchOverlayBasePosition.Y.Offset + offsetY
			)
			task.wait()
		end

		if token == hatchToken and shakeId == activeScreenShake then
			hatchOverlay.Position = hatchOverlayBasePosition
			hatchOverlay.Size = hatchOverlayBaseSize
		end
	end)
end

local function playCutsceneUi(entry, tier, accentColor)
	if tier < 4 then
		return
	end

	local color = accentColor or WHITE
	if cutsceneBackdrop and cutsceneBackdrop:IsA("GuiObject") then
		cutsceneBackdrop.BackgroundColor3 = color:Lerp(Color3.fromRGB(2, 4, 12), 0.72)
		cutsceneBackdrop.BackgroundTransparency = tier >= 5 and 0.28 or 0.55
		cutsceneBackdrop.Visible = true
		TweenService:Create(cutsceneBackdrop, TweenInfo.new(tier >= 5 and 1.1 or 0.62), {
			BackgroundTransparency = 1,
		}):Play()
	end

	if cutsceneTitle and cutsceneTitle:IsA("TextLabel") then
		cutsceneTitle.Text = tier >= 5 and "REALITY-BREAKING HATCH!" or "MASSIVE HATCH!"
		if entry and entry.hasMutation then
			cutsceneTitle.Text = string.upper(tostring(entry.mutationName or "Mutation")) .. " MUTATION!"
		end
		cutsceneTitle.TextColor3 = color
		cutsceneTitle.TextTransparency = 0
		cutsceneTitle.TextStrokeTransparency = 0
		cutsceneTitle.Position = UDim2.fromScale(0.5, 0.27)
		cutsceneTitle.Visible = true
		TweenService:Create(cutsceneTitle, TweenInfo.new(0.26, Enum.EasingStyle.Back), {
			Position = UDim2.fromScale(0.5, 0.22),
		}):Play()
		task.delay(tier >= 5 and 1.35 or 0.95, function()
			if cutsceneTitle and cutsceneTitle.Parent then
				TweenService:Create(cutsceneTitle, TweenInfo.new(0.22), {
					TextTransparency = 1,
					TextStrokeTransparency = 1,
				}):Play()
			end
		end)
	end

	if cutsceneSubtitle and cutsceneSubtitle:IsA("TextLabel") then
		cutsceneSubtitle.Text = getHatchOddsText(entry)
		cutsceneSubtitle.TextColor3 = WHITE:Lerp(color, 0.18)
		cutsceneSubtitle.TextTransparency = 0
		cutsceneSubtitle.TextStrokeTransparency = 0.35
		cutsceneSubtitle.Visible = true
		task.delay(tier >= 5 and 1.35 or 0.95, function()
			if cutsceneSubtitle and cutsceneSubtitle.Parent then
				TweenService:Create(cutsceneSubtitle, TweenInfo.new(0.22), {
					TextTransparency = 1,
					TextStrokeTransparency = 1,
				}):Play()
			end
		end)
	end

	if cutsceneShockwave and cutsceneShockwave:IsA("GuiObject") then
		cutsceneShockwave.BackgroundColor3 = color
		cutsceneShockwave.BackgroundTransparency = tier >= 5 and 0.72 or 0.82
		cutsceneShockwave.Size = UDim2.fromOffset(80, 80)
		cutsceneShockwave.Visible = true
		local stroke = cutsceneShockwave:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = color:Lerp(WHITE, 0.3)
			stroke.Transparency = 0.05
		end
		TweenService:Create(cutsceneShockwave, TweenInfo.new(tier >= 5 and 0.75 or 0.48, Enum.EasingStyle.Quad), {
			BackgroundTransparency = 1,
			Size = tier >= 5 and UDim2.fromOffset(920, 920) or UDim2.fromOffset(620, 620),
		}):Play()
		if stroke then
			TweenService:Create(stroke, TweenInfo.new(tier >= 5 and 0.75 or 0.48), {
				Transparency = 1,
			}):Play()
		end
	end
end

local function spawnHatchChargeParticle(token, color)
	if not effectBurst or not effectBurst.Parent or token ~= hatchToken then
		return
	end

	local particle = Instance.new("Frame")
	particle.Name = "HatchChargeParticle"
	particle.AnchorPoint = Vector2.new(0.5, 0.5)
	particle.Position = UDim2.new(0.5, math.random(-26, 26), 0.46, math.random(-22, 22))
	local size = math.random(5, 12)
	particle.Size = UDim2.fromOffset(size, size)
	particle.BackgroundColor3 = math.random(1, 4) == 1 and WHITE or color
	particle.BackgroundTransparency = 0.1
	particle.BorderSizePixel = 0
	particle.Rotation = math.random(0, 360)
	particle.ZIndex = 914
	particle:SetAttribute("EditableHatchRuntimeEffect", true)
	particle.Parent = effectBurst
	ensureCorner(particle, math.random(3, 999))

	local angle = math.rad(math.random(0, 359))
	local distance = math.random(54, 140)
	TweenService:Create(particle, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, math.cos(angle) * distance, 0.46, math.sin(angle) * distance),
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(1, 1),
		Rotation = particle.Rotation + math.random(-180, 180),
	}):Play()
	Debris:AddItem(particle, 0.62)
end

local function playRngRevealEffects(entry, rarityColor)
	resetRngEffects(true)
	local tier = getRngRevealTier(entry)
	local burstCount =
		math.min(#effectSparks, tier >= 5 and 96 or tier == 4 and 72 or tier == 3 and 48 or tier == 2 and 30 or 18)
	local spreadMin = tier >= 5 and 185 or tier == 4 and 150 or tier == 3 and 120 or 90
	local spreadMax = tier >= 5 and 390 or tier == 4 and 310 or tier == 3 and 245 or 185
	local flashColor = entry and (entry.mutationTypeColor or entry.auraColor) or rarityColor
	flashColor = flashColor or rarityColor or WHITE

	if rarityFlash and rarityFlash:IsA("GuiObject") then
		rarityFlash.BackgroundColor3 = flashColor
		rarityFlash.BackgroundTransparency = tier >= 5 and 0.18 or tier >= 3 and 0.62 or 0.82
		rarityFlash.Visible = true
		TweenService:Create(rarityFlash, TweenInfo.new(tier >= 5 and 1.25 or tier >= 3 and 0.9 or 0.45), {
			BackgroundTransparency = 1,
		}):Play()
	end

	if rarityBanner and rarityBanner:IsA("TextLabel") then
		if tier >= 5 then
			rarityBanner.Text = entry.hasMutation and "IMPOSSIBLE MUTATION!" or "JACKPOT COLOR!"
		elseif tier >= 4 then
			rarityBanner.Text = entry.hasMutation and "MUTATION RNG!" or "LEGENDARY RNG!"
		elseif tier == 3 then
			rarityBanner.Text = "EPIC HATCH!"
		elseif tier == 2 then
			rarityBanner.Text = "RARE HATCH!"
		else
			rarityBanner.Text = "COMMON HATCH"
		end
		rarityBanner.TextColor3 = flashColor
		rarityBanner.Visible = true
		TweenService:Create(rarityBanner, TweenInfo.new(0.45, Enum.EasingStyle.Back), {
			Position = UDim2.fromScale(0.5, tier >= 3 and 0.15 or 0.18),
		}):Play()
		task.delay(tier >= 5 and 2.15 or tier >= 3 and 1.7 or 1.1, function()
			if rarityBanner and rarityBanner.Parent then
				TweenService:Create(rarityBanner, TweenInfo.new(0.28), {
					TextTransparency = 1,
					TextStrokeTransparency = 1,
				}):Play()
			end
		end)
	end

	for index = 1, burstCount do
		local spark = effectSparks[index]
		if spark then
			local size =
				math.random(tier >= 5 and 12 or tier >= 3 and 9 or 6, tier >= 5 and 26 or tier >= 3 and 18 or 12)
			local angle = math.rad((360 / burstCount) * index + math.random(-12, 12))
			local distance = math.random(spreadMin, spreadMax)
			spark.Size = UDim2.fromOffset(size, size)
			spark.Position = UDim2.new(0.5, 0, 0.46, 0)
			spark.BackgroundColor3 = index % 3 == 0 and WHITE or flashColor
			spark.BackgroundTransparency = 0
			spark.Visible = true
			TweenService:Create(spark, TweenInfo.new(0.72, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.new(0.5, math.cos(angle) * distance, 0.46, math.sin(angle) * distance),
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(2, 2),
			}):Play()
		end
	end
end

local resultCardHomePosition = resultCard.Position
local resultCardOffscreenPosition = UDim2.new(resultCardHomePosition.X.Scale, resultCardHomePosition.X.Offset, 1.18, 0)
local SPOTLIGHT_RARITIES = {
	Epic = true,
	Legendary = true,
}

local function getMainHudRoot()
	local root = ClientUIRoot.GetRoot(playerGui)
	if root and root:IsA("GuiObject") then
		return root
	end
	return rootScreenGui
end

local function closeEditableModalWindowsForSpotlight()
	local mainHud = getMainHudRoot()
	if not mainHud then
		return
	end

	local modalWindows = mainHud:FindFirstChild("ModalWindows")
	local windowsFolder = modalWindows and (modalWindows:FindFirstChild("Windows") or modalWindows)
	if windowsFolder then
		for _, child in ipairs(windowsFolder:GetChildren()) do
			if child:IsA("GuiObject") then
				child.Visible = false
			end
		end
	end

	mainHud:SetAttribute("HatchSpotlightClosedMenusAt", os.clock())
end

local function shouldSpotlightHatch(entry, pet)
	if not entry then
		return false
	end
	if entry.hasMutation == true or entry.isShiny == true then
		return true
	end
	local rarity = tostring(entry.rarity or (pet and pet.rarity) or "")
	return SPOTLIGHT_RARITIES[rarity] == true
end

local function hideHatchResult()
	resetRngEffects()
	resultCard:SetAttribute("LargeReveal", false)
	resultCard.Visible = false
	resultCard.Position = resultCardOffscreenPosition
	resultCard.Size = UDim2.new(0, 260, 0, 100)
	resultName.Visible = false
	resultRarity.Visible = false
	resultStats.Visible = false
	resultOdds.Visible = false
	resultName.Text = ""
	resultRarity.Text = ""
	resultStats.Text = ""
	resultOdds.Text = ""
end

local function prepareHatchResult(entry, pet, rarityColor, hasMutation)
	local mutationColor = entry.mutationTypeColor or entry.auraColor or rarityColor
	resultCard:SetAttribute("LargeReveal", hasMutation == true)
	resultStroke.Color = hasMutation and mutationColor or rarityColor
	resultName.Text = entry.displayName or pet.displayName
	if hasMutation then
		resultRarity.Text = tostring(entry.rarity or pet.rarity)
			.. " "
			.. PetData.GetCompanionTypeName()
			.. "\n"
			.. tostring(entry.mutationRarity or "")
			.. " "
			.. tostring(entry.mutationType or "")
			.. " Mutation: "
			.. tostring(entry.mutationName or "Mutation")
		if entry.wasDuplicate and tonumber(entry.duplicateCount) then
			resultRarity.Text ..= "\nStack now: x" .. tostring(entry.duplicateCount)
		end
		resultRarity.TextColor3 = mutationColor
		resultRarity.Size = UDim2.new(1, -28, 0, entry.wasDuplicate and 64 or 52)
		resultStats.Position = UDim2.new(0, 14, 0, entry.wasDuplicate and 116 or 102)
	else
		resultRarity.Text = tostring(entry.rarity or pet.rarity) .. " " .. PetData.GetCompanionTypeName()
		if entry.wasDuplicate and tonumber(entry.duplicateCount) then
			resultRarity.Text ..= "\nStack now: x" .. tostring(entry.duplicateCount)
		end
		resultRarity.TextColor3 = rarityColor
		resultRarity.Size = UDim2.new(1, -28, 0, entry.wasDuplicate and 38 or 20)
		resultStats.Position = UDim2.new(0, 14, 0, entry.wasDuplicate and 96 or 80)
	end

	resultStats.Text = tostring(entry.effectivePower or entry.finalPower or 0) .. "  \226\156\138  |  EQUIP MANUALLY"
	local oddsText = getHatchOddsText(entry)
	resultOdds.Visible = oddsText ~= ""
	resultOdds.Text = oddsText
	resultOdds.TextColor3 = hasMutation and mutationColor:Lerp(Color3.fromRGB(40, 35, 55), 0.25)
		or rarityColor:Lerp(Color3.fromRGB(40, 45, 70), 0.35)
end

local function revealPreparedHatchResult(spotlight)
	resultName.Visible = true
	resultRarity.Visible = true
	resultStats.Visible = true
	resultCard.Visible = true
	resultCard.Position = resultCardHomePosition
	local largeReveal = resultCard:GetAttribute("LargeReveal") == true
	resultCard.Size = largeReveal and UDim2.new(0, 320, 0, 140) or UDim2.new(0, 260, 0, 112)
	TweenService:Create(resultCard, TweenInfo.new(0.32, Enum.EasingStyle.Back), {
		Size = largeReveal and UDim2.new(0, 500, 0, 194)
			or spotlight and UDim2.new(0, 430, 0, 154)
			or UDim2.new(0, 360, 0, 136),
	}):Play()
end

local function clearPets()
	for _, child in ipairs(petGrid:GetChildren()) do
		if not child:IsA("UIGridLayout") then
			child:Destroy()
		end
	end
end

local function updatePetGrid(egg)
	clearPets()
	if not egg or type(egg.pets) ~= "table" then
		return
	end
	local count = 0
	for _, entry in ipairs(egg.pets) do
		local pet = PetData.Pets[entry.petId]
		if not pet then
			continue
		end

		count += 1
		local rarity = RARITY_COLOR[pet.rarity] or TITLE_TEXT
		local discovered = isPetDiscovered(entry.petId)
		local chip = Instance.new("Frame")
		chip.LayoutOrder = count
		chip.BackgroundColor3 = discovered and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 155, 172)
		chip.BackgroundTransparency = discovered and 0 or 0.08
		chip.BorderSizePixel = 0
		chip.ZIndex = 13
		chip.Parent = petGrid
		local chipCorner = Instance.new("UICorner")
		chipCorner.CornerRadius = UDim.new(0, 10)
		chipCorner.Parent = chip
		local chipStroke = Instance.new("UIStroke")
		chipStroke.Color = discovered and rarity or Color3.fromRGB(70, 78, 95)
		chipStroke.Thickness = 2
		chipStroke.Parent = chip

		local dot = Instance.new("Frame")
		dot.Size = UDim2.new(0, 14, 0, 14)
		dot.Position = UDim2.new(0, 8, 0.5, -7)
		dot.BackgroundColor3 = discovered and pet.color or pet.color:Lerp(Color3.fromRGB(20, 24, 35), 0.58)
		dot.BackgroundTransparency = discovered and 0 or 0.2
		dot.BorderSizePixel = 0
		dot.ZIndex = 14
		dot.Parent = chip
		local dotCorner = Instance.new("UICorner")
		dotCorner.CornerRadius = UDim.new(1, 0)
		dotCorner.Parent = dot

		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(1, -30, 0, 27)
		name.Position = UDim2.new(0, 28, 0, 4)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.LuckiestGuy
		name.TextSize = 12
		name.TextColor3 = discovered and TITLE_TEXT or Color3.fromRGB(55, 62, 78)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Text = pet.displayName
		name.ZIndex = 14
		name.Parent = chip

		local chance = Instance.new("TextLabel")
		chance.Size = UDim2.new(1, -30, 0, 20)
		chance.Position = UDim2.new(0, 28, 0, 31)
		chance.BackgroundTransparency = 1
		chance.Font = Enum.Font.GothamBold
		chance.TextSize = 10
		chance.TextColor3 = discovered and rarity or Color3.fromRGB(55, 62, 78)
		chance.TextXAlignment = Enum.TextXAlignment.Left
		chance.Text = formatChance(entry.chance) .. " - " .. (discovered and pet.rarity or "Undiscovered")
		chance.ZIndex = 14
		chance.Parent = chip

		if not discovered then
			local shade = Instance.new("Frame")
			shade.Size = UDim2.fromScale(1, 1)
			shade.Position = UDim2.fromScale(0, 0)
			shade.BackgroundColor3 = Color3.fromRGB(12, 16, 24)
			shade.BackgroundTransparency = 0.58
			shade.BorderSizePixel = 0
			shade.ZIndex = 15
			shade.Parent = chip
			local shadeCorner = Instance.new("UICorner")
			shadeCorner.CornerRadius = UDim.new(0, 10)
			shadeCorner.Parent = shade
		end
	end
	petGrid.CanvasSize = UDim2.new(0, 0, 0, math.ceil(count / 3) * 66)
end

local function refreshWorldRows()
	for eggId, row in pairs(worldRows) do
		local egg = PetData.Eggs[eggId]
		local unlocked = egg and isEggUnlocked(egg)
		local selected = eggId == selectedEggId

		row.BackgroundColor3 = selected and Color3.fromRGB(255, 245, 255) or (unlocked and WHITE or LOCKED)
		row.UIStroke.Color = selected and (egg and egg.color or TITLE_TEXT)
			or (unlocked and Color3.fromRGB(210, 205, 230) or Color3.fromRGB(150, 155, 175))
		row.Status.Text = unlocked and "READY" or "LOCKED"
		row.Status.TextColor3 = unlocked and Color3.fromRGB(35, 130, 55) or Color3.fromRGB(100, 105, 125)
	end
end

local function selectEgg(eggId)
	if isHatching then
		return
	end

	local egg = PetData.Eggs[eggId]
	if not egg then
		return
	end
	selectedEggId = eggId

	local world = getWorldForEgg(egg)
	local unlocked = isEggUnlocked(egg)
	eggIcon.BackgroundColor3 = unlocked and egg.color or LOCKED
	eggName.Text = egg.displayName
	worldName.Text = world and world.name or "Sector Egg"
	costLabel.Text = unlocked and (formatNum(egg.cost) .. " Coins")
		or ("Unlock " .. tostring(egg.areaColor) .. " first")
	costLabel.TextColor3 = unlocked and Color3.fromRGB(220, 140, 30) or Color3.fromRGB(100, 105, 125)
	setHatchButtonState(unlocked)
	updatePetGrid(egg)
	refreshWorldRows()
end

local function buildWorldRows()
	for _, world in ipairs(ColorData.Worlds) do
		if not isWorldPlayable(world.primaryColor) then
			continue
		end
		local eggId = EGG_BY_WORLD[world.primaryColor]
		local egg = eggId and PetData.Eggs[eggId]
		if not egg then
			continue
		end

		local row = Instance.new("TextButton")
		row.Name = world.primaryColor .. "EggRow"
		row.Size = UDim2.new(1, -4, 0, 54)
		row.LayoutOrder = ColorData.getWorldIndex(world.primaryColor) or 1
		row.Text = ""
		row.AutoButtonColor = false
		row.BorderSizePixel = 0
		row.ZIndex = 12
		row.Parent = worldList
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = row
		local stroke = Instance.new("UIStroke")
		stroke.Name = "UIStroke"
		stroke.Thickness = 2
		stroke.Parent = row

		local swatch = Instance.new("Frame")
		swatch.Size = UDim2.new(0, 24, 0, 24)
		swatch.Position = UDim2.new(0, 10, 0.5, -12)
		swatch.BackgroundColor3 = egg.color
		swatch.BorderSizePixel = 0
		swatch.ZIndex = 13
		swatch.Parent = row
		local swatchCorner = Instance.new("UICorner")
		swatchCorner.CornerRadius = UDim.new(1, 0)
		swatchCorner.Parent = swatch

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, -46, 0, 24)
		label.Position = UDim2.new(0, 42, 0, 7)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.LuckiestGuy
		label.TextSize = 13
		label.TextColor3 = TITLE_TEXT
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Text = world.name
		label.ZIndex = 13
		label.Parent = row

		local status = Instance.new("TextLabel")
		status.Name = "Status"
		status.Size = UDim2.new(1, -46, 0, 18)
		status.Position = UDim2.new(0, 42, 0, 30)
		status.BackgroundTransparency = 1
		status.Font = Enum.Font.GothamBold
		status.TextSize = 10
		status.TextXAlignment = Enum.TextXAlignment.Left
		status.ZIndex = 13
		status.Parent = row

		row.MouseButton1Click:Connect(function()
			selectEgg(eggId)
		end)

		worldRows[eggId] = row
	end
	worldList.CanvasSize = UDim2.new(0, 0, 0, worldLayout.AbsoluteContentSize.Y + 20)
end

local function setWorldGuisHidden(hidden)
	if hidden then
		table.clear(hiddenWorldGuis)
		for _, obj in ipairs(workspace:GetDescendants()) do
			if (obj:IsA("BillboardGui") or obj:IsA("SurfaceGui")) and obj.Enabled then
				hiddenWorldGuis[obj] = true
				obj.Enabled = false
			end
		end
	else
		for gui in pairs(hiddenWorldGuis) do
			if gui.Parent then
				gui.Enabled = true
			end
		end
		table.clear(hiddenWorldGuis)
	end
end

local function softColor(color)
	return color:Lerp(Color3.fromRGB(235, 240, 250), 0.18)
end

local function clearHatchWorld()
	for _, child in ipairs(hatchWorld:GetChildren()) do
		child:Destroy()
	end
end

local function resetEditableHatchEgg(egg)
	hatchEgg.Visible = true
	hatchEgg.Size = hatchEggBaseSize
	hatchEgg.Position = hatchEggBasePosition
	hatchEgg.Rotation = hatchEggBaseRotation
	hatchEgg.BackgroundTransparency = hatchEggBaseTransparency
	hatchEgg.BackgroundColor3 = softColor((egg and egg.color) or hatchEggBaseColor)
	hatchEgg.ZIndex = math.max(hatchEgg.ZIndex, 900)

	local stroke = hatchEgg:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Transparency = 0
	end

	for _, crack in ipairs(hatchEggCracks) do
		crack.Visible = false
		crack.BackgroundTransparency = 0
	end
end

local function hideEditableHatchEgg()
	hatchEgg.Visible = false
	hatchEgg.Size = hatchEggBaseSize
	hatchEgg.Position = hatchEggBasePosition
	hatchEgg.Rotation = hatchEggBaseRotation
	hatchEgg.BackgroundTransparency = hatchEggBaseTransparency
	hatchEgg.BackgroundColor3 = hatchEggBaseColor
	local stroke = hatchEgg:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Transparency = 0
	end
	for _, crack in ipairs(hatchEggCracks) do
		crack.Visible = false
		crack.BackgroundTransparency = 0
	end
end

local function animateEditableHatchEgg(token)
	task.spawn(function()
		local lastParticleAt = 0
		while hatchPending and token == hatchToken and hatchOverlay.Visible and hatchEgg.Visible do
			local elapsed = os.clock() - hatchStartedAt
			local intensity = math.clamp(elapsed / 1.7, 0.25, 1)
			local shakeX = math.sin(elapsed * 31) * 7 * intensity
			local shakeY = math.abs(math.sin(elapsed * 12)) * -10 * intensity
			local grow = 1 + math.sin(elapsed * 18) * 0.035

			hatchEgg.Position = UDim2.new(
				hatchEggBasePosition.X.Scale,
				hatchEggBasePosition.X.Offset + shakeX,
				hatchEggBasePosition.Y.Scale,
				hatchEggBasePosition.Y.Offset + shakeY
			)
			hatchEgg.Rotation = hatchEggBaseRotation + math.sin(elapsed * 24) * 10 * intensity
			hatchEgg.Size = UDim2.new(
				hatchEggBaseSize.X.Scale * grow,
				math.floor(hatchEggBaseSize.X.Offset * grow),
				hatchEggBaseSize.Y.Scale * grow,
				math.floor(hatchEggBaseSize.Y.Offset * grow)
			)

			if elapsed > 0.9 then
				hatchText.Text = "CRACKING"
				for index, crack in ipairs(hatchEggCracks) do
					crack.Visible = elapsed > (0.82 + index * 0.18)
				end
			end

			if os.clock() - lastParticleAt > math.max(0.035, 0.11 - intensity * 0.045) then
				lastParticleAt = os.clock()
				spawnHatchChargeParticle(token, hatchEgg.BackgroundColor3:Lerp(WHITE, 0.22))
			end

			task.wait()
		end
	end)
end

local function popEditableHatchEgg(token, tier, accentColor)
	tier = tier or 1
	accentColor = accentColor or hatchEgg.BackgroundColor3
	for _, crack in ipairs(hatchEggCracks) do
		crack.Visible = true
	end

	local stroke = hatchEgg:FindFirstChildOfClass("UIStroke")
	if stroke then
		TweenService:Create(stroke, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = 1,
		}):Play()
	end

	TweenService:Create(hatchEgg, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
		Size = UDim2.new(
			hatchEggBaseSize.X.Scale * (tier >= 5 and 1.8 or tier >= 4 and 1.55 or 1.35),
			math.floor(hatchEggBaseSize.X.Offset * (tier >= 5 and 1.8 or tier >= 4 and 1.55 or 1.35)),
			hatchEggBaseSize.Y.Scale * (tier >= 5 and 1.8 or tier >= 4 and 1.55 or 1.35),
			math.floor(hatchEggBaseSize.Y.Offset * (tier >= 5 and 1.8 or tier >= 4 and 1.55 or 1.35))
		),
		BackgroundTransparency = 1,
		Rotation = hatchEggBaseRotation,
	}):Play()

	local shardCount = tier >= 5 and 44 or tier >= 4 and 32 or tier >= 3 and 24 or 14
	for index = 1, shardCount do
		local shard = Instance.new("Frame")
		shard.Name = "EggExplosionShard"
		shard.AnchorPoint = Vector2.new(0.5, 0.5)
		shard.Position = hatchEggBasePosition
		local shardSize = math.random(tier >= 4 and 8 or 5, tier >= 4 and 18 or 12)
		shard.Size = UDim2.fromOffset(shardSize, math.max(3, math.floor(shardSize * 0.55)))
		shard.BackgroundColor3 = index % 4 == 0 and WHITE or hatchEgg.BackgroundColor3:Lerp(accentColor, math.random())
		shard.BackgroundTransparency = 0.04
		shard.BorderSizePixel = 0
		shard.Rotation = math.random(0, 360)
		shard.ZIndex = 916
		shard:SetAttribute("EditableHatchRuntimeEffect", true)
		shard.Parent = effectBurst or hatchOverlay
		ensureCorner(shard, math.random(3, 8))

		local angle = math.rad((360 / shardCount) * index + math.random(-20, 20))
		local distance = math.random(tier >= 5 and 210 or 105, tier >= 5 and 430 or tier >= 4 and 320 or 210)
		TweenService:Create(shard, TweenInfo.new(tier >= 5 and 0.86 or 0.62, Enum.EasingStyle.Quad), {
			Position = UDim2.new(
				hatchEggBasePosition.X.Scale,
				hatchEggBasePosition.X.Offset + math.cos(angle) * distance,
				hatchEggBasePosition.Y.Scale,
				hatchEggBasePosition.Y.Offset + math.sin(angle) * distance
			),
			BackgroundTransparency = 1,
			Rotation = shard.Rotation + math.random(-360, 360),
			Size = UDim2.fromOffset(1, 1),
		}):Play()
		Debris:AddItem(shard, 0.95)
	end

	task.wait(0.18)
	if token == hatchToken then
		hideEditableHatchEgg()
	end
end

local function makeViewportPart(parent, name, shape, size, color, cframe, material, transparency)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape or Enum.PartType.Block
	part.Size = size
	part.CFrame = cframe or CFrame.new()
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Transparency = transparency or 0
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

local function createEggViewportModel(egg)
	local model = Instance.new("Model")
	model.Name = "HatchingEgg"
	model.Parent = hatchWorld

	local shellColor = softColor((egg and egg.color) or Color3.fromRGB(180, 100, 255))
	local shell = makeViewportPart(
		model,
		"Shell",
		Enum.PartType.Ball,
		Vector3.new(2.35, 3.15, 2.35),
		shellColor,
		CFrame.new(0, 0, 0),
		Enum.Material.SmoothPlastic
	)
	model.PrimaryPart = shell

	makeViewportPart(
		model,
		"Glow",
		Enum.PartType.Ball,
		Vector3.new(2.65, 3.45, 2.65),
		shellColor,
		CFrame.new(0, 0, 0),
		Enum.Material.ForceField,
		0.78
	)
	makeViewportPart(
		model,
		"Highlight",
		Enum.PartType.Ball,
		Vector3.new(0.42, 0.72, 0.12),
		WHITE,
		CFrame.new(-0.55, 0.82, 1.08) * CFrame.Angles(0, 0, math.rad(-18)),
		Enum.Material.SmoothPlastic,
		0.25
	)

	local spotColor = shellColor:Lerp(Color3.fromRGB(255, 255, 255), 0.22)
	makeViewportPart(
		model,
		"Spot1",
		Enum.PartType.Ball,
		Vector3.new(0.38, 0.25, 0.08),
		spotColor,
		CFrame.new(0.42, 0.48, 1.15),
		Enum.Material.SmoothPlastic,
		0.08
	)
	makeViewportPart(
		model,
		"Spot2",
		Enum.PartType.Ball,
		Vector3.new(0.28, 0.2, 0.08),
		spotColor,
		CFrame.new(-0.34, -0.25, 1.16),
		Enum.Material.SmoothPlastic,
		0.08
	)

	local crackColor = Color3.fromRGB(48, 38, 58)
	for i, data in ipairs({
		{ pos = Vector3.new(-0.03, 0.42, 1.22), size = Vector3.new(0.08, 0.58, 0.06), rot = -28 },
		{ pos = Vector3.new(0.16, 0.04, 1.23), size = Vector3.new(0.07, 0.54, 0.06), rot = 34 },
		{ pos = Vector3.new(-0.16, -0.22, 1.24), size = Vector3.new(0.07, 0.42, 0.06), rot = -45 },
	}) do
		local crack = makeViewportPart(
			model,
			"Crack" .. i,
			Enum.PartType.Block,
			data.size,
			crackColor,
			CFrame.new(data.pos) * CFrame.Angles(0, 0, math.rad(data.rot)),
			Enum.Material.SmoothPlastic,
			1
		)
		crack:SetAttribute("Crack", true)
	end

	return model
end

local function makeEye(parent, x, y, z)
	return makeViewportPart(
		parent,
		"Eye",
		Enum.PartType.Ball,
		Vector3.new(0.12, 0.12, 0.06),
		Color3.fromRGB(25, 28, 35),
		CFrame.new(x, y, z),
		Enum.Material.SmoothPlastic
	)
end

local function createFallbackPetModel(entry)
	local pet = PetData.Pets[entry.petId]
	if not pet then
		return nil
	end

	local model = Instance.new("Model")
	model.Name = entry.petId .. "Reveal"
	model.Parent = hatchWorld

	local name = string.lower(pet.displayName or entry.petId)
	local mainColor = softColor(pet.color)
	local accent = mainColor:Lerp(WHITE, 0.35)
	local dark = mainColor:Lerp(Color3.fromRGB(20, 24, 32), 0.35)

	local bodyShape = (string.find(name, "cubey") or string.find(name, "golem") or string.find(name, "titan"))
			and Enum.PartType.Block
		or Enum.PartType.Ball
	local body = makeViewportPart(
		model,
		"Body",
		bodyShape,
		Vector3.new(1.45, 1.35, 1.25),
		mainColor,
		CFrame.new(0, -0.1, 0),
		Enum.Material.SmoothPlastic
	)
	model.PrimaryPart = body

	local head = makeViewportPart(
		model,
		"Head",
		Enum.PartType.Ball,
		Vector3.new(1.0, 0.88, 0.9),
		accent,
		CFrame.new(0, 0.76, 0.03),
		Enum.Material.SmoothPlastic
	)
	makeEye(model, -0.22, 0.85, 0.48)
	makeEye(model, 0.22, 0.85, 0.48)

	if string.find(name, "bee") then
		makeViewportPart(
			model,
			"StripeA",
			Enum.PartType.Block,
			Vector3.new(1.52, 0.12, 0.08),
			dark,
			CFrame.new(0, -0.18, 0.64),
			Enum.Material.SmoothPlastic
		)
		makeViewportPart(
			model,
			"StripeB",
			Enum.PartType.Block,
			Vector3.new(1.2, 0.1, 0.08),
			dark,
			CFrame.new(0, 0.1, 0.65),
			Enum.Material.SmoothPlastic
		)
		makeViewportPart(
			model,
			"LeftWing",
			Enum.PartType.Ball,
			Vector3.new(0.8, 0.18, 0.62),
			Color3.fromRGB(225, 248, 255),
			CFrame.new(-0.72, 0.35, -0.08) * CFrame.Angles(0, 0, math.rad(-25)),
			Enum.Material.Glass,
			0.28
		)
		makeViewportPart(
			model,
			"RightWing",
			Enum.PartType.Ball,
			Vector3.new(0.8, 0.18, 0.62),
			Color3.fromRGB(225, 248, 255),
			CFrame.new(0.72, 0.35, -0.08) * CFrame.Angles(0, 0, math.rad(25)),
			Enum.Material.Glass,
			0.28
		)
	elseif
		string.find(name, "bunny")
		or string.find(name, "mouse")
		or string.find(name, "cat")
		or string.find(name, "fox")
		or string.find(name, "wolf")
		or string.find(name, "pup")
		or string.find(name, "panda")
		or string.find(name, "bear")
		or string.find(name, "lion")
	then
		makeViewportPart(
			model,
			"LeftEar",
			Enum.PartType.Ball,
			Vector3.new(0.28, 0.82, 0.24),
			accent,
			CFrame.new(-0.36, 1.36, 0) * CFrame.Angles(0, 0, math.rad(-13)),
			Enum.Material.SmoothPlastic
		)
		makeViewportPart(
			model,
			"RightEar",
			Enum.PartType.Ball,
			Vector3.new(0.28, 0.82, 0.24),
			accent,
			CFrame.new(0.36, 1.36, 0) * CFrame.Angles(0, 0, math.rad(13)),
			Enum.Material.SmoothPlastic
		)
		makeViewportPart(
			model,
			"Tail",
			Enum.PartType.Ball,
			Vector3.new(0.46, 0.46, 0.46),
			accent,
			CFrame.new(0.78, -0.24, -0.42),
			Enum.Material.SmoothPlastic
		)
	elseif
		string.find(name, "dragon")
		or string.find(name, "bat")
		or string.find(name, "moth")
		or string.find(name, "wyvern")
		or string.find(name, "phoenix")
		or string.find(name, "finch")
		or string.find(name, "hydra")
	then
		makeViewportPart(
			model,
			"LeftWing",
			Enum.PartType.Block,
			Vector3.new(0.12, 1.15, 1.25),
			mainColor:Lerp(WHITE, 0.18),
			CFrame.new(-0.95, 0.18, -0.05) * CFrame.Angles(0, 0, math.rad(-28)),
			Enum.Material.SmoothPlastic
		)
		makeViewportPart(
			model,
			"RightWing",
			Enum.PartType.Block,
			Vector3.new(0.12, 1.15, 1.25),
			mainColor:Lerp(WHITE, 0.18),
			CFrame.new(0.95, 0.18, -0.05) * CFrame.Angles(0, 0, math.rad(28)),
			Enum.Material.SmoothPlastic
		)
		makeViewportPart(
			model,
			"Crest",
			Enum.PartType.Ball,
			Vector3.new(0.26, 0.42, 0.2),
			dark,
			CFrame.new(0, 1.28, 0.04),
			Enum.Material.SmoothPlastic
		)
	elseif string.find(name, "sprout") then
		makeViewportPart(
			model,
			"Stem",
			Enum.PartType.Block,
			Vector3.new(0.12, 0.5, 0.12),
			dark,
			CFrame.new(0, 1.25, 0),
			Enum.Material.SmoothPlastic
		)
		makeViewportPart(
			model,
			"LeafL",
			Enum.PartType.Ball,
			Vector3.new(0.55, 0.2, 0.28),
			Color3.fromRGB(110, 230, 120),
			CFrame.new(-0.24, 1.48, 0) * CFrame.Angles(0, 0, math.rad(-24)),
			Enum.Material.SmoothPlastic
		)
		makeViewportPart(
			model,
			"LeafR",
			Enum.PartType.Ball,
			Vector3.new(0.55, 0.2, 0.28),
			Color3.fromRGB(110, 230, 120),
			CFrame.new(0.24, 1.48, 0) * CFrame.Angles(0, 0, math.rad(24)),
			Enum.Material.SmoothPlastic
		)
	elseif string.find(name, "turtle") then
		makeViewportPart(
			model,
			"Shell",
			Enum.PartType.Ball,
			Vector3.new(1.55, 0.78, 1.15),
			dark,
			CFrame.new(0, 0.1, -0.08),
			Enum.Material.SmoothPlastic
		)
	elseif string.find(name, "unicorn") then
		makeViewportPart(
			model,
			"Horn",
			Enum.PartType.Block,
			Vector3.new(0.16, 0.62, 0.16),
			Color3.fromRGB(255, 245, 160),
			CFrame.new(0, 1.36, 0.2) * CFrame.Angles(0, 0, math.rad(45)),
			Enum.Material.SmoothPlastic
		)
	end

	local light = Instance.new("PointLight")
	light.Color = pet.color
	light.Range = 8
	light.Brightness = entry.rarity == "Legendary" and 1.6 or entry.rarity == "Epic" and 1.15 or 0.8
	light.Parent = body

	return model
end

local function createPetViewportModel(entry)
	local pet = entry and PetData.Pets[entry.petId]
	if not pet then
		return nil
	end

	local model = PetModelUtil.ClonePetModel(entry.petId, { anchored = true, removeBillboards = true })
	if model and model:IsA("Model") then
		model.Name = entry.petId .. "Reveal"
		model.Parent = hatchWorld
		if not model.PrimaryPart then
			local core = model:FindFirstChild("Core") or model:FindFirstChildOfClass("BasePart")
			if core then
				model.PrimaryPart = core
			end
		end
		local extents = model:GetExtentsSize()
		local largest = math.max(extents.X, extents.Y, extents.Z)
		if largest > 4.2 then
			pcall(function()
				model:ScaleTo(4.2 / largest)
			end)
		end
		if entry.hasMutation and model.PrimaryPart then
			local mutationColor = entry.mutationTypeColor or entry.auraColor or pet.color
			local highlight = Instance.new("Highlight")
			highlight.Name = "RevealMutationHighlight"
			highlight.Adornee = model
			highlight.FillColor = mutationColor
			highlight.OutlineColor = entry.mutationType == "Corrupted" and Color3.fromRGB(80, 240, 255)
				or Color3.fromRGB(255, 255, 255)
			highlight.FillTransparency = entry.mutationType == "Corrupted" and 0.5 or 0.65
			highlight.OutlineTransparency = 0.08
			highlight.Parent = model

			local light = Instance.new("PointLight")
			light.Name = "RevealMutationLight"
			light.Color = mutationColor
			light.Range = 10
			light.Brightness = entry.mutationRarity == "Legendary" and 2.2 or 1.45
			light.Parent = model.PrimaryPart
		end
		return model
	end

	model = Instance.new("Model")
	model.Name = entry.petId .. "OrbReveal"
	model.Parent = hatchWorld

	local orbColor = entry.isShiny and pet.color:Lerp(Color3.fromRGB(255, 255, 255), 0.5) or pet.color
	if entry.hasMutation and entry.auraColor then
		orbColor = entry.auraColor
	end
	local orb = makeViewportPart(
		model,
		"PetOrb",
		Enum.PartType.Ball,
		Vector3.new(1.95, 1.95, 1.95),
		orbColor,
		CFrame.new(0, 0, 0),
		Enum.Material.SmoothPlastic
	)
	model.PrimaryPart = orb

	makeViewportPart(
		model,
		"OrbHighlight",
		Enum.PartType.Ball,
		Vector3.new(0.42, 0.42, 0.12),
		WHITE,
		CFrame.new(-0.46, 0.48, 0.86),
		Enum.Material.SmoothPlastic,
		0.18
	)
	makeViewportPart(
		model,
		"OrbGlow",
		Enum.PartType.Ball,
		Vector3.new(2.32, 2.32, 2.32),
		entry.auraColor or orbColor,
		CFrame.new(0, 0, 0),
		Enum.Material.ForceField,
		(entry.isShiny or entry.hasMutation) and 0.38 or 0.72
	)

	if entry.isShiny then
		makeViewportPart(
			model,
			"ShinyRing",
			Enum.PartType.Ball,
			Vector3.new(2.62, 2.62, 2.62),
			Color3.fromRGB(255, 250, 190),
			CFrame.new(0, 0, 0),
			Enum.Material.ForceField,
			0.68
		)
	end

	if entry.hasMutation then
		makeViewportPart(
			model,
			"MutationRing",
			Enum.PartType.Ball,
			Vector3.new(2.82, 2.82, 2.82),
			entry.auraColor or orbColor,
			CFrame.new(0, 0, 0),
			Enum.Material.ForceField,
			0.62
		)
	end

	if entry.trait then
		local traitColor = entry.trait.color or WHITE
		makeViewportPart(
			model,
			"TraitAura",
			Enum.PartType.Ball,
			Vector3.new(2.82, 2.82, 2.82),
			traitColor,
			CFrame.new(0, 0, 0),
			Enum.Material.ForceField,
			0.78
		)
	end

	local light = Instance.new("PointLight")
	light.Color = (entry.isShiny or entry.hasMutation) and (entry.auraColor or Color3.fromRGB(255, 245, 185))
		or orbColor
	light.Range = 9
	light.Brightness = entry.hasMutation and 1.9 or entry.isShiny and 1.6 or 0.9
	light.Parent = orb

	return model
end

local function showError(message)
	if screenGui:IsA("GuiObject") then
		screenGui.Visible = true
	end
	if rootScreenGui then
		rootScreenGui.Enabled = true
	end
	hatchOverlay.Visible = true
	updateHatchFocusState()
	hideEditableHatchEgg()
	hatchViewport.Visible = false
	hideHatchResult()
	clearHatchWorld()
	hatchText.Text = message or "CAN'T HATCH"
	hatchText.TextColor3 = Color3.fromRGB(255, 120, 150)
	task.delay(1, function()
		hatchOverlay.Visible = false
		hatchText.TextColor3 = WHITE
		updateHatchFocusState()
	end)
end

local function finishHatchLock(token)
	if token and token ~= hatchToken then
		return
	end
	setHatchingLocked(false)
	hatchInputLockedUntil = math.max(hatchInputLockedUntil, os.clock() + 0.2)
end

local function startHatchAnimation(eggId)
	local egg = PetData.Eggs[eggId]
	if not egg then
		return
	end

	if screenGui:IsA("GuiObject") then
		screenGui.Visible = true
	end
	if rootScreenGui then
		rootScreenGui.Enabled = true
	end
	hatchToken += 1
	local token = hatchToken
	hatchStartedAt = os.clock()
	hatchPending = true
	hatchOverlay.Visible = true
	updateHatchFocusState()
	resetEditableHatchEgg(egg)
	hatchViewport.Visible = true
	hideHatchResult()
	hatchViewport.Size = UDim2.new(0, 260, 0, 230)
	clearHatchWorld()

	local eggModel = createEggViewportModel(egg)
	hatchText.Text = "HATCHING"
	hatchText.TextColor3 = WHITE

	TweenService:Create(hatchViewport, TweenInfo.new(0.45, Enum.EasingStyle.Back), {
		Size = UDim2.new(0, 360, 0, 300),
	}):Play()
	animateEditableHatchEgg(token)

	task.spawn(function()
		while hatchPending and token == hatchToken and eggModel and eggModel.Parent and hatchOverlay.Visible do
			local elapsed = os.clock() - hatchStartedAt
			local shake = math.clamp(elapsed / 1.8, 0.25, 1.6)
			local tilt = math.sin(elapsed * 18) * math.rad(8 + 7 * shake)
			local bob = math.sin(elapsed * 9) * 0.08
			eggModel:PivotTo(CFrame.new(0, bob, 0) * CFrame.Angles(0, math.sin(elapsed * 2.2) * 0.15, tilt))

			if elapsed > 1.05 then
				hatchText.Text = "CRACKING"
				for _, part in ipairs(eggModel:GetDescendants()) do
					if part:IsA("BasePart") and part:GetAttribute("Crack") then
						part.Transparency = 0
					end
				end
			end

			task.wait()
		end
	end)
end

local function revealHatch(entry)
	local token = hatchToken
	local pet = entry and PetData.Pets[entry.petId]
	if not pet then
		hatchOverlay.Visible = false
		updateHatchFocusState()
		clearHatchWorld()
		finishHatchLock(token)
		return
	end

	local revealDelay = math.max(0, 2.25 - (os.clock() - hatchStartedAt))
	if revealDelay > 0 then
		task.wait(revealDelay)
	end
	if token ~= hatchToken then
		return
	end

	hatchPending = false
	local rarityColor = RARITY_COLOR[entry.rarity] or WHITE
	local hasMutation = entry.hasMutation == true
	local mutationColor = entry.mutationTypeColor or entry.auraColor or rarityColor
	local revealTier = getRngRevealTier(entry)
	local specialMutation = revealTier >= 4
	local spotlightReveal = shouldSpotlightHatch(entry, pet)
	if spotlightReveal then
		closeEditableModalWindowsForSpotlight()
	end
	prepareHatchResult(entry, pet, rarityColor, hasMutation)

	hatchText.Text = "CRACK!"
	hatchText.TextColor3 = hasMutation and mutationColor or rarityColor
	TweenService:Create(hatchViewport, TweenInfo.new(0.18, Enum.EasingStyle.Back), {
		Size = specialMutation and UDim2.new(0, 450, 0, 360) or UDim2.new(0, 410, 0, 330),
	}):Play()
	if revealTier >= 4 then
		playCutsceneUi(entry, revealTier, hasMutation and mutationColor or rarityColor)
		shakeHatchScreen(token, revealTier)
		task.wait(revealTier >= 5 and 0.38 or 0.12)
	end
	popEditableHatchEgg(token, revealTier, hasMutation and mutationColor or rarityColor)
	task.wait(0.07)
	if token ~= hatchToken then
		return
	end

	clearHatchWorld()
	local petModel = createPetViewportModel(entry)
	if petModel and petModel.PrimaryPart then
		petModel:PivotTo(CFrame.new(0, -0.15, 0) * CFrame.Angles(0, math.rad(180), 0))
	end

	hatchViewport.Size = UDim2.new(0, 150, 0, 130)
	TweenService:Create(hatchViewport, TweenInfo.new(0.46, Enum.EasingStyle.Back), {
		Size = specialMutation and UDim2.new(0, 440, 0, 350) or UDim2.new(0, 390, 0, 310),
	}):Play()

	if hasMutation then
		hatchText.Text = string.upper(tostring(entry.mutationName or "Mutation")) .. " MUTATION!"
	elseif entry.wasDuplicate and tonumber(entry.duplicateCount) then
		hatchText.Text = "DUPLICATE! STACK x" .. tostring(entry.duplicateCount)
	elseif revealTier <= 1 then
		hatchText.Text = "COMMON COLOR"
	else
		hatchText.Text = "YOU HATCHED!"
	end
	hatchText.TextColor3 = hasMutation and mutationColor or rarityColor
	playRngRevealEffects(entry, hasMutation and mutationColor or rarityColor)
	revealPreparedHatchResult(spotlightReveal)

	local spinConnection
	if petModel and petModel.PrimaryPart then
		local startTime = os.clock()
		spinConnection = RunService.RenderStepped:Connect(function()
			if token ~= hatchToken or not petModel.Parent or not petModel.PrimaryPart then
				if spinConnection then
					spinConnection:Disconnect()
				end
				return
			end

			local elapsed = os.clock() - startTime
			local y = -0.12 + math.sin(elapsed * 3.2) * 0.08
			petModel:PivotTo(CFrame.new(0, y, 0) * CFrame.Angles(0, math.rad(180) + elapsed * 1.4, 0))
		end)
	end

	task.delay(3.2, function()
		if token ~= hatchToken then
			return
		end
		if spinConnection then
			spinConnection:Disconnect()
		end
		clearHatchWorld()
		hideEditableHatchEgg()
		hatchViewport.Visible = false
		hatchOverlay.Visible = false
		hideHatchResult()
		finishHatchLock(token)
		updateHatchFocusState()
	end)
end

local function toggleShop(open, eggId)
	if eggId and PetData.Eggs[eggId] then
		selectedEggId = eggId
	elseif open then
		selectedEggId = selectedEggId or chooseBestUnlockedEgg()
	end

	isOpen = open
	modalBackdrop.Visible = open
	panel.Visible = open
	if open then
		setWorldGuisHidden(true)
		selectEgg(selectedEggId or chooseBestUnlockedEgg())
		panel.Size = UDim2.new(0, PANEL_WIDTH, 0, 70)
		panel.Position = UDim2.fromScale(0.5, 0.5)
		TweenService:Create(panel, TweenInfo.new(0.26, Enum.EasingStyle.Back), {
			Size = UDim2.new(0, PANEL_WIDTH, 0, PANEL_HEIGHT),
			Position = UDim2.fromScale(0.5, 0.5),
		}):Play()
	else
		if not isHatching then
			hatchToken += 1
			hatchPending = false
			hatchOverlay.Visible = false
			updateHatchFocusState()
			hideEditableHatchEgg()
			hatchViewport.Visible = false
			hideHatchResult()
			clearHatchWorld()
		end
		setWorldGuisHidden(false)
	end
end

modalBackdrop.MouseButton1Click:Connect(function()
	toggleShop(false)
end)

closeBtn.MouseButton1Click:Connect(function()
	toggleShop(false)
end)

local function requestHatch(eggId, fromAutoHatch)
	if isLegacyEggHatchingDisabled() then
		autoHatchEnabled = false
		showError("USE THE RED CORE")
		return false
	end

	local now = os.clock()
	if now < hatchInputLockedUntil then
		return false
	end
	if isHatching or hatchPending then
		if not fromAutoHatch then
			setHatchButtonState(getSelectedEggUnlocked())
		end
		return false
	end
	if autoHatchEnabled and not fromAutoHatch then
		setHatchButtonState(getSelectedEggUnlocked())
		return false
	end

	local targetEggId = eggId or selectedEggId
	local egg = PetData.Eggs[targetEggId]
	if not egg then
		return false
	end
	if
		not fromAutoHatch
		and lastHatchRequestEggId == targetEggId
		and now - lastHatchRequestAt < CLIENT_HATCH_REQUEST_COOLDOWN
	then
		return false
	end
	if not isEggUnlocked(egg) then
		showError("UNLOCK " .. tostring(egg.areaColor))
		return false
	end
	selectedEggId = targetEggId
	lastHatchRequestAt = now
	lastHatchRequestEggId = targetEggId
	hatchInputLockedUntil = now + math.max(2.4, CLIENT_HATCH_REQUEST_COOLDOWN)
	setHatchingLocked(true)
	startHatchAnimation(targetEggId)
	toggleShop(false)
	hatchEvent:FireServer(targetEggId)
	return true
end

hatchBtn.MouseButton1Click:Connect(function()
	requestHatch(selectedEggId)
end)

local function hookProximityPrompt(obj)
	if
		obj:IsA("ProximityPrompt")
		and (
			obj:GetAttribute("EggShopPrompt")
			or obj.Name == "EggShopPrompt"
			or obj.ObjectText == "Egg Shop"
			or obj.ObjectText == "Starter Egg"
		)
	then
		if isLegacyEggHatchingDisabled() then
			obj.Enabled = false
			obj:SetAttribute("EggShopClientHooked", true)
			return
		end
		if obj:GetAttribute("EggShopClientHooked") == true then
			return
		end
		obj:SetAttribute("EggShopClientHooked", true)
		eggPrompts[obj] = true
		obj.Enabled = not isHatching
		bindEggStation(obj.Parent)
		configureEggPrompt(obj)
		obj.Triggered:Connect(function(triggeringPlayer)
			if triggeringPlayer ~= player then
				return
			end
			if isHatching or hatchPending then
				return
			end

			local parent = obj.Parent
			local eggId = getEggIdFromPart(parent)
			requestHatch(eggId or chooseBestUnlockedEgg())
		end)
	end
end

local function scanEggStations()
	for _, obj in ipairs(workspace:GetDescendants()) do
		hookProximityPrompt(obj)
		if obj:IsA("BasePart") and obj:GetAttribute("EggId") then
			bindEggStation(obj)
		elseif obj:IsA("BillboardGui") and obj.Name == "EggOptions" then
			bindEggStation(obj.Parent)
		end
	end
end

scanEggStations()
workspace.DescendantAdded:Connect(function(obj)
	hookProximityPrompt(obj)
	if obj:IsA("BasePart") and obj:GetAttribute("EggId") then
		bindEggStation(obj)
		obj:GetAttributeChangedSignal("EggId"):Connect(function()
			bindEggStation(obj)
		end)
	elseif obj:IsA("BillboardGui") and obj.Name == "EggOptions" then
		bindEggStation(obj.Parent)
	end
	if isOpen and (obj:IsA("BillboardGui") or obj:IsA("SurfaceGui")) and obj.Enabled then
		hiddenWorldGuis[obj] = true
		obj.Enabled = false
	end
end)

task.spawn(function()
	for _ = 1, 12 do
		task.wait(0.5)
		scanEggStations()
	end
end)

local function stopAutoHatch()
	autoHatchEnabled = false
	setHatchButtonState(getSelectedEggUnlocked())
	setEggOptionsVisible(currentNearbyEgg)
	updateHatchFocusState()
end

local function startAutoHatch()
	if autoHatchEnabled then
		stopAutoHatch()
		return
	end
	if autoHatchRunning then
		return
	end

	local eggPart = currentNearbyEgg
	local eggId = getEggIdFromPart(eggPart)
	if not eggId or not PetData.Eggs[eggId] then
		return
	end

	autoHatchEnabled = true
	autoHatchRunning = true
	updateHatchFocusState()
	setHatchButtonState(getSelectedEggUnlocked())
	setEggOptionsVisible(eggPart)

	autoHatchThread = task.spawn(function()
		while autoHatchEnabled do
			if currentNearbyEgg ~= eggPart or not eggPart.Parent then
				break
			end

			local autoDelay = tonumber(GameBalance.AutoHatchDelay) or 2.6
			if not isHatching and not hatchPending and os.clock() - lastAutoHatchAt >= autoDelay then
				lastAutoHatchAt = os.clock()
				local started = requestHatch(eggId, true)
				if not started and not isHatching then
					autoHatchEnabled = false
					break
				end
			end

			task.wait(0.15)
		end

		autoHatchEnabled = false
		autoHatchRunning = false
		autoHatchThread = nil
		updateHatchFocusState()
		setHatchButtonState(getSelectedEggUnlocked())
		setEggOptionsVisible(currentNearbyEgg)
	end)
end

stopAutoButton.MouseButton1Click:Connect(function()
	stopAutoHatch()
end)

local lastEggScanAt = 0
RunService.RenderStepped:Connect(function()
	if os.clock() - lastEggScanAt < 0.12 then
		return
	end
	lastEggScanAt = os.clock()

	local nearestEgg = findNearestEggPart()
	if nearestEgg ~= currentNearbyEgg then
		currentNearbyEgg = nearestEgg
		if not currentNearbyEgg then
			stopAutoHatch()
		end
	end
	setEggOptionsVisible(currentNearbyEgg)
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or UserInputService:GetFocusedTextBox() then
		return
	end

	if input.KeyCode == Enum.KeyCode.E and currentNearbyEgg then
		local eggId = getEggIdFromPart(currentNearbyEgg)
		requestHatch(eggId or chooseBestUnlockedEgg())
	elseif input.KeyCode == Enum.KeyCode.R and currentNearbyEgg then
		startAutoHatch()
	end
end)

hatchEvent.OnClientEvent:Connect(function(success, entry, message)
	if type(success) == "table" then
		local result = success
		success = result.Success == true or result.success == true
		entry = result.Entry or result.entry or result.Reward or result.reward
		message = result.Error or result.error or result.Reason or result.reason or result.Message or result.message
	end

	if not isHatching and not hatchPending and not hatchOverlay.Visible then
		if success and entry then
			setHatchingLocked(true)
			startHatchAnimation(entry.eggId or selectedEggId or chooseBestUnlockedEgg())
			revealHatch(entry)
		end
		return
	end

	if not success then
		if message == "Already hatching" and (isHatching or hatchPending or hatchOverlay.Visible) then
			return
		end
		stopAutoHatch()
		hatchPending = false
		showError(message or "CAN'T HATCH")
		finishHatchLock()
		return
	end

	if entry and entry.petId then
		ownedPetIds[entry.petId] = true
		refreshEggPromptPreviews()
		updatePetGrid(PetData.Eggs[entry.eggId or selectedEggId] or PetData.Eggs[selectedEggId])
	end
	revealHatch(entry)
end)

unlockedColors:GetPropertyChangedSignal("Value"):Connect(function()
	refreshWorldRows()
	selectEgg(selectedEggId or chooseBestUnlockedEgg())
end)

if coinsValue then
	coinsValue:GetPropertyChangedSignal("Value"):Connect(function()
		setHatchButtonState(getSelectedEggUnlocked())
	end)
end

buildWorldRows()
refreshOwnedPets()
selectEgg(selectedEggId or chooseBestUnlockedEgg())

task.spawn(function()
	local petFolder = player:WaitForChild("PetData", 15)
	if not petFolder then
		return
	end
	local inventoryValue = petFolder:WaitForChild("Inventory", 10)
	if not inventoryValue then
		return
	end
	refreshOwnedPets()
	refreshEggPromptPreviews()
	if selectedEggId and PetData.Eggs[selectedEggId] then
		updatePetGrid(PetData.Eggs[selectedEggId])
	end
	inventoryValue:GetPropertyChangedSignal("Value"):Connect(function()
		refreshOwnedPets()
		refreshEggPromptPreviews()
		if selectedEggId and PetData.Eggs[selectedEggId] then
			updatePetGrid(PetData.Eggs[selectedEggId])
		end
	end)
end)

UIManager.register("Eggs", function()
	if currentNearbyEgg then
		requestHatch(getEggIdFromPart(currentNearbyEgg) or chooseBestUnlockedEgg())
	end
end, function()
	toggleShop(false)
end, function()
	return isOpen
end)

openEggShopEvent.Event:Connect(function(eggId)
	requestHatch(eggId or chooseBestUnlockedEgg())
end)
