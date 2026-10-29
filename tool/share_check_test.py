import unittest
from share_check import chooser_scroll, recipient_bounds, validate_receipt


class ShareCheckTests(unittest.TestCase):
    def test_selects_only_observed_exact_fixture_label(self):
        xml = '<hierarchy><node text="Other app" bounds="[0,0][10,10]"/><node text="Share check abc123" bounds="[20,40][80,100]"/></hierarchy>'
        self.assertEqual(recipient_bounds(xml, 'Share check abc123'), (50, 70))
        self.assertIsNone(recipient_bounds(xml, 'Share check abc'))

    def test_rejects_invisible_bounds(self):
        self.assertIsNone(recipient_bounds('<node text="Fixture" bounds="[0,0][0,0]"/>', 'Fixture'))

    def test_requires_exact_receipt(self):
        expected = [{'bytes': 3, 'sha256': 'abc', 'mime': 'image/jpeg'}]
        validate_receipt({'package': 'fixture', 'files': expected}, 'fixture', expected)
        for bad in [
            {'package': 'other', 'files': expected},
            {'package': 'fixture', 'files': []},
            {'package': 'fixture', 'files': expected, 'error': 'failed'},
        ]:
            with self.assertRaises(ValueError):
                validate_receipt(bad, 'fixture', expected)


class ChooserScrollTests(unittest.TestCase):
    def test_scroll_comes_only_from_observed_native_chooser(self):
        xml = '<node package="android" resource-id="android:id/resolver_list" scrollable="true" bounds="[0,100][100,500]"/>'
        self.assertEqual(chooser_scroll(xml), (50, 420, 50, 180))
        self.assertIsNone(chooser_scroll(xml.replace('package="android"', 'package="other"')))
        self.assertEqual(chooser_scroll(xml.replace('scrollable="true"', 'scrollable="false"')), (50, 420, 50, 180))


class RecipientTargetTests(unittest.TestCase):
    def test_taps_fixture_tile_when_label_is_clipped_at_navigation_edge(self):
        xml = '<node clickable="true" bounds="[0,180][100,240]"><node text="Fixture" bounds="[0,230][100,240]"/></node>'
        self.assertEqual(recipient_bounds(xml, 'Fixture'), (50, 210))
