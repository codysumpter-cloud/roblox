--!strict
local AvatarAdapter = {}
local saved = {}

function AvatarAdapter.setCharacterVisible(character: Model, visible: boolean)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			if descendant.Name ~= "HumanoidRootPart" then
				descendant.Transparency = visible and 0 or 1
			end
		elseif descendant:IsA("Decal") then
			descendant.Transparency = visible and 0 or 1
		end
	end
end

function AvatarAdapter.enterParty(player: Player)
	local character = player.Character
	if not character then return false end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return false end
	saved[player] = {
		walkSpeed = humanoid.WalkSpeed,
		jumpPower = humanoid.JumpPower,
		autoRotate = humanoid.AutoRotate,
	}
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.AutoRotate = false
	AvatarAdapter.setCharacterVisible(character, false)
	return true
end

function AvatarAdapter.exitParty(player: Player)
	local character = player.Character
	local values = saved[player]
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = values and values.walkSpeed or 16
			humanoid.JumpPower = values and values.jumpPower or 50
			humanoid.AutoRotate = values == nil or values.autoRotate
		end
		AvatarAdapter.setCharacterVisible(character, true)
	end
	saved[player] = nil
end

function AvatarAdapter.clear(player: Player)
	saved[player] = nil
end

-- Party-mode control swapping belongs here when implemented. Hub mode must leave the player's
-- normal Roblox avatar intact; party mode may temporarily hide/freeze it while the selected pet is
-- controlled, then restore it on exit.
return AvatarAdapter
