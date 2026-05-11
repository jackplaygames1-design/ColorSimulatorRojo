-- Binds editable BrushShopWindow cards to server-owned paint tool purchases.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ToolData = require(ReplicatedStorage:WaitForChild("ToolData"))
local Events = ReplicatedStorage:WaitForChild("Events")
local purchaseEvent = Events:WaitForChild("PurchasePaintTool")
local equipEvent = Events:WaitForChild("EquipPaintTool")

local root = playerGui:WaitForChild("ClientUIRoot", 15)
local mainHud = root and root:WaitForChild("MainHUD", 15)
local windowsFolder = mainHud
	and mainHud:WaitForChild("ModalWindows", 10)
	and mainHud.ModalWindows:WaitForChild("Windows", 10)

if not windowsFolder then
	warn("EditableBrushShopBinder: missing editable windows folder")
	return
end

local window = windowsFolder:FindFirstChild("BrushShopWindow")
if not window or not window:IsA("GuiObject") then
	warn("EditableBrushShopBinder: add editable BrushShopWindow with StudioMenuWindowsBuilder.")
	return
end

local content = window:FindFirstChild("Content")
local grid = content and (content:FindFirstChild("ToolGrid") or content)
local template = grid and grid:FindFirstChild("ToolCardTemplate")
if not template or not template:IsA("GuiObject") then
	warn("EditableBrushShopBinder: BrushShopWindow.Content.ToolGrid.ToolCardTemplate is missing.")
	return
end

template.Visible = false

local ownedValue
local equippedValue
local cardsByToolId = {}

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

local function getFirstSectorBrushes()
	local result = {}
	for _, tool in ipairs(ToolData.GetOrderedBrushes()) do
		if tool.RequiredColor == "Red" then
			table.insert(result, tool)
		end
	end
	return result
end

local function render()
	for _, child in ipairs(grid:GetChildren()) do
		if child:IsA("GuiObject") and child ~= template and child:GetAttribute("BrushShopRuntimeCard") == true then
			child:Destroy()
		end
	end
	table.clear(cardsByToolId)

	for index, tool in ipairs(getFirstSectorBrushes()) do
		local card = template:Clone()
		card.Name = tool.Id .. "Card"
		card:SetAttribute("BrushShopRuntimeCard", true)
		card:SetAttribute("ToolId", tool.Id)
		card.LayoutOrder = index
		card.Visible = true
		card.Parent = grid
		setButton(card, tool)
		cardsByToolId[tool.Id] = card
	end
end

local function refresh()
	if not ownedValue or not equippedValue then
		return
	end
	for _, tool in ipairs(getFirstSectorBrushes()) do
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

render()
task.spawn(hookPaintTools)

print("[EditableBrushShopBinder] first-sector BrushShopWindow ready.")
