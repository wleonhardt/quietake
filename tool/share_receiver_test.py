import unittest
from pathlib import Path
import xml.etree.ElementTree as ET

from share_receiver import build_receiver, fixture_package, validate_fixture_package
from dev_identity import APP, PROTECTED
import tempfile


class FixtureTests(unittest.TestCase):
    def test_fresh_identity_and_strict_namespace(self):
        first, second = fixture_package(), fixture_package()
        self.assertNotEqual(first, second)
        validate_fixture_package(first)
        for package in [APP, *PROTECTED,
                        'com.example.quietake.sharefixture', first + '.other']:
            with self.assertRaises(ValueError):
                validate_fixture_package(package)

    def test_offline_and_explicit_only(self):
        root = ET.parse(Path(__file__).parent / 'share_receiver/AndroidManifest.xml').getroot()
        self.assertFalse(root.findall('uses-permission'))
        android = '{http://schemas.android.com/apk/res/android}'
        self.assertEqual(root.find('application').get(android + 'allowBackup'), 'false')
        actions = {node.get(android + 'name') for node in root.findall('.//action')}
        self.assertEqual(actions, {'android.intent.action.SEND', 'android.intent.action.SEND_MULTIPLE'})

    def test_existing_scratch_content_is_never_overwritten(self):
        with tempfile.TemporaryDirectory() as directory:
            marker = Path(directory) / 'keep.txt'
            marker.write_text('keep')
            with self.assertRaises(ValueError):
                build_receiver(directory, fixture_package())
            self.assertEqual(marker.read_text(), 'keep')


class PlatformSelectionTests(unittest.TestCase):
    def test_preview_platform_does_not_become_install_requirement(self):
        from share_receiver import select_platform
        with tempfile.TemporaryDirectory() as directory:
            sdk = Path(directory)
            for name in ['android-33', 'android-36', 'android-37.0']:
                platform = sdk / 'platforms' / name
                platform.mkdir(parents=True)
                (platform / 'android.jar').touch()
            self.assertEqual(select_platform(sdk).name, 'android-36')
