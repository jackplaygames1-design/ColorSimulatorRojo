-- Server-authoritative quick travel for small HUD shortcuts.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ColorData = require(ReplicatedStorage:WaitForChild("ColorData"))
local PetData = require(ReplicatedStorage:WaitForChild("PetData"))
local GameBalance = require(ReplicatedStorage:WaitForChild("GameBalance"))

local Events = ReplicatedStorage:WaitForChild("Events")
local travelEvent = Events:FindFirstChild("TravelToWorldSpot")
if not travelEvent then
	travelEvent = Instance.new("RemoteEvent")
	travelEvent.Name = "TravelToWorldSpot"
	travelEvent.Parent = Events
end
local dataDirtyEvent = Events:FindFirstChild("PlayerDataDirty")

local cooldowns = {}
local COOLDOWN = 2
local MAP_NAME = "ColorSimulatorMap"
local SPAWN_TUTORIAL_EGG_NAME = "SpawnEgg"
local RUNTIME_WORLD_BUILDING_ENABLED = GameBalance.FeatureFlags and GameBalance.FeatureFlags.RuntimeWorldBuildingEnabled == true
local RUNTIME_WORLD_LABELS_ENABLED = GameBalance.FeatureFlags and GameBalance.FeatureFlags.RuntimeWorldLabelsEnabled == true
local PROGRESSION_CONFIG = GameBalance.Progression or {}
local MAX_PLAYABLE_SECTOR_INDEX = tonumber(PROGRESSION_CONFIG.MaxPlayableSectorIndex) or math.huge
local zonePartsCache = nil
local destinationCache = {}

local function isSectorPlayable(colorType)
	local index = ColorData.getWorldIndex(colorType)
	return index ~= nil and index <= MAX_PLAYABLE_SECTOR_INDEX
end

local COLORS = {
	dark = Color3.fromRGB(35, 38, 45),
	cyan = Color3.fromRGB(118, 238, 244),
	yellow = Color3.fromRGB(255, 224, 104),
	pink = Color3.fromRGB(255, 130, 188),
	green = Color3.fromRGB(116, 232, 158),
	purple = Color3.fromRGB(192, 154, 255),
}

local function getRoot(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function getUnlockedValue(player)
	local storage = player:FindFirstChild("ColorStorage")
	return storage and storage:FindFirstChild("UnlockedColors")
end

local function isUnlocked(player, colorType)
	local unlocked = getUnlockedValue(player)
	return isSectorPlayable(colorType) and ColorData.isColorUnlocked(unlocked and unlocked.Value or "Red", colorType)
end

local function setCurrentWorld(player, colorType, reason)
	local world = ColorData.getWorldByColor(colorType)
	if not world or not isUnlocked(player, world.primaryColor) then
		return false
	end

	player:SetAttribute("ActiveWorldColor", world.primaryColor)
	local storage = player:FindFirstChild("ColorStorage")
	local currentWorld = storage and storage:FindFirstChild("CurrentWorld")
	if currentWorld and currentWorld:IsA("StringValue") and currentWorld.Value ~= world.primaryColor then
		currentWorld.Value = world.primaryColor
	end
	if dataDirtyEvent and dataDirtyEvent:IsA("BindableEvent") then
		dataDirtyEvent:Fire(player, reason or "current-world")
	end
	return true
end

local function getStoredCurrentWorldColor(player)
	local storage = player:FindFirstChild("ColorStorage")
	local currentWorld = storage and storage:FindFirstChild("CurrentWorld")
	local colorType = currentWorld and currentWorld.Value or player:GetAttribute("ActiveWorldColor")
	local world = ColorData.getWorldByColor(colorType)
	if world and isUnlocked(player, world.primaryColor) then
		return world.primaryColor
	end
	return nil
end

local function isPointInside(part, worldPosition, margin)
	local localPoint = part.CFrame:PointToObjectSpace(worldPosition)
	local half = part.Size * 0.5 + Vector3.new(margin, margin, margin)
	return math.abs(localPoint.X) <= half.X
		and math.abs(localPoint.Y) <= half.Y
		and math.abs(localPoint.Z) <= half.Z
end

local function getZoneParts()
	if zonePartsCache then
		local valid = true
		for _, zone in ipairs(zonePartsCache) do
			if not zone.Parent then
				valid = false
				break
			end
		end
		if valid then
			return zonePartsCache
		end
	end

	local zones = {}
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("BasePart") and obj:GetAttribute("ColorZone") and obj:GetAttribute("ColorType") then
			table.insert(zones, obj)
		end
	end
	zonePartsCache = zones
	return zones
end

local function getMap()
	local map = workspace:FindFirstChild(MAP_NAME)
	if not map and RUNTIME_WORLD_BUILDING_ENABLED then
		map = Instance.new("Folder")
		map.Name = MAP_NAME
		map.Parent = workspace
	end
	return map
end

local function getExistingMap()
	return workspace:FindFirstChild(MAP_NAME)
end

local function shouldUseBakedMap()
	local mapConfig = GameBalance.Map or {}
	return mapConfig.UseBakedMap ~= false
end

local function isBakedEditableMap(map)
	return map
		and (map:GetAttribute("BakedEditableMap") == true or map:FindFirstChild("Lobby") or map:FindFirstChild("RedZone"))
end

local function shouldAvoidRuntimeStationCreation()
	return shouldUseBakedMap() and isBakedEditableMap(getExistingMap())
end

local function createPart(parent, name, size, cframe, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function addShopBillboard(parent)
	if not RUNTIME_WORLD_LABELS_ENABLED then
		return
	end

	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("BillboardGui") and (child.Name == "BrushShopLabel" or child.Name == "UpgradeStationLabel") then
			child:Destroy()
		end
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "BrushShopLabel"
	billboard:SetAttribute("ProximityWorldLabel", true)
	billboard:SetAttribute("ShowDistance", 42)
	billboard:SetAttribute("HideDistance", 52)
	billboard.Size = UDim2.new(0, 220, 0, 42)
	billboard.StudsOffset = Vector3.new(0, 7.2, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 80
	billboard.Enabled = false
	billboard.Parent = parent

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 1, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.LuckiestGuy
	title.TextSize = 18
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextStrokeTransparency = 0
	title.TextStrokeColor3 = COLORS.dark
	title.Text = "BRUSH SHOP"
	title.Parent = billboard
end

local function addShopPrompt(part)
	local oldUpgradePrompt = part:FindFirstChild("UpgradeStationPrompt")
	if oldUpgradePrompt then
		oldUpgradePrompt:Destroy()
	end

	local prompt = part:FindFirstChild("BrushShopPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "BrushShopPrompt"
		prompt.ActionText = "Open"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 15
		prompt.RequiresLineOfSight = false
		prompt.Parent = part
	end
	prompt.ObjectText = "Brush Shop"
	prompt:SetAttribute("BrushShopPrompt", true)
	prompt:SetAttribute("CombinedShopPrompt", true)
end

local function addUpgradeBillboard(parent)
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("BillboardGui") and child.Name == "UpgradeStationLabel" then
			child:Destroy()
		end
	end
	return
end

local function addUpgradePrompt(part)
	local prompt = part:FindFirstChild("UpgradeStationPrompt")
	if prompt then
		prompt:Destroy()
	end
	return
end

local function addDisabledUpgradeBillboard(parent)
	if not RUNTIME_WORLD_LABELS_ENABLED then
		return
	end

	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("BillboardGui") and child.Name == "UpgradeStationLabel" then
			child:Destroy()
		end
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "UpgradeStationLabel"
	billboard:SetAttribute("ProximityWorldLabel", true)
	billboard:SetAttribute("ShowDistance", 42)
	billboard:SetAttribute("HideDistance", 52)
	billboard.Size = UDim2.new(0, 190, 0, 48)
	billboard.StudsOffset = Vector3.new(0, 7.2, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 80
	billboard.Enabled = false
	billboard.Parent = parent

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 1, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.LuckiestGuy
	title.TextSize = 20
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextStrokeTransparency = 0
	title.TextStrokeColor3 = COLORS.dark
	title.Text = "UPGRADE"
	title.Parent = billboard
end

local function addDisabledUpgradePrompt(part)
	local prompt = part:FindFirstChild("UpgradeStationPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "UpgradeStationPrompt"
		prompt.Parent = part
	end
	prompt.ActionText = "Open"
	prompt.ObjectText = "Upgrade Station"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 15
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("UpgradeStationPrompt", true)
end

local function addEggBillboard(parent, world, eggData)
	if not RUNTIME_WORLD_LABELS_ENABLED then
		return
	end

	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("BillboardGui") and child.Name == "WorldEggLabel" then
			child:Destroy()
		end
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "WorldEggLabel"
	billboard:SetAttribute("ProximityWorldLabel", true)
	billboard:SetAttribute("ShowDistance", 48)
	billboard:SetAttribute("HideDistance", 58)
	billboard.Size = UDim2.new(0, 220, 0, 68)
	billboard.StudsOffset = Vector3.new(0, 9.8, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 120
	billboard.Enabled = false
	billboard.Parent = parent

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 42)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.LuckiestGuy
	title.TextSize = 24
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextStrokeTransparency = 0
	title.TextStrokeColor3 = COLORS.dark
	title.Text = eggData and string.upper(eggData.displayName or "EGG") or "EGG"
	title.Parent = billboard

	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.new(1, 0, 0, 24)
	sub.Position = UDim2.new(0, 0, 0, 40)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.GothamBold
	sub.TextSize = 14
	sub.TextColor3 = COLORS.yellow
	sub.TextStrokeTransparency = 0.1
	sub.TextStrokeColor3 = COLORS.dark
	sub.Text = world and world.name or "Sector Egg"
	sub.Parent = billboard
end

local function addEggPrompt(part)
	local prompt = part:FindFirstChild("EggShopPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "EggShopPrompt"
		prompt.Parent = part
	end
	part:SetAttribute("EggStation", true)
	part.CanCollide = true
	part.CanTouch = false
	part.CanQuery = true
	prompt.ActionText = "Open"
	prompt.ObjectText = "Egg"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("EggShopPrompt", true)
end

local function configureSpawnTutorialEgg(obj)
	if not obj or not obj:IsA("BasePart") or obj.Name ~= SPAWN_TUTORIAL_EGG_NAME then
		return nil
	end

	obj:SetAttribute("EggId", "ColorEgg")
	obj:SetAttribute("ColorType", "Red")
	obj:SetAttribute("AreaColor", "Red")
	obj:SetAttribute("EggStation", true)
	obj:SetAttribute("TutorialEgg", true)
	obj:SetAttribute("BakedTutorialEgg", true)
	obj.CanQuery = true
	addEggPrompt(obj)
	destinationCache["egg:Red"] = obj
	return obj
end

local function findSpawnTutorialEgg()
	local direct = workspace:FindFirstChild(SPAWN_TUTORIAL_EGG_NAME, true)
	local configured = configureSpawnTutorialEgg(direct)
	if configured then
		return configured
	end
	for _, obj in ipairs(workspace:GetDescendants()) do
		configured = configureSpawnTutorialEgg(obj)
		if configured then
			return configured
		end
	end
	return nil
end

local function findZonePart(colorType)
	local fallback
	for _, zone in ipairs(getZoneParts()) do
		fallback = fallback or zone
		if zone:GetAttribute("ColorType") == colorType then
			return zone
		end
	end
	return colorType == "Red" and fallback or nil
end

local function getCurrentWorldColor(player)
	local root = getRoot(player)
	local storedColor = getStoredCurrentWorldColor(player)
	if not root then
		return storedColor or "Red"
	end

	local fallbackColor = storedColor or "Red"
	local nearestDist = math.huge
	for _, zone in ipairs(getZoneParts()) do
		local colorType = zone:GetAttribute("ColorType")
		if colorType and isUnlocked(player, colorType) then
			if isPointInside(zone, root.Position, 8) then
				setCurrentWorld(player, colorType, "current-world")
				return colorType
			end

			local dist = (root.Position - zone.Position).Magnitude
			if dist < nearestDist then
				nearestDist = dist
				fallbackColor = colorType
			end
		end
	end

	if storedColor then
		return storedColor
	end

	return fallbackColor
end

local function getEggIdForColor(colorType)
	for eggId, egg in pairs(PetData.Eggs) do
		if egg.areaColor == colorType then
			return eggId
		end
	end
	return nil
end

local function getBestPartForEggObject(obj)
	if obj:IsA("BasePart") then
		return obj
	end
	if obj:IsA("Model") then
		return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function isDebugAppearanceObject(obj)
	return obj:FindFirstAncestor("PetAppearanceStudio") ~= nil
end

local function configureEggObject(obj, colorType, eggId)
	if isDebugAppearanceObject(obj) then
		return nil
	end
	local part = getBestPartForEggObject(obj)
	if not part then
		return nil
	end

	local function configurePart(basePart)
		basePart:SetAttribute("EggId", eggId)
		basePart:SetAttribute("ColorType", colorType)
		basePart:SetAttribute("AreaColor", colorType)
		basePart:SetAttribute("EggStation", true)
		basePart:SetAttribute("ColorZone", false)
		basePart.CanCollide = true
		basePart.CanTouch = false
		basePart.CanQuery = true
	end

	if obj:IsA("BasePart") then
		configurePart(obj)
	else
		obj:SetAttribute("EggId", eggId)
		obj:SetAttribute("ColorType", colorType)
		obj:SetAttribute("AreaColor", colorType)
		for _, descendant in ipairs(obj:GetDescendants()) do
			if descendant:IsA("BasePart") then
				configurePart(descendant)
			end
		end
	end

	addEggPrompt(part)
	addEggBillboard(part, ColorData.getWorldByColor(colorType), PetData.Eggs[eggId])
	return part
end

local function findEggPart(colorType)
	local cacheKey = "egg:" .. tostring(colorType)
	local cached = destinationCache[cacheKey]
	if cached and cached.Parent then
		return cached
	end

	local eggId = getEggIdForColor(colorType)
	if colorType == "Red" then
		local spawnEgg = findSpawnTutorialEgg()
		if spawnEgg then
			return spawnEgg
		end
	end

	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj.Name == tostring(colorType) .. "Egg" and not isDebugAppearanceObject(obj) then
			local configured = configureEggObject(obj, colorType, eggId)
			if configured then
				destinationCache[cacheKey] = configured
				return configured
			end
		end
	end

	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("BasePart") and obj:GetAttribute("EggId") and not isDebugAppearanceObject(obj) then
			local eggColor = obj:GetAttribute("ColorType") or obj:GetAttribute("AreaColor")
			if eggColor == colorType or obj:GetAttribute("EggId") == eggId then
				obj:SetAttribute("ColorType", colorType)
				obj:SetAttribute("AreaColor", colorType)
				addEggPrompt(obj)
				addEggBillboard(obj, ColorData.getWorldByColor(colorType), PetData.Eggs[eggId or obj:GetAttribute("EggId")])
				destinationCache[cacheKey] = obj
				return obj
			end
		end
	end
	if not eggId then
		return nil
	end

	local zone = findZonePart(colorType)
	if not zone then
		return nil
	end
	if not RUNTIME_WORLD_BUILDING_ENABLED then
		return nil
	end

	local map = getMap()
	if not map then
		return nil
	end
	local eggsFolder = map:FindFirstChild("Eggs")
	if not eggsFolder then
		eggsFolder = Instance.new("Folder")
		eggsFolder.Name = "Eggs"
		eggsFolder.Parent = map
	end

	local world = ColorData.getWorldByColor(colorType)
	local eggData = PetData.Eggs[eggId]
	local accent = eggData and eggData.color or (ColorData.Colors[colorType] and ColorData.Colors[colorType].color) or COLORS.pink
	local basePos = zone.Position + Vector3.new(math.min(zone.Size.X * 0.24, 78), zone.Size.Y * 0.5 + 7.2, math.max(zone.Size.Z * 0.24, 72))
	local egg = createPart(eggsFolder, tostring(colorType) .. "Egg", Vector3.new(12, 15, 12), CFrame.new(basePos), accent, Enum.Material.SmoothPlastic)
	egg.Shape = Enum.PartType.Ball
	egg:SetAttribute("EggId", eggId)
	egg:SetAttribute("ColorType", colorType)
	egg:SetAttribute("AreaColor", colorType)
	addEggPrompt(egg)
	addEggBillboard(egg, world, eggData)

	local pedestal = createPart(eggsFolder, tostring(colorType) .. "EggPedestal", Vector3.new(28, 2.4, 28), CFrame.new(basePos - Vector3.new(0, 7, 0)), COLORS.dark, Enum.Material.SmoothPlastic)
	pedestal:SetAttribute("EggStationDecor", true)
	pedestal:SetAttribute("ColorType", colorType)

	local glow = createPart(eggsFolder, tostring(colorType) .. "EggGlow", Vector3.new(23, 0.35, 23), CFrame.new(basePos - Vector3.new(0, 5.65, 0)), accent, Enum.Material.Neon)
	glow.Transparency = 0.18
	glow.CanCollide = false
	glow:SetAttribute("EggStationDecor", true)
	glow:SetAttribute("ColorType", colorType)

	print("Created Egg Station for " .. tostring(colorType))
	destinationCache[cacheKey] = egg
	return egg
end

local function findSellPart(colorType)
	local cacheKey = "sell:" .. tostring(colorType)
	local cached = destinationCache[cacheKey]
	if cached and cached.Parent then
		local cachedColor = cached:GetAttribute("ColorType")
			or cached:GetAttribute("AreaColor")
			or cached:GetAttribute("SellColor")
		if cachedColor == colorType then
			return cached
		end
		destinationCache[cacheKey] = nil
	end

	local worldIndex = ColorData.getWorldIndex(colorType)
	for _, name in ipairs({
		colorType .. "SellZone",
		colorType .. "SellStation",
		colorType .. "SellPad",
		colorType .. "_Sell",
		worldIndex and ("World" .. tostring(worldIndex) .. "Sell") or nil,
	}) do
		local named = name and workspace:FindFirstChild(name, true)
		if named and named:IsA("BasePart") then
			named:SetAttribute("SellZone", true)
			named:SetAttribute("SellLocation", true)
			named:SetAttribute("ColorType", colorType)
			named:SetAttribute("AreaColor", colorType)
			destinationCache[cacheKey] = named
			return named
		end
	end

	if worldIndex then
		local named = workspace:FindFirstChild("World" .. tostring(worldIndex) .. "_Sell", true)
		if named and named:IsA("BasePart") then
			named:SetAttribute("SellZone", true)
			named:SetAttribute("SellLocation", true)
			named:SetAttribute("ColorType", colorType)
			named:SetAttribute("AreaColor", colorType)
			destinationCache[cacheKey] = named
			return named
		end
	end

	cached = destinationCache[cacheKey]
	if cached and cached.Parent then
		return cached
	end

	local fallback = nil
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("BasePart")
			and (obj:GetAttribute("SellZone")
				or obj:GetAttribute("SellLocation")
				or obj.Name == "SellZone"
				or obj.Name == "Sell"
				or obj.Name == "SellPad"
				or obj.Name == colorType .. "SellPad"
				or obj.Name == colorType .. "SellStation"
				or obj.Name == "SellPart"
				or string.match(obj.Name, "^World%d+_Sell$")
				or string.match(obj.Name, "^World%d+Sell$")
				or string.match(obj.Name, "SellStation$"))
		then
			fallback = fallback or obj
			local sellColor = obj:GetAttribute("ColorType") or obj:GetAttribute("AreaColor") or obj:GetAttribute("SellColor")
			if sellColor == colorType then
				destinationCache[cacheKey] = obj
				return obj
			end
		end
	end
	if colorType == "Red" and fallback then
		return fallback
	end

	local zone = findZonePart(colorType)
	if not zone then
		return nil
	end
	if not RUNTIME_WORLD_BUILDING_ENABLED then
		return nil
	end

	local map = getMap()
	if not map then
		return nil
	end
	local stationsFolder = map:FindFirstChild("SellStations")
	if not stationsFolder then
		stationsFolder = Instance.new("Folder")
		stationsFolder.Name = "SellStations"
		stationsFolder.Parent = map
	end

	local worldIndex = ColorData.getWorldIndex(colorType) or 1
	local accent = ColorData.Colors[colorType] and ColorData.Colors[colorType].color or COLORS.green
	local basePos = zone.Position + Vector3.new(-math.max(34, zone.Size.X * 0.22), zone.Size.Y * 0.5 + 0.8, math.max(32, zone.Size.Z * 0.24))
	local sell = createPart(stationsFolder, "World" .. tostring(worldIndex) .. "_Sell", Vector3.new(42, 1.2, 30), CFrame.new(basePos), accent:Lerp(COLORS.green, 0.45), Enum.Material.Neon)
	sell.Transparency = 0.08
	sell.CanCollide = false
	sell.CanTouch = true
	sell:SetAttribute("SellZone", true)
	sell:SetAttribute("SellLocation", true)
	sell:SetAttribute("ColorType", colorType)
	sell:SetAttribute("AreaColor", colorType)
	sell:SetAttribute("SellColor", colorType)

	print("Created Sell Station for " .. tostring(colorType))
	destinationCache[cacheKey] = sell
	return sell
end

local function findShopPart(colorType)
	local cacheKey = "shop:" .. tostring(colorType)
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("BasePart")
			and obj:GetAttribute("BrushNpc") == true
			and obj:GetAttribute("BrushShop") == true
			and (obj:GetAttribute("ColorType") or obj:GetAttribute("ShopColor")) == colorType
		then
			addShopPrompt(obj)
			destinationCache[cacheKey] = obj
			return obj
		end
	end

	local cached = destinationCache[cacheKey]
	if cached and cached.Parent then
		return cached
	end

	local map = getExistingMap()
	local shopsFolder = map and map:FindFirstChild("BrushShops")
	if shopsFolder then
		for _, obj in ipairs(shopsFolder:GetChildren()) do
			if obj:IsA("BasePart") and obj:GetAttribute("BrushShop") and obj:GetAttribute("ColorType") == colorType then
				addShopBillboard(obj)
				addShopPrompt(obj)
				destinationCache[cacheKey] = obj
				return obj
			end
		end
	end

	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("BasePart")
			and (obj:GetAttribute("BrushShop")
				or obj:GetAttribute("CombinedShop")
				or obj:GetAttribute("ShopStation")
				or obj.Name == "BrushShop"
				or obj.Name == "EquipmentShop"
				or obj.Name == "Shop"
				or obj.Name == "CombinedShop"
				or obj.Name == "ShopAndUpgrades"
				or obj.Name == "UnlockTraits"
				or obj.Name == colorType .. "Shop"
				or obj.Name == colorType .. "BrushShop"
				or obj.Name == colorType .. "CombinedShop"
				or string.match(obj.Name, "^World%d+_Shop$"))
		then
			local shopColor = obj:GetAttribute("ColorType") or obj:GetAttribute("AreaColor")
			local worldIndex = ColorData.getWorldIndex(colorType)
			if not shopColor and worldIndex and obj.Name == "World" .. tostring(worldIndex) .. "_Shop" then
				shopColor = colorType
			end
			if not shopColor and obj.Name == "UnlockTraits" and colorType == "Orange" then
				shopColor = colorType
			end
			if shopColor == colorType then
				obj:SetAttribute("BrushShop", true)
				obj:SetAttribute("CombinedShop", true)
				obj:SetAttribute("ShopStation", true)
				obj:SetAttribute("ColorType", colorType)
				obj:SetAttribute("AreaColor", colorType)
				addShopBillboard(obj)
				addShopPrompt(obj)
				destinationCache[cacheKey] = obj
				return obj
			end
		end
	end

	local zone = findZonePart(colorType)
	if not zone then
		return nil
	end
	if not RUNTIME_WORLD_BUILDING_ENABLED then
		return nil
	end

	map = getMap()
	if not map then
		return nil
	end
	shopsFolder = map:FindFirstChild("BrushShops")
	if not shopsFolder then
		shopsFolder = Instance.new("Folder")
		shopsFolder.Name = "BrushShops"
		shopsFolder.Parent = map
	end

	local colorInfo = ColorData.Colors[colorType]
	local accent = colorInfo and colorInfo.color or COLORS.yellow
	local basePos = zone.Position + Vector3.new(math.max(-zone.Size.X * 0.28, -90), zone.Size.Y * 0.5 + 0.8, -zone.Size.Z * 0.28)
	local pad = createPart(shopsFolder, colorType .. "BrushShop", Vector3.new(28, 1.6, 20), CFrame.new(basePos), accent:Lerp(Color3.new(1, 1, 1), 0.25), Enum.Material.Neon)
	pad:SetAttribute("BrushShop", true)
	pad:SetAttribute("CombinedShop", true)
	pad:SetAttribute("ShopStation", true)
	pad:SetAttribute("ColorType", colorType)
	pad.CanCollide = false
	addShopBillboard(pad)
	addShopPrompt(pad)

	local back = createPart(shopsFolder, colorType .. "BrushShopSign", Vector3.new(24, 9, 1.2), CFrame.new(basePos + Vector3.new(0, 5, 8.8)), COLORS.dark)
	back:SetAttribute("BrushShopDecor", true)
	back:SetAttribute("ColorType", colorType)

	local counter = createPart(shopsFolder, colorType .. "BrushShopCounter", Vector3.new(20, 4, 3), CFrame.new(basePos + Vector3.new(0, 2.3, 5.6)), COLORS.yellow)
	counter:SetAttribute("BrushShopDecor", true)
	counter:SetAttribute("ColorType", colorType)

	print("Created Brush Shop for " .. tostring(colorType))
	destinationCache[cacheKey] = pad
	return pad
end

local function findUpgradePart(colorType)
	local combinedShop = findShopPart(colorType)
	if combinedShop then
		return combinedShop
	end

	local cacheKey = "upgrade:" .. tostring(colorType)
	local cached = destinationCache[cacheKey]
	if cached and cached.Parent then
		return cached
	end

	local map = getExistingMap()
	local stationsFolder = map and map:FindFirstChild("UpgradeStations")
	if stationsFolder then
		for _, obj in ipairs(stationsFolder:GetChildren()) do
			if obj:IsA("BasePart") and obj:GetAttribute("UpgradeStation") and obj:GetAttribute("ColorType") == colorType then
				addUpgradeBillboard(obj)
				addUpgradePrompt(obj)
				destinationCache[cacheKey] = obj
				return obj
			end
		end
	end

	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("BasePart")
			and (obj:GetAttribute("UpgradeStation")
				or obj.Name == "UpgradeStation"
				or obj.Name == "UpgradePad"
				or obj.Name == "Upgrade"
				or obj.Name == colorType .. "UpgradeStation"
				or string.match(obj.Name, "^World%d+_Upgrade$"))
		then
			local upgradeColor = obj:GetAttribute("ColorType") or obj:GetAttribute("AreaColor")
			local worldIndex = ColorData.getWorldIndex(colorType)
			if not upgradeColor and worldIndex and obj.Name == "World" .. tostring(worldIndex) .. "_Upgrade" then
				upgradeColor = colorType
			end
			if upgradeColor == colorType then
				obj:SetAttribute("UpgradeStation", true)
				obj:SetAttribute("ColorType", colorType)
				obj:SetAttribute("AreaColor", colorType)
				addUpgradeBillboard(obj)
				addUpgradePrompt(obj)
				destinationCache[cacheKey] = obj
				return obj
			end
		end
	end

	local zone = findZonePart(colorType)
	if not zone then
		return nil
	end
	if not RUNTIME_WORLD_BUILDING_ENABLED then
		return nil
	end

	map = getMap()
	if not map then
		return nil
	end
	stationsFolder = map:FindFirstChild("UpgradeStations")
	if not stationsFolder then
		stationsFolder = Instance.new("Folder")
		stationsFolder.Name = "UpgradeStations"
		stationsFolder.Parent = map
	end

	local colorInfo = ColorData.Colors[colorType]
	local accent = colorInfo and colorInfo.color or COLORS.purple
	local basePos = zone.Position + Vector3.new(math.min(zone.Size.X * 0.24, 80), zone.Size.Y * 0.5 + 0.8, -zone.Size.Z * 0.08)
	local pad = createPart(stationsFolder, colorType .. "UpgradeStation", Vector3.new(30, 1.4, 22), CFrame.new(basePos), accent:Lerp(COLORS.purple, 0.35), Enum.Material.SmoothPlastic)
	pad:SetAttribute("UpgradeStation", true)
	pad:SetAttribute("ColorType", colorType)
	pad.CanCollide = false
	addUpgradeBillboard(pad)
	addUpgradePrompt(pad)

	print("Created Upgrade Station for " .. tostring(colorType))
	destinationCache[cacheKey] = pad
	return pad
end

local function teleportNear(player, target, extraDistance)
	local root = getRoot(player)
	if not root or not target then
		return false
	end

	local distance = extraDistance or math.max(target.Size.Z * 0.5 + 7, 12)
	local destination = target.CFrame * CFrame.new(0, 4, -distance)
	root.CFrame = CFrame.lookAt(destination.Position, target.Position)
	return true
end

local function useCooldown(player)
	local now = os.clock()
	if cooldowns[player] and now - cooldowns[player] < COOLDOWN then
		return false
	end
	cooldowns[player] = now
	return true
end

travelEvent.OnServerEvent:Connect(function(player, destinationType)
	local startedAt = os.clock()
	if destinationType ~= "sell" and destinationType ~= "egg" and destinationType ~= "shop" and destinationType ~= "upgrade" then
		travelEvent:FireClient(player, false, destinationType, "Sector travel failed. Try again.")
		return
	end
	if destinationType == "sell" then
		travelEvent:FireClient(player, false, destinationType, "Selling is disabled. Break Color to earn Coins instantly.")
		return
	end
	if not useCooldown(player) then
		return
	end

	local worldColor = getCurrentWorldColor(player)
	if not isUnlocked(player, worldColor) then
		worldColor = "Red"
	end

	local world = ColorData.getWorldByColor(worldColor)
	local target
	if destinationType == "sell" then
		target = findSellPart(worldColor)
	elseif destinationType == "egg" then
		target = findEggPart(worldColor)
	elseif destinationType == "shop" then
		target = findShopPart(worldColor)
	else
		target = findUpgradePart(worldColor)
	end
	if not target then
		local message = ({
			sell = "No sell zone found.",
			egg = "No egg found for this Sector.",
			shop = "No brush shop found.",
			upgrade = "No upgrade station found.",
		})[destinationType] or "No destination found."
		warn("Quick travel failed for " .. player.Name .. ": " .. message)
		travelEvent:FireClient(player, false, destinationType, message)
		return
	end

	if teleportNear(player, target) then
		setCurrentWorld(player, worldColor, "current-world")
		local label = ({
			sell = "Sell Zone",
			egg = (world and world.name or worldColor) .. " Egg",
			shop = "Brush Shop",
			upgrade = "Brush Shop",
		})[destinationType] or "Destination"
		print(player.Name .. " quick traveled to " .. label .. " in " .. tostring(worldColor))
		travelEvent:FireClient(player, true, destinationType, "Traveling to " .. label)
		local elapsed = os.clock() - startedAt
		print("SectorTravel: " .. player.Name .. " -> " .. tostring(destinationType) .. " in " .. string.format("%.2f", elapsed) .. "s")
		print("Quick travel completed: " .. tostring(destinationType) .. " in " .. string.format("%.3f", elapsed) .. "s")
		if elapsed > 0.5 then
			warn("SectorTravel slow: " .. tostring(destinationType) .. " took " .. string.format("%.2f", elapsed) .. "s")
		end
	else
		travelEvent:FireClient(player, false, destinationType, "Sector travel failed. Try again.")
	end
end)

Players.PlayerRemoving:Connect(function(player)
	cooldowns[player] = nil
end)

workspace.DescendantAdded:Connect(function(obj)
	if configureSpawnTutorialEgg(obj) then
		print("WorldTravel: hooked baked tutorial SpawnEgg as ColorEgg.")
	end
end)

local function ensureAllWorldStations()
	for _, world in ipairs(ColorData.Worlds or {}) do
		findEggPart(world.primaryColor)
		findShopPart(world.primaryColor)
		findUpgradePart(world.primaryColor)
	end
end

task.defer(ensureAllWorldStations)
task.delay(3, ensureAllWorldStations)
task.delay(8, ensureAllWorldStations)
