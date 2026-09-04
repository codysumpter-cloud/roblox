# Asset contract

Source art lives outside Roblox as the canonical asset source (Blender/source textures/audio).
Roblox imports are runtime artifacts.

## Pet model contract (future final assets)
A final pet runtime model should expose stable semantic pieces/attachments rather than depending on
generated Part names. Target contract:
- a stable root/pivot;
- collision body appropriate for the universal pet controller;
- head/body/legs/tail attachment points where modular assembly needs them;
- animation controller/Animator integration;
- optional interaction attachment near the head/back for petting/grabbing;
- no gameplay stats encoded in model names.

The runtime adapter is the only place that should know Roblox Model/Attachment/Motor6D details.
Core pet data should remain plain part IDs + traits.

## First runtime template: Pug

The first real runtime template is selected by the portable key `runtimeTemplate = "Pug"`.
`PetRuntimeAdapter` resolves that key at runtime from the manually imported Studio asset:

```text
ServerStorage/PocketBuddyAssets/Pets/Pug
```

This ServerStorage subtree is deliberately **not** part of `default.project.json`; Rojo sync must
not delete or overwrite manually imported runtime assets. If the model is absent, the game warns
once and uses the generated placeholder so a fresh Baseplate still boots.

The imported Pug must be a reasonably scaled Model with a valid root/pivot and its rig under the
Model. Keep the source mesh/materials and animation rig intact; the runtime adapter only changes
clone/runtime properties. If an import is hundreds of studs wide, correct the import scale before
treating it as final art. Clone-time normalization is a runtime guard, not permission to keep a
broken source import.

The canonical Pug source is `Farm Animals Animated  by Quaternius/Blends/Pug.blend`. It contains
24 bones, Beige and Brown material regions, and the Idle, Walk, WalkSlow, Run, Jump, and Death
actions. The supplied `FBX/Pug.fbx` is not the complete source for this workflow. Direct Studio
imports of the older Quaternius files were observed to discard their flat material colors and
render gray/white. A single beige `Color3` is not an acceptable repair because it removes the
Pug's dark facial, ear, foot, and tail-tip regions.

Use `tools/export_quaternius_glb.py` through Blender to rebuild modern Principled shader graphs and
export material-preserving GLBs from the canonical `.blend` files. Use
`tools/render_glb_preview.py` to inspect representative exports before Roblox import. The repair
manifest must show non-default `baseColorFactor` values for the source materials, and rigged assets
must retain skins and animation clips.

Uploaded Roblox animation IDs are intentionally kept in the Roblox-only
`src/server/adapters/PetAnimationConfig.lua`. Supply IDs for `idle`, `walk`, `run`, and `jump`
after publishing the imported actions. Missing IDs are non-fatal: the pet still spawns and follows
without animation. `Death` is not used for normal gameplay.

The approved textured farm-animal roster and Roblox upload IDs are kept server-side in
`src/server/adapters/PetAssetRegistry.lua`: Pug (`101214723595393`), Cow (`80854694685461`),
Llama (`108544690208389`), Horse (`105265549474005`), Sheep (`113838729716972`),
Pig (`88505317258911`), and Zebra (`138594948463624`). These IDs were taken from the approved
textured upload receipts. `PetAssetLoader` checks the canonical ServerStorage folder first, then
uses `InsertService` for an approved registry entry, sanitizes the clone, caches it, and returns
nil for a safe placeholder fallback if Studio permissions or the asset are unavailable.

The canonical connected development place is `Test real grass` (`PlaceId 86821894064571`). Its
binary assets are Studio-managed; code remains Rojo-managed. As of the latest verified edit-mode
inspection, `ServerStorage/PocketBuddyAssets/Pets` exists but contains no Pug. Do not report the Pug
as installed until the corrected GLB has been imported at the exact canonical path and its mesh,
materials, bones, controller, and bounds have been inspected there. `PetAssetConfig.lua` holds
Roblox-only target dimensions; a valid Pug clone is normalized to a 3.5-stud largest dimension at
runtime.
