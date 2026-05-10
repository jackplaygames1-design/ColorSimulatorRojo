-- Marks players who own the Support Dev gamepass so chat can show an Early Supporter tag.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RobuxShopConfig = require(ReplicatedStorage:WaitForChild("RobuxShopConfig"))
local AdminConfig = require(ReplicatedStorage:WaitForChild("AdminConfig"))

local SUPPORT_PASS_ID
for _, pass in ipairs(RobuxShopConfig.Gamepasses or {}) do
	if pass.id == "SupportDev" or pass.earlySupporterTag then
		SUPPORT_PASS_ID = pass.gamepassId
		break
	end
end

local function setSupporter(player, owns)
	if owns ~= true and player:GetAttribute("Pass_SupportDev") == true then
		owns = true
	end
	player:SetAttribute("EarlySupporter", owns == true)
end

local function refreshSupporter(player)
	if player:GetAttribute("Pass_SupportDev") == true then
		setSupporter(player, true)
		return
	end

	if AdminConfig.isEarlyTesterName(player.Name) then
		setSupporter(player, true)
		return
	end

	if not SUPPORT_PASS_ID or SUPPORT_PASS_ID <= 0 then
		setSupporter(player, false)
		return
	end

	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, SUPPORT_PASS_ID)
	end)
	setSupporter(player, ok and owns == true)
end

Players.PlayerAdded:Connect(function(player)
	setSupporter(player, false)
	task.defer(function()
		refreshSupporter(player)
	end)
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamepassId, wasPurchased)
	if gamepassId == SUPPORT_PASS_ID and wasPurchased then
		setSupporter(player, true)
	end
end)
