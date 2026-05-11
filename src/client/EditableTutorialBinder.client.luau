-- Simple editable tutorial window: Studio owns the text; this only switches steps.
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local root = playerGui:WaitForChild("ClientUIRoot", 15)
local mainHud = root and root:WaitForChild("MainHUD", 15)
local windowsFolder = mainHud
	and mainHud:WaitForChild("ModalWindows", 10)
	and mainHud.ModalWindows:WaitForChild("Windows", 10)

if not windowsFolder then
	return
end

local window = windowsFolder:FindFirstChild("TutorialWindow")
if not window or not window:IsA("GuiObject") then
	return
end

local stepsFolder = window:FindFirstChild("Steps", true)
local nextButton = window:FindFirstChild("NextButton", true)
local backButton = window:FindFirstChild("BackButton", true)
local stepLabel = window:FindFirstChild("StepLabel", true)
local index = 1

local function getSteps()
	local steps = {}
	if stepsFolder then
		for _, child in ipairs(stepsFolder:GetChildren()) do
			if child:IsA("GuiObject") then
				table.insert(steps, child)
			end
		end
	end
	table.sort(steps, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	return steps
end

local function setText(instance, value)
	if instance and (instance:IsA("TextLabel") or instance:IsA("TextButton")) then
		instance.Text = value
	end
end

local function refresh()
	local steps = getSteps()
	index = math.clamp(index, 1, math.max(#steps, 1))
	for stepIndex, step in ipairs(steps) do
		step.Visible = stepIndex == index
	end
	setText(stepLabel, tostring(index) .. " / " .. tostring(math.max(#steps, 1)))
end

local function connect(guiObject, callback)
	if guiObject and guiObject:IsA("GuiButton") then
		guiObject.Activated:Connect(callback)
	end
end

connect(nextButton, function()
	index += 1
	refresh()
end)
connect(backButton, function()
	index -= 1
	refresh()
end)

window:GetPropertyChangedSignal("Visible"):Connect(function()
	if window.Visible then
		refresh()
	end
end)

refresh()
