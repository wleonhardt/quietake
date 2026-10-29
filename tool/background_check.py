#!/usr/bin/env python3
"""Synthetic native worker process-death probe. Development Android AVDs only."""
import base64
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from urllib.parse import quote, unquote, urlsplit
from xml.sax.saxutils import escape
from xml.etree import ElementTree

from restart_check import validate_android
from dev_identity import APP, validate_package, protected_paths

ROOT = Path(__file__).resolve().parent.parent


class DavFixture(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self):
        super().__init__(('127.0.0.1', 0), DavHandler)
        self.files = {}
        self.requests = []
        self.lock = threading.Lock()
        self.allow_worker = False


class DavHandler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass  # Never log credentials or request bodies.

    def handle_one(self):
        expected = 'Basic ' + base64.b64encode(b'fixture:synthetic-background').decode()
        if self.headers.get('Authorization') != expected:
            self.send_response(401)
            self.end_headers()
            return
        path = urlsplit(self.path).path
        if not path.startswith('/vault/') and path != '/vault':
            self.send_error(404)
            return
        name = unquote(path[len('/vault/'):])
        body = self.rfile.read(int(self.headers.get('Content-Length', '0')))
        status, data, etag = 200, b'', None
        with self.server.lock:
            self.server.requests.append((self.command, name))
            files = self.server.files
            if self.command == 'MKCOL':
                status = 201
            elif self.command == 'PROPFIND':
                status = 207
                entries = ['<D:response><D:href>/vault/</D:href><D:propstat><D:prop>'
                           '<D:resourcetype><D:collection/></D:resourcetype></D:prop>'
                           '<D:status>HTTP/1.1 200 OK</D:status></D:propstat></D:response>']
                for key, value in files.items():
                    entries.append('<D:response><D:href>/vault/' + escape(quote(key, safe='')) +
                                   '</D:href><D:propstat><D:prop><D:resourcetype/>'
                                   '<D:getcontentlength>' + str(len(value)) + '</D:getcontentlength>'
                                   '</D:prop><D:status>HTTP/1.1 200 OK</D:status></D:propstat></D:response>')
                data = ('<?xml version="1.0"?><D:multistatus xmlns:D="DAV:">' +
                        ''.join(entries) + '</D:multistatus>').encode()
            elif self.command == 'HEAD':
                status = 200 if name in files else 404
            elif self.command == 'GET':
                data = files.get(name, b'')
                status = 200 if name in files else 404
                if status == 200:
                    etag = '"' + hashlib.sha256(data).hexdigest() + '"'
            elif self.command == 'PUT':
                if name.startswith('.quietake-upload-') and not self.server.allow_worker:
                    status = 503
                else:
                    status = 204 if name in files else 201
                    files[name] = body
            elif self.command == 'DELETE':
                status = 204 if name in files else 404
                files.pop(name, None)
            elif self.command == 'MOVE':
                destination = urlsplit(self.headers.get('Destination', ''))
                target = unquote(destination.path.removeprefix('/vault/'))
                existing = files.get(target)
                condition = self.headers.get('If')
                tag = '"' + hashlib.sha256(existing or b'').hexdigest() + '"'
                if (destination.netloc != self.headers.get('Host') or
                        not destination.path.startswith('/vault/') or '/' in target or name not in files):
                    status = 400
                elif existing is not None and self.headers.get('Overwrite') == 'F':
                    status = 412
                elif condition is not None and '[' + tag + ']' not in condition:
                    status = 412
                else:
                    files[target] = files.pop(name)
                    status = 204 if existing is not None else 201
            else:
                status = 405
        self.send_response(status)
        self.send_header('Content-Length', str(len(data)))
        if etag:
            self.send_header('ETag', etag)
        self.end_headers()
        self.wfile.write(data)

    do_HEAD = do_GET = do_PUT = do_DELETE = do_MOVE = do_PROPFIND = do_MKCOL = handle_one


def output(*args):
    return subprocess.check_output(args, cwd=ROOT, text=True).strip()


def run(*args):
    subprocess.run(args, cwd=ROOT, check=True)


def wait_for(condition, timeout, label):
    deadline = time.monotonic() + timeout
    while not condition():
        if time.monotonic() > deadline:
            raise RuntimeError(label)
        time.sleep(.25)


def job_blocks(dump):
    return [part for part in re.split(r'(?m)(?=^[ \t]*JOB )', dump)
            if APP in part.split('Tracking:')[0] and 'SystemJobService' in part]


def job_identity(block):
    match = re.search(r'JOB (?:(\S+):)?#?[^/\s]+/(\d+):', block)
    if match is None:
        raise ValueError('Unexpected scheduler job identity')
    return match.group(1), match.group(2)


def main(device):
    adb = ['adb', '-s', device]
    validate_android(device, output(*adb, 'shell', 'getprop', 'ro.kernel.qemu'))
    protected = protected_paths(adb)
    server = DavFixture()
    threading.Thread(target=server.serve_forever, daemon=True).start()
    port = server.server_port
    reverse = f'tcp:{port}'
    with tempfile.TemporaryDirectory(prefix='quietake-background-') as scratch:
        run('flutter', 'build', 'apk', '--debug', '--target', 'lib/main.dart')
        apk = ROOT / 'build/app/outputs/flutter-apk/app-debug.apk'
        sdk = Path(os.environ.get('ANDROID_HOME', Path.home() / 'Library/Android/sdk'))
        aapt = max((sdk / 'build-tools').glob('*/aapt'), key=lambda p: tuple(map(int, re.findall(r'\d+', p.parent.name))))
        badging = output(str(aapt), 'dump', 'badging', str(apk))
        validate_package(re.search(r"^package: name='([^']+)'", badging, re.M).group(1))
        activity = re.search(r"^launchable-activity: name='([^']+)'", badging, re.M).group(1)
        normal = Path(scratch) / 'normal.apk'
        shutil.copyfile(apk, normal)
        run(*adb, 'reverse', reverse, reverse)
        try:
            def probe_command(stage):
                return ['flutter', 'test', 'integration_test/background_probe.dart', '-d', device,
                        '--no-uninstall', f'--dart-define=BACKGROUND_STAGE={stage}',
                        f'--dart-define=BACKGROUND_PORT={port}']

            def probe(stage):
                run(*probe_command(stage))

            probe('seed')
            # Flutter ends the test process after reporting results. Launch the
            # prebuilt normal app at its passcode gate before ordinary am kill.
            run(*adb, 'install', '-r', str(normal))
            run(*adb, 'shell', 'am', 'start', '-W', '-n', f'{APP}/{activity}')
            with server.lock:
                assert 'background-second.mp4.shtr' not in server.files, 'Worker ran before process-death checkpoint'
                before = dict(server.files)
            old_pid = output(*adb, 'shell', 'pidof', APP)
            assert re.fullmatch(r'\d+', old_pid), 'Expected one application process'
            run(*adb, 'shell', 'input', 'keyevent', 'KEYCODE_HOME')
            # am kill spares service processes. Kill only this debuggable app's
            # own UID after Home; unlike force-stop this preserves job eligibility.
            killed = subprocess.run([*adb, 'shell', 'run-as', APP, 'kill', '-9', old_pid],
                                    capture_output=True, text=True, check=False)
            current = subprocess.run([*adb, 'shell', 'pidof', APP], capture_output=True, text=True)
            if killed.returncode != 0 and old_pid in current.stdout.split():
                # API 33 SELinux denies runas_app signals to untrusted_app even
                # with the same UID. ActivityManager can induce a scoped VM crash.
                run(*adb, 'shell', 'am', 'crash', '--user', '0', APP)

            def dead():
                result = subprocess.run([*adb, 'shell', 'pidof', APP], capture_output=True, text=True)
                return old_pid not in result.stdout.split()
            wait_for(dead, 10, 'Application process did not stop')
            package = output(*adb, 'shell', 'dumpsys', 'package', APP)
            assert re.search(r'User 0:.*stopped=false', package), 'Force-stop would invalidate scheduler eligibility proof'
            with server.lock:
                server.allow_worker = True
            blocks = job_blocks(output(*adb, 'shell', 'dumpsys', 'jobscheduler'))
            assert blocks, 'No persisted WorkManager job'
            constraints = '\n'.join(blocks)
            assert 'BATTERY_NOT_LOW' in constraints and 'CONNECTIVITY' in constraints
            assert 'NOT_METERED' in constraints, 'Default unmetered constraint missing'
            namespace, job_id = job_identity(blocks[0])
            options = ['-n', namespace] if namespace else []
            run(*adb, 'shell', 'cmd', 'jobscheduler', 'run', '-f', *options, APP, job_id)

            def received():
                with server.lock:
                    return ('background-second.mp4.shtr' in server.files and
                            server.files.get('quietake.catalog') != before.get('quietake.catalog'))
            wait_for(received, 90, 'Native worker did not transfer pending capture/catalog')
            new_pid = output(*adb, 'shell', 'pidof', APP)
            assert old_pid and new_pid and old_pid != new_pid, 'A new process must perform the upload'
            activities = output(*adb, 'shell', 'dumpsys', 'activity', 'activities')
            resumed = '\n'.join(line for line in activities.splitlines() if 'ResumedActivity' in line)
            assert APP not in resumed, 'Worker launched application UI'
            expected = {}
            with server.lock:
                received_files = dict(server.files)
                requests = list(server.requests)
            for name in ['background-first.jpg.shtr', 'background-second.mp4.shtr', 'quietake.catalog']:
                local = subprocess.check_output([*adb, 'exec-out', 'run-as', APP, 'cat', 'app_flutter/vault/' + name])
                assert received_files[name] == local, 'Ciphertext changed in native transfer'
                expected[name] = hashlib.sha256(local).hexdigest()
            assert not any(name.startswith('.quietake-upload-') for name in received_files)
            assert any(method == 'MOVE' for method, _ in requests)
            assert ('GET', 'background-first.jpg.shtr') not in requests, 'Foreground receipts must prevent old-video downloads'

            def status_marker():
                raw = subprocess.check_output([*adb, 'exec-out', 'run-as', APP, 'cat',
                                               'shared_prefs/background-backup-status.xml'])
                state = ElementTree.fromstring(raw)
                value = state.find("string[@name='state']")
                stamp = state.find("long[@name='time']")
                return (value.text if value is not None else '',
                        int(stamp.attrib['value']) if stamp is not None else 0)

            wait_for(lambda: status_marker()[0] == 'transferred', 10, 'Worker completion was not persisted')
            previous = status_marker()[1]
            with server.lock:
                count = len(server.requests)
            # Keep the test process alive while forcing the newly requested
            # one-time job; Flutter otherwise stops its app after test completion.
            prior_jobs = {job_identity(block) for block in job_blocks(
                output(*adb, 'shell', 'dumpsys', 'jobscheduler'))}
            nudge = subprocess.Popen(probe_command('nudge'), cwd=ROOT,
                                     stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                     text=True, bufsize=1)
            requested = threading.Event()

            def relay():
                for line in nudge.stdout:
                    print(line, end='', flush=True)
                    if 'BACKGROUND_NUDGE_REQUESTED' in line:
                        requested.set()

            threading.Thread(target=relay, daemon=True).start()
            try:
                selected = []

                def new_job():
                    selected[:] = [job_identity(block) for block in job_blocks(
                        output(*adb, 'shell', 'dumpsys', 'jobscheduler'))
                        if job_identity(block) not in prior_jobs]
                    selected.sort(key=lambda item: int(item[1]))
                    return bool(selected) or nudge.poll() is not None

                wait_for(lambda: requested.is_set() or nudge.poll() is not None,
                         90, 'Native request checkpoint missing')
                assert requested.is_set(), 'Native request did not complete'
                new_job()
                if selected:
                    namespace, job_id = selected[-1]
                    options = ['-n', namespace] if namespace else []
                    # A dispatched/completed job can disappear between dump and
                    # force. The native completion checkpoint below is decisive.
                    subprocess.run([*adb, 'shell', 'cmd', 'jobscheduler', 'run', '-f', *options, APP, job_id],
                                   capture_output=True, text=True, check=False)
                if nudge.wait(timeout=45) != 0:
                    raise RuntimeError('Unchanged native pass failed')
            finally:
                if nudge.poll() is None:
                    nudge.terminate()
                    nudge.wait(timeout=10)
            wait_for(lambda: status_marker()[0] == 'transferred' and status_marker()[1] > previous,
                     30, 'Unchanged job did not run')
            with server.lock:
                assert len(server.requests) == count, 'Unchanged vault caused redundant NAS reads'
            probe('verify')
            result = {'old_pid': old_pid, 'worker_pid': new_pid, 'activity_closed': True,
                      'unmetered_and_battery_constraints': True, 'ciphertext_sha256': expected,
                      'worker_requests': len(requests), 'unchanged_pass_network_requests': 0}
            print(json.dumps(result, indent=2))
        finally:
            run(*adb, 'install', '-r', str(normal))
            run(*adb, 'shell', 'am', 'start', '-W', '-n', f'{APP}/{activity}')
            run(*adb, 'reverse', '--remove', reverse)
            server.shutdown()
            server.server_close()
            assert protected_paths(adb) == protected


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('Usage: python3 tool/background_check.py emulator-5554')
    main(sys.argv[1])
