#!/usr/bin/env python3
"""Generate Android launcher SVGs from the canonical DLUT Online mark."""
import argparse
from pathlib import Path
import xml.etree.ElementTree as ET

GAME = Path(__file__).resolve().parents[1]
UI = GAME / "assets/ui"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Reject stale icons without writing")
    args = parser.parse_args()
    source = ET.parse(UI / "branding/dlut-online-mark.svg").getroot()
    ET.register_namespace("", "http://www.w3.org/2000/svg")
    shapes = "\n".join(ET.tostring(child, encoding="unicode").strip()
                       for child in source if child.tag.rsplit("}", 1)[-1] not in ("title", "desc"))

    def svg(size, body):
        return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 512 512">\n'
                '  <title>DLUT Online</title>\n' + body + '\n</svg>\n')

    white = '  <rect width="512" height="512" fill="#FFFFFF"/>'
    files = {
        "android_icon.svg": svg(512, white + '\n  <g transform="translate(30.72 30.72) scale(0.88)">\n' + shapes + '\n  </g>'),
        # 212 * .72 * 432 / 512 = 128.79 px radius, inside Android's 132 px safe circle.
        "android_icon_foreground.svg": svg(432, '  <g transform="translate(71.68 71.68) scale(0.72)">\n' + shapes + '\n  </g>'),
        "android_icon_background.svg": svg(432, white),
    }
    for name, content in files.items():
        path = UI / name
        if args.check:
            if not path.is_file() or path.read_text() != content:
                parser.exit(1, f"Stale icon: {path}. Run tools/build_brand_icons.py.\n")
        else:
            path.write_text(content)
    print("Android launcher icons match the canonical mark" if args.check else "Generated Android launcher icons")


if __name__ == "__main__":
    main()
