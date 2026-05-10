-- Binder only for the editable Studio-built Sectors/Worlds window.
-- IMPORTANT: this script does NOT create cards/windows at runtime.
-- It only shows/hides existing Studio UI and wires existing cards to travel.
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
	Locked = Color3.fromRGB(180, 187, 200),
}

local function findMainHUD()
	local root = playerGui:WaitForChild("ClientUIRoot", 20)
	return root and root:WaitForChild("MainHUD", 20)
end

local mainHUD = findMainHUD()
local modalWindows = mainHUD and mainHUD:WaitForChild("ModalWindows", 20)
local windowsFolder = modalWindows and modalWindows:WaitForChild("Windows", 20)
local worldsWindow = windowsFolder and windowsFolder:WaitForChild("WorldsWindow", 20)
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

local function setTextNamed(name, text)
	setText(find(name), text)
end

local function show(obj, visible)
	if obj and obj:IsA("GuiObject") then
		obj.Visible = visible
	end
end

local function styleTabs()
	local worldsTab = find("WorldsTab")
	local zonesTab = find("ZonesTab")
	if worldsTab and worldsTab:IsA("GuiObject") then
		worldsTab.BackgroundColor3 = currentPage == "Worlds" and COLORS.Accent or COLORS.Off
		setText(worldsTab, "Worlds")
	end
	if zonesTab and zonesTab:IsA("GuiObject") then
		zonesTab.BackgroundColor3 = currentPage == "Zones" and COLORS.Accent or COLORS.Off
		setText(zonesTab, "Zones")
	end
end

local function showPage(page)
	currentPage = page
	local pages = find("Pages")
	show(pages and pages:FindFirstChild("WorldsPage"), page == "Worlds")
	show(pages and pages:FindFirstChild("ZonesPage"), page == "Zones")
	styleTabs()
end

local function setPreviewCard(card, sectorId)
	if not card then return end
	card:SetAttribute("LocationId", sectorId)
	card:SetAttribute("PreviewOnly", false)

	local title = card:FindFirstChild("LocationTitle", true)
	local desc = card:FindFirstChild("Description", true)
	local status = card:FindFirstChild("StatusPill", true)
	local thumb = card:FindFirstChild("Thumbnail", true)
	local imageText = card:FindFirstChild("ImageText", true)
	local price = card:FindFirstChild("PriceText", true)

	if sectorId == "OriginSector" then
		setText(title, "Origin Sector")
		setText(desc, "The starting sector. Contains the Red Wastelands.")
		setText(status, "CURRENT")
		if status then status.BackgroundColor3 = COLORS.Green end
		if thumb then thumb.BackgroundColor3 = COLORS.Red end
		setText(imageText, "IMAGE")
		show(price, false)
	else
		setText(title, "Orange Sector")
		setText(desc, "Contains Inside the Pipes. Unlock mutations here.")
		setText(status, "15K COINS")
		if status then status.BackgroundColor3 = COLORS.Red end
		if thumb then thumb.BackgroundColor3 = COLORS.Orange end
		setText(imageText, "ORANGE")
		show(price, true)
		setText(price, "Cost: 15,000 Coins")
	end
end

local function renderWorlds()
	showPage("Worlds")
	setPreviewCard(find("OriginSectorCard"), currentPreview)
	local arrow = find("NextSectorButton")
	setText(arrow, currentPreview == "OriginSector" and "›" or "‹")
end

local function renderZones()
	showPage("Zones")
	local originZones = find("OriginZones")
	local orangeZones = find("OrangeZones")
	local header = find("ZonesPageHeader")

	if currentPreview == "OrangeSector" then
		show(originZones, false)
		show(orangeZones, true)
		setText(header, "Zones in Orange Sector")
	else
		show(originZones, true)
		show(orangeZones, false)
		setText(header, "Zones in Origin Sector")
	end
end

local function render()
	if currentPage == "Zones" then
		renderZones()
	else
		renderWorlds()
	end
end

local hooked = {}
local function hookButton(button, callback)
	if not button or not button:IsA("GuiButton") or hooked[button] then return end
	hooked[button] = true
	button.MouseButton1Click:Connect(callback)
end

hookButton(find("WorldsTab"), function()
	currentPage = "Worlds"
	render()
end)

hookButton(find("ZonesTab"), function()
	currentPage = "Zones"
	render()
end)

hookButton(find("NextSectorButton"), function()
	currentPreview = currentPreview == "OriginSector" and "OrangeSector" or "OriginSector"
	render()
end)

hookButton(find("PreviousSectorButton"), function()
	currentPreview = currentPreview == "OriginSector" and "OrangeSector" or "OriginSector"
	render()
end)

hookButton(find("OriginSectorCard"), function()
	requestTravel:FireServer(currentPreview)
end)

for _, name in ipairs({ "RedWastelandsZoneCard", "ZorkShopZoneCard", "InsidePipesZoneCard" }) do
	local card = find(name)
	if card and card:IsA("GuiButton") then
		hookButton(card, function()
			local locationId = card:GetAttribute("LocationId")
			if type(locationId) == "string" and locationId ~= "" then
				requestTravel:FireServer(locationId)
			end
		end)
	end
end

worldsWindow:GetPropertyChangedSignal("Visible"):Connect(function()
	if worldsWindow.Visible then
		currentPage = "Worlds"
		render()
	end
end)

render()
print("WorldsWindowBinder: editable-only binder active")

if travelResult then
	travelResult.OnClientEvent:Connect(function(result)
		if type(result) ~= "table" then return end
		if result.Success then
			print("Travel success:", result.Message or result.LocationId)
		else
			warn("Travel failed:", result.Message or result.LocationId)
		end
	end)
end
