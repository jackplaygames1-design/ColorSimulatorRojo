local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local AudioIds = require(ReplicatedStorage:WaitForChild("AudioIds"))

local SOUND_EVENT_NAME = "ColorSimulatorPlaySound"
local SOUND_FOLDER_NAME = "ColorSimulatorClientSounds"

local soundGroups = {}
local soundFolder = SoundService:FindFirstChild(SOUND_FOLDER_NAME)
if not soundFolder then
	soundFolder = Instance.new("Folder")
	soundFolder.Name = SOUND_FOLDER_NAME
	soundFolder.Parent = SoundService
end

local function ensureSoundGroup(name)
	local existing = SoundService:FindFirstChild(name)
	if existing and existing:IsA("SoundGroup") then
		return existing
	end

	local group = Instance.new("SoundGroup")
	group.Name = name
	group.Parent = SoundService
	return group
end

local function setupSoundGroups()
	for groupName, config in pairs(AudioIds.Groups or {}) do
		local group = ensureSoundGroup(groupName)
		group.Volume = tonumber(config.Volume) or 1
		soundGroups[groupName] = group
	end
end

local function normalizeSoundId(soundId)
	if type(soundId) == "number" then
		if soundId <= 0 then
			return nil
		end
		return "rbxassetid://" .. tostring(soundId)
	end

	if type(soundId) ~= "string" then
		return nil
	end

	local trimmed = soundId:gsub("^%s+", ""):gsub("%s+$", "")
	if trimmed == "" or trimmed == "0" or trimmed == "rbxassetid://0" then
		return nil
	end
	if tonumber(trimmed) then
		return "rbxassetid://" .. trimmed
	end
	return trimmed
end

local function getSoundId(categoryName, soundName)
	local category = AudioIds[categoryName]
	if type(category) ~= "table" then
		return nil
	end
	return normalizeSoundId(category[soundName])
end

local function destroyAfterPlayback(sound)
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	Debris:AddItem(sound, math.max(3, sound.TimeLength + 2))
end

local function createSound(categoryName, soundName, parent)
	local soundId = getSoundId(categoryName, soundName)
	if not soundId then
		return nil
	end

	local sound = Instance.new("Sound")
	sound.Name = categoryName .. "_" .. tostring(soundName)
	sound.SoundId = soundId
	sound.Volume = AudioIds.Defaults.Volume or 0.65
	sound.SoundGroup = soundGroups[categoryName] or soundGroups.SFX or soundGroups.Master
	sound.Parent = parent or soundFolder
	return sound
end

local SoundController = {}

function SoundController.Play(categoryName, soundName)
	local sound = createSound(categoryName, soundName, soundFolder)
	if not sound then
		return nil
	end

	destroyAfterPlayback(sound)
	sound:Play()
	return sound
end

function SoundController.PlayUI(name)
	return SoundController.Play("UI", name)
end

function SoundController.PlaySFX(name)
	return SoundController.Play("SFX", name)
end

function SoundController.PlayCurrency(name)
	return SoundController.Play("Currency", name)
end

function SoundController.PlayHatch(name)
	return SoundController.Play("Hatch", name)
end

function SoundController.PlayTool(name)
	return SoundController.Play("Tools", name)
end

function SoundController.PlayAtPosition(name, position)
	if typeof(position) ~= "Vector3" then
		return nil
	end

	local soundId = getSoundId("SFX", name)
		or getSoundId("Tools", name)
		or getSoundId("Currency", name)
		or getSoundId("Hatch", name)
	if not soundId then
		return nil
	end

	local emitter = Instance.new("Part")
	emitter.Name = "ClientSoundEmitter"
	emitter.Anchored = true
	emitter.CanCollide = false
	emitter.CanQuery = false
	emitter.CanTouch = false
	emitter.Transparency = 1
	emitter.Size = Vector3.new(0.5, 0.5, 0.5)
	emitter.Position = position
	emitter.Parent = Workspace

	local sound = Instance.new("Sound")
	sound.Name = "Position_" .. tostring(name)
	sound.SoundId = soundId
	sound.Volume = AudioIds.Defaults.Volume or 0.65
	sound.RollOffMaxDistance = AudioIds.Defaults.RollOffMaxDistance or 90
	sound.RollOffMinDistance = AudioIds.Defaults.RollOffMinDistance or 8
	sound.EmitterSize = AudioIds.Defaults.EmitterSize or 8
	sound.SoundGroup = soundGroups.SFX or soundGroups.Master
	sound.Parent = emitter

	sound.Ended:Connect(function()
		emitter:Destroy()
	end)
	Debris:AddItem(emitter, math.max(3, sound.TimeLength + 2))
	sound:Play()
	return sound
end

local function ensureSoundEvent()
	local existing = ReplicatedStorage:FindFirstChild(SOUND_EVENT_NAME)
	if existing and existing:IsA("BindableEvent") then
		return existing
	end

	local event = Instance.new("BindableEvent")
	event.Name = SOUND_EVENT_NAME
	event.Parent = ReplicatedStorage
	return event
end

setupSoundGroups()

ensureSoundEvent().Event:Connect(function(categoryName, soundName, position)
	if typeof(position) == "Vector3" then
		SoundController.PlayAtPosition(soundName, position)
	else
		SoundController.Play(categoryName, soundName)
	end
end)

print("SoundController: client sound groups ready")
