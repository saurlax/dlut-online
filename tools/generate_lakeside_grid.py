"""Assemble a north-up Yongquan shoreline from geographic material cells."""

import argparse
import gzip
import hashlib
import json
import math
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image, ImageDraw

from terrain_tiles import generate_tiles, neighbor_mask, shape_mask, variant_at
from shore_tiles import assemble_shores

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "references/eda"


def inside_polygon(x, y, points):
    inside = False
    for (ax, ay), (bx, by) in zip(points, points[1:] + points[:1]):
        if (ay > y) != (by > y) and x < (bx - ax) * (y - ay) / (by - ay) + ax:
            inside = not inside
    return inside


def distance_squared(x, y, points):
    nearest = math.inf
    for (ax, ay), (bx, by) in zip(points, points[1:]):
        dx, dy = bx - ax, by - ay
        length = dx * dx + dy * dy
        t = max(0, min(1, ((x - ax) * dx + (y - ay) * dy) / length)) if length else 0
        nearest = min(nearest, (x - ax - dx * t) ** 2 + (y - ay - dy * t) ** 2)
    return nearest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / ".local/yongquan-grid")
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    config = json.loads((SOURCE / "yongquan-grid.json").read_text(encoding="utf-8"))
    archive = (SOURCE / "osm.osm.gz").read_bytes()
    osm = ET.fromstring(gzip.decompress(archive))
    lon, lat = config["originWgs84"]
    scale = 111320 * math.cos(math.radians(lat))
    nodes = {n.attrib["id"]: ((float(n.attrib["lon"]) - lon) * scale,
                              (lat - float(n.attrib["lat"])) * 111320)
             for n in osm.findall("node")}
    ways = {way.attrib["id"]: way for way in osm.findall("way")}

    def points(way_id):
        return [nodes[n.attrib["ref"]] for n in ways[way_id].findall("nd")]

    lake = points(config["waterWay"])
    walks = [points(way) for way in config["redWalkWays"]]
    left, top, right, bottom = config["boundsMeters"]
    width, height = right - left, bottom - top
    half_walk_squared = (config["walkWidthMeters"] / 2) ** 2
    materials = {}

    # Evaluate an extra border, so cropping never changes the adjacency masks.
    for y in range(top - 2, bottom + 2):
        for x in range(left - 2, right + 2):
            cx, cy = x + .5, y + .5
            material = "water" if inside_polygon(cx, cy, lake) else "grass"
            if any(distance_squared(cx, cy, walk) <= half_walk_squared for walk in walks):
                material = "red-walk"
            materials[x, y] = material

    connection_cells = {material: [] for material in ("water", "red-walk")}
    for y in range(top, bottom):
        for x in range(left, right):
            for material, cells in connection_cells.items():
                mask = neighbor_mask(lambda xx,yy: materials[xx,yy],x,y,material)
                cells.append(mask if shape_mask(mask).getbbox() else -1)
    shape_sets = {material: set(cells)-{-1} for material,cells in connection_cells.items()}
    tiles = generate_tiles(out / "tiles", shape_sets)
    texture_names = list(tiles)
    texture_ids = {name: i for i, name in enumerate(texture_names)}
    material_names = ["grass", "water", "red-walk"]
    grid, texture_grid, masks, coverage = [], [], [], []
    layers = {material: [] for material in connection_cells}
    preview = Image.new("RGBA", (width * 16, height * 16))
    semantic = Image.new("RGB", (width, height))
    colors = {"grass": "#93bb60", "water": "#448f99", "red-walk": "#c7785e"}
    for y in range(top, bottom):
        for x in range(left, right):
            material = materials[x, y]
            variant = variant_at(x, y)
            mask = neighbor_mask(lambda xx, yy: materials[xx, yy], x, y, material)
            name = f"grass-{variant}"
            px, py = (x - left) * 16, (y - top) * 16
            preview.alpha_composite(tiles[f"grass-{variant}"], (px, py))
            semantic.putpixel((x-left, y-top), tuple(int(colors[material][i:i+2],16) for i in (1,3,5)))
            grid.append(material_names.index(material))
            texture_grid.append(texture_ids[name])
            masks.append(mask)
            coverage.append("osm-water" if material == "water" else "osm-centerline-estimated-width" if material == "red-walk" else "photo-inferred-ground")

    for material,cells in connection_cells.items():
        for i,mask in enumerate(cells):
            if mask < 0:
                layers[material].append(-1)
                continue
            x,y=left+i%width,top+i//width
            name=f"{material}-{mask:03x}-{variant_at(x,y)}"
            layers[material].append(texture_ids[name])
            preview.alpha_composite(tiles[name],((i%width)*16,(i//width)*16))

    preview.convert("RGB").save(out / "flat-grid-native.png")
    shore_tiles, shore_cells = assemble_shores(materials, (left,top,right,bottom), out/"tiles")
    for name,image in shore_tiles.items():
        texture_ids[name]=len(texture_names)
        texture_names.append(name)
        tiles[name]=image
    for i,name in enumerate(shore_cells):
        if name:
            preview.alpha_composite(tiles[name], ((i%width)*16,(i//width)*16))
    preview.convert("RGB").save(out / "north-up-native.png")
    detail_bounds=(-80,182,-56,198)
    detail=preview.crop(((detail_bounds[0]-left)*16,(detail_bounds[1]-top)*16,
                         (detail_bounds[2]-left)*16,(detail_bounds[3]-top)*16))
    detail.resize((detail.width*3,detail.height*3),Image.Resampling.NEAREST).convert("RGB").save(out/"north-bank-detail.png")
    # Same pixels assembled above, displayed at integer zoom only.
    preview.resize((width * 32, height * 32), Image.Resampling.NEAREST).convert("RGB").save(out / "north-up-preview.png")
    debug = preview.copy()
    d = ImageDraw.Draw(debug)
    for x in range(0, width * 16, 16):
        d.line((x, 0, x, height*16-1), fill=(25, 40, 40, 80))
    for y in range(0, height * 16, 16):
        d.line((0, y, width*16-1, y), fill=(25, 40, 40, 80))
    debug.convert("RGB").save(out / "grid-preview.png")
    semantic.resize((width * 16, height * 16), Image.Resampling.NEAREST).save(out / "materials-preview.png")
    # Locator diagram uses the same geographic coordinates and source geometry.
    lx = math.floor(min(x for x, y in lake)) - 20
    ly = math.floor(min(y for x, y in lake)) - 20
    lw = math.ceil(max(x for x, y in lake)) + 20 - lx
    lh = math.ceil(max(y for x, y in lake)) + 20 - ly
    locator = Image.new("RGB", (lw, lh), colors["grass"])
    ld = ImageDraw.Draw(locator)
    ld.polygon([(round(x-lx), round(y-ly)) for x, y in lake], fill=colors["water"])
    for walk in walks:
        ld.line([(round(x-lx), round(y-ly)) for x, y in walk], fill=colors["red-walk"], width=2)
    ld.rectangle((left-lx, top-ly, right-lx, bottom-ly), outline="#fff0b4", width=2)
    ld.line((10, 22, 10, 8), fill="#294c47")
    ld.polygon([(10, 5), (7, 11), (13, 11)], fill="#294c47")
    ld.text((17, 5), "N", fill="#294c47")
    locator.resize((lw*4, lh*4), Image.Resampling.NEAREST).save(out / "location-preview.png")
    # Show the generated diagonal contours and their four texture variants.
    names=[f"{material}-{mask:03x}-{variant}"
           for material,shapes in shape_sets.items() for mask in sorted(shapes) for variant in range(4)]
    sheet=Image.new("RGBA",(256,math.ceil(len(names)/16)*16),"#93bb60")
    for i,name in enumerate(names):
        sheet.alpha_composite(tiles[name],((i%16)*16,(i//16)*16))
    sheet.resize((sheet.width*3,sheet.height*3),Image.Resampling.NEAREST).convert("RGB").save(out/"connections-preview.png")
    manifest = {
        "campus": "eda", "orientation": "north-up", "axis": {"x": "east", "y": "south"},
        "originWgs84": config["originWgs84"], "boundsMeters": config["boundsMeters"],
        "width": width, "height": height, "metersPerCell": 1, "tilePixels": 16,
        "coordinateTransform": "local equirectangular: east=(lon-lon0)*111320*cos(lat0); south=(lat0-lat)*111320",
        "sampling": "cell centers at x+0.5m, y+0.5m; no rotation, smoothing or per-feature shifts",
        "neighbors": ["N", "E", "S", "W", "NE", "SE", "SW", "NW"],
        "connectionShapes": {material:len(shapes) for material,shapes in shape_sets.items()},
        "centerBit": 8, "contour": "cell-center bilinear occupancy threshold, native hard pixels",
        "materials": material_names, "materialCells": grid,
        "textures": texture_names, "textureCells": texture_grid, "neighborMasks": masks,
        "terrainLayers": [{"material": material,"textureCells":cells} for material,cells in layers.items()],
        "shoreFaceCells": [texture_ids[name] if name else -1 for name in shore_cells],
        "shorePresentation": {"direction": "south-facing banks visible, north-facing banks occluded",
                              "facePixels": 8, "heightBasis": "visual low-bank estimate, not surveyed",
                              "pass": "separate 16x16 transparent modules above base material tiles"},
        "detailPreview": {"boundsMeters": detail_bounds, "integerZoom": 3},
        "underlay": "grass variant selected by world cell; transparent transition tiles overlay it",
        "evidenceClasses": coverage, "objects": [], "unplacedObjects": config["unplacedObjects"],
        "sources": [{"id": "way/"+i, "version": ways[i].attrib["version"]}
                    for i in [config["waterWay"], *config["redWalkWays"]]],
        "sourceSha256": hashlib.sha256(archive).hexdigest(),
        "attribution": "© OpenStreetMap contributors, ODbL 1.0",
        "limits": [config["walkWidthBasis"], config["landMaterialBasis"],
                   "1m sampling quantization is not source measurement accuracy"],
    }
    (out / "grid.json").write_text(json.dumps(manifest, ensure_ascii=False, separators=(",", ":"))+"\n", encoding="utf-8")
    print(f"Generated {width}x{height} north-up 1m cells, {len(tiles)} native 16x16 tiles, diagonal connection shapes {manifest['connectionShapes']}, {len(shore_tiles)} shore-face modules")


if __name__ == "__main__":
    main()
