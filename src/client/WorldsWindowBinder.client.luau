-- Single controller for the editable Sectors/Worlds window.
-- Builds the live Worlds/Zones tab inside the Studio-made WorldsWindow.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local ColorData = require(ReplicatedStorage:WaitForChild("ColorData"))
local GameBalance = require(ReplicatedStorage:WaitForChild("GameBalance"))

local Events = ReplicatedStorage:WaitForChild("Events")
local requestTravel = Events:WaitForChild("RequestTravelToLocation")
local unlockEvent = Events:WaitForChild("UnlockArea")
local travelResult = Events:FindFirstChild("TravelToLocationResult")

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

local SECTORS = {
	{
		id = "OriginSector",
		colorType = "Red",
		title = "Origin Sector",
		description = "Free starting sector. Your game spawn is the Origin Spawn.",
		thumbnailText = "ORIGIN",
		color = COLORS.Red,
	},
	{
		id = "OrangeSector",
		colorType = "Orange",
		title = "Orange Sector",
		description = "Unlocks orange spills and the Pipes zone.",
		thumbnailText = "ORANGE",
		color = COLORS.Orange,
		cost = 15000,
	},
}

local ZONES = {
	OriginSector = {
		{
			id = "RedWastelands",
			title = "Red Wastelands",
			description = "Clean spills and earn Coins.",
			color = COLORS.Red,
			alwaysUnlocked = true,
		},
		{
			id = "ZorkShop",
			title = "Zork Shop",
			description = "Visit Zork for shop rewards and upgrades.",
			color = COLORS.Gold,
			alwaysUnlocked = true,
		},
	},
	OrangeSector = {
		{
			id = "InsidePipes",
			title = "The Pipes",
			description = "Reach this zone in Orange Sector first to unlock its teleport.",
			color = COLORS.Pipes,
			requiredColor = "Orange",
		},
	},
}

local root = playerGui:WaitForChild("ClientUIRoot", 20)
local mainHUD = root and root:WaitForChild("MainHUD", 20)
local modal = mainHUD and mainHUD:WaitForChild("ModalWindows", 20)
local windows = modal and modal:WaitForChild("Windows", 20)
local worldsWindow = windows and windows:WaitForChild("WorldsWindow", 20)
if not worldsWindow then
	warn("WorldsWindowBinder: WorldsWindow missing")
	return
end

local currentPage = "Worlds"
local previewIndex = 1
local unlockedCsv = "Red"
local currentWorldColor = "Red"
local unlockedTeleportsCsv = "OriginSector"

local function formatCoins(value)
	return GameBalance.formatNumber(tonumber(value) or 0)
end

local function worldUnlocked(colorType)
	return ColorData.isColorUnlocked(unlockedCsv, colorType)
end

local function teleportUnlocked(locationId)
	if locationId == "OriginSector" then
		return true
	end
	for _, id in ipairs(string.split(unlockedTeleportsCsv or "", ",")) do
		if id == locationId then
			return true
		end
	end
	return false
end

local function find(name)
	return worldsWindow:FindFirstChild(name, true)
end

local function setText(object, text)
	if object and (object:IsA("TextLabel") or object:IsA("TextButton")) then
		object.Text = tostring(text or "")
	end
end

local function applyCorner(object, radius)
	local corner = object:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 12)
	corner.Parent = object
end

local function applyStroke(object, thickness, color)
	local stroke = object:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	stroke.Thickness = thickness or 2
	stroke.Color = color or COLORS.Outline
	stroke.Parent = object
end

local function make(className, props)
	local object = Instance.new(className)
	for key, value in pairs(props or {}) do
		object[key] = value
	end
	return object
end

local body = worldsWindow:FindFirstChild("Content") or worldsWindow:FindFirstChild("Body")
if not body or not body:IsA("GuiObject") then
	body = make("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(22, 82),
		Size = UDim2.new(1, -44, 1, -108),
		Parent = worldsWindow,
	})
end

for _, child in ipairs(body:GetChildren()) do
	if child:IsA("GuiObject") then
		child.Visible = false
	end
end

local surface = body:FindFirstChild("WorldsBinderSurface")
if not surface then
	surface = make("Frame", {
		Name = "WorldsBinderSurface",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = body,
	})
else
	surface.Visible = true
end
surface:ClearAllChildren()

local toastLayer = root:FindFirstChild("WorldsToastLayer")
if not toastLayer then
	toastLayer = make("Frame", {
		Name = "WorldsToastLayer",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 250,
		Parent = root,
	})
end

local function showToast(text, color)
	local toast = make("TextLabel", {
		Name = "TeleportToast",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 78),
		Size = UDim2.fromOffset(420, 44),
		BackgroundColor3 = color or COLORS.Green,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBlack,
		Text = text,
		TextColor3 = COLORS.White,
		TextScaled = true,
		TextStrokeColor3 = COLORS.Outline,
		TextStrokeTransparency = 0,
		ZIndex = 260,
		Parent = toastLayer,
	})
	applyCorner(toast, 12)
	applyStroke(toast, 3, COLORS.Outline)
	toast.BackgroundTransparency = 1
	toast.TextTransparency = 1
	toast.TextStrokeTransparency = 1
	TweenService:Create(toast, TweenInfo.new(0.16), {
		BackgroundTransparency = 0,
		TextTransparency = 0,
		TextStrokeTransparency = 0,
		Position = UDim2.new(0.5, 0, 0, 58),
	}):Play()
	task.delay(2.1, function()
		if toast.Parent then
			TweenService:Create(toast, TweenInfo.new(0.2), {
				BackgroundTransparency = 1,
				TextTransparency = 1,
				TextStrokeTransparency = 1,
				Position = UDim2.new(0.5, 0, 0, 42),
			}):Play()
			task.delay(0.25, function()
				if toast.Parent then
					toast:Destroy()
				end
			end)
		end
	end)
end

local function makeLabel(parent, name, text, pos, size, textSize, color)
	return make("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		Position = pos,
		Size = size,
		Font = Enum.Font.GothamBlack,
		Text = text,
		TextColor3 = color or COLORS.Text,
		TextSize = textSize or 18,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = 80,
		Parent = parent,
	})
end

local pages = make("Frame", {
	Name = "Pages",
	BackgroundTransparency = 1,
	Position = UDim2.fromScale(0, 0.12),
	Size = UDim2.fromScale(1, 0.88),
	Parent = surface,
})

local worldsPage = make("Frame", {
	Name = "WorldsPage",
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Parent = pages,
})

local zonesPage = make("Frame", {
	Name = "ZonesPage",
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Visible = false,
	Parent = pages,
})

local function getPreviewSector()
	return SECTORS[previewIndex] or SECTORS[1]
end

local function requestSector(sector)
	if sector.id == "OrangeSector" and not worldUnlocked("Orange") then
		unlockEvent:FireServer("unlock", "Orange")
		return
	end
	requestTravel:FireServer(sector.id)
end

local function requestZone(zone)
	if zone.requiredColor and not worldUnlocked(zone.requiredColor) then
		showToast("Unlock " .. tostring(zone.requiredColor) .. " Sector first.", COLORS.Red)
		return
	end
	if not zone.alwaysUnlocked and not teleportUnlocked(zone.id) then
		showToast("Visit " .. zone.title .. " first to unlock its teleport.", COLORS.Orange)
		return
	end
	requestTravel:FireServer(zone.id)
end

local function renderTabs()
	local worldsTab = find("WorldsTab")
	local zonesTab = find("ZonesTab")
	if worldsTab and worldsTab:IsA("GuiObject") then
		worldsTab.BackgroundColor3 = currentPage == "Worlds" and COLORS.Accent or COLORS.Off
	end
	if zonesTab and zonesTab:IsA("GuiObject") then
		zonesTab.BackgroundColor3 = currentPage == "Zones" and COLORS.Accent or COLORS.Off
	end
end

local render

local function drawWorlds()
	worldsPage:ClearAllChildren()
	local sector = getPreviewSector()
	local unlocked = sector.colorType == "Red" or worldUnlocked(sector.colorType)
	local current = currentWorldColor == sector.colorType

	local card = make("Frame", {
		Name = "SectorPreview",
		Position = UDim2.fromScale(0.08, 0.10),
		Size = UDim2.fromScale(0.84, 0.72),
		BackgroundColor3 = sector.color,
		BorderSizePixel = 0,
		Parent = worldsPage,
	})
	applyCorner(card, 8)

	local thumb = make("Frame", {
		Name = "Thumbnail",
		Position = UDim2.fromScale(0.04, 0.16),
		Size = UDim2.fromScale(0.28, 0.56),
		BackgroundColor3 = sector.color:Lerp(Color3.fromRGB(20, 24, 30), 0.12),
		BorderSizePixel = 0,
		Parent = card,
	})
	applyCorner(thumb, 8)
	applyStroke(thumb, 4, sector.colorType == "Orange" and Color3.fromRGB(255, 88, 20) or COLORS.Outline)
	local thumbText = makeLabel(thumb, "ThumbnailText", sector.thumbnailText, UDim2.fromScale(0.08, 0.28), UDim2.fromScale(0.84, 0.26), 22, COLORS.White)
	thumbText.TextXAlignment = Enum.TextXAlignment.Center
	thumbText.TextStrokeColor3 = COLORS.Outline
	thumbText.TextStrokeTransparency = 0

	local titlePrefix = current and "Current Sector" or (unlocked and "Unlocked Sector" or "Next Sector")
	makeLabel(card, "TitlePrefix", titlePrefix, UDim2.fromScale(0.38, 0.15), UDim2.fromScale(0.50, 0.10), 18, COLORS.White)
	local title = makeLabel(card, "Title", sector.title, UDim2.fromScale(0.38, 0.26), UDim2.fromScale(0.52, 0.12), 28, COLORS.White)
	title.TextStrokeColor3 = COLORS.Outline
	title.TextStrokeTransparency = 0
	makeLabel(card, "Description", sector.description, UDim2.fromScale(0.38, 0.40), UDim2.fromScale(0.50, 0.18), 15, COLORS.White)

	local buttonText
	local buttonColor
	if sector.id == "OrangeSector" and not unlocked then
		buttonText = "UNLOCK " .. formatCoins(sector.cost) .. " COINS"
		buttonColor = COLORS.Green
	elseif current then
		buttonText = "HERE"
		buttonColor = COLORS.Green
	else
		buttonText = "GO"
		buttonColor = COLORS.Accent
	end

	local action = make("TextButton", {
		Name = "SectorAction",
		Position = UDim2.fromScale(0.38, 0.64),
		Size = UDim2.fromScale(0.36, 0.13),
		BackgroundColor3 = buttonColor,
		BorderSizePixel = 0,
		AutoButtonColor = true,
		Font = Enum.Font.GothamBlack,
		Text = buttonText,
		TextColor3 = COLORS.White,
		TextScaled = true,
		TextStrokeColor3 = COLORS.Outline,
		TextStrokeTransparency = 0,
		Parent = card,
	})
	applyCorner(action, 12)
	action.MouseButton1Click:Connect(function()
		requestSector(sector)
	end)

	local left = make("TextButton", {
		Name = "PreviousSectorButton",
		Position = UDim2.fromScale(0.01, 0.42),
		Size = UDim2.fromScale(0.055, 0.18),
		BackgroundColor3 = COLORS.Off,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBlack,
		Text = "<",
		TextColor3 = COLORS.Text,
		TextScaled = true,
		Parent = worldsPage,
	})
	applyCorner(left, 10)
	left.MouseButton1Click:Connect(function()
		previewIndex = previewIndex == 1 and #SECTORS or previewIndex - 1
		render()
	end)

	local right = make("TextButton", {
		Name = "NextSectorButton",
		Position = UDim2.fromScale(0.935, 0.42),
		Size = UDim2.fromScale(0.055, 0.18),
		BackgroundColor3 = COLORS.Accent,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBlack,
		Text = ">",
		TextColor3 = COLORS.White,
		TextScaled = true,
		Parent = worldsPage,
	})
	applyCorner(right, 10)
	right.MouseButton1Click:Connect(function()
		previewIndex = previewIndex == #SECTORS and 1 or previewIndex + 1
		render()
	end)
end

local function drawZoneCard(parent, zone, index)
	local unlocked = zone.alwaysUnlocked or teleportUnlocked(zone.id)
	local sectorUnlocked = not zone.requiredColor or worldUnlocked(zone.requiredColor)
	local card = make("TextButton", {
		Name = zone.id .. "ZoneCard",
		Position = UDim2.fromScale(0.06 + ((index - 1) % 2) * 0.48, 0.24 + math.floor((index - 1) / 2) * 0.38),
		Size = UDim2.fromScale(0.42, 0.30),
		BackgroundColor3 = sectorUnlocked and COLORS.Card or Color3.fromRGB(225, 229, 238),
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = sectorUnlocked,
		Active = sectorUnlocked,
		Parent = parent,
	})
	applyCorner(card, 8)
	applyStroke(card, 2, unlocked and zone.color or Color3.fromRGB(190, 196, 210))

	local swatch = make("Frame", {
		Name = "Swatch",
		Position = UDim2.fromScale(0.05, 0.18),
		Size = UDim2.fromScale(0.22, 0.50),
		BackgroundColor3 = zone.color,
		BorderSizePixel = 0,
		Parent = card,
	})
	applyCorner(swatch, 8)

	makeLabel(card, "Title", zone.title, UDim2.fromScale(0.33, 0.12), UDim2.fromScale(0.58, 0.18), 19, COLORS.Text)
	makeLabel(card, "Description", zone.description, UDim2.fromScale(0.33, 0.33), UDim2.fromScale(0.58, 0.24), 13, COLORS.Muted)

	local statusText = "TELEPORT"
	local statusColor = COLORS.Green
	if not sectorUnlocked then
		statusText = "LOCKED"
		statusColor = COLORS.Red
	elseif not unlocked then
		statusText = "VISIT FIRST"
		statusColor = COLORS.Orange
	end
	local status = make("TextLabel", {
		Name = "StatusPill",
		Position = UDim2.fromScale(0.33, 0.68),
		Size = UDim2.fromScale(0.36, 0.16),
		BackgroundColor3 = statusColor,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBlack,
		Text = statusText,
		TextColor3 = COLORS.White,
		TextScaled = true,
		TextStrokeColor3 = COLORS.Outline,
		TextStrokeTransparency = 0,
		Parent = card,
	})
	applyCorner(status, 999)

	card.MouseButton1Click:Connect(function()
		requestZone(zone)
	end)
end

local function drawZones()
	zonesPage:ClearAllChildren()
	local sector = getPreviewSector()
	local zones = ZONES[sector.id] or {}
	makeLabel(zonesPage, "ZonesHeader", "Zones in " .. sector.title, UDim2.fromScale(0.05, 0.04), UDim2.fromScale(0.74, 0.10), 24, COLORS.Text)
	local subtitle = sector.id == "OrangeSector" and "The Pipes teleport unlocks after you visit it in the Orange Sector." or "Origin Sector teleports are available from the start."
	makeLabel(zonesPage, "ZonesSubtitle", subtitle, UDim2.fromScale(0.05, 0.13), UDim2.fromScale(0.82, 0.07), 14, COLORS.Muted)
	for index, zone in ipairs(zones) do
		drawZoneCard(zonesPage, zone, index)
	end
end

function render()
	renderTabs()
	worldsPage.Visible = currentPage == "Worlds"
	zonesPage.Visible = currentPage == "Zones"
	if currentPage == "Worlds" then
		drawWorlds()
	else
		drawZones()
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

local storage = player:WaitForChild("ColorStorage", 10)
local unlockedValue = storage and storage:WaitForChild("UnlockedColors", 10)
local currentWorldValue = storage and storage:WaitForChild("CurrentWorld", 10)
local unlockedTeleportsValue = storage and storage:WaitForChild("UnlockedTeleports", 10)

if unlockedValue then
	unlockedCsv = unlockedValue.Value
	unlockedValue:GetPropertyChangedSignal("Value"):Connect(function()
		unlockedCsv = unlockedValue.Value
		render()
	end)
end
if currentWorldValue then
	currentWorldColor = currentWorldValue.Value ~= "" and currentWorldValue.Value or currentWorldColor
	currentWorldValue:GetPropertyChangedSignal("Value"):Connect(function()
		currentWorldColor = currentWorldValue.Value ~= "" and currentWorldValue.Value or "Red"
		if currentWorldColor == "Orange" then
			previewIndex = 2
		end
		render()
	end)
end
if unlockedTeleportsValue then
	unlockedTeleportsCsv = unlockedTeleportsValue.Value ~= "" and unlockedTeleportsValue.Value or "OriginSector"
	unlockedTeleportsValue:GetPropertyChangedSignal("Value"):Connect(function()
		unlockedTeleportsCsv = unlockedTeleportsValue.Value ~= "" and unlockedTeleportsValue.Value or "OriginSector"
		render()
	end)
end

unlockEvent.OnClientEvent:Connect(function(kind, colorType)
	if colorType == "Orange" and (kind == "unlocked" or kind == "teleported" or kind == "state") then
		previewIndex = 2
	end
	render()
end)

if travelResult then
	travelResult.OnClientEvent:Connect(function(result)
		if type(result) ~= "table" then
			return
		end
		if result.UnlockedTeleports then
			unlockedTeleportsCsv = result.UnlockedTeleports
		end
		if result.UnlockedTeleport then
			showToast("New teleport unlocked: " .. tostring(result.DisplayName or result.LocationId), COLORS.Green)
		elseif result.Success == false and result.Message then
			showToast(tostring(result.Message), COLORS.Red)
		end
		render()
	end)
end

worldsWindow:GetPropertyChangedSignal("Visible"):Connect(function()
	if worldsWindow.Visible then
		render()
	end
end)

if currentWorldColor == "Orange" then
	previewIndex = 2
end
render()
print("WorldsWindowBinder: Worlds/Zones progression UI active")
