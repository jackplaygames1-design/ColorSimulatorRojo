-- Single client UI root and legacy UI cleanup for Color Simulator.
local ClientUIRoot = {}

local UI_SCREEN_NAME = "ClientUIRoot"
local LEGACY_GENERATED_UI_SCREEN_NAME = "ColorSimulatorUI"
local UI_VERSION = "PublicBeta_UI_SINGLE_SOURCE_v2"
local CLIENT_VERSION = "PublicBeta_MobileSectors_2026_05_08"

local rootByPlayerGui = setmetatable({}, { __mode = "k" })
local watchedPlayerGuis = setmetatable({}, { __mode = "k" })
local printedClientVersion = false
local warnedLegacy = {}

local LEGACY_SCREEN_GUI_NAMES = {
	ColorSimulatorUI = true,
	MainMenu = true,
	MenuUI = true,
	MenuGui = true,
	MainGui = true,
	HudGui = true,
	OldHudUI = true,
	OldMenuUI = true,
	OldMenuGui = true,
	Inventory = true,
	InventoryUI = true,
	InventoryGui = true,
	OldInventory = true,
	OldInventoryUI = true,
	MainInventory = true,
	MainInventoryUI = true,
	GamepassGui = true,
	PetInventoryUI = true,
	LegacyPetInventoryUI_DISABLED = true,
	EquipmentShopUI = true,
	SocialPanelUI = true,
	SocialPanelsUI = true,
}

local function warnLegacyOnce(name)
	if warnedLegacy[name] then
		return
	end
	warnedLegacy[name] = true
	warn("WARNING: Legacy UI source attempted to load")
	warn("Legacy UI source disabled: " .. name)
end

local function cleanupLegacyRoots(playerGui)
	for _, child in ipairs(playerGui:GetChildren()) do
		if child:IsA("ScreenGui") and child.Name ~= UI_SCREEN_NAME then
			if child:GetAttribute("LegacyUI") == true
				or LEGACY_SCREEN_GUI_NAMES[child.Name]
				or child.Name == LEGACY_GENERATED_UI_SCREEN_NAME
			then
				warnLegacyOnce(child.Name)
				child:Destroy()
			end
		end
	end
end

local function getCurrentRoot(playerGui)
	local currentRoot = nil
	for _, child in ipairs(playerGui:GetChildren()) do
		if child:IsA("ScreenGui") and child.Name == UI_SCREEN_NAME then
			if not currentRoot then
				currentRoot = child
			else
				warnLegacyOnce(child.Name)
				child:Destroy()
			end
		end
	end

	return currentRoot
end

function ClientUIRoot.GetRoot(playerGui)
	if not playerGui then
		return nil
	end

	cleanupLegacyRoots(playerGui)
	if not watchedPlayerGuis[playerGui] then
		watchedPlayerGuis[playerGui] = true
		playerGui.ChildAdded:Connect(function(child)
			if child:IsA("ScreenGui") then
				task.defer(function()
					if child.Parent ~= playerGui then
						return
					end
					if child.Name ~= UI_SCREEN_NAME then
						if child:GetAttribute("LegacyUI") == true
							or LEGACY_SCREEN_GUI_NAMES[child.Name]
							or child.Name == LEGACY_GENERATED_UI_SCREEN_NAME
						then
							warnLegacyOnce(child.Name)
							child:Destroy()
						end
					else
						child:SetAttribute("CurrentColorSimulatorUI", true)
						child:SetAttribute("UIScreenVersion", UI_VERSION)
						rootByPlayerGui[playerGui] = child
					end
				end)
			end
		end)
	end

	local root = rootByPlayerGui[playerGui]
	if root and root.Parent == playerGui then
		return root
	end

	root = getCurrentRoot(playerGui)
	if not root then
		local waitedRoot = playerGui:WaitForChild(UI_SCREEN_NAME, 10)
		if waitedRoot and waitedRoot:IsA("ScreenGui") then
			root = waitedRoot
		else
			warn("ClientUIRoot: PlayerGui.ClientUIRoot is missing; runtime ScreenGui creation is disabled.")
			return nil
		end
	end

	root:SetAttribute("CurrentColorSimulatorUI", true)
	root:SetAttribute("UIScreenVersion", UI_VERSION)
	playerGui:SetAttribute("CurrentColorSimulatorUI", true)
	playerGui:SetAttribute("UIScreenVersion", UI_VERSION)

	if not printedClientVersion then
		printedClientVersion = true
		print("Color Simulator Client Version: " .. CLIENT_VERSION)
		print("Color Simulator UI Loaded: " .. UI_VERSION)
	end

	rootByPlayerGui[playerGui] = root
	return root
end

function ClientUIRoot.GetLayer(playerGui, layerName)
	local root = ClientUIRoot.GetRoot(playerGui)
	if not root then
		return nil
	end

	local layer = root:FindFirstChild(layerName)
	if layer and not layer:IsA("Frame") then
		layer:Destroy()
		layer = nil
	end

	if not layer then
		layer = Instance.new("Frame")
		layer.Name = layerName
		layer.Size = UDim2.fromScale(1, 1)
		layer.BackgroundTransparency = 1
		layer.BorderSizePixel = 0
		layer.Active = false
		layer.Parent = root
	else
		for _, child in ipairs(layer:GetChildren()) do
			child:Destroy()
		end
	end

	layer:SetAttribute("UIScreenVersion", UI_VERSION)
	return layer
end

return ClientUIRoot
