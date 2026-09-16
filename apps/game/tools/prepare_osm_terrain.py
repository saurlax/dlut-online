"""Stage sourced elevation in the OSM world frame, without legacy translations.

Landcover polygons remain separate from this continuous elevation grid. Building
pads can only be added after footprint identity and geometry review. Panjin has
no archived elevation grid: report the gap instead of inventing OSM heights.
"""
import argparse
import hashlib
import json
import math
import statistics
from pathlib import Path

import osm_world as osm
from prepare_osm_world import build as world_data


class Elevation:
    def __init__(self, campus):
        self.campus = campus
        self.path = osm.ROOT/f'references/{campus}/terrain/heightfield.json'
        self.grid = json.loads(self.path.read_text(encoding='utf-8'))
        if (self.grid['horizontal_crs'] != 'EPSG:4326'
                or self.grid['vertical_datum'] != 'EGM2008' or self.grid['height_unit'] != 'm'):
            raise ValueError('Unsupported terrain datum or unit')
        raw = self.grid['rows_north_to_south']
        self.h, self.w = len(raw), len(raw[0])
        if (self.h != self.grid['height'] or self.w != self.grid['width']
                or any(len(row)!=self.w or any(not math.isfinite(v) for v in row) for row in raw)):
            raise ValueError('Invalid elevation grid')
        # Retain the existing conservative DSM filter; this is not a true DTM.
        lower = [[min(raw[rr][cc] for rr in range(max(0,r-1),min(self.h,r+2))
                       for cc in range(max(0,c-1),min(self.w,c+2)))
                  for c in range(self.w)] for r in range(self.h)]
        self.rows = [[statistics.mean(lower[rr][cc] for rr in range(max(0,r-1),min(self.h,r+2))
                                      for cc in range(max(0,c-1),min(self.w,c+2)))
                      for c in range(self.w)] for r in range(self.h)]

    def sample_geographic(self, lon, lat):
        col = (lon-self.grid['sample_origin_lon_lat'][0])/self.grid['sample_step_lon_lat'][0]
        row = (lat-self.grid['sample_origin_lon_lat'][1])/self.grid['sample_step_lon_lat'][1]
        if not (0 <= col < self.w-1 and 0 <= row < self.h-1):
            raise ValueError(f'Elevation coverage missing: {self.campus} {lon}, {lat}')
        c,r = int(col),int(row)
        u,v = col-c,row-r
        return ((self.rows[r][c]*(1-u)+self.rows[r][c+1]*u)*(1-v)
                +(self.rows[r+1][c]*(1-u)+self.rows[r+1][c+1]*u)*v)

    def sample(self, x, z):
        return self.sample_geographic(*osm.geographic(self.campus,x,z))


def build(campus, world=None):
    if not (osm.ROOT/f'references/{campus}/terrain/heightfield.json').exists():
        return {'campus_id':campus,'status':'missing-elevation-source',
                'reason':'No archived elevation grid. OSM horizontal features do not supply continuous height.'}
    world = world if world is not None else world_data(campus)
    elevation = Elevation(campus)
    step = 10.0
    low = [math.floor(min(p[i] for p in world['boundary'])/step)*step-30 for i in (0,1)]
    high = [math.ceil(max(p[i] for p in world['boundary'])/step)*step+30 for i in (0,1)]
    nx,nz = [round((high[i]-low[i])/step)+1 for i in (0,1)]
    datum = elevation.sample(0,0)
    rows = [[round(elevation.sample(low[0]+c*step,low[1]+r*step)-datum,4)
             for c in range(nx)] for r in range(nz)]
    return {'schema_version':1,'campus_id':campus,'status':'migration-input-not-runtime',
            'coordinate_frame':world['coordinate_frame'],'origin_lon_lat':world['origin_lon_lat'],
            'origin_xz':low,'step_m':step,'width':nx,'height':nz,
            'absolute_y_offset_egm2008_m':datum,'vertical_origin_basis':'Filtered DSM at shared local origin',
            'feature_base_y':{},'rows':rows,'old_official_shift_applied':False,
            'source':str(elevation.path.relative_to(osm.ROOT)).replace('\\','/'),
            'sha256':hashlib.sha256(elevation.path.read_bytes()).hexdigest(),
            'horizontal_scope_osm_id':world['boundary_osm_id'],
            'classification':'Provisional filtered Copernicus DSM; 10m mesh spacing is not source accuracy; no feature pads yet'}


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,default=osm.ROOT/'.local/osm-world')
    args=parser.parse_args();args.output.mkdir(parents=True,exist_ok=True)
    for campus in ('lingshui','eda','panjin'):
        data=build(campus)
        (args.output/(campus+'-terrain.json')).write_text(json.dumps(data,ensure_ascii=False,separators=(',',':'))+'\n',encoding='utf-8')
        print(campus,data['status'],data.get('width'),data.get('height'))
