-- Emergency-safe chat tag handler. Disabled by GameBalance.EnableChatTags for live stability.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local warned = false

local STUDIO_OWNER_NAMES = {
	jackdoesrb = true,
	jackp = true,
}

local function warnOnce(...)
	if warned then
		return
	end
	warned = true
	warn("ChatTags disabled due to setup error:", ...)
end

local function getChatTagsEnabled()
	local ok, gameBalance = pcall(function()
		return require(ReplicatedStorage:WaitForChild("GameBalance"))
	end)

	if not ok or type(gameBalance) ~= "table" then
		warnOnce(gameBalance)
		return false
	end

	return gameBalance.EnableChatTags == true
end

local function sanitizeChatPrefix(text)
	text = tostring(text or "")
	text = text:gsub("<[^>]*>", "")
	text = text:gsub("%[OWNER%]%s*", "")
	text = text:gsub("%[MOD%]%s*", "")
	text = text:gsub("%[VIP%]%s*", "")
	text = text:gsub("%[SUPPORTER%]%s*", "")
	return text:gsub("^%s+", "")
end

local function isOwner(userId, player)
	if game.CreatorType == Enum.CreatorType.User and userId == game.CreatorId then
		return true
	end

	if RunService:IsStudio() and player then
		local name = string.lower(player.Name)
		local displayName = string.lower(player.DisplayName)
		return STUDIO_OWNER_NAMES[name] == true or STUDIO_OWNER_NAMES[displayName] == true
	end

	return false
end

local function insertUnique(tags, seen, tag)
	if seen[tag] then
		return
	end
	seen[tag] = true
	table.insert(tags, tag)
end

local function buildPlainPrefix(message)
	local properties = Instance.new("TextChatMessageProperties")
	local source = message and message.TextSource
	if not source then
		properties.PrefixText = sanitizeChatPrefix(message and message.PrefixText)
		return properties
	end

	local speaker = Players:GetPlayerByUserId(source.UserId)
	if not speaker then
		properties.PrefixText = sanitizeChatPrefix(message.PrefixText)
		return properties
	end

	local tags = {}
	local seenTags = {}
	if isOwner(source.UserId, speaker) then
		insertUnique(tags, seenTags, "[OWNER]")
	end
	if speaker:GetAttribute("IsModerator") == true then
		insertUnique(tags, seenTags, "[MOD]")
	end
	if speaker:GetAttribute("IsVIP") == true then
		insertUnique(tags, seenTags, "[VIP]")
	end
	if speaker:GetAttribute("EarlySupporter") == true then
		insertUnique(tags, seenTags, "[SUPPORTER]")
	end

	local basePrefix = sanitizeChatPrefix(message.PrefixText)
	if basePrefix == "" then
		basePrefix = speaker.DisplayName
	end

	if #tags > 0 then
		properties.PrefixText = table.concat(tags, " ") .. " " .. basePrefix
	else
		properties.PrefixText = basePrefix
	end

	return properties
end

local ok, err = pcall(function()
	if not getChatTagsEnabled() then
		return
	end

	TextChatService.OnIncomingMessage = function(message)
		local success, properties = pcall(buildPlainPrefix, message)
		if success then
			return properties
		end

		warnOnce(properties)
		return Instance.new("TextChatMessageProperties")
	end
end)

if not ok then
	warnOnce(err)
end
