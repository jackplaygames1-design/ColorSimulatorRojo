-- Binds the editable Studio TradeWindow to the simple server-owned trade service.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local tradeRequest = remotes:WaitForChild("TradeRequest", 20)
local tradeUpdate = remotes:WaitForChild("TradeUpdate", 20)

local function waitForTradeWindow()
	local root = playerGui:WaitForChild("ClientUIRoot", 30)
	local mainHud = root and root:WaitForChild("MainHUD", 30)
	local modalWindows = mainHud and mainHud:WaitForChild("ModalWindows", 30)
	local windows = modalWindows and modalWindows:WaitForChild("Windows", 30)
	return windows and windows:WaitForChild("TradeWindow", 30)
end

local tradeWindow = waitForTradeWindow()
if not tradeWindow or not tradeWindow:IsA("GuiObject") then
	warn("EditableTradeBinder: missing TradeWindow.")
	return
end
if not tradeRequest or not tradeUpdate then
	warn("EditableTradeBinder: trade remotes are not ready.")
	return
end

local content = tradeWindow:FindFirstChild("Content")
if not content or not content:IsA("GuiObject") then
	warn("EditableTradeBinder: missing TradeWindow.Content.")
	return
end

content:SetAttribute("EditableTradeBinderOwns", true)

local state = {
	Players = {},
	Colors = {},
	Gems = 0,
	Session = nil,
	Message = "",
}
local busy = false
local ui = {}

local function setText(object, value)
	if object and (object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox")) then
		object.Text = tostring(value or "")
	end
end

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 10)
	c.Parent = parent
	return c
end

local function stroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.fromRGB(35, 38, 45)
	s.Thickness = thickness or 2
	s.Parent = parent
	return s
end

local function makeFrame(parent, name, position, size, color)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Position = position
	frame.Size = size
	frame.BackgroundColor3 = color or Color3.fromRGB(244, 248, 252)
	frame.BorderSizePixel = 0
	frame.ZIndex = 1002
	frame.Parent = parent
	corner(frame, 14)
	stroke(frame)
	return frame
end

local function makeText(parent, name, value, position, size, textSize)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Text = value
	label.TextColor3 = Color3.fromRGB(38, 36, 52)
	label.TextScaled = false
	label.TextSize = textSize or 14
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.ZIndex = 1003
	label.Parent = parent
	return label
end

local function makeButton(parent, name, value, position, size, color)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Position = position
	button.Size = size
	button.BackgroundColor3 = color or Color3.fromRGB(82, 219, 225)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBlack
	button.Text = value
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 13
	button.TextScaled = true
	button.AutoButtonColor = true
	button.ZIndex = 1004
	button.Parent = parent
	corner(button, 10)
	stroke(button)
	return button
end

local function makeList(parent, name, position, size)
	local list = Instance.new("ScrollingFrame")
	list.Name = name
	list.Position = position
	list.Size = size
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ZIndex = 1003
	list.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	return list
end

local function clearList(list)
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function setButtonEnabled(button, enabled)
	button.Active = enabled == true
	button.AutoButtonColor = enabled == true
	button.BackgroundTransparency = enabled and 0 or 0.35
	pcall(function()
		button.Interactable = enabled == true
	end)
end

local render

local function invoke(action, payload)
	if busy then
		return
	end
	busy = true
	local ok, result = pcall(function()
		return tradeRequest:InvokeServer(action, payload or {})
	end)
	busy = false

	if ok and type(result) == "table" then
		state = result
		render()
	else
		state.Message = "Trade request failed."
		render()
	end
end

local function makeRow(parent, textValue, buttonText, onClick, disabled)
	local row = Instance.new("Frame")
	row.Name = "Row"
	row.Size = UDim2.new(1, -4, 0, 38)
	row.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	row.BorderSizePixel = 0
	row.ZIndex = 1004
	row.Parent = parent
	corner(row, 10)
	stroke(row, Color3.fromRGB(210, 220, 235), 1)

	local label = makeText(row, "Label", textValue, UDim2.fromOffset(10, 4), UDim2.new(1, -92, 1, -8), 12)
	label.Font = Enum.Font.GothamBold

	local button = makeButton(row, "Action", buttonText, UDim2.new(1, -78, 0, 6), UDim2.fromOffset(68, 26), Color3.fromRGB(80, 220, 112))
	button.TextSize = 12
	setButtonEnabled(button, disabled ~= true)
	button.Activated:Connect(function()
		if disabled ~= true and onClick then
			onClick()
		end
	end)
	return row
end

local function makeOfferRow(parent, color, removable)
	makeRow(parent, color.Name or color.Id or "Color", removable and "REMOVE" or "COLOR", function()
		invoke("RemoveColor", { ColorId = color.Id })
	end, removable ~= true)
end

local function buildUi()
	local existing = content:FindFirstChild("TradeRuntimeRoot")
	if existing then
		existing:Destroy()
	end
	for _, child in ipairs(content:GetChildren()) do
		if child:IsA("GuiObject") then
			child.Visible = false
		end
	end

	local root = Instance.new("Frame")
	root.Name = "TradeRuntimeRoot"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.ZIndex = 1002
	root.Parent = content
	ui.root = root

	ui.status = makeText(root, "Status", "Choose a player to start trading.", UDim2.fromOffset(14, 8), UDim2.new(1, -28, 0, 24), 14)
	ui.status.TextXAlignment = Enum.TextXAlignment.Center

	ui.playersPanel = makeFrame(root, "PlayersPanel", UDim2.fromOffset(14, 40), UDim2.new(0.25, -20, 1, -54))
	ui.inventoryPanel = makeFrame(root, "InventoryPanel", UDim2.new(0.25, 4, 0, 40), UDim2.new(0.32, -18, 1, -54))
	ui.offerPanel = makeFrame(root, "OfferPanel", UDim2.new(0.57, 4, 0, 40), UDim2.new(0.43, -18, 1, -54))

	makeText(ui.playersPanel, "Title", "PLAYERS", UDim2.fromOffset(10, 8), UDim2.new(1, -20, 0, 24), 14)
	makeText(ui.inventoryPanel, "Title", "YOUR COLORS", UDim2.fromOffset(10, 8), UDim2.new(1, -20, 0, 24), 14)
	makeText(ui.offerPanel, "Title", "TRADE OFFER", UDim2.fromOffset(10, 8), UDim2.new(1, -20, 0, 24), 14)

	ui.playersList = makeList(ui.playersPanel, "PlayersList", UDim2.fromOffset(10, 38), UDim2.new(1, -20, 1, -48))
	ui.colorsList = makeList(ui.inventoryPanel, "ColorsList", UDim2.fromOffset(10, 38), UDim2.new(1, -20, 1, -112))
	ui.gemBox = Instance.new("TextBox")
	ui.gemBox.Name = "GemBox"
	ui.gemBox.Position = UDim2.new(0, 10, 1, -66)
	ui.gemBox.Size = UDim2.new(1, -106, 0, 30)
	ui.gemBox.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	ui.gemBox.BorderSizePixel = 0
	ui.gemBox.ClearTextOnFocus = false
	ui.gemBox.Font = Enum.Font.GothamBold
	ui.gemBox.PlaceholderText = "Gems"
	ui.gemBox.Text = ""
	ui.gemBox.TextColor3 = Color3.fromRGB(38, 36, 52)
	ui.gemBox.TextSize = 14
	ui.gemBox.ZIndex = 1004
	ui.gemBox.Parent = ui.inventoryPanel
	corner(ui.gemBox, 10)
	stroke(ui.gemBox)
	ui.setGemsButton = makeButton(ui.inventoryPanel, "SetGemsButton", "SET", UDim2.new(1, -88, 1, -66), UDim2.fromOffset(78, 30))
	ui.setGemsButton.Activated:Connect(function()
		invoke("SetGems", { Amount = tonumber(ui.gemBox.Text) or 0 })
	end)
	ui.gemsLabel = makeText(ui.inventoryPanel, "GemsLabel", "Gems: 0", UDim2.fromOffset(10, 1), UDim2.new(1, -20, 0, 20), 12)
	ui.gemsLabel.Position = UDim2.new(0, 10, 1, -30)

	ui.myOfferTitle = makeText(ui.offerPanel, "MyOfferTitle", "YOU", UDim2.fromOffset(10, 38), UDim2.new(0.5, -14, 0, 20), 12)
	ui.theirOfferTitle = makeText(ui.offerPanel, "TheirOfferTitle", "THEM", UDim2.new(0.5, 4, 0, 38), UDim2.new(0.5, -14, 0, 20), 12)
	ui.myOfferList = makeList(ui.offerPanel, "MyOfferList", UDim2.fromOffset(10, 62), UDim2.new(0.5, -14, 1, -124))
	ui.theirOfferList = makeList(ui.offerPanel, "TheirOfferList", UDim2.new(0.5, 4, 0, 62), UDim2.new(0.5, -14, 1, -124))
	ui.acceptButton = makeButton(ui.offerPanel, "AcceptButton", "ACCEPT", UDim2.new(0, 10, 1, -48), UDim2.new(0.5, -16, 0, 34), Color3.fromRGB(80, 220, 112))
	ui.cancelButton = makeButton(ui.offerPanel, "CancelButton", "CANCEL", UDim2.new(0.5, 6, 1, -48), UDim2.new(0.5, -16, 0, 34), Color3.fromRGB(235, 74, 90))
	ui.acceptButton.Activated:Connect(function()
		invoke("Accept")
	end)
	ui.cancelButton.Activated:Connect(function()
		invoke("Cancel")
	end)
end

render = function()
	if not ui.root then
		return
	end

	local session = state.Session
	setText(ui.status, state.Message ~= "" and state.Message or (session and ("Trading with " .. session.OtherName) or "Choose a player to trade Colors and Gems."))
	setText(ui.gemsLabel, "Gems: " .. tostring(state.Gems or 0))

	clearList(ui.playersList)
	for _, other in ipairs(state.Players or {}) do
		makeRow(ui.playersList, other.DisplayName or other.Name or "Player", session and "BUSY" or "TRADE", function()
			invoke("Start", { TargetUserId = other.UserId })
		end, session ~= nil)
	end
	if #(state.Players or {}) == 0 then
		makeText(ui.playersList, "Empty", "No other players online.", UDim2.fromOffset(4, 4), UDim2.new(1, -8, 0, 40), 12)
	end

	clearList(ui.colorsList)
	for _, color in ipairs(state.Colors or {}) do
		local suffix = color.Locked and " (Locked)" or color.Equipped and " (Equipped)" or ""
		makeRow(ui.colorsList, tostring(color.Name or color.Id) .. suffix, "ADD", function()
			invoke("AddColor", { ColorId = color.Id })
		end, not session or color.Tradeable ~= true)
	end
	if #(state.Colors or {}) == 0 then
		makeText(ui.colorsList, "Empty", "No Colors to trade.", UDim2.fromOffset(4, 4), UDim2.new(1, -8, 0, 40), 12)
	end

	clearList(ui.myOfferList)
	clearList(ui.theirOfferList)
	local myOffer = session and session.MyOffer or { Gems = 0, Colors = {} }
	local theirOffer = session and session.TheirOffer or { Gems = 0, Colors = {} }
	makeRow(ui.myOfferList, "Gems: " .. tostring(myOffer.Gems or 0), "GEMS", nil, true)
	makeRow(ui.theirOfferList, "Gems: " .. tostring(theirOffer.Gems or 0), "GEMS", nil, true)
	for _, color in ipairs(myOffer.Colors or {}) do
		makeOfferRow(ui.myOfferList, color, true)
	end
	for _, color in ipairs(theirOffer.Colors or {}) do
		makeOfferRow(ui.theirOfferList, color, false)
	end

	setText(ui.myOfferTitle, session and (session.MyAccepted and "YOU - ACCEPTED" or "YOU") or "YOU")
	setText(ui.theirOfferTitle, session and (session.TheirAccepted and "THEM - ACCEPTED" or "THEM") or "THEM")
	setButtonEnabled(ui.acceptButton, session ~= nil)
	setButtonEnabled(ui.cancelButton, session ~= nil)
	setButtonEnabled(ui.setGemsButton, session ~= nil)
end

buildUi()
render()

local function refresh()
	invoke("GetState")
end

tradeWindow:GetPropertyChangedSignal("Visible"):Connect(function()
	if tradeWindow.Visible then
		refresh()
	end
end)

tradeUpdate.OnClientEvent:Connect(function(newState)
	if type(newState) == "table" then
		state = newState
		render()
	end
end)

Players.PlayerAdded:Connect(function()
	if tradeWindow.Visible then
		refresh()
	end
end)
Players.PlayerRemoving:Connect(function()
	if tradeWindow.Visible then
		refresh()
	end
end)

if tradeWindow.Visible then
	refresh()
end

print("[EditableTradeBinder] TradeWindow bound to simple Colors/Gems trading.")
