"""Import archived OSM centerlines; network access only with explicit --fetch.

Derived road data is ODbL 1.0, © OpenStreetMap contributors. All paths resolve
from this file. Width defaults are visual estimates, not survey measurements.
"""
import argparse
from datetime import datetime, timezone
import json
import math
from pathlib import Path
import re
import urllib.parse
import urllib.request
import osm_world

ROOT = Path(__file__).resolve().parents[3]
BOUNDARIES = {'lingshui': 443031231, 'eda': 215560705, 'panjin': 463862869}
WIDTHS = {'primary': 10, 'secondary': 9, 'tertiary': 7, 'unclassified': 6,
          'residential': 6, 'service': 5, 'living_street': 5, 'pedestrian': 5,
          'footway': 2, 'path': 2, 'cycleway': 2.5, 'track': 3}


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def inside(p, ring):
    x, y = p
    hit = False
    for (a, b), (c, d) in zip(ring, ring[1:] + ring[:1]):
        if (b > y) != (d > y) and x < (c-a)*(y-b)/(d-b)+a:
            hit = not hit
    return hit


def cross(a, b):
    return a[0]*b[1]-a[1]*b[0]


def clipped_parts(points, boundaries):
    """Split at actual boundary crossings, retaining complete interior paths."""
    parts, current = [], []
    for a, b in zip(points, points[1:]):
        direction = [b[k]-a[k] for k in range(2)]
        if math.dist(a, b) < 1e-6:
            continue
        cuts = [0.0, 1.0]
        for ring in boundaries:
            for c, d in zip(ring, ring[1:]+ring[:1]):
                span = [d[k]-c[k] for k in range(2)]
                denominator = cross(direction, span)
                if abs(denominator) < 1e-10:
                    continue
                delta = [c[k]-a[k] for k in range(2)]
                t, u = cross(delta, span)/denominator, cross(delta, direction)/denominator
                if 0 < t < 1 and 0 <= u <= 1:
                    cuts.append(t)
        cuts = sorted(set(cuts))
        for start, end in zip(cuts, cuts[1:]):
            middle = [a[k]+direction[k]*(start+end)*0.5 for k in range(2)]
            if all(inside(middle, ring) for ring in boundaries):
                first = [round(a[k]+direction[k]*start, 4) for k in range(2)]
                last = [round(a[k]+direction[k]*end, 4) for k in range(2)]
                if first == last:
                    continue
                if current and math.dist(current[-1], first) > 0.001:
                    parts.append(current)
                    current = []
                if not current:
                    current.append(first)
                current.append(last)
            elif current:
                parts.append(current)
                current = []
    if current:
        parts.append(current)
    return parts


def width(tags):
    explicit = re.fullmatch(r'\s*(\d+(?:\.\d+)?)\s*(?:m)?\s*', tags.get('width', ''))
    if explicit and 0.5 <= float(explicit[1]) <= 30:
        return float(explicit[1]), 'osm:width'
    return WIDTHS[tags['highway']], 'estimated:highway-class'


def build(campus, fetch=False):
    data_dir = ROOT / f'apps/game/assets/campuses/{campus}/data'
    refs = ROOT / f'references/{campus}/mapping'
    manifest = read(data_dir / 'campus.json')
    lon, lat = manifest['origin']
    align_path = ROOT / (f'references/{campus}/terrain/alignment.json' if campus != 'panjin' else 'references/panjin/mapping/road-alignment.json')
    if manifest.get('geographic_crs') == 'EPSG:4326':
        assert manifest['origin'] == osm_world.frame(campus)['origin_lon_lat']
        align_path = osm_world.FRAME_PATH
        ox, oz = 0, 0
    else:
        alignment = read(align_path)
        ox, oz = alignment['offset_xz_m']
    factor = 111320*math.cos(math.radians(lat))
    def local(p):
        return [(p['lon']-lon)*factor-ox, -(p['lat']-lat)*111320-oz]
    archive = refs / 'osm-roads.json'
    if fetch:
        bbox = ','.join(map(str, (lat-.025, lon-.03, lat+.025, lon+.03)))
        query = f'[out:json][timeout:45];(way[highway]({bbox});way({BOUNDARIES[campus]}););out meta geom;'
        endpoint = 'https://overpass-api.de/api/interpreter'
        req = urllib.request.Request(endpoint, data=urllib.parse.urlencode({'data': query}).encode(), headers={'User-Agent': 'DLUT-Online-road-import/1.0'})
        with urllib.request.urlopen(req, timeout=60) as response:
            payload = json.load(response)
        if payload.get('remark') or not payload.get('elements'):
            raise ValueError('Incomplete Overpass response; archive was not replaced')
        source = {'retrieved': datetime.now(timezone.utc).date().isoformat(), 'endpoint': endpoint, 'query': query, 'response': payload}
    else:
        source = read(archive)
    elements = source['response']['elements']
    boundary = next(e for e in elements if e['id'] == BOUNDARIES[campus])
    campus_ring = [local(p) for p in boundary['geometry'][:-1]]
    x, z, w, h = manifest.get('bounds', [-640, -410, 1280, 930])
    # Keep half-width inside the collision world's outer boundary.
    frame = [[x+15,z+15],[x+w-15,z+15],[x+w-15,z+h-15],[x+15,z+h-15]]
    roads, excluded = [], []
    for element in sorted(elements, key=lambda e: e['id']):
        tags = element.get('tags', {})
        if 'highway' not in tags:
            continue
        paths = clipped_parts([local(p) for p in element['geometry']], [campus_ring, frame])
        if not paths:
            continue
        if (tags['highway'] not in WIDTHS or tags.get('area') == 'yes'
                or tags.get('bridge', 'no') != 'no' or tags.get('tunnel', 'no') != 'no'
                or tags.get('layer', '0') != '0' or tags.get('indoor', 'no') != 'no'):
            excluded.append({'osm_way_id': element['id'], 'tags': tags, 'reason': 'unsupported area, steps, construction or non-ground-level way'})
            continue
        road_width, basis = width(tags)
        for part, points in enumerate(paths):
            roads.append({'osm_way_id': element['id'], 'osm_version': element['version'], 'part': part,
                          'name': tags.get('name', ''), 'highway': tags['highway'], 'width': road_width,
                          'width_basis': basis, 'points': points})
    assert roads, f'No usable OSM roads for {campus}'
    if fetch:
        used = {boundary['id']} | {r['osm_way_id'] for r in roads + excluded}
        source['response']['elements'] = [e for e in elements if e['id'] in used]
        source['selection'] = 'Unmodified way records for campus boundary and intersecting roads, including excluded ways; unrelated surrounding ways omitted.'
        archive.write_text(json.dumps(source, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    output = {'source': 'https://www.openstreetmap.org', 'license': 'ODbL-1.0',
              'attribution': '© OpenStreetMap contributors', 'retrieved': source['retrieved'],
              'archive': str(archive.relative_to(ROOT)).replace('\\','/'),
              'alignment': str(align_path.relative_to(ROOT)).replace('\\','/'),
              'boundary_osm_way_id': boundary['id'], 'roads': roads, 'excluded': excluded}
    (data_dir/'osm_roads.json').write_text(json.dumps(output,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(campus, len(roads), 'road parts,', len(excluded), 'excluded')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--campus', choices=list(BOUNDARIES))
    parser.add_argument('--fetch', action='store_true', help='Refresh Overpass archives before offline conversion')
    args = parser.parse_args()
    for campus in ([args.campus] if args.campus else BOUNDARIES):
        build(campus, args.fetch)
