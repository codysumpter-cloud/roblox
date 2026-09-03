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
