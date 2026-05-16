local LightingPresets = {}

LightingPresets.Enabled = true
LightingPresets.UpdateInterval = 0.35
LightingPresets.ScanInterval = 2
LightingPresets.TransitionTime = 2.15
LightingPresets.ManualPresetAttribute = "LightingPreset"
LightingPresets.SkyFolderName = "ColorSimulatorSectorSkies"
LightingPresets.ActiveSkyName = "ColorSimulatorActiveSky"
LightingPresets.DefaultSkyName = "Spawn"

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
			Brightness = 2.65,
			ClockTime = 15.35,
			ExposureCompensation = 0.06,
			EnvironmentDiffuseScale = 0.5,
			EnvironmentSpecularScale = 0.34,
			Ambient = Color3.fromRGB(180, 112, 84),
			OutdoorAmbient = Color3.fromRGB(224, 150, 100),
			FogColor = Color3.fromRGB(196, 98, 66),
			FogStart = 220,
			FogEnd = 1350,
		},
		Atmosphere = {
			Color = Color3.fromRGB(218, 126, 82),
			Decay = Color3.fromRGB(132, 45, 30),
			Density = 0.28,
			Offset = 0.02,
			Glare = 0.08,
			Haze = 2.25,
		},
		Bloom = {
			Intensity = 0.13,
			Size = 20,
			Threshold = 1.52,
		},
		ColorCorrection = {
			Brightness = 0.045,
			Contrast = 0.09,
			Saturation = -0.02,
			TintColor = Color3.fromRGB(255, 205, 170),
		},
		DepthOfField = {
			Enabled = true,
			FarIntensity = 0.14,
			FocusDistance = 110,
			InFocusRadius = 72,
			NearIntensity = 0.025,
		},
	},

	OrangeSector = {
		Sky = "OrangeSector",
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
