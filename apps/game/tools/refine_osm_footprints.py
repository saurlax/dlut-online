"""Transfer recorded local map details while preserving OSM exterior anchors.

This is image-supported shape refinement, not geodetic rectification. No datum
conversion or global translation is inferred from the illustration.
"""
import copy
import hashlib
import json
import math

import osm_world as osm


def similarity_map(source, target):
    if len(source) != 2 or len(target) != 2:
        raise ValueError('Exactly two declared similarity anchors required')
    start, finish = [complex(*p) for p in source]
    a, b = [complex(*p) for p in target]
    if abs(finish-start) < 1e-9 or abs(b-a) < 1e-9:
        raise ValueError('Degenerate similarity anchors')
    scale_rotation = (b-a)/(finish-start)
    def transform(point):
        result = a + scale_rotation*(complex(*point)-start)
        if not math.isfinite(result.real) or not math.isfinite(result.imag):
            raise ValueError('Nonfinite similarity refinement')
        return [result.real, result.imag]
    return transform


def projective_map(source, target):
    if len(source)!=4 or len(target)!=4:
        raise ValueError('Exactly four declared anchors required')
    rows=[]
    for (x,y),(u,v) in zip(source,target):
        rows.extend([[x,y,1,0,0,0,-u*x,-u*y,u],
                     [0,0,0,x,y,1,-v*x,-v*y,v]])
    for col in range(8):
        pivot=max(range(col,8),key=lambda row:abs(rows[row][col]))
        rows[col],rows[pivot]=rows[pivot],rows[col]
        if abs(rows[col][col])<1e-10:raise ValueError('Degenerate refinement anchors')
        scale=rows[col][col]
        rows[col]=[v/scale for v in rows[col]]
        for row in range(8):
            if row==col:continue
            scale=rows[row][col]
            rows[row]=[a-scale*b for a,b in zip(rows[row],rows[col])]
    h=[r[-1] for r in rows]
    def transform(point):
        x,y=point;d=h[6]*x+h[7]*y+1
        if abs(d)<1e-9:raise ValueError('Refinement crosses projective horizon')
        result=[(h[0]*x+h[1]*y+h[2])/d,(h[3]*x+h[4]*y+h[5])/d]
        if not all(math.isfinite(v) for v in result):raise ValueError('Nonfinite refinement')
        return result
    return transform


def refine(campus, record):
    path=osm.ROOT/f'references/{campus}/mapping/footprint-refinements.json'
    if not path.exists():return record
    data=json.loads(path.read_text(encoding='utf-8'))
    matches=[r for r in data['refinements'] if r['osm_id']==record['osm_id']]
    if not matches:return record
    if len(matches)!=1:raise ValueError('Duplicate footprint refinement')
    spec=matches[0]
    if record['version']!=spec['osm_version']:raise ValueError('OSM version changed; recheck refinement')
    if len(record['polygons'])!=1 or record['polygons'][0]['holes']:
        raise ValueError('Refinement requires one declared exterior ring')
    original=record['polygons'][0]['outer']
    if len(original)!=spec['original_vertex_count']:raise ValueError('OSM ring changed')
    source=[a['pixel'] for a in spec['anchors']]
    target=[original[a['osm_vertex']] for a in spec['anchors']]
    method=spec.get('method','projective')
    if method=='similarity':
        convert=similarity_map(source,target)
    elif method=='projective':
        convert=projective_map(source,target)
    else:
        raise ValueError('Unknown footprint refinement method')
    points=[convert(p) for p in spec['pixel_outline']]
    from prepare_osm_world import valid_ring, area
    if not valid_ring(points):raise ValueError('Invalid refined footprint')
    ratio=area(points)/area(original)
    if not spec['area_ratio_limits'][0]<=ratio<=spec['area_ratio_limits'][1]:
        raise ValueError('Refinement area change exceeds recorded limits')
    result=copy.deepcopy(record)
    result['original_polygons']=result['polygons']
    result['original_area_m2']=result['area_m2']
    result['polygons']=[{'outer':points,'holes':[]}]
    result['area_m2']=area(points)
    result['refinement']={'id':spec['id'],'status':spec['status'],
        'source':str(path.relative_to(osm.ROOT)).replace('\\','/'),
        'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
        'method':'two OSM anchors; shape-preserving map similarity' if method=='similarity' else 'four exterior OSM anchors; map-traced local notches',
        'absolute_accuracy_m':None,'limits':spec['limits']}
    if spec.get('check_anchors'):
        result['refinement']['check_anchor_residuals_m']=[
            {'osm_vertex':a['osm_vertex'],'distance_m':math.dist(convert(a['pixel']),original[a['osm_vertex']])}
            for a in spec['check_anchors']]
    return result
