-- SocialPanelsUI.client.luau
if true then
	warn("SocialPanelsUI disabled; editable Codes/Settings windows are bound by EditorWindowBinder.")
	return
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local ClientUIRoot = require(ReplicatedStorage:WaitForChild("ClientUIRoot"))
local SettingsData = require(ReplicatedStorage:WaitForChild("SettingsData"))
local UIManager = require(ReplicatedStorage:WaitForChild("UIManager"))
local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))
local Events = ReplicatedStorage:FindFirstChild("Events")
local requestSetSettingEvent = Events and Events:FindFirstChild("RequestSetSetting") or nil
local settingsUpdatedEvent = Events and Events:FindFirstChild("SettingsUpdated") or nil

local DARK = UITheme.Colors.OutlineDark
local CYAN = UITheme.Colors.PrimaryCyan
local PINK = UITheme.Colors.ErrorRed
local LIME = UITheme.Colors.PrimaryGreen
local LAVENDER = UITheme.Colors.PanelLavender

local screenGui = ClientUIRoot.GetLayer(player.PlayerGui, "SocialPanelsUI")

local overlay = UITheme.CreateDimOverlay(screenGui, 50)

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 560, 0, 360)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.BackgroundColor3 = UITheme.Colors.PanelCream
panel.BorderSizePixel = 0
panel.Visible = false
panel.ZIndex = 60
panel.Parent = screenGui
UITheme.ApplyResponsiveScale(panel, 560, 360, 0.76, 28)

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 22)
corner.Parent = panel

local stroke = Instance.new("UIStroke")
stroke.Color = DARK
stroke.Thickness = 5
stroke.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -86, 0, 72)
title.Position = UDim2.new(0, 24, 0, 8)
title.BackgroundTransparency = 1
title.Font = Enum.Font.LuckiestGuy
title.TextSize = 34
title.TextColor3 = Color3.new(1, 1, 1)
title.TextStrokeTransparency = 0
title.TextStrokeColor3 = DARK
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 61
title.Parent = panel

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -54, 1, -110)
content.Position = UDim2.new(0, 27, 0, 90)
content.BackgroundTransparency = 1
content.ZIndex = 61
content.Parent = panel

local contentLayout = Instance.new("UIListLayout")
contentLayout.FillDirection = Enum.FillDirection.Vertical
contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
contentLayout.Padding = UDim.new(0, 8)
contentLayout.Parent = content

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 42, 0, 42)
closeBtn.Position = UDim2.new(1, -64, 0, 16)
closeBtn.BackgroundColor3 = PINK
closeBtn.Active = true
closeBtn.Font = Enum.Font.LuckiestGuy
closeBtn.TextSize = 28
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.TextStrokeTransparency = 0
closeBtn.TextStrokeColor3 = DARK
closeBtn.Text = "X"
closeBtn.ZIndex = 70
closeBtn.Parent = panel

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 12)
closeCorner.Parent = closeBtn
local closeStroke = Instance.new("UIStroke")
closeStroke.Color = DARK
closeStroke.Thickness = 4
closeStroke.Parent = closeBtn

local backBtn = Instance.new("TextButton")
backBtn.Size = UDim2.new(0, 42, 0, 42)
backBtn.Position = UDim2.new(0, 18, 0, 16)
backBtn.BackgroundColor3 = UITheme.Colors.PanelCream
backBtn.Font = Enum.Font.LuckiestGuy
backBtn.TextSize = 26
backBtn.TextColor3 = DARK
backBtn.TextStrokeTransparency = 1
backBtn.Text = "<"
backBtn.Visible = false
backBtn.ZIndex = 70
backBtn.Parent = panel
local backCorner = Instance.new("UICorner")
backCorner.CornerRadius = UDim.new(0, 12)
backCorner.Parent = backBtn
local backStroke = Instance.new("UIStroke")
backStroke.Color = DARK
backStroke.Thickness = 4
backStroke.Parent = backBtn

local currentName = nil
local isOpen = false
local openedFromMenu = false
local savedSettings = SettingsData.Normalize(nil)
local settingsLoaded = false
local pendingSettings = {}
local settingButtons = {}
local settingsStatusLabel = nil
local lastCloseRequestAt = 0

local SETTING_LABELS = {
	Music = "MUSIC",
	SFX = "SFX",
	Popups = "POPUPS",
	LowFX = "LOW FX",
}

local SETTING_ORDER = { "Music", "SFX", "Popups", "LowFX" }

local function isMusicSound(sound)
	local name = string.lower(sound.Name or "")
	return string.find(name, "music", 1, true)
		or string.find(name, "bgm", 1, true)
		or string.find(name, "theme", 1, true)
end

local function applyMusicSetting(enabled)
	for _, root in ipairs({ SoundService, workspace }) do
		for _, obj in ipairs(root:GetDescendants()) do
			if obj:IsA("Sound") and isMusicSound(obj) then
				if obj:GetAttribute("SettingsOriginalVolume") == nil then
					obj:SetAttribute("SettingsOriginalVolume", obj.Volume)
				end
				obj.Volume = enabled and (obj:GetAttribute("SettingsOriginalVolume") or 0.5) or 0
			end
		end
	end
end

local function applySettings(settings)
	savedSettings = SettingsData.Normalize(settings)
	settingsLoaded = true
	for key, value in pairs(savedSettings) do
		player:SetAttribute("Setting" .. key, value)
	end
	applyMusicSetting(savedSettings.Music)
	-- SFX/Popups/LowFX are read by the client systems that create those sounds/effects.
end

local function setSettingsStatus(text, color)
	if settingsStatusLabel then
		settingsStatusLabel.Text = text or ""
		settingsStatusLabel.TextColor3 = color or UITheme.Colors.TextMuted
	end
end

local function updateSettingButton(key)
	local button = settingButtons[key]
	if not button then
		return
	end

	local pending = pendingSettings[key] == true
	local value = savedSettings[key] == true
	button.Text = (SETTING_LABELS[key] or string.upper(key)) .. ": " .. (value and "ON" or "OFF")
	button.BackgroundColor3 = pending and LAVENDER or (value and CYAN or PINK)
	button.AutoButtonColor = settingsLoaded and requestSetSettingEvent ~= nil and not pending
end

local function updateAllSettingButtons()
	for _, key in ipairs(SETTING_ORDER) do
		updateSettingButton(key)
	end
end

local function readReplicatedSettings()
	local folder = player:FindFirstChild("Settings")
	if not folder then
		return false
	end

	local values = {}
	for key, defaultValue in pairs(SettingsData.Defaults) do
		local value = folder:FindFirstChild(key)
		values[key] = value and value:IsA("BoolValue") and value.Value or defaultValue
	end
	applySettings(values)
	updateAllSettingButtons()
	return true
end

local function clearContent()
	for _, child in ipairs(content:GetChildren()) do
		if child ~= contentLayout then
			child:Destroy()
		end
	end
end

local function makeLabel(text, size, color)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, size + 8)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = size
	label.TextColor3 = color or Color3.fromRGB(40, 48, 64)
	label.TextStrokeTransparency = 0.7
	label.TextStrokeColor3 = Color3.new(1, 1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.ZIndex = 62
	label.Parent = content
	return label
end

local function makeButton(text, color, onClick)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, 0, 0, 40)
	button.BackgroundColor3 = color
	button.AutoButtonColor = true
	button.Font = Enum.Font.LuckiestGuy
	button.TextSize = 28
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextStrokeTransparency = 0
	button.TextStrokeColor3 = DARK
	button.Text = text
	button.ZIndex = 62
	button.Parent = content
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color = DARK
	stroke.Thickness = 4
	stroke.Parent = button
	if onClick then
		button.MouseButton1Click:Connect(onClick)
	end
	return button
end

local function makeRow(left, right)
	local row = Instance.new("TextLabel")
	row.Size = UDim2.new(1, 0, 0, 34)
	row.BackgroundColor3 = Color3.fromRGB(236, 255, 253)
	row.Font = Enum.Font.GothamBold
	row.TextSize = 21
	row.TextColor3 = Color3.fromRGB(30, 36, 48)
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.Text = "  " .. left .. "    " .. right
	row.ZIndex = 62
	row.Parent = content
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = row
	local stroke = Instance.new("UIStroke")
	stroke.Color = DARK
	stroke.Thickness = 3
	stroke.Parent = row
	return row
end

local function buildContent(name)
	clearContent()

	if name == "Trading" then
		makeLabel("Trading is coming soon.", 24, CYAN)
		makeLabel("Trade Colors safely in a future update.", 17, UITheme.Colors.TextMuted)
		makeButton("COMING SOON", LAVENDER)
	elseif name == "Market" then
		makeLabel("Market is coming soon.", 24, CYAN)
		makeLabel("List rare Colors in a future update.", 17, UITheme.Colors.TextMuted)
		makeButton("COMING SOON", LAVENDER)
	elseif name == "Settings" then
		makeLabel("Options", 24, CYAN)
		table.clear(settingButtons)
		settingsStatusLabel =
			makeLabel(settingsLoaded and "Saved per player." or "Loading settings...", 16, UITheme.Colors.TextMuted)
		for _, key in ipairs(SETTING_ORDER) do
			local button = makeButton((SETTING_LABELS[key] or string.upper(key)) .. ": ...", LAVENDER, function()
				if not settingsLoaded or not requestSetSettingEvent then
					setSettingsStatus("Settings are still loading.", PINK)
					return
				end
				if pendingSettings[key] then
					return
				end

				local nextValue = not (savedSettings[key] == true)
				pendingSettings[key] = true
				updateSettingButton(key)
				setSettingsStatus("Saving " .. (SETTING_LABELS[key] or key) .. "...", UITheme.Colors.TextMuted)
				requestSetSettingEvent:FireServer(key, nextValue)

				task.delay(8, function()
					if pendingSettings[key] then
						pendingSettings[key] = nil
						updateSettingButton(key)
						setSettingsStatus("Setting save timed out. Try again.", PINK)
					end
				end)
			end)
			settingButtons[key] = button
			updateSettingButton(key)
		end
	end
end

local function openPanel(name, context)
	currentName = name
	isOpen = true
	openedFromMenu = context and context.from == "Menu" or false
	backBtn.Visible = openedFromMenu
	title.Position = openedFromMenu and UDim2.new(0, 72, 0, 8) or UDim2.new(0, 24, 0, 8)
	title.Size = openedFromMenu and UDim2.new(1, -134, 0, 72) or UDim2.new(1, -86, 0, 72)
	title.Text = string.upper(name)
	buildContent(name)
	overlay.Visible = true
	overlay.BackgroundTransparency = 1
	panel.Visible = true
	panel.Size = UDim2.new(0, 560, 0, 60)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	TweenService:Create(overlay, TweenInfo.new(0.18), {
		BackgroundTransparency = 0.4,
	}):Play()
	TweenService:Create(panel, TweenInfo.new(0.22, Enum.EasingStyle.Back), {
		Size = UDim2.new(0, 560, 0, 360),
		Position = UDim2.fromScale(0.5, 0.5),
	}):Play()
end

local function closePanel(name, context)
	if name and currentName ~= name then
		return
	end
	isOpen = false
	openedFromMenu = false
	backBtn.Visible = false
	if context and context.immediate then
		panel.Visible = false
		overlay.Visible = false
		overlay.BackgroundTransparency = 1
		currentName = nil
		return
	end
	TweenService:Create(overlay, TweenInfo.new(0.14), {
		BackgroundTransparency = 1,
	}):Play()
	TweenService:Create(panel, TweenInfo.new(0.14), {
		Size = UDim2.new(0, 0, 0, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0),
	}):Play()
	task.delay(0.14, function()
		if not isOpen then
			panel.Visible = false
			overlay.Visible = false
			currentName = nil
		end
	end)
end

local function requestClose()
	local now = os.clock()
	if now - lastCloseRequestAt < 0.12 then
		return
	end
	lastCloseRequestAt = now

	local name = currentName
	if name and UIManager.isRegistered(name) then
		UIManager.close(name)
	else
		closePanel()
	end
end

backBtn.MouseButton1Click:Connect(function()
	if openedFromMenu then
		UIManager.open("Menu")
	end
end)

closeBtn.Activated:Connect(requestClose)
closeBtn.MouseButton1Click:Connect(requestClose)

overlay.Activated:Connect(requestClose)
overlay.MouseButton1Click:Connect(requestClose)

if settingsUpdatedEvent then
	settingsUpdatedEvent.OnClientEvent:Connect(function(settings, success, settingKey, message)
		applySettings(settings)
		if settingKey then
			pendingSettings[settingKey] = nil
			updateSettingButton(settingKey)
		else
			updateAllSettingButtons()
		end

		if currentName == "Settings" then
			if success == false then
				setSettingsStatus(message or "Setting was not saved.", PINK)
			else
				setSettingsStatus(message or "Saved.", LIME)
			end
		end
	end)
else
	-- Remotes can arrive shortly after this client script. Settings still registers immediately.
end

task.spawn(function()
	local eventsFolder = Events or ReplicatedStorage:WaitForChild("Events", 10)
	if not eventsFolder then
		return
	end

	if not requestSetSettingEvent then
		requestSetSettingEvent = eventsFolder:WaitForChild("RequestSetSetting", 10)
	end
	if not settingsUpdatedEvent then
		settingsUpdatedEvent = eventsFolder:WaitForChild("SettingsUpdated", 10)
		if settingsUpdatedEvent then
			settingsUpdatedEvent.OnClientEvent:Connect(function(settings, success, settingKey, message)
				applySettings(settings)
				if settingKey then
					pendingSettings[settingKey] = nil
					updateSettingButton(settingKey)
				else
					updateAllSettingButtons()
				end

				if currentName == "Settings" then
					if success == false then
						setSettingsStatus(message or "Setting was not saved.", PINK)
					else
						setSettingsStatus(message or "Saved.", LIME)
					end
				end
			end)
		end
	end
	updateAllSettingButtons()
end)

if not readReplicatedSettings() then
	task.spawn(function()
		local folder = player:WaitForChild("Settings", 10)
		if folder then
			readReplicatedSettings()
			for _, child in ipairs(folder:GetChildren()) do
				if child:IsA("BoolValue") then
					child:GetPropertyChangedSignal("Value"):Connect(readReplicatedSettings)
				end
			end
			folder.ChildAdded:Connect(function(child)
				if child:IsA("BoolValue") then
					child:GetPropertyChangedSignal("Value"):Connect(readReplicatedSettings)
					readReplicatedSettings()
				end
			end)
		end
	end)
end

for _, name in ipairs({ "Trading", "Market", "Settings" }) do
	UIManager.register(name, function(context)
		openPanel(name, context)
	end, function(context)
		closePanel(name, context)
	end, function()
		return isOpen and currentName == name
	end)
end
