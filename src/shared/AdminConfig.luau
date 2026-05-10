-- Central list for trusted staff. Use usernames here; server resolves them case-insensitively.
local AdminConfig = {}

AdminConfig.Developers = {
	jackdoesrb = true,
}

AdminConfig.Moderators = {
	Hihenry7 = true,
	VORTEX_UNLOCKED = true,
	t53_yt = true,
	DontTryMeBoy = true,
}

AdminConfig.EarlyTesters = {
	DontTryMeBoy = true,
}

function AdminConfig.normalizeName(name)
	return string.lower(tostring(name or ""))
end

function AdminConfig.isModeratorName(name)
	local normalized = AdminConfig.normalizeName(name)
	for modName in pairs(AdminConfig.Moderators) do
		if AdminConfig.normalizeName(modName) == normalized then
			return true
		end
	end
	return false
end

function AdminConfig.isDeveloperName(name)
	local normalized = AdminConfig.normalizeName(name)
	for devName in pairs(AdminConfig.Developers) do
		if AdminConfig.normalizeName(devName) == normalized then
			return true
		end
	end
	return false
end

function AdminConfig.isEarlyTesterName(name)
	local normalized = AdminConfig.normalizeName(name)
	for testerName in pairs(AdminConfig.EarlyTesters) do
		if AdminConfig.normalizeName(testerName) == normalized then
			return true
		end
	end
	return false
end

return AdminConfig
