"""Normalize acquired outlines and fit review candidates; never writes game data.

Run after footprint_review.py, using its cached, source-validated review cases.
Outputs stay in .local/footprint-consensus. No networking or dependencies.
"""
import argparse
import hashlib
import html
import json
import math
from pathlib import Path
import xml.etree.ElementTree as ET

from footprint_review import ROOT, CONFIG, build_case, restore_drafts, simple_polygon


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def ring(points):
    points = [list(p) for p in points]
    if points and points[0] == points[-1]:
        points.pop()
    return points


def area(points):
    return abs(sum(a[0]*b[1]-b[0]*a[1]
                   for a,b in zip(points, points[1:]+points[:1]))) / 2


def distance(p, a, b):
    dx,dy=b[0]-a[0],b[1]-a[1]
    t=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dy)/(dx*dx+dy*dy))) if dx or dy else 0
    return math.hypot(p[0]-a[0]-t*dx,p[1]-a[1]-t*dy)


def boundary_error(a,b):
    # Densify edges: vertices alone miss large concavities / bowed boundaries.
    def directed(x,y):
        return max(min(distance([p[0]+(q[0]-p[0])*i/20,p[1]+(q[1]-p[1])*i/20],u,v)
                       for u,v in zip(y,y[1:]+y[:1]))
                   for p,q in zip(x,x[1:]+x[:1]) for i in range(21))
    return max(directed(a,b),directed(b,a))


def rectangle_fit(points):
    """Try edge orientations; do not presume every building is rectangular."""
    if not simple_polygon(points):
        raise ValueError('Cannot fit invalid or sub-square-meter review geometry')
    best=None
    for a,b in zip(points,points[1:]+points[:1]):
        angle=math.atan2(b[1]-a[1],b[0]-a[0]); c,s=math.cos(angle),math.sin(angle)
        uv=[(x*c+y*s,-x*s+y*c) for x,y in points]
        lo=[min(p[i] for p in uv) for i in (0,1)]
        hi=[max(p[i] for p in uv) for i in (0,1)]
        box=[[u*c-v*s,u*s+v*c] for u,v in
             [(lo[0],lo[1]),(hi[0],lo[1]),(hi[0],hi[1]),(lo[0],hi[1])]]
        score=boundary_error(points,box)
        if best is None or score<best[0]: best=(score,box)
    error,box=best
    change=abs(area(box)/area(points)-1)
    accepted=error<=0.6 and change<=0.03
    return (box if accepted else points), {"method":"edge-oriented enclosing rectangle",
        "accepted":accepted,"sampled_boundary_error_m":error,"relative_area_change":change,
        "limits":{"boundary_m":0.6,"area_fraction":0.03},
        "meaning":"shape regularization only; not positional accuracy"}


def record(campus, source, identity, points, frame, path, **props):
    points=ring(points)
    # Check in a translated plane to avoid longitude cancellation.
    local=[[(x-points[0][0])*111320*math.cos(math.radians(points[0][1])),
            (y-points[0][1])*111320] for x,y in points] if points else []
    return {"campus":campus,"source":source,"id":identity,"frame":frame,
            "archive":str(path.relative_to(ROOT)).replace('\\','/'),"sha256":digest(path),
            "source_url":('https://www.openstreetmap.org/'+identity if source=='osm' else
                          'http://map.dlut.edu.cn/openmap/mapi/bd/v1/bound'),
            "license":('© OpenStreetMap contributors, ODbL 1.0' if source=='osm' else 'unconfirmed; local reference only'),
            "bound":{"geoType":"polygon","points":[{"x":x,"y":y} for x,y in points]},
            "valid":len(points)>=3 and simple_polygon(local),**props}


def relation_rings(relation, ways, nodes):
    """Join member ways by node identity, preserving outer/inner roles."""
    result=[]
    for role in ('outer','inner'):
        pending=[]
        for m in relation.findall('member'):
            if m.get('type')!='way' or (m.get('role') or 'outer')!=role:
                continue
            refs=ways.get(m.get('ref'))
            if not refs or any(n not in nodes for n in refs): return None
            pending.append(list(refs))
        while pending:
            chain=pending.pop(0)
            while chain[-1]!=chain[0]:
                matches=[(i,False) for i,p in enumerate(pending) if p[0]==chain[-1]]
                matches += [(i,True) for i,p in enumerate(pending) if p[-1]==chain[-1]]
                if len(matches)!=1: return None
                i,reverse=matches[0]; part=pending.pop(i)
                chain.extend((part[::-1] if reverse else part)[1:])
            if len(chain)<4: return None
            result.append({'role':role,'points':[{'x':nodes[n][0],'y':nodes[n][1]} for n in chain[:-1]]})
    if any(m.get('type')!='way' or m.get('role','') not in ('','outer','inner') for m in relation.findall('member')):
        return None
    return result if any(r['role']=='outer' for r in result) else None


def run(output):
    output.mkdir(parents=True,exist_ok=True)
    records=[]; inventory=[]
    for campus in ('lingshui','eda','panjin'):
        path=ROOT/f'references/{campus}/mapping/bounds.json'
        data=json.loads(path.read_text(encoding='utf-8'))
        for i,f in enumerate(data['result']):
            if f.get('bound',{}).get('geoType')!='polygon': continue
            records.append(record(campus,'official',str(f['id']),
                [[p['x'],p['y']] for p in f['bound']['points']], 'official-numeric-datum-unverified',path,
                part_index=i,name=f.get('name'),role='interaction-outline-not-ground-truth'))
        path=ROOT/f'.local/osm-audit/{campus}.osm'
        xml=ET.parse(path).getroot()
        nodes={n.get('id'):[float(n.get('lon')),float(n.get('lat'))] for n in xml.findall('node')}
        relations=[]; skipped=[]
        ways={w.get('id'):[n.get('ref') for n in w.findall('nd')] for w in xml.findall('way')}
        for w in xml.findall('way'):
            tags={t.get('k'):t.get('v') for t in w.findall('tag')}
            if tags.get('building','no')=='no': continue
            refs=[n.get('ref') for n in w.findall('nd')]
            if len(refs)<4 or refs[0]!=refs[-1] or any(n not in nodes for n in refs):
                skipped.append(w.get('id')); continue
            records.append(record(campus,'osm','way/'+w.get('id'),[nodes[n] for n in refs],
                'EPSG:4326',path,tags=tags,version=w.get('version'),timestamp=w.get('timestamp'),
                role='building-candidate',scope='downloaded-bbox-not-campus-filtered'))
        for r in xml.findall('relation'):
            tags={t.get('k'):t.get('v') for t in r.findall('tag')}
            if tags.get('building','no')!='no':
                rings=relation_rings(r,ways,nodes) if tags.get('type')=='multipolygon' else None
                if rings:
                    rec=record(campus,'osm','relation/'+r.get('id'),
                        [[p['x'],p['y']] for p in rings[0]['points']], 'EPSG:4326',path,tags=tags,
                        version=r.get('version'),scope='downloaded-bbox-not-campus-filtered',
                        members=[dict(m.attrib) for m in r.findall('member')])
                    rec['valid']=all(record(campus,'osm','relation/'+r.get('id'),
                        [[p['x'],p['y']] for p in item['points']], 'EPSG:4326',path)['valid'] for item in rings)
                    rec['validation']='individual rings only; nesting and overlaps unverified'
                    rec['bound']={'geoType':'multiRing','rings':rings}
                    records.append(rec)
                else:
                    relations.append({'id':r.get('id'),'tags':tags,'members':[dict(m.attrib) for m in r.findall('member')]})
        inventory.append({'campus':campus,'unconverted_building_relations':relations,'unclosed_or_incomplete_ways':skipped})
    config=json.loads(CONFIG.read_text(encoding='utf-8'))
    cases=[build_case(c,config,ROOT/'.local/footprint-review/cache',False) for c in config['cases']]
    draft_path=ROOT/'.local/footprint-review/draft.json'
    if draft_path.exists(): restore_drafts(json.loads(draft_path.read_text(encoding='utf-8')),cases)
    results=[]; panels=[]
    for c in cases:
        scale=c['meters_per_pixel_approx']
        convert=lambda pts:[[x*scale,y*scale] for x,y in pts]
        osm=convert(c['osm']['points']); official=convert(c['official']['points'])
        draft=c.get('draft',{})
        edited=bool(draft) and draft['points']!=c['osm']['points']
        base=convert(draft['points']) if edited else osm
        candidate,fit=rectangle_fit(base)
        origin=c['pixel_origin']; zoom=c['zoom']; n=256*2**zoom
        pixels=[[x/scale,y/scale] for x,y in candidate]
        ll=[[ (x+origin[0])/n*360-180,
              math.degrees(math.atan(math.sinh(math.pi*(1-2*(y+origin[1])/n))))] for x,y in pixels]
        result={'campus':c['campus'],'official_id':c['official_id'],'osm_way_id':c['osm_way_id'],
            'name':c['name'],'status':'unverified-candidate','absolute_accuracy_m':None,
            'frame':'official-lm30-numeric-datum-unverified','pixel_origin':origin,'zoom':zoom,
            'selected_basis':'manual-map-draft' if edited else 'osm-provisional-placement',
            'notes':draft.get('notes',''),'fit':fit,'initial_alignment':c['initial_alignment'],
            'official_vs_osm_sampled_boundary_m':boundary_error(official,osm),
            'official_vs_osm_area_ratio':area(official)/area(osm),
            'bound':{'geoType':'polygon','points':[{'x':x,'y':y} for x,y in ll]},
            'pixel_points':pixels,'source_hashes':{'official':c['official']['sha256'],'osm':c['osm']['source']['sha256']},
            'excluded_from_fitting':['official interaction silhouette'],
            'independent_verified_ground_sources':0}
        results.append(result)
        all_points=official+osm+candidate
        low=[min(p[i] for p in all_points)-5 for i in (0,1)]
        high=[max(p[i] for p in all_points)+5 for i in (0,1)]
        shapes=''.join('<polygon class="'+layer+'" fill="none" stroke="'+color+'" vector-effect="non-scaling-stroke" stroke-width="'+width+'" '+dash+' points="'+
                       ' '.join(f'{x},{y}' for x,y in pts)+'"/>'
                       for layer,color,width,dash,pts in [
                           ('official','#e05252','2','',official),
                           ('osm','#3284df','4','',osm),
                           ('candidate','#c79400','2','stroke-dasharray="8 6"',candidate)])
        panels.append('<article><h2>'+html.escape(c['name'])+'</h2><svg viewBox="'+
                      f'{low[0]} {low[1]} {high[0]-low[0]} {high[1]-low[1]}'+
                      '">'+shapes+'</svg><p>'+('矩形约束通过' if fit['accepted'] else '拒绝矩形约束，保留原形')+
                      f'；约束误差 {fit["sampled_boundary_error_m"]:.2f} 米</p></article>')
    def save(name,data): (output/name).write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
    save('normalized-bounds.json',{'schema_version':1,'records':records,'inventory':inventory})
    template=Path(__file__).with_name('footprint_catalog.html').read_text(encoding='utf-8')
    payload=json.dumps({'records':records,'inventory':inventory},ensure_ascii=False).replace('<','\\u003c')
    (output/'catalog.html').write_text(template.replace('__DATA__',payload),encoding='utf-8')
    save('candidate-bounds.json',{'schema_version':1,'status':'review-only','results':results})
    save('sources.json',{'available':['official polygons','OSM bbox XML','six cached map-plane cases'],
        'not_convertible_yet':{'amap':'page only; no acquired geometry','baidu':'page/POI only; no acquired geometry',
        'campus_pdf':'raster map, no validated ground control or vector extraction',
        'overture':'no local campus extract','east_asia':'catalog only; no local campus extract',
        'CBF':'restricted files'},'limitations':['OSM bbox is not campus boundary',
        'complete multipolygon relations assembled as role-tagged rings; relation/member duplication retained',
        'No cross-source average: no independent verified ground footprints or control points']})
    rows=['# 建筑轮廓整理与候选拟合','',
          '全部结果仅用于复核，绝对位置精度未知。官网 bound 不参与几何平均；来源未验证不能通过拟合变为测绘数据。','',
          '| 样本 | 候选依据 | 矩形约束 | 约束边界误差（米） | 官网/OSM 面积比 |',
          '|---|---|---|---:|---:|']
    for r in results:
        f=r['fit']; rows.append(f"| {r['name']} | {r['selected_basis']} | {'通过' if f['accepted'] else '拒绝，保留原形'} | {f['sampled_boundary_error_m']:.2f} | {r['official_vs_osm_area_ratio']:.2f} |")
    rows+=['','误差是图面候选与矩形约束的差异，不是相对真实建筑的误差。',
           '厚民楼草稿只覆盖可见主矩形体，附属部分尚未确认。信息楼身份及拆分待核实。',
           f'标准化记录：{len(records)}；无效几何：{sum(not r["valid"] for r in records)}。',
           '完整 OSM relation 已转换为 multiRing；未组环关系、未闭合轮廓及未取得几何的来源见 inventory 与 sources.json。']
    (output/'report.md').write_text('\n'.join(rows),encoding='utf-8')
    (output/'comparison.html').write_text('<!doctype html><meta charset="utf-8"><title>轮廓候选拟合</title>'
        '<style>body{font:16px sans-serif;margin:30px;background:#fafafa}main{display:grid;grid-template-columns:repeat(3,1fr);gap:20px}'
        'article{background:white;border:1px solid #ddd;padding:16px}svg{width:100%;height:320px}h2{font-size:18px}'
        'table{border-collapse:collapse;width:100%;background:white}td,th{padding:9px;border:1px solid #ddd;text-align:left}'
        'label{display:inline-block;margin:12px 20px 12px 0}@media(max-width:900px){main{grid-template-columns:1fr}}</style>'
        '<h1>2 份几何来源，6 个建筑样本</h1><p><a href="catalog.html">查看三校区全部已下载 bound（含 OSM 多环关系）</a></p><p>黄框是派生候选，不是第三份独立来源；之前列出的其他来源尚未取得可绘制的建筑轮廓。</p>'
        '<table><tr><th>来源</th><th>已取得资料</th><th>当前可绘制 bound</th></tr>'
        '<tr><td>官网校园地图</td><td>交互多边形、二维瓦片</td><td>红色实线，不能直接认作基底</td></tr>'
        '<tr><td>OSM</td><td>建筑多边形</td><td>蓝色粗实线，初始位置未验证</td></tr>'
        '<tr><td>高德</td><td>地图页面</td><td>无，尚未取得几何</td></tr>'
        '<tr><td>百度</td><td>地图页面和 POI</td><td>无，尚未取得几何</td></tr>'
        '<tr><td>校园正射 PDF</td><td>压缩影像</td><td>无，尚未配准、描绘</td></tr>'
        '<tr><td>Overture</td><td>来源文档</td><td>无，尚未提取校园数据</td></tr>'
        '<tr><td>东亚建筑数据集</td><td>数据目录</td><td>无，尚未提取校园数据</td></tr>'
        '<tr><td>武汉大学 CBF</td><td>数据目录，文件受限</td><td>无，尚未取得数据</td></tr></table>'
        '<p>重合处以蓝色粗实线承托黄色细虚线，开关可分别查看；没有人为移动轮廓来制造差异。</p>'
        '<label><input type="checkbox" checked data-layer="official">官网红线</label>'
        '<label><input type="checkbox" checked data-layer="osm">OSM 蓝线</label>'
        '<label><input type="checkbox" checked data-layer="candidate">派生候选黄虚线</label>'
        '<p>只对已配对的六个样本做保守形状约束，不平均斜视轮廓。不把图面拟合残差当作真实误差。</p><main>'+
        ''.join(panels)+'</main><script>document.querySelectorAll("input[data-layer]").forEach(input=>'
        'input.addEventListener("change",()=>document.querySelectorAll("polygon."+input.dataset.layer)'
        '.forEach(p=>p.style.display=input.checked?"":"none")))</script>',encoding='utf-8')
    print(json.dumps({'records':len(records),'invalid':sum(not r['valid'] for r in records),
                      'samples':len(results),'rectangle_fits':sum(r['fit']['accepted'] for r in results)}))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,default=ROOT/'.local/footprint-consensus')
    run(parser.parse_args().output)
