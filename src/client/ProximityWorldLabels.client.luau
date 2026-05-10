local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local labels = {}

local function getRoot()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function getLabelPosition(label)
	local adornee = label.Adornee
	if adornee and adornee:IsA("BasePart") then
		return adornee.Position
	end

	local parent = label.Parent
	if parent and parent:IsA("BasePart") then
		return parent.Position
	end

	return nil
end

local function trackLabel(obj)
	if not obj:IsA("BillboardGui") or not obj:GetAttribute("ProximityWorldLabel") then
		return
	end

	labels[obj] = true
	obj.Enabled = false
end

for _, obj in ipairs(workspace:GetDescendants()) do
	trackLabel(obj)
end

workspace.DescendantAdded:Connect(function(obj)
	task.defer(trackLabel, obj)
end)

RunService.RenderStepped:Connect(function()
	local root = getRoot()
	if not root then
		return
	end

	for label in pairs(labels) do
		if not label.Parent then
			labels[label] = nil
		else
			local position = getLabelPosition(label)
			if position then
				local parent = label.Parent
				if parent and parent:IsA("BasePart") and parent:GetAttribute("EggId") and parent:FindFirstChild("EggOptions") then
					label.Enabled = false
					continue
				end

				local showDistance = tonumber(label:GetAttribute("ShowDistance")) or 58
				local hideDistance = tonumber(label:GetAttribute("HideDistance")) or (showDistance + 10)
				local distance = (root.Position - position).Magnitude

				if label.Enabled then
					label.Enabled = distance <= hideDistance
				else
					label.Enabled = distance <= showDistance
				end
			end
		end
	end
end)
