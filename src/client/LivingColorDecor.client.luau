-- Gives walkable color-decor spots a subtle client-only wobble.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local VISUAL_FOLDER_NAME = "LivingColorDecorVisuals"
local MAX_DECOR_AREA = 900
local MAX_DECOR_DIMENSION = 44
local MIN_DECOR_DIMENSION = 1.5
local SHOP_PROXIMITY = 130

local visualFolder = Workspace:FindFirstChild(VISUAL_FOLDER_NAME)
if not visualFolder then
	visualFolder = Instance.new("Folder")
	visualFolder.Name = VISUAL_FOLDER_NAME
	visualFolder.Parent = Workspace
end
visualFolder:SetAttribute("LivingColorDecorVisuals", true)

local records = {}
local shopAnchors = {}

local function compactName(name)
	return string.lower(string.gsub(name or "", "%s+", ""))
end

local function colorSaturation(color)
	local maxChannel = math.max(color.R, color.G, color.B)
	local minChannel = math.min(color.R, color.G, color.B)
	if maxChannel <= 0 then
		return 0
	end
	return (maxChannel - minChannel) / maxChannel
end

local function isDisabled(part)
	return part:GetAttribute("DisableLivingColorDecor") == true
end

local function isForcedLivingDecor(part)
	return part:GetAttribute("LivingColorDecor") == true
		or part:GetAttribute("ColorSpotDecor") == true
		or part:GetAttribute("AliveColorSpot") == true
end

local function hasExcludedAttribute(part)
	return part:GetAttribute("AreaGate") == true
		or part:GetAttribute("ColorZone") == true
		or part:GetAttribute("PlayableSectorFloor") == true
		or part:GetAttribute("ZoneFloor") == true
		or part:GetAttribute("GateDecor") == true
		or part:GetAttribute("GateInteraction") == true
		or part:GetAttribute("ColorBlobSpawn") == true
		or part:GetAttribute("GroundContamination") == true
		or part:GetAttribute("ContaminationCell") == true
		or part:GetAttribute("BreakableType") ~= nil
		or part:GetAttribute("GroundContaminationCell") == true
		or part:GetAttribute("SectorInteriorEntrance") == true
		or part:GetAttribute("SectorInteriorExit") == true
		or part:GetAttribute("IndexStation") == true
end

local function hasExcludedAncestor(part)
	local current = part.Parent
	while current and current ~= Workspace do
		local name = compactName(current.Name)
		if
			current == visualFolder
			or name == "colorblobs"
			or name == "colorblobspawns"
			or name == "wildcolors"
			or name == "petmodels"
			or name == "livingcolordecorvisuals"
		then
			return true
		end
		current = current.Parent
	end
	return false
end

local function isShopAnchor(object)
	if not object then
		return false
	end

	local name = compactName(object.Name)
	return object:GetAttribute("BrushShop") == true
		or object:GetAttribute("BrushShopDecor") == true
		or object:GetAttribute("CombinedShop") == true
		or object:GetAttribute("ShopStation") == true
		or object:GetAttribute("ShopEntrance") == true
		or object:GetAttribute("ShopDecor") == true
		or name:find("shop", 1, true) ~= nil
		or name:find("zork", 1, true) ~= nil
end

local function hasShopAncestor(part)
	local current = part
	while current and current ~= Workspace do
		if isShopAnchor(current) then
			return true
		end
		current = current.Parent
	end
	return false
end

local function getPartPosition(object)
	if object:IsA("BasePart") then
		return object.Position
	end
	if object:IsA("Model") then
		local primaryPart = object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart", true)
		return primaryPart and primaryPart.Position or nil
	end
	return nil
end

local function rebuildShopAnchors()
	table.clear(shopAnchors)
	for _, object in ipairs(Workspace:GetDescendants()) do
		if isShopAnchor(object) then
			local position = getPartPosition(object)
			if position then
				table.insert(shopAnchors, position)
			end
		end
	end
end

local function isNearShopAnchor(part)
	local partPosition = part.Position
	for _, position in ipairs(shopAnchors) do
		local flatDelta = Vector3.new(partPosition.X - position.X, 0, partPosition.Z - position.Z)
		if flatDelta.Magnitude <= SHOP_PROXIMITY and math.abs(partPosition.Y - position.Y) <= 35 then
			return true
		end
	end
	return false
end

local function isFlatColorDecorShape(part)
	local size = part.Size
	local area = size.X * size.Z
	local maxDimension = math.max(size.X, size.Z)
	local minDimension = math.min(size.X, size.Z)

	return size.Y <= math.max(0.75, minDimension * 0.28)
		and area >= 4
		and area <= MAX_DECOR_AREA
		and maxDimension <= MAX_DECOR_DIMENSION
		and minDimension >= MIN_DECOR_DIMENSION
		and colorSaturation(part.Color) >= 0.3
		and part.Transparency < 0.85
end

local function shouldAnimate(part)
	if
		not part:IsA("BasePart")
		or records[part]
		or isDisabled(part)
		or hasExcludedAttribute(part)
		or hasExcludedAncestor(part)
	then
		return false
	end
	if isForcedLivingDecor(part) then
		return true
	end
	if not isFlatColorDecorShape(part) then
		return false
	end
	return hasShopAncestor(part) or isNearShopAnchor(part)
end

local function cleanVisualClone(visual)
	for _, descendant in ipairs(visual:GetDescendants()) do
		if
			descendant:IsA("Script")
			or descendant:IsA("LocalScript")
			or descendant:IsA("ModuleScript")
			or descendant:IsA("ProximityPrompt")
			or descendant:IsA("ClickDetector")
			or descendant:IsA("Attachment")
			or descendant:IsA("Constraint")
			or descendant:IsA("BillboardGui")
			or descendant:IsA("SurfaceGui")
		then
			descendant:Destroy()
		end
	end
end

local function readNumberAttribute(part, attributeName, fallback)
	local value = part:GetAttribute(attributeName)
	if typeof(value) == "number" then
		return value
	end
	return fallback
end

local function updateRecordFromPart(record)
	local part = record.part
	record.baseCFrame = part.CFrame
	record.baseSize = part.Size
	record.baseColor = part.Color
	record.baseTransparency = part.Transparency
	record.speed = readNumberAttribute(part, "LivingColorSpeed", 1.9)
	record.stretchAmount = readNumberAttribute(part, "LivingColorStretch", 0.025)
	record.bobAmount = readNumberAttribute(part, "LivingColorBob", 0.035)
	record.tiltDegrees = readNumberAttribute(part, "LivingColorTiltDegrees", 0.55)
	record.colorPulse = readNumberAttribute(part, "LivingColorPulse", 0.055)
	record.visual.Material = part.Material
	record.visual.Transparency = math.clamp(record.baseTransparency, 0, 0.82)
end

local function disconnectRecord(record)
	for _, connection in ipairs(record.connections) do
		connection:Disconnect()
	end
end

local function removeRecord(part)
	local record = records[part]
	if not record then
		return
	end

	records[part] = nil
	disconnectRecord(record)
	if part.Parent then
		part.LocalTransparencyModifier = record.originalLocalTransparencyModifier
	end
	record.visual:Destroy()
end

local function bindPart(part)
	if not shouldAnimate(part) then
		return
	end

	part.Anchored = true
	part.CanCollide = true

	local visual = part:Clone()
	visual.Name = part.Name .. "_LivingVisual"
	cleanVisualClone(visual)
	visual.Anchored = true
	visual.CanCollide = false
	visual.CanTouch = false
	visual.CanQuery = false
	visual.CastShadow = false
	visual.Parent = visualFolder

	local phase = math.noise(part.Position.X * 0.13, part.Position.Z * 0.13, part.Position.Y * 0.03) * math.pi * 2
	local record = {
		part = part,
		visual = visual,
		phase = phase,
		originalLocalTransparencyModifier = part.LocalTransparencyModifier,
		connections = {},
	}
	records[part] = record

	local function refresh()
		if part.Parent then
			updateRecordFromPart(record)
		end
	end

	table.insert(record.connections, part:GetPropertyChangedSignal("CFrame"):Connect(refresh))
	table.insert(record.connections, part:GetPropertyChangedSignal("Size"):Connect(refresh))
	table.insert(record.connections, part:GetPropertyChangedSignal("Color"):Connect(refresh))
	table.insert(record.connections, part:GetPropertyChangedSignal("Material"):Connect(refresh))
	table.insert(record.connections, part:GetPropertyChangedSignal("Transparency"):Connect(refresh))
	table.insert(record.connections, part:GetAttributeChangedSignal("LivingColorSpeed"):Connect(refresh))
	table.insert(record.connections, part:GetAttributeChangedSignal("LivingColorStretch"):Connect(refresh))
	table.insert(record.connections, part:GetAttributeChangedSignal("LivingColorBob"):Connect(refresh))
	table.insert(record.connections, part:GetAttributeChangedSignal("LivingColorTiltDegrees"):Connect(refresh))
	table.insert(record.connections, part:GetAttributeChangedSignal("LivingColorPulse"):Connect(refresh))
	table.insert(
		record.connections,
		part:GetAttributeChangedSignal("DisableLivingColorDecor"):Connect(function()
			if isDisabled(part) then
				removeRecord(part)
			end
		end)
	)

	updateRecordFromPart(record)
	part.LocalTransparencyModifier = 1
end

local function bindAll()
	rebuildShopAnchors()
	for _, object in ipairs(Workspace:GetDescendants()) do
		if object:IsA("BasePart") then
			bindPart(object)
		end
	end
end

bindAll()

Workspace.DescendantAdded:Connect(function(object)
	task.defer(function()
		if isShopAnchor(object) then
			rebuildShopAnchors()
		end
		if object:IsA("BasePart") then
			bindPart(object)
		end
	end)
end)

RunService.RenderStepped:Connect(function()
	local now = os.clock()

	for part, record in pairs(records) do
		if not part.Parent or not record.visual.Parent then
			removeRecord(part)
		else
			local speed = record.speed
			local phase = record.phase
			local stretchA = 1 + math.sin(now * speed + phase) * record.stretchAmount
			local stretchB = 1 + math.cos(now * speed * 0.83 + phase) * record.stretchAmount
			local bob = math.sin(now * speed * 1.35 + phase) * record.bobAmount
			local tilt = math.sin(now * speed * 0.72 + phase) * math.rad(record.tiltDegrees)
			local tint = math.max(0, math.sin(now * speed * 1.1 + phase)) * record.colorPulse

			record.visual.Size =
				Vector3.new(record.baseSize.X * stretchA, record.baseSize.Y, record.baseSize.Z * stretchB)
			record.visual.CFrame = record.baseCFrame * CFrame.new(0, 0.018 + bob, 0) * CFrame.Angles(0, tilt, 0)
			record.visual.Color = record.baseColor:Lerp(Color3.new(1, 1, 1), tint)
			part.LocalTransparencyModifier = 1
		end
	end
end)
