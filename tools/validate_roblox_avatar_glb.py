#!/usr/bin/env python3
"""Preflight a GLB/glTF humanoid for the Pocket Buddy -> Roblox rig contract.

This is deliberately a source-asset validator, not a Marketplace validator.
Avatar Setup still owns cages, body partitioning, attachments, FACS, moderation,
and final Advanced R15 validation inside Roblox Studio.
"""
from __future__ import annotations

import argparse
import json
import pathlib
import struct
import sys

ALIASES = {
    "Root": ["Root", "root"],
    "Waist": ["Waist", "Hips", "pelvis"],
    "Spine": ["Spine", "spine_01"],
    "Chest": ["Chest", "UpperChest", "spine_03", "spine_05"],
    "Neck": ["Neck", "neck_01"],
    "HeadBase": ["HeadBase", "Head", "head"],
    "LeftClavicle": ["LeftClavicle", "LeftShoulder", "clavicle_l"],
    "LeftShoulder": ["LeftShoulder", "LeftUpperArm", "upperarm_l"],
    "LeftElbow": ["LeftElbow", "LeftLowerArm", "lowerarm_l"],
    "LeftWrist": ["LeftWrist", "LeftHand", "hand_l"],
    "RightClavicle": ["RightClavicle", "RightShoulder", "clavicle_r"],
    "RightShoulder": ["RightShoulder", "RightUpperArm", "upperarm_r"],
    "RightElbow": ["RightElbow", "RightLowerArm", "lowerarm_r"],
    "RightWrist": ["RightWrist", "RightHand", "hand_r"],
    "LeftHip": ["LeftHip", "LeftUpperLeg", "thigh_l"],
    "LeftKnee": ["LeftKnee", "LeftLowerLeg", "calf_l"],
    "LeftAnkle": ["LeftAnkle", "LeftFoot", "foot_l"],
    "LeftToeBase": ["LeftToeBase", "LeftToes", "ball_l"],
    "RightHip": ["RightHip", "RightUpperLeg", "thigh_r"],
    "RightKnee": ["RightKnee", "RightLowerLeg", "calf_r"],
    "RightAnkle": ["RightAnkle", "RightFoot", "foot_r"],
    "RightToeBase": ["RightToeBase", "RightToes", "ball_r"],
}
REQUIRED = [
    "Root", "Waist", "Neck",
    "LeftShoulder", "LeftElbow", "LeftWrist",
    "RightShoulder", "RightElbow", "RightWrist",
    "LeftHip", "LeftKnee", "LeftAnkle",
    "RightHip", "RightKnee", "RightAnkle",
]
DIGITS = {
    "LeftThumb1": ["LeftThumbMetacarpal", "LeftThumbProximal", "thumb_01_l"],
    "LeftThumb2": ["LeftThumbProximal", "thumb_02_l"],
    "LeftThumb3": ["LeftThumbDistal", "thumb_03_l"],
    "LeftIndex1": ["LeftIndexProximal", "index_01_l"], "LeftIndex2": ["LeftIndexIntermediate", "index_02_l"], "LeftIndex3": ["LeftIndexDistal", "index_03_l"],
    "LeftMiddle1": ["LeftMiddleProximal", "middle_01_l"], "LeftMiddle2": ["LeftMiddleIntermediate", "middle_02_l"], "LeftMiddle3": ["LeftMiddleDistal", "middle_03_l"],
    "LeftRing1": ["LeftRingProximal", "ring_01_l"], "LeftRing2": ["LeftRingIntermediate", "ring_02_l"], "LeftRing3": ["LeftRingDistal", "ring_03_l"],
    "LeftPinky1": ["LeftLittleProximal", "pinky_01_l"], "LeftPinky2": ["LeftLittleIntermediate", "pinky_02_l"], "LeftPinky3": ["LeftLittleDistal", "pinky_03_l"],
    "RightThumb1": ["RightThumbMetacarpal", "RightThumbProximal", "thumb_01_r"],
    "RightThumb2": ["RightThumbProximal", "thumb_02_r"],
    "RightThumb3": ["RightThumbDistal", "thumb_03_r"],
    "RightIndex1": ["RightIndexProximal", "index_01_r"], "RightIndex2": ["RightIndexIntermediate", "index_02_r"], "RightIndex3": ["RightIndexDistal", "index_03_r"],
    "RightMiddle1": ["RightMiddleProximal", "middle_01_r"], "RightMiddle2": ["RightMiddleIntermediate", "middle_02_r"], "RightMiddle3": ["RightMiddleDistal", "middle_03_r"],
    "RightRing1": ["RightRingProximal", "ring_01_r"], "RightRing2": ["RightRingIntermediate", "ring_02_r"], "RightRing3": ["RightRingDistal", "ring_03_r"],
    "RightPinky1": ["RightLittleProximal", "pinky_01_r"], "RightPinky2": ["RightLittleIntermediate", "pinky_02_r"], "RightPinky3": ["RightLittleDistal", "pinky_03_r"],
}


def read_document(path: pathlib.Path) -> dict:
    if path.suffix.lower() == ".gltf":
        return json.loads(path.read_text(encoding="utf-8"))
    raw = path.read_bytes()
    if len(raw) < 20 or raw[:4] != b"glTF":
        raise ValueError("not a GLB 2.0 file")
    version, _length = struct.unpack_from("<II", raw, 4)
    if version != 2:
        raise ValueError(f"unsupported GLB version {version}")
    offset = 12
    while offset + 8 <= len(raw):
        length, chunk_type = struct.unpack_from("<II", raw, offset)
        offset += 8
        chunk = raw[offset:offset + length]
        offset += length
        if chunk_type == 0x4E4F534A:  # JSON
            return json.loads(chunk.rstrip(b"\x00 \t\r\n").decode("utf-8"))
    raise ValueError("GLB has no JSON chunk")


def first_match(names: dict[str, str], aliases: list[str]) -> str | None:
    for alias in aliases:
        if alias.lower() in names:
            return names[alias.lower()]
    return None


def inspect(path: pathlib.Path) -> dict:
    doc = read_document(path)
    nodes = doc.get("nodes", [])
    joint_indices = set()
    for skin in doc.get("skins", []):
        joint_indices.update(skin.get("joints", []))
    names = {}
    for index in joint_indices:
        if isinstance(index, int) and 0 <= index < len(nodes):
            name = nodes[index].get("name")
            if isinstance(name, str) and name:
                names[name.lower()] = name
    mapped = {semantic: first_match(names, aliases) for semantic, aliases in ALIASES.items()}
    digits = {semantic: first_match(names, aliases) for semantic, aliases in DIGITS.items()}
    missing = [semantic for semantic in REQUIRED if not mapped[semantic]]
    return {
        "file": str(path),
        "skins": len(doc.get("skins", [])),
        "skin_joint_count": len(joint_indices),
        "required_mapped": len(REQUIRED) - len(missing),
        "required_total": len(REQUIRED),
        "body_joint_mapped": sum(bool(value) for value in mapped.values()),
        "digit_joint_mapped": sum(bool(value) for value in digits.values()),
        "missing_required": missing,
        "adaptive_animation_preflight": not missing,
        "mapped": mapped,
        "digits": digits,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("asset", type=pathlib.Path)
    parser.add_argument("--json", dest="json_path", type=pathlib.Path)
    args = parser.parse_args()
    try:
        report = inspect(args.asset)
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2
    if args.json_path:
        args.json_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    status = "PASS" if report["adaptive_animation_preflight"] else "FAIL"
    print(f"ROBLOX_AVATAR_PREFLIGHT_{status}")
    print(f"skins={report['skins']} joints={report['skin_joint_count']} required={report['required_mapped']}/{report['required_total']} body={report['body_joint_mapped']}/22 digits={report['digit_joint_mapped']}/30")
    if report["missing_required"]:
        print("missing=" + ",".join(report["missing_required"]))
    return 0 if report["adaptive_animation_preflight"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
