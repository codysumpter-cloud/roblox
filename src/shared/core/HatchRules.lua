--!strict
local EggDefinitions = require(script.Parent.EggDefinitions)
local PetGenerator = require(script.Parent.PetGenerator)

local HatchRules = {}

function HatchRules.canHatch(profile, eggId: string): boolean
	return EggDefinitions[eggId] ~= nil and (profile.eggs[eggId] or 0) > 0
end

function HatchRules.hatch(profile, eggId: string, seed: number, petId: string)
	if not HatchRules.canHatch(profile, eggId) then
		return nil, "egg_not_owned"
	end
	profile.eggs[eggId] -= 1
	local pet = PetGenerator.generate(seed, petId)
	table.insert(profile.pets, pet)
	if profile.activePetId == nil then
		profile.activePetId = pet.id
	end
	return pet, nil
end

return HatchRules
