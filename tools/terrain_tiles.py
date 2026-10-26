"""Native 16x16 material tiles with diagonal cell-center contours."""

import random
from functools import lru_cache

from PIL import Image, ImageColor, ImageDraw

SIZE = 16
NEIGHBORS = ((0, -1), (1, 0), (0, 1), (-1, 0),
             (1, -1), (1, 1), (-1, 1), (-1, -1))
SURFACE_MATERIALS = {"asphalt", "path", "red-walk", "track", "court"}
PALETTE = {
    "grass": ("#93bb60", "#80aa54", "#acce77"),
    "water": ("#448f99", "#3c828e", "#66adb0"),
    "red-walk": ("#c7785e", "#b66a56", "#d88e6c"),
    "outside": ("#778e5a", "#6e8553", "#829b62"),
    "woodland": ("#72934d", "#608044", "#8bab59"),
    "asphalt": ("#777b72", "#6d726b", "#85887c"),
    "path": ("#c4b48b", "#b4a47f", "#d2c49c"),
    "paving": ("#b8b59b", "#a5a58e", "#cacaad"),
    "bridge": ("#b9bea8", "#9da88f", "#d3d4bb"),
    "track": ("#b46c55", "#a56452", "#c67c61"),
    "court": ("#719c8f", "#678f82", "#83ac97"),
    "field": ("#8aaa5a", "#7e9c51", "#9cba68"),
}


def variant_at(x, y):
    """Stable world-grid variation, independent of crop or generation order."""
    value = ((x * 374761393) ^ (y * 668265263)) & 0xFFFFFFFF
    value = ((value ^ (value >> 13)) * 1274126177) & 0xFFFFFFFF
    return (value ^ (value >> 16)) % 4


def neighbor_mask(material_at, x, y, material):
    mask = sum(1 << bit for bit, (dx, dy) in enumerate(NEIGHBORS)
               if material_at(x + dx, y + dy) == material)
    return mask | (int(material_at(x, y) == material) << 8)


def base_tile(material, variant):
    if material == "grass":
        from campus_materials import load_material
        return load_material("grass", variant)
    base, dark, light = PALETTE[material]
    image = Image.new("RGB", (SIZE, SIZE), base)
    d = ImageDraw.Draw(image)
    rng = random.Random(variant + 127)
    if material in ("grass", "woodland", "outside", "field"):
        if variant:
            for _ in range(variant):
                x, y = rng.randrange(2, 13), rng.randrange(3, 14)
                d.line((x, y, x, y - 2), fill=dark)
                d.point((x + 1, y - 1), fill=light)
    elif material == "water":
        if variant:
            x, y = [(2, 5), (7, 11), (4, 8)][variant - 1]
            d.line([(x,y+1),(x+2,y+1),(x+3,y),(x+5,y)], fill=light)
            d.line([(x+1,y+2),(x+3,y+2),(x+4,y+1),(x+6,y+1)], fill=dark)
    elif material in ("paving", "bridge"):
        d.line((0,7,15,7),fill=dark)
        d.line((7,0,7,6),fill=dark)
        d.line((15,8,15,15),fill=dark)
        d.line((0,8,14,8),fill=light)
    elif variant:
        # Surface grain uses square clusters, not a repeated one-pixel hatch.
        positions = [(x, y) for y in range(2, 14, 2) for x in range(2, 14, 2)]
        for x, y in rng.sample(positions, 2 if variant == 2 else 1):
            d.rectangle((x, y, x + 1, y + 1), fill=light if variant % 2 else dark)
    return image


@lru_cache(maxsize=1024)
def shape_mask(mask, padding=0):
    """Interpolate cell-center occupancy into a hard-pixel diagonal contour."""
    values = {position: bool(mask & (1 << bit))
              for bit, position in enumerate((*NEIGHBORS, (0, 0)))}
    image = Image.new("1", (SIZE+padding*2, SIZE+padding*2))
    for y in range(-padding,SIZE+padding):
        sy = -1 if y < 8 else 0
        ty = 2*y + 17 if y < 8 else 2*y - 15
        for x in range(-padding,SIZE+padding):
            sx = -1 if x < 8 else 0
            tx = 2*x + 17 if x < 8 else 2*x - 15
            # Integer bilinear weights avoid filtering or fractional-color pixels.
            value = (values[sx,sy]*(32-tx)*(32-ty)
                     + values[sx+1,sy]*tx*(32-ty)
                     + values[sx,sy+1]*(32-tx)*ty
                     + values[sx+1,sy+1]*tx*ty)
            if value >= 512:
                image.putpixel((x+padding,y+padding),1)
    return image


def transition_tile(material, mask, variant):
    """Transparent land-side pixels reveal the independent grass underlay."""
    image = base_tile(material, variant).convert("RGBA")
    shape = shape_mask(mask,2)
    pixels = image.load()
    bank = ImageColor.getrgb("#a9b579")
    rims={"woodland":"#7c9c51","field":"#749d50","asphalt":"#a1a28b",
          "track":"#e4d1ae","court":"#dedfc5","paving":"#d0cbb1"}
    curb = ImageColor.getrgb(rims.get(material,"#e8d9b5"))
    for y in range(SIZE):
        for x in range(SIZE):
            if not shape.getpixel((x+2, y+2)):
                pixels[x, y] = (0, 0, 0, 0)
                continue
            # Continue the same contour across the seam when drawing the rim.
            distance = min((abs(xx-x)+abs(yy-y)
                            for yy in range(y-2,y+3)
                            for xx in range(x-2,x+3)
                            if not shape.getpixel((xx+2,yy+2))), default=3)
            if distance == 1:
                pixels[x, y] = (*(curb if material == "red-walk" else bank), 255)
            elif distance == 2 and material == "water":
                pixels[x, y] = (52, 108, 112, 255)
    return image


def generate_tiles(directory, masks_by_material):
    directory.mkdir(parents=True, exist_ok=True)
    tiles = {}
    for variant in range(4):
        name = f"grass-{variant}"
        tiles[name] = base_tile("grass", variant).convert("RGBA")
    for material, masks in masks_by_material.items():
        for mask in sorted(masks):
            for variant in range(4):
                name = f"{material}-{mask:03x}-{variant}"
                tiles[name] = transition_tile(material, mask, variant)
    for name, image in tiles.items():
        image.save(directory / f"{name}.png", optimize=True)
    return tiles
