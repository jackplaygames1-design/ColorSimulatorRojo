-- Server-authoritative Core RNG rolling. Results are granted into the existing
-- Color inventory as unique, manually-equipped Core color records.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ColorDefinitions = require(ReplicatedStorage:WaitForChild("ColorDefinitions"))
local CoreDefinitions = require(ReplicatedStorage:WaitForChild("CoreDefinitions"))
local GameBalance = require(ReplicatedStorage:WaitForChild("GameBalance"))
local MutationDefinitions = require(ReplicatedStorage:WaitForChild("MutationDefinitions"))
local RarityDefinitions = require(ReplicatedStorage:WaitForChild("RarityDefinitions"))

local Events = ReplicatedStorage:WaitForChild("Events")
local coreRollRequest = Events:WaitForChild("CoreRollRequest")
local coreRollResult = Events:WaitForChild("CoreRollResult")
local coreRollAnnouncement = Events:WaitForChild("CoreRollAnnouncement")
local coreRollState = Events:WaitForChild("CoreRollState")

local grantCoreColorFunction = ReplicatedStorage:WaitForChild("ServerGrantCoreColor")

local rng = Random.new()
local lastRollAt = {}
local warnedMissingCorePart = {}

local function getCoreConfig()
	return GameBalance.CoreRNG or {}
end

local function formatNumber(value)
	value = math.floor(tonumber(value) or 0)
	local text = tostring(value)
	while true do
		local nextText, replacements = string.gsub(text, "^(-?%d+)(%d%d%d)", "%1,%2")
		text = nextText
		if replacements == 0 then
			break
		end
	end
	return text
end

local function getRootPart(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function getCorePart(core)
	local coreId = tostring(core.CoreId or "RedCore")
	local fallbackEggId = tostring(core.FallbackEggId or "")
	local bestPart = nil
	local bestScore = -math.huge

	for _, descendant in ipairs(workspace:GetDescendants()) do
		local candidatePart = nil
		local score = -math.huge

		if descendant:IsA("BasePart") then
			candidatePart = descendant
			if descendant:GetAttribute("CoreId") == coreId then
				score = 100
			elseif fallbackEggId ~= "" and descendant:GetAttribute("EggId") == fallbackEggId then
				score = 80
			elseif string.lower(descendant.Name) == string.lower(coreId) then
				score = 70
			elseif fallbackEggId ~= "" and string.lower(descendant.Name) == string.lower(fallbackEggId) then
				score = 55
			elseif
				string.find(string.lower(descendant.Name), "core", 1, true)
				and string.find(string.lower(descendant.Name), "red", 1, true)
			then
				score = 40
			end
		elseif descendant:IsA("Model") then
			if descendant:GetAttribute("CoreId") == coreId then
				candidatePart = descendant.PrimaryPart or descendant:FindFirstChildWhichIsA("BasePart", true)
				score = 95
			elseif fallbackEggId ~= "" and descendant:GetAttribute("EggId") == fallbackEggId then
				candidatePart = descendant.PrimaryPart or descendant:FindFirstChildWhichIsA("BasePart", true)
				score = 75
			elseif string.lower(descendant.Name) == string.lower(coreId) then
				candidatePart = descendant.PrimaryPart or descendant:FindFirstChildWhichIsA("BasePart", true)
				score = 65
			end
		end

		if candidatePart and score > bestScore then
			bestPart = candidatePart
			bestScore = score
		end
	end

	return bestPart
end

local function isNearCore(player, core)
	local config = getCoreConfig()
	local coreOverride = config[core.CoreId] or {}
	local requireProximity = coreOverride.RequireProximity
	if requireProximity == nil then
		requireProximity = core.RequireProximity
	end
	if requireProximity == nil then
		requireProximity = true
	end
	if requireProximity ~= true then
		return true
	end

	local corePart = getCorePart(core)
	if not corePart then
		if not warnedMissingCorePart[core.CoreId] then
			warn(
				'CoreRollService: no editable Red Core part found. Add CoreId="'
					.. tostring(core.CoreId)
					.. '" to the Studio model/part.'
			)
			warnedMissingCorePart[core.CoreId] = true
		end
		return true
	end

	local root = getRootPart(player)
	if not root then
		return false
	end

	local radius = tonumber(coreOverride.InteractionRadius) or tonumber(core.InteractionRadius) or 28
	return (root.Position - corePart.Position).Magnitude <= radius
end

local function findNumberValue(parent, name)
	if not parent then
		return nil
	end
	local direct = parent:FindFirstChild(name)
	if direct and (direct:IsA("IntValue") or direct:IsA("NumberValue")) then
		return direct
	end
	for _, descendant in ipairs(parent:GetDescendants()) do
		if descendant.Name == name and (descendant:IsA("IntValue") or descendant:IsA("NumberValue")) then
			return descendant
		end
	end
	return nil
end

local function getCurrencyValue(player, currencyName)
	currencyName = tostring(currencyName or "Red")
	local leaderstats = player:FindFirstChild("leaderstats") or player:WaitForChild("leaderstats", 5)

	if currencyName == "Coins" or currencyName == "Coin" then
		local coins = findNumberValue(leaderstats, "Coins") or findNumberValue(leaderstats, "Coin")
		if coins then
			return coins
		end
	elseif currencyName == "Gems" or currencyName == "Diamonds" then
		local gems = findNumberValue(leaderstats, "Gems") or findNumberValue(leaderstats, "Diamonds")
		if gems then
			return gems
		end
	end

	local folders = {
		player:FindFirstChild("ColorCurrencies"),
		player:FindFirstChild("Currencies"),
		leaderstats,
		player:FindFirstChild("ColorStorage"),
		player,
	}

	for _, folder in ipairs(folders) do
		local value = findNumberValue(folder, currencyName)
		if value then
			return value
		end
	end

	if currencyName == "Red" then
		local coins = findNumberValue(leaderstats, "Coins")
		if coins then
			return coins
		end
	end

	return nil
end

local function getCurrencyAmount(player, core)
	local value = getCurrencyValue(player, core.Currency)
	return value and tonumber(value.Value) or 0, value
end

local function hasMutationsUnlocked(player)
	if player:GetAttribute("MutationsUnlocked") == true then
		return true
	end
	local progress = player:FindFirstChild("TutorialProgress")
	local unlocked = progress and progress:FindFirstChild("MutationsUnlocked")
	return unlocked and unlocked:IsA("BoolValue") and unlocked.Value == true
end

local function sendCoreState(player, core, message)
	local amount = getCurrencyAmount(player, core)
	coreRollState:FireClient(player, {
		CoreId = core.CoreId,
		Currency = core.Currency,
		Amount = amount,
		Cost = core.Cost,
		CanAfford = amount >= (tonumber(core.Cost) or 0),
		MutationsUnlocked = hasMutationsUnlocked(player),
		Message = message,
	})
end

local function getLuckMultiplier(player)
	local luck = 1
	local attributeLuck = tonumber(player:GetAttribute("CoreLuckMultiplier"))
	if attributeLuck then
		luck *= math.max(attributeLuck, 1)
	end
	return math.clamp(luck, 1, 4)
end

local function makeColorId(player, coreId)
	return table.concat({
		"core",
		tostring(player.UserId),
		tostring(coreId),
		tostring(os.time()),
		tostring(rng:NextInteger(100000, 999999)),
	}, "_")
end

local function buildRolledColor(player, core, rarity, colorId, colorData, mutationId, isGlitched)
	local power = RarityDefinitions.RollPower(rarity, rng)
	power = math.max(1, math.floor(power * MutationDefinitions.GetPowerMultiplier(mutationId, isGlitched)))

	return {
		ColorId = makeColorId(player, core.CoreId),
		ColorName = tostring(colorData.ColorName or colorId),
		Rarity = rarity,
		Power = power,
		Mutation = mutationId or MutationDefinitions.NoneId,
		IsGlitched = isGlitched == true,
		CoreId = core.CoreId,
		CreatedAt = os.time(),
		Locked = false,
		Equipped = false,
		PetId = colorId,
		BaseColorId = colorId,
		ColorType = colorData.ColorType or "Red",
	}
end

local function shouldAnnounce(result)
	local config = getCoreConfig().ChatAnnouncements or {}
	if result.IsGlitched == true and config.AnnounceGlitched ~= false then
		return true
	end
	if result.Rarity == "Secret" and config.AnnounceSecret ~= false then
		return true
	end
	if result.Rarity == "Mythic" and config.AnnounceMythic ~= false then
		return true
	end
	if result.Rarity == "Legendary" and config.AnnounceLegendary == true then
		return true
	end
	return false
end

local function announceRoll(player, result)
	if not shouldAnnounce(result) then
		return
	end

	local mutation = MutationDefinitions.Get(result.Mutation)
	local text
	if result.IsGlitched == true and mutation then
		text = ("[GLOBAL] %s hatched a GLITCHED %s %s!"):format(
			player.Name,
			string.upper(mutation.DisplayName),
			result.ColorName
		)
	elseif result.Rarity == "Secret" then
		text = ("[GLOBAL] %s discovered a SECRET %s!"):format(player.Name, result.ColorName)
	else
		text = ("[GLOBAL] %s hatched a %s %s!"):format(player.Name, string.upper(result.Rarity), result.ColorName)
	end

	coreRollAnnouncement:FireAllClients({
		Text = text,
		Rarity = result.Rarity,
		Mutation = result.Mutation,
		IsGlitched = result.IsGlitched,
		ColorName = result.ColorName,
	})
end

local function failRoll(player, core, message)
	coreRollResult:FireClient(player, false, {
		CoreId = core.CoreId,
		Message = message,
	})
	sendCoreState(player, core, message)
end

local function rollCore(player, coreId)
	local config = getCoreConfig()
	if config.Enabled == false then
		return failRoll(player, CoreDefinitions.Get(coreId), "Core rolling is disabled.")
	end

	local core = CoreDefinitions.Get(coreId or "RedCore")
	local coreOverride = config[core.CoreId] or {}
	local cost = tonumber(coreOverride.Cost) or tonumber(core.Cost) or 0
	core.Cost = cost
	if coreOverride.Currency ~= nil then
		core.Currency = tostring(coreOverride.Currency)
		core.CurrencyDisplayName = tostring(coreOverride.CurrencyDisplayName or coreOverride.Currency)
	end

	local now = os.clock()
	if now - (lastRollAt[player] or 0) < 0.45 then
		return failRoll(player, core, "Rolling too fast.")
	end
	lastRollAt[player] = now

	if not isNearCore(player, core) then
		return failRoll(player, core, "Move closer to the Core.")
	end

	local amount, currencyValue = getCurrencyAmount(player, core)
	if not currencyValue then
		return failRoll(player, core, "Missing " .. tostring(core.Currency) .. " currency.")
	end
	if amount < cost then
		return failRoll(player, core, "Need " .. CoreDefinitions.FormatCost(core) .. ".")
	end

	local rarity = RarityDefinitions.Roll(rng)
	local colorId, colorData = ColorDefinitions.GetColorForRarity(core.CoreId, rarity, rng)
	local mutationId, isGlitched = MutationDefinitions.NoneId, false
	if hasMutationsUnlocked(player) then
		mutationId, isGlitched = MutationDefinitions.Roll(rng, getLuckMultiplier(player))
	end
	local result = buildRolledColor(player, core, rarity, colorId, colorData, mutationId, isGlitched)

	currencyValue.Value = math.max(0, amount - cost)

	local invokeOk, granted, entryOrNil, reason = pcall(function()
		return grantCoreColorFunction:Invoke(player, result)
	end)
	if not invokeOk then
		currencyValue.Value = amount
		warn("CoreRollService: inventory grant failed: " .. tostring(granted))
		return failRoll(player, core, "Inventory is not ready.")
	end
	if not granted then
		currencyValue.Value = amount
		return failRoll(player, core, tostring(reason or "Inventory full."))
	end

	if type(entryOrNil) == "table" then
		result.InventoryKey = entryOrNil.variantKey
	end

	coreRollResult:FireClient(player, true, {
		CoreId = core.CoreId,
		Result = result,
		Entry = entryOrNil,
		Cost = cost,
		Currency = core.Currency,
		Remaining = currencyValue.Value,
	})
	sendCoreState(player, core, "+" .. result.ColorName)
	announceRoll(player, result)

	if (config.Debug or {}).PrintRolls == true then
		print(
			("CoreRollService: %s rolled %s %s mutation=%s glitched=%s power=%s"):format(
				player.Name,
				result.Rarity,
				result.ColorName,
				tostring(result.Mutation),
				tostring(result.IsGlitched),
				formatNumber(result.Power)
			)
		)
	end
end

coreRollRequest.OnServerEvent:Connect(function(player, coreId)
	rollCore(player, tostring(coreId or "RedCore"))
end)

Players.PlayerRemoving:Connect(function(player)
	lastRollAt[player] = nil
end)

print("CoreRollService ready")
