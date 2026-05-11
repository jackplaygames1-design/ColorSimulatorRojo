local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PetDefinitions = require(script.Parent:WaitForChild("PetDefinitions"))
local ColorMutationData = require(ReplicatedStorage:WaitForChild("ColorMutationData"))

local PetModelUtil = {}
local warned = {}

local RAINBOW_COLORS = {
	Color3.fromRGB(255, 70, 95),
	Color3.fromRGB(255, 145, 45),
	Color3.fromRGB(255, 232, 70),
	Color3.fromRGB(75, 230, 120),
	Color3.fromRGB(70, 210, 255),
	Color3.fromRGB(90, 115, 255),
	Color3.fromRGB(190, 100, 255),
}

local MUTATION_ACCENTS = {
	Dark = Color3.fromRGB(65, 24, 115),
	Light = Color3.fromRGB(255, 242, 145),
	Corrupted = Color3.fromRGB(255, 45, 95),
	None = Color3.fromRGB(210, 220, 235),
}

local function warnOnce(key, message)
	if warned[key] then
		return
	end
	warned[key] = true
	warn(message)
end

function PetModelUtil.GetPetModelsFolder()
	local folder = ReplicatedStorage:FindFirstChild("PetModels")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "PetModels"
		folder.Parent = ReplicatedStorage
	end
	return folder
end

local function applyTemplateAttributes(model, definition)
	model:SetAttribute("PetId", definition.Id)
	model:SetAttribute("DisplayName", definition.DisplayName)
	model:SetAttribute("Rarity", definition.Rarity)
	model:SetAttribute("WorldNumber", definition.WorldNumber)
	model:SetAttribute("ModelName", definition.ModelName)
	model:SetAttribute("IsPetTemplate", true)
	if definition.IsLegendaryColorOrb then
		model:SetAttribute("IsLegendaryColorOrb", true)
	end
end

local function findPrimary(model)
	if model.PrimaryPart then
		return model.PrimaryPart
	end
	local core = model:FindFirstChild("Core", true)
	if core and core:IsA("BasePart") then
		model.PrimaryPart = core
		return core
	end
	local first = model:FindFirstChildWhichIsA("BasePart", true)
	if first then
		model.PrimaryPart = first
		return first
	end
	return nil
end

local function prepPart(part, anchored)
	part.Anchored = anchored ~= false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

local function findStudioSource()
	return ReplicatedStorage:FindFirstChild("PetAppearanceStudio") or Workspace:FindFirstChild("PetAppearanceStudio")
end

local function findStudioTemplate(petId)
	local source = findStudioSource()
	if not source then
		return nil
	end

	for _, eggFolder in ipairs(source:GetChildren()) do
		local petsFolder = eggFolder:FindFirstChild("Pets")
		local template = petsFolder and petsFolder:FindFirstChild(tostring(petId))
		if template and template:IsA("Model") then
			return template
		end
	end
	return nil
end

local function makePart(model, name, shape, size, cframe, color, material, transparency)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape or Enum.PartType.Ball
	part.Size = size
	part.CFrame = cframe or CFrame.new()
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Transparency = transparency or 0
	part:SetAttribute("NoTint", true)
	prepPart(part, true)
	part.Parent = model
	return part
end

local function stripPreviewOnly(root)
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:GetAttribute("PreviewOnly") == true
			or descendant:GetAttribute("MutationVisual") == true
			or (descendant:IsA("BillboardGui") and descendant.Name == "PreviewLabel")
		then
			descendant:Destroy()
		end
	end
end

local function addLight(core, color)
	local light = Instance.new("PointLight")
	light.Name = "TemplateGlow"
	light.Color = color
	light.Range = 8
	light.Brightness = 1.25
	light.Shadows = false
	light.Parent = core
end

function PetModelUtil.CreateFallbackTemplate(definition)
	local model = Instance.new("Model")
	model.Name = definition.ModelName or definition.Id
	applyTemplateAttributes(model, definition)
	model:SetAttribute("GeneratedFallbackTemplate", true)

	local coreColor = definition.IconColor or definition.BaseColor or Color3.fromRGB(180, 180, 220)
	local accent = definition.AccentColor or coreColor:Lerp(Color3.new(1, 1, 1), 0.35)
	local core = makePart(model, "Core", Enum.PartType.Ball, Vector3.new(1.8, 1.8, 1.8), CFrame.new(), coreColor, definition.UseRainbowGradient and Enum.Material.Neon or Enum.Material.SmoothPlastic)
	model.PrimaryPart = core
	addLight(core, accent)

	makePart(model, "Highlight", Enum.PartType.Ball, Vector3.new(0.42, 0.42, 0.16), CFrame.new(-0.46, 0.5, 0.78), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, 0.08)
	makePart(model, "GlowShell", Enum.PartType.Ball, Vector3.new(2.14, 2.14, 2.14), CFrame.new(), accent, Enum.Material.ForceField, definition.UseRainbowGradient and 0.55 or 0.78)

	if definition.UseRainbowGradient then
		for index, color in ipairs(RAINBOW_COLORS) do
			local y = -0.86 + index * 0.25
			makePart(
				model,
				"RainbowBand" .. tostring(index),
				Enum.PartType.Cylinder,
				Vector3.new(0.065, 2.25, 2.25),
				CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90 + (index % 2) * 7)),
				color,
				Enum.Material.Neon,
				0.42
			)
		end
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "PetAttachment"
	attachment.Parent = core
	return model
end

function PetModelUtil.FindTemplate(petId)
	local definition = PetDefinitions.Get(petId)
	if not definition then
		return nil, nil
	end

	local studioTemplate = findStudioTemplate(definition.Id)
	if studioTemplate then
		applyTemplateAttributes(studioTemplate, definition)
		if not findPrimary(studioTemplate) then
			warnOnce("missing-primary:" .. definition.Id, "PetModelUtil: " .. studioTemplate:GetFullName() .. " is missing a PrimaryPart/Core for pet " .. definition.Id)
		end
		return studioTemplate, definition
	end

	local folder = PetModelUtil.GetPetModelsFolder()
	local modelName = definition.ModelName
	local legendaryFolder = folder:FindFirstChild("LegendaryColorOrbs")
	local candidates = {}
	local function addCandidate(template)
		if template then
			table.insert(candidates, template)
		end
	end
	addCandidate(modelName and folder:FindFirstChild(modelName))
	addCandidate(folder:FindFirstChild(definition.Id))
	addCandidate(legendaryFolder and modelName and legendaryFolder:FindFirstChild(modelName))
	addCandidate(legendaryFolder and legendaryFolder:FindFirstChild(definition.Id))
	addCandidate(modelName and folder:FindFirstChild(modelName, true))

	local fallbackTemplate = nil
	for _, template in ipairs(candidates) do
		if template and template:IsA("Model") then
			if template:GetAttribute("GeneratedFallbackTemplate") == true then
				fallbackTemplate = fallbackTemplate or template
			else
				applyTemplateAttributes(template, definition)
				if not findPrimary(template) then
					warnOnce("missing-primary:" .. definition.Id, "PetModelUtil: " .. template:GetFullName() .. " is missing a PrimaryPart/Core for pet " .. definition.Id)
				end
				return template, definition
			end
		end
	end

	if fallbackTemplate then
		applyTemplateAttributes(fallbackTemplate, definition)
		if not findPrimary(fallbackTemplate) then
			warnOnce("missing-primary:" .. definition.Id, "PetModelUtil: " .. fallbackTemplate:GetFullName() .. " is missing a PrimaryPart/Core for pet " .. definition.Id)
		end
		return fallbackTemplate, definition
	end

	return nil, definition
end

function PetModelUtil.EnsureTemplate(petId)
	local template, definition = PetModelUtil.FindTemplate(petId)
	if template then
		return template, definition
	end
	if not definition then
		return nil, nil
	end

	local folder = PetModelUtil.GetPetModelsFolder()
	template = PetModelUtil.CreateFallbackTemplate(definition)
	template.Parent = folder
	return template, definition
end

local function getMutationData(mutationId)
	local mutation = ColorMutationData.get(mutationId)
	if not mutation or mutation.Id == ColorMutationData.NoneId then
		return nil
	end
	return mutation
end

local function makeMutationPart(model, name, shape, size, cframe, color, material, transparency)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape or Enum.PartType.Ball
	part.Size = size
	part.CFrame = cframe or CFrame.new()
	part.Color = color
	part.Material = material or Enum.Material.Neon
	part.Transparency = transparency or 0
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part:SetAttribute("MutationVisual", true)
	part:SetAttribute("PreviewOnly", true)
	part.Parent = model
	return part
end

local function tintModelForMutation(model, mutation)
	local typeColor = mutation.TypeColor or ColorMutationData.getTypeColor(mutation.Type)
	local auraColor = mutation.AuraColor or ColorMutationData.getTypeAura(mutation.Type)
	local tintStrength = mutation.Type == "Dark" and 0.62 or mutation.Type == "Light" and 0.38 or 0.5

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant:GetAttribute("NoMutationTint") ~= true then
			if descendant:GetAttribute("NoTint") == true and descendant.Name ~= "Core" and descendant.Name ~= "GlowShell" then
				continue
			end
			descendant.Color = descendant.Color:Lerp(typeColor, tintStrength)
			if mutation.Type == "Light" then
				descendant.Material = Enum.Material.Neon
			elseif mutation.Type == "Dark" then
				descendant.Material = descendant.Name == "Core" and Enum.Material.SmoothPlastic or Enum.Material.ForceField
			elseif mutation.Type == "Corrupted" then
				descendant.Material = Enum.Material.Neon
			end
		end
	end

	local primary = findPrimary(model)
	if primary then
		local light = primary:FindFirstChild("MutationGlow") or Instance.new("PointLight")
		light.Name = "MutationGlow"
		light.Color = auraColor
		light.Range = mutation.Type == "Light" and 13 or 10
		light.Brightness = mutation.Type == "Corrupted" and 2.1 or mutation.Type == "Light" and 1.8 or 1.25
		light.Shadows = false
		light:SetAttribute("MutationVisual", true)
		light.Parent = primary
	end
end

function PetModelUtil.ApplyMutationVisuals(model, mutationId)
	if not model or not model:IsA("Model") then
		return model
	end

	local mutation = getMutationData(mutationId)
	model:SetAttribute("MutationId", mutation and mutation.Id or ColorMutationData.NoneId)
	model:SetAttribute("MutationName", mutation and mutation.DisplayName or "Normal")
	if not mutation then
		return model
	end

	stripPreviewOnly(model)
	tintModelForMutation(model, mutation)

	local primary = findPrimary(model)
	if not primary then
		return model
	end

	local baseCFrame = primary.CFrame
	local auraColor = mutation.AuraColor or MUTATION_ACCENTS[mutation.Type] or Color3.fromRGB(255, 255, 255)
	local typeColor = mutation.TypeColor or auraColor

	makeMutationPart(model, "MutationAura", Enum.PartType.Ball, Vector3.new(2.75, 2.75, 2.75), baseCFrame, auraColor, Enum.Material.ForceField, mutation.Type == "Dark" and 0.45 or 0.62)

	if mutation.Type == "Dark" then
		makeMutationPart(model, "DarkMist", Enum.PartType.Ball, Vector3.new(3.15, 1.2, 3.15), baseCFrame * CFrame.new(0, -0.25, 0), Color3.fromRGB(25, 12, 45), Enum.Material.ForceField, 0.52)
		makeMutationPart(model, "EclipseRing", Enum.PartType.Cylinder, Vector3.new(0.08, 3.45, 3.45), baseCFrame * CFrame.Angles(0, 0, math.rad(90)), typeColor, Enum.Material.Neon, 0.24)
	elseif mutation.Type == "Light" then
		makeMutationPart(model, "LightHalo", Enum.PartType.Cylinder, Vector3.new(0.08, 2.55, 2.55), baseCFrame * CFrame.new(0, 1.65, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 245, 155), Enum.Material.Neon, 0.08)
		makeMutationPart(model, "RadiantShell", Enum.PartType.Ball, Vector3.new(3.15, 3.15, 3.15), baseCFrame, Color3.fromRGB(255, 255, 210), Enum.Material.ForceField, 0.72)
	elseif mutation.Type == "Corrupted" then
		makeMutationPart(model, "GlitchShardA", Enum.PartType.Block, Vector3.new(0.22, 0.8, 0.22), baseCFrame * CFrame.new(1.35, 0.45, 0) * CFrame.Angles(math.rad(18), math.rad(35), math.rad(10)), Color3.fromRGB(255, 42, 84), Enum.Material.Neon, 0.05)
		makeMutationPart(model, "GlitchShardB", Enum.PartType.Block, Vector3.new(0.18, 0.7, 0.18), baseCFrame * CFrame.new(-1.25, -0.15, 0.45) * CFrame.Angles(math.rad(-14), math.rad(-25), math.rad(20)), Color3.fromRGB(70, 230, 255), Enum.Material.Neon, 0.05)
		makeMutationPart(model, "ErrorRing", Enum.PartType.Cylinder, Vector3.new(0.08, 3.05, 3.05), baseCFrame * CFrame.Angles(math.rad(25), 0, math.rad(90)), Color3.fromRGB(255, 35, 105), Enum.Material.Neon, 0.18)
	end

	return model
end

function PetModelUtil.PrepareModel(model, options)
	options = options or {}
	if not model or not model:IsA("Model") then
		return nil
	end

	stripPreviewOnly(model)

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			prepPart(descendant, options.anchored)
		end
	end

	local primary = findPrimary(model)
	if not primary then
		warnOnce("clone-missing-primary:" .. model.Name, "PetModelUtil: cloned pet model " .. model.Name .. " has no PrimaryPart/Core.")
	end

	if options.mutationId then
		PetModelUtil.ApplyMutationVisuals(model, options.mutationId)
	end

	return model
end

function PetModelUtil.ClonePetModel(petId, options)
	local template, definition = PetModelUtil.EnsureTemplate(petId)
	if not template then
		return nil, definition
	end

	local clone = template:Clone()
	clone.Name = (definition and definition.Id or petId) .. "Model"
	PetModelUtil.PrepareModel(clone, options)
	return clone, definition
end

function PetModelUtil.MountViewport(viewport, petId, options)
	options = options or {}
	viewport:ClearAllChildren()

	local world = Instance.new("WorldModel")
	world.Name = "PetPreviewWorld"
	world.Parent = viewport

	local camera = Instance.new("Camera")
	camera.Name = "PetPreviewCamera"
	camera.FieldOfView = options.fieldOfView or 32
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local model = PetModelUtil.ClonePetModel(petId, { anchored = true, removeBillboards = true, mutationId = options.mutationId })
	if not model then
		return nil
	end

	model.Parent = world
	local primary = findPrimary(model)
	if not primary then
		return model
	end

	local extents = model:GetExtentsSize()
	local largest = math.max(extents.X, extents.Y, extents.Z)
	local targetSize = options.targetSize or 3.1
	if largest > 0 and largest > targetSize then
		pcall(function()
			model:ScaleTo(targetSize / largest)
		end)
	end

	model:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(options.yaw or 180), 0))
	camera.CFrame = CFrame.new(0, options.cameraY or 0.55, options.cameraZ or 7) * CFrame.Angles(math.rad(options.pitch or -5), 0, 0)
	return model
end

return PetModelUtil
