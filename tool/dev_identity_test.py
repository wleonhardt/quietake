"""Installation guards use binary metadata, not source settings or filenames."""
from pathlib import Path
import plistlib
import tempfile
import unittest
from unittest.mock import patch

from dev_identity import APP, PROTECTED, protected_paths, validate_binary


class BinaryIdentityTests(unittest.TestCase):
    def test_simulator_metadata_rejects_every_protected_identity(self):
        with tempfile.TemporaryDirectory() as root:
            binary = Path(root) / 'Runner.app'
            binary.mkdir()
            for package in [APP, *PROTECTED, 'unrelated.app']:
                (binary / 'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier': package}))
                if package == APP:
                    validate_binary(binary)
                else:
                    with self.assertRaises(ValueError):
                        validate_binary(binary)

    def test_apk_badging_rejects_stale_and_missing_identity(self):
        with patch('dev_identity.Path.glob', return_value=iter([Path('/sdk/build-tools/36.0.0/aapt')])):
            with patch('dev_identity.subprocess.check_output', return_value=f"package: name='{APP}'"):
                validate_binary('debug.apk')
        for metadata in [*(f"package: name='{p}'" for p in PROTECTED), 'invalid badging']:
            with patch('dev_identity.Path.glob', return_value=iter([Path('/sdk/build-tools/36.0.0/aapt')])):
                with patch('dev_identity.subprocess.check_output', return_value=metadata):
                    with self.assertRaises(ValueError):
                        validate_binary('debug.apk')

    def test_snapshot_includes_old_development_installation(self):
        with patch('dev_identity.package_path', side_effect=lambda _, p: 'package:/' + p) as probe:
            snapshot = protected_paths(['adb', '-s', 'emulator-5554'])
        self.assertEqual(set(snapshot), set(PROTECTED))
        self.assertEqual(probe.call_count, 3)
