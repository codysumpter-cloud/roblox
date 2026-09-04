--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Registry = require(script.Parent.Parent.assets.LegacyAdminEventRegistry)

local LegacyAdminEventService = {}
local started = false
local runtimeRoot: Folder? = nil
local state: Folder? = nil
local sourceByKey: {[string]: Instance} = {}
local runningByKey: {[string]: Instance} = {}

local function normalized(value: string): string
	return string.lower((string.gsub(value, "[%s_%-]+", "")))
end

local function matchesAny(name: string, aliases: {string}): boolean
	local candidate = normalized(name)
	for _, alias in aliases do
		if candidate == normalized(alias) then return true end
	end
	return false
end

local function codeCounts(root: Instance): (number, number, number)
	local scripts, localScripts, modules = 0, 0, 0
	local function count(item: Instance)
		if item:IsA("Script") then scripts += 1
		elseif item:IsA("LocalScript") then localScripts += 1
		elseif item:IsA("ModuleScript") then modules += 1 end
	end
	count(root)
	for _, item in root:GetDescendants() do count(item) end
	return scripts, localScripts, modules
end

local function totalCode(root: Instance): number
	local scripts, localScripts, modules = codeCounts(root)
	return scripts + localScripts + modules
end

local function rootScore(item: Instance, preferredAliases: {string}): number
	local score = 0
	local cursor = item.Parent
	while cursor and cursor ~= ServerStorage do
		if matchesAny(cursor.Name, preferredAliases) then score += 100 end
		cursor = cursor.Parent
	end
	return score
end

local function findSource(key: string): Instance?
	local spec = Registry[key]
	if not spec then return nil end
	local best: Instance? = nil
	local bestScore = -math.huge
	for _, item in ServerStorage:GetDescendants() do
		if matchesAny(item.Name, spec.aliases) then
			local serverScripts = select(1, codeCounts(item))
			local total = totalCode(item)
			if serverScripts > 0 and total <= spec.maxScripts then
				local score = rootScore(item, spec.preferredRootAliases) - total
				if score > bestScore then best, bestScore = item, score end
			end
		end
	end
	return best
end

local function setRunningState(key: string, running: boolean)
	if state then state:SetAttribute("LegacyEvent_" .. key, running) end
end

local function prepareRuntimeClone(source: Instance, key: string): Instance
	local clone = source:Clone()
	clone.Name = "PocketBuddyLegacyEvent_" .. key
	-- Preserve the approved package exactly, including LocalScripts and
	-- ModuleScripts. Only server Scripts are temporarily disabled while the clone
	-- is parented so the full package tree exists before execution begins.
	if clone:IsA("Script") then clone.Enabled = false end
	for _, item in clone:GetDescendants() do
		if item:IsA("Script") then item.Enabled = false end
	end
	clone:SetAttribute("PocketBuddyLegacyEvent", key)
	clone:SetAttribute("PocketBuddySourcePath", source:GetFullName())
	return clone
end

local function enableServerScripts(root: Instance)
	if root:IsA("Script") then root.Enabled = true end
	for _, item in root:GetDescendants() do
		if item:IsA("Script") then item.Enabled = true end
	end
end

function LegacyAdminEventService.start()
	if started then return end
	started = true
	state = ReplicatedStorage:WaitForChild("PocketBuddy"):WaitForChild("EnvironmentState") :: Folder
	runtimeRoot = ServerScriptService:FindFirstChild("PocketBuddyLegacyEvents") :: Folder?
	if not runtimeRoot then
		runtimeRoot = Instance.new("Folder")
		runtimeRoot.Name = "PocketBuddyLegacyEvents"
		runtimeRoot.Parent = ServerScriptService
	end
	for key in Registry do
		setRunningState(key, false)
		local source = findSource(key)
		if source then
			sourceByKey[key] = source
			local scripts, localScripts, modules = codeCounts(source)
			print(("[PocketBuddy] approved Admin V5 event found: %s <- %s (server=%d local=%d modules=%d)")
				:format(key, source:GetFullName(), scripts, localScripts, modules))
		else
			warn(("[PocketBuddy] approved Admin V5 event not found in ServerStorage: %s"):format(key))
		end
	end
end

function LegacyAdminEventService.available(key: string): boolean
	return sourceByKey[key] ~= nil
end

function LegacyAdminEventService.isRunning(key: string): boolean
	local running = runningByKey[key]
	return running ~= nil and running.Parent ~= nil
end

function LegacyAdminEventService.stop(key: string): boolean
	local running = runningByKey[key]
	if not running then
		setRunningState(key, false)
		return false
	end
	runningByKey[key] = nil
	if running.Parent then running:Destroy() end
	setRunningState(key, false)
	return true
end

function LegacyAdminEventService.run(key: string): boolean
	local spec = Registry[key]
	local source = sourceByKey[key]
	if not spec or not source or not runtimeRoot then return false end
	LegacyAdminEventService.stop(key)
	local clone = prepareRuntimeClone(source, key)
	clone.Parent = runtimeRoot
	runningByKey[key] = clone
	setRunningState(key, true)
	enableServerScripts(clone)
	task.delay(spec.maxRuntimeSeconds, function()
		if runningByKey[key] == clone then LegacyAdminEventService.stop(key) end
	end)
	return true
end

function LegacyAdminEventService.toggle(key: string): boolean?
	if LegacyAdminEventService.isRunning(key) then
		LegacyAdminEventService.stop(key)
		return false
	end
	if LegacyAdminEventService.run(key) then return true end
	return nil
end

function LegacyAdminEventService.report(): {[string]: any}
	local out = {}
	for key in Registry do
		out[key] = {
			available = LegacyAdminEventService.available(key),
			running = LegacyAdminEventService.isRunning(key),
			source = sourceByKey[key] and sourceByKey[key]:GetFullName() or nil,
		}
	end
	return out
end

return LegacyAdminEventService
