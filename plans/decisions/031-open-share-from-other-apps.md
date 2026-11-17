# 031 Open a share from other apps

Status: accepted 2026-11-17 (owner chose it as the first build-on item). Android slice built; iOS slice not built.

## Problem

A received `.quietake-share` bundle (decision 025) can only be opened by picking it from inside Import. Opening it from Files, mail or a chat app ("Open with Quietake") should land in the same passphrase dialog.

## Decision

- Android registers two `VIEW` filters on `MainActivity` for `content` URIs: the type `application/vnd.quietake.share`, and `application/octet-stream` with a path ending in `.quietake-share`. An unrelated binary file does not offer Quietake (checked with `cmd package query-activities`). `file` URIs are not accepted.
- `IncomingShare` makes one bounded private copy (513 MiB, same limit as the picker) in `cacheDir/quietake-incoming`, deletes stale copies at startup, and claims nothing about the content: the bundle reader decides whether it is a share. The copy is already encrypted with its own passphrase, so holding it while the vault is locked reveals nothing.
- The copy is never taken or shown while the app is locked. `GalleryScreen` asks the `quietake/import` channel (`incomingShare`, which waits for a copy still running) at build and on resume, but only while its tickers are on (they are off behind the lock screen). It then opens `ImportScreen(openIncoming: true)`, which calls `takeIncomingShare`, moves the copy into the import folder (so the normal `clear` removes it) and shows the existing passphrase dialog. Opening, wrong passphrase, cancel and cleanup are the existing paths.
- iOS: a document type for `.quietake-share` and the same take call. Not built; iOS hands over a file URL that must be copied inside the app's access window. The `quietake/import` iOS handler does not know `incomingShare` yet, so the Dart check ignores it there.

## Not verified

A real "Open with" from a Files app or chat app (the filters resolve on the emulator, but no real content URI was opened), a 513 MiB copy, and the dialog appearing after unlock on a device. The sender still labels the bundle `application/octet-stream`; apps that rename the file would not match the path filter. Policy: the encrypted share paragraph in `assets/privacy-policy.json` already covers opening a bundle; add one sentence when iOS ships.

## Checks

Host suite 847 passed (3 new: import screen takes the incoming share, gallery opens it when unlocked, gallery ignores it while locked); `flutter analyze` clean; Android compile, JVM tests and `startup_test.dart` pass.
