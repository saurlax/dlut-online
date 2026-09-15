"""Convert archived official Panjin polygons into the desktop model manifest."""
import json
import math
from pathlib import Path
from prepare_lingshui import split_crossings

CLIENT = Path(__file__).resolve().parents[1]
REFERENCES = CLIENT.parents[1] / 'references/panjin'
ORIGIN = (122.12445312006, 40.6862493884607)
# These facilities are south of Yanzhong Street, outside this campus model.
EXCLUDED_IDS = {80152, 80155, 80158, 80161, 80164, 80691, 80693, 80694, 80697}


def main():
    source = json.loads((REFERENCES / 'mapping/bounds.json').read_text())
    profiles = json.loads((REFERENCES / 'buildings/facades.json').read_text())
    features, excluded, parts = [], [], {}
    for item in source['result']:
        if item['id'] in EXCLUDED_IDS:
            excluded.append({'id': str(item['id']), 'name': item['name'],
                             'source_index': item['source_index'],
                             'reason': '衍中街以南体育中心、附属田径场及停车场，不纳入本次校园范围'})
            continue
        fid, name = str(item['id']), item['name']
        kind = ('reference' if fid == '80731' else 'road' if name.endswith(('路', '街')) and not name.startswith('B')
                else 'plaza' if name == '停车场' else 'gate' if name.endswith('门') else 'building')
        points = [[round((p['x']-ORIGIN[0])*111320*math.cos(math.radians(ORIGIN[1])), 3),
                   round(-(p['y']-ORIGIN[1])*111320, 3)] for p in item['bound']['points']]
        if points[-1] == points[0]:
            points.pop()
        profile = profiles.get(fid, {})
        part = parts.get(fid, 0)
        parts[fid] = part+1
        features.append({'id': fid, 'part': part, 'name': name, 'kind': kind,
                         'source_index': item['source_index'], 'points': points,
                         'render_polygons': split_crossings(points),
                         'height': profile.get('height', 18.0 if kind == 'building' else 0.06),
                         'height_source': 'photo-proportion-estimate' if profile else 'unmeasured-outline-estimate',
                         'footprint_source': source['source'], 'facade': profile})
    points = [p for f in features for p in f['points']]
    low = [math.floor(min(p[i] for p in points)/10)*10-30 for i in range(2)]
    high = [math.ceil(max(p[i] for p in points)/10)*10+30 for i in range(2)]
    output = CLIENT / 'assets/campuses/panjin/data'
    output.mkdir(parents=True, exist_ok=True)
    data = {'campus_id': 'panjin', 'origin': ORIGIN, 'units': 'approximate meters',
            'source': source['source'], 'retrieved': source['retrieved'],
            'bounds': low+[high[i]-low[i] for i in range(2)], 'features': features}
    (output/'campus.json').write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n')
    (REFERENCES/'mapping/excluded.json').write_text(json.dumps(excluded, ensure_ascii=False, indent=2)+'\n')
    print(f'Panjin: {len(features)} polygon parts, {len(parts)} IDs, {len(excluded)} excluded')


if __name__ == '__main__':
    main()
