--!strict
local CollectionService = game:GetService("CollectionService")
local DemoWorldBuilder = {}

local function makePart(parent, name, size, position, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = position
	p.Anchored = true
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function prompt(part, actionText, objectText)
	local value = Instance.new("ProximityPrompt")
	value.ActionText = actionText
	value.ObjectText = objectText
	value.HoldDuration = 0.15
	value.MaxActivationDistance = 10
	value.Parent = part
end

local function careStation(parent, name, position, action, color)
	local p = makePart(parent, name, Vector3.new(4, 1, 4), position, color)
	p:SetAttribute("CareAction", action)
	prompt(p, string.upper(action), name)
	CollectionService:AddTag(p, "PocketBuddyCareStation")
	return p
end

local function authoredSpawn(): SpawnLocation?
	local direct = workspace:FindFirstChildWhichIsA("SpawnLocation")
	if direct then return direct end
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("SpawnLocation") then
			return descendant
		end
	end
	return nil
end

local function authoredSpawnPosition(): Vector3
	local spawn = authoredSpawn()
	if spawn then return spawn.Position end
	return Vector3.new(0, 0.5, 18)
end

function DemoWorldBuilder.build()
	local old = workspace:FindFirstChild("PocketBuddyDemoWorld")
	if old then old:Destroy() end

	local root = Instance.new("Folder")
	root.Name = "PocketBuddyDemoWorld"
	root.Parent = workspace

	-- The place owns its authored ground, terrain, grass, lighting, and dressing.
	-- This builder only adds gameplay-critical markers and interaction stations.
	local spawnPosition = authoredSpawnPosition()
	local groundY = spawnPosition.Y + 0.5

	if not authoredSpawn() then
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Spawn"
		spawn.Size = Vector3.new(8, 1, 8)
		spawn.Position = spawnPosition
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.Parent = root
	end

	careStation(root, "Food Bowl", spawnPosition + Vector3.new(-10, groundY - spawnPosition.Y, 8), "feed", Color3.fromRGB(230, 153, 91))
	careStation(root, "Wash Tub", spawnPosition + Vector3.new(0, groundY - spawnPosition.Y, 8), "wash", Color3.fromRGB(91, 178, 230))
	careStation(root, "Toy Mat", spawnPosition + Vector3.new(10, groundY - spawnPosition.Y, 8), "play", Color3.fromRGB(224, 113, 180))
	careStation(root, "Pet Spot", spawnPosition + Vector3.new(0, groundY - spawnPosition.Y, -10), "pet", Color3.fromRGB(232, 211, 114))

	local hatch = makePart(root, "Hatch Nest", Vector3.new(7, 1, 7), spawnPosition + Vector3.new(18, groundY - spawnPosition.Y, -4), Color3.fromRGB(238, 220, 166))
	prompt(hatch, "HATCH", "Egg Nest")
	CollectionService:AddTag(hatch, "PocketBuddyHatchStation")

	local hiddenEgg = makePart(root, "Backyard Egg", Vector3.new(2, 2.6, 2), spawnPosition + Vector3.new(-28, groundY - spawnPosition.Y + 0.8, -24), Color3.fromRGB(231, 241, 201))
	hiddenEgg.Shape = Enum.PartType.Ball
	hiddenEgg:SetAttribute("EggId", "Backyard")
	hiddenEgg:SetAttribute("WorldFlag", "found_backyard_egg_001")
	prompt(hiddenEgg, "TAKE", "??? Egg")
	CollectionService:AddTag(hiddenEgg, "PocketBuddyEggPickup")

	local couch = makePart(root, "KingOfTheCouch", Vector3.new(20, 3, 8), spawnPosition + Vector3.new(0, groundY - spawnPosition.Y + 1, -28), Color3.fromRGB(127, 94, 171))
	makePart(root, "CouchBack", Vector3.new(20, 6, 2), spawnPosition + Vector3.new(0, groundY - spawnPosition.Y + 3.5, -31), Color3.fromRGB(111, 80, 153))
	prompt(couch, "JOIN / LEAVE", "King of the Couch")
	CollectionService:AddTag(couch, "PocketBuddyPartyQueue")
	couch:SetAttribute("FutureGameMode", "KingOfTheCouch")

	return root
end

return DemoWorldBuilder
