-- Hooks the baked shop interior to the existing brush shop UI.
-- The NPC is intentionally small and system-owned: the actual buying still uses ShopUI/PurchasePaintTool.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Events = ReplicatedStorage:WaitForChild("Events")
local shopTransitionEvent = Events:FindFirstChild("ShopTransition")
if not shopTransitionEvent then
	shopTransitionEvent = Instance.new("RemoteEvent")
	shopTransitionEvent.Name = "ShopTransition"
	shopTransitionEvent.Parent = Events
end

local tutorialShopEnteredEvent = Events:FindFirstChild("TutorialShopEntered")
if not tutorialShopEnteredEvent then
	tutorialShopEnteredEvent = Instance.new("BindableEvent")
	tutorialShopEnteredEvent.Name = "TutorialShopEntered"
	tutorialShopEnteredEvent.Parent = Events
end

local MAP_NAME = "ColorSimulatorMap"
local SHOP_FOLDER_NAME = "Shop"
local SHOP_INSIDE_NAME = "shopinside"
local NPC_NAME = "Zork"
local NPC_DISPLAY_NAME = "Zork"
local NPC_ROLE = "Brush Merchant"
local SHOP_COLOR = "Red"
local FADE_IN_TIME = 0.18
local SHOP_TELEPORT_COOLDOWN = 1.2
local SHOP_REENTER_GRACE_SECONDS = 2.75

local teleportLocks = {}
local reenterBlockedUntil = {}

local function getMap()
	return Workspace:FindFirstChild(MAP_NAME)
end

local function compactName(value)
	return string.lower(tostring(value or "")):gsub("[%s_%-%p]", "")
end

local function isContainer(instance)
	return instance and (instance:IsA("Folder") or instance:IsA("Model"))
end

local function findFirstContainerNamed(root, wantedName)
	if not root then
		return nil
	end

	local wanted = compactName(wantedName)
	if isContainer(root) and compactName(root.Name) == wanted then
		return root
	end

	for _, descendant in ipairs(root:GetDescendants()) do
		if isContainer(descendant) and compactName(descendant.Name) == wanted then
			return descendant
		end
	end
	return nil
end

local function findAncestorContainerNamed(instance, wantedName)
	local wanted = compactName(wantedName)
	local current = instance and instance.Parent
	while current and current ~= Workspace do
		if isContainer(current) and compactName(current.Name) == wanted then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function getShopInside()
	local map = getMap()
	return findFirstContainerNamed(map, SHOP_INSIDE_NAME) or findFirstContainerNamed(Workspace, SHOP_INSIDE_NAME)
end

local function getShopFolder()
	local shopInside = getShopInside()
	local shop = findAncestorContainerNamed(shopInside, SHOP_FOLDER_NAME)
	if shop then
		return shop
	end

	local map = getMap()
	shop = findFirstContainerNamed(map, SHOP_FOLDER_NAME) or findFirstContainerNamed(Workspace, SHOP_FOLDER_NAME)
	if shop then
		return shop
	end
	return shopInside and shopInside.Parent or nil
end

local function isNpcPart(part)
	return part and part:IsDescendantOf(Workspace) and part:FindFirstAncestor(NPC_NAME) ~= nil
end

local function findInteriorFloor(shopInside)
	local best
	local bestScore = -math.huge
	for _, obj in ipairs(shopInside:GetDescendants()) do
		if obj:IsA("BasePart") and not isNpcPart(obj) then
			local size = obj.Size
			local flatEnough = size.Y <= math.max(0.5, math.min(size.X, size.Z) * 0.25)
			local area = size.X * size.Z
			local score = area - obj.Position.Y * 20
			if flatEnough and score > bestScore then
				best = obj
				bestScore = score
			end
		end
	end

	if best then
		return best
	end

	for _, obj in ipairs(shopInside:GetDescendants()) do
		if obj:IsA("BasePart") and not isNpcPart(obj) then
			local area = obj.Size.X * obj.Size.Z
			if area > bestScore then
				best = obj
				bestScore = area
			end
		end
	end
	return best
end

local function isShopInteriorDescendant(obj, shopInside)
	return shopInside and obj:IsDescendantOf(shopInside)
end

local function isNamedEntrancePart(obj)
	local name = compactName(obj.Name)
	return obj:GetAttribute("ShopEntrance") == true
		or obj:GetAttribute("ShopDoorTeleport") == true
		or name == "shopentrance"
		or name == "door"
		or name == "entrance"
		or name:find("zorkdoor", 1, true) ~= nil
		or (name:find("shop", 1, true) ~= nil and name:find("door", 1, true) ~= nil)
end

local function getEntranceFallbackScore(obj)
	local color = obj.Color
	local blueScore = color.B - math.max(color.R, color.G) * 0.35
	local verticalScore = obj.Size.Y - math.min(obj.Size.X, obj.Size.Z)
	return blueScore * 10 + verticalScore
end

local function findExteriorEntrances(shop, shopInside)
	if not shop then
		return {}
	end

	local namedEntrances = {}
	for _, obj in ipairs(shop:GetDescendants()) do
		if
			obj:IsA("BasePart")
			and obj.Name ~= "ShopDoorTeleportTrigger"
			and not isNpcPart(obj)
			and isNamedEntrancePart(obj)
		then
			table.insert(namedEntrances, obj)
		end
	end
	if #namedEntrances > 0 then
		table.sort(namedEntrances, function(a, b)
			return a.Name < b.Name
		end)
		return namedEntrances
	end

	local best
	local bestScore = -math.huge
	for _, obj in ipairs(shop:GetDescendants()) do
		if
			obj:IsA("BasePart")
			and obj.Name ~= "ShopDoorTeleportTrigger"
			and not isNpcPart(obj)
			and (isNamedEntrancePart(obj) or not isShopInteriorDescendant(obj, shopInside))
		then
			local score = getEntranceFallbackScore(obj)
			if score > bestScore then
				best = obj
				bestScore = score
			end
		end
	end
	return best and { best } or {}
end

local function makePart(parent, name, size, cframe, color, material, shape)
	local part = parent:FindFirstChild(name)
	if not part then
		part = Instance.new("Part")
		part.Name = name
		part.Parent = parent
	end
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Shape = shape or Enum.PartType.Block
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = true
	part.CastShadow = false
	return part
end

local function applyShopAttributes(instance)
	instance:SetAttribute("BrushShop", true)
	instance:SetAttribute("CombinedShop", true)
	instance:SetAttribute("ShopStation", true)
	instance:SetAttribute("ColorType", SHOP_COLOR)
	instance:SetAttribute("AreaColor", SHOP_COLOR)
	instance:SetAttribute("ShopColor", SHOP_COLOR)
	instance:SetAttribute("BrushNpc", true)
end

local function ensurePrompt(core)
	local prompt = core:FindFirstChild("BrushShopPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "BrushShopPrompt"
		prompt.Parent = core
	end
	prompt.ActionText = "Talk"
	prompt.ObjectText = NPC_DISPLAY_NAME
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("BrushShopPrompt", true)
	prompt:SetAttribute("CombinedShopPrompt", true)
	prompt:SetAttribute("BrushNpcDialogue", true)
	prompt:SetAttribute("NpcDialogueId", NPC_DISPLAY_NAME)
	prompt:SetAttribute("NpcName", NPC_DISPLAY_NAME)
	prompt:SetAttribute("ColorType", SHOP_COLOR)
	prompt:SetAttribute("ShopColor", SHOP_COLOR)
	return prompt
end

local function ensureNpcLabel(core)
	local label = core:FindFirstChild("BrushNpcLabel")
	if not label then
		label = Instance.new("BillboardGui")
		label.Name = "BrushNpcLabel"
		label.Parent = core
	end
	label.AlwaysOnTop = true
	label.LightInfluence = 0
	label.MaxDistance = 70
	label.Size = UDim2.fromOffset(190, 58)
	label.StudsOffset = Vector3.new(0, 4.7, 0)

	local background = label:FindFirstChild("Background")
	if not background then
		background = Instance.new("Frame")
		background.Name = "Background"
		background.Parent = label
	end
	background.AnchorPoint = Vector2.new(0.5, 0.5)
	background.Position = UDim2.fromScale(0.5, 0.5)
	background.Size = UDim2.new(1, -14, 1, -8)
	background.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
	background.BackgroundTransparency = 0.18
	background.BorderSizePixel = 0
	local bgCorner = background:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 12)
	bgCorner.Parent = background
	local bgStroke = background:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	bgStroke.Color = Color3.fromRGB(118, 238, 244)
	bgStroke.Thickness = 2
	bgStroke.Transparency = 0.18
	bgStroke.Parent = background

	local text = label:FindFirstChild("Text")
	if not text then
		text = Instance.new("TextLabel")
		text.Name = "Text"
		text.Parent = label
	end
	text.Size = UDim2.new(1, -20, 0, 28)
	text.Position = UDim2.fromOffset(10, 6)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBlack
	text.TextSize = 20
	text.TextColor3 = Color3.fromRGB(255, 255, 255)
	text.TextStrokeTransparency = 0.35
	text.TextStrokeColor3 = Color3.fromRGB(30, 33, 42)
	text.Text = NPC_DISPLAY_NAME

	local role = label:FindFirstChild("Role")
	if not role then
		role = Instance.new("TextLabel")
		role.Name = "Role"
		role.Parent = label
	end
	role.Size = UDim2.new(1, -20, 0, 20)
	role.Position = UDim2.fromOffset(10, 32)
	role.BackgroundTransparency = 1
	role.Font = Enum.Font.GothamBold
	role.TextSize = 12
	role.TextColor3 = Color3.fromRGB(170, 244, 248)
	role.TextStrokeTransparency = 0.65
	role.TextStrokeColor3 = Color3.fromRGB(30, 33, 42)
	role.Text = NPC_ROLE
	return label
end

local function getCharacterRoot(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function setRootCFrame(player, cframe)
	local root = getCharacterRoot(player)
	if not root then
		return false
	end
	root.CFrame = cframe
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	return true
end

local function teleportToInterior(player, floor, npcCore)
	if not floor then
		return false
	end
	local floorTopY = floor.Position.Y + floor.Size.Y * 0.5 + 3.2
	local targetPosition = npcCore and npcCore.Position or floor.Position
	local distance = math.clamp(math.min(floor.Size.X, floor.Size.Z) * 0.26, 7, 14)
	local destination = floor.Position + floor.CFrame.LookVector * distance
	destination = Vector3.new(destination.X, floorTopY, destination.Z)
	local lookAt = Vector3.new(targetPosition.X, floorTopY, targetPosition.Z)
	return setRootCFrame(player, CFrame.lookAt(destination, lookAt))
end

local function getExteriorShopCenter(entrance)
	local shop = getShopFolder()
	if not shop then
		return nil
	end

	local shopInside = getShopInside()
	local total = Vector3.zero
	local count = 0
	for _, obj in ipairs(shop:GetDescendants()) do
		if
			obj:IsA("BasePart")
			and obj ~= entrance
			and (not shopInside or not obj:IsDescendantOf(shopInside))
			and obj.Name ~= "ShopDoorTeleportTrigger"
			and not isNpcPart(obj)
		then
			total += obj.Position
			count += 1
		end
	end

	if count <= 0 then
		return nil
	end
	return total / count
end

local function findExteriorExitAnchor()
	local shop = getShopFolder()
	if not shop then
		return nil
	end

	for _, obj in ipairs(shop:GetDescendants()) do
		if
			obj:IsA("BasePart")
			and (
				obj:GetAttribute("ShopExitSpawn") == true
				or obj.Name == "ShopExitSpawn"
				or obj.Name == "ShopExteriorSpawn"
				or obj.Name == "ShopExteriorExit"
			)
		then
			return obj
		end
	end
	return nil
end

local function getEntranceOutward(entrance)
	local shopCenter = getExteriorShopCenter(entrance)
	local outward = shopCenter and (entrance.Position - shopCenter) or Vector3.zero
	if outward.Magnitude < 0.01 then
		local shopInside = getShopInside()
		local interiorFloor = shopInside and findInteriorFloor(shopInside)
		if interiorFloor then
			outward = entrance.Position - interiorFloor.Position
		end
	else
		outward = outward.Unit
	end

	if outward.Magnitude < 0.01 then
		outward = -entrance.CFrame.LookVector
	else
		outward = outward.Unit
	end

	return outward
end

local function teleportToExterior(player, entrance)
	if not entrance then
		return false
	end

	local outward = getEntranceOutward(entrance)
	local minimumDoorClearance = math.max(math.max(entrance.Size.X, entrance.Size.Z) * 0.5 + 22, 24)
	local exitAnchor = findExteriorExitAnchor()
	if exitAnchor then
		local destination = exitAnchor.Position + Vector3.new(0, exitAnchor.Size.Y * 0.5 + 3.2, 0)
		local horizontalOffset =
			Vector3.new(destination.X - entrance.Position.X, 0, destination.Z - entrance.Position.Z)
		if horizontalOffset.Magnitude < minimumDoorClearance then
			destination = entrance.Position + outward * minimumDoorClearance
			destination = Vector3.new(destination.X, entrance.Position.Y + entrance.Size.Y * 0.5 + 3.2, destination.Z)
		end
		local lookAt = Vector3.new(entrance.Position.X, destination.Y, entrance.Position.Z)
		return setRootCFrame(player, CFrame.lookAt(destination, lookAt))
	end

	local offset = minimumDoorClearance
	local destination = entrance.Position + outward * offset
	destination = Vector3.new(destination.X, entrance.Position.Y + entrance.Size.Y * 0.5 + 3.2, destination.Z)
	local lookAt = Vector3.new(entrance.Position.X, destination.Y, entrance.Position.Z)
	return setRootCFrame(player, CFrame.lookAt(destination, lookAt))
end

local function playShopTransition(player, teleportCallback, afterTeleport)
	local now = os.clock()
	if teleportLocks[player] and now - teleportLocks[player] < SHOP_TELEPORT_COOLDOWN then
		return
	end
	teleportLocks[player] = now

	if shopTransitionEvent and shopTransitionEvent:IsA("RemoteEvent") then
		shopTransitionEvent:FireClient(player, "FadeIn")
	end
	task.delay(FADE_IN_TIME, function()
		if not player.Parent then
			return
		end
		local ok = teleportCallback()
		if ok and afterTeleport then
			afterTeleport()
		end
		task.delay(0.08, function()
			if player.Parent and shopTransitionEvent and shopTransitionEvent:IsA("RemoteEvent") then
				shopTransitionEvent:FireClient(player, "FadeOut")
			end
		end)
	end)
end

local function getPlayerFromTouchedPart(part)
	local character = part and part.Parent
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end
	return Players:GetPlayerFromCharacter(character)
end

local function ensureShopTeleportPrompts(shopInside, floor, npcCore)
	local shop = getShopFolder()
	local entrances = findExteriorEntrances(shop, shopInside)
	local primaryEntrance = entrances[1]
	if not primaryEntrance or not floor then
		return
	end

	local function enterShop(player)
		local blockedUntil = reenterBlockedUntil[player]
		if blockedUntil and os.clock() < blockedUntil then
			return
		end
		playShopTransition(player, function()
			return teleportToInterior(player, floor, npcCore or floor)
		end, function()
			if tutorialShopEnteredEvent and tutorialShopEnteredEvent:IsA("BindableEvent") then
				tutorialShopEnteredEvent:Fire(player)
			end
		end)
	end

	for _, entrance in ipairs(entrances) do
		entrance:SetAttribute("ShopEntrance", true)
		entrance:SetAttribute("ColorType", SHOP_COLOR)
		local enterPrompt = entrance:FindFirstChild("EnterShopPrompt")
		if not enterPrompt then
			enterPrompt = Instance.new("ProximityPrompt")
			enterPrompt.Name = "EnterShopPrompt"
			enterPrompt.Parent = entrance
		end
		enterPrompt.ActionText = "Enter"
		enterPrompt.ObjectText = "Brush Shop"
		enterPrompt.KeyboardKeyCode = Enum.KeyCode.E
		enterPrompt.GamepadKeyCode = Enum.KeyCode.ButtonX
		enterPrompt.HoldDuration = 0
		enterPrompt.MaxActivationDistance = 14
		enterPrompt.RequiresLineOfSight = false
		enterPrompt:SetAttribute("ShopEnterPrompt", true)

		if enterPrompt:GetAttribute("ShopTeleportHooked") ~= true then
			enterPrompt:SetAttribute("ShopTeleportHooked", true)
			enterPrompt.Triggered:Connect(enterShop)
		end

		local trigger = entrance:FindFirstChild("ShopDoorTeleportTrigger")
		if not trigger then
			trigger = Instance.new("Part")
			trigger.Name = "ShopDoorTeleportTrigger"
			trigger.Parent = entrance
		end
		trigger.Size = Vector3.new(
			math.max(entrance.Size.X + 2, 6),
			math.max(entrance.Size.Y + 2, 7),
			math.max(entrance.Size.Z + 3, 5)
		)
		trigger.CFrame = entrance.CFrame
		trigger.Anchored = true
		trigger.CanCollide = false
		trigger.CanTouch = true
		trigger.CanQuery = false
		trigger.Transparency = 1
		trigger:SetAttribute("ShopDoorTeleport", true)

		if trigger:GetAttribute("ShopTeleportHooked") ~= true then
			trigger:SetAttribute("ShopTeleportHooked", true)
			trigger.Touched:Connect(function(hit)
				local player = getPlayerFromTouchedPart(hit)
				if player then
					enterShop(player)
				end
			end)
		end
	end

	local exitAnchor = shopInside:FindFirstChild("ShopExitPromptAnchor")
	if not exitAnchor then
		exitAnchor = Instance.new("Part")
		exitAnchor.Name = "ShopExitPromptAnchor"
		exitAnchor.Parent = shopInside
	end
	exitAnchor.Size = Vector3.new(4, 4, 4)
	exitAnchor.CFrame = floor.CFrame * CFrame.new(0, floor.Size.Y * 0.5 + 3, math.max(floor.Size.Z * 0.35, 7))
	exitAnchor.Anchored = true
	exitAnchor.CanCollide = false
	exitAnchor.CanTouch = false
	exitAnchor.CanQuery = false
	exitAnchor.Transparency = 1

	local exitPrompt = exitAnchor:FindFirstChild("ExitShopPrompt")
	if not exitPrompt then
		exitPrompt = Instance.new("ProximityPrompt")
		exitPrompt.Name = "ExitShopPrompt"
		exitPrompt.Parent = exitAnchor
	end
	exitPrompt.ActionText = "Exit"
	exitPrompt.ObjectText = "Shop Exit"
	exitPrompt.KeyboardKeyCode = Enum.KeyCode.E
	exitPrompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	exitPrompt.HoldDuration = 0
	exitPrompt.MaxActivationDistance = 12
	exitPrompt.RequiresLineOfSight = false
	exitPrompt:SetAttribute("ShopExitPrompt", true)
	if exitPrompt:GetAttribute("ShopTeleportHooked") ~= true then
		exitPrompt:SetAttribute("ShopTeleportHooked", true)
		exitPrompt.Triggered:Connect(function(player)
			playShopTransition(player, function()
				return teleportToExterior(player, primaryEntrance)
			end, function()
				reenterBlockedUntil[player] = os.clock() + SHOP_REENTER_GRACE_SECONDS
			end)
		end)
	end
end

local function ensureColorBrushNpc()
	local shopInside = getShopInside()
	if not shopInside then
		return false
	end

	local floor = findInteriorFloor(shopInside)
	if not floor then
		return false
	end

	local npc = shopInside:FindFirstChild(NPC_NAME) or shopInside:FindFirstChild("ColorBrushNpc")
	if not npc then
		npc = Instance.new("Model")
		npc.Parent = shopInside
	end
	npc.Name = NPC_NAME
	applyShopAttributes(npc)

	local basePosition = floor.Position + Vector3.new(0, floor.Size.Y * 0.5 + 3.2, 0)
	local baseCFrame = CFrame.new(basePosition)

	local root = makePart(
		npc,
		"HumanoidRootPart",
		Vector3.new(2, 5, 2),
		baseCFrame,
		Color3.fromRGB(80, 210, 255),
		Enum.Material.SmoothPlastic
	)
	root.Transparency = 1
	root.CanQuery = false
	npc.PrimaryPart = root

	local body = makePart(
		npc,
		"ColorBody",
		Vector3.new(3.2, 3.2, 3.2),
		baseCFrame,
		Color3.fromRGB(55, 198, 255),
		Enum.Material.Neon,
		Enum.PartType.Ball
	)
	local core = makePart(
		npc,
		"ShopPromptCore",
		Vector3.new(3.8, 4.6, 3.8),
		baseCFrame,
		Color3.fromRGB(55, 198, 255),
		Enum.Material.SmoothPlastic
	)
	core.Transparency = 1
	local head = makePart(
		npc,
		"ColorHead",
		Vector3.new(1.7, 1.7, 1.7),
		baseCFrame * CFrame.new(0, 2.35, 0),
		Color3.fromRGB(148, 255, 119),
		Enum.Material.Neon,
		Enum.PartType.Ball
	)
	local glow = makePart(
		npc,
		"ColorGlow",
		Vector3.new(4.3, 0.25, 4.3),
		baseCFrame * CFrame.new(0, -1.75, 0),
		Color3.fromRGB(92, 235, 255),
		Enum.Material.Neon,
		Enum.PartType.Cylinder
	)
	glow.Transparency = 0.22

	local handle = makePart(
		npc,
		"BrushHandle",
		Vector3.new(0.28, 3.1, 0.28),
		baseCFrame * CFrame.new(1.75, 0.2, 0) * CFrame.Angles(0, 0, math.rad(24)),
		Color3.fromRGB(255, 218, 112),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Cylinder
	)
	local bristles = makePart(
		npc,
		"BrushBristles",
		Vector3.new(0.8, 0.65, 0.8),
		baseCFrame * CFrame.new(2.35, 1.55, 0) * CFrame.Angles(0, 0, math.rad(24)),
		Color3.fromRGB(255, 85, 130),
		Enum.Material.Neon,
		Enum.PartType.Ball
	)

	for _, part in ipairs({ root, body, core, head, glow, handle, bristles }) do
		applyShopAttributes(part)
	end
	ensurePrompt(core)
	ensureNpcLabel(core)
	ensureShopTeleportPrompts(shopInside, floor, core)

	return true
end

task.defer(ensureColorBrushNpc)
task.delay(2, ensureColorBrushNpc)
task.delay(6, ensureColorBrushNpc)

Players.PlayerRemoving:Connect(function(player)
	teleportLocks[player] = nil
	reenterBlockedUntil[player] = nil
end)

Workspace.DescendantAdded:Connect(function(obj)
	local name = compactName(obj.Name)
	if
		name == compactName(SHOP_FOLDER_NAME)
		or name == compactName(SHOP_INSIDE_NAME)
		or name:find("zorkdoor", 1, true) ~= nil
		or (name:find("shop", 1, true) ~= nil and name:find("door", 1, true) ~= nil)
	then
		task.defer(ensureColorBrushNpc)
	end
end)
