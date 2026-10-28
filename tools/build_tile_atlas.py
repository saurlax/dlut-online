"""Pack native campus tiles in map texture order without resampling."""

import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
CAMPUS = ROOT / "apps/web/public/campuses/eda"
COLUMNS = 64
TILE_SIZE = 16


def build():
    manifest = json.loads((CAMPUS / "map.json").read_text(encoding="utf-8"))
    names = manifest["textures"]
    image = Image.new("RGBA", (COLUMNS * TILE_SIZE, ((len(names) + COLUMNS - 1) // COLUMNS) * TILE_SIZE))
    for index, name in enumerate(names):
        with Image.open(CAMPUS / "tiles" / f"{name}.png") as tile:
            if tile.size != (TILE_SIZE, TILE_SIZE):
                raise ValueError(f"{name}: expected 16×16 tile")
            image.paste(tile.convert("RGBA"), ((index % COLUMNS) * TILE_SIZE, (index // COLUMNS) * TILE_SIZE))
    image.save(CAMPUS / "tile-atlas.png", optimize=True)


if __name__ == "__main__":
    build()
