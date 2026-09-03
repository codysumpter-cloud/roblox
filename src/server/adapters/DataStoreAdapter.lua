--!strict
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local Config = require(game.ReplicatedStorage.PocketBuddy.Shared.core.Config)

local DataStoreAdapter = {}
local store = DataStoreService:GetDataStore("PocketBuddy_Profile_v1")

function DataStoreAdapter.load(userId: number)
	if RunService:IsStudio() and not Config.PersistInStudio then
		return nil, "studio_session"
	end
	local ok, result = pcall(function()
		return store:GetAsync(("player:%d"):format(userId))
	end)
	if not ok then
		warn("[PocketBuddy] profile load failed", result)
		return nil, "load_failed"
	end
	return result, "persistent"
end

function DataStoreAdapter.save(userId: number, profile)
	if RunService:IsStudio() and not Config.PersistInStudio then
		return true, "studio_session"
	end
	local ok, result = pcall(function()
		store:UpdateAsync(("player:%d"):format(userId), function()
			return profile
		end)
	end)
	if not ok then
		warn("[PocketBuddy] profile save failed", result)
		return false, "save_failed"
	end
	return true, "persistent"
end

return DataStoreAdapter
