local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local events = ReplicatedStorage:WaitForChild("Events")
local remote = events:WaitForChild("MutationStation")
local ClientUIRoot = require(ReplicatedStorage:WaitForChild("ClientUIRoot"))
local ColorMutationData = require(ReplicatedStorage:WaitForChild("ColorMutationData"))
local UIManager = require(ReplicatedStorage:WaitForChild("UIManager"))
local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))

local DARK = Color3.fromRGB(10, 12, 26)
local PANEL = Color3.fromRGB(17, 18, 42)
local PANEL_2 = Color3.fromRGB(26, 24, 62)
local CYAN = Color3.fromRGB(71, 229, 255)
local BLUE = Color3.fromRGB(44, 144, 255)
local PINK = Color3.fromRGB(255, 59, 221)
local PURPLE = Color3.fromRGB(159, 67, 255)
local GOLD = Color3.fromRGB(255, 213, 66)
local GREEN = Color3.fromRGB(106, 245, 32)
local RED = Color3.fromRGB(255, 48, 77)
local WHITE = Color3.fromRGB(255, 255, 255)
local MUTED = Color3.fromRGB(208, 215, 255)

local gui = ClientUIRoot.GetLayer(player:WaitForChild("PlayerGui"), "MutationStationGui")
for _, child in ipairs(gui:GetChildren()) do
	child:Destroy()
end
gui.Visible = false

local function corner(parent, radius)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, radius)
	item.Parent = parent
	return item
end

local function stroke(parent, color, thickness, transparency)
	local item = Instance.new("UIStroke")
	item.Color = color
	item.Thickness = thickness or 2
	item.Transparency = transparency or 0
	item.Parent = parent
	return item
end

local function label(parent, props)
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.BorderSizePixel = 0
	item.Font = props.Font or Enum.Font.GothamBold
	item.Text = props.Text or ""
	item.TextColor3 = props.TextColor3 or WHITE
	item.TextSize = props.TextSize or 18
	item.TextWrapped = props.TextWrapped ~= false
	item.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	item.TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center
	item.TextStrokeTransparency = props.TextStrokeTransparency or 1
	item.TextStrokeColor3 = props.TextStrokeColor3 or Color3.new()
	item.ZIndex = props.ZIndex or 160
	item.Parent = parent
	if props.Size then
		item.Size = props.Size
	end
	if props.Position then
		item.Position = props.Position
	end
	return item
end

local function button(parent, props)
	local item = Instance.new("TextButton")
	item.AutoButtonColor = false
	item.BorderSizePixel = 0
	item.BackgroundColor3 = props.BackgroundColor3 or CYAN
	item.Font = props.Font or Enum.Font.LuckiestGuy
	item.Text = props.Text or "BUTTON"
	item.TextColor3 = props.TextColor3 or WHITE
	item.TextSize = props.TextSize or 22
	item.TextStrokeTransparency = props.TextStrokeTransparency or 0
	item.TextStrokeColor3 = props.TextStrokeColor3 or DARK
	item.ZIndex = props.ZIndex or 170
	item.Parent = parent
	if props.Size then
		item.Size = props.Size
	end
	if props.Position then
		item.Position = props.Position
	end
	corner(item, props.CornerRadius or 14)
	stroke(item, props.StrokeColor or Color3.fromRGB(255, 255, 255), props.StrokeThickness or 2, props.StrokeTransparency or 0.5)
	UITheme.ApplyTouchTarget(item, math.max(44, item.AbsoluteSize.Y))
	return item
end

local function section(parent, titleText, numberText, position, size, accent)
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Color3.fromRGB(15, 16, 42)
	frame.BorderSizePixel = 0
	frame.Position = position
	frame.Size = size
	frame.ZIndex = 161
	frame.Parent = parent
	corner(frame, 18)
	stroke(frame, accent, 3, 0.05)

	local header = Instance.new("Frame")
	header.BackgroundColor3 = Color3.fromRGB(54, 28, 115)
	header.BorderSizePixel = 0
	header.Size = UDim2.new(1, 0, 0, 48)
	header.ZIndex = 162
	header.Parent = frame
	corner(header, 18)

	local badge = Instance.new("TextLabel")
	badge.BackgroundColor3 = accent
	badge.Size = UDim2.fromOffset(42, 42)
	badge.Position = UDim2.fromOffset(10, 3)
	badge.Font = Enum.Font.LuckiestGuy
	badge.Text = numberText
	badge.TextColor3 = WHITE
	badge.TextSize = 23
	badge.TextStrokeTransparency = 0
	badge.TextStrokeColor3 = DARK
	badge.ZIndex = 164
	badge.Parent = header
	corner(badge, 21)
	stroke(badge, Color3.fromRGB(255, 255, 255), 2, 0.45)

	label(header, {
		Text = titleText,
		Position = UDim2.fromOffset(64, 0),
		Size = UDim2.new(1, -76, 1, 0),
		Font = Enum.Font.LuckiestGuy,
		TextSize = 24,
		TextStrokeTransparency = 0,
		TextStrokeColor3 = DARK,
		ZIndex = 164,
	})

	return frame
end

local dim = Instance.new("TextButton")
dim.Name = "Dim"
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.fromRGB(3, 4, 12)
dim.BackgroundTransparency = 0.34
dim.BorderSizePixel = 0
dim.Text = ""
dim.AutoButtonColor = false
dim.ZIndex = 150
dim.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "MutationPanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.52)
panel.Size = UDim2.fromOffset(1010, 650)
panel.BackgroundColor3 = PANEL
panel.BorderSizePixel = 0
panel.ClipsDescendants = false
panel.ZIndex = 151
panel.Parent = gui
UITheme.ApplyResponsiveScale(panel, 1010, 650, 0.58, 20)
corner(panel, 24)
stroke(panel, PINK, 4, 0)

local panelGradient = Instance.new("UIGradient")
panelGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(12, 16, 44)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(24, 16, 64)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(21, 10, 33)),
})
panelGradient.Rotation = 20
panelGradient.Parent = panel

local glow = Instance.new("ImageLabel")
glow.Name = "NeonGlow"
glow.BackgroundTransparency = 1
glow.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
glow.ImageColor3 = PINK
glow.ImageTransparency = 0.82
glow.AnchorPoint = Vector2.new(0.5, 0.5)
glow.Position = UDim2.fromScale(0.5, 0.5)
glow.Size = UDim2.new(1, 120, 1, 120)
glow.ZIndex = 149
glow.Parent = panel

local overlayPage = Instance.new("Frame")
overlayPage.Name = "UnlockOverlay"
overlayPage.BackgroundTransparency = 1
overlayPage.Size = UDim2.fromScale(1, 1)
overlayPage.ClipsDescendants = false
overlayPage.ZIndex = 152
overlayPage.Parent = panel

local indexPage = Instance.new("Frame")
indexPage.Name = "MutationIndex"
indexPage.BackgroundTransparency = 1
indexPage.Size = UDim2.fromScale(1, 1)
indexPage.Visible = false
indexPage.ZIndex = 152
indexPage.Parent = panel

local title = label(overlayPage, {
	Text = "MUTATIONS\nUNLOCKED!",
	Position = UDim2.fromOffset(72, -72),
	Size = UDim2.new(1, -144, 0, 140),
	Font = Enum.Font.LuckiestGuy,
	TextSize = 58,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextStrokeTransparency = 0,
	TextStrokeColor3 = Color3.fromRGB(82, 20, 118),
	ZIndex = 175,
})
local titleGradient = Instance.new("UIGradient")
titleGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, CYAN),
	ColorSequenceKeypoint.new(0.35, PINK),
	ColorSequenceKeypoint.new(0.7, Color3.fromRGB(255, 94, 89)),
	ColorSequenceKeypoint.new(1, GOLD),
})
titleGradient.Parent = title

label(overlayPage, {
	Text = "Your Colors can now hatch with powerful mutations!",
	Position = UDim2.fromOffset(60, 62),
	Size = UDim2.new(1, -120, 0, 36),
	Font = Enum.Font.GothamBlack,
	TextSize = 22,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextColor3 = WHITE,
	TextStrokeTransparency = 0.35,
	TextStrokeColor3 = DARK,
	ZIndex = 174,
})

local closeOverlay = button(overlayPage, {
	Text = "X",
	Position = UDim2.new(1, -72, 0, 18),
	Size = UDim2.fromOffset(48, 48),
	BackgroundColor3 = Color3.fromRGB(201, 73, 255),
	TextSize = 24,
	CornerRadius = 24,
	StrokeColor = Color3.fromRGB(255, 213, 255),
	ZIndex = 176,
})

local what = section(overlayPage, "What Are Mutations?", "1", UDim2.fromOffset(28, 118), UDim2.fromOffset(392, 180), PURPLE)
local dna = label(what, {
	Text = "DNA",
	Position = UDim2.fromOffset(34, 76),
	Size = UDim2.fromOffset(104, 74),
	Font = Enum.Font.LuckiestGuy,
	TextSize = 32,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextColor3 = Color3.fromRGB(242, 178, 255),
	TextStrokeTransparency = 0,
	TextStrokeColor3 = Color3.fromRGB(96, 0, 132),
	ZIndex = 165,
})
dna.BackgroundColor3 = Color3.fromRGB(78, 23, 125)
dna.BackgroundTransparency = 0
corner(dna, 18)
stroke(dna, Color3.fromRGB(230, 91, 255), 3, 0)
label(what, {
	Text = "Mutations are rare special versions of Colors. They can add stronger value, new bonuses, and visible effects.",
	Position = UDim2.fromOffset(160, 70),
	Size = UDim2.new(1, -184, 0, 86),
	Font = Enum.Font.GothamBlack,
	TextSize = 20,
	TextColor3 = WHITE,
	ZIndex = 165,
})

local how = section(overlayPage, "How Do They Work?", "2", UDim2.fromOffset(438, 118), UDim2.fromOffset(544, 180), BLUE)
local bullets = {
	"Unlocked at the Mutation Core.",
	"Hatched Colors now have a rare chance to be born mutated.",
	"Mutations boost power and rewards.",
	"Mutation names appear on hatch results and inventory cards.",
}
for index, text in ipairs(bullets) do
	local dot = Instance.new("Frame")
	dot.BackgroundColor3 = CYAN
	dot.BorderSizePixel = 0
	dot.Position = UDim2.fromOffset(20, 66 + (index - 1) * 25)
	dot.Size = UDim2.fromOffset(10, 10)
	dot.ZIndex = 165
	dot.Parent = how
	corner(dot, 5)
	label(how, {
		Text = text,
		Position = UDim2.fromOffset(42, 56 + (index - 1) * 25),
		Size = UDim2.new(1, -58, 0, 24),
		Font = Enum.Font.GothamBold,
		TextSize = 17,
		TextColor3 = WHITE,
		ZIndex = 165,
	})
end

local types = section(overlayPage, "Mutation Types", "3", UDim2.fromOffset(28, 312), UDim2.fromOffset(556, 220), PINK)
local typeCards = {
	{ Name = "DARK", Text = "More coins & item drops.", Color = Color3.fromRGB(69, 27, 112), Stroke = PURPLE },
	{ Name = "LIGHT", Text = "More gems & luck.", Color = Color3.fromRGB(83, 64, 19), Stroke = GOLD },
	{ Name = "CORRUPTED", Text = "Risky but super powerful.", Color = Color3.fromRGB(61, 13, 20), Stroke = RED },
}
for index, info in ipairs(typeCards) do
	local card = Instance.new("Frame")
	card.BackgroundColor3 = info.Color
	card.BorderSizePixel = 0
	card.Position = UDim2.fromOffset(22 + (index - 1) * 170, 74)
	card.Size = UDim2.fromOffset(150, 124)
	card.ZIndex = 164
	card.Parent = types
	corner(card, 16)
	stroke(card, info.Stroke, 3, 0)
	label(card, {
		Text = info.Name,
		Position = UDim2.fromOffset(10, 18),
		Size = UDim2.new(1, -20, 0, 32),
		Font = Enum.Font.LuckiestGuy,
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = WHITE,
		TextStrokeTransparency = 0,
		TextStrokeColor3 = DARK,
		ZIndex = 165,
	})
	label(card, {
		Text = info.Text,
		Position = UDim2.fromOffset(14, 58),
		Size = UDim2.new(1, -28, 0, 46),
		Font = Enum.Font.GothamBlack,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = WHITE,
		ZIndex = 165,
	})
end

local why = section(overlayPage, "Why They Matter", "4", UDim2.fromOffset(604, 312), UDim2.fromOffset(378, 220), BLUE)
local benefits = {
	{ Text = "+ Stronger Colors", Color = PURPLE },
	{ Text = "+ Better Rewards", Color = GOLD },
	{ Text = "+ Rare Visual Forms", Color = CYAN },
}
for index, info in ipairs(benefits) do
	local row = Instance.new("Frame")
	row.BackgroundColor3 = Color3.fromRGB(62, 25, 95)
	row.BorderSizePixel = 0
	row.Position = UDim2.fromOffset(20, 70 + (index - 1) * 48)
	row.Size = UDim2.new(1, -40, 0, 38)
	row.ZIndex = 164
	row.Parent = why
	corner(row, 14)
	stroke(row, info.Color, 3, 0.08)
	label(row, {
		Text = info.Text,
		Position = UDim2.fromOffset(18, 0),
		Size = UDim2.new(1, -36, 1, 0),
		Font = Enum.Font.LuckiestGuy,
		TextSize = 23,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = WHITE,
		TextStrokeTransparency = 0,
		TextStrokeColor3 = DARK,
		ZIndex = 165,
	})
end

local tip = Instance.new("Frame")
tip.BackgroundColor3 = Color3.fromRGB(49, 24, 80)
tip.BorderSizePixel = 0
tip.Position = UDim2.fromOffset(28, 546)
tip.Size = UDim2.new(1, -56, 0, 38)
tip.ZIndex = 164
tip.Parent = overlayPage
corner(tip, 18)
stroke(tip, PURPLE, 2, 0.15)
label(tip, {
	Text = "Tip: Mutations are separate from Traits. A Color can have both!",
	Position = UDim2.fromOffset(18, 0),
	Size = UDim2.new(1, -36, 1, 0),
	Font = Enum.Font.GothamBlack,
	TextSize = 19,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextColor3 = Color3.fromRGB(252, 238, 255),
	ZIndex = 165,
})

local openIndex = button(overlayPage, {
	Text = "OPEN MUTATION INDEX",
	Position = UDim2.fromOffset(72, 600),
	Size = UDim2.fromOffset(410, 56),
	BackgroundColor3 = Color3.fromRGB(27, 155, 255),
	TextSize = 25,
	StrokeColor = CYAN,
	ZIndex = 176,
})

local gotIt = button(overlayPage, {
	Text = "GOT IT!",
	Position = UDim2.new(1, -482, 0, 600),
	Size = UDim2.fromOffset(410, 56),
	BackgroundColor3 = GREEN,
	TextSize = 30,
	StrokeColor = Color3.fromRGB(210, 255, 110),
	ZIndex = 176,
})

local indexTitle = label(indexPage, {
	Text = "MUTATION INDEX",
	Position = UDim2.fromOffset(34, 22),
	Size = UDim2.new(1, -120, 0, 52),
	Font = Enum.Font.LuckiestGuy,
	TextSize = 40,
	TextColor3 = WHITE,
	TextStrokeTransparency = 0,
	TextStrokeColor3 = DARK,
	ZIndex = 165,
})
local indexTitleGradient = Instance.new("UIGradient")
indexTitleGradient.Color = ColorSequence.new(CYAN, PINK)
indexTitleGradient.Parent = indexTitle

local closeIndex = button(indexPage, {
	Text = "X",
	Position = UDim2.new(1, -72, 0, 22),
	Size = UDim2.fromOffset(48, 48),
	BackgroundColor3 = PINK,
	TextSize = 24,
	CornerRadius = 24,
	StrokeColor = Color3.fromRGB(255, 213, 255),
	ZIndex = 176,
})

label(indexPage, {
	Text = "Preview every mutation type. Hatch mutated Colors after unlocking the Mutation Core.",
	Position = UDim2.fromOffset(38, 74),
	Size = UDim2.new(1, -76, 0, 28),
	Font = Enum.Font.GothamBlack,
	TextSize = 17,
	TextColor3 = MUTED,
	ZIndex = 165,
})

local list = Instance.new("ScrollingFrame")
list.Name = "MutationList"
list.BackgroundColor3 = Color3.fromRGB(10, 12, 30)
list.BackgroundTransparency = 0.1
list.BorderSizePixel = 0
list.Position = UDim2.fromOffset(34, 112)
list.Size = UDim2.new(1, -68, 0, 436)
list.ScrollBarThickness = 8
list.ScrollBarImageColor3 = CYAN
list.CanvasSize = UDim2.fromOffset(0, 0)
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.ZIndex = 162
list.Parent = indexPage
corner(list, 18)
stroke(list, CYAN, 2, 0.35)

local listPadding = Instance.new("UIPadding")
listPadding.PaddingTop = UDim.new(0, 12)
listPadding.PaddingBottom = UDim.new(0, 12)
listPadding.PaddingLeft = UDim.new(0, 12)
listPadding.PaddingRight = UDim.new(0, 12)
listPadding.Parent = list

local grid = Instance.new("UIGridLayout")
grid.CellPadding = UDim2.fromOffset(12, 12)
grid.CellSize = UDim2.fromOffset(286, 126)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = list

local function makeMutationCard(mutationId, order)
	local mutation = ColorMutationData.get(mutationId)
	if not mutation or mutation.Id == ColorMutationData.NoneId then
		return
	end

	local typeColor = ColorMutationData.getTypeColor(mutation.Type)
	local card = Instance.new("Frame")
	card.BackgroundColor3 = mutation.Type == "Light"
		and Color3.fromRGB(58, 48, 24)
		or mutation.Type == "Corrupted"
		and Color3.fromRGB(47, 13, 24)
		or Color3.fromRGB(31, 18, 57)
	card.BorderSizePixel = 0
	card.LayoutOrder = order
	card.ZIndex = 163
	card.Parent = list
	corner(card, 14)
	stroke(card, typeColor, mutation.Rarity == "Legendary" and 4 or 2, 0.06)

	label(card, {
		Text = mutation.DisplayName,
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(1, -28, 0, 24),
		Font = Enum.Font.LuckiestGuy,
		TextSize = 21,
		TextColor3 = WHITE,
		TextStrokeTransparency = 0,
		TextStrokeColor3 = DARK,
		ZIndex = 164,
	})
	label(card, {
		Text = mutation.Rarity .. " " .. mutation.Type .. " Mutation",
		Position = UDim2.fromOffset(14, 38),
		Size = UDim2.new(1, -28, 0, 18),
		Font = Enum.Font.GothamBlack,
		TextSize = 13,
		TextColor3 = typeColor,
		ZIndex = 164,
	})
	label(card, {
		Text = mutation.Description,
		Position = UDim2.fromOffset(14, 60),
		Size = UDim2.new(1, -28, 0, 28),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(231, 235, 255),
		ZIndex = 164,
	})
	label(card, {
		Text = mutation.VisualTheme,
		Position = UDim2.fromOffset(14, 90),
		Size = UDim2.new(1, -28, 0, 24),
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(190, 198, 238),
		ZIndex = 164,
	})

	if RunService:IsStudio() then
		local force = button(card, {
			Text = "FORCE",
			Position = UDim2.new(1, -78, 1, -34),
			Size = UDim2.fromOffset(64, 24),
			BackgroundColor3 = typeColor,
			TextSize = 13,
			CornerRadius = 8,
			StrokeTransparency = 0.7,
			ZIndex = 166,
		})
		force.Activated:Connect(function()
			remote:FireServer("DebugForceMutation", mutation.Id)
		end)
	end
end

for index, mutationId in ipairs(ColorMutationData.RollOrder) do
	makeMutationCard(mutationId, index)
end

local replayHelp = button(indexPage, {
	Text = "REPLAY TUTORIAL",
	Position = UDim2.fromOffset(54, 574),
	Size = UDim2.fromOffset(240, 48),
	BackgroundColor3 = PURPLE,
	TextSize = 20,
	StrokeColor = PINK,
	ZIndex = 176,
})

local closeIndexBottom = button(indexPage, {
	Text = "CLOSE",
	Position = UDim2.new(1, -294, 0, 574),
	Size = UDim2.fromOffset(240, 48),
	BackgroundColor3 = BLUE,
	TextSize = 22,
	StrokeColor = CYAN,
	ZIndex = 176,
})

local debugReset
if RunService:IsStudio() then
	debugReset = button(indexPage, {
		Text = "RESET POPUP",
		Position = UDim2.fromOffset(322, 574),
		Size = UDim2.fromOffset(170, 48),
		BackgroundColor3 = Color3.fromRGB(72, 75, 96),
		TextSize = 17,
		StrokeTransparency = 0.75,
		ZIndex = 176,
	})
	debugReset.Activated:Connect(function()
		remote:FireServer("DebugResetTutorial")
	end)
end

local currentState = nil

local function tweenIn()
	panel.Size = UDim2.fromOffset(970, 624)
	TweenService:Create(panel, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(1010, 650),
	}):Play()
	TweenService:Create(dim, TweenInfo.new(0.16), {
		BackgroundTransparency = 0.34,
	}):Play()
end

local function showGui()
	dim.BackgroundTransparency = 1
	gui.Visible = true
	tweenIn()
end

local function markSeen()
	if currentState and currentState.unlocked == true and currentState.hasSeenTutorial ~= true then
		currentState.hasSeenTutorial = true
		remote:FireServer("MarkTutorialSeen")
	end
end

local function showOverlay(data)
	currentState = data or currentState or {
		unlocked = true,
		hasSeenTutorial = true,
	}
	overlayPage.Visible = true
	indexPage.Visible = false
	showGui()
end

local function showIndex(data)
	currentState = data or currentState or {}
	overlayPage.Visible = false
	indexPage.Visible = true
	showGui()
end

local function closeGui()
	if overlayPage.Visible then
		markSeen()
	end
	gui.Visible = false
end

closeOverlay.Activated:Connect(closeGui)
gotIt.Activated:Connect(closeGui)
openIndex.Activated:Connect(function()
	markSeen()
	showIndex(currentState)
end)

closeIndex.Activated:Connect(closeGui)
closeIndexBottom.Activated:Connect(closeGui)
replayHelp.Activated:Connect(function()
	showOverlay(currentState)
end)

remote.OnClientEvent:Connect(function(actionName, data)
	if actionName == "ShowUnlocked" then
		showOverlay(data)
	elseif actionName == "Open" then
		if data and data.unlocked == true and data.hasSeenTutorial ~= true then
			showOverlay(data)
		else
			showIndex(data)
		end
	elseif actionName == "OpenIndex" then
		showIndex(data)
	elseif actionName == "State" then
		currentState = data or currentState
		if gui.Visible and indexPage.Visible then
			showIndex(currentState)
		end
	end
end)

UIManager.register("MutationStation", function(data)
	if data then
		showIndex(data)
	else
		remote:FireServer("Get")
		showIndex(currentState)
	end
end, closeGui, function()
	return gui.Visible == true
end)
