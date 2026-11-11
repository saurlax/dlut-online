"""Adapt the archived, ground-registered records to the shared pixel pipeline."""
import json
from pathlib import Path
from generate_eda_map import main as generate

ROOT = Path(__file__).resolve().parents[1]


def main():
    for campus in ("lingshui", "panjin"):
        directory = ROOT / "references" / campus
        def read(name):
            return json.loads((directory / name).read_text(encoding="utf-8"))
        source = read("campus.json")
        roads = read("osm_roads.json")
        buildings = []
        facilities={job["id"]:job for job in read("sports-models.json")}
        for feature in source["features"]:
            key=f'{feature["id"]}-{feature["part"]}'
            if feature["kind"] != "building" and key not in facilities:
                continue
            for index, ring in enumerate(feature["render_polygons"]):
                buildings.append({**feature, "id":f'{feature["id"]}-{feature["part"]}' + (f"-ring{index}" if index else ""),
                    "points":ring, "osm_id":feature["osm_id"]})
                if key in facilities:
                    buildings[-1]["collisionPolygons"]=facilities[key]["collisionPolygons"]
        overlays=list(source.get("ground_overlays",[]))
        for feature in source["features"]:
            if feature["kind"]=="plaza":
                overlays.append({"outer":feature["points"],"surface_type":"paving", "osm_id":feature["osm_id"],"osm_version":feature["osm_version"]})
        geometry = {"campus":campus,"origin":source["origin"],"spawn_xz":read("pixel-layout.json")["spawn_xz"],
            "boundary_osm_way_id":roads["boundary_osm_way_id"],"roads":roads["roads"],
            "buildings":buildings,"ground_overlays":overlays}
        (directory / "geometry.json").write_text(json.dumps(geometry,ensure_ascii=False,separators=(",",":"))+"\n",encoding="utf-8")
        (directory / "planting.json").write_text(json.dumps(read("vegetation.json"),ensure_ascii=False)+"\n",encoding="utf-8")
        (directory / "osm.osm.gz").write_bytes((directory / "mapping/osm-world.osm.gz").read_bytes())
        generate(campus)


if __name__ == "__main__":
    main()
