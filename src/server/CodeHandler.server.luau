-- Server-authoritative redeem code handling.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local codeDataModule = ReplicatedStorage:FindFirstChild("CodeData")
local CodeData = codeDataModule and require(codeDataModule) or {
	Codes = {
		RELEASE = {
			Code = "RELEASE",
			Active = true,
			MaxUsesPerPlayer = 1,
			Message = "Release reward claimed!",
			Rewards = {
				{ Type = "Coins", Amount = 1000 },
			},
		},
		COLOR = {
			Code = "COLOR",
			Active = true,
			MaxUsesPerPlayer = 1,
			Message = "Color boost claimed!",
			Rewards = {
				{ Type = "Coins", Amount = 250 },
			},
		},
		PET = {
			Code = "PET",
			Active = true,
			MaxUsesPerPlayer = 1,
			Message = "Starter Color claimed!",
			Rewards = {
				{ Type = "Pet", PetId = "RedBlob", Amount = 5 },
			},
		},
	},
}

CodeData.normalize = CodeData.normalize or function(code)
	return string.upper((tostring(code or ""):gsub("%s+", "")))
end

CodeData.getCode = CodeData.getCode or function(code)
	return CodeData.Codes[CodeData.normalize(code)]
end

local Events = ReplicatedStorage:WaitForChild("Events")
local redeemEvent = Events:FindFirstChild("RedeemCode")
if not redeemEvent then
	redeemEvent = Instance.new("RemoteEvent")
	redeemEvent.Name = "RedeemCode"
	redeemEvent.Parent = Events
end
local grantPetFunction = ReplicatedStorage:FindFirstChild("ServerGrantPet")
if not grantPetFunction then
	grantPetFunction = Instance.new("BindableFunction")
	grantPetFunction.Name = "ServerGrantPet"
	grantPetFunction.Parent = ReplicatedStorage
end

local cooldowns = {}
local COOLDOWN = 0.8

local function getRedeemedFolder(player)
	local folder = player:FindFirstChild("RedeemedCodes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "RedeemedCodes"
		folder.Parent = player
	end
	return folder
end

local function getUses(player, normalizedCode)
	local existing = getRedeemedFolder(player):FindFirstChild(normalizedCode)
	return existing and existing.Value or 0
end

local function setUses(player, normalizedCode, uses)
	local folder = getRedeemedFolder(player)
	local existing = folder:FindFirstChild(normalizedCode)
	if not existing then
		existing = Instance.new("IntValue")
		existing.Name = normalizedCode
		existing.Parent = folder
	end
	existing.Value = uses
end

local function awardReward(player, reward)
	local rewardType = tostring(reward.Type or reward.type or "")
	local amount = math.max(1, math.floor(tonumber(reward.Amount or reward.amount) or 1))

	if rewardType == "Coins" or rewardType == "Color" or rewardType == "Storage" then
		local stats = player:FindFirstChild("leaderstats")
		local coins = stats and stats:FindFirstChild("Coins")
		if not coins then
			return false, "Coins are not ready."
		end
		coins.Value += amount
		return true
	elseif rewardType == "Gems" or rewardType == "Diamonds" then
		local stats = player:FindFirstChild("leaderstats")
		local gems = stats and (stats:FindFirstChild("Gems") or stats:FindFirstChild("Diamonds"))
		if not gems then
			return false, "Gems are not ready."
		end
		gems.Value += amount
		return true
	elseif rewardType == "Pet" then
		if not grantPetFunction then
			return false, "Color rewards are not ready."
		end
		local ok, granted = pcall(function()
			return grantPetFunction:Invoke(player, reward.PetId or reward.petId, amount)
		end)
		if not ok or not granted then
			return false, "Color reward failed."
		end
		return true
	end

	return false, "Unsupported reward type."
end

redeemEvent.OnServerEvent:Connect(function(player, rawCode)
	local now = os.clock()
	if cooldowns[player] and now - cooldowns[player] < COOLDOWN then
		return
	end
	cooldowns[player] = now

	local normalized = CodeData.normalize(rawCode)
	if normalized == "" then
		redeemEvent:FireClient(player, false, "Enter a code first.")
		return
	end

	local code = CodeData.getCode(normalized)
	if not code or code.Active == false then
		redeemEvent:FireClient(player, false, "Invalid or expired code.")
		return
	end

	if code.ExpiresAt and os.time() > code.ExpiresAt then
		redeemEvent:FireClient(player, false, "That code has expired.")
		return
	end

	local maxUses = tonumber(code.MaxUsesPerPlayer) or 1
	local uses = getUses(player, normalized)
	if uses >= maxUses then
		redeemEvent:FireClient(player, false, "You already redeemed that code.")
		return
	end

	for _, reward in ipairs(code.Rewards or {}) do
		local ok, message = awardReward(player, reward)
		if not ok then
			redeemEvent:FireClient(player, false, message or "Could not redeem code.")
			return
		end
	end

	setUses(player, normalized, uses + 1)
	redeemEvent:FireClient(player, true, code.Message or "Code redeemed!")
end)

Players.PlayerRemoving:Connect(function(player)
	cooldowns[player] = nil
end)
