--!strict
local RoundRules = {}
RoundRules.Phase = { Idle = "Idle", Countdown = "Countdown", Playing = "Playing", Results = "Results" }

function RoundRules.newState()
	return { phase = RoundRules.Phase.Idle, players = {}, eliminated = {}, winnerUserId = nil }
end

function RoundRules.remaining(state)
	local result = {}
	for _, userId in state.players do
		if not state.eliminated[userId] then
			table.insert(result, userId)
		end
	end
	return result
end

return RoundRules
