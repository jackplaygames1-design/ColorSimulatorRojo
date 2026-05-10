-- Hooks the handmade PlayerGui.ClientUIRoot.MainHUD currency UI.
-- This script does NOT create a duplicate HUD/window. It only binds existing Studio UI
-- and creates tiny temporary gain popups/animations when values increase.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local WARNED = {}

local function warnOnce(key, message)
	if WARNED[key] then
		return
	end
	WARNED[key] = true
	warn(message)
end

local function formatNumber(value)
	value = math.floor(tonumber(value) or 0)
	local sign = value < 0 and "-" or ""
	value = math.abs(value)

	if value < 1000 then
		return sign .. tostring(value)
	end
	if value < 1000000 then
		local text = string.format("%.1f", value / 1000):gsub("%.0$", "")
		return sign .. text .. "K"
	end
	if value < 1000000000 then
		local text = string.format("%.1f", value / 1000000):gsub("%.0$", "")
		return sign .. text .. "M"
	end

	local text = string.format("%.1f", value / 1000000000):gsub("%.0$", "")
	return sign .. text .. "B"
end

local function printChildren(parent, indent)
	indent = indent or ""
	if not parent then
		return
	end

	for _, child in ipairs(parent:GetChildren()) do
		print(indent .. child.Name .. " [" .. child.ClassName .. "]")
	end
end

local function waitForMainHUD()
	local root = playerGui:WaitForChild("ClientUIRoot", 15)
	if not root then
		warnOnce("missing-root", "CurrencyHUD: missing PlayerGui.ClientUIRoot; handmade currency not hooked.")
		return nil
	end

	local mainHud = root:WaitForChild("MainHUD", 15)
	if not mainHud then
		warnOnce("missing-mainhud", "CurrencyHUD: missing PlayerGui.ClientUIRoot.MainHUD; handmade currency not hooked.")
		printChildren(root, "[CurrencyHUD] ClientUIRoot child: ")
		return nil
	end

	return mainHud
end

local function findCurrencyBar(mainHud)
	local leftHud = mainHud:FindFirstChild("LeftHUD")
	local bar = leftHud and leftHud:FindFirstChild("CurrencyBar")
		or mainHud:FindFirstChild("CurrencyBar")
		or mainHud:FindFirstChild("CurrencyBar", true)

	if not bar then
		warnOnce("missing-currencybar", "CurrencyHUD: missing handmade CurrencyBar.")
		printChildren(mainHud, "[CurrencyHUD] MainHUD child: ")
		return nil
	end

	return bar
end

local function setZRecursive(obj, z)
	if obj:IsA("GuiObject") then
		obj.ZIndex = z
	end
	for _, child in ipairs(obj:GetChildren()) do
		setZRecursive(child, z)
	end
end

local function polishCurrencyBar(bar)
	if not bar or not bar:IsA("GuiObject") then
		return
	end

	bar.BackgroundTransparency = 1
	bar.BorderSizePixel = 0
	bar.ClipsDescendants = false
	bar.Visible = true
	bar.ZIndex = math.max(bar.ZIndex, 10)

	-- If the bar is inside LeftHUD, let LeftHUD handle positioning. If it is still
	-- directly under MainHUD, place it cleanly in the lower-left safe zone.
	if bar.Parent and bar.Parent.Name == "LeftHUD" then
		bar.AnchorPoint = Vector2.new(0, 1)
		bar.Position = UDim2.fromScale(0, 1)
		bar.Size = UDim2.fromScale(1, 0.30)
	else
		bar.AnchorPoint = Vector2.new(0, 1)
		bar.Position = UDim2.new(0.035, 0, 0.96, 0)
		bar.Size = UDim2.new(0.16, 0, 0.20, 0)
	end

	local layout = bar:FindFirstChildOfClass("UIListLayout")
	if not layout then
		layout = Instance.new("UIListLayout")
		layout.Parent = bar
	end
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 10)

	for _, frame in ipairs(bar:GetChildren()) do
		if frame:IsA("GuiObject") and not frame:IsA("UIListLayout") then
			frame.BackgroundTransparency = 1
			frame.BorderSizePixel = 0
			frame.ClipsDescendants = false
			frame.Size = UDim2.new(0, 150, 0, 48)
			frame.ZIndex = bar.ZIndex + 1
			if frame.Name:lower():find("gem") or frame.Name:lower():find("diamond") then
				frame.LayoutOrder = 1
			elseif frame.Name:lower():find("coin") then
				frame.LayoutOrder = 2
			else
				frame.LayoutOrder = 3
			end
		end
	end

	setZRecursive(bar, bar.ZIndex)
end

local function findCurrencyFrame(root, names)
	for _, name in ipairs(names) do
		local frame = root:FindFirstChild(name)
		if frame and frame:IsA("GuiObject") then
			return frame
		end
	end

	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("GuiObject") then
			local lowered = descendant.Name:lower()
			for _, name in ipairs(names) do
				if lowered == name:lower() or lowered:find(name:lower(), 1, true) then
					return descendant
				end
			end
		end
	end

	return nil
end

local function findTextLabel(root, frameNames)
	local frame = findCurrencyFrame(root, frameNames)
	if frame then
		local amount = frame:FindFirstChild("Amount", true)
		if amount and amount:IsA("TextLabel") then
			return amount, frame
		end

		for _, descendant in ipairs(frame:GetDescendants()) do
			if descendant:IsA("TextLabel") then
				return descendant, frame
			end
		end
	end

	return nil, frame
end

local function styleAmountLabel(label)
	if not label then
		return
	end

	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.ZIndex = math.max(label.ZIndex, 12)

	local constraint = label:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = 12
	constraint.MaxTextSize = 28
	constraint.Parent = label
end

local function styleIcon(frame)
	if not frame then
		return
	end
	local icon = frame:FindFirstChild("Icon", true)
	if icon and icon:IsA("GuiObject") then
		icon.ZIndex = math.max(icon.ZIndex, 12)
		if icon:IsA("ImageLabel") or icon:IsA("ImageButton") then
			icon.BackgroundTransparency = 1
			icon.ScaleType = Enum.ScaleType.Fit
		end
	end
end

local function playGainEffect(label, frame, delta, prefix)
	if not label or not label.Parent or not frame then
		return
	end

	prefix = prefix or "+"
	local originalTextSize = label.TextSize
	local originalRotation = label.Rotation
	local originalColor = label.TextColor3

	local scale = frame:FindFirstChild("CurrencyPopScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "CurrencyPopScale"
		scale.Scale = 1
		scale.Parent = frame
	end

	TweenService:Create(scale, TweenInfo.new(0.10, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.16 }):Play()
	task.delay(0.10, function()
		if scale.Parent then
			TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
	end)

	label.TextColor3 = Color3.fromRGB(255, 245, 160)
	task.delay(0.18, function()
		if label.Parent then
			label.TextColor3 = originalColor
			label.TextSize = originalTextSize
			label.Rotation = originalRotation
		end
	end)

	local popup = Instance.new("TextLabel")
	popup.Name = "CurrencyGainPopup"
	popup.BackgroundTransparency = 1
	popup.AnchorPoint = Vector2.new(0, 0.5)
	popup.Position = UDim2.new(1, 6, 0.5, 0)
	popup.Size = UDim2.fromOffset(120, 34)
	popup.Font = Enum.Font.GothamBlack
	popup.Text = prefix .. formatNumber(delta)
	popup.TextColor3 = Color3.fromRGB(255, 255, 255)
	popup.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	popup.TextStrokeTransparency = 0
	popup.TextScaled = true
	popup.TextXAlignment = Enum.TextXAlignment.Left
	popup.ZIndex = (frame.ZIndex or 10) + 12
	popup.Parent = frame

	local popupConstraint = Instance.new("UITextSizeConstraint")
	popupConstraint.MinTextSize = 12
	popupConstraint.MaxTextSize = 24
	popupConstraint.Parent = popup

	TweenService:Create(popup, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(1, 18, 0.5, -30),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()

	task.delay(0.65, function()
		if popup.Parent then
			popup:Destroy()
		end
	end)
end

local function connectValue(valueObject, label, frame, missingText, prefix)
	if not label then
		return
	end
	if not valueObject then
		label.Text = missingText or "0"
		return
	end

	local lastValue = tonumber(valueObject.Value) or 0
	local initialized = false

	local function update()
		local newValue = tonumber(valueObject.Value) or 0
		label.Text = formatNumber(newValue)
		if initialized and newValue > lastValue then
			playGainEffect(label, frame, newValue - lastValue, prefix)
		end
		lastValue = newValue
		initialized = true
	end

	update()
	valueObject:GetPropertyChangedSignal("Value"):Connect(update)
end

local mainHud = waitForMainHUD()
if not mainHud then
	return
end

local currencyBar = findCurrencyBar(mainHud)
if not currencyBar then
	return
end

polishCurrencyBar(currencyBar)

local coinsAmount, coinsFrame = findTextLabel(currencyBar, { "CoinsFrame", "CoinFrame", "Coins", "Coin" })
local gemsAmount, gemsFrame = findTextLabel(currencyBar, { "GemsFrame", "GemFrame", "DiamondsFrame", "DiamondFrame", "Gems", "Diamonds" })
local colorAmount, colorFrame = findTextLabel(currencyBar, { "ColorFrame", "ColorsFrame", "PaintFrame", "Color" })

styleAmountLabel(coinsAmount)
styleAmountLabel(gemsAmount)
styleAmountLabel(colorAmount)
styleIcon(coinsFrame)
styleIcon(gemsFrame)
styleIcon(colorFrame)

if not coinsAmount then
	warnOnce("missing-coins-label", "CurrencyHUD: could not find CoinsFrame.Amount TextLabel.")
end
if not gemsAmount then
	warnOnce("missing-gems-label", "CurrencyHUD: could not find Gems/Diamonds Amount TextLabel.")
end

local leaderstats = player:WaitForChild("leaderstats", 20)
if not leaderstats then
	warnOnce("missing-leaderstats", "CurrencyHUD: leaderstats did not load.")
	return
end

local coins = leaderstats:FindFirstChild("Coins") or leaderstats:WaitForChild("Coins", 10)
local gems = leaderstats:FindFirstChild("Gems") or leaderstats:FindFirstChild("Diamonds")
if not gems then
	gems = leaderstats:WaitForChild("Gems", 10) or leaderstats:WaitForChild("Diamonds", 2)
end

local colorValue = leaderstats:FindFirstChild("Color") or leaderstats:FindFirstChild("Colors") or leaderstats:FindFirstChild("Paint")

connectValue(coins, coinsAmount, coinsFrame, "0", "+")
connectValue(gems, gemsAmount, gemsFrame, "0", "+")
connectValue(colorValue, colorAmount, colorFrame, "0", "+")

if not coins then
	warnOnce("missing-coins", "CurrencyHUD: leaderstats.Coins is missing.")
end
if not gems then
	warnOnce("missing-gems", "CurrencyHUD: leaderstats.Gems/Diamonds is missing.")
end

print("CurrencyHUD: hooked and polished handmade currency UI with gain effects.")
