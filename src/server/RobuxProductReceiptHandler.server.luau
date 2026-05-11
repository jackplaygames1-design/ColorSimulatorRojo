-- Server-authoritative Developer Product rewards for the editable Robux shop.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RobuxShopConfig = require(ReplicatedStorage:WaitForChild("RobuxShopConfig"))

local Events = ReplicatedStorage:WaitForChild("Events", 30)
if not Events then
	Events = Instance.new("Folder")
	Events.Name = "Events"
	Events.Parent = ReplicatedStorage
end
local dataDirtyEvent = Events and Events:FindFirstChild("PlayerDataDirty")
local petBreakRewardEvent = Events and Events:FindFirstChild("PetBreakReward")
local claimInfinitePackTierEvent = Events and Events:FindFirstChild("ClaimInfinitePackTier")
if not claimInfinitePackTierEvent or not claimInfinitePackTierEvent:IsA("RemoteEvent") then
	if claimInfinitePackTierEvent then
		claimInfinitePackTierEvent:Destroy()
	end
	claimInfinitePackTierEvent = Instance.new("RemoteEvent")
	claimInfinitePackTierEvent.Name = "ClaimInfinitePackTier"
	claimInfinitePackTierEvent.Parent = Events
end

local productsById = {}
local infinitePackTiersById = {}
for _, product in ipairs(RobuxShopConfig.DevProducts or {}) do
	local productId = tonumber(product.productId)
	if productId and productId > 0 then
		productsById[productId] = product
	end
end
local infinitePackTiers = RobuxShopConfig.getInfinitePackTiers and RobuxShopConfig.getInfinitePackTiers()
	or ((RobuxShopConfig.InfinitePack and RobuxShopConfig.InfinitePack.tiers) or {})
for _, tier in ipairs(infinitePackTiers) do
	infinitePackTiersById[tostring(tier.id)] = tier
	local productId = tonumber(tier.productId)
	if productId and productId > 0 then
		productsById[productId] = tier
	end
end

local function markDirty(player, reason)
	if dataDirtyEvent and dataDirtyEvent:IsA("BindableEvent") then
		dataDirtyEvent:Fire(player, reason)
	end
end

local function addCurrency(player, currencyName, amount, reason)
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 then
		return true
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild(currencyName)
	if not value or not value:IsA("ValueBase") then
		return false
	end

	value.Value += amount
	markDirty(player, reason or ("developer-product-" .. string.lower(currencyName)))
	return true
end

local function getCurrencyRewardAmount(reward, currencyName)
	local rewardKind = tostring(reward.rewardKind or "")
	if currencyName == "Coins" then
		return math.floor(tonumber(reward.coinReward or (rewardKind == "Coin" and reward.amount) or 0) or 0)
	elseif currencyName == "Gems" then
		return math.floor(tonumber(reward.gemReward or (rewardKind == "Gem" and reward.amount) or 0) or 0)
	elseif currencyName == "Diamonds" then
		return math.floor(tonumber(reward.diamondReward or (rewardKind == "Diamond" and reward.amount) or 0) or 0)
	end
	return 0
end

local function hasCurrencyReward(reward)
	return getCurrencyRewardAmount(reward, "Coins") > 0
		or getCurrencyRewardAmount(reward, "Gems") > 0
		or getCurrencyRewardAmount(reward, "Diamonds") > 0
end

local function grantCurrencyRewards(player, reward, reason)
	for _, currencyName in ipairs({ "Coins", "Gems", "Diamonds" }) do
		local amount = getCurrencyRewardAmount(reward, currencyName)
		if amount > 0 and not addCurrency(player, currencyName, amount, reason) then
			return false, currencyName .. " are not ready."
		end
	end
	return true
end

local function todayKey()
	return os.date("!%Y-%m-%d")
end

local function getClaimState(player)
	local folder = player:FindFirstChild("InfinitePackClaims")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "InfinitePackClaims"
		folder.Parent = player
	end

	local resetKey = folder:FindFirstChild("ResetKey")
	if not resetKey or not resetKey:IsA("StringValue") then
		if resetKey then
			resetKey:Destroy()
		end
		resetKey = Instance.new("StringValue")
		resetKey.Name = "ResetKey"
		resetKey.Parent = folder
	end

	local claimedTiers = folder:FindFirstChild("ClaimedTiers")
	if not claimedTiers or not claimedTiers:IsA("Folder") then
		if claimedTiers then
			claimedTiers:Destroy()
		end
		claimedTiers = Instance.new("Folder")
		claimedTiers.Name = "ClaimedTiers"
		claimedTiers.Parent = folder
	end

	local currentKey = todayKey()
	if resetKey.Value ~= currentKey then
		resetKey.Value = currentKey
		for _, child in ipairs(claimedTiers:GetChildren()) do
			child:Destroy()
		end
		for tierId in pairs(infinitePackTiersById) do
			player:SetAttribute("InfinitePackClaimed_" .. tierId, false)
		end
		markDirty(player, "infinite-pack-reset")
	end

	return claimedTiers
end

local function isTierClaimed(player, tierId)
	local claimedTiers = getClaimState(player)
	local claim = claimedTiers:FindFirstChild(tierId)
	return claim and claim:IsA("BoolValue") and claim.Value == true
end

local function getCurrentTierId(player)
	for _, tier in ipairs(infinitePackTiers) do
		local tierId = tostring(tier.id)
		if not isTierClaimed(player, tierId) then
			return tierId
		end
	end
	return nil
end

local function markTierClaimed(player, tierId)
	local claimedTiers = getClaimState(player)
	local claim = claimedTiers:FindFirstChild(tierId)
	if not claim or not claim:IsA("BoolValue") then
		if claim then
			claim:Destroy()
		end
		claim = Instance.new("BoolValue")
		claim.Name = tierId
		claim.Parent = claimedTiers
	end
	claim.Value = true
	player:SetAttribute("InfinitePackClaimed_" .. tierId, true)
	markDirty(player, "infinite-pack-claim")
end

local function fireClaimResult(player, action, tierId, payload)
	if claimInfinitePackTierEvent and claimInfinitePackTierEvent:IsA("RemoteEvent") then
		claimInfinitePackTierEvent:FireClient(player, action, tierId, payload or {})
	end
end

local function fireCurrencyToast(player, reward)
	if not petBreakRewardEvent or not petBreakRewardEvent:IsA("RemoteEvent") then
		return
	end
	local gems = getCurrencyRewardAmount(reward, "Gems")
	if gems > 0 then
		petBreakRewardEvent:FireClient(player, { type = "gems", amount = gems })
	end
	local coins = getCurrencyRewardAmount(reward, "Coins")
	if coins > 0 then
		petBreakRewardEvent:FireClient(player, { type = "coins", amount = coins })
	end
end

claimInfinitePackTierEvent.OnServerEvent:Connect(function(player, tierId)
	tierId = tostring(tierId or "")
	local tier = infinitePackTiersById[tierId]
	if not tier then
		fireClaimResult(player, "Rejected", tierId, { message = "Unknown Infinite Pack tier." })
		return
	end
	if not (tier.free == true or tonumber(tier.price) == 0) then
		fireClaimResult(player, "Rejected", tierId, { message = "This tier is a Robux purchase." })
		return
	end
	if not hasCurrencyReward(tier) then
		fireClaimResult(player, "Rejected", tierId, { message = "This reward type is not claimable yet." })
		return
	end
	if isTierClaimed(player, tierId) then
		fireClaimResult(player, "Rejected", tierId, { message = "Already claimed." })
		return
	end
	if getCurrentTierId(player) ~= tierId then
		fireClaimResult(player, "Rejected", tierId, { message = "Claim the current Forever Pack tier first." })
		return
	end

	local ok, message = grantCurrencyRewards(player, tier, "infinite-pack-claim")
	if not ok then
		fireClaimResult(player, "Rejected", tierId, { message = message })
		return
	end

	markTierClaimed(player, tierId)
	fireCurrencyToast(player, tier)
	fireClaimResult(player, "Claimed", tierId, {
		coins = getCurrencyRewardAmount(tier, "Coins"),
		gems = getCurrencyRewardAmount(tier, "Gems"),
		diamonds = getCurrencyRewardAmount(tier, "Diamonds"),
		message = "Claimed " .. tostring(tier.rewardText or tier.displayName or "reward") .. "!",
	})
	print("RobuxProductReceiptHandler: claimed free Infinite Pack tier " .. tierId .. " for " .. player.Name)
end)

MarketplaceService.ProcessReceipt = function(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local product = productsById[tonumber(receiptInfo.ProductId)]
	if not product then
		warn("RobuxProductReceiptHandler: unknown Developer Product " .. tostring(receiptInfo.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local ok = grantCurrencyRewards(player, product, "developer-product-" .. tostring(product.id))
	if not ok then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if product.productCategory == "InfinitePack" then
		markTierClaimed(player, tostring(product.id))
	end

	print("RobuxProductReceiptHandler: granted " .. tostring(product.id) .. " to " .. player.Name)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end
