-- Shared knobs for core economy. Weekly balance changes should start here.
local GameBalance = {}

GameBalance.EnableChatTags = false

GameBalance.Sell = {
	BaseCoinsPerColor = 1,
	ColorValueMultipliers = {
		Red = 1,
		Orange = 2.5,
		Blue = 5,
		Yellow = 12,
		Green = 30,
		Purple = 75,
		Neon = 180,
		Rainbow = 450,
	},
}

GameBalance.Collection = {
	RequireBrushToCollect = true,
	AllowTouchCollectionFallback = false,
}

GameBalance.Contamination = {
	Enabled = false,
	TileSize = 10,
	MaxCellDimension = 10,
	CellFill = 0.82,
	MaxCellsPerZone = 520,
	SurfaceInset = 10,
	FallbackFloorCoverageX = 220,
	FallbackFloorCoverageZ = 220,
	HeightOffset = 0.08,
	BaseTransparency = 0.18,
	BaseLayerTransparency = 0.34,
	BaseLayerHeightOffset = 0.025,
	CleanTransparency = 1,
	DefaultRegenDelay = 8,
	RegenDelayByColor = {
		Red = 9,
		Orange = 8,
		Green = 7,
		Blue = 7,
		Yellow = 7,
		Purple = 6,
		Pink = 6,
		Neon = 6,
		Rainbow = 5,
	},
	BaseReward = 4,
	RewardMultiplier = 0.35,
	PetRewardMultiplier = 0.24,
	InitialBuildDelay = 1,
	BuildBatchSize = 12,
	BuildBatchDelay = 0.03,
	SpawnExclusionPadding = 48,
	SafeExclusionPadding = 24,
	SafeNameFragments = {
		"origin",
		"zork",
		"shop",
		"safe",
		"tutorial",
		"spawn",
		"pipe",
		"portal",
		"teleport",
		"gate",
		"egg",
	},
	AllowColors = {
		Red = true,
		Orange = true,
		Green = true,
		Blue = true,
		Yellow = true,
		Purple = true,
		Pink = true,
		Neon = true,
		Rainbow = true,
	},
}

GameBalance.GroundPaint = {
	Enabled = true,

	DisableOldZoneSpawnerColors = true,
	DisableOldWildColorPopulation = true,
	DisableOldGroundContaminationParts = true,

	CellSize = 6,
	MaxLogicalCellsPerSurface = 6500,
	MaxLogicalCellsTotal = 50000,
	StartCoverage = 1,
	FullCoverage = 1,
	EmptyCoverage = 0,
	SurfaceInset = 5,
	RewardPerCoverageUnit = 10,

	Regen = {
		Enabled = true,
		DelayAfterBrush = 0.45,
		CoveragePerSecond = 0.22,
		TickHz = 8,
	},

	Visual = {
		Enabled = true,
		Mode = "SoftStampMask",

		PaintYOffset = 0.18,
		ClearStampYOffset = 0.24,

		MaxCoatPlanesPerSurface = 16,
		MaxActiveClearStamps = 260,
		MaxActiveClearStampsPerSurface = 90,

		PaintMaterial = Enum.Material.Neon,
		PaintTransparency = 0,
		PaintReflectance = 0.03,

		UseNeonGlow = true,
		GlowTransparency = 0.25,
		GlowYOffset = 0.045,

		BaseSurfaceColor = Color3.fromRGB(5, 5, 5),

		Thickness = {
			Enabled = true,
			SideLipEnabled = true,
			EdgeDarken = 0.22,
			StrokeRimTransparency = 0.35,
		},

		BrushStamp = {
			Softness = 0.65,
			RingCount = 5,
			MinStampLifetime = 0.45,
			FadeOutTime = 1.35,
			UseConcentricDiscsFallback = true,
			TextureAssetId = "",
		},
	},

	DefaultColorType = "Red",
	ZoneColors = {
		StarterField = {
			ColorType = "Red",
			PaintColor = Color3.fromRGB(235, 35, 32),
			BaseSurfaceColor = Color3.fromRGB(5, 5, 5),
		},
		Red = {
			ColorType = "Red",
			PaintColor = Color3.fromRGB(235, 35, 32),
			BaseSurfaceColor = Color3.fromRGB(5, 5, 5),
		},
		OrangeGrove = {
			ColorType = "Orange",
			PaintColor = Color3.fromRGB(255, 132, 28),
			BaseSurfaceColor = Color3.fromRGB(8, 8, 8),
		},
		Orange = {
			ColorType = "Orange",
			PaintColor = Color3.fromRGB(255, 132, 28),
			BaseSurfaceColor = Color3.fromRGB(8, 8, 8),
		},
		GreenForest = {
			ColorType = "Green",
			PaintColor = Color3.fromRGB(62, 220, 88),
			BaseSurfaceColor = Color3.fromRGB(8, 8, 8),
		},
		Green = {
			ColorType = "Green",
			PaintColor = Color3.fromRGB(62, 220, 88),
			BaseSurfaceColor = Color3.fromRGB(8, 8, 8),
		},
	},

	Brush = {
		BaseRadius = 7,
		BasePower = 0.28,
		BaseCooldown = 0.38,
		MinimumCooldown = 0.12,
		MaxRewardPerSweep = 250,
		MaxRewardPerSecond = 900,
		SoftEdgeMultiplier = 1.35,
		MaxRadius = 42,
	},

	Pets = {
		Enabled = true,
		CollectRadius = 5,
		CollectPower = 0.16,
		CollectInterval = 0.75,
		TargetSearchRadius = 45,
		MaxTargetsPerPet = 1,
		ReserveSeconds = 1.5,
		CoverageThreshold = 0.18,
	},

	Networking = {
		SnapshotRadius = 420,
		DeltaHz = 12,
		MaxDeltasPerPacket = 150,
		SendOnlyNearbyPlayers = true,
	},

	Debug = {
		Enabled = false,
		PrintBoot = true,
		PrintClientVisuals = true,
		PrintSurfaceDiscovery = false,
		PrintSweepRejects = false,
		DrawSurfaceIds = false,
		DrawBrushHits = false,
	},
}

GameBalance.FeatureFlags = {
	GemDepositsEnabled = true,
	WildColorsEnabled = false,
	RuntimeColorPopulationEnabled = false,
	RuntimeTutorialSectorBuildingEnabled = false,
	RuntimeWorldBuildingEnabled = false,
	RuntimeWorldLabelsEnabled = false,
	DebugPetShowcaseEnabled = false,
	RuntimeUpdateBoardEnabled = false,
	RuntimeComingSoonSignEnabled = false,
}

GameBalance.WildGameplay = {
	GemDeposits = {
		MaxPerZone = 1,
		InitialSpawnDelay = 2,
		SpawnCheckInterval = 3,
		RespawnMin = 18,
		RespawnMax = 28,
		PerColorMax = {
			Red = 1,
			Orange = 1,
		},
	},
	WildColors = {
		MaxPerZone = 2,
		RollInterval = 5,
		SpawnChance = 1,
		DespawnAfter = 0,
		PerColorMax = {
			Red = 3,
			Orange = 2,
		},
	},
}

GameBalance.Map = {
	UseBakedMap = true,
	GenerateTempMapIfMissing = false,
	ClearGeneratedMapOnStart = false,
	ReturnToCurrentWorldOnSpawn = false,
}

GameBalance.Progression = {
	StartSectorColor = "Red",
	NextSectorColor = "Orange",
	MaxPlayableSectorIndex = 3,
	DefaultUnlockedSectorIndex = 1,
}

GameBalance.ZonePopulation = {
	MaxBlobsPerZone = 80,
	SpawnBatchSize = 10,
	SpawnBatchDelay = 0.03,
	RepopulateCooldown = 20,
	PopulateAllZonesOnStartup = false,
	PopulateStartZonesOnStartup = false,
	InitialPlayerPopulateDelay = 3.5,
}

GameBalance.HatchCooldown = 2.5
GameBalance.FastHatchCooldown = 1.25
GameBalance.AutoHatchDelay = 2.6
GameBalance.MergeUnlockWorldIndex = 2
GameBalance.TraitsUnlockWorldIndex = 1
GameBalance.MutationsUnlockWorldIndex = 2
GameBalance.TraitsUnlockZoneId = "StarterField"
GameBalance.MutationsUnlockZoneId = "OrangeGrove"

GameBalance.Pets = {
	-- Beta nerf: Colors should help clean spills, not play the game by themselves.
	PowerScale = 0.35,
	RewardBonusScale = 0.12,
	MaxColorMultiplierFromPets = 1.35,
	MaxCoinMultiplierFromPets = 1.35,
	AttackRange = 16,
	AttackInterval = 0.65,
	DamageScale = 0.35,
	MinDamageFraction = 0.08,
}

GameBalance.Testing = {
	-- Studio-only hatch luck for testing egg odds. Live servers still use the normal 2.5x cap.
	StudioHatchLuckMultiplier = 100,
	MaxStudioHatchLuckMultiplier = 100,
	AutoGrantDevRainbowColor = false,
}

GameBalance.Running = {
	Enabled = true,
	SpeedMultiplier = 1.45,
	MinRunSpeed = 62,
	MaxRunSpeed = 104,
}

GameBalance.ColorEffects = {
	BaseWalkSpeed = 44,
	MaxWalkSpeedFromColors = 20,
	AbsoluteMaxWalkSpeed = 92,

	BaseJumpPower = 50,
	MaxJumpPowerFromColors = 30,
	AbsoluteMaxJumpPower = 85,

	MinimumBrushCooldown = 0.20,
	MaxBrushRangeMultiplier = 1.75,
	MaxColorGainMultiplierFromColors = 3,
	MaxSellMultiplierFromColors = 3,
	MaxHatchLuckBonusFromColors = 1.50,
	MaxWalkSpeedMultiplierFromBuffs = 1.6,
	MaxHatchLuckMultiplierFromBuffs = 2,

	LightningGlobalCooldown = 1.0,
	LightningMaxTargetsPerProc = 4,
	LightningMaxRange = 55,

	MagnetGlobalCooldown = 1.0,
	MagnetMaxTargetsPerProc = 5,
	MagnetMaxRange = 55,
}

function GameBalance.formatNumber(value)
	value = tonumber(value) or 0
	local absValue = math.abs(value)

	if absValue >= 1000000000 then
		local text = string.format("%.2fB", value / 1000000000):gsub("%.00", "")
		return text
	elseif absValue >= 1000000 then
		local text = string.format("%.2fM", value / 1000000):gsub("%.00", "")
		return text
	elseif absValue >= 1000 then
		local text = string.format("%.1fK", value / 1000):gsub("%.0K", "K")
		return text
	end

	return tostring(math.floor(value))
end

function GameBalance.getWorldNameByIndex(index)
	index = tonumber(index) or 1
	local colorData = rawget(_G, "__ColorSimulatorColorData")
	if not colorData then
		local ok, module = pcall(function()
			return require(script.Parent:WaitForChild("ColorData"))
		end)
		if ok then
			colorData = module
		end
	end

	local world = colorData and colorData.Worlds and colorData.Worlds[index]
	return world and world.name or ("Sector " .. tostring(index))
end

function GameBalance.getFeatureUnlockWorldIndex(featureName)
	if featureName == "Merge" or featureName == "Merging" then
		return tonumber(GameBalance.MergeUnlockWorldIndex) or 2
	elseif featureName == "Traits" or featureName == "Trait" then
		return tonumber(GameBalance.TraitsUnlockWorldIndex) or 3
	elseif featureName == "Mutations" or featureName == "Mutation" then
		return tonumber(GameBalance.MutationsUnlockWorldIndex) or 4
	end
	return 1
end

function GameBalance.getFeatureUnlockText(featureName)
	local index = GameBalance.getFeatureUnlockWorldIndex(featureName)
	return "Unlocks in " .. GameBalance.getWorldNameByIndex(index)
end

return GameBalance
