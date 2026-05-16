local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local AudioIds = require(ReplicatedStorage:WaitForChild("AudioIds"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SOUND_EVENT_NAME = "ColorSimulatorPlaySound"
local WHITE = Color3.fromRGB(255, 255, 255)
local DARK = Color3.fromRGB(23, 27, 38)
local CYAN = Color3.fromRGB(84, 229, 238)
local GREEN = Color3.fromRGB(91, 228, 126)
local GOLD = Color3.fromRGB(255, 218, 74)
local PINK = Color3.fromRGB(255, 105, 165)
local RED = Color3.fromRGB(255, 91, 104)

local RNG = Random.new()
local states = setmetatable({}, { __mode = "k" })
local fallbackSoundGroup = nil
local lastHoverSoundAt = 0

local ACTION_ACCENTS = {
	BUY = GREEN,
	CLAIM = GREEN,
	CLAIMED = GREEN,
	CONFIRM = GREEN,
	EQUIP = GREEN,
	EQUIPPED = GREEN,
	PLAY = GREEN,
	REDEEM = GOLD,
	TELEPORT = CYAN,
	SHOP = PINK,
	DELETE = RED,
	CLOSE = RED,
	X = RED,
	BACK = CYAN,
	NEXT = CYAN,
	CONTINUE = CYAN,
}

local function normalizeText(text)
	return string.upper(tostring(text or "")):gsub("^%s+", ""):gsub("%s+$", "")
end

local function normalizeSoundId(soundId)
	if type(soundId) == "number" then
		if soundId <= 0 then
			return nil
		end
		return "rbxassetid://" .. tostring(soundId)
	end
	if type(soundId) ~= "string" then
		return nil
	end

	local trimmed = soundId:gsub("^%s+", ""):gsub("%s+$", "")
	if trimmed == "" or trimmed == "0" or trimmed == "rbxassetid://0" then
		return nil
	end
	if tonumber(trimmed) then
		return "rbxassetid://" .. trimmed
	end
	return trimmed
end

local function getUiSoundConfig(soundName)
	local entry = AudioIds.UI and AudioIds.UI[soundName]
	if type(entry) == "table" then
		local soundId = normalizeSoundId(entry.Id or entry.SoundId or entry.AssetId)
		if not soundId then
			return nil
		end
		return {
			SoundId = soundId,
			Volume = tonumber(entry.Volume),
			PlaybackSpeed = tonumber(entry.PlaybackSpeed),
			PlaybackSpeedVariance = tonumber(entry.PlaybackSpeedVariance or entry.Variance),
		}
	end

	local soundId = normalizeSoundId(entry)
	if not soundId then
		return nil
	end
	return {
		SoundId = soundId,
	}
end

local function getFallbackSoundGroup()
	if fallbackSoundGroup and fallbackSoundGroup.Parent then
		return fallbackSoundGroup
	end
	local existing = SoundService:FindFirstChild("UI")
	if existing and existing:IsA("SoundGroup") then
		fallbackSoundGroup = existing
		return fallbackSoundGroup
	end
	return nil
end

local function playLocalUiSound(soundName)
	local config = getUiSoundConfig(soundName)
	if not config then
		return
	end

	local sound = Instance.new("Sound")
	sound.Name = "UIPolish_" .. tostring(soundName)
	sound.SoundId = config.SoundId
	sound.Volume = config.Volume or AudioIds.Defaults.Volume or 0.65
	sound.SoundGroup = getFallbackSoundGroup()

	local playbackSpeed = config.PlaybackSpeed or 1
	local variance = config.PlaybackSpeedVariance or 0
	if variance > 0 then
		playbackSpeed += RNG:NextNumber(-variance, variance)
	end
	sound.PlaybackSpeed = math.max(0.05, playbackSpeed)
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 2.5)
end

local function playUiSound(soundName)
	local soundEvent = ReplicatedStorage:FindFirstChild(SOUND_EVENT_NAME)
	if soundEvent and soundEvent:IsA("BindableEvent") then
		soundEvent:Fire("UI", soundName)
		return
	end
	playLocalUiSound(soundName)
end

local function getViewportSize()
	local camera = Workspace.CurrentCamera
	return camera and camera.ViewportSize or Vector2.new(1280, 720)
end

local function getButtonLabel(button)
	if button:IsA("TextButton") then
		local text = normalizeText(button.Text)
		if text ~= "" then
			return text
		end
	end

	local label = button:FindFirstChild("Label", true)
	if label and label:IsA("TextLabel") then
		local text = normalizeText(label.Text)
		if text ~= "" then
			return text
		end
	end

	return normalizeText(button.Name)
end

local function getAccentColor(button)
	local label = getButtonLabel(button)
	for word, color in pairs(ACTION_ACCENTS) do
		if label == word or string.find(label, word, 1, true) then
			return color
		end
	end

	if button.BackgroundTransparency < 0.95 then
		return button.BackgroundColor3:Lerp(WHITE, 0.2)
	end
	return CYAN
end

local function hasBackdropRole(button)
	local name = string.lower(button.Name)
	if not (string.find(name, "dim") or string.find(name, "overlay") or string.find(name, "backdrop")) then
		return false
	end
	if getButtonLabel(button) ~= normalizeText(button.Name) then
		return false
	end
	return true
end

local function isInteractive(button)
	if button:GetAttribute("NoInteractionPolish") == true or button:GetAttribute("NoGlobalButtonPolish") == true then
		return false
	end
	if button.Active == false then
		return false
	end

	local ok, interactable = pcall(function()
		return button.Interactable
	end)
	if ok and interactable == false then
		return false
	end

	return button.Visible
end

local function getOrCreateScale(button)
	local existing = button:FindFirstChild("InteractionPolishScale")
	if existing and existing:IsA("UIScale") then
		return existing
	end

	local current = button:FindFirstChildOfClass("UIScale")
	if current then
		return current
	end

	local scale = Instance.new("UIScale")
	scale.Name = "InteractionPolishScale"
	scale.Scale = 1
	scale.Parent = button
	return scale
end

local function getOrCreateStroke(button)
	local existing = button:FindFirstChildOfClass("UIStroke")
	if existing then
		return existing
	end

	local stroke = Instance.new("UIStroke")
	stroke.Name = "InteractionPolishStroke"
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = getAccentColor(button):Lerp(DARK, 0.35)
	stroke.Thickness = math.clamp(math.floor(button.AbsoluteSize.Y / 20), 1, 3)
	stroke.Transparency = 0.18
	stroke.Parent = button
	return stroke
end

local function addSoftGradient(button)
	if button:FindFirstChildOfClass("UIGradient") or button.BackgroundTransparency >= 0.95 then
		return
	end
	if button.AbsoluteSize.X >= getViewportSize().X * 0.35 and button.AbsoluteSize.Y >= getViewportSize().Y * 0.25 then
		return
	end

	local base = button.BackgroundColor3
	local gradient = Instance.new("UIGradient")
	gradient.Name = "InteractionPolishGradient"
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, base:Lerp(WHITE, 0.18)),
		ColorSequenceKeypoint.new(0.5, base),
		ColorSequenceKeypoint.new(1, base:Lerp(DARK, 0.08)),
	})
	gradient.Parent = button
end

local function addCornerIfNeeded(button)
	if button:FindFirstChildOfClass("UICorner") or button.BackgroundTransparency >= 0.95 then
		return
	end

	local corner = Instance.new("UICorner")
	corner.Name = "InteractionPolishCorner"
	local radius = math.clamp(math.floor(button.AbsoluteSize.Y * 0.24), 6, 18)
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = button
end

local function decorateButton(button)
	if hasBackdropRole(button) then
		return
	end

	addCornerIfNeeded(button)
	addSoftGradient(button)
	getOrCreateStroke(button)
end

local function getScaleTargets(button)
	local size = button.AbsoluteSize
	local compact = math.min(size.X, size.Y) <= 46
	local touchOnly = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
	return {
		Hover = touchOnly and 1.02 or (compact and 1.075 or 1.045),
		Pressed = touchOnly and 0.9 or (compact and 0.91 or 0.94),
		Pop = compact and 1.13 or 1.085,
	}
end

local function tweenScale(state, multiplier, duration, easingStyle, easingDirection)
	if not state.Scale or not state.Scale.Parent then
		return
	end
	TweenService:Create(
		state.Scale,
		TweenInfo.new(
			duration or 0.12,
			easingStyle or Enum.EasingStyle.Quad,
			easingDirection or Enum.EasingDirection.Out
		),
		{ Scale = state.BaseScale * multiplier }
	):Play()
end

local function tweenStroke(state, button, hovering, pressing)
	local stroke = state.Stroke
	if not stroke or not stroke.Parent then
		return
	end

	local accent = getAccentColor(button)
	local color = pressing and accent:Lerp(WHITE, 0.35) or (hovering and accent or state.StrokeColor)
	local thickness = pressing and state.StrokeThickness + 2
		or (hovering and state.StrokeThickness + 1 or state.StrokeThickness)
	local transparency = pressing and 0.02 or (hovering and 0.08 or state.StrokeTransparency)

	TweenService:Create(stroke, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Color = color,
		Thickness = thickness,
		Transparency = transparency,
	}):Play()
end

local function getPointerPosition(button, inputObject)
	if inputObject and typeof(inputObject.Position) == "Vector3" then
		return Vector2.new(inputObject.Position.X, inputObject.Position.Y)
	end

	local mouse = UserInputService:GetMouseLocation()
	local pos = button.AbsolutePosition
	local size = button.AbsoluteSize
	if mouse.X >= pos.X and mouse.X <= pos.X + size.X and mouse.Y >= pos.Y and mouse.Y <= pos.Y + size.Y then
		return mouse
	end

	return pos + size / 2
end

local function ripple(button, screenPosition)
	if hasBackdropRole(button) or button.AbsoluteSize.X <= 0 or button.AbsoluteSize.Y <= 0 then
		return
	end

	local localPosition = screenPosition - button.AbsolutePosition
	local maxSize = math.max(button.AbsoluteSize.X, button.AbsoluteSize.Y) * 1.65
	local circle = Instance.new("Frame")
	circle.Name = "InteractionRipple"
	circle.AnchorPoint = Vector2.new(0.5, 0.5)
	circle.Position = UDim2.fromOffset(localPosition.X, localPosition.Y)
	circle.Size = UDim2.fromOffset(0, 0)
	circle.BackgroundColor3 = getAccentColor(button):Lerp(WHITE, 0.35)
	circle.BackgroundTransparency = 0.68
	circle.BorderSizePixel = 0
	circle.ZIndex = button.ZIndex + 3
	circle.Active = false
	circle.Parent = button

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = circle

	TweenService:Create(circle, TweenInfo.new(0.34, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(maxSize, maxSize),
	}):Play()
	Debris:AddItem(circle, 0.4)
end

local function playHoverSound()
	local now = os.clock()
	if now - lastHoverSoundAt < 0.08 then
		return
	end
	lastHoverSoundAt = now
	playUiSound("Hover")
end

local function bindButton(button)
	if states[button] or button:GetAttribute("InteractionPolishBound") == true then
		return
	end
	if not button:IsA("GuiButton") then
		return
	end

	task.defer(function()
		if not button.Parent then
			return
		end

		decorateButton(button)

		local scale = getOrCreateScale(button)
		local stroke = button:FindFirstChildOfClass("UIStroke")
		local state = {
			Scale = scale,
			BaseScale = scale.Scale,
			Stroke = stroke,
			StrokeColor = stroke and stroke.Color or DARK,
			StrokeThickness = stroke and stroke.Thickness or 1,
			StrokeTransparency = stroke and stroke.Transparency or 0.2,
			Hovering = false,
			Pressing = false,
		}
		states[button] = state
		button:SetAttribute("InteractionPolishBound", true)

		button.MouseEnter:Connect(function()
			if not isInteractive(button) or UserInputService.MouseEnabled ~= true then
				return
			end
			state.Hovering = true
			local targets = getScaleTargets(button)
			tweenScale(state, targets.Hover, 0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			tweenStroke(state, button, true, false)
			playHoverSound()
		end)

		button.MouseLeave:Connect(function()
			state.Hovering = false
			state.Pressing = false
			tweenScale(state, 1, 0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			tweenStroke(state, button, false, false)
		end)

		button.InputBegan:Connect(function(input)
			if
				not isInteractive(button)
				or (
					input.UserInputType ~= Enum.UserInputType.MouseButton1
					and input.UserInputType ~= Enum.UserInputType.Touch
				)
			then
				return
			end
			state.Pressing = true
			local targets = getScaleTargets(button)
			tweenScale(state, targets.Pressed, 0.055, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			tweenStroke(state, button, state.Hovering, true)
		end)

		button.InputEnded:Connect(function(input)
			if
				input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end
			state.Pressing = false
			local targets = getScaleTargets(button)
			tweenScale(
				state,
				state.Hovering and targets.Hover or 1,
				0.14,
				Enum.EasingStyle.Back,
				Enum.EasingDirection.Out
			)
			tweenStroke(state, button, state.Hovering, false)
		end)

		button.Activated:Connect(function(inputObject)
			if not isInteractive(button) then
				return
			end

			local targets = getScaleTargets(button)
			playUiSound("Click")
			ripple(button, getPointerPosition(button, inputObject))
			tweenScale(state, targets.Pressed, 0.045, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			task.delay(0.045, function()
				if not button.Parent then
					return
				end
				tweenScale(state, targets.Pop, 0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			end)
			task.delay(0.18, function()
				if not button.Parent then
					return
				end
				tweenScale(
					state,
					state.Hovering and targets.Hover or 1,
					0.12,
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.Out
				)
				tweenStroke(state, button, state.Hovering, false)
			end)
		end)

		button:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
			local gradient = button:FindFirstChild("InteractionPolishGradient")
			if gradient and gradient:IsA("UIGradient") then
				gradient.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, button.BackgroundColor3:Lerp(WHITE, 0.18)),
					ColorSequenceKeypoint.new(0.5, button.BackgroundColor3),
					ColorSequenceKeypoint.new(1, button.BackgroundColor3:Lerp(DARK, 0.08)),
				})
			end
		end)
	end)
end

local function scan(root)
	if root:IsA("GuiButton") then
		bindButton(root)
	end
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("GuiButton") then
			bindButton(descendant)
		end
	end
end

scan(playerGui)

playerGui.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("GuiButton") then
		bindButton(descendant)
	end
end)

task.spawn(function()
	while player.Parent do
		task.wait(3)
		scan(playerGui)
	end
end)
