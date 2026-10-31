"""Bootstrap regression: connected TCP devices must never receive emulator work."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class EmulatorBootstrapTests(unittest.TestCase):
    def test_wired_ac_phone_stays_awake_and_restores_setting_on_exit(self):
        for test_exit in [0, 1, 124]:
            with self.subTest(test_exit=test_exit), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                (root / 'tool').mkdir()
                (root / 'integration_test').mkdir()
                (root / 'integration_test/example_test.dart').touch()
                (root / 'integration_test/next_test.dart').touch()
                for name in ['e2e.sh', 'dev_identity.py', 'run_bounded.py']:
                    shutil.copyfile(Path(__file__).with_name(name), root / 'tool' / name)
                if test_exit == 124:
                    runner = root / 'tool/e2e.sh'
                    runner.write_text(runner.read_text().replace('bounded 300', 'bounded .3').replace('--grace 5', '--grace .1'))
                state = root / 'stay-awake'
                state.write_text('2')  # USB-only does not cover an AC-reported charger.
                env = dict(os.environ, ANDROID_HOME=str(root / 'sdk'),
                           AWAKE_STATE=str(state), TEST_EXIT=str(test_exit),
                           TEST_CALLS=str(root / 'test-calls'))
                env['PATH'] = str(root / 'bin') + os.pathsep + env['PATH']

                def executable(name, body):
                    path = root / name
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_text('#!/usr/bin/env python3\n' + body)
                    path.chmod(0o755)

                executable('sdk/platform-tools/adb', '''
import os, sys
from pathlib import Path
state = Path(os.environ['AWAKE_STATE'])
args = sys.argv[1:]
if args == ['devices']:
    print('List of devices attached\\nsynthetic-phone\\tdevice')
else:
    assert args[:2] == ['-s', 'synthetic-phone'], args
    command = args[2:]
    if command == ['shell', 'settings', 'get', 'global', 'stay_on_while_plugged_in']:
        print(state.read_text())
    elif command[:4] == ['shell', 'svc', 'power', 'stayon']:
        state.write_text('15' if command[4] == 'true' else '2')
    elif command[:5] == ['shell', 'settings', 'put', 'global', 'stay_on_while_plugged_in']:
        state.write_text(command[5])
''')
                executable('sdk/build-tools/36.0.0/aapt', '''
print("package: name='cam.quietake.app.dev'")
''')
                executable('bin/flutter', '''
import os, sys
from pathlib import Path
if not int(Path(os.environ['AWAKE_STATE']).read_text()) & 1:
    sys.exit('AC-reported wired phone can sleep during build/test')
if sys.argv[1] == 'test':
    assert '--no-uninstall' in sys.argv
    with open(os.environ['TEST_CALLS'], 'a') as stream:
        stream.write(sys.argv[2] + '\\n')
    if os.environ['TEST_EXIT'] == '124':
        import time
        time.sleep(20)
    sys.exit(int(os.environ['TEST_EXIT']))
''')
                result = subprocess.run(['bash', 'tool/e2e.sh', 'synthetic-phone'],
                                        cwd=root, env=env, capture_output=True,
                                        text=True, timeout=20)
                self.assertEqual(result.returncode, test_exit, result.stderr)
                self.assertNotIn('phone can sleep', result.stderr)
                self.assertEqual(state.read_text(), '2')
                if test_exit == 124:
                    self.assertIn('QUIETAKE_TIMEOUT label=integration_test/example_test.dart', result.stdout)
                    self.assertEqual((root / 'test-calls').read_text().splitlines(),
                                     ['integration_test/example_test.dart'])

    def test_stops_before_next_file_after_native_load_failure(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'tool').mkdir()
            (root / 'integration_test').mkdir()
            (root / 'bin').mkdir()
            for name in ['a_test.dart', 'b_test.dart']:
                (root / 'integration_test' / name).touch()
            for name in ['e2e.sh', 'run_bounded.py']:
                shutil.copyfile(Path(__file__).with_name(name), root / 'tool' / name)
            flutter = root / 'bin/flutter'
            flutter.write_text('''#!/usr/bin/env python3
import os, sys
from pathlib import Path
target = Path(sys.argv[2])
# Model Flutter's native directory dispatcher continuing after a load failure.
files = sorted(target.glob('*_test.dart')) if target.is_dir() else [target]
with open(os.environ['CALLS'], 'a') as output:
    for file in files:
        output.write(file.name + '\\n')
sys.exit(int(os.environ['TEST_EXIT']))
''')
            flutter.chmod(0o755)
            adb = root / 'sdk/platform-tools/adb'
            adb.parent.mkdir(parents=True)
            adb.write_text('#!/bin/sh\nexit 0\n')
            adb.chmod(0o755)
            log = root / 'calls'
            env = dict(os.environ, ANDROID_HOME=str(root / 'sdk'), CALLS=str(log),
                       TEST_EXIT='1')
            env['PATH'] = str(root / 'bin') + os.pathsep + env['PATH']
            result = subprocess.run(['bash', 'tool/e2e.sh', 'synthetic-device'],
                                    cwd=root, env=env, capture_output=True,
                                    text=True, timeout=20)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(log.read_text().splitlines(), ['a_test.dart'])
            log.write_text('')
            env['TEST_EXIT'] = '0'
            result = subprocess.run(['bash', 'tool/e2e.sh', 'synthetic-device'],
                                    cwd=root, env=env, capture_output=True,
                                    text=True, timeout=20)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(log.read_text().splitlines(), ['a_test.dart', 'b_test.dart'])
            log.write_text('')
            result = subprocess.run(['bash', 'tool/e2e.sh', 'synthetic-device',
                                     'integration_test/b_test.dart'],
                                    cwd=root, env=env, capture_output=True,
                                    text=True, timeout=20)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(log.read_text().splitlines(), ['b_test.dart'])
            for invalid in ['integration_test/missing_test.dart',
                            'integration_test/physical_check.dart',
                            'integration_test/../integration_test/a_test.dart']:
                log.write_text('')
                result = subprocess.run(['bash', 'tool/e2e.sh', 'synthetic-device', invalid],
                                        cwd=root, env=env, capture_output=True,
                                        text=True, timeout=20)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(log.read_text(), '')


    def test_explicit_emulator_boot_and_binary_guard(self):
        for package in ['cam.quietake.app.dev', 'club.hubner.shuttered.dev', 'cam.quietake.app']:
            with self.subTest(package=package), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                (root / 'tool').mkdir()
                (root / 'integration_test').mkdir()
                (root / 'integration_test/example_test.dart').touch()
                for name in ['e2e.sh', 'dev_identity.py', 'run_bounded.py']:
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
