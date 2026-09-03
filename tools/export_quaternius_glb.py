"""Batch-export Quaternius .blend sources to material-preserving Roblox GLBs.

Run with Blender, not system Python:
    blender --background --python tools/export_quaternius_glb.py -- OUTPUT_DIR

The source .blend files remain canonical. This creates disposable import artifacts
plus a manifest recording source materials, rig contents, and animation actions.
"""

from __future__ import annotations

import json
import os
import sys
import traceback
from pathlib import Path

import bpy


DOWNLOADS_ROOT = Path(os.environ.get("POCKET_BUDDY_DOWNLOADS", Path.home() / "Downloads"))

PACKS = {
    "farm_animals": DOWNLOADS_ROOT / "Farm Animals Animated  by Quaternius" / "Blends",
    "fish": DOWNLOADS_ROOT / "Fish Pack Animated by Quaternius" / "Blends",
    "dinosaurs": DOWNLOADS_ROOT / "Dinosaur Animated Pack - Dec 2018" / "Dinosaur Animated Pack - Dec 2018" / "Blends",
    "cars": DOWNLOADS_ROOT / "Realistic Car Pack - Nov 2018" / "Realistic Car Pack - Nov 2018" / "Blends",
    "nature": DOWNLOADS_ROOT / "Ultimate Nature Pack by Quaternius" / "Blends",
    "enemies": DOWNLOADS_ROOT / "Easy Animated Enemy Pack - Jan 2019" / "Easy Animated Enemy Pack - Jan 2019" / "Blends",
}


def output_root() -> Path:
    if "--" not in sys.argv:
        raise SystemExit("Expected output directory after --")
    args = sys.argv[sys.argv.index("--") + 1 :]
    if len(args) != 1:
        raise SystemExit("Expected exactly one output directory after --")
    root = Path(args[0]).resolve()
    root.mkdir(parents=True, exist_ok=True)
    return root


def normalize_materials() -> list[dict[str, object]]:
    result: list[dict[str, object]] = []
    for material in bpy.data.materials:
        rgba = [round(float(value), 6) for value in material.diffuse_color]
        material.use_nodes = True
        # These older .blend files predate the modern Principled shader graph.
        # Merely enabling nodes leaves an unconnected/default-white graph, which
        # is exactly why the direct Roblox imports lost every material color.
        nodes = material.node_tree.nodes
        nodes.clear()
        output = nodes.new("ShaderNodeOutputMaterial")
        principled = nodes.new("ShaderNodeBsdfPrincipled")
        # Roblox's GLB importer currently drops baseColorFactor-only colors for
        # these models. Embed a tiny real texture so the color survives upload.
        image = bpy.data.images.new(
            name=f"PB_{material.name}_Color",
            width=4,
            height=4,
            alpha=True,
        )
        image.generated_color = tuple(material.diffuse_color)
        image.pack()
        texture = nodes.new("ShaderNodeTexImage")
        texture.image = image
        texture.interpolation = "Closest"
        material.node_tree.links.new(texture.outputs["Color"], principled.inputs["Base Color"])
        material.node_tree.links.new(texture.outputs["Alpha"], principled.inputs["Alpha"])
        principled.inputs["Roughness"].default_value = 0.8
        material.node_tree.links.new(principled.outputs["BSDF"], output.inputs["Surface"])
        result.append({"name": material.name, "rgba": rgba, "embedded_texture": image.name})
    return result


def ensure_uv_layers() -> None:
    """Give texture-only flat colors a valid coordinate on every mesh."""
    for mesh in bpy.data.meshes:
        uv_layer = mesh.uv_layers.active or mesh.uv_layers.new(name="PocketBuddyColorUV")
        for loop_uv in uv_layer.data:
            loop_uv.uv = (0.5, 0.5)


def scene_manifest(source: Path, destination: Path, pack: str) -> dict[str, object]:
    ensure_uv_layers()
    objects = []
    armatures = []
    for obj in bpy.context.scene.objects:
        objects.append({
            "name": obj.name,
            "type": obj.type,
            "materials": [slot.material.name for slot in obj.material_slots if slot.material],
        })
        if obj.type == "ARMATURE":
            armatures.append({
                "name": obj.name,
                "bones": [bone.name for bone in obj.data.bones],
            })
    return {
        "pack": pack,
        "source": str(source),
        "output": str(destination),
        "materials": normalize_materials(),
        "objects": objects,
        "armatures": armatures,
        "actions": [action.name for action in bpy.data.actions],
    }


def export_one(source: Path, destination: Path, pack: str) -> dict[str, object]:
    bpy.ops.wm.open_mainfile(filepath=str(source))
    destination.parent.mkdir(parents=True, exist_ok=True)
    record = scene_manifest(source, destination, pack)
    bpy.ops.export_scene.gltf(
        filepath=str(destination),
        export_format="GLB",
        use_selection=False,
        export_materials="EXPORT",
        export_skins=True,
        export_animations=True,
        export_nla_strips=True,
        export_anim_slide_to_zero=True,
        export_yup=True,
    )
    record["bytes"] = destination.stat().st_size
    record["status"] = "exported"
    return record


def main() -> None:
    root = output_root()
    selected_pack = os.environ.get("POCKET_BUDDY_EXPORT_PACK", "").casefold()
    selected_asset = os.environ.get("POCKET_BUDDY_EXPORT_ASSET", "").casefold()
    records: list[dict[str, object]] = []
    for pack, source_dir in PACKS.items():
        if selected_pack and pack.casefold() != selected_pack:
            continue
        for source in sorted(source_dir.glob("*.blend"), key=lambda path: path.name.casefold()):
            if selected_asset and source.stem.casefold() != selected_asset:
                continue
            destination = root / pack / f"{source.stem}.glb"
            try:
                record = export_one(source, destination, pack)
                print(f"EXPORTED {pack}/{source.stem} -> {destination}", flush=True)
            except Exception as exc:  # Blender must continue through the remaining pack.
                record = {
                    "pack": pack,
                    "source": str(source),
                    "output": str(destination),
                    "status": "failed",
                    "error": str(exc),
                    "traceback": traceback.format_exc(),
                }
                print(f"FAILED {pack}/{source.stem}: {exc}", flush=True)
            records.append(record)

    manifest = root / "manifest.json"
    manifest.write_text(json.dumps(records, indent=2), encoding="utf-8")
    exported = sum(record["status"] == "exported" for record in records)
    failed = len(records) - exported
    print(f"COMPLETE exported={exported} failed={failed} manifest={manifest}", flush=True)
    if failed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
