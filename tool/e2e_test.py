"""Bootstrap regression: connected TCP devices must never receive emulator work."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class EmulatorBootstrapTests(unittest.TestCase):
    def test_explicit_emulator_boot_and_binary_guard(self):
        for package in ['cam.quietake.app.dev', 'club.hubner.shuttered.dev', 'cam.quietake.app']:
            with self.subTest(package=package), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                (root / 'tool').mkdir()
                for name in ['e2e.sh', 'dev_identity.py']:
                    shutil.copyfile(Path(__file__).with_name(name), root / 'tool' / name)
                runner = root / 'tool/e2e.sh'
                runner.write_text(runner.read_text().replace('/tmp/quietake-emulator.log', str(root / 'emulator.log')))
                log = root / 'calls'
                env = dict(os.environ, ANDROID_HOME=str(root / 'sdk'), CALLS=str(log),
                           PACKAGE=package, BOOTED=str(root / 'booted'))
                env['PATH'] = str(root / 'bin') + os.pathsep + env['PATH']

                def executable(name, body):
                    path = root / name
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_text('''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
with open(os.environ['CALLS'], 'a') as stream:
    stream.write(json.dumps([Path(sys.argv[0]).name, *sys.argv[1:]]) + '\\n')
''' + body)
                    path.chmod(0o755)

                executable('sdk/emulator/emulator', '')
                executable('sdk/platform-tools/adb', '''
args = sys.argv[1:]
if args == ['devices']:
    print('List of devices attached\\n10.0.0.1:5555\\tdevice\\n10.0.0.2:5555\\tdevice')
    if Path(os.environ['BOOTED']).exists(): print('emulator-5554\\tdevice')
elif args[:2] != ['-s', 'emulator-5554']:
    sys.exit('Ambiguous or protected device target')
elif args[2:] == ['wait-for-device']:
    Path(os.environ['BOOTED']).touch()
elif args[2:] == ['shell', 'getprop', 'sys.boot_completed']:
    print('1')
''')
                executable('sdk/build-tools/36.0.0/aapt', '''
print("package: name='" + os.environ['PACKAGE'] + "'")
''')
                executable('bin/flutter', '')
                result = subprocess.run(['bash', 'tool/e2e.sh', 'android'], cwd=root, env=env,
                                        capture_output=True, text=True, timeout=20)
                calls = [json.loads(line) for line in log.read_text().splitlines()]
                self.assertIn(['adb', '-s', 'emulator-5554', 'wait-for-device'], calls)
                installs = [call for call in calls if 'install' in call]
                tests = [call for call in calls if call[:2] == ['flutter', 'test']]
                if package == 'cam.quietake.app.dev':
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(len(installs), 1)
                    self.assertIn('--no-uninstall', tests[0])
                else:
                    self.assertNotEqual(result.returncode, 0)
                    self.assertEqual(installs, [])
                    self.assertEqual(tests, [])
