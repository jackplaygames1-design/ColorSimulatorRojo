-- Gives every player a real Starter Brush Tool while keeping collection server-validated.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ToolData = require(ReplicatedStorage:WaitForChild("ToolData"))

local TOOL_NAME = "Starter Brush"
local BRUSH_VISUAL_VERSION = "palm-grip-v2"

local function makePart(name, size, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function weldToHandle(handle, part, localCFrame)
	part.CFrame = handle.CFrame * localCFrame
	part.Parent = handle.Parent

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = part
	weld.Parent = part
end

local function createStarterBrushTool()
	local config = ToolData.get("StarterBrush")

	local tool = Instance.new("Tool")
	tool.Name = TOOL_NAME
	tool.ToolTip = "Collect Color"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool:SetAttribute("PaintToolId", "StarterBrush")
	tool:SetAttribute("GeneratedStarterBrush", true)
	tool:SetAttribute("BrushVisualVersion", BRUSH_VISUAL_VERSION)

	local handle = makePart(
		"Handle",
		Vector3.new(0.22, 0.22, 0.22),
		config.HandleColor or Color3.fromRGB(255, 213, 125),
		Enum.Material.SmoothPlastic
	)
	handle.Transparency = 1
	handle.Parent = tool

	local shaftRotation = CFrame.Angles(math.rad(90), 0, 0)
	weldToHandle(
		handle,
		makePart(
			"BrushShaft",
			Vector3.new(0.22, 1.45, 0.22),
			config.HandleColor or Color3.fromRGB(255, 213, 125),
			Enum.Material.Wood
		),
		CFrame.new(0, 0, -0.72) * shaftRotation
	)
	weldToHandle(
		handle,
		makePart("Grip", Vector3.new(0.34, 0.42, 0.34), Color3.fromRGB(45, 48, 58)),
		CFrame.new(0, 0, -0.16) * shaftRotation
	)
	weldToHandle(
		handle,
		makePart("Band", Vector3.new(0.48, 0.22, 0.48), Color3.fromRGB(190, 220, 238), Enum.Material.Metal),
		CFrame.new(0, 0, -1.28) * shaftRotation
	)
	weldToHandle(
		handle,
		makePart("BrushHead", Vector3.new(0.78, 0.42, 0.34), config.HeadColor or Color3.fromRGB(110, 235, 245)),
		CFrame.new(0, 0, -1.52)
	)
	weldToHandle(
		handle,
		makePart(
			"PaintTip",
			Vector3.new(0.76, 0.16, 0.38),
			config.PaintColor or Color3.fromRGB(255, 92, 164),
			Enum.Material.Neon
		),
		CFrame.new(0, -0.24, -1.55)
	)

	tool.Grip = CFrame.new(0.08, -0.08, -0.28) * CFrame.Angles(math.rad(-8), 0, math.rad(8))
	return tool
end

local function removeExtraGeneratedBrushes(container, keep)
	if not container then
		return
	end

	for _, child in ipairs(container:GetChildren()) do
		if
			child:IsA("Tool")
			and child ~= keep
			and (
				child:GetAttribute("GeneratedStarterBrush")
				or child:GetAttribute("PaintToolId") == "StarterBrush"
				or child.Name == TOOL_NAME
			)
		then
			child:Destroy()
		end
	end
end

local function ensureStarterBrushIn(container)
	if not container then
		return nil
	end

	local existing
	for _, child in ipairs(container:GetChildren()) do
		if
			child:IsA("Tool")
			and (
				child:GetAttribute("GeneratedStarterBrush")
				or child:GetAttribute("PaintToolId") == "StarterBrush"
				or child.Name == TOOL_NAME
			)
		then
			existing = existing or child
		end
	end

	if existing and existing:GetAttribute("BrushVisualVersion") ~= BRUSH_VISUAL_VERSION then
		existing:Destroy()
		existing = nil
	end

	if existing then
		existing:SetAttribute("PaintToolId", "StarterBrush")
		existing:SetAttribute("GeneratedStarterBrush", true)
		existing:SetAttribute("BrushVisualVersion", BRUSH_VISUAL_VERSION)
		existing.CanBeDropped = false
		removeExtraGeneratedBrushes(container, existing)
		return existing
	end

	local tool = createStarterBrushTool()
	tool.Parent = container
	return tool
end

local function ensurePlayerBrush(player)
	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 10)
	local starterGear = player:FindFirstChild("StarterGear") or player:WaitForChild("StarterGear", 10)
	local character = player.Character

	local equippedBrush = ensureStarterBrushIn(character)
	if not equippedBrush then
		ensureStarterBrushIn(backpack)
	else
		removeExtraGeneratedBrushes(backpack)
	end
	ensureStarterBrushIn(starterGear)
end

Players.PlayerAdded:Connect(function(player)
	task.defer(function()
		ensurePlayerBrush(player)
	end)

	player.CharacterAdded:Connect(function()
		task.wait(0.35)
		ensurePlayerBrush(player)
	end)
end)
