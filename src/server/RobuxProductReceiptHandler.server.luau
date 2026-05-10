-- Server-authoritative Developer Product rewards for the editable Robux shop.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RobuxShopConfig = require(ReplicatedStorage:WaitForChild("RobuxShopConfig"))

local Events = ReplicatedStorage:FindFirstChild("Events")
local dataDirtyEvent = Events and Events:FindFirstChild("PlayerDataDirty")

local productsById = {}
for _, product in ipairs(RobuxShopConfig.DevProducts or {}) do
	local productId = tonumber(product.productId)
	if productId and productId > 0 then
		productsById[productId] = product
	end
end

local function markDirty(player, reason)
	if dataDirtyEvent and dataDirtyEvent:IsA("BindableEvent") then
		dataDirtyEvent:Fire(player, reason)
	end
end

local function addCurrency(player, currencyName, amount)
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
	markDirty(player, "developer-product-" .. string.lower(currencyName))
	return true
end

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

	if product.coinReward and not addCurrency(player, "Coins", product.coinReward) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if product.gemReward and not addCurrency(player, "Gems", product.gemReward) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if product.diamondReward and not addCurrency(player, "Diamonds", product.diamondReward) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	print("RobuxProductReceiptHandler: granted " .. tostring(product.id) .. " to " .. player.Name)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end
