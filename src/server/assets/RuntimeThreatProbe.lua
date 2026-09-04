--!strict
-- Diagnostic-only probe for infected free-model behavior. It never destroys or
-- disables anything. The goal is to fingerprint the exact offender (path/image
-- asset/script insertion) so quarantine can be surgical instead of deleting good
-- pack scripts.

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local RuntimeThreatProbe = {}
local started = false
local report: Folder? = nil
local sequence = 0

local function ensureReport(): Folder
	local existing = ServerStorage:FindFirstChild("PocketBuddyRuntimeThreatReport")
	if existing and existing:IsA("Folder") then return existing end
	if existing then existing:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = "PocketBuddyRuntimeThreatReport"
	folder.Parent = ServerStorage
	return folder
end

local function safePath(instance: Instance): string
	local ok, path = pcall(function() return instance:GetFullName() end)
	return if ok then path else instance.Name
end

local function nearestPart(instance: Instance): BasePart?
	local cursor: Instance? = instance
	while cursor do
		if cursor:IsA("BasePart") then return cursor end
		cursor = cursor.Parent
	end
	return nil
end

local function imageId(instance: Instance): string?
	if instance:IsA("Decal") or instance:IsA("Texture") then return instance.Texture end
	if instance:IsA("ImageLabel") or instance:IsA("ImageButton") then return instance.Image end
	return nil
end

local function record(kind: string, instance: Instance, details: {[string]: any}?)
	if not report then return end
	sequence += 1
	local entry = Instance.new("Folder")
	entry.Name = string.format("%05d_%s", sequence, kind)
	entry:SetAttribute("Kind", kind)
	entry:SetAttribute("Path", safePath(instance))
	entry:SetAttribute("ClassName", instance.ClassName)
	entry:SetAttribute("Name", instance.Name)
	entry:SetAttribute("ObservedAt", os.clock())
	if details then
		for key, value in details do
			if type(value) == "string" or type(value) == "number" or type(value) == "boolean" then
				entry:SetAttribute(key, value)
			end
		end
	end
	entry.Parent = report
	warn(("[PocketBuddy][threat-probe] %s %s (%s)"):format(kind, safePath(instance), instance.ClassName))
end

local function inspectVisual(instance: Instance, existing: boolean)
	local id = imageId(instance)
	if not id or id == "" then return end
	local part = nearestPart(instance)
	local locked = part ~= nil and part.Locked
	local name = string.lower(instance.Name .. " " .. (part and part.Name or ""))
	local glitchNamed = string.find(name, "glitch", 1, true) ~= nil
	-- Existing authored images are only reported when they match the exact behavior
	-- we care about (locked or glitch-named). Newly created runtime images are
	-- recorded regardless, making it possible to correlate them with event/package runs.
	if not existing or locked or glitchNamed then
		record(existing and "existing_image_candidate" or "runtime_image_created", instance, {
			Image = id,
			LockedPart = locked,
			PartPath = part and safePath(part) or "",
			GlitchNamed = glitchNamed,
		})
	end
end

local function inspectCode(instance: Instance, existing: boolean)
	if not (instance:IsA("Script") or instance:IsA("LocalScript") or instance:IsA("ModuleScript")) then return end
	-- Source text is not readable by normal runtime scripts. Record identity and
	-- location only; Studio/source review remains necessary before quarantine.
	if not existing then
		record("runtime_code_created", instance, {
			Enabled = if instance:IsA("Script") or instance:IsA("LocalScript") then instance.Enabled else true,
		})
	end
end

local function inspect(instance: Instance, existing: boolean)
	inspectVisual(instance, existing)
	inspectCode(instance, existing)
end

function RuntimeThreatProbe.start()
	if started then return end
	started = true
	report = ensureReport()

	-- Capture suspicious authored visuals already present in the place.
	for _, item in workspace:GetDescendants() do inspect(item, true) end

	workspace.DescendantAdded:Connect(function(item) inspect(item, false) end)
	ServerScriptService.DescendantAdded:Connect(function(item) inspectCode(item, false) end)

	print("[PocketBuddy] non-destructive runtime threat probe active; suspicious images/scripts will be fingerprinted, not deleted")
end

return RuntimeThreatProbe
