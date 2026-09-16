"""Extract OSM buildings and terrain features in the shared WGS84 local frame.

Offline, deterministic migration input. Output is staged outside runtime until
identity conflicts, photo facade anchors and all dependent layers are migrated.
No assumed elevations, automatic footprint averaging or invented polygon closure.
"""
import argparse
from collections import Counter, defaultdict
import json
import math
from pathlib import Path

import osm_world as osm


def on_segment(p, a, b):
    return (abs((b[0]-a[0])*(p[1]-a[1])-(b[1]-a[1])*(p[0]-a[0])) < 1e-7
            and min(a[0], b[0])-1e-7 <= p[0] <= max(a[0], b[0])+1e-7
            and min(a[1], b[1])-1e-7 <= p[1] <= max(a[1], b[1])+1e-7)


def inside(p, ring):
    hit = False
    for a, b in zip(ring, ring[1:]+ring[:1]):
        if on_segment(p, a, b):
            return True
        if ((a[1] > p[1]) != (b[1] > p[1])
                and p[0] < (b[0]-a[0])*(p[1]-a[1])/(b[1]-a[1])+a[0]):
            hit = not hit
    return hit


def intersects(a, b, c, d):
    def cross(p, q, r):
        return (q[0]-p[0])*(r[1]-p[1])-(q[1]-p[1])*(r[0]-p[0])
    return (cross(a,b,c)*cross(a,b,d) < 0 and cross(c,d,a)*cross(c,d,b) < 0
            or on_segment(a,c,d) or on_segment(b,c,d)
            or on_segment(c,a,b) or on_segment(d,a,b))


def crosses(a, b, c, d):
    def side(p,q,r):
        return (q[0]-p[0])*(r[1]-p[1])-(q[1]-p[1])*(r[0]-p[0])
    return side(a,b,c)*side(a,b,d) < 0 and side(c,d,a)*side(c,d,b) < 0


def area(ring):
    return abs(sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(ring,ring[1:]+ring[:1])))/2


def valid_ring(ring):
    if len(ring) < 3 or area(ring) < 0.01:
        return False
    edges = list(zip(ring, ring[1:]+ring[:1]))
    for i, (a,b) in enumerate(edges):
        if math.dist(a,b) < 1e-6:
            return False
        for j in range(i+2,len(edges)):
            if i == 0 and j == len(edges)-1:
                continue
            if intersects(a,b,*edges[j]):
                return False
    return True


def rings_touch(a, b):
    return any(intersects(p,q,r,s) for p,q in zip(a,a[1:]+a[:1])
               for r,s in zip(b,b[1:]+b[:1]))


def scope(points, boundary, closed=True):
    hits = [inside(p,boundary) for p in points]
    if all(hits):
        # Endpoints alone do not prove containment in a concave boundary.
        edges = zip(points,points[1:]+points[:1]) if closed else zip(points,points[1:])
        if all(inside([(a[k]+b[k])/2 for k in (0,1)],boundary)
               and not any(crosses(a,b,c,d) for c,d in zip(boundary,boundary[1:]+boundary[:1]))
               for a,b in edges):
            return 'inside'
    edges = list(zip(points,points[1:]+points[:1])) if closed else list(zip(points,points[1:]))
    if (any(hits) or (closed and inside(boundary[0],points)) or any(
            intersects(a,b,c,d) for a,b in edges for c,d in zip(boundary,boundary[1:]+boundary[:1]))):
        return 'boundary-crossing'
    return 'outside'


def category(tags):
    if tags.get('building','no') != 'no': return 'building'
    if tags.get('natural') == 'water' or tags.get('waterway') == 'riverbank': return 'water'
    if tags.get('landuse') in ('forest','grass','meadow') or tags.get('natural') in ('wood','scrub','grassland'): return 'vegetation-area'
    if tags.get('leisure') in ('park','garden'): return 'garden'
    if tags.get('leisure') in ('pitch','track','stadium','sports_centre'): return 'sports'
    if tags.get('amenity') == 'parking': return 'parking'
    if tags.get('area:highway') or tags.get('highway') == 'pedestrian' and tags.get('area') == 'yes': return 'paved-area'
    if tags.get('landuse') in ('construction','brownfield'): return 'reserve'
    return None


def build(campus, include_outside=False):
    source,nodes,ways,relations = osm.archive(campus)
    spec = osm.frame(campus)
    boundary = [osm.local(campus,*p) for p in osm.way_coordinates(ways[spec['boundary_way']],nodes)[:-1]]
    records, lines, points, rejected, outside, members = [], [], [], [], Counter(), set()

    def add(element, kind, raw_rings):
        rings = [{'role':r['role'],'points':[osm.local(campus,*p) for p in r['lon_lat']]} for r in raw_rings]
        outer = [r['points'] for r in rings if r['role']=='outer']
        coverage = [scope(r,boundary) for r in outer]
        if all(s=='outside' for s in coverage):
            outside[kind] += 1
            if not include_outside:
                return
        if not all(valid_ring(r['points']) for r in rings):
            raise ValueError('Degenerate or self-intersecting ring')
        polygons = [{'outer':p,'holes':[]} for p in outer]
        for r in rings:
            if r['role']!='inner': continue
            owners = [p for p in polygons if inside(r['points'][0],p['outer'])
                      and not rings_touch(r['points'],p['outer'])]
            if len(owners)!=1:
                raise ValueError('Inner ring has no unique containing outer')
            owners[0]['holes'].append(r['points'])
        for p in polygons:
            for i,a in enumerate(p['holes']):
                if any(rings_touch(a,b) or inside(a[0],b) or inside(b[0],a) for b in p['holes'][i+1:]):
                    raise ValueError('Intersecting or nested inner rings')
        for i,a in enumerate(outer):
            if any(rings_touch(a,b) or inside(a[0],b) or inside(b[0],a) for b in outer[i+1:]):
                raise ValueError('Intersecting or nested outer rings')
        records.append({'osm_id':element.tag+'/'+element.get('id'),'version':int(element.get('version')),
                        'tags':osm.tags(element),'category':kind,'polygons':polygons,
                        'scope':('inside' if all(s=='inside' for s in coverage) else
                                 'outside' if all(s=='outside' for s in coverage) else 'boundary-crossing'),
                        'area_m2':sum(area(p['outer'])-sum(area(h) for h in p['holes']) for p in polygons)})

    for element in relations.values():
        kind=category(osm.tags(element))
        if not kind: continue
        relation_members={m.get('ref') for m in element.findall('member') if m.get('type')=='way'}
        # A failed relation must not silently become a filled outer member.
        members.update(relation_members)
        try:
            add(element,kind,osm.relation_rings(element,ways,nodes))
        except ValueError as error:
            rejected.append({'osm_id':'relation/'+element.get('id'),'reason':str(error)})
    for element in ways.values():
        t=osm.tags(element);kind=category(t)
        ll=osm.way_coordinates(element,nodes)
        local=[osm.local(campus,*p) for p in ll]
        closed=len(ll)>3 and ll[0]==ll[-1]
        line_kind=('road' if 'highway' in t and t.get('area')!='yes' else 'watercourse' if 'waterway' in t
                   else 'tree-row' if t.get('natural')=='tree_row' else 'contour' if 'contour' in t else None)
        if line_kind and scope(local,boundary,False)!='outside':
            lines.append({'osm_id':'way/'+element.get('id'),'version':int(element.get('version')),
                          'category':line_kind,'tags':t,'points':local,'scope':scope(local,boundary,False)})
        if not kind or element.get('id') in members: continue
        if not closed:
            if scope(local,boundary,False)!='outside':
                rejected.append({'osm_id':'way/'+element.get('id'),'reason':'Open way is not an area'})
            continue
        try:
            add(element,kind,[{'role':'outer','lon_lat':ll[:-1]}])
        except ValueError as error:
            rejected.append({'osm_id':'way/'+element.get('id'),'reason':str(error)})
    for element in nodes.values():
        t=osm.tags(element)
        if not ('ele' in t or t.get('natural') in ('peak','tree') or t.get('barrier') in ('gate','entrance')): continue
        p=osm.local(campus,float(element.get('lon')),float(element.get('lat')))
        if inside(p,boundary):
            points.append({'osm_id':'node/'+element.get('id'),'tags':t,'point':p})
    names=defaultdict(list)
    for r in records:
        if r['category']=='building' and r['tags'].get('name'):
            names[r['tags']['name']].append(r['osm_id'])
    conflicts=[{'name':n,'osm_ids':ids,'status':'identity-review-required'} for n,ids in names.items() if len(ids)>1]
    return {'schema_version':1,'campus_id':campus,'status':'migration-input-not-runtime',
            'scope_selection':'full-archive' if include_outside else 'university-boundary-intersection',
            'coordinate_frame':str(osm.FRAME_PATH.relative_to(osm.ROOT)).replace('\\','/'),
            'origin_lon_lat':spec['origin_lon_lat'],'axes':'X east, Z south; metres',
            'source':source,'boundary_osm_id':'way/'+spec['boundary_way'],'boundary':boundary,
            'areas':records,'lines':lines,'points':points,'identity_conflicts':conflicts,
            'rejected':rejected,'outside_counts':dict(outside),
            'limits':['Boundary crossing geometry retained whole for explicit clipping at generation.',
                      'OSM campus boundary is a source feature, not a verified property survey.',
                      'Areas may overlap semantically; category precedence belongs to terrain generation.',
                      'No continuous elevation is inferred from landcover, peak points or missing contours.']}


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,default=osm.ROOT/'.local/osm-world')
    args=parser.parse_args();args.output.mkdir(parents=True,exist_ok=True)
    for campus in ('lingshui','eda','panjin'):
        data=build(campus)
        (args.output/(campus+'.json')).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        print(campus,dict(Counter(r['category'] for r in data['areas'])),
              'lines',len(data['lines']),'points',len(data['points']),
              'conflicts',len(data['identity_conflicts']),'rejected',len(data['rejected']))
