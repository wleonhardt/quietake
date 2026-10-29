# Quietake recovery

Build the recovery command as `quietake-recover`.

Reads `.shtr` containers with the recovery key or an explicitly enabled NAS backup passphrase. Pure Go, no libsodium, no app: the
tool you reach for when the phone is gone and the NAS share is all that is left.

```bash
cd recover && go build -o quietake-recover .

# from a mounted or downloaded copy of the share
./quietake-recover -key-prompt -dir /Volumes/vault -out ~/restored

# straight from the WebDAV share (HTTPS only; password from the flag or QUIETAKE_WEBDAV_PASS)
./quietake-recover -key-prompt \
  -webdav https://nas.example.com/vault/ -user backup-user -out ~/restored

# with the keyfile and passcode instead of the recovery key
./quietake-recover -keyfile vault.keyfile.json -passcode-prompt -dir ./vault -out ~/restored

# with previously enabled NAS passphrase recovery; the prompt is masked
./quietake-recover -backup-passphrase-prompt -dir ./vault -out ~/restored
./quietake-recover -backup-passphrase-prompt \
  -webdav https://nas.example.com/vault/ -user backup-user -check

# verify every container, write nothing
./quietake-recover -key-prompt -dir ./vault -check
```

`-key-prompt` reads the recovery key privately from the terminal without echo.
Paste it only into that prompt, never into a shell command. The prompt requires
an interactive terminal and cannot be combined with other key/passcode options.
For existing automation, `-key` remains supported, but its value is visible in
process arguments and may remain in shell history. No recovery-key environment
variable or saved credential is added. The temporary input byte buffer is cleared;
Go strings and runtime copies do not provide guaranteed full memory erasure.

`-backup-passphrase-prompt` reads `quietake.recovery.json` (or legacy `tucklight.recovery.json`) from the chosen folder
or WebDAV source and asks for the separate backup passphrase without echo. It
validates the bounded schema and fixed parameters before deriving a key. It cannot be combined with recovery-key, local-keyfile or
passcode flags. There is deliberately no passphrase argument/environment option.
The short phone passcode does not open this envelope. Derivation needs 256 MiB
and may take several seconds. Unknown versions and wrong passphrases fail without
writing output. See [the envelope contract](../docs/nas-recovery.md).

Output names are the container names minus `.shtr`, so `2026-10-17T13-09-35.687974Z.jpg.shtr`
becomes `2026-10-17T13-09-35.687974Z.jpg`. Files are written to `.part` first and renamed when the
FINAL chunk verified. A wrong key, a flipped byte, a swapped chunk or a missing FINAL chunk fails
that file and the exit code is 1.

`go test ./...` checks the implementation against the frozen public synthetic fixtures in
`docs/vectors/`. Never regenerate v1 vectors. The Dart test `test/vectors_freeze_test.dart`
checks the app against the same fixtures. Recovery write-path tests preserve existing output
on verification failure and remove partial plaintext; synthetic WebDAV tests reject redirects
and unsafe URLs. Connections, response headers and individual network reads have a two-minute
inactivity limit. Progressing downloads and local decryption may take longer overall.

## Private library metadata

Recovery recognizes `quietake.catalog` and writes
`quietake.catalog.json`; legacy `tucklight.catalog` retains its own output name after authenticating the entire container. `-check`
verifies it without writing plaintext. The manifest uses the same v1 encryption
format as media; schema version 1 stores album IDs/names and capture filenames
mapped to display names, favorite flags and album IDs. See
`../docs/private-catalog.md`. Older recovery versions still recover media but skip
this manifest. Metadata never instructs the recovery tool to delete media.

WebDAV recovery listings are limited to 16 MiB and 10,000 capture entries, matching
the app. Oversized directory responses fail before recovery output is opened.
Media still authenticates incrementally; valid large captures require disk space.

CLI diagnostics quote filenames and errors so server-controlled control characters
cannot execute terminal escape sequences. On-disk filenames remain unchanged.

Recovered outputs must be single local basenames. Dot targets, nested paths and
backslash separators are excluded before source reads or output writes; Windows
drive/device names also follow the platform's local-path checks. The CLI skips
unsupported names. It does not create nested output paths from remote names.


Schema 2 envelopes use the Quietake purpose and marker; frozen schema 1 envelopes
remain readable. If both recovery filenames exist, recovery stops before prompting
rather than choosing an identity. WebDAV passwords use `QUIETAKE_WEBDAV_PASS`;
update existing scripts that used the old environment-variable name. No master-key
or recovery-passphrase environment variable is introduced.
