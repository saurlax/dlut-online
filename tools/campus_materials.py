"""Import imagegen materials as native tiles and refresh existing campus assets."""
import argparse
import json
from pathlib import Path
from PIL import Image, ImageChops, ImageColor, ImageOps

ROOT = Path(__file__).resolve().parents[1]
MATERIALS = ROOT / 'apps/web/public/campuses/eda/materials'

def load_material(kind, variant):
    return Image.open(MATERIALS / f'{kind}-{variant % 4}.png').convert('RGB')

def repeat_material(tile, size):
    pattern = tile
    while pattern.width < size[0] or pattern.height < size[1]:
        width, height = pattern.size
        expanded = Image.new('RGB', (min(width * 2, size[0]), min(height * 2, size[1])))
        for y in (0, height):
            for x in (0, width):
                expanded.paste(pattern, (x, y))
        pattern = expanded
    return pattern.crop((0, 0, *size))

def detail_building(image, style, colors):
    variant = {'information': 0, 'library': 1, 'academic': 2, 'gym': 3, 'residence': 0, 'dining': 1, 'tower': 2, 'unverified': 3}[style]
    original = image.convert('RGB')
    for kind, color, strength in zip(('wall', 'roof', 'glass'), colors, (10, 14, 18)):
        base = ImageColor.getrgb(color)
        delta = ImageChops.difference(original, Image.new('RGB', image.size, base))
        r, g, b = delta.split()
        mask = ImageChops.lighter(ImageChops.lighter(r, g), b).point(lambda v: 255 if v == 0 else 0)
        light = ImageOps.autocontrast(ImageOps.grayscale(load_material(kind, variant)))
        tile = ImageOps.colorize(light, tuple(max(0, c - strength) for c in base), tuple(min(255, c + strength) for c in base))
        image.paste(repeat_material(tile, image.size), (0, 0), mask)
    return image

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--atlas', type=Path)
    parser.add_argument('--grass-atlas', type=Path)
    parser.add_argument('--refresh', action='store_true')
    args = parser.parse_args()
    if args.atlas:
        atlas = Image.open(args.atlas).convert('RGB').resize((64, 64), Image.Resampling.NEAREST)
        MATERIALS.mkdir(parents=True, exist_ok=True)
        for row, name in enumerate(('grass', 'roof', 'wall', 'glass')):
            for variant in range(4):
                tile = atlas.crop((variant * 16, row * 16, variant * 16 + 16, row * 16 + 16))
                tile.quantize(colors=8, method=Image.Quantize.MAXCOVERAGE, dither=Image.Dither.NONE).save(MATERIALS / f'{name}-{variant}.png')
    if args.grass_atlas:
        atlas = Image.open(args.grass_atlas).convert('RGB').resize((64, 16), Image.Resampling.NEAREST)
        palette = Image.new('P', (1, 1))
        colors = ['#93bb60', '#86af58', '#a0c66b']
        palette.putpalette([channel for color in colors for channel in ImageColor.getrgb(color)] + list(ImageColor.getrgb(colors[0])) * 253)
        for variant in range(4):
            tile = atlas.crop((variant * 16, 0, variant * 16 + 16, 16))
            tile.quantize(palette=palette, dither=Image.Dither.NONE).save(MATERIALS / f'grass-{variant}.png')
    if args.refresh:
        from campus_objects import build_building
        manifest = json.loads((ROOT / 'apps/web/public/campuses/eda/map.json').read_text(encoding='utf-8'))
        geometry = json.loads((ROOT / 'references/eda/geometry.json').read_text(encoding='utf-8'))
        directory = ROOT / 'apps/web/public/campuses/eda'
        for variant in range(4):
            load_material('grass', variant).convert('RGBA').save(directory / f'tiles/grass-{variant}.png')
        for source in geometry['buildings']:
            result = build_building(source, manifest['offset'], directory / 'buildings')
            existing = next(b for b in manifest['buildings'] if b['id'] == result['id'])
            assert (result['x'], result['y'], result['width'], result['height'], [list(p) for p in result['footprint']]) == (existing['x'], existing['y'], existing['width'], existing['height'], existing['footprint'])
            for part in source.get('parts', []):
                if part['role'] == 'podium':
                    podium = {**source, 'id':source['id']+'-podium', 'points':part['points'], 'height':8.2, 'height_source':'photo proportion estimate', 'style':'academic', 'storeys':2, 'osm_id':part['osm_id']}
                    build_building(podium, manifest['offset'], directory / 'buildings')
        from build_tile_atlas import build as build_tile_atlas
        build_tile_atlas()
        print('Refreshed four native grass tiles and seventeen building textures; geometry unchanged.')

if __name__ == '__main__':
    main()
