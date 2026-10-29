"""Safety contracts for the benchmark launcher; never contacts a real device."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class BenchmarkSafetyTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "tool").mkdir()
        shutil.copyfile(Path(__file__).with_name("bench.sh"), self.root / "tool/bench.sh")
        self.log = self.root / "calls.jsonl"
        self.protected = self.root / "original-installed"
        self.protected.touch()
        self.env = dict(os.environ, ANDROID_HOME=str(self.root / "sdk"),
                        CALLS=str(self.log), FIXTURE_ORIGINAL_FILE=str(self.protected),
                        PACKAGE="cam.quietake.app.dev", PROTECTED_PACKAGE="club.hubner.shuttered")
        self.env["PATH"] = str(self.root / "bin") + os.pathsep + self.env["PATH"]
        self.executable("bin/flutter", '''
import os, sys
from pathlib import Path
args = sys.argv[1:]
if args[0] == 'build':
    if os.getenv('BUILD_FAIL'): sys.exit(2)
    p = Path('build/app/outputs/flutter-apk/app-profile.apk')
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_bytes(b'apk fixture')
if args[0] == 'drive' and os.getenv('REMOVE_ORIGINAL'):
    Path(os.environ['FIXTURE_ORIGINAL_FILE']).unlink()
''')
        self.executable("sdk/platform-tools/adb", '''
import os, sys
from pathlib import Path
args = sys.argv[1:]
if args[2:] == ['get-state']: print('device')
if args[2:] == ['shell', 'pm', 'path', os.environ['PROTECTED_PACKAGE']]:
    if not Path(os.environ['FIXTURE_ORIGINAL_FILE']).exists(): sys.exit(1)
    print('package:/fixture/base.apk')
''')
        self.executable("sdk/build-tools/36.0.0/aapt", '''
import os
print("package: name='" + os.environ['PACKAGE'] + "' versionCode='1'")
''')

    def executable(self, name, body):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        recorder = """import json, os, sys
with open(os.environ['CALLS'], 'a') as log:
    log.write(json.dumps([os.path.basename(sys.argv[0]), *sys.argv[1:]]) + '\\n')
"""
        path.write_text("#!/usr/bin/env python3\n" + recorder + body)
        path.chmod(0o755)

    def run_bench(self):
        result = subprocess.run(["bash", "tool/bench.sh", "fixture-device"],
                                cwd=self.root, env=self.env, capture_output=True, text=True)
        calls = [json.loads(line) for line in self.log.read_text().splitlines()]
        return result, calls

    def test_uses_validated_prebuilt_and_disables_uninstall(self):
        result, calls = self.run_bench()
        self.assertEqual(result.returncode, 0, result.stderr)
        drive = next(call for call in calls if call[:2] == ["flutter", "drive"])
        self.assertIn("--use-application-binary=build/app/outputs/flutter-apk/app-profile.apk", drive)
        self.assertIn("--keep-app-running", drive)
        self.assertTrue(self.protected.exists())
        self.assertNotIn("uninstall", [arg for call in calls for arg in call])
        stops = [call for call in calls if "force-stop" in call]
        self.assertEqual([call[-1] for call in stops], ["cam.quietake.app.dev"])

    def test_refuses_original_package_before_launch(self):
        self.env["PACKAGE"] = "club.hubner.shuttered"
        result, calls = self.run_bench()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Refusing benchmark", result.stderr)
        self.assertFalse(any(call[:2] == ["flutter", "drive"] for call in calls))
        self.assertTrue(self.protected.exists())

    def test_refuses_legacy_development_package_before_launch(self):
        self.env["PACKAGE"] = "club.hubner.shuttered.dev"
        result, calls = self.run_bench()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any(call[:2] == ["flutter", "drive"] for call in calls))
        self.assertFalse(any("force-stop" in call for call in calls))

    def test_build_failure_does_not_launch(self):
        self.env["BUILD_FAIL"] = "1"
        result, calls = self.run_bench()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any(call[:2] == ["flutter", "drive"] for call in calls))
        self.assertTrue(self.protected.exists())

    def test_detects_unexpected_original_removal(self):
        for package in ['cam.quietake.app', 'club.hubner.shuttered', 'club.hubner.shuttered.dev']:
            with self.subTest(package=package):
                self.protected.touch()
                self.env['PROTECTED_PACKAGE'] = package
                self.env['REMOVE_ORIGINAL'] = '1'
                result, _ = self.run_bench()
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('original application disappeared', result.stderr)

    def test_refuses_new_release_package(self):
        self.env['PACKAGE'] = 'cam.quietake.app'
        result, calls = self.run_bench()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any(call[:2] == ['flutter', 'drive'] for call in calls))


if __name__ == "__main__":
    unittest.main()
