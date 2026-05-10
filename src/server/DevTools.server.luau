local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Events = ReplicatedStorage:WaitForChild("Events")
local PetData = require(ReplicatedStorage:WaitForChild("PetData"))
local ColorTraitData = require(ReplicatedStorage:WaitForChild("ColorTraitData"))
local ColorMutationData = require(ReplicatedStorage:WaitForChild("ColorMutationData"))
local GamepassBenefits = require(script.Parent:WaitForChild("GamepassBenefits"))
local AdminConfig = require(ReplicatedStorage:WaitForChild("AdminConfig"))
local grantCoinsEvent = Events:WaitForChild("DevGrantCoins")
local resetProfileRemote = Events:FindFirstChild("DevResetProfile")
if not resetProfileRemote then
	resetProfileRemote = Instance.new("RemoteEvent")
	resetProfileRemote.Name = "DevResetProfile"
	resetProfileRemote.Parent = Events
end
local resetProfileFunction = ReplicatedStorage:FindFirstChild("StudioResetProfile")
if not resetProfileFunction then
	resetProfileFunction = Instance.new("BindableFunction")
	resetProfileFunction.Name = "StudioResetProfile"
	resetProfileFunction.Parent = ReplicatedStorage
end
local grantRainbowFunction = ReplicatedStorage:FindFirstChild("StudioGrantRainbowColor")
if not grantRainbowFunction then
	grantRainbowFunction = Instance.new("BindableFunction")
	grantRainbowFunction.Name = "StudioGrantRainbowColor"
	grantRainbowFunction.Parent = ReplicatedStorage
end
local forceMutationFunction = ReplicatedStorage:FindFirstChild("StudioForceNextMutation")
if not forceMutationFunction then
	forceMutationFunction = Instance.new("BindableFunction")
	forceMutationFunction.Name = "StudioForceNextMutation"
	forceMutationFunction.Parent = ReplicatedStorage
end
local grantAllGamepassesFunction = ReplicatedStorage:FindFirstChild("StudioGrantAllGamepasses")
if not grantAllGamepassesFunction then
	grantAllGamepassesFunction = Instance.new("BindableFunction")
	grantAllGamepassesFunction.Name = "StudioGrantAllGamepasses"
	grantAllGamepassesFunction.Parent = ReplicatedStorage
end

local DEV_COIN_AMOUNT = 2000000000

local DEFAULTS = {
	Coins = 0,
	Gems = 0,
	Diamonds = 0,
	Rebirths = 0,
	UnlockedColors = "Red",
	CurrentWorld = "Red",
	MaxPetSlots = 3,
	WalkSpeed = 44,
}

local function findPlayerByName(name)
	if not name or tostring(name) == "" then
		return Players:GetPlayers()[1]
	end

	local wanted = string.lower(tostring(name))
	for _, candidate in ipairs(Players:GetPlayers()) do
		if string.lower(candidate.Name) == wanted or string.lower(candidate.DisplayName) == wanted then
			return candidate
		end
	end

	return Players:FindFirstChild(tostring(name))
end

local function canUseGamepassGrant(actor)
	if RunService:IsStudio() then
		return true
	end
	if not actor then
		return false
	end
	if game.CreatorType == Enum.CreatorType.User and actor.UserId == game.CreatorId then
		return true
	end
	return AdminConfig.isModeratorName(actor.Name)
end

grantCoinsEvent.OnServerEvent:Connect(function(player)
	if not RunService:IsStudio() then
		warn("DevTools: blocked coin grant outside Studio for " .. player.Name)
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")
	if not coins or not coins:IsA("IntValue") then
		return
	end

	coins.Value = DEV_COIN_AMOUNT
	print("DevTools: set " .. player.Name .. " coins to " .. tostring(DEV_COIN_AMOUNT))
end)

local function clearChildren(folder)
	if not folder then
		return
	end

	for _, child in ipairs(folder:GetChildren()) do
		child:Destroy()
	end
end

local function setValue(parent, name, value)
	local child = parent and parent:FindFirstChild(name)
	if child and child:IsA("ValueBase") then
		child.Value = value
	end
end

local function resetPlayer(player)
	if not RunService:IsStudio() then
		warn("DevTools: blocked profile reset outside Studio for " .. tostring(player and player.Name))
		return false
	end
	player:SetAttribute("IntentionalProfileReset", true)

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		setValue(leaderstats, "Coins", DEFAULTS.Coins)
		setValue(leaderstats, "Gems", DEFAULTS.Gems)
		setValue(leaderstats, "Diamonds", DEFAULTS.Diamonds)
		setValue(leaderstats, "Rebirths", DEFAULTS.Rebirths)
	end

	local storage = player:FindFirstChild("ColorStorage")
	if storage then
		setValue(storage, "UnlockedColors", DEFAULTS.UnlockedColors)
		setValue(storage, "CurrentWorld", DEFAULTS.CurrentWorld)
	end
	player:SetAttribute("ActiveWorldColor", DEFAULTS.CurrentWorld)

	local petFolder = player:FindFirstChild("PetData")
	if petFolder then
		setValue(petFolder, "Inventory", "")
		setValue(petFolder, "Equipped", "")
		local maxSlots = petFolder:FindFirstChild("MaxSlots")
		if not maxSlots then
			maxSlots = Instance.new("IntValue")
			maxSlots.Name = "MaxSlots"
			maxSlots.Parent = petFolder
		end
		maxSlots.Value = DEFAULTS.MaxPetSlots
	end

	local upgrades = player:FindFirstChild("Upgrades")
	if upgrades then
		for _, child in ipairs(upgrades:GetChildren()) do
			if child:IsA("IntValue") and child.Name:find("_Level") then
				child.Value = 0
			elseif child:IsA("NumberValue") or child:IsA("IntValue") then
				if child.Name == "PickupRange" then
					child.Value = 8
				elseif child.Name == "ColorMultiplier" then
					child.Value = 1
				elseif child.Name == "HatchSpeed" then
					child.Value = 1
				elseif child.Name == "WalkSpeed" then
					child.Value = DEFAULTS.WalkSpeed
				elseif child.Name == "PetSlots" then
					child.Value = DEFAULTS.MaxPetSlots
				end
			end
		end
	end

	clearChildren(player:FindFirstChild("RedeemedCodes"))
	clearChildren(player:FindFirstChild("Boosts"))
	clearChildren(player:FindFirstChild("ItemFlags"))

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = DEFAULTS.WalkSpeed
	end

	print("Studio profile reset complete")
	print("DevTools: reset profile stats for " .. player.Name)
	return true
end

resetProfileFunction.OnInvoke = function(playerName)
	if not RunService:IsStudio() then
		warn("DevTools: blocked profile reset outside Studio")
		return false
	end

	local player = playerName and Players:FindFirstChild(tostring(playerName)) or Players:GetPlayers()[1]
	if not player then
		warn("DevTools: no player found to reset")
		return false
	end

	return resetPlayer(player)
end

resetProfileRemote.OnServerEvent:Connect(function(player)
	if not RunService:IsStudio() then
		warn("DevTools: blocked remote profile reset outside Studio for " .. player.Name)
		return
	end

	resetPlayer(player)
end)

local function grantRainbowColor(player)
	if not RunService:IsStudio() then
		warn("DevTools: blocked Rainbow Color grant outside Studio")
		return false
	end
	if not player then
		warn("DevTools: no player found for Rainbow Color grant")
		return false
	end

	local grantPetFunction = ReplicatedStorage:FindFirstChild("ServerGrantPet")
	if not grantPetFunction or not grantPetFunction:IsA("BindableFunction") then
		warn("DevTools: ServerGrantPet function is missing")
		return false
	end

	local ok, entry = grantPetFunction:Invoke(player, "DevRainbowPet", 1, "SuperLucky", "None", false)
	if ok then
		print("DevTools: added Rainbow Pet to " .. player.Name .. "'s inventory")
	else
		warn("DevTools: failed to add Rainbow Pet to " .. player.Name .. "'s inventory")
	end
	return ok, entry
end

grantRainbowFunction.OnInvoke = function(playerName)
	if not RunService:IsStudio() then
		warn("DevTools: blocked Rainbow Color grant outside Studio")
		return false
	end

	local player = playerName and Players:FindFirstChild(tostring(playerName)) or Players:GetPlayers()[1]
	return grantRainbowColor(player)
end

forceMutationFunction.OnInvoke = function(playerName, mutationId)
	if not RunService:IsStudio() then
		warn("DevTools: blocked forced mutation outside Studio")
		return false
	end

	local player = playerName and Players:FindFirstChild(tostring(playerName)) or Players:GetPlayers()[1]
	if not player then
		warn("DevTools: no player found for forced mutation")
		return false
	end

	local normalizedMutationId = ColorMutationData.normalize(mutationId or "BlackHole")
	if normalizedMutationId == ColorMutationData.NoneId then
		warn("DevTools: unknown mutation " .. tostring(mutationId))
		return false
	end

	player:SetAttribute("ForceNextMutation", normalizedMutationId)
	print("DevTools: next hatch mutation for " .. player.Name .. " forced to " .. normalizedMutationId)
	return true, normalizedMutationId
end

local function grantAllGamepasses(player, actor)
	if not canUseGamepassGrant(actor) then
		warn("DevTools: blocked gamepass grant from " .. tostring(actor and actor.Name or "server"))
		return false
	end
	if not player then
		warn("DevTools: no player found for gamepass grant")
		return false
	end

	local ok, granted = GamepassBenefits.grantAll(player)
	if ok then
		print("DevTools: granted all gamepasses to " .. player.Name .. ": " .. table.concat(granted, ", "))
	else
		warn("DevTools: failed to grant gamepasses to " .. player.Name)
	end
	return ok, granted
end

grantAllGamepassesFunction.OnInvoke = function(playerName)
	if not RunService:IsStudio() then
		warn("DevTools: blocked gamepass grant outside Studio")
		return false
	end

	local player = findPlayerByName(playerName)
	return grantAllGamepasses(player, nil)
end

Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(message)
		local normalized = string.lower(tostring(message or ""))
		local parts = string.split(tostring(message or ""), " ")
		local command = string.lower(parts[1] or "")
		if command == "/grantpasses" or command == "/grantallgamepasses" then
			local target = parts[2] and findPlayerByName(parts[2]) or player
			grantAllGamepasses(target, player)
			return
		end

		if not RunService:IsStudio() then
			return
		end

		if normalized == "/resetprofile" or normalized == "!resetprofile" or normalized == "/reset" then
			resetPlayer(player)
			return
		end

		if command == "/printpetdata" or command == "/printcolordata" then
			local printPetDataFunction = ReplicatedStorage:FindFirstChild("PrintPetData")
			if printPetDataFunction and printPetDataFunction:IsA("BindableFunction") then
				printPetDataFunction:Invoke(player.Name)
			else
				warn("DevTools: PrintPetData function is missing")
			end
		elseif command == "/forceMutation" or command == "/forcemutation" then
			local mutationId = ColorMutationData.normalize(parts[2] or "BlackHole")
			if mutationId ~= ColorMutationData.NoneId then
				player:SetAttribute("ForceNextMutation", mutationId)
				print("DevTools: next hatch mutation for " .. player.Name .. " forced to " .. mutationId)
			else
				warn("DevTools: unknown mutation " .. tostring(parts[2]))
			end
		elseif command == "/givecolor" then
			local petId = parts[2] or "RedCubey"
			local traitId = PetData.normalizeTraitId(parts[3] or "Neutral")
			local mutationId = PetData.normalizeMutationId(parts[4] or "None")
			if not PetData.Pets[petId] then
				warn("DevTools: unknown Color " .. tostring(petId))
				return
			end

			local grantPetFunction = ReplicatedStorage:FindFirstChild("ServerGrantPet")
			if grantPetFunction and grantPetFunction:IsA("BindableFunction") then
				local ok, entry = grantPetFunction:Invoke(player, petId, 1, traitId, mutationId)
				print("DevTools: givecolor " .. tostring(ok) .. " " .. tostring(entry and entry.displayName or petId)
					.. " trait=" .. tostring(ColorTraitData.get(traitId).DisplayName)
					.. " mutation=" .. tostring(ColorMutationData.get(mutationId).DisplayName))
			end
		elseif command == "/giverainbow" or command == "/giverainbowcolor" then
			grantRainbowColor(player)
		elseif command == "/printcoloreffects" then
			local handler = script.Parent:FindFirstChild("ColorEffectHandler")
			if handler then
				local ColorEffectHandler = require(handler)
				local effects = ColorEffectHandler.CalculateEquippedColorEffects(player)
				print("DevTools Color Effects for " .. player.Name .. ":")
				for key, value in pairs(effects) do
					print("  " .. tostring(key) .. " = " .. tostring(value))
				end
			end
		end
	end)
end)
