"""Prepare imagegen vegetation sprites and refresh their native 16px map modules."""
import argparse
import json
import math
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
CAMPUS = ROOT/'apps/web/public/campuses/eda'
SIZES = {'broadleaf': (96,144), 'willow': (96,144), 'cypress': (48,112), 'shrub': (32,32)}

def clean_alpha(image):
    alpha = image.getchannel('A')
    remaining = {(x,y) for y in range(image.height) for x in range(image.width) if alpha.getpixel((x,y))}
    groups = []
    while remaining:
        group = {remaining.pop()}
        pending = list(group)
        while pending:
            x,y = pending.pop()
            for dy in (-1,0,1):
                for dx in (-1,0,1):
                    point = (x+dx,y+dy)
                    if point in remaining:
                        remaining.remove(point); group.add(point); pending.append(point)
        groups.append(group)
    largest = max(groups,key=len)
    for group in groups:
        if group is largest: continue
        if len(group)<4 or not any(image.width*.15<=x<=image.width*.85 for x,y in group):
            for point in group: alpha.putpixel(point,0)
    image.putalpha(alpha)
    return image

def prepare(kind, path):
    source = Image.open(path).convert('RGBA')
    directory = CAMPUS/'vegetation'
    directory.mkdir(parents=True,exist_ok=True)
    for variant in range(2):
        part = source.crop((variant*source.width//2,0,(variant+1)*source.width//2,source.height))
        part.putalpha(part.getchannel('A').point(lambda a:255 if a>=128 else 0))
        bounds = part.getbbox()
        if not bounds: raise ValueError(f'Empty {kind} variant {variant}')
        part = part.crop(bounds)
        # Register the bottom contact area, rather than centering an asymmetric crown.
        bottom = part.getchannel('A').crop((0,part.height*4//5,part.width,part.height)).getbbox()
        anchor = (bottom[0]+bottom[2])/2
        width,height = SIZES[kind]
        scale = min((width/2-2)/anchor,(width/2-2)/(part.width-anchor),(height-4)/part.height)
        native = part.resize((max(1,math.floor(part.width*scale)),max(1,math.floor(part.height*scale))),Image.Resampling.NEAREST)
        native = clean_alpha(native)
        alpha = native.getchannel('A')
        native = native.convert('RGB').quantize(colors=16,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE).convert('RGBA')
        native.putalpha(alpha)
        image = Image.new('RGBA',(width,height))
        image.paste(native,(round(width/2-anchor*scale),height-2-native.height))
        image.save(directory/f'{kind}-{variant}.png',optimize=True)

def refresh():
    from generate_eda_map import Catalog, encode, save
    from campus_objects import plant_prototypes
    import hashlib
    manifest = json.loads((CAMPUS/'map.json').read_text(encoding='utf-8'))
    old = manifest['textures']
    catalog = Catalog()
    remap = {}
    for index,name in enumerate(old):
        if name.startswith('plant-'): continue
        remap[index] = len(catalog.names)
        catalog.ids[name] = len(catalog.names)
        catalog.hashes[hashlib.sha256(Image.open(CAMPUS/'tiles'/f'{name}.png').convert('RGBA').tobytes()).digest()] = len(catalog.names)
        catalog.names.append(name)
    for chunk in manifest['chunks']:
        for runs in [*chunk['layers'],chunk['overview']]:
            for i in range(1,len(runs),2):
                if runs[i]>=0: runs[i] = remap[runs[i]]
    manifest['plantPrototypes'] = plant_prototypes(catalog,encode)
    manifest['textures'] = catalog.names
    save(CAMPUS/'map.json',manifest)
    from build_tile_atlas import build as build_tile_atlas
    build_tile_atlas()
    keep = set(catalog.names)
    for path in (CAMPUS/'tiles').glob('plant-*.png'):
        if path.stem not in keep: path.unlink()
    record_path = ROOT/'references/eda/generated.json'
    record = json.loads(record_path.read_text(encoding='utf-8'))
    record['textureCount'] = len(catalog.names)
    save(record_path,record)
    print('Refreshed eight vegetation prototypes; tree positions and geographic data unchanged.')

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--source',action='append',default=[],help='kind=path to imagegen two-variant sheet')
    parser.add_argument('--refresh',action='store_true')
    args = parser.parse_args()
    for source in args.source:
        kind,path = source.split('=',1)
        prepare(kind,Path(path))
    if args.refresh: refresh()

if __name__=='__main__': main()
