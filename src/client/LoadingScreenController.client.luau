-- Controls the Studio-authored StarterGui.LoadingGui clone in PlayerGui.
-- This script never creates or clones the loading screen; edit LoadingGui in Studio.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local ClientUIRoot = require(ReplicatedStorage:WaitForChild("ClientUIRoot"))

local RUN_ONCE_ATTRIBUTE = "ColorSimulatorLoadingControllerStarted"
local HEAVY_FX_READY_ATTRIBUTE = "ClientHeavyVFXReady"
local STARTUP_COMPLETE_ATTRIBUTE = "ClientStartupComplete"

if playerGui:GetAttribute(RUN_ONCE_ATTRIBUTE) == true then
	return
end
playerGui:SetAttribute(RUN_ONCE_ATTRIBUTE, true)
player:SetAttribute(HEAVY_FX_READY_ATTRIBUTE, false)
player:SetAttribute(STARTUP_COMPLETE_ATTRIBUTE, false)

local STEP_DELAY = 0.12
local HEAVY_FX_DELAY_AFTER_LOAD = 3
local WAIT_TIMEOUT = 30

local STEPS = {
	Data = {
		text = "Loading data...",
		progress = 0.22,
	},
	UI = {
		text = "Loading UI...",
		progress = 0.46,
	},
	Colors = {
		text = "Loading colors...",
		progress = 0.72,
	},
	World = {
		text = "Entering sector...",
		progress = 0.92,
	},
	Complete = {
		text = "Entering sector...",
		progress = 1,
	},
}

local function getLoadingGui()
	local first = nil
	for _, child in ipairs(playerGui:GetChildren()) do
		if child:IsA("ScreenGui") and child.Name == "LoadingGui" then
			if not first then
				first = child
			else
				child:Destroy()
			end
		end
	end
	return first or playerGui:WaitForChild("LoadingGui", 10)
end

local loadingGui = getLoadingGui()
if not (loadingGui and loadingGui:IsA("ScreenGui")) then
	warn("LoadingScreenController: missing PlayerGui.LoadingGui. Add StarterGui.LoadingGui in Studio.")
	return
end

loadingGui.ResetOnSpawn = false
loadingGui.IgnoreGuiInset = true
loadingGui.DisplayOrder = math.max(loadingGui.DisplayOrder, 100000)
loadingGui.Enabled = true
playerGui:SetAttribute("ColorSimulatorLoadingGuiShownEarly", true)
RunService.RenderStepped:Wait()

local root = loadingGui:FindFirstChild("LoadingRoot")
local statusText = loadingGui:FindFirstChild("StatusText", true)
local progressFill = loadingGui:FindFirstChild("ProgressFill", true)

local function setMainHudEnabled(enabled)
	local mainHud = playerGui:FindFirstChild("MainHUD") or ClientUIRoot.GetRoot(playerGui)
	if mainHud and mainHud:IsA("ScreenGui") then
		mainHud.Enabled = enabled
		return
	end
	if mainHud and mainHud:IsA("GuiObject") then
		mainHud.Visible = enabled
	end
end

setMainHudEnabled(false)

local function setStatus(step)
	if statusText and statusText:IsA("TextLabel") then
		statusText.Text = step.text
	end
	if progressFill and progressFill:IsA("GuiObject") then
		TweenService:Create(progressFill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(step.progress, 1),
		}):Play()
	end
	task.wait(STEP_DELAY)
end

local function waitForAttribute(instance, attributeName, expectedValue)
	while instance.Parent and instance:GetAttribute(attributeName) ~= expectedValue do
		instance:GetAttributeChangedSignal(attributeName):Wait()
	end
	return instance:GetAttribute(attributeName) == expectedValue
end

local function waitForChild(parent, childName, timeout)
	if not parent then
		return nil
	end
	return parent:FindFirstChild(childName) or parent:WaitForChild(childName, timeout or WAIT_TIMEOUT)
end

local function waitForDataReady()
	setStatus(STEPS.Data)
	if player:GetAttribute("DataManagerLoadFailed") == true then
		return false
	end
	if player:GetAttribute("DataManagerReady") ~= true then
		waitForAttribute(player, "DataManagerReady", true)
	end

	local colorStorage = waitForChild(player, "ColorStorage")
	if colorStorage then
		waitForChild(colorStorage, "CurrentWorld")
		waitForChild(colorStorage, "UnlockedColors")
	end

	print("[Loading] Data loaded")
	return true
end

local function waitForCharacterReady()
	local character = player.Character or player.CharacterAdded:Wait()
	waitForChild(character, "HumanoidRootPart")
	waitForChild(character, "Humanoid")
	print("[Loading] Character spawned")
	return true
end

local function waitForHudReady()
	setStatus(STEPS.UI)
	local mainHud = ClientUIRoot.GetRoot(playerGui)
	if not mainHud then
		warn("LoadingScreenController: PlayerGui.MainHUD did not appear before timeout.")
		return false
	end
	waitForChild(mainHud, "BottomButtons")
	local modalRoot = waitForChild(mainHud, "ModalWindows")
	local modalWindows = modalRoot and (modalRoot:FindFirstChild("Windows") or modalRoot)
	if not modalWindows then
		return false
	end
	task.wait(STEP_DELAY)
	print("[Loading] HUD ready")
	return true
end

local function waitForPetsReady()
	setStatus(STEPS.Colors)
	local petData = waitForChild(player, "PetData")
	if petData then
		waitForChild(petData, "Inventory")
		waitForChild(petData, "Equipped")
	end
	print("[Loading] Pets ready")
	return true
end

local function waitForWorldReady()
	setStatus(STEPS.World)
	local colorStorage = waitForChild(player, "ColorStorage")
	if colorStorage then
		waitForChild(colorStorage, "CurrentWorld")
		waitForChild(colorStorage, "UnlockedTeleports")
	end
	waitForChild(player, "TutorialProgress", 8)
	task.wait(STEP_DELAY)
	print("[Loading] World ready")
	return true
end

local function tweenGuiOut()
	setStatus(STEPS.Complete)

	local tweenInfo = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, descendant in ipairs(loadingGui:GetDescendants()) do
		if descendant:IsA("GuiObject") then
			local properties = {}
			if descendant:IsA("TextLabel") or descendant:IsA("TextButton") or descendant:IsA("TextBox") then
				properties.TextTransparency = 1
				properties.TextStrokeTransparency = 1
			end
			if descendant:IsA("ImageLabel") or descendant:IsA("ImageButton") then
				properties.ImageTransparency = 1
			end
			properties.BackgroundTransparency = 1
			TweenService:Create(descendant, tweenInfo, properties):Play()
		elseif descendant:IsA("UIStroke") then
			TweenService:Create(descendant, tweenInfo, {
				Transparency = 1,
			}):Play()
		end
	end

	if root and root:IsA("GuiObject") then
		TweenService:Create(root, tweenInfo, {
			BackgroundTransparency = 1,
		}):Play()
	end

	task.wait(0.5)
	loadingGui.Enabled = false
end

task.spawn(function()
	if not waitForDataReady() then
		return
	end
	waitForCharacterReady()
	waitForHudReady()
	waitForPetsReady()
	waitForWorldReady()

	player:SetAttribute(STARTUP_COMPLETE_ATTRIBUTE, true)
	playerGui:SetAttribute("ColorSimulatorLoadingComplete", true)
	setMainHudEnabled(true)
	tweenGuiOut()
	print("[Loading] Complete")

	task.delay(HEAVY_FX_DELAY_AFTER_LOAD, function()
		if player.Parent then
			player:SetAttribute(HEAVY_FX_READY_ATTRIBUTE, true)
		end
	end)
end)
