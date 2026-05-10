-- Hooks the handmade PlayerGui.ClientUIRoot.MainHUD.CurrencyBar.
-- This script must not create HUD UI; Studio owns the visual objects.
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local WARNED = {}

local function warnOnce(key, message)
	if WARNED[key] then
		return
	end
	WARNED[key] = true
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
		local text = string.format("%.1f", value / 1000):gsub("%.0$", "")
		return sign .. text .. "K"
	end

	local text = string.format("%.1f", value / 1000000):gsub("%.0$", "")
	return sign .. text .. "M"
end

local function printChildren(parent, indent)
	indent = indent or ""
	if not parent then
		return
	end

	for _, child in ipairs(parent:GetChildren()) do
		print(indent .. child.Name .. " [" .. child.ClassName .. "]")
	end
end

local function waitForCurrencyBar()
	local root = playerGui:WaitForChild("ClientUIRoot", 15)
	if not root then
		warnOnce("missing-root", "CurrencyHUD: missing PlayerGui.ClientUIRoot; handmade currency not hooked.")
		return nil
	end

	local mainHud = root:WaitForChild("MainHUD", 15)
	if not mainHud then
		warnOnce("missing-mainhud", "CurrencyHUD: missing PlayerGui.ClientUIRoot.MainHUD; handmade currency not hooked.")
		printChildren(root, "[CurrencyHUD] ClientUIRoot child: ")
		return nil
	end

	local bar = mainHud:WaitForChild("CurrencyBar", 15)
	if not bar then
		warnOnce("missing-currencybar", "CurrencyHUD: missing PlayerGui.ClientUIRoot.MainHUD.CurrencyBar; handmade currency not hooked.")
		printChildren(mainHud, "[CurrencyHUD] MainHUD child: ")
		return nil
	end

	return bar
end

local function findTextLabel(root, preferredFrameName)
	local preferredFrame = root:FindFirstChild(preferredFrameName)
	if preferredFrame then
		local amount = preferredFrame:FindFirstChild("Amount", true)
		if amount and amount:IsA("TextLabel") then
			return amount
		end

		for _, descendant in ipairs(preferredFrame:GetDescendants()) do
			if descendant:IsA("TextLabel") then
				return descendant
			end
		end
	end

	local loweredPreferred = preferredFrameName:lower()
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("TextLabel") and descendant.Name:lower():find(loweredPreferred, 1, true) then
			return descendant
		end
	end

	return nil
end

local currencyBar = waitForCurrencyBar()
if not currencyBar then
	return
end

local coinsAmount = findTextLabel(currencyBar, "CoinsFrame")
local gemsAmount = findTextLabel(currencyBar, "GemsFrame")

if not coinsAmount then
	warnOnce("missing-coins-label", "CurrencyHUD: could not find CoinsFrame.Amount TextLabel. CurrencyBar children:")
	printChildren(currencyBar, "[CurrencyHUD] CurrencyBar child: ")
end
if not gemsAmount then
	warnOnce("missing-gems-label", "CurrencyHUD: could not find GemsFrame.Amount TextLabel. CurrencyBar children:")
	printChildren(currencyBar, "[CurrencyHUD] CurrencyBar child: ")
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

local leaderstats = player:WaitForChild("leaderstats", 20)
if not leaderstats then
	warnOnce("missing-leaderstats", "CurrencyHUD: leaderstats did not load.")
	return
end

local coins = leaderstats:WaitForChild("Coins", 10)
local gems = leaderstats:FindFirstChild("Gems") or leaderstats:FindFirstChild("Diamonds")
if not gems then
	gems = leaderstats:WaitForChild("Gems", 10) or leaderstats:WaitForChild("Diamonds", 2)
end

connectValue(coins, coinsAmount, "0")
connectValue(gems, gemsAmount, "0")

if not coins then
	warnOnce("missing-coins", "CurrencyHUD: leaderstats.Coins is missing.")
end
if not gems then
	warnOnce("missing-gems", "CurrencyHUD: leaderstats.Gems/Diamonds is missing.")
end

print("CurrencyHUD: hooked handmade ClientUIRoot.MainHUD.CurrencyBar.")
