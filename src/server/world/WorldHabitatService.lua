--!strict
-- Ensures a usable aquatic habitat in clean Rojo/Baseplate sessions. The
-- canonical authored place already contains this Terrain pond and real nature
-- assets, so this service is a no-op there.
local PetAssetLoader = require(script.Parent.Parent.adapters.PetAssetLoader)
local HabitatConfig = require(script.Parent.HabitatConfig)
local WorldAssetRegistry = require(script.Parent.WorldAssetRegistry)

local WorldHabitatService = {}
local started = false

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
	if largest > 0 then pcall(function() model:ScaleTo(targetLargestDimension / largest) end) end
end

local function place(parent: Folder, key: string, name: string, pivot: CFrame, collidable: boolean, float: boolean)
	local model, config = PetAssetLoader.loadModel(key, WorldAssetRegistry)
	if not model or not config then return end
	model.Name = name
	normalize(model, config.targetLargestDimension)
	setPhysical(model, collidable)
	model.Parent = parent
	model:PivotTo(pivot)
	if not float then
		local bounds, size = model:GetBoundingBox()
		local bottom = bounds.Position.Y - size.Y * 0.5
		model:PivotTo(model:GetPivot() + Vector3.new(0, 10 - bottom, 0))
	end
end

function WorldHabitatService.start()
	if started then return end
	started = true
	local pond = HabitatConfig.pond
	if workspace:FindFirstChild(pond.folderName) then
		print("[PocketBuddy] authored aquatic pond found")
		return
	end

	local terrain = workspace.Terrain
	terrain:FillCylinder(CFrame.new(pond.terrainAirCenter), pond.terrainAirHeight, pond.terrainAirRadius, Enum.Material.Air)
	terrain:FillCylinder(CFrame.new(pond.terrainWaterCenter), pond.terrainWaterHeight, pond.terrainWaterRadius, Enum.Material.Water)
	terrain.WaterColor = Color3.fromRGB(52, 170, 205)
	terrain.WaterTransparency = 0.22
	terrain.WaterReflectance = 0.08
	terrain.WaterWaveSize = 0.12
	terrain.WaterWaveSpeed = 8

	local folder = Instance.new("Folder")
	folder.Name = pond.folderName
	folder:SetAttribute("Habitat", "Aquatic")
	folder:SetAttribute("Center", pond.center)
	folder.Parent = workspace
	place(folder, "MossRock1", "PondRockWest", CFrame.new(171, 10, -326) * CFrame.Angles(0, math.rad(25), 0), true, false)
	place(folder, "MossRock2", "PondRockEast", CFrame.new(223, 10, -326) * CFrame.Angles(0, math.rad(-20), 0), true, false)
	place(folder, "Rock1", "PondRockNorth", CFrame.new(197, 10, -351) * CFrame.Angles(0, math.rad(10), 0), true, false)
	place(folder, "Rock2", "PondRockSouth", CFrame.new(197, 10, -301) * CFrame.Angles(0, math.rad(-15), 0), true, false)
	place(folder, "Lilypad", "PondLilypadA", CFrame.new(190, 9, -322) * CFrame.Angles(0, math.rad(15), 0), false, true)
	place(folder, "Lilypad", "PondLilypadB", CFrame.new(204, 9, -331) * CFrame.Angles(0, math.rad(-20), 0), false, true)
	place(folder, "Lilypad", "PondLilypadC", CFrame.new(199, 9, -318) * CFrame.Angles(0, math.rad(45), 0), false, true)
	print("[PocketBuddy] clean-session aquatic pond created with approved nature assets")
end

return WorldHabitatService
