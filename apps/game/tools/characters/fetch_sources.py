"""Fetch or verify the pinned, CC0-only inputs for the character samples.

Uses HTTP ranges so the 268 MB system archive need not be downloaded in full.
All decoded files are SHA-256 checked before being installed in the input cache.
"""
import argparse
import concurrent.futures
import hashlib
import json
from pathlib import Path
import struct
import time
import urllib.request
import zlib

ROOT = Path(__file__).resolve().parents[4]
MANIFEST = ROOT / "references/shared/characters/source.json"


def verify(directory, manifest):
    for source in manifest["files"]:
        path = directory / source["path"]
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != source["sha256"]:
            raise ValueError(f"Missing or modified character input: {path}")


def download(directory, manifest, no_proxy=False):
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({})) if no_proxy else urllib.request.build_opener()

    def get(url, start=None, size=None):
        headers = {"User-Agent": "DLUT-Online-asset-builder/1"}
        if start is not None:
            headers["Range"] = f"bytes={start}-{start + size - 1}"
        for attempt in range(3):
            try:
                with opener.open(urllib.request.Request(url, headers=headers), timeout=60) as response:
                    if start is not None and (response.status != 206 or not response.headers.get("Content-Range", "").startswith(f"bytes {start}-{start + size - 1}/")):
                        raise ValueError("Source no longer supports the recorded byte range")
                    data = response.read()
                    if size is not None and len(data) != size:
                        raise ValueError("Incomplete asset response")
                    return data
            except Exception:
                if attempt == 2:
                    raise
                time.sleep(attempt + 1)

    def one(source):
        path = (directory / source["path"]).resolve()
        if not path.is_relative_to(directory.resolve()):
            raise ValueError("Source path outside input directory")
        if path.exists() and hashlib.sha256(path.read_bytes()).hexdigest() == source["sha256"]:
            return
        if "archive_member" in source:
            header = get(source["url"], source["header_offset"], 30)
            fields = struct.unpack("<4s5H3I2H", header)
            if fields[0] != b"PK\x03\x04":
                raise ValueError("Source ZIP changed; verify and update the manifest")
            start = source["header_offset"] + 30 + fields[-2] + fields[-1]
            size = source["compressed_size"]
            chunks = range(0, size, 262144)
            with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
                raw = b"".join(pool.map(lambda offset: get(source["url"], start + offset, min(262144, size - offset)), chunks))
            data = zlib.decompress(raw, -15) if source["compression"] == 8 else raw
        else:
            data = get(source["url"])
        if hashlib.sha256(data).hexdigest() != source["sha256"]:
            raise ValueError(f"Asset checksum mismatch: {source['path']}")
        path.parent.mkdir(parents=True, exist_ok=True)
        temporary = path.with_suffix(path.suffix + ".part")
        temporary.write_bytes(data)
        temporary.replace(path)
        print(source["path"], flush=True)

    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        list(pool.map(one, manifest["files"]))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--inputs", type=Path, default=ROOT / ".local/characters")
    parser.add_argument("--verify-only", action="store_true")
    parser.add_argument("--no-proxy", action="store_true")
    args = parser.parse_args()
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if not args.verify_only:
        download(args.inputs, data, args.no_proxy)
    verify(args.inputs, data)
    print(f"Verified {len(data['files'])} pinned character sources")
