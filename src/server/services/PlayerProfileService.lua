--!strict
local Config = require(game.ReplicatedStorage.PocketBuddy.Shared.core.Config)
local SaveSchema = require(game.ReplicatedStorage.PocketBuddy.Shared.core.SaveSchema)
local DataStoreAdapter = require(script.Parent.Parent.adapters.DataStoreAdapter)
local IdAdapter = require(script.Parent.Parent.adapters.IdAdapter)

local PlayerProfileService = {}
local profiles = {}
local saveAllowed = {}
local loading = {}

function PlayerProfileService.load(player: Player)
	if profiles[player] then return profiles[player] end
	if loading[player] then return nil end
	loading[player] = true
	local starterId = IdAdapter.newPetId()
	local starterSeed = math.abs(player.UserId * Config.StarterPetSeedSalt) + 1
	local fallback = SaveSchema.default(player.UserId, starterId, starterSeed)
	local raw, mode = DataStoreAdapter.load(player.UserId)
	local profile = SaveSchema.sanitize(raw, fallback)
	loading[player] = nil
	-- A player may leave while GetAsync is yielding. Never retain a profile for a
	-- departed player, and never let that late load be saved under a new session.
	if player.Parent == nil then return nil end

	profiles[player] = profile
	saveAllowed[player] = mode ~= "load_failed"
	player:SetAttribute("PocketBuddyPersistence", mode)

	if mode == "load_failed" then
		warn(("[PocketBuddy] refusing to save fallback profile for %s because load failed"):format(player.Name))
	end

	return profile
end

function PlayerProfileService.get(player: Player)
	return profiles[player]
end

function PlayerProfileService.save(player: Player)
	local profile = profiles[player]
	if profile and saveAllowed[player] then
		DataStoreAdapter.save(player.UserId, profile)
	end
end

function PlayerProfileService.remove(player: Player)
	profiles[player] = nil
	saveAllowed[player] = nil
	loading[player] = nil
end

return PlayerProfileService
