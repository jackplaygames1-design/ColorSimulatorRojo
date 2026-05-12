-- Bind-only currency HUD. The CurrencyBar must be built in Studio.
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ROOT_PATH = "PlayerGui.MainHUD"
local CURRENCY_PATH = ROOT_PATH .. ".CurrencyBar"
local warned = {}

local function warnOnce(key, message)
	if warned[key] then
		return
	end
	warned[key] = true
	warn(message)
end

local function formatNumber(value)
	value = math.floor(tonumber(value) or 0)
	local sign = value < 0 and "-" or ""
	value = math.abs(value)

	if value < 1000 then
		return sign .. tostring(value)
	end
	if value < 1000000 then
		return sign .. string.format("%.1f", value / 1000):gsub("%.0$", "") .. "K"
	end
	if value < 1000000000 then
		return sign .. string.format("%.1f", value / 1000000):gsub("%.0$", "") .. "M"
	end
	return sign .. string.format("%.1f", value / 1000000000):gsub("%.0$", "") .. "B"
end

local function findCurrencyFrame(root, names)
	for _, name in ipairs(names) do
		local frame = root:FindFirstChild(name)
		if frame and frame:IsA("GuiObject") then
			return frame
		end
	end

	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("GuiObject") then
			local lowered = string.lower(descendant.Name)
			for _, name in ipairs(names) do
				if lowered == string.lower(name) or string.find(lowered, string.lower(name), 1, true) then
					return descendant
				end
			end
		end
	end

	return nil
end

local function findAmountLabel(root, frameNames, labelPath)
	local frame = findCurrencyFrame(root, frameNames)
	if not frame then
		warnOnce(labelPath, "CurrencyHUD: missing " .. labelPath)
		return nil
	end

	local amount = frame:FindFirstChild("Amount", true)
	if amount and amount:IsA("TextLabel") then
		return amount
	end

	for _, descendant in ipairs(frame:GetDescendants()) do
		if descendant:IsA("TextLabel") then
			return descendant
		end
	end

	warnOnce(labelPath .. ".Amount", "CurrencyHUD: missing " .. labelPath .. ".Amount")
	return nil
end

local function connectValue(valueObject, label, missingText)
	if not label then
		return
	end
	if not valueObject then
		label.Text = missingText or "0"
		return
	end

	local function update()
		label.Text = formatNumber(valueObject.Value)
	end

	update()
	valueObject:GetPropertyChangedSignal("Value"):Connect(update)
end

local mainHud = playerGui:WaitForChild("MainHUD", 20)
if not mainHud then
	warnOnce(ROOT_PATH, "CurrencyHUD: missing " .. ROOT_PATH)
	return
end

local currencyBar = mainHud:WaitForChild("CurrencyBar", 20)
if not currencyBar or not currencyBar:IsA("GuiObject") then
	warnOnce(CURRENCY_PATH, "CurrencyHUD: missing " .. CURRENCY_PATH)
	return
end

currencyBar.Visible = true

local coinsAmount =
	findAmountLabel(currencyBar, { "CoinsFrame", "CoinFrame", "Coins", "Coin" }, CURRENCY_PATH .. ".CoinsFrame")
local gemsAmount = findAmountLabel(
	currencyBar,
	{ "GemsFrame", "GemFrame", "DiamondsFrame", "DiamondFrame", "Gems", "Diamonds" },
	CURRENCY_PATH .. ".GemsFrame"
)
local colorAmount =
	findAmountLabel(currencyBar, { "ColorFrame", "ColorsFrame", "PaintFrame", "Color" }, CURRENCY_PATH .. ".ColorFrame")

local leaderstats = player:WaitForChild("leaderstats", 20)
if not leaderstats then
	warnOnce("leaderstats", "CurrencyHUD: missing Player.leaderstats")
	return
end

local coins = leaderstats:FindFirstChild("Coins") or leaderstats:WaitForChild("Coins", 10)
local gems = leaderstats:FindFirstChild("Gems") or leaderstats:FindFirstChild("Diamonds")
if not gems then
	gems = leaderstats:WaitForChild("Gems", 10) or leaderstats:WaitForChild("Diamonds", 2)
end
local colorValue = leaderstats:FindFirstChild("Color")
	or leaderstats:FindFirstChild("Colors")
	or leaderstats:FindFirstChild("Paint")

connectValue(coins, coinsAmount, "0")
connectValue(gems, gemsAmount, "0")
connectValue(colorValue, colorAmount, "0")
