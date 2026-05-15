-- Bind-only power-up toast. The panel must be Studio-authored under PlayerGui.MainHUD.PowerUpToast.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ClientUIRoot = require(ReplicatedStorage:WaitForChild("ClientUIRoot"))
local Events = ReplicatedStorage:WaitForChild("Events")
local noticeEvent = Events:WaitForChild("WildBuffNotice")

local DEFAULT_COLOR = Color3.fromRGB(118, 238, 244)
local HIDDEN_POSITION = UDim2.new(0.5, 0, 0, -90)
local SHOWN_POSITION = UDim2.new(0.5, 0, 0, 82)

local warned = {}
local activeTween
local hideToken = 0
local tweenToken = 0

local function warnOnce(key, message)
	if warned[key] then
		return
	end
	warned[key] = true
	warn(message)
end

local function findText(parent, name)
	local object = parent and parent:FindFirstChild(name, true)
	if object and (object:IsA("TextLabel") or object:IsA("TextButton")) then
		return object
	end
	return nil
end

local function setText(parent, name, value)
	local label = findText(parent, name)
	if label then
		label.Text = tostring(value or "")
	end
	return label
end

local function getToast()
	local mainHud = ClientUIRoot.GetRoot(playerGui)
	if not mainHud then
		warnOnce("MainHUD", "BuffToastUI: missing PlayerGui.MainHUD")
		return nil
	end

	local toast = mainHud:FindFirstChild("PowerUpToast")
	if not toast or not toast:IsA("GuiObject") then
		warnOnce(
			"PowerUpToast",
			"BuffToastUI: missing editable PlayerGui.MainHUD.PowerUpToast. Run StudioMenuWindowsBuilder.UpdatePowerUpToastUI() in edit mode."
		)
		return nil
	end
	return toast
end

local function setToastColor(toast, color)
	color = typeof(color) == "Color3" and color or DEFAULT_COLOR

	local accent = toast:FindFirstChild("Accent", true)
	if accent and accent:IsA("GuiObject") then
		accent.BackgroundColor3 = color
	end

	local icon = toast:FindFirstChild("Icon", true)
	if icon and icon:IsA("GuiObject") then
		icon.BackgroundColor3 = color:Lerp(Color3.fromRGB(255, 255, 255), 0.14)
	end

	local stroke = toast:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = color
	end
end

local function formatPayload(payload)
	if payload.type == "buff" then
		local duration = math.max(0, math.floor(tonumber(payload.duration) or 0))
		return {
			title = tostring(payload.name or "Power Up"),
			body = duration > 0 and ("Active for " .. tostring(duration) .. "s") or "Power-up active",
			icon = "UP",
			color = payload.color,
		}
	elseif payload.type == "gems" then
		return {
			title = "Gem Surge",
			body = "+" .. tostring(payload.amount or 0) .. " Gems",
			icon = "GM",
			color = Color3.fromRGB(90, 255, 120),
		}
	elseif payload.type == "message" then
		return {
			title = "Power Up",
			body = tostring(payload.message or ""),
			icon = "UP",
			color = payload.color,
		}
	end
	return nil
end

local function tweenToast(toast, shown)
	tweenToken += 1
	local token = tweenToken
	if activeTween then
		activeTween:Cancel()
		activeTween = nil
	end

	toast.Visible = true
	toast.Position = shown and HIDDEN_POSITION or toast.Position
	activeTween = TweenService:Create(toast, TweenInfo.new(shown and 0.22 or 0.2, Enum.EasingStyle.Back), {
		Position = shown and SHOWN_POSITION or HIDDEN_POSITION,
		BackgroundTransparency = shown and 0.04 or 1,
	})
	activeTween:Play()
	activeTween.Completed:Connect(function()
		if token ~= tweenToken then
			return
		end
		activeTween = nil
		if not shown then
			toast.Visible = false
		end
	end)
end

local function showPowerUp(payload)
	local content = formatPayload(payload)
	if not content then
		return
	end

	local toast = getToast()
	if not toast then
		return
	end

	setText(toast, "Title", content.title)
	setText(toast, "Body", content.body)
	setText(toast, "IconText", content.icon)
	setToastColor(toast, content.color)

	hideToken += 1
	local token = hideToken
	tweenToast(toast, true)
	task.delay(2.35, function()
		if token == hideToken and toast.Parent then
			tweenToast(toast, false)
		end
	end)
end

local toast = getToast()
if toast then
	toast.Visible = false
	toast.Position = HIDDEN_POSITION
end

noticeEvent.OnClientEvent:Connect(function(payload)
	if type(payload) == "table" then
		showPowerUp(payload)
	end
end)
