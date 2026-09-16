"""Convert official map polygons to a local model manifest. No invented footprint data."""
import json, math, re
from pathlib import Path
import osm_world
from prepare_osm_world import build as osm_data
from prepare_map_surfaces import build as ground_surfaces
ROOT=Path(__file__).resolve().parents[1]
source=json.loads((ROOT.parents[1]/'references/eda/mapping/bounds.json').read_text(encoding='utf-8'))
origin=(121.816326506145,39.084522240291)
height_profiles=json.loads((ROOT.parents[1]/'references/eda/buildings/residence_facades.json').read_text(encoding='utf-8'))
height_profiles.update(json.loads((ROOT.parents[1]/'references/eda/buildings/academic_facades.json').read_text(encoding='utf-8')))
height_profiles.update(json.loads((ROOT.parents[1]/'references/eda/buildings/gym_profile.json').read_text(encoding='utf-8')))
height_profiles.update(json.loads((ROOT.parents[1]/'references/eda/buildings/comprehensive_profile.json').read_text(encoding='utf-8')))
height_profiles.update(json.loads((ROOT.parents[1]/'references/eda/buildings/dining_profile.json').read_text(encoding='utf-8')))
height_profiles.update(json.loads((ROOT.parents[1]/'references/eda/buildings/library_information_profiles.json').read_text(encoding='utf-8')))
seventh_profile=json.loads((ROOT.parents[1]/'references/eda/buildings/seventh-residence/profile.json').read_text(encoding='utf-8'))
features=[]
for b in source['result']:
 name=b['name']; kind='building'; height=20.0
 if '门' in name: kind='gate'; height=5.0
 elif '湖' in name: kind='water'; height=0.18
 elif '广场' in name: kind='plaza'; height=0.1
 elif '山' in name: kind='hill'; height=26.0
 elif '用地' in name: kind='reserve'; height=0.05
 elif '运动场' in name: kind='track'; height=0.12
 elif '篮球场' in name: kind='basketball'; height=0.12
 elif '网球场' in name: kind='tennis'; height=0.12
 elif '体育馆' in name: height=15.0
 elif '图书馆' in name: height=27.0
 elif '信息楼' in name: height=24.0
 elif '教学楼' in name: height=21.0
 elif '宿舍' in name: height=23.0
 elif '食堂' in name: height=12.0
 elif '实验室' in name: height=9.0
 if str(b['id']) in height_profiles: height=float(height_profiles[str(b['id'])]['height'])
 if str(b['id']) == '2304982': height=float(seventh_profile['height'])
 points=[[round((p['x']-origin[0])*111320*math.cos(math.radians(origin[1])),3),round(-(p['y']-origin[1])*111320,3)] for p in b['bound']['points']]
 if points[-1]==points[0]:points.pop()
 features.append(dict(id=str(b['id']),name=name,kind=kind,height=height,height_source='official-news-81930' if str(b['id']) == '2304982' else height_profiles[str(b['id'])].get('height_source','photo-storey-proportion-estimate') if str(b['id']) in height_profiles else 'approximation',footprint_source='official-map',points=points))
data=dict(campus_id='eda',campus='大连理工大学 · 开发区校区',origin=list(origin),units='approximate meters',source=source['source'],retrieved=source['retrieved'],features=features)
# One runtime frame. Unreviewed source shapes are explicitly retained during
# migration; their generators still use original reference points, then bake
# this same frame conversion before terrain fitting and collision generation.
world=osm_data('eda',refine=True)
alignment=json.loads((ROOT.parents[1]/'references/eda/terrain/alignment.json').read_text(encoding='utf-8'))
scale=math.cos(math.radians(world['origin_lon_lat'][1]))/math.cos(math.radians(origin[1]))
origin_offset=osm_world.local('eda',*origin)
offset=[origin_offset[0]+alignment['offset_xz_m'][0]*scale,origin_offset[1]+alignment['offset_xz_m'][1]]
def moved(p):return [p[0]*scale+offset[0],p[1]+offset[1]]
selected={'77914':'way/1422474847','77921':'way/232559719','77917':'way/1422474848',
          '77925':'way/232559611','96575':'way/1381450451',
          '2304775':'way/232560296','39328846':'way/232560016',
          '2304759':'way/232560269','2304752':'way/1381450450'}
records={r['osm_id']:r for r in world['areas']}
for feature in features:
 if feature['id'] in selected:
  record=records[selected[feature['id']]]
  assert len(record['polygons'])==1 and not record['polygons'][0]['holes']
  feature.update(points=record['polygons'][0]['outer'],osm_id=record['osm_id'],osm_version=record['version'],footprint_source='osm',geometry_status='registered-source-outline')
  if 'refinement' in record:
   feature['footprint_refinement']=record['refinement']['id']
   feature['geometry_status']=record['refinement']['status']
 else:
  feature['reference_points']=feature['points']
  feature['points']=[moved(p) for p in feature['points']]
  feature['geometry_status']='legacy-silhouette-pending-replacement'
all_points=world['boundary']+[p for f in features for p in f['points']]
low=[math.floor(min(p[i] for p in all_points)/10)*10-30 for i in (0,1)]
high=[math.ceil(max(p[i] for p in all_points)/10)*10+30 for i in (0,1)]
data.update(origin=world['origin_lon_lat'],coordinate_frame=world['coordinate_frame'],geographic_crs='EPSG:4326',
            legacy_reference_transform={'scale_x':scale,'offset_xz':offset,'basis':'references/eda/terrain/alignment.json','status':'temporary placement for retained legacy reference geometry; not OSM footprint validation'},
            spawn_xz=moved([12,387]),bounds=low+[high[i]-low[i] for i in (0,1)],
            migration_status='shared-frame-active; unreviewed shapes explicitly retained')
data['ground_overlays']=ground_surfaces('eda')
(ROOT/'assets/campuses/eda/data/campus.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
scene_path=ROOT/'scenes/campuses/eda.tscn'
scene=scene_path.read_text(encoding='utf-8')
scene=re.sub(r'^spawn_position = Vector3\([^\n]+\)\n','',scene,flags=re.MULTILINE)
scene=scene.replace('campus_id = "eda"\n',f'campus_id = "eda"\nspawn_position = Vector3({data["spawn_xz"][0]:.6f}, 0.35, {data["spawn_xz"][1]:.6f})\n',1)
scene_path.write_text(scene,encoding='utf-8')
print(f'Prepared {len(features)} features in shared OSM frame; {len(selected)} OSM source outlines, remaining shapes marked pending')
