-- Lightweight in-game moderator/admin commands.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AdminConfig = require(ReplicatedStorage:WaitForChild("AdminConfig"))
local PetData = require(ReplicatedStorage:WaitForChild("PetData"))
local ColorTraitData = require(ReplicatedStorage:WaitForChild("ColorTraitData"))
local ColorMutationData = require(ReplicatedStorage:WaitForChild("ColorMutationData"))

local BanStore = DataStoreService:GetDataStore("ColorSimulatorAdminBans_v1")
local sessionBans = {}

local function isOwner(player)
	return game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
end

local function isDeveloper(player)
	return isOwner(player) or AdminConfig.isDeveloperName(player.Name)
end

local function isAdmin(player)
	return isDeveloper(player) or AdminConfig.isModeratorName(player.Name)
end

local function findPlayer(query)
	query = string.lower(tostring(query or ""))
	if query == "" then
		return nil
	end

	for _, player in ipairs(Players:GetPlayers()) do
		local name = string.lower(player.Name)
		local displayName = string.lower(player.DisplayName)
		if name == query or displayName == query or string.sub(name, 1, #query) == query or string.sub(displayName, 1, #query) == query then
			return player
		end
	end
	return nil
end

local function getRoot(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function setStaffAttributes(player)
	local moderator = AdminConfig.isModeratorName(player.Name)
	local developer = isDeveloper(player)
	player:SetAttribute("IsModerator", moderator)
	player:SetAttribute("IsDeveloper", developer)
	player:SetAttribute("IsAdmin", moderator or developer)
end

local function announce(message)
	print("[ADMIN ANNOUNCE] " .. tostring(message or ""))
	for _, player in ipairs(Players:GetPlayers()) do
		player:SetAttribute("AdminAnnouncement", tostring(message or ""))
	end
end

local function parseAmount(value, fallback, maxValue)
	local amount = math.floor(tonumber(value) or fallback or 0)
	if maxValue then
		amount = math.min(amount, maxValue)
	end
	return math.max(0, amount)
end

local function addCurrency(target, currencyName, amount)
	local stats = target and target:FindFirstChild("leaderstats")
	local value = stats and stats:FindFirstChild(currencyName)
	if not value or not value:IsA("ValueBase") then
		return false
	end

	value.Value += amount
	return true
end

local function grantColor(target, petId, amount, traitId, mutationId)
	if not target then
		return false, "No target."
	end
	petId = tostring(petId or "RedCubey")
	if not PetData.Pets[petId] then
		return false, "Unknown Color: " .. petId
	end

	local grantPetFunction = ReplicatedStorage:FindFirstChild("ServerGrantPet")
	if not grantPetFunction or not grantPetFunction:IsA("BindableFunction") then
		return false, "ServerGrantPet missing."
	end

	amount = math.clamp(parseAmount(amount, 1, 1000), 1, 1000)
	traitId = PetData.normalizeTraitId(traitId or "Neutral")
	mutationId = PetData.normalizeMutationId(mutationId or "None")

	local ok, entry = grantPetFunction:Invoke(target, petId, amount, traitId, mutationId, true)
	if ok then
		return true, "Gave " .. tostring(amount) .. "x " .. tostring(entry and entry.displayName or petId)
	end
	return false, "Color grant failed."
end

local function setBan(userId, banned, reason, moderatorName)
	userId = tonumber(userId)
	if not userId then
		return false
	end

	sessionBans[userId] = banned and {
		reason = reason ~= "" and reason or "Banned by staff.",
		moderator = moderatorName,
		time = os.time(),
	} or nil

	local ok, err = pcall(function()
		BanStore:UpdateAsync("User_" .. tostring(userId), function()
			if not banned then
				return false
			end
			return sessionBans[userId]
		end)
	end)
	if not ok then
		warn("Admin ban store failed for " .. tostring(userId) .. ": " .. tostring(err))
	end
	return ok
end

local function getBan(userId)
	userId = tonumber(userId)
	if not userId then
		return nil
	end
	if sessionBans[userId] then
		return sessionBans[userId]
	end

	local ok, data = pcall(function()
		return BanStore:GetAsync("User_" .. tostring(userId))
	end)
	if ok and type(data) == "table" then
		sessionBans[userId] = data
		return data
	end
	return nil
end

local function commandHelp(player)
	print("Admin commands for " .. player.Name .. ":")
	print("  !kick player [reason] | !bring player | !goto player | !respawn [player] | !announce message")
	if isDeveloper(player) then
		print("  Developer: !coins player amount | !gems player amount | !givepet player petId [amount] [trait] [mutation]")
		print("  Developer: !fly [player] [on/off] | !unfly [player] | !ban player [reason] | !unban userId")
	end
end

local function handleCommand(player, rawMessage)
	if not isAdmin(player) then
		return
	end

	local message = tostring(rawMessage or "")
	if string.sub(message, 1, 1) ~= "!" and string.sub(message, 1, 1) ~= "/" then
		return
	end

	local args = string.split(message, " ")
	local command = string.lower(string.sub(args[1] or "", 2))

	if command == "cmds" or command == "commands" then
		commandHelp(player)
	elseif command == "kick" then
		local target = findPlayer(args[2])
		if target and target ~= player then
			local reason = table.concat(args, " ", 3)
			target:Kick(reason ~= "" and reason or "Removed by a moderator.")
			print(player.Name .. " kicked " .. target.Name)
		end
	elseif command == "bring" then
		local target = findPlayer(args[2])
		local adminRoot = getRoot(player)
		local targetRoot = target and getRoot(target)
		if adminRoot and targetRoot then
			targetRoot.CFrame = adminRoot.CFrame + adminRoot.CFrame.LookVector * 5 + Vector3.new(0, 2, 0)
			print(player.Name .. " brought " .. target.Name)
		end
	elseif command == "goto" or command == "to" then
		local target = findPlayer(args[2])
		local adminRoot = getRoot(player)
		local targetRoot = target and getRoot(target)
		if adminRoot and targetRoot then
			adminRoot.CFrame = targetRoot.CFrame + targetRoot.CFrame.LookVector * -5 + Vector3.new(0, 2, 0)
			print(player.Name .. " went to " .. target.Name)
		end
	elseif command == "respawn" then
		local target = findPlayer(args[2]) or player
		target:LoadCharacter()
		print(player.Name .. " respawned " .. target.Name)
	elseif command == "announce" then
		local text = table.concat(args, " ", 2)
		if text ~= "" then
			announce(text)
		end
	elseif command == "coins" or command == "givecoins" or command == "money" then
		if not isDeveloper(player) then return end
		local target = findPlayer(args[2]) or player
		local amount = parseAmount(args[3] or args[2], 0, 100000000)
		if amount > 0 and addCurrency(target, "Coins", amount) then
			print(player.Name .. " gave " .. tostring(amount) .. " Coins to " .. target.Name)
		end
	elseif command == "gems" or command == "givegems" or command == "diamonds" then
		if not isDeveloper(player) then return end
		local target = findPlayer(args[2]) or player
		local amount = parseAmount(args[3] or args[2], 0, 10000000)
		if amount > 0 and addCurrency(target, "Gems", amount) then
			print(player.Name .. " gave " .. tostring(amount) .. " Gems to " .. target.Name)
		end
	elseif command == "givepet" or command == "givecolor" or command == "pet" then
		if not isDeveloper(player) then return end
		local target = findPlayer(args[2]) or player
		local petArgIndex = target == player and 2 or 3
		local ok, result = grantColor(target, args[petArgIndex], args[petArgIndex + 1], args[petArgIndex + 2], args[petArgIndex + 3])
		print("Admin givepet by " .. player.Name .. ": " .. tostring(ok) .. " - " .. tostring(result))
	elseif command == "fly" then
		if not isDeveloper(player) then return end
		local target = findPlayer(args[2]) or player
		local mode = string.lower(tostring(args[3] or args[2] or "on"))
		local enabled = mode ~= "off" and mode ~= "false" and mode ~= "0"
		target:SetAttribute("AdminFlyEnabled", enabled)
		print(player.Name .. " set fly=" .. tostring(enabled) .. " for " .. target.Name)
	elseif command == "unfly" then
		if not isDeveloper(player) then return end
		local target = findPlayer(args[2]) or player
		target:SetAttribute("AdminFlyEnabled", false)
		print(player.Name .. " disabled fly for " .. target.Name)
	elseif command == "ban" then
		if not isDeveloper(player) then return end
		local target = findPlayer(args[2])
		if target and target ~= player then
			local reason = table.concat(args, " ", 3)
			if setBan(target.UserId, true, reason, player.Name) then
				target:Kick(reason ~= "" and reason or "Banned by staff.")
				print(player.Name .. " banned " .. target.Name)
			end
		end
	elseif command == "unban" then
		if not isDeveloper(player) then return end
		local userId = tonumber(args[2])
		if userId and setBan(userId, false, "", player.Name) then
			print(player.Name .. " unbanned userId " .. tostring(userId))
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	local ban = getBan(player.UserId)
	if ban then
		player:Kick(tostring(ban.reason or "Banned by staff."))
		return
	end
	setStaffAttributes(player)
	player.Chatted:Connect(function(message)
		handleCommand(player, message)
	end)
end)

for _, player in ipairs(Players:GetPlayers()) do
	setStaffAttributes(player)
end
