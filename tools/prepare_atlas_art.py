"""Standardize imagegen building artwork into native atlas sprites."""
import argparse
import hashlib
import json
import math
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
DIRECTORY=ROOT/"apps/web/public/world/atlas/landmarks"
RECORD=ROOT/"references/city/building-art.json"


def prepare(job):
    source=Path(job["source"])
    metadata=json.loads(source.with_suffix(".json").read_text(encoding="utf-8-sig"))
    image=Image.open(source).convert("RGBA")
    image.putalpha(image.getchannel("A").point(lambda value:255 if value>=128 else 0))
    image=image.crop(image.getbbox())
    width,height=metadata["nativeSize"]
    scale=min((width-4)/image.width,(height-4)/image.height)
    image=image.resize((max(1,math.floor(image.width*scale)),max(1,math.floor(image.height*scale))),Image.Resampling.NEAREST)
    alpha=image.getchannel("A")
    occupied={(x,y) for y in range(image.height) for x in range(image.width) if alpha.getpixel((x,y))}
    while occupied:
        component={occupied.pop()};pending=list(component)
        while pending:
            x,y=pending.pop()
            for dx,dy in ((-1,-1),(-1,0),(-1,1),(0,-1),(0,1),(1,-1),(1,0),(1,1)):
                point=x+dx,y+dy
                if point in occupied:occupied.remove(point);component.add(point);pending.append(point)
        if len(component)<3:
            for point in component:alpha.putpixel(point,0)
    image=image.convert("RGB").quantize(colors=48,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE).convert("RGBA")
    image.putalpha(alpha)
    native=Image.new("RGBA",(width,height))
    native.paste(image,((width-image.width)//2,height-2-image.height))
    bounds=native.getbbox()
    sprite_height=min(height,max(16,math.ceil((height-bounds[1]+2)/8)*8))
    native=native.crop((0,height-sprite_height,width,height))
    output=DIRECTORY/f"{job['id']}.png"
    native.save(output,optimize=True)
    return {**metadata,"budgetSize":[width,height],"nativeSize":list(native.size),"sourceSha256":hashlib.sha256(source.read_bytes()).hexdigest(),
        "image":str(output.relative_to(ROOT)).replace("\\","/"),"sha256":hashlib.sha256(output.read_bytes()).hexdigest()}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--asset",help="Compile a single generated asset during a batch")
    parser.add_argument("--available",action="store_true",help="Compile the finished portion of an ongoing generation batch")
    parser.add_argument("--source-dir",type=Path,default=ROOT/".local/city-map/imagegen")
    args=parser.parse_args()
    models=json.loads((ROOT/"references/city/landmarks.json").read_text(encoding="utf-8"))["objects"]
    jobs=[{"id":model["id"],"source":str(args.source_dir/f"{model['id']}.png")} for model in models]
    if args.asset:jobs=[next(job for job in jobs if job["id"]==args.asset)]
    elif args.available:jobs=[job for job in jobs if Path(job["source"]).exists() and Path(job["source"]).with_suffix(".json").exists()]
    previous=json.loads(RECORD.read_text(encoding="utf-8"))["objects"] if RECORD.exists() else []
    compiled={item["id"]:item for item in previous}
    for job in jobs:compiled[job["id"]]=prepare(job)
    record={"date":"2026-11-08","generator":"built-in image_gen","palette":48,"alpha":[0,255],
        "processing":"Threshold generated alpha at 128, trim, nearest-neighbor fit with two-pixel margins, remove isolated components smaller than three pixels, median-cut to 48 colors without dithering, trim unused headroom to an eight-pixel canvas grid with at least two-pixel margins, bottom-center ground anchor.",
        "scope":"Stylized artwork based on registered building model references; no new geographic or architectural survey.",
        "objects":sorted(compiled.values(),key=lambda item:item["id"])}
    RECORD.write_text(json.dumps(record,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(f"Prepared {len(jobs)} imagegen building sprites; {len(compiled)} artwork records")


if __name__=="__main__":main()
