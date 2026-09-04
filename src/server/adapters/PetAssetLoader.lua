--!strict
local InsertService = game:GetService("InsertService")
local ServerStorage = game:GetService("ServerStorage")
local Registry = require(script.Parent.PetAssetRegistry)

local PetAssetLoader = {}
local cache: {[string]: Model} = {}
local warned: {[string]: boolean} = {}

local function warnOnce(key: string, message: string)
	if warned[key] then return end
	warned[key] = true
	warn(message)
end

local function canonicalTemplate(config): Model?
	local parent: Instance = ServerStorage
	for _, segment in (config.serverPath or { "PocketBuddyAssets", "Pets" }) do
		local nextParent = parent:FindFirstChild(segment)
		if not nextParent then return nil end
		parent = nextParent
	end
	local candidate = parent:FindFirstChild(config.templateName) or parent:FindFirstChild(config.displayName)
	if candidate and candidate:IsA("Model") then return candidate end
	return nil
end

local function sanitize(model: Model): boolean
	local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not root then return false end
	model.PrimaryPart = root
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("ModuleScript") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end
	return true
end

local function loadUploaded(config): Model?
	local ok, container = pcall(function()
		return InsertService:LoadAsset(tonumber(config.assetId))
	end)
	if not ok or not container then return nil end
	local model = container:IsA("Model") and container or container:FindFirstChildWhichIsA("Model", true)
	if not model then container:Destroy() return nil end
	local result = model:Clone()
	container:Destroy()
	if not sanitize(result) then result:Destroy() return nil end
	return result
end

function PetAssetLoader.loadModel(key: string, registry): (Model?, {[string]: any}?)
	local config = registry[key]
	if not config then return nil, nil end
	local cacheKey = (config.cacheNamespace or "default") .. ":" .. key
	if cache[cacheKey] then return cache[cacheKey]:Clone(), config end
	local source = canonicalTemplate(config)
	local template = source and source:Clone() or loadUploaded(config)
	if not template then
		warnOnce(key, ("[PocketBuddy] no canonical or uploaded asset available for runtime template %s"):format(key))
		return nil, config
	end
	if not sanitize(template) then
		warnOnce(key, ("[PocketBuddy] runtime template %s has no usable BasePart root"):format(key))
		template:Destroy()
		return nil, config
	end
	cache[cacheKey] = template
	return template:Clone(), config
end

function PetAssetLoader.get(key: string): (Model?, {[string]: any}?)
	return PetAssetLoader.loadModel(key, Registry)
end

function PetAssetLoader.clearCache()
	for key, template in cache do
		template:Destroy()
		cache[key] = nil
	end
end

return PetAssetLoader
