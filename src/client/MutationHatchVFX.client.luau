-- Disabled: no PlayerGui UI should be created at runtime.
if true then
	return
end

-- Adds an extra visual burst whenever a hatched Color has a mutation.
-- This is intentionally separate from EggShopUI so the existing hatch animation stays editable/stable.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ColorMutationData = require(ReplicatedStorage:WaitForChild("ColorMutationData"))
local Events = ReplicatedStorage:WaitForChild("Events")
local hatchEvent = Events:WaitForChild("HatchEgg")

local gui = Instance.new("ScreenGui")
gui.Name = "MutationHatchVFX"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 950
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local function isMutationId(value)
	if type(value) ~= "string" then
		return false
	end
	return ColorMutationData.isMutated(value)
end

local function findMutationPayload(...)
	local visited = {}

	local function scan(value, depth)
		if depth > 5 then
			return nil
		end

		if type(value) ~= "table" then
			return nil
		end
		if visited[value] then
			return nil
		end
		visited[value] = true

		local mutationId = value.mutationId
			or value.MutationId
			or value.mutation
			or value.Mutation
			or value.mutationName
			or value.MutationName

		if value.hasMutation == true or value.HasMutation == true or isMutationId(mutationId) then
			mutationId = ColorMutationData.normalize(mutationId or value.mutationName or value.MutationName)
			local mutation = ColorMutationData.get(mutationId)
			if mutation and mutation.IsMutation then
				return {
					id = mutation.Id,
					name = value.mutationName or value.MutationName or mutation.DisplayName,
					typeName = value.mutationType or value.MutationType or mutation.Type,
					rarity = value.mutationRarity or value.MutationRarity or mutation.Rarity,
					description = value.mutationDescription or value.MutationDescription or mutation.Description,
					auraColor = value.mutationAuraColor or value.MutationAuraColor or value.auraColor or mutation.AuraColor,
					typeColor = value.mutationTypeColor or value.MutationTypeColor or mutation.TypeColor,
				}
			end
		end

		for _, child in pairs(value) do
			local found = scan(child, depth + 1)
			if found then
				return found
			end
		end

		return nil
	end

	for index = 1, select("#", ...) do
		local found = scan(select(index, ...), 1)
		if found then
			return found
		end
	end

	return nil
end

local function makeCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius or UDim.new(1, 0)
	corner.Parent = parent
	return corner
end

local function makeStroke(parent, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or 2
	stroke.Transparency = transparency or 0
	stroke.Parent = parent
	return stroke
end

local function showMutationBurst(payload)
	local accent = payload.typeColor or payload.auraColor or Color3.fromRGB(180, 80, 255)
	local aura = payload.auraColor or accent

	local holder = Instance.new("Frame")
	holder.Name = "MutationBurst"
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	holder.ZIndex = 1
	holder.Parent = gui

	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = accent
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = 1
	flash.Parent = holder

	local burst = Instance.new("Frame")
	burst.Name = "BurstRing"
	burst.AnchorPoint = Vector2.new(0.5, 0.5)
	burst.Position = UDim2.fromScale(0.5, 0.46)
	burst.Size = UDim2.fromOffset(80, 80)
	burst.BackgroundColor3 = aura
	burst.BackgroundTransparency = 0.45
	burst.BorderSizePixel = 0
	burst.ZIndex = 2
	burst.Parent = holder
	makeCorner(burst, UDim.new(1, 0))
	makeStroke(burst, Color3.new(1, 1, 1), 5, 0.1)

	local inner = Instance.new("Frame")
	inner.Name = "InnerGlow"
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.fromScale(0.62, 0.62)
	inner.BackgroundColor3 = Color3.new(1, 1, 1)
	inner.BackgroundTransparency = 0.35
	inner.BorderSizePixel = 0
	inner.ZIndex = 3
	inner.Parent = burst
	makeCorner(inner, UDim.new(1, 0))

	local banner = Instance.new("Frame")
	banner.Name = "Banner"
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.fromScale(0.5, 0.68)
	banner.Size = UDim2.fromOffset(520, 118)
	banner.BackgroundColor3 = Color3.fromRGB(24, 26, 36)
	banner.BackgroundTransparency = 0.08
	banner.BorderSizePixel = 0
	banner.ZIndex = 5
	banner.Parent = holder
	makeCorner(banner, UDim.new(0, 22))
	makeStroke(banner, accent, 5, 0)

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -36, 0, 44)
	title.Position = UDim2.new(0, 18, 0, 12)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.LuckiestGuy
	title.Text = "MUTATION HATCHED!"
	title.TextScaled = true
	title.TextColor3 = accent
	title.TextStrokeTransparency = 0
	title.TextStrokeColor3 = Color3.fromRGB(5, 5, 8)
	title.ZIndex = 6
	title.Parent = banner

	local name = Instance.new("TextLabel")
	name.Name = "MutationName"
	name.Size = UDim2.new(1, -36, 0, 34)
	name.Position = UDim2.new(0, 18, 0, 57)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBlack
	name.Text = string.upper(tostring(payload.rarity or "") .. " " .. tostring(payload.typeName or "") .. " • " .. tostring(payload.name or "Mutation"))
	name.TextScaled = true
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.45
	name.TextStrokeColor3 = Color3.fromRGB(5, 5, 8)
	name.ZIndex = 6
	name.Parent = banner

	local desc = Instance.new("TextLabel")
	desc.Name = "Description"
	desc.Size = UDim2.new(1, -36, 0, 20)
	desc.Position = UDim2.new(0, 18, 1, -26)
	desc.BackgroundTransparency = 1
	desc.Font = Enum.Font.GothamBold
	desc.Text = tostring(payload.description or "Special mutated Color bonus.")
	desc.TextScaled = true
	desc.TextColor3 = Color3.fromRGB(230, 235, 255)
	desc.TextTransparency = 0.1
	desc.ZIndex = 6
	desc.Parent = banner

	TweenService:Create(flash, TweenInfo.new(0.12), { BackgroundTransparency = 0.28 }):Play()
	TweenService:Create(flash, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(burst, TweenInfo.new(0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(390, 390),
		BackgroundTransparency = 0.82,
	}):Play()
	TweenService:Create(banner, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(560, 128),
	}):Play()

	for i = 1, 28 do
		local particle = Instance.new("Frame")
		particle.Name = "MutationSpark"
		particle.AnchorPoint = Vector2.new(0.5, 0.5)
		particle.Position = UDim2.fromScale(0.5, 0.46)
		local size = math.random(7, 16)
		particle.Size = UDim2.fromOffset(size, size)
		particle.BackgroundColor3 = i % 3 == 0 and Color3.new(1, 1, 1) or accent:Lerp(aura, math.random())
		particle.BackgroundTransparency = 0.05
		particle.BorderSizePixel = 0
		particle.Rotation = math.random(0, 360)
		particle.ZIndex = 4
		particle.Parent = holder
		makeCorner(particle, UDim.new(0, math.random(3, 8)))

		local angle = math.rad((360 / 28) * i + math.random(-16, 16))
		local dist = math.random(145, 310)
		local x = math.cos(angle) * dist
		local y = math.sin(angle) * dist
		TweenService:Create(particle, TweenInfo.new(math.random(52, 88) / 100, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, x, 0.46, y),
			BackgroundTransparency = 1,
			Rotation = particle.Rotation + math.random(-180, 180),
		}):Play()
	end

	Debris:AddItem(holder, 2.8)
end

hatchEvent.OnClientEvent:Connect(function(success, ...)
	if success == false then
		return
	end

	local payload = findMutationPayload(...)
	if payload then
		showMutationBurst(payload)
	end
end)

print("MutationHatchVFX ready")
