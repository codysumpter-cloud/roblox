"""Generate the Roblox-side Pug bone animation table from a source GLB.

The source GLB is intentionally kept outside the repository.  This script
extracts authored TRS curves, converts them to local bind-pose deltas, and
writes a compact Luau module consumed by PetAnimationAdapter.  Roblox's
Bone.Transform property cannot apply scale, so scale channels are inspected
but omitted from the runtime artifact.

Usage::

    python tools/generate_pug_bone_animation.py INPUT_GLB OUTPUT_LUA

The importer is stdlib-only so generation can run in CI or on a machine that
does not have Blender installed.
"""

from __future__ import annotations

import json
import math
import struct
import sys
from pathlib import Path
from typing import Any


COMPONENTS = {
    "SCALAR": 1,
    "VEC2": 2,
    "VEC3": 3,
    "VEC4": 4,
}


def read_glb(path: Path) -> tuple[dict[str, Any], bytes]:
    blob = path.read_bytes()
    if blob[:4] != b"glTF":
        raise ValueError(f"Not a GLB: {path}")
    _, version, length = struct.unpack_from("<4sII", blob, 0)
    if version != 2 or length > len(blob):
        raise ValueError(f"Unsupported GLB header in {path}")
    offset = 12
    json_chunk: bytes | None = None
    bin_chunk = b""
    while offset < length:
        chunk_length, chunk_type = struct.unpack_from("<II", blob, offset)
        offset += 8
        chunk = blob[offset : offset + chunk_length]
        offset += chunk_length
        if chunk_type == 0x4E4F534A:
            json_chunk = chunk
        elif chunk_type == 0x004E4942:
            bin_chunk = chunk
    if json_chunk is None:
        raise ValueError(f"GLB has no JSON chunk: {path}")
    return json.loads(json_chunk.decode("utf-8").rstrip(" \t\r\n\0")), bin_chunk


def accessor_values(gltf: dict[str, Any], binary: bytes, index: int) -> list[tuple[float, ...]]:
    accessor = gltf["accessors"][index]
    if accessor.get("componentType") != 5126:
        raise ValueError(f"Accessor {index} is not float32")
    width = COMPONENTS[accessor["type"]]
    view = gltf["bufferViews"][accessor["bufferView"]]
    start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    stride = view.get("byteStride", width * 4)
    values: list[tuple[float, ...]] = []
    for item in range(accessor["count"]):
        offset = start + item * stride
        values.append(struct.unpack_from("<" + "f" * width, binary, offset))
    return values


def qnorm(q: tuple[float, float, float, float]) -> tuple[float, float, float, float]:
    length = math.sqrt(sum(value * value for value in q))
    if length <= 1e-12:
        return (0.0, 0.0, 0.0, 1.0)
    return tuple(value / length for value in q)  # type: ignore[return-value]


def qconj(q: tuple[float, float, float, float]) -> tuple[float, float, float, float]:
    return (-q[0], -q[1], -q[2], q[3])


def qmul_raw(a: tuple[float, float, float, float], b: tuple[float, float, float, float]) -> tuple[float, float, float, float]:
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return (
        aw * bx + ax * bw + ay * bz - az * by,
        aw * by - ax * bz + ay * bw + az * bx,
        aw * bz + ax * by - ay * bx + az * bw,
        aw * bw - ax * bx - ay * by - az * bz,
    )


def qmul(a: tuple[float, float, float, float], b: tuple[float, float, float, float]) -> tuple[float, float, float, float]:
    return qnorm(qmul_raw(a, b))


def qrotate(q: tuple[float, float, float, float], value: tuple[float, float, float]) -> tuple[float, float, float]:
    rotated = qmul_raw(qmul_raw(q, (value[0], value[1], value[2], 0.0)), qconj(q))
    return rotated[:3]


def interpolate(values: list[tuple[float, ...]], times: list[float], t: float, step: str) -> tuple[float, ...]:
    if len(times) == 1 or t <= times[0]:
        return values[0]
    if t >= times[-1]:
        return values[-1]
    upper = next(index for index, value in enumerate(times) if value >= t)
    lower = upper - 1
    if step == "STEP":
        return values[lower]
    alpha = (t - times[lower]) / max(times[upper] - times[lower], 1e-9)
    return tuple(a + (b - a) * alpha for a, b in zip(values[lower], values[upper]))


def fmt(value: float) -> str:
    rounded = round(float(value), 5)
    if abs(rounded) < 0.000005:
        rounded = 0.0
    return f"{rounded:.5f}".rstrip("0").rstrip(".") or "0"


def lua_array(values: list[float]) -> str:
    return "{" + ",".join(fmt(value) for value in values) + "}"


def lua_int_array(values: list[float], scale: int) -> str:
    return "{" + ",".join(str(round(value * scale)) for value in values) + "}"


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("Usage: generate_pug_bone_animation.py INPUT_GLB OUTPUT_LUA")
    source = Path(sys.argv[1]).resolve()
    destination = Path(sys.argv[2]).resolve()
    gltf, binary = read_glb(source)

    nodes = gltf.get("nodes", [])
    animated_nodes = {
        node_index: node
        for node_index, node in enumerate(nodes)
        if isinstance(node.get("name"), str)
    }
    bones = [node["name"] for node in animated_nodes.values() if node["name"] != "Armature"]

    # The GLB contains an armature wrapper and a skinned mesh node.  Bone names
    # are the nodes referenced by the skin joints, which avoids accidentally
    # emitting render-only nodes if the source changes later.
    skin_joints = set(gltf.get("skins", [{}])[0].get("joints", []))
    bones = [nodes[index]["name"] for index in skin_joints if isinstance(nodes[index].get("name"), str)]
    bones.sort()

    node_defaults: dict[str, tuple[tuple[float, float, float], tuple[float, float, float, float]]] = {}
    for index in skin_joints:
        node = nodes[index]
        node_defaults[node["name"]] = (
            tuple(node.get("translation", [0.0, 0.0, 0.0])),
            qnorm(tuple(node.get("rotation", [0.0, 0.0, 0.0, 1.0]))),
        )

    clips: dict[str, dict[str, Any]] = {}
    for animation in gltf.get("animations", []):
        name = animation.get("name", "")
        key = name.lower()
        if key not in {"idle", "walk", "walkslow", "run", "jump"}:
            continue
        channels_by_node: dict[int, dict[str, tuple[list[float], list[tuple[float, ...]], str]]] = {}
        duration = 0.0
        for channel in animation["channels"]:
            target = channel["target"]
            node_index = target["node"]
            if node_index not in skin_joints:
                continue
            sampler = animation["samplers"][channel["sampler"]]
            times = [item[0] for item in accessor_values(gltf, binary, sampler["input"])]
            values = accessor_values(gltf, binary, sampler["output"])
            duration = max(duration, times[-1])
            channels_by_node.setdefault(node_index, {})[target["path"]] = (
                times,
                values,
                sampler.get("interpolation", "LINEAR"),
            )

        tracks: dict[str, dict[str, Any]] = {}
        for node_index, channels in channels_by_node.items():
            node_name = nodes[node_index]["name"]
            rest_translation, rest_rotation = node_defaults[node_name]
            sample_times = sorted({time for times, _, _ in channels.values() for time in times})
            poses: list[tuple[float, ...]] = []
            for time in sample_times:
                if "translation" in channels:
                    translation = interpolate(
                        channels["translation"][1],
                        channels["translation"][0],
                        time,
                        channels["translation"][2],
                    )
                else:
                    translation = rest_translation
                if "rotation" in channels:
                    rotation = qnorm(interpolate(
                        channels["rotation"][1],
                        channels["rotation"][0],
                        time,
                        channels["rotation"][2],
                    ))
                else:
                    rotation = rest_rotation
                delta_translation = qrotate(qconj(rest_rotation), tuple(a - b for a, b in zip(translation, rest_translation)))
                delta_rotation = qmul(qconj(rest_rotation), rotation)
                # Blender's exporter bakes constraint/IK evaluation into translation
                # channels on every pose bone. Applying those offsets again through
                # Roblox Bone.Transform changes bone lengths and visibly stretches
                # legs. The imported rest rig already owns joint positions, so keep
                # the pack's authored rotations and strip baked translations.
                delta_translation = (0.0, 0.0, 0.0)
                poses.append((*delta_translation, *delta_rotation))

            # Do not emit untouched bones; the runtime resets every bone to its
            # captured imported pose before applying each clip.
            if not any(
                max(abs(value) for value in pose[:3]) > 0.00005
                or max(abs(value) for value in pose[3:6]) > 0.00005
                for pose in poses
            ):
                continue
            tracks[node_name] = {"times": sample_times, "poses": poses}
        clips[key] = {"name": name, "duration": duration, "tracks": tracks}

    if set(clips) != {"idle", "walk", "walkslow", "run", "jump"}:
        raise ValueError(f"Missing required clips: {sorted(set(('idle', 'walk', 'walkslow', 'run', 'jump')) - set(clips))}")

    lines = [
        "--!strict",
        "-- GENERATED FILE: do not hand-edit; regenerate from the preserved Quaternius GLB.",
        f"-- Source: {source.name}",
        "return {",
        "    version = 1,",
        "    timeScale = 1000,",
        "    valueScale = 1000,",
        "    bones = {" + ",".join(f'\"{bone}\"' for bone in bones) + "},",
        "    clips = {",
    ]
    for key in ("idle", "walkslow", "walk", "run", "jump"):
        clip = clips[key]
        lines += [
            f"        {key} = {{",
            f"            duration = {fmt(clip['duration'])},",
            "            tracks = {",
        ]
        for bone_name in sorted(clip["tracks"]):
            track = clip["tracks"][bone_name]
            lines += [
                f'                [{json.dumps(bone_name)}] = {{',
                f"                    times = {lua_int_array(track['times'], 1000)},",
                "                    values = {",
            ]
            flattened = [value for pose in track["poses"] for value in pose]
            lines += [f"                        {','.join(str(round(value * 1000)) for value in flattened)},"]
            lines += ["                    },", "                },"]
        lines += ["            },", "        },"]
    lines += ["    },", "}", ""]
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text("\n".join(lines), encoding="utf-8")
    print(f"Generated {destination} ({len(bones)} bones, {len(clips)} clips, {sum(len(clip['tracks']) for clip in clips.values())} tracks)")


if __name__ == "__main__":
    main()
