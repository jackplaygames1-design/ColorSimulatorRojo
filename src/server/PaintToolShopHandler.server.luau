-- Server-owned paintbrush shop and equipment state.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ColorData = require(ReplicatedStorage:WaitForChild("ColorData"))
local ToolData = require(ReplicatedStorage:WaitForChild("ToolData"))

local Events = ReplicatedStorage:WaitForChild("Events")
local purchaseEvent = Events:WaitForChild("PurchasePaintTool")
local equipEvent = Events:WaitForChild("EquipPaintTool")
local dirtyEvent = Events:FindFirstChild("PlayerDataDirty")

local cooldowns = {}
local COOLDOWN = 0.35

local function isDataReady(player)
	return player and player:GetAttribute("DataManagerReady") == true
end

local function reportDailyQuestProgress(player, questId, amount)
	local event = ServerStorage:FindFirstChild("DailyQuestProgress")
	if event and event:IsA("BindableEvent") then
		event:Fire(player, questId, amount)
	end
end

local function markDirty(player, reason)
	if dirtyEvent then
		dirtyEvent:Fire(player, reason)
	end
end

local function ensureToolsFolder(player)
	local folder = player:FindFirstChild("PaintTools")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "PaintTools"
		folder.Parent = player
	end

	local owned = folder:FindFirstChild("Owned")
	if not owned then
		owned = Instance.new("StringValue")
		owned.Name = "Owned"
		owned.Value = "StarterBrush"
		owned.Parent = folder
	end
	if owned.Value == "" then
		owned.Value = "StarterBrush"
	end

	local equipped = folder:FindFirstChild("Equipped")
	if not equipped then
		equipped = Instance.new("StringValue")
		equipped.Name = "Equipped"
		equipped.Value = "StarterBrush"
		equipped.Parent = folder
	end
	if equipped.Value == "" or not ToolData.isValid(equipped.Value) then
		equipped.Value = "StarterBrush"
	end

	return folder, owned, equipped
end

local function csvSet(value)
	local set = {}
	for _, part in ipairs(string.split(value or "", ",")) do
		if part ~= "" then
			set[part] = true
		end
	end
	return set
end

local function setToCsv(set)
	local parts = {}
	for _, toolId in ipairs(ToolData.Order) do
		if set[toolId] then
			table.insert(parts, toolId)
		end
	end
	return table.concat(parts, ",")
end

local function ownsTool(player, toolId)
	local _, owned = ensureToolsFolder(player)
	return csvSet(owned.Value)[toolId] == true
end

local function isToolUnlocked(player, tool)
	local requiredColor = tool and tool.RequiredColor or "Red"
	if requiredColor == "Red" then
		return true
	end

	local storage = player:FindFirstChild("ColorStorage")
	local unlocked = storage and storage:FindFirstChild("UnlockedColors")
	return unlocked and ColorData.isColorUnlocked(unlocked.Value, requiredColor)
end

local function getToolWorldName(tool)
	local world = ColorData.getWorldByColor(tool and tool.RequiredColor or "Red")
	return world and world.name or "Starter Field"
end

local function useCooldown(player)
	local now = os.clock()
	if cooldowns[player] and now - cooldowns[player] < COOLDOWN then
		return false
	end
	cooldowns[player] = now
	return true
end

purchaseEvent.OnServerEvent:Connect(function(player, toolId)
	if not useCooldown(player) then
		return
	end
	if not isDataReady(player) then
		purchaseEvent:FireClient(player, false, toolId, "Data is still loading.")
		return
	end

	local tool = ToolData.Tools[toolId or ""]
	if not tool then
		purchaseEvent:FireClient(player, false, toolId, "Unknown brush.")
		return
	end
	if not isToolUnlocked(player, tool) then
		purchaseEvent:FireClient(player, false, tool.Id, "Unlock " .. getToolWorldName(tool) .. " first.")
		return
	end

	local _, owned, equipped = ensureToolsFolder(player)
	local ownedSet = csvSet(owned.Value)
	if ownedSet[tool.Id] then
		equipped.Value = tool.Id
		markDirty(player, "paint-tool-equipped")
		purchaseEvent:FireClient(player, true, tool.Id, "Equipped " .. tool.DisplayName)
		equipEvent:FireClient(player, true, tool.Id, "Equipped " .. tool.DisplayName)
		return
	end

	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	local cost = tonumber(tool.Cost) or 0
	if not coins or coins.Value < cost then
		purchaseEvent:FireClient(player, false, tool.Id, "Need " .. tostring(cost) .. " Coins.")
		return
	end

	coins.Value -= cost
	ownedSet[tool.Id] = true
	owned.Value = setToCsv(ownedSet)
	equipped.Value = tool.Id
	markDirty(player, "paint-tool-purchased")
	reportDailyQuestProgress(player, "BuyBrush", 1)

	print(player.Name .. " bought and equipped " .. tool.DisplayName .. " for " .. tostring(cost) .. " Coins")
	purchaseEvent:FireClient(player, true, tool.Id, "Bought " .. tool.DisplayName)
	equipEvent:FireClient(player, true, tool.Id, "Equipped " .. tool.DisplayName)
end)

equipEvent.OnServerEvent:Connect(function(player, toolId, equippedRequested)
	if not useCooldown(player) then
		return
	end
	if not isDataReady(player) then
		equipEvent:FireClient(player, false, toolId, "Data is still loading.")
		return
	end

	local tool = ToolData.Tools[toolId or ""]
	if not tool then
		equipEvent:FireClient(player, false, toolId, "Unknown brush.")
		return
	end
	if not isToolUnlocked(player, tool) then
		equipEvent:FireClient(player, false, tool.Id, "Unlock " .. getToolWorldName(tool) .. " first.")
		return
	end

	local _, _, equipped = ensureToolsFolder(player)
	if not ownsTool(player, tool.Id) then
		equipEvent:FireClient(player, false, tool.Id, "You do not own this brush.")
		return
	end

	if equippedRequested == false and equipped.Value == tool.Id then
		equipped.Value = "StarterBrush"
		equipEvent:FireClient(player, true, "StarterBrush", "Equipped Starter Brush")
	else
		equipped.Value = tool.Id
		equipEvent:FireClient(player, true, tool.Id, "Equipped " .. tool.DisplayName)
	end

	markDirty(player, "paint-tool-equipped")
end)

Players.PlayerAdded:Connect(function(player)
	task.defer(function()
		if player:GetAttribute("DataManagerReady") ~= true then
			player:GetAttributeChangedSignal("DataManagerReady"):Wait()
		end
		if not isDataReady(player) then
			return
		end
		ensureToolsFolder(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	cooldowns[player] = nil
end)
