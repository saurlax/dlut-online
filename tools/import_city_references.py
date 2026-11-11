"""Archive regional Natural Earth and Mapzen terrain data for the atlas."""
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import hashlib
from io import BytesIO
import json
import math
import struct
from pathlib import Path
from urllib.request import Request, urlopen
from zipfile import ZipFile

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "references/city"
CACHE = ROOT / ".local/city-map/downloads"
BBOX = [120.7, 38.4, 124.2, 41.15]
ZOOM = 9


def pixel(lon, lat):
    size = 256 * 2 ** ZOOM
    return ((lon + 180) / 360 * size,
            (1 - math.asinh(math.tan(math.radians(lat))) / math.pi) / 2 * size)


def download(url, name):
    path = CACHE / name
    if not path.exists():
        request = Request(url, headers={"User-Agent":"DLUTOnline-OfflineAtlas/1.0"})
        with urlopen(request, timeout=90) as response:
            path.write_bytes(response.read())
    data = path.read_bytes()
    return data, {"url":url,"sha256":hashlib.sha256(data).hexdigest()}


def clipped(ring):
    points = [p[:2] for p in ring]
    for axis, bound, positive in [(0,BBOX[0],True),(0,BBOX[2],False),(1,BBOX[1],True),(1,BBOX[3],False)]:
        output = []
        if not points:
            return []
        previous = points[-1]
        for point in points:
            before = previous[axis] >= bound if positive else previous[axis] <= bound
            after = point[axis] >= bound if positive else point[axis] <= bound
            if before != after:
                t = (bound-previous[axis])/(point[axis]-previous[axis])
                output.append([previous[i]+(point[i]-previous[i])*t for i in range(2)])
            if after:
                output.append(point)
            previous = point
        points = output
    return [[round(x,6),round(y,6)] for x,y in points] if len(points)>2 else []


def main():
    OUTPUT.mkdir(parents=True,exist_ok=True)
    CACHE.mkdir(parents=True,exist_ok=True)
    sources=[]
    attribution,attribution_source=download("https://raw.githubusercontent.com/tilezen/joerd/master/docs/attribution.md","terrain-attribution.md")
    (OUTPUT/"terrain-attribution.md").write_bytes(attribution)
    sources.append({**attribution_source,"provider":"Mapzen terrain attribution"})
    layers={}
    names={"land":"ne_10m_land", "urban":"ne_10m_urban_areas", "places":"ne_10m_populated_places", "rivers":"ne_10m_rivers_lake_centerlines"}
    def natural(item):
        key,name=item
        data,source=download(f"https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/{name}.geojson",name+".geojson")
        return key,json.loads(data),source
    with ThreadPoolExecutor(max_workers=3) as pool:
        for key,geo,source in pool.map(natural,names.items()):
            sources.append({**source,"provider":"Natural Earth","license":"Public Domain"})
            if key=="places":
                layers[key]=[{"point":f["geometry"]["coordinates"],"name":f["properties"].get("NAME_ZH") or f["properties"]["NAME"],"population":f["properties"]["POP_MAX"]}
                    for f in geo["features"] if BBOX[0]<=f["geometry"]["coordinates"][0]<=BBOX[2] and BBOX[1]<=f["geometry"]["coordinates"][1]<=BBOX[3]]
            elif key=="rivers":
                layers[key]=[]
                for f in geo["features"]:
                    geometry=f["geometry"]
                    for line in geometry["coordinates"] if geometry["type"]=="MultiLineString" else [geometry["coordinates"]]:
                        xs,ys=zip(*[p[:2] for p in line])
                        if max(xs)>=BBOX[0] and min(xs)<=BBOX[2] and max(ys)>=BBOX[1] and min(ys)<=BBOX[3]:
                            layers[key].append({"kind":"river","points":[p[:2] for p in line]})
            else:
                polygons=[]
                for feature in geo["features"]:
                    geometry=feature["geometry"]
                    for polygon in geometry["coordinates"] if geometry["type"]=="MultiPolygon" else [geometry["coordinates"]]:
                        outer=clipped(polygon[0])
                        if outer:
                            polygons.append([outer]+[p for ring in polygon[1:] if (p:=clipped(ring))])
                layers[key]=polygons
            print(f"Archived {key}: {len(layers[key])} regional features",flush=True)
    data,source=download("https://naturalearth.s3.amazonaws.com/10m_cultural/ne_10m_roads.zip","ne_10m_roads.zip")
    sources.append({**source,"provider":"Natural Earth","license":"Public Domain"})
    archive=ZipFile(BytesIO(data));shape=archive.read("ne_10m_roads.shp")
    position=100;roads=[]
    while position<len(shape):
        ident,length=struct.unpack_from(">ii",shape,position);position+=8
        record=shape[position:position+length*2];position+=length*2
        kind=struct.unpack_from("<i",record)[0]
        if kind==0:continue
        if kind!=3:raise ValueError("Expected Natural Earth PolyLine roads")
        xmin,ymin,xmax,ymax=struct.unpack_from("<4d",record,4)
        if xmax<BBOX[0] or xmin>BBOX[2] or ymax<BBOX[1] or ymin>BBOX[3]:continue
        parts,count=struct.unpack_from("<2i",record,36)
        indices=list(struct.unpack_from(f"<{parts}i",record,44))+[count]
        points=list(struct.iter_unpack("<2d",record[44+parts*4:44+parts*4+count*16]))
        for a,b in zip(indices,indices[1:]):roads.append({"id":ident,"kind":"road","points":[[round(x,6),round(y,6)] for x,y in points[a:b]]})
    layers["roads"]=roads+layers.pop("rivers")
    left,top=pixel(BBOX[0],BBOX[3]);right,bottom=pixel(BBOX[2],BBOX[1])
    tx0,ty0=math.floor(left/256),math.floor(top/256)
    tx1,ty1=math.floor(right/256),math.floor(bottom/256)
    mosaic=Image.new("RGB",((tx1-tx0+1)*256,(ty1-ty0+1)*256))
    def terrain(pair):
        x,y=pair
        data,source=download(f"https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{ZOOM}/{x}/{y}.png",f"terrain-{ZOOM}-{x}-{y}.png")
        return x,y,Image.open(BytesIO(data)).convert("RGB"),source
    with ThreadPoolExecutor(max_workers=6) as pool:
        for x,y,tile,source in pool.map(terrain,[(x,y) for y in range(ty0,ty1+1) for x in range(tx0,tx1+1)]):
            mosaic.paste(tile,((x-tx0)*256,(y-ty0)*256))
            sources.append({**source,"provider":"Mapzen terrain tiles","license":"Source attribution at https://github.com/tilezen/joerd/blob/master/docs/attribution.md"})
    mosaic.save(OUTPUT/"terrain.png",optimize=True)
    layers["terrain"]={"zoom":ZOOM,"tileOrigin":[tx0,ty0],"image":"terrain.png","encoding":"Terrarium: R*256+G+B/256-32768 meters"}
    (OUTPUT/"geography.json").write_text(json.dumps({"bbox":BBOX,**layers},ensure_ascii=False,separators=(",",":"))+"\n",encoding="utf-8")
    (OUTPUT/"sources.json").write_text(json.dumps({"retrieved":datetime.now(timezone.utc).isoformat(),"scope":"Dalian municipality with northward coverage to Panjin campus; regional atlas, not a surveyed street map","sources":sources},ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(f"Archived {len(layers['roads'])} Natural Earth road/river segments and terrain mosaic",flush=True)


if __name__=="__main__":
    main()
