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
clone/runtime properties. If an import is hundreds of studs wide, correct the FBX/Studio import
scale before moving it to the canonical ServerStorage path. A current Studio inspection found a
Pug at `Workspace.Pug` (not the canonical path), about 145 x 266 x 351 studs, with six Bones and
an AnimationController but no Animator; that asset is not considered detected until it is moved,
rescaled, and given an Animator or published animation setup. Studio also currently contains
`ServerStorage/RBX_ANIMSAVES/Pug` with `Armature|Idle` and `Armature|Jump` KeyframeSequences.
Those are editor-side animation sources, not runtime Animation asset IDs; Walk and Run are not
present there yet.

Uploaded Roblox animation IDs are intentionally kept in the Roblox-only
`src/server/adapters/PetAnimationConfig.lua`. Supply IDs for `idle`, `walk`, `run`, and `jump`
after publishing the imported actions. Missing IDs are non-fatal: the pet still spawns and follows
without animation. `Death` is not used for normal gameplay.
