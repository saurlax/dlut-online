"""Replay locally traced ground surfaces anchored to archived OSM geometry."""
import hashlib
import json
import math

import osm_world as osm


def build(campus):
    path = osm.ROOT / f'references/{campus}/mapping/ground-surfaces.json'
    if not path.exists():
        return []
    spec = json.loads(path.read_text(encoding='utf-8'))
    _, nodes, ways, _ = osm.archive(campus)
    result = []
    for item in spec['surfaces']:
        anchor = item['osm_anchor']
        way = ways[anchor['way_id']]
        if int(way.get('version')) != anchor['version']:
            raise ValueError('Ground surface anchor version changed')
        line = [osm.local(campus, *p) for p in osm.way_coordinates(way, nodes)]
        loop = line[anchor['loop_start_vertex']:]
        if math.dist(loop[0], loop[-1]) > 0.001:
            raise ValueError('Declared plaza anchor must be a closed OSM loop')
        center = [(min(p[i] for p in loop)+max(p[i] for p in loop))/2 for i in (0, 1)]
        direction = item['scale_direction']
        building = ways[direction['way_id']]
        if int(building.get('version')) != direction['version']:
            raise ValueError('Ground surface scale reference version changed')
        points = [osm.local(campus, *p) for p in osm.way_coordinates(building, nodes)]
        a, b = [points[i] for i in direction['vertices']]
        pa, pb = direction['pixels']
        dx, dy = pb[0]-pa[0], pb[1]-pa[1]
        denom = dx*dx+dy*dy
        real = ((b[0]-a[0])*dx+(b[1]-a[1])*dy)/denom
        imag = ((b[1]-a[1])*dx-(b[0]-a[0])*dy)/denom
        def convert(p):
            x, y = p[0]-item['pixel_anchor'][0], p[1]-item['pixel_anchor'][1]
            return [center[0]+real*x-imag*y, center[1]+imag*x+real*y]
        outer = [convert(p) for p in item['pixel_outer']]
        holes = [[convert(p) for p in ring] for ring in item['pixel_holes']]
        from prepare_osm_world import valid_ring
        if not all(valid_ring(ring) for ring in [outer]+holes):
            raise ValueError('Invalid map surface ring')
        result.append({'id':item['id'], 'kind':'plaza', 'outer':outer, 'holes':holes,
                       'source':str(path.relative_to(osm.ROOT)).replace('\\','/'),
                       'source_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                       'status':item['status'], 'osm_anchor_way':anchor['way_id'],
                       'absolute_accuracy_m':None})
    return result
