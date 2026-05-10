-- CodesUI.client.luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local UIManager = require(ReplicatedStorage:WaitForChild("UIManager"))
local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))
local ClientUIRoot = require(ReplicatedStorage:WaitForChild("ClientUIRoot"))

local Events = ReplicatedStorage:WaitForChild("Events")
local redeemEvent = Events:WaitForChild("RedeemCode", 10)

local DARK = Color3.fromRGB(35, 38, 45)
local WHITE = Color3.fromRGB(255, 255, 255)
local BLUE = Color3.fromRGB(118, 205, 255)
local GREEN = Color3.fromRGB(116, 220, 125)
local RED = Color3.fromRGB(255, 105, 125)
local PANEL = Color3.fromRGB(255, 248, 252)
local PANEL_WIDTH = 540
local PANEL_HEIGHT = 320

local screenGui = ClientUIRoot.GetLayer(player.PlayerGui, "CodesUI")

local overlay = UITheme.CreateDimOverlay(screenGui, 50)

local panel = Instance.new("Frame")
panel.Name = "CodesPanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Size = UDim2.new(0, PANEL_WIDTH, 0, PANEL_HEIGHT)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.BackgroundColor3 = PANEL
panel.BorderSizePixel = 0
panel.Visible = false
panel.ZIndex = 60
panel.Parent = screenGui
UITheme.ApplyResponsiveScale(panel, PANEL_WIDTH, PANEL_HEIGHT, 0.74, 28)
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 22)
corner.Parent = panel
local stroke = Instance.new("UIStroke")
stroke.Color = DARK
stroke.Thickness = 5
stroke.Parent = panel

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 62)
header.BackgroundColor3 = BLUE
header.BorderSizePixel = 0
header.Parent = panel
local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 22)
headerCorner.Parent = header

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -76, 1, 0)
title.Position = UDim2.new(0, 20, 0, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.LuckiestGuy
title.TextSize = 30
title.TextColor3 = WHITE
title.TextStrokeTransparency = 0
title.TextStrokeColor3 = DARK
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "CODES"
title.Parent = header

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 42, 0, 42)
closeBtn.Position = UDim2.new(1, -54, 0.5, -21)
closeBtn.BackgroundColor3 = RED
closeBtn.Font = Enum.Font.LuckiestGuy
closeBtn.TextSize = 22
closeBtn.TextColor3 = WHITE
closeBtn.TextStrokeTransparency = 0
closeBtn.TextStrokeColor3 = DARK
closeBtn.Text = "X"
closeBtn.Parent = header
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 12)
closeCorner.Parent = closeBtn

local prompt = Instance.new("TextLabel")
prompt.Size = UDim2.new(1, -40, 0, 48)
prompt.Position = UDim2.new(0, 20, 0, 88)
prompt.BackgroundTransparency = 1
prompt.Font = Enum.Font.GothamBold
prompt.TextSize = 16
prompt.TextColor3 = Color3.fromRGB(80, 84, 104)
prompt.TextWrapped = true
prompt.TextXAlignment = Enum.TextXAlignment.Left
prompt.Text = "Redeem update codes for Coins, Color, and starter rewards."
prompt.Parent = panel

local input = Instance.new("TextBox")
input.Size = UDim2.new(1, -180, 0, 54)
input.Position = UDim2.new(0, 20, 0, 150)
input.BackgroundColor3 = WHITE
input.Font = Enum.Font.LuckiestGuy
input.TextSize = 22
input.TextColor3 = DARK
input.PlaceholderText = "ENTER CODE"
input.PlaceholderColor3 = Color3.fromRGB(150, 155, 175)
input.Text = ""
input.ClearTextOnFocus = false
input.Parent = panel
local inputCorner = Instance.new("UICorner")
inputCorner.CornerRadius = UDim.new(0, 14)
inputCorner.Parent = input
local inputStroke = Instance.new("UIStroke")
inputStroke.Color = DARK
inputStroke.Thickness = 3
inputStroke.Parent = input

local redeemBtn = Instance.new("TextButton")
redeemBtn.Size = UDim2.new(0, 130, 0, 54)
redeemBtn.Position = UDim2.new(1, -150, 0, 150)
redeemBtn.BackgroundColor3 = GREEN
redeemBtn.Font = Enum.Font.LuckiestGuy
redeemBtn.TextSize = 20
redeemBtn.TextColor3 = WHITE
redeemBtn.TextStrokeTransparency = 0
redeemBtn.TextStrokeColor3 = DARK
redeemBtn.Text = "REDEEM"
redeemBtn.Parent = panel
local redeemCorner = Instance.new("UICorner")
redeemCorner.CornerRadius = UDim.new(0, 14)
redeemCorner.Parent = redeemBtn
local redeemStroke = Instance.new("UIStroke")
redeemStroke.Color = DARK
redeemStroke.Thickness = 3
redeemStroke.Parent = redeemBtn

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -40, 0, 46)
statusLabel.Position = UDim2.new(0, 20, 0, 222)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.GothamBold
statusLabel.TextSize = 15
statusLabel.TextColor3 = Color3.fromRGB(80, 84, 104)
statusLabel.TextWrapped = true
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Text = "Try RELEASE or COLOR."
statusLabel.Parent = panel

local isOpen = false
local pending = false

local function applyModalLayer()
	panel.ZIndex = 60
	for _, obj in ipairs(panel:GetDescendants()) do
		if obj:IsA("GuiObject") and obj.ZIndex < 61 then
			obj.ZIndex = 61
		end
	end
	closeBtn.ZIndex = 70
end

local function setStatus(text, color)
	statusLabel.Text = text or ""
	statusLabel.TextColor3 = color or Color3.fromRGB(80, 84, 104)
end

local function submitCode()
	if pending then
		return
	end

	local code = input.Text
	if code == "" then
		setStatus("Enter a code first.", RED)
		return
	end

	pending = true
	redeemBtn.Text = "..."
	setStatus("Checking code...")
	if not redeemEvent then
		pending = false
		redeemBtn.Text = "REDEEM"
		setStatus("Codes are still loading. Restart Play after Rojo syncs.", RED)
		return
	end
	redeemEvent:FireServer(code)
end

local function toggleCodes(open)
	isOpen = open
	if open then
		overlay.Visible = true
		overlay.BackgroundTransparency = 1
		panel.Visible = true
		panel.Size = UDim2.new(0, 80, 0, 80)
		panel.Position = UDim2.fromScale(0.5, 0.5)
		applyModalLayer()
		TweenService:Create(overlay, TweenInfo.new(0.18), {
			BackgroundTransparency = 0.4,
		}):Play()
		TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Back), {
			Size = UDim2.new(0, PANEL_WIDTH, 0, PANEL_HEIGHT),
			Position = UDim2.fromScale(0.5, 0.5),
		}):Play()
	else
		TweenService:Create(overlay, TweenInfo.new(0.16), {
			BackgroundTransparency = 1,
		}):Play()
		TweenService:Create(panel, TweenInfo.new(0.16), {
			Size = UDim2.new(0, 0, 0, 0),
			Position = UDim2.fromScale(0.5, 0.5),
		}):Play()
		task.delay(0.16, function()
			if not isOpen then
				panel.Visible = false
				overlay.Visible = false
			end
		end)
	end
end

redeemBtn.MouseButton1Click:Connect(submitCode)
input.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		submitCode()
	end
end)

closeBtn.MouseButton1Click:Connect(function()
	toggleCodes(false)
end)

overlay.MouseButton1Click:Connect(function()
	toggleCodes(false)
end)

if redeemEvent then
	redeemEvent.OnClientEvent:Connect(function(success, message)
		pending = false
		redeemBtn.Text = "REDEEM"
		if success then
			input.Text = ""
			setStatus(tostring(message or "Code redeemed!"), Color3.fromRGB(45, 150, 80))
		else
			setStatus(tostring(message or "Could not redeem code."), RED)
		end
	end)
end

UIManager.register("Codes", function() toggleCodes(true) end, function() toggleCodes(false) end, function() return isOpen end)

local codesBtn = ReplicatedStorage:WaitForChild("HudButton_CODES", 10)
if codesBtn then
	codesBtn.Event:Connect(function()
		UIManager.toggle("Codes")
	end)
end
