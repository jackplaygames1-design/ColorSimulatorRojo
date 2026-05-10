-- Hide old Roblox CoreGui panels that clash with the custom simulator HUD.
local StarterGui = game:GetService("StarterGui")

local function setCoreGuiEnabled(coreGuiType, enabled)
	for _ = 1, 20 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(coreGuiType, enabled)
		end)
		if ok then
			return
		end
		task.wait(0.25)
	end
end

task.spawn(function()
	setCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	setCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
end)
