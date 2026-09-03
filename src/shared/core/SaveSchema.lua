--!strict
local PetGenerator = require(script.Parent.PetGenerator)

local SaveSchema = {}
SaveSchema.VERSION = 1

function SaveSchema.default(_userId: number, starterPetId: string, starterSeed: number)
	local starter = PetGenerator.generate(starterSeed, starterPetId)
	starter.name = "Buddy"
	return {
		version = SaveSchema.VERSION,
		pets = { starter },
		activePetId = starter.id,
		eggs = { Backyard = 0, Play = 0, Party = 0 },
		worldFlags = {},
		stats = { partyGamesPlayed = 0, partyWins = 0 },
	}
end

function SaveSchema.findPet(profile, petId: string?)
	if not petId then return nil end
	for _, pet in profile.pets do
		if pet.id == petId then return pet end
	end
	return nil
end

function SaveSchema.activePet(profile)
	return SaveSchema.findPet(profile, profile.activePetId)
end

function SaveSchema.sanitize(raw, fallback)
	if type(raw) ~= "table" or raw.version ~= SaveSchema.VERSION then
		return fallback
	end
	if type(raw.pets) ~= "table" or #raw.pets == 0 then
		return fallback
	end
	raw.eggs = type(raw.eggs) == "table" and raw.eggs or {}
	raw.eggs.Backyard = math.max(0, math.floor(tonumber(raw.eggs.Backyard) or 0))
	raw.eggs.Play = math.max(0, math.floor(tonumber(raw.eggs.Play) or 0))
	raw.eggs.Party = math.max(0, math.floor(tonumber(raw.eggs.Party) or 0))
	raw.worldFlags = type(raw.worldFlags) == "table" and raw.worldFlags or {}
	raw.stats = type(raw.stats) == "table" and raw.stats or {}
	if not SaveSchema.findPet(raw, raw.activePetId) then
		raw.activePetId = raw.pets[1].id
	end
	return raw
end

return SaveSchema
