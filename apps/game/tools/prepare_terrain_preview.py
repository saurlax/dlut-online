"""Build a provisional 10 m terrain grid from sourced DSM in the shared WGS84 frame."""
import argparse
import hashlib
import json
import math
import statistics
from pathlib import Path
import osm_world

ROOT = Path(__file__).resolve().parents[3]
STEP = 10.0


def inside(x, z, polygon):
    hit = False
    for (a, b), (c, d) in zip(polygon, polygon[1:] + polygon[:1]):
        if (b > z) != (d > z) and x < (c - a) * (z - b) / (d - b) + a:
            hit = not hit
    return hit


def edge_distance(x, z, polygon):
    result = float('inf')
    for (a, b), (c, d) in zip(polygon, polygon[1:] + polygon[:1]):
        length = (c-a)**2 + (d-b)**2
        t = max(0, min(1, ((x-a)*(c-a)+(z-b)*(d-b))/length)) if length else 0
        result = min(result, math.hypot(x-a-t*(c-a), z-b-t*(d-b)))
    return result


def build(campus):
    directory = ROOT / f'apps/game/assets/campuses/{campus}/data'
    manifest = json.loads((directory/'campus.json').read_text(encoding='utf-8'))
    if (manifest.get('geographic_crs') != 'EPSG:4326'
            or manifest.get('coordinate_frame') != osm_world.FRAME_PATH.relative_to(ROOT).as_posix()
            or manifest.get('origin') != osm_world.frame(campus)['origin_lon_lat']):
        raise ValueError(f'{campus}: shared WGS84 frame required; legacy terrain shifts are unsupported')
    refs = ROOT / f'references/{campus}/terrain'
    grid = json.loads((refs/'heightfield.json').read_text(encoding='utf-8'))
    raw = grid['rows_north_to_south']; h = len(raw); w = len(raw[0])
    # Lower-envelope then mean, each 3x3 source cells: an estimate, never a measured DTM.
    lower = [[min(raw[rr][cc] for rr in range(max(0,r-1),min(h,r+2)) for cc in range(max(0,c-1),min(w,c+2))) for c in range(w)] for r in range(h)]
    smooth = [[statistics.mean(lower[rr][cc] for rr in range(max(0,r-1),min(h,r+2)) for cc in range(max(0,c-1),min(w,c+2))) for c in range(w)] for r in range(h)]
    lon0,lat0=manifest['origin']; meter_lon=111320*math.cos(math.radians(lat0))
    def sample(x,z):
        lon=lon0+x/meter_lon; lat=lat0-z/111320
        col=(lon-grid['sample_origin_lon_lat'][0])/grid['sample_step_lon_lat'][0]
        row=(lat-grid['sample_origin_lon_lat'][1])/grid['sample_step_lon_lat'][1]
        assert 0<=col<w-1 and 0<=row<h-1,(campus,x,z,col,row)
        c=int(col);r=int(row);u=col-c;v=row-r
        return (smooth[r][c]*(1-u)+smooth[r][c+1]*u)*(1-v)+(smooth[r+1][c]*(1-u)+smooth[r+1][c+1]*u)*v
    bounds=manifest.get('bounds',[-640,-410,1280,930]);x0,z0,bw,bh=bounds
    nx=math.ceil(bw/STEP)+1;nz=math.ceil(bh/STEP)+1
    spawn=manifest.get('spawn_xz',[96,28] if campus=='lingshui' else [12,387])
    datum=sample(*spawn)
    rows=[[sample(x0+c*STEP,z0+r*STEP)-datum for c in range(nx)] for r in range(nz)]
    pads={}
    priorities=[[float("inf") for _ in range(nx)] for _ in range(nz)]
    feature_samples={}
    for f in manifest["features"]:
        feature_samples.setdefault(f["id"], []).extend(sample(*p) for p in f["points"])
    for f in manifest['features']:
        if f['kind'] not in ['building','water','sports','track','basketball','tennis','gate']:continue
        polygons=f.get('render_polygons',[f['points']]);points=f['points']
        if not polygons:continue
        level=statistics.median(feature_samples[f["id"]])-datum
        name='Feature_'+f['id']+('_'+str(f['part']) if 'part' in f else '')
        pads[name]=round(level,4)
        for polygon in polygons:
            xs=[p[0] for p in polygon];zs=[p[1] for p in polygon]
            for r in range(max(0,int((min(zs)-20-z0)/STEP)),min(nz,math.ceil((max(zs)+20-z0)/STEP)+1)):
                for c in range(max(0,int((min(xs)-20-x0)/STEP)),min(nx,math.ceil((max(xs)+20-x0)/STEP)+1)):
                    x=x0+c*STEP;z=z0+r*STEP;distance=edge_distance(x,z,polygon)
                    signed_distance = -distance if inside(x,z,polygon) else distance
                    if signed_distance >= priorities[r][c]: continue
                    priorities[r][c] = signed_distance
                    weight=1 if signed_distance<7.5 else max(0,1-(signed_distance-7.5)/12.5)
                    rows[r][c]=(sample(x,z)-datum)*(1-weight)+level*weight
    output={'schema_version':1,'campus_id':campus,'origin_xz':[x0,z0],'step_m':STEP,'width':nx,'height':nz,'absolute_y_offset_egm2008_m':datum,'feature_base_y':pads,'rows':[[round(v,4) for v in row] for row in rows],'basis':manifest['coordinate_frame'],'classification':'provisional filtered DSM with estimated feature pads; 10m is mesh spacing, not survey accuracy'}
    output.update(horizontal_crs='EPSG:4326',old_official_shift_applied=False)
    output.update(vertical_datum='EGM2008', height_unit='m',
                  source=(refs/'heightfield.json').relative_to(ROOT).as_posix(),
                  source_sha256=hashlib.sha256((refs/'heightfield.json').read_bytes()).hexdigest())
    (directory/'terrain.json').write_text(json.dumps(output,separators=(',',':'),ensure_ascii=False)+'\n',encoding='utf-8')
    print(campus,nx,nz,'vertical origin',datum)


if __name__=='__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--campus', choices=['lingshui','eda','panjin','all'], default='all')
    args = parser.parse_args()
    for campus in ['lingshui','eda','panjin'] if args.campus == 'all' else [args.campus]:
        build(campus)
