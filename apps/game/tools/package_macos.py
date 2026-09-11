#!/usr/bin/env python3
"""Sign an exported Apple Silicon app and verify the final DMG on macOS."""
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile

GAME = Path(__file__).resolve().parents[1]


def run(*args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)


def verify(app):
    run("codesign", "--verify", "--deep", "--strict", str(app))
    info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    if info["CFBundleIdentifier"] != "com.saurlax.dlutonline":
        raise RuntimeError("Unexpected application bundle identifier")
    executable = app / "Contents/MacOS" / info["CFBundleExecutable"]
    architectures = run("lipo", "-archs", str(executable), capture_output=True, text=True).stdout.strip()
    if architectures != "arm64":
        raise RuntimeError(f"Expected only arm64, got {architectures}")


def main():
    if sys.platform != "darwin":
        raise RuntimeError("DMG packaging requires macOS")
    source = GAME / "build/macos/DLUT Online.app"
    output = GAME / "build/macos/DLUT-Online-macOS.dmg"
    with tempfile.TemporaryDirectory(prefix="dlut-signing-") as directory:
        temporary = Path(directory)
        stage = temporary / "stage"
        stage.mkdir()
        shutil.copyfile(GAME / "WEATHER-CREDITS.txt", stage / "WEATHER-CREDITS.txt")
        app = stage / source.name
        run("ditto", str(source), str(app))
        # Official templates contain only universal binaries. Ship only Apple Silicon.
        info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
        executable = app / "Contents/MacOS" / info["CFBundleExecutable"]
        thin = temporary / "arm64"
        run("lipo", str(executable), "-thin", "arm64", "-output", str(thin))
        thin.chmod(executable.stat().st_mode)
        thin.replace(executable)
        # Replace all template/export signatures after the bundle is complete.
        run("codesign", "--force", "--deep", "--sign", "-", str(app))
        verify(app)
        (stage / "Applications").symlink_to("/Applications")
        run("hdiutil", "create", "-ov", "-format", "UDZO", "-volname", "DLUT Online",
            "-srcfolder", str(stage), str(output))
        run("hdiutil", "verify", str(output))
        mount = temporary / "mounted"
        run("hdiutil", "attach", "-readonly", "-nobrowse", "-mountpoint", str(mount), str(output))
        try:
            verify(mount / source.name)
        finally:
            run("hdiutil", "detach", str(mount))
        status = ("macOS: valid ad-hoc signature, no Developer ID or Apple notarization; "
                  "Gatekeeper may block browser downloads.\n")
        print(status, end="")


if __name__ == "__main__":
    main()
