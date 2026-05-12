local SettingsData = {}

SettingsData.Defaults = {
	Music = true,
	SFX = true,
	Popups = true,
	LowFX = false,
	TradeRequests = true,
	HidePets = false,
	AutoHatch = false,
	CameraShake = true,
}

SettingsData.AllowedKeys = {
	Music = true,
	SFX = true,
	Popups = true,
	LowFX = true,
	TradeRequests = true,
	HidePets = true,
	AutoHatch = true,
	CameraShake = true,
}

function SettingsData.IsAllowedKey(key)
	return SettingsData.AllowedKeys[tostring(key or "")] == true
end

function SettingsData.Normalize(settings)
	local normalized = {}
	for key, defaultValue in pairs(SettingsData.Defaults) do
		local value = type(settings) == "table" and settings[key]
		normalized[key] = type(value) == "boolean" and value or defaultValue
	end
	return normalized
end

return SettingsData
