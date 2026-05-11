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
	Click = "",
	Open = "",
	Close = "",
	Tab = "",
	Error = "",
	Confirm = "",
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
