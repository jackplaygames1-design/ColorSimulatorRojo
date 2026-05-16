-- Client-side paint brush feel: Tool activation, sweep visuals, and candidate detection.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local ClientUIRoot = require(ReplicatedStorage:WaitForChild("ClientUIRoot"))
local ColorData = require(ReplicatedStorage:WaitForChild("ColorData"))

local function loadToolData()
	local module = ReplicatedStorage:WaitForChild("ToolData", 3)
	if module then
		return require(module)
	end

	warn("PaintToolController: ToolData missing; using Starter Brush fallback config.")
	local fallback = {}
	fallback.Tools = {
		StarterBrush = {
			Id = "StarterBrush",
			DisplayName = "Starter Brush",
			Range = 9,
			Width = 7,
			Cooldown = 0.45,
			PowerMultiplier = 1,
			CollectPowerMultiplier = 1,
			SweepWidthMultiplier = 1,
			UseSpeedMultiplier = 1,
			PickupRadiusMultiplier = 1,
			VisualType = "Brush",
			MaxTargets = 8,
			MaxServerRange = 24,
			BrushRadius = 5,
			BrushTickRate = 0.14,
			BrushRewardMultiplier = 0.38,
			MaxGroundTargets = 6,
		},
	}
	function fallback.get(toolId)
		return fallback.Tools[toolId or ""] or fallback.Tools.StarterBrush
	end
	function fallback.GetEffectiveStats(toolId)
		local tool = fallback.get(toolId)
		return {
			Id = tool.Id,
			CollectPowerMultiplier = tool.CollectPowerMultiplier or tool.PowerMultiplier or 1,
			SweepWidthMultiplier = tool.SweepWidthMultiplier or 1,
			UseSpeedMultiplier = tool.UseSpeedMultiplier or 1,
			PickupRadiusMultiplier = tool.PickupRadiusMultiplier or 1,
			BrushRadius = tool.BrushRadius or 5,
			BrushTickRate = tool.BrushTickRate or 0.14,
			BrushRewardMultiplier = tool.BrushRewardMultiplier or 0.38,
			MaxGroundTargets = tool.MaxGroundTargets or 6,
		}
	end
	return fallback
end

local ToolData = loadToolData()
local Events = ReplicatedStorage:WaitForChild("Events", 10)
if not Events then
	warn("Brush remote missing, using touch fallback.")
	return
end
local paintSweepEvent = Events:WaitForChild("PaintToolSweep", 10)
if not paintSweepEvent then
	warn("Brush remote missing, using touch fallback.")
	return
end

local sweepGui = ClientUIRoot.GetLayer(playerGui, "PaintToolFeedbackUI")

local activeTool
local localCooldownUntil = 0
local autoCollectUntil = 0
local WALK_AUTO_COLLECT_INTERVAL = 0.16
local WALK_PICKUP_BASE_RANGE = 7.5
local WALK_PICKUP_MAX_TARGETS = 5
local brushEquipped = true
local equippedToolId = "StarterBrush"
local brushVisual
local brushMotor
local brushHeld = false
local lastPointerPosition
local lastGroundVisualAt = 0

local equipState = ReplicatedStorage:FindFirstChild("PaintToolEquippedState")
if not equipState then
	equipState = Instance.new("BoolValue")
	equipState.Name = "PaintToolEquippedState"
	equipState.Value = true
	equipState.Parent = ReplicatedStorage
end
brushEquipped = equipState.Value

local function getClientSetting(key, defaultValue)
	local value = player:GetAttribute("Setting" .. key)
	return type(value) == "boolean" and value or defaultValue
end

local equipChangedEvent = ReplicatedStorage:FindFirstChild("PaintToolEquipChanged")
if not equipChangedEvent then
	equipChangedEvent = Instance.new("BindableEvent")
	equipChangedEvent.Name = "PaintToolEquipChanged"
	equipChangedEvent.Parent = ReplicatedStorage
end

local function getToolConfig(tool)
	if not tool then
		return nil
	end
	return ToolData.get(tool:GetAttribute("PaintToolId"))
end

local function getToolEffectiveStats(toolConfig)
	if ToolData.GetEffectiveStats then
		return ToolData.GetEffectiveStats(toolConfig and toolConfig.Id or "StarterBrush")
	end

	return {
		CollectPowerMultiplier = toolConfig and (toolConfig.CollectPowerMultiplier or toolConfig.PowerMultiplier) or 1,
		SweepWidthMultiplier = toolConfig and toolConfig.SweepWidthMultiplier or 1,
		UseSpeedMultiplier = toolConfig and toolConfig.UseSpeedMultiplier or 1,
		PickupRadiusMultiplier = toolConfig and toolConfig.PickupRadiusMultiplier or 1,
	}
end

local getUpgradeMultiplier

local function hasActiveWildBuff(buffId)
	local folder = player:FindFirstChild("WildBuffs")
	return folder and folder:FindFirstChild(buffId) ~= nil
end

local function getClientRange(toolConfig)
	local range = toolConfig.Range or 9
	local upgrades = player:FindFirstChild("Upgrades")
	local pickupRange = upgrades and upgrades:FindFirstChild("PickupRange")
	if pickupRange then
		range += math.max(0, pickupRange.Value - 8) * 0.35
	end
	local stats = getToolEffectiveStats(toolConfig)
	local buffMultiplier = hasActiveWildBuff("BrushFrenzy") and 1.25 or 1
	return math.min(range * (stats.PickupRadiusMultiplier or 1) * buffMultiplier, toolConfig.MaxServerRange or 24)
end

local function isGroundContamination(part)
	return part
		and part:IsA("BasePart")
		and (
			part:GetAttribute("GroundContamination") == true
			or part:GetAttribute("BreakableType") == "GroundContamination"
		)
end

local function getSurfaceColorAttribute(instance)
	if not instance then
		return nil
	end

	local attrColor = instance:GetAttribute("ColorType")
		or instance:GetAttribute("WorldColor")
		or instance:GetAttribute("AreaColor")
		or instance:GetAttribute("SectorColor")
		or instance:GetAttribute("SpawnColor")
	if type(attrColor) == "string" and ColorData.Colors[attrColor] then
		return attrColor
	end

	return nil
end

local function inferGroundColorFromSurface(part)
	local current = part
	while current and current ~= workspace do
		local attrColor = getSurfaceColorAttribute(current)
		if attrColor then
			return attrColor
		end

		local loweredName = string.lower(current.Name or "")
		for _, world in ipairs(ColorData.Worlds or {}) do
			local color = world.primaryColor
			if color and loweredName:find(string.lower(color), 1, true) then
				return color
			end
		end
		for color in pairs(ColorData.Colors or {}) do
			if loweredName:find(string.lower(color), 1, true) then
				return color
			end
		end

		current = current.Parent
	end

	return nil
end

local function looksLikeBrushableSectorFloor(part)
	local partName = string.lower(part.Name or "")
	local parentName = part.Parent and string.lower(part.Parent.Name or "") or ""
	if
		partName:find("pipe", 1, true)
		or parentName:find("pipe", 1, true)
		or partName == "core"
		or partName == "glowshell"
		or partName == "highlight"
		or partName:find("floatcore", 1, true)
	then
		return false
	end

	local hasSurfaceName = partName:find("floor", 1, true)
		or partName:find("ground", 1, true)
		or partName:find("zone", 1, true)
		or partName:find("area", 1, true)
		or partName:find("sector", 1, true)
		or parentName:find("floor", 1, true)
		or parentName:find("ground", 1, true)
		or parentName:find("zone", 1, true)
		or parentName:find("area", 1, true)
		or parentName:find("sector", 1, true)
		or parentName:find("wasteland", 1, true)
	local largeFlatSurface = (part.Size.X * part.Size.Z) >= 1600
		and part.Size.X >= 35
		and part.Size.Z >= 35
		and part.Size.Y <= math.max(8, math.min(part.Size.X, part.Size.Z) * 0.3)

	return hasSurfaceName ~= nil and largeFlatSurface and inferGroundColorFromSurface(part) ~= nil
end

local function isBrushableGroundSurface(part)
	if not part or not part:IsA("BasePart") then
		return false
	end
	if isGroundContamination(part) then
		return true
	end
	if part:GetAttribute("BreakableType") ~= nil then
		return true
	end
	if part:GetAttribute("NoContamination") == true or part:GetAttribute("NoColorSpawn") == true then
		return false
	end
	return part:GetAttribute("ColorZone") == true
		or part:GetAttribute("PlayableSectorFloor") == true
		or part:GetAttribute("ZoneFloor") == true
		or part:GetAttribute("ContaminationAllowed") == true
		or looksLikeBrushableSectorFloor(part)
end

local function getGroundBrushRadius(toolConfig)
	local stats = getToolEffectiveStats(toolConfig)
	local radius = tonumber(stats.BrushRadius)
		or tonumber(toolConfig.BrushRadius)
		or math.max(4, (toolConfig.Width or 7) * 0.7)
	radius *= getUpgradeMultiplier("BrushSize", 1)
	return math.clamp(radius, 3, 30)
end

local function findNearestGroundContamination(position, radius)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character, brushVisual }

	local nearest = nil
	local nearestDistance = math.huge
	for _, part in ipairs(workspace:GetPartBoundsInRadius(position, math.max(radius, 10), params)) do
		if isGroundContamination(part) and part.Transparency < 1 and not part:GetAttribute("IsCollected") then
			local distance = (part.Position - position).Magnitude
			if distance < nearestDistance then
				nearest = part
				nearestDistance = distance
			end
		end
	end

	return nearest
end

local function getInputPosition(input)
	local position = input and input.Position
	if typeof(position) == "Vector3" then
		return Vector2.new(position.X, position.Y)
	end
	return UserInputService:GetMouseLocation()
end

local function findGroundBrushPayload(toolConfig)
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end

	local pointer = lastPointerPosition or UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(pointer.X, pointer.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character, brushVisual }
	params.IgnoreWater = true

	local result = workspace:Raycast(ray.Origin, ray.Direction * 600, params)
	if not result or not isBrushableGroundSurface(result.Instance) then
		return nil
	end

	local hitPosition = result.Position
	local target = result.Instance
	if not isGroundContamination(target) then
		target = findNearestGroundContamination(hitPosition, getGroundBrushRadius(toolConfig)) or result.Instance
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		local maxRange = tonumber(toolConfig.MaxServerRange) or getClientRange(toolConfig)
		if (root.Position - hitPosition).Magnitude > maxRange + 12 then
			return nil
		end
	end

	return {
		Position = hitPosition,
		Normal = result.Normal,
		Target = target,
	}
end

local function showGroundBrushEffect(payload, toolConfig)
	if type(payload) ~= "table" or typeof(payload.Position) ~= "Vector3" then
		return
	end

	local now = os.clock()
	if now - lastGroundVisualAt < 0.045 then
		return
	end
	lastGroundVisualAt = now

	local radius = getGroundBrushRadius(toolConfig)
	local ring = Instance.new("Part")
	ring.Name = "LocalBrushCleanPulse"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanTouch = false
	ring.CanQuery = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = toolConfig.PaintColor or toolConfig.AccentColor or Color3.fromRGB(91, 230, 235)
	ring.Transparency = 0.62
	ring.Size = Vector3.new(radius * 2, 0.045, radius * 2)
	ring.CFrame = CFrame.new(payload.Position + (payload.Normal or Vector3.yAxis) * 0.1)
	ring.Parent = workspace

	TweenService:Create(ring, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		Size = Vector3.new(radius * 2.35, 0.045, radius * 2.35),
	}):Play()
	Debris:AddItem(ring, 0.28)
end

function getUpgradeMultiplier(name, defaultValue)
	local upgrades = player:FindFirstChild("Upgrades")
	local value = upgrades and upgrades:FindFirstChild(name)
	return value and math.max(tonumber(value.Value) or defaultValue, 0.01) or defaultValue
end

local function playSweepSound()
	-- Keep silent for now; invalid public sound assets create noisy client error reports.
end

local function makeVisualPart(name, size, color, material)
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
	return part
end

local function weldVisual(root, part, cframe)
	part.CFrame = root.CFrame * cframe
	part.Parent = root.Parent

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
end

local function getHand(character)
	return character:FindFirstChild("RightHand")
		or character:FindFirstChild("Right Arm")
		or character:FindFirstChild("RightLowerArm")
end

local setToolPartsHidden

local function isPaintTool(tool)
	return tool and tool:IsA("Tool") and tool:GetAttribute("PaintToolId") ~= nil
end

local function relaxPaintToolArm()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:UnequipTools()
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	if not character or not backpack then
		return
	end

	for _, child in ipairs(character:GetChildren()) do
		if isPaintTool(child) then
			setToolPartsHidden(child, false)
			child.Parent = backpack
		end
	end
	activeTool = nil
end

local function destroyBrushVisual()
	if brushMotor then
		brushMotor:Destroy()
		brushMotor = nil
	end
	if brushVisual then
		brushVisual:Destroy()
		brushVisual = nil
	end
end

function setToolPartsHidden(tool, hidden)
	if not tool then
		return
	end

	for _, child in ipairs(tool:GetDescendants()) do
		if child:IsA("BasePart") then
			child.LocalTransparencyModifier = hidden and 1 or 0
		end
	end
end

local function ensureBrushVisual(character)
	if not brushEquipped then
		destroyBrushVisual()
		return
	end

	if brushVisual and brushVisual.Parent and brushMotor and brushMotor.Parent then
		return
	end

	local hand = getHand(character)
	if not hand then
		return
	end
	local toolConfig = ToolData.get(equippedToolId)

	if brushVisual then
		brushVisual:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = tostring(toolConfig.Id or "StarterBrush") .. "Visual"

	local handle = makeVisualPart(
		"VisualHandle",
		Vector3.new(0.22, 0.22, 0.22),
		toolConfig.HandleColor or Color3.fromRGB(255, 213, 125),
		Enum.Material.SmoothPlastic
	)
	handle.CFrame = hand.CFrame
	handle.Transparency = 1
	handle.Parent = model
	model.PrimaryPart = handle

	local shaftRotation = CFrame.Angles(math.rad(90), 0, 0)
	weldVisual(
		handle,
		makeVisualPart(
			"VisualShaft",
			Vector3.new(0.22, 1.45, 0.22),
			toolConfig.HandleColor or Color3.fromRGB(255, 213, 125),
			Enum.Material.Wood
		),
		CFrame.new(0, 0, -0.72) * shaftRotation
	)
	weldVisual(
		handle,
		makeVisualPart("VisualGrip", Vector3.new(0.34, 0.42, 0.34), Color3.fromRGB(45, 48, 58)),
		CFrame.new(0, 0, -0.16) * shaftRotation
	)
	weldVisual(
		handle,
		makeVisualPart("VisualBand", Vector3.new(0.48, 0.22, 0.48), Color3.fromRGB(190, 220, 238), Enum.Material.Metal),
		CFrame.new(0, 0, -1.28) * shaftRotation
	)
	if toolConfig.VisualType == "Roller" then
		weldVisual(
			handle,
			makeVisualPart(
				"VisualRollerArm",
				Vector3.new(0.25, 0.35, 0.9),
				Color3.fromRGB(190, 220, 238),
				Enum.Material.Metal
			),
			CFrame.new(0, 0, -1.52)
		)
		weldVisual(
			handle,
			makeVisualPart(
				"VisualRoller",
				Vector3.new(1.2, 0.5, 0.5),
				toolConfig.PaintColor or Color3.fromRGB(255, 92, 164),
				Enum.Material.Neon
			),
			CFrame.new(0, -0.28, -1.7)
		)
	else
		weldVisual(
			handle,
			makeVisualPart(
				"VisualHead",
				Vector3.new(0.78, 0.42, 0.34),
				toolConfig.HeadColor or Color3.fromRGB(110, 235, 245)
			),
			CFrame.new(0, 0, -1.52)
		)
		weldVisual(
			handle,
			makeVisualPart(
				"VisualPaint",
				Vector3.new(0.76, 0.16, 0.38),
				toolConfig.PaintColor or Color3.fromRGB(255, 92, 164),
				Enum.Material.Neon
			),
			CFrame.new(0, -0.24, -1.55)
		)
	end

	model.Parent = character

	local motor = Instance.new("Motor6D")
	motor.Name = "StarterBrushVisualGrip"
	motor.Part0 = hand
	motor.Part1 = handle
	motor.C0 = CFrame.new(0.08, -0.08, -0.28) * CFrame.Angles(math.rad(-8), 0, math.rad(8))
	motor.C1 = CFrame.new()
	motor.Parent = hand

	brushVisual = model
	brushMotor = motor
end

local function setBrushEquipped(equipped)
	brushEquipped = equipped == true
	equipState.Value = brushEquipped
	if not brushEquipped then
		brushHeld = false
	end

	local character = player.Character
	if brushEquipped and character then
		ensureBrushVisual(character)
	else
		destroyBrushVisual()
		relaxPaintToolArm()
	end
end

local function showFeedback(text, color)
	if not getClientSetting("Popups", true) and text ~= "STORAGE FULL" then
		return
	end
	if not sweepGui then
		return
	end
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Size = UDim2.new(0, 280, 0, 42)
	label.Position = UDim2.new(0.5, 0, 0.56, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.LuckiestGuy
	label.TextSize = 24
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(35, 38, 45)
	label.Text = text
	label.ZIndex = 100
	label.Parent = sweepGui

	TweenService:Create(label, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = label.Position - UDim2.new(0, 0, 0, 48),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	Debris:AddItem(label, 0.6)
end

local function animateTool(tool)
	if brushMotor and brushMotor.Parent then
		local originalC0 = brushMotor.C0
		local outC0 = originalC0 * CFrame.Angles(math.rad(-28), 0, math.rad(36))
		local backC0 = originalC0 * CFrame.Angles(math.rad(16), 0, math.rad(-22))

		local first =
			TweenService:Create(brushMotor, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				C0 = outC0,
			})
		first:Play()
		first.Completed:Wait()
		local second =
			TweenService:Create(brushMotor, TweenInfo.new(0.13, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				C0 = backC0,
			})
		second:Play()
		second.Completed:Wait()
		if brushMotor and brushMotor.Parent then
			TweenService:Create(brushMotor, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {
				C0 = originalC0,
			}):Play()
		end
		return
	end

	if not tool then
		return
	end

	local originalGrip = tool.Grip
	local outGrip = originalGrip * CFrame.Angles(math.rad(-36), 0, math.rad(22))
	local backGrip = originalGrip * CFrame.Angles(math.rad(18), 0, math.rad(-18))

	local first = TweenService:Create(tool, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Grip = outGrip,
	})
	first:Play()
	first.Completed:Wait()
	local second = TweenService:Create(tool, TweenInfo.new(0.13, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Grip = backGrip,
	})
	second:Play()
	second.Completed:Wait()
	if tool and tool.Parent then
		TweenService:Create(tool, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {
			Grip = originalGrip,
		}):Play()
	end
end

local function showSweepArc(root, range, width)
	local look = root.CFrame.LookVector
	local center = root.Position + look * (range * 0.48) + Vector3.new(0, -2.35, 0)

	local arc = Instance.new("Part")
	arc.Name = "PaintSweepArc"
	arc.Size = Vector3.new(width, 0.12, range)
	arc.CFrame = CFrame.lookAt(center, center + look)
	arc.Color = Color3.fromRGB(120, 245, 255)
	arc.Material = Enum.Material.Neon
	arc.Transparency = 0.68
	arc.Anchored = true
	arc.CanCollide = false
	arc.CanTouch = false
	arc.CanQuery = false
	arc.CastShadow = false
	arc.Parent = workspace

	TweenService:Create(arc, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(width * 1.18, 0.12, range * 1.05),
		Transparency = 1,
	}):Play()
	Debris:AddItem(arc, 0.25)
end

local function findSweepCandidates(root, toolConfig)
	local range = getClientRange(toolConfig)
	local stats = getToolEffectiveStats(toolConfig)
	local width = (toolConfig.Width or 7) * (stats.SweepWidthMultiplier or 1)
	width *= getUpgradeMultiplier("BrushSize", 1)
	local look = root.CFrame.LookVector
	local center = root.Position + look * (range * 0.5)

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }

	local found = {}
	local parts = workspace:GetPartBoundsInRadius(center, range, params)
	for _, part in ipairs(parts) do
		if
			part:IsA("BasePart")
			and (part:GetAttribute("BreakableType") or part:GetAttribute("GemDeposit"))
			and not part:GetAttribute("IsCollected")
			and part.Transparency < 1
			and not isGroundContamination(part)
		then
			local offset = part.Position - root.Position
			local distance = offset.Magnitude
			local forward = distance > 0 and offset.Unit:Dot(look) or 1
			local side = math.abs(offset:Cross(look).Magnitude)
			if distance <= range and forward > -0.15 and side <= width then
				table.insert(found, part)
			end
		end
	end

	table.sort(found, function(a, b)
		return (a.Position - root.Position).Magnitude < (b.Position - root.Position).Magnitude
	end)

	local capped = {}
	for i = 1, math.min(#found, toolConfig.MaxTargets or 8) do
		table.insert(capped, found[i])
	end

	return capped, range, width
end

local function findWalkoverCandidates(root, toolConfig)
	local stats = getToolEffectiveStats(toolConfig)
	local range = math.min(
		WALK_PICKUP_BASE_RANGE + math.max(0, getClientRange(toolConfig) - (toolConfig.Range or 9)) * 0.25,
		9 * (stats.PickupRadiusMultiplier or 1)
	)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }

	local found = {}
	for _, part in ipairs(workspace:GetPartBoundsInRadius(root.Position, range, params)) do
		if
			part:IsA("BasePart")
			and (part:GetAttribute("BreakableType") or part:GetAttribute("GemDeposit"))
			and not part:GetAttribute("IsCollected")
			and part.Transparency < 1
			and not isGroundContamination(part)
		then
			table.insert(found, part)
		end
	end

	table.sort(found, function(a, b)
		return (a.Position - root.Position).Magnitude < (b.Position - root.Position).Magnitude
	end)

	local capped = {}
	for i = 1, math.min(#found, WALK_PICKUP_MAX_TARGETS) do
		table.insert(capped, found[i])
	end

	return capped
end

local function activateBrush(tool, groundPayload)
	if not brushEquipped then
		return
	end

	local toolConfig = ToolData.get(equippedToolId)
	local toolStats = getToolEffectiveStats(toolConfig)

	local now = os.clock()
	if now < localCooldownUntil then
		return
	end
	local useSpeedMultiplier = math.max(tonumber(toolStats.UseSpeedMultiplier) or 1, 0.01)
	useSpeedMultiplier *= getUpgradeMultiplier("PaintSpeed", 1)
	local baseCooldown = groundPayload
			and (tonumber(toolStats.BrushTickRate) or tonumber(toolConfig.BrushTickRate) or 0.14)
		or (toolConfig.Cooldown or 0.45)
	localCooldownUntil = now + (baseCooldown / useSpeedMultiplier)

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	ensureBrushVisual(character)

	local candidates, range, width = findSweepCandidates(root, toolConfig)
	showSweepArc(root, range, width)
	if groundPayload then
		showGroundBrushEffect(groundPayload, toolConfig)
	end
	playSweepSound()
	task.spawn(animateTool, tool)
	paintSweepEvent:FireServer(toolConfig.Id, candidates, "sweep", groundPayload)
end

local function autoCollectBrush()
	if not brushEquipped then
		return
	end

	local toolConfig = ToolData.get(equippedToolId)
	local now = os.clock()
	if now < autoCollectUntil then
		return
	end
	autoCollectUntil = now + WALK_AUTO_COLLECT_INTERVAL

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end

	ensureBrushVisual(character)
	local candidates = findWalkoverCandidates(root, toolConfig)
	if #candidates > 0 then
		paintSweepEvent:FireServer(toolConfig.Id, candidates, "walk")
	end
end

local function watchTool(tool)
	if not tool:IsA("Tool") or not tool:GetAttribute("PaintToolId") or tool:GetAttribute("PaintToolWatched") then
		return
	end
	tool:SetAttribute("PaintToolWatched", true)
	if not brushEquipped and tool.Parent == player.Character then
		task.defer(relaxPaintToolArm)
	end

	tool.Equipped:Connect(function()
		if not brushEquipped then
			task.defer(relaxPaintToolArm)
			return
		end
		activeTool = tool
		setToolPartsHidden(tool, true)
		if brushEquipped and player.Character then
			ensureBrushVisual(player.Character)
		end
	end)
	tool.Unequipped:Connect(function()
		setToolPartsHidden(tool, false)
		if activeTool == tool then
			activeTool = nil
		end
		if brushEquipped and player.Character then
			ensureBrushVisual(player.Character)
		end
	end)
	tool.Activated:Connect(function()
		local toolConfig = ToolData.get(equippedToolId)
		activateBrush(tool, findGroundBrushPayload(toolConfig))
	end)
end

local function scan(container)
	if not container then
		return
	end
	for _, child in ipairs(container:GetChildren()) do
		watchTool(child)
	end
	container.ChildAdded:Connect(watchTool)
end

local function setupCharacter(character)
	task.wait(0.25)
	if brushEquipped then
		ensureBrushVisual(character)
	else
		relaxPaintToolArm()
	end
	scan(character)
end

scan(player:WaitForChild("Backpack"))
player.CharacterAdded:Connect(function(character)
	brushVisual = nil
	brushMotor = nil
	setupCharacter(character)
end)
if player.Character then
	setupCharacter(player.Character)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		if brushEquipped then
			brushHeld = true
			lastPointerPosition = getInputPosition(input)
			local toolConfig = ToolData.get(equippedToolId)
			activateBrush(activeTool, findGroundBrushPayload(toolConfig))
		end
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		lastPointerPosition = getInputPosition(input)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		brushHeld = false
	end
end)

equipChangedEvent.Event:Connect(setBrushEquipped)
equipState:GetPropertyChangedSignal("Value"):Connect(function()
	if equipState.Value ~= brushEquipped then
		setBrushEquipped(equipState.Value)
	end
end)

local function watchEquippedToolValue(value)
	equippedToolId = value and value.Value ~= "" and value.Value or "StarterBrush"
	destroyBrushVisual()
	if brushEquipped and player.Character then
		ensureBrushVisual(player.Character)
	end
	if value then
		value:GetPropertyChangedSignal("Value"):Connect(function()
			equippedToolId = value.Value ~= "" and value.Value or "StarterBrush"
			destroyBrushVisual()
			if brushEquipped and player.Character then
				ensureBrushVisual(player.Character)
			end
		end)
	end
end

local toolsFolder = player:WaitForChild("PaintTools", 10)
if toolsFolder then
	watchEquippedToolValue(toolsFolder:WaitForChild("Equipped", 10))
end

task.spawn(function()
	while true do
		task.wait(0.04)
		if brushHeld and brushEquipped then
			local toolConfig = ToolData.get(equippedToolId)
			local groundPayload = findGroundBrushPayload(toolConfig)
			if groundPayload then
				activateBrush(activeTool, groundPayload)
			end
		end
	end
end)

paintSweepEvent.OnClientEvent:Connect(function(result)
	if type(result) ~= "table" then
		return
	end
	if result.success then
		showFeedback("+" .. tostring(result.total or 0) .. " COINS", Color3.fromRGB(255, 220, 90))
	end
end)
