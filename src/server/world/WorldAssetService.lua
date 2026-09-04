--!strict
local PetAssetLoader = require(script.Parent.Parent.adapters.PetAssetLoader)
local Registry = require(script.Parent.WorldAssetRegistry)
local Manifest = require(script.Parent.WorldManifest)

local WorldAssetService = {}
local ROOT_NAME = "PocketBuddyRuntimeArt"

local function setPhysical(model: Model, collidable: boolean)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = collidable
			descendant.CanTouch = false
			descendant.CanQuery = collidable
		end
	end
end

local function normalize(model: Model, targetLargestDimension: number?)
	if not targetLargestDimension then return end
	local _, size = model:GetBoundingBox()
	local largest = math.max(size.X, size.Y, size.Z)
	if largest <= 0 then return end
	pcall(function() model:ScaleTo(targetLargestDimension / largest) end)
end

local function placeOnGround(model: Model, pivot: CFrame)
	model:PivotTo(pivot)
	local bounds, size = model:GetBoundingBox()
	local bottom = bounds.Position.Y - size.Y / 2
	model:PivotTo(model:GetPivot() + Vector3.new(0, pivot.Position.Y - bottom, 0))
end

local function hideGeneratedHubVisuals()
	local hub = workspace:FindFirstChild("PocketBuddyHub")
	if not hub then return end
	for _, child in hub:GetChildren() do
		if child:IsA("BasePart") then
			-- Preserve invisible collision/query parts used by gameplay, but remove
			-- the colored primitive presentation layer.
			child.Transparency = 1
			child.CastShadow = false
		end
	end
end

local function cloneAuthoredBench(parent: Instance): Model?
	local sourceMap = workspace:FindFirstChild("cartoony map")
	local source = sourceMap and sourceMap:FindFirstChild("Bench")
	if not source or not source:IsA("Model") then return nil end
	local clone = source:Clone()
	clone.Name = "KingOfTheCouchSeat"
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("ModuleScript")
			or descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction") then
			descendant:Destroy()
		end
	end
	normalize(clone, 18)
	setPhysical(clone, true)
	clone.Parent = parent
	placeOnGround(clone, CFrame.new(136, 10, -254) * CFrame.Angles(0, math.rad(180), 0))
	return clone
end

function WorldAssetService.build()
	local old = workspace:FindFirstChild(ROOT_NAME)
	if old then old:Destroy() end
	local root = Instance.new("Folder")
	root.Name = ROOT_NAME
	root.Parent = workspace

	hideGeneratedHubVisuals()
	local placed = 0
	for _, placement in Manifest do
		local model, config = PetAssetLoader.loadModel(placement.key, Registry)
		if model and config then
			model.Name = placement.name
			normalize(model, config.targetLargestDimension)
			setPhysical(model, placement.collidable == true)
			model.Parent = root
			placeOnGround(model, placement.pivot)
			placed += 1
		end
	end
	if cloneAuthoredBench(root) then placed += 1 end
	print(("[PocketBuddy] real world assets placed=%d"):format(placed))
	return root
end

return WorldAssetService
