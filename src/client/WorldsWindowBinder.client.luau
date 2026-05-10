-- Binds the editable StarterGui/Studio-built WorldsWindow to server-authoritative travel.
-- This script does not create duplicate runtime windows; it only connects existing cards/buttons.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Events = ReplicatedStorage:WaitForChild("Events")
local ColorData = require(ReplicatedStorage:WaitForChild("ColorData"))
local requestTravel = Events:WaitForChild("RequestTravelToLocation")
local travelResult = Events:FindFirstChild("TravelToLocationResult")
local tutorialActionEvent = Events:FindFirstChild("TutorialAction")

local LOCATION_ALIASES = {
	OriginSectorCard = "OriginSector",
	SpawnWorldCard = "OriginSector",
	StartSectorCard = "OriginSector",
	RedWastelandsCard = "RedWastelands",
	RedAreaCard = "RedWastelands",
	RedWorldCard = "RedWastelands",
	RedSectorCard = "RedWastelands",
	InsidePipesCard = "InsidePipes",
	InsideThePipesCard = "InsidePipes",
	OrangeSectorCard = "OrangeSector",
	OrangeAreaCard = "OrangeSector",
	OrangeWorldCard = "OrangeSector",
	FutureSectorCard = "FutureSector",
	OriginSectorZoneCard = "OriginSector",
	SpawnWorldZoneCard = "OriginSector",
	StartSectorZoneCard = "OriginSector",
	RedWastelandsZoneCard = "RedWastelands",
	RedAreaZoneCard = "RedWastelands",
	RedWorldZoneCard = "RedWastelands",
	InsidePipesZoneCard = "InsidePipes",
	InsideThePipesZoneCard = "InsidePipes",
	OrangeSectorZoneCard = "OrangeSector",
	OrangeWorldZoneCard = "OrangeSector",
}

local LOCKED_LOCATIONS = {
	FutureSector = true,
}

local PREVIEW_DATA = {
	OriginSector = {
		Title = "Origin Sector",
		Description = "The starting sector, contains the Red Wastelands.",
		Status = "CURRENT",
		NextTitle = "Next: Orange",
		NextDescription = "Contains Inside the Pipes",
		NextStatus = "READY",
	},
	OrangeSector = {
		Title = "Orange Sector",
		Description = "Contains Inside the Pipes.",
		Status = "LOCKED",
		NextTitle = "Back: Origin",
		NextDescription = "Contains the Red Wastelands",
		NextStatus = "BACK",
	},
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

local function formatNumber(value)
	local number = math.floor(tonumber(value) or 0)
	local text = tostring(number)
	while true do
		local nextText, replacements = string.gsub(text, "^(-?%d+)(%d%d%d)", "%1,%2")
		text = nextText
		if replacements == 0 then
			break
		end
	end
	return text
end

local function formatCompactNumber(value)
	local number = tonumber(value) or 0
	if number >= 1000000 then
		return string.format("%.1fM", number / 1000000):gsub("%.0M", "M")
	end
	if number >= 1000 then
		return string.format("%.1fK", number / 1000):gsub("%.0K", "K")
	end
	return tostring(math.floor(number))
end

local function getOrangeCost()
	local orangeWorld = ColorData.getWorldByColor("Orange")
	return orangeWorld and (orangeWorld.UnlockCost or orangeWorld.unlockCost) or 0
end

local function getOrangeCostText(compact)
	local cost = getOrangeCost()
	if compact then
		return string.upper(formatCompactNumber(cost) .. " Coins")
	end
	return formatNumber(cost) .. " Coins"
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

local function cleanWorldTravelText(root)
	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("TextLabel") or obj:IsA("TextButton") then
			if obj.Text == "Spawn World" or obj.Text == "SPAWN WORLD" then
				obj.Text = "Origin Sector"
			elseif obj.Text == "SpawnWorld" or obj.Text == "SPAWNWORLD" then
				obj.Text = "Origin Sector"
			elseif obj.Text == "Red World" or obj.Text == "RED WORLD" then
				obj.Text = "Red Wastelands"
			elseif obj.Text == "Orange World" or obj.Text == "ORANGE WORLD" then
				obj.Text = "Orange Sector"
			elseif obj.Text == "READY" then
				obj.Text = getOrangeCostText(true)
			end
		end
	end
end

local function textScore(textObject)
	return (textObject.TextSize or 0) * 1000 + textObject.AbsoluteSize.X + textObject.AbsoluteSize.Y
end

local function findBestText(root, predicate)
	local best = nil
	local bestScore = -math.huge
	for _, obj in ipairs(root:GetDescendants()) do
		if (obj:IsA("TextLabel") or obj:IsA("TextButton")) and predicate(obj.Text, obj) then
			local score = textScore(obj)
			if score > bestScore then
				best = obj
				bestScore = score
			end
		end
	end
	return best
end

local function findFirstText(root, predicate)
	for _, obj in ipairs(root:GetDescendants()) do
		if (obj:IsA("TextLabel") or obj:IsA("TextButton")) and predicate(obj.Text, obj) then
			return obj
		end
	end
	return nil
end

local function findAncestorWithImage(textObject)
	local current = textObject
	while current and current.Parent do
		local image = current:FindFirstChildWhichIsA("ImageLabel", true) or current:FindFirstChildWhichIsA("ImageButton", true)
		if image then
			return current, image
		end
		current = current.Parent
	end
	return nil, nil
end

local function copyImageProperties(source, target)
	if not source or not target or source == target then
		return
	end
	if source.Image == "" then
		return
	end
	target.Image = source.Image
	target.ImageRectOffset = source.ImageRectOffset
	target.ImageRectSize = source.ImageRectSize
	target.ScaleType = source.ScaleType
	target.ImageColor3 = source.ImageColor3
	target.ImageTransparency = source.ImageTransparency
	target.BackgroundColor3 = source.BackgroundColor3
end

local function copyOrangePreviewImage(worldsWindow)
	local orangeLabel = findFirstText(worldsWindow, function(textValue)
		return textValue == "Next: Orange" or textValue == "Orange Sector" or textValue == "Orange World"
	end)
	local originLabel = findBestText(worldsWindow, function(textValue)
		return textValue == "Origin Sector" or textValue == "Spawn World"
	end)
	if not orangeLabel or not originLabel then
		return
	end

	local _, sourceImage = findAncestorWithImage(orangeLabel)
	local _, targetImage = findAncestorWithImage(originLabel)
	copyImageProperties(sourceImage, targetImage)
end

local function setWorldPreview(worldsWindow, locationId)
	local preview = PREVIEW_DATA[locationId] or PREVIEW_DATA.OriginSector
	local orangeCost = getOrangeCostText(false)
	local orangeCostCompact = getOrangeCostText(true)

	if locationId == "OrangeSector" then
		preview.Description = "Contains Inside the Pipes.\nCost: " .. orangeCost
		preview.Status = orangeCostCompact
		copyOrangePreviewImage(worldsWindow)
	else
		PREVIEW_DATA.OriginSector.NextStatus = orangeCostCompact
	end

	local title = findBestText(worldsWindow, function(textValue)
		return textValue == "Origin Sector" or textValue == "Orange Sector" or textValue == "Spawn World"
	end)
	if title then
		title.Text = preview.Title
	end

	local description = findBestText(worldsWindow, function(textValue)
		return textValue:find("starting sector") ~= nil
			or textValue:find("Contains Inside") ~= nil
			or textValue:find("Cost:") ~= nil
	end)
	if description then
		description.Text = preview.Description
	end

	local status
	if locationId == "OrangeSector" then
		status = findFirstText(worldsWindow, function(textValue)
			return textValue == "CURRENT" or textValue == "LOCKED"
		end)
	else
		status = findFirstText(worldsWindow, function(textValue)
			return textValue == "CURRENT"
		end) or findFirstText(worldsWindow, function(textValue)
			return textValue == orangeCostCompact or textValue == "LOCKED"
		end)
	end
	if status then
		status.Text = preview.Status
	end

	local nextTitle = findFirstText(worldsWindow, function(textValue)
		return textValue == "Next: Orange" or textValue == "Back: Origin"
	end)
	if nextTitle then
		nextTitle.Text = preview.NextTitle
	end

	local nextDescription = findFirstText(worldsWindow, function(textValue)
		return textValue == "Contains Inside the Pipes" or textValue == "Contains the Red Wastelands"
	end)
	if nextDescription then
		nextDescription.Text = preview.NextDescription
	end

	local nextStatus = findFirstText(worldsWindow, function(textValue)
		return textValue == "READY" or textValue == "BACK" or textValue == orangeCostCompact
	end)
	if nextStatus and nextStatus ~= status then
		nextStatus.Text = preview.NextStatus == "READY" and orangeCostCompact or preview.NextStatus
	end

	worldsWindow:SetAttribute("PreviewLocationId", locationId)
end

local function getLocationId(instance)
	if not instance then
		return nil
	end
	local attr = instance:GetAttribute("LocationId")
	if type(attr) == "string" and attr ~= "" then
		if attr == "SpawnWorld" or attr == "StartSector" then
			return "OriginSector"
		end
		return attr
	end
	return LOCATION_ALIASES[instance.Name]
end

local function getLocationHolder(button)
	local current = button
	while current do
		local locationId = getLocationId(current)
		if locationId then
			return current, locationId
		end
		current = current.Parent
	end
	return nil, nil
end

local function hasAncestorNamed(instance, name)
	local current = instance
	while current do
		if current.Name == name then
			return true
		end
		current = current.Parent
	end
	return false
end

local function isPreviewOnly(instance)
	local current = instance
	while current do
		if current:GetAttribute("PreviewOnly") == true then
			return true
		end
		current = current.Parent
	end
	return false
end

local function isLocked(locationHolder, locationId)
	if locationHolder:GetAttribute("Locked") == true then
		return true
	end
	return LOCKED_LOCATIONS[locationId] == true
end

local hookedPreviewButtons = {}
local function hookPreviewButton(worldsWindow, button)
	if hookedPreviewButtons[button] or not button:IsA("GuiButton") then
		return
	end
	if not isPreviewOnly(button) then
		return
	end

	hookedPreviewButtons[button] = true
	button.MouseButton1Click:Connect(function()
		local currentLocation = worldsWindow:GetAttribute("PreviewLocationId") or "OriginSector"
		local nextLocation = currentLocation == "OrangeSector" and "OriginSector" or "OrangeSector"
		local loweredName = string.lower(button.Name)
		local buttonText = button:IsA("TextButton") and button.Text or ""
		if loweredName:find("left") or loweredName:find("prev") or loweredName:find("back") or buttonText:find("<") then
			nextLocation = "OriginSector"
		elseif loweredName:find("right") or loweredName:find("next") or buttonText:find(">") then
			nextLocation = "OrangeSector"
		end

		setWorldPreview(worldsWindow, nextLocation)
		if nextLocation == "OrangeSector" and tutorialActionEvent and tutorialActionEvent:IsA("RemoteEvent") then
			tutorialActionEvent:FireServer("NextWorldPreviewed")
		end
	end)
end

local hookedCards = {}
local function hookTravelCard(button)
	if button:GetAttribute("PreviewOnly") == true then
		return
	end
	if isPreviewOnly(button) then
		return
	end
	if hookedCards[button] or not button:IsA("GuiButton") then
		return
	end

	local locationHolder, locationId = getLocationHolder(button)
	if not locationId then
		return
	end
	if hasAncestorNamed(locationHolder, "WorldsPage") and not hasAncestorNamed(locationHolder, "ZonesPage") then
		return
	end

	hookedCards[button] = true
	button:SetAttribute("LocationId", locationId)

	if isLocked(locationHolder, locationId) then
		locationHolder:SetAttribute("Locked", true)
		setStatusText(locationHolder, "LOCKED")
		button.AutoButtonColor = false
		if button:IsA("TextButton") then
			button.Text = "LOCKED"
		end
	else
		button.AutoButtonColor = true
		if button:IsA("TextButton") and (button.Name == "BuyButton" or string.lower(button.Name):find("teleport")) then
			button.Text = "GO"
		end
	end

	button.MouseButton1Click:Connect(function()
		if isLocked(locationHolder, locationId) then
			warn("WorldsWindow: location locked", locationId)
			return
		end
		requestTravel:FireServer(locationId)
	end)
end

local function hookAll(worldsWindow)
	cleanWorldTravelText(worldsWindow)

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
	setWorldPreview(worldsWindow, worldsWindow:GetAttribute("PreviewLocationId") or "OriginSector")

	for _, obj in ipairs(worldsWindow:GetDescendants()) do
		if obj:IsA("GuiButton") then
			hookPreviewButton(worldsWindow, obj)
			hookTravelCard(obj)
		end
	end

	worldsWindow.DescendantAdded:Connect(function(obj)
		if obj:IsA("TextLabel") or obj:IsA("TextButton") then
			if obj.Text == "Spawn World" or obj.Text == "SPAWN WORLD" then
				obj.Text = "Origin Sector"
			elseif obj.Text == "SpawnWorld" or obj.Text == "SPAWNWORLD" then
				obj.Text = "Origin Sector"
			elseif obj.Text == "Red World" or obj.Text == "RED WORLD" then
				obj.Text = "Red Wastelands"
			elseif obj.Text == "Orange World" or obj.Text == "ORANGE WORLD" then
				obj.Text = "Orange Sector"
			end
		end
		if obj:IsA("GuiButton") then
			task.defer(function()
				hookPreviewButton(worldsWindow, obj)
				hookTravelCard(obj)
			end)
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
