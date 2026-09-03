--!strict
local HttpService = game:GetService("HttpService")

local IdAdapter = {}

function IdAdapter.newPetId(): string
	return HttpService:GenerateGUID(false)
end

function IdAdapter.seed(userId: number, nonce: number): number
	local now = DateTime.now().UnixTimestampMillis
	return math.abs((now + userId * 104729 + nonce * 7919) % 2147483647)
end

return IdAdapter
