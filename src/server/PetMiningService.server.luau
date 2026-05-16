local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BreakableService = require(script.Parent:WaitForChild("BreakableService"))
local GameBalance = require(ReplicatedStorage:WaitForChild("GameBalance"))
local PetData = require(ReplicatedStorage:WaitForChild("PetData"))

local Events = ReplicatedStorage:WaitForChild("Events")
local petAttackEvent = Events:WaitForChild("PetAttack")

local config = GameBalance.Breakables or {}
local petConfig = config.Pets or {}
if
	config.Enabled == false
	or petConfig.Enabled == false
	or (GameBalance.GameMode and GameBalance.GameMode.UseBreakables == false)
then
	return
end

local lastAttackAt = {}
local lastTargetAt = {}
local currentTargets = {}

local function parseCsv(value)
	local result = {}
	for _, segment in ipairs(string.split(tostring(value or ""), ",")) do
		if segment ~= "" then
			table.insert(result, segment)
		end
	end
	return result
end

local function decodeInventoryValue(value)
	local records = {}
	for _, encoded in ipairs(parseCsv(value)) do
		local segments = string.split(encoded, ":")
		local variantKey
		local petId
		local stackIndex
		if tonumber(segments[2]) then
			petId = segments[1]
			variantKey = petId
			stackIndex = 2
		else
			variantKey = segments[1]
			petId = segments[2]
			stackIndex = 3
		end
		if variantKey and petId then
			records[variantKey] = {
				variantKey = variantKey,
				petId = petId,
				stackAmount = tonumber(segments[stackIndex]) or 1,
				traitId = segments[stackIndex + 1],
				isShiny = segments[stackIndex + 2] == "shiny" or segments[stackIndex + 2] == "true",
				personalityId = segments[stackIndex + 3] or "Neutral",
				mutationId = segments[stackIndex + 4] or "None",
				isCoreColor = segments[stackIndex + 5] == "core",
				power = segments[stackIndex + 5] == "core" and tonumber(segments[stackIndex + 9]) or nil,
				isGlitched = segments[stackIndex + 5] == "core"
						and (segments[stackIndex + 11] == "true" or segments[stackIndex + 11] == "1")
					or false,
			}
		end
	end
	return records
end

local function getEquippedRecords(player)
	local petFolder = player:FindFirstChild("PetData")
	local inventoryValue = petFolder and petFolder:FindFirstChild("Inventory")
	local equippedValue = petFolder and petFolder:FindFirstChild("Equipped")
	if not inventoryValue or not equippedValue then
		return {}
	end
	local inventory = decodeInventoryValue(inventoryValue.Value)
	local equipped = {}
	for _, key in ipairs(parseCsv(equippedValue.Value)) do
		if inventory[key] then
			table.insert(equipped, inventory[key])
		end
	end
	return equipped
end

local function getMutationBonus(record, target)
	local multiplier = 1
	local mutationId = tostring(record.mutationId or "None")
	local bonuses = petConfig.MutationBonuses or {}
	local bonus = bonuses[mutationId]
	if bonus then
		multiplier *= tonumber(bonus.DamageMultiplier) or 1
		local breakableType = target and target:GetAttribute("BreakableType")
		if breakableType and string.find(string.lower(breakableType), "chest", 1, true) then
			multiplier *= tonumber(bonus.ChestDamageMultiplier) or 1
		end
	end
	if record.isGlitched == true then
		multiplier *= tonumber(petConfig.GlitchedDamageMultiplier) or 1.5
	end
	return multiplier
end

local function getRecordPower(record, target)
	if record.isCoreColor and tonumber(record.power) then
		return math.max(1, tonumber(record.power) or 1) * getMutationBonus(record, target)
	end
	local entry = PetData.buildPetEntry(
		record.petId,
		record.stackAmount,
		record.isShiny,
		record.personalityId,
		record.mutationId,
		record.traitId
	)
	return math.max(0, tonumber(entry and entry.finalPower) or 0) * getMutationBonus(record, target)
end

local function getRoot(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function chooseTarget(player, root)
	local now = os.clock()
	local current = currentTargets[player]
	local range = tonumber(petConfig.TargetRange) or 60
	if
		current
		and current.Parent
		and current.PrimaryPart
		and current:GetAttribute("Alive") == true
		and (current.PrimaryPart.Position - root.Position).Magnitude <= range
		and now - (lastTargetAt[player] or 0) < (tonumber(petConfig.RetargetInterval) or 0.5)
	then
		return current
	end

	lastTargetAt[player] = now
	local candidates = BreakableService.GetBreakablesInRange(root.Position, range)
	currentTargets[player] = candidates[1] and candidates[1].Model or nil
	return currentTargets[player]
end

local function getAttackInterval(records)
	local interval = tonumber(petConfig.AttackInterval) or 0.75
	for _, record in ipairs(records) do
		local bonus = (petConfig.MutationBonuses or {})[tostring(record.mutationId or "None")]
		if bonus and bonus.AttackIntervalMultiplier then
			interval *= tonumber(bonus.AttackIntervalMultiplier) or 1
		end
	end
	return math.clamp(interval, 0.2, 2)
end

task.spawn(function()
	while true do
		local now = os.clock()
		for _, player in ipairs(Players:GetPlayers()) do
			local root = getRoot(player)
			if not root then
				continue
			end
			local records = getEquippedRecords(player)
			local interval = getAttackInterval(records)
			if now - (lastAttackAt[player] or 0) < interval then
				continue
			end

			local target = chooseTarget(player, root)
			if not target then
				continue
			end

			local totalDamage = 0
			for _, record in ipairs(records) do
				totalDamage += getRecordPower(record, target)
			end
			if #records == 0 then
				totalDamage = tonumber(petConfig.BaseDamageIfNoPets) or 0
			end
			if totalDamage <= 0 then
				continue
			end
			totalDamage =
				math.max(totalDamage * (tonumber(petConfig.PowerScale) or 1), tonumber(petConfig.MinDamage) or 1)

			lastAttackAt[player] = now
			BreakableService.DamageBreakable(player, target, totalDamage)
			local petFolder = player:FindFirstChild("PetData")
			local equippedValue = petFolder and petFolder:FindFirstChild("Equipped")
			petAttackEvent:FireClient(
				player,
				parseCsv(equippedValue and equippedValue.Value or ""),
				target.PrimaryPart,
				target:GetAttribute("ColorType") or "Red"
			)
		end
		task.wait(0.1)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastAttackAt[player] = nil
	lastTargetAt[player] = nil
	currentTargets[player] = nil
end)

print("PetMiningService ready")
