"""Convert official map polygons to a local model manifest. No invented footprint data."""
import json, math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
source=json.loads((ROOT.parents[1]/'references/eda/mapping/bounds.json').read_text())
origin=(121.816326506145,39.084522240291)
height_profiles=json.loads((ROOT.parents[1]/'references/eda/buildings/residence_facades.json').read_text())
height_profiles.update(json.loads((ROOT.parents[1]/'references/eda/buildings/academic_facades.json').read_text()))
height_profiles.update(json.loads((ROOT.parents[1]/'references/eda/buildings/gym_profile.json').read_text()))
height_profiles.update(json.loads((ROOT.parents[1]/'references/eda/buildings/comprehensive_profile.json').read_text()))
height_profiles.update(json.loads((ROOT.parents[1]/'references/eda/buildings/dining_profile.json').read_text()))
height_profiles.update(json.loads((ROOT.parents[1]/'references/eda/buildings/library_information_profiles.json').read_text()))
seventh_profile=json.loads((ROOT.parents[1]/'references/eda/buildings/seventh-residence/profile.json').read_text())
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
(ROOT/'assets/campuses/eda/data/campus.json').write_text(json.dumps(data,ensure_ascii=False,indent=2))
print(f'Prepared {len(features)} official footprints')
