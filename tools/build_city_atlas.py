"""Paint a georeferenced pixel atlas from archived regional and campus data."""
from array import array
import argparse
import hashlib
import gzip
import json
import math
import re
import subprocess
import shutil
import xml.etree.ElementTree as ET
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, ImageFilter
from import_city_references import pixel, ZOOM

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/"references/city"
PUBLIC=ROOT/"apps/web/public"
OUTPUT=PUBLIC/"world/atlas"
CAMPUS_NAMES={"lingshui":"凌水主校区","eda":"开发区校区","panjin":"盘锦校区"}
LANDMARKS={"lingshui":["77386-0","77357-0","77447-0","77445-0","78473-0"],
           "eda":["77914","77917","77921","77923","77927","2304982"],
           "panjin":["77963-0","77986-0","77955-0"]}


def read(path):return json.loads(path.read_text(encoding="utf-8"))


def geographic(x,y):
    size=256*2**ZOOM
    return [x/size*360-180,math.degrees(math.atan(math.sinh(math.pi*(1-2*y/size))))]


def corners(bounds):
    west,south,east,north=bounds
    return [[west,north],[east,north],[east,south],[west,south]]


def campus_point(campus,x,y):
    lon,lat=campus["origin"]
    return [lon+(x+campus["offset"][0])/(111320*math.cos(math.radians(lat))),
            lat-(y+campus["offset"][1])/111320]


def point_in_ring(point, ring):
    x, y = point
    inside = False
    previous = ring[-1]
    for current in ring:
        x1, y1 = previous
        x2, y2 = current
        if (y1 > y) != (y2 > y) and x < x1 + (y - y1) * (x2 - x1) / (y2 - y1):
            inside = not inside
        previous = current
    return inside


def campus_labels(ident,campus,clip_coordinates):
    """Use named OSM features from the archived campus and its immediate surroundings."""
    root=ET.fromstring(gzip.decompress((ROOT/f"references/{ident}/osm.osm.gz").read_bytes()))
    nodes={e.attrib["id"]:[float(e.attrib["lon"]),float(e.attrib["lat"])] for e in root.findall("node")}
    nw=campus_point(campus,-800,-800);se=campus_point(campus,campus["width"]+800,campus["height"]+800)
    def inside(p):return nw[0]<=p[0]<=se[0] and se[1]<=p[1]<=nw[1]
    candidates=[]
    for element in root:
        tags={t.attrib["k"]:t.attrib["v"] for t in element.findall("tag")}
        name=tags.get("name:zh") or tags.get("name")
        if not name or tags.get("building") or tags.get("amenity")=="university":continue
        if element.tag=="node":points=[nodes[element.attrib["id"]]]
        elif element.tag=="way":
            refs=[n.attrib["ref"] for n in element.findall("nd")]
            if any(ref not in nodes for ref in refs):continue
            points=[nodes[ref] for ref in refs]
        else:continue
        if not points:continue
        if tags.get("highway") and tags["highway"]!="bus_stop":
            # Label the longest contiguous part of the road within the artwork.
            parts=[[]]
            for p in points:
                if any(point_in_ring(p, ring) for ring in clip_coordinates):parts[-1].append(p)
                elif parts[-1]:parts.append([])
            points=max(parts,key=len)
            if len(points)<2:continue
            lengths=[math.hypot((b[0]-a[0])*math.cos(math.radians(a[1])),b[1]-a[1]) for a,b in zip(points,points[1:])]
            length=sum(lengths);distance=length/2;point=points[0]
            for a,b,segment in zip(points,points[1:],lengths):
                if segment and distance<=segment:
                    point=[a[i]+(b[i]-a[i])*distance/segment for i in range(2)];break
                distance-=segment
            if not any(point_in_ring(point, ring) for ring in clip_coordinates):continue
            kind="road";minzoom=13
        else:
            point=[sum(p[i] for p in points)/len(points) for i in range(2)]
            if not inside(point):continue
            if tags.get("place") or tags.get("landuse") or tags.get("natural") or tags.get("leisure") or tags.get("waterway"):
                kind="area";minzoom=12 if tags.get("place") in ("town","suburb","neighbourhood") else 13
            elif tags.get("barrier")=="gate" or tags.get("tourism")=="artwork" or tags.get("historic")=="memorial":
                kind="place";minzoom=16
            else:continue
            length=0
        name=re.sub(r"^大连理工大学[（(](?:开发区|盘锦|凌水)校区[）)]", "",name)
        candidates.append({"key":f"osm-{element.tag}-{element.attrib['id']}","name":name,"point":point,"kind":kind,"minZoom":minzoom,"length":length})
    labels=[]
    for label in sorted(candidates,key=lambda item:-item["length"]):
        if any(other["name"]==label["name"] and math.hypot((other["point"][0]-label["point"][0])*math.cos(math.radians(label["point"][1])),other["point"][1]-label["point"][1])<.004 for other in labels):continue
        del label["length"]
        labels.append(label)
    return labels


def campus_ground(campus,path):
    colors=["#b5ba89","#9db875","#628e61","#67a9b2","#96998a","#d4c197","#be8068","#d5caab","#cfceb0","#b77966","#82a79a","#a6bb79"]
    values=bytearray()
    for count,material in zip(campus["materialRuns"][::2],campus["materialRuns"][1::2]):values.extend(bytes([material])*count)
    image=Image.frombytes("P",(campus["width"],campus["height"]),bytes(values))
    palette=[]
    for color in colors:palette.extend(bytes.fromhex(color[1:]))
    image.putpalette(palette+[0]*(768-len(palette)))
    image=image.convert("RGB").resize((campus["width"]//2,campus["height"]//2),Image.Resampling.NEAREST)
    visible=Image.frombytes("L",(campus["width"],campus["height"]),bytes(255 if value else 0 for value in values)).resize(image.size,Image.Resampling.NEAREST)
    visible_draw=ImageDraw.Draw(visible)
    ground=image.copy();draw=ImageDraw.Draw(image)
    for b in sorted(campus["buildings"],key=lambda b:b["depth"]):
        if "collisionPolygons" in b:continue
        p=[(round(x/2),round(y/2)) for x,y in b["footprint"]]
        visible_draw.polygon(p,fill=255)
        if b["style"]=="unverified":draw.polygon(p,fill="#b9b899",outline="#939b80")
        for ring in b.get("holes",[]):
            mask=Image.new("1",image.size);ImageDraw.Draw(mask).polygon([(round(x/2),round(y/2)) for x,y in ring],fill=1);image.paste(ground,(0,0),mask)
    image=image.quantize(colors=48,dither=Image.Dither.NONE).convert("RGBA");image.putalpha(visible);image.save(path,optimize=True)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--render-landmarks",action="store_true",help="Render model references into .local, preserving published imagegen artwork")
    parser.add_argument("--blender",default="C:/Program Files/Blender Foundation/Blender 5.1/blender.exe")
    args=parser.parse_args()
    OUTPUT.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(ROOT/"apps/web/node_modules/maplibre-gl/LICENSE.txt",OUTPUT/"MapLibre-LICENSE.txt")
    (OUTPUT/"NOTICE.txt").write_text("Regional land, urban areas, roads, rivers and city labels: Natural Earth, Public Domain.\nhttps://www.naturalearthdata.com/about/terms-of-use/\n\nCampus geography: © OpenStreetMap contributors, ODbL 1.0.\nhttps://www.openstreetmap.org/copyright\n\nCampus illustrations: generated with imagegen; approximate local-preview registration.\nPosition and architecture reference: http://map.dlut.edu.cn/\nOffline composition reference: DLUT Four Seasons, umasou / Moka Design Studio.\nhttps://www.zcool.com.cn/work/ZMjgyNjc4Mjg%3D.html\nOriginal reference images are not distributed.\n\nMapzen terrain source attribution:\n\n"+(SOURCE/"terrain-attribution.md").read_text(encoding="utf-8"),encoding="utf-8")
    geo=read(SOURCE/"geography.json")
    west,south,east,north=geo["bbox"]
    left,top=map(math.floor,pixel(west,north));right,bottom=map(math.ceil,pixel(east,south))
    width,height=right-left,bottom-top
    land=Image.new("L",(width,height));urban=Image.new("L",land.size)
    def points(ring):return [(round(pixel(x,y)[0]-left),round(pixel(x,y)[1]-top)) for x,y in ring]
    for polygons,mask in [(geo["land"],land),(geo["urban"],urban)]:
        draw=ImageDraw.Draw(mask)
        for polygon in polygons:
            draw.polygon(points(polygon[0]),fill=255)
            for hole in polygon[1:]:draw.polygon(points(hole),fill=0)
    # Registered OSM campus land takes precedence over the generalized coastline.
    for ident in CAMPUS_NAMES:
        campus=read(PUBLIC/f"campuses/{ident}/map.json")
        ImageDraw.Draw(land).polygon(points([campus_point(campus,x,y) for x,y in campus["boundary"]]),fill=255)
    origin=geo["terrain"]["tileOrigin"]
    terrain=Image.open(SOURCE/"terrain.png").crop((left-origin[0]*256,top-origin[1]*256,right-origin[0]*256,bottom-origin[1]*256))
    elevations=array('f', (r*256+g+b/256-32768 for r,g,b in terrain.getdata()))
    native=Image.new("RGB",land.size)
    mask=land.load();cities=urban.load();canvas=native.load()
    terrain_colors=[(165,186,119),(148,176,109),(126,158,96),(111,146,91),(134,147,99),(157,153,112)]
    for y in range(height):
        for x in range(width):
            noise=((x//2*73856093)^(y//2*19349663))%7
            if not mask[x,y]:
                color=(91,158,176) if (x+y*3)%59<3 and y%7==0 else (80,148,168)
            elif cities[x,y]:color=(205,195,155) if noise<4 else (192,184,145)
            else:
                h=max(0,elevations[y*width+x]);level=min(5,int(h/140))
                color=tuple(max(0,min(255,c+(noise-3)*2)) for c in terrain_colors[level])
            canvas[x,y]=color
    coast=ImageChops.subtract(land.filter(ImageFilter.MaxFilter(5)),land)
    native.paste((117,183,185),mask=coast)
    draw=ImageDraw.Draw(native)
    for road in geo["roads"]:
        p=points(road["points"])
        if road["kind"]=="river":draw.line(p,fill="#70b1b5",width=2)
        else:
            draw.line(p,fill="#a79d7e",width=3 if road["kind"]=="motorway" else 2)
            draw.line(p,fill="#e4d1a5",width=1)
    native.quantize(colors=48,dither=Image.Dither.NONE).save(OUTPUT/"region.png",optimize=True)
    sw,ne=geographic(left,bottom),geographic(right,top)
    result={"bounds":[sw,ne],"image":"/world/atlas/region.png","coordinates":corners([sw[0],sw[1],ne[0],ne[1]]),
            "nativeSize":[width,height],"nativeZoom":ZOOM,"campuses":[],"places":geo["places"],"landmarks":[],"labels":[]}
    jobs=[]
    illustrations={item['id']:item for item in read(SOURCE/'campus-registration.json')['campuses']}
    for ident,name in CAMPUS_NAMES.items():
        campus=read(PUBLIC/f"campuses/{ident}/map.json")
        campus_ground(campus,OUTPUT/f"{ident}.png")
        nw=campus_point(campus,0,0);se=campus_point(campus,campus["width"],campus["height"])
        entry={"id":ident,"name":name,"bounds":[[nw[0],se[1]],[se[0],nw[1]]],"coordinates":[nw,[se[0],nw[1]],se,[nw[0],se[1]]],
               "center":campus_point(campus,campus["width"]/2,campus["height"]/2),"image":f"/world/atlas/{ident}.png"}
        illustration=illustrations[ident]
        entry['image']=illustration['image']
        entry['coordinates']=illustration['coordinates']
        entry['bounds']=illustration['viewBounds']
        result["campuses"].append(entry)
        result["labels"].extend(campus_labels(ident,campus,illustration['clipCoordinates']))
        models={b["id"]:b for b in read(PUBLIC/f"campuses/{ident}/models/manifest.json")["buildings"]}
        for building in campus["buildings"]:
            ring=building["footprint"]
            xs,ys=zip(*ring)
            key=ident+"-"+building["id"]
            primary=building["id"] in LANDMARKS[ident]
            record={"key":key,"id":building["id"],"campus":ident,"name":building["name"],"primary":primary,
                    "point":campus_point(campus,(min(xs)+max(xs))/2,(min(ys)+max(ys))/2),
                    "polygon":[campus_point(campus,x,y) for x,y in ring],
                    "holes":[[campus_point(campus,x,y) for x,y in hole] for hole in building.get("holes",[])]}
            if building["id"] in models:
                jobs.append({"id":key,"file":str(PUBLIC/f"campuses/{ident}"/models[building["id"]]["file"]),"elevation":90 if "collisionPolygons" in building else 26,"output":str(ROOT/f".local/city-map/model-sprites/{key}.png")})
            result["landmarks"].append(record)
            # Remove catalog prefixes and long parenthetical descriptions only from the map label.
            label=re.sub(r"^[A-Z]\d?区\d+-", "",building["name"]).split("（")[0].split("(")[0].split("/")[0]
            if not any(l["name"]==label and math.hypot(l["point"][0]-record["point"][0],l["point"][1]-record["point"][1])<.001 for l in result["labels"]):
                result["labels"].append({"key":key,"name":label,"point":record["point"],"kind":"building","minZoom":13 if primary else 14})
    (OUTPUT/"manifest.json").write_text(json.dumps(result,ensure_ascii=False,separators=(",",":"))+"\n",encoding="utf-8")
    temporary=ROOT/".local/city-map";temporary.mkdir(parents=True,exist_ok=True)
    (temporary/"landmark-jobs.json").write_text(json.dumps(jobs),encoding="utf-8")
    if args.render_landmarks:
        subprocess.run([args.blender,"-b","-t","4","--python",str(ROOT/"tools/render_atlas_landmarks.py"),"--",str(temporary/"landmark-jobs.json")],check=True)
        records=[]
        for job in jobs:
            path=Path(job["output"])
            icon=Image.open(path).convert("RGBA")
            alpha=icon.getchannel("A").point(lambda value:255 if value>=128 else 0)
            icon=icon.convert("RGB").quantize(colors=48,dither=Image.Dither.NONE).convert("RGBA")
            icon.putalpha(alpha);icon.save(path,optimize=True)
            records.append({"id":job["id"],"model":str(Path(job["file"]).relative_to(ROOT)).replace('\\','/'),
                "nativeSize":list(icon.size),
                "elevation":job["elevation"],
                "modelSha256":hashlib.sha256(Path(job["file"]).read_bytes()).hexdigest(),
                "image":str(path.relative_to(ROOT)).replace('\\','/'),"sha256":hashlib.sha256(path.read_bytes()).hexdigest()})
        (SOURCE/"landmarks.json").write_text(json.dumps({"palette":48,"alpha":[0,255],
            "projection":"Buildings: south-facing orthographic view at 26 degrees; open sports facilities: north-up plan view. Frame fitted using Camera.view_frame(scene) to preserve all model bounds; native 1.5 pixels/m capped at 256 pixels.", "objects":records},ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(f"Built {width}x{height} regional atlas, {len(result['landmarks'])} selectable landmarks and 3 registered campus illustrations",flush=True)


if __name__=="__main__":main()
