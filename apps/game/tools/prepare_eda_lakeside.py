"""Replay photo-bounded lake surfaces in the existing OSM world frame."""
import hashlib
import json
from pathlib import Path

from prepare_osm_world import valid_ring

ROOT = Path(__file__).resolve().parents[3]
PROFILE = ROOT / 'references/eda/mapping/lakeside-environment.json'


def build():
    profile = json.loads(PROFILE.read_text(encoding='utf-8'))
    roads = json.loads((ROOT / 'apps/game/assets/campuses/eda/data/osm_roads.json').read_text(encoding='utf-8'))['roads']
    for anchor in profile['anchors']:
        matches = [r for r in roads if r['osm_way_id'] == anchor['osm_way_id'] and r['part'] == anchor['part']]
        if len(matches) != 1 or any(matches[0][k] != anchor[k] for k in anchor):
            raise ValueError('Lake ground anchor changed; recheck photo registration')
    surfaces, areas = [], []
    for source in profile['surfaces']:
        if not valid_ring(source['outer']):
            raise ValueError('Invalid lake paving ring: ' + source['id'])
        surfaces.append(dict(source, source='references/eda/mapping/lakeside-environment.json',
                             absolute_accuracy_m=None, registration=profile['registration']))
    for source in profile['planting']:
        if not valid_ring(source['points']):
            raise ValueError('Invalid lake planting ring: ' + source['id'])
        areas.append(dict(id=source['id'], points=source['points'],
                          photo_registration_sha256=hashlib.sha256(PROFILE.read_bytes()).hexdigest()))
    return surfaces, areas
