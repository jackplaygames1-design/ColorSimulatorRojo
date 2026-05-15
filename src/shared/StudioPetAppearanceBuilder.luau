local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ColorData = require(ReplicatedStorage:WaitForChild("ColorData"))
local ColorMutationData = require(ReplicatedStorage:WaitForChild("ColorMutationData"))
local PetData = require(ReplicatedStorage:WaitForChild("PetData"))
local PetModelUtil = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PetModelUtil"))

local StudioPetAppearanceBuilder = {}

local SOURCE_NAME = "PetAppearanceStudio"
local ORIGIN = Vector3.new(50000, 5000, 50000)
local ROW_SPACING = 35
local PET_SPACING = 14
local MUTATION_SPACING = 8

local function isVisualObject(object)
	return object and (object:IsA("Model") or object:IsA("BasePart"))
end

local function getOrCreateSource()
	local source = Workspace:FindFirstChild(SOURCE_NAME)
	if not source then
		source = Instance.new("Folder")
		source.Name = SOURCE_NAME
		source:SetAttribute("EditablePetAppearanceSource", true)
		source.Parent = Workspace
	end
	return source
end

local function getSortedChildren(parent)
	local children = parent:GetChildren()
	table.sort(children, function(a, b)
		return a.Name < b.Name
	end)
	return children
end

local function getOrCreateFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end
	return folder
end

local function makePreviewPart(model, name, shape, size, cframe, color, material, transparency)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape or Enum.PartType.Ball
	part.Size = size
	part.CFrame = cframe or CFrame.new()
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Transparency = transparency or 0
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Parent = model
	return part
end

local function createEggModel(eggId, egg)
	local model = Instance.new("Model")
	model.Name = "EggModel"
	model:SetAttribute("EggId", eggId)
	model:SetAttribute("DisplayName", egg.displayName or eggId)

	local color = egg.color or Color3.fromRGB(255, 255, 255)
	local dark = color:Lerp(Color3.fromRGB(30, 32, 42), 0.32)
	local light = color:Lerp(Color3.fromRGB(255, 255, 255), 0.5)

	local core = makePreviewPart(
		model,
		"Core",
		Enum.PartType.Ball,
		Vector3.new(4.4, 5.4, 4.4),
		CFrame.new(0, 2.7, 0),
		color,
		Enum.Material.SmoothPlastic
	)
	model.PrimaryPart = core
	makePreviewPart(
		model,
		"LowerBand",
		Enum.PartType.Cylinder,
		Vector3.new(0.26, 4.7, 4.7),
		CFrame.new(0, 1.55, 0) * CFrame.Angles(0, 0, math.rad(90)),
		dark,
		Enum.Material.SmoothPlastic,
		0.05
	)
	makePreviewPart(
		model,
		"UpperBand",
		Enum.PartType.Cylinder,
		Vector3.new(0.22, 3.9, 3.9),
		CFrame.new(0, 3.72, 0) * CFrame.Angles(0, 0, math.rad(90)),
		light,
		Enum.Material.SmoothPlastic,
		0.12
	)
	makePreviewPart(
		model,
		"Highlight",
		Enum.PartType.Ball,
		Vector3.new(0.8, 1.15, 0.24),
		CFrame.new(-1.2, 4, -1.6) * CFrame.Angles(0, math.rad(-25), math.rad(-15)),
		Color3.fromRGB(255, 255, 255),
		Enum.Material.SmoothPlastic,
		0.1
	)

	local lightObject = Instance.new("PointLight")
	lightObject.Name = "EggGlow"
	lightObject.Color = color
	lightObject.Brightness = 1.1
	lightObject.Range = 12
	lightObject.Parent = core

	return model
end

local function applyPetAttributes(petObject, eggId, entry)
	local pet = PetData.Pets[entry.petId]
	petObject:SetAttribute("EggId", eggId)
	petObject:SetAttribute("PetId", entry.petId)
	petObject:SetAttribute("Weight", tonumber(entry.chance) or tonumber(entry.weight) or 1)
	petObject:SetAttribute("Rarity", pet and pet.rarity or "Common")
	petObject:SetAttribute("DisplayName", pet and pet.displayName or entry.petId)
end

local function createPetTemplate(entry)
	local petId = entry.petId
	local clone = PetModelUtil.ClonePetModel(petId, { anchored = true, removeBillboards = true })
	if clone and clone:IsA("Model") then
		clone.Name = petId
		return clone
	end

	local pet = PetData.Pets[petId]
	if not pet then
		return nil
	end

	local model = Instance.new("Model")
	model.Name = petId
	local core = makePreviewPart(
		model,
		"Core",
		Enum.PartType.Ball,
		Vector3.new(2.2, 2.2, 2.2),
		CFrame.new(0, 1.1, 0),
		pet.color or Color3.fromRGB(255, 255, 255),
		Enum.Material.SmoothPlastic
	)
	model.PrimaryPart = core
	return model
end

local function preparePreviewObject(object)
	for _, part in ipairs(object:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
		end
	end

	if object:IsA("BasePart") then
		object.Anchored = true
		object.CanCollide = false
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

local function pivotObject(object, cframe)
	if object:IsA("Model") then
		findPrimary(object)
		object:PivotTo(cframe)
	elseif object:IsA("BasePart") then
		object.CFrame = cframe
	end
end

local function getBounds(object)
	if object:IsA("Model") then
		return object:GetBoundingBox()
	elseif object:IsA("BasePart") then
		return object.CFrame, object.Size
	end
	return CFrame.new(), Vector3.new(4, 4, 4)
end

local function placeOnGround(object, position, yawDegrees)
	preparePreviewObject(object)
	local yaw = math.rad(yawDegrees or 0)
	pivotObject(object, CFrame.new(position) * CFrame.Angles(0, yaw, 0))

	local boundsCFrame, boundsSize = getBounds(object)
	local bottomY = boundsCFrame.Position.Y - boundsSize.Y / 2
	local yOffset = ORIGIN.Y - bottomY
	local currentCFrame = object:IsA("Model") and object:GetPivot() or object.CFrame
	pivotObject(object, currentCFrame + Vector3.new(0, yOffset, 0))
end

local function addPreviewLabel(object, text)
	local oldLabel = object:FindFirstChild("PreviewLabel", true)
	if oldLabel and oldLabel:GetAttribute("PreviewOnly") == true then
		oldLabel:Destroy()
	end

	local holder
	if object:IsA("Model") then
		holder = findPrimary(object)
	elseif object:IsA("BasePart") then
		holder = object
	end
	if not holder then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PreviewLabel"
	billboard:SetAttribute("PreviewOnly", true)
	billboard.Size = UDim2.fromOffset(190, 64)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = holder

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label:SetAttribute("PreviewOnly", true)
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = billboard
end

local function removeMutationVariantFolders(petsFolder)
	for _, child in ipairs(petsFolder:GetChildren()) do
		if child:IsA("Folder") and string.match(child.Name, "_Mutations$") then
			child:Destroy()
		end
	end
end

function StudioPetAppearanceBuilder.Build()
	local source = getOrCreateSource()
	local createdPets = 0
	local createdEggs = 0

	for _, eggId in ipairs(PetData.EggOrder or {}) do
		local egg = PetData.Eggs[eggId]
		if not egg then
			continue
		end

		local eggFolder = getOrCreateFolder(source, eggId)
		eggFolder:SetAttribute("EggId", eggId)
		eggFolder:SetAttribute("DisplayName", egg.displayName or eggId)

		if not isVisualObject(eggFolder:FindFirstChild("EggModel")) then
			local eggModel = createEggModel(eggId, egg)
			eggModel.Parent = eggFolder
			createdEggs += 1
		end

		local petsFolder = getOrCreateFolder(eggFolder, "Pets")
		removeMutationVariantFolders(petsFolder)
		for _, entry in ipairs(egg.pets or {}) do
			if not entry.petId then
				continue
			end
			entry.eggId = eggId
			local petObject = petsFolder:FindFirstChild(entry.petId)
			if not isVisualObject(petObject) then
				petObject = createPetTemplate(entry)
				if petObject then
					petObject.Parent = petsFolder
					createdPets += 1
				end
			end
			if petObject then
				applyPetAttributes(petObject, eggId, entry)
			end
		end
	end

	StudioPetAppearanceBuilder.Arrange()
	print("StudioPetAppearanceBuilder: ready at Workspace." .. SOURCE_NAME .. " with editable pet templates only.")
	return source
end

function StudioPetAppearanceBuilder.Arrange()
	local source = getOrCreateSource()
	local row = 0

	for _, eggFolder in ipairs(getSortedChildren(source)) do
		if not (eggFolder:IsA("Folder") or eggFolder:IsA("Model")) then
			continue
		end

		local rowOrigin = ORIGIN + Vector3.new(0, 0, row * ROW_SPACING)
		local eggModel = eggFolder:FindFirstChild("EggModel")
		if isVisualObject(eggModel) then
			placeOnGround(eggModel, rowOrigin, 0)
			addPreviewLabel(eggModel, eggFolder.Name .. "\nEGG")
		end

		local petsFolder = eggFolder:FindFirstChild("Pets")
		if petsFolder then
			local column = 1
			for _, pet in ipairs(getSortedChildren(petsFolder)) do
				if pet:IsA("Folder") then
					local mutationColumn = column
					for _, mutationModel in ipairs(getSortedChildren(pet)) do
						if isVisualObject(mutationModel) then
							local mutationPosition = rowOrigin
								+ Vector3.new(mutationColumn * PET_SPACING, 0, MUTATION_SPACING)
							placeOnGround(mutationModel, mutationPosition, 0)
							addPreviewLabel(
								mutationModel,
								mutationModel:GetAttribute("MutationId") or mutationModel.Name
							)
							mutationColumn += 1
						end
					end
				elseif isVisualObject(pet) then
					local petPosition = rowOrigin + Vector3.new(column * PET_SPACING, 0, 0)
					placeOnGround(pet, petPosition, 0)

					local rarity = pet:GetAttribute("Rarity")
					local weight = pet:GetAttribute("Weight")
					local labelText = pet.Name
					if rarity then
						labelText ..= "\n" .. tostring(rarity)
					end
					if weight ~= nil then
						labelText ..= "\nWeight: " .. tostring(weight)
					end
					addPreviewLabel(pet, labelText)
					column += 1
				end
			end
		end

		row += 1
	end

	print("StudioPetAppearanceBuilder: arranged mutation previews at " .. tostring(ORIGIN) .. ".")
	return source
end

StudioPetAppearanceBuilder.BuildAndArrange = StudioPetAppearanceBuilder.Build

return StudioPetAppearanceBuilder
