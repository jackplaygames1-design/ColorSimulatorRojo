local VFXConfig = {}

VFXConfig.Enabled = true
VFXConfig.EventName = "ColorSimulatorPlayVFX"
VFXConfig.FolderName = "ColorSimulatorClientVFX"
VFXConfig.MaxActiveEffects = 36

VFXConfig.Colors = {
	Paint = Color3.fromRGB(120, 235, 255),
	Coin = Color3.fromRGB(255, 220, 80),
	Gem = Color3.fromRGB(95, 255, 145),
	Portal = Color3.fromRGB(145, 105, 255),
	Mutation = Color3.fromRGB(190, 95, 255),
	White = Color3.fromRGB(255, 255, 255),
}

VFXConfig.RarityColors = {
	Common = Color3.fromRGB(235, 245, 255),
	Uncommon = Color3.fromRGB(110, 245, 135),
	Rare = Color3.fromRGB(90, 190, 255),
	Epic = Color3.fromRGB(185, 105, 255),
	Legendary = Color3.fromRGB(255, 192, 70),
	Mythic = Color3.fromRGB(255, 92, 170),
	Secret = Color3.fromRGB(120, 255, 235),
}

VFXConfig.Effects = {
	PaintPop = {
		Lifetime = 0.55,
		Particles = 10,
		ParticleLifetime = NumberRange.new(0.22, 0.42),
		Speed = NumberRange.new(8, 15),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55),
			NumberSequenceKeypoint.new(1, 0),
		}),
	},
	CoinPickup = {
		Lifetime = 0.7,
		Particles = 8,
		ParticleLifetime = NumberRange.new(0.25, 0.45),
		Speed = NumberRange.new(5, 10),
	},
	GemBreak = {
		Lifetime = 0.75,
		Particles = 12,
		ShardCount = 5,
		ParticleLifetime = NumberRange.new(0.28, 0.5),
		Speed = NumberRange.new(10, 18),
	},
	HatchBurst = {
		Lifetime = 0.95,
		Particles = 18,
		ParticleLifetime = NumberRange.new(0.35, 0.65),
		Speed = NumberRange.new(11, 20),
	},
	MutationReveal = {
		Lifetime = 1.25,
		Particles = 20,
		ParticleLifetime = NumberRange.new(0.42, 0.82),
		Speed = NumberRange.new(7, 14),
	},
	PortalPulse = {
		Lifetime = 0.85,
		Particles = 10,
		ParticleLifetime = NumberRange.new(0.28, 0.52),
		Speed = NumberRange.new(5, 11),
	},
}

return VFXConfig
