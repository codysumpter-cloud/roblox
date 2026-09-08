--!strict

local TargetingRules = {}

export type Candidate = {
	distance: number,
	angleDegrees: number,
	screenDistance: number,
	hasLineOfSight: boolean,
	isCurrent: boolean?,
}

export type TargetingConfig = {
	MaxRange: number,
	SoftConeDegrees: number,
	HardConeDegrees: number,
	ScreenWeight: number,
	AngleWeight: number,
	DistanceWeight: number,
	CurrentTargetBonus: number,
}

function TargetingRules.score(candidate: Candidate, config: TargetingConfig, hardLock: boolean): number?
	if not candidate.hasLineOfSight or candidate.distance > config.MaxRange then
		return nil
	end

	local cone = if hardLock then config.HardConeDegrees else config.SoftConeDegrees
	if candidate.angleDegrees > cone * 0.5 then
		return nil
	end

	local distanceScore = 1 - math.clamp(candidate.distance / config.MaxRange, 0, 1)
	local angleScore = 1 - math.clamp(candidate.angleDegrees / math.max(cone * 0.5, 0.001), 0, 1)
	local screenScore = 1 - math.clamp(candidate.screenDistance, 0, 1)
	local sticky = if candidate.isCurrent then config.CurrentTargetBonus else 0

	return screenScore * config.ScreenWeight
		+ angleScore * config.AngleWeight
		+ distanceScore * config.DistanceWeight
		+ sticky
end

return TargetingRules
