-- Bind-only transition used by shop/interior teleports.
-- The fade frame must be Studio-authored under PlayerGui.MainHUD.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Events = ReplicatedStorage:WaitForChild("Events")
local transitionEvent = Events:WaitForChild("ShopTransition")

local warned = {}
local function warnOnce(key, message)
	if warned[key] then
		return
	end
	warned[key] = true
	warn(message)
end

local function getFade()
	local mainHud = playerGui:FindFirstChild("MainHUD") or playerGui:WaitForChild("MainHUD", 20)
	if not mainHud then
		warnOnce("MainHUD", "ShopTransition: missing PlayerGui.MainHUD")
		return nil, nil
	end

	local layer = mainHud:FindFirstChild("ShopTransitionOverlay")
		or mainHud:FindFirstChild("TransitionOverlay")
		or mainHud:FindFirstChild("ShopFade")
	if not layer or not layer:IsA("GuiObject") then
		warnOnce("Overlay", "ShopTransition: missing PlayerGui.MainHUD.ShopTransitionOverlay")
		return nil, nil
	end

	local fade = layer.Name == "ShopFade" and layer or layer:FindFirstChild("ShopFade")
	if not fade or not fade:IsA("GuiObject") then
		warnOnce("Fade", "ShopTransition: missing PlayerGui.MainHUD.ShopTransitionOverlay.ShopFade")
		return nil, nil
	end

	return layer, fade
end

local activeTween
local token = 0

local function tweenFade(targetTransparency, duration, hideWhenDone)
	local layer, fade = getFade()
	if not layer or not fade then
		return
	end

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
