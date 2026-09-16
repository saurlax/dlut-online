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

ROOT = Path(__file__).resolve().parents[3]
FRAME_PATH = ROOT / 'references/shared/mapping/osm-world-frame.json'


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


def archive(campus):
    spec = frame(campus)
    path = ROOT / spec['archive']
    source = json.loads(path.with_name('osm-world-source.json').read_text(encoding='utf-8'))
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
