-- Single controller for the editable Sectors/Worlds window.
-- Uses the Studio-built WorldsWindow only. Does not create duplicate windows.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Events = ReplicatedStorage:WaitForChild("Events")
local requestTravel = Events:WaitForChild("RequestTravelToLocation")
local travelResult = Events:FindFirstChild("TravelToLocationResult")

local currentPage = "Worlds"
local currentPreview = "OriginSector"

local COLORS = {
	Accent = Color3.fromRGB(88, 224, 235),
	Off = Color3.fromRGB(230, 235, 243),
	Text = Color3.fromRGB(31, 34, 45),
	White = Color3.fromRGB(255, 255, 255),
	Green = Color3.fromRGB(72, 210, 102),
	Red = Color3.fromRGB(245, 76, 76),
	Orange = Color3.fromRGB(245, 151, 35),
	Gold = Color3.fromRGB(255, 198, 64),
	Pipes = Color3.fromRGB(34, 140, 160),
	Card = Color3.fromRGB(247, 249, 252),
	Muted = Color3.fromRGB(112, 118, 132),
	Outline = Color3.fromRGB(30, 34, 44),
}

local function findHud()
	local root = playerGui:WaitForChild("ClientUIRoot", 20)
	return root and root:WaitForChild("MainHUD", 20)
end

local mainHUD = findHud()
local modal = mainHUD and mainHUD:WaitForChild("ModalWindows", 20)
local windows = modal and modal:WaitForChild("Windows", 20)
local worldsWindow = windows and windows:WaitForChild("WorldsWindow", 20)
if not worldsWindow then
	warn("WorldsWindowBinder: WorldsWindow missing")
	return
end

local function find(name)
	return worldsWindow:FindFirstChild(name, true)
end

local function setText(obj, text)
	if obj and (obj:IsA("TextLabel") or obj:IsA("TextButton")) then
		obj.Text = tostring(text or "")
	end
end

local function setVisible(obj, visible)
	if obj and obj:IsA("GuiObject") then
		obj.Visible = visible
	end
end

local function corner(obj, radius)
	local old = obj:FindFirstChildOfClass("UICorner")
	if old then old:Destroy() end
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 16)
	c.Parent = obj
end

local function stroke(obj, thickness, color)
	local old = obj:FindFirstChildOfClass("UIStroke")
	if old then old:Destroy() end
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 2
	s.Color = color or COLORS.Outline
	s.Parent = obj
end

local function label(parent, name, text, pos, size, textSize, color)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Text = text
	l.Position = pos
	l.Size = size
	l.BackgroundTransparency = 1
	l.TextColor3 = color or COLORS.Text
	l.Font = Enum.Font.GothamBlack
	l.TextSize = textSize or 18
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.ZIndex = 80
	l.Parent = parent
	return l
end

local function getPages()
	local body = worldsWindow:FindFirstChild("Body") or worldsWindow:FindFirstChild("Content")
	return body and body:FindFirstChild("Pages")
end

local function showPage(page)
	currentPage = page
	local pages = getPages()
	if not pages then return end
	local worldsPage = pages:FindFirstChild("WorldsPage")
	local zonesPage = pages:FindFirstChild("ZonesPage")
	if worldsPage then worldsPage.Visible = page == "Worlds" end
	if zonesPage then zonesPage.Visible = page == "Zones" end
	local worldsTab = find("WorldsTab")
	local zonesTab = find("ZonesTab")
	if worldsTab and worldsTab:IsA("GuiObject") then worldsTab.BackgroundColor3 = page == "Worlds" and COLORS.Accent or COLORS.Off end
	if zonesTab and zonesTab:IsA("GuiObject") then zonesTab.BackgroundColor3 = page == "Zones" and COLORS.Accent or COLORS.Off end
end

local function renderWorlds()
	local card = find("OriginSectorCard") or find("SpawnWorldCard")
	if not card then return end
	card.Name = "OriginSectorCard"
	card:SetAttribute("LocationId", currentPreview)
	card:SetAttribute("PreviewOnly", false)
	local title = card:FindFirstChild("LocationTitle", true)
	local desc = card:FindFirstChild("Description", true)
	local status = card:FindFirstChild("StatusPill", true)
	local thumb = card:FindFirstChild("Thumbnail", true)
	local img = card:FindFirstChild("ImageText", true)
	local arrow = find("NextSectorButton")
	if currentPreview == "OriginSector" then
		setText(title, "Origin Sector")
		setText(desc, "The starting sector. Contains the Red Wastelands.")
		setText(status, "CURRENT")
		if status then status.BackgroundColor3 = COLORS.Green end
		if thumb then thumb.BackgroundColor3 = COLORS.Red end
		if img then img.Text = "IMAGE" end
		if arrow and arrow:IsA("TextButton") then arrow.Text = "›" end
	else
		setText(title, "Orange Sector")
		setText(desc, "Contains Inside the Pipes. Unlock mutations here. Cost: 15,000 Coins")
		setText(status, "15K COINS")
		if status then status.BackgroundColor3 = COLORS.Red end
		if thumb then thumb.BackgroundColor3 = COLORS.Orange end
		if img then img.Text = "ORANGE" end
		if arrow and arrow:IsA("TextButton") then arrow.Text = "‹" end
	end
end

local function zoneCard(parent, name, locationId, pos, color, title, desc)
	local card = Instance.new("TextButton")
	card.Name = name
	card.Position = pos
	card.Size = UDim2.fromScale(0.46, 0.32)
	card.BackgroundColor3 = COLORS.Card
	card.BorderSizePixel = 0
	card.Text = ""
	card.AutoButtonColor = true
	card.Active = true
	card:SetAttribute("LocationId", locationId)
	card:SetAttribute("Locked", false)
	card.Parent = parent
	corner(card, 20)
	stroke(card, 2, Color3.fromRGB(220, 226, 236))

	local thumb = Instance.new("Frame")
	thumb.Name = "Thumbnail"
	thumb.Position = UDim2.fromScale(0.04, 0.14)
	thumb.Size = UDim2.fromScale(0.27, 0.72)
	thumb.BackgroundColor3 = color
	thumb.BorderSizePixel = 0
	thumb.Parent = card
	corner(thumb, 16)
	stroke(thumb, 2, COLORS.Outline)

	local img = label(thumb, "ImageText", "IMAGE", UDim2.fromScale(0,0), UDim2.fromScale(1,1), 22, COLORS.White)
	img.TextScaled = true
	img.TextXAlignment = Enum.TextXAlignment.Center
	img.TextStrokeTransparency = 0
	img.TextStrokeColor3 = COLORS.Outline

	label(card, "LocationTitle", title, UDim2.fromScale(0.36, 0.14), UDim2.fromScale(0.58, 0.20), 20, COLORS.Text)
	label(card, "Description", desc, UDim2.fromScale(0.36, 0.36), UDim2.fromScale(0.58, 0.26), 14, COLORS.Muted)

	local pill = Instance.new("TextLabel")
	pill.Name = "StatusPill"
	pill.Text = "TELEPORT"
	pill.Position = UDim2.fromScale(0.36, 0.70)
	pill.Size = UDim2.fromScale(0.34, 0.14)
	pill.BackgroundColor3 = COLORS.Green
	pill.TextColor3 = COLORS.White
	pill.Font = Enum.Font.GothamBlack
	pill.TextScaled = true
	pill.BorderSizePixel = 0
	pill.Parent = card
	corner(pill, 999)

	card.MouseButton1Click:Connect(function()
		requestTravel:FireServer(locationId)
		print("WorldsWindowBinder: requested zone travel", locationId)
	end)
end

local function renderZones()
	local pages = getPages()
	local zonesPage = pages and pages:FindFirstChild("ZonesPage")
	if not zonesPage then return end
	for _, child in ipairs(zonesPage:GetChildren()) do child:Destroy() end
	if currentPreview == "OrangeSector" then
		label(zonesPage, "ZonesPageHeader", "Zones in Orange Sector", UDim2.fromScale(0.04, 0.02), UDim2.fromScale(0.70, 0.08), 24, COLORS.Text)
		label(zonesPage, "ZonesInstruction", "Tap a zone to travel there.", UDim2.fromScale(0.04, 0.09), UDim2.fromScale(0.70, 0.06), 16, COLORS.Muted)
		zoneCard(zonesPage, "InsidePipesZoneCard", "InsidePipes", UDim2.fromScale(0.04, 0.22), COLORS.Pipes, "Inside the Pipes", "Orange Sector zone. Unlock mutations here.")
	else
		label(zonesPage, "ZonesPageHeader", "Zones in Origin Sector", UDim2.fromScale(0.04, 0.02), UDim2.fromScale(0.70, 0.08), 24, COLORS.Text)
		label(zonesPage, "ZonesInstruction", "Tap a zone to travel there.", UDim2.fromScale(0.04, 0.09), UDim2.fromScale(0.70, 0.06), 16, COLORS.Muted)
		zoneCard(zonesPage, "RedWastelandsZoneCard", "RedWastelands", UDim2.fromScale(0.04, 0.22), COLORS.Red, "Red Wastelands", "Clean spills and earn coins.")
		zoneCard(zonesPage, "ZorkShopZoneCard", "ZorkShop", UDim2.fromScale(0.52, 0.22), COLORS.Gold, "Zork Shop", "Visit Zork for rewards, shop, and upgrades.")
	end
end

local function render()
	if currentPage == "Zones" then
		showPage("Zones")
		renderZones()
	else
		showPage("Worlds")
		renderWorlds()
	end
end

local worldsTab = find("WorldsTab")
if worldsTab and worldsTab:IsA("GuiButton") then
	worldsTab.MouseButton1Click:Connect(function()
		currentPage = "Worlds"
		render()
	end)
end

local zonesTab = find("ZonesTab")
if zonesTab and zonesTab:IsA("GuiButton") then
	zonesTab.MouseButton1Click:Connect(function()
		currentPage = "Zones"
		render()
	end)
end

local arrow = find("NextSectorButton")
if arrow and arrow:IsA("GuiButton") then
	arrow.MouseButton1Click:Connect(function()
		currentPreview = currentPreview == "OriginSector" and "OrangeSector" or "OriginSector"
		render()
	end)
end

local card = find("OriginSectorCard") or find("SpawnWorldCard")
if card and card:IsA("GuiButton") then
	card.MouseButton1Click:Connect(function()
		requestTravel:FireServer(currentPreview)
	end)
end

worldsWindow:GetPropertyChangedSignal("Visible"):Connect(function()
	if worldsWindow.Visible then
		currentPage = "Worlds"
		render()
	end
end)

render()
print("WorldsWindowBinder: single sectors controller active")

if travelResult then
	travelResult.OnClientEvent:Connect(function(result)
		if type(result) == "table" then
			if result.Success then
				print("Travel success:", result.Message or result.LocationId)
			else
				warn("Travel failed:", result.Message or result.LocationId)
			end
		end
	end)
end
