#!/usr/bin/env python3
"""Exercise the real masked CLI with explicitly synthetic interoperability data."""
import os
from pathlib import Path
import pty
import select
import subprocess
import sys
import termios
import time
from urllib.parse import urlsplit, urlunsplit

PHRASE = 'synthetic river violet paper lantern canyon'
UNICODE_PHRASE = 'synthetic café violet 🦉 paper lantern canyon'


def validate(binary, root, live=False):
    root = Path(root).resolve()
    if not root.name.startswith('quietake-nas-live-' if live else 'quietake-backup-interop-'):
        raise ValueError('Synthetic interoperability directory required')
    if Path(binary).resolve() != root / 'recover-fixture':
        raise ValueError('Synthetic recovery binary required')
    return root


def live_source(root):
    """Only the newly owned synthetic child, never the configured share itself."""
    url = urlsplit(os.environ['QUIETAKE_WEBDAV_URL'])
    if (url.scheme != 'https' or not url.hostname or url.username or url.password
            or url.query or url.fragment or not url.path.endswith('/')):
        raise ValueError('HTTPS collection URL required')
    return urlunsplit((url.scheme, url.netloc, url.path + root.name + '/', '', ''))


def main(binary, root, *source):
    live = source == ('nas-live',)
    root = validate(binary, root, live)
    wrong = source == ('wrong',)
    unicode = source == ('unicode',)
    output = root / ('wrong' if wrong else 'unicode' if unicode else 'remote' if source else 'local')
    args = [binary, '-backup-passphrase-prompt', '-out', str(output)]
    if source and not wrong and not unicode:
        if not live and (len(source) != 1 or not source[0].startswith('http://127.0.0.1:')):
            raise ValueError('Loopback fixture required')
        args += ['-webdav', live_source(root) if live else source[0],
                 '-user', os.environ['QUIETAKE_WEBDAV_USER'] if live else 'vaultapp']
    else:
        args += ['-dir', str(root / 'containers')]
    master, slave = pty.openpty()
    process = subprocess.Popen(args, stdin=slave, stdout=slave, stderr=slave,
                               env={**os.environ, 'QUIETAKE_WEBDAV_PASS':
                                    os.environ['QUIETAKE_WEBDAV_PASS'] if live else 'secret'})
    sent = False
    observed = bytearray()
    phrase = ('another river violet paper lantern canyon' if wrong else UNICODE_PHRASE if unicode else PHRASE)
    deadline = time.monotonic() + 30
    try:
        while process.poll() is None:
            if time.monotonic() > deadline:
                raise AssertionError('Masked backup prompt deadline')
            ready, _, _ = select.select([master], [], [], 0.05)
            if ready:
                observed.extend(os.read(master, 65536))
            if not sent and b'backup passphrase: ' in observed:
                if termios.tcgetattr(slave)[3] & termios.ECHO:
                    continue
                command = subprocess.check_output(['ps', '-p', str(process.pid), '-o', 'command='])
                assert phrase.encode() not in command, 'Passphrase in process arguments'
                os.write(master, (phrase + '\n').encode())
                sent = True
        while select.select([master], [], [], 0)[0]:
            observed.extend(os.read(master, 65536))
        assert sent, 'No masked prompt'
        assert phrase.encode() not in observed, 'Passphrase echoed'
        assert process.returncode == (2 if wrong else 0), 'Unexpected recovery exit status (output withheld)'
        print('Masked backup prompt: expected result; no echo or argument exposure')
    finally:
        if process.poll() is None:
            process.kill()
        process.wait()
        os.close(master)
        os.close(slave)


if __name__ == '__main__':
    main(*sys.argv[1:])
