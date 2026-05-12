-- Binds the Studio-authored ShopWindow. This script does not create a replacement shop UI.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local RobuxShopConfig = require(ReplicatedStorage:WaitForChild("RobuxShopConfig"))
local iconConfigModule = ReplicatedStorage:FindFirstChild("GamepassIconConfig")
local GamepassIconConfig = iconConfigModule and require(iconConfigModule) or { Icons = {}, ByShopItemId = {} }
local Events = ReplicatedStorage:WaitForChild("Events", 30)
local claimInfinitePackTierEvent = Events and Events:WaitForChild("ClaimInfinitePackTier", 30)

local OUTLINE = Color3.fromRGB(35, 38, 45)
local TEXT_DARK = Color3.fromRGB(38, 36, 52)
local TAB_ACTIVE = Color3.fromRGB(76, 214, 224)
local TAB_INACTIVE = Color3.fromRGB(232, 238, 248)
local GREEN = Color3.fromRGB(84, 225, 112)
local DISABLED = Color3.fromRGB(170, 180, 205)

local PAGE_NAMES = {
	Featured = "FeaturedPage",
	Gamepasses = "GamepassesPage",
	Boosts = "BoostsPage",
	Currency = "CurrencyPage",
}

local PREMIUM_PULSE_IDS = {
	VIP = true,
	LuckyHatch = true,
}

local gamepassesById = {}
for _, pass in ipairs(RobuxShopConfig.Gamepasses or {}) do
	gamepassesById[pass.id] = pass
end

local productsById = {}
for _, product in ipairs(RobuxShopConfig.DevProducts or {}) do
	productsById[product.id] = product
end

local infinitePackTiersById = {}
local infinitePackTiers = {}
if RobuxShopConfig.getInfinitePackTiers then
	for _, tier in ipairs(RobuxShopConfig.getInfinitePackTiers()) do
		table.insert(infinitePackTiers, tier)
		infinitePackTiersById[tier.id] = tier
	end
end

local warned = {}
local ownedCache = {}
local claimingInfinitePackTier = {}

local function warnOnce(key, message)
	if warned[key] then
		return
	end
	warned[key] = true
	warn(message)
end

local function getMainHUD()
	return playerGui:WaitForChild("MainHUD", 30)
end

local function getWindows(mainHUD)
	local modalWindows = mainHUD and mainHUD:FindFirstChild("ModalWindows")
	return modalWindows
end

local function getTextLabel(parent, name)
	local object = parent and parent:FindFirstChild(name, true)
	return object and object:IsA("TextLabel") and object or nil
end

local function getButton(parent)
	local object = parent and parent:FindFirstChild("BuyButton", true)
	return object and object:IsA("GuiButton") and object or nil
end

local function getStroke(parent)
	return parent and parent:FindFirstChildOfClass("UIStroke")
end

local function getShopIconSpec(item)
	if type(item) ~= "table" then
		return nil
	end

	local iconKey = item.iconKey or (GamepassIconConfig.ByShopItemId and GamepassIconConfig.ByShopItemId[item.id])
	return iconKey and GamepassIconConfig.Icons and GamepassIconConfig.Icons[iconKey] or nil
end

local function applyShopIcon(card, item)
	if not card or type(item) ~= "table" then
		return
	end

	local iconCircle = card:FindFirstChild("IconCircle", true) or card:FindFirstChild("RewardBox", true)
	if not iconCircle or not iconCircle:IsA("GuiObject") then
		return
	end

	local spec = getShopIconSpec(item)
	local image = spec and tostring(spec.Image or "") or ""
	if image == "" then
		image = tostring(item.iconImage or "")
	end

	local iconImage = iconCircle:FindFirstChild("IconImage")
	if not iconImage or not iconImage:IsA("ImageLabel") then
		warnOnce(
			"missing-icon-" .. tostring(item.id or item.name or item.iconKey),
			"EditableShopBinder: missing Studio-authored IconImage under " .. iconCircle:GetFullName()
		)
		return
	end
	iconImage.Image = image
	iconImage.Visible = image ~= ""
	iconImage:SetAttribute("GamepassIconKey", item.iconKey or "")
	iconImage:SetAttribute("ExpectedGamepassIconFile", spec and spec.SourceFile or item.iconSourceFile or "")

	local iconText = iconCircle:FindFirstChild("IconText")
	if iconText and iconText:IsA("TextLabel") then
		iconText.Text = tostring(item.icon or iconText.Text or "?")
		iconText.Visible = image == ""
	end

	iconCircle:SetAttribute("GamepassIconKey", item.iconKey or "")
	iconCircle:SetAttribute("ExpectedGamepassIconFile", spec and spec.SourceFile or item.iconSourceFile or "")
end

local function findScale(parent, name)
	local scale = parent:FindFirstChild(name)
	if scale and scale:IsA("UIScale") then
		return scale
	end
	return nil
end

local function tweenScale(scale, value, duration)
	if not scale then
		return
	end
	TweenService:Create(scale, TweenInfo.new(duration or 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Scale = value,
	}):Play()
end

local function setButtonText(button, text)
	if button:IsA("TextButton") then
		button.Text = text
	end
end

local function setButtonEnabled(button, enabled)
	button.Active = enabled
	button.Selectable = enabled
	button.AutoButtonColor = false
	pcall(function()
		button.Interactable = enabled
	end)
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

local function hasClaimableFreeReward(tier)
	return getCurrencyRewardAmount(tier, "Coins") > 0
		or getCurrencyRewardAmount(tier, "Gems") > 0
		or getCurrencyRewardAmount(tier, "Diamonds") > 0
end

local function isInfinitePackTierClaimed(tier)
	if not tier then
		return false
	end
	if player:GetAttribute("InfinitePackClaimed_" .. tostring(tier.id)) == true then
		return true
	end
	local folder = player:FindFirstChild("InfinitePackClaims")
	local claimedTiers = folder and folder:FindFirstChild("ClaimedTiers")
	local claim = claimedTiers and claimedTiers:FindFirstChild(tostring(tier.id))
	return claim and claim:IsA("BoolValue") and claim.Value == true
end

local function getCurrentInfinitePackTier()
	for _, tier in ipairs(infinitePackTiers) do
		if not isInfinitePackTierClaimed(tier) then
			return tier
		end
	end
	return nil
end

local function ownsPass(pass)
	if not pass then
		return false
	end
	if player:GetAttribute("Pass_" .. tostring(pass.id)) == true then
		ownedCache[pass.id] = true
		return true
	end
	if ownedCache[pass.id] ~= nil then
		return ownedCache[pass.id]
	end

	local gamepassId = tonumber(pass.gamepassId)
	if not gamepassId or gamepassId <= 0 then
		ownedCache[pass.id] = false
		return false
	end

	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepassId)
	end)
	ownedCache[pass.id] = ok and owns == true
	return ownedCache[pass.id]
end

local function setOwnedVisual(card, owned)
	local stroke = getStroke(card)
	if stroke then
		stroke.Color = owned and GREEN or OUTLINE
		stroke.Thickness = owned and 4 or 2
	end
end

local function updateGamepassCard(card, pass)
	local button = getButton(card)
	local priceLabel = getTextLabel(card, "PriceLabel")
	local owned = ownsPass(pass)
	local gamepassId = tonumber(pass.gamepassId)
	local hasRealId = gamepassId and gamepassId > 0

	if priceLabel then
		priceLabel.Text = tostring(pass.price or 0) .. " R$"
	end

	setOwnedVisual(card, owned)
	if not button then
		return
	end

	if owned then
		setButtonText(button, "OWNED ✓")
		button.BackgroundColor3 = GREEN
		setButtonEnabled(button, false)
	elseif hasRealId then
		setButtonText(button, "BUY " .. tostring(pass.price or 0) .. " R$")
		button.BackgroundColor3 = GREEN
		setButtonEnabled(button, true)
	else
		setButtonText(button, "SET ID")
		button.BackgroundColor3 = DISABLED
		setButtonEnabled(button, false)
	end
end

local function updateProductCard(card, product)
	local button = getButton(card)
	local priceLabel = getTextLabel(card, "PriceLabel")
	local productId = tonumber(product.productId)
	local hasRealId = productId and productId > 0

	if priceLabel then
		priceLabel.Text = hasRealId and (tostring(product.price or 0) .. " R$") or "COMING SOON"
	end

	setOwnedVisual(card, false)
	if not button then
		return
	end

	if hasRealId then
		setButtonText(button, "BUY " .. tostring(product.price or 0) .. " R$")
		button.BackgroundColor3 = GREEN
		setButtonEnabled(button, true)
	else
		setButtonText(button, "COMING SOON")
		button.BackgroundColor3 = DISABLED
		setButtonEnabled(button, false)
	end
end

local function updateInfinitePackTierCard(card, tier)
	local button = getButton(card)
	local priceLabel = getTextLabel(card, "PriceLabel")
	local rewardLabel = getTextLabel(card, "RewardLabel")
	local iconCircle = card:FindFirstChild("IconCircle", true) or card:FindFirstChild("RewardBox", true)
	local currentTier = getCurrentInfinitePackTier()
	local isCurrent = currentTier and currentTier.id == tier.id
	local productId = tonumber(tier.productId)
	local isFree = tier.free == true or tonumber(tier.price) == 0
	local hasRealId = productId and productId > 0
	local claimed = isInfinitePackTierClaimed(tier)
	local claimableFreeReward = hasClaimableFreeReward(tier)

	if rewardLabel then
		rewardLabel.Text = tostring(tier.rewardText or tier.displayName or "")
	end
	if iconCircle and iconCircle:IsA("GuiObject") then
		iconCircle.BackgroundColor3 = tier.color or iconCircle.BackgroundColor3
	end
	applyShopIcon(card, tier)

	if priceLabel then
		priceLabel.Text = isFree and "FREE" or (tostring(tier.price or 0) .. " R$")
	end

	setOwnedVisual(card, claimed)
	if not button then
		return
	end

	if claimed then
		setButtonText(button, "CLAIMED")
		button.BackgroundColor3 = GREEN
		setButtonEnabled(button, false)
	elseif claimingInfinitePackTier[tier.id] then
		setButtonText(button, "CLAIMING")
		button.BackgroundColor3 = DISABLED
		setButtonEnabled(button, false)
	elseif not isCurrent then
		setButtonText(button, "LOCKED")
		button.BackgroundColor3 = DISABLED
		setButtonEnabled(button, false)
	elseif isFree and claimableFreeReward then
		setButtonText(button, "FREE")
		button.BackgroundColor3 = GREEN
		setButtonEnabled(button, true)
	elseif isFree then
		setButtonText(button, "SOON")
		button.BackgroundColor3 = DISABLED
		setButtonEnabled(button, false)
	elseif hasRealId then
		setButtonText(button, tostring(tier.price or 0) .. " R$")
		button.BackgroundColor3 = GREEN
		setButtonEnabled(button, true)
	else
		setButtonText(button, "SET ID")
		button.BackgroundColor3 = DISABLED
		setButtonEnabled(button, false)
	end
end

local function focusInfinitePackTrack(shopWindow)
	local currentTier = getCurrentInfinitePackTier()
	if not currentTier then
		return
	end

	local track = shopWindow:FindFirstChild("TierTrack", true)
	if not track or not track:IsA("ScrollingFrame") then
		return
	end
	track.ScrollingEnabled = false
	track.ScrollBarThickness = 0

	local card = track:FindFirstChild(tostring(currentTier.id) .. "Card")
	if not card or not card:IsA("GuiObject") then
		return
	end

	task.defer(function()
		if not card.Parent or not track.Parent then
			return
		end
		local targetX = card.AbsolutePosition.X - track.AbsolutePosition.X + track.CanvasPosition.X - 8
		track.CanvasPosition = Vector2.new(math.max(0, targetX), 0)
	end)
end

local function updateCardState(card)
	local itemId = card:GetAttribute("ShopItemId")
	local kind = card:GetAttribute("ShopItemKind")
	if kind == "Gamepass" then
		local pass = gamepassesById[itemId]
		if pass then
			applyShopIcon(card, pass)
			updateGamepassCard(card, pass)
		end
	elseif kind == "Product" then
		local product = productsById[itemId]
		if product then
			updateProductCard(card, product)
		end
	elseif kind == "InfinitePackTier" then
		local tier = infinitePackTiersById[itemId]
		if tier then
			updateInfinitePackTierCard(card, tier)
		end
	end
end

local function bindButton(card)
	if card:GetAttribute("EditableShopCardBound") == true then
		return
	end
	card:SetAttribute("EditableShopCardBound", true)

	local cardScale = findScale(card, "CardScale")
	card.MouseEnter:Connect(function()
		local stroke = getStroke(card)
		local itemId = card:GetAttribute("ShopItemId")
		local pass = gamepassesById[itemId]
		local tier = infinitePackTiersById[itemId]
		tweenScale(cardScale, 1.025, 0.12)
		if stroke and pass and not ownsPass(pass) then
			stroke.Color = pass.color or TAB_ACTIVE
			stroke.Thickness = 3
		elseif stroke and tier then
			stroke.Color = tier.color or TAB_ACTIVE
			stroke.Thickness = 3
		end
	end)
	card.MouseLeave:Connect(function()
		tweenScale(cardScale, 1, 0.12)
		updateCardState(card)
	end)

	local button = getButton(card)
	if not button then
		return
	end

	local buttonScale = findScale(button, "ButtonScale")
	button.MouseEnter:Connect(function()
		tweenScale(buttonScale, 1.05, 0.1)
	end)
	button.MouseLeave:Connect(function()
		tweenScale(buttonScale, 1, 0.1)
	end)
	button.MouseButton1Down:Connect(function()
		tweenScale(buttonScale, 0.94, 0.08)
	end)
	button.MouseButton1Up:Connect(function()
		tweenScale(buttonScale, 1.05, 0.08)
	end)
	button.Activated:Connect(function()
		local itemId = card:GetAttribute("ShopItemId")
		local kind = card:GetAttribute("ShopItemKind")
		if kind == "Gamepass" then
			local pass = gamepassesById[itemId]
			local gamepassId = pass and tonumber(pass.gamepassId)
			if pass and not ownsPass(pass) and gamepassId and gamepassId > 0 then
				MarketplaceService:PromptGamePassPurchase(player, gamepassId)
			end
		elseif kind == "Product" then
			local product = productsById[itemId]
			local productId = product and tonumber(product.productId)
			if product and productId and productId > 0 then
				MarketplaceService:PromptProductPurchase(player, productId)
			end
		elseif kind == "InfinitePackTier" then
			local tier = infinitePackTiersById[itemId]
			local productId = tier and tonumber(tier.productId)
			local isFree = tier and (tier.free == true or tonumber(tier.price) == 0)
			if tier and isFree and hasClaimableFreeReward(tier) and not isInfinitePackTierClaimed(tier) then
				if claimInfinitePackTierEvent and claimInfinitePackTierEvent:IsA("RemoteEvent") then
					claimingInfinitePackTier[tier.id] = true
					updateCardState(card)
					claimInfinitePackTierEvent:FireServer(tier.id)
				else
					warnOnce("infinite-pack-free", "EditableShopBinder: ClaimInfinitePackTier remote is missing.")
				end
			elseif tier and isFree then
				warnOnce(
					"infinite-pack-unsupported-free",
					"EditableShopBinder: this free Infinite Pack reward is not wired yet."
				)
			elseif tier and productId and productId > 0 then
				MarketplaceService:PromptProductPurchase(player, productId)
			end
		end
	end)
end

local function startShimmer(card)
	if card:GetAttribute("EditableShopShimmerStarted") == true then
		return
	end
	local shimmer = card:FindFirstChild("ShimmerBar", true)
	if not shimmer or not shimmer:IsA("GuiObject") then
		return
	end
	card:SetAttribute("EditableShopShimmerStarted", true)
	task.spawn(function()
		while shimmer.Parent do
			shimmer.Position = UDim2.new(-0.2, 0, -0.3, 0)
			local tween = TweenService:Create(
				shimmer,
				TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Position = UDim2.new(1.2, 0, -0.3, 0) }
			)
			tween:Play()
			tween.Completed:Wait()
			task.wait(1.8)
		end
	end)
end

local function startIconPulse(card)
	local itemId = card:GetAttribute("ShopItemId")
	if not PREMIUM_PULSE_IDS[itemId] or card:GetAttribute("EditableShopPulseStarted") == true then
		return
	end
	local iconCircle = card:FindFirstChild("IconCircle", true)
	if not iconCircle or not iconCircle:IsA("GuiObject") then
		return
	end
	local scale = findScale(iconCircle, "IconScale")
	card:SetAttribute("EditableShopPulseStarted", true)
	task.spawn(function()
		while iconCircle.Parent do
			tweenScale(scale, 1.08, 0.55)
			task.wait(0.55)
			tweenScale(scale, 1, 0.55)
			task.wait(1.35)
		end
	end)
end

local function updateAllCards(shopWindow)
	for _, descendant in ipairs(shopWindow:GetDescendants()) do
		if descendant:IsA("GuiObject") and descendant:GetAttribute("ShopItemId") then
			updateCardState(descendant)
			bindButton(descendant)
			if descendant.Name == "InfinitePassHeroCard" then
				startShimmer(descendant)
			end
			startIconPulse(descendant)
		end
	end
	focusInfinitePackTrack(shopWindow)
end

local function watchInfinitePackClaims(shopWindow)
	local function refresh()
		updateAllCards(shopWindow)
	end

	local function bindClaimFolder(folder)
		if not folder then
			return
		end
		if folder:GetAttribute("EditableShopClaimFolderWatched") ~= true then
			folder:SetAttribute("EditableShopClaimFolderWatched", true)
			folder.ChildAdded:Connect(function(child)
				if child.Name == "ClaimedTiers" then
					bindClaimFolder(folder)
					refresh()
				end
			end)
		end

		local claimedTiers = folder and folder:FindFirstChild("ClaimedTiers")
		if not claimedTiers or claimedTiers:GetAttribute("EditableShopClaimsWatched") == true then
			return
		end
		claimedTiers:SetAttribute("EditableShopClaimsWatched", true)
		claimedTiers.ChildAdded:Connect(refresh)
		claimedTiers.ChildRemoved:Connect(refresh)
	end

	bindClaimFolder(player:FindFirstChild("InfinitePackClaims"))
	player.ChildAdded:Connect(function(child)
		if child.Name == "InfinitePackClaims" then
			bindClaimFolder(child)
			refresh()
		end
	end)

	for _, tier in pairs(infinitePackTiersById) do
		player:GetAttributeChangedSignal("InfinitePackClaimed_" .. tostring(tier.id)):Connect(refresh)
	end
end

local function getTabs(shopWindow)
	return shopWindow:FindFirstChild("Tabs", true)
end

local function getContent(shopWindow)
	return shopWindow:FindFirstChild("Content", true)
end

local function showPage(shopWindow, pageKey)
	local content = getContent(shopWindow)
	local tabs = getTabs(shopWindow)
	if not content then
		return
	end

	for key, pageName in pairs(PAGE_NAMES) do
		local page = content:FindFirstChild(pageName)
		if page and page:IsA("GuiObject") then
			page.Visible = key == pageKey
		end
	end

	if tabs then
		for key in pairs(PAGE_NAMES) do
			local tab = tabs:FindFirstChild(key .. "Tab", true)
			if tab and tab:IsA("TextButton") then
				local active = key == pageKey
				tab.BackgroundColor3 = active and TAB_ACTIVE or TAB_INACTIVE
				tab.TextColor3 = active and Color3.fromRGB(255, 255, 255) or TEXT_DARK
			end
		end
	end
end

local function bindTabs(shopWindow)
	local tabs = getTabs(shopWindow)
	if not tabs then
		warnOnce("missing-tabs", "EditableShopBinder: ShopWindow.Tabs is missing.")
		return
	end
	for key in pairs(PAGE_NAMES) do
		local tab = tabs:FindFirstChild(key .. "Tab", true)
		if tab and tab:IsA("GuiButton") and tab:GetAttribute("EditableShopTabBound") ~= true then
			tab:SetAttribute("EditableShopTabBound", true)
			tab.Activated:Connect(function()
				showPage(shopWindow, key)
			end)
		end
	end
	showPage(shopWindow, "Featured")
end

local mainHUD = getMainHUD()
local windows = mainHUD and getWindows(mainHUD)
local shopWindow = windows and windows:WaitForChild("ShopWindow", 30)
if not shopWindow then
	warn("EditableShopBinder: missing PlayerGui.MainHUD.ModalWindows.ShopWindow")
	return
end

if claimInfinitePackTierEvent and claimInfinitePackTierEvent:IsA("RemoteEvent") then
	claimInfinitePackTierEvent.OnClientEvent:Connect(function(action, tierId, payload)
		tierId = tostring(tierId or "")
		claimingInfinitePackTier[tierId] = nil
		if action == "Claimed" then
			player:SetAttribute("InfinitePackClaimed_" .. tierId, true)
		elseif payload and payload.message then
			warnOnce(
				"infinite-pack-claim-" .. tierId .. "-" .. tostring(payload.message),
				"EditableShopBinder: " .. tostring(payload.message)
			)
		end
		updateAllCards(shopWindow)
	end)
end

watchInfinitePackClaims(shopWindow)
bindTabs(shopWindow)
updateAllCards(shopWindow)
shopWindow.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("GuiObject") and descendant:GetAttribute("ShopItemId") then
		task.defer(function()
			updateCardState(descendant)
			bindButton(descendant)
			startIconPulse(descendant)
		end)
	end
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(purchasingPlayer, gamepassId, wasPurchased)
	if purchasingPlayer ~= player or not wasPurchased then
		return
	end
	for _, pass in ipairs(RobuxShopConfig.Gamepasses or {}) do
		if tonumber(pass.gamepassId) == tonumber(gamepassId) then
			ownedCache[pass.id] = true
			player:SetAttribute("Pass_" .. pass.id, true)
			break
		end
	end
	updateAllCards(shopWindow)
end)

for _, pass in ipairs(RobuxShopConfig.Gamepasses or {}) do
	player:GetAttributeChangedSignal("Pass_" .. pass.id):Connect(function()
		ownedCache[pass.id] = player:GetAttribute("Pass_" .. pass.id) == true
		updateAllCards(shopWindow)
	end)
end

print("[EditableShopBinder] Featured Robux shop bound to existing Studio UI.")
