local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuffService = require(script.Parent:WaitForChild("BuffService"))
local ColorMutationData = require(ReplicatedStorage:WaitForChild("ColorMutationData"))
local ColorTraitData = require(ReplicatedStorage:WaitForChild("ColorTraitData"))
local GameBalance = require(ReplicatedStorage:WaitForChild("GameBalance"))
local PetData = require(ReplicatedStorage:WaitForChild("PetData"))
local ToolData = require(ReplicatedStorage:WaitForChild("ToolData"))

local ColorEffectHandler = {}

local CAPS = GameBalance.ColorEffects or {}

local DEFAULT_EFFECTS = {
	WalkSpeedBonus = 0,
	WalkSpeedMultiplier = 1,
	JumpPowerBonus = 0,
	BrushCooldownMultiplier = 1,
	BrushRangeMultiplier = 1,
	ColorGainMultiplier = 1,
	SellCoinsMultiplier = 1,
	HatchLuckBonus = 0,
	HatchLuckMultiplier = 1,
	LightningProcChance = 0,
	LightningTargets = 0,
	LightningRange = 0,
	LightningCooldown = 0,
	MagnetProcChance = 0,
	MagnetRange = 0,
	MagnetTargets = 0,
	GemRewardMultiplier = 1,
	GemDamageMultiplier = 1,
	GemSpawnChanceMultiplier = 1,
	ItemDropMultiplier = 1,
	CritChanceBonus = 0,
	InstantWeakSpillChance = 0,
	CoinBurstChance = 0,
	DoubleGemChance = 0,
	MutationLuckMultiplier = 1,
	RandomMultiplierCeiling = 1,
	ComboCoinMultiplier = 1,
	PetPowerMultiplier = 1,
	PetCoinMultiplier = 1,
	PetRangeMultiplier = 1,
	SourceMutationId = "None",
	BaseColorGainMultiplier = 1,
	BaseSellCoinsMultiplier = 1,
}

local function cloneDefaults()
	local result = {}
	for key, value in pairs(DEFAULT_EFFECTS) do
		result[key] = value
	end
	return result
end

local function parseInventory(str)
	local inventory = {}
	if not str or str == "" then
		return inventory
	end

	for _, part in ipairs(string.split(str, ",")) do
		local segments = string.split(part, ":")
		local variantKey
		local petId
		local stackIndex
		if tonumber(segments[2]) then
			petId = segments[1]
			stackIndex = 2
		else
			variantKey = segments[1]
			petId = segments[2]
			stackIndex = 3
		end

		if not petId or petId == "" or not PetData.Pets[petId] then
			continue
		end

		local stackAmount = math.max(1, tonumber(segments[stackIndex]) or 1)
		local traitId = PetData.normalizeTraitId(segments[stackIndex + 1])
		local shinyStr = segments[stackIndex + 2] or "normal"
		local personalityId = PetData.normalizePersonalityId(segments[stackIndex + 3] or "Neutral")
		local mutationId = PetData.normalizeMutationId(segments[stackIndex + 4] or "None")
		variantKey = PetData.makeVariantKey(petId, personalityId, mutationId, traitId)

		inventory[variantKey] = {
			petId = petId,
			stackAmount = stackAmount,
			traitId = traitId,
			isShiny = shinyStr == "shiny" or shinyStr == "true",
			personalityId = personalityId,
			mutationId = mutationId,
		}
	end

	return inventory
end

local function getPlayerInventoryData(player)
	local petFolder = player:FindFirstChild("PetData")
	local invVal = petFolder and petFolder:FindFirstChild("Inventory")
	local equippedVal = petFolder and petFolder:FindFirstChild("Equipped")
	if not invVal or not equippedVal then
		return {}, {}
	end

	local inventory = parseInventory(invVal.Value)
	local equipped = {}
	for _, rawKey in ipairs(string.split(equippedVal.Value or "", ",")) do
		local key = rawKey
		if inventory[key] then
			table.insert(equipped, key)
		else
			local legacyParts = string.split(rawKey, "|")
			for variantKey, data in pairs(inventory) do
				if
					rawKey == data.petId
					or rawKey == variantKey
					or (
						#legacyParts >= 3
						and legacyParts[1] == data.petId
						and PetData.normalizeMutationId(legacyParts[3]) == data.mutationId
					)
				then
					table.insert(equipped, variantKey)
					break
				end
			end
		end
	end

	return inventory, equipped
end

local function multiplyEffect(result, key, value)
	value = tonumber(value)
	if value and value > 0 then
		result[key] *= value
	end
end

local function addEffect(result, key, value)
	value = tonumber(value)
	if value then
		result[key] += value
	end
end

local function mergeEffects(result, effects)
	if type(effects) ~= "table" then
		return
	end

	addEffect(result, "WalkSpeedBonus", effects.WalkSpeedBonus)
	multiplyEffect(result, "WalkSpeedMultiplier", effects.WalkSpeedMultiplier)
	addEffect(result, "JumpPowerBonus", effects.JumpPowerBonus)
	multiplyEffect(result, "BrushCooldownMultiplier", effects.BrushCooldownMultiplier)
	multiplyEffect(result, "BrushRangeMultiplier", effects.BrushRangeMultiplier)
	multiplyEffect(result, "ColorGainMultiplier", effects.ColorGainMultiplier)
	multiplyEffect(result, "SellCoinsMultiplier", effects.SellCoinsMultiplier)
	addEffect(result, "HatchLuckBonus", effects.HatchLuckBonus)
	multiplyEffect(result, "HatchLuckMultiplier", effects.HatchLuckMultiplier)
	addEffect(result, "LightningProcChance", effects.LightningProcChance)
	result.LightningTargets += math.floor(tonumber(effects.LightningTargets) or 0)
	result.LightningRange = math.max(result.LightningRange, tonumber(effects.LightningRange) or 0)
	result.LightningCooldown = result.LightningCooldown == 0 and (tonumber(effects.LightningCooldown) or 0)
		or math.min(result.LightningCooldown, tonumber(effects.LightningCooldown) or result.LightningCooldown)
	addEffect(result, "MagnetProcChance", effects.MagnetProcChance)
	result.MagnetRange = math.max(result.MagnetRange, tonumber(effects.MagnetRange) or 0)
	result.MagnetTargets += math.floor(tonumber(effects.MagnetTargets) or 0)
	multiplyEffect(result, "GemRewardMultiplier", effects.GemRewardMultiplier)
	multiplyEffect(result, "GemDamageMultiplier", effects.GemDamageMultiplier)
	multiplyEffect(result, "GemSpawnChanceMultiplier", effects.GemSpawnChanceMultiplier)
	multiplyEffect(result, "ItemDropMultiplier", effects.ItemDropMultiplier)
	addEffect(result, "CritChanceBonus", effects.CritChanceBonus)
	addEffect(result, "InstantWeakSpillChance", effects.InstantWeakSpillChance)
	addEffect(result, "CoinBurstChance", effects.CoinBurstChance)
	addEffect(result, "DoubleGemChance", effects.DoubleGemChance)
	multiplyEffect(result, "MutationLuckMultiplier", effects.MutationLuckMultiplier)
	multiplyEffect(result, "RandomMultiplierCeiling", effects.RandomMultiplierCeiling)
	multiplyEffect(result, "ComboCoinMultiplier", effects.ComboCoinMultiplier)
	multiplyEffect(result, "PetPowerMultiplier", effects.PetPowerMultiplier)
	multiplyEffect(result, "PetCoinMultiplier", effects.PetCoinMultiplier)
	multiplyEffect(result, "PetRangeMultiplier", effects.PetRangeMultiplier)
end

local function clampEffects(result)
	result.WalkSpeedBonus = math.clamp(result.WalkSpeedBonus, 0, CAPS.MaxWalkSpeedFromColors or 8)
	result.WalkSpeedMultiplier = math.clamp(result.WalkSpeedMultiplier, 1, CAPS.MaxWalkSpeedMultiplierFromBuffs or 1.6)
	result.JumpPowerBonus = math.clamp(result.JumpPowerBonus, 0, CAPS.MaxJumpPowerFromColors or 30)
	result.BrushRangeMultiplier = math.clamp(result.BrushRangeMultiplier, 1, CAPS.MaxBrushRangeMultiplier or 1.75)
	result.ColorGainMultiplier = math.clamp(result.ColorGainMultiplier, 1, CAPS.MaxColorGainMultiplierFromColors or 3)
	result.SellCoinsMultiplier = math.clamp(result.SellCoinsMultiplier, 1, CAPS.MaxSellMultiplierFromColors or 3)
	result.HatchLuckBonus = math.clamp(result.HatchLuckBonus, 0, CAPS.MaxHatchLuckBonusFromColors or 0.5)
	result.HatchLuckMultiplier = math.clamp(result.HatchLuckMultiplier, 1, CAPS.MaxHatchLuckMultiplierFromBuffs or 2)
	result.LightningProcChance = math.clamp(result.LightningProcChance, 0, 0.75)
	result.LightningTargets = math.clamp(result.LightningTargets, 0, CAPS.LightningMaxTargetsPerProc or 4)
	result.LightningRange = math.clamp(result.LightningRange, 0, CAPS.LightningMaxRange or 55)
	result.MagnetProcChance = math.clamp(result.MagnetProcChance, 0, 0.75)
	result.MagnetTargets =
		math.clamp(result.MagnetTargets > 0 and result.MagnetTargets or 2, 0, CAPS.MagnetMaxTargetsPerProc or 5)
	result.MagnetRange = math.clamp(result.MagnetRange, 0, CAPS.MagnetMaxRange or 55)
	result.GemRewardMultiplier = math.clamp(result.GemRewardMultiplier, 1, 5)
	result.GemDamageMultiplier = math.clamp(result.GemDamageMultiplier, 1, 6)
	result.GemSpawnChanceMultiplier = math.clamp(result.GemSpawnChanceMultiplier, 1, 4)
	result.ItemDropMultiplier = math.clamp(result.ItemDropMultiplier, 1, 5)
	result.CritChanceBonus = math.clamp(result.CritChanceBonus, 0, 0.75)
	result.InstantWeakSpillChance = math.clamp(result.InstantWeakSpillChance, 0, 0.5)
	result.CoinBurstChance = math.clamp(result.CoinBurstChance, 0, 0.75)
	result.DoubleGemChance = math.clamp(result.DoubleGemChance, 0, 0.75)
	result.MutationLuckMultiplier = math.clamp(result.MutationLuckMultiplier, 1, 4)
	result.RandomMultiplierCeiling = math.clamp(result.RandomMultiplierCeiling, 1, 6)
	result.ComboCoinMultiplier = math.clamp(result.ComboCoinMultiplier, 1, 4)
	result.PetPowerMultiplier = math.clamp(result.PetPowerMultiplier, 1, 1.75)
	result.PetCoinMultiplier = math.clamp(result.PetCoinMultiplier, 1, 1.75)
	result.PetRangeMultiplier = math.clamp(result.PetRangeMultiplier, 1, 1.5)
	if result.LightningCooldown <= 0 then
		result.LightningCooldown = 4
	end
end

local function getEquippedBrushPassiveEffects(player)
	local toolsFolder = player and player:FindFirstChild("PaintTools")
	local equippedValue = toolsFolder and toolsFolder:FindFirstChild("Equipped")
	local brushId = equippedValue and equippedValue.Value or "StarterBrush"
	if not ToolData.GetBrushPassiveEffects then
		return nil
	end
	return ToolData.GetBrushPassiveEffects(brushId, player)
end

function ColorEffectHandler.CalculateEquippedColorEffects(player)
	local result = cloneDefaults()
	local inventory, equipped = getPlayerInventoryData(player)

	for _, variantKey in ipairs(equipped) do
		local data = inventory[variantKey]
		if data then
			local entry = PetData.buildPetEntry(
				data.petId,
				data.stackAmount,
				data.isShiny,
				data.personalityId,
				data.mutationId,
				data.traitId
			)
			if entry then
				multiplyEffect(result, "BaseColorGainMultiplier", entry.colorMult or 1)
				multiplyEffect(result, "BaseSellCoinsMultiplier", entry.coinMult or 1)
			end

			local trait = ColorTraitData.get(data.traitId)
			local mutation = ColorMutationData.get(data.mutationId)
			mergeEffects(result, trait and trait.Effects)
			mergeEffects(result, mutation and mutation.Effects)
			if mutation and ColorMutationData.isMutated(mutation.Id) then
				result.SourceMutationId = mutation.Id
			end
		end
	end

	mergeEffects(result, BuffService.GetEffects(player))
	mergeEffects(result, getEquippedBrushPassiveEffects(player))

	clampEffects(result)
	result.ColorGainMultiplier *= result.BaseColorGainMultiplier
	result.SellCoinsMultiplier *= result.BaseSellCoinsMultiplier
	return result
end

function ColorEffectHandler.GetColorGainMultiplier(player)
	return ColorEffectHandler.CalculateEquippedColorEffects(player).ColorGainMultiplier
end

function ColorEffectHandler.GetSellCoinsMultiplier(player)
	return ColorEffectHandler.CalculateEquippedColorEffects(player).SellCoinsMultiplier
end

function ColorEffectHandler.GetHatchLuckBonus(player)
	return ColorEffectHandler.CalculateEquippedColorEffects(player).HatchLuckBonus
end

function ColorEffectHandler.GetHatchLuckMultiplier(player)
	return ColorEffectHandler.CalculateEquippedColorEffects(player).HatchLuckMultiplier
end

function ColorEffectHandler.ApplyCharacterEffects(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local effects = ColorEffectHandler.CalculateEquippedColorEffects(player)
	local upgrades = player:FindFirstChild("Upgrades")
	local walkSpeedValue = upgrades and upgrades:FindFirstChild("WalkSpeed")
	local baseWalkSpeed = walkSpeedValue and walkSpeedValue.Value or (CAPS.BaseWalkSpeed or 16)
	local walkSpeed = math.min(
		(baseWalkSpeed + effects.WalkSpeedBonus) * effects.WalkSpeedMultiplier,
		CAPS.AbsoluteMaxWalkSpeed or 28
	)
	humanoid.WalkSpeed = walkSpeed

	humanoid.UseJumpPower = true
	local baseJumpPower = CAPS.BaseJumpPower or 50
	local jumpPower = math.min(baseJumpPower + effects.JumpPowerBonus, CAPS.AbsoluteMaxJumpPower or 85)
	humanoid.JumpPower = jumpPower
end

return ColorEffectHandler
