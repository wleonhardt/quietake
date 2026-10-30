#!/usr/bin/env python3
"""Trace the hosted CI emulator child without changing its native arguments."""
import argparse
import os
from pathlib import Path
import signal
import subprocess
import sys
import time


def install(sdk):
    launcher = sdk / 'emulator' / 'emulator'
    native = launcher.with_name('.quietake-emulator-native')
    if native.exists() or not launcher.is_file():
        raise ValueError('Expected an unmodified emulator launcher')
    source = str(Path(__file__).resolve())
    launcher.rename(native)
    launcher.write_text(
        '#!/usr/bin/env python3\nimport runpy, sys\n'
        f'sys.argv = [{source!r}, "run", {str(native)!r}, *sys.argv[1:]]\n'
        f'runpy.run_path({source!r}, run_name="__main__")\n')
    launcher.chmod(0o755)


def supervise(native, arguments):
    started = time.monotonic()
    # Retain the original argv[0] and directory used by the native launcher.
    child = subprocess.Popen(
        [str(native.with_name('emulator')), *arguments], executable=str(native))
    for sig in (signal.SIGINT, signal.SIGTERM):
        signal.signal(sig, lambda number, frame: child.send_signal(number))
    print(f'QUIETAKE_EMULATOR_START pid={child.pid}', flush=True)
    code = child.wait()
    name = signal.Signals(-code).name if code < 0 else 'none'
    print(f'QUIETAKE_EMULATOR_EXIT pid={child.pid} returncode={code} '
          f'signal={name} elapsed_seconds={time.monotonic() - started:.1f}',
          flush=True)
    return 128 - code if code < 0 else code


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    commands.add_parser('install').add_argument('sdk', type=Path)
    run = commands.add_parser('run')
    run.add_argument('native', type=Path)
    run.add_argument('arguments', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if args.command == 'install':
        if sys.platform != 'linux' or os.environ.get('GITHUB_ACTIONS') != 'true':
            parser.error('Installation is restricted to the disposable Linux CI SDK')
        install(args.sdk.resolve())
        return 0
    return supervise(args.native, args.arguments)


if __name__ == '__main__':
    sys.exit(main())
