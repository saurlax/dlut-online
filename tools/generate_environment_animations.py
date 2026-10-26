"""Build native water frames and the shared environment animation manifest."""
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
CAMPUS = ROOT / 'apps/web/public/campuses/eda'
BASE = (68, 143, 153, 255)
LIGHT = (102, 173, 176, 255)
DARK = (60, 130, 142, 255)
WATER = {BASE, LIGHT, DARK}

def water_frames(source, seed):
    mask = { (x,y) for y in range(16) for x in range(16) if source.getpixel((x,y)) in WATER }
    # Keep a still margin around the shore: only the water's interior ripples.
    interior = {(x,y) for x,y in mask if all(((x+dx)%16,(y+dy)%16) in mask for dx,dy in ((0,0),(1,0),(-1,0),(0,1),(0,-1)))}
    frames = []
    for frame in range(16):
        image = source.copy()
        for position in mask:
            image.putpixel(position, BASE)
        for x,y in ((2+(seed%3),4+(seed%2)),(10-(seed%3),11-(seed%2))):
            for dx,dy,color in ((0,0,LIGHT),(1,0,LIGHT),(2,-1,LIGHT),(3,-1,LIGHT),(1,1,DARK),(2,1,DARK)):
                point = ((x+dx+frame)%16,(y+dy)%16)
                if point in interior:
                    image.putpixel(point,color)
        frames.append(image)
    return frames

def main():
    campus = json.loads((CAMPUS/'map.json').read_text(encoding='utf-8'))
    names = [name for name in campus['textures'] if name.startswith('water-')]
    sheet = Image.new('RGBA',(16*16,16*((len(names)*16+15)//16)))
    mapping = {}
    for index,name in enumerate(names):
        source = Image.open(CAMPUS/'tiles'/f'{name}.png').convert('RGBA')
        frames = water_frames(source,index%4)
        mapping[name] = []
        for phase,image in enumerate(frames):
            frame = index*16+phase
            sheet.paste(image,((frame%16)*16,(frame//16)*16))
            mapping[name].append(frame)
    directory = CAMPUS/'animations'
    directory.mkdir(parents=True,exist_ok=True)
    sheet.save(directory/'water.png',optimize=True)
    manifest = {'water':{'image':'animations/water.png','frameWidth':16,'frameHeight':16,'frameDurationMs':120,'framesByTile':mapping},'trees':{'frameDurationMs':220,'offsets':[0,0,1,1,0,0,-1,-1],'fixedRootPixels':32}}
    (directory/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    print(f'Generated {len(names)} water tile sequences, 16 native 16x16 frames each.')

if __name__ == '__main__':
    main()
