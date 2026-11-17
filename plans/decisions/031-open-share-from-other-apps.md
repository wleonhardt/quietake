# 031 Open a share from other apps

Status: accepted 2026-11-17 (owner chose it as the first build-on item). Android and iOS slices built.

## Problem

A received `.quietake-share` bundle (decision 025) can only be opened by picking it from inside Import. Opening it from Files, mail or a chat app ("Open with Quietake") should land in the same passphrase dialog.

## Decision

- Android registers two `VIEW` filters on `MainActivity` for `content` URIs: the type `application/vnd.quietake.share`, and `application/octet-stream` with a path ending in `.quietake-share`. An unrelated binary file does not offer Quietake (checked with `cmd package query-activities`). `file` URIs are not accepted.
- `IncomingShare` makes one bounded private copy (513 MiB, same limit as the picker) in `cacheDir/quietake-incoming`, deletes stale copies at startup, and claims nothing about the content: the bundle reader decides whether it is a share. The copy is already encrypted with its own passphrase, so holding it while the vault is locked reveals nothing.
- The copy is never taken or shown while the app is locked. `GalleryScreen` asks the `quietake/import` channel (`incomingShare`, which waits for a copy still running) at build and on resume, but only while its tickers are on (they are off behind the lock screen). It then opens `ImportScreen(openIncoming: true)`, which calls `takeIncomingShare`, moves the copy into the import folder (so the normal `clear` removes it) and shows the existing passphrase dialog. Opening, wrong passphrase, cancel and cleanup are the existing paths.
- iOS: `Info.plist` exports the type `cam.quietake.share` (extension `quietake-share`, conforms to `public.data`, no MIME claim) and declares it as a document type with rank Owner; open in place is not enabled. `SceneDelegate` handles `scene(_:openURLContexts:)` and the cold-start `urlContexts` (after the Flutter super call, which must always run) and passes the file URL to `IncomingShare` in `PrivateImport.swift`, which makes the same bounded 513 MiB copy in `Caches/quietake-incoming`, removes the system Inbox copy, removes stale copies at startup and answers `incomingShare` and `takeIncomingShare` like Android. Nothing else of the URL is used.

## Verified on the iOS simulator

`xcrun simctl openurl` with a `file:` URL for a `.quietake-share` file copied it into `quietake-incoming` while the app ran, a second open replaced it, and a restart removed it. `startup_test.dart` and `locked_camera_test.dart` pass after the change. The Info.plist review of decision 028 is extended: one document type and one exported type were added, still no URL scheme and no file sharing key.

## Not verified

On iOS the passphrase dialog appearing after unlock, and a real Open in from Files or Mail. A real "Open with" from a Files app or chat app (the filters resolve on the emulator, but no real content URI was opened), a 513 MiB copy, and the dialog appearing after unlock on a device. The sender still labels the bundle `application/octet-stream`; apps that rename the file would not match the path filter. Policy: the encrypted share paragraph in `assets/privacy-policy.json` already covers opening a bundle; draft sentence F in decision 030 awaits the owner.

## Checks

Host suite 847 passed (3 new: import screen takes the incoming share, gallery opens it when unlocked, gallery ignores it while locked); `flutter analyze` clean; Android compile, JVM tests and `startup_test.dart` pass.

## Emulator check and a fixed crash (2026-11-17)

Opening a real `content://` URI (a file in Downloads, via `am start --grant-read-uri-permission`) on the Android emulator showed a launch crash in the first version: `MainActivity.handleLaunch` ran in `onCreate` before the Flutter engine was configured, so the `lateinit` `incomingShare` was not set and a cold start from "Open with" crashed. It is now created on first use, and `configureFlutterEngine` touches it so a normal start still removes copies left by an earlier process. After the fix the cold open copied the exact bytes into `cache/quietake-incoming`, a second open while the app ran (`onNewIntent`) did too, and a normal restart removed the copy. Android compile, JVM tests and `startup_test.dart` pass.

Limit found: the filter with `application/octet-stream` and a `.quietake-share` path pattern does not match a MediaStore URI such as `content://media/external/downloads/<id>`, which carries no file name, and Files, Gmail and most chat apps open attachments that way. Only a sender that supplies `application/vnd.quietake.share` or a URI path ending in the file name lists Quietake. So "Open with" from other apps will often not offer Quietake on Android. Owner call: widen the filter to every `application/octet-stream` file (Quietake would then appear for any unknown binary, and the reader would refuse non-shares), or keep it narrow. Not changed.
