import unittest
from restart_check import APP, validate_android, validate_package


class RestartGuards(unittest.TestCase):
    def test_only_actual_emulators(self):
        validate_android('emulator-5554', '1')
        for device, flag in [('339cb190', '0'), ('10.11.30.1:5555', '1'), ('emulator-5554', '0')]:
            with self.assertRaises(ValueError):
                validate_android(device, flag)

    def test_only_development_identity(self):
        validate_package(APP)
        for package in ['cam.quietake.app', 'club.hubner.shuttered', 'club.hubner.shuttered.dev', 'com.example.app', '']:
            with self.assertRaises(ValueError):
                validate_package(package)
