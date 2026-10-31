#!/usr/bin/env python3
"""Trace the hosted CI emulator child without changing its native arguments."""
import argparse
from contextlib import nullcontext
import os
from pathlib import Path
import signal
import resource
import subprocess
import sys
import time
import tempfile


def install(sdk, log_dir):
    launcher = sdk / 'emulator' / 'emulator'
    native = launcher.with_name('.quietake-emulator-native')
    if native.exists() or not launcher.is_file():
        raise ValueError('Expected an unmodified emulator launcher')
    source = str(Path(__file__).resolve())
    launcher.rename(native)
    launcher.write_text(
        '#!/usr/bin/env python3\nimport runpy, sys\n'
        f'sys.argv = [{source!r}, "run", "--log-dir", {str(log_dir)!r}, {str(native)!r}, *sys.argv[1:]]\n'
        f'runpy.run_path({source!r}, run_name="__main__")\n')
    launcher.chmod(0o755)


def supervise(native, arguments, log_dir):
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    started = time.monotonic()
    # Only AVD launches are noisy. Keep version/setup probes visible.
    capture = '-avd' in arguments
    if capture:
        log_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
    output = (tempfile.NamedTemporaryFile(
        mode='wb', prefix='emulator-', suffix='.log', dir=log_dir, delete=False)
        if capture else nullcontext(None))
    with output as diagnostic:
        # Retain the original argv[0] and directory used by the native launcher.
        child = subprocess.Popen(
            [str(native.with_name('emulator')), *arguments], executable=str(native),
            stdout=diagnostic, stderr=subprocess.STDOUT if capture else None)
        for sig in (signal.SIGINT, signal.SIGTERM):
            signal.signal(sig, lambda number, frame: child.send_signal(number))
        print(f'QUIETAKE_EMULATOR_START pid={child.pid}', flush=True)
        if diagnostic:
            (log_dir / 'emulator.pid').write_text(str(child.pid))
            print(f'QUIETAKE_EMULATOR_LOG path={diagnostic.name}', flush=True)
        code = child.wait()
    name = signal.Signals(-code).name if code < 0 else 'none'
    print(f'QUIETAKE_EMULATOR_EXIT pid={child.pid} returncode={code} '
          f'signal={name} elapsed_seconds={time.monotonic() - started:.1f}',
          flush=True)
    return 128 - code if code < 0 else code


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    setup = commands.add_parser('install')
    setup.add_argument('sdk', type=Path)
    setup.add_argument('log_dir', type=Path)
    run = commands.add_parser('run')
    run.add_argument('--log-dir', type=Path, required=True)
    run.add_argument('native', type=Path)
    run.add_argument('arguments', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if args.command == 'install':
        if sys.platform != 'linux' or os.environ.get('GITHUB_ACTIONS') != 'true':
            parser.error('Installation is restricted to the disposable Linux CI SDK')
        install(args.sdk.resolve(), args.log_dir.resolve())
        return 0
    return supervise(args.native, args.arguments, args.log_dir)


if __name__ == '__main__':
    sys.exit(main())
