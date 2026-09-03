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
RemoteService.Notify = remote("Notify")

return RemoteService
