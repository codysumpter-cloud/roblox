--!strict
local ServerStorage = game:GetService("ServerStorage")

local AdvancedAvatarAdapter = require(script.Parent.Parent.adapters.AdvancedAvatarAdapter)

local AvatarAssetService = {}
local started = false

function AvatarAssetService.start()
	if started then return end
	started = true
	local pocketBuddyAssets = ServerStorage:FindFirstChild("PocketBuddyAssets")
	local avatars = pocketBuddyAssets and pocketBuddyAssets:FindFirstChild("Avatars")
	if not avatars then
		print("[PocketBuddy] no Studio avatar catalog at ServerStorage/PocketBuddyAssets/Avatars; normal Roblox avatars remain active")
		return
	end
	for _, item in avatars:GetChildren() do
		if item:IsA("Model") then
			local report = AdvancedAvatarAdapter.tagInspection(item)
			if report.adaptiveAnimationRigReady then
				print(("[PocketBuddy] avatar rig %s maps %d/%d required joints, %d body joints, %d digit joints")
					:format(item.Name, report.r15Mapped, report.r15Required, report.bodyJointMapped, report.digitJointMapped))
			else
				warn(("[PocketBuddy] avatar rig %s is missing required Adaptive Animation joints: %s")
					:format(item.Name, table.concat(report.missingRequired, ", ")))
			end
		end
	end
end

return AvatarAssetService
