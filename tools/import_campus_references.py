"""Import verified Lingshui/Panjin records from a local archived Git commit."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def archived(ref, path):
    data = subprocess.check_output(["git", "show", f"{ref}:{path}"], cwd=ROOT)
    if data.startswith(b"version https://git-lfs.github.com/spec/v1"):
        digest = data.decode().split("oid sha256:")[1].split()[0]
        data = (ROOT / ".git/lfs/objects" / digest[:2] / digest[2:4] / digest).read_bytes()
        if hashlib.sha256(data).hexdigest() != digest:
            raise ValueError(f"Invalid local archive: {path}")
    return data


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_ref")
    args = parser.parse_args()
    commit = subprocess.check_output(["git", "rev-parse", args.source_ref], cwd=ROOT).decode().strip()
    paths = subprocess.check_output(["git", "ls-tree", "-r", "--name-only", commit, "references"], cwd=ROOT).decode().splitlines()
    for path in paths:
        if path.startswith("references/shared/") and path.endswith((".json", ".md")):
            destination=ROOT/path
            destination.parent.mkdir(parents=True,exist_ok=True)
            destination.write_bytes(archived(commit,path))
    for campus in ("lingshui", "panjin"):
        directory = ROOT / "references" / campus
        for path in paths:
            if path.startswith(f"references/{campus}/") and path != f"references/{campus}/README.md" and path.endswith((".json", ".md", ".osm.gz")):
                destination = ROOT / path
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(archived(commit, path))
        prefix = f"apps/game/assets/campuses/{campus}/"
        for name in ("campus", "osm_roads", "vegetation"):
            (directory / f"{name}.json").write_bytes(archived(commit, prefix + f"data/{name}.json"))
        source = prefix + f"models/{campus}_campus.tscn"
        scene = archived(commit, source).decode()
        # Remove offline PBR references before opening the archived scene.
        import re
        scene = re.sub(r'^\[ext_resource[^\n]*\n', '', scene, flags=re.M)
        scene = re.sub(r'^.*ExtResource\([^\n]*\n', '', scene, flags=re.M)
        temporary = ROOT / ".local/campus-models" / campus
        temporary.mkdir(parents=True, exist_ok=True)
        (temporary.parent / "project.godot").write_text('[application]\nconfig/name="Offline campus export"\n',encoding="utf-8")
        (temporary / "source.tscn").write_text(scene, encoding="utf-8")
        (directory / "archive.json").write_text(json.dumps({"commit": commit, "scene": source,
            "sceneSha256": hashlib.sha256(archived(commit, source)).hexdigest(),
            "method": "Local Git archive and verified existing object cache; no network or LFS fetch."}, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
