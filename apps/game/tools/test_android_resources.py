"""Regression checks for the fixed-size Android resource namespace correction."""
from pathlib import Path
import struct
import tempfile
import unittest
import zipfile

from android_resources import resource_package, rewrite_apk, verify_icons


def table(name='com.godot.game', package_id=0x7f):
    package = struct.pack('<HHII', 0x0200, 284, 284, package_id)
    package += name.encode('utf-16-le').ljust(256, b'\0') + bytes(16)
    return struct.pack('<HHII', 0x0002, 12, 12 + len(package), 1) + package


class AndroidResourcesTest(unittest.TestCase):
    def test_changes_only_name_and_is_idempotent(self):
        source = table()
        fixed = resource_package(source, 'com.saurlax.dlutonline')
        self.assertEqual(len(source), len(fixed))
        self.assertEqual(source[:24], fixed[:24])
        self.assertEqual(source[280:], fixed[280:])
        self.assertEqual(resource_package(fixed), 'com.saurlax.dlutonline')
        self.assertEqual(resource_package(fixed, 'com.saurlax.dlutonline'), fixed)

    def test_rejects_malformed_or_unexpected_tables(self):
        for source in (b'', table()[:-1], table('unexpected.package'), table(package_id=2)):
            with self.subTest(source=source[:12]), self.assertRaises(ValueError):
                resource_package(source, 'com.saurlax.dlutonline')
        source = bytearray(table())
        struct.pack_into('<I', source, 16, 0)  # Zero-sized chunk must not loop.
        with self.assertRaises(ValueError):
            resource_package(source)

    def test_rejects_invalid_target_names(self):
        for name in ('', 'no spaces.allowed', 'a.' + 'b' * 126, 'a\0.b'):
            with self.subTest(name=name), self.assertRaises(ValueError):
                resource_package(table(), name)

    def test_zip_preserves_payload_and_removes_stale_signatures(self):
        with tempfile.TemporaryDirectory() as temporary:
            source, destination = (Path(temporary) / name for name in ('source.apk', 'fixed.apk'))
            with zipfile.ZipFile(source, 'w') as apk:
                apk.writestr('resources.arsc', table(), compress_type=zipfile.ZIP_STORED)
                apk.writestr('assets/game.pck', b'game payload', compress_type=zipfile.ZIP_DEFLATED)
                apk.writestr('META-INF/CERT.RSA', b'old signature')
                apk.writestr('META-INF/MANIFEST.MF', b'old digests')
                apk.writestr('META-INF/library.version', b'1')
            rewrite_apk(source, destination, 'com.saurlax.dlutonline')
            with zipfile.ZipFile(destination) as apk:
                self.assertEqual(apk.read('assets/game.pck'), b'game payload')
                self.assertEqual(apk.getinfo('assets/game.pck').compress_type, zipfile.ZIP_DEFLATED)
                self.assertEqual(apk.getinfo('resources.arsc').compress_type, zipfile.ZIP_STORED)
                self.assertEqual(apk.read('META-INF/library.version'), b'1')
                self.assertNotIn('META-INF/CERT.RSA', apk.namelist())
                self.assertNotIn('META-INF/MANIFEST.MF', apk.namelist())
            with self.assertRaises(ValueError):
                rewrite_apk(source, source, 'com.saurlax.dlutonline')

    def test_icon_links_and_missing_resource_rejection(self):
        package = 'com.saurlax.dlutonline'
        names = {'res/mipmap-anydpi-v26/icon.xml', 'res/mipmap/icon.webp',
                 'res/mipmap/icon_foreground.webp', 'res/mipmap/icon_background.webp'}
        resources = ''
        for index, name in enumerate(('icon', 'icon_foreground', 'icon_background')):
            resources += f'spec resource 0x7f0a000{index} {package}:mipmap/{name}: flags=0\n'
            resources += f'resource 0x7f0a000{index} {package}:mipmap/{name}: t=0x03\n (string16) "res/mipmap/{name}.webp"\n'
        resources += f'config anydpi-v26:\n resource 0x7f0a0000 {package}:mipmap/icon: t=0x03\n (string16) "res/mipmap-anydpi-v26/icon.xml"\n'
        manifest = 'A: android:icon(0x01010002)=@0x7f0a0000'
        xml = 'E: adaptive-icon (line=1)\n E: foreground (line=2)\n A: android:drawable(0x01010199)=@0x7f0a0001\n E: background (line=3)\n A: android:drawable(0x01010199)=@0x7f0a0002'
        verify_icons(manifest, resources, xml, names, package)
        for args in ((manifest.replace('=@0x7f0a0000', '=@0x7f0a0001'), resources, xml, names),
                     (manifest, resources, xml.replace('=@0x7f0a0001', '=@0x7f0a0002'), names),
                     (manifest, resources, xml, names - {'res/mipmap/icon_foreground.webp'}),
                     (manifest, resources.replace('anydpi-v26', 'anydpi-v25'), xml, names)):
            with self.subTest(args=args[:1]), self.assertRaises(ValueError):
                verify_icons(*args, package)


if __name__ == '__main__':
    unittest.main()
