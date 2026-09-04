--!strict
-- Logical runtime keys only. Roblox asset IDs stay in the server adapter registry.
local RuntimeTemplates = {}
RuntimeTemplates.values = { "Pug", "Cow", "Llama", "Horse", "Sheep", "Pig", "Zebra" }

function RuntimeTemplates.isApproved(value: string?): boolean
	if type(value) ~= "string" then return false end
	for _, candidate in RuntimeTemplates.values do
		if value == candidate then return true end
	end
	return false
end

function RuntimeTemplates.pick(seed: number): string
	local normalized = math.floor(math.abs(seed)) % #RuntimeTemplates.values
	return RuntimeTemplates.values[normalized + 1]
end

return RuntimeTemplates
