"""Validate generated native Roblox animal animation packages."""
from __future__ import annotations

import sys
import xml.etree.ElementTree as ET
from pathlib import Path

NON_LOOPING = {"Attack", "Death", "Jump"}
EXPECTED_PRIORITY = {
    "Idle": "0",
    "WalkSlow": "1",
    "Walk": "1",
    "Run": "1",
    "Swim": "1",
    "Flying": "1",
    "Attack": "2",
    "Death": "2",
    "Jump": "2",
}


def property_text(sequence: ET.Element, kind: str, name: str) -> str | None:
    return sequence.findtext(f"./Properties/{kind}[@name='{name}']")


def main() -> None:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else "src/shared/native_animations")
    failures: list[str] = []
    packages = 0
    clips = 0
    for package in sorted(path for path in root.iterdir() if path.is_dir()):
        packages += 1
        names: set[str] = set()
        for path in sorted(package.glob("*.rbxmx")):
            clips += 1
            sequence = ET.parse(path).getroot().find("./Item[@class='KeyframeSequence']")
            if sequence is None:
                failures.append(f"{path}: missing KeyframeSequence")
                continue
            name = property_text(sequence, "string", "Name")
            if name != path.stem:
                failures.append(f"{path}: internal name {name!r} does not match file")
            if name in names:
                failures.append(f"{path}: duplicate clip name")
            names.add(name or "")
            expected_loop = "false" if name in NON_LOOPING else "true"
            if property_text(sequence, "bool", "Loop") != expected_loop:
                failures.append(f"{path}: incorrect Loop value")
            expected_priority = EXPECTED_PRIORITY.get(name or "")
            if expected_priority is None or property_text(sequence, "token", "Priority") != expected_priority:
                failures.append(f"{path}: incorrect Priority value")
            keyframes = sequence.findall("./Item[@class='Keyframe']")
            if not keyframes:
                failures.append(f"{path}: no keyframes")
                continue
            reference = [pose.findtext("./Properties/string[@name='Name']") for pose in keyframes[0].iter("Item") if pose.get("class") == "Pose"]
            if not reference or any(not value for value in reference):
                failures.append(f"{path}: empty pose hierarchy")
            for index, keyframe in enumerate(keyframes[1:], start=2):
                current = [pose.findtext("./Properties/string[@name='Name']") for pose in keyframe.iter("Item") if pose.get("class") == "Pose"]
                if current != reference:
                    failures.append(f"{path}: pose hierarchy changes at keyframe {index}")
                    break
    if failures:
        raise SystemExit("\n".join(failures))
    print(f"validated packages={packages} clips={clips}")


if __name__ == "__main__":
    main()
