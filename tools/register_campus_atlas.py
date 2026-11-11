"""Snap campus illustrations to a pixel grid, cut out campus grounds and register them."""
from io import BytesIO
from pathlib import Path
import cmath
import hashlib
import json
import math
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
PUBLIC = ROOT / 'apps/web/public/world/atlas'
SOURCE = ROOT / 'references/city'
SIZE = 256 * 2 ** 17

def read(path):
    return json.loads(path.read_text(encoding='utf-8'))

def pixel(point):
    lon, lat = point
    return complex((lon + 180) / 360 * SIZE,
                   (1 - math.asinh(math.tan(math.radians(lat))) / math.pi) / 2 * SIZE)

def geographic(point):
    return [point.real / SIZE * 360 - 180,
            math.degrees(math.atan(math.sinh(math.pi * (1 - 2 * point.imag / SIZE))))]

def main():
    from pixelfixer.api import process

    registration = read(SOURCE / 'campus-registration.json')
    art = {c['campus']: c for c in read(SOURCE / 'campus-art.json')['campuses']}
    landmarks = {f['key']: f for f in read(PUBLIC / 'manifest.json')['landmarks']}
    (PUBLIC / 'illustrations').mkdir(exist_ok=True)
    for campus in registration['campuses']:
        ident = campus['id']
        source = ROOT / next(o['file'] for o in art[ident]['outputs'] if o['kind'] == registration['artworkKind'])
        width, height = Image.open(source).size
        controls = campus['controls']
        p = [complex(*c['imagePixel']) for c in controls]
        q = [pixel(landmarks[c['key']]['point']) for c in controls]
        pm, qm = sum(p) / len(p), sum(q) / len(q)
        a = sum((x - pm).conjugate() * (y - qm) for x, y in zip(p, q)) / sum(abs(x - pm) ** 2 for x in p)
        b = qm - a * pm
        meters = 40075016.68557849 / SIZE * math.cos(math.radians(geographic(qm)[1]))
        for control, x, y in zip(controls, p, q):
            control['worldPoint'] = landmarks[control['key']]['point']
            control['residualMeters'] = round(abs(a * x + b - y) * meters, 2)
        processed = process(source.read_bytes(), force_step=registration['pixelStep'], k_colors=48)
        snapped = Image.open(BytesIO(processed['png'])).convert('RGB')
        snapped_width, snapped_height = snapped.size
        mask = Image.new('L', snapped.size)
        draw = ImageDraw.Draw(mask)
        for ring in campus['clipPolygons']:
            draw.polygon([(x * snapped_width / width, y * snapped_height / height) for x, y in ring], fill=255)
        left, top, right, bottom = mask.getbbox()
        bounds = (left, top, right, bottom)
        visible = snapped.crop(bounds)
        alpha = mask.crop(bounds)
        # Derive the palette from visible campus pixels so surrounding roads and
        # the source background do not consume colors.
        colors = bytes(channel for rgb, opacity in zip(visible.getdata(), alpha.tobytes())
                       if opacity for channel in rgb)
        palette = Image.frombytes('RGB', (len(colors) // 3, 1), colors).quantize(colors=48)
        indexed = visible.quantize(palette=palette, dither=Image.Dither.NONE).convert('RGB')
        cropped = Image.new('RGBA', visible.size)
        cropped.paste(indexed, mask=alpha)
        dest = PUBLIC / 'illustrations' / f'{ident}.png'
        cropped.save(dest, optimize=True)
        campus['image'] = f'/world/atlas/illustrations/{ident}.png'
        campus['imageSha256'] = hashlib.sha256(dest.read_bytes()).hexdigest()
        campus['nativeSize'] = list(cropped.size)
        campus['sourceSize'] = [width, height]
        campus['cropPixels'] = list(bounds)
        campus['coordinates'] = [
            geographic(a * complex(x * width / snapped_width, y * height / snapped_height) + b)
            for x, y in [(left, top), (right, top), (right, bottom), (left, bottom)]
        ]
        campus['clipCoordinates'] = [
            [geographic(a * complex(x, y) + b) for x, y in ring]
            for ring in campus['clipPolygons']
        ]
        view = [point for ring in campus['clipCoordinates'] for point in ring]
        campus['viewBounds'] = [[min(p[i] for p in view) for i in range(2)], [max(p[i] for p in view) for i in range(2)]]
        campus['fit'] = {'method': 'least-squares 2D similarity in Web Mercator; one scale, rotation and translation; no local warp',
                         'rotationDegrees': round(math.degrees(cmath.phase(a)), 4),
                         'rmsMeters': round(math.sqrt(sum(c['residualMeters'] ** 2 for c in controls) / len(controls)), 2),
                         'maxMeters': max(c['residualMeters'] for c in controls)}
        print(ident, campus['fit'])
    (SOURCE / 'campus-registration.json').write_text(json.dumps(registration, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

if __name__ == '__main__':
    main()
