-- Tags user-built distant sector models so gameplay systems treat them as landmarks,
-- not color zones or spawn surfaces.
local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

local MAP_NAME = "ColorSimulatorMap"
local DISTANT_SECTORS_FOLDER = "DistantSectors"

local SECTOR_MODELS = {
	sector1 = {
		displayName = "Orange Sector",
		sectorColor = "Orange",
		sectorIndex = 2,
		locked = false,
		playable = true,
	},
}

local function getOrCreateDistantSectorsFolder()
	local map = Workspace:FindFirstChild(MAP_NAME)
	if not map then
		return nil
	end

	local folder = map:FindFirstChild(DISTANT_SECTORS_FOLDER)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = DISTANT_SECTORS_FOLDER
		folder.Parent = map
	end
	return folder
end

local function applySectorAttributes(instance, config)
	instance:SetAttribute("DistantSectorColumn", true)
	instance:SetAttribute("SectorAnchor", true)
	instance:SetAttribute("DecorativeOnly", false)
	instance:SetAttribute("SectorName", config.displayName)
	instance:SetAttribute("SectorColor", config.sectorColor)
	instance:SetAttribute("SectorIndex", config.sectorIndex)
	instance:SetAttribute("SectorLocked", config.locked == true)
	instance:SetAttribute("ColorZone", false)
	instance:SetAttribute("ColorBlobSpawn", false)
	instance:SetAttribute("AreaGate", false)
	instance:SetAttribute("GateInteraction", false)
	instance:SetAttribute("ColorType", config.sectorColor)
end

local function getAncestorNamed(instance, name)
	local current = instance
	while current do
		if string.lower(current.Name or "") == string.lower(name) then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function isEggPart(part, config)
	local loweredColor = string.lower(config.sectorColor or "")
	local current = part
	while current do
		local loweredName = string.lower(current.Name or "")
		if string.find(loweredName, "egg") and string.find(loweredName, loweredColor) then
			return true
		end
		current = current.Parent
	end
	return false
end

local function applyPlayableFloorAttributes(part, config)
	part:SetAttribute("DistantSectorColumn", false)
	part:SetAttribute("SectorAnchor", false)
	part:SetAttribute("DecorativeOnly", false)
	part:SetAttribute("PlayableSectorFloor", true)
	part:SetAttribute("SectorName", config.displayName)
	part:SetAttribute("SectorColor", config.sectorColor)
	part:SetAttribute("SectorIndex", config.sectorIndex)
	part:SetAttribute("SectorLocked", config.locked == true)
	part:SetAttribute("ColorZone", true)
	part:SetAttribute("ColorBlobSpawn", false)
	part:SetAttribute("AreaGate", false)
	part:SetAttribute("GateInteraction", false)
	part:SetAttribute("ColorType", config.sectorColor)
	part:SetAttribute("AreaColor", config.sectorColor)
end

local function ensureEggPrompt(part)
	local prompt = part:FindFirstChild("EggShopPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "EggShopPrompt"
		prompt.Parent = part
	end

	prompt.ActionText = "Hatch"
	prompt.ObjectText = "Egg"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = math.max(prompt.MaxActivationDistance, 18)
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt:SetAttribute("EggShopPrompt", true)
	return prompt
end

local function applyEggAttributes(part, config)
	part:SetAttribute("DistantSectorColumn", false)
	part:SetAttribute("SectorAnchor", false)
	part:SetAttribute("DecorativeOnly", false)
	part:SetAttribute("PlayableSectorFloor", false)
	part:SetAttribute("ColorZone", false)
	part:SetAttribute("ColorBlobSpawn", false)
	part:SetAttribute("EggStation", true)
	part:SetAttribute("EggId", config.sectorColor .. "Egg")
	part:SetAttribute("ColorType", config.sectorColor)
	part:SetAttribute("AreaColor", config.sectorColor)
	part.CanCollide = true
	part.CanTouch = false
	part.CanQuery = true
	ensureEggPrompt(part)
end

local function isLargeHorizontalFloor(part)
	local size = part.Size
	local horizontalArea = size.X * size.Z
	local smallestHorizontal = math.max(1, math.min(size.X, size.Z))
	return size.X >= 35 and size.Z >= 35 and horizontalArea >= 1600 and size.Y <= smallestHorizontal * 0.28
end

local function shouldBePlayableFloor(part, config)
	if part:GetAttribute("PlayableSectorFloor") == true then
		return true
	end
	if isEggPart(part, config) then
		return false
	end
	if part:GetAttribute("BrushShop") or part:GetAttribute("ShopStation") or part:GetAttribute("CombinedShop") then
		return false
	end
	return isLargeHorizontalFloor(part)
end

local function setupSectorModel(model, config)
	if not model or not model.Parent then
		return false
	end

	local folder = not config.playable and getOrCreateDistantSectorsFolder() or nil
	if folder and not config.playable and model.Parent ~= folder then
		model.Parent = folder
	end

	model:SetAttribute("SectorName", config.displayName)
	model:SetAttribute("SectorColor", config.sectorColor)
	model:SetAttribute("SectorIndex", config.sectorIndex)
	model:SetAttribute("SectorLocked", config.locked == true)
	model:SetAttribute("ColorType", config.sectorColor)
	model:SetAttribute("DecorativeOnly", config.playable ~= true)

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = true
			descendant.CanTouch = false
			descendant.CanQuery = true
			if config.playable and isEggPart(descendant, config) then
				applyEggAttributes(descendant, config)
			elseif config.playable and shouldBePlayableFloor(descendant, config) then
				applyPlayableFloorAttributes(descendant, config)
			else
				applySectorAttributes(descendant, config)
			end
		end
	end

	local eggModel = getAncestorNamed(model, config.sectorColor .. "Egg") or model:FindFirstChild(config.sectorColor .. "Egg", true)
	if eggModel then
		if eggModel:IsA("BasePart") then
			applyEggAttributes(eggModel, config)
		else
			for _, descendant in ipairs(eggModel:GetDescendants()) do
				if descendant:IsA("BasePart") then
					applyEggAttributes(descendant, config)
				end
			end
		end
	end

	if config.playable then
		local populateRequest = ServerScriptService:FindFirstChild("RequestPopulateColorZone")
		if populateRequest and populateRequest:IsA("BindableEvent") then
			task.defer(function()
				populateRequest:Fire(config.sectorColor)
			end)
			task.delay(3, function()
				populateRequest:Fire(config.sectorColor)
			end)
		end
	end

	return true
end

local function setupAllSectorModels()
	for name, config in pairs(SECTOR_MODELS) do
		local model = Workspace:FindFirstChild(name)
		if not model then
			local map = Workspace:FindFirstChild(MAP_NAME)
			model = map and map:FindFirstChild(name, true)
		end

		if model then
			setupSectorModel(model, config)
		end
	end
end

task.defer(setupAllSectorModels)
task.delay(2, setupAllSectorModels)

Workspace.ChildAdded:Connect(function(child)
	local config = SECTOR_MODELS[string.lower(child.Name)]
	if config then
		task.defer(function()
			setupSectorModel(child, config)
		end)
	end
end)
