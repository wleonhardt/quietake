#!/usr/bin/env python3
"""Actual Android URI-grant receipt check; disposable development emulator only."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time
import xml.etree.ElementTree as ET

from restart_check import ROOT, validate_android
from dev_identity import APP, PROTECTED, validate_binary
from share_receiver import build_receiver, fixture_package, validate_fixture_package


def recipient_bounds(xml, label):
    """Select only the fixture label observed in the native chooser hierarchy."""
    root = ET.fromstring(xml)
    parents = {child: parent for parent in root.iter() for child in parent}
    for node in root.iter('node'):
        if node.get('text') == label or node.get('content-desc') == label:
            target = node
            while target in parents and target.get('clickable') != 'true':
                target = parents[target]
            if target.get('clickable') != 'true':
                target = node
            bounds = re.fullmatch(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', target.get('bounds', ''))
            if bounds:
                left, top, right, bottom = map(int, bounds.groups())
                if right > left and bottom > top:
                    return (left + right) // 2, (top + bottom) // 2
    return None


def chooser_scroll(xml):
    # A collapsed chooser delegates dragging to its parent even when the list
    # advertises scrollable=false. Its observed bounds still define the gesture.
    for node in ET.fromstring(xml).iter('node'):
        if node.get('package') == 'android' and node.get('resource-id') == 'android:id/resolver_list':
            bounds = re.fullmatch(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', node.get('bounds', ''))
            if bounds:
                left, top, right, bottom = map(int, bounds.groups())
                if right > left and bottom > top:
                    x = (left + right) // 2
                    return x, top + (bottom - top) * 4 // 5, x, top + (bottom - top) // 5
    return None


def validate_receipt(receipt, package, expected):
    if receipt.get('package') != package or receipt.get('files') != expected or 'error' in receipt:
        raise ValueError('Separate recipient did not consume the expected bytes and MIME types')


def main(device, batch=False):
    adb = ['adb', '-s', device]

    def output(*args):
        return subprocess.check_output([*adb, *args], text=True, stderr=subprocess.DEVNULL, timeout=20).strip()

    def run(*args):
        subprocess.run([*adb, *args], check=True, stdout=subprocess.DEVNULL, timeout=30)

    validate_android(device, output('shell', 'getprop', 'ro.kernel.qemu'))
    def package_path(name):
        installed = output('shell', 'pm', 'list', 'packages', name).splitlines()
        return output('shell', 'pm', 'path', name) if f'package:{name}' in installed else ''

    protected = {name: package_path(name) for name in PROTECTED}
    subprocess.run(['flutter', 'build', 'apk', '--debug'], cwd=ROOT, check=True)
    validate_binary(ROOT / 'build/app/outputs/flutter-apk/app-debug.apk')
    run('shell', 'am', 'force-stop', APP)
    package = fixture_package()
    validate_fixture_package(package)
    if package_path(package):
        raise ValueError('Refusing to replace an existing recipient')
    label = f'Share check {package.split("run_")[1][:6]}'
    hierarchy = f'/sdcard/quietake-share-check-{package.split("run_")[1]}.xml'
    installed = False
    process = None
    with tempfile.TemporaryDirectory(prefix='quietake-share-check-') as directory:
        scratch = Path(directory)
        apk = build_receiver(scratch, package, label)
        try:
            run('install', str(apk))  # Deliberately no replacement flag.
            installed = True
            sender_uid = output('shell', 'run-as', APP, 'id', '-u')
            receiver_uid = output('shell', 'run-as', package, 'id', '-u')
            if sender_uid == receiver_uid:
                raise ValueError('Recipient must run under a separate UID')
            log = scratch / 'flutter.log'
            with log.open('w') as stream:
                process = subprocess.Popen(
                    ['flutter', 'test', 'integration_test/share_receiver_check.dart',
                     '-d', device, '--no-uninstall', '--dart-define=QUIETAKE_SHARE_CHECK=true',
                     f'--dart-define=QUIETAKE_SHARE_BATCH={str(batch).lower()}'],
                    cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
                deadline = time.monotonic() + 240
                selected = False
                scrolls = 0
                receipt = None
                while time.monotonic() < deadline and process.poll() is None:
                    if 'NATIVE_SHARE_READY' in log.read_text():
                        if not selected:
                            run('shell', 'uiautomator', 'dump', hierarchy)
                            xml = output('shell', 'cat', hierarchy)
                            bounds = recipient_bounds(xml, label)
                            if bounds:
                                run('shell', 'input', 'tap', *map(str, bounds))
                                selected = True
                            elif scrolls < 8:
                                gesture = chooser_scroll(xml)
                                if gesture:
                                    run('shell', 'input', 'swipe', *map(str, gesture), '400')
                                    scrolls += 1
                        else:
                            try:
                                receipt = json.loads(output('shell', 'run-as', package, 'cat', 'files/receipt.json'))
                            except (subprocess.CalledProcessError, json.JSONDecodeError):
                                pass
                            if receipt is not None:
                                names = [('tiny.jpg', 'image/jpeg')]
                                if batch:
                                    names += [('tiny.mp4', 'video/mp4'), ('wide.png', 'image/png')]
                                expected = []
                                for name, mime in names:
                                    media = (ROOT / 'test_fixtures' / name).read_bytes()
                                    expected.append({'bytes': len(media), 'sha256': hashlib.sha256(media).hexdigest(), 'mime': mime})
                                validate_receipt(receipt, package, expected)
                                if not output('shell', 'run-as', APP, 'ls', 'cache/quietake-share') or not output('shell', 'run-as', APP, 'ls', 'cache/share_plus'):
                                    raise ValueError('Sender cleaned granted copies before returning')
                                print(f'Recipient byte/MIME receipt checked: {len(expected)} files.', flush=True)
                                run('shell', 'input', 'keyevent', 'KEYCODE_BACK')
                                component = output('shell', 'cmd', 'package', 'resolve-activity', '--brief', '-a', 'android.intent.action.MAIN', '-c', 'android.intent.category.LAUNCHER', APP).splitlines()[-1]
                                if not component.startswith(APP + '/'):
                                    raise ValueError('Refusing to foreground a different app')
                                run('shell', 'am', 'start', '-W', '--activity-reorder-to-front', '-n', component)
                                try:
                                    process.wait(timeout=60)
                                except subprocess.TimeoutExpired as error:
                                    raise RuntimeError('Recipient returned but probe did not finish\n' + log.read_text()) from error
                                break
                    time.sleep(1)
                if process.poll() is None or process.returncode or receipt is None:
                    raise RuntimeError('Native sharing check failed\n' + log.read_text())
            print('Separate Android UID consumed the delayed granted copy; return cleanup passed.')
        finally:
            if process is not None and process.poll() is None:
                run('shell', 'input', 'keyevent', 'KEYCODE_BACK')
                process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=10)
            if installed:
                validate_fixture_package(package)
                run('uninstall', package)
            run('shell', 'rm', '-f', hierarchy)
            if {name: package_path(name) for name in PROTECTED} != protected:
                raise RuntimeError('Protected app identity changed')


if __name__ == '__main__':
    if len(sys.argv) not in (2, 3) or (len(sys.argv) == 3 and sys.argv[2] != '--batch'):
        raise SystemExit('Usage: python3 tool/share_check.py emulator-5554 [--batch]')
    main(sys.argv[1], batch=len(sys.argv) == 3)
