"""Shared OSM source reader and local frame for offline campus generation.

No datum shifts: the archived OSM coordinates and terrain source use WGS84.
Callers must filter source coverage and preserve relation topology themselves.
"""
import gzip
import hashlib
import json
import math
from pathlib import Path
import xml.etree.ElementTree as ET
from functools import lru_cache

ROOT = Path(__file__).resolve().parents[3]
FRAME_PATH = ROOT / 'references/shared/mapping/osm-world-frame.json'


def withhold_selection_bounds(features, campus):
    """Keep source identities, never publish DLUTMap 3D selection bounds as geometry.

    Raw coordinates and photo profiles remain in references/. Empty runtime
    nodes make missing evidence explicit without affecting terrain or collision.
    Call after identity/compound review, before computing runtime coverage.
    """
    for feature in features:
        if feature.get('osm_id'):
            continue
        feature.setdefault('source_kind', feature['kind'])
        feature['withheld_geometry'] = {
            'reason': 'dlutmap-3d-selection-bound-is-not-ground-geometry',
            'archive': f'references/{campus}/mapping/bounds.json',
            'official_id': feature['id'],
            'part': feature.get('part', 0),
            'previous_status': feature.get('geometry_status'),
        }
        for key in ('reference_points', 'reference_render_polygons', 'holes',
                    'sports', 'building_parts'):
            feature.pop(key, None)
        feature.update(kind='reference', points=[], render_polygons=[], facade={},
                       height=None, height_source='unavailable', footprint_source=None)
        if feature.get('geometry_status') == 'legacy-silhouette-pending-replacement':
            feature['geometry_status'] = 'withheld-pending-valid-ground-source'


@lru_cache(maxsize=3)
def frame(campus):
    return json.loads(FRAME_PATH.read_text(encoding='utf-8'))['campuses'][campus]


def local(campus, lon, lat):
    origin = frame(campus)['origin_lon_lat']
    return [(lon-origin[0])*111320*math.cos(math.radians(origin[1])),
            -(lat-origin[1])*111320]


def geographic(campus, x, z):
    origin = frame(campus)['origin_lon_lat']
    return [origin[0]+x/(111320*math.cos(math.radians(origin[1]))),
            origin[1]-z/111320]


def archive(campus, source_path=None):
    spec = frame(campus)
    source_path = Path(source_path) if source_path else (ROOT / spec['archive']).with_name('osm-world-source.json')
    source = json.loads(source_path.read_text(encoding='utf-8'))
    path = source_path.parent / source['archive']
    raw = gzip.decompress(path.read_bytes())
    if hashlib.sha256(raw).hexdigest() != source['sha256_uncompressed']:
        raise ValueError(f'OSM archive checksum mismatch: {campus}')
    xml = ET.fromstring(raw)
    nodes = {n.get('id'): n for n in xml.findall('node')}
    ways = {w.get('id'): w for w in xml.findall('way')}
    relations = {r.get('id'): r for r in xml.findall('relation')}
    if spec['boundary_way'] not in ways:
        raise ValueError(f'Campus boundary missing from OSM archive: {campus}')
    return source, nodes, ways, relations


def tags(element):
    return {t.get('k'): t.get('v') for t in element.findall('tag')}


def way_coordinates(way, nodes):
    refs = [n.get('ref') for n in way.findall('nd')]
    if any(ref not in nodes for ref in refs):
        raise ValueError(f'Incomplete OSM way {way.get("id")}')
    return [[float(nodes[ref].get('lon')),float(nodes[ref].get('lat'))] for ref in refs]


def relation_rings(relation, ways, nodes):
    """Assemble complete multipolygons without filling courtyards or open ways."""
    if tags(relation).get('type') != 'multipolygon':
        raise ValueError('Not a multipolygon')
    result = []
    for member in relation.findall('member'):
        if member.get('type') != 'way' or member.get('role', '') not in ('', 'outer', 'inner'):
            raise ValueError('Unsupported multipolygon member')
        if member.get('ref') not in ways:
            raise ValueError('Incomplete multipolygon member')
    for role in ('outer', 'inner'):
        pending = []
        for member in relation.findall('member'):
            if (member.get('role') or 'outer') == role:
                refs = [n.get('ref') for n in ways[member.get('ref')].findall('nd')]
                if len(refs) < 2 or any(ref not in nodes for ref in refs):
                    raise ValueError('Incomplete multipolygon nodes')
                pending.append(refs)
        while pending:
            chain = pending.pop(0)
            while chain[-1] != chain[0]:
                matches = [(i, p if p[0] == chain[-1] else p[::-1])
                           for i, p in enumerate(pending) if chain[-1] in (p[0], p[-1])]
                if len(matches) != 1:
                    raise ValueError('Open or branching multipolygon ring')
                index, part = matches[0]
                pending.pop(index)
                chain.extend(part[1:])
            if len(chain) < 4:
                raise ValueError('Degenerate multipolygon ring')
            result.append({'role': role, 'lon_lat': [
                [float(nodes[n].get('lon')), float(nodes[n].get('lat'))] for n in chain[:-1]]})
    if not any(r['role'] == 'outer' for r in result):
        raise ValueError('Missing outer ring')
    return result


def registered_planting_areas(campus):
    """Publish only independently reviewed OSM planting areas, never legacy rings."""
    from prepare_osm_world import build
    path = ROOT / f'references/{campus}/vegetation/planting.json'
    config = json.loads(path.read_text(encoding='utf-8'))
    registered = [z for z in config['zones'] if z.get('osm_registration')]
    if not registered:
        return []
    areas = {r['osm_id']: r for r in build(campus)['areas']}
    result = []
    for zone in registered:
        spec = zone['osm_registration']
        record = areas.get(spec['osm_id'])
        if record is None or record['version'] != spec['osm_version']:
            raise ValueError('Planting source missing or version changed: ' + zone['id'])
        digest = hashlib.sha256(json.dumps(record['polygons'], sort_keys=True, separators=(',', ':')).encode()).hexdigest()
        if digest != spec['expected_geometry_sha256']:
            raise ValueError('Planting source geometry changed: ' + zone['id'])
        if record['category'] != 'vegetation-area' or any(record['tags'].get(k) != v for k, v in spec['expected_tags'].items()):
            raise ValueError('Planting source semantics changed: ' + zone['id'])
        if len(record['polygons']) != 1 or record['polygons'][0]['holes']:
            raise ValueError('Planting area needs explicit multipart/hole support: ' + zone['id'])
        result.append({'id':zone['id'], 'osm_id':record['osm_id'], 'osm_version':record['version'],
                       'geometry_sha256':digest, 'points':record['polygons'][0]['outer'],
                       'review':spec['review']})
    return result
