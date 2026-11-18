# Review fixes queue

Status: active. This is the work queue from the whole-project review of 2026-11-17. The loop takes
the first item that is still `planned`, fixes it with the smallest change, runs the scoped checks
from `development-process.md`, records evidence here and commits. Items that need an owner answer
get the obvious default (or no change), a decision record where one applies, and a line in
`open-questions.md`; they are then marked `blocked` or `complete` with that note. Nothing is pushed.

Status words: planned, active, complete, blocked (needs the owner), deferred (with the reason).

## Done before the queue started

- complete: Setup no longer adopts a key left in the keystore (decision 033, commit `0d9564f`).
- complete: Photos use the full sensor; recording keeps its preset (decision 034, commit `0a33f76`).
- complete: The plain launcher entry switches between two aliases (decision 029 correction, commit `409ffd9`).
- complete: Device tests no longer rely on key adoption (commits `3ffd05d` and the `TestApp.setPasscode` commit).
- Evidence for these four, 2026-11-17: analyzer clean and host suite 875 passed after all of them. Android emulator (API 33), all passing: `launcher_icon_test`, `settings_icon_test`, `lock_test` 7, `startup_test` 6, `recovery_identity_test`, `portable_test` 6, `appearance_test`, `library_layout_test`, `import_test` 5, `privacy_test` 8, `sharing_test` 7, `capture_test`, `capture_failure_test`, `camera_lifecycle_test`, `locked_camera_test`. iOS simulator, all passing: the same files except the two icon tests (`capture_test` skips 2 without a camera, `startup_test` skips 2). Android JVM tests pass. Not run: `backup_test`, `sync_test`, `nas_recovery_test` (they need a server) and the other device files, which these changes do not touch. Not measured: the saved photo size on a real phone; a real tile tap and "Open with" while the plain entry is on.

## A. Small defects in app code

- R01 complete: Startup now also removes the `quietake-import` folder, where an import killed part way leaves plaintext copies. A share still clears only its own folders, because an import may be running. Red and green test in `test/share_media_test.dart`. The received-share folder `quietake-incoming` is separate and untouched.
- R02 complete: Messages from "Show recovery key" (wrong passcode, locked out, unreadable keyfile) now appear under that button in the Recovery card and clear on the next attempt. Red and green check in `test/settings_access_test.dart`.
- R03 complete: Casting sends the title "Photo" or "Video" instead of the capture file name. Red and green in `test/cast_controller_test.dart`. Limits: the label is English on the receiver in every language, and it was not seen on a real Cast receiver.
- R04 complete: JPEG share copies now also lose extended XMP segments, which hold XMP too large for one segment and can carry location. Red and green in `test/exif_strip_test.dart`; the random-damage test still passes.
- R05 planned: "Remove location" does nothing for PNG copies; rebuild them from pixels so no metadata is carried (`lib/gallery/share_media.dart`). Video stays unchanged and the switch text must say so.
- R06 planned: Hidden areas are pixelated while the policy says solid blocks; fill them with one solid colour and correct the in-app sentence in four languages (`lib/gallery/redact.dart`).
- R07 planned: The wrong-passcode lock is checked before the slow key derivation and counted after it, so parallel attempts all pass the check (`lib/vault/master_key_store.dart`).
- R08 planned: `CaptureStore.recover` and `ingest` can work on the same pending folder at once (`lib/camera/capture_store.dart`).
- R09 planned: `Vault.ingestAs` deletes the plaintext even when encryption fails (`lib/vault/vault.dart`); confirm against the import callers before changing.
- R10 planned: `PendingCrypto` clears the file key only on success (`lib/crypto/pending_crypto.dart`).
- R11 planned: `NasRecovery` lists the server without a size bound (`lib/sync/nas_recovery.dart`).
- R12 planned: `SyncController.sync` drops a request made while disconnecting (`lib/sync/sync_controller.dart`).
- R13 planned: `forgetDeleted` never removes remote-name entries of deleted captures (`lib/library/private_catalog.dart`).
- R14 planned: The share bundle writer accepts a one-byte passphrase (`lib/crypto/share_bundle.dart`); the app only writes its own six-word phrase, so enforce the rule in the writer.
- R15 planned: `VaultCrypto.decrypt` may accept bytes after the final chunk; check and add the same refusal the share reader has (`lib/crypto/vault_crypto.dart`). Frozen vectors must keep passing.
- R16 planned: The restore startup gate offers only Retry when resume keeps failing (`lib/backup/restore_startup_gate.dart`).
- R17 planned: One unreadable server object fails the whole sync pass, and a listing that reports size 0 has no download bound (`lib/sync/sync_service.dart`).

## B. Camera

- R20 planned: The status bar icons are dark on the black camera screen in light mode.
- R21 planned: The "Saved" status never clears.
- R22 planned: The backup state icon uses an Android phone glyph on iOS and announces every sync change to screen readers.
- R23 planned: "No camera" and "Camera unavailable" offer no retry.
- R24 planned: Pinch to zoom (decision record first).
- R25 planned: Flash and torch control (decision record first).
- R26 planned: The shutter is a radio-button icon, and during a recording the centre button is dead while Stop is the small left icon.
- R27 planned: Two opaque panels cover about a third of the viewfinder; use scrims.
- R28 deferred: Controls stay on the long edge in landscape; needs a physical device to judge.

## C. Library and viewer

- R30 planned: Multi-select has no delete (decision 015 rules apply).
- R31 planned: Import and Sync are unlabeled icons at the bottom of the actions sheet.
- R32 planned: The grid has no date headers.
- R33 planned: The viewer pages vertically and has no swipe-down to close; check decisions 002 and 008 first.
- R34 planned: Six unlabeled viewer actions with Delete between Share and Cast; group the rare ones under More.
- R35 planned: With Recently deleted on, delete could skip the dialog and offer Undo; the dialog button "Recently deleted" is a noun.
- R36 planned: The viewer title is "2 / 3"; show the capture date and time.
- R37 planned: The eye button stays over the photo; hide the system bars with the chrome.
- R38 planned: `Icons.ios_share` is used on Android.
- R39 planned: Every thumbnail decrypts its whole file into an 8 MB memory cache; store encrypted thumbnails (decision record first; touches sync, backup and format docs).
- R40 deferred: Split the 1,249-line gallery widget; do after the behavior items so tests guard it.

## D. Setup, lock and settings

- R45 planned: Setup and lock errors render below every button; use the field error text.
- R46 planned: No progress is shown while the vault is created.
- R47 planned: No show or hide toggle on passcode fields.
- R48 planned: The recovery key is drawn in a proportional font on iOS; add system monospace fallbacks.
- R49 planned: The recovery key screen can be passed in one tap; ask for one group back (decision record first, wording for owner review).
- R50 blocked: Recovery key format (base64 with `/`, `=`, `I`, `l`) is a format and recovery-tool contract; needs the owner.
- R51 planned: First run is one form with four equal links; split into a welcome choice and a restore page (decision record first, wording for owner review).
- R52 planned: With the plain icon on, the lock screen and the iOS cover still show the name and logo.
- R53 planned: English-only messages reach other languages (`passcodeTooShort`, exception text, the startup error, the name dialog, the policy screen chrome); check decision 021 first.
- R54 planned: Settings has no About or version row.
- R55 planned: `FormBody` clips its scroll content above the home indicator.
- R56 planned: Settings is one long page with an inline server form; give Backup its own screen (decision record first).
- R57 planned: Type scale mixes tight titles with loose body text; the logo is a hard-cornered dark square on light surfaces.
- R58 planned: Predictive back: page transition and the manifest flag.
- R59 blocked: Bind the keystore key to biometrics and make biometric unlock a choice (decision 033; needs real devices).

## E. Android, iOS, recovery tool, CI

- R60 planned: `INTERNET` is declared only in the debug and profile manifests; declare it in main and assert it in `tool/check_bundle.py`.
- R61 planned: Any app can send `LOCKED_CAMERA` and raise the camera over the phone lock screen.
- R62 planned: Method channel arguments use `!!` and can crash the process.
- R63 planned: Folder import trusts the copy target path from Dart on both platforms.
- R64 planned: The folder walk has no cap on folders visited and drops unreadable subfolders silently.
- R65 planned: `VideoPreparation` reads media on the main thread.
- R66 complete: The Gradle wrapper now carries the distribution checksum (value read from `services.gradle.org` for 9.3.1-all; the wrapper checks it on the next fresh download, which was not forced here) and Dependabot watches `/android`.
- R67 complete in part: CI cancels in-progress runs only for pull requests, and the Go step runs `go mod verify` (passes locally). Both files parse as YAML; no workflow linter is installed here and the hosted run is unproven. Blocked part, in `open-questions.md`: running `tool/ci_scope.py` from the base commit instead of the pull request head, and adding a pinned `govulncheck`.
- R68 blocked: CI has no iOS build job and one emulator API level; both cost runner time, owner call.
- R69 planned: iOS has no privacy manifest, no export-compliance key and English-only permission prompts.
- R70 planned: `Podfile` has no platform line.
- R71 blocked: Release build has no code shrinking; turning it on needs a signed-build check by the owner.
- R72 complete: Recovery tool. Done: keyfile read bounded at 64 KiB, a warning for `-key` in arguments, a warning when the catalog cannot be read, recovery key bytes cleared, exit codes and overwrite rule documented. Tests `TestKeyfileReadIsBounded` and `TestUnreadableCatalogIsReported`; `gofmt`, `go vet`, `go test` pass. Not changed, with reasons: replacing an existing output with a verified recovery is deliberate and tested (`TestRecoveryWritesOnlyVerifiedMedia`); stricter share entry names (colon, Windows device names) would change the share bundle contract for both readers, so that is an owner question; the fixed `.part` name and the missing folder cap only concern the user's own output and input folders.
- R73 complete: Tool tests. `grant-on-phone.sh` now taps only buttons of the system permission dialog (package contains `permissioncontroller`); the matcher was checked on two sample screens, not on a phone. Not changed after reading: the `/tmp/quietake-nas-live-synthetic` path in `backup_prompt_check_test.py` is only validated, never created, and `run_bounded_test.py` reads its marker after the runner has already killed the child. Tool suite: 76 tests pass.

## F. Website, wording, documents

- R80 complete, wording awaits the owner: Website. The status now leads the first screen, the hero says who the app is for, the main button goes to the privacy section and the source link is secondary, the Cast sentence says the SDK's analytics cannot be turned off, no text is under 12 px, the hero heading scales down on narrow screens, the policy pages and the 404 page have descriptions, the sitemap lists the app policy, social tags are complete, and the 404 page uses the site style with links. Checked with the repository content checks and in a browser at 320 px (no sideways scroll, heading 70 px, nothing under 12 px). The policy text itself is unchanged. Not done: a 1200x630 social image, an Apple touch icon, a light colour scheme. Nothing is published until this branch reaches main.
- R81 blocked: Website screenshots need owner-approved images.
- R82 planned: In-app wording drafts for owner review: missing plurals, "backup server" instead of three names, "check code" instead of "fingerprint", where to keep the recovery key, passcode-loss warning, error sentences.
- R83 complete: Documents. Fixed the stale random-name sentence in `docs/container-format.md`, the status lines of decisions 026 and 029, and the two Settings paths quoted in `docs/portable-backup.md` and `docs/nas-recovery.md`. Blocked part, now in `open-questions.md`: code and tests cite decisions 027 and 036 to 040 from the private history, which are not in this repository and whose numbers the public records will reach.
- R84 complete: `docs/threat-model.md` and `docs/architecture.md` are written from the source and linked from the README, which now says the listed commands need no device. The threat model states the current limits (keystore copy not bound to biometrics, key stays in memory while locked, 2 MiB library index). Checked with the repository content checks only.
- R85 complete in part: `recover/README.md` opens with numbered steps for someone who has never built a program (install Go, download, build, run on macOS, Linux or Windows) and says what each message means. The Windows commands were written from the tool's behavior and not run on Windows. Blocked part, in `open-questions.md`: publishing ready-made binaries so that no build is needed.

## G. Structure (each needs a decision record and an owner answer before building)

- R90 blocked: Make lock a key boundary: close the session on lock and rebuild it on unlock.
- R91 blocked: Replace the single 2 MiB catalog file with per-record encrypted storage.
- R92 planned: Move hashing, bulk decryption and pixel loops off the UI isolate.
