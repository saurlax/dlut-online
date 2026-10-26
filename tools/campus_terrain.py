"""Rasterize registered campus geography at cell centers in the shared frame."""

import gzip
import math
import xml.etree.ElementTree as ET

from PIL import Image

from generate_lakeside_grid import inside_polygon

MATERIALS=["outside","grass","woodland","water","asphalt","path","red-walk","paving","bridge","track","court","field"]
IDS={name:i for i,name in enumerate(MATERIALS)}
RED_WALKS={1076344124,1076344125,1076344132,1076344133}


def load_osm(path,origin):
    root=ET.fromstring(gzip.decompress(path.read_bytes()))
    scale=111320*math.cos(math.radians(origin[1]))
    nodes={n.attrib["id"]:((float(n.attrib["lon"])-origin[0])*scale,
                          (origin[1]-float(n.attrib["lat"]))*111320) for n in root.findall("node")}
    ways={w.attrib["id"]:w for w in root.findall("way")}
    def points(way):return [nodes[n.attrib["ref"]] for n in way.findall("nd")]
    return root,ways,points


def rasterize(root,ways,points,geometry,bounds):
    left,top,right,bottom=bounds
    # Two context cells are required by the diagonal contour and shore passes.
    width,height=right-left+4,bottom-top+4
    raster=Image.new("L",(width,height),IDS["outside"])
    cells=raster.load()
    sources=[];lakes=[]
    def polygon(vertices,material):
        ax=max(left-2,math.floor(min(x for x,y in vertices)))
        ay=max(top-2,math.floor(min(y for x,y in vertices)))
        bx=min(right+2,math.ceil(max(x for x,y in vertices)))
        by=min(bottom+2,math.ceil(max(y for x,y in vertices)))
        for y in range(ay,by):
            for x in range(ax,bx):
                if inside_polygon(x+.5,y+.5,vertices):cells[x-left+2,y-top+2]=IDS[material]
    polygon(points(ways["215560705"]),"grass")
    for way in ways.values():
        tags={t.attrib["k"]:t.attrib["v"] for t in way.findall("tag")}
        material=None
        if tags.get("natural") in ("wood","scrub"):material="woodland"
        elif tags.get("landuse")=="grass":material="grass"
        elif tags.get("natural")=="water":material="water"
        elif tags.get("leisure")=="pitch":material="field" if tags.get("sport") in ("soccer","baseball") else "court"
        elif tags.get("leisure")=="track":material="track"
        elif tags.get("area")=="yes" and tags.get("highway")=="pedestrian":material="paving"
        vertices=points(way)
        if material and len(vertices)>3 and vertices[0]==vertices[-1]:
            polygon(vertices,material)
            sources.append({"id":"way/"+way.attrib["id"],"version":way.attrib["version"],"material":material})
            if material=="water":lakes.append(vertices)
    # Track rings retain their field interiors. Members here are closed ways.
    for relation in root.findall("relation"):
        tags={t.attrib["k"]:t.attrib["v"] for t in relation.findall("tag")}
        if tags.get("leisure")!="track":continue
        for role,material in (("outer","track"),("inner","field")):
            for member in relation.findall("member"):
                if member.attrib.get("role")==role and member.attrib["type"]=="way":
                    polygon(points(ways[member.attrib["ref"]]),material)
        sources.append({"id":"relation/"+relation.attrib["id"],"version":relation.attrib["version"],"material":"track-ring"})
    for road in geometry["roads"]:
        material="asphalt" if road["highway"] in ("secondary","tertiary","residential","service","unclassified") else "path"
        if road["osm_way_id"] in RED_WALKS:material="red-walk"
        if road.get("bridge"):material="bridge"
        radius=road["width"]/2
        for (ax,ay),(bx,by) in zip(road["points"],road["points"][1:]):
            dx,dy=bx-ax,by-ay;length=dx*dx+dy*dy
            for y in range(max(top-2,math.floor(min(ay,by)-radius)),min(bottom+2,math.ceil(max(ay,by)+radius))):
                for x in range(max(left-2,math.floor(min(ax,bx)-radius)),min(right+2,math.ceil(max(ax,bx)+radius))):
                    t=max(0,min(1,((x+.5-ax)*dx+(y+.5-ay)*dy)/length)) if length else 0
                    if (x+.5-ax-t*dx)**2+(y+.5-ay-t*dy)**2<=radius*radius:
                        cells[x-left+2,y-top+2]=IDS[material]
        sources.append({"id":"way/"+str(road["osm_way_id"]),"version":road["osm_version"],
                        "material":material,"widthMeters":road["width"],"widthBasis":road["width_basis"]})
    return raster,sources,lakes
