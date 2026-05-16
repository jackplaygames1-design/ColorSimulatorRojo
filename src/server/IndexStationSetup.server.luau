-- Adds an interactable prompt to the physical index station in the map.
local Workspace = game:GetService("Workspace")

local PROMPT_NAME = "IndexPrompt"
local STATION_NAMES = {
	index = true,
	collectionindex = true,
	indexstation = true,
}

local function isIndexStation(object)
	if not object then
		return false
	end
	if object:GetAttribute("IndexStation") == true then
		return true
	end
	local compactName = string.lower(string.gsub(object.Name or "", "%s+", ""))
	return STATION_NAMES[compactName] == true
end

local function findPromptHost(object)
	if not object then
		return nil
	end
	if object:IsA("BasePart") then
		return object
	end
	if object:IsA("Model") then
		if object.PrimaryPart then
			return object.PrimaryPart
		end
		return object:FindFirstChildWhichIsA("BasePart", true)
	end
	if object:IsA("Folder") then
		return object:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function ensurePrompt(object)
	if not isIndexStation(object) then
		return
	end

	local host = findPromptHost(object)
	if not host then
		return
	end

	local prompt = host:FindFirstChild(PROMPT_NAME)
	if prompt and not prompt:IsA("ProximityPrompt") then
		prompt:Destroy()
		prompt = nil
	end
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = PROMPT_NAME
		prompt.Parent = host
	end

	prompt.ActionText = "Open"
	prompt.ObjectText = "Collection Index"
	prompt.HoldDuration = 0.05
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt:SetAttribute("IndexStationPrompt", true)
end

for _, object in ipairs(Workspace:GetDescendants()) do
	ensurePrompt(object)
end

Workspace.DescendantAdded:Connect(function(object)
	task.defer(ensurePrompt, object)
end)
