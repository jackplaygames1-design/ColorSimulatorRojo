local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local PetData = require(ReplicatedStorage:WaitForChild("PetData"))
local PetDefinitions = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PetDefinitions"))

local PetVisualService = {}

local SOURCE_NAME = "PetAppearanceStudio"
local EGG_MODELS_FOLDER_NAME = "EggModels"
local RNG = Random.new()

local sourceFolder

local function isVisualObject(object)
	return object and (object:IsA("Model") or object:IsA("BasePart"))
end

local function getPetModelsFolder()
	local folder = ReplicatedStorage:FindFirstChild("PetModels")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "PetModels"
		folder.Parent = ReplicatedStorage
	end
	return folder
end

local function getSourceFolder(optional)
	if sourceFolder and sourceFolder.Parent then
		return sourceFolder
	end

	sourceFolder = ReplicatedStorage:FindFirstChild(SOURCE_NAME)
		or Workspace:FindFirstChild(SOURCE_NAME)
		or ServerStorage:FindFirstChild(SOURCE_NAME)
	if not sourceFolder and not optional then
		warn("PetVisualService: missing Workspace." .. SOURCE_NAME .. ". Run the StudioPetAppearanceBuilder command to create it.")
	end
	return sourceFolder
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

local function stripPreviewOnly(root)
	if root:GetAttribute("PreviewOnly") == true then
		root:Destroy()
		return nil
	end

	for _, object in ipairs(root:GetDescendants()) do
		if object:GetAttribute("PreviewOnly") == true then
			object:Destroy()
		end
	end

	return root
end

local function prepareRuntimeClone(clone, options)
	options = options or {}
	clone = stripPreviewOnly(clone)
	if not clone then
		return nil
	end

	for _, object in ipairs(clone:GetDescendants()) do
		if object:IsA("BasePart") then
			object.CanCollide = false
			object.Massless = true
			object.CastShadow = object.CastShadow == true
			if options.Unanchor == true then
				object.Anchored = false
			end
		end
	end

	if clone:IsA("BasePart") then
		clone.CanCollide = false
		clone.Massless = true
		clone.CastShadow = clone.CastShadow == true
		if options.Unanchor == true then
			clone.Anchored = false
		end
	end

	return clone
end

local function wrapBasePartAsModel(part, modelName)
	local model = Instance.new("Model")
	model.Name = modelName
	part.Name = part.Name ~= "" and part.Name or "Core"
	part.Parent = model
	model.PrimaryPart = part
	return model
end

local function cloneAsModel(template, modelName, options)
	if not isVisualObject(template) then
		return nil
	end

	local clone = template:Clone()
	clone = prepareRuntimeClone(clone, options)
	if not clone then
		return nil
	end

	if clone:IsA("BasePart") then
		clone = wrapBasePartAsModel(clone, modelName)
	end

	clone.Name = modelName
	findPrimary(clone)
	return clone
end

local function getEggFolder(eggId)
	local source = getSourceFolder(true)
	return source and source:FindFirstChild(tostring(eggId))
end

local function getPetsFolder(eggId)
	local eggFolder = getEggFolder(eggId)
	return eggFolder and eggFolder:FindFirstChild("Pets")
end

local function getSourcePetTemplate(eggId, petId)
	local petsFolder = getPetsFolder(eggId)
	return petsFolder and petsFolder:FindFirstChild(tostring(petId))
end

local function getDefinitionModelName(petId)
	local definition = PetDefinitions.Get(petId)
	return (definition and definition.ModelName) or tostring(petId)
end

local function clearPublishedTemplates(folder)
	for _, child in ipairs(folder:GetChildren()) do
		if child:GetAttribute("FromPetAppearanceStudio") == true then
			child:Destroy()
		end
	end
end

local function removeGeneratedMutationFolders(source)
	for _, eggFolder in ipairs(source:GetChildren()) do
		local petsFolder = eggFolder:FindFirstChild("Pets")
		if not petsFolder then
			continue
		end
		for _, child in ipairs(petsFolder:GetChildren()) do
			if child:IsA("Folder") and string.match(child.Name, "_Mutations$") then
				child:Destroy()
			end
		end
	end
end

function PetVisualService.GetSourceFolder()
	return getSourceFolder(false)
end

function PetVisualService.GetEggIds()
	local source = getSourceFolder(true)
	local eggIds = {}
	if not source then
		return eggIds
	end

	for _, child in ipairs(source:GetChildren()) do
		if child:IsA("Folder") or child:IsA("Model") then
			table.insert(eggIds, child.Name)
		end
	end
	table.sort(eggIds)
	return eggIds
end

function PetVisualService.GetPetIds(eggId)
	local petIds = {}
	local petsFolder = getPetsFolder(eggId)
	if not petsFolder then
		return petIds
	end

	for _, pet in ipairs(petsFolder:GetChildren()) do
		if isVisualObject(pet) then
			table.insert(petIds, pet.Name)
		end
	end
	table.sort(petIds)
	return petIds
end

function PetVisualService.ClonePet(eggId, petId, options)
	local template = getSourcePetTemplate(eggId, petId)
	if not template then
		return nil
	end

	local modelName = getDefinitionModelName(petId)
	local clone = cloneAsModel(template, modelName, options)
	if not clone then
		return nil
	end

	clone:SetAttribute("EggId", eggId)
	clone:SetAttribute("PetId", petId)
	return clone
end

function PetVisualService.CloneEgg(eggId, options)
	local eggFolder = getEggFolder(eggId)
	local eggModel = eggFolder and eggFolder:FindFirstChild("EggModel")
	if not isVisualObject(eggModel) then
		return nil
	end

	local clone = cloneAsModel(eggModel, tostring(eggId) .. "_Egg", options)
	if clone then
		clone:SetAttribute("EggId", eggId)
	end
	return clone
end

function PetVisualService.ChooseRandomPet(eggId)
	local petsFolder = getPetsFolder(eggId)
	if not petsFolder then
		return nil
	end

	local weightedPets = {}
	local totalWeight = 0
	for _, pet in ipairs(petsFolder:GetChildren()) do
		if isVisualObject(pet) then
			local weight = tonumber(pet:GetAttribute("Weight")) or 1
			if weight > 0 then
				totalWeight += weight
				table.insert(weightedPets, {
					PetId = pet.Name,
					Weight = weight,
				})
			end
		end
	end

	if totalWeight <= 0 then
		return nil
	end

	local roll = RNG:NextNumber(0, totalWeight)
	local runningWeight = 0
	for _, pet in ipairs(weightedPets) do
		runningWeight += pet.Weight
		if roll <= runningWeight then
			return pet.PetId
		end
	end
	return weightedPets[#weightedPets] and weightedPets[#weightedPets].PetId or nil
end

function PetVisualService.PublishToReplicatedStorage()
	local source = getSourceFolder(true)
	if not source then
		return 0
	end

	local published = 0
	local petModelsFolder = getPetModelsFolder()
	clearPublishedTemplates(petModelsFolder)
	removeGeneratedMutationFolders(source)

	local eggModelsFolder = petModelsFolder:FindFirstChild(EGG_MODELS_FOLDER_NAME)
	if not eggModelsFolder then
		eggModelsFolder = Instance.new("Folder")
		eggModelsFolder.Name = EGG_MODELS_FOLDER_NAME
		eggModelsFolder.Parent = petModelsFolder
	end
	clearPublishedTemplates(eggModelsFolder)

	for eggId, egg in pairs(PetData.Eggs or {}) do
		local eggFolder = source:FindFirstChild(eggId)
		local eggModel = eggFolder and eggFolder:FindFirstChild("EggModel")
		if isVisualObject(eggModel) then
			local publishedEgg = cloneAsModel(eggModel, tostring(eggId), { Unanchor = false })
			if publishedEgg then
				publishedEgg:SetAttribute("FromPetAppearanceStudio", true)
				publishedEgg:SetAttribute("EggId", eggId)
				publishedEgg.Parent = eggModelsFolder
			end
		end

		local petsFolder = eggFolder and eggFolder:FindFirstChild("Pets")
		if petsFolder then
			for _, entry in ipairs(egg.pets or {}) do
				local petId = entry.petId
				local template = petId and petsFolder:FindFirstChild(petId)
				if isVisualObject(template) then
					local modelName = getDefinitionModelName(petId)
					local clone = cloneAsModel(template, modelName, { Unanchor = false })
					if clone then
						clone:SetAttribute("FromPetAppearanceStudio", true)
						clone:SetAttribute("EggId", eggId)
						clone:SetAttribute("PetId", petId)
						clone:SetAttribute("DisplayName", template:GetAttribute("DisplayName") or PetData.GetCompanionDisplayName(petId))
						clone:SetAttribute("Rarity", template:GetAttribute("Rarity") or (PetData.Pets[petId] and PetData.Pets[petId].rarity) or "Common")
						clone.Parent = petModelsFolder
						published += 1
					end
				end
			end
		end
	end

	if source.Parent ~= ReplicatedStorage then
		source.Parent = ReplicatedStorage
		source:SetAttribute("RuntimeTemplateSource", true)
	end

	return published
end

return PetVisualService
