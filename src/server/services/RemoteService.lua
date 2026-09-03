--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteService = {}
local root = ReplicatedStorage:FindFirstChild("PocketBuddyRemotes") or Instance.new("Folder")
root.Name = "PocketBuddyRemotes"
root.Parent = ReplicatedStorage

local function remote(name: string): RemoteEvent
	local existing = root:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then return existing end
	local value = Instance.new("RemoteEvent")
	value.Name = name
	value.Parent = root
	return value
end

RemoteService.ProfileUpdated = remote("ProfileUpdated")
RemoteService.ProfileRequest = remote("ProfileRequest")
RemoteService.Notify = remote("Notify")
-- Clients send intents, never authoritative state. Party/controller services validate
-- the action, current phase, ownership, proximity, and this per-player cooldown.
RemoteService.Intent = remote("Intent")
RemoteService.RoundUpdated = remote("RoundUpdated")

local lastIntent = {}
function RemoteService.rateLimit(player: Player, action: string, interval: number): boolean
	local key = tostring(player.UserId) .. ":" .. action
	local now = os.clock()
	if now - (lastIntent[key] or -math.huge) < interval then
		return false
	end
	lastIntent[key] = now
	return true
end

function RemoteService.clearPlayer(player: Player)
	local prefix = tostring(player.UserId) .. ":"
	for key in lastIntent do
		if string.sub(key, 1, #prefix) == prefix then lastIntent[key] = nil end
	end
end

return RemoteService
