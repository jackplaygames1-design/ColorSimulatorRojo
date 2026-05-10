-- Add weekly redeem codes here. Codes are matched case-insensitively by CodeHandler.
local CodeData = {}

CodeData.Codes = {
	RELEASE = {
		Code = "RELEASE",
		Active = true,
		MaxUsesPerPlayer = 1,
		Message = "Release reward claimed!",
		Rewards = {
			{ Type = "Coins", Amount = 1000 },
		},
	},
	COLOR = {
		Code = "COLOR",
		Active = true,
		MaxUsesPerPlayer = 1,
		Message = "Color boost claimed!",
		Rewards = {
			{ Type = "Color", Amount = 250 },
		},
	},
	PET = {
		Code = "PET",
		Active = true,
		MaxUsesPerPlayer = 1,
		Message = "Starter Color claimed!",
		Rewards = {
			{ Type = "Pet", PetId = "RedBlob", Amount = 5 },
		},
	},
}

function CodeData.normalize(code)
	return string.upper((tostring(code or ""):gsub("%s+", "")))
end

function CodeData.getCode(code)
	return CodeData.Codes[CodeData.normalize(code)]
end

return CodeData
