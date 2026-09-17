"""Build an offline footprint comparison/editor, never a game resource.

Run with --download to explicitly fetch public OSM ways and official 2D tiles.
Multipolygon relations use the verified campus archive and are read-only.
Subsequent runs reuse the cache under .local/footprint-review without networking.
Only the Python standard library is required. Paths do not depend on cwd.
"""

import argparse
import base64
from datetime import datetime, timezone
import hashlib
from http.server import HTTPServer, SimpleHTTPRequestHandler
import json
import math
from pathlib import Path
import urllib.request
import xml.etree.ElementTree as ET
import osm_world

ROOT = Path(__file__).resolve().parents[3]
CONFIG = ROOT / "references/shared/mapping/footprint-review.json"
TEMPLATE = Path(__file__).with_suffix(".html")


def project(lon, lat, zoom):
    scale = 256 * 2 ** zoom
    return [(lon + 180) / 360 * scale,
            (1 - math.asinh(math.tan(math.radians(lat))) / math.pi) / 2 * scale]


def centroid(points):
    edges = list(zip(points, points[1:] + points[:1]))
    area2 = sum(a[0] * b[1] - b[0] * a[1] for a, b in edges)
    if abs(area2) < 1e-15:
        raise ValueError("Degenerate polygon")
    return [sum((a[i] + b[i]) * (a[0] * b[1] - b[0] * a[1])
                for a, b in edges) / (3 * area2) for i in (0, 1)]


def fetch(url, cache, download, image=False):
    key = hashlib.sha256(url.encode()).hexdigest()
    path = cache / key
    meta_path = cache / (key + ".json")
    if not path.exists() or not meta_path.exists():
        if not download:
            raise RuntimeError(f"Missing cached source; run with --download: {url}")
        request = urllib.request.Request(url, headers={"User-Agent": "DLUT-Online-footprint-review/1.0"})
        with urllib.request.urlopen(request, timeout=45) as response:
            body = response.read()
        if image and not (body.startswith(b"\x89PNG\r\n\x1a\n") or body.startswith(b"\xff\xd8")):
            raise ValueError(f"Not an image: {url}")
        if not image:
            ET.fromstring(body)
        meta = {"url": url, "retrieved": datetime.now(timezone.utc).isoformat(),
                "sha256": hashlib.sha256(body).hexdigest()}
        path.write_bytes(body)
        meta_path.write_text(json.dumps(meta, indent=2), encoding="utf-8")
    body = path.read_bytes()
    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    if meta["sha256"] != hashlib.sha256(body).hexdigest():
        raise ValueError(f"Cache checksum mismatch: {url}")
    return body, meta


def build_case(case, config, cache, download):
    campus, fid = case["campus"], case["official_id"]
    wid = case.get("osm_way_id")
    rid = case.get("osm_relation_id")
    if bool(wid) == bool(rid):
        raise ValueError("Exactly one OSM way or relation identity is required")
    source_path = ROOT / f"references/{campus}/mapping/bounds.json"
    source = json.loads(source_path.read_text(encoding="utf-8"))
    matches = [f for f in source["result"] if str(f["id"]) == fid]
    if len(matches) != 1:
        raise ValueError(f"Expected one official outline for {campus}/{fid}")
    official = [[p["x"], p["y"]] for p in matches[0]["bound"]["points"]]
    if official[-1] == official[0]:
        official.pop()
    holes = []
    if rid:
        archive_meta, raw_nodes, ways, relations = osm_world.archive(campus)
        way = relations[str(rid)]
        rings = osm_world.relation_rings(way,ways,raw_nodes)
        outers = [r['lon_lat'] for r in rings if r['role']=='outer']
        if len(outers)!=1:
            raise ValueError("Relation comparison currently requires one outer ring")
        osm = outers[0]
        holes = [r['lon_lat'] for r in rings if r['role']=='inner']
        member_ids = {m.get('ref') for m in way.findall('member')}
        node_ids = {n.get('ref') for member in member_ids for n in ways[member].findall('nd')}
        xml = ET.Element('osm')
        for node_id in sorted(node_ids): xml.append(raw_nodes[node_id])
        osm_meta = {'url':f'https://www.openstreetmap.org/relation/{rid}',
                    'archive':osm_world.frame(campus)['archive'],
                    'sha256':archive_meta['sha256_uncompressed']}
    else:
        body, osm_meta = fetch(f"https://api.openstreetmap.org/api/0.6/way/{wid}/full", cache, download)
        xml = ET.fromstring(body)
        nodes = {n.get("id"): [float(n.get("lon")), float(n.get("lat"))] for n in xml.findall("node")}
        way = next(w for w in xml.findall("way") if w.get("id") == wid)
        osm = [nodes[n.get("ref")] for n in way.findall("nd")]
        if len(osm) < 4 or osm[0] != osm[-1]:
            raise ValueError(f"OSM way {wid} is not a closed outline")
        osm.pop()
    tags = {t.get("k"): t.get("v") for t in way.findall("tag")}
    zoom = config["zoom"]
    # Subtract a nearby origin before computing a centroid to avoid cancellation.
    lon0, lat0 = official[0]
    old_center_delta = centroid([[x - lon0, y - lat0] for x, y in official])
    center = [lon0 + old_center_delta[0], lat0 + old_center_delta[1]]
    alignment_path = ROOT / f"references/{campus}/terrain/alignment.json"
    if alignment_path.exists():
        alignment = json.loads(alignment_path.read_text(encoding="utf-8"))
        ox, oz = alignment["offset_xz_m"]
        latitude = alignment["origin_lon_lat"][1]
        shift = [-ox / (111320 * math.cos(math.radians(latitude))), oz / 111320]
        alignment_basis = str(alignment_path.relative_to(ROOT)).replace("\\", "/")
        alignment_status = "旧 bound 质心平移，仅初始定位，未验证"
    else:
        a, b = osm[0]
        delta = centroid([[x - a, y - b] for x, y in osm])
        shift = [center[0] - a - delta[0], center[1] - b - delta[1]]
        alignment_basis = "此样本 OSM 与 bound 面积质心重合"
        alignment_status = "单样本质心平移，仅初始定位，未验证"
    origin = [math.floor(v) for v in project(*center, zoom)]

    def local(points):
        return [[p[i] - origin[i] for i in (0, 1)] for p in points]

    official_pixels = local([project(*p, zoom) for p in official])
    osm_pixels = local([project(p[0] + shift[0], p[1] + shift[1], zoom) for p in osm])
    related = []
    for related_id in case.get('related_official_ids',[]):
        found = [f for f in source['result'] if str(f['id'])==related_id]
        if len(found)!=1: raise ValueError(f'Missing related official outline {related_id}')
        raw = [[p['x'],p['y']] for p in found[0]['bound']['points']]
        if raw[-1]==raw[0]:raw.pop()
        related.append({'official_id':related_id,'points':local([project(*p,zoom) for p in raw]),'raw_lon_lat':raw})
    hole_pixels = [local([project(p[0]+shift[0],p[1]+shift[1],zoom) for p in ring]) for ring in holes]
    all_points = official_pixels + osm_pixels + [p for ring in hole_pixels for p in ring] + [p for r in related for p in r["points"]]
    low = [min(p[i] for p in all_points) - 100 for i in (0, 1)]
    high = [max(p[i] for p in all_points) + 100 for i in (0, 1)]
    tiles = []
    for x in range(math.floor((origin[0] + low[0]) / 256), math.floor((origin[0] + high[0]) / 256) + 1):
        for y in range(math.floor((origin[1] + low[1]) / 256), math.floor((origin[1] + high[1]) / 256) + 1):
            url = config["tile_url"].format(x=x, y=y, z=zoom)
            data, meta = fetch(url, cache, download, image=True)
            mime = "image/png" if data.startswith(b"\x89PNG") else "image/jpeg"
            tiles.append({"x": x * 256 - origin[0], "y": y * 256 - origin[1],
                          "tile": [x, y, zoom], "source": meta,
                          "image": f"data:{mime};base64," + base64.b64encode(data).decode()})
    return {**case, "read_only": bool(rid), "osm_id": f"relation/{rid}" if rid else f"way/{wid}", "zoom": zoom, "pixel_origin": origin,
            "meters_per_pixel_approx": math.cos(math.radians(center[1])) * 2 * math.pi * 6378137 / (256 * 2**zoom),
            "frame": config["reference"], "bounds": low + high, "tiles": tiles,
            "related_official":related,
            "official": {"points": official_pixels, "raw_lon_lat": official,
                         "url": source.get("source"), "retrieved": source.get("retrieved"),
                         "archive": str(source_path.relative_to(ROOT)).replace("\\", "/"),
                         "sha256": hashlib.sha256(source_path.read_bytes()).hexdigest()},
            "osm": {"points": osm_pixels, "holes":hole_pixels, "raw_wgs84_holes":holes, "raw_wgs84_lon_lat": osm,
                    "source": osm_meta, "version": way.get("version"), "tags": tags,
                    "changeset": way.get("changeset"), "timestamp": way.get("timestamp"),
                    "nodes": [{"id": n.get("id"), "version": n.get("version"),
                               "lon": n.get("lon"), "lat": n.get("lat")} for n in xml.findall("node")]},
            "initial_alignment": {"shift_lon_lat": shift, "basis": alignment_basis, "status": alignment_status}}


def restore_drafts(saved, cases):
    """Refuse to reuse manual points against changed source data or another frame."""
    if saved.get("status") != "unverified-map-plane-draft" or saved.get("reference") != "official-lm30-pixel-plane":
        raise ValueError("Unsupported draft format")
    by_id = {(c["campus"], c["official_id"]): c for c in saved["cases"]}
    if len(by_id) != len(cases) or len(saved["cases"]) != len(cases):
        raise ValueError("Draft sample set differs")
    drafts = []
    for case in cases:
        old = by_id[(case["campus"], case["official_id"])]
        if (old["pixel_origin"] != case["pixel_origin"] or old["zoom"] != case["zoom"]
                or old.get("osm_id", "way/"+str(old.get("osm_way_id"))) != case["osm_id"]
                or old["official"]["sha256"] != case["official"]["sha256"]
                or old["osm"]["source"]["sha256"] != case["osm"]["source"]["sha256"]
                or old["initial_alignment"] != case["initial_alignment"]
                or [(t["tile"], t["source"]["sha256"]) for t in old["tiles"]]
                != [(t["tile"], t["source"]["sha256"]) for t in case["tiles"]]):
            raise ValueError("Draft source or frame changed; review alignment again")
        draft = old["draft"]
        points = draft["points"]
        if case.get('read_only'):
            if draft.get('status')!='reference-only' or points!=[] or not isinstance(draft.get('notes'),str):
                raise ValueError('Relation geometry is read-only; preserve all source rings')
            drafts.append(draft)
            continue
        if len(points) < 3 or len(points) > 10000 or not isinstance(draft.get("notes"), str):
            raise ValueError("Invalid draft")
        for point in points:
            if len(point) != 2 or any(not isinstance(v, (int, float)) or not math.isfinite(v) for v in point):
                raise ValueError("Invalid coordinates")
        if not simple_polygon(points):
            raise ValueError("Draft polygon is degenerate or self-intersecting")
        if draft.get("status") != "unverified":
            raise ValueError("This tool only saves unverified drafts")
        drafts.append(draft)
    for case, draft in zip(cases, drafts):
        case["draft"] = draft


def simple_polygon(points):
    def cross(a, b, c):
        return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])

    def on(a, b, p):
        return (abs(cross(a, b, p)) < 1e-7
                and min(a[0], b[0]) - 1e-7 <= p[0] <= max(a[0], b[0]) + 1e-7
                and min(a[1], b[1]) - 1e-7 <= p[1] <= max(a[1], b[1]) + 1e-7)

    edges = list(zip(points, points[1:] + points[:1]))
    if abs(sum(a[0] * b[1] - a[1] * b[0] for a, b in edges)) <= 1:
        return False
    for i, (a, b) in enumerate(edges):
        if math.dist(a, b) < .01:
            return False
        for j, (c, d) in enumerate(edges):
            if j <= i + 1 or i == 0 and j == len(edges) - 1:
                continue
            if ((cross(a, b, c) * cross(a, b, d) < 0 and cross(c, d, a) * cross(c, d, b) < 0)
                    or on(a, b, c) or on(a, b, d) or on(c, d, a) or on(c, d, b)):
                return False
    return True


def serve(output, cases, port):
    class Handler(SimpleHTTPRequestHandler):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory=str(output), **kwargs)

        def do_GET(self):
            if self.path in ("/", "/index.html"):
                payload = {"schema_version": 1, "cases": cases}
                encoded = json.dumps(payload, ensure_ascii=False).replace("<", "\\u003c")
                body = TEMPLATE.read_text(encoding="utf-8").replace("/* REVIEW_DATA */null", encoded).encode("utf-8")
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Cache-Control", "no-store")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
                return
            super().do_GET()

        def do_POST(self):
            if (self.path != "/draft" or self.headers.get("Origin") != f"http://127.0.0.1:{port}"
                    or self.headers.get_content_type() != "application/json"):
                self.send_error(403)
                return
            try:
                length = int(self.headers.get("Content-Length", "0"))
                if not 0 < length < 4_000_000:
                    raise ValueError("Draft too large or empty")
                saved = json.loads(self.rfile.read(length))
                restore_drafts(saved, cases)
                target = output / "draft.json"
                temporary = output / "draft.json.tmp"
                temporary.write_text(json.dumps(saved, ensure_ascii=False, indent=2), encoding="utf-8")
                temporary.replace(target)
            except (ValueError, KeyError, TypeError, AttributeError, IndexError) as error:
                self.send_error(400, str(error))
                return
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"saved":"draft.json"}')

    print(f"Review: http://127.0.0.1:{port}", flush=True)
    HTTPServer(("127.0.0.1", port), Handler).serve_forever()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--official-id", help="Build only the selected official feature for a focused review")
    parser.add_argument("--download", action="store_true", help="Fetch missing public reference data")
    parser.add_argument("--output", type=Path, default=ROOT / ".local/footprint-review")
    parser.add_argument("--serve", action="store_true", help="Serve locally and allow saving draft.json")
    parser.add_argument("--port", type=int, default=8769)
    args = parser.parse_args()
    output = args.output.resolve()
    cache = output / "cache"
    cache.mkdir(parents=True, exist_ok=True)
    config = json.loads(CONFIG.read_text(encoding="utf-8"))
    cases = []
    selected = [c for c in config["cases"] if args.official_id is None or c["official_id"]==args.official_id]
    if not selected: raise ValueError("No matching review case")
    for case in selected:
        cases.append(build_case(case, config, cache, args.download))
        print(f"Prepared {case['campus']}/{case['official_id']}", flush=True)
    draft_path = output / "draft.json"
    if draft_path.exists():
        restore_drafts(json.loads(draft_path.read_text(encoding="utf-8")), cases)
    payload = {"schema_version": 1, "generated": datetime.now(timezone.utc).isoformat(), "cases": cases}
    encoded = json.dumps(payload, ensure_ascii=False).replace("<", "\\u003c")
    html = TEMPLATE.read_text(encoding="utf-8").replace("/* REVIEW_DATA */null", encoded)
    (output / "index.html").write_text(html, encoding="utf-8")
    print(output / "index.html")
    if args.serve:
        serve(output, cases, args.port)


if __name__ == "__main__":
    main()
