"""Prepare separate, sourced campus backgrounds (offline: rasterio, numpy, shapely).

Run before build_surroundings.gd. Raw DSM crops and source records are archived;
no imagery pixels or synthetic peaks are embedded in the client.
"""
import argparse
import hashlib
import json
import math
import random
from pathlib import Path
import urllib.request

import numpy as np
import rasterio
from rasterio.windows import from_bounds, Window
from shapely.geometry import Polygon, Point, box
from shapely import constrained_delaunay_triangles, unary_union
from shapely.prepared import prep

import osm_world as osm
from prepare_osm_world import build as osm_data

ROOT = osm.ROOT


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")


def terrain_sample(t, x, z):
    u = np.clip((x-t['origin_xz'][0])/t['step_m'], 0, t['width']-1.000001)
    v = np.clip((z-t['origin_xz'][1])/t['step_m'], 0, t['height']-1.000001)
    c, r = int(u), int(v)
    u, v = u-c, v-r
    a, b = t['rows'][r][c:c+2]
    d, e = t['rows'][r+1][c:c+2]
    return a+u*(b-a)+v*(d-a) if u+v <= 1 else e+(1-u)*(d-e)+(1-v)*(b-e)


def build(campus, cache):
    config = read(ROOT/'references/shared/terrain/surroundings.json')
    spec = config['campuses'][campus]
    dem = read(ROOT/'references/shared/terrain/copernicus.json')['campuses'][campus]
    tile = cache/dem['file']
    cache.mkdir(parents=True, exist_ok=True)
    if not tile.exists():
        with urllib.request.urlopen(dem['url'], timeout=120) as response:
            tile.write_bytes(response.read())
    if hashlib.sha256(tile.read_bytes()).hexdigest() != dem['sha256']:
        raise ValueError('DSM source checksum mismatch')
    reference = ROOT/f'references/{campus}/terrain'
    crop = reference/'surroundings-dem.tif'
    with rasterio.open(tile) as src:
        if src.crs is None or src.crs.to_epsg()!=4326 or src.count!=1:
            raise ValueError('Expected a single-band WGS84 DSM')
        w = from_bounds(*spec['bbox_wgs84'], src.transform)
        left, top = math.floor(w.col_off)-3, math.floor(w.row_off)-3
        window = Window(left, top, math.ceil(w.width)+7, math.ceil(w.height)+7)
        if left < 0 or top < 0 or left+window.width > src.width or top+window.height > src.height:
            raise ValueError('Background outside pinned source tile')
        raw = src.read(1, window=window)
        transform = src.window_transform(window)
        if not np.isfinite(raw).all() or (src.nodata is not None and np.any(raw == src.nodata)):
            raise ValueError('Missing DSM samples')
        profile = src.profile.copy()
        profile.update(width=raw.shape[1], height=raw.shape[0], transform=transform, compress='deflate')
        with rasterio.open(crop, 'w', **profile) as dst:
            dst.write(raw, 1)
            dst.update_tags(**src.tags())
    # The same conservative filter as the campus removes isolated canopy/roof spikes.
    padded = np.pad(raw, 1, mode='edge')
    lower = np.minimum.reduce([padded[r:r+raw.shape[0], c:c+raw.shape[1]] for r in range(3) for c in range(3)])
    padded = np.pad(lower, 1, mode='edge')
    filtered = sum(padded[r:r+raw.shape[0], c:c+raw.shape[1]].astype(float) for r in range(3) for c in range(3))/9
    terrain = read(ROOT/f'apps/game/assets/campuses/{campus}/data/terrain.json')
    offset = terrain['absolute_y_offset_egm2008_m']
    def sample(x, z, values=filtered):
        lon, lat = osm.geographic(campus, x, z)
        col, row = (~transform)*(lon, lat)
        col, row = col-.5, row-.5
        c, r = math.floor(col), math.floor(row)
        if not (0 <= c < raw.shape[1]-1 and 0 <= r < raw.shape[0]-1):
            raise ValueError('Background sample outside archived coverage')
        u, v = col-c, row-r
        return float((values[r,c]*(1-u)+values[r,c+1]*u)*(1-v)+(values[r+1,c]*(1-u)+values[r+1,c+1]*u)*v)-offset
    xmin, zmin = terrain['origin_xz']
    xmax = xmin+(terrain['width']-1)*terrain['step_m']
    zmax = zmin+(terrain['height']-1)*terrain['step_m']
    def height(x, z):
        cx, cz = np.clip(x, xmin, xmax), np.clip(z, zmin, zmax)
        distance = math.hypot(x-cx, z-cz)
        if distance == 0:
            return terrain_sample(terrain,x,z)
        blend = min(1, distance/config['blend_distance_m'])
        blend = blend*blend*(3-2*blend)
        original = sample(x,z)
        if campus=='eda' and x < -550:
            ridge = np.clip((original+offset-130)/100,0,1)
            original += (sample(x,z,raw)-original)*ridge*0.65
        return original+(terrain_sample(terrain,cx,cz)-sample(cx,cz))*(1-blend)
    west,south,east,north = spec['bbox_wgs84']
    x0,z0 = osm.local(campus,west,north)
    x1,z1 = osm.local(campus,east,south)
    step = spec['step_m']
    # Include every existing campus edge vertex: no T-junction or overlapping ground.
    xs = sorted(set(np.arange(x0,x1,step).tolist()+[x1]+[xmin+c*terrain['step_m'] for c in range(terrain['width'])]))
    zs = sorted(set(np.arange(z0,z1,step).tolist()+[z1]+[zmin+r*terrain['step_m'] for r in range(terrain['height'])]))
    extended = ROOT/f'references/{campus}/mapping/osm-surroundings-source.json'
    world = osm_data(campus, include_outside=True, source_path=extended if extended.exists() else None)
    woods = [Polygon(p['outer'],p['holes']) for a in world['areas']
             if a['category']=='vegetation-area' and a['tags'].get('natural',a['tags'].get('landuse')) in ('wood','forest','scrub')
             for p in a['polygons']]
    woodland = prep(unary_union(woods))
    vertices, masks, transition = [], [], []
    for z in zs:
        for x in xs:
            y = height(x,z)
            # KFQ00 back panorama supports wooded mountain slopes; extent is an
            # approximate visual zone, not a surveyed forest or individual trees.
            mountain = campus=='eda' and x < -550 and y+offset > 130
            forest = mountain or woodland.contains(Point(x,z))
            vertices.extend([round(x,4),round(y,4),round(z,4)])
            masks.append(1 if forest else 0)
            blend=min(1, math.hypot(x-np.clip(x,xmin,xmax),z-np.clip(z,zmin,zmax))/config['blend_distance_m'])
            transition.append(round(blend*blend*(3-2*blend),4))
    indices=[]
    for r in range(len(zs)-1):
        for c in range(len(xs)-1):
            if xmin <= (xs[c]+xs[c+1])/2 <= xmax and zmin <= (zs[r]+zs[r+1])/2 <= zmax:
                continue
            a=r*len(xs)+c;b=a+1;d=a+len(xs);e=d+1
            indices.extend([a,b,d,b,e,d])
    review_path=ROOT/f'references/{campus}/buildings/surroundings-review.json'
    overrides={osm_id:group for group in read(review_path)['groups'] for osm_id in group['osm_ids']} if review_path.exists() else {}
    buildings=[]; rejected=[]
    boundary=Polygon(world['boundary'])
    extent=box(x0,z0,x1,z1)
    for record in world['areas']:
        if record['category']!='building' or record['scope']!='outside':continue
        for part,p in enumerate(record['polygons']):
            poly=Polygon(p['outer'],p['holes'])
            if not extent.contains(poly) or poly.intersects(boundary):continue
            points=p['outer']
            ground=min(height(x,z) for x,z in points)
            t=record['tags'];basis='generic-unmeasured-9m'
            h=9.0
            review=overrides.get(record['osm_id'])
            try:
                if review:
                    h=review['height_m'];basis='photo-group-estimate:'+review['id']
                elif 'height' in t:
                    h=float(t['height'].removesuffix('m').strip());basis='osm-height'
                elif 'building:levels' in t:
                    h=float(t['building:levels'])*3.0;basis='osm-levels-times-estimated-3m'
                else:
                    # Roof/ground contrast from old DSM is only a coarse estimate.
                    roof=max(sample(x,z,raw) for x,z in points+[list(poly.representative_point().coords)[0]])
                    if roof-ground > 12:
                        h=roof-ground;basis='dsm-roof-ground-estimate'
                if not math.isfinite(h) or not 2 <= h <= 250:raise ValueError()
            except ValueError:
                rejected.append({'osm_id':record['osm_id'],'reason':'invalid-height'});continue
            roofs=[]
            for tri in constrained_delaunay_triangles(poly).geoms:
                roofs.append([list(v) for v in list(tri.exterior.coords)[:-1]])
            buildings.append({'osm_id':record['osm_id'],'version':record['version'],'part':part,
                              'outer':points,'holes':p['holes'],'roof':roofs,'base_y':round(ground,3),
                              'height':round(h,3),'height_source':basis,
                              'color':review['color'] if review else t.get('building:colour','#d0c9bc' if campus=='eda' else '#d0d0c9')})
    trees=[]
    if campus=='eda':
        rng=random.Random(18092026)
        occupied=prep(unary_union([Polygon(b['outer'],b['holes']).buffer(20) for b in buildings]))
        for z in np.arange(z0+100,z1-100,80):
            for x in np.arange(x0+100,-650,80):
                tx,tz=x+rng.uniform(-28,28),z+rng.uniform(-28,28)
                y=height(tx,tz)
                slope=math.hypot((height(tx+15,tz)-height(tx-15,tz))/30,(height(tx,tz+15)-height(tx,tz-15))/30)
                if y+offset<130 or slope>.6 or occupied.contains(Point(tx,tz)) or rng.random()>.65:continue
                trees.append([round(tx,3),round(y,3),round(tz,3),round(rng.uniform(5,9),2),round(rng.uniform(0,math.tau),3)])
    output={'campus_id':campus,'vertices':vertices,'forest':masks,'transition':transition,'indices':indices,'buildings':buildings,'canopy':trees,
            'campus_rect':[xmin,zmin,xmax,zmax],'source':'references/'+campus+'/terrain/surroundings-source.json'}
    write(ROOT/f'apps/game/assets/campuses/{campus}/data/surroundings.json',output)
    source={'campus_id':campus,'dsm_url':dem['url'],'dsm_tile_sha256':dem['sha256'],
            'crop_sha256':hashlib.sha256(crop.read_bytes()).hexdigest(),'bbox_wgs84':spec['bbox_wgs84'],
            'retrieved':'2026-09-18','horizontal_crs':'EPSG:4326','vertical_datum':'EGM2008',
            'absolute_y_offset_egm2008_m':offset,'source_pixel_window':[left,top,int(window.width),int(window.height)],
            'osm_source':world['source'],'osm_rejected':world['rejected'],'rejected':rejected,
            'triangles':len(indices)//3,'building_parts':len(buildings),'canopy_clusters':len(trees),'mesh_step_m':step,
            'limits':'DSM 2011–2015为主，非裸地测量；3x3最小值及均值过滤，大黑山高处渐进保留65%原始起伏，校界外150m衔接。照片分组高度、OSM层高换算、9m占位及DSM屋顶差均非实测。大黑山林地与稀疏树冠为KFQ00照片支持的近似视觉覆盖，无逐树定位。',
            'generator':'apps/game/tools/prepare_surroundings.py'}
    write(reference/'surroundings-source.json',source)
    print(campus,source['triangles'],'terrain triangles',len(buildings),'buildings',flush=True)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--campus',choices=['all','lingshui','eda','panjin'],default='all')
    parser.add_argument('--cache',type=Path,default=ROOT/'.local/surroundings')
    args=parser.parse_args()
    for campus in (['lingshui','eda','panjin'] if args.campus=='all' else [args.campus]):build(campus,args.cache)
