import base64
import hashlib
from http.client import HTTPConnection
import threading
import unittest
from unittest.mock import patch
from subprocess import CompletedProcess

from background_check import DavFixture, job_blocks, job_identity
from dev_identity import package_path


class BackgroundFixtureTests(unittest.TestCase):
    def setUp(self):
        self.server = DavFixture()
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        self.client = HTTPConnection('127.0.0.1', self.server.server_port, timeout=3)
        self.headers = {'Authorization': 'Basic ' + base64.b64encode(b'fixture:synthetic-background').decode()}

    def tearDown(self):
        self.client.close()
        self.server.shutdown()
        self.server.server_close()

    def request(self, method, name, body=None, headers=None):
        self.client.request(method, '/vault/' + name, body=body,
                            headers={**self.headers, **(headers or {})})
        response = self.client.getresponse()
        data = response.read()
        return response.status, data

    def test_ciphertext_put_and_no_overwrite_move(self):
        self.assertEqual(self.request('PUT', '.owned', b'encrypted')[0], 201)
        destination = f'http://127.0.0.1:{self.server.server_port}/vault/one.shtr'
        self.assertEqual(self.request('MOVE', '.owned', headers={'Destination': destination, 'Overwrite': 'F'})[0], 201)
        self.assertEqual(self.request('GET', 'one.shtr'), (200, b'encrypted'))
        self.request('PUT', '.another', b'conflict')
        self.assertEqual(self.request('MOVE', '.another', headers={'Destination': destination, 'Overwrite': 'F'})[0], 412)
        self.assertEqual(self.request('GET', 'one.shtr'), (200, b'encrypted'))

    def test_destination_precondition_detects_changed_catalog(self):
        self.request('PUT', 'quietake.catalog', b'old')
        self.request('PUT', '.owned', b'new')
        destination = f'http://127.0.0.1:{self.server.server_port}/vault/quietake.catalog'
        headers = {'Destination': destination, 'Overwrite': 'T', 'If': '<' + destination + '> (["wrong"])'}
        self.assertEqual(self.request('MOVE', '.owned', headers=headers)[0], 412)
        headers['If'] = '<' + destination + '> (["' + hashlib.sha256(b'old').hexdigest() + '"])'
        self.assertEqual(self.request('MOVE', '.owned', headers=headers)[0], 204)
        self.assertEqual(self.request('GET', 'quietake.catalog'), (200, b'new'))

    def test_only_fixture_credentials_are_accepted(self):
        self.headers = {}
        self.assertEqual(self.request('GET', 'one.shtr')[0], 401)
        self.assertEqual(self.server.requests, [])

    def test_worker_writes_are_blocked_until_process_death_checkpoint(self):
        name = '.quietake-upload-fixture'
        self.assertEqual(self.request('PUT', name, b'encrypted')[0], 503)
        self.assertNotIn(name, self.server.files)
        self.server.allow_worker = True
        self.assertEqual(self.request('PUT', name, b'encrypted')[0], 201)

    def test_job_selection_excludes_other_packages(self):
        dump = ('JOB #u0a1/1: other.package/.SystemJobService\nTracking: x\n'
                'JOB #u0a2/2: cam.quietake.app.dev/androidx.work.impl.background.systemjob.SystemJobService\nTracking: x\n'
                'JOB #u0a3/3: club.hubner.shuttered/SystemJobService\nTracking: x\n'
                'JOB #u0a4/4: club.hubner.shuttered.dev/SystemJobService\nTracking: x\n')
        blocks = job_blocks(dump)
        self.assertEqual(len(blocks), 1)
        self.assertIn('/2:', blocks[0])
        self.assertEqual(job_identity(blocks[0]), (None, '2'))

    def test_namespaced_scheduler_jobs_are_selected_on_new_android(self):
        dump = ('  JOB androidx.work.systemjobscheduler:u0a1/4: other.package/SystemJobService\nTracking: x\n'
                '  JOB androidx.work.systemjobscheduler:u0a2/6: cam.quietake.app.dev/SystemJobService\nTracking: x\n')
        blocks = job_blocks(dump)
        self.assertEqual(len(blocks), 1)
        self.assertEqual(job_identity(blocks[0]), ('androidx.work.systemjobscheduler', '6'))

    def test_absent_protected_package_is_valid_baseline(self):
        with patch('dev_identity.subprocess.run', return_value=CompletedProcess([], 1, '', '')):
            self.assertEqual(package_path(['adb', '-s', 'emulator-5556'], 'cam.quietake.app'), '')
        with patch('dev_identity.subprocess.run', return_value=CompletedProcess([], 1, '', 'device offline')):
            with self.assertRaises(RuntimeError):
                package_path(['adb', '-s', 'emulator-5556'], 'cam.quietake.app')
