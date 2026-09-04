--!strict
-- Non-destructive inventory of Studio-managed packages. Imported scripts are
-- treated as candidate systems, not junk. This module never destroys, disables,
-- reparents, or executes source content.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local StudioPackageInventory = {}
local started = false

type PackageSummary = {
	path: string,
	className: string,
	scripts: number,
	localScripts: number,
	moduleScripts: number,
	models: number,
	folders: number,
	sounds: number,
	particles: number,
	animations: number,
	guis: number,
	lightingObjects: number,
}

local function ensureFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then return existing end
	if existing then existing:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function summarize(root: Instance): PackageSummary
	local summary: PackageSummary = {
		path = root:GetFullName(),
		className = root.ClassName,
		scripts = 0,
		localScripts = 0,
		moduleScripts = 0,
		models = 0,
		folders = 0,
		sounds = 0,
		particles = 0,
		animations = 0,
		guis = 0,
		lightingObjects = 0,
	}
	for _, item in root:GetDescendants() do
		if item:IsA("Script") then summary.scripts += 1
		elseif item:IsA("LocalScript") then summary.localScripts += 1
		elseif item:IsA("ModuleScript") then summary.moduleScripts += 1
		elseif item:IsA("Model") then summary.models += 1
		elseif item:IsA("Folder") then summary.folders += 1
		elseif item:IsA("Sound") then summary.sounds += 1
		elseif item:IsA("ParticleEmitter") then summary.particles += 1
		elseif item:IsA("Animation") then summary.animations += 1
		elseif item:IsA("ScreenGui") or item:IsA("SurfaceGui") or item:IsA("BillboardGui") then summary.guis += 1
		elseif item:IsA("Sky") or item:IsA("Atmosphere") or item:IsA("BloomEffect") or item:IsA("ColorCorrectionEffect") or item:IsA("SunRaysEffect") or item:IsA("DepthOfFieldEffect") then
			summary.lightingObjects += 1
		end
	end
	return summary
end

local function codeCount(summary: PackageSummary): number
	return summary.scripts + summary.localScripts + summary.moduleScripts
end

function StudioPackageInventory.scan(): {PackageSummary}
	local summaries = {}
	for _, child in ServerStorage:GetChildren() do
		local summary = summarize(child)
		if codeCount(summary) > 0 or summary.particles > 0 or summary.animations > 0 or summary.lightingObjects > 0 or summary.guis > 0 then
			table.insert(summaries, summary)
		end
	end
	table.sort(summaries, function(a, b) return a.path < b.path end)
	return summaries
end

function StudioPackageInventory.start(): {PackageSummary}
	if started then return StudioPackageInventory.scan() end
	started = true
	local summaries = StudioPackageInventory.scan()
	local root = ReplicatedStorage:WaitForChild("PocketBuddy")
	local report = ensureFolder(root, "StudioPackageInventory")
	for _, child in report:GetChildren() do child:Destroy() end

	for index, summary in summaries do
		local entry = Instance.new("Folder")
		entry.Name = string.format("%03d_%s", index, string.gsub(string.match(summary.path, "[^%.]+$") or "Package", "[^%w_]", "_"))
		entry:SetAttribute("Path", summary.path)
		entry:SetAttribute("ClassName", summary.className)
		entry:SetAttribute("Scripts", summary.scripts)
		entry:SetAttribute("LocalScripts", summary.localScripts)
		entry:SetAttribute("ModuleScripts", summary.moduleScripts)
		entry:SetAttribute("Models", summary.models)
		entry:SetAttribute("Sounds", summary.sounds)
		entry:SetAttribute("Particles", summary.particles)
		entry:SetAttribute("Animations", summary.animations)
		entry:SetAttribute("Guis", summary.guis)
		entry:SetAttribute("LightingObjects", summary.lightingObjects)
		entry.Parent = report
		print(("[PocketBuddy] Studio package candidate: %s scripts=%d local=%d modules=%d particles=%d animations=%d gui=%d lighting=%d")
			:format(summary.path, summary.scripts, summary.localScripts, summary.moduleScripts, summary.particles, summary.animations, summary.guis, summary.lightingObjects))
	end
	return summaries
end

return StudioPackageInventory
