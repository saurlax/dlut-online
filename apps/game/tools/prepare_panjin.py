"""Convert archived official Panjin polygons into the desktop model manifest."""
import json
import math
import re
from pathlib import Path
from prepare_lingshui import split_crossings
import osm_world
from prepare_osm_identities import build as identities

CLIENT = Path(__file__).resolve().parents[1]
REFERENCES = CLIENT.parents[1] / 'references/panjin'
ORIGIN = (122.12445312006, 40.6862493884607)
# These facilities are south of Yanzhong Street, outside this campus model.
EXCLUDED_IDS = {80152, 80155, 80158, 80161, 80164, 80691, 80693, 80694, 80697}


def main():
    source = json.loads((REFERENCES / 'mapping/bounds.json').read_text(encoding='utf-8'))
    profiles = json.loads((REFERENCES / 'buildings/facades.json').read_text(encoding='utf-8'))
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
    mapping = identities('panjin', {'features':features})
    matched = {m['official_id']:m for m in mapping['buildings'] if m['status']=='matched'}
    origin = osm_world.frame('panjin')['origin_lon_lat']
    alignment = json.loads((REFERENCES/'mapping/road-alignment.json').read_text(encoding='utf-8'))
    scale = math.cos(math.radians(origin[1]))/math.cos(math.radians(ORIGIN[1]))
    delta = osm_world.local('panjin',*ORIGIN)
    offset = [delta[0]+alignment['offset_xz_m'][0]*scale,delta[1]+alignment['offset_xz_m'][1]]
    def moved(p): return [p[0]*scale+offset[0],p[1]+offset[1]]
    for feature in features:
        match = matched.get(feature['id'])
        # Photo-covered facades require reviewed edge registrations before replacing
        # their source ring. Retain them explicitly rather than copying old indexes.
        registration=feature['facade'].get('osm_registration')
        if match and (not feature['facade'] or registration):
            assert len(match['osm_candidates'])==1 and match['official_parts']==1
            record = match['osm_candidates'][0]
            assert len(record['polygons'])==1 and not record['polygons'][0]['holes']
            ring = record['polygons'][0]['outer']
            if registration:
                assert record['osm_id']==registration['osm_id'] and record['osm_version']==registration['osm_version']
                assert len(ring)==registration['expected_vertices']
                feature['facade']=dict(feature['facade'],**registration)
            feature.update(points=ring,render_polygons=[ring],osm_id=record['osm_id'],
                           osm_version=record['osm_version'],footprint_source='osm',
                           geometry_status='osm-source-outline; absolute accuracy unverified')
        else:
            feature['reference_points']=feature['points']
            feature['reference_render_polygons']=feature['render_polygons']
            feature['points']=[moved(p) for p in feature['points']]
            feature['render_polygons']=[[moved(p) for p in ring] for ring in feature['render_polygons']]
            feature['geometry_status']='legacy-silhouette-pending-replacement'
    osm_world.withhold_selection_bounds(features, 'panjin')
    from prepare_osm_world import build as osm_geometry
    points = [p for f in features for p in f['points']] + osm_geometry('panjin')['boundary']
    low = [math.floor(min(p[i] for p in points)/10)*10-30 for i in range(2)]
    high = [math.ceil(max(p[i] for p in points)/10)*10+30 for i in range(2)]
    output = CLIENT / 'assets/campuses/panjin/data'
    output.mkdir(parents=True, exist_ok=True)
    data = {'campus_id': 'panjin', 'origin': origin, 'units': 'approximate meters',
            'geographic_crs':'EPSG:4326','coordinate_frame':'references/shared/mapping/osm-world-frame.json',
            'spawn_xz':moved([12,-62]),'elevation_status':'no archived elevation; existing flat ground retained',
            'source': source['source'], 'retrieved': source['retrieved'],
            'bounds': low+[high[i]-low[i] for i in range(2)], 'features': features}
    (output/'campus.json').write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n',encoding='utf-8')
    (REFERENCES/'mapping/excluded.json').write_text(json.dumps(excluded, ensure_ascii=False, indent=2)+'\n',encoding='utf-8')
    scene_path=CLIENT/'scenes/campuses/panjin.tscn'
    scene=scene_path.read_text(encoding='utf-8')
    scene=re.sub(r'^spawn_position = Vector3\([^\n]+\)',f'spawn_position = Vector3({data["spawn_xz"][0]:.6f}, 0.35, {data["spawn_xz"][1]:.6f})',scene,flags=re.MULTILINE)
    scene_path.write_text(scene,encoding='utf-8')
    print(f'Panjin: {len(features)} source identity parts, {len(parts)} IDs, {len(excluded)} excluded')


if __name__ == '__main__':
    main()
