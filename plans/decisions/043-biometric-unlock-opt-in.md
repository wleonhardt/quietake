# 043 Biometric unlock is a choice and starts off

Status: accepted 2026-11-18 (owner chose "Bind and opt-in"). Part 1 built; part 2 planned.

## Problem

Decision 033 left two limits. The platform keystore held a copy of the vault key from the first
passcode unlock on, on every install, whether or not the person wanted biometric unlock. And
that copy is not bound to biometrics: the fingerprint or face prompt is a check made by the
app, not a condition the keystore enforces.

## Decision

Part 1, built: the copy exists only by choice.

- Settings, Privacy, "Unlock with fingerprint or face" is a switch that starts off.
- Turning it on asks for the passcode and then stores the copy of the key. Turning it off
  deletes the copy and needs no passcode.
- A passcode unlock, a passcode change or a restore rewrites the copy only when one exists.
  A new vault and a restore from a backup start with the switch off.
- The lock screen offers the biometric button only when the copy exists and the phone has
  biometrics set up, as before.

Part 2, planned: bind the copy to biometrics in the keystore itself.

- Android: a separate storage namespace whose key requires a strong biometric for every use
  (`AndroidOptions.biometric(enforceBiometrics: true, requireBiometricsPerOperation: true)`).
- iOS: a keychain item with the access control flag `biometryCurrentSet`.
- The keystore then shows the system prompt when the key is read, so the app's own prompt
  (`local_auth`) goes away on the lock screen, and newly enrolled biometrics invalidate the
  copy. The device tests keep an unbound copy as their test vault key and need their own store.

## Limits

- Until part 2, the copy is still not bound: on a phone where the app's process or the
  keystore is compromised, the copy can be read without a biometric. It no longer exists
  unless the person turned the switch on.
- Development installs that already hold a copy keep the switch on. No release ever shipped.
- The switch is shown on phones without biometrics too; turning it on there stores the copy
  and the lock screen still offers no biometric button. Part 2 refuses the write on such phones.
- Part 2 changes the unlock flow on both platforms and needs a real phone with enrolled
  biometrics; that check stays with the owner.

## Evidence

Host tests: `test/master_key_store_test.dart` ("the keystore copy exists only while biometric
unlock is on"), `test/settings_access_test.dart` ("fingerprint or face unlock is off until the
passcode turns it on"). Device runs are listed in `plans/review-fixes.md`.
