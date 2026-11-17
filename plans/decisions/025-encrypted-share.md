# 025 Encrypted share

Status: accepted 2026-11-16 (owner): option B, the Quietake share container, as a later step; option A is not chosen. No code yet; B needs a container version decision, frozen vectors and Go support before building.

## Problem

The "Encrypted share" idea sends selected captures as a passphrase-protected archive
instead of plaintext copies. The portable backup format cannot be reused as it is:
its media containers and its ZIP password come from the vault master key, so opening
one would hand the recipient the key to the whole vault. A share needs its own secret.

## Options

A. Standard AES-256 ZIP with a generated passphrase (recommended first step).
   The share dialog offers "Encrypted ZIP". The app writes the selected captures,
   after the usual metadata removal or redaction, into a WinZip AES-256 archive whose
   password is a fresh six-word passphrase from the existing `BackupPassphrase`
   generator. The app shows the passphrase once and the owner sends it by another
   channel. Any ZIP tool with AES support opens it (7-Zip, Keka, many Android file
   managers). Apple's built-in Archive Utility and iOS Files do not open AES ZIPs,
   so iPhone recipients need a third-party app.
   Limits: ZIP hides file contents, not names or sizes; use neutral entry names such
   as `photo-01.jpg`. ZIP AES passphrases can be guessed offline, so the strength is
   the passphrase's six random words, not the cipher.

B. Quietake share container. A new container version with a per-share random key
   wrapped by an Argon2id passphrase, readable by Quietake and the Go recovery tool.
   Stronger and name-hiding, but it is a new format: frozen vectors, Go support,
   documentation and a recipient who has the app. Larger than one iteration.

C. Do nothing. Plaintext share copies with metadata removal and redaction already
   exist.

## Recommendation

Build A, because it works with tools the recipient already has and reuses the
passphrase generator, `archive` package and share pipeline. Keep B as a later step if
recipients using Quietake matter. Either way the vault originals never change and
the temporary archive is deleted after sharing like other share copies.

## Needs the owner

- Go or no-go on A, and whether the iPhone limitation is acceptable.
- Wording for the share dialog and the privacy policy, which says copies are
  unencrypted today.

## Build plan for option B (2026-11-16, not started)

The share bundle is a separate format, not a new version of the `.shtr` container, so the v1
container contract and its frozen vectors stay untouched. It gets its own magic `SHSB`, version byte
and file extension `.quietake-share`.

Proposed layout (all integers big-endian): magic `SHSB`, version `1`, reserved `0`, Argon2id
operations and memory limits (validated like the keyfile: 1-3 operations, 8 KiB-256 MiB), a 16-byte
salt, a 24-byte secretbox nonce, a 48-byte random share key wrapped by the passphrase-derived key, then one
`crypto_secretstream_xchacha20poly1305` body that carries a sequence of entries: a 4-byte name length,
the neutral name (`photo-01.jpg`), an 8-byte content length and the content. The last chunk is tagged
FINAL, so truncation is detected. The passphrase is a fresh six-word phrase from `BackupPassphrase`,
shown once; the vault master key is never involved, which is the whole reason A and B differ from the
portable backup.

Slices, each with tests and its own commit:

1. Format document `docs/share-bundle.md` and frozen vectors `docs/vectors/share.json` (fixed salt,
   nonces and key so the bytes are reproducible). Owner review of the layout before code, because a
   shipped format cannot change.
2. Dart writer and reader in `lib/crypto/share_bundle.dart`, pure and streaming, with tests against the
   vectors and for wrong passphrase, tampering, truncation and oversized parameters.
3. Go reader in `recover/` plus an interop case in `tool/check_interop.dart`, so recipients without the
   app can open a bundle with the command line tool.
4. Share dialog "Encrypted share" using the existing metadata removal and redaction, a passphrase
   screen shown once, and deletion of the temporary bundle like other share copies. Wording needs the
   owner's approval, and the privacy policy sentence that copies are unencrypted must be reviewed.
5. Opening a bundle inside Quietake (import from a received file) with the passphrase.

Risks: entry names and sizes inside the stream are hidden but the total size is visible; passphrase
strength is the only protection against guessing; iPhone recipients need the app or the Go tool.

Owner answer 2026-11-16: the proposed `SHSB` layout is approved. Slice 1 is the format document `docs/share-bundle.md`; vectors are produced by the first Dart writer in slice 2 and then frozen, because libsodium chooses the secretstream header at random.

Slice 2 done 2026-11-16: `lib/crypto/share_bundle.dart` writes and extracts bundles per the spec; it rejects a wrong passphrase, any changed byte, truncation at any length (including on a chunk boundary), trailing data, unsafe or duplicate names, out-of-range cost or chunk size and totals above the cap, and deletes partial output. Vectors are frozen in `docs/vectors/share.json` and guarded by `test/vectors_freeze_test.dart`. The Go reader is slice 3.

Slice 3 done 2026-11-16: `quietake-recover -share FILE -out DIR` (`recover/share.go`, `recover/internal/shtr/share.go`) opens bundles with a masked passphrase prompt, applies the same limits as the Dart reader, and additionally rejects a FINAL chunk of full chunk size. Tests open the frozen Dart vectors and reject flips, cuts, trailing data, bad limits and wrong passphrases without leaving files.

Slice 4 done 2026-11-16: the share dialog has an "Encrypt with a passphrase" checkbox (`Keys.shareEncrypted`). With it on, Choose app first shows a fresh six-word passphrase from `BackupPassphrase.generate` once (`Keys.sharePassphrase`, selectable text, no copy button, Cancel backs out and shares nothing), then `shareMediaCopies(passphrase:)` prepares the usual copies (metadata removal, redaction), writes one `.quietake-share` bundle with neutral entry names (`photo-01.jpg`, `video-02.mp4`), deletes the plain copies and hands only the bundle to the chooser (`application/octet-stream`); everything is removed after sharing like other copies. The passphrase is never stored or logged. Tests: `test/share_media_test.dart` (bundle opens with the passphrase, only the bundle is in the share folder, wrong passphrase fails), `test/share_dialog_test.dart` (passphrase shown before any sharing, back out, share), Android `sharing_test.dart` passes. Strings in en, es, fr, de are drafts for owner approval (decision 030 item D). Not done: slice 5 (open a received bundle in the app), iOS device run, a run with a real recipient. A 64 MiB Argon2 pass takes a few seconds in debug builds; the dialog shows its progress bar meanwhile.

Slice 5 done 2026-11-17: the Import screen has "Open encrypted share" (`Keys.importShare`). The native picker takes a new `pickShare` call on both platforms: one file, extension `.quietake-share` only, private copy up to 513 MiB (the 512 MiB bundle cap plus header). Dart asks for the passphrase (`Keys.importSharePassphrase`, Open, Cancel), extracts the bundle into `quietake-import/opened` inside the private import folder and imports the photos and videos through the normal `MediaImporter` (type checks, size limits, duplicate skip, encryption into the vault). A wrong passphrase or damaged file shows one message and imports nothing. The native cleanup call removes the folder afterwards. Tests: `test/import_screen_test.dart` (wrong passphrase, right passphrase imports a real JPEG, backing out); Android and iOS `import_test.dart` pass, which compiles the native changes. Not verified: the native `pickShare` picker on a device (the picker UI cannot be automated here), a real share between two phones, Argon2 time on a low-end phone. Strings in en, es, fr, de are drafts for owner approval. The policy sentence for item D in decision 030 can now be approved.

Follow-up 2026-11-17: the passphrase field of the open-share dialog is cleared when the app pauses (`_SharePassphraseDialog`), like the other secret fields, because the content stays alive behind the lock screen. Test in `test/import_screen_test.dart`.
