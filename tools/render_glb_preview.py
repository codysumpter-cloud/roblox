"""Render neutral QA thumbnails for one or more GLB files with Blender."""

from __future__ import annotations

import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def look_at(obj: bpy.types.Object, target: Vector) -> None:
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.armatures, bpy.data.cameras, bpy.data.lights):
        for block in list(datablocks):
            datablocks.remove(block)


def bounds() -> tuple[Vector, Vector]:
    points = []
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        points.extend(obj.matrix_world @ Vector(corner) for corner in obj.bound_box)
    if not points:
        raise RuntimeError("GLB contains no visible mesh bounds")
    return (
        Vector((min(point.x for point in points), min(point.y for point in points), min(point.z for point in points))),
        Vector((max(point.x for point in points), max(point.y for point in points), max(point.z for point in points))),
    )


def render(source: Path, destination: Path) -> None:
    reset_scene()
    bpy.ops.import_scene.gltf(filepath=str(source))
    minimum, maximum = bounds()
    center = (minimum + maximum) / 2
    size = maximum - minimum
    radius = max(size.x, size.y, size.z, 0.1)

    camera_data = bpy.data.cameras.new("QA Camera")
    camera = bpy.data.objects.new("QA Camera", camera_data)
    bpy.context.scene.collection.objects.link(camera)
    camera.location = center + Vector((radius * 1.6, -radius * 2.2, radius * 1.3))
    camera_data.lens = 55
    look_at(camera, center)
    bpy.context.scene.camera = camera

    key_data = bpy.data.lights.new("Key", type="AREA")
    key_data.energy = 900
    key_data.shape = "DISK"
    key_data.size = radius * 2.0
    key = bpy.data.objects.new("Key", key_data)
    bpy.context.scene.collection.objects.link(key)
    key.location = center + Vector((-radius * 2, -radius * 2, radius * 3))
    look_at(key, center)

    fill_data = bpy.data.lights.new("Fill", type="AREA")
    fill_data.energy = 500
    fill_data.size = radius * 2.0
    fill = bpy.data.objects.new("Fill", fill_data)
    bpy.context.scene.collection.objects.link(fill)
    fill.location = center + Vector((radius * 2, radius, radius))
    look_at(fill, center)

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.world.color = (0.035, 0.035, 0.05)
    scene.render.filepath = str(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.render.render(write_still=True)


def main() -> None:
    if "--" not in sys.argv:
        raise SystemExit("Expected GLB paths after --")
    sources = [Path(value).resolve() for value in sys.argv[sys.argv.index("--") + 1 :]]
    if not sources:
        raise SystemExit("Expected at least one GLB path")
    for source in sources:
        destination = source.parent / "previews" / f"{source.stem}.png"
        render(source, destination)
        print(f"RENDERED {source} -> {destination}", flush=True)


if __name__ == "__main__":
    main()
