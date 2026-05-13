local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local DialogueData = require(script.Parent:WaitForChild("NpcDialogueData"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Events = ReplicatedStorage:WaitForChild("Events")
local dailyQuestRemote = ReplicatedStorage:WaitForChild("DailyQuestRemote", 10)
	or Events:FindFirstChild("DailyQuestRemote")

local DARK = Color3.fromRGB(24, 27, 36)
local DARKER = Color3.fromRGB(13, 16, 24)
local TEXT = Color3.fromRGB(255, 255, 255)
local MUTED = Color3.fromRGB(176, 188, 204)
local RED = Color3.fromRGB(236, 72, 92)

local TYPE_INTERVAL = 0.021
local CAMERA_TWEEN_TIME = 0.32

local mainHud = playerGui:WaitForChild("MainHUD", 30)
if not mainHud then
	warn("NpcDialogueClient: missing PlayerGui.MainHUD")
	return
end

local function ensureChild(parent, className, name)
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

local function ensureCorner(parent, radius)
	local corner = parent:FindFirstChildOfClass("UICorner")
	if not corner then
		corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, radius)
		corner.Parent = parent
	end
	return corner
end

local function ensureStroke(parent, color, thickness)
	local stroke = parent:FindFirstChildOfClass("UIStroke")
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Color = color
		stroke.Thickness = thickness
		stroke.Parent = parent
	end
	return stroke
end

local dialogueRoot, dialogueRootCreated = ensureChild(mainHud, "Frame", "ZorkDialogueUI")
dialogueRoot:SetAttribute("EditableNpcDialogueUI", true)
dialogueRoot:SetAttribute("ClientBoundBy", "NpcDialogueClient.client.luau")
if dialogueRootCreated then
	dialogueRoot.AnchorPoint = Vector2.new(0.5, 1)
	dialogueRoot.Position = UDim2.fromScale(0.5, 0.46)
	dialogueRoot.Size = UDim2.fromOffset(620, 330)
	dialogueRoot.BackgroundTransparency = 1
	dialogueRoot.BorderSizePixel = 0
	dialogueRoot.ZIndex = 900
end
dialogueRoot.Visible = false

local panel, panelCreated = ensureChild(dialogueRoot, "Frame", "Panel")
if panelCreated then
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(1, -10, 1, -10)
	panel.BackgroundColor3 = DARK
	panel.BackgroundTransparency = 0.04
	panel.BorderSizePixel = 0
	panel.ZIndex = dialogueRoot.ZIndex + 10
end
ensureCorner(panel, 18)
local panelStroke = ensureStroke(panel, Color3.fromRGB(76, 214, 224), 4)

local accentBar, accentCreated = ensureChild(panel, "Frame", "AccentBar")
if accentCreated then
	accentBar.Position = UDim2.fromOffset(0, 0)
	accentBar.Size = UDim2.new(0, 12, 1, 0)
	accentBar.BackgroundColor3 = Color3.fromRGB(76, 214, 224)
	accentBar.BorderSizePixel = 0
	accentBar.ZIndex = panel.ZIndex + 1
end
ensureCorner(accentBar, 18)

local speakerName, speakerNameCreated = ensureChild(panel, "TextLabel", "SpeakerName")
if speakerNameCreated then
	speakerName.BackgroundTransparency = 1
	speakerName.Position = UDim2.fromOffset(30, 16)
	speakerName.Size = UDim2.new(0.48, 0, 0, 34)
	speakerName.Font = Enum.Font.GothamBlack
	speakerName.Text = "Zork"
	speakerName.TextColor3 = TEXT
	speakerName.TextSize = 28
	speakerName.TextStrokeColor3 = DARKER
	speakerName.TextStrokeTransparency = 0.25
	speakerName.TextXAlignment = Enum.TextXAlignment.Left
	speakerName.ZIndex = panel.ZIndex + 2
end

local speakerRole, speakerRoleCreated = ensureChild(panel, "TextLabel", "SpeakerRole")
if speakerRoleCreated then
	speakerRole.BackgroundTransparency = 1
	speakerRole.Position = UDim2.new(0.52, 0, 0, 22)
	speakerRole.Size = UDim2.new(0.42, 0, 0, 24)
	speakerRole.Font = Enum.Font.GothamBold
	speakerRole.Text = "Brush Merchant + Quest Keeper"
	speakerRole.TextColor3 = MUTED
	speakerRole.TextSize = 14
	speakerRole.TextXAlignment = Enum.TextXAlignment.Right
	speakerRole.ZIndex = panel.ZIndex + 2
end

local bodyButton, bodyButtonCreated = ensureChild(panel, "TextButton", "BodyButton")
if bodyButtonCreated then
	bodyButton.Position = UDim2.fromScale(0, 0)
	bodyButton.Size = UDim2.fromScale(1, 1)
	bodyButton.BackgroundTransparency = 1
	bodyButton.BorderSizePixel = 0
	bodyButton.AutoButtonColor = false
	bodyButton.Text = ""
	bodyButton.ZIndex = panel.ZIndex + 1
end

local bodyText, bodyTextCreated = ensureChild(bodyButton, "TextLabel", "BodyText")
if bodyTextCreated then
	bodyText.BackgroundTransparency = 1
	bodyText.Position = UDim2.fromOffset(28, 58)
	bodyText.Size = UDim2.new(1, -56, 0, 104)
	bodyText.Font = Enum.Font.GothamBold
	bodyText.Text = ""
	bodyText.TextColor3 = TEXT
	bodyText.TextSize = 19
	bodyText.TextWrapped = true
	bodyText.TextXAlignment = Enum.TextXAlignment.Left
	bodyText.TextYAlignment = Enum.TextYAlignment.Top
	bodyText.ZIndex = panel.ZIndex + 4
end

local optionsFrame, optionsCreated = ensureChild(panel, "Frame", "Options")
if optionsCreated then
	optionsFrame.BackgroundTransparency = 1
	optionsFrame.Position = UDim2.fromOffset(28, 180)
	optionsFrame.Size = UDim2.new(1, -56, 0, 118)
	optionsFrame.ZIndex = panel.ZIndex + 10
end
local optionsGrid = optionsFrame:FindFirstChildOfClass("UIGridLayout")
if not optionsGrid then
	optionsGrid = Instance.new("UIGridLayout")
	optionsGrid.CellSize = UDim2.fromOffset(268, 32)
	optionsGrid.CellPadding = UDim2.fromOffset(10, 8)
	optionsGrid.FillDirectionMaxCells = 2
	optionsGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	optionsGrid.VerticalAlignment = Enum.VerticalAlignment.Top
	optionsGrid.SortOrder = Enum.SortOrder.LayoutOrder
	optionsGrid.Parent = optionsFrame
end
local optionTemplate = optionsFrame:FindFirstChild("OptionTemplate")
if optionTemplate and not optionTemplate:IsA("TextButton") then
	optionTemplate = nil
end

local pointer, pointerCreated = ensureChild(panel, "Frame", "Pointer")
if pointerCreated then
	pointer.AnchorPoint = Vector2.new(0.5, 0)
	pointer.Position = UDim2.new(0.5, 0, 1, -12)
	pointer.Size = UDim2.fromOffset(26, 26)
	pointer.BackgroundColor3 = DARK
	pointer.BorderSizePixel = 0
	pointer.Rotation = 45
	pointer.ZIndex = panel.ZIndex - 1
end

local voice = Instance.new("Sound")
voice.Name = "NpcDialogueBlip"
voice.SoundId = "rbxasset://sounds/electronicpingshort.wav"
voice.Volume = 0.13
voice.PlaybackSpeed = 1.4
voice.Parent = SoundService

local activePrompt = nil
local activeNpc = nil
local activeNodeId = nil
local activeContext = {}
local activeLineIndex = 1
local dialogueToken = 0
local typing = false
local fullLine = ""
local savedCamera = nil
local cameraTween = nil
local optionsVisible = false
local activeAdornee = nil
local hiddenNpcBillboards = {}
local hiddenNpcPrompts = {}
local heldChromeWindowConnection = nil
local controlsLocked = false
local playerControls = nil
local savedMovement = nil

local function getCamera()
	return Workspace.CurrentCamera
end

local function getPlayerControls()
	if playerControls then
		return playerControls
	end

	local playerScripts = player:FindFirstChild("PlayerScripts") or player:WaitForChild("PlayerScripts", 5)
	local playerModule = playerScripts and playerScripts:FindFirstChild("PlayerModule")
	if not playerModule then
		return nil
	end

	local ok, module = pcall(require, playerModule)
	if not ok or type(module) ~= "table" or type(module.GetControls) ~= "function" then
		return nil
	end

	local controlsOk, controls = pcall(function()
		return module:GetControls()
	end)
	if controlsOk then
		playerControls = controls
	end
	return playerControls
end

local function getCharacterHumanoid()
	local character = player.Character
	if not character then
		return nil, nil
	end
	return character:FindFirstChildOfClass("Humanoid"), character
end

local function lockPlayerMovement()
	if controlsLocked then
		return
	end
	controlsLocked = true

	local controls = getPlayerControls()
	if controls and type(controls.Disable) == "function" then
		pcall(function()
			controls:Disable()
		end)
	end

	local humanoid, character = getCharacterHumanoid()
	if humanoid then
		savedMovement = {
			Humanoid = humanoid,
			WalkSpeed = humanoid.WalkSpeed,
			JumpPower = humanoid.JumpPower,
			JumpHeight = humanoid.JumpHeight,
			AutoRotate = humanoid.AutoRotate,
		}
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
		humanoid.AutoRotate = false
	end

	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
end

local function unlockPlayerMovement()
	if controlsLocked then
		local controls = getPlayerControls()
		if controls and type(controls.Enable) == "function" then
			pcall(function()
				controls:Enable()
			end)
		end
	end

	if savedMovement and savedMovement.Humanoid and savedMovement.Humanoid.Parent then
		local humanoid = savedMovement.Humanoid
		humanoid.WalkSpeed = savedMovement.WalkSpeed
		humanoid.JumpPower = savedMovement.JumpPower
		humanoid.JumpHeight = savedMovement.JumpHeight
		humanoid.AutoRotate = savedMovement.AutoRotate
	end

	controlsLocked = false
	savedMovement = nil
end

local function updateDialoguePosition()
	if not dialogueRoot.Visible or not activeAdornee then
		return
	end

	local camera = getCamera()
	if not camera then
		return
	end

	local offsetY = tonumber(dialogueRoot:GetAttribute("WorldOffsetY")) or 5.8
	local screenPoint = camera:WorldToViewportPoint(activeAdornee.Position + Vector3.new(0, offsetY, 0))
	if screenPoint.Z <= 0 then
		return
	end

	local viewport = camera.ViewportSize
	local size = dialogueRoot.AbsoluteSize
	local minX = (size.X * 0.5) + 12
	local maxX = math.max(minX, viewport.X - minX)
	local minY = size.Y + 12
	local maxY = math.max(minY, viewport.Y - 20)

	dialogueRoot.Position =
		UDim2.fromOffset(math.clamp(screenPoint.X, minX, maxX), math.clamp(screenPoint.Y, minY, maxY))
end

local function inputIsInsideDialogue(input)
	local position = input.Position
	local topLeft = dialogueRoot.AbsolutePosition
	local size = dialogueRoot.AbsoluteSize
	return position.X >= topLeft.X
		and position.X <= topLeft.X + size.X
		and position.Y >= topLeft.Y
		and position.Y <= topLeft.Y + size.Y
end

local function requestWindow(windowName)
	mainHud:SetAttribute("RequestedWindow", windowName)
	mainHud:SetAttribute("RequestedWindowNonce", os.clock())
end

local function findPromptAdornee(prompt)
	local parent = prompt and prompt.Parent
	if parent and parent:IsA("BasePart") then
		return parent
	end
	local ancestor = parent
	while ancestor and ancestor ~= Workspace do
		if ancestor:IsA("Model") then
			local primary = ancestor.PrimaryPart or ancestor:FindFirstChildWhichIsA("BasePart", true)
			if primary then
				return primary
			end
		elseif ancestor:IsA("BasePart") then
			return ancestor
		end
		ancestor = ancestor.Parent
	end
	return nil
end

local function getNpcChromeRoot(adornee)
	if not adornee then
		return nil
	end
	return adornee:FindFirstAncestorOfClass("Model") or adornee
end

local function restoreNpcChrome()
	if heldChromeWindowConnection then
		heldChromeWindowConnection:Disconnect()
		heldChromeWindowConnection = nil
	end

	for gui, wasEnabled in pairs(hiddenNpcBillboards) do
		if gui.Parent then
			gui.Enabled = wasEnabled
		end
	end
	table.clear(hiddenNpcBillboards)

	for prompt, wasEnabled in pairs(hiddenNpcPrompts) do
		if prompt.Parent then
			prompt.Enabled = wasEnabled
		end
	end
	table.clear(hiddenNpcPrompts)
end

local function hideNpcChrome(adornee)
	restoreNpcChrome()
	local root = getNpcChromeRoot(adornee)
	if not root then
		return
	end

	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("BillboardGui") then
			hiddenNpcBillboards[descendant] = descendant.Enabled
			descendant.Enabled = false
		elseif descendant:IsA("ProximityPrompt") then
			hiddenNpcPrompts[descendant] = descendant.Enabled
			descendant.Enabled = false
		end
	end
end

local function keepChromeHiddenUntilWindowCloses(windowName)
	local windowsFolder = mainHud:FindFirstChild("ModalWindows")
	local window = windowsFolder and windowsFolder:FindFirstChild(windowName)
	if not window or not window:IsA("GuiObject") then
		task.delay(0.35, restoreNpcChrome)
		return
	end

	if heldChromeWindowConnection then
		heldChromeWindowConnection:Disconnect()
	end
	heldChromeWindowConnection = window:GetPropertyChangedSignal("Visible"):Connect(function()
		if not window.Visible then
			restoreNpcChrome()
		end
	end)

	task.delay(0.35, function()
		if not window.Visible then
			restoreNpcChrome()
		end
	end)
end

local function getPromptNpcId(prompt)
	local npcId = prompt:GetAttribute("NpcDialogueId") or prompt:GetAttribute("NpcId") or prompt:GetAttribute("NpcName")
	if type(npcId) == "string" and npcId ~= "" then
		return npcId
	end
	if prompt:GetAttribute("BrushNpcDialogue") == true or prompt:GetAttribute("BrushShopPrompt") == true then
		return "Zork"
	end
	return nil
end

local function getStartNode(npc, context)
	local colorType = context.colorType
	local byColor = npc.StartNodeByColor
	if type(byColor) == "table" and type(colorType) == "string" and byColor[colorType] then
		return byColor[colorType]
	end
	return npc.StartNode or "start"
end

local function optionAllowed(option)
	local condition = option.Condition
	if not condition or condition == "" then
		return true
	end
	if condition == "BrushShopAvailable" then
		local colorType = activeContext.colorType
		return colorType == nil or colorType == "" or colorType == "Red"
	end
	return true
end

local function clearOptions()
	for _, child in ipairs(optionsFrame:GetChildren()) do
		if child:IsA("GuiButton") then
			if child:GetAttribute("GeneratedDialogueOption") == true then
				child:Destroy()
			else
				child.Visible = false
			end
		end
	end
	optionsVisible = false
end

local function styleButton(button, color)
	if button:GetAttribute("UseDialogueOptionColor") ~= false then
		button.BackgroundColor3 = color
	end
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = Enum.Font.GothamBlack
	button.TextColor3 = TEXT
	button.TextSize = 13
	button.TextScaled = false
	button.TextTruncate = Enum.TextTruncate.AtEnd
	button.TextStrokeColor3 = DARKER
	button.TextStrokeTransparency = 0.25
	local corner = button:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button
	local stroke = button:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	stroke.Color = DARKER
	stroke.Thickness = 2
	stroke.Parent = button
	local constraint = button:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = 10
	constraint.MaxTextSize = 13
	constraint.Parent = button
end

local function tintButton(button, color)
	if button:GetAttribute("UseDialogueOptionColor") ~= false then
		button.BackgroundColor3 = color
	end
end

local function makeOptionButton(name, order, color)
	local button
	if optionTemplate then
		button = optionTemplate:Clone()
		button.Name = name
		button.Visible = true
		tintButton(button, color)
	else
		button = Instance.new("TextButton")
		button.Name = name
		styleButton(button, color)
	end

	button:SetAttribute("GeneratedDialogueOption", true)
	button.LayoutOrder = order
	button.ZIndex = math.max(button.ZIndex, optionsFrame.ZIndex + 2)
	button.Parent = optionsFrame
	return button
end

local function saveAndFocusCamera(adornee)
	local camera = getCamera()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not camera or not root or not adornee then
		return
	end

	savedCamera = {
		CameraType = camera.CameraType,
		CameraSubject = camera.CameraSubject,
		CFrame = camera.CFrame,
		FieldOfView = camera.FieldOfView,
	}
	if cameraTween then
		cameraTween:Cancel()
	end

	local npcPos = adornee.Position
	local rootPos = root.Position
	local between = rootPos:Lerp(npcPos, 0.5) + Vector3.new(0, 2.8, 0)
	local away = rootPos - npcPos
	if away.Magnitude < 2 then
		away = -root.CFrame.LookVector
	end
	local cameraPos = rootPos + away.Unit * 8 + Vector3.new(0, 4.5, 0)

	camera.CameraType = Enum.CameraType.Scriptable
	cameraTween =
		TweenService:Create(camera, TweenInfo.new(CAMERA_TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.lookAt(cameraPos, between),
			FieldOfView = math.max(52, camera.FieldOfView - 8),
		})
	cameraTween:Play()
end

local function restoreCamera()
	local camera = getCamera()
	if not camera or not savedCamera then
		return
	end
	if cameraTween then
		cameraTween:Cancel()
	end
	local restore = savedCamera
	savedCamera = nil
	cameraTween = TweenService:Create(camera, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = restore.CFrame,
		FieldOfView = restore.FieldOfView,
	})
	cameraTween:Play()
	local restoreConnection
	restoreConnection = cameraTween.Completed:Connect(function()
		if restoreConnection then
			restoreConnection:Disconnect()
		end
		if not savedCamera then
			camera.CameraType = restore.CameraType
			camera.CameraSubject = restore.CameraSubject
		end
	end)
end

local closeDialogue
local showNode
local advance

local function performAction(action)
	if action == "OpenBrushShop" then
		local keepNpcChromeHidden = activeAdornee ~= nil
		closeDialogue(keepNpcChromeHidden)
		requestWindow("BrushShopWindow")
		if keepNpcChromeHidden then
			keepChromeHiddenUntilWindowCloses("BrushShopWindow")
		end
	elseif action == "OpenDailyQuests" then
		if dailyQuestRemote then
			dailyQuestRemote:FireServer("UnlockFromZork")
		end
		closeDialogue()
		requestWindow("DailyQuestsWindow")
	elseif action == "Close" or action == nil or action == "" then
		closeDialogue()
	else
		warn("NpcDialogueClient: unknown dialogue action " .. tostring(action))
		closeDialogue()
	end
end

local function showOptions(node)
	clearOptions()
	local lineCount = type(node.Lines) == "table" and #node.Lines or 0
	if activeLineIndex < lineCount or node.Next then
		return
	end

	local options = type(node.Options) == "table" and node.Options or {}
	local visibleCount = 0
	for _, option in ipairs(options) do
		if optionAllowed(option) then
			visibleCount += 1
			local color = visibleCount == #options and RED
				or (option.Action == "OpenDailyQuests" and activeNpc.SecondaryColor or activeNpc.AccentColor)
			local button = makeOptionButton("Option" .. tostring(visibleCount), visibleCount, color)
			button.Text = tostring(option.Text or "Continue")
			button.Activated:Connect(function()
				if option.Next then
					showNode(tostring(option.Next))
				else
					performAction(option.Action)
				end
			end)
		end
	end

	if visibleCount == 0 then
		local button = makeOptionButton("OptionClose", 1, RED)
		button.Text = "Bye"
		button.Activated:Connect(closeDialogue)
	end
	optionsVisible = true
end

local function playBlip(index)
	if index % 3 ~= 0 then
		return
	end
	voice.PlaybackSpeed = 1.22 + ((index % 7) * 0.045)
	voice.TimePosition = 0
	voice:Play()
end

local function typeCurrentLine(node)
	dialogueToken += 1
	local token = dialogueToken
	clearOptions()
	bodyText.Text = ""
	typing = true
	fullLine = tostring((node.Lines or {})[activeLineIndex] or "")

	task.spawn(function()
		for index = 1, #fullLine do
			if token ~= dialogueToken then
				return
			end
			bodyText.Text = string.sub(fullLine, 1, index)
			local char = string.sub(fullLine, index, index)
			if char ~= " " and char ~= "\n" then
				playBlip(index)
			end
			task.wait(TYPE_INTERVAL)
		end
		if token ~= dialogueToken then
			return
		end
		typing = false
		showOptions(node)
	end)
end

function showNode(nodeId)
	local node = activeNpc and activeNpc.Nodes and activeNpc.Nodes[nodeId]
	if not node then
		closeDialogue()
		return
	end
	activeNodeId = nodeId
	activeLineIndex = 1
	typeCurrentLine(node)
end

function advance()
	if not activeNpc or not activeNodeId then
		return
	end
	if optionsVisible then
		return
	end
	if typing then
		dialogueToken += 1
		typing = false
		bodyText.Text = fullLine
		local node = activeNpc.Nodes[activeNodeId]
		if node then
			showOptions(node)
		end
		return
	end

	local node = activeNpc.Nodes[activeNodeId]
	local lineCount = type(node.Lines) == "table" and #node.Lines or 0
	if activeLineIndex < lineCount then
		activeLineIndex += 1
		typeCurrentLine(node)
	elseif node.Next then
		showNode(tostring(node.Next))
	else
		showOptions(node)
	end
end

function closeDialogue(keepNpcChromeHidden)
	dialogueToken += 1
	typing = false
	clearOptions()
	bodyText.Text = ""
	dialogueRoot.Visible = false
	unlockPlayerMovement()
	restoreCamera()
	if keepNpcChromeHidden ~= true then
		local promptWasTracked = activePrompt and hiddenNpcPrompts[activePrompt] ~= nil
		restoreNpcChrome()
		if activePrompt and activePrompt.Parent and not promptWasTracked then
			activePrompt.Enabled = true
		end
	end
	activePrompt = nil
	activeAdornee = nil
	activeNpc = nil
	activeNodeId = nil
	activeContext = {}
end

local function openDialogue(prompt)
	local npcId = getPromptNpcId(prompt)
	if not npcId then
		return
	end
	local npc = DialogueData.GetNpc(npcId)
	if not npc then
		return
	end

	local adornee = findPromptAdornee(prompt)
	if not adornee then
		warn("NpcDialogueClient: no adornee for " .. prompt:GetFullName())
		return
	end

	if activePrompt then
		closeDialogue()
	end

	activePrompt = prompt
	activeNpc = npc
	activeContext = {
		colorType = tostring(prompt:GetAttribute("ShopColor") or prompt:GetAttribute("ColorType") or ""),
		npcId = npcId,
	}
	activeAdornee = adornee
	hideNpcChrome(activeAdornee)
	if activePrompt.Parent and hiddenNpcPrompts[activePrompt] == nil then
		hiddenNpcPrompts[activePrompt] = activePrompt.Enabled
	end
	activePrompt.Enabled = false

	local accentColor = npc.AccentColor or Color3.fromRGB(76, 214, 224)
	if panelStroke:GetAttribute("UseNpcAccent") ~= false then
		panelStroke.Color = accentColor
	end
	if accentBar:GetAttribute("UseNpcAccent") ~= false then
		accentBar.BackgroundColor3 = accentColor
	end
	speakerName.Text = npc.DisplayName or npcId
	speakerRole.Text = npc.Role or ""
	lockPlayerMovement()
	dialogueRoot.Visible = true
	updateDialoguePosition()
	saveAndFocusCamera(adornee)
	showNode(getStartNode(npc, activeContext))
end

bodyButton.Activated:Connect(advance)

RunService.RenderStepped:Connect(updateDialoguePosition)

UserInputService.InputBegan:Connect(function(input, processed)
	if not dialogueRoot.Visible then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		if not inputIsInsideDialogue(input) then
			closeDialogue()
			return
		end
		if processed then
			return
		end
		if typing then
			advance()
		end
	elseif not processed and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then
		closeDialogue()
	end
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeringPlayer)
	if triggeringPlayer ~= player then
		return
	end
	openDialogue(prompt)
end)

player.CharacterRemoving:Connect(function()
	if dialogueRoot.Visible then
		closeDialogue()
	else
		restoreNpcChrome()
	end
end)

print("[NpcDialogueClient] cinematic NPC dialogue ready.")
