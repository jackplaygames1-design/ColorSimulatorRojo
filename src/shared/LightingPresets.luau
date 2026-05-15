local LightingPresets = {}

LightingPresets.Enabled = true
LightingPresets.UpdateInterval = 0.35
LightingPresets.ScanInterval = 2
LightingPresets.TransitionTime = 0.7
LightingPresets.ManualPresetAttribute = "LightingPreset"

LightingPresets.EffectNames = {
	Atmosphere = "ColorSimulatorAtmosphere",
	Bloom = "ColorSimulatorBloom",
	ColorCorrection = "ColorSimulatorColor",
	DepthOfField = "ColorSimulatorDepthOfField",
}

LightingPresets.Presets = {
	Spawn = {
		Lighting = {
			Brightness = 1.55,
			ClockTime = 6.05,
			ExposureCompensation = -0.2,
			EnvironmentDiffuseScale = 0.28,
			EnvironmentSpecularScale = 0.22,
			Ambient = Color3.fromRGB(70, 78, 86),
			OutdoorAmbient = Color3.fromRGB(86, 92, 96),
			FogColor = Color3.fromRGB(91, 101, 104),
			FogStart = 90,
			FogEnd = 780,
		},
		Atmosphere = {
			Color = Color3.fromRGB(116, 126, 128),
			Decay = Color3.fromRGB(66, 72, 66),
			Density = 0.43,
			Offset = -0.08,
			Glare = 0.01,
			Haze = 2.25,
		},
		Bloom = {
			Intensity = 0.08,
			Size = 18,
			Threshold = 1.55,
		},
		ColorCorrection = {
			Brightness = -0.08,
			Contrast = 0.14,
			Saturation = -0.24,
			TintColor = Color3.fromRGB(194, 205, 198),
		},
		DepthOfField = {
			Enabled = true,
			FarIntensity = 0.16,
			FocusDistance = 95,
			InFocusRadius = 58,
			NearIntensity = 0.04,
		},
	},

	RedZone = {
		Lighting = {
			Brightness = 1.75,
			ClockTime = 20.2,
			ExposureCompensation = -0.16,
			EnvironmentDiffuseScale = 0.3,
			EnvironmentSpecularScale = 0.36,
			Ambient = Color3.fromRGB(95, 28, 32),
			OutdoorAmbient = Color3.fromRGB(130, 42, 38),
			FogColor = Color3.fromRGB(112, 22, 30),
			FogStart = 120,
			FogEnd = 920,
		},
		Atmosphere = {
			Color = Color3.fromRGB(144, 43, 46),
			Decay = Color3.fromRGB(74, 12, 18),
			Density = 0.38,
			Offset = -0.05,
			Glare = 0.03,
			Haze = 2.1,
		},
		Bloom = {
			Intensity = 0.18,
			Size = 24,
			Threshold = 1.42,
		},
		ColorCorrection = {
			Brightness = -0.06,
			Contrast = 0.18,
			Saturation = 0.08,
			TintColor = Color3.fromRGB(255, 155, 145),
		},
		DepthOfField = {
			Enabled = true,
			FarIntensity = 0.2,
			FocusDistance = 88,
			InFocusRadius = 56,
			NearIntensity = 0.04,
		},
	},

	OrangeSector = {
		Lighting = {
			Brightness = 2.75,
			ClockTime = 16,
			ExposureCompensation = 0.05,
			EnvironmentDiffuseScale = 0.52,
			EnvironmentSpecularScale = 0.62,
			Ambient = Color3.fromRGB(202, 138, 92),
			OutdoorAmbient = Color3.fromRGB(245, 184, 116),
			FogColor = Color3.fromRGB(255, 202, 136),
			FogStart = 580,
			FogEnd = 1600,
		},
		Atmosphere = {
			Color = Color3.fromRGB(255, 204, 142),
			Decay = Color3.fromRGB(218, 96, 40),
			Density = 0.22,
			Offset = 0.1,
			Glare = 0.11,
			Haze = 1.08,
		},
		Bloom = {
			Intensity = 0.2,
			Size = 22,
			Threshold = 1.34,
		},
		ColorCorrection = {
			Brightness = 0.025,
			Contrast = 0.07,
			Saturation = 0.16,
			TintColor = Color3.fromRGB(255, 232, 205),
		},
		DepthOfField = {
			Enabled = true,
			FarIntensity = 0.1,
			FocusDistance = 112,
			InFocusRadius = 78,
			NearIntensity = 0.03,
		},
	},

	MutationPipes = {
		Lighting = {
			Brightness = 2.05,
			ClockTime = 20.65,
			ExposureCompensation = -0.02,
			EnvironmentDiffuseScale = 0.35,
			EnvironmentSpecularScale = 0.78,
			Ambient = Color3.fromRGB(70, 44, 96),
			OutdoorAmbient = Color3.fromRGB(38, 70, 62),
			FogColor = Color3.fromRGB(58, 34, 78),
			FogStart = 180,
			FogEnd = 820,
		},
		Atmosphere = {
			Color = Color3.fromRGB(104, 70, 150),
			Decay = Color3.fromRGB(26, 154, 102),
			Density = 0.32,
			Offset = -0.02,
			Glare = 0.04,
			Haze = 1.5,
		},
		Bloom = {
			Intensity = 0.24,
			Size = 24,
			Threshold = 1.45,
		},
		ColorCorrection = {
			Brightness = -0.01,
			Contrast = 0.12,
			Saturation = 0.22,
			TintColor = Color3.fromRGB(226, 214, 255),
		},
		DepthOfField = {
			Enabled = true,
			FarIntensity = 0.18,
			FocusDistance = 82,
			InFocusRadius = 60,
			NearIntensity = 0.04,
		},
	},

	HatchArea = {
		Lighting = {
			Brightness = 2.9,
			ClockTime = 13.8,
			ExposureCompensation = 0.06,
			EnvironmentDiffuseScale = 0.55,
			EnvironmentSpecularScale = 0.7,
			Ambient = Color3.fromRGB(176, 188, 220),
			OutdoorAmbient = Color3.fromRGB(222, 214, 242),
			FogColor = Color3.fromRGB(230, 222, 255),
			FogStart = 620,
			FogEnd = 1650,
		},
		Atmosphere = {
			Color = Color3.fromRGB(220, 218, 255),
			Decay = Color3.fromRGB(255, 194, 218),
			Density = 0.2,
			Offset = 0.15,
			Glare = 0.09,
			Haze = 1.02,
		},
		Bloom = {
			Intensity = 0.22,
			Size = 22,
			Threshold = 1.38,
		},
		ColorCorrection = {
			Brightness = 0.025,
			Contrast = 0.06,
			Saturation = 0.14,
			TintColor = Color3.fromRGB(250, 242, 255),
		},
		DepthOfField = {
			Enabled = true,
			FarIntensity = 0.12,
			FocusDistance = 80,
			InFocusRadius = 64,
			NearIntensity = 0.035,
		},
	},
}

LightingPresets.DefaultPreset = "Spawn"

LightingPresets.AreaRules = {
	{
		Preset = "MutationPipes",
		PlayerAttribute = "InsideSectorInterior",
		AttributeValue = true,
	},
	{
		Preset = "MutationPipes",
		PartAttributes = {
			MutationUnlockArea = true,
			SectorInterior = true,
			SectorInteriorSpawn = true,
		},
		NameContains = {
			"Pipe",
			"Mutation",
			"OrangeInterior",
		},
	},
	{
		Preset = "HatchArea",
		PartAttributes = {
			EggStation = true,
		},
		NameContains = {
			"Egg",
			"Hatch",
		},
	},
	{
		Preset = "RedZone",
		PartAttributes = {
			ColorType = "Red",
			AreaColor = "Red",
			ZoneId = "RedZone",
			SpawnColor = "Red",
		},
		NameContains = {
			"RedZone",
			"RedWastelands",
		},
	},
	{
		Preset = "OrangeSector",
		PartAttributes = {
			ColorType = "Orange",
			AreaColor = "Orange",
			SectorColor = "Orange",
			ZoneId = "OrangeSector",
		},
		NameContains = {
			"OrangeSector",
			"OrangeZone",
			"OrangeGrove",
		},
	},
	{
		Preset = "Spawn",
		PartAttributes = {
			ZoneId = "Lobby",
			LobbyFloor = true,
			LobbySpawn = true,
		},
		NameContains = {
			"Lobby",
			"SpawnWorld",
			"OriginSector",
		},
	},
}

return LightingPresets
