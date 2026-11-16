# 001 Unlock throttling

Status: accepted.

## Decision

`MasterKeyStore.unlockWithPasscode` refuses further tries after five consecutive
wrong passcodes in one app process. The lock lasts 30 seconds, doubles with each
further failure and stops growing at 15 minutes. A correct passcode resets it.
A refused try throws `PasscodeLockedException`, a subtype of
`WrongPasscodeException`, so every existing handler stays correct. The lock
screen shows the wait time.

## Reasons and limits

- The check sits in the store so the lock screen, Settings, change passcode,
  NAS recovery and portable backup share one counter.
- The counter is not persisted. Argon2id already prices each guess, and a stored
  counter could lock the owner out of their own vault. Restarting the app clears
  it, so this slows casual guessing and does not stop an attacker who can
  restart the process or read the app's storage.
- Recovery key restore and biometric unlock are not throttled.
- No keyfile or container format change.
