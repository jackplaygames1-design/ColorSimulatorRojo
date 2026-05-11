-- Binds the Studio-authored CodesWindow without creating replacement UI.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Events = ReplicatedStorage:WaitForChild("Events")
local redeemEvent = Events:WaitForChild("RedeemCode", 10)

local root = playerGui:WaitForChild("ClientUIRoot", 15)
if not root then
	warn("EditableCodesBinder: missing PlayerGui.ClientUIRoot")
	return
end

local mainHud = root:WaitForChild("MainHUD", 15)
local modalWindows = mainHud and mainHud:WaitForChild("ModalWindows", 10)
local windowsFolder = modalWindows and modalWindows:WaitForChild("Windows", 10)
local codesWindow = windowsFolder and windowsFolder:WaitForChild("CodesWindow", 10)
if not codesWindow then
	warn("EditableCodesBinder: missing CodesWindow")
	return
end

local codeBox = codesWindow:FindFirstChild("CodeBox", true)
local redeemButton = codesWindow:FindFirstChild("RedeemButton", true)
local statusText = codesWindow:FindFirstChild("StatusText", true) or codesWindow:FindFirstChild("InfoText", true)

if not (codeBox and codeBox:IsA("TextBox")) then
	warn("EditableCodesBinder: CodesWindow needs a TextBox named CodeBox.")
	return
end
if not (redeemButton and redeemButton:IsA("GuiButton")) then
	warn("EditableCodesBinder: CodesWindow needs a GuiButton named RedeemButton.")
	return
end

local pending = false

local function setStatus(message, color)
	if statusText and statusText:IsA("TextLabel") then
		statusText.Text = tostring(message or "")
		statusText.TextColor3 = color or Color3.fromRGB(88, 96, 120)
	end
end

local function setPending(isPending)
	pending = isPending
	redeemButton.Active = not pending
	redeemButton.AutoButtonColor = not pending
	pcall(function()
		redeemButton.Interactable = not pending
	end)
	if redeemButton:IsA("TextButton") then
		redeemButton.Text = pending and "..." or "REDEEM"
	end
end

local function trim(text)
	return string.gsub(tostring(text or ""), "^%s*(.-)%s*$", "%1")
end

local function submitCode()
	if pending then
		return
	end

	local code = trim(codeBox.Text)
	if code == "" then
		setStatus("Enter a code first.", Color3.fromRGB(220, 72, 92))
		return
	end
	if not redeemEvent then
		setStatus("Codes are still loading. Restart Play after Rojo syncs.", Color3.fromRGB(220, 72, 92))
		return
	end

	setPending(true)
	setStatus("Checking code...")
	redeemEvent:FireServer(code)
end

redeemButton.Activated:Connect(submitCode)
codeBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		submitCode()
	end
end)

if redeemEvent then
	redeemEvent.OnClientEvent:Connect(function(success, message)
		setPending(false)
		if success then
			codeBox.Text = ""
			setStatus(message or "Code redeemed!", Color3.fromRGB(55, 160, 95))
		else
			setStatus(message or "Could not redeem code.", Color3.fromRGB(220, 72, 92))
		end
	end)
end

setPending(false)
setStatus("Try RELEASE, COLOR, PET, or UPDATE.")

print("[EditableCodesBinder] CodesWindow bound to existing Studio UI.")
