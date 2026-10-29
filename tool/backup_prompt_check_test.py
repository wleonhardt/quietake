"""Network-free guards for the explicitly opted-in NAS prompt check."""
import os
from pathlib import Path
import unittest
from unittest.mock import patch

from tool.backup_prompt_check import live_source, validate


class LivePromptGuardTest(unittest.TestCase):
    def test_requires_synthetic_directory_and_its_own_binary(self):
        root = Path('/tmp/quietake-nas-live-synthetic')
        self.assertEqual(validate(root / 'recover-fixture', root, True), root.resolve())
        for binary, folder, live in [
            (root / 'recover-fixture', root, False),
            ('/tmp/recover-fixture', root, True),
            ('/tmp/private/recover-fixture', '/tmp/private', True),
        ]:
            with self.assertRaises(ValueError):
                validate(binary, folder, live)

    def test_live_target_is_child_of_configured_collection(self):
        with patch.dict(os.environ, {'QUIETAKE_WEBDAV_URL': 'https://nas.invalid:5006/vault/'}):
            self.assertEqual(live_source(Path('/tmp/quietake-nas-live-synthetic')),
                             'https://nas.invalid:5006/vault/quietake-nas-live-synthetic/')

    def test_rejects_credentials_redirect_components_and_non_tls(self):
        for url in ['http://nas.invalid/vault/', 'https://u:p@nas.invalid/vault/',
                    'https://nas.invalid/vault', 'https://nas.invalid/vault/?x=1',
                    'https://nas.invalid/vault/#x']:
            with patch.dict(os.environ, {'QUIETAKE_WEBDAV_URL': url}):
                with self.assertRaises(ValueError):
                    live_source(Path('/tmp/quietake-nas-live-synthetic'))


if __name__ == '__main__':
    unittest.main()
