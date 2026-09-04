--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Registry = require(script.Parent.Parent.assets.LegacyAdminEventRegistry)

local LegacyAdminEventService = {}
local started = false
local runtimeRoot: Folder? = nil
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

local function codeCount(root: Instance): number
	local count = 0
	if root:IsA("Script") or root:IsA("LocalScript") or root:IsA("ModuleScript") then count += 1 end
	for _, item in root:GetDescendants() do
		if item:IsA("Script") or item:IsA("LocalScript") or item:IsA("ModuleScript") then count += 1 end
	end
	return count
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
			local scripts = codeCount(item)
			if scripts > 0 and scripts <= spec.maxScripts then
				local score = rootScore(item, spec.preferredRootAliases) - scripts
				if score > bestScore then best, bestScore = item, score end
			end
		end
	end
	return best
end

local function prepareRuntimeClone(source: Instance, key: string): Instance
	local clone = source:Clone()
	clone.Name = "PocketBuddyLegacyEvent_" .. key
	-- LocalScripts from a server event package are not trusted/run here. ModuleScripts
	-- are preserved because the approved server Script may require them.
	if clone:IsA("LocalScript") then clone:Destroy(); return Instance.new("Folder") end
	if clone:IsA("Script") then clone.Enabled = false end
	for _, item in clone:GetDescendants() do
		if item:IsA("LocalScript") then item:Destroy()
		elseif item:IsA("Script") then item.Enabled = false end
	end
	clone:SetAttribute("PocketBuddyLegacyEvent", key)
	clone:SetAttribute("PocketBuddySourcePath", source:GetFullName())
	return clone
end

local function enableScripts(root: Instance)
	if root:IsA("Script") then root.Enabled = true end
	for _, item in root:GetDescendants() do
		if item:IsA("Script") then item.Enabled = true end
	end
end

function LegacyAdminEventService.start()
	if started then return end
	started = true
	runtimeRoot = ServerScriptService:FindFirstChild("PocketBuddyLegacyEvents") :: Folder?
	if not runtimeRoot then
		runtimeRoot = Instance.new("Folder")
		runtimeRoot.Name = "PocketBuddyLegacyEvents"
		runtimeRoot.Parent = ServerScriptService
	end
	for key in Registry do
		local source = findSource(key)
		if source then
			sourceByKey[key] = source
			print(("[PocketBuddy] approved Admin V5 event found: %s <- %s (%d code objects)")
				:format(key, source:GetFullName(), codeCount(source)))
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
	if not running then return false end
	runningByKey[key] = nil
	if running.Parent then running:Destroy() end
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
	enableScripts(clone)
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
