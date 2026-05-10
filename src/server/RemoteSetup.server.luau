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
	"MutationStation",
	"MarkTutorialProgress",
	"TutorialAction",
	"ShopTransition",
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
