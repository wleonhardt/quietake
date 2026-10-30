import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from tool.ci_scope import select, validate_non_app, completion_ok


class ScopeTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.git('init', '-q')
        self.git('config', 'user.email', 'test@example.invalid')
        self.git('config', 'user.name', 'Synthetic CI test')
        self.put('README.md', '# Test\n')
        self.put('lib/main.dart', 'original')
        self.base = self.commit()

    def git(self, *args):
        return subprocess.check_output(['git', *args], cwd=self.root, text=True).strip()

    def put(self, path, text):
        file = self.root / path
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text(text)

    def commit(self):
        self.git('add', '.')
        self.git('commit', '-qm', 'fixture')
        return self.git('rev-parse', 'HEAD')

    def push(self):
        head = self.commit()
        return select(self.root, 'push', {'before': self.base, 'after': head})

    def test_known_prose_and_website_skip_app(self):
        for path in ['README.md', 'AGENTS.md', 'docs/guide.md', 'plans/next-up.md',
                     'website/index.html', 'website/style.css']:
            with self.subTest(path=path):
                self.put(path, 'updated')
                self.assertEqual(self.push()['mode'], 'non-app')
                self.base = self.git('rev-parse', 'HEAD')

    def test_sensitive_and_unknown_inputs_require_full_checks(self):
        for path in ['assets/privacy-policy.json', 'pubspec.lock', 'lib/main.dart',
                     'android/build.gradle.kts', '.github/workflows/ci.yml',
                     'tool/ci_scope.py', 'tool/e2e.sh', 'docs/vectors/new.md',
                     'docs/recovery-vectors/new.json', 'unknown.txt']:
            with self.subTest(path=path):
                self.put(path, 'updated')
                self.assertEqual(self.push()['mode'], 'full')
                self.base = self.git('rev-parse', 'HEAD')

    def test_rename_app_into_docs_still_requires_full(self):
        (self.root / 'docs').mkdir()
        self.git('mv', 'lib/main.dart', 'docs/moved.md')
        result = self.push()
        self.assertEqual(result['mode'], 'full')
        self.assertIn('lib/main.dart', result['paths'])

    def test_deleted_app_requires_full(self):
        (self.root / 'lib/main.dart').unlink()
        self.assertEqual(self.push()['mode'], 'full')

    def test_nul_safe_unusual_name_is_not_mistaken_for_prose(self):
        self.put('docs/guide.md\nlib/main.dart', 'updated')
        self.assertEqual(self.push()['mode'], 'full')

    def test_missing_base_dispatch_and_mismatched_head_require_full(self):
        for name, event in [('workflow_dispatch', {}), ('push', {}),
                            ('push', {'before': '0' * 40, 'after': self.base}),
                            ('push', {'before': '1' * 40, 'after': self.base}),
                            ('push', {'before': self.base, 'after': '1' * 40})]:
            with self.subTest(name=name, event=event):
                self.assertEqual(select(self.root, name, event)['mode'], 'full')

    def test_symlink_is_not_treated_as_prose(self):
        (self.root / 'docs').mkdir()
        (self.root / 'docs/link.md').symlink_to('../lib/main.dart')
        self.assertEqual(self.push()['mode'], 'full')

    def test_policy_text_and_contact_must_match_bundle(self):
        self.put('assets/privacy-policy.json', '{"contact":"hello@example.invalid","sections":[{"heading":"Privacy","paragraphs":["Approved words"]}]}')
        html = '<html><head><title>Policy</title></head><body><section><h2>Privacy</h2><p>Approved words</p></section><a href="mailto:hello@example.invalid">Contact</a></body></html>'
        self.put('website/app-privacy.html', html)
        validate_non_app(self.root, ['website/app-privacy.html'])
        for changed in [html.replace('Approved words', 'Different words'),
                        html.replace('mailto:hello@', 'mailto:wrong@')]:
            self.put('website/app-privacy.html', changed)
            with self.assertRaises(ValueError):
                validate_non_app(self.root, ['website/app-privacy.html'])

    def test_pr_requires_actual_merge_base_parent(self):
        self.git('checkout', '-qb', 'topic')
        self.put('docs/guide.md', '# Guide')
        topic = self.commit()
        event = {'pull_request': {'base': {'sha': self.base}}}
        self.assertEqual(select(self.root, 'pull_request', event)['mode'], 'full')
        self.git('checkout', '--detach', self.base)
        self.git('merge', '--no-ff', '-qm', 'merge fixture', topic)
        self.assertEqual(select(self.root, 'pull_request', event)['mode'], 'non-app')

    def test_markdown_links_fail_on_missing_file(self):
        self.put('docs/guide.md', '[Missing](absent.md)')
        with self.assertRaises(ValueError):
            validate_non_app(self.root, ['docs/guide.md'])
        self.put('docs/guide.md', '[Readme](../README.md)')
        validate_non_app(self.root, ['docs/guide.md'])

    def test_website_links_and_deleted_targets_are_checked(self):
        self.put('website/index.html', '<html><head><title>Test</title></head><body><a href="gone.html">Go</a></body></html>')
        with self.assertRaises(ValueError):
            validate_non_app(self.root, ['website/gone.html'])
        self.put('website/gone.html', '<html><head><title>Gone</title></head><body></body></html>')
        validate_non_app(self.root, ['website/index.html'])

    def test_non_app_validation_rejects_app_input(self):
        with self.assertRaises(ValueError):
            validate_non_app(self.root, ['assets/privacy-policy.json'])

    def test_completion_cannot_green_missing_failed_or_unknown_steps(self):
        self.assertTrue(completion_ok('full', 'success', 'skipped', 'success'))
        self.assertTrue(completion_ok('non-app', 'success', 'success', 'skipped'))
        for status in ['', 'failure', 'skipped', 'cancelled']:
            self.assertFalse(completion_ok('full', 'success', 'skipped', status))
            self.assertFalse(completion_ok('non-app', 'success', status, 'skipped'))
            self.assertFalse(completion_ok('full', status, 'skipped', 'success'))
        self.assertFalse(completion_ok('unknown', 'success', 'success', 'success'))

    def test_cli_content_failure_cannot_complete_required_check(self):
        self.put('docs/guide.md', '[Broken](missing.md)')
        head = self.commit()
        event = self.root / 'event.json'
        event.write_text(json.dumps({'before': self.base, 'after': head}))
        result_file = self.root / 'scope.json'
        output = self.root / 'github-output'
        script = Path(__file__).with_name('ci_scope.py').resolve()
        command = [sys.executable, str(script)]
        result = subprocess.run(command + ['select', '--event', str(event),
                                '--event-name', 'push', '--output', str(result_file)],
                                cwd=self.root, env={**os.environ, 'GITHUB_OUTPUT': str(output)},
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(output.read_text(), 'mode=non-app\n')
        check = subprocess.run(command + ['check-content', str(result_file)],
                               cwd=self.root, capture_output=True, text=True)
        self.assertNotEqual(check.returncode, 0)
        gate = subprocess.run(command + ['complete', 'non-app', 'success',
                              'failure', 'skipped'], cwd=self.root, capture_output=True)
        self.assertNotEqual(gate.returncode, 0)


if __name__ == '__main__':
    unittest.main()
