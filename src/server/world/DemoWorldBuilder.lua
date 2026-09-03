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

function DemoWorldBuilder.build()
	local old = workspace:FindFirstChild("PocketBuddyDemoWorld")
	if old then old:Destroy() end

	local root = Instance.new("Folder")
	root.Name = "PocketBuddyDemoWorld"
	root.Parent = workspace

	makePart(root, "Backyard", Vector3.new(120, 1, 120), Vector3.new(0, -0.5, 0), Color3.fromRGB(111, 172, 92), Enum.Material.Grass)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Vector3.new(0, 0.5, 18)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Parent = root

	careStation(root, "Food Bowl", Vector3.new(-10, 0.5, 8), "feed", Color3.fromRGB(230, 153, 91))
	careStation(root, "Wash Tub", Vector3.new(0, 0.5, 8), "wash", Color3.fromRGB(91, 178, 230))
	careStation(root, "Toy Mat", Vector3.new(10, 0.5, 8), "play", Color3.fromRGB(224, 113, 180))
	careStation(root, "Pet Spot", Vector3.new(0, 0.5, 0), "pet", Color3.fromRGB(232, 211, 114))

	local hatch = makePart(root, "Hatch Nest", Vector3.new(7, 1, 7), Vector3.new(18, 0.5, -4), Color3.fromRGB(238, 220, 166))
	prompt(hatch, "HATCH", "Egg Nest")
	CollectionService:AddTag(hatch, "PocketBuddyHatchStation")

	local hiddenEgg = makePart(root, "Backyard Egg", Vector3.new(2, 2.6, 2), Vector3.new(-28, 1.3, -24), Color3.fromRGB(231, 241, 201))
	hiddenEgg.Shape = Enum.PartType.Ball
	hiddenEgg:SetAttribute("EggId", "Backyard")
	hiddenEgg:SetAttribute("WorldFlag", "found_backyard_egg_001")
	prompt(hiddenEgg, "TAKE", "??? Egg")
	CollectionService:AddTag(hiddenEgg, "PocketBuddyEggPickup")

	local couch = makePart(root, "KingOfTheCouch", Vector3.new(20, 3, 8), Vector3.new(0, 1.5, -28), Color3.fromRGB(127, 94, 171))
	makePart(root, "CouchBack", Vector3.new(20, 6, 2), Vector3.new(0, 4, -31), Color3.fromRGB(111, 80, 153))
	prompt(couch, "JOIN / LEAVE", "King of the Couch")
	CollectionService:AddTag(couch, "PocketBuddyPartyQueue")
	couch:SetAttribute("FutureGameMode", "KingOfTheCouch")

	return root
end

return DemoWorldBuilder
