local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local currentHoverModel = nil
local touchHoverUntil = 0
local lastScanAt = 0

local HOVER_SCAN_INTERVAL = 0.05
local MAX_HOVER_DISTANCE = 500
local TOUCH_HOVER_DURATION = 2

local function getCharacter()
	return player.Character
end

local function findBreakableModel(instance)
	local cursor = instance
	while cursor and cursor ~= Workspace do
		if cursor:IsA("Model") and cursor:GetAttribute("BreakableId") then
			return cursor
		end
		cursor = cursor.Parent
	end
	return nil
end

local function getHealthBar(model)
	local primary = model and model.PrimaryPart
	local healthBar = primary and primary:FindFirstChild("HealthBar")
	if healthBar and healthBar:IsA("BillboardGui") then
		return healthBar
	end
	return nil
end

local function setModelHealthVisible(model, visible)
	local healthBar = getHealthBar(model)
	if healthBar then
		healthBar.Enabled = visible
	end
end

local function setHoveredModel(model)
	if currentHoverModel == model then
		return
	end
	if currentHoverModel then
		setModelHealthVisible(currentHoverModel, false)
	end
	currentHoverModel = model
	if currentHoverModel then
		setModelHealthVisible(currentHoverModel, true)
	end
end

local function raycastScreenPoint(screenPosition)
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end

	local ray = camera:ViewportPointToRay(screenPosition.X, screenPosition.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { getCharacter() }
	params.IgnoreWater = true

	local result = Workspace:Raycast(ray.Origin, ray.Direction * MAX_HOVER_DISTANCE, params)
	return result and findBreakableModel(result.Instance) or nil
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local model = raycastScreenPoint(input.Position)
	setHoveredModel(model)
	touchHoverUntil = model and (os.clock() + TOUCH_HOVER_DURATION) or 0
end)

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	if now - lastScanAt < HOVER_SCAN_INTERVAL then
		return
	end
	lastScanAt = now

	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		if touchHoverUntil > 0 and now > touchHoverUntil then
			touchHoverUntil = 0
			setHoveredModel(nil)
		end
		return
	end

	local mouseLocation = UserInputService:GetMouseLocation()
	setHoveredModel(raycastScreenPoint(mouseLocation))
end)

Workspace.DescendantRemoving:Connect(function(instance)
	if instance == currentHoverModel or (currentHoverModel and instance:IsAncestorOf(currentHoverModel)) then
		currentHoverModel = nil
	end
end)
