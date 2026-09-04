--!strict
local PetGenerator = require(script.Parent.PetGenerator)
local PetSchema = require(script.Parent.PetSchema)
local PartCatalog = require(script.Parent.PartCatalog)
local TraitRules = require(script.Parent.TraitRules)
local RuntimeTemplates = require(script.Parent.RuntimeTemplates)

local SaveSchema = {}
SaveSchema.VERSION = 1

function SaveSchema.default(_userId: number, starterPetId: string, starterSeed: number)
	local starter = PetGenerator.generate(starterSeed, starterPetId)
	starter.name = "Buddy"
	starter.runtimeTemplate = "Pug"
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
	-- DataStore contents are external input. Keep only the portable fields we know how
	-- to use and recalculate traits from parts instead of trusting persisted stats.
	local pets = {}
	local seenIds = {}
	local function catalogValue(values, value, default)
		if type(value) ~= "string" then return default end
		for _, candidate in values do
			if candidate == value then return value end
		end
		return default
	end
	for _, rawPet in raw.pets do
		local rawId = type(rawPet) == "table" and type(rawPet.id) == "string" and string.sub(rawPet.id, 1, 64) or nil
		if type(rawPet) == "table" and rawId and #rawId > 0 and not seenIds[rawId] then
			local rawParts = type(rawPet.parts) == "table" and rawPet.parts or {}
			local parts = {
				head = catalogValue(PartCatalog.heads, rawParts.head, PartCatalog.heads[1]),
				ears = catalogValue(PartCatalog.ears, rawParts.ears, PartCatalog.ears[1]),
				body = catalogValue(PartCatalog.bodies, rawParts.body, PartCatalog.bodies[1]),
				legs = catalogValue(PartCatalog.legs, rawParts.legs, PartCatalog.legs[1]),
				tail = catalogValue(PartCatalog.tails, rawParts.tail, PartCatalog.tails[1]),
				pattern = catalogValue(PartCatalog.patterns, rawParts.pattern, PartCatalog.patterns[1]),
				palette = catalogValue(PartCatalog.palettes, rawParts.palette, PartCatalog.palettes[1]),
			}
			local pet = {
				id = rawId,
				name = type(rawPet.name) == "string" and string.sub(rawPet.name, 1, 32) or "Buddy",
				runtimeTemplate = RuntimeTemplates.isApproved(rawPet.runtimeTemplate) and rawPet.runtimeTemplate or "Pug",
				seed = math.floor(tonumber(rawPet.seed) or 1),
				parts = parts,
				traits = TraitRules.fromParts(parts),
				needs = PetSchema.sanitizeNeeds(rawPet.needs),
				friendship = math.max(0, math.floor(tonumber(rawPet.friendship) or 0)),
				createdAt = math.max(0, math.floor(tonumber(rawPet.createdAt) or 0)),
			}
			table.insert(pets, pet)
			seenIds[pet.id] = true
			if #pets >= 100 then break end
		end
	end
	if #pets == 0 then return fallback end
	local activeId = type(raw.activePetId) == "string" and raw.activePetId or pets[1].id
	local activeExists = false
	for _, pet in pets do
		if pet.id == activeId then activeExists = true break end
	end
	if not activeExists then activeId = pets[1].id end
	local eggs = type(raw.eggs) == "table" and raw.eggs or {}
	local rawFlags = type(raw.worldFlags) == "table" and raw.worldFlags or {}
	local worldFlags = {}
	for flag, value in rawFlags do
		if type(flag) == "string" and #flag <= 64 and value == true then
			worldFlags[flag] = true
		end
	end
	local stats = type(raw.stats) == "table" and raw.stats or {}
	return {
		version = SaveSchema.VERSION,
		pets = pets,
		activePetId = activeId,
		eggs = {
			Backyard = math.max(0, math.floor(tonumber(eggs.Backyard) or 0)),
			Play = math.max(0, math.floor(tonumber(eggs.Play) or 0)),
			Party = math.max(0, math.floor(tonumber(eggs.Party) or 0)),
		},
		worldFlags = worldFlags,
		stats = {
			partyGamesPlayed = math.max(0, math.floor(tonumber(stats.partyGamesPlayed) or 0)),
			partyWins = math.max(0, math.floor(tonumber(stats.partyWins) or 0)),
		},
	}
end

return SaveSchema
