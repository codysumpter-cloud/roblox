"""Convert original GLB animation clips to native Roblox KeyframeSequence files.

This tool only changes the storage representation. Runtime playback is owned by
Roblox Animator/AnimationTrack; no manual runtime pose sampling is generated.
"""
from __future__ import annotations

import json
import math
import struct
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

COMPONENTS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}
PRIORITY = {
    "idle": 0,
    "walkslow": 1,
    "walk": 1,
    "run": 1,
    "swim": 1,
    "flying": 1,
    "jump": 2,
    "attack": 2,
    "death": 2,
}
DISPLAY = {name: name.title() for name in PRIORITY}
DISPLAY["walkslow"] = "WalkSlow"


def read_glb(path: Path):
    blob = path.read_bytes()
    if blob[:4] != b"glTF": raise ValueError(f"Not a GLB: {path}")
    _, version, length = struct.unpack_from("<4sII", blob, 0)
    if version != 2 or length > len(blob): raise ValueError("Unsupported GLB")
    offset, document, binary = 12, None, b""
    while offset < length:
        size, kind = struct.unpack_from("<II", blob, offset); offset += 8
        chunk = blob[offset:offset + size]; offset += size
        if kind == 0x4E4F534A: document = json.loads(chunk.decode("utf-8").rstrip(" \t\r\n\0"))
        elif kind == 0x004E4942: binary = chunk
    if document is None: raise ValueError("GLB has no JSON chunk")
    return document, binary


def accessor(gltf, binary, index):
    item = gltf["accessors"][index]
    if item["componentType"] != 5126: raise ValueError("Only float32 animation accessors are supported")
    width = COMPONENTS[item["type"]]
    view = gltf["bufferViews"][item["bufferView"]]
    start = view.get("byteOffset", 0) + item.get("byteOffset", 0)
    stride = view.get("byteStride", width * 4)
    return [struct.unpack_from("<" + "f" * width, binary, start + row * stride) for row in range(item["count"])]


def qnorm(q):
    length = math.sqrt(sum(v * v for v in q))
    return tuple(v / length for v in q) if length > 1e-12 else (0.0, 0.0, 0.0, 1.0)


def qconj(q): return (-q[0], -q[1], -q[2], q[3])


def qmul_raw(a, b):
    ax, ay, az, aw = a; bx, by, bz, bw = b
    return (aw*bx + ax*bw + ay*bz - az*by, aw*by - ax*bz + ay*bw + az*bx,
            aw*bz + ax*by - ay*bx + az*bw, aw*bw - ax*bx - ay*by - az*bz)


def qmul(a, b): return qnorm(qmul_raw(a, b))


def qrotate(q, v): return qmul_raw(qmul_raw(q, (v[0], v[1], v[2], 0.0)), qconj(q))[:3]


def interpolate(values, times, t, mode):
    if len(times) == 1 or t <= times[0]: return values[0]
    if t >= times[-1]: return values[-1]
    upper = next(i for i, value in enumerate(times) if value >= t)
    lower = upper - 1
    if mode == "STEP": return values[lower]
    alpha = (t - times[lower]) / max(times[upper] - times[lower], 1e-9)
    return tuple(a + (b-a)*alpha for a, b in zip(values[lower], values[upper]))


def rotation_matrix(q):
    x, y, z, w = qnorm(q)
    return (1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w),
            2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w),
            2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y))


def fmt(value):
    value = 0.0 if abs(value) < 1e-10 else value
    return format(float(value), ".9g")


class Refs:
    def __init__(self): self.value = 0
    def next(self):
        result = f"RBX{self.value}"; self.value += 1; return result


def prop(parent, kind, name, value):
    node = ET.SubElement(parent, kind, {"name": name}); node.text = str(value); return node


def cframe(parent, position, quaternion):
    node = ET.SubElement(parent, "CoordinateFrame", {"name": "CFrame"})
    fields = ("X","Y","Z","R00","R01","R02","R10","R11","R12","R20","R21","R22")
    for name, value in zip(fields, (*position, *rotation_matrix(quaternion))):
        child = ET.SubElement(node, name); child.text = fmt(value)


def pose(parent, bone_index, nodes, children, transforms, refs):
    item = ET.SubElement(parent, "Item", {"class": "Pose", "referent": refs.next()})
    props = ET.SubElement(item, "Properties")
    prop(props, "string", "Name", nodes[bone_index]["name"])
    position, quaternion = transforms[bone_index]
    cframe(props, position, quaternion)
    prop(props, "float", "Weight", "1")
    prop(props, "float", "MaskWeight", "0")
    prop(props, "token", "EasingDirection", "0")
    prop(props, "token", "EasingStyle", "0")
    for child in children.get(bone_index, []): pose(item, child, nodes, children, transforms, refs)


def write_sequence(path, name, samples, nodes, roots, children, loop, priority):
    refs = Refs(); root = ET.Element("roblox", {"version": "4"})
    sequence = ET.SubElement(root, "Item", {"class": "KeyframeSequence", "referent": refs.next()})
    props = ET.SubElement(sequence, "Properties")
    prop(props, "string", "Name", name)
    prop(props, "bool", "Loop", "true" if loop else "false")
    prop(props, "token", "Priority", priority)
    for time, transforms in samples:
        keyframe = ET.SubElement(sequence, "Item", {"class": "Keyframe", "referent": refs.next()})
        kprops = ET.SubElement(keyframe, "Properties")
        prop(kprops, "string", "Name", "Keyframe")
        prop(kprops, "float", "Time", fmt(time))
        for bone in roots: pose(keyframe, bone, nodes, children, transforms, refs)
    ET.indent(root, space="  ")
    path.parent.mkdir(parents=True, exist_ok=True)
    ET.ElementTree(root).write(path, encoding="utf-8", xml_declaration=False)


def main():
    if len(sys.argv) != 4: raise SystemExit("usage: export_native_keyframe_sequences.py INPUT.glb OUTPUT_DIR TEMPLATE")
    source, destination, template = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
    gltf, binary = read_glb(source); nodes = gltf["nodes"]
    joints = set(gltf["skins"][0]["joints"])
    parents = {}
    for index, node in enumerate(nodes):
        for child in node.get("children", []): parents[child] = index
    children = {joint: [child for child in nodes[joint].get("children", []) if child in joints] for joint in joints}
    roots = sorted(joint for joint in joints if parents.get(joint) not in joints)
    defaults = {joint: (tuple(nodes[joint].get("translation", (0,0,0))), qnorm(tuple(nodes[joint].get("rotation", (0,0,0,1))))) for joint in joints}
    exported = []
    for animation in gltf.get("animations", []):
        authored_name = animation.get("name", "")
        key = authored_name.lower().rsplit("_", 1)[-1]
        if key not in PRIORITY: continue
        channels = {}
        for channel in animation["channels"]:
            target = channel["target"]; joint = target["node"]
            if joint not in joints or target["path"] not in {"translation", "rotation"}: continue
            sampler = animation["samplers"][channel["sampler"]]
            times = [row[0] for row in accessor(gltf, binary, sampler["input"])]
            values = accessor(gltf, binary, sampler["output"])
            channels.setdefault(joint, {})[target["path"]] = (times, values, sampler.get("interpolation", "LINEAR"))
        sample_times = sorted({time for joint in channels.values() for curve in joint.values() for time in curve[0]})
        samples = []
        for time in sample_times:
            transforms = {}
            for joint in joints:
                rest_t, rest_q = defaults[joint]; curves = channels.get(joint, {})
                animated_t = interpolate(curves["translation"][1], curves["translation"][0], time, curves["translation"][2]) if "translation" in curves else rest_t
                animated_q = qnorm(interpolate(curves["rotation"][1], curves["rotation"][0], time, curves["rotation"][2])) if "rotation" in curves else rest_q
                transforms[joint] = (qrotate(qconj(rest_q), tuple(a-b for a,b in zip(animated_t, rest_t))), qmul(qconj(rest_q), animated_q))
            samples.append((time, transforms))
        clip_name = DISPLAY[key]
        output = destination / template / f"{clip_name}.rbxmx"
        write_sequence(
            output,
            clip_name,
            samples,
            nodes,
            roots,
            children,
            key not in {"attack", "jump", "death"},
            PRIORITY[key],
        )
        exported.append((clip_name, len(samples), sample_times[-1] if sample_times else 0))
    if not exported: raise ValueError(f"No supported clips in {source}")
    print(json.dumps({"template": template, "source": str(source), "clips": exported}))


if __name__ == "__main__": main()
