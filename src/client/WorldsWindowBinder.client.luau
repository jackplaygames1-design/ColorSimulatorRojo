-- Binds the editable StarterGui/Studio-built WorldsWindow to server-authoritative travel.
-- This script does not create duplicate runtime windows; it only connects existing cards/buttons.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Events = ReplicatedStorage:WaitForChild("Events")
local requestTravel = Events:WaitForChild("RequestTravelToLocation")
local travelResult = Events:FindFirstChild("TravelToLocationResult")

local LOCATION_ALIASES = {
	SpawnWorldCard = "SpawnWorld",
	RedWastelandsCard = "RedWastelands",
	InsidePipesCard = "InsidePipes",
	OrangeSectorCard = "OrangeSector",
	FutureSectorCard = "FutureSector",
	RedWastelandsZoneCard = "RedWastelands",
	InsidePipesZoneCard = "InsidePipes",
	OrangeSectorZoneCard = "OrangeSector",
}

local LOCKED_LOCATIONS = {
	FutureSector = true,
}

local function findMainHUD()
	local root = playerGui:WaitForChild("ClientUIRoot", 20)
	if not root then
		warn("WorldsWindowBinder: ClientUIRoot missing")
		return nil
	end
	return root:WaitForChild("MainHUD", 20)
end

local function findWindows(mainHUD)
	local modalWindows = mainHUD:FindFirstChild("ModalWindows")
	if modalWindows then
		local windows = modalWindows:FindFirstChild("Windows")
		if windows then
			return windows
		end
	end
	return mainHUD:FindFirstChild("Windows")
end

local function styleTab(tab, active)
	if not tab or not tab:IsA("GuiObject") then
		return
	end
	tab.BackgroundColor3 = active and Color3.fromRGB(88, 224, 235) or Color3.fromRGB(230, 235, 243)
	if tab:IsA("TextButton") or tab:IsA("TextLabel") then
		tab.TextColor3 = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(31, 34, 45)
	end
end

local function setPages(worldsWindow, activePageName)
	local body = worldsWindow:FindFirstChild("Body") or worldsWindow:FindFirstChild("Content")
	local tabs = body and body:FindFirstChild("Tabs")
	local pages = body and body:FindFirstChild("Pages")
	local worldsTab = tabs and tabs:FindFirstChild("WorldsTab")
	local zonesTab = tabs and tabs:FindFirstChild("ZonesTab")
	local teleportTab = tabs and tabs:FindFirstChild("TeleportTab")

	if teleportTab and teleportTab:IsA("GuiObject") then
		teleportTab.Visible = false
	end

	styleTab(worldsTab, activePageName == "Worlds")
	styleTab(zonesTab, activePageName == "Zones")

	if pages then
		local worldsPage = pages:FindFirstChild("WorldsPage")
		local zonesPage = pages:FindFirstChild("ZonesPage")
		if worldsPage and worldsPage:IsA("GuiObject") then
			worldsPage.Visible = activePageName == "Worlds"
		end
		if zonesPage and zonesPage:IsA("GuiObject") then
			zonesPage.Visible = activePageName == "Zones"
		end
	end
end

local function setStatusText(card, text)
	local status = card:FindFirstChild("StatusPill", true)
	if status and (status:IsA("TextLabel") or status:IsA("TextButton")) then
		status.Text = text
	end
end

local function getLocationId(card)
	local attr = card:GetAttribute("LocationId")
	if type(attr) == "string" and attr ~= "" then
		return attr
	end
	return LOCATION_ALIASES[card.Name]
end

local function isLocked(card, locationId)
	if card:GetAttribute("Locked") == true then
		return true
	end
	return LOCKED_LOCATIONS[locationId] == true
end

local hookedCards = {}
local function hookTravelCard(card)
	if hookedCards[card] or not card:IsA("GuiButton") then
		return
	end

	local locationId = getLocationId(card)
	if not locationId then
		return
	end

	hookedCards[card] = true
	card:SetAttribute("LocationId", locationId)

	if isLocked(card, locationId) then
		card:SetAttribute("Locked", true)
		setStatusText(card, "LOCKED")
		card.AutoButtonColor = false
	else
		card.AutoButtonColor = true
	end

	-- Old versions had small Teleport buttons inside cards. Hide their label if present;
	-- the whole card is the travel target now.
	for _, child in ipairs(card:GetDescendants()) do
		if child:IsA("TextButton") and string.lower(child.Name):find("teleport") then
			child.Visible = false
		end
	end

	card.MouseButton1Click:Connect(function()
		if isLocked(card, locationId) then
			warn("WorldsWindow: location locked", locationId)
			return
		end
		requestTravel:FireServer(locationId)
	end)
end

local function hookAll(worldsWindow)
	local body = worldsWindow:FindFirstChild("Body") or worldsWindow:FindFirstChild("Content")
	local tabs = body and body:FindFirstChild("Tabs")
	local worldsTab = tabs and tabs:FindFirstChild("WorldsTab")
	local zonesTab = tabs and tabs:FindFirstChild("ZonesTab")

	if worldsTab and worldsTab:IsA("GuiButton") then
		worldsTab.MouseButton1Click:Connect(function()
			setPages(worldsWindow, "Worlds")
		end)
	end
	if zonesTab and zonesTab:IsA("GuiButton") then
		zonesTab.MouseButton1Click:Connect(function()
			setPages(worldsWindow, "Zones")
		end)
	end

	-- Remove old teleport tab behavior visually.
	setPages(worldsWindow, "Worlds")

	for _, obj in ipairs(worldsWindow:GetDescendants()) do
		if obj:IsA("GuiButton") then
			hookTravelCard(obj)
		end
	end

	worldsWindow.DescendantAdded:Connect(function(obj)
		if obj:IsA("GuiButton") then
			task.defer(hookTravelCard, obj)
		end
	end)
end

local mainHUD = findMainHUD()
if mainHUD then
	local windows = findWindows(mainHUD)
	local worldsWindow = windows and windows:WaitForChild("WorldsWindow", 20)
	if worldsWindow then
		hookAll(worldsWindow)
	else
		warn("WorldsWindowBinder: WorldsWindow missing; no runtime UI will be created.")
	end
end

if travelResult then
	travelResult.OnClientEvent:Connect(function(result)
		if type(result) ~= "table" then
			return
		end
		if result.Success then
			print("Travel success:", result.Message or result.LocationId)
		else
			warn("Travel failed:", result.Message or result.LocationId)
		end
	end)
end
