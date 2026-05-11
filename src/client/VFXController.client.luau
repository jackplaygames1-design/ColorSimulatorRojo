local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local VFXConfig = require(ReplicatedStorage:WaitForChild("VFXConfig"))

local vfxFolder = Workspace:FindFirstChild(VFXConfig.FolderName)
if not vfxFolder then
	vfxFolder = Instance.new("Folder")
	vfxFolder.Name = VFXConfig.FolderName
	vfxFolder.Parent = Workspace
end

local activeEffects = 0

local function canPlay()
	if VFXConfig.Enabled == false then
		return false
	end
	return activeEffects < (VFXConfig.MaxActiveEffects or 36)
end

local function trackLifetime(instance, lifetime)
	activeEffects += 1
	Debris:AddItem(instance, lifetime)
	task.delay(lifetime, function()
		activeEffects = math.max(0, activeEffects - 1)
	end)
end

local function asColor(value, fallback)
	if typeof(value) == "Color3" then
		return value
	end
	return fallback or VFXConfig.Colors.White
end

local function asPosition(position)
	if typeof(position) == "Vector3" then
		return position
	end
	return nil
end

local function getEffect(name)
	return VFXConfig.Effects[name] or {}
end

local function getRarityColor(rarity)
	return VFXConfig.RarityColors[tostring(rarity or "Common")] or VFXConfig.RarityColors.Common
end

local function createAnchor(name, position, lifetime)
	local anchor = Instance.new("Part")
	anchor.Name = name
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.4, 0.4, 0.4)
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = vfxFolder
	trackLifetime(anchor, lifetime)
	return anchor
end

local function emitParticles(parent, effect, color, count)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Burst"
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.45
	emitter.Lifetime = effect.ParticleLifetime or NumberRange.new(0.25, 0.5)
	emitter.Rate = 0
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-120, 120)
	emitter.Speed = effect.Speed or NumberRange.new(6, 12)
	emitter.SpreadAngle = Vector2.new(360, 360)
	emitter.Size = effect.Size
		or NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.38),
			NumberSequenceKeypoint.new(1, 0),
		})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.72, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = parent
	emitter:Emit(math.min(count or effect.Particles or 8, 24))
	return emitter
end

local function makePulseSphere(position, color, startSize, endSize, lifetime)
	local sphere = Instance.new("Part")
	sphere.Name = "PulseSphere"
	sphere.Shape = Enum.PartType.Ball
	sphere.Anchored = true
	sphere.CanCollide = false
	sphere.CanQuery = false
	sphere.CanTouch = false
	sphere.CastShadow = false
	sphere.Material = Enum.Material.Neon
	sphere.Color = color
	sphere.Size = Vector3.new(startSize, startSize, startSize)
	sphere.CFrame = CFrame.new(position)
	sphere.Transparency = 0.35
	sphere.Parent = vfxFolder

	TweenService:Create(sphere, TweenInfo.new(lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(endSize, endSize, endSize),
		Transparency = 1,
	}):Play()

	Debris:AddItem(sphere, lifetime + 0.08)
	return sphere
end

local function makeTrailShard(position, color, offset, lifetime)
	local shard = Instance.new("Part")
	shard.Name = "TrailShard"
	shard.Anchored = true
	shard.CanCollide = false
	shard.CanQuery = false
	shard.CanTouch = false
	shard.CastShadow = false
	shard.Material = Enum.Material.Neon
	shard.Color = color
	shard.Size = Vector3.new(0.35, 0.35, 0.35)
	shard.CFrame = CFrame.new(position)
	shard.Parent = vfxFolder

	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.16, 0)
	a0.Parent = shard
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.16, 0)
	a1.Parent = shard

	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(color)
	trail.LightEmission = 0.55
	trail.Lifetime = math.min(0.22, lifetime)
	trail.MinLength = 0.05
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Parent = shard

	TweenService:Create(shard, TweenInfo.new(lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = CFrame.new(position + offset),
		Transparency = 1,
	}):Play()

	Debris:AddItem(shard, lifetime + 0.12)
	return shard
end

local function makeBeamPulse(position, color, radius, lifetime)
	local left = createAnchor("BeamPulseA", position + Vector3.new(-radius, 0, 0), lifetime)
	local right = createAnchor("BeamPulseB", position + Vector3.new(radius, 0, 0), lifetime)
	local a0 = Instance.new("Attachment")
	a0.Parent = left
	local a1 = Instance.new("Attachment")
	a1.Parent = right

	local beam = Instance.new("Beam")
	beam.Name = "PulseBeam"
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Color = ColorSequence.new(color)
	beam.LightEmission = 0.65
	beam.Width0 = 0.38
	beam.Width1 = 0.38
	beam.Transparency = NumberSequence.new(0.15)
	beam.Parent = left

	TweenService:Create(beam, TweenInfo.new(lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Width0 = 0,
		Width1 = 0,
	}):Play()
	return beam
end

local function makeRevealLabel(position, text, color, lifetime)
	local anchor = createAnchor("RevealLabelAnchor", position + Vector3.new(0, 3.2, 0), lifetime)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "RevealLabel"
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Size = UDim2.fromOffset(240, 56)
	billboard.StudsOffset = Vector3.new(0, 0, 0)
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.TextStrokeColor3 = Color3.fromRGB(20, 18, 35)
	label.TextStrokeTransparency = 0
	label.Parent = billboard

	TweenService:Create(billboard, TweenInfo.new(lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = Vector3.new(0, 2.2, 0),
	}):Play()
	task.delay(lifetime * 0.62, function()
		if label.Parent then
			TweenService:Create(label, TweenInfo.new(lifetime * 0.25), {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			}):Play()
		end
	end)
end

local VFXController = {}

function VFXController.PlayPaintPop(position, color)
	position = asPosition(position)
	if not position or not canPlay() then
		return
	end

	local effect = getEffect("PaintPop")
	local finalColor = asColor(color, VFXConfig.Colors.Paint)
	local anchor = createAnchor("PaintPop", position, effect.Lifetime or 0.55)
	emitParticles(anchor, effect, finalColor, effect.Particles)
	makePulseSphere(position, finalColor, 0.45, 2.2, 0.28)
	makeTrailShard(position, finalColor, Vector3.new(0.8, 1.4, 0.35), 0.32)
end

function VFXController.PlayCoinPickup(position)
	position = asPosition(position)
	if not position or not canPlay() then
		return
	end

	local effect = getEffect("CoinPickup")
	local color = VFXConfig.Colors.Coin
	local anchor = createAnchor("CoinPickup", position, effect.Lifetime or 0.7)
	emitParticles(anchor, effect, color, effect.Particles)
	makeTrailShard(position, color, Vector3.new(0, 2.2, 0), 0.42)
	makePulseSphere(position, color, 0.35, 1.5, 0.25)
end

function VFXController.PlayGemBreak(position)
	position = asPosition(position)
	if not position or not canPlay() then
		return
	end

	local effect = getEffect("GemBreak")
	local color = VFXConfig.Colors.Gem
	local anchor = createAnchor("GemBreak", position, effect.Lifetime or 0.75)
	emitParticles(anchor, effect, color, effect.Particles)
	for index = 1, math.min(effect.ShardCount or 5, 6) do
		local angle = (math.pi * 2 / (effect.ShardCount or 5)) * index
		local offset = Vector3.new(math.cos(angle) * 1.8, 1.1, math.sin(angle) * 1.8)
		makeTrailShard(position, color, offset, 0.42)
	end
end

function VFXController.PlayHatchBurst(position, rarity)
	position = asPosition(position)
	if not position or not canPlay() then
		return
	end

	local effect = getEffect("HatchBurst")
	local color = getRarityColor(rarity)
	local anchor = createAnchor("HatchBurst", position, effect.Lifetime or 0.95)
	emitParticles(anchor, effect, color, effect.Particles)
	makePulseSphere(position, color, 1.2, 5.5, 0.48)
	makeBeamPulse(position + Vector3.new(0, 1.2, 0), color, 3.4, 0.45)
	makeBeamPulse(position + Vector3.new(0, 1.2, 0), color, 2.2, 0.38)
end

function VFXController.PlayMutationReveal(position, mutationName)
	position = asPosition(position)
	if not position or not canPlay() then
		return
	end

	local effect = getEffect("MutationReveal")
	local color = VFXConfig.Colors.Mutation
	local anchor = createAnchor("MutationReveal", position, effect.Lifetime or 1.25)
	emitParticles(anchor, effect, color, effect.Particles)
	makePulseSphere(position + Vector3.new(0, 1, 0), color, 1.1, 4.8, 0.55)
	makeBeamPulse(position + Vector3.new(0, 1.4, 0), color, 3, 0.55)
	makeRevealLabel(position, tostring(mutationName or "Mutation"), color, 1.1)
end

function VFXController.PlayPortalPulse(position, color)
	position = asPosition(position)
	if not position or not canPlay() then
		return
	end

	local effect = getEffect("PortalPulse")
	local finalColor = asColor(color, VFXConfig.Colors.Portal)
	local anchor = createAnchor("PortalPulse", position, effect.Lifetime or 0.85)
	emitParticles(anchor, effect, finalColor, effect.Particles)
	makePulseSphere(position, finalColor, 1.4, 6, 0.52)
	makeBeamPulse(position + Vector3.new(0, 1.1, 0), finalColor, 3.2, 0.5)
end

local function ensureVFXEvent()
	local existing = ReplicatedStorage:FindFirstChild(VFXConfig.EventName)
	if existing and existing:IsA("BindableEvent") then
		return existing
	end

	local event = Instance.new("BindableEvent")
	event.Name = VFXConfig.EventName
	event.Parent = ReplicatedStorage
	return event
end

ensureVFXEvent().Event:Connect(function(effectName, position, firstArg)
	if effectName == "PaintPop" then
		VFXController.PlayPaintPop(position, firstArg)
	elseif effectName == "CoinPickup" then
		VFXController.PlayCoinPickup(position)
	elseif effectName == "GemBreak" then
		VFXController.PlayGemBreak(position)
	elseif effectName == "HatchBurst" then
		VFXController.PlayHatchBurst(position, firstArg)
	elseif effectName == "MutationReveal" then
		VFXController.PlayMutationReveal(position, firstArg)
	elseif effectName == "PortalPulse" then
		VFXController.PlayPortalPulse(position, firstArg)
	end
end)

print("VFXController: lightweight client VFX ready")
