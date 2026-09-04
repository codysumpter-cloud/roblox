"""Export the canonical Pug GLB into one FBX per authored animation action.

Run from Blender:
    blender --background --python tools/export_pug_animation_fbx.py -- INPUT_GLB OUTPUT_DIR

These FBX files are import-ready source artifacts for Roblox Studio's Animation
Editor.  Publishing them remains a Studio/account action; no animation IDs are
invented here.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import bpy


def arguments() -> tuple[Path, Path]:
    argv = sys.argv
    if "--" not in argv:
        raise SystemExit("Expected INPUT_GLB OUTPUT_DIR after --")
    values = argv[argv.index("--") + 1 :]
    if len(values) != 2:
        raise SystemExit("Expected INPUT_GLB OUTPUT_DIR")
    return Path(values[0]).resolve(), Path(values[1]).resolve()


def select_rig_and_meshes(rig: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    for item in bpy.context.scene.objects:
        if item.type == "MESH" and item.find_armature() == rig:
            item.select_set(True)
    bpy.context.view_layer.objects.active = rig


def main() -> None:
    source, output = arguments()
    if not source.is_file():
        raise SystemExit(f"Missing source: {source}")
    output.mkdir(parents=True, exist_ok=True)

    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(source))

    rigs = [item for item in bpy.context.scene.objects if item.type == "ARMATURE"]
    if len(rigs) != 1:
        raise SystemExit(f"Expected one armature, found {len(rigs)}")
    rig = rigs[0]
    if not bpy.data.actions:
        raise SystemExit("No animation actions found")
    if rig.animation_data is None:
        rig.animation_data_create()

    exported: list[dict[str, object]] = []
    for action in sorted(bpy.data.actions, key=lambda item: item.name):
        action_name = action.name.replace("/", "_").replace("\\", "_")
        lower_name = action_name.lower()
        if lower_name not in {"idle", "walk", "walkslow", "run", "jump", "death"}:
            continue
        rig.animation_data.action = action
        frame_start, frame_end = action.frame_range
        bpy.context.scene.frame_start = int(frame_start)
        bpy.context.scene.frame_end = int(frame_end)
        select_rig_and_meshes(rig)
        destination = output / f"Pug_{action_name}.fbx"
        bpy.ops.export_scene.fbx(
            filepath=str(destination),
            use_selection=True,
            add_leaf_bones=False,
            bake_anim=True,
            bake_anim_use_all_actions=False,
            bake_anim_use_nla_strips=False,
            bake_anim_force_startend_keying=True,
            path_mode="COPY",
            embed_textures=False,
        )
        exported.append({
            "action": action.name,
            "file": destination.name,
            "frameStart": frame_start,
            "frameEnd": frame_end,
        })

    (output / "manifest.json").write_text(
        json.dumps({"source": str(source), "exports": exported}, indent=2),
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
