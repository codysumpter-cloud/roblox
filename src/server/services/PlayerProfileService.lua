--!strict
local Config = require(game.ReplicatedStorage.PocketBuddy.Shared.core.Config)
local SaveSchema = require(game.ReplicatedStorage.PocketBuddy.Shared.core.SaveSchema)
local DataStoreAdapter = require(script.Parent.Parent.adapters.DataStoreAdapter)
local IdAdapter = require(script.Parent.Parent.adapters.IdAdapter)

local PlayerProfileService = {}
local profiles = {}

function PlayerProfileService.load(player: Player)
	local starterId = IdAdapter.newPetId()
	local starterSeed = math.abs(player.UserId * Config.StarterPetSeedSalt) + 1
	local fallback = SaveSchema.default(player.UserId, starterId, starterSeed)
	local raw, mode = DataStoreAdapter.load(player.UserId)
	local profile = SaveSchema.sanitize(raw, fallback)
	profiles[player] = profile
	player:SetAttribute("PocketBuddyPersistence", mode)
	return profile
end

function PlayerProfileService.get(player: Player)
	return profiles[player]
end

function PlayerProfileService.save(player: Player)
	local profile = profiles[player]
	if profile then
		DataStoreAdapter.save(player.UserId, profile)
	end
end

function PlayerProfileService.remove(player: Player)
	profiles[player] = nil
end

return PlayerProfileService
