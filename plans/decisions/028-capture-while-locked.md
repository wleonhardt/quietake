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
