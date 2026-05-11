local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local LightingPresets = require(ReplicatedStorage:WaitForChild("LightingPresets"))

local player = Players.LocalPlayer

local areaParts = {}
local currentPresetName = nil
local lastScan = 0

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
		TweenService:Create(instance, tweenInfo, tweenable):Play()
	end
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

local function pointIsInsidePart(position, part)
	local localPosition = part.CFrame:PointToObjectSpace(position)
	local halfSize = part.Size * 0.5
	return math.abs(localPosition.X) <= halfSize.X
		and math.abs(localPosition.Y) <= halfSize.Y + 8
		and math.abs(localPosition.Z) <= halfSize.Z
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
				})
				break
			end
		end
	end
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

	local position = getRootPosition()
	if not position then
		return LightingPresets.DefaultPreset
	end

	if os.clock() - lastScan > (LightingPresets.ScanInterval or 2) then
		rescanAreaParts()
	end

	for _, area in ipairs(areaParts) do
		local part = area.Part
		if part and part.Parent and pointIsInsidePart(position, part) then
			return area.Preset
		end
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
