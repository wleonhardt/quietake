#!/usr/bin/env python3
"""Run one local/CI command with a wall-clock deadline and owned-group cleanup."""
import argparse
import math
import os
import signal
import subprocess
import time


class Cancelled(Exception):
    def __init__(self, signum):
        self.signum = signum


def positive(value):
    number = float(value)
    if not math.isfinite(number) or number <= 0:
        raise argparse.ArgumentTypeError('deadline must be positive and finite')
    return number


def stop_group(proc, grace):
    # Only the session created for this command. Never kill shared adb servers,
    # emulator processes or processes selected by name.
    for sig in (signal.SIGINT, signal.SIGTERM):
        signal.signal(sig, signal.SIG_IGN)
    try:
        os.killpg(proc.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    time.sleep(grace)
    # Reap an exited leader before signalling again (macOS returns EPERM for
    # a process group containing only an unreaped zombie).
    proc.poll()
    # The leader may have exited while its child ignored TERM.
    try:
        os.killpg(proc.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    try:
        proc.wait(timeout=1)
    except subprocess.TimeoutExpired:
        print('QUIETAKE_CLEANUP process did not reap after SIGKILL', flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--seconds', type=positive, required=True)
    parser.add_argument('--grace', type=positive, default=5)
    parser.add_argument('--label', required=True)
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    if not command or any(ord(c) < 32 for c in args.label):
        parser.error('provide a command and a single-line label')
    started = time.monotonic()
    proc = subprocess.Popen(command, start_new_session=True)

    def cancel(signum, frame):
        raise Cancelled(signum)

    for sig in (signal.SIGINT, signal.SIGTERM):
        signal.signal(sig, cancel)
    print(f'QUIETAKE_START label={args.label} deadline_seconds={args.seconds:g}', flush=True)
    try:
        code = proc.wait(timeout=args.seconds)
        code = 128 - code if code < 0 else code
    except subprocess.TimeoutExpired:
        print(f'QUIETAKE_TIMEOUT label={args.label} elapsed_seconds={time.monotonic() - started:.1f}', flush=True)
        stop_group(proc, args.grace)
        code = 124
    except Cancelled as error:
        print(f'QUIETAKE_CANCEL label={args.label} signal={error.signum}', flush=True)
        stop_group(proc, args.grace)
        code = 128 + error.signum
    print(f'QUIETAKE_END label={args.label} exit={code} elapsed_seconds={time.monotonic() - started:.1f}', flush=True)
    return code


if __name__ == '__main__':
    raise SystemExit(main())
