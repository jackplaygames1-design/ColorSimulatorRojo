local AudioIds = {}

AudioIds.Groups = {
	Master = {
		Volume = 1,
	},
	UI = {
		Volume = 0.75,
	},
	SFX = {
		Volume = 0.8,
	},
	Currency = {
		Volume = 0.75,
	},
	Hatch = {
		Volume = 0.85,
	},
	Ambience = {
		Volume = 0.45,
	},
	Tools = {
		Volume = 0.75,
	},
}

AudioIds.UI = {
	Click = {
		Id = "rbxasset://sounds/button.wav",
		Volume = 0.38,
		PlaybackSpeed = 1.08,
		PlaybackSpeedVariance = 0.05,
	},
	Hover = {
		Id = "rbxasset://sounds/electronicpingshort.wav",
		Volume = 0.08,
		PlaybackSpeed = 1.35,
		PlaybackSpeedVariance = 0.04,
	},
	Open = {
		Id = "rbxasset://sounds/electronicpingshort.wav",
		Volume = 0.24,
		PlaybackSpeed = 1.08,
	},
	Close = {
		Id = "rbxasset://sounds/button.wav",
		Volume = 0.25,
		PlaybackSpeed = 0.92,
	},
	Tab = {
		Id = "rbxasset://sounds/button.wav",
		Volume = 0.28,
		PlaybackSpeed = 1.18,
		PlaybackSpeedVariance = 0.03,
	},
	Error = {
		Id = "rbxasset://sounds/button.wav",
		Volume = 0.32,
		PlaybackSpeed = 0.72,
	},
	Confirm = {
		Id = "rbxasset://sounds/electronicpingshort.wav",
		Volume = 0.3,
		PlaybackSpeed = 1.18,
	},
}

AudioIds.SFX = {
	Pop = "",
	Success = "",
	Error = "",
	Teleport = "",
}

AudioIds.Currency = {
	Coins = "",
	Gems = "",
	Sell = "",
	Purchase = "",
}

AudioIds.Hatch = {
	Start = "",
	Crack = "",
	Reveal = "",
	RareReveal = "",
}

AudioIds.Ambience = {
	Spawn = "",
	RedZone = "",
	Pipes = "",
}

AudioIds.Tools = {
	Swing = "",
	Paint = "",
	Equip = "",
	Unequip = "",
}

AudioIds.Defaults = {
	Volume = 0.65,
	RollOffMaxDistance = 90,
	RollOffMinDistance = 8,
	EmitterSize = 8,
}

return AudioIds
