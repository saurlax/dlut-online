"""Export the isolated character preview without campus assets or networking.

python export_preview.py --godot /path/to/godot [--platform Windows|macOS]
Only the ignored .local/characters/preview-project directory is populated.
"""
import argparse
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[4]
GAME = ROOT / "apps/game"


def run(command):
    result = subprocess.run(command, text=True, encoding="utf-8", errors="replace", stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=300)
    print(result.stdout)
    if result.returncode or "SCRIPT ERROR:" in result.stdout or "ERROR:" in result.stdout:
        raise RuntimeError(f"Godot failed ({result.returncode})")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--platform", choices=["Windows", "macOS"], default="Windows")
    args = parser.parse_args()
    workspace = ROOT / ".local/characters/preview-project"
    workspace.mkdir(parents=True, exist_ok=True)
    for relative in ["assets/characters", "scenes/characters"]:
        shutil.copytree(GAME / relative, workspace / relative, dirs_exist_ok=True)
    for relative in ["assets/fonts/CampusSans.ttf", "assets/fonts/CampusSans.ttf.import", "assets/fonts/OFL.txt", "scripts/client/character_avatar.gd", "scripts/client/character_avatar.gd.uid", "scripts/client/character_preview.gd", "scripts/client/character_preview.gd.uid"]:
        destination = workspace / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(GAME / relative, destination)
    shutil.copy2(ROOT / "CREDITS.md", workspace / "CREDITS.md")
    (workspace / "project.godot").write_text('''config_version=5
[application]
config/name="DLUT Online 人物试衣"
run/main_scene="res://scenes/characters/preview.tscn"
config/features=PackedStringArray("4.7", "Forward Plus")
[display]
window/size/viewport_width=1280
window/size/viewport_height=800
window/stretch/mode="canvas_items"
[rendering]
renderer/rendering_method="forward_plus"
''', encoding="utf-8")
    (workspace / "export_presets.cfg").write_text('''[preset.0]
name="Windows"
platform="Windows Desktop"
runnable=true
export_filter="all_resources"
include_filter="*.md,*.txt"
exclude_filter=""
script_export_mode=2
[preset.0.options]
binary_format/architecture="x86_64"
binary_format/embed_pck=true
codesign/enable=false
debug/export_console_wrapper=0
[preset.1]
name="macOS"
platform="macOS"
runnable=true
export_filter="all_resources"
include_filter="*.md,*.txt"
exclude_filter=""
script_export_mode=2
[preset.1.options]
application/bundle_identifier="online.dlut.characterpreview"
application/short_version="0.1.0"
application/version="0.1.0"
binary_format/architecture="arm64"
codesign/codesign=1
notarization/notarization=0
''', encoding="utf-8")
    output = ROOT / ".local/characters/build"
    output.mkdir(parents=True, exist_ok=True)
    extension = ".exe" if args.platform == "Windows" else ".zip"
    target = output / ("DLUT-Online-Character-Preview" + extension)
    run([args.godot, "--headless", "--path", str(workspace), "--editor", "--import", "--quit"])
    run([args.godot, "--headless", "--path", str(workspace), "--export-release", args.platform, str(target)])
    if not target.exists() or target.stat().st_size < 1_000_000:
        raise RuntimeError("Export is missing or unexpectedly small")
    print(target)


if __name__ == "__main__":
    main()
