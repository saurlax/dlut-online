"""Generate the north-up EDA campus from native tiles and building images."""

import hashlib
import json
import math
from array import array
from pathlib import Path

from PIL import ImageFilter

from campus_objects import build_building, plant_prototypes
from campus_terrain import IDS, MATERIALS, load_osm, rasterize
from generate_lakeside_grid import inside_polygon
from shore_tiles import assemble_shores
from terrain_tiles import SURFACE_MATERIALS, base_tile, neighbor_mask, shape_mask, transition_tile, variant_at

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/"references/eda"
OUTPUT=ROOT/"apps/web/public/campuses/eda"
CHUNK=64


def read(path):return json.loads(path.read_text(encoding="utf-8"))


def save(path,value):
    path.write_text(json.dumps(value,ensure_ascii=False,separators=(",",":"))+"\n",encoding="utf-8")


def encode(values):
    result=[]
    for value in values:
        if result and result[-1]==value:result[-2]+=1
        else:result.extend((1,value))
    return result


class Catalog:
    def __init__(self):
        self.names=[];self.ids={};self.images=[];self.hashes={}
        self.directory=OUTPUT/"tiles"
        self.directory.mkdir(parents=True,exist_ok=True)

    def __call__(self,name,paint):
        if name in self.ids:return self.ids[name]
        image=paint().convert("RGBA")
        fingerprint=hashlib.sha256(image.tobytes()).digest()
        if fingerprint in self.hashes:
            self.ids[name]=self.hashes[fingerprint]
        else:
            self.ids[name]=len(self.names)
            self.hashes[fingerprint]=len(self.names)
            self.names.append(name);self.images.append(image)
            image.save(self.directory/f"{name}.png",optimize=True)
        return self.ids[name]


def main():
    geometry=read(SOURCE/"geometry.json")
    planting=read(SOURCE/"planting.json")
    origin=geometry["origin"]
    root,ways,points=load_osm(SOURCE/"osm.osm.gz",origin)
    boundary=points(ways["215560705"])
    all_points=boundary+[p for b in geometry["buildings"] for p in b["points"]]
    left=math.floor((min(x for x,y in all_points)-48)/CHUNK)*CHUNK
    top=math.floor((min(y for x,y in all_points)-80)/CHUNK)*CHUNK
    right=math.ceil((max(x for x,y in all_points)+48)/CHUNK)*CHUNK
    bottom=math.ceil((max(y for x,y in all_points)+48)/CHUNK)*CHUNK
    width,height=right-left,bottom-top
    print(f"Rasterizing {width}x{height} geographic cells",flush=True)
    raster,sources,lakes=rasterize(root,ways,points,geometry,(left,top,right,bottom))
    pixels=raster.load()
    def material_at(x,y):return pixels[x-left+2,y-top+2]
    catalog=Catalog()
    ground=array('i');material_cells=array('B')
    for y in range(height):
        for x in range(width):
            code=pixels[x+2,y+2]
            material_cells.append(code)
            name="outside" if code==0 else "grass"
            variant=variant_at(x+left,y+top) if (x*17+y*31)%7==0 else 0
            ground.append(catalog(f"{name}-{variant}",lambda:base_tile(name,variant)))
    layers=[ground]
    for code,name in enumerate(MATERIALS[2:],2):
        binary=raster.point([255 if i==code else 0 for i in range(256)])
        nearby=binary.filter(ImageFilter.MaxFilter(3)).crop((2,2,width+2,height+2)).tobytes()
        layer=array('i',[-1])*(width*height)
        for i,value in enumerate(nearby):
            if not value:continue
            x,y=left+i%width,top+i//width
            mask=neighbor_mask(material_at,x,y,code)
            if not shape_mask(mask).getbbox():continue
            textured=mask==511 or (name in SURFACE_MATERIALS and mask & 256)
            variant=variant_at(x,y) if textured else 0
            tile=catalog(f"{name}-{mask:03x}-{variant}",lambda:transition_tile(name,mask,variant))
            layer[i]=tile
        layers.append(layer)
        print(f"Connected {name}",flush=True)
    shore=array('i',[-1])*(width*height)
    for lake in lakes:
        bounds=(max(left,math.floor(min(x for x,y in lake))-1),max(top,math.floor(min(y for x,y in lake))-1),
                min(right,math.ceil(max(x for x,y in lake))+1),min(bottom,math.ceil(max(y for x,y in lake))+1))
        if bounds[0]>=bounds[2] or bounds[1]>=bounds[3]:continue
        tiles,cells=assemble_shores(material_at,bounds,catalog.directory,IDS["water"])
        for i,name in enumerate(cells):
            if name:
                x=bounds[0]+i%(bounds[2]-bounds[0])-left
                y=bounds[1]+i//(bounds[2]-bounds[0])-top
                shore[y*width+x]=catalog(name,lambda:tiles[name])
    layers.append(shore)
    overview_ids={code:catalog(f"{name}-overview",lambda:base_tile(name,0)) for code,name in enumerate(MATERIALS)}
    chunks=[]
    for cy in range(0,height,CHUNK):
        for cx in range(0,width,CHUNK):
            region_layers=[]
            for layer in layers:
                values=[layer[(cy+y)*width+cx+x] for y in range(CHUNK) for x in range(CHUNK)]
                runs=encode(values)
                if runs!=[CHUNK*CHUNK,-1]:region_layers.append(runs)
            coarse=[overview_ids[material_cells[(cy+y+2)*width+cx+x+2]]
                    for y in range(0,CHUNK,4) for x in range(0,CHUNK,4)]
            chunks.append({"x":cx,"y":cy,"layers":region_layers,"overview":encode(coarse)})
    print("Building independent exteriors",flush=True)
    buildings=[]
    for source in geometry["buildings"]:
        buildings.append(build_building(source,(left,top),OUTPUT/"buildings"))
        for part in source.get("parts",[]):
            if part["role"]=="podium":
                podium={**source,"id":source["id"]+"-podium","points":part["points"],"height":8.2,
                        "height_source":"photo proportion estimate","style":"academic","storeys":2,
                        "osm_id":part["osm_id"]}
                buildings.append(build_building(podium,(left,top),OUTPUT/"buildings"))
    registered={b["osm_id"].split('/')[1] for b in geometry["buildings"]}|{"1381473266"}
    unresolved=[]
    for way in ways.values():
        tags={t.attrib['k']:t.attrib['v'] for t in way.findall('tag')}
        if "building" not in tags or way.attrib['id'] in registered:continue
        p=points(way)
        if inside_polygon(sum(x for x,y in p)/len(p),sum(y for x,y in p)/len(p),boundary):
            unresolved.append({"id":"way/"+way.attrib['id'],"name":tags.get("name",""),
                               "reason":"unregistered compound boundary overlaps verified building footprints; withheld pending photo registration"})
    prototypes=plant_prototypes(catalog,encode)
    plants=[];skipped=0
    for i,source in enumerate(planting["instances"]):
        x,y=source["x"]-left,source["y"]-top
        if not (0<=x<width and 0<=y<height):continue
        if material_cells[math.floor(y)*width+math.floor(x)] not in (IDS["grass"],IDS["woodland"]):
            skipped+=1;continue
        kind="shrub" if source["kind"] in ("shrub","juniper","hedge") else "willow" if source["kind"]=="willow" else "cypress" if source["kind"]=="cypress" else "broadleaf"
        key=f"{kind}-{int(source['variant'])%2}"
        sprite=prototypes[key]
        plants.append({"id":i,"prototype":key,"x":round(x-sprite['width']/2,3),
                       "y":round(y-sprite['height']+.2,3),"depth":round(y,3),"zone":source["zone"]})
    manifest={"campus":"eda","tileSize":16,"metersPerTile":1,"chunkSize":CHUNK,
              "orientation":"north-up","origin":origin,"offset":[left,top],"width":width,"height":height,
              "boundary":[[x-left,y-top] for x,y in boundary],"textures":catalog.names,
              "focus":[-62-left,194-top],"chunks":chunks,"buildings":buildings,
              "plantPrototypes":prototypes,"plants":plants,
              "materials":MATERIALS,"materialRuns":encode(material_cells),
              "sources":sources,"attribution":"© OpenStreetMap contributors, ODbL 1.0"}
    manifest["unresolvedFeatures"]=unresolved
    save(OUTPUT/"map.json",manifest)
    save(SOURCE/"generated.json",{"generator":"tools/generate_eda_map.py","width":width,"height":height,
         "buildingObjects":len(buildings),"plantObjects":len(plants),"plantingSkippedOnNonGreen":skipped,
         "chunkCount":len(chunks),"textureCount":len(catalog.names),"nativePixels":16,
         "sourceSha256":hashlib.sha256((SOURCE/"osm.osm.gz").read_bytes()).hexdigest(),
         "limits":["building exteriors simplified from photographs; no interiors",
                   "registered planting positions and heights are estimates, not surveyed trees",
                   "unverified buildings retain footprint-only roofs"]})
    keep=set(catalog.names)
    for file in catalog.directory.glob("*.png"):
        if file.stem not in keep:file.unlink()
    from build_tile_atlas import build as build_tile_atlas
    build_tile_atlas()
    print(f"Generated {len(buildings)} building objects, {len(plants)} plants, {len(catalog.names)} native tiles",flush=True)


if __name__=="__main__":main()
