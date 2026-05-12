-- Bind-only trade script. It never creates TradeWindow UI; build the visuals in Studio.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local tradeRequest = remotes:WaitForChild("TradeRequest", 20)
local tradeUpdate = remotes:WaitForChild("TradeUpdate", 20)

local ROOT_PATH = "PlayerGui.MainHUD.ModalWindows.TradeWindow"
local TRADE_PICK_ACTIVE_ATTRIBUTE = "TradePickColorActive"
local TRADE_PICK_RETURN_ATTRIBUTE = "TradePickReturnWindow"
local TRADE_PICK_REFRESH_ATTRIBUTE = "TradePickRefreshToken"
local warned = {}
local state = {
	Message = "",
	Gems = 0,
	Session = nil,
}
local render

local function warnOnce(path)
	if warned[path] then
		return
	end
	warned[path] = true
	warn("EditableTradeBinder: missing " .. path)
end

local function findPath(parent, childPath)
	local current = parent
	for segment in string.gmatch(childPath, "[^%.]+") do
		current = current and current:FindFirstChild(segment)
		if not current then
			warnOnce(ROOT_PATH .. "." .. childPath)
			return nil
		end
	end
	return current
end

local function findDescendant(parent, name, className, path)
	local found = parent and parent:FindFirstChild(name, true)
	if not found then
		warnOnce(path or (ROOT_PATH .. "." .. name))
		return nil
	end
	if className and not found:IsA(className) then
		warn("EditableTradeBinder: " .. (path or found:GetFullName()) .. " must be a " .. className)
		return nil
	end
	return found
end

local mainHud = playerGui:WaitForChild("MainHUD", 20)
if not mainHud then
	warnOnce("PlayerGui.MainHUD")
	return
end

local modalWindows = mainHud:WaitForChild("ModalWindows", 20)
if not modalWindows then
	warnOnce("PlayerGui.MainHUD.ModalWindows")
	return
end

local tradeWindow = modalWindows:WaitForChild("TradeWindow", 20)
if not tradeWindow or not tradeWindow:IsA("GuiObject") then
	warnOnce(ROOT_PATH)
	return
end

local content = tradeWindow:FindFirstChild("Content") or tradeWindow
local inventoryWindow = modalWindows:FindFirstChild("InventoryWindow")
local ui = {
	Status = findDescendant(content, "Status", "TextLabel", ROOT_PATH .. ".Content.Status"),
	GemsLabel = findDescendant(content, "GemsLabel", "TextLabel", ROOT_PATH .. ".Content.GemsLabel"),
	GemBox = findDescendant(content, "GemBox", "TextBox", ROOT_PATH .. ".Content.GemBox"),
	SetGemsButton = findDescendant(content, "SetGemsButton", "GuiButton", ROOT_PATH .. ".Content.SetGemsButton"),
	AcceptButton = findDescendant(content, "AcceptButton", "GuiButton", ROOT_PATH .. ".Content.AcceptButton"),
	CancelButton = findDescendant(content, "CancelButton", "GuiButton", ROOT_PATH .. ".Content.CancelButton"),
	MyOfferGems = findDescendant(content, "MyOfferGems", "TextLabel", ROOT_PATH .. ".Content.MyOfferGems"),
	TheirOfferGems = findDescendant(content, "TheirOfferGems", "TextLabel", ROOT_PATH .. ".Content.TheirOfferGems"),
	MyReady = findDescendant(content, "MyReady", "TextLabel", ROOT_PATH .. ".Content.MyReady"),
	TheirReady = findDescendant(content, "TheirReady", "TextLabel", ROOT_PATH .. ".Content.TheirReady"),
	PlayersList = findDescendant(content, "PlayersList", nil, ROOT_PATH .. ".Content.PlayersList"),
	ColorsList = findDescendant(content, "ColorsList", nil, ROOT_PATH .. ".Content.ColorsList"),
	MyOfferList = findDescendant(content, "MyOfferList", nil, ROOT_PATH .. ".Content.MyOfferList"),
	TheirOfferList = findDescendant(content, "TheirOfferList", nil, ROOT_PATH .. ".Content.TheirOfferList"),
}

findPath(tradeWindow, "Content")

local slotConnections = {}
local lastPickRefreshToken = mainHud:GetAttribute(TRADE_PICK_REFRESH_ATTRIBUTE)

local function setText(object, value)
	if object and (object:IsA("TextLabel") or object:IsA("TextButton")) then
		object.Text = tostring(value or "")
	end
end

local function findText(parent, names)
	if not parent then
		return nil
	end
	for _, name in ipairs(names) do
		local object = parent:FindFirstChild(name, true)
		if object and (object:IsA("TextLabel") or object:IsA("TextButton")) then
			return object
		end
	end
	return nil
end

local function findButton(parent, names)
	if not parent then
		return nil
	end
	for _, name in ipairs(names) do
		local object = parent:FindFirstChild(name, true)
		if object and object:IsA("GuiButton") then
			return object
		end
	end
	if parent:IsA("GuiButton") then
		return parent
	end
	return nil
end

local function setGuiVisible(object, visible)
	if object and object:IsA("GuiObject") then
		object.Visible = visible == true
	end
end

local function setButtonEnabled(button, enabled)
	if not button then
		return
	end
	button.Active = enabled == true
	button.Selectable = enabled == true
	button.AutoButtonColor = enabled == true
	button.BackgroundTransparency = enabled == true and 0 or 0.35
	pcall(function()
		button.Interactable = enabled == true
	end)
end

local function disconnectSlotConnections()
	for _, connection in ipairs(slotConnections) do
		if connection and connection.Connected then
			connection:Disconnect()
		end
	end
	table.clear(slotConnections)
end

local function collectSlots(container, prefix)
	local slots = {}
	if not container then
		return slots
	end

	for _, object in ipairs(container:GetDescendants()) do
		if
			object:IsA("GuiObject")
			and (object.Name:match("^" .. prefix .. "Slot%d+$") or object:GetAttribute("TradeSlotRole") == prefix)
		then
			table.insert(slots, object)
		end
	end

	table.sort(slots, function(a, b)
		if a.LayoutOrder ~= b.LayoutOrder then
			return a.LayoutOrder < b.LayoutOrder
		end
		return a.Name < b.Name
	end)
	return slots
end

local function updateSlot(slot, labelText, metaText, buttonText, enabled, callback)
	local nameLabel = findText(slot, { "Name", "PlayerName", "ItemName", "Title", "Label" })
	local metaLabel = findText(slot, { "Meta", "Status", "Amount", "Subtitle" })
	local button = findButton(slot, { "TradeButton", "AddButton", "RemoveButton", "ActionButton", "Button" })

	setText(nameLabel, labelText)
	setText(metaLabel, metaText)
	if button then
		if button == slot then
			setText(button, labelText == "" and buttonText or "")
		else
			setText(button, buttonText)
		end
	end
	setButtonEnabled(button, enabled == true)
	setGuiVisible(slot, true)

	if button and callback and enabled == true then
		table.insert(slotConnections, button.Activated:Connect(callback))
	end
end

local function beginInventoryPick()
	if not state.Session then
		setText(ui.Status, "Choose a player before adding Colors.")
		return
	end
	mainHud:SetAttribute(TRADE_PICK_ACTIVE_ATTRIBUTE, true)
	mainHud:SetAttribute(TRADE_PICK_RETURN_ATTRIBUTE, "TradeWindow")
	if inventoryWindow and inventoryWindow:IsA("GuiObject") then
		tradeWindow.Visible = false
		inventoryWindow.Visible = true
	else
		warnOnce("PlayerGui.MainHUD.ModalWindows.InventoryWindow")
	end
end

local function clearRemainingSlots(slots, startIndex)
	for index = startIndex, #slots do
		local slot = slots[index]
		setText(findText(slot, { "Name", "PlayerName", "ItemName", "Title", "Label" }), "")
		setText(findText(slot, { "Meta", "Status", "Amount", "Subtitle" }), "")
		local button = findButton(slot, { "TradeButton", "AddButton", "RemoveButton", "ActionButton", "Button" })
		setText(button, "")
		setButtonEnabled(button, false)
		setGuiVisible(slot, false)
	end
end

local function invoke(action, payload)
	if not tradeRequest then
		warn("EditableTradeBinder: missing ReplicatedStorage.Remotes.TradeRequest")
		return nil
	end
	local ok, result = pcall(function()
		return tradeRequest:InvokeServer(action, payload or {})
	end)
	if not ok then
		warn("EditableTradeBinder: trade request failed: " .. tostring(result))
		return nil
	end
	return result
end

local function applyResult(result)
	if type(result) == "table" then
		state = result
		render()
	end
end

render = function()
	disconnectSlotConnections()

	local session = state.Session
	local message = tostring(state.Message or "")
	if message == "" then
		message = session and ("Trading with " .. tostring(session.OtherName or "Player"))
			or "Choose a player to trade."
	end

	setText(ui.Status, message)
	setText(ui.GemsLabel, "Gems: " .. tostring(state.Gems or 0))

	local myOffer = session and session.MyOffer or { Gems = 0 }
	local theirOffer = session and session.TheirOffer or { Gems = 0 }
	setText(ui.MyOfferGems, "Gems: " .. tostring(myOffer.Gems or 0))
	setText(ui.TheirOfferGems, "Gems: " .. tostring(theirOffer.Gems or 0))
	setText(ui.MyReady, session and session.MyAccepted and "READY" or "NOT READY")
	setText(ui.TheirReady, session and session.TheirAccepted and "READY" or "NOT READY")

	local playerSlots = collectSlots(ui.PlayersList, "Player")
	local players = type(state.Players) == "table" and state.Players or {}
	for index, row in ipairs(players) do
		local slot = playerSlots[index]
		if slot then
			updateSlot(
				slot,
				tostring(row.DisplayName or row.Name or "Player"),
				tostring(row.Name or ""),
				"TRADE",
				true,
				function()
					applyResult(invoke("Start", { TargetUserId = row.UserId }))
				end
			)
		end
	end
	clearRemainingSlots(playerSlots, #players + 1)

	local colorSlots = collectSlots(ui.ColorsList, "Color")
	local colors = type(state.Colors) == "table" and state.Colors or {}
	for index, row in ipairs(colors) do
		local slot = colorSlots[index]
		if slot then
			local enabled = session ~= nil and row.Tradeable == true
			local meta = row.Locked and "Locked"
				or row.Equipped and "Equipped"
				or enabled and "Ready"
				or "Choose player"
			updateSlot(slot, tostring(row.Name or row.Id or "Color"), meta, "ADD", enabled, function()
				applyResult(invoke("AddColor", { ColorId = row.Id }))
			end)
		end
	end
	clearRemainingSlots(colorSlots, #colors + 1)

	local myColorSlots = collectSlots(ui.MyOfferList, "MyOffer")
	local myColors = type(myOffer.Colors) == "table" and myOffer.Colors or {}
	for index, row in ipairs(myColors) do
		local slot = myColorSlots[index]
		if slot then
			updateSlot(slot, tostring(row.Name or row.Id or "Color"), "", "REMOVE", true, function()
				applyResult(invoke("RemoveColor", { ColorId = row.Id }))
			end)
		end
	end
	for index = #myColors + 1, #myColorSlots do
		updateSlot(myColorSlots[index], "", "", "+", session ~= nil, beginInventoryPick)
	end

	local theirColorSlots = collectSlots(ui.TheirOfferList, "TheirOffer")
	local theirColors = type(theirOffer.Colors) == "table" and theirOffer.Colors or {}
	for index, row in ipairs(theirColors) do
		local slot = theirColorSlots[index]
		if slot then
			updateSlot(slot, tostring(row.Name or row.Id or "Color"), "", "", false)
		end
	end
	clearRemainingSlots(theirColorSlots, #theirColors + 1)
end

local function connectButton(button, callback)
	if button and button:IsA("GuiButton") then
		button.Activated:Connect(callback)
	end
end

connectButton(ui.SetGemsButton, function()
	local amount = ui.GemBox and tonumber(ui.GemBox.Text) or 0
	applyResult(invoke("SetGems", { Amount = amount or 0 }))
end)

connectButton(ui.AcceptButton, function()
	applyResult(invoke("Accept"))
end)

connectButton(ui.CancelButton, function()
	applyResult(invoke("Cancel"))
end)

mainHud:GetAttributeChangedSignal(TRADE_PICK_REFRESH_ATTRIBUTE):Connect(function()
	local token = mainHud:GetAttribute(TRADE_PICK_REFRESH_ATTRIBUTE)
	if token == lastPickRefreshToken then
		return
	end
	lastPickRefreshToken = token
	applyResult(invoke("GetState"))
end)

if tradeUpdate then
	tradeUpdate.OnClientEvent:Connect(function(newState)
		if type(newState) == "table" then
			state = newState
			render()
		end
	end)
else
	warn("EditableTradeBinder: missing ReplicatedStorage.Remotes.TradeUpdate")
end

local initialState = invoke("GetState")
if type(initialState) == "table" then
	state = initialState
end
render()
