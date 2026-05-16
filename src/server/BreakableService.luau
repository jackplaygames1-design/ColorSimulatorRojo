local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

local RED = Color3.fromRGB(235, 35, 32)
local DARK = Color3.fromRGB(18, 8, 10)
local COLOR_PALETTES = {
	Red = {
		Primary = Color3.fromRGB(235, 35, 32),
		Dark = Color3.fromRGB(18, 8, 10),
		Announcement = Color3.fromRGB(255, 65, 75),
	},
	Orange = {
		Primary = Color3.fromRGB(255, 132, 28),
		Dark = Color3.fromRGB(42, 18, 8),
		Announcement = Color3.fromRGB(255, 156, 48),
	},
	Green = {
		Primary = Color3.fromRGB(70, 220, 90),
		Dark = Color3.fromRGB(7, 30, 14),
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
	part.CastShadow = true
end

local function makePart(name, size, color, material, cframe)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.CFrame = cframe or CFrame.new()
	configurePart(part)
	return part
end

local function ensureAssetsFolder()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then
		assets = Instance.new("Folder")
		assets.Name = "Assets"
		assets.Parent = ReplicatedStorage
	end
	local breakables = assets:FindFirstChild("Breakables")
	if not breakables then
		breakables = Instance.new("Folder")
		breakables.Name = "Breakables"
		breakables.Parent = assets
	end
	return breakables
end

local function setPrimary(model, part)
	part.Parent = model
	model.PrimaryPart = part
	return part
end

local function createTemplate(typeId)
	local model = Instance.new("Model")
	model.Name = typeId
	model:SetAttribute("TemporaryBreakableAsset", true)

	if typeId == "ColorSpill" then
		local puddle = setPrimary(model, makePart("Puddle", Vector3.new(5, 0.28, 4), RED, Enum.Material.SmoothPlastic))
		puddle.Shape = Enum.PartType.Cylinder
	elseif typeId == "ColorClump" then
		local blob = setPrimary(model, makePart("Blob", Vector3.new(4, 3.2, 4), RED, Enum.Material.SmoothPlastic))
		blob.Shape = Enum.PartType.Ball
		local base =
			makePart("DarkBase", Vector3.new(4.6, 0.35, 4.6), DARK, Enum.Material.SmoothPlastic, CFrame.new(0, -1.6, 0))
		base.Parent = model
	elseif typeId == "ColorCrate" then
		setPrimary(model, makePart("CrateBody", Vector3.new(5, 4.5, 5), RED, Enum.Material.SmoothPlastic))
		for _, offset in ipairs({ -2.6, 2.6 }) do
			local band = makePart(
				"DarkBand",
				Vector3.new(5.4, 0.35, 0.35),
				DARK,
				Enum.Material.SmoothPlastic,
				CFrame.new(0, offset * 0.3, -2.75)
			)
			band.Parent = model
		end
	elseif typeId == "ColorChest" or typeId == "HugeColorChest" then
		local scale = typeId == "HugeColorChest" and 1.8 or 1
		setPrimary(model, makePart("ChestBody", Vector3.new(7, 4, 5) * scale, RED, Enum.Material.SmoothPlastic))
		local lid = makePart(
			"ChestLid",
			Vector3.new(7.4, 1.3, 5.4) * scale,
			RED:Lerp(Color3.new(1, 1, 1), 0.08),
			Enum.Material.SmoothPlastic,
			CFrame.new(0, 2.4 * scale, 0)
		)
		lid.Parent = model
		local latch = makePart(
			"DarkLatch",
			Vector3.new(1.2, 1.2, 0.35) * scale,
			DARK,
			Enum.Material.SmoothPlastic,
			CFrame.new(0, 0.2 * scale, -2.68 * scale)
		)
		latch.Parent = model
	else
		local base = setPrimary(model, makePart("CoreBase", Vector3.new(10, 2, 10), DARK, Enum.Material.SmoothPlastic))
		local orb = makePart("CoreOrb", Vector3.new(8, 8, 8), RED, Enum.Material.Neon, CFrame.new(0, 5, 0))
		orb.Parent = model
		base:SetAttribute("CoreVisualPart", true)
	end

	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part:SetAttribute("BreakableVisualPart", true)
		end
	end
	return model
end

function BreakableService.EnsureTemplates()
	local folder = ensureAssetsFolder()
	for _, typeId in ipairs(BreakableDefinitions.Order) do
		if not folder:FindFirstChild(typeId) then
			createTemplate(typeId).Parent = folder
		end
	end
end

local function makeHealthBar(model, primary, definition)
	local palette = getPalette(model:GetAttribute("ColorType"))
	local billboard = Instance.new("BillboardGui")
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
	title.Text = definition.DisplayName or model.Name
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
	local backCorner = Instance.new("UICorner")
	backCorner.CornerRadius = UDim.new(1, 0)
	backCorner.Parent = back

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = palette.Primary
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = back
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	local numbers = Instance.new("TextLabel")
	numbers.Name = "HealthText"
	numbers.BackgroundTransparency = 1
	numbers.Font = Enum.Font.GothamBold
	numbers.TextColor3 = Color3.fromRGB(235, 240, 255)
	numbers.TextScaled = true
	numbers.TextStrokeTransparency = 0.5
	numbers.Position = UDim2.new(0, 0, 0, 34)
	numbers.Size = UDim2.new(1, 0, 0, 13)
	numbers.Parent = root
end

local function tintBreakable(model, colorType)
	local palette = getPalette(colorType)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant:GetAttribute("BreakableVisualPart") == true then
			if descendant:GetAttribute("CoreVisualPart") == true or descendant.Name == "CoreOrb" then
				descendant.Color = palette.Primary
				descendant.Material = Enum.Material.Neon
			elseif
				string.find(string.lower(descendant.Name), "dark", 1, true)
				or string.find(string.lower(descendant.Name), "base", 1, true)
				or string.find(string.lower(descendant.Name), "latch", 1, true)
				or string.find(string.lower(descendant.Name), "band", 1, true)
			then
				descendant.Color = palette.Dark
			else
				descendant.Color = palette.Primary
			end
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
	BreakableService.EnsureTemplates()
	local template = ensureAssetsFolder():FindFirstChild(definition.AssetName)
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
	tintBreakable(model, colorType)
	model:PivotTo(cframe)
	makeHealthBar(model, model.PrimaryPart, definition)
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
	BreakableService.EnsureTemplates()
	if GameBalance.Breakables and GameBalance.Breakables.Debug and GameBalance.Breakables.Debug.PrintBoot then
		print("BreakableService ready")
	end
end

return BreakableService
