-- Binds editable BrushShopWindow cards to server-owned paint tool purchases.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ClientUIRoot = require(ReplicatedStorage:WaitForChild("ClientUIRoot"))
local ColorData = require(ReplicatedStorage:WaitForChild("ColorData"))
local ToolData = require(ReplicatedStorage:WaitForChild("ToolData"))
local Events = ReplicatedStorage:WaitForChild("Events")
local purchaseEvent = Events:WaitForChild("PurchasePaintTool")
local equipEvent = Events:WaitForChild("EquipPaintTool")

local mainHud = ClientUIRoot.GetRoot(playerGui)
local modalRoot = mainHud and mainHud:WaitForChild("ModalWindows", 10)
local windowsFolder = modalRoot and (modalRoot:FindFirstChild("Windows") or modalRoot)

if not windowsFolder then
	warn("EditableBrushShopBinder: missing PlayerGui.MainHUD.ModalWindows")
	return
end

local window = windowsFolder:FindFirstChild("BrushShopWindow")
if not window or not window:IsA("GuiObject") then
	warn("EditableBrushShopBinder: missing PlayerGui.MainHUD.ModalWindows.BrushShopWindow")
	return
end

local content = window:FindFirstChild("Content")
local grid = content and content:FindFirstChild("ToolGrid")
if not grid or not grid:IsA("GuiObject") then
	warn(
		"EditableBrushShopBinder: BrushShopWindow.Content.ToolGrid is missing. Run StudioMenuWindowsBuilder.UpdateZorkWindows() in edit mode."
	)
	return
end

if not grid:IsA("ScrollingFrame") then
	warn(
		"EditableBrushShopBinder: BrushShopWindow.Content.ToolGrid should be a Studio-authored ScrollingFrame. Run StudioMenuWindowsBuilder.UpdateZorkWindows() in edit mode."
	)
end

local template = grid and grid:FindFirstChild("ToolCardTemplate")
if not template or not template:IsA("GuiObject") then
	warn("EditableBrushShopBinder: BrushShopWindow.Content.ToolGrid.ToolCardTemplate is missing.")
	return
end

template.Visible = false

local ownedValue
local equippedValue
local activeShopColor = nil
local cardsByToolId = {}
local reusableCards = {}

local function csvSet(value)
	local set = {}
	for _, part in ipairs(string.split(value or "", ",")) do
		if part ~= "" then
			set[part] = true
		end
	end
	set.StarterBrush = true
	return set
end

local function setText(parent, name, value)
	local instance = parent:FindFirstChild(name, true)
	if instance and (instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox")) then
		instance.Text = value
	end
	return instance
end

local function setButton(card, tool)
	local button = card:FindFirstChild("BuyButton", true)
	if not button or not button:IsA("GuiButton") then
		return
	end

	if button:GetAttribute("BrushShopBound") ~= true then
		button:SetAttribute("BrushShopBound", true)
		button.Activated:Connect(function()
			local toolId = button:GetAttribute("ToolId")
			if not toolId then
				return
			end
			local owned = csvSet(ownedValue and ownedValue.Value or "")
			if owned[toolId] then
				equipEvent:FireServer(toolId, not (equippedValue and equippedValue.Value == toolId))
			else
				purchaseEvent:FireServer(toolId)
			end
		end)
	end

	button:SetAttribute("ToolId", tool.Id)
end

local function normalizeShopColor(colorType)
	colorType = tostring(colorType or "")
	if colorType == "" then
		return nil
	end

	local world = ColorData.getWorldByColor and ColorData.getWorldByColor(colorType)
	if world and world.primaryColor then
		return world.primaryColor
	end

	for _, worldData in ipairs(ColorData.Worlds or {}) do
		if
			colorType == worldData.id
			or colorType == worldData.ZoneId
			or colorType == worldData.DisplayName
			or colorType == worldData.name
		then
			return worldData.primaryColor or worldData.id
		end
	end

	return colorType
end

local function getCurrentWorldColor()
	local storage = player:FindFirstChild("ColorStorage")
	local currentWorld = storage and storage:FindFirstChild("CurrentWorld")
	if currentWorld and currentWorld:IsA("StringValue") then
		return normalizeShopColor(currentWorld.Value)
	end
	return nil
end

local function getActiveShopColor()
	return normalizeShopColor(mainHud:GetAttribute("ActiveBrushShopColor"))
		or normalizeShopColor(player:GetAttribute("ActiveWorldColor"))
		or getCurrentWorldColor()
		or "Red"
end

local function setShopCopy(colorType)
	local world = ColorData.getWorldByColor and ColorData.getWorldByColor(colorType)
	local displayName = (world and (world.DisplayName or world.name)) or tostring(colorType or "Sector")
	setText(content, "IntroText", displayName .. " brushes. Buy once, then equip or unequip.")
end

local function collectReusableCards()
	table.clear(reusableCards)
	for _, child in ipairs(grid:GetChildren()) do
		if child:IsA("GuiObject") and child ~= template then
			if child:GetAttribute("BrushShopStudioCard") == true or string.find(child.Name, "Card", 1, true) then
				table.insert(reusableCards, child)
			end
		end
	end
	table.sort(reusableCards, function(a, b)
		return (a.LayoutOrder or 0) < (b.LayoutOrder or 0)
	end)
end

local function updateCard(card, tool)
	local owned = csvSet(ownedValue and ownedValue.Value or "")
	local equipped = equippedValue and equippedValue.Value == tool.Id
	local isOwned = owned[tool.Id] == true

	setText(card, "Name", tool.DisplayName)
	setText(card, "Description", tool.Description or tool.PassiveDescription or "")
	setText(
		card,
		"Stats",
		string.format("Power x%.2f  Range %d", tonumber(tool.PowerMultiplier) or 1, tonumber(tool.Range) or 0)
	)
	setText(card, "Price", tool.Cost == 0 and "FREE" or tostring(tool.Cost) .. " Coins")
	setText(card, "Status", equipped and "EQUIPPED" or (isOwned and "OWNED" or tool.Rarity or "Brush"))
	setText(card, "IconText", tool.ShortName or string.sub(tool.DisplayName, 1, 2):upper())

	local buyButton = card:FindFirstChild("BuyButton", true)
	if buyButton and buyButton:IsA("TextButton") then
		if equipped then
			buyButton.Text = "UNEQUIP"
		elseif isOwned then
			buyButton.Text = "EQUIP"
		elseif tool.Cost == 0 then
			buyButton.Text = "CLAIM"
		else
			buyButton.Text = "BUY"
		end
	end

	local stroke = card:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = equipped and Color3.fromRGB(84, 225, 112) or Color3.fromRGB(35, 38, 45)
		stroke.Thickness = equipped and 4 or 2
	end
end

local function getShopBrushes()
	return ToolData.GetBrushesForWorldColor(activeShopColor or getActiveShopColor())
end

local function render()
	activeShopColor = getActiveShopColor()
	table.clear(cardsByToolId)
	collectReusableCards()
	setShopCopy(activeShopColor)

	for _, card in ipairs(reusableCards) do
		card.Visible = false
		card:SetAttribute("ToolId", nil)
	end

	for index, tool in ipairs(getShopBrushes()) do
		local card = reusableCards[index]
		if not card or not card:IsA("GuiObject") then
			warn(
				"EditableBrushShopBinder: not enough Studio-authored brush cards for "
					.. tool.Id
					.. ". Run StudioMenuWindowsBuilder.UpdateZorkWindows() in edit mode."
			)
			continue
		end

		card:SetAttribute("ToolId", tool.Id)
		card.LayoutOrder = index
		card.Visible = true
		setButton(card, tool)
		updateCard(card, tool)
		cardsByToolId[tool.Id] = card
	end
end

local function refresh()
	if not ownedValue or not equippedValue then
		return
	end
	local nextColor = getActiveShopColor()
	if nextColor ~= activeShopColor then
		render()
		return
	end
	for _, tool in ipairs(getShopBrushes()) do
		local card = cardsByToolId[tool.Id]
		if card then
			updateCard(card, tool)
		end
	end
end

local function hookPaintTools()
	local folder = player:WaitForChild("PaintTools", 20)
	if not folder then
		return
	end
	ownedValue = folder:WaitForChild("Owned", 10)
	equippedValue = folder:WaitForChild("Equipped", 10)
	if ownedValue then
		ownedValue:GetPropertyChangedSignal("Value"):Connect(refresh)
	end
	if equippedValue then
		equippedValue:GetPropertyChangedSignal("Value"):Connect(refresh)
	end
	refresh()
end

purchaseEvent.OnClientEvent:Connect(refresh)
equipEvent.OnClientEvent:Connect(refresh)
mainHud:GetAttributeChangedSignal("ActiveBrushShopColor"):Connect(render)
player:GetAttributeChangedSignal("ActiveWorldColor"):Connect(render)

render()
task.spawn(hookPaintTools)

print("[EditableBrushShopBinder] sector-aware BrushShopWindow ready.")
