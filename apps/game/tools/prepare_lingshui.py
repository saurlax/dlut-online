"""Prepare Lingshui from archived official polygons; never fetch during export."""
import json
import math
import re
from pathlib import Path

CLIENT = Path(__file__).resolve().parents[1]
REFERENCES = CLIENT.parents[1] / 'references/lingshui'
OUTPUT = CLIENT / 'assets/campuses/lingshui/data'
ORIGIN = (121.526958936262, 38.879216194937)
# Source map also covers neighbouring housing and a separate institution.
EXCLUDED_PREFIXES = ('文萃', '文荟', '新新园', '中国大连高级经理学院', '凌水路', '文静街')
EXCLUDED_NAMES = ('居民房', '便利店', '凌水超市', '汇源美食广场')


def classify(name):
    if '规划中' in name:
        return 'reserve'
    if name.endswith('路') or name == '健康步道':
        return 'road'
    if '湖' in name or name == '凌水河':
        return 'water'
    if any(word in name for word in ('停车场', '广场', '派发区')):
        return 'plaza'
    if any(word in name for word in ('足球场', '体育场', '网球场', '篮球场', '排球场', '风雨操场')):
        return 'sports'
    if name.endswith('门') or name == '西区北':
        return 'gate'
    if '雕像' in name or name == '毛主席像':
        return 'reference'
    if name.endswith('桥'):
        return 'reference'
    return 'building'


def split_crossings(points):
    """Split crossing rings at their exact intersection, retaining both lobes."""
    def cross(a, b):
        return a[0]*b[1]-a[1]*b[0]
    def sub(a, b):
        return [a[0]-b[0], a[1]-b[1]]
    for i, a in enumerate(points):
        b = points[(i+1) % len(points)]
        for j in range(i+2, len(points)):
            if i == 0 and j == len(points)-1:
                continue
            c, d = points[j], points[(j+1) % len(points)]
            r, t = sub(b, a), sub(d, c)
            denominator = cross(r, t)
            if abs(denominator) < 1e-10:
                continue
            u, v = cross(sub(c, a), t)/denominator, cross(sub(c, a), r)/denominator
            if 1e-8 < u < 1-1e-8 and 1e-8 < v < 1-1e-8:
                hit = [a[k]+u*r[k] for k in range(2)]
                return (split_crossings([hit]+points[i+1:j+1]) +
                        split_crossings([hit]+points[j+1:]+points[:i+1]))
    return [points]


def main():
    import osm_world
    from prepare_osm_identities import build as identities
    source = json.loads((REFERENCES / 'mapping/bounds.json').read_text(encoding='utf-8'))
    profiles = json.loads((REFERENCES / 'buildings/facades.json').read_text(encoding='utf-8'))
    sports = json.loads((REFERENCES / 'facilities/sports.json').read_text(encoding='utf-8'))
    features, excluded = [], []
    parts = {}
    for source_index, item in enumerate(source['result']):
        name = item['name']
        if name.startswith(EXCLUDED_PREFIXES) or name in EXCLUDED_NAMES:
            excluded.append({'source_index': source_index, 'id': str(item['id']), 'name': name})
            continue
        feature_id = str(item['id'])
        part = parts.get(feature_id, 0)
        parts[feature_id] = part + 1
        points = [[round((p['x'] - ORIGIN[0]) * 111320 * math.cos(math.radians(ORIGIN[1])), 3),
                   round(-(p['y'] - ORIGIN[1]) * 111320, 3)] for p in item['bound']['points']]
        if points[-1] == points[0]:
            points.pop()
        assert len(points) >= 3
        kind = classify(name)
        profile = profiles.get(feature_id, {})
        height = profile.get('height', 18.0 if kind == 'building' else 0.06)
        features.append({'id': feature_id, 'part': part, 'source_index': source_index,
                         'name': name, 'kind': kind, 'points': points, 'height': height,
                         'height_source': profile.get('height_source', 'photo-proportion-estimate') if profile else 'unmeasured-outline-estimate',
                         'footprint_source': source['source'], 'facade': profile,
                         'render_polygons': split_crossings(points)})
        if feature_id in sports:
            features[-1]['sports'] = sports[feature_id]
    mapping=identities('lingshui',{'features':features})
    matches={m['official_id']:m for m in mapping['buildings'] if m['status']=='matched'}
    origin=osm_world.frame('lingshui')['origin_lon_lat']
    alignment=json.loads((REFERENCES/'terrain/alignment.json').read_text(encoding='utf-8'))
    scale=math.cos(math.radians(origin[1]))/math.cos(math.radians(ORIGIN[1]))
    delta=osm_world.local('lingshui',*ORIGIN)
    offset=[delta[0]+alignment['offset_xz_m'][0]*scale,delta[1]+alignment['offset_xz_m'][1]]
    def moved(p):return [p[0]*scale+offset[0],p[1]+offset[1]]
    for feature in features:
        match=matches.get(feature['id'])
        candidate=match['osm_candidates'][0] if match and len(match['osm_candidates'])==1 else None
        registration=feature['facade'].get('osm_registration')
        if candidate and (not feature['facade'] or registration) and match['official_parts']==1 and len(candidate['polygons'])==1:
            ring=candidate['polygons'][0]['outer']
            if registration:
                assert candidate['osm_id']==registration['osm_id'] and candidate['osm_version']==registration['osm_version']
                assert len(ring)==registration['expected_vertices']
                feature['facade']={**feature['facade'],**registration['profile']}
                if 'ground_ring_uv' in registration:
                    # Photo-supported refinements within a registered four-corner source.
                    # U runs from source corner 0 to 3; V from the north to south edge.
                    assert len(ring)==4 and 'ground_ring_indices' not in registration
                    uv=registration['ground_ring_uv']
                    assert len(uv)>=3 and len({tuple(p) for p in uv})==len(uv)
                    assert all(len(p)==2 and all(isinstance(v,(int,float)) and math.isfinite(v) and 0<=v<=1 for v in p) for p in uv)
                    feature['osm_source_points']=ring
                    ring=[[(1-v)*((1-u)*ring[0][axis]+u*ring[3][axis])+v*((1-u)*ring[1][axis]+u*ring[2][axis]) for axis in range(2)] for u,v in uv]
                if 'ground_ring_indices' in registration:
                    indices=registration['ground_ring_indices']
                    assert len(indices)>=3 and len(set(indices))==len(indices)
                    assert all(isinstance(i,int) and 0<=i<len(ring) for i in indices)
                    feature['osm_source_points']=ring
                    ring=[ring[i] for i in indices]
            feature.update(points=ring,render_polygons=[ring],osm_id=candidate['osm_id'],
                           osm_version=candidate['osm_version'],footprint_source='osm',
                           geometry_status='osm-source-outline; absolute accuracy unverified')
            feature['holes']=candidate['polygons'][0]['holes']
            if 'osm_source_points' in feature:
                feature['geometry_status']='photo-refined-osm-ground-ring; absolute accuracy unverified'
        else:
            feature['reference_points']=feature['points']
            feature['reference_render_polygons']=feature['render_polygons']
            feature['points']=[moved(p) for p in feature['points']]
            feature['render_polygons']=[[moved(p) for p in ring] for ring in feature['render_polygons']]
            feature['geometry_status']='legacy-silhouette-pending-replacement'
    all_points = [p for f in features for p in f['points']]
    low = [math.floor(min(p[i] for p in all_points)/10)*10-30 for i in range(2)]
    high = [math.ceil(max(p[i] for p in all_points)/10)*10+30 for i in range(2)]
    data = {'campus_id': 'lingshui', 'origin': origin, 'units': 'approximate meters',
            'geographic_crs':'EPSG:4326','coordinate_frame':'references/shared/mapping/osm-world-frame.json',
            'legacy_reference_transform':{'scale_x':scale,'offset_xz':offset,
                'basis':'references/lingshui/terrain/alignment.json',
                'status':'temporary placement for retained references; not shape validation'},
            'spawn_xz':moved([96,28]),
            'source': source['source'], 'retrieved': source['retrieved'],
            'bounds': low + [high[i]-low[i] for i in range(2)],
            'features': features}
    OUTPUT.mkdir(parents=True, exist_ok=True)
    (OUTPUT/'campus.json').write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n',encoding='utf-8')
    (REFERENCES/'mapping/excluded.json').write_text(json.dumps(excluded, ensure_ascii=False, indent=2)+'\n',encoding='utf-8')
    scene_path=CLIENT/'scenes/campuses/lingshui.tscn'
    scene=scene_path.read_text(encoding='utf-8')
    scene=re.sub(r'^spawn_position = Vector3\([^\n]+\)',f'spawn_position = Vector3({data["spawn_xz"][0]:.6f}, 0.35, {data["spawn_xz"][1]:.6f})',scene,flags=re.MULTILINE)
    scene_path.write_text(scene,encoding='utf-8')
    print(f'Lingshui: {len(features)} polygons, {len(parts)} IDs, {len(excluded)} surrounding polygons excluded')


if __name__ == '__main__':
    main()
