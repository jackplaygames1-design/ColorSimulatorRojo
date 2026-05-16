-- Creates core remotes before gameplay scripts/clients rely on them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("Color Simulator Server Version: PublicBeta_MobileSectors_2026_05_08")

local events = ReplicatedStorage:FindFirstChild("Events")
if not events then
	events = Instance.new("Folder")
	events.Name = "Events"
	events.Parent = ReplicatedStorage
end

local remoteEvents = {
	"CollectColor",
	"PaintToolSweep",
	"ColorEffectVFX",
	"PaintFieldDelta",
	"PaintFieldClientReady",
	"HatchEgg",
	"EquipPet",
	"LockPet",
	"DeletePet",
	"MergePet",
	"PetAttack",
	"PetBreakReward",
	"PetsLoaded",
	"PurchaseUpgrade",
	"UnlockArea",
	"RequestTravelToSector",
	"RequestTravelToLocation",
	"TravelToLocationResult",
	"TravelToMarket",
	"TravelToWorldSpot",
	"TeleportToSell",
	"SellColor",
	"RedeemCode",
	"DevGrantCoins",
	"UseItem",
	"PurchasePaintTool",
	"EquipPaintTool",
	"RequestSetSetting",
	"SettingsUpdated",
	"GroupRewards",
	"ClaimInfinitePackTier",
	"MutationStation",
	"MarkTutorialProgress",
	"TutorialAction",
	"ShopTransition",
	"WildBuffNotice",
}

for _, name in ipairs(remoteEvents) do
	local existing = events:FindFirstChild(name)
	if existing and not existing:IsA("RemoteEvent") then
		warn("RemoteSetup: replacing invalid Events." .. name)
		existing:Destroy()
		existing = nil
	end
	if not existing then
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = events
	end
end

local remoteFunctions = {
	"PaintFieldSnapshot",
}

for _, name in ipairs(remoteFunctions) do
	local existing = events:FindFirstChild(name)
	if existing and not existing:IsA("RemoteFunction") then
		warn("RemoteSetup: replacing invalid Events." .. name)
		existing:Destroy()
		existing = nil
	end
	if not existing then
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = events
	end
end

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local inventoryRequest = remotes:FindFirstChild("InventoryRequest")
if inventoryRequest and not inventoryRequest:IsA("RemoteFunction") then
	warn("RemoteSetup: replacing invalid Remotes.InventoryRequest")
	inventoryRequest:Destroy()
	inventoryRequest = nil
end
if not inventoryRequest then
	inventoryRequest = Instance.new("RemoteFunction")
	inventoryRequest.Name = "InventoryRequest"
	inventoryRequest.Parent = remotes
end

local inventoryAction = remotes:FindFirstChild("InventoryAction")
if inventoryAction and not inventoryAction:IsA("RemoteEvent") then
	warn("RemoteSetup: replacing invalid Remotes.InventoryAction")
	inventoryAction:Destroy()
	inventoryAction = nil
end
if not inventoryAction then
	inventoryAction = Instance.new("RemoteEvent")
	inventoryAction.Name = "InventoryAction"
	inventoryAction.Parent = remotes
end

local tradeRequest = remotes:FindFirstChild("TradeRequest")
if tradeRequest and not tradeRequest:IsA("RemoteFunction") then
	warn("RemoteSetup: replacing invalid Remotes.TradeRequest")
	tradeRequest:Destroy()
	tradeRequest = nil
end
if not tradeRequest then
	tradeRequest = Instance.new("RemoteFunction")
	tradeRequest.Name = "TradeRequest"
	tradeRequest.Parent = remotes
end

local tradeUpdate = remotes:FindFirstChild("TradeUpdate")
if tradeUpdate and not tradeUpdate:IsA("RemoteEvent") then
	warn("RemoteSetup: replacing invalid Remotes.TradeUpdate")
	tradeUpdate:Destroy()
	tradeUpdate = nil
end
if not tradeUpdate then
	tradeUpdate = Instance.new("RemoteEvent")
	tradeUpdate.Name = "TradeUpdate"
	tradeUpdate.Parent = remotes
end

local bindableEvents = {
	"PlayerDataDirty",
	"TutorialPatchCleared",
	"TutorialGemBroken",
	"TutorialHatchSucceeded",
	"TutorialColorEquipped",
	"TutorialWorldTraveled",
	"TutorialShopEntered",
	"TutorialDailyQuestsIntroduced",
}

for _, name in ipairs(bindableEvents) do
	local existing = events:FindFirstChild(name)
	if existing and not existing:IsA("BindableEvent") then
		warn("RemoteSetup: replacing invalid Events." .. name)
		existing:Destroy()
		existing = nil
	end
	if not existing then
		local bindable = Instance.new("BindableEvent")
		bindable.Name = name
		bindable.Parent = events
	end
end

local bindableFunctions = {
	"ServerSellPaint",
	"ServerGrantPet",
}

for _, name in ipairs(bindableFunctions) do
	local existing = ReplicatedStorage:FindFirstChild(name)
	if existing and not existing:IsA("BindableFunction") then
		warn("RemoteSetup: replacing invalid ReplicatedStorage." .. name)
		existing:Destroy()
		existing = nil
	end
	if not existing then
		local bindable = Instance.new("BindableFunction")
		bindable.Name = name
		bindable.Parent = ReplicatedStorage
	end
end
