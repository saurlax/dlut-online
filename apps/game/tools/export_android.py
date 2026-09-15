#!/usr/bin/env python3
"""Export a release-mode arm64 test APK using installed Android SDK and JDK 17 tools."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import re
import sys
import zipfile

GAME = Path(__file__).resolve().parents[1]


def run(*args, **kwargs):
    result = subprocess.run([str(arg) for arg in args], cwd=GAME,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, timeout=600, **kwargs)
    print(result.stdout, end="", flush=True)
    result.check_returncode()
    errors = [line for line in result.stdout.splitlines() if "ERROR:" in line]
    # Godot 4.7 may report shader RID cleanup leaks after a successful export.
    # Keep those diagnostics visible; reject script, resource and export errors.
    if any(not re.fullmatch(r"ERROR: \d+ RID allocations of type '.+' were leaked at exit\.", line) for line in errors):
        raise RuntimeError("Build tool reported an error")
    return result.stdout


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sdk', type=Path, required=True, help='Android SDK root')
    parser.add_argument('--java', type=Path, required=True, help='JDK 17 home (contains bin/java)')
    parser.add_argument('--godot', default='godot')
    args = parser.parse_args()
    sdk, java = args.sdk.resolve(), args.java.resolve()
    build_tools = sdk / 'build-tools' / '35.0.0'
    for tool in (java / 'bin/java', java / 'bin/keytool', build_tools / 'aapt', build_tools / 'apksigner', build_tools / 'zipalign', sdk / 'platform-tools/adb'):
        if not tool.is_file():
            parser.error(f'Missing tool: {tool}')
    output = GAME / 'build/android/DLUT-Online-Android.apk'
    output.parent.mkdir(parents=True, exist_ok=True)
    # Reuse Android's standard debug keystore, initializing it only when absent.
    keystore = Path.home() / '.android/debug.keystore'
    keystore.parent.mkdir(parents=True, exist_ok=True)
    if not keystore.exists():
        run(java / 'bin/keytool', '-genkeypair', '-keystore', keystore,
            '-storepass', 'android', '-keypass', 'android', '-alias', 'androiddebugkey',
            '-dname', 'CN=Android Debug,O=Android,C=US', '-keyalg', 'RSA',
            '-keysize', '2048', '-validity', '10000')
    # Editor paths are local Godot preferences, never committed export credentials.
    settings = {
        'export/android/java_sdk_path': str(java),
        'export/android/android_sdk_path': str(sdk),
    }
    version = subprocess.check_output([args.godot, '--version'], text=True).strip()
    major_minor = '.'.join(version.split('.')[:2])
    if sys.platform == 'darwin':
        config_root = Path.home() / 'Library/Application Support/Godot'
    elif sys.platform == 'win32':
        config_root = Path(os.environ['APPDATA']) / 'Godot'
    else:
        config_root = Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home() / '.config'))) / 'godot'
    preferences = config_root / f'editor_settings-{major_minor}.tres'
    if not preferences.is_file():
        run(args.godot, '--headless', '--recovery-mode', '--import')
    content = preferences.read_text()
    if '[resource]' not in content:
        raise RuntimeError('Invalid Godot editor preferences')
    for key, value in settings.items():
        line = f'{key} = {json.dumps(value)}'
        pattern = r'^' + re.escape(key) + r' = .*?$'
        if re.search(pattern, content, flags=re.MULTILINE):
            content = re.sub(pattern, lambda match: line, content, flags=re.MULTILINE)
        else:
            content = content.replace('[resource]', '[resource]\n' + line, 1)
    preferences.write_text(content)
    # Import without running @tool homepage previews; export below enables plugins.
    run(args.godot, '--headless', '--recovery-mode', '--import')
    # A failed export must never leave an older APK looking like a new result.
    output.unlink(missing_ok=True)
    # Release build mode is independent of the default debug signing identity.
    export_environment = dict(os.environ,
        GODOT_ANDROID_KEYSTORE_RELEASE_PATH=str(keystore),
        GODOT_ANDROID_KEYSTORE_RELEASE_USER='androiddebugkey',
        GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD='android')
    run(args.godot, '--headless', '--export-release', 'Android', output, env=export_environment)
    with zipfile.ZipFile(output) as apk:
        names = apk.namelist()
        libraries = [name for name in names if name.startswith('lib/') and name.endswith('.so')]
        if not libraries or any(not name.startswith('lib/arm64-v8a/') for name in libraries):
            raise RuntimeError('APK must contain only arm64 native libraries')
        if not any(name.startswith('assets/scripts/client/touch_controls.') for name in names):
            raise RuntimeError('Missing touch controls script')
        if 'assets/desktop_config.json' not in names:
            raise RuntimeError('Missing packaged API configuration')
        for campus in ('lingshui', 'eda', 'panjin'):
            if f'assets/assets/campuses/{campus}/data/campus.json' not in names:
                raise RuntimeError(f'Missing campus: {campus}')
        if any('/scripts/server/' in name or '/references/' in name for name in names):
            raise RuntimeError('Unexpected server code or offline references')
    manifest = run(build_tools / 'aapt', 'dump', 'xmltree', output, 'AndroidManifest.xml')
    debuggable = [line.split('=', 1)[1].strip() for line in manifest.splitlines()
                  if 'A: android:debuggable(' in line]
    if any(value != '(type 0x12)0x0' for value in debuggable):
        raise RuntimeError('Expected a non-debuggable Release APK')
    environment = dict(os.environ, JAVA_HOME=str(java))
    run(build_tools / 'apksigner', 'verify', '--verbose', output, env=environment)
    run(build_tools / 'zipalign', '-c', '-P', '16', '4', output)
    print(f'Verified Release test APK: {output} ({output.stat().st_size / 1048576:.1f} MiB)')


if __name__ == '__main__':
    main()
