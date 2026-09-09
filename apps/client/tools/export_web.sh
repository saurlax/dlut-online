#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
python3 tools/prepare_campus.py
python3 tools/add_roads.py
python3 tools/prepare_lingshui.py
godot --headless --path . --script tools/build_model.gd
godot --headless --path . --script tools/build_lingshui.gd
godot --headless --path . --editor --quit > /tmp/dlut-godot-import.log 2>&1
mkdir -p build/web
godot --headless --path . --export-release Web build/web/index.html
printf 'Web build ready: build/web/index.html\n'
