-- Disabled: no PlayerGui UI should be created at runtime.
if true then
	return
end

-- Client-only feedback layer for the core loop: break Color, hatch, merge, unlock.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local ClientUIRoot = require(ReplicatedStorage:WaitForChild("ClientUIRoot"))

local Events = ReplicatedStorage:WaitForChild("Events")
local collectEvent = Events:WaitForChild("CollectColor")
local petBreakRewardEvent = Events:WaitForChild("PetBreakReward")
local hatchEvent = Events:WaitForChild("HatchEgg")
local mergeEvent = Events:WaitForChild("MergePet")
local unlockEvent = Events:WaitForChild("UnlockArea")
local hatchFocusActive = ReplicatedStorage:FindFirstChild("HatchFocusActive")
if not hatchFocusActive then
	hatchFocusActive = Instance.new("BoolValue")
	hatchFocusActive.Name = "HatchFocusActive"
	hatchFocusActive.Parent = ReplicatedStorage
end

local stats = player:WaitForChild("leaderstats")
local coins = stats:WaitForChild("Coins")

local UI_DARK = Color3.fromRGB(35, 38, 45)
local CYAN = Color3.fromRGB(118, 238, 244)
local YELLOW = Color3.fromRGB(255, 235, 105)
local GREEN = Color3.fromRGB(116, 245, 42)
local PINK = Color3.fromRGB(255, 24, 96)
local PURPLE = Color3.fromRGB(200, 120, 255)
local WHITE = Color3.fromRGB(255, 255, 255)
local ORANGE = Color3.fromRGB(255, 170, 70)

local SOUND_IDS = {
	collect = "rbxasset://sounds/button.wav",
	coins = "rbxasset://sounds/electronicpingshort.wav",
	hatch = "rbxasset://sounds/electronicpingshort.wav",
	merge = "rbxasset://sounds/button.wav",
	unlock = "rbxasset://sounds/electronicpingshort.wav",
}

local juiceGui = ClientUIRoot.GetLayer(playerGui, "CoreJuiceUI")

local function playSound(kind, volume, speed)
	local soundId = SOUND_IDS[kind]
	if not soundId then
		return
	end

	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.25
	sound.PlaybackSpeed = speed or 1
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 3)
end

local function getHudObject(name)
	local currentRoot = playerGui:FindFirstChild("ColorSimulatorUI")
	if currentRoot then
		local hud = currentRoot:FindFirstChild("HUD")
		if hud then
			local object = hud:FindFirstChild(name, true)
			if object then
				return object
			end
		end

		local legacyLayer = currentRoot:FindFirstChild("HudUI")
		if legacyLayer then
			return legacyLayer:FindFirstChild(name, true)
		end
	end

	local legacyRoot = playerGui:FindFirstChild("HudUI")
	return legacyRoot and legacyRoot:FindFirstChild(name, true) or nil
end

local function pulse(guiObject, peak)
	if not guiObject then
		return
	end

	local scale = guiObject:FindFirstChild("JuiceScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "JuiceScale"
		scale.Scale = 1
		scale.Parent = guiObject
	end

	TweenService:Create(scale, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Scale = peak or 1.08,
	}):Play()

	task.delay(0.08, function()
		if scale and scale.Parent then
			TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back), {
				Scale = 1,
			}):Play()
		end
	end)
end

local function makeFlash(color, transparency)
	local flash = Instance.new("Frame")
	flash.Size = UDim2.new(1, 0, 1, 0)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = transparency or 0.55
	flash.BorderSizePixel = 0
	flash.ZIndex = 300
	flash.Parent = juiceGui

	TweenService:Create(flash, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()

	Debris:AddItem(flash, 0.4)
end

local function burstAt(screenPos, color, count, spread)
	count = count or 12
	spread = spread or 60

	for i = 1, count do
		local dot = Instance.new("Frame")
		local size = math.random(7, 13)
		dot.Size = UDim2.new(0, size, 0, size)
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.new(0, screenPos.X, 0, screenPos.Y)
		dot.BackgroundColor3 = color
		dot.BorderSizePixel = 0
		dot.ZIndex = 250
		dot.Parent = juiceGui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = dot
		local stroke = Instance.new("UIStroke")
		stroke.Color = UI_DARK
		stroke.Thickness = 1
		stroke.Transparency = 0.25
		stroke.Parent = dot

		local angle = math.rad((360 / count) * i + math.random(-18, 18))
		local distance = math.random(math.floor(spread * 0.45), spread)
		local target = screenPos + Vector2.new(math.cos(angle) * distance, math.sin(angle) * distance)

		TweenService:Create(dot, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, target.X, 0, target.Y),
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 2, 0, 2),
		}):Play()

		task.delay(0.3, function()
			if stroke and stroke.Parent then
				TweenService:Create(stroke, TweenInfo.new(0.15), { Transparency = 1 }):Play()
			end
		end)
		Debris:AddItem(dot, 0.55)
	end
end

local function toast(text, color)
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Size = UDim2.new(0, 320, 0, 42)
	label.Position = UDim2.new(0.5, 0, 0.22, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.LuckiestGuy
	label.TextSize = 24
	label.TextColor3 = color or WHITE
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = UI_DARK
	label.Text = text
	label.ZIndex = 260
	label.Parent = juiceGui

	label.TextTransparency = 1
	label.TextStrokeTransparency = 1
	TweenService:Create(label, TweenInfo.new(0.16, Enum.EasingStyle.Back), {
		TextTransparency = 0,
		TextStrokeTransparency = 0,
		Position = UDim2.new(0.5, 0, 0.18, 0),
	}):Play()

	task.delay(1.1, function()
		if label and label.Parent then
			TweenService:Create(label, TweenInfo.new(0.2), {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
				Position = UDim2.new(0.5, 0, 0.14, 0),
			}):Play()
		end
	end)

	Debris:AddItem(label, 1.45)
end

local function ripple(button, color)
	if not button or not button:IsA("GuiButton") then
		return
	end

	local pos = UserInputService:GetMouseLocation()
	local absPos = button.AbsolutePosition
	local localX = pos.X - absPos.X
	local localY = pos.Y - absPos.Y
	local maxSize = math.max(button.AbsoluteSize.X, button.AbsoluteSize.Y) * 1.6

	local circle = Instance.new("Frame")
	circle.AnchorPoint = Vector2.new(0.5, 0.5)
	circle.Size = UDim2.new(0, 0, 0, 0)
	circle.Position = UDim2.new(0, localX, 0, localY)
	circle.BackgroundColor3 = color or WHITE
	circle.BackgroundTransparency = 0.55
	circle.BorderSizePixel = 0
	circle.ZIndex = button.ZIndex + 4
	circle.Active = false
	circle.Parent = button
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = circle

	TweenService:Create(circle, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, maxSize, 0, maxSize),
		BackgroundTransparency = 1,
	}):Play()

	Debris:AddItem(circle, 0.36)
end

local function buttonColor(button)
	if button:IsA("TextButton") or button:IsA("ImageButton") then
		return button.BackgroundColor3
	end
	return CYAN
end

local function enhanceButton(button)
	if not button:IsA("GuiButton") or button:GetAttribute("CoreJuiced") then
		return
	end
	button:SetAttribute("CoreJuiced", true)

	local scale = button:FindFirstChild("ButtonJuiceScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "ButtonJuiceScale"
		scale.Scale = 1
		scale.Parent = button
	end

	local function tweenScale(value, duration)
		if scale and scale.Parent then
			TweenService:Create(scale, TweenInfo.new(duration or 0.12, Enum.EasingStyle.Back), { Scale = value }):Play()
		end
	end

	button.MouseEnter:Connect(function()
		tweenScale(1.045, 0.12)
	end)

	button.MouseLeave:Connect(function()
		tweenScale(1, 0.12)
	end)

	button.MouseButton1Down:Connect(function()
		tweenScale(0.94, 0.06)
	end)

	button.MouseButton1Up:Connect(function()
		tweenScale(1.045, 0.1)
		task.delay(0.09, function()
			tweenScale(1, 0.12)
		end)
	end)

	button.Activated:Connect(function()
		local color = buttonColor(button)
		playSound("collect", 0.08, math.random(112, 124) / 100)
		ripple(button, color:Lerp(WHITE, 0.45))
		burstAt(UserInputService:GetMouseLocation(), color:Lerp(WHITE, 0.25), 5, 22)
	end)
end

local function enhancePanel(panel)
	if not panel:IsA("Frame") or panel:GetAttribute("CoreShine") then
		return
	end
	if panel:IsDescendantOf(juiceGui) then
		return
	end
	if not panel:FindFirstChildOfClass("UIStroke") then
		return
	end

	local name = string.lower(panel.Name)
	if not (string.find(name, "panel") or string.find(name, "popup") or string.find(name, "card")) then
		return
	end

	panel:SetAttribute("CoreShine", true)

	local shine = Instance.new("Frame")
	shine.Name = "CoreShineSweep"
	shine.Size = UDim2.new(0, 70, 1, 40)
	shine.Position = UDim2.new(0, -90, 0, -20)
	shine.BackgroundColor3 = WHITE
	shine.BackgroundTransparency = 0.7
	shine.BorderSizePixel = 0
	shine.Rotation = 14
	shine.ZIndex = panel.ZIndex + 2
	shine.Active = false
	shine.Parent = panel
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = shine

	task.spawn(function()
		while shine.Parent do
			task.wait(math.random(18, 32) / 10)
			if panel.Visible then
				shine.Position = UDim2.new(0, -90, 0, -20)
				TweenService:Create(shine, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Position = UDim2.new(1, 30, 0, -20),
				}):Play()
			end
		end
	end)
end

local function enhanceExistingGui(root)
	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("GuiButton") then
			enhanceButton(obj)
		elseif obj:IsA("Frame") then
			enhancePanel(obj)
		end
	end
end

task.defer(function()
	enhanceExistingGui(playerGui)
end)

playerGui.DescendantAdded:Connect(function(obj)
	task.defer(function()
		if obj:IsA("GuiButton") then
			enhanceButton(obj)
		elseif obj:IsA("Frame") then
			enhancePanel(obj)
		end
	end)
end)

collectEvent.OnClientEvent:Connect(function(success, amount)
	if not success or not amount or amount <= 0 then
		return
	end

	playSound("collect", 0.18, math.random(96, 110) / 100)
	pulse(getHudObject("CoinsRow") or getHudObject("CoinPill"), 1.04)
	burstAt(UserInputService:GetMouseLocation(), CYAN, 8, 42)
end)

local lastCoins = coins.Value
local lastCoinJuiceAt = 0
local petRewardCoinsToSuppress = 0
local lastPetRewardAt = 0

local function playCoinJuice()
	local now = os.clock()
	if now - lastCoinJuiceAt < 0.45 then
		return
	end
	lastCoinJuiceAt = now

	pulse(getHudObject("CoinsRow") or getHudObject("CoinPill"), 1.08)
end

coins:GetPropertyChangedSignal("Value"):Connect(function()
	local oldCoins = lastCoins
	local gained = coins.Value - oldCoins
	if gained > 0 then
		pulse(getHudObject("CoinsRow") or getHudObject("CoinPill"), 1.05)
		local suppressForPet = false
		if petRewardCoinsToSuppress > 0 and os.clock() - lastPetRewardAt < 2 then
			local consumed = math.min(petRewardCoinsToSuppress, gained)
			petRewardCoinsToSuppress -= consumed
			suppressForPet = consumed > 0
		end
		if not suppressForPet then
			playCoinJuice()
		end
	end
	lastCoins = coins.Value
end)

petBreakRewardEvent.OnClientEvent:Connect(function(payload)
	local amount = 0
	if type(payload) == "table" then
		amount = tonumber(payload.Amount or payload.amount) or 0
	else
		amount = tonumber(payload) or 0
	end
	amount = math.floor(amount)
	if amount <= 0 then
		return
	end

	petRewardCoinsToSuppress += amount
	lastPetRewardAt = os.clock()
	pulse(getHudObject("CoinsRow") or getHudObject("CoinPill"), 1.05)
end)

local hatchToastToken = 0
hatchEvent.OnClientEvent:Connect(function(success, entry)
	if not success or not entry then
		return
	end

	hatchToastToken += 1
	local token = hatchToastToken
	task.delay(2.65, function()
		if token ~= hatchToastToken then
			return
		end

		playSound("hatch", 0.32, entry.rarity == "Legendary" and 0.9 or 1.12)
		local color = entry.rarity == "Legendary" and YELLOW
			or entry.rarity == "Epic" and PURPLE
			or entry.rarity == "Rare" and CYAN
			or WHITE
		makeFlash(color, entry.rarity == "Legendary" and 0.45 or 0.75)
		if hatchFocusActive.Value == true then
			return
		end
		local label = string.upper(entry.displayName or entry.baseName or "COLOR")
		if entry.traitName then
			label ..= " [" .. string.upper(entry.traitName) .. "]"
		elseif entry.trait then
			label ..= " [" .. string.upper(entry.trait.name) .. "]"
		end
		toast("HATCHED " .. label, color)
	end)
end)

mergeEvent.OnClientEvent:Connect(function(success, petId, result)
	if not success then
		return
	end

	playSound("merge", 0.3, 0.82)
	makeFlash(PURPLE, 0.65)
	toast("MERGE UPGRADE", PURPLE)
	burstAt(Vector2.new(workspace.CurrentCamera.ViewportSize.X / 2, workspace.CurrentCamera.ViewportSize.Y * 0.35), PURPLE, 18, 96)
end)

unlockEvent.OnClientEvent:Connect(function(kind, colorType, world)
	if kind ~= "unlocked" then
		return
	end

	playSound("unlock", 0.38, 0.82)
	makeFlash(GREEN, 0.55)
	toast((world and string.upper(world.name) or "SECTOR") .. " UNLOCKED", GREEN)
	burstAt(Vector2.new(workspace.CurrentCamera.ViewportSize.X / 2, workspace.CurrentCamera.ViewportSize.Y * 0.28), GREEN, 24, 130)
end)
