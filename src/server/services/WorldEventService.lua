--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldEventService = {}
local started = false
local state: Folder? = nil

local EVENTS = {
	TacoRain = true,
}

function WorldEventService.start()
	if started then return end
	started = true
	local root = ReplicatedStorage:WaitForChild("PocketBuddy")
	state = root:WaitForChild("EnvironmentState") :: Folder
	state:SetAttribute("EventOwner", "PocketBuddy.WorldEventService")
	for name in EVENTS do
		if state:GetAttribute(name) == nil then state:SetAttribute(name, false) end
	end
end

function WorldEventService.set(name: string, enabled: boolean): boolean
	if not EVENTS[name] or not state then return false end
	state:SetAttribute(name, enabled)
	return true
end

function WorldEventService.toggle(name: string): boolean?
	if not EVENTS[name] or not state then return nil end
	local enabled = state:GetAttribute(name) == true
	state:SetAttribute(name, not enabled)
	return not enabled
end

function WorldEventService.get(name: string): boolean
	return state ~= nil and state:GetAttribute(name) == true
end

return WorldEventService
