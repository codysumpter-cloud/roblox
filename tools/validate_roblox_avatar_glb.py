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
    "Waist": ["Waist", "Hips", "pelvis", "J_Bip_C_Hips"],
    "Spine": ["Spine", "spine_01", "J_Bip_C_Spine"],
    "Chest": ["Chest", "UpperChest", "spine_03", "spine_05", "J_Bip_C_Chest", "J_Bip_C_UpperChest"],
    "Neck": ["Neck", "neck_01", "J_Bip_C_Neck"],
    "HeadBase": ["HeadBase"],
    "LeftClavicle": ["LeftClavicle", "clavicle_l", "J_Bip_L_Shoulder"],
    "LeftShoulder": ["LeftShoulder", "LeftUpperArm", "upperarm_l", "J_Bip_L_UpperArm"],
    "LeftElbow": ["LeftElbow", "LeftLowerArm", "lowerarm_l", "J_Bip_L_LowerArm"],
    "LeftWrist": ["LeftWrist", "LeftHand", "hand_l", "J_Bip_L_Hand"],
    "RightClavicle": ["RightClavicle", "clavicle_r", "J_Bip_R_Shoulder"],
    "RightShoulder": ["RightShoulder", "RightUpperArm", "upperarm_r", "J_Bip_R_UpperArm"],
    "RightElbow": ["RightElbow", "RightLowerArm", "lowerarm_r", "J_Bip_R_LowerArm"],
    "RightWrist": ["RightWrist", "RightHand", "hand_r", "J_Bip_R_Hand"],
    "LeftHip": ["LeftHip", "LeftUpperLeg", "thigh_l", "J_Bip_L_UpperLeg"],
    "LeftKnee": ["LeftKnee", "LeftLowerLeg", "calf_l", "J_Bip_L_LowerLeg"],
    "LeftAnkle": ["LeftAnkle", "LeftFoot", "foot_l", "J_Bip_L_Foot"],
    "LeftToeBase": ["LeftToeBase", "LeftToes", "ball_l", "J_Bip_L_ToeBase"],
    "RightHip": ["RightHip", "RightUpperLeg", "thigh_r", "J_Bip_R_UpperLeg"],
    "RightKnee": ["RightKnee", "RightLowerLeg", "calf_r", "J_Bip_R_LowerLeg"],
    "RightAnkle": ["RightAnkle", "RightFoot", "foot_r", "J_Bip_R_Foot"],
    "RightToeBase": ["RightToeBase", "RightToes", "ball_r", "J_Bip_R_ToeBase"],
}
REQUIRED = [
    "Root", "Waist", "Neck",
    "LeftShoulder", "LeftElbow", "LeftWrist",
    "RightShoulder", "RightElbow", "RightWrist",
    "LeftHip", "LeftKnee", "LeftAnkle",
    "RightHip", "RightKnee", "RightAnkle",
]
DIGITS = {
    "LeftThumb1": ["LeftThumbMetacarpal", "LeftThumbProximal", "thumb_01_l", "J_Bip_L_Thumb1"],
    "LeftThumb2": ["LeftThumbProximal", "thumb_02_l", "J_Bip_L_Thumb2"],
    "LeftThumb3": ["LeftThumbDistal", "thumb_03_l", "J_Bip_L_Thumb3"],
    "LeftIndex1": ["LeftIndexProximal", "index_01_l", "J_Bip_L_Index1"],
    "LeftIndex2": ["LeftIndexIntermediate", "index_02_l", "J_Bip_L_Index2"],
    "LeftIndex3": ["LeftIndexDistal", "index_03_l", "J_Bip_L_Index3"],
    "LeftMiddle1": ["LeftMiddleProximal", "middle_01_l", "J_Bip_L_Middle1"],
    "LeftMiddle2": ["LeftMiddleIntermediate", "middle_02_l", "J_Bip_L_Middle2"],
    "LeftMiddle3": ["LeftMiddleDistal", "middle_03_l", "J_Bip_L_Middle3"],
    "LeftRing1": ["LeftRingProximal", "ring_01_l", "J_Bip_L_Ring1"],
    "LeftRing2": ["LeftRingIntermediate", "ring_02_l", "J_Bip_L_Ring2"],
    "LeftRing3": ["LeftRingDistal", "ring_03_l", "J_Bip_L_Ring3"],
    "LeftPinky1": ["LeftLittleProximal", "pinky_01_l", "J_Bip_L_Little1"],
    "LeftPinky2": ["LeftLittleIntermediate", "pinky_02_l", "J_Bip_L_Little2"],
    "LeftPinky3": ["LeftLittleDistal", "pinky_03_l", "J_Bip_L_Little3"],
    "RightThumb1": ["RightThumbMetacarpal", "RightThumbProximal", "thumb_01_r", "J_Bip_R_Thumb1"],
    "RightThumb2": ["RightThumbProximal", "thumb_02_r", "J_Bip_R_Thumb2"],
    "RightThumb3": ["RightThumbDistal", "thumb_03_r", "J_Bip_R_Thumb3"],
    "RightIndex1": ["RightIndexProximal", "index_01_r", "J_Bip_R_Index1"],
    "RightIndex2": ["RightIndexIntermediate", "index_02_r", "J_Bip_R_Index2"],
    "RightIndex3": ["RightIndexDistal", "index_03_r", "J_Bip_R_Index3"],
    "RightMiddle1": ["RightMiddleProximal", "middle_01_r", "J_Bip_R_Middle1"],
    "RightMiddle2": ["RightMiddleIntermediate", "middle_02_r", "J_Bip_R_Middle2"],
    "RightMiddle3": ["RightMiddleDistal", "middle_03_r", "J_Bip_R_Middle3"],
    "RightRing1": ["RightRingProximal", "ring_01_r", "J_Bip_R_Ring1"],
    "RightRing2": ["RightRingIntermediate", "ring_02_r", "J_Bip_R_Ring2"],
    "RightRing3": ["RightRingDistal", "ring_03_r", "J_Bip_R_Ring3"],
    "RightPinky1": ["RightLittleProximal", "pinky_01_r", "J_Bip_R_Little1"],
    "RightPinky2": ["RightLittleIntermediate", "pinky_02_r", "J_Bip_R_Little2"],
    "RightPinky3": ["RightLittleDistal", "pinky_03_r", "J_Bip_R_Little3"],
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
    print(
        f"skins={report['skins']} joints={report['skin_joint_count']} "
        f"required={report['required_mapped']}/{report['required_total']} "
        f"body={report['body_joint_mapped']}/22 digits={report['digit_joint_mapped']}/30"
    )
    if report["missing_required"]:
        print("missing=" + ",".join(report["missing_required"]))
    return 0 if report["adaptive_animation_preflight"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
