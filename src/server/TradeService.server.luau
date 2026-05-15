-- Simple server-owned trading for Colors and Gems.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetData = require(ReplicatedStorage:WaitForChild("PetData"))
local Events = ReplicatedStorage:WaitForChild("Events")
local dataDirtyEvent = Events:FindFirstChild("PlayerDataDirty")

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local tradeRequest = remotes:FindFirstChild("TradeRequest")
if tradeRequest and not tradeRequest:IsA("RemoteFunction") then
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
	tradeUpdate:Destroy()
	tradeUpdate = nil
end
if not tradeUpdate then
	tradeUpdate = Instance.new("RemoteEvent")
	tradeUpdate.Name = "TradeUpdate"
	tradeUpdate.Parent = remotes
end

local sessions = {}
local activeSessionByPlayer = {}
local nextSessionId = 0
local MAX_COLORS_PER_OFFER = 6

local function markDirty(player)
	if dataDirtyEvent and dataDirtyEvent:IsA("BindableEvent") then
		dataDirtyEvent:Fire(player, "trade")
	end
end

local function splitCsv(value)
	local out = {}
	for _, item in ipairs(string.split(value or "", ",")) do
		if item ~= "" then
			table.insert(out, item)
		end
	end
	return out
end

local function joinCsv(items)
	return table.concat(items, ",")
end

local function getVariantKey(encoded)
	local segments = string.split(tostring(encoded or ""), ":")
	if #segments <= 1 then
		return encoded
	end
	if tonumber(segments[2]) then
		return segments[1]
	end
	return segments[1]
end

local function getPetId(encoded)
	local segments = string.split(tostring(encoded or ""), ":")
	if segments[2] and not tonumber(segments[2]) then
		return segments[2]
	end
	local keyParts = string.split(segments[1] or "", "|")
	return keyParts[1] or segments[1]
end

local function getColorDisplayName(encoded)
	local petId = getPetId(encoded)
	local displayName = PetData.GetCompanionDisplayName(petId)
	if displayName ~= "Unknown Color" then
		return displayName
	end
	return tostring(petId or getVariantKey(encoded))
end

local function getPetValues(player)
	local petFolder = player:FindFirstChild("PetData")
	if not petFolder then
		return nil
	end
	return petFolder:FindFirstChild("Inventory"),
		petFolder:FindFirstChild("Equipped"),
		petFolder:FindFirstChild("Locked")
end

local function makeSet(csv)
	local set = {}
	for _, value in ipairs(splitCsv(csv)) do
		set[value] = true
	end
	return set
end

local function getGemsValue(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	return leaderstats and (leaderstats:FindFirstChild("Gems") or leaderstats:FindFirstChild("Diamonds"))
end

local function findColorEntry(player, colorId)
	local inventoryValue, equippedValue, lockedValue = getPetValues(player)
	if not inventoryValue then
		return nil, "Color inventory is not ready."
	end

	local equipped = makeSet(equippedValue and equippedValue.Value or "")
	local locked = makeSet(lockedValue and lockedValue.Value or "")
	for _, encoded in ipairs(splitCsv(inventoryValue.Value)) do
		local variantKey = getVariantKey(encoded)
		local petId = getPetId(encoded)
		if variantKey == colorId then
			if equipped[variantKey] or equipped[petId] then
				return nil, "Unequip that Color before trading it."
			end
			if locked[variantKey] or locked[petId] then
				return nil, "Unlock that Color before trading it."
			end
			return encoded
		end
	end

	return nil, "That Color is no longer in your inventory."
end

local function getColorRows(player)
	local rows = {}
	local inventoryValue, equippedValue, lockedValue = getPetValues(player)
	if not inventoryValue then
		return rows
	end

	local equipped = makeSet(equippedValue and equippedValue.Value or "")
	local locked = makeSet(lockedValue and lockedValue.Value or "")
	for _, encoded in ipairs(splitCsv(inventoryValue.Value)) do
		local variantKey = getVariantKey(encoded)
		local petId = getPetId(encoded)
		table.insert(rows, {
			Id = variantKey,
			Name = getColorDisplayName(encoded),
			Equipped = equipped[variantKey] == true or equipped[petId] == true,
			Locked = locked[variantKey] == true or locked[petId] == true,
			Tradeable = equipped[variantKey] ~= true
				and equipped[petId] ~= true
				and locked[variantKey] ~= true
				and locked[petId] ~= true,
		})
	end

	table.sort(rows, function(a, b)
		return tostring(a.Name) < tostring(b.Name)
	end)
	return rows
end

local function getPlayerList(player)
	local list = {}
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			table.insert(list, {
				UserId = other.UserId,
				Name = other.Name,
				DisplayName = other.DisplayName,
			})
		end
	end
	return list
end

local function getOtherPlayer(session, player)
	return session.players[1] == player and session.players[2] or session.players[1]
end

local function makeOffer()
	return {
		Gems = 0,
		Colors = {},
	}
end

local function getSession(player)
	local sessionId = activeSessionByPlayer[player]
	return sessionId and sessions[sessionId] or nil
end

local function serializeOffer(offer)
	local colors = {}
	for colorId, encoded in pairs(offer.Colors) do
		table.insert(colors, {
			Id = colorId,
			Name = getColorDisplayName(encoded),
		})
	end
	table.sort(colors, function(a, b)
		return tostring(a.Name) < tostring(b.Name)
	end)
	return {
		Gems = offer.Gems,
		Colors = colors,
	}
end

local function serializeSessionFor(player)
	local session = getSession(player)
	if not session then
		return nil
	end

	local other = getOtherPlayer(session, player)
	return {
		Id = session.id,
		OtherUserId = other and other.UserId or 0,
		OtherName = other and other.Name or "Player",
		MyOffer = serializeOffer(session.offers[player]),
		TheirOffer = serializeOffer(session.offers[other]),
		MyAccepted = session.accepted[player] == true,
		TheirAccepted = session.accepted[other] == true,
	}
end

local function makeState(player, message, success)
	local gems = getGemsValue(player)
	return {
		Success = success ~= false,
		Message = message or "",
		Players = getPlayerList(player),
		Colors = getColorRows(player),
		Gems = gems and gems.Value or 0,
		Session = serializeSessionFor(player),
	}
end

local function pushState(player, message, success)
	tradeUpdate:FireClient(player, makeState(player, message, success))
end

local function pushSession(session, message)
	for _, player in ipairs(session.players) do
		if player and player.Parent then
			pushState(player, message, true)
		end
	end
end

local function closeSession(session, message)
	if not session then
		return
	end

	sessions[session.id] = nil
	for _, player in ipairs(session.players) do
		activeSessionByPlayer[player] = nil
		if player and player.Parent then
			pushState(player, message, true)
		end
	end
end

local function resetAccepted(session)
	for _, player in ipairs(session.players) do
		session.accepted[player] = false
	end
end

local function startTrade(player, targetUserId)
	if activeSessionByPlayer[player] then
		return makeState(player, "Finish your current trade first.", false)
	end

	local target = Players:GetPlayerByUserId(tonumber(targetUserId) or 0)
	if not target or target == player then
		return makeState(player, "Choose another player to trade.", false)
	end
	if activeSessionByPlayer[target] then
		return makeState(player, target.Name .. " is already trading.", false)
	end

	nextSessionId += 1
	local session = {
		id = nextSessionId,
		players = { player, target },
		offers = {
			[player] = makeOffer(),
			[target] = makeOffer(),
		},
		accepted = {
			[player] = false,
			[target] = false,
		},
	}

	sessions[session.id] = session
	activeSessionByPlayer[player] = session.id
	activeSessionByPlayer[target] = session.id
	pushSession(session, player.Name .. " started a trade.")
	return makeState(player, "Trade started with " .. target.Name .. ".", true)
end

local function addColor(player, colorId)
	local session = getSession(player)
	if not session then
		return makeState(player, "Start a trade first.", false)
	end

	colorId = tostring(colorId or "")
	local offer = session.offers[player]
	if offer.Colors[colorId] then
		return makeState(player, "That Color is already in your offer.", false)
	end
	local count = 0
	for _ in pairs(offer.Colors) do
		count += 1
	end
	if count >= MAX_COLORS_PER_OFFER then
		return makeState(player, "You can offer up to " .. tostring(MAX_COLORS_PER_OFFER) .. " Colors.", false)
	end

	local encoded, message = findColorEntry(player, colorId)
	if not encoded then
		return makeState(player, message, false)
	end

	offer.Colors[colorId] = encoded
	resetAccepted(session)
	pushSession(session, player.Name .. " changed their offer.")
	return makeState(player, "Color added.", true)
end

local function removeColor(player, colorId)
	local session = getSession(player)
	if not session then
		return makeState(player, "Start a trade first.", false)
	end

	session.offers[player].Colors[tostring(colorId or "")] = nil
	resetAccepted(session)
	pushSession(session, player.Name .. " changed their offer.")
	return makeState(player, "Color removed.", true)
end

local function setGems(player, amount)
	local session = getSession(player)
	if not session then
		return makeState(player, "Start a trade first.", false)
	end

	local gems = getGemsValue(player)
	if not gems then
		return makeState(player, "Gems are not ready.", false)
	end

	amount = math.clamp(math.floor(tonumber(amount) or 0), 0, gems.Value)
	session.offers[player].Gems = amount
	resetAccepted(session)
	pushSession(session, player.Name .. " changed their offer.")
	return makeState(player, "Gems updated.", true)
end

local function validateOffer(player, offer)
	local gems = getGemsValue(player)
	if not gems or gems.Value < offer.Gems then
		return false, "Not enough Gems."
	end

	for colorId in pairs(offer.Colors) do
		local encoded, message = findColorEntry(player, colorId)
		if not encoded then
			return false, message
		end
		offer.Colors[colorId] = encoded
	end

	return true
end

local function removeColorEntries(player, colors)
	local inventoryValue = getPetValues(player)
	local remove = {}
	for colorId in pairs(colors) do
		remove[colorId] = true
	end

	local kept = {}
	for _, encoded in ipairs(splitCsv(inventoryValue.Value)) do
		if not remove[getVariantKey(encoded)] then
			table.insert(kept, encoded)
		end
	end
	inventoryValue.Value = joinCsv(kept)
end

local function addColorEntries(player, colors)
	local inventoryValue = getPetValues(player)
	local entries = splitCsv(inventoryValue.Value)
	for _, encoded in pairs(colors) do
		table.insert(entries, encoded)
	end
	inventoryValue.Value = joinCsv(entries)
end

local function commitTrade(session)
	local a = session.players[1]
	local b = session.players[2]
	local aOffer = session.offers[a]
	local bOffer = session.offers[b]

	local ok, message = validateOffer(a, aOffer)
	if not ok then
		closeSession(session, "Trade failed: " .. tostring(message))
		return
	end
	ok, message = validateOffer(b, bOffer)
	if not ok then
		closeSession(session, "Trade failed: " .. tostring(message))
		return
	end

	local aGems = getGemsValue(a)
	local bGems = getGemsValue(b)
	removeColorEntries(a, aOffer.Colors)
	removeColorEntries(b, bOffer.Colors)
	addColorEntries(a, bOffer.Colors)
	addColorEntries(b, aOffer.Colors)
	aGems.Value = aGems.Value - aOffer.Gems + bOffer.Gems
	bGems.Value = bGems.Value - bOffer.Gems + aOffer.Gems
	markDirty(a)
	markDirty(b)
	closeSession(session, "Trade complete!")
end

local function acceptTrade(player)
	local session = getSession(player)
	if not session then
		return makeState(player, "Start a trade first.", false)
	end

	local ok, message = validateOffer(player, session.offers[player])
	if not ok then
		return makeState(player, message, false)
	end

	session.accepted[player] = true
	local other = getOtherPlayer(session, player)
	if session.accepted[other] == true then
		commitTrade(session)
		return makeState(player, "Trade complete!", true)
	end

	pushSession(session, player.Name .. " accepted.")
	return makeState(player, "Waiting for " .. other.Name .. " to accept.", true)
end

tradeRequest.OnServerInvoke = function(player, action, payload)
	payload = type(payload) == "table" and payload or {}
	action = tostring(action or "GetState")

	if action == "GetState" then
		return makeState(player)
	elseif action == "Start" then
		return startTrade(player, payload.TargetUserId)
	elseif action == "AddColor" then
		return addColor(player, payload.ColorId)
	elseif action == "RemoveColor" then
		return removeColor(player, payload.ColorId)
	elseif action == "SetGems" then
		return setGems(player, payload.Amount)
	elseif action == "Accept" then
		return acceptTrade(player)
	elseif action == "Cancel" then
		local session = getSession(player)
		if session then
			closeSession(session, player.Name .. " cancelled the trade.")
		end
		return makeState(player, "Trade cancelled.", true)
	end

	return makeState(player, "Unknown trade action.", false)
end

Players.PlayerRemoving:Connect(function(player)
	local session = getSession(player)
	if session then
		closeSession(session, player.Name .. " left the game.")
	end
end)
