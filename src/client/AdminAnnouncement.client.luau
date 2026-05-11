-- Disabled: no PlayerGui UI should be created at runtime.
if true then
	return
end

-- Simple display for moderator/admin announcements.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local ClientUIRoot = require(ReplicatedStorage:WaitForChild("ClientUIRoot"))

local gui = ClientUIRoot.GetLayer(player:WaitForChild("PlayerGui"), "AdminAnnouncementUI")

local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(0.5, 0)
label.Size = UDim2.new(0, 560, 0, 56)
label.Position = UDim2.new(0.5, 0, 0, 70)
label.BackgroundColor3 = Color3.fromRGB(35, 38, 45)
label.BackgroundTransparency = 0.1
label.BorderSizePixel = 0
label.Font = Enum.Font.LuckiestGuy
label.TextSize = 22
label.TextColor3 = Color3.fromRGB(255, 255, 255)
label.TextStrokeTransparency = 0
label.TextStrokeColor3 = Color3.fromRGB(20, 22, 28)
label.TextWrapped = true
label.Visible = false
label.ZIndex = 100
label.Parent = gui
Instance.new("UICorner", label).CornerRadius = UDim.new(0, 16)

local token = 0
local function show(message)
	if not message or message == "" then
		return
	end
	token += 1
	local myToken = token
	label.Text = message
	label.TextTransparency = 0
	label.TextStrokeTransparency = 0
	label.Visible = true
	task.delay(4, function()
		if myToken == token then
			local tween = TweenService:Create(label, TweenInfo.new(0.25), {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			})
			tween:Play()
			tween.Completed:Wait()
			if myToken == token then
				label.Visible = false
			end
		end
	end)
end

player:GetAttributeChangedSignal("AdminAnnouncement"):Connect(function()
	show(player:GetAttribute("AdminAnnouncement"))
end)
