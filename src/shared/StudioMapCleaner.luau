-- ModuleScript in ReplicatedStorage named "StudioMapCleaner".
-- Run in Studio edit mode from the command bar:
-- require(game.ReplicatedStorage.StudioMapCleaner).toneDownExisting()
local StudioMapCleaner = {}

local MAP_NAME = "ColorSimulatorMap"

local THEME = {
	Red = { color = Color3.fromRGB(210, 82, 82), accent = Color3.fromRGB(150, 70, 70), material = Enum.Material.SmoothPlastic },
	Blue = { color = Color3.fromRGB(72, 132, 210), accent = Color3.fromRGB(80, 125, 170), material = Enum.Material.Sand },
	Yellow = { color = Color3.fromRGB(215, 190, 76), accent = Color3.fromRGB(155, 135, 70), material = Enum.Material.Sand },
	Green = { color = Color3.fromRGB(82, 175, 95), accent = Color3.fromRGB(70, 125, 78), material = Enum.Material.Grass },
	Purple = { color = Color3.fromRGB(132, 82, 185), accent = Color3.fromRGB(105, 70, 145), material = Enum.Material.Slate },
	Neon = { color = Color3.fromRGB(46, 170, 150), accent = Color3.fromRGB(30, 115, 108), material = Enum.Material.SmoothPlastic },
	Rainbow = { color = Color3.fromRGB(178, 190, 215), accent = Color3.fromRGB(135, 110, 165), material = Enum.Material.SmoothPlastic },
}

local function toneBreakable(part)
	if part:GetAttribute("BreakableType") then
		local colorType = part:GetAttribute("ColorType")
		local theme = THEME[colorType]
		part.Material = Enum.Material.SmoothPlastic
		if theme then
			part.Color = colorType == "Rainbow" and Color3.fromRGB(215, 180, 255) or theme.color
		end

		local light = part:FindFirstChildOfClass("PointLight")
		if light then
			light.Brightness = 0.08
			light.Range = math.max(2, part.Size.X * 0.9)
		end

		local fx = part:FindFirstChild("IdleColorFx")
		local motes = fx and fx:FindFirstChild("GlowMotes")
		if motes and motes:IsA("ParticleEmitter") then
			motes.Rate = 0.75
			motes.LightEmission = 0.2
		end
	end
end

function StudioMapCleaner.toneDownExisting()
	local map = workspace:FindFirstChild(MAP_NAME)
	if not map then
		warn("StudioMapCleaner: no " .. MAP_NAME .. " found.")
		return nil
	end

	for _, obj in ipairs(map:GetDescendants()) do
		if obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
			obj:Destroy()
		elseif obj:IsA("BasePart") then
			local colorType = obj:GetAttribute("ColorType")
			local theme = colorType and THEME[colorType]

			if obj:GetAttribute("ColorZone") and theme then
				obj.Color = theme.color
				obj.Material = theme.material
				obj.Transparency = 0
			elseif obj:GetAttribute("AreaGate") then
				obj.Color = Color3.fromRGB(75, 82, 105)
				obj.Material = Enum.Material.Glass
				obj.Transparency = 0.25
			elseif obj:GetAttribute("AreaSpawn") and theme then
				obj.Color = theme.accent
				obj.Material = Enum.Material.SmoothPlastic
				obj.Transparency = 0
			elseif obj:GetAttribute("EggId") then
				obj.Material = Enum.Material.SmoothPlastic
				obj.Transparency = 0
			elseif obj.Name == "SellZone" then
				obj.Color = Color3.fromRGB(88, 190, 72)
				obj.Material = Enum.Material.SmoothPlastic
				obj.Transparency = 0
			elseif string.find(obj.Name, "Border") or string.find(obj.Name, "BuildMarker") then
				if theme then
					obj.Color = theme.accent
				end
				obj.Material = Enum.Material.SmoothPlastic
				obj.Transparency = 0.25
			end

			toneBreakable(obj)
		end
	end

	print("StudioMapCleaner: toned down " .. MAP_NAME .. " and removed floating labels.")
	return map
end

return StudioMapCleaner
