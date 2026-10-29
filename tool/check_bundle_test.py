import struct
import contextlib
import io
import tempfile
import unittest
from unittest.mock import patch
from pathlib import Path
import zipfile

from tool.check_bundle import archive_errors, manifest_errors, main


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


class BundleSigningModeTests(unittest.TestCase):
    def run_inspection(self, verification, *, unsigned=False, certificate='CN=Release', entries=()):
        with tempfile.TemporaryDirectory() as directory:
            bundle = Path(directory) / 'test.aab'
            with zipfile.ZipFile(bundle, 'w') as archive:
                for entry in entries:
                    archive.writestr(entry, b'synthetic signature marker')
            args = ['check_bundle.py', str(bundle), '--application-id', 'app.test.camera']
            if unsigned:
                args.append('--expect-unsigned')

            def command(*args):
                if args[:2] == ('bundletool', 'validate'):
                    return ''
                if args[:3] == ('bundletool', 'dump', 'manifest'):
                    return BundleArchiveTests().manifest()
                if args[:3] == ('bundletool', 'dump', 'config'):
                    return 'PAGE_ALIGNMENT_16K'
                if args[0] == 'jarsigner':
                    return verification
                if args[0] == 'keytool':
                    return certificate
                raise AssertionError(args)

            with patch('sys.argv', args), patch('tool.check_bundle.command', side_effect=command), \
                    contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                return main()

    def test_unsigned_rehearsal_requires_explicit_mode(self):
        self.assertEqual(self.run_inspection('jar is unsigned.'), 1)
        self.assertEqual(self.run_inspection('jar is unsigned.', unsigned=True), 0)

    def test_rehearsal_rejects_signed_or_ambiguous_output(self):
        for result in ['jar verified.', 'invalid signature', '']:
            with self.subTest(result=result):
                self.assertEqual(self.run_inspection(result, unsigned=True), 1)

    def test_rehearsal_rejects_leftover_signature_files(self):
        self.assertEqual(self.run_inspection('jar is unsigned.', unsigned=True,
                                            entries=['META-INF/UPLOAD.SF']), 1)

    def test_default_release_mode_stays_strict(self):
        self.assertEqual(self.run_inspection('jar verified.'), 0)
        self.assertEqual(self.run_inspection('jar verified.', certificate='CN=Android Debug'), 1)
        self.assertEqual(self.run_inspection('invalid signature'), 1)

    def test_release_rejects_files_added_after_signing(self):
        # JDK 21 exits zero and reports "jar verified" for this partial signature.
        result = ('jar verified.\n\nWarning:\n'
                  'This jar contains unsigned entries which have not been integrity-checked.\n')
        self.assertEqual(self.run_inspection(result), 1)


if __name__ == "__main__":
    unittest.main()
