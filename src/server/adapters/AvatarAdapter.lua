--!strict
local AvatarAdapter = {}
local saved: {[Player]: any} = {}
type Fadeable = BasePart | Decal

local function hideCharacter(character: Model): {[Fadeable]: number}
	local transparencies: {[Fadeable]: number} = {}
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") or descendant:IsA("Decal") then
			transparencies[descendant] = descendant.Transparency
			descendant.Transparency = 1
		end
	end
	return transparencies
end

local function restoreCharacter(transparencies: {[Fadeable]: number})
	for instance, transparency in transparencies do
		if instance.Parent then instance.Transparency = transparency end
	end
end

function AvatarAdapter.enterParty(player: Player)
	local character = player.Character
	if not character then return false end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return false end
	local existing = saved[player]
	if existing and existing.character == character then return true end
	saved[player] = {
		character = character,
		walkSpeed = humanoid.WalkSpeed,
		jumpPower = humanoid.JumpPower,
		jumpHeight = humanoid.JumpHeight,
		autoRotate = humanoid.AutoRotate,
		transparencies = hideCharacter(character),
	}
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.AutoRotate = false
	return true
end

function AvatarAdapter.exitParty(player: Player)
	local character = player.Character
	local values = saved[player]
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and values then
			humanoid.WalkSpeed = values.walkSpeed
			humanoid.JumpPower = values.jumpPower
			humanoid.JumpHeight = values.jumpHeight
			humanoid.AutoRotate = values.autoRotate
		end
		if values and values.character == character then
			restoreCharacter(values.transparencies)
		end
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
