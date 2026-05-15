-- Disabled: no PlayerGui UI should be created at runtime.
if true then
	return
end

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local ClientUIRoot = require(ReplicatedStorage:WaitForChild("ClientUIRoot"))

local events = ReplicatedStorage:WaitForChild("Events")
local noticeEvent = events:WaitForChild("WildBuffNotice")

local layer = ClientUIRoot.GetLayer(player.PlayerGui, "WildBuffToastUI")

local function showToast(message, color)
	message = tostring(message or "")
	color = color or Color3.fromRGB(118, 238, 244)

	local toast = Instance.new("TextLabel")
	toast.Name = "WildBuffToast"
	toast.AnchorPoint = Vector2.new(0.5, 1)
	toast.Size = UDim2.new(0, 360, 0, 50)
	toast.Position = UDim2.new(0.5, 0, 1, -210)
	toast.BackgroundColor3 = Color3.fromRGB(28, 32, 42)
	toast.BackgroundTransparency = 0
	toast.BorderSizePixel = 0
	toast.Font = Enum.Font.LuckiestGuy
	toast.TextSize = 18
	toast.TextScaled = true
	toast.TextWrapped = true
	toast.TextColor3 = Color3.fromRGB(255, 255, 255)
	toast.TextStrokeTransparency = 0.08
	toast.TextStrokeColor3 = Color3.fromRGB(20, 22, 28)
	toast.Text = message
	toast.ZIndex = 120
	toast.Parent = layer
	local textSizeLimit = Instance.new("UITextSizeConstraint")
	textSizeLimit.MinTextSize = 12
	textSizeLimit.MaxTextSize = 18
	textSizeLimit.Parent = toast

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = toast
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 3
	stroke.Transparency = 0.05
	stroke.Parent = toast

	TweenService:Create(toast, TweenInfo.new(0.18, Enum.EasingStyle.Back), {
		Position = UDim2.new(0.5, 0, 1, -232),
	}):Play()
	task.delay(2.1, function()
		if toast.Parent then
			TweenService:Create(toast, TweenInfo.new(0.22), {
				BackgroundTransparency = 1,
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			}):Play()
		end
	end)
	Debris:AddItem(toast, 2.45)
end

noticeEvent.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end

	if payload.type == "buff" then
		showToast(
			tostring(payload.name or "Wild Color") .. "! " .. tostring(math.floor(payload.duration or 0)) .. "s",
			payload.color
		)
	elseif payload.type == "gems" then
		showToast("+" .. tostring(payload.amount or 0) .. " Gems", Color3.fromRGB(90, 255, 120))
	elseif payload.type == "message" then
		showToast(tostring(payload.message or ""), payload.color)
	end
end)
