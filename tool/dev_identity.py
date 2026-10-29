"""Validate built development binaries before installation or sandbox mutation."""
import os
from pathlib import Path
import plistlib
import re
import subprocess
import sys

APP = 'cam.quietake.app.dev'
# Legacy development installs can contain the only surviving migration source.
PROTECTED = ('cam.quietake.app', 'club.hubner.shuttered', 'club.hubner.shuttered.dev')


def validate_package(package):
    if package != APP:
        raise ValueError(f'Refusing non-development package: {package}')


def validate_binary(binary):
    binary = Path(binary)
    if binary.suffix == '.app':
        with (binary / 'Info.plist').open('rb') as stream:
            package = plistlib.load(stream)['CFBundleIdentifier']
    elif binary.suffix == '.apk':
        sdk = Path(os.environ.get('ANDROID_HOME', Path.home() / 'Library/Android/sdk'))
        aapt = max((sdk / 'build-tools').glob('*/aapt'),
                   key=lambda p: tuple(map(int, re.findall(r'\d+', p.parent.name))))
        metadata = subprocess.check_output([str(aapt), 'dump', 'badging', str(binary)], text=True)
        match = re.search(r"^package: name='([^']+)'", metadata, re.M)
        package = match.group(1) if match else None
    else:
        raise ValueError('Expected an APK or simulator .app')
    validate_package(package)


def package_path(adb, package):
    result = subprocess.run([*adb, 'shell', 'pm', 'path', package],
                            capture_output=True, text=True, check=False)
    if result.returncode not in (0, 1) or result.stderr.strip():
        raise RuntimeError('Could not inspect protected package')
    value = result.stdout.strip()
    if value and not all(line.startswith('package:') for line in value.splitlines()):
        raise RuntimeError('Unexpected protected package response')
    return value


def protected_paths(adb):
    return {package: package_path(adb, package) for package in PROTECTED}


if __name__ == '__main__':
    validate_binary(sys.argv[1])
