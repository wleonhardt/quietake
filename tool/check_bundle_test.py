import struct
import tempfile
import unittest
from unittest.mock import patch
from pathlib import Path
import zipfile

from tool.check_bundle import archive_errors, manifest_errors


class BundleArchiveTests(unittest.TestCase):
    def inspect(self, entries, forbidden=()):
        with tempfile.TemporaryDirectory() as directory:
            bundle = Path(directory) / "test.aab"
            with zipfile.ZipFile(bundle, "w") as archive:
                for name, content in entries.items():
                    archive.writestr(name, content)
            return archive_errors(bundle, forbidden)

    def test_excludes_test_media_and_private_configuration(self):
        errors = self.inspect({
            "base/assets/flutter_assets/test_fixtures/tiny.jpg": b"synthetic",
            "base/assets/flutter_assets/.env": b"not a credential",
            "base/assets/upload.jks": b"not a key",
        })
        self.assertEqual(len(errors), 3)

    def test_vault_exports_are_rejected_without_reading_them(self):
        with patch("zipfile.ZipFile.read", side_effect=AssertionError("Read private file")):
            errors = self.inspect({
                "base/assets/vault.keyfile.json": b"not a keyfile",
                "base/assets/capture.shtr": b"not a capture",
            })
        self.assertEqual(len(errors), 2)

    def test_private_content_is_reported_without_echoing_it(self):
        marker = b"PRIVATE-MARKER"
        errors = self.inspect({"base/lib/arm64-v8a/libapp.data": marker}, (marker.lower(),))
        self.assertEqual(errors, ["Forbidden content: base/lib/arm64-v8a/libapp.data"])
        self.assertNotIn(marker.decode(), "\n".join(errors))

    def test_native_library_must_support_16_kb_load_alignment(self):
        for alignment in (4096, 16384):
            with self.subTest(alignment=alignment):
                elf = bytearray(120)
                elf[:6] = b"\x7fELF\x02\x01"
                struct.pack_into("<Q", elf, 32, 64)
                struct.pack_into("<HH", elf, 54, 56, 1)
                struct.pack_into("<I", elf, 64, 1)
                struct.pack_into("<Q", elf, 112, alignment)
                errors = self.inspect({"base/lib/arm64-v8a/libapp.so": elf})
                self.assertEqual(bool(errors), alignment < 16384)

    def test_rejects_malformed_native_library(self):
        errors = self.inspect({"base/lib/x86_64/libbad.so": b"not ELF"})
        self.assertEqual(errors, ["Invalid native ELF headers: base/lib/x86_64/libbad.so"])

    def manifest(self, **attrs):
        defaults = {"allowBackup": "false", "fullBackupContent": "false",
                    "dataExtractionRules": "@xml/exclusions"}
        defaults.update(attrs)
        attributes = " ".join(f'android:{key}="{value}"' for key, value in defaults.items())
        return f'''<manifest xmlns:android="http://schemas.android.com/apk/res/android"
            package="app.test.camera"><uses-sdk android:targetSdkVersion="36"/>
            <application {attributes}/></manifest>'''

    def test_public_manifest_requires_identity_and_backup_protection(self):
        self.assertEqual(manifest_errors(self.manifest(), "app.test.camera"), [])
        self.assertTrue(manifest_errors(self.manifest(), "app.test.other"))
        self.assertTrue(manifest_errors(self.manifest(allowBackup="true"), "app.test.camera"))
        self.assertTrue(manifest_errors(self.manifest(dataExtractionRules=""), "app.test.camera"))

    def test_debuggable_and_old_target_builds_are_rejected(self):
        self.assertTrue(manifest_errors(self.manifest(debuggable="true"), "app.test.camera"))
        old_target = self.manifest().replace('targetSdkVersion="36"', 'targetSdkVersion="35"')
        self.assertTrue(manifest_errors(old_target, "app.test.camera"))

    def test_obsolete_cast_service_is_rejected(self):
        xml = self.manifest().replace(
            "/></manifest>",
            '><service android:name="com.google.android.gms.cast.framework.media.MediaNotificationService"/></application></manifest>',
        )
        self.assertTrue(manifest_errors(xml, "app.test.camera"))

    def test_shared_storage_permissions_are_rejected(self):
        xml = self.manifest().replace(
            "</manifest>",
            '<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/></manifest>',
        )
        self.assertTrue(manifest_errors(xml, "app.test.camera"))

    def test_ordinary_backup_workers_do_not_add_foreground_services(self):
        permission = self.manifest().replace('</manifest>',
            '<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/></manifest>')
        service = self.manifest().replace('/></manifest>',
            '><service android:name="androidx.work.impl.foreground.SystemForegroundService"/></application></manifest>')
        for xml in (permission, service):
            with self.subTest(xml=xml):
                self.assertTrue(manifest_errors(xml, 'app.test.camera'))


if __name__ == "__main__":
    unittest.main()
