# Next up

## Queue

- Complete protected source acceptance for 1.0.0+5. The Android Back correction
  keeps native Back routed to the restored content navigator after lock/unlock.
  Source regression, focused Android/iOS lock/privacy checks and native Android
  Back verification passed before this version reservation. Preserve those scopes;
  the signed successor and its Play-delivered upgrade still need separate proof.
- Keep brief capture-confirmation timing in controlled-clock widget coverage.
  Device capture checks verify encrypted media, playback and catalog persistence;
  a loaded device can miss the 180 ms flash between test frames.
- Finish internal Play validation, report coverage and data-preserving upgrades.
  Preserve original vaults and encrypted backups; restore old backups only into
  separate empty targets. Source CI is not signed-artifact or store evidence.
- Keep both protected checks and the existing scoped validation/deadline rules.
  Do not bypass failures or repeat full suites without a concrete reason. Seen twice at load average ~6 (emulator and Chrome running): `sync_controller_test` (fake WebDAV "Connection closed") and `camera_recovery_status_test` failed in the full run, passed alone and in `--concurrency=4` (722 passed); treat as load flakes, not defects.
- Coverage run (`flutter test --coverage`, 92.6% total at iteration 91, 590 tests passing) lowest files: `portable_screen.dart` 70%, `nas_recovery_screen.dart` 72%, `authenticator.dart` now 17 of 18 lines (five error-path tests added; only the unreachable loop-end return is uncovered), `capture_screen.dart` 86%. `backup_screen.dart`'s Cancel check button needs a stalled WebDAV verify (device e2e covers it). `portable_screen.dart` remaining gaps need real export/restore I/O or lifecycle pause during prepare (widget-zone hang risk). Older list: `import_screen.dart`
  22% (now covered by `import_screen_test.dart`), `settings_screen.dart` 51% (connection test paths now covered by
  `settings_connection_test.dart`; idle timeout, recovery prompt, disconnect and save/disconnect storage failures now covered by `settings_access_test.dart`; change-passcode success from Settings and error branches now covered by `change_passcode_failure_test.dart`; Android-only background rows remain),
  `background_uploads.dart` 55% (now covered), `nas_recovery_screen.dart` 62% (restore-mode validation and clearing of typed secrets on app pause now covered by
  `nas_restore_validation_test.dart`; change-mode validation in `nas_change_validation_test.dart`; the committed change/disable success flows still need a locking server). Take these next.
- Open: a host test that drives real first-run Setup through the recovery screen while
  `Session.start` fails (documents path is a file) segfaults flutter_tester. Calling
  `SetupScreen.onUnlocked` directly after writing the keyfile does not. Cause unfound; the
  crash may be a test-process artifact, but a native key-use-after-dispose is unproven either way.
- Next: continue `lib/` bug review. Read so far with no defect found (incl. `sync_controller.dart`, well covered):
  `media_server.dart`, `lock_screen.dart`, `restore_transaction.dart`,
  `capture_store.dart` (atomic `encryptFile` protects the
  prepared-video overwrite), `privacy_controller.dart`, `master_key_store.dart`, `webdav_client.dart` and the
  push path of `sync_service.dart`. Store-level passcode minimum is enforced
  only at UI/NAS entry points (tests rely on short ones). `background_uploads.dart`, `sync_settings.dart` and `backup_screen.dart` read, no defect (all covered by tests). Still to read:
  nothing in `sync/`. `main.dart` lifecycle and `sync_service.dart` pull path read; `exif_location.dart`
  and `import_media.dart` read, no defect (XMP geotags stay by documented design; a failed import
  still spends batch size budget, minor). `vault.dart` and `share_media.dart` read, no
  defect (`Vault.ingestAs` deletes its plaintext even when the name collides; only the importer's
  private staging copy is affected and microsecond names make that unreachable). `nas_recovery.dart` and
  `portable_backup.dart` read, no defect. Sweep of async button handlers and `SyncSettings`/keyfile callers found only the Settings gap fixed above; `_backgroundLock` in `main.dart` would skip locking if `hasKeyfile` threw before the first check finished, which `File.exists` does not realistically do (not changed). Doc drift check (iterations 47-48, incl. `website/app-privacy.html` idle default, import/share location wording, limits): NAS recovery KDF parameters, 16 MiB/10,000-capture list bounds, portable 2 GiB/10,000-file limits and passcode minimum match `lib/`. iOS e2e after this branch's app fixes: `startup_test.dart` (4 pass, 2 skipped, 31.9 s) and `privacy_test.dart` (8 pass, 103.4 s) pass; Setup segfault theory (RecoveryScreen builder reusing a disposed key) ruled out because `push` completes after the route is gone. Empty-catch sweep (iteration 59): all swallowed errors are best-effort cleanup in `finally` blocks (unlock lease, native clear/cancel, sink close); no defect. Unread: `vault_crypto.dart` (frozen vectors), `viewer_screen.dart` share/delete/video-open paths read, handled with snackbars, no defect (device e2e covers the rest). `capture_screen.dart` capture, stop and ingest paths read: failed stop clears recording state, no plaintext handled outside `CaptureStore`; no defect. Add a failing test per bug found.
- NAS and simulator checks are authorized for the dev loop. The home NAS needs
  WebDAV credentials that live in HubnerDocs `.secrets`, which this loop must
  not read. A real-NAS run needs a test credential and an empty test folder
  handed over by the owner; until then loopback WebDAV tests stand in.

## Feature ideas (owner answers 2026-11-16, build one small item per iteration, in this order)

Each idea keeps the privacy boundaries in AGENTS.md and needs a decision record first.

1. Slideshow keep-awake: DONE (decision 017). Own `quietake/screen` channel; host test with mocked channel; iOS and Android emulator viewer tests pass; the actual dimming is not observable in them.
2. Albums (tags) cover choice: DONE (decision 018): optional `covers` field plus Tags screen thumbnail, Set cover and Clear cover. Viewer shortcut not built. Host test covers the empty picker only; pick and clear run in `library_test.dart` on devices.
3. Share EXIF strip: DONE (decision 019): JPEG share copies keep only orientation; XMP, IPTC, comments and MPF go too; policy and website wording updated and awaits owner review. Video metadata removal is a later item (meaning unconfirmed).
4. Folder import (decision 020): DONE. `FolderImport` pipeline with encrypted resume ledger, native pickers (`quietake/folder`, Android SAF tree, iOS folder picker), and the Choose folder button with progress and resume. Subfolders not walked. Policy and website sentence added, awaits owner review. Device tests mock the picker channel over real files; the real system folder picker was never driven on a device.
5. Localization (decision 021): DONE for every app screen in es/fr/de (slices 1-5, incl. Settings, portable backup, NAS recovery, tag cover, restore startup). Stays English by decision: vault, sync, import, share and restore layer messages, policy, website, privacy policy screen title/error, `main.dart` startup text. The import and share explanations describe privacy behavior; owner should review their translations. All translations need native review. Feature ideas now all wait for owner go/no-go (decisions 025-029); work on coverage and bug review meanwhile.
6. Storage view: owner said "whatever is best": drop cache prune (previews are memory only) and pending-upload count; no work planned.
7. NAS restore dry run: owner says the test credentials are in bw-cli. Needs the vault unlocked by the owner (a master password is never typed by the agent); see Queue note.
8. Recently deleted is finished (decision 015, policy wording approved and applied).

Ideas from related privacy camera and vault projects (added 2026-11-16, none started; checked against `lib/`, none exists yet):

- Lock now: DONE (decision 023): the Gallery button existed; Android Quick Settings tile added (`LockTileService`, bridge to the `quietake/privacy` channel, `ScreenPrivacy.onLockNow`, es/fr/de labels). Host test covers the Dart handler; Android build, install, service registration and `privacy_test.dart` pass. Not verified: an actual tile tap locking an unlocked app (`cmd statusbar click-tile` ran without error but no unlocked vault was driven); iOS has no equivalent.
- Recovery key drill: first step DONE (decision 022): Settings "Check my recovery key" compares a typed key with the vault key, es/fr/de, host tests; Android and iOS privacy and portable device tests still pass (no device test drives the dialog). The periodic reminder and a saved last-checked date are not built; they need a storage decision and owner-reviewed wording.
- Redacted share copies: DONE for one photo (decision 024): `redactToPng`, `RedactScreen` (drag, undo, Done) and a share dialog button; copy shares as a metadata-free PNG, es/fr/de text, host tests; `sharing_test.dart` passes on both devices. Section chips (3x3 thirds) give keyboard and screen-reader use; finer placement, face detection, a device test of the editor, multi-photo redaction.
- Encrypted share: decision 025 proposed, no code. The portable format cannot be reused (its secret is the vault key); recommended option A is an AES-256 ZIP with a generated six-word passphrase. Needs owner go/no-go and wording (iPhone Files cannot open AES ZIPs).
- Capture while locked: decision 028 proposed, no code (transient sealed pending format, v1 unchanged; split over several iterations). Original idea: open the camera from the lock screen and seal each capture to a vault public key...
- Provenance proof: decision 027 proposed, no code (linkability trade-off). Original idea: at capture, record a SHA-256 hash and time in the private catalog and sign it wi...
- NAS metadata hardening: decision 026 proposed, no code (option A random remote names). Original idea: pad uploads to size buckets and use random remote names, so the server learns le...
- Neutral app icon: decision 029 proposed, no code (needs artwork). Original idea: an optional plain icon and name (Tella camouflage) through an Android activity a...

## Done

- Feature from the ideas list: backup check reminder (decision `005-backup-check-reminder.md`). The last full check date is saved per share and Check backup shows a reminder after 30 days or when never checked. Tests in `sync_settings_test.dart`, `backup_verification_test.dart` and `backup_screen_test.dart`. Reminder shows only after the first sync of a launch; no notification. Host suite 627 passed, analyzer clean, iOS `backup_test.dart` passed (4 cases, 56.3 s). Android not run.
- Feature from the ideas list: "Check backup only" on the ZIP restore screen (decision `014-restore-dry-run.md`), staging and authenticating without committing. Device test in `integration_test/portable_test.dart` (iOS, 6 cases, 82.8 s); host test for the missing-input message. Host suite 643 passed, analyzer clean. Android not run.
- Feature from the ideas list: Moments (decision `013-moments.md`): month list from file names on the Tags screen, opening the Library filtered by month (`LibraryQuery.month`, removable chip). Tests: `library_query_test.dart`, `moments_screen_test.dart`, `gallery_selection_test.dart`. Host suite 642 passed, analyzer clean, iOS `library_layout_test.dart` passed (1 case, 66.7 s). Android not run; extra Tags app bar icon fit on narrow screens is only checked by that iOS run.
- Feature from the ideas list: burst of five photos on shutter long press (decision `012-burst-capture.md`), sequential through the normal private save path; test `capture_burst_test.dart`. Found: the shutter's default tooltip claims the long press (manual trigger via `TooltipTheme`); the gesture and custom action sit in `MergeSemantics` so the shutter keeps one labeled node. Host suite 638 passed, analyzer clean, iOS `capture_test.dart` passed (1 case, 2 skipped, 49.3 s). Android and a real device burst not run.
- Features from the ideas list, details in their decision records `006` to `011`: capture grid overlay, Tags sort by count, viewer slideshow, tap to focus and meter, capture self timer, focus and exposure lock. Each has host tests and passed iOS e2e; Android emulator later passed the capture, library and viewer tests.
- Sanity run (iterations 150 and again after Recently deleted): Go recovery checks and `dart run tool/check_interop.dart` pass (nothing under `recover/` or crypto changed since). `docs/portable-backup.md` now describes Check backup only; no other doc drift found for the new camera, viewer, Moments or Tags features (README and website do not list them).
- Bug fixed: a failed camera lens switch left a dead controller (`CameraController.setDescription` closes the old camera before opening the new one), so the preview and shutter stopped working. `_flipCamera` now reopens the camera on the same lens and still shows "Could not switch camera. Try again." (red/green in `camera_recording_start_test.dart` with a fake that rejects a closed camera). Host suite 594 passed, analyzer clean, iOS `camera_lifecycle_test.dart` passed (2 cases, 35.1 s). Android not rerun; a real failing switch was not tried on a device. Same file also covers a denied microphone and a camera that cannot open with audio ("Could not start video", photo preview returns). `camera_cast_orientation_test.dart` covers landscape while casting; `camera_album_test.dart` covers the unreadable tag list message. Remaining `capture_screen.dart` gaps: recording paths and some controls.
- Host test (`camera_cast_orientation_test.dart`): landscape follows a cast session, a refused lock shows "Could not update camera orientation.", a photo while casting loads on the TV (skipped without a LAN address). Remaining `capture_screen.dart` gaps: recording paths and some controls.
- Host tests, iterations 55-87, all passing and no defect: gallery Reset view, Set up backup, vault Retry, viewer return and catalog Retry (`gallery_selection_test.dart`); viewer swipe, zoom, oversize photo and video pause/resume (`viewer_actions_test.dart`, `viewer_test.dart`, `viewer_video_test.dart`); cast picker connect, Settings subscreens, share retry, Setup restore entries; catalog size limits (`private_catalog_test.dart`); idle lock (`idle_lock_test.dart`); post-restore lock screen (`app_start_failure_test.dart`). Lessons: tap handlers whose continuation does file IO must run inside `tester.runAsync`, and pushed screens that start file IO need pumping inside `runAsync`.
- Bug fixed: cancelling the Settings "Show recovery key" passcode prompt disposed its text controller while the dialog was still animating out (debug assertion "TextEditingController was used after being disposed"). The prompt is now a small widget that owns its controller (red/green `settings_access_test.dart`, which also covers empty-save and unreadable-keyfile messages). Host suite 578 passed, analyzer clean, iOS `lock_test.dart` passed (7 cases, 74.4 s). Android not rerun. Sweep of every `TextEditingController` in `lib/`: all others are `State` fields disposed in `dispose`; no other dispose-after-pop case.
- Bug fixed: typing in the NAS recovery and portable backup fields (soft keyboard sends no pointer or hardware key events) did not reset the idle-lock timer, so a 1-minute timeout could lock mid-entry and clear the NAS draft. Their fields now call `PrivacyScope.activity()` like Settings and Change passcode (red/green `typing_activity_test.dart`). Host suite 560 passed, analyzer clean, iOS `portable_test.dart` (5 cases, 73.8 s) and `nas_recovery_test.dart` (6 cases, 146.5 s) passed. Android not rerun. Other fields not changed: name/tag/search entries are short; Setup has no session timer.
- Bugs fixed earlier: Gallery Settings with unreadable saved NAS details now shows "Could not read saved NAS details. Try again."; after a failed session open Setup no longer reappears and the lock screen shows "Could not open the vault" (`gallery_selection_test.dart`, `app_start_failure_test.dart`).
- A widget test that ran the full export (isolate worker plus file IO) under
  `testWidgets` hung with no output after 3 minutes even with `runAsync` polling.
  Not diagnosed further; export success/save paths stay covered by
  `portable_backup_test.dart` and `integration_test/portable_test.dart`.
- Widget tests that delete the last capture, delete a tag or merge tags pass their body, then
  `session.close()` hangs because `catalog.load()` never completes in the widget zone. A plain
  `test()` running create, merge, delete, load and close on `PrivateCatalog` finishes at once,
  so the catalog is not stuck; this is a widget-test zone artifact. Success paths stay covered by
  `private_catalog_test.dart` and device e2e; widget success tests are omitted until the zone
  cause is found.
- `testWidgets` swaps in a mock HTTP client answering 400; loopback `FakeWebDavServer` tests set `HttpOverrides.global = null` first.
- Widget tests that touch real files must start that IO inside `tester.runAsync` (also a tap whose handler writes); bare file IO in `testWidgets` never completes.
- The 1.0.0+4 source passed both protected checks and complete hosted Android
  acceptance. Offline policy access, native notices and the published policy match.
- Source uses MPL 2.0 with independent recovery contracts and synthetic tests.
- Root privacy gates, encrypted backup and recovery, explicit sharing and Cast
  retain their established boundaries. The Back correction changes navigation
  ownership without changing encryption or vault identity.
- Release preparation retains immutable artifacts, private symbols and separate
  owner-controlled app/upload signing identities. Public CI has no signing or
  publishing credentials.
