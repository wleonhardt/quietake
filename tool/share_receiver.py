#!/usr/bin/env python3
"""Build a disposable offline share recipient with the existing Android SDK.

This never installs an APK. Device runners must separately enforce emulator-only
installation. All signing material is newly generated inside an empty scratch
folder; no app signing credentials or user media are read.
"""
from pathlib import Path
import os
import re
import secrets
import subprocess
import tempfile
import xml.etree.ElementTree as ET
import zipfile

SOURCE = Path(__file__).resolve().parent / 'share_receiver'


def fixture_package():
    return f'com.example.quietake.sharefixture.run_{secrets.token_hex(6)}.dev'


def validate_fixture_package(package):
    if not re.fullmatch(r'com\.example\.quietake\.sharefixture\.run_[0-9a-f]{12}\.dev', package):
        raise ValueError('Refusing a non-fixture package identity')


def select_platform(sdk):
    candidates = [p for p in (sdk / 'platforms').iterdir()
                  if re.fullmatch(r'android-\d+', p.name) and (p / 'android.jar').is_file()]
    return max(candidates, key=lambda p: int(p.name.removeprefix('android-')))


def build_receiver(workspace, package, label='Local share fixture'):
    validate_fixture_package(package)
    workspace = Path(workspace)
    if any(workspace.iterdir()):
        raise ValueError('Fixture build requires an empty scratch directory')
    sdk = Path(os.environ.get('ANDROID_HOME', Path.home() / 'Library/Android/sdk'))
    version = lambda path: tuple(map(int, re.findall(r'\d+', path.name)))
    tools = max((p for p in (sdk / 'build-tools').iterdir() if (p / 'aapt2').is_file()), key=version)
    platform = select_platform(sdk)
    jar = platform / 'android.jar'
    java = Path(os.environ.get('JAVA_HOME', '/Applications/Android Studio.app/Contents/jbr/Contents/Home'))
    env = dict(os.environ, JAVA_HOME=str(java), QUIETAKE_FIXTURE_PASS=secrets.token_urlsafe(24))

    def run(*args):
        return subprocess.check_output(list(map(str, args)), env=env, stderr=subprocess.PIPE, text=True)

    manifest = ET.parse(SOURCE / 'AndroidManifest.xml')
    manifest.getroot().set('package', package)
    manifest.getroot().find('application').set('{http://schemas.android.com/apk/res/android}label', label)
    manifest.write(workspace / 'AndroidManifest.xml', encoding='utf-8', xml_declaration=True)
    classes, dex = workspace / 'classes', workspace / 'dex'
    classes.mkdir()
    dex.mkdir()
    run(java / 'bin/javac', '--release', '8', '-classpath', jar, '-d', classes, SOURCE / 'ShareReceiver.java')
    run(tools / 'd8', '--min-api', '24', '--lib', jar, '--output', dex, *classes.rglob('*.class'))
    raw, aligned, apk = workspace / 'raw.apk', workspace / 'aligned.apk', workspace / 'fixture.apk'
    run(tools / 'aapt2', 'link', '--manifest', workspace / 'AndroidManifest.xml', '-I', jar,
        '--min-sdk-version', '24', '--target-sdk-version', platform.name.removeprefix('android-'),
        '--version-code', '1', '--version-name', '1', '-o', raw)
    with zipfile.ZipFile(raw, 'a') as archive:
        archive.write(dex / 'classes.dex', 'classes.dex')
    run(tools / 'zipalign', '-p', '4', raw, aligned)
    keystore = workspace / 'fixture.jks'
    run(java / 'bin/keytool', '-genkeypair', '-keystore', keystore, '-alias', 'fixture',
        '-storepass:env', 'QUIETAKE_FIXTURE_PASS', '-keypass:env', 'QUIETAKE_FIXTURE_PASS',
        '-keyalg', 'RSA', '-keysize', '2048', '-validity', '1', '-dname', 'CN=LocalShareFixture')
    run(tools / 'apksigner', 'sign', '--ks', keystore, '--ks-key-alias', 'fixture',
        '--ks-pass', 'env:QUIETAKE_FIXTURE_PASS', '--key-pass', 'env:QUIETAKE_FIXTURE_PASS',
        '--out', apk, aligned)
    run(tools / 'apksigner', 'verify', apk)
    badging = run(tools / 'aapt', 'dump', 'badging', apk)
    observed = re.search(r"^package: name='([^']+)'", badging, re.M)
    if not observed or observed.group(1) != package or 'application-debuggable' not in badging:
        raise ValueError('Receiver APK identity/debugging validation failed')
    if 'uses-permission:' in run(tools / 'aapt', 'dump', 'permissions', apk):
        raise ValueError('Receiver APK must not request permissions')
    keystore.unlink()
    return apk


if __name__ == '__main__':
    with tempfile.TemporaryDirectory(prefix='quietake-share-fixture-') as directory:
        build_receiver(directory, fixture_package())
        print('Offline share receiver builds, signs and validates with an isolated test identity.')
