-- Keeps the server-side mutation unlock flag in sync with world progression.
-- PetHandler checks player:GetAttribute("MutationsUnlocked") and TutorialProgress.MutationsUnlocked
-- before allowing hatch rolls to receive mutations, so this script is the single bridge from
-- progression -> mutation availability.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ColorData = require(ReplicatedStorage:WaitForChild("ColorData"))
local GameBalance = require(ReplicatedStorage:WaitForChild("GameBalance"))

local Events = ReplicatedStorage:WaitForChild("Events")
local dataDirtyEvent = Events:FindFirstChild("PlayerDataDirty")

local function getRequiredWorldIndex()
	if GameBalance.getFeatureUnlockWorldIndex then
		return tonumber(GameBalance.getFeatureUnlockWorldIndex("Mutations"))
			or tonumber(GameBalance.MutationsUnlockWorldIndex)
			or 2
	end
	return tonumber(GameBalance.MutationsUnlockWorldIndex) or 2
end

local function getHighestUnlockedWorldIndex(player)
	local storage = player:FindFirstChild("ColorStorage")
	local unlockedValue = storage and storage:FindFirstChild("UnlockedColors")
	local unlocked = ColorData.getUnlockedColorSet(unlockedValue and unlockedValue.Value or "Red")

	local highest = 1
	for index, world in ipairs(ColorData.Worlds or {}) do
		if unlocked[world.primaryColor] then
			highest = math.max(highest, index)
		end
	end

	return highest
end

local function getTutorialProgressFolder(player)
	local folder = player:FindFirstChild("TutorialProgress")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "TutorialProgress"
		folder.Parent = player
	end
	return folder
end

local function getOrCreateBool(parent, name, defaultValue)
	local value = parent:FindFirstChild(name)
	if value and value:IsA("BoolValue") then
		return value
	end

	if value then
		value:Destroy()
	end

	value = Instance.new("BoolValue")
	value.Name = name
	value.Value = defaultValue == true
	value.Parent = parent
	return value
end

local function markDirty(player, reason)
	if dataDirtyEvent and dataDirtyEvent:IsA("BindableEvent") then
		dataDirtyEvent:Fire(player, reason or "mutations-unlocked")
	end
end

local function syncPlayer(player)
	if not player or not player.Parent then
		return
	end

	local requiredIndex = getRequiredWorldIndex()
	local highestIndex = getHighestUnlockedWorldIndex(player)
	local unlockedNow = highestIndex >= requiredIndex

	local progress = getTutorialProgressFolder(player)
	local unlockedValue = getOrCreateBool(progress, "MutationsUnlocked", false)
	local hadUnlocked = unlockedValue.Value == true or player:GetAttribute("MutationsUnlocked") == true

	-- Once unlocked, keep it unlocked. This avoids taking mutations away if a save temporarily
	-- reports an older world during load/migration.
	local finalUnlocked = hadUnlocked or unlockedNow
	unlockedValue.Value = finalUnlocked
	player:SetAttribute("MutationsUnlocked", finalUnlocked)

	if finalUnlocked and not hadUnlocked then
		print(
			"MutationUnlockSync: mutations unlocked for " .. player.Name .. " at world index " .. tostring(highestIndex)
		)
		markDirty(player, "mutations-unlocked")
	end
end

local function hookPlayer(player)
	local function deferredSync()
		task.defer(syncPlayer, player)
	end

	if player:GetAttribute("DataManagerReady") ~= true then
		player:GetAttributeChangedSignal("DataManagerReady"):Connect(deferredSync)
	end

	deferredSync()

	task.spawn(function()
		local storage = player:WaitForChild("ColorStorage", 20)
		local unlocked = storage and storage:WaitForChild("UnlockedColors", 20)
		if unlocked then
			unlocked:GetPropertyChangedSignal("Value"):Connect(deferredSync)
			deferredSync()
		end
	end)
end

Players.PlayerAdded:Connect(hookPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	hookPlayer(player)
end
