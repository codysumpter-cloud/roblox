--!strict

local ComboRules = {}

function ComboRules.nextIndex(lastIndex: number, elapsed: number, count: number, resetSeconds: number): number
	if count <= 0 then
		return 0
	end
	if elapsed > resetSeconds or lastIndex < 1 or lastIndex >= count then
		return 1
	end
	return lastIndex + 1
end

function ComboRules.canAct(now: number, lockedUntil: number): boolean
	return now >= lockedUntil
end

return ComboRules
