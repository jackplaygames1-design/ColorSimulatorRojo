-- Marks flat shop-adjacent color pieces as living decor while keeping them walkable.
local Workspace = game:GetService("Workspace")

local MAX_DECOR_AREA = 900
local MAX_DECOR_DIMENSION = 44
local MIN_DECOR_DIMENSION = 1.5
local SHOP_PROXIMITY = 130
local SHOP_RESCAN_DELAY = 1.5

local shopAnchors = {}
local rescanQueued = false

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
			name == "colorblobs"
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

local function shouldMarkAsLivingDecor(part)
	if not part:IsA("BasePart") or isDisabled(part) or hasExcludedAttribute(part) or hasExcludedAncestor(part) then
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

local function configurePart(part)
	if not shouldMarkAsLivingDecor(part) then
		return
	end

	part.Anchored = true
	part.CanCollide = true
	part.CanQuery = true
	part:SetAttribute("LivingColorDecor", true)
end

local function configureAll()
	rebuildShopAnchors()
	for _, object in ipairs(Workspace:GetDescendants()) do
		if object:IsA("BasePart") then
			configurePart(object)
		end
	end
end

local function queueRescan()
	if rescanQueued then
		return
	end

	rescanQueued = true
	task.delay(SHOP_RESCAN_DELAY, function()
		rescanQueued = false
		configureAll()
	end)
end

configureAll()

Workspace.DescendantAdded:Connect(function(object)
	task.defer(function()
		if isShopAnchor(object) then
			queueRescan()
			return
		end

		if object:IsA("BasePart") then
			configurePart(object)
		end
	end)
end)
