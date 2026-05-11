-- Keeps the handmade side HUD inside the visible screen area without creating UI.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SAFE_MARGIN = 12
local TOP_MARGIN = 10
local BOTTOM_MARGIN = 10
local MAX_SAFE_SCALE = 1
local MIN_SAFE_SCALE = 0.72

local SIDE_CONTAINER_NAMES = {
	LeftHUD = true,
	LeftButtons = true,
	SideHUD = true,
	SideButtons = true,
	SideDock = true,
}

local FLOATING_WIDGET_NAMES = {
	CurrencyBar = true,
	StatsButton = true,
	StatsToggle = true,
	LeaderboardToggle = true,
}

local function isGuiObject(obj)
	return obj and obj:IsA("GuiObject")
end

local function isSideWidget(obj)
	if not isGuiObject(obj) then
		return false
	end
	if SIDE_CONTAINER_NAMES[obj.Name] or FLOATING_WIDGET_NAMES[obj.Name] then
		return true
	end
	if obj:IsA("GuiButton") then
		return obj.Name:find("Button") ~= nil or obj.Name:find("Toggle") ~= nil
	end
	return false
end

local function addPositionDelta(obj, deltaX, deltaY)
	if deltaX == 0 and deltaY == 0 then
		return
	end

	local position = obj.Position
	obj.Position = UDim2.new(position.X.Scale, position.X.Offset + deltaX, position.Y.Scale, position.Y.Offset + deltaY)
end

local function ensureScale(obj, scaleValue)
	local scale = obj:FindFirstChild("SafeAreaScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "SafeAreaScale"
		scale.Parent = obj
	end
	scale.Scale = scaleValue
end

local function unclampVisuals(obj)
	if isGuiObject(obj) then
		obj.ClipsDescendants = false
	end
	for _, descendant in ipairs(obj:GetDescendants()) do
		if descendant:IsA("GuiObject") then
			descendant.ClipsDescendants = false
		end
	end
end

local function clampToViewport(obj, viewportSize, marginLeft, marginTop, marginBottom)
	if not isGuiObject(obj) or not obj.Visible then
		return
	end

	local size = obj.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return
	end

	local availableHeight = math.max(1, viewportSize.Y - marginTop - marginBottom)
	local scaleValue = math.clamp(availableHeight / size.Y, MIN_SAFE_SCALE, MAX_SAFE_SCALE)
	if size.Y > availableHeight + 1 then
		ensureScale(obj, scaleValue)
	end

	local position = obj.AbsolutePosition
	local scaledSize = obj.AbsoluteSize
	local minX = marginLeft
	local maxX = viewportSize.X - SAFE_MARGIN
	local minY = marginTop
	local maxY = viewportSize.Y - marginBottom
	local deltaX = 0
	local deltaY = 0

	if position.X < minX then
		deltaX = minX - position.X
	elseif position.X + scaledSize.X > maxX then
		deltaX = maxX - (position.X + scaledSize.X)
	end

	if position.Y < minY then
		deltaY = minY - position.Y
	elseif position.Y + scaledSize.Y > maxY then
		deltaY = maxY - (position.Y + scaledSize.Y)
	end

	addPositionDelta(obj, math.floor(deltaX + 0.5), math.floor(deltaY + 0.5))
end

local function findMainHud()
	local root = playerGui:FindFirstChild("ClientUIRoot") or playerGui:WaitForChild("ClientUIRoot", 10)
	if not root then
		return nil
	end
	return root:FindFirstChild("MainHUD") or root:WaitForChild("MainHUD", 10)
end

local mainHud = findMainHud()
if not mainHud then
	return
end

local scheduled = false
local function applySafeArea()
	scheduled = false
	if not mainHud.Parent then
		return
	end

	local viewportSize = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or mainHud.AbsoluteSize
	if viewportSize.X <= 0 or viewportSize.Y <= 0 then
		viewportSize = mainHud.AbsoluteSize
	end

	mainHud.ClipsDescendants = false

	for _, child in ipairs(mainHud:GetChildren()) do
		if isGuiObject(child) and (SIDE_CONTAINER_NAMES[child.Name] or FLOATING_WIDGET_NAMES[child.Name]) then
			unclampVisuals(child)
			clampToViewport(child, viewportSize, SAFE_MARGIN, TOP_MARGIN, BOTTOM_MARGIN)
		end
	end

	local sideRoots = {
		mainHud:FindFirstChild("LeftHUD"),
		mainHud:FindFirstChild("LeftButtons"),
		mainHud:FindFirstChild("SideHUD"),
		mainHud:FindFirstChild("SideButtons"),
	}

	for _, sideRoot in ipairs(sideRoots) do
		if isGuiObject(sideRoot) then
			unclampVisuals(sideRoot)
			for _, child in ipairs(sideRoot:GetChildren()) do
				if isSideWidget(child) then
					clampToViewport(child, viewportSize, SAFE_MARGIN, TOP_MARGIN, BOTTOM_MARGIN)
				end
			end
		end
	end

	for _, descendant in ipairs(mainHud:GetDescendants()) do
		if
			isGuiObject(descendant)
			and FLOATING_WIDGET_NAMES[descendant.Name]
			and not descendant:FindFirstAncestor("ModalWindows")
		then
			clampToViewport(descendant, viewportSize, SAFE_MARGIN, TOP_MARGIN, BOTTOM_MARGIN)
		end
	end
end

local function scheduleSafeArea()
	if scheduled then
		return
	end
	scheduled = true
	task.defer(applySafeArea)
end

scheduleSafeArea()
task.delay(0.25, scheduleSafeArea)
task.delay(1, scheduleSafeArea)

mainHud.DescendantAdded:Connect(function(descendant)
	if isSideWidget(descendant) then
		task.defer(scheduleSafeArea)
	end
end)

mainHud:GetPropertyChangedSignal("AbsoluteSize"):Connect(scheduleSafeArea)
if Workspace.CurrentCamera then
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(scheduleSafeArea)
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(scheduleSafeArea)
	end
	scheduleSafeArea()
end)

RunService.RenderStepped:Connect(function()
	if mainHud:GetAttribute("SafeAreaDirty") == true then
		mainHud:SetAttribute("SafeAreaDirty", false)
		scheduleSafeArea()
	end
end)
