local LightingPresets = {}

LightingPresets.Enabled = true
LightingPresets.UpdateInterval = 0.35
LightingPresets.ScanInterval = 2
LightingPresets.TransitionTime = 2.15
LightingPresets.GroundProbeDistance = 28
LightingPresets.UseWorldColorFallback = false
LightingPresets.ManualPresetAttribute = "LightingPreset"
LightingPresets.SkyFolderName = "ColorSimulatorSectorSkies"
LightingPresets.ActiveSkyName = "ColorSimulatorActiveSky"
LightingPresets.DefaultSkyName = "Spawn"
LightingPresets.WorldColorPresets = {
	Red = "RedZone",
	Orange = "OrangeSector",
	Green = "GreenSector",
}

LightingPresets.EffectNames = {
	Atmosphere = "ColorSimulatorAtmosphere",
	Bloom = "ColorSimulatorBloom",
	ColorCorrection = "ColorSimulatorColor",
	DepthOfField = "ColorSimulatorDepthOfField",
}

LightingPresets.Presets = {
	Spawn = {
		Sky = "Spawn",
		Lighting = {
			Brightness = 2.35,
			ClockTime = 14.25,
			ExposureCompensation = 0.04,
			EnvironmentDiffuseScale = 0.46,
			EnvironmentSpecularScale = 0.36,
			Ambient = Color3.fromRGB(136, 128, 104),
			OutdoorAmbient = Color3.fromRGB(186, 172, 132),
			FogColor = Color3.fromRGB(158, 145, 115),
			FogStart = 180,
			FogEnd = 1050,
		},
		Atmosphere = {
			Color = Color3.fromRGB(184, 174, 142),
			Decay = Color3.fromRGB(105, 98, 76),
			Density = 0.3,
			Offset = 0,
			Glare = 0.04,
			Haze = 2,
		},
		Bloom = {
			Intensity = 0.1,
			Size = 18,
			Threshold = 1.55,
		},
		ColorCorrection = {
			Brightness = 0.02,
			Contrast = 0.08,
			Saturation = -0.16,
			TintColor = Color3.fromRGB(224, 214, 186),
		},
		DepthOfField = {
			Enabled = true,
			FarIntensity = 0.11,
			FocusDistance = 115,
			InFocusRadius = 70,
			NearIntensity = 0.025,
		},
	},

	RedZone = {
		Sky = "RedZone",
		Lighting = {
			Brightness = 2.35,
			ClockTime = 16.15,
			ExposureCompensation = 0.01,
			EnvironmentDiffuseScale = 0.42,
			EnvironmentSpecularScale = 0.28,
			Ambient = Color3.fromRGB(166, 54, 42),
			OutdoorAmbient = Color3.fromRGB(210, 78, 58),
			FogColor = Color3.fromRGB(182, 38, 34),
			FogStart = 65,
			FogEnd = 760,
		},
		Atmosphere = {
			Color = Color3.fromRGB(226, 68, 50),
			Decay = Color3.fromRGB(105, 18, 22),
			Density = 0.47,
			Offset = -0.08,
			Glare = 0.04,
			Haze = 4.1,
		},
		Bloom = {
			Intensity = 0.16,
			Size = 22,
			Threshold = 1.42,
		},
		ColorCorrection = {
			Brightness = -0.01,
			Contrast = 0.13,
			Saturation = 0.08,
			TintColor = Color3.fromRGB(255, 148, 128),
		},
		DepthOfField = {
			Enabled = true,
			FarIntensity = 0.18,
			FocusDistance = 92,
			InFocusRadius = 62,
			NearIntensity = 0.035,
		},
	},

	OrangeSector = {
		Sky = "OrangeSector",
		Lighting = {
			Brightness = 2.55,
			ClockTime = 16.25,
			ExposureCompensation = 0.03,
			EnvironmentDiffuseScale = 0.48,
			EnvironmentSpecularScale = 0.46,
			Ambient = Color3.fromRGB(205, 102, 38),
			OutdoorAmbient = Color3.fromRGB(246, 142, 50),
			FogColor = Color3.fromRGB(242, 116, 34),
			FogStart = 90,
			FogEnd = 900,
		},
		Atmosphere = {
			Color = Color3.fromRGB(255, 150, 54),
			Decay = Color3.fromRGB(156, 58, 16),
			Density = 0.38,
			Offset = -0.03,
			Glare = 0.08,
			Haze = 3.05,
		},
		Bloom = {
			Intensity = 0.22,
			Size = 22,
			Threshold = 1.32,
		},
		ColorCorrection = {
			Brightness = 0.01,
			Contrast = 0.11,
			Saturation = 0.2,
			TintColor = Color3.fromRGB(255, 194, 130),
		},
		DepthOfField = {
			Enabled = true,
			FarIntensity = 0.16,
			FocusDistance = 98,
			InFocusRadius = 66,
			NearIntensity = 0.03,
		},
	},

	GreenSector = {
		Sky = "GreenSector",
		Lighting = {
			Brightness = 2.5,
			ClockTime = 13.9,
			ExposureCompensation = 0.02,
			EnvironmentDiffuseScale = 0.48,
			EnvironmentSpecularScale = 0.38,
			Ambient = Color3.fromRGB(58, 146, 68),
			OutdoorAmbient = Color3.fromRGB(98, 196, 104),
			FogColor = Color3.fromRGB(72, 180, 80),
			FogStart = 85,
			FogEnd = 850,
		},
		Atmosphere = {
			Color = Color3.fromRGB(84, 210, 96),
			Decay = Color3.fromRGB(18, 84, 36),
			Density = 0.39,
			Offset = -0.04,
			Glare = 0.05,
			Haze = 3.25,
		},
		Bloom = {
			Intensity = 0.18,
			Size = 22,
			Threshold = 1.38,
		},
		ColorCorrection = {
			Brightness = 0.005,
			Contrast = 0.11,
			Saturation = 0.16,
			TintColor = Color3.fromRGB(166, 255, 174),
		},
		DepthOfField = {
			Enabled = true,
			FarIntensity = 0.16,
			FocusDistance = 98,
			InFocusRadius = 66,
			NearIntensity = 0.03,
		},
	},

	MutationPipes = {
		Sky = "MutationPipes",
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
		Sky = "HatchArea",
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
		Priority = 100,
		PlayerAttribute = "InsideSectorInterior",
		AttributeValue = true,
	},
	{
		Preset = "MutationPipes",
		Priority = 95,
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
		Priority = 40,
		PartAttributes = {
			EggStation = true,
		},
		NameContains = {
			"Egg",
			"Hatch",
		},
	},
	{
		Preset = "Spawn",
		Priority = 30,
		PartAttributes = {
			ZoneId = "Lobby",
			LobbyFloor = true,
			LobbySpawn = true,
			OriginSector = true,
			OriginSectorFloor = true,
			StartSector = true,
		},
		NameContains = {
			"Lobby",
			"SpawnWorld",
			"OriginSector",
			"OriginSpawn",
			"StartSector",
		},
	},
	{
		Preset = "RedZone",
		Priority = 20,
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
		Priority = 20,
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
		Preset = "GreenSector",
		Priority = 20,
		PartAttributes = {
			ColorType = "Green",
			AreaColor = "Green",
			SectorColor = "Green",
			ZoneId = "GreenSector",
		},
		NameContains = {
			"GreenSector",
			"GreenZone",
			"GreenForest",
		},
	},
	{
		Preset = "Spawn",
		Priority = 10,
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
