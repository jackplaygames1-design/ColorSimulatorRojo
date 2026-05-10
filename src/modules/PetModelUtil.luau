local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetDefinitions = require(script.Parent:WaitForChild("PetDefinitions"))

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
		if descendant:GetAttribute("PreviewOnly") == true then
			descendant:Destroy()
		elseif descendant:IsA("BillboardGui") and descendant.Name == "PreviewLabel" then
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

	local model = PetModelUtil.ClonePetModel(petId, { anchored = true, removeBillboards = true })
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
