local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BreakableDefinitions = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("BreakableDefinitions"))
local GameBalance = require(ReplicatedStorage:WaitForChild("GameBalance"))
local RankService = require(script.Parent:WaitForChild("RankService"))
local RewardDropService = require(script.Parent:WaitForChild("RewardDropService"))

local Events = ReplicatedStorage:WaitForChild("Events")
local announcementEvent = Events:WaitForChild("BreakableAnnouncement")
local tutorialBreakableProgressEvent = Events:WaitForChild("TutorialBreakableProgress")

local BreakableService = {}
BreakableService.BreakableBroken = Instance.new("BindableEvent")

local activeBreakables = {}
local started = false
local nextBreakableId = 0
local missingAssetWarnings = {}
local missingHealthBarWarnings = {}

local COLOR_PALETTES = {
	Red = {
		Primary = Color3.fromRGB(235, 35, 32),
		Announcement = Color3.fromRGB(255, 65, 75),
	},
	Orange = {
		Primary = Color3.fromRGB(255, 132, 28),
		Announcement = Color3.fromRGB(255, 156, 48),
	},
	Green = {
		Primary = Color3.fromRGB(70, 220, 90),
		Announcement = Color3.fromRGB(90, 255, 120),
	},
}

local function getPalette(colorType)
	return COLOR_PALETTES[tostring(colorType or "Red")] or COLOR_PALETTES.Red
end

local function configurePart(part)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = true
	part.CastShadow = false
end

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if folder and folder:IsA("Folder") then
		return folder
	end
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function createHealthBar(primary, displayName, color)
	local billboard = primary:FindFirstChild("HealthBar")
	if billboard and billboard:IsA("BillboardGui") then
		return billboard
	end
	if billboard then
		billboard:Destroy()
	end

	billboard = Instance.new("BillboardGui")
	billboard.Name = "HealthBar"
	billboard.AlwaysOnTop = true
	billboard.Enabled = false
	billboard.MaxDistance = 115
	billboard.Size = UDim2.fromOffset(150, 48)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, primary.Size.Y * 0.5 + 2.4, 0)
	billboard.Parent = primary

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = billboard

	local title = Instance.new("TextLabel")
	title.Name = "NameLabel"
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.Text = displayName
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextScaled = true
	title.TextStrokeTransparency = 0.35
	title.Size = UDim2.new(1, 0, 0, 19)
	title.Parent = root

	local back = Instance.new("Frame")
	back.Name = "BarBack"
	back.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
	back.BorderSizePixel = 0
	back.Position = UDim2.new(0.08, 0, 0, 22)
	back.Size = UDim2.new(0.84, 0, 0, 10)
	back.Parent = root

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = back

	local numbers = Instance.new("TextLabel")
	numbers.Name = "HealthText"
	numbers.BackgroundTransparency = 1
	numbers.Font = Enum.Font.GothamBold
	numbers.Text = "0 / 0"
	numbers.TextColor3 = Color3.fromRGB(235, 240, 255)
	numbers.TextScaled = true
	numbers.TextStrokeTransparency = 0.5
	numbers.Position = UDim2.new(0, 0, 0, 34)
	numbers.Size = UDim2.new(1, 0, 0, 13)
	numbers.Parent = root

	return billboard
end

local function makePart(name, size, color, material, cframe, shape)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.CFrame = cframe or CFrame.new()
	part.Shape = shape or Enum.PartType.Block
	configurePart(part)
	part:SetAttribute("BreakableVisualPart", true)
	return part
end

local function createFallbackTemplate(typeId, definition)
	local red = COLOR_PALETTES.Red.Primary
	local model = Instance.new("Model")
	model.Name = definition.AssetName
	model:SetAttribute("RuntimeFallbackBreakableAsset", true)

	local primary
	if typeId == "ColorSpill" then
		primary =
			makePart("Puddle", Vector3.new(5, 0.32, 4), red, Enum.Material.SmoothPlastic, nil, Enum.PartType.Cylinder)
	elseif typeId == "ColorClump" then
		primary = makePart("Blob", Vector3.new(4, 3.2, 4), red, Enum.Material.SmoothPlastic, nil, Enum.PartType.Ball)
	elseif typeId == "ColorCrate" then
		primary = makePart("CrateBody", Vector3.new(5, 4.5, 5), red, Enum.Material.SmoothPlastic)
	elseif typeId == "ColorChest" then
		primary = makePart("ChestBody", Vector3.new(7, 4, 5), red, Enum.Material.SmoothPlastic)
		makePart("ChestLid", Vector3.new(7.4, 1.3, 5.4), red, Enum.Material.SmoothPlastic, CFrame.new(0, 2.4, 0)).Parent =
			model
	elseif typeId == "HugeColorChest" then
		primary = makePart("ChestBody", Vector3.new(12.6, 7.2, 9), red, Enum.Material.SmoothPlastic)
		makePart("ChestLid", Vector3.new(13.3, 2.3, 9.7), red, Enum.Material.SmoothPlastic, CFrame.new(0, 4.3, 0)).Parent =
			model
	else
		primary = makePart("CoreBase", Vector3.new(10, 2, 10), red, Enum.Material.SmoothPlastic)
		makePart("CoreOrb", Vector3.new(8, 8, 8), red, Enum.Material.Neon, CFrame.new(0, 5, 0), Enum.PartType.Ball).Parent =
			model
	end

	primary.Parent = model
	model.PrimaryPart = primary
	createHealthBar(primary, definition.DisplayName or typeId, red)
	return model
end

local function ensureFallbackAssetsFolder()
	local assets = ensureFolder(ReplicatedStorage, "Assets")
	return ensureFolder(assets, "Breakables")
end

local function ensureFallbackTemplate(typeId, definition)
	local folder = ensureFallbackAssetsFolder()
	local existing = folder:FindFirstChild(definition.AssetName)
	if existing and existing:IsA("Model") then
		return existing
	end
	if existing then
		existing:Destroy()
	end

	warn(("[BreakableSpawner] Missing asset %s, creating fallback asset."):format(tostring(definition.AssetName)))
	local template = createFallbackTemplate(typeId, definition)
	template.Parent = folder
	return template
end

local function getLibraryFolders()
	local folders = {}
	local workspaceLibrary = Workspace:FindFirstChild("BreakableAssetLibrary")
	local workspaceBreakables = workspaceLibrary and workspaceLibrary:FindFirstChild("Breakables")
	if workspaceBreakables then
		table.insert(folders, workspaceBreakables)
	end

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local replicatedBreakables = assets and assets:FindFirstChild("Breakables")
	if replicatedBreakables then
		table.insert(folders, replicatedBreakables)
	end

	return folders
end

local function findBreakableTemplate(assetName, typeId)
	for _, folder in ipairs(getLibraryFolders()) do
		local template = folder:FindFirstChild(assetName)
		if template and template:IsA("Model") then
			return template
		end
	end

	if not missingAssetWarnings[assetName] then
		missingAssetWarnings[assetName] = true
		warn(
			("BreakableService missing editable asset '%s'. Add it under Workspace.BreakableAssetLibrary.Breakables."):format(
				tostring(assetName)
			)
		)
	end
	local definition = BreakableDefinitions.Get(typeId or assetName)
	if definition then
		return ensureFallbackTemplate(typeId or assetName, definition)
	end
	return nil
end

local function getPreferredPrimaryPart(model)
	local primary = model.PrimaryPart
	if primary and primary:IsA("BasePart") then
		return primary
	end

	for _, name in ipairs({ "Root", "Puddle", "Blob", "CrateBody", "ChestBody", "CoreBase" }) do
		local candidate = model:FindFirstChild(name, true)
		if candidate and candidate:IsA("BasePart") then
			return candidate
		end
	end

	return model:FindFirstChildWhichIsA("BasePart", true)
end

function BreakableService.ValidateAssetLibrary()
	for _, typeId in ipairs(BreakableDefinitions.Order) do
		local definition = BreakableDefinitions.Get(typeId)
		if definition then
			findBreakableTemplate(definition.AssetName, typeId)
		end
	end
end

local function configureHealthBar(model, primary, definition)
	local palette = getPalette(model:GetAttribute("ColorType"))
	local billboard = primary and primary:FindFirstChild("HealthBar")
	if not billboard or not billboard:IsA("BillboardGui") then
		local assetName = definition and definition.AssetName or model.Name
		if not missingHealthBarWarnings[assetName] then
			missingHealthBarWarnings[assetName] = true
			warn(
				("Breakable asset '%s' is missing editable HealthBar BillboardGui on its primary part."):format(
					assetName
				)
			)
		end
		createHealthBar(primary, definition and definition.DisplayName or model.Name, palette.Primary)
		return
	end

	billboard.Enabled = false
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 115
	billboard.StudsOffsetWorldSpace = Vector3.new(0, primary.Size.Y * 0.5 + 2.4, 0)

	local root = billboard:FindFirstChild("Root")
	local title = root and root:FindFirstChild("NameLabel")
	if title and title:IsA("TextLabel") then
		title.Text = definition.DisplayName or model.Name
	end

	local back = root and root:FindFirstChild("BarBack")
	local fill = back and back:FindFirstChild("Fill")
	if fill and fill:IsA("Frame") then
		fill.BackgroundColor3 = palette.Primary
	end
end

local function tintBreakable(model, colorType)
	local palette = getPalette(colorType)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			if descendant.Name == "CoreOrb" then
				descendant.Color = palette.Primary
				descendant.Material = Enum.Material.Neon
			else
				descendant.Color = palette.Primary
			end
		end
	end
end

local function tagBreakableParts(model)
	local breakableId = model:GetAttribute("BreakableId")
	local breakableType = model:GetAttribute("BreakableType")
	local zoneId = model:GetAttribute("ZoneId")
	local worldZoneId = model:GetAttribute("WorldZoneId")
	local locationId = model:GetAttribute("LocationId")
	local colorType = model:GetAttribute("ColorType")

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant:SetAttribute("BreakableId", breakableId)
			descendant:SetAttribute("BreakableType", breakableType)
			descendant:SetAttribute("BreakableModelPart", true)
			descendant:SetAttribute("ZoneId", zoneId)
			descendant:SetAttribute("WorldZoneId", worldZoneId)
			descendant:SetAttribute("LocationId", locationId)
			descendant:SetAttribute("ColorType", colorType)
		end
	end
end

function BreakableService.UpdateHealthBar(model)
	local primary = model and model.PrimaryPart
	local billboard = primary and primary:FindFirstChild("HealthBar")
	local root = billboard and billboard:FindFirstChild("Root")
	if not root then
		return
	end
	local maxHealth = math.max(tonumber(model:GetAttribute("MaxHealth")) or 1, 1)
	local currentHealth = math.clamp(tonumber(model:GetAttribute("CurrentHealth")) or maxHealth, 0, maxHealth)
	local pct = currentHealth / maxHealth
	local back = root:FindFirstChild("BarBack")
	local fill = back and back:FindFirstChild("Fill")
	if fill and fill:IsA("Frame") then
		fill.Size = UDim2.fromScale(pct, 1)
	end
	local text = root:FindFirstChild("HealthText")
	if text and text:IsA("TextLabel") then
		text.Text = tostring(math.ceil(currentHealth)) .. " / " .. tostring(math.ceil(maxHealth))
	end
end

function BreakableService.SpawnBreakable(typeId, zoneId, cframe, parent, colorType, zoneDefinition)
	local definition = BreakableDefinitions.Get(typeId)
	if not definition then
		return nil
	end
	local template = findBreakableTemplate(definition.AssetName, typeId)
	if not template then
		return nil
	end

	nextBreakableId += 1
	local model = template:Clone()
	local maxHealth = math.max(
		1,
		math.floor(
			(tonumber(definition.MaxHealth) or 1) * (tonumber(zoneDefinition and zoneDefinition.HealthMultiplier) or 1)
		)
	)
	local rewardMultiplier = math.max(tonumber(zoneDefinition and zoneDefinition.RewardMultiplier) or 1, 0)
	model.Name = definition.AssetName .. "_" .. tostring(nextBreakableId)
	model:SetAttribute("BreakableId", "breakable_" .. tostring(nextBreakableId))
	model:SetAttribute("BreakableType", typeId)
	model:SetAttribute("ZoneId", zoneId)
	model:SetAttribute("WorldZoneId", zoneDefinition and zoneDefinition.WorldZoneId)
	model:SetAttribute("LocationId", zoneDefinition and zoneDefinition.LocationId)
	model:SetAttribute("ColorType", colorType or "Red")
	model:SetAttribute("MaxHealth", maxHealth)
	model:SetAttribute("CurrentHealth", maxHealth)
	model:SetAttribute("RewardTable", definition.RewardTable)
	model:SetAttribute("RewardMultiplier", rewardMultiplier)
	model:SetAttribute("Alive", true)
	model:SetAttribute("IsBreakable", true)
	model.Parent = parent
	local primary = getPreferredPrimaryPart(model)
	if not primary then
		warn(("Breakable asset '%s' has no BasePart to use as PrimaryPart."):format(definition.AssetName))
		model:Destroy()
		return nil
	end
	model.PrimaryPart = primary
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			configurePart(descendant)
		end
	end
	tintBreakable(model, colorType)
	tagBreakableParts(model)
	model:PivotTo(cframe)
	configureHealthBar(model, model.PrimaryPart, definition)
	BreakableService.UpdateHealthBar(model)
	activeBreakables[model] = definition

	if definition.AnnounceOnSpawn == true then
		local displayColor = tostring(colorType or "Red")
		local palette = getPalette(displayColor)
		announcementEvent:FireAllClients({
			Text = "[GLOBAL] A Giant " .. displayColor .. " Color Core has appeared in " .. tostring(
				zoneDefinition and zoneDefinition.DisplayName or (displayColor .. " Sector")
			) .. "!",
			Color = palette.Announcement,
		})
	end

	return model
end

function BreakableService.GetActiveBreakables()
	return activeBreakables
end

function BreakableService.GetBreakablesInRange(position, range, zoneId)
	local results = {}
	for model in pairs(activeBreakables) do
		if model.Parent and model.PrimaryPart and model:GetAttribute("Alive") == true then
			if not zoneId or model:GetAttribute("ZoneId") == zoneId then
				local distance = (model.PrimaryPart.Position - position).Magnitude
				if distance <= range then
					table.insert(results, {
						Model = model,
						Distance = distance,
					})
				end
			end
		end
	end
	table.sort(results, function(a, b)
		return a.Distance < b.Distance
	end)
	return results
end

function BreakableService.DamageBreakable(player, model, damage)
	local definition = activeBreakables[model]
	if not definition or not model or not model.Parent or model:GetAttribute("Alive") ~= true then
		return false
	end

	damage = math.max(tonumber(damage) or 0, 0)
	if damage <= 0 then
		return false
	end

	local currentHealth = math.max(tonumber(model:GetAttribute("CurrentHealth")) or definition.MaxHealth, 0)
	currentHealth = math.max(0, currentHealth - damage)
	model:SetAttribute("CurrentHealth", currentHealth)
	BreakableService.UpdateHealthBar(model)

	local primary = model.PrimaryPart
	if primary then
		local palette = getPalette(model:GetAttribute("ColorType"))
		local maxHealth = math.max(tonumber(model:GetAttribute("MaxHealth")) or definition.MaxHealth, 1)
		primary.Color = palette.Primary:Lerp(Color3.new(1, 1, 1), math.clamp(1 - currentHealth / maxHealth, 0, 0.25))
	end

	if currentHealth > 0 then
		return true, false
	end

	model:SetAttribute("Alive", false)
	activeBreakables[model] = nil
	if player then
		RankService.RecordBreakableBroken(player, definition.AssetName)
		tutorialBreakableProgressEvent:FireClient(player, {
			BreakableType = definition.AssetName,
			DisplayName = definition.DisplayName,
		})
		RewardDropService.RollAndGrant(
			player,
			definition,
			model:GetPivot().Position,
			model:GetAttribute("ColorType") or "Red",
			tonumber(model:GetAttribute("RewardMultiplier")) or 1
		)
	end
	if definition.AssetName == "GiantColorCoreChest" and player then
		local colorType = tostring(model:GetAttribute("ColorType") or "Red")
		local palette = getPalette(colorType)
		announcementEvent:FireAllClients({
			Text = "[GLOBAL] " .. player.Name .. " broke the Giant " .. colorType .. " Color Core!",
			Color = palette.Announcement,
		})
	end
	BreakableService.BreakableBroken:Fire(model, definition, model:GetAttribute("ZoneId"))
	task.defer(function()
		if model and model.Parent then
			model:Destroy()
		end
	end)
	return true, true
end

function BreakableService.Start()
	if started then
		return
	end
	started = true
	BreakableService.ValidateAssetLibrary()
	if GameBalance.Breakables and GameBalance.Breakables.Debug and GameBalance.Breakables.Debug.PrintBoot then
		print("BreakableService ready")
	end
end

return BreakableService
