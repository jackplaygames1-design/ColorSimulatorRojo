-- Hooks baked mutation station parts. The station unlocks mutation rolls; it does not build map geometry.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Events = ReplicatedStorage:WaitForChild("Events")
local ColorMutationData = require(ReplicatedStorage:WaitForChild("ColorMutationData"))
local remote = Events:FindFirstChild("MutationStation")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "MutationStation"
	remote.Parent = Events
end

local noticeEvent = Events:FindFirstChild("WildBuffNotice")
local dataDirtyEvent = Events:FindFirstChild("PlayerDataDirty")

local PROMPT_NAME = "MutationStationPrompt"
local TOUCH_COOLDOWN = 1.35
local NEAR_DISTANCE = 34
local hooked = {}
local pads = {}
local lastTouchedAt = {}

local function getCharacterRoot(player)
	local character = player and player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function getPlayerFromTouchedPart(part)
	local character = part and part.Parent
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end
	return Players:GetPlayerFromCharacter(character)
end

local function isPointInside(part, position, margin)
	local localPoint = part.CFrame:PointToObjectSpace(position)
	local half = part.Size * 0.5 + Vector3.new(margin, margin, margin)
	return math.abs(localPoint.X) <= half.X
		and math.abs(localPoint.Y) <= half.Y
		and math.abs(localPoint.Z) <= half.Z
end

local function isLikelyMutationStation(part)
	if not part or not part:IsA("BasePart") then
		return false
	end
	if part:GetAttribute("MutationUnlockStation") == true
		or part:GetAttribute("MutationStation") == true
		or part:GetAttribute("FeatureUnlock") == "Mutations"
	then
		return true
	end

	local lowerName = string.lower(part.Name or "")
	if string.find(lowerName, "mutation", 1, true) or string.find(lowerName, "mutate", 1, true) then
		return true
	end

	local interior = part:FindFirstAncestor("OrangeSectorInterior")
	if not interior then
		return false
	end

	local color = part.Color
	local isBrightPink = color.R > 0.78 and color.B > 0.72 and color.G < 0.48
	local isFlatPad = part.Size.X >= 10 and part.Size.Z >= 10 and part.Size.Y <= 4
	return isBrightPink and isFlatPad
end

local function ensureProgressBool(player, name)
	local folder = player:FindFirstChild("TutorialProgress")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "TutorialProgress"
		folder.Parent = player
	end

	local value = folder:FindFirstChild(name)
	if not value then
		value = Instance.new("BoolValue")
		value.Name = name
		value.Parent = folder
	end
	return value
end

local function ensureProgressValues(player)
	return ensureProgressBool(player, "MutationsUnlocked"), ensureProgressBool(player, "HasSeenMutationTutorial")
end

local function getUnlocked(player)
	local progress = player and player:FindFirstChild("TutorialProgress")
	local value = progress and progress:FindFirstChild("MutationsUnlocked")
	return value and value:IsA("BoolValue") and value.Value == true
end

local function getHasSeenTutorial(player)
	local progress = player and player:FindFirstChild("TutorialProgress")
	local value = progress and progress:FindFirstChild("HasSeenMutationTutorial")
	return value and value:IsA("BoolValue") and value.Value == true
end

local function makeState(player, justUnlocked)
	return {
		unlocked = getUnlocked(player),
		justUnlocked = justUnlocked == true,
		hasSeenTutorial = getHasSeenTutorial(player),
		title = "Mutation Core",
		description = "Mutations are now active for future hatches.",
		detail = "New hatches can roll rare Dark, Light, or Corrupted Color variants. Mutation names appear in hatch results and inventory.",
	}
end

local function notify(player, message, color)
	if noticeEvent and noticeEvent:IsA("RemoteEvent") then
		noticeEvent:FireClient(player, {
			type = "message",
			message = message,
			color = color or Color3.fromRGB(255, 92, 235),
		})
	end
end

local function markDirty(player)
	if dataDirtyEvent and dataDirtyEvent:IsA("BindableEvent") then
		dataDirtyEvent:Fire(player, "tutorial-progress")
	end
end

local function unlockForPlayer(player)
	local value, seenTutorial = ensureProgressValues(player)
	local justUnlocked = false
	if value.Value ~= true then
		value.Value = true
		justUnlocked = true
		player:SetAttribute("MutationsUnlocked", true)
		markDirty(player)
		notify(player, "Mutations unlocked!", Color3.fromRGB(255, 92, 235))
	else
		player:SetAttribute("MutationsUnlocked", true)
	end

	local state = makeState(player, justUnlocked)
	if seenTutorial.Value ~= true then
		remote:FireClient(player, "ShowUnlocked", state)
	else
		if not justUnlocked then
			notify(player, "Mutations are already unlocked.", Color3.fromRGB(154, 80, 255))
		end
		remote:FireClient(player, "OpenIndex", state)
	end
	return justUnlocked
end

local function isNearAnyPad(player)
	local root = getCharacterRoot(player)
	if not root then
		return false
	end

	for pad in pairs(pads) do
		if pad.Parent and (root.Position - pad.Position).Magnitude <= NEAR_DISTANCE then
			return true
		end
	end
	return false
end

local function handlePlayer(player, pad)
	if not player or not player.Parent then
		return
	end
	if pad and pad.Parent then
		local root = getCharacterRoot(player)
		if not root or (root.Position - pad.Position).Magnitude > NEAR_DISTANCE then
			return
		end
	elseif not isNearAnyPad(player) then
		return
	end

	local now = os.clock()
	if lastTouchedAt[player] and now - lastTouchedAt[player] < TOUCH_COOLDOWN then
		return
	end
	lastTouchedAt[player] = now
	unlockForPlayer(player)
end

local function configurePad(part)
	if not isLikelyMutationStation(part) or hooked[part] then
		return
	end

	hooked[part] = true
	pads[part] = true
	part:SetAttribute("MutationStation", true)
	part:SetAttribute("MutationUnlockStation", true)
	part:SetAttribute("FeatureUnlock", "Mutations")
	part:SetAttribute("ColorZone", false)
	part.CanTouch = true
	part.CanQuery = true

	local prompt = part:FindFirstChild(PROMPT_NAME)
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = PROMPT_NAME
		prompt.ObjectText = "Mutation Core"
		prompt.ActionText = "Unlock Mutations"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt.Parent = part
	end
	prompt.Triggered:Connect(function(player)
		handlePlayer(player, part)
	end)

	part.Touched:Connect(function(hit)
		local player = getPlayerFromTouchedPart(hit)
		if player then
			handlePlayer(player, part)
		end
	end)
end

local function configureExisting()
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("BasePart") then
			configurePad(obj)
		end
	end
end

remote.OnServerEvent:Connect(function(player, action, value)
	if action == "Get" then
		remote:FireClient(player, "State", makeState(player, false))
	elseif action == "Unlock" then
		if isNearAnyPad(player) then
			unlockForPlayer(player)
		end
	elseif action == "MarkTutorialSeen" then
		local unlocked, seenTutorial = ensureProgressValues(player)
		if unlocked.Value == true and seenTutorial.Value ~= true then
			seenTutorial.Value = true
			markDirty(player)
		end
	elseif RunService:IsStudio() and action == "DebugUnlock" then
		local _, seenTutorial = ensureProgressValues(player)
		seenTutorial.Value = false
		markDirty(player)
		unlockForPlayer(player)
	elseif RunService:IsStudio() and action == "DebugResetTutorial" then
		local unlocked, seenTutorial = ensureProgressValues(player)
		seenTutorial.Value = false
		markDirty(player)
		if unlocked.Value == true then
			remote:FireClient(player, "ShowUnlocked", makeState(player, false))
		end
	elseif RunService:IsStudio() and action == "DebugForceMutation" then
		local mutationId = ColorMutationData.normalize(value)
		if mutationId ~= ColorMutationData.NoneId then
			player:SetAttribute("ForceNextMutation", mutationId)
			player:SetAttribute("ForceMutationsUnlocked", true)
			notify(player, "Next hatch mutation forced: " .. mutationId, ColorMutationData.get(mutationId).TypeColor)
		end
	end
end)

Players.PlayerAdded:Connect(function(player)
	task.defer(function()
		local value = ensureProgressValues(player)
		player:SetAttribute("MutationsUnlocked", value.Value == true)
		value:GetPropertyChangedSignal("Value"):Connect(function()
			player:SetAttribute("MutationsUnlocked", value.Value == true)
		end)
	end)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.defer(function()
		local value = ensureProgressValues(player)
		player:SetAttribute("MutationsUnlocked", value.Value == true)
		value:GetPropertyChangedSignal("Value"):Connect(function()
			player:SetAttribute("MutationsUnlocked", value.Value == true)
		end)
	end)
end

Players.PlayerRemoving:Connect(function(player)
	lastTouchedAt[player] = nil
end)

configureExisting()
Workspace.DescendantAdded:Connect(function(obj)
	if obj:IsA("BasePart") then
		task.defer(configurePad, obj)
	end
end)

task.spawn(function()
	while true do
		task.wait(0.5)
		for pad in pairs(pads) do
			if not pad.Parent then
				pads[pad] = nil
			else
				for _, player in ipairs(Players:GetPlayers()) do
					local root = getCharacterRoot(player)
					if root and isPointInside(pad, root.Position, 3) then
						handlePlayer(player, pad)
					end
				end
			end
		end
	end
end)
