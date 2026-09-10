"""Prepare Lingshui from archived official polygons; never fetch during export."""
import json
import math
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
    source = json.loads((REFERENCES / 'bounds.json').read_text())
    profiles = json.loads((REFERENCES / 'facades.json').read_text())
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
                         'height_source': 'photo-proportion-estimate' if profile else 'unmeasured-outline-estimate',
                         'footprint_source': source['source'], 'facade': profile,
                         'render_polygons': split_crossings(points)})
    all_points = [p for f in features for p in f['points']]
    low = [math.floor(min(p[i] for p in all_points)/10)*10-30 for i in range(2)]
    high = [math.ceil(max(p[i] for p in all_points)/10)*10+30 for i in range(2)]
    data = {'campus_id': 'lingshui', 'origin': ORIGIN, 'units': 'approximate meters',
            'source': source['source'], 'retrieved': source['retrieved'],
            'bounds': low + [high[i]-low[i] for i in range(2)],
            'features': features}
    OUTPUT.mkdir(parents=True, exist_ok=True)
    (OUTPUT/'campus.json').write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n')
    (REFERENCES/'excluded.json').write_text(json.dumps(excluded, ensure_ascii=False, indent=2)+'\n')
    print(f'Lingshui: {len(features)} polygons, {len(parts)} IDs, {len(excluded)} surrounding polygons excluded')


if __name__ == '__main__':
    main()
