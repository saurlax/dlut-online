"""Bake previously exported campus jobs into native pixel GLB/PNG pairs."""
import argparse
import json
from pathlib import Path
import subprocess
from build_pixel_buildings import finish_model

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("campus", choices=("lingshui", "panjin"))
    parser.add_argument("--blender", default="C:/Program Files/Blender Foundation/Blender 5.1/blender.exe")
    parser.add_argument("--finish", action="store_true", help="Package an already completed bake")
    parser.add_argument("--facilities", action="store_true", help="Only bake added sports facilities")
    args = parser.parse_args()
    directory = ROOT / ".local/campus-models" / args.campus
    jobs = json.loads((directory / "jobs.json").read_text(encoding="utf-8"))
    (ROOT / "references" / args.campus / "sports-models.json").write_text(json.dumps([
        {"id":job["id"],"collisionPolygons":job["collisionPolygons"]} for job in jobs if job.get("facility")
    ],separators=(",",":"))+"\n",encoding="utf-8")
    if not args.finish:
        selected=[job for job in jobs if job.get("facility")] if args.facilities else jobs
        (directory / "selected.json").write_text(json.dumps(selected),encoding="utf-8")
        subprocess.run([args.blender, "-b", "-t", "4", "--python", str(ROOT / "tools/bake_hd2d_buildings.py"), "--", str(directory / "selected.json")], check=True)
    output = ROOT / "apps/web/public/campuses" / args.campus / "models"
    output.mkdir(parents=True, exist_ok=True)
    archive = json.loads((ROOT / "references" / args.campus / "archive.json").read_text(encoding="utf-8"))
    records = []
    for job in jobs:
        key = job["id"]
        stats = finish_model(Path(job["directory"]) / "baked.glb", output / f"{key}.glb", output / "textures" / f"{key}.png")
        records.append({"id":key,"file":f"models/{key}.glb","origin":job["origin"],"baseSource":job["baseSource"],"facility":job.get("facility",False),**stats})
    manifest = {"campus":args.campus,"source":archive,"ground":"Flat shared pixel ground; archived terrain Y is omitted.",
        "method":"Registered structural meshes; unlit native 8px/m color bake, at most 48 colors; no photo or PBR textures.","buildings":records}
    (output / "manifest.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(f"Packaged {len(records)} {args.campus} building/facility models",flush=True)


if __name__ == "__main__":
    main()
