--!strict
local NeedsRules = {}

local DELTAS = {
	feed = { food = 24, clean = -2, happy = 3, friendship = 2 },
	wash = { food = 0, clean = 30, happy = 2, friendship = 2 },
	pet = { food = 0, clean = 0, happy = 14, friendship = 3 },
	play = { food = -2, clean = -2, happy = 24, friendship = 4 },
}

local function clamp(value: number): number
	return math.clamp(value, 0, 100)
end

function NeedsRules.apply(pet, action: string)
	local delta = DELTAS[action]
	if not delta then
		return false
	end
	pet.needs.food = clamp(pet.needs.food + delta.food)
	pet.needs.clean = clamp(pet.needs.clean + delta.clean)
	pet.needs.happy = clamp(pet.needs.happy + delta.happy)
	pet.friendship = math.max(0, math.floor(pet.friendship + delta.friendship))
	return true
end

function NeedsRules.decay(pet, amount: number)
	local decay = math.max(0, amount)
	pet.needs.food = clamp(pet.needs.food - decay)
	pet.needs.clean = clamp(pet.needs.clean - decay)
	pet.needs.happy = clamp(pet.needs.happy - decay)
end

return NeedsRules
