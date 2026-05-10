-- Small full-screen fade used by shop door teleports.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local ClientUIRoot = require(ReplicatedStorage:WaitForChild("ClientUIRoot"))

local Events = ReplicatedStorage:WaitForChild("Events")
local transitionEvent = Events:WaitForChild("ShopTransition")

local layer = ClientUIRoot.GetLayer(player:WaitForChild("PlayerGui"), "ShopTransitionUI")
layer.ZIndex = 10000
layer.Visible = false
layer.Active = false

local fade = Instance.new("Frame")
fade.Name = "ShopFade"
fade.Size = UDim2.fromScale(1, 1)
fade.BackgroundColor3 = Color3.fromRGB(5, 7, 12)
fade.BackgroundTransparency = 1
fade.BorderSizePixel = 0
fade.Active = false
fade.Visible = false
fade.ZIndex = 10000
fade.Parent = layer

local activeTween
local token = 0

local function tweenFade(targetTransparency, duration, hideWhenDone)
	token += 1
	local myToken = token
	if activeTween then
		activeTween:Cancel()
		activeTween = nil
	end

	layer.Visible = true
	fade.Visible = true
	fade.Active = true
	activeTween = TweenService:Create(fade, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = targetTransparency,
	})
	activeTween:Play()
	activeTween.Completed:Connect(function()
		if myToken ~= token then
			return
		end
		activeTween = nil
		if hideWhenDone then
			fade.Visible = false
			fade.Active = false
			layer.Visible = false
		end
	end)
end

transitionEvent.OnClientEvent:Connect(function(action)
	if action == "FadeIn" then
		tweenFade(0, 0.18, false)
	elseif action == "FadeOut" then
		tweenFade(1, 0.26, true)
	end
end)
