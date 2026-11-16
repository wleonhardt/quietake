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

## Done

- Review (iteration 113): `Setup._submit` (restore and create paths), `QuietakeApp._start` and `Session.start` read for a key use after dispose; each key has one owner and one disposal, so the Setup segfault theory stays unproven. No code changed.
- Lesson (iteration 112): reading a disposed `SecureKey` (`extractBytes`) segfaults flutter_tester, so a test cannot assert disposal by reading the key. The same native crash may explain the open Setup-failure segfault above: some path may read a key after dispose. No test added; app code unchanged.
- Full host suite at iteration 111: 604 passed, analyzer clean (supersedes the iteration 104 count).
- Host test (`lock_unlock_failure_test.dart`): a wrong passcode submitted with the keyboard action shows "wrong passcode" (the `onSubmitted` path was untested).
- Host test (`lock_unlock_failure_test.dart`): a refused biometric prompt shows the authenticator's reason and keeps the biometric button.
- Host test (`lock_unlock_failure_test.dart`): recovery started from the lock screen opens a restore-only Setup and hands its key to the app, popping Setup.
- Host test (`viewer_actions_test.dart`): the viewer shows "Could not cast. Try again." after a failed connect and "casting to <device>" after a successful one (skipped without a LAN address).
- Host test (`sync_controller_test.dart`): a same-key NAS copy with different content is kept and the result reads "NAS conflict for …. Both copies kept" with state pending. Lesson: a conflict is detected by size or content, and with a remote catalog present equal-size copies are skipped, so the test copy must differ in size.
- Host test (`nas_change_validation_test.dart`): Generate fills a multi-word backup passphrase and clears the confirmation field (`Keys.nasGenerate` was untested). `nas_recovery_screen.dart` still lacks the committed change/disable success paths (lines about 239-324), which need a locking WebDAV server.
- Host test (`portable_screen_test.dart`): a file pick that finishes after the screen is left cancels and then discards its private copy. `portable_screen.dart` remaining gaps are the prepare/commit paths (lines about 162-238), which need real isolate and file work.
- Iteration 100 sanity run: Go recovery checks and `dart run tool/check_interop.dart` pass. Full host suite at iteration 104: 599 passed, analyzer clean.
- Bug fixed: a failed camera lens switch left a dead controller (`CameraController.setDescription` closes the old camera before opening the new one), so the preview and shutter stopped working. `_flipCamera` now reopens the camera on the same lens and still shows "Could not switch camera. Try again." (red/green in `camera_recording_start_test.dart` with a fake that rejects a closed camera). Host suite 594 passed, analyzer clean, iOS `camera_lifecycle_test.dart` passed (2 cases, 35.1 s). Android not rerun; a real failing switch was not tried on a device. Same file also covers a denied microphone and a camera that cannot open with audio ("Could not start video", photo preview returns). `camera_cast_orientation_test.dart` covers landscape while casting; `camera_album_test.dart` covers the unreadable tag list message. Remaining `capture_screen.dart` gaps: recording paths and some controls.
- Host test (`camera_cast_orientation_test.dart`): the capture screen requests landscape when a cast starts and frees orientation when it stops (skipped on a host with no LAN address); a camera that refuses the landscape lock shows "Could not update camera orientation.", and a photo taken while casting is loaded on the TV. Remaining `capture_screen.dart` gaps: tag choice errors (146-149), recording paths (447-481), controls (542-603).
- Host tests (`gallery_selection_test.dart`, iterations 86-87): Reset view restores a view narrowed to Favorites, with backup unconfigured the sync button (tooltip "Set up backup") opens Settings, and a vault folder that cannot be listed shows "Could not open vault. Retry" and Retry recovers once the folder returns; returning from the viewer reloads the list; Retry on an unreadable catalog unlocks selection after repair.
- Full host suite at iteration 85: 585 passed, analyzer clean, after the gallery, cast picker, Settings and Setup coverage tests. No app code changed since the recovery-prompt fix, so the iOS lock result still applies.
- Host test (`viewer_actions_test.dart`): swiping the real viewer moves to the next capture and back (the page-change handler was uncovered), double tap zooms a photo while Reset to fit restores it, and a too-large photo shows its size message (`viewer_test.dart`), and backgrounding pauses video playback while foregrounding resumes it, and a paused video with hidden controls offers a play overlay (`viewer_video_test.dart`). Coverage at iteration 70: `portable_screen.dart` 70%, `nas_recovery_screen.dart` 72%, `viewer_screen.dart` 82%.
- Bug fixed: cancelling the Settings "Show recovery key" passcode prompt disposed its text controller while the dialog was still animating out (debug assertion "TextEditingController was used after being disposed"). The prompt is now a small widget that owns its controller (red/green `settings_access_test.dart`, which also covers empty-save and unreadable-keyfile messages). Host suite 578 passed, analyzer clean, iOS `lock_test.dart` passed (7 cases, 74.4 s). Android not rerun. Sweep of every `TextEditingController` in `lib/`: all others are `State` fields disposed in `dispose`; no other dispose-after-pop case.
- Host test (`gallery_selection_test.dart`): Add tags then Remove tags change the selected capture's tags. Also: Settings opens with readable NAS details, and Untagged in the actions sheet opens a filtered search. Lesson: tap a handler whose continuation does file IO inside `tester.runAsync`, and pump inside `runAsync` when a newly pushed screen starts its own file IO, or teardown hangs.
- Host tests, iterations 70-80, all passing: choosing a TV in the cast picker connects and shows the "Open a capture to cast it" note (skipped without a LAN address); Settings opens the Portable backup, Privacy policy and Licenses screens; a failing system chooser shows the share retry message and a retry succeeds; Setup's ZIP and NAS restore entries open their screens. Full host suite at iteration 75: 573 passed.
- Host tests (`private_catalog_test.dart`): a library too large to save is refused with state unchanged, and an oversized catalog is refused on load. `private_catalog.dart`, `cast_controller.dart`, `library_query.dart`, `tag_picker.dart`, `merge_target.dart`, `name_dialog.dart` and `albums_screen.dart` and most of `gallery_screen.dart` (load, selection, tags, settings, grid and tile) re-read, no defect. `CastController.start`'s "Connect to Wi-Fi" branch is untested because `MediaServer.lanAddress` is a static with no test hook. Both limits were untested before. Also covered: edits naming a deleted tag are refused, and a closed catalog refuses edits. A grep for untested error strings is not useful because tests assert exception types.
- Host tests (`idle_lock_test.dart`): an idle session locks after the app's timeout, and hardware key presses and touches keep it unlocked (first host coverage of `QuietakeApp` idle locking; `idleTimeout` is the test hook).
- Host test (`app_start_failure_test.dart`): after a restore completes, the app shows the lock screen, not Setup. Other short text entry points (names, tags, search) still do not reset the idle timer; they are short, so left unchanged.
- Bug fixed: typing in the NAS recovery and portable backup fields (soft keyboard sends no pointer or hardware key events) did not reset the idle-lock timer, so a 1-minute timeout could lock mid-entry and clear the NAS draft. Their fields now call `PrivacyScope.activity()` like Settings and Change passcode (red/green `typing_activity_test.dart`). Host suite 560 passed, analyzer clean, iOS `portable_test.dart` (5 cases, 73.8 s) and `nas_recovery_test.dart` (6 cases, 146.5 s) passed. Android not rerun. Other fields not changed: name/tag/search entries are short; Setup has no session timer.
- Iterations 49-52, test-only, no defect: restore-journal tampering refused by `resume` (`master_key_store_test.dart`); WebDAV listing size limit and rejected PROPFIND (`webdav_client_test.dart`); catalog-less legacy backup never restores a deleted capture (`delete_sync_test.dart`); `saveSettings` persists, syncs and reports busy (`sync_controller_test.dart`); stale `.recovery-work-*` staging removed before a recovery change, other hidden dirs kept (`nas_recovery_test.dart`); failed idle-timeout save shows its message and keeps the old value (`settings_access_test.dart`, 9 pass). Full host suite at iteration 52: 554 passed, analyzer clean.
- Bug fixed: Gallery Settings button threw an unhandled error and did nothing when the saved NAS details could not be read (keystore failure). It now shows "Could not read saved NAS details. Try again." (red/green in `gallery_selection_test.dart`). Host suite 547 passed, analyzer clean, iOS `backup_test.dart` passed (4 cases, 56.7 s). Android not rerun. Corrupt-JSON blobs fail the same way and now get the same message; sync still reports pending.
- Bugs fixed: after a failed session open, Setup reappeared because `_hasKeyfile` stayed false, and `LockScreen` never showed the "Could not open the vault" message because it copied it only in `initState` (red/green `app_start_failure_test.dart`). Host suite 536 passed; iOS `lock_test.dart` passed (7 cases). Android lock e2e not rerun.
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
