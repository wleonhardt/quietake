# Architecture overview

Status: written 2026-11-17 from the source. It is a map for a new reader; the format documents
in this folder stay the contracts.

## Keys

```
passcode --Argon2id--> key-encryption key --unwraps--> master key (32 random bytes)
                                                          |
recovery key = the master key, base64                     +--> wraps a random file key per container
platform keystore copy of the master key (biometric unlock)
backup passphrase --Argon2id--> wraps the master key in the NAS recovery file (optional)
vault public key  --sealed box--> file keys of photos taken on the lock screen
```

- `lib/vault/master_key_store.dart` owns the keyfile (`vault.keyfile.json`), the keystore copy,
  the recovery key text and unlock throttling. Only the keyfile proves a vault exists (decision 033).
- `lib/crypto/vault_crypto.dart` writes and reads `.shtr` containers: a per-file key wrapped by
  the master key, then libsodium secretstream chunks ending in a FINAL tag.
- `lib/crypto/pending_crypto.dart` and `lib/vault/pending_key_store.dart` let the lock screen
  camera encrypt without the master key (decision 028).

## Life of a capture

1. `lib/camera/capture_screen.dart` takes the photo or video. The camera plugin writes plaintext
   into the app's private cache.
2. `lib/camera/capture_store.dart` moves it into a private pending folder, encrypts it into the
   vault folder through a `.part` file and a rename, and only then deletes the plaintext. A crash
   in between is picked up by `recover()` at the next camera open.
3. `lib/vault/vault.dart` lists, reads, deletes and trashes containers. Titles, favorites, tags
   and remote names live in one encrypted file handled by `lib/library/private_catalog.dart`.
4. `lib/sync/sync_controller.dart` and `sync_service.dart` upload containers and the catalog to a
   WebDAV folder with staged PUT then MOVE, and download what the phone lacks. Sync never infers a
   deletion from a missing file; deletions are recorded explicitly.
5. `lib/gallery/` shows the library. Thumbnails are decrypted into memory only
   (`preview.dart`). Video and Cast read through `lib/media/media_server.dart`, a local HTTP
   server that decrypts on request and needs a random token in the URL.

## Getting data out and back

- Share: `lib/gallery/share_media.dart` writes plaintext copies into a private share folder for
  the system share sheet and clears them afterwards; `lib/crypto/share_bundle.dart` makes the
  optional encrypted bundle.
- Portable backup: `lib/backup/` writes an encrypted ZIP and restores one through a journaled
  transaction (`restore_transaction.dart`) that startup can finish after a crash.
- NAS passphrase recovery: `lib/sync/nas_recovery.dart`.
- Without the app: `recover/` is an independent Go program that reads the same formats. It
  shares no code with the app; `tool/check_interop.dart` and the frozen vectors in `docs/vectors/`
  keep the two in step.

## App shell

- `lib/main.dart` decides between setup, lock and the camera, owns the lock gate and keeps the
  content navigator alive behind it. `lib/session.dart` holds everything that exists only while
  unlocked.
- State is plain `StatefulWidget` and `ChangeNotifier`; there is no dependency container.
  `lib/privacy/` handles the idle timer and the native privacy channel.
- Native code: `android/app/src/main/kotlin/` and `ios/Runner/` provide the privacy cover,
  pickers, background uploads (Android), tiles and the launcher entries. Each feature has its own
  method channel named `quietake/<feature>`.
- Text is in `lib/l10n/*.arb` (English, German, French, Spanish).

## Tests

- `test/`: host tests with fakes for camera, keystore, Cast and WebDAV.
- `integration_test/` with `tool/e2e.sh`: the same app on an emulator or simulator with
  synthetic data only.
- `recover/`: Go tests against the frozen vectors. `tool/`: Python tests for the runners and the
  release bundle check.
