-- SellHandler.server.luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DEBUG_LOGS = RunService:IsStudio()

local ColorData = require(ReplicatedStorage:WaitForChild("ColorData"))
local PetData = require(ReplicatedStorage:WaitForChild("PetData"))
local GameBalance = require(ReplicatedStorage:WaitForChild("GameBalance"))
local GamepassBenefits = require(script.Parent:WaitForChild("GamepassBenefits"))
local ColorEffectHandler = require(script.Parent:WaitForChild("ColorEffectHandler"))

local Events = ReplicatedStorage:WaitForChild("Events")
local teleportToSellEvent = Events:WaitForChild("TeleportToSell")
local sellColorEvent = Events:FindFirstChild("SellColor")
local dataDirtyEvent = Events:FindFirstChild("PlayerDataDirty")
local serverSellPaint = ReplicatedStorage:FindFirstChild("ServerSellPaint")
if not serverSellPaint then
	serverSellPaint = Instance.new("BindableFunction")
	serverSellPaint.Name = "ServerSellPaint"
	serverSellPaint.Parent = ReplicatedStorage
end
local sellDebounce = {}
local unexpectedSellWarnings = {}
local SELLING_ENABLED = false

local function warnUnexpectedSellValuesOnce(player, action)
	local key = tostring(player and player.UserId or "server") .. ":" .. tostring(action)
	if unexpectedSellWarnings[key] then
		return
	end
	unexpectedSellWarnings[key] = true
	warn("Sell request ignored unexpected client value fields for " .. tostring(action) .. ". Server calculates Coins.")
end
local SELL_DEBOUNCE = 1.25

local SELL_DARK = Color3.fromRGB(28, 35, 42)
local SELL_GREEN = Color3.fromRGB(98, 255, 190)
local SELL_CYAN = Color3.fromRGB(118, 238, 244)
local SELL_YELLOW = Color3.fromRGB(255, 226, 92)

local function disableSellPart(sellPart)
	if not sellPart or not sellPart:IsA("BasePart") then
		return
	end

	sellPart:SetAttribute("SellZoneDisabled", true)
	sellPart.CanTouch = false
	sellPart.CanCollide = false
	sellPart.Transparency = math.max(sellPart.Transparency, 0.9)

	local prompt = sellPart:FindFirstChild("SellPrompt")
	if prompt then
		prompt.Enabled = false
	end

	for _, child in ipairs(sellPart:GetDescendants()) do
		if child:IsA("ProximityPrompt")
			or child:IsA("BillboardGui")
			or child:IsA("SurfaceGui")
			or child:IsA("ParticleEmitter")
			or child:IsA("PointLight")
		then
			child.Enabled = false
		elseif child:IsA("BasePart") and child:GetAttribute("SellZoneDecor") then
			child.Transparency = 1
			child.CanCollide = false
			child.CanTouch = false
			child.CanQuery = false
		end
	end
end

local function sellPartMatchesColor(part, colorType)
	if not part or not colorType then
		return false
	end

	local sellColor = part:GetAttribute("ColorType")
		or part:GetAttribute("AreaColor")
		or part:GetAttribute("SellColor")
	if not sellColor then
		local worldIndex = ColorData.getWorldIndex(colorType)
		if part.Name == tostring(colorType) .. "SellPad"
			or part.Name == tostring(colorType) .. "SellStation"
			or (worldIndex and (part.Name == "World" .. tostring(worldIndex) .. "Sell" or part.Name == "World" .. tostring(worldIndex) .. "_Sell"))
		then
			sellColor = colorType
			part:SetAttribute("ColorType", colorType)
			part:SetAttribute("AreaColor", colorType)
			part:SetAttribute("SellColor", colorType)
		end
	end
	return sellColor == colorType
end

local function isSellPart(obj)
	return obj:IsA("BasePart")
		and (obj:GetAttribute("SellZone")
			or obj:GetAttribute("SellLocation")
			or obj.Name == "SellZone"
			or obj.Name == "Sell"
			or obj.Name == "SellPart"
			or obj.Name == "SellArea"
			or obj.Name == "SellPad"
			or obj.Name == "OrangeSellPad"
			or obj.Name == "OrangeSellStation"
			or obj.Name == "World2Sell"
			or string.match(obj.Name, "^World%d+_Sell$")
			or string.match(obj.Name, "^World%d+Sell$")
			or string.match(obj.Name, "SellStation$"))
end

local function findSellPart(colorType)
	local fallback = nil
	for _, obj in ipairs(workspace:GetDescendants()) do
		if isSellPart(obj) then
			fallback = fallback or obj
			if sellPartMatchesColor(obj, colorType) then
				return obj
			end
		end
	end

	return colorType == "Red" and fallback or nil
end

local function ensureSellBillboard(sellPart)
	for _, child in ipairs(sellPart:GetChildren()) do
		if child:IsA("BillboardGui") and child.Name ~= "SellZoneLabel" then
			child:Destroy()
		end
	end

	local billboard = sellPart:FindFirstChild("SellZoneLabel")
	if not billboard then
		billboard = Instance.new("BillboardGui")
		billboard.Name = "SellZoneLabel"
		billboard.AlwaysOnTop = true
		billboard.LightInfluence = 0
		billboard.MaxDistance = 190
		billboard.Size = UDim2.new(0, 310, 0, 96)
		billboard.StudsOffset = Vector3.new(0, 10.5, 0)
		billboard.Parent = sellPart
	end

	local title = billboard:FindFirstChild("Title")
	if not title then
		title = Instance.new("TextLabel")
		title.Name = "Title"
		title.BackgroundTransparency = 1
		title.Size = UDim2.new(1, 0, 0, 48)
		title.Font = Enum.Font.LuckiestGuy
		title.TextSize = 34
		title.TextColor3 = Color3.fromRGB(255, 255, 255)
		title.TextStrokeTransparency = 0
		title.TextStrokeColor3 = SELL_DARK
		title.Parent = billboard
	end
	title.Text = "SELL COLOR"

	local sub = billboard:FindFirstChild("Subtitle")
	if not sub then
		sub = Instance.new("TextLabel")
		sub.Name = "Subtitle"
		sub.BackgroundTransparency = 1
		sub.Size = UDim2.new(1, 0, 0, 28)
		sub.Position = UDim2.new(0, 0, 0, 50)
		sub.Font = Enum.Font.GothamBold
		sub.TextSize = 16
		sub.TextColor3 = Color3.fromRGB(205, 255, 236)
		sub.TextStrokeTransparency = 0.15
		sub.TextStrokeColor3 = SELL_DARK
		sub.Parent = billboard
	end
	sub.Text = "Turn Color into Coins"
end

local function makeVisualPart(root, name, size, offset, color, material, transparency)
	local part = root:FindFirstChild(name)
	if not part then
		part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.Parent = root
	end

	part.Size = size
	part.CFrame = root.CFrame * CFrame.new(offset)
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Transparency = transparency or 0
	part:SetAttribute("SellZoneDecor", true)
	return part
end

local function ensureSellVisuals(sellPart)
	for _, child in ipairs(sellPart:GetChildren()) do
		if (child:IsA("BasePart") and child:GetAttribute("SellZoneDecor"))
			or child:IsA("ParticleEmitter")
			or child:IsA("PointLight")
			or child.Name == "SellSparkles"
			or child.Name == "SellZoneLabel"
			or (child:IsA("BillboardGui") and child.Name == "ProximityStationLabel")
		then
			child:Destroy()
		end
	end

	sellPart:SetAttribute("SellZone", true)
	sellPart.Anchored = true
	sellPart.CanCollide = false
	sellPart.CanTouch = true

	local prompt = sellPart:FindFirstChild("SellPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "SellPrompt"
		prompt.Parent = sellPart
	end
	prompt.ActionText = "Sell Color"
	prompt.ObjectText = "Sell Station"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 20
	prompt.RequiresLineOfSight = false

	return prompt
end

local function parseInventory(str)
	local inventory = {}
	if not str or str == "" then
		return inventory
	end

	for _, part in ipairs(string.split(str, ",")) do
		local segments = string.split(part, ":")
		local variantKey
		local petId
		local stackIndex
		if tonumber(segments[2]) then
			petId = segments[1]
			stackIndex = 2
		else
			variantKey = segments[1]
			petId = segments[2]
			stackIndex = 3
		end
		local stackAmount = tonumber(segments[stackIndex]) or 1
		local traitId = PetData.normalizeTraitId(segments[stackIndex + 1])
		local shinyStr = segments[stackIndex + 2] or "normal"
		local personalityId = PetData.normalizePersonalityId(segments[stackIndex + 3] or "Neutral")
		local mutationId = PetData.normalizeMutationId(segments[stackIndex + 4] or "None")
		variantKey = variantKey or PetData.makeVariantKey(petId, personalityId, mutationId, traitId)
		if petId and petId ~= "" then
			inventory[variantKey] = {
				petId = petId,
				stackAmount = stackAmount,
				traitId = traitId,
				isShiny = shinyStr == "shiny" or shinyStr == "true",
				personalityId = personalityId,
				mutationId = mutationId,
			}
		end
	end

	return inventory
end

local function getPetCoinMultiplier(player)
	return ColorEffectHandler.GetSellCoinsMultiplier(player)
end

local function getSellMultiplier(player)
	local multiplier = getPetCoinMultiplier(player)
	local boostFolder = player:FindFirstChild("Boosts")
	local coinBoost = boostFolder and boostFolder:FindFirstChild("coins")
	if coinBoost and os.time() < coinBoost.Value then
		multiplier *= 2
	end
	multiplier *= GamepassBenefits.getCoinMultiplier(player)

	return multiplier
end

local function isPointInside(part, worldPosition, margin)
	local localPoint = part.CFrame:PointToObjectSpace(worldPosition)
	local half = part.Size * 0.5 + Vector3.new(margin, margin, margin)
	return math.abs(localPoint.X) <= half.X
		and math.abs(localPoint.Y) <= half.Y
		and math.abs(localPoint.Z) <= half.Z
end

local function getHighestUnlockedColor(player)
	local storage = player:FindFirstChild("ColorStorage")
	local unlockedValue = storage and storage:FindFirstChild("UnlockedColors")
	local unlocked = ColorData.getUnlockedColorSet(unlockedValue and unlockedValue.Value or "Red")
	local highest = "Red"
	for _, world in ipairs(ColorData.Worlds or {}) do
		if unlocked[world.primaryColor] then
			highest = world.primaryColor
		end
	end
	return highest
end

local function getStoredCurrentWorldColor(player)
	local storage = player:FindFirstChild("ColorStorage")
	local unlockedValue = storage and storage:FindFirstChild("UnlockedColors")
	local unlockedCsv = unlockedValue and unlockedValue.Value or "Red"
	local currentWorld = storage and storage:FindFirstChild("CurrentWorld")
	local colorType = currentWorld and currentWorld.Value or player:GetAttribute("ActiveWorldColor")
	local world = ColorData.getWorldByColor(colorType)
	if world and ColorData.isColorUnlocked(unlockedCsv, world.primaryColor) then
		return world.primaryColor
	end
	return nil
end

local function setCurrentWorld(player, colorType)
	local storage = player:FindFirstChild("ColorStorage")
	local unlockedValue = storage and storage:FindFirstChild("UnlockedColors")
	if not ColorData.isColorUnlocked(unlockedValue and unlockedValue.Value or "Red", colorType) then
		return
	end

	player:SetAttribute("ActiveWorldColor", colorType)
	local currentWorld = storage and storage:FindFirstChild("CurrentWorld")
	if currentWorld and currentWorld:IsA("StringValue") and currentWorld.Value ~= colorType then
		currentWorld.Value = colorType
		if dataDirtyEvent and dataDirtyEvent:IsA("BindableEvent") then
			dataDirtyEvent:Fire(player, "current-world")
		end
	end
end

local function getCurrentSellColor(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local storedColor = getStoredCurrentWorldColor(player)
	if root then
		local nearestColor = nil
		local nearestDistance = math.huge
		local storage = player:FindFirstChild("ColorStorage")
		local unlockedValue = storage and storage:FindFirstChild("UnlockedColors")
		local unlockedCsv = unlockedValue and unlockedValue.Value or "Red"
		for _, obj in ipairs(workspace:GetDescendants()) do
			if obj:IsA("BasePart") and obj:GetAttribute("ColorZone") and obj:GetAttribute("ColorType") then
				local colorType = obj:GetAttribute("ColorType")
				if isPointInside(obj, root.Position, 8) then
					setCurrentWorld(player, colorType)
					return colorType
				end
				if ColorData.isColorUnlocked(unlockedCsv, colorType) then
					local distance = (root.Position - obj.Position).Magnitude
					if distance < nearestDistance then
						nearestDistance = distance
						nearestColor = colorType
					end
				end
			end
		end
		if storedColor then
			return storedColor
		end
		if nearestColor then
			return nearestColor
		end
	end
	if storedColor then
		return storedColor
	end
	return getHighestUnlockedColor(player)
end

local function getZoneColorValueMultiplier(player)
	local colorType = getCurrentSellColor(player)
	local configured = GameBalance.Sell
		and GameBalance.Sell.ColorValueMultipliers
		and GameBalance.Sell.ColorValueMultipliers[colorType]
	local world = ColorData.getWorldByColor(colorType)
	return tonumber(configured or (world and world.colorValueMultiplier)) or 1, colorType or "Red"
end

local function sellPaint(player)
	return false, "Selling is disabled. Break Color to earn Coins instantly."
end

serverSellPaint.OnInvoke = function(player)
	return sellPaint(player)
end

local function teleportToSell(player)
	if not SELLING_ENABLED then
		return
	end

	local sellPart = findSellPart(getCurrentSellColor(player))
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")

	if sellPart and root then
		root.CFrame = sellPart.CFrame + Vector3.new(0, 4, 0)
	end
end

local function handleSell(player, shouldTeleport, responseEvent)
	if not SELLING_ENABLED then
		responseEvent = responseEvent or teleportToSellEvent
		if responseEvent then
			responseEvent:FireClient(player, false, "Selling is disabled. Break Color to earn Coins instantly.")
		end
		return
	end

	if shouldTeleport then
		teleportToSell(player)
	end

	local ok, result = sellPaint(player)
	responseEvent = responseEvent or teleportToSellEvent
	if ok then
		if DEBUG_LOGS then
			print("Sell zone sold " .. tostring(result.colorSold) .. " Color for " .. tostring(result.coinsEarned) .. " Coins")
		end
		responseEvent:FireClient(player, true, result)
	else
		responseEvent:FireClient(player, false, result)
	end
end

local function useSellZone(player, responseEvent)
	local now = os.clock()
	if sellDebounce[player] and now - sellDebounce[player] < SELL_DEBOUNCE then
		return
	end
	sellDebounce[player] = now

	if DEBUG_LOGS then
		print("Sell zone used")
	end
	handleSell(player, false, responseEvent or sellColorEvent or teleportToSellEvent)
end

teleportToSellEvent.OnServerEvent:Connect(function(player, action, ...)
	if select("#", ...) > 0 then
		warnUnexpectedSellValuesOnce(player, "TeleportToSell")
	end
	handleSell(player, action ~= "sell", teleportToSellEvent)
end)

if sellColorEvent then
	sellColorEvent.OnServerEvent:Connect(function(player, ...)
		if select("#", ...) > 0 then
			warnUnexpectedSellValuesOnce(player, "SellColor")
		end
		handleSell(player, false, sellColorEvent)
	end)
end

local function hookSellPart(sellPart)
	if not sellPart or not sellPart:IsA("BasePart") or sellPart:GetAttribute("SellZoneHooked") then
		return
	end
	sellPart:SetAttribute("SellZoneHooked", true)

	if not SELLING_ENABLED then
		disableSellPart(sellPart)
		return
	end

	local prompt = ensureSellVisuals(sellPart)
	prompt.Triggered:Connect(function(player)
		useSellZone(player, sellColorEvent or teleportToSellEvent)
	end)

	sellPart.Touched:Connect(function(hit)
		local character = hit and hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if player then
			useSellZone(player, sellColorEvent or teleportToSellEvent)
		end
	end)
end

task.defer(function()
	for _, obj in ipairs(workspace:GetDescendants()) do
		if isSellPart(obj) then
			hookSellPart(obj)
		end
	end
end)

workspace.DescendantAdded:Connect(function(obj)
	if not SELLING_ENABLED and obj:IsA("ProximityPrompt") and obj.Name == "SellPrompt" then
		obj.Enabled = false
		return
	end
	if obj:IsA("BasePart") and isSellPart(obj) then
		task.defer(function()
			hookSellPart(obj)
		end)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	sellDebounce[player] = nil
end)
