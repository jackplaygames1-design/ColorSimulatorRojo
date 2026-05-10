local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local enabled = false
local speed = 72

local function getCharacterParts()
	local character = player.Character
	if not character then
		return nil, nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	return humanoid, root
end

local function getMoveVector()
	local camera = workspace.CurrentCamera
	if not camera then
		return Vector3.zero
	end

	local move = Vector3.zero
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		move += camera.CFrame.LookVector
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		move -= camera.CFrame.LookVector
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		move += camera.CFrame.RightVector
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		move -= camera.CFrame.RightVector
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
		move += Vector3.yAxis
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
		move -= Vector3.yAxis
	end

	if move.Magnitude > 0 then
		return move.Unit
	end
	return Vector3.zero
end

local function setEnabled(value)
	enabled = value == true
	local humanoid, root = getCharacterParts()
	if humanoid then
		humanoid.PlatformStand = enabled
	end
	if root and not enabled then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
end

player:GetAttributeChangedSignal("AdminFlyEnabled"):Connect(function()
	setEnabled(player:GetAttribute("AdminFlyEnabled") == true)
end)

player.CharacterAdded:Connect(function()
	task.wait(0.25)
	setEnabled(player:GetAttribute("AdminFlyEnabled") == true)
end)

RunService.RenderStepped:Connect(function()
	if not enabled then
		return
	end

	local humanoid, root = getCharacterParts()
	if not humanoid or not root then
		return
	end

	humanoid.PlatformStand = true
	local move = getMoveVector()
	root.AssemblyLinearVelocity = move * speed
	root.AssemblyAngularVelocity = Vector3.zero

	local camera = workspace.CurrentCamera
	if camera then
		local look = camera.CFrame.LookVector
		local flatLook = Vector3.new(look.X, 0, look.Z)
		if flatLook.Magnitude > 0.01 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + flatLook.Unit)
		end
	end
end)

setEnabled(player:GetAttribute("AdminFlyEnabled") == true)
