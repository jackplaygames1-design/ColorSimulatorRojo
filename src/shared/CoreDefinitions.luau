local MutationDefinitions = require(script.Parent:WaitForChild("MutationDefinitions"))
local RarityDefinitions = require(script.Parent:WaitForChild("RarityDefinitions"))

local CoreDefinitions = {}

CoreDefinitions.Cores = {
	RedCore = {
		CoreId = "RedCore",
		DisplayName = "RED CORE",
		Currency = "Coins",
		CurrencyDisplayName = "Coins",
		Cost = 1000,
		FoundText = "8 / 14 Found",
		InteractionRadius = 28,
		RequireProximity = true,
		FallbackEggId = "ColorEgg",
		AccentColor = Color3.fromRGB(255, 48, 52),
		CoreColor = Color3.fromRGB(210, 12, 18),
	},
}

function CoreDefinitions.Get(coreId)
	return CoreDefinitions.Cores[tostring(coreId or "")] or CoreDefinitions.Cores.RedCore
end

function CoreDefinitions.FormatCost(core)
	core = type(core) == "table" and core or CoreDefinitions.Get(core)
	local cost = math.floor(tonumber(core.Cost) or 0)
	local text = tostring(cost)
	local left, num, right = string.match(text, "^([^%d]*%d)(%d*)(.-)$")
	if left then
		text = left .. (num:reverse():gsub("(%d%d%d)", "%1,"):reverse()) .. right
	end
	text = text:gsub("^,", "")
	return text .. " " .. tostring(core.CurrencyDisplayName or core.Currency or "")
end

function CoreDefinitions.GetOddsRows(coreId)
	local _core = CoreDefinitions.Get(coreId)
	return RarityDefinitions.GetOddsRows()
end

function CoreDefinitions.GetMutationRows()
	return MutationDefinitions.GetRows()
end

return CoreDefinitions
