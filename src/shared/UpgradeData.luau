local UpgradeData = {}

local function makeLevels(values, costs)
	local levels = {}
	for index, value in ipairs(values) do
		levels[index] = {
			value = value,
			cost = costs[index] or costs[#costs] or 0,
			currency = "Gems",
		}
	end
	return levels
end

local playerCosts = { 25, 50, 100, 175, 275, 425, 650, 950, 1350, 1900 }
local brushCosts = { 35, 75, 140, 240, 375, 575, 850, 1250, 1800, 2500 }
local economyCosts = { 50, 110, 200, 350, 550, 825, 1200, 1700, 2350, 3200 }

UpgradeData.Upgrades = {
	{
		id = "WalkSpeed",
		displayName = "Walk Speed",
		category = "Player",
		icon = "SPD",
		iconKey = "walk_speed",
		description = "Move faster around the map.",
		baseValue = 44,
		valueFormat = "speed",
		levels = makeLevels({ 48, 52, 56, 60, 64, 68, 72, 76, 80, 84 }, playerCosts),
	},
	{
		id = "PetSlots",
		displayName = "Color Slots",
		category = "Player",
		icon = "SLOT",
		iconKey = "inventory_size",
		description = "Equip more Colors at once.",
		baseValue = 3,
		valueFormat = "slots",
		levels = makeLevels({ 4, 5, 6, 7, 8, 9, 10, 11, 12, 13 }, playerCosts),
	},
	{
		id = "PlayerPower",
		displayName = "Player Power",
		category = "Player",
		icon = "PWR",
		iconKey = "player_power",
		description = "Boost all Color breaking power.",
		baseValue = 1,
		valueFormat = "multiplier",
		levels = makeLevels({ 1.08, 1.16, 1.25, 1.35, 1.48, 1.62, 1.78, 1.95, 2.15, 2.4 }, playerCosts),
	},
	{
		id = "Luck",
		displayName = "Gem Luck",
		category = "Player",
		icon = "LUK",
		iconKey = "luck",
		description = "Improve rare Color hatch chances.",
		baseValue = 1,
		valueFormat = "multiplier",
		levels = makeLevels({ 1.05, 1.1, 1.16, 1.23, 1.31, 1.4, 1.5, 1.62, 1.76, 1.9 }, playerCosts),
	},
	{
		id = "GemCapacity",
		displayName = "Gem Capacity",
		category = "Player",
		icon = "GEM",
		iconKey = "gem_capacity",
		description = "Hold more mined Gems.",
		baseValue = 250,
		valueFormat = "number",
		levels = makeLevels({ 400, 650, 1000, 1500, 2200, 3200, 4600, 6500, 9000, 12500 }, playerCosts),
	},
	{
		id = "Health",
		displayName = "Health",
		category = "Player",
		icon = "HP",
		iconKey = "health",
		description = "Increase your maximum health.",
		baseValue = 100,
		valueFormat = "number",
		levels = makeLevels({ 115, 130, 145, 160, 180, 200, 225, 250, 280, 320 }, playerCosts),
	},
	{
		id = "BrushPower",
		displayName = "Brush Power",
		category = "Brush",
		icon = "BR",
		iconKey = "brush_power",
		description = "Break Colors faster.",
		baseValue = 1,
		valueFormat = "multiplier",
		levels = makeLevels({ 1.12, 1.25, 1.4, 1.58, 1.78, 2, 2.25, 2.55, 2.9, 3.3 }, brushCosts),
	},
	{
		id = "BrushSize",
		displayName = "Brush Size",
		category = "Brush",
		icon = "SIZE",
		iconKey = "brush_size",
		description = "Widen your brush sweep.",
		baseValue = 1,
		valueFormat = "multiplier",
		levels = makeLevels({ 1.05, 1.1, 1.16, 1.22, 1.3, 1.38, 1.48, 1.58, 1.7, 1.85 }, brushCosts),
	},
	{
		id = "PaintCapacity",
		displayName = "Paint Capacity",
		category = "Brush",
		icon = "CAP",
		iconKey = "paint_capacity",
		description = "Carry more paint between upgrades.",
		baseValue = 100,
		valueFormat = "number",
		levels = makeLevels({ 125, 155, 190, 230, 280, 340, 415, 500, 610, 750 }, brushCosts),
	},
	{
		id = "PaintSpeed",
		displayName = "Paint Speed",
		category = "Brush",
		icon = "FAST",
		iconKey = "paint_speed",
		description = "Use your brush more quickly.",
		baseValue = 1,
		valueFormat = "multiplier",
		levels = makeLevels({ 1.08, 1.16, 1.25, 1.35, 1.46, 1.58, 1.72, 1.88, 2.05, 2.25 }, brushCosts),
	},
	{
		id = "PickupRange",
		displayName = "Splash Range",
		category = "Brush",
		icon = "RNG",
		iconKey = "splash_range",
		description = "Reach Colors from farther away.",
		baseValue = 8,
		valueFormat = "studs",
		levels = makeLevels({ 10, 12, 15, 18, 22, 26, 30, 35, 40, 46 }, brushCosts),
	},
	{
		id = "CritChance",
		displayName = "Crit Chance",
		category = "Brush",
		icon = "CRIT",
		iconKey = "crit_chance",
		description = "Chance to double Color rewards.",
		baseValue = 0,
		valueFormat = "percent",
		levels = makeLevels({ 0.02, 0.04, 0.06, 0.08, 0.1, 0.12, 0.145, 0.17, 0.2, 0.25 }, brushCosts),
	},
	{
		id = "ColorMultiplier",
		displayName = "Coin Boost",
		category = "Economy",
		icon = "2X",
		iconKey = "coin_multiplier",
		description = "Earn more Coins from breaks.",
		baseValue = 1,
		valueFormat = "multiplier",
		levels = makeLevels({ 1.15, 1.3, 1.5, 1.75, 2.05, 2.4, 2.8, 3.25, 3.8, 4.5 }, economyCosts),
	},
	{
		id = "CoinCapacity",
		displayName = "Coin Capacity",
		category = "Economy",
		icon = "BAG",
		iconKey = "coin_capacity",
		description = "Increase your Coin storage cap.",
		baseValue = 10000,
		valueFormat = "number",
		levels = makeLevels(
			{ 15000, 22500, 34000, 50000, 75000, 110000, 165000, 250000, 375000, 550000 },
			economyCosts
		),
	},
	{
		id = "SellValue",
		displayName = "Sell Value",
		category = "Economy",
		icon = "SELL",
		iconKey = "sell_value",
		description = "Increase sell and Coin value.",
		baseValue = 1,
		valueFormat = "multiplier",
		levels = makeLevels({ 1.1, 1.22, 1.36, 1.52, 1.7, 1.9, 2.15, 2.45, 2.8, 3.2 }, economyCosts),
	},
	{
		id = "GemMultiplier",
		displayName = "Gem Multiplier",
		category = "Economy",
		icon = "GEM",
		iconKey = "gem_multiplier",
		description = "Earn more Gems from deposits.",
		baseValue = 1,
		valueFormat = "multiplier",
		levels = makeLevels({ 1.1, 1.22, 1.35, 1.5, 1.68, 1.88, 2.1, 2.35, 2.65, 3 }, economyCosts),
	},
	{
		id = "GemValue",
		displayName = "Gem Value",
		category = "Economy",
		icon = "VAL",
		iconKey = "gem_value",
		description = "Boost every mined Gem reward.",
		baseValue = 1,
		valueFormat = "multiplier",
		levels = makeLevels({ 1.08, 1.18, 1.3, 1.44, 1.6, 1.78, 2, 2.25, 2.55, 2.9 }, economyCosts),
	},
	{
		id = "PassiveIncome",
		displayName = "Passive Income",
		category = "Economy",
		icon = "PIG",
		iconKey = "passive_income",
		description = "Stores passive income power.",
		baseValue = 0,
		valueFormat = "number",
		levels = makeLevels({ 5, 10, 18, 28, 42, 60, 85, 115, 155, 210 }, economyCosts),
	},
}

UpgradeData.Aliases = {
	BrushRange = "PickupRange",
	CoinBoost = "ColorMultiplier",
	CoinMultiplier = "ColorMultiplier",
	ColorLuck = "Luck",
	GemBoost = "GemMultiplier",
	GemLuck = "Luck",
	HatchSpeed = "PaintSpeed",
	InventorySize = "PetSlots",
}

UpgradeData.ById = {}
UpgradeData.ByNormalizedName = {}

local function normalizeName(name)
	return string.lower(tostring(name or "")):gsub("[^%w]", "")
end

for _, upgrade in ipairs(UpgradeData.Upgrades) do
	UpgradeData.ById[upgrade.id] = upgrade
	UpgradeData.ByNormalizedName[normalizeName(upgrade.displayName)] = upgrade.id
	UpgradeData.ByNormalizedName[normalizeName(upgrade.id)] = upgrade.id
end

function UpgradeData.getCanonicalId(id)
	if type(id) ~= "string" then
		return nil
	end
	if UpgradeData.ById[id] then
		return id
	end
	return UpgradeData.Aliases[id]
end

function UpgradeData.getUpgrade(id)
	local canonicalId = UpgradeData.getCanonicalId(id)
	return canonicalId and UpgradeData.ById[canonicalId] or nil
end

function UpgradeData.getUpgradeByCardName(cardName)
	local directId = UpgradeData.ByNormalizedName[normalizeName(cardName)]
	if directId then
		return UpgradeData.getUpgrade(directId)
	end

	local cleaned = normalizeName(tostring(cardName or ""):gsub("Card$", ""))
	directId = UpgradeData.ByNormalizedName[cleaned]
	return directId and UpgradeData.getUpgrade(directId) or nil
end

function UpgradeData.getCategoryUpgrades(category)
	local upgrades = {}
	for _, upgrade in ipairs(UpgradeData.Upgrades) do
		if upgrade.category == category then
			table.insert(upgrades, upgrade)
		end
	end
	return upgrades
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

local function trimNumber(value)
	local text = string.format("%.2f", tonumber(value) or 0)
	text = text:gsub("0+$", "")
	return text:gsub("%.$", "")
end

function UpgradeData.getLevelData(upgradeId, level)
	local upgrade = UpgradeData.getUpgrade(upgradeId)
	if not upgrade then
		return nil
	end
	return upgrade.levels[tonumber(level) or 0]
end

function UpgradeData.getNextLevelData(upgradeId, level)
	local upgrade = UpgradeData.getUpgrade(upgradeId)
	if not upgrade then
		return nil
	end
	return upgrade.levels[(tonumber(level) or 0) + 1]
end

function UpgradeData.getValue(upgradeId, level)
	local upgrade = UpgradeData.getUpgrade(upgradeId)
	if not upgrade then
		return nil
	end

	level = math.max(0, tonumber(level) or 0)
	if level <= 0 then
		return upgrade.baseValue
	end

	local levelData = upgrade.levels[level]
	return levelData and levelData.value or upgrade.baseValue
end

function UpgradeData.getValueDisplay(upgradeId, level)
	local upgrade = UpgradeData.getUpgrade(upgradeId)
	if not upgrade then
		return "?"
	end

	local value = UpgradeData.getValue(upgrade.id, level)
	if upgrade.valueFormat == "speed" then
		return tostring(value) .. " speed"
	elseif upgrade.valueFormat == "slots" then
		return tostring(value) .. " slots"
	elseif upgrade.valueFormat == "studs" then
		return tostring(value) .. " studs"
	elseif upgrade.valueFormat == "multiplier" then
		return "x" .. trimNumber(value)
	elseif upgrade.valueFormat == "percent" then
		return tostring(math.floor((tonumber(value) or 0) * 100 + 0.5)) .. "%"
	end

	return UpgradeData.formatNumber(value)
end

return UpgradeData
