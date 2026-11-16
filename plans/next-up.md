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
  Do not bypass failures or repeat full suites without a concrete reason.
- Coverage run (`flutter test --coverage`, 92.6% total at iteration 91, 590 tests passing) lowest files: `portable_screen.dart` 70%, `nas_recovery_screen.dart` 72%, `authenticator.dart` 83%, `capture_screen.dart` 86%. `backup_screen.dart`'s Cancel check button needs a stalled WebDAV verify (device e2e covers it). `portable_screen.dart` remaining gaps need real export/restore I/O or lifecycle pause during prepare (widget-zone hang risk). Older list: `import_screen.dart`
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

## Feature ideas (planned, unscheduled)

Each idea keeps the privacy boundaries in AGENTS.md and needs a decision record before structural work. None is started.

- Recently deleted: keep deleted captures encrypted for 30 days and offer restore. Backup sync must still never infer deletion from absence.
- Capture options are done (grid, tap-to-focus, focus/exposure lock, self timer, burst). Possible follow-ups: a burst size choice, a real-device capture pass.
- Albums: cover choice (the Moments month view is done).
- Viewer: keep the screen awake during the slideshow only while the vault is unlocked (needs a plugin decision; the slideshow itself is done).
- Share: per-share option to strip all EXIF fields, not only GPS; video location strip is a separate, larger item.
- Backup: a restore dry run that checks without writing (the check reminder is done).
- Storage view, rest: what is pending upload, and a safe prune of re-creatable caches only (the count and encrypted size are done).
- Import: folder import with progress and a resume after interruption, using the existing 10,000-file limits.
- Localization: extract strings and add one second language; policy text stays reviewed by the owner.

## Done

- Feature from the ideas list: backup check reminder (decision `005-backup-check-reminder.md`). The last full check date is saved per share and Check backup shows a reminder after 30 days or when never checked. Tests in `sync_settings_test.dart`, `backup_verification_test.dart` and `backup_screen_test.dart`. Reminder shows only after the first sync of a launch; no notification. Host suite 627 passed, analyzer clean, iOS `backup_test.dart` passed (4 cases, 56.3 s). Android not run.
- Feature from the ideas list: Moments (decision `013-moments.md`): month list from file names on the Tags screen, opening the Library filtered by month (`LibraryQuery.month`, removable chip). Tests: `library_query_test.dart`, `moments_screen_test.dart`, `gallery_selection_test.dart`. Host suite 642 passed, analyzer clean, iOS `library_layout_test.dart` passed (1 case, 66.7 s). Android not run; extra Tags app bar icon fit on narrow screens is only checked by that iOS run.
- Feature from the ideas list: burst of five photos on shutter long press (decision `012-burst-capture.md`), sequential through the normal private save path; test `capture_burst_test.dart`. Found: the shutter's default tooltip claims the long press (manual trigger via `TooltipTheme`); the gesture and custom action sit in `MergeSemantics` so the shutter keeps one labeled node. Host suite 638 passed, analyzer clean, iOS `capture_test.dart` passed (1 case, 2 skipped, 49.3 s). Android and a real device burst not run.
- Feature from the ideas list: long press on the preview locks focus and exposure until the next tap (decision `011-focus-exposure-lock.md`); tests in `capture_grid_test.dart`. No real camera tried. Host suite 637 passed, analyzer clean, iOS `camera_lifecycle_test.dart` passed (2 cases, 35.3 s). Android not run.
- Feature from the ideas list: capture self timer, off/3 s/10 s (decision `010-capture-timer.md`); tests `capture_timer_test.dart` and `capture_timer_cancel_test.dart` (cancel test mutation-checked). Host suite 635 passed, analyzer clean, iOS `capture_test.dart` passed (1 case, 2 skipped, 48.4 s). Android and a real timed capture on a device not run.
- Feature from the ideas list: tap to focus and meter on the camera preview with a 0.8 s ring (decision `009-tap-to-focus.md`). Tests in `capture_grid_test.dart`. Not tried on a real camera: simulators have no focus hardware. Found on the way: a `GestureDetector` over `CameraPreview` needs `HitTestBehavior.opaque`, or the texture never receives the tap. The preview also needed a semantic label ("Camera preview", hint "Tap to focus"): `camera_controls_layout_test.dart` failed on an unlabeled tappable node. Host suite 633 passed, analyzer clean, iOS `camera_lifecycle_test.dart` passed (2 cases, 35.2 s). Android not run.
- Feature from the ideas list: viewer slideshow (decision `008-viewer-slideshow.md`), 4 s per photo, stops at a video or the last capture, no keep-awake. Tests in `viewer_actions_test.dart`. Host suite 631 passed, analyzer clean, iOS `delete_test.dart` passed (5 cases, 67.3 s). Android not run.
- Feature from the ideas list: Tags screen sort by capture count (decision `007-tags-sort-by-count.md`), session-only; test in `albums_screen_test.dart`. Host suite 629 passed, analyzer clean, iOS `library_test.dart` passed (1 case, 164.3 s). Android not run.
- Feature from the ideas list: capture grid overlay (decision `006-capture-grid.md`), a Show/Hide grid button drawing thirds over the preview, session-only, never in captured media. Test `capture_grid_test.dart`. Host suite 628 passed, analyzer clean, iOS `capture_test.dart` passed (1 case, 2 skipped, 48.4 s). Android and narrow-screen layout of the extra button not checked.
- Iteration 100 sanity run: Go recovery checks and `dart run tool/check_interop.dart` pass. Full host suite at iteration 104: 599 passed, analyzer clean.
- Bug fixed: a failed camera lens switch left a dead controller (`CameraController.setDescription` closes the old camera before opening the new one), so the preview and shutter stopped working. `_flipCamera` now reopens the camera on the same lens and still shows "Could not switch camera. Try again." (red/green in `camera_recording_start_test.dart` with a fake that rejects a closed camera). Host suite 594 passed, analyzer clean, iOS `camera_lifecycle_test.dart` passed (2 cases, 35.1 s). Android not rerun; a real failing switch was not tried on a device. Same file also covers a denied microphone and a camera that cannot open with audio ("Could not start video", photo preview returns). `camera_cast_orientation_test.dart` covers landscape while casting; `camera_album_test.dart` covers the unreadable tag list message. Remaining `capture_screen.dart` gaps: recording paths and some controls.
- Host test (`camera_cast_orientation_test.dart`): landscape follows a cast session, a refused lock shows "Could not update camera orientation.", a photo while casting loads on the TV (skipped without a LAN address). Remaining `capture_screen.dart` gaps: recording paths and some controls.
- Host tests, iterations 55-87, all passing and no defect: gallery Reset view, Set up backup, vault Retry, viewer return and catalog Retry (`gallery_selection_test.dart`); viewer swipe, zoom, oversize photo and video pause/resume (`viewer_actions_test.dart`, `viewer_test.dart`, `viewer_video_test.dart`); cast picker connect, Settings subscreens, share retry, Setup restore entries; catalog size limits (`private_catalog_test.dart`); idle lock (`idle_lock_test.dart`); post-restore lock screen (`app_start_failure_test.dart`). Lessons: tap handlers whose continuation does file IO must run inside `tester.runAsync`, and pushed screens that start file IO need pumping inside `runAsync`.
- Bug fixed: cancelling the Settings "Show recovery key" passcode prompt disposed its text controller while the dialog was still animating out (debug assertion "TextEditingController was used after being disposed"). The prompt is now a small widget that owns its controller (red/green `settings_access_test.dart`, which also covers empty-save and unreadable-keyfile messages). Host suite 578 passed, analyzer clean, iOS `lock_test.dart` passed (7 cases, 74.4 s). Android not rerun. Sweep of every `TextEditingController` in `lib/`: all others are `State` fields disposed in `dispose`; no other dispose-after-pop case.
- Bug fixed: typing in the NAS recovery and portable backup fields (soft keyboard sends no pointer or hardware key events) did not reset the idle-lock timer, so a 1-minute timeout could lock mid-entry and clear the NAS draft. Their fields now call `PrivacyScope.activity()` like Settings and Change passcode (red/green `typing_activity_test.dart`). Host suite 560 passed, analyzer clean, iOS `portable_test.dart` (5 cases, 73.8 s) and `nas_recovery_test.dart` (6 cases, 146.5 s) passed. Android not rerun. Other fields not changed: name/tag/search entries are short; Setup has no session timer.
- Bugs fixed earlier: Gallery Settings with unreadable saved NAS details now shows "Could not read saved NAS details. Try again."; after a failed session open Setup no longer reappears and the lock screen shows "Could not open the vault" (`gallery_selection_test.dart`, `app_start_failure_test.dart`).
- Earlier iterations (test-only or small fixes, all green): `WebDavClient.list` rejects a listing entry with no href or file name (red/green; iOS `backup_test.dart` passed); a non-passcode unlock failure shows the retry message (`lock_unlock_failure_test.dart`); NAS recovery change-mode validation, Albums empty state/search/delete-cancel, camera-open recovery and `sortedTags` covered. Host baseline was 486 then 444+ tests at the time; the current baseline is in the iteration 104 entry.
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
- `testWidgets` swaps in a mock HTTP client that answers 400 to everything. A widget
  test that talks to the loopback `FakeWebDavServer` must set
  `HttpOverrides.global = null` first.
- Widget tests that touch real files must start that IO inside `tester.runAsync` (also a tap whose handler writes);
  bare file IO inside `testWidgets` never completes (share dialog test hang).
- The 1.0.0+4 source passed both protected checks and complete hosted Android
  acceptance. Offline policy access, native notices and the published policy match.
- Source uses MPL 2.0 with independent recovery contracts and synthetic tests.
- Root privacy gates, encrypted backup and recovery, explicit sharing and Cast
  retain their established boundaries. The Back correction changes navigation
  ownership without changing encryption or vault identity.
- Release preparation retains immutable artifacts, private symbols and separate
  owner-controlled app/upload signing identities. Public CI has no signing or
  publishing credentials.
