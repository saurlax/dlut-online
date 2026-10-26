"""Native 16x16 material tiles selected with normalized eight-neighbor masks."""

import random

from PIL import Image, ImageColor, ImageDraw

SIZE = 16
NEIGHBORS = ((0, -1), (1, 0), (0, 1), (-1, 0),
             (1, -1), (1, 1), (-1, 1), (-1, -1))
PALETTE = {
    "grass": ("#93bb60", "#80aa54", "#acce77"),
    "water": ("#448f99", "#3c828e", "#66adb0"),
    "red-walk": ("#c7785e", "#b66a56", "#d88e6c"),
}


def normalize_mask(mask):
    """A diagonal participates only when its two cardinal neighbors connect."""
    for diagonal, first, second in ((4, 0, 1), (5, 1, 2), (6, 2, 3), (7, 3, 0)):
        if not (mask & (1 << first) and mask & (1 << second)):
            mask &= ~(1 << diagonal)
    return mask


MASKS = sorted({normalize_mask(value) for value in range(256)})


def variant_at(x, y):
    """Stable world-grid variation, independent of crop or generation order."""
    value = ((x * 374761393) ^ (y * 668265263)) & 0xFFFFFFFF
    value = ((value ^ (value >> 13)) * 1274126177) & 0xFFFFFFFF
    return (value ^ (value >> 16)) % 4


def neighbor_mask(material_at, x, y, material):
    mask = sum(1 << bit for bit, (dx, dy) in enumerate(NEIGHBORS)
               if material_at(x + dx, y + dy) == material)
    return normalize_mask(mask)


def base_tile(material, variant):
    base, dark, light = PALETTE[material]
    image = Image.new("RGB", (SIZE, SIZE), base)
    d = ImageDraw.Draw(image)
    rng = random.Random(variant + 127)
    if material == "grass":
        if variant:
            for _ in range(variant):
                x, y = rng.randrange(2, 13), rng.randrange(3, 14)
                d.line((x, y, x, y - 2), fill=dark)
                d.point((x + 1, y - 1), fill=light)
    elif material == "water":
        if variant:
            x, y = [(2, 5), (7, 11), (4, 8)][variant - 1]
            d.line((x, y, x + 4, y), fill=light)
            d.line((x + 1, y + 1, x + 5, y + 1), fill=dark)
    else:
        for _ in range(2):
            x, y = rng.randrange(2, 13), rng.randrange(2, 14)
            d.line((x, y, x + 1, y), fill=light if variant % 2 else dark)
    return image


def shape_mask(mask):
    """The material's silhouette inside one cell; neighboring cells stay intact."""
    image = Image.new("1", (SIZE, SIZE))
    cardinal = [bool(mask & (1 << bit)) for bit in range(4)]
    corners = [(15, 0, 0, 1, 4), (15, 15, 1, 2, 5),
               (0, 15, 2, 3, 6), (0, 0, 3, 0, 7)]
    for y in range(SIZE):
        for x in range(SIZE):
            if ((not cardinal[0] and y < 3) or (not cardinal[1] and x > 12)
                    or (not cardinal[2] and y > 12) or (not cardinal[3] and x < 3)):
                continue
            clipped = False
            for cx, cy, first, second, diagonal in corners:
                dx, dy = abs(x - cx), abs(y - cy)
                if not cardinal[first] and not cardinal[second]:
                    # Rounded outer corner, including isolated cells and endcaps.
                    if dx < 6 and dy < 6 and (dx - 6) ** 2 + (dy - 6) ** 2 > 12:
                        clipped = True
                elif cardinal[first] and cardinal[second] and not mask & (1 << diagonal):
                    # Concave corner where a different material occupies the diagonal.
                    if dx + dy < 3:
                        clipped = True
            if not clipped:
                image.putpixel((x, y), 1)
    return image


def transition_tile(material, mask, variant):
    """Transparent land-side pixels reveal the independent grass underlay."""
    image = base_tile(material, variant).convert("RGBA")
    shape = shape_mask(mask)
    pixels = image.load()
    bank = ImageColor.getrgb("#a9b579")
    curb = ImageColor.getrgb("#e8d9b5")
    for y in range(SIZE):
        for x in range(SIZE):
            if not shape.getpixel((x, y)):
                pixels[x, y] = (0, 0, 0, 0)
                continue
            # Only sample within this tile: connected edges are not outlines.
            distance = min((abs(xx-x)+abs(yy-y)
                            for yy in range(max(0,y-2), min(SIZE,y+3))
                            for xx in range(max(0,x-2), min(SIZE,x+3))
                            if not shape.getpixel((xx,yy))), default=3)
            if distance == 1:
                pixels[x, y] = (*(curb if material == "red-walk" else bank), 255)
            elif distance == 2 and material == "water":
                pixels[x, y] = (52, 108, 112, 255)
    return image


def generate_tiles(directory):
    directory.mkdir(parents=True, exist_ok=True)
    tiles = {}
    for variant in range(4):
        name = f"grass-{variant}"
        tiles[name] = base_tile("grass", variant).convert("RGBA")
    for material in ("water", "red-walk"):
        for mask in MASKS:
            for variant in range(4):
                name = f"{material}-{mask:02x}-{variant}"
                tiles[name] = transition_tile(material, mask, variant)
    for name, image in tiles.items():
        image.save(directory / f"{name}.png", optimize=True)
    return tiles
