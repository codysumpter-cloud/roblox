"""Upload material-preserving GLBs to Roblox Open Cloud with resumable receipts.

The API key is read only from ROBLOX_OPEN_CLOUD_API_KEY. It is never written to
disk or included in logs. Existing assets are not modified or deleted; each GLB
is created as a new Model so failed imports remain recoverable for comparison.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import mimetypes
import os
import random
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path


ASSETS_URL = "https://apis.roblox.com/assets/v1/assets"
OPERATIONS_URL = "https://apis.roblox.com/assets/v1/operations/{operation_id}"
MAX_UPLOAD_BYTES = 20 * 1024 * 1024


def request_json(request: urllib.request.Request, attempts: int = 7) -> dict:
    for attempt in range(attempts):
        try:
            with urllib.request.urlopen(request, timeout=90) as response:
                return json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:
            body = exc.read().decode("utf-8", errors="replace")
            if exc.code not in {429, 500, 502, 503, 504} or attempt == attempts - 1:
                raise RuntimeError(f"Roblox API returned HTTP {exc.code}: {body[:1000]}") from exc
            retry_after = exc.headers.get("Retry-After")
            delay = float(retry_after) if retry_after else min(60.0, (2**attempt) + random.random())
            time.sleep(delay)
        except urllib.error.URLError as exc:
            if attempt == attempts - 1:
                raise RuntimeError(f"Roblox API request failed: {exc.reason}") from exc
            time.sleep(min(60.0, (2**attempt) + random.random()))
    raise AssertionError("unreachable")


def multipart_body(metadata: dict, file_path: Path) -> tuple[bytes, str]:
    boundary = f"PocketBuddy-{uuid.uuid4().hex}"
    file_bytes = file_path.read_bytes()
    chunks = [
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"request\"\r\nContent-Type: application/json\r\n\r\n".encode(),
        json.dumps(metadata, separators=(",", ":")).encode(),
        b"\r\n",
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{file_path.name}\"\r\nContent-Type: {content_type(file_path)}\r\n\r\n".encode(),
        file_bytes,
        b"\r\n",
        f"--{boundary}--\r\n".encode(),
    ]
    return b"".join(chunks), boundary


def operation_id(payload: dict) -> str:
    value = payload.get("operationId") or payload.get("path") or payload.get("name")
    if not value:
        raise RuntimeError(f"Upload response did not include an operation id: {payload}")
    return str(value).rstrip("/").split("/")[-1]


def content_type(file_path: Path) -> str:
    if file_path.suffix.lower() in {".rbxm", ".rbxmx"}:
        return "model/x-rbxm"
    return mimetypes.guess_type(file_path.name)[0] or "model/gltf-binary"


def upload_one(api_key: str, user_id: str, path: Path, display_name: str, asset_type: str, description: str) -> dict:
    metadata = {
        "assetType": asset_type,
        "displayName": display_name,
        "description": description,
        "creationContext": {"creator": {"userId": user_id}, "expectedPrice": 0},
    }
    body, boundary = multipart_body(metadata, path)
    upload_request = urllib.request.Request(
        ASSETS_URL,
        data=body,
        method="POST",
        headers={"x-api-key": api_key, "Content-Type": f"multipart/form-data; boundary={boundary}"},
    )
    initial = request_json(upload_request)
    op_id = operation_id(initial)

    deadline = time.monotonic() + 600
    latest = initial
    while time.monotonic() < deadline:
        poll_request = urllib.request.Request(
            OPERATIONS_URL.format(operation_id=op_id),
            headers={"x-api-key": api_key},
        )
        latest = request_json(poll_request)
        if latest.get("done"):
            if latest.get("error"):
                raise RuntimeError(f"Asset operation {op_id} failed: {latest['error']}")
            return {"operation_id": op_id, "operation": latest}
        time.sleep(2)
    raise TimeoutError(f"Asset operation {op_id} did not finish within 10 minutes")


def read_completed(receipts_path: Path) -> set[str]:
    completed: set[str] = set()
    if not receipts_path.exists():
        return completed
    for line in receipts_path.read_text(encoding="utf-8").splitlines():
        try:
            record = json.loads(line)
        except json.JSONDecodeError:
            continue
        if record.get("status") == "uploaded":
            completed.add(record["relative_path"])
    return completed


def append_receipt(receipts_path: Path, record: dict) -> None:
    receipts_path.parent.mkdir(parents=True, exist_ok=True)
    with receipts_path.open("a", encoding="utf-8") as stream:
        stream.write(json.dumps(record, separators=(",", ":")) + "\n")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path)
    parser.add_argument("--user-id", required=True)
    parser.add_argument("--suffix", default="_Textured")
    parser.add_argument("--asset-type", choices=("Model", "Animation"), default="Model")
    parser.add_argument("--description", default="Pocket Buddy source asset reimport with embedded material textures.")
    parser.add_argument("--extension", action="append", default=[])
    parser.add_argument("--include-parent", action="store_true", help="Prefix display names with the immediate parent folder")
    parser.add_argument("--receipts", type=Path, required=True)
    parser.add_argument("--only", action="append", default=[], help="Case-insensitive asset stem; repeatable")
    parser.add_argument("--workers", type=int, default=1, choices=range(1, 9))
    args = parser.parse_args()

    api_key = os.environ.get("ROBLOX_OPEN_CLOUD_API_KEY", "").strip()
    if not api_key:
        raise SystemExit("ROBLOX_OPEN_CLOUD_API_KEY is required")

    root = args.root.resolve()
    selected = {name.casefold() for name in args.only}
    extensions = {value.lower().lstrip(".") for value in args.extension}
    if not extensions:
        extensions = {"rbxm", "rbxmx"} if args.asset_type == "Animation" else {"glb"}
    files = sorted(
        (path for path in root.rglob("*") if path.is_file() and path.suffix.lower().lstrip(".") in extensions),
        key=lambda value: str(value).casefold(),
    )
    if selected:
        files = [path for path in files if path.stem.casefold() in selected]
    completed = read_completed(args.receipts)
    print(f"READY files={len(files)} already_uploaded={len(completed)}", flush=True)

    pending: list[tuple[int, Path]] = []
    for index, path in enumerate(files, start=1):
        relative = path.relative_to(root).as_posix()
        if relative in completed:
            print(f"SKIP {index}/{len(files)} {relative}", flush=True)
            continue
        pending.append((index, path))

    def process(item: tuple[int, Path]) -> dict:
        index, path = item
        relative = path.relative_to(root).as_posix()
        record = {"relative_path": relative, "bytes": path.stat().st_size}
        if record["bytes"] > MAX_UPLOAD_BYTES:
            record.update(status="failed", error="File exceeds Roblox's 20 MB model upload limit")
            print(f"FAILED {index}/{len(files)} {relative}: file exceeds 20 MB", flush=True)
            return record
        try:
            stem = f"{path.parent.name}_{path.stem}" if args.include_parent else path.stem
            result = upload_one(api_key, args.user_id, path, f"{stem}{args.suffix}", args.asset_type, args.description)
            record.update(status="uploaded", **result)
            print(f"UPLOADED {index}/{len(files)} {relative} operation={result['operation_id']}", flush=True)
        except Exception as exc:
            record.update(status="failed", error=str(exc))
            print(f"FAILED {index}/{len(files)} {relative}: {exc}", flush=True)
        return record

    failed = 0
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as executor:
        futures = [executor.submit(process, item) for item in pending]
        for future in concurrent.futures.as_completed(futures):
            record = future.result()
            append_receipt(args.receipts, record)
            failed += record["status"] == "failed"

    print(f"COMPLETE total={len(files)} failed={failed} receipts={args.receipts.resolve()}", flush=True)
    if failed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
