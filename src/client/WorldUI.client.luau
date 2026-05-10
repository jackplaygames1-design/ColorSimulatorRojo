-- SectorUI.client.luau. Internal registration names stay "World" for compatibility.
if true then
	warn("WorldUI disabled; editable MainHUD.ModalWindows.Windows.WorldsWindow is bound by EditorWindowBinder.")
	return
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local ColorData = require(ReplicatedStorage:WaitForChild("ColorData"))
local GameBalance = require(ReplicatedStorage:WaitForChild("GameBalance"))
local UIManager = require(ReplicatedStorage:WaitForChild("UIManager"))
local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))
local ClientUIRoot = require(ReplicatedStorage:WaitForChild("ClientUIRoot"))

local Events = ReplicatedStorage:WaitForChild("Events")
local unlockEvent = Events:WaitForChild("UnlockArea")
local tutorialActionEvent = Events:WaitForChild("TutorialAction", 10)

local UI_DARK = Color3.fromRGB(35, 38, 45)
local UI_WHITE = Color3.fromRGB(255, 255, 255)
local UI_CYAN = Color3.fromRGB(118, 238, 244)
local UI_GREEN = Color3.fromRGB(116, 245, 42)
local UI_RED = Color3.fromRGB(255, 24, 96)
local UI_YELLOW = Color3.fromRGB(255, 235, 105)
local PANEL_WIDTH = 620
local PANEL_HEIGHT = 470

local unlockedCsv = "Red"
local unlockedSet = { Red = true }
local currentWorldColor = "Red"
local currentCoins = 0
local redTutorialCompleted = false
local rows = {}
local soonRow
local tutorialCompletionConnection
local tutorialStageConnection

local screenGui = ClientUIRoot.GetLayer(player.PlayerGui, "WorldUI")

local overlay = UITheme.CreateDimOverlay(screenGui, 50)

local panel = Instance.new("Frame")
panel.Name = "WorldPanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Size = UDim2.new(0, PANEL_WIDTH, 0, PANEL_HEIGHT)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.BackgroundColor3 = UI_WHITE
panel.BorderSizePixel = 0
panel.Visible = false
panel.ZIndex = 60
panel.Parent = screenGui
UITheme.ApplyResponsiveScale(panel, PANEL_WIDTH, PANEL_HEIGHT, 0.74, 28)
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 24)
corner.Parent = panel
local stroke = Instance.new("UIStroke")
stroke.Color = UI_DARK
stroke.Thickness = 5
stroke.Parent = panel

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 60)
header.BackgroundColor3 = UI_CYAN
header.BorderSizePixel = 0
header.Parent = panel
local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 24)
headerCorner.Parent = header

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -70, 1, 0)
title.Position = UDim2.new(0, 20, 0, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.LuckiestGuy
title.TextSize = 28
title.TextColor3 = UI_WHITE
title.TextStrokeTransparency = 0
title.TextStrokeColor3 = UI_DARK
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "SECTORS"
title.Parent = header

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 42, 0, 42)
closeBtn.Position = UDim2.new(1, -52, 0.5, -21)
closeBtn.BackgroundColor3 = UI_RED
closeBtn.AutoButtonColor = false
closeBtn.Font = Enum.Font.LuckiestGuy
closeBtn.TextSize = 22
closeBtn.TextColor3 = UI_WHITE
closeBtn.TextStrokeTransparency = 0
closeBtn.TextStrokeColor3 = UI_DARK
closeBtn.Text = "X"
closeBtn.Parent = header
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 14)
closeCorner.Parent = closeBtn
local closeStroke = Instance.new("UIStroke")
closeStroke.Color = UI_DARK
closeStroke.Thickness = 4
closeStroke.Parent = closeBtn

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -30, 0, 42)
statusLabel.Position = UDim2.new(0, 15, 0, 68)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.GothamBold
statusLabel.TextSize = 13
statusLabel.TextColor3 = Color3.fromRGB(80, 84, 104)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextWrapped = true
statusLabel.Text = "Preview locked Sectors and return to unlocked Sectors."
statusLabel.Parent = panel

local list = Instance.new("ScrollingFrame")
list.Size = UDim2.new(1, -30, 1, -128)
list.Position = UDim2.new(0, 15, 0, 116)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.ScrollBarImageColor3 = UI_DARK
list.CanvasSize = UDim2.new(0, 0, 0, 0)
list.Parent = panel
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 10)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local function formatNum(value)
	value = tonumber(value) or 0
	return GameBalance and GameBalance.formatNumber and GameBalance.formatNumber(value) or tostring(value)
end

local function setStatus(text, color)
	statusLabel.Text = text
	statusLabel.TextColor3 = color or Color3.fromRGB(80, 84, 104)
end

local isSectorPlayable

local function getSectorSummary(world)
	local eggName = world.EggIds and world.EggIds[1] and tostring(world.EggIds[1]:gsub("Egg", " Egg")) or "new Egg"
	local brushText = world.BrushIds and #world.BrushIds > 0 and "new brushes" or "new gear"
	if world.primaryColor == "Orange" then
		return "Orange Sector: stronger orange spills, better Coin rewards, " .. eggName .. ", " .. brushText .. ", and the Mutation Core."
	end
	return tostring(world.name or "Sector") .. ": new color spills, better rewards, " .. eggName .. ", and " .. brushText .. "."
end

local function previewSector(world)
	local playable = isSectorPlayable(world.primaryColor)
	local color = playable and Color3.fromRGB(80, 84, 104) or UI_RED
	setStatus(getSectorSummary(world), color)
end

local function applyModalLayer()
	panel.ZIndex = 60
	for _, obj in ipairs(panel:GetDescendants()) do
		if obj:IsA("GuiObject") and obj.ZIndex < 61 then
			obj.ZIndex = 61
		end
	end
	closeBtn.ZIndex = 70
end

local function isUnlocked(colorType)
	local progression = GameBalance.Progression or {}
	local maxPlayableIndex = tonumber(progression.MaxPlayableSectorIndex) or math.huge
	local index = ColorData.getWorldIndex(colorType) or math.huge
	return unlockedSet[colorType] == true and index <= maxPlayableIndex
end

function isSectorPlayable(colorType)
	local progression = GameBalance.Progression or {}
	local maxPlayableIndex = tonumber(progression.MaxPlayableSectorIndex) or math.huge
	local index = ColorData.getWorldIndex(colorType) or math.huge
	return index <= maxPlayableIndex
end

local function isTutorialPreviewStep()
	local folder = player:FindFirstChild("TutorialObjectives")
	local completed = folder and folder:FindFirstChild("TutorialCompleted")
	if completed and completed.Value == true then
		return false
	end
	local stage = folder and folder:FindFirstChild("Stage")
	return stage and stage.Value == "PreviewNextWorld"
end

local function isTutorialLockedGate(colorType)
	return colorType == "Orange" and not redTutorialCompleted
end

local function canTryUnlock(world)
	if world.primaryColor == "Orange" and isTutorialPreviewStep() then
		return true
	end
	local previous = ColorData.getPreviousWorld(world.primaryColor)
	return isSectorPlayable(world.primaryColor)
		and (not previous or isUnlocked(previous.primaryColor))
		and currentCoins >= (tonumber(world.unlockCost) or 0)
end

local function canPreviewLockedWorld(world, visible)
	if not world or isUnlocked(world.primaryColor) or not isSectorPlayable(world.primaryColor) then
		return false
	end
	return visible == true
end

local function getVisibleWorldSet()
	local visible = {}
	local highestUnlockedIndex = 1
	local allPlayableUnlocked = true
	local progression = GameBalance.Progression or {}
	local maxPlayableIndex = tonumber(progression.MaxPlayableSectorIndex) or #ColorData.Worlds

	for index, world in ipairs(ColorData.Worlds) do
		if index > maxPlayableIndex then
			break
		end
		if isUnlocked(world.primaryColor) then
			highestUnlockedIndex = index
		else
			allPlayableUnlocked = false
			break
		end
	end

	local nextIndex = math.min(highestUnlockedIndex + 1, maxPlayableIndex, #ColorData.Worlds)
	for index, world in ipairs(ColorData.Worlds) do
		if index > maxPlayableIndex then
			break
		end
		if index <= highestUnlockedIndex or index == nextIndex then
			visible[world.primaryColor] = true
		end
	end

	return visible, allPlayableUnlocked
end

local function getWorldColor(world)
	local colorInfo = ColorData.Colors[world.primaryColor]
	return colorInfo and colorInfo.color or UI_CYAN
end

local function updateGateSign(sign, world, open)
	for _, surface in ipairs(sign:GetChildren()) do
		if surface:IsA("SurfaceGui") then
			local title = surface:FindFirstChild("Title", true)
			local status = surface:FindFirstChild("Status", true)
			local backing = surface:FindFirstChild("Backing")
			if title and title:IsA("TextLabel") then
				title.Text = world.name
				title.TextColor3 = Color3.fromRGB(242, 248, 255)
			end
			if status and status:IsA("TextLabel") then
				status.Text = open and "Unlocked - Go" or (formatNum(world.unlockCost) .. " Coins")
				status.TextColor3 = open and Color3.fromRGB(145, 245, 170) or Color3.fromRGB(255, 216, 122)
			end
			if backing and backing:IsA("Frame") then
				backing.BackgroundTransparency = open and 0.24 or 0.12
			end
		end
	end
end

local function applyGateVisualState(gate, world, open)
	local worldColor = getWorldColor(world)
	local lockedPanel = worldColor:Lerp(Color3.fromRGB(35, 38, 45), 0.62)
	local openPanel = worldColor:Lerp(Color3.fromRGB(190, 245, 245), 0.2)
	gate.Color = open and openPanel or lockedPanel
	gate.Material = open and Enum.Material.Glass or Enum.Material.SmoothPlastic
	gate.LocalTransparencyModifier = open and 0.58 or 0

	for _, child in ipairs(gate:GetChildren()) do
		if child:IsA("BasePart") and child:GetAttribute("GateDecor") then
			local role = child:GetAttribute("GateVisualRole") or child.Name
			if role == "GateVisualSign" then
				child.Color = Color3.fromRGB(24, 27, 34)
				child.LocalTransparencyModifier = open and 0.12 or 0
				updateGateSign(child, world, open)
			elseif string.find(role, "Glow") then
				child.Color = open and worldColor:Lerp(Color3.fromRGB(255, 255, 255), 0.2) or Color3.fromRGB(255, 96, 116)
				child.LocalTransparencyModifier = open and 0.12 or 0.2
			elseif role == "GateVisualStatusLight" then
				child.Color = open and Color3.fromRGB(125, 255, 150) or Color3.fromRGB(255, 104, 118)
				child.LocalTransparencyModifier = 0
			else
				child.Color = open and Color3.fromRGB(42, 50, 58) or Color3.fromRGB(24, 27, 34)
				child.LocalTransparencyModifier = open and 0.18 or 0
			end
		end
	end
end

local function refreshGates()
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("BasePart") then
			local gateColor = obj:GetAttribute("GateColor") or obj:GetAttribute("UnlockColor")
			if obj:GetAttribute("AreaGate") then
				gateColor = gateColor or obj:GetAttribute("ColorType")
			end

			if gateColor and ColorData.getWorldByColor(gateColor) then
				local world = ColorData.getWorldByColor(gateColor)
				local open = isUnlocked(gateColor)
				local playable = isSectorPlayable(gateColor)
				local tutorialLocked = isTutorialLockedGate(gateColor)
				if obj:GetAttribute("GateInteraction") then
					obj.LocalTransparencyModifier = 1
					obj.CanCollide = false
					local prompt = obj:FindFirstChild("GatePrompt")
					if prompt and prompt:IsA("ProximityPrompt") then
						prompt.Enabled = playable and not tutorialLocked
						prompt.ActionText = open and ("Go to " .. world.name) or ("Unlock " .. world.name)
						prompt.ObjectText = playable and (open and "Unlocked" or (formatNum(world.unlockCost) .. " Coins")) or "Locked for now"
						prompt.MaxActivationDistance = 30
						prompt.HoldDuration = 0.1
						prompt.RequiresLineOfSight = false
					end
				elseif obj:GetAttribute("AreaGate") then
					applyGateVisualState(obj, world, open)
					obj.CanCollide = tutorialLocked or not open or not playable
					local prompt = obj:FindFirstChild("GatePrompt")
					if prompt and prompt:IsA("ProximityPrompt") then
						prompt.Enabled = playable and not tutorialLocked
						prompt.ActionText = open and ("Go to " .. world.name) or ("Unlock " .. world.name)
						prompt.ObjectText = playable and (open and "Unlocked" or (formatNum(world.unlockCost) .. " Coins")) or "Locked for now"
					end

					local billboard = obj:FindFirstChild("GateBillboard")
					if billboard and billboard:IsA("BillboardGui") then
						billboard.Enabled = false
					end
				elseif obj:GetAttribute("GateDecor") then
					obj.LocalTransparencyModifier = open and 0.2 or 0
					obj.CanCollide = false
				else
					obj.LocalTransparencyModifier = open and 0.75 or 0
					obj.CanCollide = not open
				end
			end
		end
	end
end

local function refreshRows()
	unlockedSet = ColorData.getUnlockedColorSet(unlockedCsv)
	local visibleSet, allUnlocked = getVisibleWorldSet()

	for _, row in pairs(rows) do
		local world = row.world
		local visible = visibleSet[world.primaryColor] == true
		row.frame.Visible = visible
		if not visible then
			continue
		end

		local unlocked = isUnlocked(world.primaryColor)
		local tutorialPreview = world.primaryColor == "Orange" and isTutorialPreviewStep()
		local canUnlock = canTryUnlock(world)
		local canPreview = tutorialPreview or (not canUnlock and canPreviewLockedWorld(world, visible))
		local current = unlocked and currentWorldColor == world.primaryColor
		local previous = ColorData.getPreviousWorld(world.primaryColor)
		local playable = isSectorPlayable(world.primaryColor)

		row.frame.BackgroundColor3 = current and Color3.fromRGB(236, 255, 252) or (unlocked and Color3.fromRGB(250, 255, 255) or Color3.fromRGB(244, 246, 252))
		if row.stroke then
			row.stroke.Color = tutorialPreview and UI_YELLOW or (current and UI_GREEN or UI_DARK)
			row.stroke.Thickness = (current or tutorialPreview) and 4 or 3
		end
		if current then
			row.status.Text = "CURRENT SECTOR"
		elseif unlocked then
			row.status.Text = "UNLOCKED"
		elseif tutorialPreview then
			row.status.Text = "Preview next Sector"
		elseif canPreview then
			row.status.Text = "Preview available - requires " .. formatNum(world.unlockCost) .. " Coins"
		elseif not playable then
			row.status.Text = "LOCKED FOR NOW"
		elseif previous and not isUnlocked(previous.primaryColor) then
			row.status.Text = "Requires " .. previous.name
		else
			row.status.Text = "Requires " .. formatNum(world.unlockCost) .. " Coins"
		end
		row.status.TextColor3 = unlocked and Color3.fromRGB(35, 130, 55) or Color3.fromRGB(120, 90, 30)
		row.button.Visible = not unlocked
		row.button.Active = true
		row.button.BackgroundColor3 = tutorialPreview and UI_YELLOW or (canPreview and UI_CYAN or (canUnlock and UI_GREEN or Color3.fromRGB(210, 214, 225)))
		row.button.Text = (tutorialPreview or canPreview) and "PREVIEW" or (canUnlock and "UNLOCK" or "LOCKED")
		row.teleport.Visible = unlocked
		row.teleport.Active = tutorialPreview or unlocked
		row.teleport.BackgroundColor3 = tutorialPreview and UI_YELLOW or (current and UI_GREEN or UI_CYAN)
		row.teleport.Text = tutorialPreview and "PREVIEW" or (current and "HERE" or "GO")
		row.teleport.TextSize = current and 17 or 13
	end

	if soonRow then
		soonRow.Visible = allUnlocked
	end

	list.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 12)
	refreshGates()
end

local function buildRows()
	for _, child in ipairs(list:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	rows = {}

	for order, world in ipairs(ColorData.Worlds) do
		local row = Instance.new("Frame")
		row.Name = "WorldRow_" .. world.primaryColor
		row.Size = UDim2.new(1, -6, 0, 76)
		row.LayoutOrder = order
		row.BackgroundColor3 = Color3.fromRGB(250, 255, 255)
		row.BorderSizePixel = 0
		row.Active = true
		row.Parent = list
		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 14)
		rowCorner.Parent = row
		local rowStroke = Instance.new("UIStroke")
		rowStroke.Color = UI_DARK
		rowStroke.Thickness = 3
		rowStroke.Parent = row

		local swatch = Instance.new("Frame")
		swatch.Size = UDim2.new(0, 44, 0, 44)
		swatch.Position = UDim2.new(0, 14, 0.5, -22)
		swatch.BackgroundColor3 = ColorData.Colors[world.primaryColor] and ColorData.Colors[world.primaryColor].color or UI_CYAN
		swatch.BorderSizePixel = 0
		swatch.Parent = row
		local swatchCorner = Instance.new("UICorner")
		swatchCorner.CornerRadius = UDim.new(1, 0)
		swatchCorner.Parent = swatch
		local swatchStroke = Instance.new("UIStroke")
		swatchStroke.Color = UI_DARK
		swatchStroke.Thickness = 3
		swatchStroke.Parent = swatch

		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(1, -230, 0, 30)
		name.Position = UDim2.new(0, 72, 0, 10)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.LuckiestGuy
		name.TextSize = 19
		name.TextColor3 = UI_DARK
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Text = world.name
		name.Parent = row

		local status = Instance.new("TextLabel")
		status.Size = UDim2.new(1, -230, 0, 24)
		status.Position = UDim2.new(0, 72, 0, 40)
		status.BackgroundTransparency = 1
		status.Font = Enum.Font.GothamBold
		status.TextSize = 13
		status.TextXAlignment = Enum.TextXAlignment.Left
		status.Text = ""
		status.Parent = row

		local button = Instance.new("TextButton")
		button.Name = "WorldUnlockButton_" .. world.primaryColor
		button.Size = UDim2.new(0, 118, 0, 42)
		button.Position = UDim2.new(1, -132, 0.5, -21)
		button.AutoButtonColor = false
		button.Font = Enum.Font.LuckiestGuy
		button.TextSize = 15
		button.TextColor3 = UI_WHITE
		button.TextStrokeTransparency = 0
		button.TextStrokeColor3 = UI_DARK
		button.Text = "UNLOCK"
		button.Parent = row
		local buttonCorner = Instance.new("UICorner")
		buttonCorner.CornerRadius = UDim.new(0, 12)
		buttonCorner.Parent = button
		local buttonStroke = Instance.new("UIStroke")
		buttonStroke.Color = UI_DARK
		buttonStroke.Thickness = 3
		buttonStroke.Parent = button

		local teleportButton = Instance.new("TextButton")
		teleportButton.Name = "WorldTeleportButton_" .. world.primaryColor
		teleportButton.Size = UDim2.new(0, 118, 0, 42)
		teleportButton.Position = UDim2.new(1, -132, 0.5, -21)
		teleportButton.BackgroundColor3 = UI_CYAN
		teleportButton.AutoButtonColor = false
		teleportButton.Font = Enum.Font.LuckiestGuy
		teleportButton.TextSize = 17
		teleportButton.TextColor3 = UI_WHITE
		teleportButton.TextStrokeTransparency = 0
		teleportButton.TextStrokeColor3 = UI_DARK
		teleportButton.Text = "GO"
		teleportButton.Visible = false
		teleportButton.Parent = row
		local teleportCorner = Instance.new("UICorner")
		teleportCorner.CornerRadius = UDim.new(0, 12)
		teleportCorner.Parent = teleportButton
		local teleportStroke = Instance.new("UIStroke")
		teleportStroke.Color = UI_DARK
		teleportStroke.Thickness = 3
		teleportStroke.Parent = teleportButton

		button.MouseButton1Click:Connect(function()
			previewSector(world)
			if world.primaryColor == "Orange" and isTutorialPreviewStep() then
				setStatus(world.name .. " previewed. Visit the shop next.", Color3.fromRGB(35, 130, 55))
				if tutorialActionEvent and tutorialActionEvent:IsA("RemoteEvent") then
					tutorialActionEvent:FireServer("NextWorldPreviewed")
				end
				return
			end
			if button.Active then
				if not canTryUnlock(world) then
					return
				end
				unlockEvent:FireServer(world.primaryColor)
			end
		end)

		teleportButton.MouseButton1Click:Connect(function()
			previewSector(world)
			if world.primaryColor == "Orange" and isTutorialPreviewStep() then
				setStatus(world.name .. " previewed. Visit the shop next.", Color3.fromRGB(35, 130, 55))
				if tutorialActionEvent and tutorialActionEvent:IsA("RemoteEvent") then
					tutorialActionEvent:FireServer("NextWorldPreviewed")
				end
				return
			end
			if teleportButton.Active and isUnlocked(world.primaryColor) then
				if currentWorldColor == world.primaryColor then
					return
				end
				unlockEvent:FireServer("teleport", world.primaryColor)
			end
		end)

		row.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				previewSector(world)
			end
		end)

		rows[world.primaryColor] = { world = world, frame = row, stroke = rowStroke, status = status, button = button, teleport = teleportButton }
	end

	soonRow = Instance.new("Frame")
	soonRow.Size = UDim2.new(1, -6, 0, 76)
	soonRow.LayoutOrder = #ColorData.Worlds + 1
	soonRow.BackgroundColor3 = Color3.fromRGB(246, 242, 255)
	soonRow.BorderSizePixel = 0
	soonRow.Parent = list
	local soonCorner = Instance.new("UICorner")
	soonCorner.CornerRadius = UDim.new(0, 14)
	soonCorner.Parent = soonRow
	local soonStroke = Instance.new("UIStroke")
	soonStroke.Color = UI_DARK
	soonStroke.Thickness = 3
	soonStroke.Parent = soonRow

	local soonSwatch = Instance.new("Frame")
	soonSwatch.Size = UDim2.new(0, 44, 0, 44)
	soonSwatch.Position = UDim2.new(0, 14, 0.5, -22)
	soonSwatch.BackgroundColor3 = Color3.fromRGB(202, 176, 255)
	soonSwatch.BorderSizePixel = 0
	soonSwatch.Parent = soonRow
	local soonSwatchCorner = Instance.new("UICorner")
	soonSwatchCorner.CornerRadius = UDim.new(1, 0)
	soonSwatchCorner.Parent = soonSwatch
	local soonSwatchStroke = Instance.new("UIStroke")
	soonSwatchStroke.Color = UI_DARK
	soonSwatchStroke.Thickness = 3
	soonSwatchStroke.Parent = soonSwatch

	local soonName = Instance.new("TextLabel")
	soonName.Size = UDim2.new(1, -230, 0, 30)
	soonName.Position = UDim2.new(0, 72, 0, 10)
	soonName.BackgroundTransparency = 1
	soonName.Font = Enum.Font.LuckiestGuy
	soonName.TextSize = 19
	soonName.TextColor3 = UI_DARK
	soonName.TextXAlignment = Enum.TextXAlignment.Left
	soonName.Text = "BETA PATH COMPLETE"
	soonName.Parent = soonRow

	local soonStatus = Instance.new("TextLabel")
	soonStatus.Size = UDim2.new(1, -230, 0, 24)
	soonStatus.Position = UDim2.new(0, 72, 0, 40)
	soonStatus.BackgroundTransparency = 1
	soonStatus.Font = Enum.Font.GothamBold
	soonStatus.TextSize = 13
	soonStatus.TextXAlignment = Enum.TextXAlignment.Left
	soonStatus.TextColor3 = Color3.fromRGB(92, 78, 130)
	soonStatus.Text = "Red and Orange are the current playable Sectors."
	soonStatus.Parent = soonRow

	local soonBadge = Instance.new("TextLabel")
	soonBadge.Size = UDim2.new(0, 118, 0, 42)
	soonBadge.Position = UDim2.new(1, -132, 0.5, -21)
	soonBadge.BackgroundColor3 = Color3.fromRGB(202, 176, 255)
	soonBadge.Font = Enum.Font.LuckiestGuy
	soonBadge.TextSize = 17
	soonBadge.TextColor3 = UI_WHITE
	soonBadge.TextStrokeTransparency = 0
	soonBadge.TextStrokeColor3 = UI_DARK
	soonBadge.Text = "LIVE"
	soonBadge.Parent = soonRow
	local soonBadgeCorner = Instance.new("UICorner")
	soonBadgeCorner.CornerRadius = UDim.new(0, 12)
	soonBadgeCorner.Parent = soonBadge
	local soonBadgeStroke = Instance.new("UIStroke")
	soonBadgeStroke.Color = UI_DARK
	soonBadgeStroke.Thickness = 3
	soonBadgeStroke.Parent = soonBadge

	refreshRows()
end

local isOpen = false
local function toggleWorld(open)
	isOpen = open
	if open then
		if tutorialActionEvent and tutorialActionEvent:IsA("RemoteEvent") then
			tutorialActionEvent:FireServer("WorldMenuOpened")
		end
		overlay.Visible = true
		overlay.BackgroundTransparency = 1
		panel.Visible = true
		panel.Size = UDim2.new(0, 80, 0, 80)
		panel.Position = UDim2.fromScale(0.5, 0.5)
		applyModalLayer()
		TweenService:Create(overlay, TweenInfo.new(0.18), {
			BackgroundTransparency = 0.4,
		}):Play()
		TweenService:Create(panel, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
			Size = UDim2.new(0, PANEL_WIDTH, 0, PANEL_HEIGHT),
			Position = UDim2.fromScale(0.5, 0.5),
		}):Play()
		refreshRows()
	else
		TweenService:Create(overlay, TweenInfo.new(0.18), {
			BackgroundTransparency = 1,
		}):Play()
		TweenService:Create(panel, TweenInfo.new(0.2), {
			Size = UDim2.new(0, 60, 0, 60),
			Position = UDim2.fromScale(0.5, 0.5),
		}):Play()
		task.wait(0.2)
		panel.Visible = false
		overlay.Visible = false
	end
end

unlockEvent.OnClientEvent:Connect(function(kind, arg1, arg2, arg3)
	if kind == "state" then
		unlockedCsv = arg1 or "Red"
		currentWorldColor = arg3 or currentWorldColor
		refreshRows()
	elseif kind == "unlocked" then
		local world = arg2
		if world then
			currentWorldColor = arg1 or currentWorldColor
			setStatus(world.name .. " unlocked!", Color3.fromRGB(35, 130, 55))
		end
		refreshRows()
	elseif kind == "teleported" then
		local world = arg2
		if world then
			currentWorldColor = arg1 or currentWorldColor
			setStatus("Moved to " .. world.name .. ".", Color3.fromRGB(35, 130, 55))
		end
		refreshRows()
	elseif kind == "error" then
		setStatus(tostring(arg2 or "Could not unlock area."), UI_RED)
	end
end)

local storage = player:WaitForChild("ColorStorage", 10)
local unlockedValue = storage and storage:WaitForChild("UnlockedColors", 10)
local currentWorldValue = storage and storage:WaitForChild("CurrentWorld", 10)
local leaderstats = player:WaitForChild("leaderstats", 10)
local coinsValue = leaderstats and leaderstats:WaitForChild("Coins", 10)
if unlockedValue then
	unlockedCsv = unlockedValue.Value
	unlockedValue:GetPropertyChangedSignal("Value"):Connect(function()
		unlockedCsv = unlockedValue.Value
		refreshRows()
	end)
end
if currentWorldValue then
	currentWorldColor = currentWorldValue.Value ~= "" and currentWorldValue.Value or currentWorldColor
	currentWorldValue:GetPropertyChangedSignal("Value"):Connect(function()
		currentWorldColor = currentWorldValue.Value ~= "" and currentWorldValue.Value or "Red"
		refreshRows()
	end)
end
if coinsValue then
	currentCoins = coinsValue.Value
	coinsValue:GetPropertyChangedSignal("Value"):Connect(function()
		currentCoins = coinsValue.Value
		refreshRows()
	end)
end

local function bindTutorialCompletion()
	if tutorialCompletionConnection then
		tutorialCompletionConnection:Disconnect()
		tutorialCompletionConnection = nil
	end
	if tutorialStageConnection then
		tutorialStageConnection:Disconnect()
		tutorialStageConnection = nil
	end

	local folder = player:FindFirstChild("TutorialObjectives")
	local completed = folder and folder:FindFirstChild("TutorialCompleted")
	local stage = folder and folder:FindFirstChild("Stage")
	redTutorialCompleted = completed and completed.Value == true
	if completed then
		tutorialCompletionConnection = completed:GetPropertyChangedSignal("Value"):Connect(function()
			redTutorialCompleted = completed.Value == true
			refreshGates()
			refreshRows()
		end)
	end
	if stage then
		tutorialStageConnection = stage:GetPropertyChangedSignal("Value"):Connect(function()
			refreshGates()
			refreshRows()
		end)
	end

	refreshGates()
	refreshRows()
end

bindTutorialCompletion()
player.ChildAdded:Connect(function(child)
	if child.Name == "TutorialObjectives" then
		task.defer(bindTutorialCompletion)
	end
end)

closeBtn.MouseButton1Click:Connect(function()
	toggleWorld(false)
end)

overlay.MouseButton1Click:Connect(function()
	toggleWorld(false)
end)

workspace.DescendantAdded:Connect(function(obj)
	if obj:IsA("BasePart") then
		task.defer(refreshGates)
	end
end)

buildRows()
refreshRows()

UIManager.register("World", function() toggleWorld(true) end, function() toggleWorld(false) end, function() return isOpen end)

local worldBtn = ReplicatedStorage:WaitForChild("HudButton_WORLD", 10)
if worldBtn then
	worldBtn.Event:Connect(function() UIManager.toggle("World") end)
end
