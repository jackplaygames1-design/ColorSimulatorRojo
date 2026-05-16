-- LocalScript in StarterPlayerScripts named "InputHandler"
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local ClientUIRoot = require(ReplicatedStorage:WaitForChild("ClientUIRoot"))
local ColorMutationData = require(ReplicatedStorage:WaitForChild("ColorMutationData"))
local ColorTraitData = require(ReplicatedStorage:WaitForChild("ColorTraitData"))
local PetData = require(ReplicatedStorage:WaitForChild("PetData"))

local Events = ReplicatedStorage:WaitForChild("Events", 10)
if not Events then
	warn("Collection remote missing, using touch fallback only.")
	return
end
local collectEvent = Events:WaitForChild("CollectColor", 10)
local hatchEvent = Events:WaitForChild("HatchEgg", 10)
if not collectEvent then
	warn("Collection remote missing, using touch fallback only.")
	return
end
local openEggShopEvent = ReplicatedStorage:FindFirstChild("OpenEggShop")
if not openEggShopEvent then
	openEggShopEvent = Instance.new("BindableEvent")
	openEggShopEvent.Name = "OpenEggShop"
	openEggShopEvent.Parent = ReplicatedStorage
end

local DEFAULT_HOVER_RANGE = 20
local pendingCollectPart = nil

local function getClientSetting(key, defaultValue)
	local value = player:GetAttribute("Setting" .. key)
	return type(value) == "boolean" and value or defaultValue
end

local function parseInventory(str)
	local inventory = {}
	if not str or str == "" then
		return inventory
	end

	for _, part in ipairs(string.split(str, ",")) do
		local segments = string.split(part, ":")
		local variantKey
		local petId
		local stackIndex
		if tonumber(segments[2]) then
			petId = segments[1]
			stackIndex = 2
		else
			variantKey = segments[1]
			petId = segments[2]
			stackIndex = 3
		end
		if petId and petId ~= "" then
			local variantPetId, variantTraitId, variantMutationId = PetData.splitVariantKey(variantKey or petId)
			if variantPetId then
				petId = variantPetId
			end
			local traitId = PetData.normalizeTraitId(segments[stackIndex + 1])
			local personalityId = PetData.normalizePersonalityId(segments[stackIndex + 3] or "Neutral")
			local mutationId = PetData.normalizeMutationId(segments[stackIndex + 4] or variantMutationId or "None")
			if variantTraitId and (not segments[stackIndex + 1] or segments[stackIndex + 1] == "") then
				traitId = variantTraitId
			end
			variantKey = variantKey or PetData.makeVariantKey(petId, personalityId, mutationId, traitId)
			inventory[variantKey] = {
				traitId = traitId,
				personalityId = personalityId,
				mutationId = mutationId,
			}
		end
	end

	return inventory
end

local function getEquippedPickupMultiplier()
	local petFolder = player:FindFirstChild("PetData")
	local invVal = petFolder and petFolder:FindFirstChild("Inventory")
	local equippedVal = petFolder and petFolder:FindFirstChild("Equipped")
	if not invVal or not equippedVal or equippedVal.Value == "" then
		return 1
	end

	local multiplier = 1
	local inventory = parseInventory(invVal.Value)
	for _, variantKey in ipairs(string.split(equippedVal.Value, ",")) do
		local data = inventory[variantKey]
		if data then
			local trait = ColorTraitData.get(data.traitId)
			local mutation = ColorMutationData.get(data.mutationId)
			multiplier *= (trait.Effects and trait.Effects.BrushRangeMultiplier) or 1
			multiplier *= (mutation.Effects and mutation.Effects.BrushRangeMultiplier) or 1
		end
	end

	return multiplier
end

local function getHoverRange()
	local range = DEFAULT_HOVER_RANGE
	local upgrades = player:FindFirstChild("Upgrades")
	local pickupRange = upgrades and upgrades:FindFirstChild("PickupRange")
	if pickupRange then
		range = pickupRange.Value
	end

	local boostFolder = player:FindFirstChild("Boosts")
	local rangeBoost = boostFolder and boostFolder:FindFirstChild("range")
	if rangeBoost and os.time() < rangeBoost.Value then
		range *= 1.5
	end

	range *= getEquippedPickupMultiplier()
	return range
end

local function hasPaintToolEquipped()
	local character = player.Character
	if not character then
		return false
	end

	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") and child:GetAttribute("PaintToolId") then
			return true
		end
	end

	return false
end

local feedbackGui = ClientUIRoot.GetLayer(player:WaitForChild("PlayerGui"), "CollectFeedbackUI")

local function playWorldCollectBurst(part)
	if not getClientSetting("Popups", true) then
		return
	end
	if not part or not part.Parent or not part:IsA("BasePart") then
		return
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "CollectBurst"
	attachment.Parent = part

	local particles = Instance.new("ParticleEmitter")
	particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	particles.Color = ColorSequence.new(part.Color, Color3.new(1, 1, 1))
	particles.LightEmission = 0.8
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	particles.Speed = NumberRange.new(8, 16)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Lifetime = NumberRange.new(0.35, 0.65)
	particles.Rate = 0
	particles.Parent = attachment
	particles:Emit(getClientSetting("LowFX", false) and 8 or 28)

	Debris:AddItem(attachment, 1)
end

local function showCollectFeedback(success, amount, message)
	if success and amount and amount > 0 then
		playWorldCollectBurst(pendingCollectPart)
	end
	pendingCollectPart = nil

	local text
	local color

	if success then
		if amount and amount > 0 then
			text = "+" .. amount .. " COINS"
			color = Color3.fromRGB(255, 220, 90)
		else
			text = message or "NO REWARD"
			color = Color3.fromRGB(255, 220, 90)
		end
	elseif message == "Slow down." or message == "Already collected." then
		return
	else
		text = message or "CAN'T COLLECT"
		color = Color3.fromRGB(255, 110, 140)
	end

	if not getClientSetting("Popups", true) then
		return
	end
	if not feedbackGui then
		return
	end

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Size = UDim2.new(0, 170, 0, 36)
	label.Position = UDim2.new(0, mouse.X, 0, mouse.Y - 24)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.LuckiestGuy
	label.TextSize = 22
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(35, 38, 45)
	label.Text = text
	label.ZIndex = 100
	label.Parent = feedbackGui

	TweenService:Create(label, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = label.Position - UDim2.new(0, 0, 0, 42),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()

	task.delay(0.5, function()
		if label and label.Parent then
			label:Destroy()
		end
	end)
end

-- ========================
--   HOVER OUTLINE
-- ========================
local currentHover = nil
local currentHighlights = {}

local function clearHighlight()
	for _, hl in ipairs(currentHighlights) do
		if hl and hl.Parent then
			hl:Destroy()
		end
	end
	table.clear(currentHighlights)
	currentHover = nil
end

local function addHoverHighlight(adornee)
	local hl = Instance.new("Highlight")
	hl.Name = "HoverHighlight"
	hl.FillColor = Color3.fromRGB(255, 255, 255)
	hl.OutlineColor = Color3.fromRGB(255, 255, 255)
	hl.FillTransparency = 0.82
	hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Adornee = adornee
	hl.Parent = adornee
	table.insert(currentHighlights, hl)
end

local function setHighlight(part)
	if currentHover == part then
		return
	end
	clearHighlight()
	if not part then
		return
	end

	addHoverHighlight(part)
	for _, child in ipairs(part:GetDescendants()) do
		if child:IsA("BasePart") and child:GetAttribute("PuddleDetail") and child.Transparency < 1 then
			addHoverHighlight(child)
		end
	end

	currentHover = part
end

-- Update hover every frame
RunService.Heartbeat:Connect(function()
	local target = mouse.Target
	if not target then
		clearHighlight()
		return
	end

	local char = player.Character
	if not char then
		return
	end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	-- Only highlight breakables that are in range
	if target:GetAttribute("BreakableType") then
		local dist = (root.Position - target.Position).Magnitude
		if dist <= getHoverRange() then
			setHighlight(target)
			return
		end
	end

	clearHighlight()
end)

-- ========================
--   CLICK TO BREAK / HATCH
-- ========================
mouse.Button1Down:Connect(function()
	local target = mouse.Target
	if not target then
		return
	end

	if target:GetAttribute("BreakableType") then
		if hasPaintToolEquipped() then
			return
		end
		pendingCollectPart = target
		collectEvent:FireServer(target)
	elseif target:GetAttribute("EggId") then
		openEggShopEvent:Fire(target:GetAttribute("EggId"))
	end
end)

collectEvent.OnClientEvent:Connect(showCollectFeedback)
