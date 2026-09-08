--!strict
local Workspace = game:GetService("Workspace")

local CombatGrayboxBuilder = {}

local function anchoredPart(parent: Instance, name: string, size: Vector3, position: Vector3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function spawn(parent: Instance, name: string, position: Vector3)
	local location = Instance.new("SpawnLocation")
	location.Name = name
	location.Anchored = true
	location.Neutral = true
	location.Size = Vector3.new(6, 1, 6)
	location.Position = position
	location.Transparency = 0.35
	location.Parent = parent
end

function CombatGrayboxBuilder.build()
	if Workspace:FindFirstChild("CombatGraybox") then return end
	local folder = Instance.new("Folder")
	folder.Name = "CombatGraybox"
	folder.Parent = Workspace

	anchoredPart(folder, "Floor", Vector3.new(120, 2, 120), Vector3.new(0, -1, 0))
	anchoredPart(folder, "NorthWall", Vector3.new(120, 18, 2), Vector3.new(0, 8, -60))
	anchoredPart(folder, "SouthWall", Vector3.new(120, 18, 2), Vector3.new(0, 8, 60))
	anchoredPart(folder, "WestWall", Vector3.new(2, 18, 120), Vector3.new(-60, 8, 0))
	anchoredPart(folder, "EastWall", Vector3.new(2, 18, 120), Vector3.new(60, 8, 0))

	-- LOS blockers and elevation are deliberate: they let us test target acquisition,
	-- target loss, corner peeking, launcher arcs, and knockback without art noise.
	anchoredPart(folder, "CenterCover", Vector3.new(10, 12, 10), Vector3.new(0, 6, 0))
	anchoredPart(folder, "WestCover", Vector3.new(8, 8, 22), Vector3.new(-24, 4, 12))
	anchoredPart(folder, "EastCover", Vector3.new(8, 8, 22), Vector3.new(24, 4, -12))
	anchoredPart(folder, "NorthPlatform", Vector3.new(24, 2, 16), Vector3.new(0, 5, -34))
	anchoredPart(folder, "NorthRamp", Vector3.new(12, 1, 22), Vector3.new(0, 2.2, -22)).CFrame = CFrame.new(0, 2.2, -22) * CFrame.Angles(math.rad(-14), 0, 0)

	spawn(folder, "SpawnNW", Vector3.new(-42, 1, -42))
	spawn(folder, "SpawnNE", Vector3.new(42, 1, -42))
	spawn(folder, "SpawnSW", Vector3.new(-42, 1, 42))
	spawn(folder, "SpawnSE", Vector3.new(42, 1, 42))

	print("[PocketBuddy] combat graybox built")
end

return CombatGrayboxBuilder
