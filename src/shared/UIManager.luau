-- ModuleScript in ReplicatedStorage named "UIManager"
local UIManager = {}

-- Registry: { [name] = { open=fn, close=fn, isOpen=fn } }
local registry = {}
local currentOpen = nil
local currentContext = nil
local warnedMissing = {}

local function getRegisteredNamesText()
	local names = {}
	for name in pairs(registry) do
		table.insert(names, tostring(name))
	end
	table.sort(names)
	return #names > 0 and table.concat(names, ", ") or "none"
end

function UIManager.register(name, openFn, closeFn, isOpenFn)
	registry[name] = {
		open = openFn,
		close = closeFn,
		isOpen = isOpenFn,
	}
end

function UIManager.closeAll(except)
	for name, entry in pairs(registry) do
		if name ~= except then
			local ok, err = pcall(function()
				if entry.isOpen() then
					entry.close({ immediate = true })
				end
			end)
			if not ok then
				warn("UIManager closeAll error on " .. name .. ": " .. tostring(err))
			end
		end
	end
	if currentOpen == except then
		return
	end
	currentOpen = nil
	currentContext = nil
end

function UIManager.open(name, context)
	UIManager.closeAll(name)
	local entry = registry[name]
	if not entry then
		if not warnedMissing[name] then
			warnedMissing[name] = true
			warn("UIManager: no window registered as '" .. name .. "'. Registered: " .. getRegisteredNamesText())
		end
		return false
	end
	local ok, err = pcall(function()
		entry.open(context)
	end)
	if not ok then
		warn("UIManager open error on " .. tostring(name) .. ": " .. tostring(err))
		currentOpen = nil
		currentContext = nil
		return false
	end
	local stayedOpen = true
	if entry.isOpen then
		local isOpenOk, result = pcall(entry.isOpen)
		stayedOpen = isOpenOk and result == true
	end
	if stayedOpen then
		currentOpen = name
		currentContext = context
	else
		currentOpen = nil
		currentContext = nil
	end
	return true
end

UIManager.OpenWindow = UIManager.open

function UIManager.close(name)
	local entry = registry[name]
	if not entry then
		return
	end
	entry.close()
	if currentOpen == name then
		currentOpen = nil
		currentContext = nil
	end
end

UIManager.CloseWindow = UIManager.close
UIManager.CloseAllWindows = UIManager.closeAll

function UIManager.toggle(name, context)
	local entry = registry[name]
	if not entry then
		if not warnedMissing[name] then
			warnedMissing[name] = true
			warn("UIManager: no window registered as '" .. name .. "'. Registered: " .. getRegisteredNamesText())
		end
		return false
	end
	if entry.isOpen() then
		entry.close()
		if currentOpen == name then
			currentOpen = nil
			currentContext = nil
		end
	else
		UIManager.open(name, context)
	end
	return true
end

function UIManager.isOpen(name)
	local entry = registry[name]
	if not entry then
		return false
	end
	local ok, result = pcall(entry.isOpen)
	return ok and result or false
end

function UIManager.getCurrent()
	for name, entry in pairs(registry) do
		local ok, result = pcall(entry.isOpen)
		if ok and result then
			currentOpen = name
			return name
		end
	end
	currentOpen = nil
	currentContext = nil
	return nil
end

function UIManager.isRegistered(name)
	return registry[name] ~= nil
end

function UIManager.GetActiveWindow()
	return UIManager.getCurrent()
end

function UIManager.GetOpenContext()
	return currentContext
end

function UIManager.IsModalOpen()
	return UIManager.getCurrent() ~= nil
end

return UIManager
