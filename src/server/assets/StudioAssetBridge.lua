--!strict
-- Curates presentation/runtime assets from Studio-managed source packages.
-- Rojo intentionally does not own ServerStorage/PocketBuddyAssets, so imported
-- models/effects/scripts remain intact there. This bridge strips executable code
-- only from the COPIES it exposes to clients; executable package integration is
-- handled separately by explicit services such as LegacyAdminEventService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local StudioAssetBridge = {}
local started = false

local function ensureFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then return existing end
	if existing then existing:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function isCode(instance: Instance): boolean
	return instance:IsA("Script") or instance:IsA("LocalScript") or instance:IsA("ModuleScript")
end

local function sanitizedClone(source: Instance, name: string?): Instance?
	if isCode(source) or not source.Archivable then return nil end
	local clone = source:Clone()
	if name then clone.Name = name end
	for _, descendant in clone:GetDescendants() do
		if isCode(descendant) then descendant:Destroy() end
	end
	clone:SetAttribute("PocketBuddyImported", true)
	clone:SetAttribute("PocketBuddySourceName", source:GetFullName())
	return clone
end

local function putClone(source: Instance?, destination: Folder, name: string): boolean
	if not source then return false end
	local existing = destination:FindFirstChild(name)
	if existing then return true end
	local clone = sanitizedClone(source, name)
	if not clone then return false end
	clone.Parent = destination
	return true
end

local function lowerName(instance: Instance): string
	return string.lower(instance.Name)
end

local function findFirst(predicate: (Instance) -> boolean): Instance?
	for _, item in ServerStorage:GetDescendants() do
		if not isCode(item) and predicate(item) then return item end
	end
	return nil
end

local function namedLike(tokens: {string}, classes: {string}?): Instance?
	return findFirst(function(item)
		if classes then
			local classAllowed = false
			for _, className in classes do
				if item:IsA(className) then classAllowed = true break end
			end
			if not classAllowed then return false end
		end
		local name = lowerName(item)
		for _, token in tokens do
			if string.find(name, token, 1, true) then return true end
		end
		return false
	end)
end

local function visualContainerLike(tokens: {string}): Instance?
	return namedLike(tokens, { "Model", "Folder", "BasePart", "Attachment" })
end

local function copyFolderChildren(source: Instance?, destination: Folder): number
	if not source then return 0 end
	local count = 0
	for _, child in source:GetChildren() do
		if destination:FindFirstChild(child.Name) then continue end
		local clone = sanitizedClone(child)
		if clone then clone.Parent = destination; count += 1 end
	end
	return count
end

function StudioAssetBridge.start(): {[string]: number}
	if started then return {} end
	started = true

	local root = ReplicatedStorage:WaitForChild("PocketBuddy")
	local weatherAssets = ensureFolder(root, "WeatherAssets")
	local fxAssets = ensureFolder(root, "FXAssets")
	local eventAssets = ensureFolder(root, "EventAssets")
	local adminAssets = ensureFolder(root, "AdminAssets")
	local humanoidAssets = ensureFolder(root, "HumanoidAssets")
	local animationAssets = ensureFolder(humanoidAssets, "Animations")

	local report = { weather = 0, fx = 0, events = 0, admin = 0, humanoidAnimations = 0 }

	-- Prefer explicitly organized folders, then fall back to conservative name matching.
	local pocketBuddyAssets = ServerStorage:FindFirstChild("PocketBuddyAssets")
	local weatherFolder = pocketBuddyAssets and (pocketBuddyAssets:FindFirstChild("WeatherAssets") or pocketBuddyAssets:FindFirstChild("Weather"))
		or ServerStorage:FindFirstChild("WeatherAssets") or ServerStorage:FindFirstChild("Weather")
	if weatherFolder then report.weather += copyFolderChildren(weatherFolder, weatherAssets) end

	if putClone(namedLike({ "rainparticles", "rain particles" }, { "Model", "Folder", "BasePart", "Attachment" })
		or visualContainerLike({ "rain" }), weatherAssets, "RainParticles") then report.weather += 1 end
	if putClone(namedLike({ "rainsound", "rain sound" }, { "Sound" }), weatherAssets, "RainSound") then report.weather += 1 end
	if putClone(visualContainerLike({ "snow" }), weatherAssets, "SnowParticles") then report.weather += 1 end
	if putClone(namedLike({ "snowsound", "snow sound" }, { "Sound" }), weatherAssets, "SnowSound") then report.weather += 1 end
	if putClone(visualContainerLike({ "fog" }), weatherAssets, "FogVisual") then report.weather += 1 end
	if putClone(visualContainerLike({ "lightning" }), weatherAssets, "LightningVisual") then report.weather += 1 end

	local fxFolder = pocketBuddyAssets and (pocketBuddyAssets:FindFirstChild("FXLibrary") or pocketBuddyAssets:FindFirstChild("Effects") or pocketBuddyAssets:FindFirstChild("VFX"))
		or ServerStorage:FindFirstChild("FXLibrary") or ServerStorage:FindFirstChild("AnimeFXPack")
	if fxFolder then report.fx += copyFolderChildren(fxFolder, fxAssets) end
	if putClone(namedLike({ "healed", "heal" }, { "BasePart", "Model", "Folder" }), fxAssets, "Healed") then report.fx += 1 end

	-- These are fallback presentation assets only. If the real Admin V5 Raining
	-- Tacos package is approved and found, LegacyAdminEventService runs that intact
	-- package and AdminService keeps the synthetic fallback disabled.
	if putClone(visualContainerLike({ "rainingtacos", "raining tacos", "tacorain", "taco rain" }), eventAssets, "RainingTacos") then report.events += 1 end
	if putClone(namedLike({ "taco" }, { "Sound" }), eventAssets, "TacoSound") then report.events += 1 end

	-- Preserve an imported admin panel as a presentation skin. The original panel
	-- and all of its scripts remain untouched in ServerStorage; this replicated
	-- copy intentionally contains no executable code.
	local adminGui = namedLike({ "admin v5", "adminv5", "admin" }, { "ScreenGui" })
	if putClone(adminGui, adminAssets, "AdminPanel") then report.admin += 1 end

	-- Published Roblox Animation objects can live in Studio-managed folders. The
	-- client GASP controller consumes semantic attributes/names from this clone.
	local animationFolder = pocketBuddyAssets and (pocketBuddyAssets:FindFirstChild("HumanoidAnimations", true) or pocketBuddyAssets:FindFirstChild("Animations", true))
	if animationFolder then
		for _, item in animationFolder:GetDescendants() do
			if item:IsA("Animation") and item.AnimationId ~= "" then
				local semantic = item:GetAttribute("Semantic")
				local name = if type(semantic) == "string" and semantic ~= "" then semantic else item.Name
				if putClone(item, animationAssets, string.lower(name)) then report.humanoidAnimations += 1 end
			end
		end
	end

	local reportFolder = ensureFolder(root, "RuntimeAssetReport")
	for key, value in report do reportFolder:SetAttribute(key, value) end
	print(("[PocketBuddy] Studio assets curated: weather=%d fx=%d events=%d admin=%d humanoidAnimations=%d")
		:format(report.weather, report.fx, report.events, report.admin, report.humanoidAnimations))
	return report
end

return StudioAssetBridge
