--!strict
local PetSchema = {}

function PetSchema.new(id: string, seed: number, parts, traits)
	return {
		id = id,
		name = "Buddy",
		seed = seed,
		parts = parts,
		traits = traits,
		needs = { food = 82, clean = 82, happy = 82 },
		friendship = 0,
		createdAt = 0,
	}
end

function PetSchema.sanitizeNeeds(needs)
	return {
		food = math.clamp(tonumber(needs and needs.food) or 80, 0, 100),
		clean = math.clamp(tonumber(needs and needs.clean) or 80, 0, 100),
		happy = math.clamp(tonumber(needs and needs.happy) or 80, 0, 100),
	}
end

return PetSchema
