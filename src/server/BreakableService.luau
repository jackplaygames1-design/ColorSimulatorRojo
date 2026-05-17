local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BreakableDefinitions = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("BreakableDefinitions"))
local GameBalance = require(ReplicatedStorage:WaitForChild("GameBalance"))
local RewardDropService = require(script.Parent:WaitForChild("RewardDropService"))

local Events = ReplicatedStorage:WaitForChild("Events")
local announcementEvent = Events:WaitForChild("BreakableAnnouncement")

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

local function findBreakableTemplate(assetName)
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
			findBreakableTemplate(definition.AssetName)
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
	local template = findBreakableTemplate(definition.AssetName)
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
