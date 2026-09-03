--!strict

local WorldArtAdapter = {}

function WorldArtAdapter.apply()
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		-- A readable lime-green backyard, without changing imported pet assets.
		-- The custom NoTextureGrass material remains in MaterialService for the
		-- place-level override configured in Studio's Material Manager.
		terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(112, 194, 89))
	end
end

return WorldArtAdapter
