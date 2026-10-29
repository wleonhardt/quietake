"""Disposable CI acceptance probe. This branch must never be merged."""
import unittest

class IntentionalFailure(unittest.TestCase):
    def test_required_check_rejects_failure(self):
        self.fail("Intentional release-gate acceptance probe")
