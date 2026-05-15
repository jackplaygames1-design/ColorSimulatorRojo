-- Normalizes baked egg models so they are solid, hatchable, and labeled cleanly.
-- This does not create map layout; it only tags/fixes egg objects the player placed.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ColorData = require(ReplicatedStorage:WaitForChild("ColorData"))
local PetData = require(ReplicatedStorage:WaitForChild("PetData"))

local DARK = Color3.fromRGB(26, 26, 30)
local GOLD = Color3.fromRGB(255, 228, 86)
local configured = {}

local function isDebugAppearanceObject(obj)
	return obj:FindFirstAncestor("PetAppearanceStudio") ~= nil
end

local function compactName(name)
	return string.lower(tostring(name or "")):gsub("%s+", "")
end

local function getEggIdForColor(colorType)
	local world = ColorData.getWorldByColor(colorType)
	if world and world.EggIds and world.EggIds[1] then
		return world.EggIds[1]
	end
	return tostring(colorType) .. "Egg"
end

local function inferEggInfo(obj)
	local current = obj
	while current and current ~= Workspace do
		local eggId = current:GetAttribute("EggId")
		if eggId and PetData.Eggs[eggId] then
			local egg = PetData.Eggs[eggId]
			return egg.areaColor, eggId
		end

		local lowered = compactName(current.Name)
		for _, world in ipairs(ColorData.Worlds or {}) do
			local colorType = world.primaryColor
			local expectedEggId = getEggIdForColor(colorType)
			if
				lowered == compactName(expectedEggId)
				or lowered == compactName(colorType .. "Egg")
				or (string.find(lowered, string.lower(colorType), 1, true) and string.find(lowered, "egg", 1, true))
			then
				return colorType, expectedEggId
			end
		end
		current = current.Parent
	end
	return nil, nil
end

local function getParts(root)
	local parts = {}
	if root:IsA("BasePart") then
		table.insert(parts, root)
	end
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	return parts
end

local function getBestPart(root)
	if root:IsA("BasePart") then
		return root
	end
	if root:IsA("Model") then
		return root.PrimaryPart or root:FindFirstChildWhichIsA("BasePart", true)
	end
	return root:FindFirstChildWhichIsA("BasePart", true)
end

local function getDisplayName(eggId)
	local egg = PetData.Eggs[eggId]
	if egg and egg.displayName and egg.displayName ~= "" then
		return egg.displayName
	end
	local spaced = tostring(eggId or "Egg"):gsub("(%l)(%u)", "%1 %2")
	return spaced
end

local configureEgg

local function findEggModelAncestor(part)
	local current = part and part.Parent
	while current and current ~= Workspace do
		if current:IsA("Model") then
			local colorType, eggId = inferEggInfo(current)
			if colorType and eggId then
				return current
			end
		end
		current = current.Parent
	end
	return nil
end

local function removeBadEggLabels(holder)
	for _, child in ipairs(holder:GetChildren()) do
		if
			child:IsA("BillboardGui")
			and (child.Name == "WorldEggLabel" or child.Name == "PreviewLabel" or child.Name == "EggStationLabel")
		then
			child:Destroy()
		end
	end
end

local function ensureLabel(holder, colorType, eggId)
	removeBadEggLabels(holder)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "EggStationLabel"
	billboard:SetAttribute("ProximityWorldLabel", true)
	billboard:SetAttribute("ShowDistance", 54)
	billboard:SetAttribute("HideDistance", 64)
	billboard.Size = UDim2.fromOffset(220, 62)
	billboard.StudsOffset = Vector3.new(0, 9.5, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 120
	billboard.Enabled = false
	billboard.Parent = holder

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 38)
	title.Font = Enum.Font.LuckiestGuy
	title.TextSize = 23
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextStrokeTransparency = 0
	title.TextStrokeColor3 = DARK
	title.Text = string.upper(getDisplayName(eggId))
	title.Parent = billboard

	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.fromOffset(0, 35)
	sub.Size = UDim2.new(1, 0, 0, 22)
	sub.Font = Enum.Font.GothamBold
	sub.TextSize = 14
	sub.TextColor3 = GOLD
	sub.TextStrokeTransparency = 0.08
	sub.TextStrokeColor3 = DARK
	sub.Text = "HATCH COLORS"
	sub.Parent = billboard

	return billboard
end

local function ensurePrompt(holder)
	local prompt = holder:FindFirstChild("EggShopPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "EggShopPrompt"
		prompt.Parent = holder
	end
	prompt.ActionText = "Hatch"
	prompt.ObjectText = "Egg"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = math.max(prompt.MaxActivationDistance, 18)
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt:SetAttribute("EggShopPrompt", true)
	return prompt
end

function configureEgg(root)
	if not root or not root.Parent or isDebugAppearanceObject(root) or configured[root] then
		return
	end

	if root:IsA("BasePart") then
		local eggModel = findEggModelAncestor(root)
		if eggModel then
			configureEgg(eggModel)
			return
		end
	end

	local colorType, eggId = inferEggInfo(root)
	if not colorType or not eggId or not PetData.Eggs[eggId] then
		return
	end

	local holder = getBestPart(root)
	if not holder then
		return
	end

	configured[root] = true
	if root:IsA("Model") then
		root:SetAttribute("EggId", eggId)
		root:SetAttribute("ColorType", colorType)
		root:SetAttribute("AreaColor", colorType)
		if not root.PrimaryPart then
			root.PrimaryPart = holder
		end
	end

	for _, part in ipairs(getParts(root)) do
		part:SetAttribute("EggId", eggId)
		part:SetAttribute("ColorType", colorType)
		part:SetAttribute("AreaColor", colorType)
		part:SetAttribute("EggStation", true)
		part:SetAttribute("ColorZone", false)
		part:SetAttribute("ColorBlobSpawn", false)
		part:SetAttribute("PlayableSectorFloor", false)
		part.CanCollide = true
		part.CanQuery = true
		part.CanTouch = false
	end

	holder:SetAttribute("EggId", eggId)
	holder:SetAttribute("EggStation", true)
	holder.CanCollide = true
	holder.CanQuery = true
	ensurePrompt(holder)
	ensureLabel(holder, colorType, eggId)
end

local function configureExisting()
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("Model") or obj:IsA("BasePart") then
			configureEgg(obj)
		end
	end
end

configureExisting()
task.delay(2, configureExisting)

Workspace.DescendantAdded:Connect(function(obj)
	if obj:IsA("Model") or obj:IsA("BasePart") then
		task.defer(configureEgg, obj)
	end
end)
