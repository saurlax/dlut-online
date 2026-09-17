"""Match existing campus building identities to archived OSM, retaining gaps.

Names establish candidate identities, not survey accuracy. Search the complete
archive because the OSM university boundary omits known campus buildings. Never
add unrelated buildings just because they occur inside that boundary.
"""
import argparse
from collections import defaultdict, Counter
import hashlib
import json
import re
from pathlib import Path

import osm_world as osm
from prepare_osm_world import build as world_data


def normalized(campus, name):
    name=re.sub(r'^[A-Z]\d?区\d+-','',name)
    name=name.replace('大连理工大学(开发区校区)','').replace('大连理工大学','').replace('大工','')
    if campus=='panjin':
        match=re.match(r'^([A-H]\d{2})(?:-|$)',name)
        return match[1] if match else name
    match=re.fullmatch(r'(北山|西山)学生宿舍0*(\d+)#?',name)
    if match:return match[1]+str(int(match[2]))+'舍'
    match=re.fullmatch(r'博留公寓0*(\d+)',name)
    if match:return '博留'+str(int(match[1]))+'舍'
    if name.startswith('小楼'):return name.replace('小楼','院士楼',1)
    return name


def build(campus, manifest=None):
    directory=osm.ROOT/f'references/{campus}/mapping'
    manifest_path=osm.ROOT/f'apps/game/assets/campuses/{campus}/data/campus.json'
    manifest=json.loads(manifest_path.read_text(encoding='utf-8')) if manifest is None else manifest
    config_path=directory/'osm-identity-overrides.json'
    config=json.loads(config_path.read_text(encoding='utf-8')) if config_path.exists() else {'aliases':{},'objects':{}}
    world=world_data(campus,include_outside=True)
    records={r['osm_id']:r for r in world['areas']}
    names=defaultdict(list)
    for r in records.values():
        if r['category']!='building':continue
        for name in set(filter(None,[r['tags'].get('name'),r['tags'].get('name:zh')])):
            names[normalized(campus,name)].append(r['osm_id'])
    existing=defaultdict(list)
    for f in manifest['features']:
        if f['kind']=='building':existing[f['id']].append(f)
    matches=[]
    for fid,parts in existing.items():
        name=parts[0]['name']; original_key=normalized(campus,name)
        key=config['aliases'].get(original_key,original_key)
        override=config['objects'].get(fid)
        ids=override['osm_ids'] if override else sorted(set(names.get(key,[])))
        missing=[i for i in ids if i not in records]
        if missing:raise ValueError(f'{campus}/{fid}: unavailable explicit OSM identity {missing}')
        state='matched' if override or len(ids)==1 else 'ambiguous' if ids else 'missing'
        matches.append({'official_id':fid,'name':name,'official_parts':len(parts),
                        'status':state,'identity_basis':override['basis'] if override else
                            ('unambiguous declared name alias' if key!=original_key else 'unambiguous normalized building name') if len(ids)==1 else 'unresolved',
                        'osm_candidates':[{'osm_id':i,'osm_version':records[i]['version'],
                                           'category':records[i]['category'],'tags':records[i]['tags'],
                                           'name':records[i]['tags'].get('name',''),
                                           'scope':records[i]['scope'],'polygons':records[i]['polygons']} for i in ids],
                        'geometry_review_required':True,
                        'geometry_deferred':bool(override and override.get('defer_geometry',False)),
                        'facade_registration_required':any(f.get('facade') for f in parts)
                            or campus=='eda' and fid not in ('96575',)})
    assigned=defaultdict(list)
    for match in matches:
        if match['status']=='matched':
            for r in match['osm_candidates']:assigned[r['osm_id']].append(match['official_id'])
    collisions={i:fids for i,fids in assigned.items() if len(fids)>1}
    if collisions:raise ValueError(f'Multiple official identities assigned to one OSM object: {collisions}')
    return {'schema_version':1,'campus_id':campus,'status':'identity-input-not-runtime',
            'existing_manifest':str(manifest_path.relative_to(osm.ROOT)).replace('\\','/'),
            'existing_manifest_sha256':hashlib.sha256(manifest_path.read_bytes()).hexdigest(),
            'coordinate_frame':world['coordinate_frame'],'origin_lon_lat':world['origin_lon_lat'],
            'osm_archive_sha256':world['source']['sha256_uncompressed'],
            'overrides_sha256':hashlib.sha256(config_path.read_bytes()).hexdigest() if config_path.exists() else None,
            'buildings':matches,'counts':dict(Counter(m['status'] for m in matches)),
            'limits':['Every existing building ID is retained, including unresolved and multipart objects.',
                      'Matching names is not validation of footprint accuracy, date or photo facade geometry.',
                      'Outside-boundary matches require campus scope review; they are not discarded.',
                      'No nearest-centroid geometry selection or averaging is performed.']}


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,default=osm.ROOT/'.local/osm-world')
    args=parser.parse_args();args.output.mkdir(parents=True,exist_ok=True)
    for campus in ('lingshui','eda','panjin'):
        data=build(campus)
        (args.output/(campus+'-identities.json')).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        print(campus,data['counts'])
