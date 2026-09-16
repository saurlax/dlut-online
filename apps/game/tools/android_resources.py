"""Keep Godot's prebuilt Android resource package consistent with the manifest.

Godot's non-Gradle exporter renames the manifest but leaves com.godot.game
in resources.arsc. MagicOS then bypasses launcher icon theming. Only the
fixed-size ResTable_package.name field is changed; resource IDs stay intact.
Layout: AOSP libs/androidfw/include/androidfw/ResourceTypes.h.
"""
import re
import struct
import zipfile


def resource_package(data, package_name=None):
    """Read or normalize the single application package; reject unknown layouts."""
    if len(data) < 12:
        raise ValueError('Truncated Android resource table')
    kind, header, size, count = struct.unpack_from('<HHII', data)
    if kind != 0x0002 or header != 12 or size != len(data):
        raise ValueError('Invalid Android resource table header')
    offset, packages, names = header, 0, []
    while offset < size:
        if offset + 8 > size:
            raise ValueError('Truncated Android resource chunk')
        chunk_kind, chunk_header, chunk_size = struct.unpack_from('<HHI', data, offset)
        if chunk_header < 8 or chunk_size < chunk_header or offset + chunk_size > size:
            raise ValueError('Invalid Android resource chunk size')
        if chunk_kind == 0x0200:
            packages += 1
            if chunk_header < 284:
                raise ValueError('Truncated Android resource package')
            package_id = struct.unpack_from('<I', data, offset + 8)[0]
            if package_id == 0x7f:
                name = data[offset + 12:offset + 268].decode('utf-16-le').split('\0', 1)[0]
                names.append((offset + 12, name))
        offset += chunk_size
    if packages != count or len(names) != 1:
        raise ValueError('Expected exactly one application resource package (0x7f)')
    name_offset, old_name = names[0]
    if package_name is None:
        return old_name
    encoded = package_name.encode('utf-16-le')
    if not re.fullmatch(r'[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z][A-Za-z0-9_]*)+', package_name) or len(encoded) > 254:
        raise ValueError('Invalid or oversized Android package name')
    if old_name not in ('com.godot.game', package_name):
        raise ValueError(f'Unexpected Android resource package: {old_name}')
    result = bytearray(data)
    result[name_offset:name_offset + 256] = encoded.ljust(256, b'\0')
    return bytes(result)


def rewrite_apk(source, destination, package_name):
    """Write an unsigned APK; caller must zipalign and sign before distribution."""
    if source.resolve() == destination.resolve():
        raise ValueError('Source and destination APK must differ')
    with zipfile.ZipFile(source) as original:
        table = resource_package(original.read('resources.arsc'), package_name)
        with zipfile.ZipFile(destination, 'w') as output:
            for entry in original.infolist():
                # Rebuilding also removes the APK v2/v3 signing block. Strip only
                # v1 signature files, preserving unrelated META-INF metadata.
                if re.fullmatch(r'META-INF/(?:MANIFEST\.MF|[^/]+\.(?:SF|RSA|DSA|EC))', entry.filename, re.IGNORECASE):
                    continue
                content = table if entry.filename == 'resources.arsc' else original.read(entry)
                output.writestr(entry, content)


def verify_icons(manifest, resources, adaptive_xml, names, package_name):
    """Check compiled icon references, including Android 8+ resource selection."""
    ids = {}
    for name in ('icon', 'icon_foreground', 'icon_background'):
        match = re.search(r'spec resource (0x[0-9a-f]+) ' + re.escape(package_name)
                          + r':mipmap/' + name + r':', resources)
        if not match:
            raise ValueError(f'Missing compiled launcher resource: {name}')
        ids[name] = match[1]
    icon_refs = re.findall(r'A: android:icon\([^)]*\)=@(0x[0-9a-f]+)', manifest)
    if not icon_refs or any(ref != ids['icon'] for ref in icon_refs):
        raise ValueError('Manifest launcher icon does not reference mipmap/icon')
    adaptive_path = 'res/mipmap-anydpi-v26/icon.xml'
    selection = (r'config anydpi-v26:\s+resource ' + ids['icon']
                 + r' [^\n]+\n\s+\(string16\) "' + re.escape(adaptive_path) + '"')
    if not re.search(selection, resources) or adaptive_path not in names:
        raise ValueError('Missing Android 8+ adaptive icon selection')
    if 'E: adaptive-icon ' not in adaptive_xml:
        raise ValueError('Launcher XML is not an adaptive icon')
    for layer in ('foreground', 'background'):
        pattern = r'E: ' + layer + r' [^\n]+\n\s+A: android:drawable\([^)]*\)=@' + ids['icon_' + layer] + r'\b'
        if not re.search(pattern, adaptive_xml):
            raise ValueError(f'Invalid adaptive {layer} reference')
    for name in ids:
        pattern = r'resource ' + ids[name] + r' [^\n]+\n\s+\(string16\) "([^"]+)"'
        paths = re.findall(pattern, resources)
        if not paths or any(path not in names for path in paths):
            raise ValueError(f'Missing packaged launcher images: {name}')
