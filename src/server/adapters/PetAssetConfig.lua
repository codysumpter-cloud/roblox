--!strict

-- Roblox-only runtime asset metadata. Portable pet data stores only the logical key.
return {
	Pug = {
		templateName = "Pug",
		targetLargestDimension = 3.5,
		-- The imported Quaternius FBX has material colors rather than image
		-- textures. Studio flattened the original two-slot import to one MeshPart,
		-- so the Studio-managed source has its warm beige base color restored.
		appearance = "quaternius-fbx-material-color; no-external-texture",
	},
}
