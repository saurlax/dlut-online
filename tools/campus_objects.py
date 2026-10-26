"""Native pixel building images and reusable 16px planting modules."""

import math

from PIL import Image, ImageDraw


STYLES={
    "information":("#b9af94","#9c9f8e","#538088"),
    "library":("#a7b3aa","#959d95","#476a73"),
    "academic":("#aaa88f","#8f9689","#4c7278"),
    "gym":("#a9aaa0","#858e85","#537779"),
    "residence":("#c4b69b","#b1a68f","#657f7e"),
    "dining":("#c4b48e","#a6a18a","#557579"),
    "tower":("#b9c3b3","#949f97","#3b5966"),
    "unverified":("#a4a68f","#909580","#62746d"),
}


def build_building(building,offset,directory):
    points=[(x-offset[0],y-offset[1]) for x,y in building["points"]]
    bx=math.floor(min(x for x,y in points))-1
    by=math.floor(min(y for x,y in points))-1
    width=math.ceil(max(x for x,y in points))-bx+1
    depth=math.ceil(max(y for x,y in points))-by+1
    style=building["style"]
    height=building["height"] if style!="unverified" else 0
    rise=math.ceil(height)
    image=Image.new("RGBA",(width*16,(depth+rise)*16))
    d=ImageDraw.Draw(image)
    wall,roof,glass=STYLES[style]
    ground=[(round((x-bx)*16),round((y-by+rise)*16)) for x,y in points]
    hp=round(height*16)
    area=sum(ax*cy-cx*ay for (ax,ay),(cx,cy) in zip(points,points[1:]+points[:1]))
    sign=1 if area>0 else -1
    faces=[]
    for i,(a,b) in enumerate(zip(ground,ground[1:]+ground[:1])):
        if -sign*(b[0]-a[0])>0:faces.append((max(a[1],b[1]),i,a,b))
    for _,edge,a,b in sorted(faces):
        if not hp:continue
        def pos(t,z):return (round(a[0]+(b[0]-a[0])*t),round(a[1]+(b[1]-a[1])*t-z*16))
        d.polygon([a,b,(b[0],b[1]-hp),(a[0],a[1]-hp)],fill=wall)
        d.line([a,b],fill="#758075",width=3)
        length=math.hypot(b[0]-a[0],b[1]-a[1])/16
        storeys=building["storeys"]
        storey=height/storeys
        columns=max(1,round(length/(3.2 if style=="library" else 4.5)))
        for floor in range(storeys):
            z1=(floor+.22)*storey;z2=(floor+.76)*storey
            d.line([pos(0,floor*storey),pos(1,floor*storey)],fill="#ded7bb",width=2)
            for column in range(columns):
                t=(column+.5)/columns
                if style=="tower" and not any(f["edge"]==edge and f["span"][0]<=t<=f["span"][1] and 8<=z1<=25 for f in building.get("southVisibleFaces",[])):
                    continue
                half=(.40 if style=="library" else .27)/columns
                quad=[pos(t-half,z1),pos(t+half,z1),pos(t+half,z2),pos(t-half,z2)]
                d.polygon(quad,fill=glass)
                d.line([pos(t-half,z2),pos(t+half,z2)],fill="#a8c0b4",width=2)
                d.line([pos(t,z1),pos(t,z2)],fill="#c9cbb3",width=2)
                d.line([pos(t-half,z1),pos(t+half,z1)],fill="#e2dbc1",width=2)
                d.line([pos(t-half,(z1+z2)/2),pos(t+half,(z1+z2)/2)],fill="#354f55",width=1)
    roof_points=[(x,y-hp) for x,y in ground]
    d.polygon(roof_points,fill=roof)
    d.line(roof_points+[roof_points[0]],fill="#d1cdb2",width=3)
    for a,b in zip(roof_points,roof_points[1:]+roof_points[:1]):
        if -sign*(b[0]-a[0])>0:d.line([a,b],fill="#64746c",width=2)
    directory.mkdir(parents=True,exist_ok=True)
    from campus_materials import detail_building
    image=detail_building(image,style,(wall,roof,glass))
    filename=building["id"]+".png"
    image.save(directory/filename,optimize=True)
    return {"id":building["id"],"name":building["name"],"osmId":building["osm_id"],
            "image":"buildings/"+filename,"x":bx,"y":by-rise,"width":width,"height":depth+rise,
            "depth":by+depth,"footprint":points,"style":style,
            "heightMeters":building["height"],"heightBasis":building["height_source"]}


def plant_sprite(kind,variant):
    from pathlib import Path
    directory=Path(__file__).resolve().parents[1]/"apps/web/public/campuses/eda/vegetation"
    return Image.open(directory/f"{kind}-{variant}.png").convert("RGBA")


def plant_prototypes(catalog,encode):
    result={}
    for kind in ("broadleaf","willow","cypress","shrub"):
        for variant in range(2):
            image=plant_sprite(kind,variant)
            values=[]
            for y in range(0,image.height,16):
                for x in range(0,image.width,16):
                    piece=image.crop((x,y,x+16,y+16))
                    values.append(catalog(f"plant-{kind}-{variant}-{x}-{y}",lambda:piece) if piece.getbbox() else -1)
            result[f"{kind}-{variant}"]={"width":image.width//16,"height":image.height//16,"runs":encode(values)}
    return result
