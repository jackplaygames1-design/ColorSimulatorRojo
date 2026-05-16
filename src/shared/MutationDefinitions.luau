local MutationDefinitions = {}

MutationDefinitions.NoneId = "None"
MutationDefinitions.MutationChanceOneIn = 12
MutationDefinitions.GlitchedChanceOneIn = 850

MutationDefinitions.Order = {
	"Overflow",
	"Prism",
	"Corrupted",
	"Radioactive",
}

MutationDefinitions.Mutations = {
	Overflow = {
		Id = "Overflow",
		DisplayName = "Overflow",
		Weight = 34,
		PowerMultiplier = 1.55,
		TextColor = Color3.fromRGB(255, 58, 58),
		AuraColor = Color3.fromRGB(255, 45, 45),
		VisualTag = "overflow_drip",
		Description = "Dripping paint overflow.",
	},
	Prism = {
		Id = "Prism",
		DisplayName = "Prism",
		Weight = 26,
		PowerMultiplier = 1.75,
		TextColor = Color3.fromRGB(130, 255, 245),
		AuraColor = Color3.fromRGB(160, 120, 255),
		VisualTag = "prism_rainbow",
		Description = "Subtle rainbow refraction.",
	},
	Corrupted = {
		Id = "Corrupted",
		DisplayName = "Corrupted",
		Weight = 18,
		PowerMultiplier = 2.05,
		TextColor = Color3.fromRGB(190, 68, 255),
		AuraColor = Color3.fromRGB(85, 20, 125),
		VisualTag = "corrupted_smoke",
		Description = "Broken purple-black color energy.",
	},
	Radioactive = {
		Id = "Radioactive",
		DisplayName = "Radioactive",
		Weight = 22,
		PowerMultiplier = 1.9,
		TextColor = Color3.fromRGB(82, 255, 84),
		AuraColor = Color3.fromRGB(82, 255, 84),
		VisualTag = "radioactive_toxic",
		Description = "Toxic green color particles.",
	},
}

local function getRandom(rng)
	if typeof(rng) == "Random" then
		return rng:NextNumber()
	end
	return math.random()
end

function MutationDefinitions.Get(mutationId)
	return MutationDefinitions.Mutations[tostring(mutationId or "")]
end

function MutationDefinitions.IsMutated(mutationId)
	return MutationDefinitions.Get(mutationId) ~= nil
end

function MutationDefinitions.Roll(rng, luckMultiplier)
	luckMultiplier = math.clamp(tonumber(luckMultiplier) or 1, 1, 4)
	local mutationChance = math.clamp((1 / MutationDefinitions.MutationChanceOneIn) * luckMultiplier, 0, 0.75)
	if getRandom(rng) > mutationChance then
		return nil, false
	end

	local totalWeight = 0
	for _, mutationId in ipairs(MutationDefinitions.Order) do
		local mutation = MutationDefinitions.Mutations[mutationId]
		totalWeight += tonumber(mutation and mutation.Weight) or 0
	end

	local roll = getRandom(rng) * totalWeight
	local running = 0
	local selected = MutationDefinitions.Order[1]
	for _, mutationId in ipairs(MutationDefinitions.Order) do
		local mutation = MutationDefinitions.Mutations[mutationId]
		running += tonumber(mutation and mutation.Weight) or 0
		if roll <= running then
			selected = mutationId
			break
		end
	end

	local glitchedChance = math.clamp((1 / MutationDefinitions.GlitchedChanceOneIn) * luckMultiplier, 0, 0.2)
	local isGlitched = getRandom(rng) <= glitchedChance
	return selected, isGlitched
end

function MutationDefinitions.GetPowerMultiplier(mutationId, isGlitched)
	local mutation = MutationDefinitions.Get(mutationId)
	local multiplier = mutation and tonumber(mutation.PowerMultiplier) or 1
	if isGlitched == true then
		multiplier *= 3
	end
	return multiplier
end

function MutationDefinitions.GetLabel(mutationId, isGlitched)
	local mutation = MutationDefinitions.Get(mutationId)
	if not mutation then
		return "None"
	end
	if isGlitched == true then
		return "GLITCHED " .. string.upper(mutation.DisplayName)
	end
	return string.upper(mutation.DisplayName)
end

function MutationDefinitions.GetRows()
	local rows = {}
	for _, mutationId in ipairs(MutationDefinitions.Order) do
		local mutation = MutationDefinitions.Mutations[mutationId]
		table.insert(rows, {
			Id = mutation.Id,
			DisplayName = mutation.DisplayName,
			TextColor = mutation.TextColor,
			Description = mutation.Description,
		})
	end
	return rows
end

return MutationDefinitions
