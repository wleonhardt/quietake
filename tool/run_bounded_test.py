"""Behavioral tests for the host-side deadline, using only synthetic processes."""
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest

SCRIPT = Path(__file__).with_name('run_bounded.py')


class DeadlineTests(unittest.TestCase):
    def run_command(self, body, seconds='2', grace='0.1'):
        return subprocess.run([sys.executable, str(SCRIPT), '--seconds', seconds,
                               '--grace', grace, '--label', 'synthetic-test', '--',
                               sys.executable, '-u', '-c', body],
                              capture_output=True, text=True, timeout=8)

    def test_preserves_output_and_exit_status(self):
        for status in [0, 7]:
            result = self.run_command(f'import sys; print("child output"); sys.exit({status})')
            self.assertEqual(result.returncode, status, result.stderr)
            self.assertIn('child output', result.stdout)
            self.assertIn('QUIETAKE_END label=synthetic-test', result.stdout)

    def test_heartbeat_cannot_extend_deadline(self):
        start = time.monotonic()
        result = self.run_command('import time\nwhile True:\n print("heartbeat")\n time.sleep(.02)', '.15')
        self.assertEqual(result.returncode, 124, result.stderr)
        self.assertIn('QUIETAKE_TIMEOUT label=synthetic-test', result.stdout)
        self.assertLess(time.monotonic() - start, 3)

    def test_kills_ignoring_child_even_when_parent_exits_on_term(self):
        with tempfile.TemporaryDirectory() as temporary:
            marker = Path(temporary) / 'child-alive'
            child = ('import signal,time; from pathlib import Path; '
                     'signal.signal(signal.SIGTERM, signal.SIG_IGN); '
                     f'p=Path({str(marker)!r}); '
                     '\nwhile True:\n p.write_text(str(time.time_ns()))\n time.sleep(.02)')
            body = f'import subprocess,sys,time\nsubprocess.Popen([sys.executable,"-c",{child!r}])\ntime.sleep(20)'
            result = self.run_command(body, '.4')
            self.assertEqual(result.returncode, 124, result.stderr)
            before = marker.read_text()
            time.sleep(.15)
            self.assertEqual(marker.read_text(), before)

    def test_external_termination_stops_owned_command(self):
        with subprocess.Popen([sys.executable, str(SCRIPT), '--seconds', '10',
                               '--grace', '.1', '--label', 'cancel-test', '--',
                               sys.executable, '-c', 'import time; time.sleep(20)'],
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) as proc:
            try:
                self.assertIn('QUIETAKE_START', proc.stdout.readline())
                proc.send_signal(signal.SIGTERM)
                out, err = proc.communicate(timeout=3)
                self.assertEqual(proc.returncode, 143, err)
                self.assertIn('QUIETAKE_CANCEL', out)
            finally:
                if proc.poll() is None:
                    proc.kill()

    def test_invalid_deadlines_do_not_run_command(self):
        for seconds in ['0', '-1', 'nan', 'inf']:
            result = self.run_command('print("should not run")', seconds)
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn('should not run', result.stdout)


if __name__ == '__main__':
    unittest.main()
