local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local AudioIds = require(ReplicatedStorage:WaitForChild("AudioIds"))

local SOUND_EVENT_NAME = "ColorSimulatorPlaySound"
local SOUND_FOLDER_NAME = "ColorSimulatorClientSounds"

local RNG = Random.new()
local player = Players.LocalPlayer
local lastPlayedAt = {}
local soundGroups = {}
local originalGroupVolumes = {}
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
		originalGroupVolumes[groupName] = group.Volume
	end
	for _, groupName in ipairs({ "MusicGroup", "SFXGroup" }) do
		local group = ensureSoundGroup(groupName)
		soundGroups[groupName] = group
		if originalGroupVolumes[groupName] == nil then
			originalGroupVolumes[groupName] = group.Volume
		end
	end
end

local function getClientSetting(key, defaultValue)
	local value = player:GetAttribute("Setting" .. key)
	return type(value) == "boolean" and value or defaultValue
end

local function applyAudioSettings()
	local musicEnabled = getClientSetting("Music", true)
	local sfxEnabled = getClientSetting("SoundEffects", true)

	for groupName, group in pairs(soundGroups) do
		local baseVolume = originalGroupVolumes[groupName]
			or (AudioIds.Groups and AudioIds.Groups[groupName] and AudioIds.Groups[groupName].Volume)
			or 1
		if groupName == "Ambience" or groupName == "MusicGroup" then
			group.Volume = musicEnabled and baseVolume or 0
		elseif groupName ~= "Master" then
			group.Volume = sfxEnabled and baseVolume or 0
		end
	end

	for _, container in ipairs({ SoundService, Workspace }) do
		for _, sound in ipairs(container:GetDescendants()) do
			if sound:IsA("Sound") and string.find(string.lower(sound.Name), "music", 1, true) then
				if sound:GetAttribute("SettingsOriginalVolume") == nil then
					sound:SetAttribute("SettingsOriginalVolume", sound.Volume)
				end
				sound.Volume = musicEnabled and (sound:GetAttribute("SettingsOriginalVolume") or 0.5) or 0
				if musicEnabled and not sound.Playing then
					pcall(function()
						sound:Play()
					end)
				end
			end
		end
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

local function getSoundConfig(categoryName, soundName)
	local category = AudioIds[categoryName]
	if type(category) ~= "table" then
		return nil
	end

	local entry = category[soundName]
	local soundId = entry
	local config = {}
	if type(entry) == "table" then
		config = entry
		soundId = entry.Id or entry.SoundId or entry.AssetId
	end

	local normalized = normalizeSoundId(soundId)
	if not normalized then
		return nil
	end

	return {
		SoundId = normalized,
		Volume = tonumber(config.Volume),
		PlaybackSpeed = tonumber(config.PlaybackSpeed),
		PlaybackSpeedVariance = tonumber(config.PlaybackSpeedVariance or config.Variance),
		RollOffMaxDistance = tonumber(config.RollOffMaxDistance),
		RollOffMinDistance = tonumber(config.RollOffMinDistance),
		EmitterSize = tonumber(config.EmitterSize),
	}
end

local function destroyAfterPlayback(sound)
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	Debris:AddItem(sound, math.max(3, sound.TimeLength + 2))
end

local function applySoundConfig(sound, config, categoryName)
	sound.SoundId = config.SoundId
	sound.Volume = config.Volume or AudioIds.Defaults.Volume or 0.65
	sound.SoundGroup = soundGroups[categoryName] or soundGroups.SFX or soundGroups.Master

	local playbackSpeed = config.PlaybackSpeed or 1
	local variance = config.PlaybackSpeedVariance or 0
	if variance > 0 then
		playbackSpeed += RNG:NextNumber(-variance, variance)
	end
	sound.PlaybackSpeed = math.max(0.05, playbackSpeed)
end

local function createSound(categoryName, soundName, parent)
	local config = getSoundConfig(categoryName, soundName)
	if not config then
		return nil
	end

	local sound = Instance.new("Sound")
	sound.Name = categoryName .. "_" .. tostring(soundName)
	applySoundConfig(sound, config, categoryName)
	sound.Parent = parent or soundFolder
	return sound
end

local SoundController = {}

local function shouldSkipDuplicate(categoryName, soundName)
	if categoryName ~= "UI" then
		return false
	end

	local cooldown = soundName == "Hover" and 0.08 or 0.04
	local key = tostring(categoryName) .. ":" .. tostring(soundName)
	local now = os.clock()
	if lastPlayedAt[key] and now - lastPlayedAt[key] < cooldown then
		return true
	end
	lastPlayedAt[key] = now
	return false
end

function SoundController.Play(categoryName, soundName)
	if shouldSkipDuplicate(categoryName, soundName) then
		return nil
	end

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

	local categoryName = nil
	local config = nil
	for _, candidate in ipairs({ "SFX", "Tools", "Currency", "Hatch" }) do
		config = getSoundConfig(candidate, name)
		if config then
			categoryName = candidate
			break
		end
	end
	if not config then
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
	applySoundConfig(sound, config, categoryName or "SFX")
	sound.RollOffMaxDistance = config.RollOffMaxDistance or AudioIds.Defaults.RollOffMaxDistance or 90
	sound.RollOffMinDistance = config.RollOffMinDistance or AudioIds.Defaults.RollOffMinDistance or 8
	sound.EmitterSize = config.EmitterSize or AudioIds.Defaults.EmitterSize or 8
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
applyAudioSettings()

player:GetAttributeChangedSignal("SettingMusic"):Connect(applyAudioSettings)
player:GetAttributeChangedSignal("SettingSoundEffects"):Connect(applyAudioSettings)
player:GetAttributeChangedSignal("SettingSFX"):Connect(applyAudioSettings)

ensureSoundEvent().Event:Connect(function(categoryName, soundName, position)
	if typeof(position) == "Vector3" then
		SoundController.PlayAtPosition(soundName, position)
	else
		SoundController.Play(categoryName, soundName)
	end
end)

print("SoundController: client sound groups ready")
