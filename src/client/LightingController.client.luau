local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local LightingPresets = require(ReplicatedStorage:WaitForChild("LightingPresets"))

local player = Players.LocalPlayer

local areaParts = {}
local currentPresetName = nil
local currentSkyName = nil
local lastScan = 0
local activeTweens = {}
local currentWorldConnection = nil
local colorStorageConnection = nil

local function ensureEffect(className, name)
	local existing = Lighting:FindFirstChild(name)
	if existing and existing:IsA(className) then
		return existing
	end

	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA(className) and child.Name == name then
			return child
		end
	end

	local effect = Instance.new(className)
	effect.Name = name
	effect:SetAttribute("ColorSimulatorLightingController", true)
	effect.Parent = Lighting
	return effect
end

local function getEffects()
	local names = LightingPresets.EffectNames
	return {
		Atmosphere = ensureEffect("Atmosphere", names.Atmosphere),
		Bloom = ensureEffect("BloomEffect", names.Bloom),
		ColorCorrection = ensureEffect("ColorCorrectionEffect", names.ColorCorrection),
		DepthOfField = ensureEffect("DepthOfFieldEffect", names.DepthOfField),
	}
end

local function tweenProperties(instance, properties, tweenInfo)
	if not instance or type(properties) ~= "table" then
		return
	end

	local tweenable = {}
	for propertyName, value in pairs(properties) do
		if typeof(value) == "boolean" then
			instance[propertyName] = value
		else
			tweenable[propertyName] = value
		end
	end

	if next(tweenable) then
		local tweenKey = tostring(instance)
		if activeTweens[tweenKey] then
			activeTweens[tweenKey]:Cancel()
		end
		local tween = TweenService:Create(instance, tweenInfo, tweenable)
		activeTweens[tweenKey] = tween
		tween.Completed:Connect(function()
			if activeTweens[tweenKey] == tween then
				activeTweens[tweenKey] = nil
			end
		end)
		tween:Play()
	end
end

local function findSkyInFolder(skyName)
	local folderName = LightingPresets.SkyFolderName
	local skyFolder = folderName and Lighting:FindFirstChild(folderName)
	if not skyFolder then
		return nil
	end

	local namedSky = skyFolder:FindFirstChild(skyName)
	if namedSky and namedSky:IsA("Sky") then
		return namedSky
	end

	local defaultSkyName = LightingPresets.DefaultSkyName
	local defaultSky = defaultSkyName and skyFolder:FindFirstChild(defaultSkyName)
	if defaultSky and defaultSky:IsA("Sky") then
		return defaultSky
	end

	return nil
end

local function findAttributedSky(skyName, presetName)
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("Sky") and child.Name ~= (LightingPresets.ActiveSkyName or "ColorSimulatorActiveSky") then
			local lightingPreset = child:GetAttribute("LightingPreset")
			local sectorSky = child:GetAttribute("SectorSky")
			if
				lightingPreset == skyName
				or lightingPreset == presetName
				or sectorSky == skyName
				or sectorSky == presetName
			then
				return child
			end
		end
	end

	return nil
end

local function applySky(presetName, preset)
	local skyName = preset.Sky or presetName
	if type(skyName) ~= "string" or skyName == "" then
		return
	end

	local template = findSkyInFolder(skyName) or findAttributedSky(skyName, presetName)
	if not template then
		local activeSky = Lighting:FindFirstChild(LightingPresets.ActiveSkyName or "ColorSimulatorActiveSky")
		if activeSky and activeSky:IsA("Sky") then
			activeSky:Destroy()
		end
		currentSkyName = nil
		return
	end

	local activeSkyName = LightingPresets.ActiveSkyName or "ColorSimulatorActiveSky"
	local activeSky = Lighting:FindFirstChild(activeSkyName)
	local sourceName = template:GetAttribute("SourceSkyName") or template.Name
	if activeSky and activeSky:IsA("Sky") and currentSkyName == sourceName then
		return
	end

	if activeSky and activeSky:IsA("Sky") then
		activeSky:Destroy()
	end

	local sky = template:Clone()
	sky.Name = activeSkyName
	sky:SetAttribute("ColorSimulatorLightingController", true)
	sky:SetAttribute("SourceSkyName", sourceName)
	sky.Parent = Lighting
	currentSkyName = sourceName
end

local function applyPreset(presetName)
	if currentPresetName == presetName then
		return
	end

	local preset = LightingPresets.Presets[presetName]
	if not preset then
		return
	end

	currentPresetName = presetName
	local tweenInfo =
		TweenInfo.new(LightingPresets.TransitionTime or 0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local effects = getEffects()

	applySky(presetName, preset)
	tweenProperties(Lighting, preset.Lighting, tweenInfo)
	tweenProperties(effects.Atmosphere, preset.Atmosphere, tweenInfo)
	tweenProperties(effects.Bloom, preset.Bloom, tweenInfo)
	tweenProperties(effects.ColorCorrection, preset.ColorCorrection, tweenInfo)
	tweenProperties(effects.DepthOfField, preset.DepthOfField, tweenInfo)
end

local function getRootPosition()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root and root.Position or nil
end

local function getGroundContact()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil, nil
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = true

	local distance = tonumber(LightingPresets.GroundProbeDistance) or 28
	local result = Workspace:Raycast(root.Position, Vector3.new(0, -distance, 0), params)
	if not result then
		return nil, nil
	end

	return result.Position, result.Instance
end

local function pointIsInsidePart(position, part)
	local localPosition = part.CFrame:PointToObjectSpace(position)
	local halfSize = part.Size * 0.5
	return math.abs(localPosition.X) <= halfSize.X
		and math.abs(localPosition.Y) <= halfSize.Y + 8
		and math.abs(localPosition.Z) <= halfSize.Z
end

local function pointIsOnTopSurface(position, part)
	local localPosition = part.CFrame:PointToObjectSpace(position)
	local halfSize = part.Size * 0.5
	return math.abs(localPosition.X) <= halfSize.X
		and math.abs(localPosition.Z) <= halfSize.Z
		and math.abs(localPosition.Y - halfSize.Y) <= 3
end

local function nameMatches(part, rule)
	for _, fragment in ipairs(rule.NameContains or {}) do
		if string.find(string.lower(part.Name), string.lower(fragment), 1, true) then
			return true
		end
	end
	return false
end

local function attributeMatches(part, rule)
	for attributeName, expectedValue in pairs(rule.PartAttributes or {}) do
		if part:GetAttribute(attributeName) == expectedValue then
			return true
		end
	end
	return false
end

local function instanceMatchesRule(instance, rule)
	if not instance then
		return false
	end

	return attributeMatches(instance, rule) or nameMatches(instance, rule)
end

local function partOrAncestorMatchesRule(part, rule)
	local cursor = part
	while cursor and cursor ~= Workspace do
		if instanceMatchesRule(cursor, rule) then
			return true
		end
		cursor = cursor.Parent
	end
	return false
end

local function getGroundPartPreset(part)
	if not part then
		return nil
	end

	local bestPreset = nil
	local bestPriority = -math.huge
	for _, rule in ipairs(LightingPresets.AreaRules or {}) do
		if rule.PartAttributes and partOrAncestorMatchesRule(part, rule) then
			local priority = tonumber(rule.Priority) or 0
			if priority > bestPriority then
				bestPriority = priority
				bestPreset = rule.Preset
			end
		end
	end

	return bestPreset
end

local function partMatchesRule(part, rule)
	if not part:IsA("BasePart") or not part.CanQuery then
		return false
	end

	return attributeMatches(part, rule) or nameMatches(part, rule)
end

local function rescanAreaParts()
	table.clear(areaParts)
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		for _, rule in ipairs(LightingPresets.AreaRules or {}) do
			if rule.PartAttributes and partMatchesRule(descendant, rule) then
				table.insert(areaParts, {
					Part = descendant,
					Preset = rule.Preset,
					Priority = tonumber(rule.Priority) or 0,
				})
				break
			end
		end
	end
	table.sort(areaParts, function(a, b)
		return (a.Priority or 0) > (b.Priority or 0)
	end)
	lastScan = os.clock()
end

local function getAttributePreset()
	for _, rule in ipairs(LightingPresets.AreaRules or {}) do
		if rule.PlayerAttribute and player:GetAttribute(rule.PlayerAttribute) == rule.AttributeValue then
			return rule.Preset
		end
	end
	return nil
end

local function getCurrentWorldColor()
	local activeWorldColor = player:GetAttribute("ActiveWorldColor")
	if type(activeWorldColor) == "string" and activeWorldColor ~= "" then
		return activeWorldColor
	end

	local storage = player:FindFirstChild("ColorStorage")
	local currentWorld = storage and storage:FindFirstChild("CurrentWorld")
	if currentWorld and currentWorld:IsA("StringValue") and currentWorld.Value ~= "" then
		return currentWorld.Value
	end

	return nil
end

local function getWorldColorPreset()
	local worldColor = getCurrentWorldColor()
	local worldColorPresets = LightingPresets.WorldColorPresets
	local presetName = worldColorPresets and worldColor and worldColorPresets[worldColor]
	if type(presetName) == "string" and LightingPresets.Presets[presetName] then
		return presetName
	end
	return nil
end

local function getAreaPreset()
	local manualPresetAttribute = LightingPresets.ManualPresetAttribute
	local manualPreset = manualPresetAttribute and player:GetAttribute(manualPresetAttribute)
	if type(manualPreset) == "string" and LightingPresets.Presets[manualPreset] then
		return manualPreset
	end

	local attributePreset = getAttributePreset()
	if attributePreset then
		return attributePreset
	end

	local rootPosition = getRootPosition()
	if not rootPosition then
		return LightingPresets.DefaultPreset
	end

	if os.clock() - lastScan > (LightingPresets.ScanInterval or 2) then
		rescanAreaParts()
	end

	local groundPosition, groundPart = getGroundContact()
	local groundPreset = getGroundPartPreset(groundPart)
	if groundPreset then
		return groundPreset
	end

	if groundPosition then
		for _, area in ipairs(areaParts) do
			local part = area.Part
			if part and part.Parent and pointIsOnTopSurface(groundPosition, part) then
				return area.Preset
			end
		end
	else
		return currentPresetName or LightingPresets.DefaultPreset
	end

	for _, area in ipairs(areaParts) do
		local part = area.Part
		if
			part
			and part.Parent
			and part:GetAttribute("LightingAreaVolume") == true
			and pointIsInsidePart(rootPosition, part)
		then
			return area.Preset
		end
	end

	local worldPreset = LightingPresets.UseWorldColorFallback == true and getWorldColorPreset() or nil
	if worldPreset and not groundPosition then
		return worldPreset
	end

	return LightingPresets.DefaultPreset
end

local function updateLighting()
	if LightingPresets.Enabled == false then
		return
	end

	applyPreset(getAreaPreset())
end

for _, rule in ipairs(LightingPresets.AreaRules or {}) do
	if rule.PlayerAttribute then
		player:GetAttributeChangedSignal(rule.PlayerAttribute):Connect(updateLighting)
	end
end

if LightingPresets.ManualPresetAttribute then
	player:GetAttributeChangedSignal(LightingPresets.ManualPresetAttribute):Connect(updateLighting)
end

player:GetAttributeChangedSignal("ActiveWorldColor"):Connect(updateLighting)

local function hookCurrentWorldValue()
	if currentWorldConnection then
		currentWorldConnection:Disconnect()
		currentWorldConnection = nil
	end
	if colorStorageConnection then
		colorStorageConnection:Disconnect()
		colorStorageConnection = nil
	end

	local storage = player:FindFirstChild("ColorStorage")
	local currentWorld = storage and storage:FindFirstChild("CurrentWorld")
	if currentWorld and currentWorld:IsA("StringValue") then
		currentWorldConnection = currentWorld:GetPropertyChangedSignal("Value"):Connect(updateLighting)
		updateLighting()
	end

	if storage then
		colorStorageConnection = storage.ChildAdded:Connect(function(child)
			if child.Name == "CurrentWorld" then
				task.defer(hookCurrentWorldValue)
			end
		end)
	end
end

player.ChildAdded:Connect(function(child)
	if child.Name == "ColorStorage" then
		task.defer(hookCurrentWorldValue)
	end
end)
hookCurrentWorldValue()

player.CharacterAdded:Connect(function()
	task.wait(0.25)
	updateLighting()
end)

Workspace.DescendantAdded:Connect(function(descendant)
	for _, rule in ipairs(LightingPresets.AreaRules or {}) do
		if rule.PartAttributes and partMatchesRule(descendant, rule) then
			rescanAreaParts()
			updateLighting()
			return
		end
	end
end)

rescanAreaParts()
updateLighting()

task.spawn(function()
	while LightingPresets.Enabled ~= false do
		task.wait(LightingPresets.UpdateInterval or 0.35)
		updateLighting()
	end
end)
