-- ModuleScript in ReplicatedStorage named "UpgradeData"
local UpgradeData = {}

UpgradeData.Upgrades = {
	{
		id          = "WalkSpeed",
		displayName = "Walk Speed",
		icon        = "SPD",
		description = "Move faster across the color zones",
		baseValue   = 44,
		levels = {
			{ value = 48, cost = 300     },
			{ value = 52, cost = 800     },
			{ value = 56, cost = 2000    },
			{ value = 60, cost = 5000    },
			{ value = 64, cost = 22000   },
			{ value = 68, cost = 70000   },
			{ value = 72, cost = 180000  },
			{ value = 76, cost = 550000  },
			{ value = 80, cost = 1600000 },
			{ value = 84, cost = 5000000 },
		},
	},
	{
		id          = "PetSlots",
		displayName = "Color Slots",
		icon        = "ORB",
		description = "Equip more Colors at once",
		baseValue   = 3,
		levels = {
			{ value = 4,  cost = 2500     },
			{ value = 5,  cost = 10000    },
			{ value = 6,  cost = 40000    },
			{ value = 7,  cost = 150000   },
			{ value = 8,  cost = 250000   },
			{ value = 9,  cost = 800000   },
			{ value = 10, cost = 2500000  },
			{ value = 11, cost = 6500000  },
			{ value = 12, cost = 15000000 },
		},
	},
	{
		id          = "PickupRange",
		displayName = "Pickup Range",
		icon        = "RNG",
		description = "Absorb color from further away",
		baseValue   = 8,
		levels = {
			{ value = 10, cost = 400     },
			{ value = 12, cost = 1200    },
			{ value = 15, cost = 3500    },
			{ value = 18, cost = 9000    },
			{ value = 22, cost = 25000   },
			{ value = 26, cost = 80000   },
			{ value = 30, cost = 210000  },
			{ value = 35, cost = 650000  },
			{ value = 40, cost = 1800000 },
			{ value = 46, cost = 5500000 },
		},
	},
	{
		id          = "ColorMultiplier",
		displayName = "Coin Value",
		icon        = "x2",
		description = "Earn more Coins from each Color break",
		baseValue   = 1.0,
		levels = {
			{ value = 1.25, cost = 500      },
			{ value = 1.5,  cost = 1500     },
			{ value = 2.0,  cost = 5000     },
			{ value = 2.75, cost = 15000    },
			{ value = 3.75, cost = 75000    },
			{ value = 5.0,  cost = 240000   },
			{ value = 6.75, cost = 850000   },
			{ value = 9.0,  cost = 2800000  },
			{ value = 12.0, cost = 9000000  },
		},
	},
	{
		id          = "HatchSpeed",
		displayName = "Hatch Speed",
		icon        = "EGG",
		description = "Hatch Colors faster",
		baseValue   = 1.0,
		levels = {
			{ value = 0.9,  cost = 500     },
			{ value = 0.8,  cost = 1800    },
			{ value = 0.7,  cost = 6000    },
			{ value = 0.6,  cost = 18000   },
			{ value = 0.5,  cost = 70000   },
			{ value = 0.4,  cost = 300000  },
			{ value = 0.32, cost = 1200000 },
			{ value = 0.25, cost = 5000000 },
		},
	},
}

function UpgradeData.getUpgrade(id)
	for _, upg in ipairs(UpgradeData.Upgrades) do
		if upg.id == id then return upg end
	end
	return nil
end

function UpgradeData.formatNumber(n)
	n = tonumber(n) or 0
	if math.abs(n) >= 1000000000 then
		return string.format("%.2fB", n / 1000000000):gsub("%.00", "")
	elseif math.abs(n) >= 1000000 then
		return string.format("%.2fM", n / 1000000):gsub("%.00", "")
	elseif math.abs(n) >= 1000 then
		return string.format("%.1fK", n / 1000):gsub("%.0K", "K")
	end
	return tostring(math.floor(n))
end

function UpgradeData.getValueDisplay(upgradeId, level)
	local upg = UpgradeData.getUpgrade(upgradeId)
	if not upg then return "?" end

	local val = level == 0 and upg.baseValue or upg.levels[level].value

	if upgradeId == "WalkSpeed" then
		return val .. " speed"
	elseif upgradeId == "PetSlots" then
		return val .. " Color slots"
	elseif upgradeId == "PickupRange" then
		return val .. " studs"
	elseif upgradeId == "ColorMultiplier" then
		return "x" .. val
	elseif upgradeId == "HatchSpeed" then
		if val == 1.0 then
			return "Normal"
		else
			return math.floor((1 - val) * 100) .. "% faster"
		end
	end
	return tostring(val)
end

return UpgradeData
