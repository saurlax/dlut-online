"""Export all development-campus Blender building sources for Godot.

This regular Python wrapper only launches Blender. Geometry creation, manual
editing and GLB export all happen inside Blender.
"""

import argparse
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--blender", required=True, type=Path)
    parser.add_argument("--feature", help="Export one Feature ID instead of all buildings")
    args = parser.parse_args()
    command = [
        str(args.blender),
        "--background",
        "--factory-startup",
        "--python-exit-code",
        "1",
        "--python",
        str(Path(__file__).with_name("build_eda_streaming_assets.py")),
        "--",
        "--sources",
        str(ROOT / "references" / "eda" / "buildings" / "blender"),
        "--runtime",
        str(ROOT / "apps" / "game" / "assets" / "campuses" / "eda" / "models" / "buildings"),
    ]
    if args.feature:
        command.extend(["--feature", args.feature])
    subprocess.run(
        command,
        check=True,
        cwd=ROOT,
    )


if __name__ == "__main__":
    main()
