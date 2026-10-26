"""Import registered EDA geometry and reference metadata from a local archive."""

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "references/eda"


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def save(name, value):
    (OUT/name).write_text(json.dumps(value,ensure_ascii=False,separators=(",",":"))+"\n",encoding="utf-8")


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive",type=Path)
    root=parser.parse_args().archive.resolve()
    data=root/"apps/game/assets/campuses/eda/data"
    campus=read(data/"campus.json")
    buildings=[]
    appearances={
        "77914":("information",4), "77917":("library",4),
        "77921":("academic",5), "77923":("gym",3),
        "77925":("academic",5), "77927":("academic",5), "77928":("academic",2),
        **{i:("residence",6) for i in ("77931","77933","77935","77941")},
        "77937":("residence",5), "77938":("residence",5),
        "77943":("dining",3), "2304982":("tower",15),
    }
    photos={}
    for feature in campus["features"]:
        if feature["kind"]!="building" or feature["footprint_source"]!="osm":continue
        building={k:feature[k] for k in ("id","name","points","height","height_source","osm_id","osm_version","geometry_status")}
        building["style"],building["storeys"]=appearances.get(feature["id"],("unverified",0))
        if "building_parts" in feature:
            building["parts"]=feature["building_parts"]
            building["compoundFootprint"]=building["points"]
            building["points"]=next(p["points"] for p in feature["building_parts"] if p["role"]=="tower")
        buildings.append(building)
        photo_record=read(root/f"references/eda/buildings/photos/{feature['id']}.json")
        photos[feature["id"]]={"source":photo_record["source"],"retrieved":photo_record["retrieved"],
                               "images":[{"url":"http://map.dlut.edu.cn"+p["imageURL"],"id":p["id"]}
                                         for p in photo_record["result"]],
                               "use":"pixel facade palette and storey rhythm; dimensions remain source estimates"}
    seventh=read(root/"references/eda/buildings/seventh-residence/profile.json")
    photos["2304982"]["images"]=seventh["photos"]
    tower=next(b for b in buildings if b["id"]=="2304982")
    tower["southVisibleFaces"]=seventh["osm_registration"]["south_visible_faces"]
    tower["visibility"]="north-up view from south; DUT logo face is hidden, do not rotate or copy its graphics"
    roads=read(data/"osm_roads.json")
    save("geometry.json",{"origin":[121.811878,39.085291],"buildings":buildings,"roads":roads["roads"]})
    vegetation=read(data/"vegetation.json")
    allowed=set(vegetation["registered_zone_ids"])|{z["id"] for z in vegetation["linear_zones"]}
    points=[{"kind":i["kind"],"x":i["position"][0],"y":i["position"][2],
             "height":i["height"],"zone":i["zone"],"variant":i["variant"]}
            for i in vegetation["instances"] if i["kind"]!="grass" and i["zone"] in allowed]
    save("planting.json",{"precision":vegetation["precision"],"registeredZones":vegetation["registered_zone_ids"],
                          "linearZones":vegetation["linear_zones"],"instances":points,
                          "source":"registered EDA vegetation archive; x east/y south in shared WGS84 frame",
                          "sources":["https://news.dlut.edu.cn/info/1292/147345.htm","https://news.dlut.edu.cn/info/1022/143385.htm"],
                          "withheldZones":vegetation["withheld_zone_ids"]})
    save("building-photos.json",{"reviewed":"2026-10-26","buildings":photos,
                                "limits":"Photographs establish visible colors and storey rhythm; pixel exteriors are simplified, no interiors or unverified facade details."})
    print(f"Imported {len(buildings)} building profiles, {len(roads['roads'])} roads, {len(points)} registered planting estimates")


if __name__=="__main__":main()
