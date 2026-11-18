# 033 A keystore entry without a keyfile is not a vault

Status: accepted 2026-11-17 (owner asked for the fix after the whole-project review). Built.

## Problem

`MasterKeyStore.prepareKey` returned the raw master key found in the platform keystore
(`quietake.master_key`) when no keyfile existed. First-run setup therefore handed an old vault
key to whoever chose a new passcode, with no passcode, biometric or recovery-key proof, and
showed that key as the "new" recovery key.

Seen on the iOS simulator on 2026-11-17: the development sandbox had old test captures and a
keystore entry but no keyfile. Setting a new passcode on the Setup screen opened those captures.

The iOS keychain outlives an uninstall, and the saved NAS address and password live in the same
keychain. Traced in code, not run on a device: delete the app, install it again, set any passcode,
and the first sync would download and decrypt the backup.

`RestoreTransaction.requireFresh` also treated such an entry as an existing vault, so a portable
or NAS restore after an iOS reinstall would have been refused.

## Decision

The keyfile is the only proof that a vault exists on this device.

- `prepareKey` always generates a new key and removes the old keystore entry first.
- `preparePortableKeyfile` (portable and NAS restore) removes the old keystore entry too.
- `requireFresh` no longer counts a keystore entry; it still refuses when a keyfile or any vault
  file exists.

The adoption was written for installs that had a keystore key but no passcode. No build of the
`cam.quietake.app` identity ever shipped that way, so nothing depends on it.

## Limits

- If a keyfile is lost while vault files remain, creating a new vault leaves those files
  unreadable in the library. They are not deleted; "I have a recovery key" on the Setup screen
  or the recovery CLI still opens them with the old recovery key. Setup does not yet warn about
  this case.
- The keystore entry is still the raw master key, stored without a platform biometric access
  rule, and it is written on every passcode unlock. Biometric unlock is a prompt in the app, not
  a property of the stored key, and the user cannot turn it off. Binding the entry to biometrics
  (iOS access control, Android user-authentication-required keys) and making biometric unlock an
  explicit choice are the next steps. They change the unlock flow on both platforms and need
  checks on real devices with enrolled biometrics, so they are not part of this change.
- A saved backup server address and password could survive an iOS reinstall. Since 2026-11-18
  (owner's answer) creating a brand-new vault clears them; restores keep or set their own.

## Evidence

Red and green host tests in `test/master_key_store_test.dart`: "setup never adopts a key left in
the keystore" and "portable restore passes a stale keystore entry and removes it". Device runs
are listed in `plans/next-up.md`.
