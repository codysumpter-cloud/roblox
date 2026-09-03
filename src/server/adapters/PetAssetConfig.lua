--!strict

-- Roblox-only runtime asset metadata. Portable pet data stores only the logical key.
return {
	Pug = {
		templateName = "Pug",
		targetLargestDimension = 3.5,
		-- Studio-managed source is the repaired uploaded Pug package.  This stays
		-- outside Rojo so runtime cloning preserves its mesh, rig, and textures.
		appearance = "uploaded-textured-pug-package",
	},
}
