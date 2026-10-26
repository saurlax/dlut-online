"""Align imagegen title illustrations to the runtime pixel grid and palette."""

import argparse
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "apps/web/public/title"


def align(source, size, colors, destination, transparent=False):
    image = Image.open(source).convert("RGBA")
    image = image.resize(size, Image.Resampling.NEAREST)
    if transparent:
        pixels = [pixel[:3] for pixel in image.getdata() if pixel[3] >= 160]
        swatches = Image.new("RGB", (len(pixels), 1))
        swatches.putdata(pixels)
        palette = swatches.quantize(colors, method=Image.Quantize.MAXCOVERAGE, dither=Image.Dither.NONE)
        rgb = image.convert("RGB").quantize(palette=palette, dither=Image.Dither.NONE)
        rgb = rgb.convert("RGBA")
        alpha = image.getchannel("A").point(lambda value: 255 if value >= 160 else 0)
        rgb.putalpha(alpha)
        rgb.paste((0, 0, 0, 0), (0, 0), alpha.point(lambda value: 255-value))
    else:
        rgb = image.convert("RGB").quantize(colors, dither=Image.Dither.NONE).convert("RGB")
    rgb.save(OUT/destination, optimize=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--logo", type=Path)
    parser.add_argument("--landscape", type=Path)
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    if args.logo:align(args.logo, (320, 160), 40, "dlut-online.png", transparent=True)
    if args.landscape:align(args.landscape, (512, 288), 64, "landscape.png")


if __name__ == "__main__":main()
