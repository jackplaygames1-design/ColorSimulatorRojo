local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Events = ReplicatedStorage:WaitForChild("Events")
local rewardEvent = Events:WaitForChild("BreakableRewardVFX")
local announcementEvent = Events:WaitForChild("BreakableAnnouncement")

local function getRoot()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function makeOrb(kind, position, color)
	local orb = Instance.new("Part")
	orb.Name = "BreakableReward_" .. kind
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.new(0.55, 0.55, 0.55)
	orb.CFrame = CFrame.new(position)
	orb.Anchored = true
	orb.CanCollide = false
	orb.CanTouch = false
	orb.CanQuery = false
	orb.CastShadow = false
	orb.Material = Enum.Material.Neon
	orb.Color = color
	orb.Parent = Workspace
	return orb
end

local function flyOrb(orb, index)
	local root = getRoot()
	if not root then
		orb:Destroy()
		return
	end
	local spread = Vector3.new(math.random(-6, 6), math.random(3, 8), math.random(-6, 6))
	local popTween = TweenService:Create(orb, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = orb.Position + spread,
	})
	popTween:Play()
	task.delay(0.18 + index * 0.018, function()
		if not orb or not orb.Parent then
			return
		end
		local target = root.Position + Vector3.new(0, 2, 0)
		TweenService:Create(orb, TweenInfo.new(0.48, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = target,
			Transparency = 1,
			Size = Vector3.new(0.12, 0.12, 0.12),
		}):Play()
		Debris:AddItem(orb, 0.55)
	end)
end

local function spawnRewardVfx(payload)
	if type(payload) ~= "table" or typeof(payload.Position) ~= "Vector3" then
		return
	end
	local rewards = payload.Rewards or {}
	local drops = {}
	local function append(kind, amount, color, divisor)
		amount = math.floor(tonumber(amount) or 0)
		if amount <= 0 then
			return
		end
		local count = math.clamp(math.ceil(amount / divisor), 1, 8)
		for _ = 1, count do
			table.insert(drops, {
				Kind = kind,
				Color = color,
			})
		end
	end
	append("Coin", rewards.Coins, Color3.fromRGB(255, 210, 65), 150)
	append("Gem", rewards.Gems, Color3.fromRGB(70, 255, 145), 45)
	append(
		tostring(payload.ColorType or "Color"),
		rewards.ColorAmount or rewards.Red,
		payload.Color or Color3.fromRGB(255, 50, 55),
		120
	)
	for _, item in ipairs(rewards.Items or {}) do
		append(tostring(item.ItemId or "Item"), item.Amount, Color3.fromRGB(170, 80, 255), 1)
	end

	local maxDrops = 20
	for i = 1, math.min(#drops, maxDrops) do
		local drop = drops[i]
		local orb = makeOrb(drop.Kind, payload.Position + Vector3.new(0, 2, 0), drop.Color)
		flyOrb(orb, i)
	end
end

local function announce(payload)
	local text = type(payload) == "table" and tostring(payload.Text or "") or tostring(payload or "")
	if text == "" then
		return
	end
	local ok = pcall(function()
		local channel = TextChatService.TextChannels and TextChatService.TextChannels:FindFirstChild("RBXGeneral")
		if channel then
			channel:DisplaySystemMessage('<font color="#ff4545">' .. text .. "</font>")
		else
			error("No text channel")
		end
	end)
	if not ok then
		pcall(function()
			StarterGui:SetCore("ChatMakeSystemMessage", {
				Text = text,
				Color = Color3.fromRGB(255, 70, 80),
			})
		end)
	end
end

rewardEvent.OnClientEvent:Connect(spawnRewardVfx)
announcementEvent.OnClientEvent:Connect(announce)

print("BreakableVFXClient ready")
