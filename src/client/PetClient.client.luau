-- LocalScript in StarterPlayerScripts named "PetClient"
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player    = Players.LocalPlayer
local PetData   = require(ReplicatedStorage:WaitForChild("PetData"))
local ColorData = require(ReplicatedStorage:WaitForChild("ColorData"))
local ColorMutationData = require(ReplicatedStorage:WaitForChild("ColorMutationData"))
local ClientUIRoot = require(ReplicatedStorage:WaitForChild("ClientUIRoot"))
local Modules    = ReplicatedStorage:WaitForChild("Modules")
local PetModelUtil = require(Modules:WaitForChild("PetModelUtil"))
local PetTraits  = Modules:FindFirstChild("PetTraits") and require(Modules:FindFirstChild("PetTraits"))

local function getClientSetting(key, defaultValue)
	local value = player:GetAttribute("Setting" .. key)
	return type(value) == "boolean" and value or defaultValue
end

local TRAIT_RARITY_COLOR = {
	Common    = Color3.fromRGB(160, 210, 255),
	Uncommon  = Color3.fromRGB(120, 230, 150),
	Rare      = Color3.fromRGB(120, 220, 120),
	Epic      = Color3.fromRGB(200, 100, 255),
	Legendary = Color3.fromRGB(255, 200, 40),
}

local Events          = ReplicatedStorage:WaitForChild("Events")
local hatchEvent      = Events:WaitForChild("HatchEgg")
local petAtkEvent     = Events:WaitForChild("PetAttack")
local petsLoadedEvent = Events:WaitForChild("PetsLoaded")
local equipEvent      = Events:WaitForChild("EquipPet")
local mergeEvent      = Events:WaitForChild("MergePet")

-- Pastel theme
local PANEL_BG     = Color3.fromRGB(255, 248, 252)
local PANEL_STROKE = Color3.fromRGB(255, 180, 220)
local TITLE_BG     = Color3.fromRGB(180, 220, 255)
local TITLE_TEXT   = Color3.fromRGB(80, 60, 130)
local SUB_BG       = Color3.fromRGB(245, 235, 252)

local RARITY_COLOR = {
	Common    = Color3.fromRGB(160, 160, 160),
	Uncommon  = Color3.fromRGB(60,  180, 80),
	Rare      = Color3.fromRGB(80,  120, 255),
	Epic      = Color3.fromRGB(160, 60,  240),
	Legendary = Color3.fromRGB(220, 160, 0),
}

local TIER_COLOR = {
	Normal    = Color3.fromRGB(200, 200, 200),
	Gilded    = Color3.fromRGB(255, 200, 50),
	Royal     = Color3.fromRGB(180, 60,  255),
	Celestial = Color3.fromRGB(100, 220, 255),
}

local RARITY_FX = {
	Common = { rate = 3.0, size = 0.07, light = 0.08, dust = 1.2 },
	Uncommon = { rate = 4.0, size = 0.08, light = 0.1, dust = 1.6 },
	Rare = { rate = 5.0, size = 0.095, light = 0.13, dust = 2.1 },
	Epic = { rate = 6.5, size = 0.115, light = 0.16, dust = 2.8 },
	Legendary = { rate = 8.0, size = 0.14, light = 0.2, dust = 3.5 },
}

local TIER_FX_MULT = {
	Normal = 1,
	Gilded = 1.2,
	Royal = 1.45,
	Celestial = 1.75,
}

local MUTATION_TYPE_COLOR = {
	Dark = Color3.fromRGB(92, 42, 155),
	Light = Color3.fromRGB(255, 225, 110),
	Corrupted = Color3.fromRGB(255, 42, 84),
}

-- State
local spawnedPets  = {}  -- { { model, variantKey } }
local allPets      = {}  -- list of buildPetEntry results
local equippedPets = {}  -- list of variant keys
local lastPetStateAt = 0
local replicatedStateQueued = false
local warnedEmptyEquippedVisuals = false
local rebuildOrbitingPets
local refreshInventoryUI

local function getEntryKey(entry)
	if typeof(entry) == "table" then
		return entry.variantKey or entry.petId
	end
	return entry
end

local function getEntryPower(entry)
	return entry.effectivePower or entry.finalPower or 0
end

local function parseReplicatedInventory(value)
	local inventory = {}
	if type(value) ~= "string" or value == "" then
		return inventory
	end

	for _, raw in ipairs(string.split(value, ",")) do
		local segments = string.split(raw, ":")
		if #segments >= 3 then
			local variantKey = segments[1]
			local petId = segments[2]
			local stackAmount = tonumber(segments[3]) or 1
			local traitId = PetData.normalizeTraitId(segments[4])
			local shinyStr = string.lower(tostring(segments[5] or "normal"))
			local personalityId = PetData.normalizePersonalityId(segments[6])
			local mutationId = PetData.normalizeMutationId(segments[7])
			local entry = PetData.buildPetEntry(petId, stackAmount, shinyStr == "shiny" or shinyStr == "true", personalityId, mutationId, traitId)
			if entry then
				entry.variantKey = variantKey ~= "" and variantKey or entry.variantKey
				entry.effectivePower = entry.finalPower
				table.insert(inventory, entry)
			end
		end
	end

	return inventory
end

local function parseReplicatedEquipped(value)
	local equipped = {}
	if type(value) ~= "string" or value == "" then
		return equipped
	end

	for _, rawKey in ipairs(string.split(value, ",")) do
		local key = string.gsub(rawKey, "^%s*(.-)%s*$", "%1")
		if key ~= "" then
			table.insert(equipped, key)
		end
	end
	return equipped
end

local function applyPetState(inventory, equipped, source)
	inventory = inventory or {}
	equipped = equipped or {}

	if #inventory == 0 and #allPets > 0 and os.clock() - lastPetStateAt < 1.5 then
		if isOpen then refreshInventoryUI() end
		warn("PetClient: ignored a transient empty Color inventory update.")
		return
	end

	allPets = inventory
	equippedPets = equipped
	lastPetStateAt = os.clock()
	rebuildOrbitingPets()
	if #equippedPets > 0 and #spawnedPets == 0 and not warnedEmptyEquippedVisuals then
		warnedEmptyEquippedVisuals = true
		warn("PetClient: equipped Colors were replicated, but no visible models were created from " .. tostring(source or "state") .. ".")
	elseif #spawnedPets > 0 then
		warnedEmptyEquippedVisuals = false
	end
	if isOpen then refreshInventoryUI() end
end

local function refreshPetsFromReplicatedValues()
	if replicatedStateQueued then
		return
	end
	replicatedStateQueued = true
	task.defer(function()
		replicatedStateQueued = false
		local petFolder = player:FindFirstChild("PetData")
		local inventoryValue = petFolder and petFolder:FindFirstChild("Inventory")
		local equippedValue = petFolder and petFolder:FindFirstChild("Equipped")
		if not inventoryValue or not equippedValue then
			return
		end
		local inventory = parseReplicatedInventory(inventoryValue.Value)
		local equipped = parseReplicatedEquipped(equippedValue.Value)
		if #inventory > 0 or #equipped > 0 then
			applyPetState(inventory, equipped, "replicated-values")
		end
	end)
end

local function entryMatchesKey(entry, key)
	if not entry or not key then
		return false
	end
	if getEntryKey(entry) == key or entry.petId == key then
		return true
	end
	if type(key) ~= "string" then
		return false
	end
	local parts = string.split(key, "|")
	if #parts < 3 or parts[1] ~= entry.petId then
		return false
	end
	local mutationMatches = PetData.normalizeMutationId(parts[3]) == PetData.normalizeMutationId(entry.mutationId)
	local traitMatches = PetData.normalizeTraitId(parts[2]) == PetData.normalizeTraitId(entry.traitId)
		or (PetData.normalizeTraitId(parts[2]) == "Neutral" and PetData.normalizeTraitId(entry.traitId) == "Neutral")
	return mutationMatches and traitMatches
end

local function softColor(color)
	return color:Lerp(Color3.fromRGB(215, 225, 235), 0.28)
end

local function getFxColor(petEntry, pet)
	if petEntry.hasMutation and petEntry.auraColor then
		return petEntry.auraColor
	end

	if petEntry.isShiny then
		return pet.color:Lerp(Color3.fromRGB(255, 255, 255), 0.58)
	end

	local color = petEntry.auraColor or pet.color
	if petEntry.petId == "RainbowDragon" or petEntry.petId == "RainbowSlime" or petEntry.petId == "ColorTitan" then
		return Color3.fromRGB(205, 175, 255)
	end
	return softColor(color)
end

local function getColorSequence(petEntry, pet, fxColor)
	if petEntry.mutationVisualTag == "rainbow"
		or petEntry.mutationId == "Rainbow"
		or petEntry.petId == "DevRainbowPet"
		or petEntry.petId == "RainbowDragon"
		or petEntry.petId == "RainbowSlime"
		or petEntry.petId == "ColorTitan"
	then
		return ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 120)),
			ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 220, 80)),
			ColorSequenceKeypoint.new(0.4, Color3.fromRGB(90, 235, 130)),
			ColorSequenceKeypoint.new(0.6, Color3.fromRGB(90, 215, 255)),
			ColorSequenceKeypoint.new(0.8, Color3.fromRGB(185, 120, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 115, 215)),
		})
	end

	local baseColor = petEntry.hasMutation and (petEntry.auraColor or fxColor) or pet.color
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, softColor(baseColor)),
		ColorSequenceKeypoint.new(0.55, fxColor),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
	})
end

local function getMutationFxBoost(petEntry)
	local tag = petEntry.mutationVisualTag
	local mutationType = petEntry.mutationType
	if mutationType == "Corrupted" or string.find(tostring(tag), "corrupted") then
		return 2.25, NumberRange.new(1.7, 3.8), NumberRange.new(0.18, 0.45)
	elseif mutationType == "Dark" or string.find(tostring(tag), "dark") then
		return 1.8, NumberRange.new(0.85, 2.3), NumberRange.new(0.35, 0.85)
	elseif mutationType == "Light" or string.find(tostring(tag), "light") then
		return 1.75, NumberRange.new(0.9, 2.4), NumberRange.new(0.35, 0.8)
	elseif tag == "glitch" then
		return 2.0, NumberRange.new(1.4, 3.2), NumberRange.new(0.22, 0.55)
	elseif tag == "storm" then
		return 1.8, NumberRange.new(1.2, 2.8), NumberRange.new(0.25, 0.6)
	elseif tag == "magnetic" then
		return 1.55, NumberRange.new(0.75, 1.8), NumberRange.new(0.55, 1.15)
	elseif tag == "hyper" then
		return 1.45, NumberRange.new(1.8, 3.4), NumberRange.new(0.22, 0.5)
	elseif tag == "gold" or tag == "sparkle" then
		return 1.35, NumberRange.new(0.9, 2.1), NumberRange.new(0.4, 0.9)
	end
	return 1.25, NumberRange.new(0.7, 1.8), NumberRange.new(0.45, 1.0)
end

local function tonePetPart(part, color)
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = softColor(color)
	part.Transparency = math.max(part.Transparency, 0)
end

local function createDevRainbowPetModel(petEntry, pet)
	local model = Instance.new("Model")
	model.Name = "RainbowPet"

	local function makePart(name, shape, size, cframe, color, material, transparency)
		local part = Instance.new("Part")
		part.Name = name
		part.Shape = shape or Enum.PartType.Ball
		part.Size = size
		part.CFrame = cframe or CFrame.new()
		tonePetPart(part, color)
		part.Material = material or Enum.Material.SmoothPlastic
		part.Transparency = transparency or 0
		part.Parent = model
		return part
	end

	local body = makePart(
		"RainbowBody",
		Enum.PartType.Ball,
		Vector3.new(2.4, 2.4, 2.4),
		CFrame.new(),
		Color3.fromRGB(255, 245, 255),
		Enum.Material.Neon
	)
	model.PrimaryPart = body

	local shell = makePart(
		"RainbowGlowShell",
		Enum.PartType.Ball,
		Vector3.new(2.72, 2.72, 2.72),
		CFrame.new(),
		Color3.fromRGB(180, 120, 255),
		Enum.Material.ForceField,
		0.62
	)
	shell:SetAttribute("NoTint", true)

	local rainbowColors = {
		Color3.fromRGB(255, 70, 95),
		Color3.fromRGB(255, 142, 54),
		Color3.fromRGB(255, 230, 70),
		Color3.fromRGB(75, 230, 120),
		Color3.fromRGB(70, 210, 255),
		Color3.fromRGB(90, 115, 255),
		Color3.fromRGB(190, 100, 255),
		Color3.fromRGB(255, 105, 205),
	}

	for index, color in ipairs(rainbowColors) do
		local angle = math.rad(index * 45)
		makePart(
			"RainbowGem" .. tostring(index),
			Enum.PartType.Ball,
			Vector3.new(0.5, 0.5, 0.5),
			CFrame.new(math.cos(angle) * 1.58, 0.18 * math.sin(angle * 2), math.sin(angle) * 1.58),
			color,
			Enum.Material.Neon
		)
	end

	for index, color in ipairs(rainbowColors) do
		local offsetY = -0.84 + ((index - 1) * 0.24)
		local band = makePart(
			"RainbowBand" .. tostring(index),
			Enum.PartType.Cylinder,
			Vector3.new(0.08, 2.66, 2.66),
			CFrame.new(0, offsetY, 0) * CFrame.Angles(0, 0, math.rad(90 + (index % 2) * 7)),
			color,
			Enum.Material.Neon,
			0.34
		)
		band:SetAttribute("NoTint", true)
	end

	makePart(
		"RainbowHalo",
		Enum.PartType.Cylinder,
		Vector3.new(0.12, 2.9, 2.9),
		CFrame.new(0, 1.65, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(255, 236, 120),
		Enum.Material.Neon,
		0.18
	)

	local leftWing = Instance.new("WedgePart")
	leftWing.Name = "LeftPrismWing"
	leftWing.Size = Vector3.new(1.1, 1.5, 0.34)
	leftWing.CFrame = CFrame.new(-1.35, 0.1, 0.05) * CFrame.Angles(0, 0, math.rad(18))
	tonePetPart(leftWing, Color3.fromRGB(105, 230, 255))
	leftWing.Material = Enum.Material.Neon
	leftWing.Transparency = 0.12
	leftWing.Parent = model

	local rightWing = Instance.new("WedgePart")
	rightWing.Name = "RightPrismWing"
	rightWing.Size = Vector3.new(1.1, 1.5, 0.34)
	rightWing.CFrame = CFrame.new(1.35, 0.1, 0.05) * CFrame.Angles(0, math.rad(180), math.rad(-18))
	tonePetPart(rightWing, Color3.fromRGB(185, 120, 255))
	rightWing.Material = Enum.Material.Neon
	rightWing.Transparency = 0.12
	rightWing.Parent = model

	body:SetAttribute("NoTint", true)
	return model
end

local function addPetParticles(model, petEntry, pet)
	if getClientSetting("LowFX", false) then
		return
	end
	if not model.PrimaryPart then
		return
	end

	local primary = model.PrimaryPart
	local tierName = petEntry.currentStackTier or "Normal"
	local rarityFx = RARITY_FX[pet.rarity] or RARITY_FX.Common
	local tierMult = TIER_FX_MULT[tierName] or 1
	local fxColor = getFxColor(petEntry, pet)
	local colorSequence = getColorSequence(petEntry, pet, fxColor)

	local attachment = primary:FindFirstChild("PetFxAttachment")
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "PetFxAttachment"
		attachment.Parent = primary
	end

	local motes = Instance.new("ParticleEmitter")
	motes.Name = "PetAuraMotes"
	motes.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	motes.Color = colorSequence
	motes.LightEmission = 0.32
	motes.LightInfluence = 0.35
	motes.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, rarityFx.size * tierMult),
		NumberSequenceKeypoint.new(1, 0),
	})
	motes.Speed = NumberRange.new(0.45, 1.35)
	motes.SpreadAngle = Vector2.new(180, 180)
	motes.Lifetime = NumberRange.new(0.65, 1.35)
	motes.Rate = rarityFx.rate * tierMult
	motes.Parent = attachment

	local dust = Instance.new("ParticleEmitter")
	dust.Name = "ColorDriftDust"
	dust.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	dust.Color = colorSequence
	dust.LightEmission = 0.18
	dust.LightInfluence = 0.5
	dust.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, rarityFx.size * 1.35 * tierMult),
		NumberSequenceKeypoint.new(0.55, rarityFx.size * 0.75 * tierMult),
		NumberSequenceKeypoint.new(1, 0),
	})
	dust.Speed = NumberRange.new(0.08, 0.45)
	dust.Acceleration = Vector3.new(0, 0.35, 0)
	dust.Drag = 1.2
	dust.SpreadAngle = Vector2.new(180, 180)
	dust.Lifetime = NumberRange.new(1.1, 2.0)
	dust.Rate = rarityFx.dust * tierMult
	dust.Rotation = NumberRange.new(0, 360)
	dust.RotSpeed = NumberRange.new(-45, 45)
	dust.Parent = attachment

	local glowPops = Instance.new("ParticleEmitter")
	glowPops.Name = "ColorGlowPops"
	glowPops.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	glowPops.Color = colorSequence
	glowPops.LightEmission = 0.42
	glowPops.LightInfluence = 0.28
	glowPops.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, rarityFx.size * 2.2 * tierMult),
		NumberSequenceKeypoint.new(0.35, rarityFx.size * 1.1 * tierMult),
		NumberSequenceKeypoint.new(1, 0),
	})
	glowPops.Speed = NumberRange.new(0.15, 0.65)
	glowPops.SpreadAngle = Vector2.new(180, 180)
	glowPops.Lifetime = NumberRange.new(0.45, 0.85)
	glowPops.Rate = math.max(0.8, rarityFx.rate * 0.22 * tierMult)
	glowPops.Parent = attachment

	if petEntry.hasMutation then
		local boost, mutationSpeed, mutationLifetime = getMutationFxBoost(petEntry)
		local mutationEmitter = Instance.new("ParticleEmitter")
		mutationEmitter.Name = "ColorMutationAura"
		mutationEmitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		mutationEmitter.Color = colorSequence
		mutationEmitter.LightEmission = 0.55
		mutationEmitter.LightInfluence = 0.25
		mutationEmitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.16 * tierMult),
			NumberSequenceKeypoint.new(0.45, 0.09 * tierMult),
			NumberSequenceKeypoint.new(1, 0),
		})
		mutationEmitter.Speed = mutationSpeed
		mutationEmitter.SpreadAngle = Vector2.new(180, 180)
		mutationEmitter.Lifetime = mutationLifetime
		mutationEmitter.Rate = math.min(16, rarityFx.rate * boost)
		mutationEmitter.Rotation = NumberRange.new(0, 360)
		mutationEmitter.RotSpeed = NumberRange.new(-120, 120)
		mutationEmitter.Parent = attachment
	end

	if pet.rarity == "Epic" or pet.rarity == "Legendary" or tierName ~= "Normal" then
		local ring = Instance.new("ParticleEmitter")
		ring.Name = "PetSoftAura"
		ring.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		ring.Color = colorSequence
		ring.LightEmission = 0.22
		ring.LightInfluence = 0.5
		ring.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.18 * tierMult),
			NumberSequenceKeypoint.new(0.65, 0.08 * tierMult),
			NumberSequenceKeypoint.new(1, 0),
		})
		ring.Speed = NumberRange.new(0.1, 0.35)
		ring.SpreadAngle = Vector2.new(180, 180)
		ring.Lifetime = NumberRange.new(0.8, 1.4)
		ring.Rate = math.min(5, 1.4 * tierMult)
		ring.Parent = attachment
	end

	local light = Instance.new("PointLight")
	light.Name = "PetSoftLight"
	light.Color = fxColor
	light.Range = 4.5 + tierMult
	light.Brightness = rarityFx.light * tierMult
	light.Parent = primary
end

local function getMutationPalette(petEntry)
	local mutationType = tostring(petEntry.mutationType or "")
	local base = petEntry.mutationTypeColor
		or MUTATION_TYPE_COLOR[mutationType]
		or ColorMutationData.getTypeColor(mutationType)
		or petEntry.auraColor
		or Color3.fromRGB(255, 255, 255)

	if mutationType == "Dark" then
		return base, Color3.fromRGB(14, 8, 24), Color3.fromRGB(140, 65, 255)
	elseif mutationType == "Light" then
		return base, Color3.fromRGB(255, 250, 210), Color3.fromRGB(255, 205, 80)
	elseif mutationType == "Corrupted" then
		return base, Color3.fromRGB(20, 0, 8), Color3.fromRGB(75, 238, 255)
	end

	return base, base:Lerp(Color3.new(0, 0, 0), 0.55), base:Lerp(Color3.new(1, 1, 1), 0.2)
end

local function applyMutationOverlay(model, petEntry)
	if not model or not model.PrimaryPart or not petEntry or not petEntry.hasMutation then
		return
	end

	local primary = model.PrimaryPart
	local mutationType = tostring(petEntry.mutationType or "")
	local mainColor, darkColor, accentColor = getMutationPalette(petEntry)
	local extents = model:GetExtentsSize()
	local largest = math.max(extents.X, extents.Y, extents.Z, 1)

	local highlight = Instance.new("Highlight")
	highlight.Name = "MutationHighlight"
	highlight.Adornee = model
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = mutationType == "Corrupted" and accentColor or mainColor
	highlight.OutlineColor = mutationType == "Dark" and accentColor or darkColor
	highlight.FillTransparency = mutationType == "Corrupted" and 0.62 or 0.72
	highlight.OutlineTransparency = petEntry.mutationRarity == "Legendary" and 0.08 or 0.18
	highlight.Parent = model

	local mutationLight = Instance.new("PointLight")
	mutationLight.Name = "MutationPointLight"
	mutationLight.Color = mainColor
	mutationLight.Range = 7 + largest
	mutationLight.Brightness = mutationType == "Corrupted" and 1.35 or 0.9
	mutationLight.Parent = primary

	local attachment = primary:FindFirstChild("MutationFxAttachment")
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "MutationFxAttachment"
		attachment.Parent = primary
	end

	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "MutationSignatureParticles"
	smoke.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	smoke.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, darkColor),
		ColorSequenceKeypoint.new(0.5, mainColor),
		ColorSequenceKeypoint.new(1, accentColor),
	})
	smoke.LightEmission = mutationType == "Dark" and 0.25 or 0.72
	smoke.LightInfluence = mutationType == "Corrupted" and 0.05 or 0.2
	smoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, mutationType == "Corrupted" and 0.22 or 0.16),
		NumberSequenceKeypoint.new(0.45, 0.1),
		NumberSequenceKeypoint.new(1, 0),
	})
	smoke.Speed = mutationType == "Corrupted" and NumberRange.new(2.2, 5.2) or NumberRange.new(0.7, 2.6)
	smoke.SpreadAngle = Vector2.new(180, 180)
	smoke.Lifetime = mutationType == "Corrupted" and NumberRange.new(0.12, 0.42) or NumberRange.new(0.55, 1.35)
	smoke.Rate = mutationType == "Corrupted" and 20 or 12
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.RotSpeed = NumberRange.new(-190, 190)
	smoke.Parent = attachment

	if mutationType == "Light" then
		local halo = Instance.new("Part")
		halo.Name = "MutationHalo"
		halo.Shape = Enum.PartType.Cylinder
		halo.Size = Vector3.new(0.08, largest * 1.75, largest * 1.75)
		halo.CFrame = primary.CFrame * CFrame.new(0, largest * 0.72, 0) * CFrame.Angles(0, 0, math.rad(90))
		halo.Color = accentColor
		halo.Material = Enum.Material.Neon
		halo.Transparency = 0.24
		halo.Anchored = true
		halo.CanCollide = false
		halo.CanTouch = false
		halo.CanQuery = false
		halo.CastShadow = false
		halo.Parent = model
	elseif mutationType == "Dark" then
		local eclipse = Instance.new("Part")
		eclipse.Name = "MutationEclipseRing"
		eclipse.Shape = Enum.PartType.Cylinder
		eclipse.Size = Vector3.new(0.09, largest * 1.95, largest * 1.95)
		eclipse.CFrame = primary.CFrame * CFrame.Angles(math.rad(84), math.rad(18), 0)
		eclipse.Color = Color3.fromRGB(8, 5, 18)
		eclipse.Material = Enum.Material.Neon
		eclipse.Transparency = 0.34
		eclipse.Anchored = true
		eclipse.CanCollide = false
		eclipse.CanTouch = false
		eclipse.CanQuery = false
		eclipse.CastShadow = false
		eclipse.Parent = model
	end
end

-- ========================
--   CREATE PET MODEL
-- ========================
local function createPetModel(petEntry)
	local pet = PetData.Pets[petEntry.petId]
	if not pet then return nil end

	local tierName  = petEntry.currentStackTier
	local auraColor = petEntry.auraColor
	local model = PetModelUtil.ClonePetModel(petEntry.petId, { anchored = true, removeBillboards = true })

	if model and model:IsA("Model") then
		model.Name = petEntry.petId .. "_" .. tierName

		if not model.PrimaryPart then
			local first = model:FindFirstChild("Core") or model:FindFirstChildOfClass("BasePart")
			if first then model.PrimaryPart = first end
		end
	else
		model = Instance.new("Model")
		model.Name = petEntry.petId .. "_" .. tierName

		-- Scale body based on tier
		local sizeScale = tierName == "Celestial" and 2.8
			or tierName == "Royal"     and 2.2
			or tierName == "Gilded"    and 1.8
			or 1.5

		local body = Instance.new("Part")
		body.Shape      = Enum.PartType.Ball
		body.Size       = Vector3.new(sizeScale, sizeScale, sizeScale)
		tonePetPart(body, petEntry.isShiny and pet.color:Lerp(Color3.fromRGB(255, 255, 255), 0.58) or pet.color)
		body.Parent     = model
		model.PrimaryPart = body

		-- Tier-specific soft shell. Particles carry the visible aura.
		if tierName ~= "Normal" then
			local aura = Instance.new("Part")
			aura.Shape        = Enum.PartType.Ball
			aura.Size         = Vector3.new(sizeScale * 1.18, sizeScale * 1.18, sizeScale * 1.18)
			aura.Color        = softColor(auraColor)
			aura.Material     = Enum.Material.ForceField
			aura.Transparency = tierName == "Celestial" and 0.82 or 0.88
			aura.CastShadow   = false
			aura.Anchored     = true
			aura.CanCollide   = false
			aura.Parent       = model
		end

		if petEntry.isShiny then
			local shine = Instance.new("Part")
			shine.Shape        = Enum.PartType.Ball
			shine.Size         = Vector3.new(sizeScale * 1.32, sizeScale * 1.32, sizeScale * 1.32)
			shine.Color        = Color3.fromRGB(255, 245, 160)
			shine.Material     = Enum.Material.ForceField
			shine.Transparency = 0.74
			shine.CastShadow   = false
			shine.Anchored     = true
			shine.CanCollide   = false
			shine.Parent       = model
		end
	end

	-- Attachment for drain beams
	if model.PrimaryPart and not model.PrimaryPart:FindFirstChild("PetAttachment") then
		local att = Instance.new("Attachment")
		att.Name   = "PetAttachment"
		att.Parent = model.PrimaryPart
	end

	if petEntry.hasMutation and model.PrimaryPart then
		local extents = model:GetExtentsSize()
		local auraSize = math.max(extents.X, extents.Y, extents.Z) * 1.35
		local mutationAura = Instance.new("Part")
		mutationAura.Name = "MutationAura"
		mutationAura.Shape = Enum.PartType.Ball
		mutationAura.Size = Vector3.new(auraSize, auraSize, auraSize)
		mutationAura.CFrame = model.PrimaryPart.CFrame
		mutationAura.Color = softColor(petEntry.auraColor or pet.color)
		mutationAura.Material = Enum.Material.ForceField
		mutationAura.Transparency = petEntry.mutationVisualTag == "glitch" and 0.72 or 0.82
		mutationAura.CastShadow = false
		mutationAura.Anchored = true
		mutationAura.CanCollide = false
		mutationAura.Parent = model
	end

	-- Point light — color and intensity scale with tier
	applyMutationOverlay(model, petEntry)
	addPetParticles(model, petEntry, pet)

	model.Parent = workspace
	return model
end
local function applyTraitEffect(model, trait)
	if not model or not model.PrimaryPart or not trait then return end
	local effect = trait.visualEffect or "none"
	local primary = model.PrimaryPart

	if effect == "glow" then
		local existing = primary:FindFirstChildOfClass("PointLight")
		if not existing then
			local light = Instance.new("PointLight")
			light.Color      = softColor(trait.color or Color3.new(1, 1, 1))
			light.Range      = 5
			light.Brightness = 0.12
			light.Parent     = primary
		end

	elseif effect == "rainbow" then
		-- Slow color cycle via Heartbeat
		local t0 = tick()
		task.spawn(function()
			while model and model.Parent do
				local t   = (tick() - t0) * 0.3
				local h   = t % 1
				local col = Color3.fromHSV(h, 0.55, 0.82)
				for _, part in ipairs(model:GetDescendants()) do
					if part:IsA("BasePart") then
						part.Color = col
					end
				end
				task.wait(0.05)
			end
		end)

	elseif effect == "giant" then
		local scale = trait.sizeScale or 1.4
		model:ScaleTo(scale)

	elseif effect == "spark" or effect == "electric" then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Color         = ColorSequence.new(softColor(trait.color or Color3.fromRGB(255, 240, 80)))
		emitter.Size          = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.08),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Speed         = NumberRange.new(1, 3)
		emitter.Lifetime      = NumberRange.new(0.2, 0.5)
		emitter.Rate          = 4
		emitter.LightEmission = 0.25
		emitter.LightInfluence = 0.4
		emitter.LockedToPart  = true
		emitter.Parent        = primary

	elseif effect == "celestial" then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Color         = ColorSequence.new(Color3.fromRGB(150, 195, 235))
		emitter.Size          = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.08),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Speed         = NumberRange.new(0.5, 1.5)
		emitter.Lifetime      = NumberRange.new(0.5, 1.2)
		emitter.Rate          = 3
		emitter.LightEmission = 0.2
		emitter.LightInfluence = 0.45
		emitter.LockedToPart  = false
		emitter.Parent        = primary
	end

	if trait.sizeScale and effect ~= "giant" then
		model:ScaleTo(trait.sizeScale)
	end
end

local function collectFloatCores(model)
	if not model or not model.PrimaryPart then
		return {}
	end

	local cores = {}
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant ~= model.PrimaryPart then
			local loweredName = string.lower(descendant.Name)
			if string.match(loweredName, "^floatcore") then
				table.insert(cores, descendant)
			end
		end
	end

	table.sort(cores, function(a, b)
		return a.Name < b.Name
	end)

	local orbiters = {}
	for index, part in ipairs(cores) do
		local relative = model.PrimaryPart.CFrame:PointToObjectSpace(part.Position)
		local radius = Vector3.new(relative.X, 0, relative.Z).Magnitude
		if radius < 1.35 then
			radius = 2.35 + index * 0.18
		end

		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part:SetAttribute("ColorOrbiter", true)

		table.insert(orbiters, {
			part = part,
			radius = radius,
			verticalOffset = math.clamp(relative.Y, -1.2, 1.8),
			phase = ((index - 1) / math.max(1, #cores)) * math.pi * 2,
			speed = (index % 2 == 0 and -1 or 1) * (1.65 + index * 0.18),
			bobPhase = index * 1.9,
		})
	end

	return orbiters
end

local function shouldUseRedLightning(petEntry, model)
	if petEntry and petEntry.petId == "red_legendary_orb" then
		return true
	end
	if model and model:GetAttribute("PetId") == "red_legendary_orb" then
		return true
	end
	return model and string.find(string.lower(model.Name), "red_legendary_orb") ~= nil
end

local function makeRedLightningVisuals(model, petEntry)
	if getClientSetting("LowFX", false) then
		return nil
	end
	if not model or not model.PrimaryPart or not shouldUseRedLightning(petEntry, model) then
		return nil
	end

	local primary = model.PrimaryPart
	local source = primary:FindFirstChild("RedLightningSource")
	if not source then
		source = Instance.new("Attachment")
		source.Name = "RedLightningSource"
		source.Parent = primary
	end

	local sparks = primary:FindFirstChild("RedLightningSparks")
	if not sparks then
		sparks = Instance.new("ParticleEmitter")
		sparks.Name = "RedLightningSparks"
		sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparks.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 55, 55)),
			ColorSequenceKeypoint.new(0.65, Color3.fromRGB(255, 20, 20)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 210, 210)),
		})
		sparks.LightEmission = 0.85
		sparks.LightInfluence = 0.08
		sparks.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.18),
			NumberSequenceKeypoint.new(0.35, 0.09),
			NumberSequenceKeypoint.new(1, 0),
		})
		sparks.Speed = NumberRange.new(2.5, 6)
		sparks.SpreadAngle = Vector2.new(180, 180)
		sparks.Lifetime = NumberRange.new(0.12, 0.28)
		sparks.Rate = 16
		sparks.Rotation = NumberRange.new(0, 360)
		sparks.RotSpeed = NumberRange.new(-260, 260)
		sparks.Parent = primary
	end

	return {
		source = source,
		nextStrikeAt = 0,
	}
end

local function spawnRedLightningStrike(model, lightning)
	if not model or not model.Parent or not model.PrimaryPart or not lightning or not lightning.source then
		return
	end

	local primary = model.PrimaryPart
	local angle = math.random() * math.pi * 2
	local elevation = math.rad(math.random(-28, 45))
	local distance = math.random(32, 58) / 10
	local localTarget = Vector3.new(
		math.cos(angle) * math.cos(elevation) * distance,
		math.sin(elevation) * distance + math.random(-8, 12) / 10,
		math.sin(angle) * math.cos(elevation) * distance
	)

	local target = Instance.new("Attachment")
	target.Name = "RedLightningTarget"
	target.Position = localTarget
	target.Parent = primary

	local beam = Instance.new("Beam")
	beam.Name = "RedLightningBolt"
	beam.Attachment0 = lightning.source
	beam.Attachment1 = target
	beam.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 235, 235)),
		ColorSequenceKeypoint.new(0.18, Color3.fromRGB(255, 35, 35)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 0, 0)),
	})
	beam.Width0 = 0.13
	beam.Width1 = 0.02
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Segments = 7
	beam.CurveSize0 = math.random(-18, 18) / 10
	beam.CurveSize1 = math.random(-18, 18) / 10
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.06),
		NumberSequenceKeypoint.new(0.7, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	beam.Parent = primary

	task.delay(0.12, function()
		if beam and beam.Parent then
			beam:Destroy()
		end
		if target and target.Parent then
			target:Destroy()
		end
	end)
end

local function buildPetVisualState(model, petEntry)
	return {
		floatCores = collectFloatCores(model),
		redLightning = makeRedLightningVisuals(model, petEntry),
		mutationHighlight = model and model:FindFirstChild("MutationHighlight"),
		mutationType = petEntry and petEntry.mutationType,
	}
end

local function updateCustomPetVisuals(entry, now)
	local model = entry.model
	local visuals = entry.visuals
	if not model or not model.Parent or not model.PrimaryPart or not visuals then
		return
	end

	local primaryCFrame = model.PrimaryPart.CFrame
	for _, orbiter in ipairs(visuals.floatCores or {}) do
		local part = orbiter.part
		if part and part.Parent then
			local angle = now * orbiter.speed + orbiter.phase
			local bob = math.sin(now * 3 + orbiter.bobPhase) * 0.22
			local localOffset = Vector3.new(
				math.cos(angle) * orbiter.radius,
				orbiter.verticalOffset + bob,
				math.sin(angle) * orbiter.radius
			)
			part.CFrame = primaryCFrame * CFrame.new(localOffset)
		end
	end

	local lightning = visuals.redLightning
	if lightning and now >= lightning.nextStrikeAt then
		lightning.nextStrikeAt = now + math.random(22, 42) / 10
		spawnRedLightningStrike(model, lightning)
	end

	local mutationHighlight = visuals.mutationHighlight
	if mutationHighlight and mutationHighlight.Parent then
		if visuals.mutationType == "Corrupted" then
			mutationHighlight.FillTransparency = 0.48 + math.abs(math.sin(now * 18)) * 0.28
			mutationHighlight.OutlineTransparency = 0.02 + math.abs(math.sin(now * 13.5)) * 0.22
		elseif visuals.mutationType == "Light" then
			mutationHighlight.FillTransparency = 0.62 + math.sin(now * 3.2) * 0.08
			mutationHighlight.OutlineTransparency = 0.12 + math.sin(now * 2.6) * 0.06
		elseif visuals.mutationType == "Dark" then
			mutationHighlight.FillTransparency = 0.68 + math.sin(now * 2.2) * 0.06
			mutationHighlight.OutlineTransparency = 0.13 + math.sin(now * 2.8) * 0.07
		end
	end
end
-- ========================
--   REBUILD ORBITING PETS
-- ========================
function rebuildOrbitingPets()
	for _, entry in ipairs(spawnedPets) do
		if entry.model and entry.model.Parent then
			entry.model:Destroy()
		end
	end
	spawnedPets = {}

	-- Build a lookup from variantKey -> entry data. Legacy petIds still work as a fallback.
	local entryByKey = {}
	for _, entry in ipairs(allPets) do
		entryByKey[getEntryKey(entry)] = entry
		entryByKey[entry.petId] = entryByKey[entry.petId] or entry
	end

	for _, variantKey in ipairs(equippedPets) do
		local petEntry = entryByKey[variantKey]
		if not petEntry then
			for _, entry in ipairs(allPets) do
				if entryMatchesKey(entry, variantKey) then
					petEntry = entry
					break
				end
			end
		end
		if petEntry then
			local model = createPetModel(petEntry)
			if model then
				applyTraitEffect(model, petEntry.trait)
				table.insert(spawnedPets, {
					model = model,
					variantKey = variantKey,
					visuals = buildPetVisualState(model, petEntry),
				})
				
			end
		end
	end
end

-- ========================
--   DRAIN BEAM
-- ========================
local function createDrainBeam(petModel, targetObj, colorType)
	if getClientSetting("LowFX", false) then return end
	if not petModel or not petModel.PrimaryPart then return end
	if not targetObj or not targetObj.Parent then return end

	local petAtt = petModel.PrimaryPart:FindFirstChild("PetAttachment")
	if not petAtt then return end

	local targetAtt = Instance.new("Attachment")
	targetAtt.Name   = "DrainAttachment"
	targetAtt.Parent = targetObj

	-- Get the breakable's current color (drains toward grey so this shifts too)
	local breakColor = targetObj.Color

	-- Get the pet's color from the model
	local petColor = petModel.PrimaryPart.Color

	-- Mix: beam starts as the breakable color at the object end
	-- and shifts to the pet color at the pet end
	-- This visually shows the color being "sucked" into the pet
	local beam = Instance.new("Beam")
	beam.Attachment0  = targetAtt   -- from object
	beam.Attachment1  = petAtt      -- to pet
	beam.Color        = ColorSequence.new({
		ColorSequenceKeypoint.new(0,    breakColor),                        -- object end: breakable color
		ColorSequenceKeypoint.new(0.4,  breakColor:Lerp(petColor, 0.4)),   -- blend
		ColorSequenceKeypoint.new(0.75, petColor:Lerp(Color3.new(1,1,1), 0.2)), -- near pet: pet color slightly brightened
		ColorSequenceKeypoint.new(1,    petColor),                          -- pet end: pure pet color
	})
	beam.Width0        = 0.18
	beam.Width1        = 0.035
	beam.TextureSpeed  = 4     -- flows toward the pet
	beam.Transparency  = NumberSequence.new({
		NumberSequenceKeypoint.new(0,   0.45),
		NumberSequenceKeypoint.new(0.5, 0.62),
		NumberSequenceKeypoint.new(1,   0.88),
	})
	beam.LightEmission = 0.25
	beam.Segments      = 8
	beam.CurveSize0    = 0.8
	beam.CurveSize1    = 0.8
	beam.FaceCamera    = true
	beam.Parent        = targetObj

	-- Particles: spawn at object, colored like the breakable, fly toward pet
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0,   breakColor),
		ColorSequenceKeypoint.new(0.5, breakColor:Lerp(petColor, 0.5)),
		ColorSequenceKeypoint.new(1,   petColor),
	})
	emitter.Size          = NumberSequence.new({
		NumberSequenceKeypoint.new(0,   0.12),
		NumberSequenceKeypoint.new(0.7, 0.06),
		NumberSequenceKeypoint.new(1,   0),
	})
	emitter.Speed         = NumberRange.new(2, 4)
	emitter.Lifetime      = NumberRange.new(0.15, 0.35)
	emitter.Rate          = 8
	emitter.LightEmission = 0.25
	emitter.LightInfluence = 0.5
	emitter.LockedToPart  = false
	emitter.SpreadAngle   = Vector2.new(15, 15)
	emitter.Parent        = targetObj

	task.delay(0.4, function()
		if beam    and beam.Parent    then beam:Destroy()    end
		if targetAtt and targetAtt.Parent then targetAtt:Destroy() end
		if emitter and emitter.Parent then
			emitter.Enabled = false
			task.delay(0.4, function()
				if emitter and emitter.Parent then emitter:Destroy() end
			end)
		end
	end)
end

-- ========================
--   BUILD UI
-- ========================
local isOpen = false
function refreshInventoryUI()
	-- Legacy inventory UI disabled. InventoryUI.client.luau is the active source.
end
-- Do not register or create a second inventory/menu UI here. PetClient only owns orbiting
-- Color companions and small VFX; InventoryUI.client.luau is the single inventory source.

-- Legacy inventory builder removed. InventoryUI.client.luau owns the single Inventory window.
-- If an old Pets/Bag/Colors route fires, InventoryUI aliases it to current Inventory and warns once.

-- ========================
--   EVENTS
-- ========================
petsLoadedEvent.OnClientEvent:Connect(function(inventory, equipped)
	applyPetState(inventory, equipped, "PetsLoaded")
end)

task.spawn(function()
	local petFolder = player:WaitForChild("PetData", 15)
	if not petFolder then
		return
	end
	local inventoryValue = petFolder:WaitForChild("Inventory", 10)
	local equippedValue = petFolder:WaitForChild("Equipped", 10)
	if inventoryValue then
		inventoryValue:GetPropertyChangedSignal("Value"):Connect(refreshPetsFromReplicatedValues)
	end
	if equippedValue then
		equippedValue:GetPropertyChangedSignal("Value"):Connect(refreshPetsFromReplicatedValues)
	end
	refreshPetsFromReplicatedValues()
end)

player.CharacterAdded:Connect(function()
	task.wait(0.2)
	if #equippedPets > 0 then
		rebuildOrbitingPets()
	else
		refreshPetsFromReplicatedValues()
	end
end)

-- EggShopUI owns hatch reveal animations now.

mergeEvent.OnClientEvent:Connect(function(success, petId, result)
	local popup = ClientUIRoot.GetLayer(player.PlayerGui, "PetMergeToastUI")

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 280, 0, 86)
	frame.Position = UDim2.new(0.5, -140, 0.32, 0)
	frame.BackgroundColor3 = PANEL_BG
	frame.BorderSizePixel = 0
	frame.Parent = popup
	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = UDim.new(0, 18)
	frameCorner.Parent = frame
	local frameStroke = Instance.new("UIStroke")
	frameStroke.Thickness = 3
	frameStroke.Color = success and Color3.fromRGB(255, 215, 90) or Color3.fromRGB(255, 130, 150)
	frameStroke.Parent = frame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -16, 0, 36)
	title.Position = UDim2.new(0, 8, 0, 8)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.LuckiestGuy
	title.TextSize = 18
	title.TextColor3 = success and Color3.fromRGB(170, 105, 10) or Color3.fromRGB(180, 45, 65)
	title.TextStrokeTransparency = 1
	title.Text = success and "MERGE COMPLETE" or "MERGE FAILED"
	title.Parent = frame

	local detail = Instance.new("TextLabel")
	detail.Size = UDim2.new(1, -16, 0, 28)
	detail.Position = UDim2.new(0, 8, 0, 44)
	detail.BackgroundTransparency = 1
	detail.Font = Enum.Font.GothamBold
	detail.TextSize = 13
	detail.TextColor3 = TITLE_TEXT
	detail.Text = success and (result and result.displayName or tostring(petId)) or tostring(result or "Not ready.")
	detail.Parent = frame

	frame.Size = UDim2.new(0, 40, 0, 40)
	frame.Position = UDim2.new(0.5, -20, 0.32, 30)
	TweenService:Create(frame, TweenInfo.new(0.28, Enum.EasingStyle.Back), {
		Size = UDim2.new(0, 280, 0, 86),
		Position = UDim2.new(0.5, -140, 0.32, 0),
	}):Play()

	task.wait(success and 2.2 or 1.5)
	if frame and frame.Parent then
		frame:Destroy()
	end
end)


petAtkEvent.OnClientEvent:Connect(function(equippedPetIds, targetObj, colorType)
	if not equippedPetIds or not targetObj then return end
	for i, petId in ipairs(equippedPetIds) do
		local petModel = spawnedPets[i] and spawnedPets[i].model
		if petModel then createDrainBeam(petModel, targetObj, colorType) end
	end
end)

-- ========================
--   ORBIT LOOP
-- ========================
RunService.Heartbeat:Connect(function()
	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local t     = tick()
	local total = #spawnedPets
	if total == 0 then return end

	for i, entry in ipairs(spawnedPets) do
		local model = entry.model
		if model and model.Parent and model.PrimaryPart then
			local row = math.floor((i - 1) / 3)
			local slot = (i - 1) % 3
			local rowCount = math.min(3, total - row * 3)
			local sideOffset = (slot - (rowCount - 1) * 0.5) * 3.2
			local backOffset = 4.8 + row * 2.2
			local bob = math.sin(t * 2.4 + i) * 0.35
			local pos = root.Position
				- root.CFrame.LookVector * backOffset
				+ root.CFrame.RightVector * sideOffset
				+ Vector3.new(0, 2.4 + bob, 0)
			model:PivotTo(CFrame.lookAt(pos, root.Position + Vector3.new(0, 1.8, 0)))
			updateCustomPetVisuals(entry, t)
		end
	end
end)
