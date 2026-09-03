--!strict
local TraitRules = {}

function TraitRules.fromParts(parts)
	local traits = {
		speed = 1,
		jump = 1,
		pushResistance = 1,
		swim = 1,
		chargedJump = 1,
	}

	if parts.body == "chunky" then
		traits.pushResistance *= 1.10
		traits.speed *= 0.94
	elseif parts.body == "tiny" then
		traits.speed *= 1.08
		traits.pushResistance *= 0.86
	elseif parts.body == "long" then
		traits.speed *= 1.03
	end

	if parts.legs == "long" then
		traits.jump *= 1.10
	elseif parts.legs == "frog" then
		traits.jump *= 1.05
		traits.chargedJump *= 1.22
	end

	if parts.tail == "otter" then
		traits.swim *= 1.25
	end

	return traits
end

return TraitRules
