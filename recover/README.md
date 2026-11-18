# Quietake recovery

Build the recovery command as `quietake-recover`.

Reads `.shtr` containers with the recovery key or an explicitly enabled NAS backup passphrase. Pure Go, no libsodium, no app: the
tool you reach for when the phone is gone and the NAS share is all that is left.

## If you have never built a program

There is no ready-made download yet, so the tool has to be built once. It takes about five minutes.

1. Install Go from <https://go.dev/dl/> (the standard installer for your computer).
2. Download this project: on the project page choose Code, then Download ZIP, and unpack it.
3. Copy your backup files (the ones ending in `.shtr`, plus `quietake.catalog` if it is there)
   from your server into one folder, for example `backup` inside your home folder.
4. Open a terminal (Terminal on macOS, PowerShell on Windows), go into the unpacked project's
   `recover` folder and build the tool:
   `cd recover` then `go build -o quietake-recover .` (on Windows: `go build -o quietake-recover.exe .`).
5. Run it and paste your recovery key when it asks. Nothing shows while you paste; that is intended.
   macOS and Linux: `./quietake-recover -key-prompt -dir ~/backup -out ~/restored`
   Windows: `.\quietake-recover.exe -key-prompt -dir $HOME\backup -out $HOME\restored`
6. Your photos and videos are now in the `restored` folder under their capture names.

What the messages mean:

- `ok "name"`: that file was recovered and checked.
- `FAIL "name"`: that file is damaged or was encrypted with a different key. The others are still
  written. If every file fails, the recovery key is not the one for this backup.
- `recovery key is not 32 bytes of base64`: the key was mistyped or cut short. It is 44 characters
  in groups of four and can end in `=`. Capital and small letters matter.
- `interactive prompt requires a terminal`: run the command directly in a terminal window.
- A warning that the catalog could not be read: files keep the names they have on the server; the
  photos themselves are not affected.

The rest of this page is the reference for every option.

## Reference

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

# open a .quietake-share bundle; the share passphrase is asked without echo
./quietake-recover -share photos.quietake-share -out ~/opened
```

`-share` needs only the bundle's own passphrase and `-out`; it never touches a vault key, keyfile or NAS. See `docs/share-bundle.md`.

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
Your phone passcode does not open this envelope. Derivation needs 256 MiB
and may take several seconds. Unknown versions and wrong passphrases fail without
writing output. See [the envelope contract](../docs/nas-recovery.md).

Output names are the container names minus `.shtr`, so `2026-10-17T13-09-35.687974Z.jpg.shtr`
becomes `2026-10-17T13-09-35.687974Z.jpg`. Files are written to `.part` first and renamed when the
FINAL chunk verified. If the folder holds a readable `quietake.catalog` with the optional
`remoteNames` object (random NAS names, decision 026), each randomly named container is written
under its capture name instead. A mapping is ignored, and the generic name kept, when its file is
not listed, its name is not a plain `.shtr` name, two captures claim one file, or the output name
would collide with another output. A wrong key, a flipped byte, a swapped chunk or a missing FINAL chunk fails
that file and the exit code is 1. When a listed `quietake.catalog` cannot be read, a warning says
that files keep the names they have on the server.

Exit codes: 0 when every file was recovered or checked, 1 when at least one file failed (the others
are still written), 2 for a usage error or a failure before any file was read (wrong options,
unreachable server, wrong key or passcode). A file that already exists in `-out` is replaced only
by a fully verified recovery of the same name; a failed file leaves it untouched.

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
