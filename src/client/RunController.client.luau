-- Local sprint controller. It boosts the current server-provided WalkSpeed so upgrades
-- and equipped Color personality bonuses still remain the source of truth.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local GameBalance = require(ReplicatedStorage:WaitForChild("GameBalance"))

local RUN_ACTION = "ColorSimulatorRun"
local runningConfig = GameBalance.Running or {}
local enabled = runningConfig.Enabled ~= false
local speedMultiplier = tonumber(runningConfig.SpeedMultiplier) or 1.45
local minRunSpeed = tonumber(runningConfig.MinRunSpeed) or 62
local maxRunSpeed = tonumber(runningConfig.MaxRunSpeed) or 104

local humanoid
local baseWalkSpeed = 44
local isRunning = false
local applyingSpeed = false
local defaultFov = Workspace.CurrentCamera and Workspace.CurrentCamera.FieldOfView or 70

local function getRunSpeed()
	return math.clamp(baseWalkSpeed * speedMultiplier, minRunSpeed, maxRunSpeed)
end

local function tweenFov(target)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	TweenService:Create(camera, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		FieldOfView = target,
	}):Play()
end

local function applySpeed()
	if not humanoid or not enabled then
		return
	end

	applyingSpeed = true
	humanoid.WalkSpeed = isRunning and getRunSpeed() or baseWalkSpeed
	applyingSpeed = false
	tweenFov(isRunning and (defaultFov + 4) or defaultFov)
end

local function setRunning(active)
	if not enabled or isRunning == active then
		return
	end

	isRunning = active
	applySpeed()
end

local function bindHumanoid(character)
	humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		humanoid = character and character:WaitForChild("Humanoid", 10)
	end
	if not humanoid then
		return
	end

	baseWalkSpeed = humanoid.WalkSpeed
	humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
		if applyingSpeed then
			return
		end

		if isRunning then
			local current = humanoid.WalkSpeed
			local expected = getRunSpeed()
			if math.abs(current - expected) > 0.05 then
				baseWalkSpeed = current
				applySpeed()
			end
		else
			baseWalkSpeed = humanoid.WalkSpeed
		end
	end)

	humanoid.Died:Connect(function()
		isRunning = false
	end)
end

local function onRunAction(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		setRunning(true)
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		setRunning(false)
	end

	return Enum.ContextActionResult.Sink
end

if enabled then
	ContextActionService:BindAction(
		RUN_ACTION,
		onRunAction,
		true,
		Enum.KeyCode.LeftShift,
		Enum.KeyCode.RightShift,
		Enum.KeyCode.ButtonL3
	)
	ContextActionService:SetTitle(RUN_ACTION, "RUN")
	ContextActionService:SetPosition(RUN_ACTION, UDim2.new(1, -92, 1, -168))
end

if player.Character then
	bindHumanoid(player.Character)
end

player.CharacterAdded:Connect(function(character)
	isRunning = false
	task.defer(bindHumanoid, character)
end)
