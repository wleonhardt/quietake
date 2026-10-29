#!/usr/bin/env python3
"""Synthetic process-death checks, restricted to development emulators.

Usage: python3 tool/restart_check.py android emulator-5554
       python3 tool/restart_check.py ios <booted-simulator-uuid>

This resets only the development test vault. Never use against a phone.
"""
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import time

from dev_identity import APP, validate_package, protected_paths
ROOT = Path(__file__).resolve().parent.parent


def output(*args):
    return subprocess.check_output(args, cwd=ROOT, text=True).strip()


def run(*args):
    subprocess.run(args, cwd=ROOT, check=True)


def validate_android(device, emulated):
    if not re.fullmatch(r'emulator-\d+', device) or emulated != '1':
        raise ValueError('Restart checks require an Android emulator')


def main(platform, device):
    if platform == 'android':
        validate_android(device, output('adb', '-s', device, 'shell', 'getprop', 'ro.kernel.qemu'))
        adb = ['adb', '-s', device]
        protected = protected_paths(adb)
    elif platform == 'ios':
        inventory = json.loads(output('xcrun', 'simctl', 'list', 'devices', 'booted', '-j'))
        if not any(d['udid'] == device and d['state'] == 'Booted'
                   for group in inventory['devices'].values() for d in group):
            raise ValueError('Restart checks require a booted iOS simulator')
    else:
        raise ValueError('Choose android or ios')

    def probe(stage):
        run('flutter', 'test', 'integration_test/restart_probe.dart', '-d', device,
            '--no-uninstall', f'--dart-define=RESTART_STAGE={stage}')

    with tempfile.TemporaryDirectory(prefix='quietake-restart-') as scratch:
        if platform == 'android':
            run('flutter', 'build', 'apk', '--debug')
            apk = ROOT / 'build/app/outputs/flutter-apk/app-debug.apk'
            sdk = Path(os.environ.get('ANDROID_HOME', Path.home() / 'Library/Android/sdk'))
            aapt = max((sdk / 'build-tools').glob('*/aapt'), key=lambda p: tuple(map(int, re.findall(r'\d+', p.parent.name))))
            badging = output(str(aapt), 'dump', 'badging', str(apk))
            validate_package(re.search(r"^package: name='([^']+)'", badging, re.M).group(1))
            activity = re.search(r"^launchable-activity: name='([^']+)'", badging, re.M).group(1)
            binary = Path(scratch) / 'normal.apk'
            shutil.copyfile(apk, binary)

            def install():
                run(*adb, 'install', '-r', str(binary))

            def launch():
                run(*adb, 'shell', 'am', 'start', '-W', '-n', f'{APP}/{activity}')
                return output(*adb, 'shell', 'pidof', APP)

            def stop():
                run(*adb, 'shell', 'am', 'force-stop', APP)

            def plant():
                run(*adb, 'shell', 'run-as', APP, 'sh', '-c',
                    "'mkdir -p cache/quietake-share cache/share_plus cache/quietake-import cache/quietake-backup app_flutter/.portable-stage-interrupted; "
                    "echo synthetic-only > cache/quietake-share/interrupted.jpg; "
                    "echo synthetic-only > cache/share_plus/interrupted.jpg; "
                    "echo synthetic-only > cache/quietake-import/interrupted.jpg; "
                    "echo encrypted-fixture > cache/quietake-backup/interrupted.zip; "
                    "echo encrypted-fixture > app_flutter/.portable-stage-interrupted/item.shtr'")

            def clean():
                return output(*adb, 'shell', 'run-as', APP, 'sh', '-c',
                              "'test ! -e cache/quietake-share && test ! -e cache/share_plus && test ! -e cache/quietake-import && test ! -e cache/quietake-backup && test ! -e app_flutter/.portable-stage-interrupted && echo clean'") == 'clean'

            def digest():
                data = subprocess.check_output([*adb, 'exec-out', 'run-as', APP, 'cat',
                                                'app_flutter/vault/2099-restart.tiny.mp4.shtr'])
                return hashlib.sha256(data).digest()
        else:
            run('flutter', 'build', 'ios', '--simulator', '--debug')
            source = ROOT / 'build/ios/iphonesimulator/Runner.app'
            with (source / 'Info.plist').open('rb') as stream:
                validate_package(plistlib.load(stream)['CFBundleIdentifier'])
            binary = Path(scratch) / 'Runner.app'
            shutil.copytree(source, binary)

            def install():
                run('xcrun', 'simctl', 'install', device, str(binary))

            def launch():
                return output('xcrun', 'simctl', 'launch', device, APP).split(':')[-1].strip()

            def stop():
                run('xcrun', 'simctl', 'terminate', device, APP)

            def container():
                return Path(output('xcrun', 'simctl', 'get_app_container', device, APP, 'data'))

            def plant():
                for name in ['quietake-share', 'share_plus', 'quietake-import', 'quietake-backup']:
                    directory = container() / 'Library/Caches' / name
                    directory.mkdir(parents=True, exist_ok=True)
                    (directory / 'interrupted.jpg').write_bytes(b'synthetic-only')
                staged = container() / 'Documents/.portable-stage-interrupted'
                staged.mkdir(parents=True)
                (staged / 'item.shtr').write_bytes(b'encrypted-fixture')

            def clean():
                return (all(not (container() / 'Library/Caches' / n).exists()
                            for n in ['quietake-share', 'share_plus', 'quietake-import', 'quietake-backup'])
                        and not (container() / 'Documents/.portable-stage-interrupted').exists())

            def digest():
                return hashlib.sha256((container() / 'Documents/vault/2099-restart.tiny.mp4.shtr').read_bytes()).digest()

        # Validate the normal development identity before any test installation.
        probe('seed')
        install()
        try:
            first = launch()
            assert first, 'Normal app has no process'
            time.sleep(3)
            plant()
            before = digest()
            stop()
            second = launch()
            assert second and second != first, 'Expected a new app process'
            deadline = time.monotonic() + 30
            while True:
                try:
                    if clean():
                        break
                except subprocess.CalledProcessError:
                    pass
                if time.monotonic() > deadline:
                    raise AssertionError('Normal startup left interrupted share copies')
                time.sleep(0.25)
            assert digest() == before, 'Encrypted original changed during restart'
            print(f'RESTART {platform}: new PID; normal-entry cleanup; encrypted hash unchanged', flush=True)
            probe('verify')
        finally:
            install()
            launch()
        if platform == 'android':
            assert protected_paths(adb) == protected, 'Protected installation changed'


if __name__ == '__main__':
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    main(*sys.argv[1:])
