--!strict

local WorldArtAdapter = {}

-- Grass terrain is the only Roblox terrain surface which draws the very tall
-- animated blades visible in the current place.  The companion hub needs a
-- readable, walkable lawn, so only its play-space is converted to LeafyGrass
-- when the server starts.  LeafyGrass still reads as grass but does not bury
-- the companion, prompts, or couch in decorative blades.
local HUB_TERRAIN_REGION = Region3.new(
	Vector3.new(-64, -32, -448),
	Vector3.new(336, 64, -80)
):ExpandToGrid(4)

function WorldArtAdapter.apply()
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		terrain:ReplaceMaterial(HUB_TERRAIN_REGION, 4, Enum.Material.Grass, Enum.Material.LeafyGrass)
		-- A warm middle green: deliberately less fluorescent than the prior lime
		-- tint, while remaining clearly lighter than the muddy base surface.
		terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(93, 161, 83))
	end
end

return WorldArtAdapter
