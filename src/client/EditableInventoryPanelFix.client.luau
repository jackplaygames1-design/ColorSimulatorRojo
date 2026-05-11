-- Fixes handmade InventoryWindow detail panel layering/visibility.
-- This does not create a new UI. It only corrects your existing DetailsPanel objects.

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local BUTTON_LABELS = {
	EquipButton = "EQUIP",
	LockButton = "LOCK",
	DeleteButton = "DELETE",
}

local BUTTON_COLORS = {
	EquipButton = Color3.fromRGB(84, 225, 112),
	LockButton = Color3.fromRGB(88, 174, 255),
	DeleteButton = Color3.fromRGB(220, 46, 58),
}

local function findInventoryWindow()
	for _, obj in ipairs(playerGui:GetDescendants()) do
		if obj.Name == "InventoryWindow" and obj:IsA("GuiObject") then
			return obj
		end
	end
	return nil
end

local function findDetailsPanel(window)
	return window and window:FindFirstChild("DetailsPanel", true)
end

local function findChild(panel, name)
	local child = panel and panel:FindFirstChild(name, true)
	if child and child:IsA("GuiObject") then
		return child
	end
	return nil
end

local function ensureButtonText(button, text)
	if not button or not button:IsA("GuiButton") then
		return
	end

	local label = button:FindFirstChild("RuntimeText")
	if not label then
		label = Instance.new("TextLabel")
		label.Name = "RuntimeText"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Position = UDim2.fromScale(0, 0)
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextStrokeColor3 = Color3.fromRGB(35, 38, 45)
		label.TextStrokeTransparency = 0.15
		label.Parent = button
	end
	label.Text = text
	label.Visible = true
	label.ZIndex = math.max(button.ZIndex + 2, 20)

	if button:IsA("ImageButton") then
		button.ImageTransparency = 1
	end
	button.BackgroundColor3 = BUTTON_COLORS[button.Name] or button.BackgroundColor3
	button.BackgroundTransparency = 0
	button.Visible = true
	button.ZIndex = math.max(button.ZIndex, 18)
end

local function forceTextLabel(label, text, y, height, size)
	if not label or not (label:IsA("TextLabel") or label:IsA("TextButton")) then
		return
	end
	label.BackgroundTransparency = 1
	label.Position = UDim2.new(0, 12, 0, y)
	label.Size = UDim2.new(1, -24, 0, height)
	label.Text = label.Text ~= "" and label.Text or text
	label.TextColor3 = Color3.fromRGB(38, 36, 52)
	label.TextStrokeTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextWrapped = true
	label.Visible = true
	label.ZIndex = 20
	if size then
		label.TextSize = size
		label.TextScaled = false
	end
end

local function fixPanel()
	local window = findInventoryWindow()
	local panel = findDetailsPanel(window)
	if not panel or not panel:IsA("GuiObject") then
		return false
	end

	panel.ClipsDescendants = false
	panel.ZIndex = math.max(panel.ZIndex, 10)

	local preview = findChild(panel, "PreviewImage") or findChild(panel, "PreviewIcon") or findChild(panel, "BigPreview")
	if preview then
		preview.AnchorPoint = Vector2.new(0.5, 0)
		preview.Position = UDim2.new(0.5, 0, 0, 16)
		preview.Size = UDim2.fromOffset(112, 112)
		preview.BackgroundTransparency = 1
		preview.Visible = true
		preview.ZIndex = 14
		if preview:IsA("ImageLabel") or preview:IsA("ImageButton") then
			preview.ImageTransparency = 0
			preview.ScaleType = Enum.ScaleType.Fit
		end
	end

	forceTextLabel(findChild(panel, "ItemName") or findChild(panel, "SelectedName"), "Rainbow Color", 138, 28)
	forceTextLabel(findChild(panel, "RarityLabel"), "Rare • Glitched", 170, 24)
	forceTextLabel(findChild(panel, "StatsLabel") or findChild(panel, "Stats"), "Power: 25\nEquipped: No\nLocked: No", 202, 76, 16)

	local equip = findChild(panel, "EquipButton")
	local lock = findChild(panel, "LockButton")
	local delete = findChild(panel, "DeleteButton")

	if equip then
		equip.Position = UDim2.new(0, 12, 1, -116)
		equip.Size = UDim2.new(1, -24, 0, 32)
		ensureButtonText(equip, BUTTON_LABELS.EquipButton)
	end
	if lock then
		lock.Position = UDim2.new(0, 12, 1, -76)
		lock.Size = UDim2.new(0.5, -16, 0, 32)
		ensureButtonText(lock, BUTTON_LABELS.LockButton)
	end
	if delete then
		delete.Position = UDim2.new(0.5, 4, 1, -76)
		delete.Size = UDim2.new(0.5, -16, 0, 32)
		ensureButtonText(delete, BUTTON_LABELS.DeleteButton)
	end

	return true
end

task.defer(function()
	for _ = 1, 80 do
		fixPanel()
		task.wait(0.15)
	end
end)

playerGui.DescendantAdded:Connect(function(obj)
	if obj.Name == "InventoryWindow" or obj.Name == "DetailsPanel" or BUTTON_LABELS[obj.Name] then
		task.defer(fixPanel)
	end
end)

while task.wait(1) do
	fixPanel()
end
