local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Events = ReplicatedStorage:WaitForChild("Events")
local colorEffectVfxEvent = Events:WaitForChild("ColorEffectVFX")

local function getClientSetting(key, defaultValue)
	local value = player:GetAttribute("Setting" .. key)
	return type(value) == "boolean" and value or defaultValue
end

local EFFECT_COLORS = {
	Lightning = Color3.fromRGB(92, 220, 255),
	Magnet = Color3.fromRGB(105, 230, 255),
	Storm = Color3.fromRGB(95, 175, 255),
	Glitched = Color3.fromRGB(180, 90, 255),
	Rainbow = Color3.fromRGB(255, 120, 220),
	BrushActive = Color3.fromRGB(91, 230, 235),
}

local function configureNonInteractiveVfx(part)
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Massless = true
	part:SetAttribute("NonInteractiveVFX", true)
end

local function getFxColor(payload)
	local mutationId = payload and payload.MutationId
	return EFFECT_COLORS[mutationId] or EFFECT_COLORS[payload and payload.Effect] or EFFECT_COLORS.Lightning
end

local function makeBeamPart(fromPosition, toPosition, color)
	local direction = toPosition - fromPosition
	local distance = direction.Magnitude
	if distance <= 0.1 then
		return
	end

	local part = Instance.new("Part")
	part.Name = "ColorEffectBeam"
	part.Anchored = true
	configureNonInteractiveVfx(part)
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = Vector3.new(0.18, 0.18, distance)
	part.CFrame = CFrame.lookAt(fromPosition:Lerp(toPosition, 0.5), toPosition)
	part.Transparency = 0.12
	part.Parent = workspace

	TweenService:Create(part, TweenInfo.new(0.18), {
		Transparency = 1,
		Size = Vector3.new(0.04, 0.04, distance),
	}):Play()
	Debris:AddItem(part, 0.22)
end

local function makeFlash(position, color)
	local flash = Instance.new("Part")
	flash.Name = "ColorEffectFlash"
	flash.Shape = Enum.PartType.Ball
	flash.Anchored = true
	configureNonInteractiveVfx(flash)
	flash.Material = Enum.Material.Neon
	flash.Color = color
	flash.Size = Vector3.new(1.2, 1.2, 1.2)
	flash.CFrame = CFrame.new(position)
	flash.Transparency = 0.2
	flash.Parent = workspace

	TweenService:Create(flash, TweenInfo.new(0.22, Enum.EasingStyle.Quad), {
		Transparency = 1,
		Size = Vector3.new(3.5, 3.5, 3.5),
	}):Play()
	Debris:AddItem(flash, 0.28)
end

local function playLightning(payload)
	local fromPosition = payload.From
	local targets = payload.Targets
	if typeof(fromPosition) ~= "Vector3" or type(targets) ~= "table" then
		return
	end

	local color = getFxColor(payload)
	for _, targetPosition in ipairs(targets) do
		if typeof(targetPosition) == "Vector3" then
			makeBeamPart(fromPosition, targetPosition, color)
			makeFlash(targetPosition, color)
		end
	end
end

local function playMagnet(payload)
	local fromPosition = payload.From
	local targets = payload.Targets
	if typeof(fromPosition) ~= "Vector3" or type(targets) ~= "table" then
		return
	end

	local color = getFxColor(payload)
	for _, targetPosition in ipairs(targets) do
		if typeof(targetPosition) == "Vector3" then
			local orb = Instance.new("Part")
			orb.Name = "ColorMagnetOrb"
			orb.Shape = Enum.PartType.Ball
			orb.Anchored = true
			configureNonInteractiveVfx(orb)
			orb.Material = Enum.Material.Neon
			orb.Color = color
			orb.Size = Vector3.new(0.7, 0.7, 0.7)
			orb.CFrame = CFrame.new(targetPosition)
			orb.Parent = workspace
			TweenService:Create(orb, TweenInfo.new(0.24, Enum.EasingStyle.Quad), {
				CFrame = CFrame.new(fromPosition),
				Transparency = 1,
			}):Play()
			Debris:AddItem(orb, 0.3)
		end
	end
end

colorEffectVfxEvent.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	if getClientSetting("LowFX", false) then
		return
	end

	if payload.Effect == "Magnet" then
		playMagnet(payload)
	else
		playLightning(payload)
	end
end)
