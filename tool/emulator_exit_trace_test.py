import importlib.util
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import unittest

spec = importlib.util.spec_from_file_location(
    'emulator_exit_trace', Path(__file__).with_name('emulator_exit_trace.py'))
trace = importlib.util.module_from_spec(spec)
spec.loader.exec_module(trace)


class EmulatorExitTraceTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.sdk = Path(self.temp.name)
        self.launcher = self.sdk / 'emulator' / 'emulator'
        self.launcher.parent.mkdir()

    def install(self, body):
        content = f'#!{sys.executable}\n{body}\n'
        self.launcher.write_text(content)
        self.launcher.chmod(0o755)
        trace.install(self.sdk)
        self.assertEqual(
            self.launcher.with_name('.quietake-emulator-native').read_text(),
            content)

    def run_launcher(self, *arguments):
        return subprocess.run([str(self.launcher), *arguments],
                              text=True, capture_output=True, timeout=10)

    def test_preserves_arguments_output_and_success(self):
        self.install('import sys\nprint(repr(sys.argv[1:]))\n'
                     'print("native stderr", file=sys.stderr)')
        result = self.run_launcher('-avd', 'name with spaces', '-no-snapshot')
        self.assertEqual(result.returncode, 0)
        self.assertIn("['-avd', 'name with spaces', '-no-snapshot']", result.stdout)
        self.assertIn('QUIETAKE_EMULATOR_START pid=', result.stdout)
        self.assertIn('returncode=0 signal=none', result.stdout)
        self.assertEqual(result.stderr, 'native stderr\n')

    def test_reports_nonzero_native_exit(self):
        self.install('import sys\nsys.exit(7)')
        result = self.run_launcher()
        self.assertEqual(result.returncode, 7)
        self.assertIn('returncode=7 signal=none', result.stdout)

    def test_reports_native_signal(self):
        self.install('import os, signal\nos.kill(os.getpid(), signal.SIGTERM)')
        result = self.run_launcher()
        self.assertEqual(result.returncode, 143)
        self.assertIn('returncode=-15 signal=SIGTERM', result.stdout)

    def test_forwards_termination_to_native_child(self):
        self.install('import time\ntime.sleep(30)')
        with subprocess.Popen([str(self.launcher)], text=True,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE) as proc:
            try:
                first = proc.stdout.readline()
                self.assertIn('QUIETAKE_EMULATOR_START pid=', first)
                pid = int(first.split('pid=')[1].split()[0])
                proc.send_signal(signal.SIGTERM)
                output, error = proc.communicate(timeout=5)
                self.assertEqual(proc.returncode, 143, error)
                self.assertIn('returncode=-15 signal=SIGTERM', output)
                with self.assertRaises(ProcessLookupError):
                    os.kill(pid, 0)
            finally:
                if proc.poll() is None:
                    proc.kill()

    def test_refuses_second_install(self):
        self.install('pass')
        before = self.launcher.read_bytes()
        with self.assertRaises(ValueError):
            trace.install(self.sdk)
        self.assertEqual(self.launcher.read_bytes(), before)

    def test_cli_refuses_non_ci_sdk_mutation(self):
        self.launcher.write_text('unchanged')
        env = dict(os.environ)
        env.pop('GITHUB_ACTIONS', None)
        result = subprocess.run(
            [sys.executable, spec.origin, 'install', str(self.sdk)],
            env=env, text=True, capture_output=True, timeout=5)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.launcher.read_text(), 'unchanged')


if __name__ == '__main__':
    unittest.main()
