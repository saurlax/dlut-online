"""Draw a native-pixel Yongquan lakeside art study and export 16px modules."""

import json
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / ".local/yongquan-study"
SIZE = (480, 288)
P = {
    "grass": "#8ebc59", "grass_light": "#a9ce67", "grass_dark": "#78a64b",
    "grass_deep": "#648c43", "soil": "#a19161", "water": "#448e98",
    "water_dark": "#397b86", "water_light": "#69b2b5", "water_glint": "#96d2c5",
    "bank": "#536f45", "bank_light": "#c7c580", "bank_dark": "#3c6663",
    "path": "#c76f58", "path_light": "#da8b68", "path_dark": "#a2554b",
    "curb": "#e9ddbb", "curb_shadow": "#a0a080", "shadow": "#527d48",
    "leaf_outline": "#344f39", "leaf_dark": "#3f6c40", "leaf_mid": "#578a43",
    "leaf_light": "#79a94a", "leaf_sun": "#a4c45c", "leaf_gold": "#b9cc6a",
    "bark_dark": "#594c3b", "bark": "#826342", "bark_light": "#ad8754",
    "stone_dark": "#717b6b", "stone": "#a4ad94", "stone_light": "#d5d4b0",
    "stone_sun": "#eee2bb", "red_dark": "#7f3d35", "red": "#b3533f",
    "red_light": "#e18b57", "wood": "#995939", "wood_light": "#cb8850",
}


def poly(draw, points, color):
    draw.polygon(points, fill=P.get(color, color))


def cluster(draw, cx, cy, rx, ry, color):
    """An authored stepped silhouette, without antialiased curves."""
    points = [(-1, -.75), (-.66, -.75), (-.66, -1), (.35, -1),
              (.35, -.8), (.72, -.8), (.72, -.5), (1, -.5),
              (1, .2), (.8, .2), (.8, .65), (.35, .65),
              (.35, 1), (-.45, 1), (-.45, .75), (-.85, .75),
              (-.85, .35), (-1, .35)]
    poly(draw, [(round(cx + x * rx), round(cy + y * ry)) for x, y in points], color)


def grass_tile(seed):
    im = Image.new("RGB", (16, 16), P["grass"])
    d = ImageDraw.Draw(im)
    rng = random.Random(seed)
    for _ in range(2):
        x, y = rng.randrange(2, 13), rng.randrange(3, 14)
        d.line((x, y, x + 1, y - 2), fill=P["grass_dark"])
        d.point((x + 2, y - 1), fill=P["grass_light"])
    return im


def tree(seed, willow=False):
    im = Image.new("RGBA", (64, 80))
    d = ImageDraw.Draw(im)
    rng = random.Random(seed)
    # Ground contact is (32, 76); canopy height never changes the footprint.
    poly(d, [(28, 73), (29, 41), (23, 28), (28, 29), (33, 46),
             (39, 31), (43, 29), (36, 51), (35, 72), (41, 76),
             (33, 76), (30, 74), (24, 76)], "bark_dark")
    poly(d, [(30, 70), (31, 43), (28, 33), (32, 42), (34, 55),
             (34, 71), (36, 73), (30, 73)], "bark")
    d.line((31, 49, 31, 67), fill=P["bark_light"])
    d.rectangle((29, 65, 34, 68), fill="#d4d0af")
    d.rectangle((29, 69, 34, 73), fill="#c0c7a8")
    canopy = [(26, 3), (36, 3), (36, 5), (43, 5), (43, 9), (49, 9),
              (49, 14), (53, 14), (53, 20), (58, 20), (58, 27),
              (61, 27), (61, 39), (58, 39), (58, 48), (54, 48),
              (54, 53), (46, 53), (46, 57), (37, 57), (37, 55),
              (31, 55), (31, 59), (20, 59), (20, 55), (12, 55),
              (12, 51), (6, 51), (6, 44), (3, 44), (3, 34),
              (6, 34), (6, 25), (10, 25), (10, 19), (15, 19),
              (15, 13), (20, 13), (20, 7), (26, 7)]
    poly(d, canopy, "leaf_outline")
    poly(d, [(x + (1 if x < 31 else -1), y - 1 if y > 30 else y + 1)
             for x, y in canopy], "leaf_dark")
    # One connected crown with overlapping asymmetric leaf masses, rather than
    # outlining each lobe as a separate geometric ball.
    for x, y, rx, ry in [(29, 17, 13, 11), (17, 28, 11, 12),
                          (43, 27, 13, 12), (14, 41, 9, 10),
                          (30, 38, 14, 12), (48, 43, 10, 10)]:
        cluster(d, x, y, rx, ry, "leaf_mid")
        poly(d, [(x-rx+2, y-1), (x-rx+2, y-6), (x-6, y-6),
                 (x-6, y-ry+1), (x+2, y-ry+1), (x+2, y-ry+3),
                 (x+7, y-ry+3), (x+7, y-4), (x+4, y-4),
                 (x+4, y), (x-2, y), (x-2, y+3), (x-7, y+3)], "leaf_light")
        d.line((x-5, y-ry+2, x+1, y-ry+2), fill=P["leaf_sun"])
        d.line((x-rx+3, y-4, x-rx+5, y-4), fill=P["leaf_sun"])
        for _ in range(11):
            xx, yy = x + rng.randrange(-rx+2, rx-1), y + rng.randrange(-ry+2, ry-1)
            d.line((xx, yy, xx+1, yy), fill=P[rng.choice(["leaf_light", "leaf_mid"])])
            if rng.random() < .35:
                d.point((xx, yy+1), fill=P["leaf_dark"])
    if willow:
        for x, y, length in [(8, 28, 23), (15, 31, 28), (21, 37, 25),
                             (44, 29, 29), (51, 31, 25), (56, 35, 20)]:
            d.line((x, y, x - 1, y + length), fill=P["leaf_dark"], width=3)
            d.line((x - 1, y + 1, x - 2, y + length - 4), fill=P["leaf_light"])
            for dy in range(2, length - 2, 4):
                d.line((x - 3, y + dy, x, y + dy + 1), fill=P["leaf_sun"])
    return im


def shrub(seed, width=32):
    im = Image.new("RGBA", (width, 16))
    d = ImageDraw.Draw(im)
    rng = random.Random(seed)
    d.rectangle((2, 9, width - 2, 14), fill=P["leaf_dark"])
    for x in range(5, width - 3, 7):
        cluster(d, x, 7, 6, 5, "leaf_mid")
        cluster(d, x - 1, 5, 4, 3, "leaf_light")
        d.line((x - 2, 3, x, 3), fill=P["leaf_sun"])
    for _ in range(width // 5):
        x, y = rng.randrange(2, width - 2), rng.randrange(8, 13)
        d.line((x, y, x + 1, y), fill=P["leaf_mid"])
    return im


def rock():
    im = Image.new("RGBA", (32, 48))
    d = ImageDraw.Draw(im)
    d.rectangle((5, 40, 28, 44), fill=P["stone_dark"])
    d.rectangle((5, 39, 28, 40), fill=P["stone_light"])
    silhouette = [(9, 39), (5, 33), (7, 26), (12, 23), (10, 18),
                  (13, 12), (14, 5), (19, 1), (23, 4), (23, 13),
                  (27, 18), (25, 26), (29, 32), (25, 39)]
    poly(d, silhouette, "stone_dark")
    poly(d, [(10, 37), (8, 31), (14, 25), (13, 18), (17, 14),
             (17, 7), (19, 3), (22, 5), (21, 18), (25, 19),
             (22, 28), (24, 37)], "stone")
    poly(d, [(12, 34), (12, 27), (16, 24), (15, 18), (19, 12),
             (19, 5), (21, 4), (20, 17), (22, 22), (18, 27),
             (20, 33), (18, 36)], "stone_light")
    d.line((17, 8, 17, 13), fill=P["stone_sun"])
    d.line((11, 30, 14, 27), fill=P["stone_sun"])
    d.line((23, 23, 20, 27), fill=P["stone_dark"])
    d.rectangle((15, 29, 17, 31), fill=P["stone_dark"])
    d.point((23, 8), fill=P["stone_light"])
    return im


def bench():
    im = Image.new("RGBA", (48, 32))
    d = ImageDraw.Draw(im)
    for x in (8, 37):
        d.line((x, 12, x - 2, 29), fill="#414c45", width=2)
        d.line((x - 1, 22, x + 3, 28), fill="#414c45", width=2)
    poly(d, [(5, 18), (40, 18), (45, 23), (9, 23)], "wood")
    d.line((8, 20, 42, 20), fill=P["wood_light"])
    for y in (7, 11, 15):
        d.rectangle((5, y, 40, y + 2), fill=P["wood"])
        d.line((5, y, 40, y), fill=P["wood_light"])
    d.line((4, 8, 4, 21), fill="#414c45", width=2)
    d.line((41, 8, 43, 23), fill="#414c45", width=2)
    return im


def lamp():
    im = Image.new("RGBA", (16, 64))
    d = ImageDraw.Draw(im)
    d.rectangle((6, 6, 8, 59), fill=P["red_dark"])
    d.line((6, 6, 6, 58), fill=P["red_light"])
    d.line((7, 7, 7, 59), fill=P["red"])
    for y, side in [(10, 1), (19, -1), (28, 1)]:
        end = 7 + side * 5
        d.line((7, y + 4, end, y), fill=P["red"], width=2)
        d.rectangle((end - 2, y - 3, end + 1, y - 1), fill=P["red_dark"])
        d.line((end - 2, y - 3, end, y - 3), fill=P["red_light"])
        d.rectangle((end - 1, y - 1, end, y), fill="#e5c37d")
    d.rectangle((4, 60, 10, 62), fill="#8b8e72")
    return im


def person():
    im = Image.new("RGBA", (16, 32))
    d = ImageDraw.Draw(im)
    d.rectangle((5, 25, 7, 29), fill="#3b4f60")
    d.rectangle((9, 25, 11, 29), fill="#3b4f60")
    d.rectangle((4, 29, 7, 30), fill="#453f39")
    d.rectangle((9, 29, 12, 30), fill="#453f39")
    poly(d, [(4, 15), (11, 15), (13, 22), (11, 25), (4, 25), (2, 22)], "#ce9756")
    d.rectangle((5, 16, 10, 23), fill="#f0c77b")
    d.rectangle((3, 20, 4, 23), fill="#d7a37d")
    d.rectangle((11, 20, 12, 23), fill="#d7a37d")
    d.rectangle((4, 6, 11, 14), fill="#e3b485")
    poly(d, [(3, 7), (4, 4), (10, 3), (12, 5), (12, 10), (10, 8),
             (8, 8), (8, 7), (5, 9), (4, 11)], "#624632")
    d.rectangle((5, 4, 9, 5), fill="#8d623b")
    d.point((9, 11), fill="#41434a")
    d.point((10, 13), fill="#bb805d")
    return im


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    modules = OUT / "tiles"
    modules.mkdir(exist_ok=True)
    rng = random.Random(20261026)
    ground = Image.new("RGB", SIZE)
    for y in range(0, SIZE[1], 16):
        for x in range(0, SIZE[0], 16):
            ground.paste(grass_tile(rng.randrange(5)), (x, y))
    d = ImageDraw.Draw(ground)
    # Large connected patches, kept quieter than the object silhouettes.
    for cx, cy, rx, ry in [(55, 242, 53, 19), (151, 269, 45, 12),
                          (326, 155, 38, 11), (414, 171, 42, 13),
                          (347, 278, 44, 9), (175, 120, 30, 8)]:
        cluster(d, cx, cy, rx, ry, "grass_light")
    shore = [(-10, 100), (30, 98), (58, 94), (84, 91), (110, 94),
             (130, 102), (149, 114), (166, 121), (193, 125),
             (224, 126), (253, 124), (281, 117), (310, 107),
             (344, 99), (375, 95), (408, 88), (445, 80), (490, 77)]
    water_polygon = [(0, 0), (480, 0), *reversed(shore), (0, 0)]
    water_mask = Image.new("1", SIZE)
    ImageDraw.Draw(water_mask).polygon(water_polygon, fill=1)
    poly(d, water_polygon, "water")
    # A two-level bank: soil/grass sits above the dark wet edge.
    for offset, color, width in [(5, "grass_dark", 7), (2, "bank_light", 3),
                                 (-1, "bank", 3), (-4, "bank_dark", 3),
                                 (-7, "water_light", 1)]:
        d.line([(x, y + offset) for x, y in shore], fill=P[color], width=width, joint="curve")
    for _ in range(260):
        x, y = rng.randrange(480), rng.randrange(126)
        length = rng.choice([3, 4, 5, 7, 9, 12])
        if all(water_mask.getpixel((min(479, x + dx), min(287, y + 5))) for dx in (0, length)):
            color = rng.choice(["water_dark", "water_light", "water_light"])
            d.line((x, y, min(479, x + length), y), fill=P[color])
            if color == "water_light" and length >= 9:
                d.line((x + 2, y - 1, x + 4, y - 1), fill=P["water_glint"])
    # The round planting island and branching red walk are photo references,
    # laid out here as an art composition rather than surveyed coordinates.
    path_mask = Image.new("L", SIZE)
    pd = ImageDraw.Draw(path_mask)
    routes = [([(-20, 141), (35, 128), (77, 120), (110, 123), (140, 139),
                (155, 160), (176, 174)], 17),
              ([(-20, 219), (33, 188), (76, 169), (114, 170), (174, 188)], 23),
              ([(272, 190), (306, 202), (340, 223), (385, 244), (440, 261), (490, 280)], 25)]
    for points, width in routes:
        pd.line(points, fill=255, width=width, joint="curve")
        for x, y in points:
            pd.ellipse((x - width // 2, y - width // 2, x + width // 2, y + width // 2), fill=255)
    pd.ellipse((165, 148, 283, 211), fill=255)
    pd.ellipse((181, 160, 267, 199), fill=0)
    # Hard pixel outlines from morphology, with no resampling.
    outer = path_mask.filter(ImageFilter.MaxFilter(5))
    drop = Image.new("L", SIZE)
    drop.paste(outer, (0, 2))
    ground.paste(P["curb_shadow"], mask=drop)
    ground.paste(P["curb"], mask=outer)
    ground.paste(P["path"], mask=path_mask)
    d = ImageDraw.Draw(ground)
    for _ in range(400):
        x, y = rng.randrange(480), rng.randrange(288)
        if path_mask.getpixel((x, y)):
            d.line((x, y, x + 1, y), fill=P[rng.choice(["path_light", "path_dark"])])
    # Low planting bed, lit upper rim and a visible southern face.
    d.ellipse((183, 163, 265, 196), fill=P["leaf_dark"])
    d.ellipse((185, 161, 264, 190), fill=P["leaf_mid"])
    d.arc((185, 161, 264, 190), 180, 340, fill=P["leaf_sun"], width=2)
    for _ in range(100):
        x, y = rng.randrange(188, 261), rng.randrange(163, 190)
        if ((x - 224) / 38) ** 2 + ((y - 176) / 14) ** 2 < 1:
            d.line((x, y, x + 1, y), fill=P[rng.choice(["leaf_light", "leaf_mid", "leaf_sun"])])
    # The stone's small stone-paved approach interrupts the hedge.
    poly(d, [(218, 178), (235, 178), (241, 202), (213, 202)], "#afb394")
    for y in (184, 190, 196, 201):
        d.line((216 - (y - 184) // 8, y, 237 + (y - 184) // 8, y), fill="#8a967b")
    d.line((225, 180, 226, 200), fill="#cfd0af")
    placements = []
    sprites = {"tree-a": tree(3), "tree-b": tree(8), "willow": tree(13, True),
               "hedge": shrub(5), "stone": rock(), "bench": bench(),
               "lamp": lamp(), "person": person()}

    def place(name, x, foot_y, anchor=None):
        sprite = sprites[name]
        ax, ay = anchor or (sprite.width // 2, sprite.height - 4)
        placements.append({"asset": name, "x": x - ax, "y": foot_y - ay,
                           "foot": [x, foot_y], "depth": foot_y})

    for x, y, name in [(18, 139, "tree-a"), (112, 131, "tree-b"),
                        (368, 124, "tree-a"), (447, 114, "willow"),
                        (472, 169, "tree-b"), (26, 277, "tree-b"),
                        (80, 296, "tree-a"), (443, 313, "tree-a")]:
        place(name, x, y)
    for x, y in [(56, 150), (84, 149), (316, 159), (343, 151),
                 (304, 255), (332, 266), (360, 276), (390, 285),
                 (465, 207), (456, 195), (153, 249)]:
        place("hedge", x, y)
    place("stone", 226, 181)
    place("bench", 382, 220)
    place("lamp", 144, 160)
    place("lamp", 302, 180)
    place("person", 329, 225)

    # Export the drawing as separate 16x16 ground/object modules, not an HD image.
    catalog = {}
    for name, sprite in {"ground": ground, **sprites}.items():
        entries = []
        for y in range(0, sprite.height, 16):
            for x in range(0, sprite.width, 16):
                part = sprite.crop((x, y, x + 16, y + 16)).convert("RGBA")
                if not part.getbbox():
                    continue
                filename = f"{name}-{x // 16}-{y // 16}.png"
                part.save(modules / filename)
                entries.append({"file": filename, "x": x, "y": y})
        catalog[name] = {"size": list(sprite.size), "modules": entries}

    scene = ground.convert("RGBA")
    sd = ImageDraw.Draw(scene)
    for p in sorted(placements, key=lambda p: p["depth"]):
        x, y = p["foot"]
        name = p["asset"]
        if name in ("tree-a", "tree-b", "willow"):
            sd.ellipse((x - 18, y - 4, x + 24, y + 6), fill=P["shadow"])
        elif name == "person":
            sd.ellipse((x - 6, y - 2, x + 8, y + 2), fill=P["path_dark"])
        elif name == "lamp":
            sd.line((x, y, x + 14, y + 5), fill=P["shadow"], width=2)
        scene.alpha_composite(sprites[name], (p["x"], p["y"]))

    scene.convert("RGB").save(OUT / "yongquan-native.png")
    scene.resize((SIZE[0] * 3, SIZE[1] * 3), Image.Resampling.NEAREST).convert("RGB").save(OUT / "yongquan-preview.png")
    # A separate palette/module board is useful for reviewing the native assets.
    board = Image.new("RGB", (192, 112), "#e0d8b4")
    for name, x, y in [("tree-a", 0, 0), ("willow", 64, 0), ("stone", 128, 0),
                       ("lamp", 164, 0), ("bench", 128, 64), ("person", 176, 72),
                       ("hedge", 8, 88)]:
        board.paste(sprites[name], (x, y), sprites[name])
    board.resize((768, 448), Image.Resampling.NEAREST).save(OUT / "assets-preview.png")
    (OUT / "scene.json").write_text(json.dumps({
        "nativeSize": SIZE, "moduleSize": 16, "previewScale": 3,
        "kind": "lakeside art study, composition not a surveyed map",
        "sourcePhotos": [
            {"path": "references/eda/vegetation/photos/eda-lake-4.jpg",
             "url": "https://news.dlut.edu.cn/info/1292/147345.htm",
             "use": "red walk, pale curb, planting island, scholar rock, bench and red lamps"},
            {"path": "references/eda/vegetation/photos/eda-lake-2.jpg",
             "url": "https://news.dlut.edu.cn/info/1292/147345.htm",
             "use": "water, curved shore and tree belt"}],
        "assets": catalog, "objects": placements,
    }, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Drew {SIZE[0]}x{SIZE[1]} native pixels; exported {sum(len(a['modules']) for a in catalog.values())} 16x16 modules to {OUT}")


if __name__ == "__main__":
    main()
