--!strict
local PartCatalog = require(script.Parent.PartCatalog)
local PetSchema = require(script.Parent.PetSchema)
local TraitRules = require(script.Parent.TraitRules)

local PetGenerator = {}
local MOD = 2147483647
local MUL = 48271

local function nextSeed(seed: number): number
	local normalized = math.floor(math.abs(seed)) % MOD
	if normalized == 0 then
		normalized = 1
	end
	return (normalized * MUL) % MOD
end

local function pick(seed: number, values)
	local nextValue = nextSeed(seed)
	local index = (nextValue % #values) + 1
	return nextValue, values[index]
end

function PetGenerator.generate(seed: number, id: string)
	local cursor = seed
	local parts = {}
	cursor, parts.head = pick(cursor, PartCatalog.heads)
	cursor, parts.ears = pick(cursor, PartCatalog.ears)
	cursor, parts.body = pick(cursor, PartCatalog.bodies)
	cursor, parts.legs = pick(cursor, PartCatalog.legs)
	cursor, parts.tail = pick(cursor, PartCatalog.tails)
	cursor, parts.pattern = pick(cursor, PartCatalog.patterns)
	cursor, parts.palette = pick(cursor, PartCatalog.palettes)
	return PetSchema.new(id, seed, parts, TraitRules.fromParts(parts))
end

return PetGenerator
