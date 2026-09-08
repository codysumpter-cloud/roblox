--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local HitboxService = {}

local function characterRoot(player: Player): (Model?, BasePart?)
	local character = player.Character
	if not character then return nil, nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then return character, nil end
	return character, root
end

local function hasLineOfSight(attackerCharacter: Model, targetCharacter: Model, attackerRoot: BasePart, targetRoot: BasePart): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { attackerCharacter }
	local hit = Workspace:Raycast(attackerRoot.Position, targetRoot.Position - attackerRoot.Position, params)
	return hit == nil or hit.Instance:IsDescendantOf(targetCharacter)
end

function HitboxService.findPlayerTargets(attacker: Player, attack, maxRange: number): {Player}
	local character, root = characterRoot(attacker)
	if not character or not root then return {} end

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.MaxParts = 64

	local size = Vector3.new(attack.Width, attack.Height, attack.Depth)
	local center = root.CFrame * CFrame.new(0, 0, -attack.ForwardOffset)
	local parts = Workspace:GetPartBoundsInBox(center, size, params)
	local seen: {[Player]: boolean} = {}
	local candidates = {}

	for _, part in parts do
		local model = part:FindFirstAncestorOfClass("Model")
		local target = model and Players:GetPlayerFromCharacter(model)
		if target and target ~= attacker and not seen[target] then
			local targetCharacter, targetRoot = characterRoot(target)
			if targetCharacter and targetRoot and hasLineOfSight(character, targetCharacter, root, targetRoot) then
				seen[target] = true
				local delta = targetRoot.Position - root.Position
				local distance = delta.Magnitude
				local forward = if distance > 0.001 then root.CFrame.LookVector:Dot(delta.Unit) else 1
				local score = forward * 2 - distance / math.max(maxRange, 1)
				table.insert(candidates, { player = target, score = score })
			end
		end
	end

	table.sort(candidates, function(a, b) return a.score > b.score end)
	local targets = {}
	local maxTargets = math.max(1, attack.MaxTargets or 1)
	for index = 1, math.min(maxTargets, #candidates) do
		table.insert(targets, candidates[index].player)
	end
	return targets
end

return HitboxService
