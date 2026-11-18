# Review fixes queue

Status: active. This is the work queue from the whole-project review of 2026-11-17. The loop takes
the first item that is still `planned`, fixes it with the smallest change, runs the scoped checks
from `development-process.md`, records evidence here and commits. Items that need an owner answer
get the obvious default (or no change), a decision record where one applies, and a line in
`open-questions.md`; they are then marked `blocked` or `complete` with that note. From 2026-11-17 the owner asked for every commit to be pushed to this branch.

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
- R05 complete, policy wording awaits the owner: With "Remove metadata from photo copies" on, a PNG copy is rebuilt from its pixels, so text, XMP and EXIF chunks are gone; with it off the copy is unchanged. The switch text says so in four languages and the README matches. Red and green in `test/share_media_test.dart`; `integration_test/sharing_test.dart` is updated and runs with the next device batch. Limits: a PNG over 40 megapixels is scaled down and a stored colour profile is dropped. The published policy still says PNG copies are unchanged; draft H in decision 030 proposes the two replacement sentences.
- R06 complete: A hidden area is now one opaque black block, so nothing under it survives in the shared copy, and the share dialog says "covered in black" in four languages (decision 024 change note). Red and green in `test/redact_test.dart`; share tests pass. The editor preview was not looked at on a device.
- R07 complete: A passcode attempt is now counted before the slow key derivation instead of after it, so attempts started together cannot all pass the lock check; a correct passcode still resets the count and an unreadable keyfile is not counted. Red and green in `test/master_key_store_test.dart` ("attempts started together are still counted one by one"). The counter is still kept in memory only, as decision 001 chose.
- R08 complete, no change: `recover` runs only from the capture screen before its camera exists, and a capture needs that camera; a resume or a replacement screen waits for the running capture first. The two cannot overlap today.
- R09 complete, no change: `ingestAs` is used for the importer's private staging copy, which must not outlive a failed import; the external original is never touched (noted in `review-log.md`).
- R10 complete: The file key of a lock-screen capture is now cleared even when re-wrapping it throws. No new test (a memory wipe is not observable); `pending_crypto_test.dart` and the interop check pass.
- R11 complete: The passphrase change path lists the server with the same 16 MiB bound as restore. No new test; the bound itself is covered for sync.
- R12 complete, no change: every path that sets the busy flag ends in a sync (`saveSettings`) or leaves the backup unconfigured (`disconnect`), so a request dropped meanwhile is not lost.
- R13 deferred: Remote-name entries of deleted captures stay in the catalog. Sync needs such an entry to remove the server copy later, so it can only be dropped after the server deletion is confirmed; that belongs with the catalog storage change (R91). Each entry is about 80 bytes.
- R14 complete, no change: the app never takes a typed share passphrase; it generates six words itself (`_askPassphrase`). Enforcing the backup passphrase rule in the writer could reject a generated phrase of short words.
- R15 complete, no change: trailing data is already refused and tested (`vault_crypto_test.dart`, "rejects trailing data, reordered chunks and malformed headers"; Go `TestRecoveryWritesOnlyVerifiedMedia` mode `trailing`).
- R16 complete: After a retry has failed too, the startup gate offers "Discard the unfinished restore" with a confirmation. It removes the prepared copy and, only when no keyfile exists, media that the restore had already moved into the vault folder; an existing vault and the backup are never touched. Strings in en, de, es, fr. Tests: `test/restore_startup_gate_test.dart` and two discard tests in `test/master_key_store_test.dart`. Not driven on a device.
- R17 complete: When the server catalog authenticates with this vault's key, a server file that does not authenticate is skipped: it is not adopted, not uploaded over, not removed and not counted as backed up, and the sync result ends with "N NAS files skipped (unreadable)". Without such a catalog the pass still stops, so originals are never uploaded into another vault's folder (the existing wrong-key test requires this). A download whose size the server did not report is capped at 4 GiB. Tests in `test/sync_test.dart`; the sync, delete, catalog, verification and controller host tests pass. The result text is English only, like the other sync messages.

- Evidence for groups A and B, 2026-11-17, after the last camera commit (`e8a0aa0`): analyzer clean, host suite 886 passed. Android emulator and iOS simulator, all passing on both: `capture_test`, `capture_failure_test`, `camera_lifecycle_test`, `locked_camera_test`, `appearance_test`, `startup_test`, `lock_test`, `privacy_test`, `sharing_test`, `import_test`, `cast_test`. The emulator camera exercised zoom-capable opening, flash start value and the recording swap only as far as those tests go; pinch, the flash button and Retry were not driven on a device.

## B. Camera

- R20 complete: The camera screen asks for light status bar icons in every theme (the lock-screen camera already gets them from its black app bar). Red and green in `test/capture_chrome_test.dart`.
- R21 complete: "Saved securely" and the burst count clear after four seconds; a save with a problem note stays. Red and green in `test/capture_chrome_test.dart`.
- R22 complete: The "on this phone only" state uses a neutral phone glyph, and the backup state is announced to screen readers only when a backup needs attention. No new test; the tooltip and label are unchanged.
- R23 complete: Both states show a Retry button (the existing translated word) that opens the camera again. Red and green in `test/capture_chrome_test.dart`. Not seen on a device.
- R24 complete: Pinch to zoom with a factor label that also resets it (decision 035). Host tests in `test/capture_chrome_test.dart`. Limits: no screen-reader control for zoom, not tried on a phone.
- R25 complete: One button in the top row cycles the photo flash off, automatic and on; it starts off, a recording camera is always off, and a camera that refuses says "This camera has no flash." (decision 035). Strings in en, de, es, fr (translations need native review). Host tests in `test/capture_chrome_test.dart`; host suite 885 passed. The button sits in the top row because the bottom row has no room at 320 px. No torch for video, and not tried on a phone.
- R26 complete: The shutter is drawn as a ring around a disc, and while recording the Stop button moves to the large centre position with the disabled shutter at the side; both buttons keep their keys. Test in `test/capture_chrome_test.dart`; host suite 886 passed. Not seen on a phone.
- R27 planned (owner 2026-11-18): Move the camera controls into bars outside the picture so nothing covers the viewfinder and label contrast stays guaranteed.
- R28 deferred: Controls stay on the long edge in landscape; needs a physical device to judge.

## C. Library and viewer

- R30 complete: The selection bar has Delete. With Recently deleted on, the whole selection moves there after one confirmation; with it off, the confirmation states that the captures are removed for good. Strings in en, de, es, fr. Host test for the dialog and Cancel in `test/gallery_selection_test.dart`; device test "deleting a selection in the library moves all of it to Recently deleted" in `integration_test/recently_deleted_test.dart` passes on the Android emulator and the iOS simulator, with `delete_test` and `library_test`. Host suite 887 passed.
- R31 complete: Import and Sync in the library actions sheet are labelled rows like the others ("Import copies from Files", "Sync with NAS" / "Set up backup" / "Cancel sync"); keys unchanged. Host layout, selection, query and accessibility tests pass after three tests were changed from tooltip to text lookups.
- R32 planned: The grid has no date headers.
- R33 planned: The viewer pages vertically and has no swipe-down to close; check decisions 002 and 008 first.
- R34 planned: Six unlabeled viewer actions with Delete between Share and Cast; group the rare ones under More.
- R35 planned: With Recently deleted on, delete could skip the dialog and offer Undo; the dialog button "Recently deleted" is a noun.
- R36 deferred: The viewer title stays "2 / 3". A date line would make the app bar two lines, and `test/viewer_dialog_test.dart` requires a one-line bar of at most 56 px at double text size. The capture date is in Details.
- R37 planned: The eye button stays over the photo; hide the system bars with the chrome.
- R38 complete: The share buttons use the platform's share glyph (`Icons.adaptive.share`) instead of the iOS one everywhere. No test; the keys and tooltips are unchanged.
- R39 planned: Every thumbnail decrypts its whole file into an 8 MB memory cache; store encrypted thumbnails (decision record first; touches sync, backup and format docs).
- R40 deferred: Split the 1,249-line gallery widget; do after the behavior items so tests guard it.

## D. Setup, lock and settings

- R45 planned: Setup and lock errors render below every button; use the field error text.
- R46 planned: No progress is shown while the vault is created.
- R47 planned: No show or hide toggle on passcode fields.
- R48 planned: The recovery key is drawn in a proportional font on iOS; add system monospace fallbacks.
- R49 planned: The recovery key screen can be passed in one tap; ask for one group back (decision record first, wording for owner review).
- R50 planned (owner 2026-11-18): Show the recovery key as 24 words with the base64 form under "Show as text"; the app and the recovery tool accept both. Needs a format note, vectors for the word form and a decision record (041 or later).
- R51 planned: First run is one form with four equal links; split into a welcome choice and a restore page (decision record first, wording for owner review).
- R52 planned: With the plain icon on, the lock screen and the iOS cover still show the name and logo.
- R53 planned: English-only messages reach other languages (`passcodeTooShort`, exception text, the startup error, the name dialog, the policy screen chrome); check decision 021 first.
- R54 planned: Settings has no About or version row.
- R55 planned: `FormBody` clips its scroll content above the home indicator.
- R56 planned: Settings is one long page with an inline server form; give Backup its own screen (decision record first).
- R57 planned: Type scale mixes tight titles with loose body text; the logo is a hard-cornered dark square on light surfaces.
- R58 planned: Predictive back: page transition and the manifest flag.
- R59 planned (owner 2026-11-18): Bind the keystore key to biometrics on both platforms and add a Settings switch for biometric unlock, off by default (decision 033, second part). Real-phone confirmation stays with the owner.

## E. Android, iOS, recovery tool, CI

- R60 planned: `INTERNET` is declared only in the debug and profile manifests; declare it in main and assert it in `tool/check_bundle.py`.
- R61 planned: Any app can send `LOCKED_CAMERA` and raise the camera over the phone lock screen.
- R62 planned: Method channel arguments use `!!` and can crash the process.
- R63 planned: Folder import trusts the copy target path from Dart on both platforms.
- R64 planned: The folder walk has no cap on folders visited and drops unreadable subfolders silently.
- R65 planned: `VideoPreparation` reads media on the main thread.
- R66 complete: The Gradle wrapper now carries the distribution checksum (value read from `services.gradle.org` for 9.3.1-all; the wrapper checks it on the next fresh download, which was not forced here) and Dependabot watches `/android`.
- R67 complete: CI cancels in-progress runs only for pull requests and the Go step runs `go mod verify`; the selector and `govulncheck` parts are R98.
- R68 complete in part: CI has a macOS job that makes an unsigned simulator build of the app and its control extension (the same command passes locally). The Swift tests are not run: the target holds one empty test, and `xcodebuild test` on the Runner scheme failed locally after seven minutes with "The test runner hung before establishing connection". The job uses `macos-latest`, and the hosted run is unproven until a pull request or a main push runs it. The job is not a required check until the owner adds it.
- R69 planned: iOS has no privacy manifest, no export-compliance key and English-only permission prompts.
- R70 planned: `Podfile` has no platform line.
- R71 complete, no change (owner 2026-11-18): release code shrinking stays off for now.
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

- R90 planned (owner 2026-11-18): Lock closes the session (key out of memory, sync and casting stopped) and unlock builds a new one; the app returns to the camera after unlock. Decision record first.
- R91 planned (owner 2026-11-18): Keep the catalog format and raise its size cap. Found while preparing it: the cap is one of several linked limits. NAS passphrase restore and the recovery tool refuse more than 10,000 captures and a server listing over 16 MiB, and the portable ZIP bounds its catalog entry at 2 MiB. Raising only the catalog cap would let a vault grow past what a restore accepts, so all of them must move together (catalog 8 MiB, restore and recovery tool 40,000 captures, listing 64 MiB, ZIP catalog entry 8 MiB), with a test at each bound and the documents updated. An older app version cannot read a larger catalog. A larger catalog is also re-encoded on every edit on the UI thread, which R92 addresses.
- R92 planned: Move hashing, bulk decryption and pixel loops off the UI isolate.

## H. Added from the owner's answers of 2026-11-18

- Evidence for R05, R06, R16, R17, R93, R97 and the batch delete, 2026-11-18, at commit `40ac3ca`: analyzer clean; host suite 892 passed and one failed in the full run, `camera_recovery_status_test`, which passed alone (the load flake already noted in `next-up.md`). Android emulator and iOS simulator, all passing on both: `sharing_test` 7, `lock_test` 7, `startup_test`, `sync_test`, `delete_test`, `portable_test`, `library_recovery_test`. `sync_test` first failed on both because one case still expected a readable server name; that test was stale since decision 026 and now checks the uploaded bytes. Not driven on a device: the restore gate's Discard button and a skipped server file.

- R93 complete: Creating a brand-new vault clears any saved backup server address and password before the keyfile is written; a failure to clear stops setup like a failed save. Restores keep or set their own details. Red and green in `test/setup_screen_test.dart` ("a new vault starts without a saved backup server").
- R94 planned: Video quality setting with 720p, 1080p and 4K, 1080p by default (decision 034).
- R95 complete: Policy sentences F (a received share is kept privately until unlock) and G ("Include subfolders") are in `assets/privacy-policy.json` and `website/app-privacy.html`, dated November 18, 2026. G replaces the clause "not its subfolders"; the rest of that sentence now starts "Quietake copies up to 20 files at a time". The repository check confirms the website matches the bundled policy. Not published until this branch reaches main.
- R96 complete: `plans/README.md` says that public decision numbers continue from 041 and what the private-history numbers cited in code refer to, as far as the comments state it.
- R97 complete: The Dart and Go share bundle readers (and the Dart writer) refuse an entry name with a colon, a trailing dot or a Windows device name, and `docs/share-bundle.md` states the rule. Red and green in `test/share_bundle_test.dart` and Go `TestShareNamesWindowsCannotHold`; frozen share vectors, Go checks and the interop check pass. Not run on Windows.
- R98 complete: Both existing CI jobs and the new iOS job take the check selector from the base commit; the step was run locally with an edited checkout copy and still used the base copy. A change can still edit the workflow file itself, which only review prevents. The Go step runs `govulncheck` v1.10.0, which reports no vulnerability in code the tool calls. Hosted run unproven.
- R99 complete: `.github/workflows/recover-release.yml` builds `quietake-recover` for macOS (arm64, amd64), Linux (amd64, arm64) and Windows (amd64) when a release is published and attaches them with `SHA256SUMS.txt`. The five cross-builds were run locally with the same commands; the upload step runs only on a real release and is unproven.
