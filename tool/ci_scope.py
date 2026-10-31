#!/usr/bin/env python3
"""Conservative CI selection and local content checks; never grants release approval."""
import argparse
from html.parser import HTMLParser
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
from urllib.parse import unquote, urlsplit
import xml.etree.ElementTree as ET


SITE_FILES = {'website/index.html', 'website/app-privacy.html', 'website/privacy.html',
              'website/404.html', 'website/style.css', 'website/robots.txt',
              'website/sitemap.xml'}


def non_app(path):
    parts = PurePosixPath(path).parts
    if not parts or path.startswith('/') or '..' in parts or any(ord(c) < 32 for c in path):
        return False
    if path in SITE_FILES or path in {'README.md', 'AGENTS.md'}:
        return True
    return (parts[0] in {'docs', 'plans'} and path.endswith('.md')
            and not path.startswith(('docs/vectors/', 'docs/recovery-vectors/')))


def git(root, *args):
    return subprocess.check_output(['git', *args], cwd=root, stderr=subprocess.DEVNULL)


def select(root, event_name, event):
    result = {'mode': 'full', 'reason': 'unknown comparison; full checks required', 'paths': []}
    try:
        head = git(root, 'rev-parse', 'HEAD').decode().strip()
        if event_name == 'pull_request':
            base = event['pull_request']['base']['sha']
            parents = git(root, 'rev-list', '--parents', '-n', '1', head).decode().split()
            if len(parents) != 3 or parents[1] != base:
                return result
        elif event_name == 'push':
            base = event['before']
            if event['after'] != head:
                return result
        else:
            return result
        if not re.fullmatch(r'[0-9a-f]{40}', base) or base == '0' * 40:
            return result
        paths = git(root, 'diff', '--name-only', '--no-renames', '-z', base, head, '--')
        paths = [p.decode('utf-8') for p in paths.split(b'\0') if p]
        result.update(base=base, head=head, paths=paths)
        if not all(non_app(p) for p in paths):
            result['reason'] = 'app, tooling or unknown path changed'
            return result
        for revision in (base, head):
            for path in paths:
                entry = git(root, 'ls-tree', '-z', revision, '--', path)
                if entry and not entry.startswith(b'100644 blob '):
                    result['reason'] = 'non-regular content input'
                    return result
        result.update(mode='non-app', reason='only allowlisted prose/website inputs changed')
    except (KeyError, TypeError, ValueError, UnicodeError, OSError, subprocess.CalledProcessError):
        pass
    return result


class Page(HTMLParser):
    def __init__(self, text):
        super().__init__(convert_charrefs=True)
        self.links = []
        self.ids = set()
        self.tags = set()
        self.section_depth = 0
        self.capture = None
        self.nodes = []
        self.feed(text)
        self.close()

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        self.tags.add(tag)
        self.links.extend(attrs[k] for k in ('href', 'src') if attrs.get(k))
        if attrs.get('id'):
            self.ids.add(attrs['id'])
        if tag == 'section':
            self.section_depth += 1
        if self.section_depth and tag in {'h2', 'p'}:
            self.capture = (tag, [])

    def handle_data(self, data):
        if self.capture:
            self.capture[1].append(data)

    def handle_endtag(self, tag):
        if self.capture and tag == self.capture[0]:
            self.nodes.append(' '.join(''.join(self.capture[1]).split()))
            self.capture = None
        if tag == 'section':
            self.section_depth -= 1


def check_link(root, source, link, *, website=False):
    url = urlsplit(link)
    if url.scheme or url.netloc:
        return  # No third-party requests or sign-ins in content validation.
    path = unquote(url.path)
    base = root / 'website' if website else root
    target = (base / path.lstrip('/') if path.startswith('/') else source.parent / path) if path else source
    target = target.resolve()
    if not target.is_relative_to(root.resolve()):
        raise ValueError(f'Link leaves repository: {source.relative_to(root)}')
    if target.is_dir():
        target /= 'index.html' if website else 'README.md'
    if not target.is_file():
        raise ValueError(f'Missing local link target in {source.relative_to(root)}: {link}')
    if website and url.fragment and target.suffix == '.html':
        if unquote(url.fragment) not in Page(target.read_text()).ids:
            raise ValueError(f'Missing HTML fragment in {source.relative_to(root)}: {link}')


def validate_non_app(root, paths):
    root = Path(root).resolve()
    if not all(non_app(p) for p in paths):
        raise ValueError('Non-app validation refuses app or unknown inputs')
    for path in paths:
        file = root / path
        if file.exists() and (file.is_symlink() or not file.is_file()):
            raise ValueError('Content must be regular files')
        if file.is_file() and file.suffix == '.md':
            for link in re.findall(r'\]\(([^\s)]+)\)', file.read_text()):
                check_link(root, file, link.strip('<>'))
    if any(p.startswith('website/') for p in paths):
        for file in (root / 'website').glob('*.html'):
            page = Page(file.read_text())
            if not {'html', 'head', 'title', 'body'} <= page.tags:
                raise ValueError(f'Incomplete HTML document: {file.name}')
            for link in page.links:
                check_link(root, file, link, website=True)
        css = root / 'website/style.css'
        if css.is_file():
            for link in re.findall(r'url\([\s\'\"]*([^\s)\'\"]+)', css.read_text()):
                check_link(root, css, link, website=True)
        sitemap = root / 'website/sitemap.xml'
        if sitemap.is_file():
            ET.parse(sitemap)
        policy = root / 'assets/privacy-policy.json'
        if policy.is_file():
            data = json.loads(policy.read_text())
            page = Page((root / 'website/app-privacy.html').read_text())
            expected = [value for section in data['sections']
                        for value in [section['heading'], *section['paragraphs']]]
            if page.nodes != [' '.join(value.split()) for value in expected]:
                raise ValueError('Website policy differs from bundled approved policy')
            if 'mailto:' + data['contact'] not in page.links:
                raise ValueError('Privacy contact mailto differs from bundled policy')


def completion_ok(mode, selection, content, full):
    return selection == 'success' and (
        (mode == 'full' and full == 'success')
        or (mode == 'non-app' and content == 'success'))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    choose = sub.add_parser('select')
    choose.add_argument('--event', type=Path, required=True)
    choose.add_argument('--event-name', required=True)
    choose.add_argument('--output', type=Path, required=True)
    check = sub.add_parser('check-content')
    check.add_argument('selection', type=Path)
    complete = sub.add_parser('complete')
    for name in ('mode', 'selection', 'content', 'full'):
        complete.add_argument(name)
    args = parser.parse_args()
    if args.command == 'select':
        try:
            event = json.loads(args.event.read_text())
        except (OSError, ValueError):
            event = {}
        result = select(Path.cwd(), args.event_name, event)
        args.output.write_text(json.dumps(result, indent=2) + '\n')
        if output := os.environ.get('GITHUB_OUTPUT'):
            with open(output, 'a') as file:
                file.write('mode=' + result['mode'] + '\n')
        print(json.dumps(result))
    elif args.command == 'check-content':
        result = json.loads(args.selection.read_text())
        if result['mode'] != 'non-app':
            raise ValueError('Content-only path requires non-app selection')
        validate_non_app(Path.cwd(), result['paths'])
        print('Selected content checks passed; app checks are inapplicable to these inputs.')
    elif not completion_ok(args.mode, args.selection, args.content, args.full):
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
