-- Global readability polish for Color Simulator UI.
-- Fixes unreadable dark/blobbed button text by forcing bold white text with a dark outline.
-- Also makes hovered/pressed buttons turn cyan/blue for consistent feedback.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local TEXT_WHITE = Color3.fromRGB(255, 255, 255)
local OUTLINE = Color3.fromRGB(20, 24, 34)
local HOVER_BLUE = Color3.fromRGB(88, 224, 235)
local DISABLED_GREY = Color3.fromRGB(175, 181, 195)

local processedText = setmetatable({}, { __mode = "k" })
local processedButtons = setmetatable({}, { __mode = "k" })

local BUTTON_WORDS = {
	BUY = true,
	CLAIM = true,
	CLAIMED = true,
	EQUIP = true,
	SELECT = true,
	DELETE = true,
	LOCK = true,
	LOCKED = true,
	HIDE = true,
	SHOW = true,
	RELEASE = true,
	CONTINUE = true,
	CLOSE = true,
	OPEN = true,
	READY = true,
	AVAILABLE = true,
	CURRENT = true,
	SHOP = true,
	QUESTS = true,
	NEXT = true,
	DONE = true,
	REDEEM = true,
	TELEPORT = true,
	"IN PROGRESS" = true,
	"COMING SOON" = true,
	"DELETE OFF" = true,
	"SET ID" = true,
	OWNED = true,
}

local function normalizeText(text)
	return string.upper(tostring(text or "")):gsub("^%s+", ""):gsub("%s+$", "")
end

local function shouldStyleText(obj)
	if not (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) then
		return false
	end
	if obj:GetAttribute("NoGlobalTextPolish") == true then
		return false
	end
	local text = normalizeText(obj.Text)
	if text == "" then
		return false
	end
	if BUTTON_WORDS[text] then
		return true
	end
	if obj:IsA("TextButton") then
		return true
	end
	if #text <= 18 and (obj.Name:lower():find("button") or obj.Name:lower():find("status") or obj.Name:lower():find("pill")) then
		return true
	end
	return false
end

local function applyReadableText(obj)
	if processedText[obj] then
		return
	end
	processedText[obj] = true

	obj.Font = Enum.Font.GothamBlack
	obj.TextColor3 = TEXT_WHITE
	obj.TextStrokeColor3 = OUTLINE
	obj.TextStrokeTransparency = 0
	obj.TextTransparency = 0
	obj.TextWrapped = true

	if obj:IsA("TextButton") or obj:IsA("TextLabel") then
		obj.TextScaled = true
		local constraint = obj:FindFirstChild("ReadableTextSizeConstraint") or Instance.new("UITextSizeConstraint")
		constraint.Name = "ReadableTextSizeConstraint"
		constraint.MinTextSize = 10
		constraint.MaxTextSize = math.max(16, math.min(34, obj.TextSize > 0 and obj.TextSize or 22))
		constraint.Parent = obj
	end
end

local function isDisabledButton(button)
	local text = normalizeText(button.Text)
	return text == "LOCKED" or text == "CLAIMED" or text == "COMING SOON" or text == "SET ID" or text == "DELETE OFF" or button.Active == false
end

local function applyHover(button)
	if processedButtons[button] then
		return
	end
	processedButtons[button] = true

	button.AutoButtonColor = false
	local originalColor = button.BackgroundColor3
	local hoverColor = HOVER_BLUE
	local pressedColor = Color3.fromRGB(56, 190, 220)

	local function tweenColor(color)
		if not button.Parent then return end
		TweenService:Create(button, TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = color,
		}):Play()
	end

	button.MouseEnter:Connect(function()
		if isDisabledButton(button) then return end
		tweenColor(hoverColor)
	end)

	button.MouseLeave:Connect(function()
		if not button.Parent then return end
		if isDisabledButton(button) then
			button.BackgroundColor3 = DISABLED_GREY
		else
			tweenColor(originalColor)
		end
	end)

	button.MouseButton1Down:Connect(function()
		if isDisabledButton(button) then return end
		tweenColor(pressedColor)
	end)

	button.MouseButton1Up:Connect(function()
		if isDisabledButton(button) then return end
		local mouseLocation = UserInputService:GetMouseLocation()
		local pos = button.AbsolutePosition
		local size = button.AbsoluteSize
		local inside = mouseLocation.X >= pos.X and mouseLocation.X <= pos.X + size.X and mouseLocation.Y >= pos.Y and mouseLocation.Y <= pos.Y + size.Y
		tweenColor(inside and hoverColor or originalColor)
	end)

	button:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
		if not isDisabledButton(button) and button.BackgroundColor3 ~= hoverColor and button.BackgroundColor3 ~= pressedColor then
			originalColor = button.BackgroundColor3
		end
	end)

	button:GetPropertyChangedSignal("Text"):Connect(function()
		applyReadableText(button)
		if isDisabledButton(button) then
			button.BackgroundColor3 = DISABLED_GREY
		end
	end)
end

local function polish(obj)
	if shouldStyleText(obj) then
		applyReadableText(obj)
	end
	if obj:IsA("TextButton") then
		applyHover(obj)
	end
end

local function scan(root)
	for _, obj in ipairs(root:GetDescendants()) do
		polish(obj)
	end
end

scan(playerGui)

playerGui.DescendantAdded:Connect(function(obj)
	task.defer(function()
		if obj.Parent then
			polish(obj)
			for _, child in ipairs(obj:GetDescendants()) do
				polish(child)
			end
		end
	end)
end)

-- Re-polish periodically for UI created/changed by existing scripts.
task.spawn(function()
	while player.Parent do
		scan(playerGui)
		task.wait(2)
	end
end)
