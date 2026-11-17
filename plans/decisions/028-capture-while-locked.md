# 028 Capture while locked

Status: accepted 2026-11-16 (owner): build on both Android and iOS, split over several iterations. Slice 1 is built (see the build plan below).

## Problem

Opening the camera from the lock screen needs the camera to save without the master key
being in memory, while "Capture. Keep. Yours." and the rule that pending captures survive
until encrypted publication succeeds still hold.

## Proposal

Generate an X25519 key pair at setup. Store the public key unprotected and the secret key
encrypted under the master key. While locked, a capture is encrypted as a secretstream
exactly like a v1 container, except its random 32-byte file key is wrapped with a sealed
box to the public key instead of a secretbox under the master key. The file is a transient
pending format with its own magic and is never uploaded. On the next unlock the app opens
each pending file with the secret key, re-wraps only the 48-byte file key under the master
key and publishes an ordinary v1 container. Final stored files, NAS files, frozen vectors
and the Go recovery tool stay unchanged.

## Risks and costs

- The unlock path must handle a crash between re-wrap and publish; the pending file stays
  until the v1 file is durable.
- A lock-screen camera route needs native entry points on both platforms and must not
  expose the library, catalog or tags. Tags cannot be applied until unlock.
- Plaintext must never touch shared storage before encryption; the camera plugin writes
  to private cache today and that boundary needs a fresh review for this path.
- Existing vaults need a one-time key-pair creation that requires the passcode.
- Largest idea on the list: new pending format, setup change, native lock-screen entry,
  new tests and docs. It should be split across several iterations.

## Needs the owner

- Go or no-go, and whether the lock-screen entry should be allowed on iOS and Android.

## Build plan (2026-11-16)

1. Done: `lib/crypto/pending_crypto.dart`. A pending file is the magic `SHTP`, version 1, a reserved byte, a wrap key sealed to the vault public key (80 bytes), then an ordinary v1 container whose file key is wrapped with that wrap key. Publishing opens the wrap key with the secret key, re-wraps only the 48-byte file key under the master key and copies the rest, so the result is a normal v1 container and the format of stored files does not change. Tests in `test/pending_crypto_test.dart`: round trip at 0, 1, one chunk and 700000 bytes; wrong key and damaged files leave no output. The key pair is not stored anywhere yet.
2. Store the public key next to the keyfile and the secret key encrypted under the master key; create them for new and existing vaults at the next unlock. Needs a keyfile-adjacent file with its own tests.
3. A pending directory in private storage, a locked-state capture path in `CaptureStore`, and publication on unlock that keeps the pending file until the v1 file is durable.
4. Android lock-screen camera entry, then iOS. Neither may expose the library, catalog or tags.

Slice 2 done: `lib/vault/pending_key_store.dart` keeps `vault.pendingkey.json` in the app documents folder (public key in the clear, secret key encrypted under the master key, version 1). `Session.start` creates it without waiting (a failure or an early lock retries at the next unlock). The keyfile, passcode change and v1 containers are not touched. A secret that no longer opens with the master key (vault key replaced by a restore) is replaced by a new pair, because older pending files could not be published anyway. Not covered yet: portable backup and restore do not carry the file; a restore creates a new pair at the next unlock.

Slice 3 done: `lib/camera/locked_capture_store.dart`. `save` seals a capture into `.pending/<id>.<ext>.pending` in the vault folder (hidden from library, sync and portable listings like `.captures`; excluded from iOS backup through the existing `quietake/captures` channel) and deletes the plaintext only after the sealed file is complete. `publishAll` runs from `Session.start` in the background after the key pair exists: each file becomes `<id>.<ext>.shtr` through `Vault.publishPending`, is authenticated through FINAL, and only then is the pending file deleted; a name the owner already deleted is discarded; a failure keeps the file for the next unlock. Tags and the cast-ready conversion are not applied to locked captures. Nothing calls `save` from the app yet: the lock-screen camera entry (slice 4) is next.

Slice 4a done (in-app entry, no OS lock-screen shortcut yet): the app's own lock screen shows a Camera button (`Keys.lockCamera`) only when the vault public key file exists, so a vault never unlocked since slice 2 offers nothing. It opens `LockedCameraScreen`: back camera, photo only, no audio, no library, tags, settings or cast. Each photo is sealed through `LockedCaptureStore` (plaintext deleted after sealing) and a status line says it appears after unlock; the screen closes itself when the app goes to the background. Strings in en, de, es, fr. Host tests in `test/locked_camera_test.dart` (no pair means no button; a photo ends as one `.jpg.pending` file and the camera output is removed); iOS `lock_test.dart` passes. Not verified: a real camera on a device (the simulator has none), and that the capture appears after unlock on a device. Still open: the OS-level entry from the phone lock screen (Android lock-screen shortcut, iOS Lock Screen control), which needs native work and an owner look at what it exposes; video and tags while locked are not planned.

Device check of slice 4a: `integration_test/locked_camera_test.dart` drives the real lock screen Camera button, the real camera, sealing, publication with the vault key and a read of the published JPEG header. It passes on the Android emulator (virtual scene camera, 3 s of test time). On the iOS simulator, which has no camera, it checks that the screen reports no camera instead of hanging, and passes. Not run on a physical phone.

Review fix: two locked saves with the same clock reading overwrote each other's sealed file; the name now moves on by a microsecond on a clash (test with an injected clock). Known remaining edge, not changed: if a published container already has the same microsecond name as a pending capture (a normal capture and a locked one in the same microsecond), publication treats the existing file as the published copy and removes the pending file. A crash between publishing and deleting needs exactly that rule to finish, and the collision is not realistic for one person's phone.

Review fix: when sealing fails in the locked camera, the camera's plaintext photo is now deleted and the screen says "Could not save the photo." (test makes the pending folder path a file). Unlike the unlocked camera, a locked failure has no pending retry copy, so keeping plaintext would only leave an unprotected file behind.

Interop check: `tool/check_interop.dart` now also publishes captures sealed while locked (0, 1, one chunk and 300000 bytes) and the Go recovery tool restores them byte for byte, which proves the published result is an ordinary v1 container. Go tests and `gofmt`/`go vet` were clean and nothing under `recover/` changed.

Owner answer 2026-11-16: build the OS-level entry on both platforms (Android lock screen shortcut, iOS Lock Screen control), in addition to the in-app lock screen button.

## Slice 4b done 2026-11-16: Android Quick Settings tile

`CameraTileService` adds a Quick Settings tile ("Quietake camera", en/es/fr/de) that starts `MainActivity` with the action `cam.quietake.app.LOCKED_CAMERA`. `MainActivity` honors only that action: it asks the Dart side to lock the app first (so an unlocked session never appears over the phone's lock screen), sets show-when-locked and turn-screen-on, and drops both as soon as the activity pauses. The Dart lock screen reads the one-shot flag (`takeLockedCamera` on `quietake/privacy`) at start and on resume and opens `LockedCameraScreen` only when the vault has a key pair, so the tile cannot reach anything the in-app Camera button cannot. `FLAG_SECURE` is unchanged. Tests: two widget tests in `test/locked_camera_test.dart`; the Android `locked_camera_test.dart` still passes and an `am start` with the action does not crash. Not verified: the tile on a real lock screen (some phones ask for unlock before running a tile, which only delays the camera), a physical camera, and the exposed label on a phone that uses the plain icon: the tile label says Quietake, so the owner should decide whether the tile label should follow the plain-icon setting. Any app can start the action, but it only opens the sealed-photo camera, the same as the lock screen button. Next: the iOS Lock Screen control.

Manifest review 2026-11-17: `allowBackup` and `fullBackupContent` are off; both tile services require `BIND_QUICK_SETTINGS_TILE`, so only the system can bind them; `MainActivity` is exported only for launching. An outside app can send it the `LOCKED_CAMERA` action, which locks the app first and shows only the sealed-photo camera, so the worst effect is an unwanted lock and camera screen, never access to the vault.

iOS `Info.plist` review 2026-11-17: App Transport Security allows only local networking, no file sharing or document-open keys, no URL schemes and no background modes are declared, and the usage descriptions match what the app does. No entitlements file exists. No change needed.
