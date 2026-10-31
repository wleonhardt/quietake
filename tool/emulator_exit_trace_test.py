import importlib.util
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import textwrap
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
        self.logs = self.sdk / 'diagnostic logs'

    def install(self, body):
        content = f'#!{sys.executable}\n{body}\n'
        self.launcher.write_text(content)
        self.launcher.chmod(0o755)
        trace.install(self.sdk, self.logs)
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
        logs = list(self.logs.glob('emulator-*.log'))
        self.assertEqual(len(logs), 1)
        diagnostic = logs[0].read_text()
        self.assertIn("['-avd', 'name with spaces', '-no-snapshot']", diagnostic)
        self.assertIn('native stderr', diagnostic)
        self.assertNotIn('native stderr', result.stdout + result.stderr)
        self.assertNotIn('name with spaces', result.stdout)
        self.assertIn('QUIETAKE_EMULATOR_LOG path=', result.stdout)
        pid = (self.logs / 'emulator.pid').read_text()
        self.assertIn(f'QUIETAKE_EMULATOR_START pid={pid}', result.stdout)
        self.assertIn('returncode=0 signal=none', result.stdout)
        self.assertEqual(result.stderr, '')

    def test_version_probe_keeps_output_visible(self):
        self.install('import sys\nprint("native version")\n'
                     'print("version warning", file=sys.stderr)')
        result = self.run_launcher('-version')
        self.assertEqual(result.returncode, 0)
        self.assertIn('native version', result.stdout)
        self.assertEqual(result.stderr, 'version warning\n')
        self.assertFalse(self.logs.exists())

    def test_failed_launches_retain_separate_diagnostics(self):
        self.install('import sys\nprint("native boot failure", flush=True)\nsys.exit(7)')
        for _ in range(2):
            result = self.run_launcher('-avd', 'synthetic')
            self.assertEqual(result.returncode, 7)
            self.assertIn('returncode=7 signal=none', result.stdout)
            self.assertNotIn('native boot failure', result.stdout + result.stderr)
        logs = list(self.logs.glob('emulator-*.log'))
        self.assertEqual(len(logs), 2)
        self.assertTrue(all(p.read_text() == 'native boot failure\n' for p in logs))

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
        with subprocess.Popen([str(self.launcher), '-avd', 'synthetic'], text=True,
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

    def test_diagnostic_step_keeps_raw_messages_inside_disabled_commands(self):
        root = Path(__file__).resolve().parents[1]
        workflow = root / '.github/workflows/ci.yml'
        if not workflow.exists():
            workflow = root / 'release/public-source/.github/workflows/ci.yml'
        step = workflow.read_text().split('      - name: Emulator diagnostic log\n', 1)[1]
        script = textwrap.dedent(step.split('        run: |\n', 1)[1]
                                 .split('      - name:', 1)[0])
        logs = self.sdk / 'quietake-emulator-logs'
        logs.mkdir()
        raw = 'kernel failure\n::error::untrusted synthetic diagnostic'
        (logs / 'emulator-synthetic.log').write_text(raw)
        result = subprocess.run(['bash', '-e', '-c', script],
                                env=dict(os.environ, RUNNER_TEMP=str(self.sdk)),
                                capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('::group::emulator-synthetic.log\n', result.stdout)
        token = result.stdout.split('::stop-commands::', 1)[1].splitlines()[0]
        self.assertIn(raw + '\n::' + token + '::\n::endgroup::\n', result.stdout)

    def test_refuses_second_install(self):
        self.install('pass')
        before = self.launcher.read_bytes()
        with self.assertRaises(ValueError):
            trace.install(self.sdk, self.logs)
        self.assertEqual(self.launcher.read_bytes(), before)

    def test_cli_refuses_non_ci_sdk_mutation(self):
        self.launcher.write_text('unchanged')
        env = dict(os.environ)
        env.pop('GITHUB_ACTIONS', None)
        result = subprocess.run(
            [sys.executable, spec.origin, 'install', str(self.sdk), str(self.logs)],
            env=env, text=True, capture_output=True, timeout=5)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.launcher.read_text(), 'unchanged')


if __name__ == '__main__':
    unittest.main()
