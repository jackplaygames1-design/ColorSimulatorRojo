-- Disabled: no shop cards should be created at runtime.
if true then
	return
end

-- Populates the editable Studio ShopWindow with real gamepasses/dev products.
-- This does not create a duplicate shop window. It only fills the existing editable window.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local RobuxShopConfig = require(ReplicatedStorage:WaitForChild("RobuxShopConfig"))

local COLORS = {
	Outline = Color3.fromRGB(35, 38, 45),
	Card = Color3.fromRGB(255, 255, 255),
	Panel = Color3.fromRGB(244, 248, 252),
	Text = Color3.fromRGB(38, 36, 52),
	Muted = Color3.fromRGB(92, 98, 116),
	Accent = Color3.fromRGB(82, 219, 225),
	Green = Color3.fromRGB(84, 225, 112),
	Disabled = Color3.fromRGB(170, 178, 194),
}

local function findMainHUD()
	local root = playerGui:WaitForChild("ClientUIRoot", 30)
	return root and root:WaitForChild("MainHUD", 30)
end

local function findWindows(mainHUD)
	local modalWindows = mainHUD and mainHUD:FindFirstChild("ModalWindows")
	if modalWindows and modalWindows:FindFirstChild("Windows") then
		return modalWindows.Windows
	end
	return mainHUD and mainHUD:FindFirstChild("Windows")
end

local function corner(obj, radius)
	local c = obj:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 16)
	c.Parent = obj
	return c
end

local function stroke(obj, thickness, color)
	local s = obj:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	s.Thickness = thickness or 2
	s.Color = color or COLORS.Outline
	s.Parent = obj
	return s
end

local function clearGenerated(container)
	for _, child in ipairs(container:GetChildren()) do
		if child:GetAttribute("EditableShopGenerated") == true then
			child:Destroy()
		end
	end
end

local function label(parent, name, text, pos, size, textSize, color)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Text = text or ""
	l.Position = pos
	l.Size = size
	l.Font = Enum.Font.GothamBold
	l.TextSize = textSize or 14
	l.TextColor3 = color or COLORS.Text
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.TextWrapped = true
	l.Parent = parent
	return l
end

local function makeButton(parent, name, text, pos, size, bg)
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = text
	b.Position = pos
	b.Size = size
	b.BackgroundColor3 = bg or COLORS.Green
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBlack
	b.TextColor3 = Color3.fromRGB(255, 255, 255)
	b.TextStrokeTransparency = 0
	b.TextStrokeColor3 = COLORS.Outline
	b.TextScaled = true
	b.Parent = parent
	corner(b, 12)
	stroke(b, 2)
	return b
end

local function getContent(shopWindow)
	return shopWindow:FindFirstChild("Content", true) or shopWindow:FindFirstChild("Body", true) or shopWindow
end

local function getTabs(shopWindow)
	return shopWindow:FindFirstChild("Tabs", true)
end

local function setTabVisual(tabs, activeName)
	if not tabs then return end
	for _, tab in ipairs(tabs:GetDescendants()) do
		if tab:IsA("TextButton") then
			local isActive = string.lower(tab.Name):find(string.lower(activeName)) or string.lower(tab.Text):find(string.lower(activeName))
			tab.BackgroundColor3 = isActive and COLORS.Accent or Color3.fromRGB(232, 238, 248)
			tab.TextColor3 = isActive and Color3.fromRGB(255,255,255) or COLORS.Text
		end
	end
end

local function ownsPass(gamepassId)
	if not gamepassId or tonumber(gamepassId) == 0 then
		return false
	end
	local ok, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, tonumber(gamepassId))
	end)
	return ok and result == true
end

local function makeShopCard(parent, item, index, kind)
	local width = 220
	local height = 126
	local col = (index - 1) % 3
	local row = math.floor((index - 1) / 3)

	local card = Instance.new("Frame")
	card.Name = tostring(item.id or item.displayName or kind) .. "Card"
	card:SetAttribute("EditableShopGenerated", true)
	card.Position = UDim2.fromOffset(14 + col * 238, 14 + row * 140)
	card.Size = UDim2.fromOffset(width, height)
	card.BackgroundColor3 = COLORS.Card
	card.BorderSizePixel = 0
	card.Parent = parent
	corner(card, 18)
	stroke(card, 3)

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.Position = UDim2.fromOffset(10, 12)
	icon.Size = UDim2.fromOffset(58, 58)
	icon.BackgroundColor3 = item.color or Color3.fromRGB(225, 244, 255)
	icon.BorderSizePixel = 0
	icon.Image = tostring(item.iconImage or "")
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Parent = card
	corner(icon, 14)
	stroke(icon, 2)

	if icon.Image == "" then
		local iconText = label(icon, "IconText", tostring(item.icon or "?"), UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 15, COLORS.Text)
		iconText.TextXAlignment = Enum.TextXAlignment.Center
		iconText.Font = Enum.Font.GothamBlack
	end

	label(card, "Name", tostring(item.displayName or item.id or "Item"), UDim2.fromOffset(78, 8), UDim2.new(1, -88, 0, 28), 16, COLORS.Text).Font = Enum.Font.GothamBlack
	label(card, "Description", tostring(item.description or ""), UDim2.fromOffset(78, 38), UDim2.new(1, -88, 0, 34), 11, COLORS.Muted)

	local owned = kind == "Gamepass" and ownsPass(item.gamepassId)
	local hasRealId = kind == "Gamepass" and tonumber(item.gamepassId) and tonumber(item.gamepassId) > 0
		or kind == "Product" and tonumber(item.productId) and tonumber(item.productId) > 0
	local buttonText = owned and "OWNED" or (hasRealId and ("BUY " .. tostring(item.price or "")) or "SET ID")
	local buy = makeButton(card, "BuyButton", buttonText, UDim2.new(1, -112, 1, -42), UDim2.fromOffset(98, 32), owned and COLORS.Disabled or (hasRealId and COLORS.Green or COLORS.Disabled))
	buy.AutoButtonColor = hasRealId and not owned

	buy.MouseButton1Click:Connect(function()
		if owned then return end
		if kind == "Gamepass" then
			if hasRealId then
				MarketplaceService:PromptGamePassPurchase(player, tonumber(item.gamepassId))
			else
				warn("Missing gamepassId for", item.id)
			end
		elseif kind == "Product" then
			if hasRealId then
				MarketplaceService:PromptProductPurchase(player, tonumber(item.productId))
			else
				warn("Missing productId for", item.id)
			end
		end
	end)
end

local function renderGamepasses(content)
	clearGenerated(content)
	local passes = RobuxShopConfig.getSortedGamepasses()
	if #passes == 0 then
		label(content, "NoGamepassesLabel", "No gamepasses configured yet.", UDim2.fromScale(0.05, 0.40), UDim2.fromScale(0.90, 0.12), 22, COLORS.Muted).TextXAlignment = Enum.TextXAlignment.Center
		return
	end
	for i, pass in ipairs(passes) do
		makeShopCard(content, pass, i, "Gamepass")
	end
end

local function renderProducts(content, tabName)
	clearGenerated(content)
	local products = RobuxShopConfig.getSortedDevProducts()
	if #products == 0 then
		label(content, "ComingSoonLabel", tabName .. " coming soon. Product IDs are not set yet.", UDim2.fromScale(0.05, 0.40), UDim2.fromScale(0.90, 0.12), 22, COLORS.Muted).TextXAlignment = Enum.TextXAlignment.Center
		return
	end
	for i, product in ipairs(products) do
		makeShopCard(content, product, i, "Product")
	end
end

local function hookTabs(shopWindow, content)
	local tabs = getTabs(shopWindow)
	local function show(tabName)
		setTabVisual(tabs, tabName)
		if tabName == "Gamepasses" then
			renderGamepasses(content)
		else
			renderProducts(content, tabName)
		end
	end

	if tabs then
		for _, tab in ipairs(tabs:GetDescendants()) do
			if tab:IsA("TextButton") then
				local lowered = string.lower(tab.Text .. " " .. tab.Name)
				tab.MouseButton1Click:Connect(function()
					local tabName = "Gamepasses"
					if not lowered:find("gamepass") then
						if lowered:find("potion") then
							tabName = "Potions"
						elseif lowered:find("currency") then
							tabName = "Currency"
						elseif lowered:find("bundle") then
							tabName = "Bundles"
						end
					end
					show(tabName)
				end)
			end
		end
	end

	show("Gamepasses")
end

local mainHUD = findMainHUD()
local windows = mainHUD and findWindows(mainHUD)
local shopWindow = windows and windows:WaitForChild("ShopWindow", 30)
if shopWindow then
	hookTabs(shopWindow, getContent(shopWindow))
else
	warn("EditableShopBinder: ShopWindow missing; no runtime shop window will be created.")
end
