# 014 Check backup only (restore dry run)

Status: accepted.

## Decision

The restore screen for an encrypted ZIP has a "Check backup only" button. With a
chosen ZIP and its recovery key it runs the same staging step as a restore, which
authenticates every encrypted file and the catalog, and then stops. It says
"Backup checked ... Nothing was restored." It needs no new passcode.

## Reasons and limits

- It reuses `PortableBackup.stage`, so the check is the one a real restore would
  pass or fail. No second verifier can drift from it.
- Nothing is committed: no keyfile, vault file, secure-storage entry or passcode is
  written, and the staged copy is deleted in the existing `finally`.
- The private copy of the chosen ZIP is cleared afterwards like after a restore, so
  the user picks the file again to restore. The message says so.
- It requires a fresh vault, like restore, so it is only reachable where restore is.
- The check proves the ZIP and key match. It does not prove the new passcode, the
  biometric setup or device storage for the real restore.
