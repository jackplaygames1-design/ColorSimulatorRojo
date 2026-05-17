local SettingsData = {}

SettingsData.Defaults = {
	Music = true,
	TradeRequests = true,
	SoundEffects = true,
	ShowDamageNumbers = true,
	PetHideMode = false,
	AutoHatch = false,
	CameraShake = true,
	LowDetailFX = false,
}

SettingsData.LegacyAliases = {
	SFX = "SoundEffects",
	Popups = "ShowDamageNumbers",
	HidePets = "PetHideMode",
	LowFX = "LowDetailFX",
}

SettingsData.AllowedKeys = {}
for key in pairs(SettingsData.Defaults) do
	SettingsData.AllowedKeys[key] = true
end
for key in pairs(SettingsData.LegacyAliases) do
	SettingsData.AllowedKeys[key] = true
end

function SettingsData.ResolveKey(key)
	key = tostring(key or "")
	return SettingsData.LegacyAliases[key] or key
end

function SettingsData.IsAllowedKey(key)
	return SettingsData.AllowedKeys[tostring(key or "")] == true
end

function SettingsData.Normalize(settings)
	local normalized = {}
	for key, defaultValue in pairs(SettingsData.Defaults) do
		local value = type(settings) == "table" and settings[key]
		if type(value) ~= "boolean" then
			for legacyKey, canonicalKey in pairs(SettingsData.LegacyAliases) do
				if canonicalKey == key and type(settings) == "table" then
					value = settings[legacyKey]
					break
				end
			end
		end
		normalized[key] = type(value) == "boolean" and value or defaultValue
	end
	return normalized
end

function SettingsData.GetPlayerSetting(player, key, defaultValue)
	key = SettingsData.ResolveKey(key)
	local default = if type(defaultValue) == "boolean" then defaultValue else SettingsData.Defaults[key] == true
	if not player then
		return default
	end

	local settingsFolder = player:FindFirstChild("Settings")
	local value = settingsFolder and settingsFolder:FindFirstChild(key)
	if value and value:IsA("BoolValue") then
		return value.Value
	end

	for legacyKey, canonicalKey in pairs(SettingsData.LegacyAliases) do
		if canonicalKey == key then
			value = settingsFolder and settingsFolder:FindFirstChild(legacyKey)
			if value and value:IsA("BoolValue") then
				return value.Value
			end
		end
	end

	local attribute = player:GetAttribute("Setting" .. key)
	if type(attribute) == "boolean" then
		return attribute
	end
	return default
end

function SettingsData.CanReceiveTrades(player)
	return SettingsData.GetPlayerSetting(player, "TradeRequests", true)
end

return SettingsData
