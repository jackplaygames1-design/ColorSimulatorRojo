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
			Brightness = 3,
			ClockTime = 14.2,
			ExposureCompensation = 0.08,
			EnvironmentDiffuseScale = 0.56,
			EnvironmentSpecularScale = 0.58,
			Ambient = Color3.fromRGB(172, 188, 212),
			OutdoorAmbient = Color3.fromRGB(215, 224, 236),
			FogColor = Color3.fromRGB(222, 234, 246),
			FogStart = 760,
			FogEnd = 1900,
		},
		Atmosphere = {
			Color = Color3.fromRGB(210, 228, 255),
			Decay = Color3.fromRGB(255, 226, 234),
			Density = 0.17,
			Offset = 0.18,
			Glare = 0.08,
			Haze = 0.9,
		},
		Bloom = {
			Intensity = 0.16,
			Size = 20,
			Threshold = 1.35,
		},
		ColorCorrection = {
			Brightness = 0.03,
			Contrast = 0.05,
			Saturation = 0.1,
			TintColor = Color3.fromRGB(255, 251, 246),
		},
		DepthOfField = {
			Enabled = true,
			FarIntensity = 0.07,
			FocusDistance = 120,
			InFocusRadius = 90,
			NearIntensity = 0.02,
		},
	},

	RedZone = {
		Lighting = {
			Brightness = 2.65,
			ClockTime = 15.35,
			ExposureCompensation = 0.04,
			EnvironmentDiffuseScale = 0.5,
			EnvironmentSpecularScale = 0.58,
			Ambient = Color3.fromRGB(190, 118, 96),
			OutdoorAmbient = Color3.fromRGB(235, 166, 126),
			FogColor = Color3.fromRGB(255, 188, 140),
			FogStart = 540,
			FogEnd = 1550,
		},
		Atmosphere = {
			Color = Color3.fromRGB(255, 192, 148),
			Decay = Color3.fromRGB(190, 64, 66),
			Density = 0.23,
			Offset = 0.08,
			Glare = 0.11,
			Haze = 1.12,
		},
		Bloom = {
			Intensity = 0.2,
			Size = 22,
			Threshold = 1.33,
		},
		ColorCorrection = {
			Brightness = 0.02,
			Contrast = 0.08,
			Saturation = 0.18,
			TintColor = Color3.fromRGB(255, 224, 204),
		},
		DepthOfField = {
			Enabled = true,
			FarIntensity = 0.09,
			FocusDistance = 110,
			InFocusRadius = 78,
			NearIntensity = 0.03,
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
