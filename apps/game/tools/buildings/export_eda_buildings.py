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
    args = parser.parse_args()
    subprocess.run(
        [
            str(args.blender),
            "--background",
            "--factory-startup",
            "--python-exit-code",
            "1",
            "--python",
            str(Path(__file__).with_name("build_eda_blend.py")),
            "--",
            "--output",
            str(ROOT / "references" / "eda" / "buildings" / "blender"),
            "--runtime",
            str(ROOT / "apps" / "game" / "assets" / "campuses" / "eda" / "models" / "buildings"),
            "--export-only",
        ],
        check=True,
        cwd=ROOT,
    )


if __name__ == "__main__":
    main()
