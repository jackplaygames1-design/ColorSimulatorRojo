-- Binds the editable Studio TradeWindow to the simple server-owned trade service.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local tradeRequest = remotes:WaitForChild("TradeRequest", 20)
local tradeUpdate = remotes:WaitForChild("TradeUpdate", 20)

local THEME = {
	Ink = Color3.fromRGB(38, 36, 52),
	Muted = Color3.fromRGB(95, 103, 122),
	Stroke = Color3.fromRGB(35, 38, 45),
	Outer = Color3.fromRGB(246, 249, 253),
	Panel = Color3.fromRGB(236, 243, 252),
	PanelSoft = Color3.fromRGB(249, 252, 255),
	White = Color3.fromRGB(255, 255, 255),
	Cyan = Color3.fromRGB(82, 214, 224),
	Green = Color3.fromRGB(77, 224, 111),
	GreenDark = Color3.fromRGB(26, 124, 52),
	Pink = Color3.fromRGB(241, 83, 110),
	Yellow = Color3.fromRGB(255, 210, 64),
	Purple = Color3.fromRGB(160, 118, 237),
	Disabled = Color3.fromRGB(190, 198, 211),
}

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

local function getInitials(value, fallback)
	local text = tostring(value or "")
	text = string.gsub(text, "^%s+", "")
	text = string.upper(string.sub(text, 1, 2))
	if text == "" then
		return fallback or "CO"
	end
	return text
end

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 10)
	c.Parent = parent
	return c
end

local function stroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or THEME.Stroke
	s.Thickness = thickness or 2
	s.Parent = parent
	return s
end

local function makeText(parent, name, value, position, size, textSize, options)
	options = options or {}
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = options.backgroundTransparency or 1
	label.BackgroundColor3 = options.backgroundColor or THEME.White
	label.BorderSizePixel = 0
	label.Font = options.font or Enum.Font.GothamBlack
	label.Text = tostring(value or "")
	label.TextColor3 = options.textColor or THEME.Ink
	label.TextScaled = options.scaled == true
	label.TextSize = textSize or 14
	label.TextWrapped = options.wrapped ~= false
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.TextXAlignment = options.xAlignment or Enum.TextXAlignment.Left
	label.TextYAlignment = options.yAlignment or Enum.TextYAlignment.Center
	label.TextStrokeColor3 = options.strokeColor or THEME.Stroke
	label.TextStrokeTransparency = options.textStroke and 0.12 or 1
	label.ZIndex = options.zIndex or 1003
	label.Parent = parent
	if options.radius then
		corner(label, options.radius)
	end
	if options.outline then
		stroke(label, options.outlineColor or THEME.Stroke, options.outlineThickness or 1)
	end
	if options.scaled then
		local constraint = Instance.new("UITextSizeConstraint")
		constraint.MinTextSize = options.minTextSize or 9
		constraint.MaxTextSize = options.maxTextSize or textSize or 18
		constraint.Parent = label
	end
	return label
end

local function makeButton(parent, name, value, position, size, color, options)
	options = options or {}
	local button = Instance.new("TextButton")
	button.Name = name
	button.Position = position
	button.Size = size
	button.BackgroundColor3 = color or THEME.Cyan
	button.BorderSizePixel = 0
	button.Font = options.font or Enum.Font.GothamBlack
	button.Text = tostring(value or "")
	button.TextColor3 = options.textColor or THEME.White
	button.TextScaled = true
	button.TextSize = options.textSize or 18
	button.TextStrokeColor3 = options.strokeColor or THEME.Stroke
	button.TextStrokeTransparency = options.textStroke == false and 1 or 0.1
	button.AutoButtonColor = true
	button.ZIndex = options.zIndex or 1005
	button.Parent = parent
	button:SetAttribute("EnabledColor", button.BackgroundColor3)
	corner(button, options.radius or 12)
	stroke(button, options.outlineColor or THEME.Stroke, options.outlineThickness or 2)

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = options.minTextSize or 10
	constraint.MaxTextSize = options.maxTextSize or options.textSize or 22
	constraint.Parent = button
	return button
end

local function clearList(list)
	if not list then
		return
	end
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function setButtonEnabled(button, enabled)
	if not button then
		return
	end
	local enabledColor = button:GetAttribute("EnabledColor")
	button.Active = enabled == true
	button.AutoButtonColor = enabled == true
	button.BackgroundTransparency = enabled and 0 or 0.18
	if typeof(enabledColor) == "Color3" then
		button.BackgroundColor3 = enabled and enabledColor or THEME.Disabled
	end
	button.TextTransparency = enabled and 0 or 0.12
	button.TextStrokeTransparency = enabled and 0.1 or 0.65
	pcall(function()
		button.Interactable = enabled == true
	end)
end

local function setAvatar(image, userId)
	if not image or not image:IsA("ImageLabel") then
		return
	end
	image.Image = ""
	userId = tonumber(userId) or 0
	if userId <= 0 then
		return
	end
	task.spawn(function()
		local ok, thumbnail = pcall(function()
			return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok and image.Parent then
			image.Image = thumbnail
		end
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

local function makeEmptyState(parent, textValue)
	local empty = makeText(parent, "Empty", textValue, UDim2.fromOffset(0, 0), UDim2.new(1, -8, 0, 44), 12, {
		font = Enum.Font.GothamBold,
		textColor = THEME.Muted,
		wrapped = true,
	})
	empty.LayoutOrder = 9999
	return empty
end

local function makeIcon(parent, textValue, color)
	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.Position = UDim2.fromOffset(8, 7)
	icon.Size = UDim2.fromOffset(32, 32)
	icon.BackgroundColor3 = color or THEME.Cyan
	icon.BorderSizePixel = 0
	icon.ZIndex = 1005
	icon.Parent = parent
	corner(icon, 10)
	stroke(icon, THEME.Stroke, 2)

	makeText(icon, "Letters", textValue, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 16, {
		scaled = true,
		maxTextSize = 16,
		textColor = THEME.White,
		textStroke = true,
		xAlignment = Enum.TextXAlignment.Center,
	})
	return icon
end

local function makeRow(parent, textValue, buttonText, onClick, disabled, options)
	options = options or {}
	local row = Instance.new("Frame")
	row.Name = options.name or "Row"
	row.Size = UDim2.new(1, -4, 0, options.height or 48)
	row.BackgroundColor3 = options.backgroundColor or THEME.White
	row.BorderSizePixel = 0
	row.LayoutOrder = options.layoutOrder or 0
	row.ZIndex = 1004
	row.Parent = parent
	corner(row, options.radius or 12)
	stroke(row, options.strokeColor or Color3.fromRGB(206, 218, 235), options.strokeThickness or 1)

	local labelX = 10
	if options.iconText then
		makeIcon(row, options.iconText, options.iconColor)
		labelX = 48
	end

	local buttonWidth = buttonText and (options.buttonWidth or 78) or 0
	local label = makeText(
		row,
		"Label",
		textValue,
		UDim2.fromOffset(labelX, 4),
		UDim2.new(1, -(labelX + buttonWidth + 16), 0, options.meta and 22 or row.Size.Y.Offset - 8),
		options.textSize or 13,
		{
			font = Enum.Font.GothamBlack,
			scaled = options.scaled == true,
			maxTextSize = options.textSize or 14,
			wrapped = false,
		}
	)

	if options.meta then
		makeText(
			row,
			"Meta",
			options.meta,
			UDim2.fromOffset(labelX, 25),
			UDim2.new(1, -(labelX + buttonWidth + 16), 0, 18),
			10,
			{
				font = Enum.Font.GothamBold,
				textColor = options.metaColor or THEME.Muted,
				wrapped = false,
			}
		)
	end

	local button = nil
	if buttonText then
		button = makeButton(
			row,
			"Action",
			buttonText,
			UDim2.new(1, -(buttonWidth + 8), 0.5, -15),
			UDim2.fromOffset(buttonWidth, 30),
			options.buttonColor or THEME.Green,
			{
				textSize = options.buttonTextSize or 17,
				maxTextSize = options.buttonMaxTextSize or 17,
				minTextSize = 8,
			}
		)
		setButtonEnabled(button, disabled ~= true)
		button.Activated:Connect(function()
			if disabled ~= true and onClick then
				onClick()
			end
		end)
	end

	return row, label, button
end

local function makePlayerRow(parent, other, session)
	local row = Instance.new("Frame")
	row.Name = "PlayerRow"
	row.Size = UDim2.new(1, -4, 0, 54)
	row.BackgroundColor3 = THEME.White
	row.BorderSizePixel = 0
	row.ZIndex = 1004
	row.Parent = parent
	corner(row, 13)
	stroke(row, Color3.fromRGB(206, 218, 235), 1)

	local avatar = Instance.new("ImageLabel")
	avatar.Name = "Avatar"
	avatar.Position = UDim2.fromOffset(8, 8)
	avatar.Size = UDim2.fromOffset(38, 38)
	avatar.BackgroundColor3 = Color3.fromRGB(218, 231, 246)
	avatar.BorderSizePixel = 0
	avatar.ZIndex = 1005
	avatar.Parent = row
	corner(avatar, 19)
	stroke(avatar, THEME.Stroke, 1)
	setAvatar(avatar, other.UserId)

	makeText(
		row,
		"Name",
		other.DisplayName or other.Name or "Player",
		UDim2.fromOffset(54, 6),
		UDim2.new(1, -132, 0, 22),
		13,
		{ wrapped = false }
	)
	makeText(
		row,
		"Handle",
		"@" .. tostring(other.Name or "player"),
		UDim2.fromOffset(54, 28),
		UDim2.new(1, -132, 0, 18),
		10,
		{
			font = Enum.Font.GothamBold,
			textColor = THEME.Muted,
			wrapped = false,
		}
	)

	local button = makeButton(
		row,
		"TradeButton",
		session and "BUSY" or "TRADE",
		UDim2.new(1, -70, 0.5, -15),
		UDim2.fromOffset(60, 30),
		THEME.Cyan,
		{
			textSize = 14,
			maxTextSize = 14,
			minTextSize = 8,
		}
	)
	setButtonEnabled(button, session == nil)
	button.Activated:Connect(function()
		if session == nil then
			invoke("Start", { TargetUserId = other.UserId })
		end
	end)
end

local function makeOfferColorRow(parent, color, removable)
	local label = tostring(color.Name or color.Id or "Color")
	makeRow(
		parent,
		label,
		removable and "X" or nil,
		function()
			invoke("RemoveColor", { ColorId = color.Id })
		end,
		removable ~= true,
		{
			iconText = getInitials(label, "CO"),
			iconColor = THEME.Purple,
			meta = "Color",
			buttonWidth = 34,
			buttonColor = THEME.Pink,
			buttonTextSize = 18,
			height = 46,
		}
	)
end

local function makeGemOfferRow(parent, amount)
	makeRow(parent, "Gems", nil, nil, true, {
		iconText = "$",
		iconColor = THEME.Yellow,
		meta = tostring(amount or 0),
		metaColor = THEME.GreenDark,
		height = 46,
	})
end

local function findBoundGui(parent, name, className)
	local found = parent and parent:FindFirstChild(name, true)
	if found and (not className or found:IsA(className)) then
		return found
	end
	warn("EditableTradeBinder: missing editable TradeWindow element " .. name .. ".")
	return nil
end

local function rememberButtonColor(button)
	if button and button:IsA("TextButton") then
		button:SetAttribute("EnabledColor", button.BackgroundColor3)
	end
end

local function bindUi()
	local oldRuntime = content:FindFirstChild("TradeRuntimeRoot")
	if oldRuntime then
		oldRuntime:Destroy()
	end

	content.ClipsDescendants = false
	local root = content:FindFirstChild("TradeRoot")
	if not root or not root:IsA("GuiObject") then
		warn(
			"EditableTradeBinder: TradeRoot is missing. Run require(game.ReplicatedStorage.StudioMenuWindowsBuilder).UpdateTradeWindow() in edit mode."
		)
		return false
	end

	for _, child in ipairs(content:GetChildren()) do
		if child:IsA("GuiObject") then
			child.Visible = child == root
		end
	end

	ui.root = root
	ui.status = findBoundGui(root, "Status", "TextLabel")
	ui.playersList = findBoundGui(root, "PlayersList", "ScrollingFrame")
	ui.colorsList = findBoundGui(root, "ColorsList", "ScrollingFrame")
	ui.gemsOwned = findBoundGui(root, "GemsOwned", "TextLabel")
	ui.gemBox = findBoundGui(root, "GemBox", "TextBox")
	ui.setGemsButton = findBoundGui(root, "SetGemsButton", "TextButton")
	ui.offerHint = findBoundGui(root, "OfferHint", "TextLabel")
	ui.myOfferPanel = findBoundGui(root, "MyOfferPanel", "Frame")
	ui.theirOfferPanel = findBoundGui(root, "TheirOfferPanel", "Frame")
	ui.myName = findBoundGui(root, "MyName", "TextLabel")
	ui.theirName = findBoundGui(root, "TheirName", "TextLabel")
	ui.myReady = findBoundGui(root, "MyReady", "TextLabel")
	ui.theirReady = findBoundGui(root, "TheirReady", "TextLabel")
	ui.myOfferList = findBoundGui(root, "MyOfferList", "ScrollingFrame")
	ui.theirOfferList = findBoundGui(root, "TheirOfferList", "ScrollingFrame")
	ui.acceptButton = findBoundGui(root, "AcceptButton", "TextButton")
	ui.cancelButton = findBoundGui(root, "CancelButton", "TextButton")

	local required = {
		ui.status,
		ui.playersList,
		ui.colorsList,
		ui.gemsOwned,
		ui.gemBox,
		ui.setGemsButton,
		ui.offerHint,
		ui.myOfferPanel,
		ui.theirOfferPanel,
		ui.myName,
		ui.theirName,
		ui.myReady,
		ui.theirReady,
		ui.myOfferList,
		ui.theirOfferList,
		ui.acceptButton,
		ui.cancelButton,
	}
	for _, object in ipairs(required) do
		if not object then
			return false
		end
	end

	rememberButtonColor(ui.setGemsButton)
	rememberButtonColor(ui.acceptButton)
	rememberButtonColor(ui.cancelButton)
	ui.acceptButton.Activated:Connect(function()
		invoke("Accept")
	end)
	ui.cancelButton.Activated:Connect(function()
		invoke("Cancel")
	end)
	ui.setGemsButton.Activated:Connect(function()
		invoke("SetGems", { Amount = tonumber(ui.gemBox.Text) or 0 })
	end)
	return true
end

local function setReadyBadge(label, accepted)
	if not label then
		return
	end
	if accepted then
		label.Text = "READY"
		label.TextColor3 = THEME.White
		label.BackgroundColor3 = THEME.Green
	else
		label.Text = "NOT READY"
		label.TextColor3 = THEME.Muted
		label.BackgroundColor3 = Color3.fromRGB(230, 236, 246)
	end
end

local function setOfferStroke(panel, accepted)
	local panelStroke = panel and panel:FindFirstChildOfClass("UIStroke")
	if panelStroke then
		panelStroke.Color = accepted and THEME.Green or Color3.fromRGB(206, 218, 235)
		panelStroke.Thickness = accepted and 3 or 1
	end
end

render = function()
	if not ui.root then
		return
	end

	local session = state.Session
	local message = tostring(state.Message or "")
	if message ~= "" then
		setText(ui.status, message)
	elseif session then
		setText(ui.status, "Trading with " .. tostring(session.OtherName or "Player"))
	else
		setText(ui.status, "Choose a player to trade Colors and Gems.")
	end
	setText(ui.gemsOwned, "Gems: " .. tostring(state.Gems or 0))
	setText(ui.offerHint, session and "Add colors, set gems, then ready up." or "Start a trade to build an offer.")

	clearList(ui.playersList)
	for _, other in ipairs(state.Players or {}) do
		makePlayerRow(ui.playersList, other, session)
	end
	if #(state.Players or {}) == 0 then
		makeEmptyState(ui.playersList, "No other players online.")
	end

	clearList(ui.colorsList)
	for _, color in ipairs(state.Colors or {}) do
		local meta = "Tradeable"
		local metaColor = THEME.GreenDark
		if color.Locked then
			meta = "Locked"
			metaColor = THEME.Pink
		elseif color.Equipped then
			meta = "Equipped"
			metaColor = THEME.Muted
		end
		local name = tostring(color.Name or color.Id or "Color")
		makeRow(
			ui.colorsList,
			name,
			"ADD",
			function()
				invoke("AddColor", { ColorId = color.Id })
			end,
			not session or color.Tradeable ~= true,
			{
				iconText = getInitials(name, "CO"),
				iconColor = color.Tradeable == true and THEME.Cyan or THEME.Disabled,
				meta = meta,
				metaColor = metaColor,
				buttonWidth = 60,
				buttonColor = THEME.Green,
				height = 48,
			}
		)
	end
	if #(state.Colors or {}) == 0 then
		makeEmptyState(ui.colorsList, "No Colors to trade.")
	end

	local myOffer = session and session.MyOffer or { Gems = 0, Colors = {} }
	local theirOffer = session and session.TheirOffer or { Gems = 0, Colors = {} }
	local myAccepted = session and session.MyAccepted == true
	local theirAccepted = session and session.TheirAccepted == true

	setText(ui.myName, "YOU")
	setText(ui.theirName, session and tostring(session.OtherName or "THEM") or "THEM")
	setReadyBadge(ui.myReady, myAccepted)
	setReadyBadge(ui.theirReady, theirAccepted)
	setOfferStroke(ui.myOfferPanel, myAccepted)
	setOfferStroke(ui.theirOfferPanel, theirAccepted)

	clearList(ui.myOfferList)
	clearList(ui.theirOfferList)
	makeGemOfferRow(ui.myOfferList, myOffer.Gems or 0)
	makeGemOfferRow(ui.theirOfferList, theirOffer.Gems or 0)
	for _, color in ipairs(myOffer.Colors or {}) do
		makeOfferColorRow(ui.myOfferList, color, true)
	end
	for _, color in ipairs(theirOffer.Colors or {}) do
		makeOfferColorRow(ui.theirOfferList, color, false)
	end
	if #(myOffer.Colors or {}) == 0 then
		makeEmptyState(ui.myOfferList, "No colors added.")
	end
	if #(theirOffer.Colors or {}) == 0 then
		makeEmptyState(ui.theirOfferList, "No colors added.")
	end

	setText(ui.acceptButton, myAccepted and "READY" or "READY!")
	setButtonEnabled(ui.acceptButton, session ~= nil and not myAccepted)
	setButtonEnabled(ui.cancelButton, session ~= nil)
	setButtonEnabled(ui.setGemsButton, session ~= nil)
end

if not bindUi() then
	return
end
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
