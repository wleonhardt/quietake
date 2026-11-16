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
- Coverage run (`flutter test --coverage`, 541 tests, 90.2% total at iteration 40; `backup_screen_test.dart` added after) lowest files: `portable_screen.dart` 70%, `nas_recovery_screen.dart` 71%, `settings_screen.dart` 78%, `viewer_screen.dart` 82%. `portable_screen.dart` remaining gaps need real export/restore I/O or lifecycle pause during prepare (widget-zone hang risk). Older list: `import_screen.dart`
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
  only at UI/NAS entry points (tests rely on short ones). Still to read:
  rest of `sync/`. `main.dart` lifecycle and `sync_service.dart` pull path read; `exif_location.dart`
  and `import_media.dart` read, no defect (XMP geotags stay by documented design; a failed import
  still spends batch size budget, minor). `vault.dart` and `share_media.dart` read, no
  defect (`Vault.ingestAs` deletes its plaintext even when the name collides; only the importer's
  private staging copy is affected and microsecond names make that unreachable). `nas_recovery.dart` and
  `portable_backup.dart` read, no defect. Sweep of async button handlers and `SyncSettings`/keyfile callers found only the Settings gap fixed above; `_backgroundLock` in `main.dart` would skip locking if `hasKeyfile` threw before the first check finished, which `File.exists` does not realistically do (not changed). Doc drift check (iterations 47-48, incl. `website/app-privacy.html` idle default, import/share location wording, limits): NAS recovery KDF parameters, 16 MiB/10,000-capture list bounds, portable 2 GiB/10,000-file limits and passcode minimum match `lib/`. Unread: `vault_crypto.dart` (frozen vectors), `viewer_screen.dart` share/delete/video-open paths read, handled with snackbars, no defect (device e2e covers the rest). `capture_screen.dart` capture, stop and ingest paths read: failed stop clears recording state, no plaintext handled outside `CaptureStore`; no defect. Add a failing test per bug found.
- NAS and simulator checks are authorized for the dev loop. The home NAS needs
  WebDAV credentials that live in HubnerDocs `.secrets`, which this loop must
  not read. A real-NAS run needs a test credential and an empty test folder
  handed over by the owner; until then loopback WebDAV tests stand in.

## Done

- Iterations 49-52, test-only, no defect: restore-journal tampering refused by `resume` (`master_key_store_test.dart`); WebDAV listing size limit and rejected PROPFIND (`webdav_client_test.dart`); catalog-less legacy backup never restores a deleted capture (`delete_sync_test.dart`); `saveSettings` persists, syncs and reports busy (`sync_controller_test.dart`); stale `.recovery-work-*` staging removed before a recovery change, other hidden dirs kept (`nas_recovery_test.dart`). Full host suite at iteration 52: 554 passed, analyzer clean.
- Bug fixed: Gallery Settings button threw an unhandled error and did nothing when the saved NAS details could not be read (keystore failure). It now shows "Could not read saved NAS details. Try again." (red/green in `gallery_selection_test.dart`). Host suite 547 passed, analyzer clean, iOS `backup_test.dart` passed (4 cases, 56.7 s). Android not rerun. Corrupt-JSON blobs fail the same way and now get the same message; sync still reports pending.
- Bug fixed: after a failed session open from first-run Setup or restore, `_hasKeyfile` stayed
  false, so Setup reappeared with no reason although the keyfile was committed. `_start` now sets
  it, so the lock screen shows the message (red/green `app_start_failure_test.dart`, firstRun case).
  Host suite 536 passed, analyzer clean, iOS `lock_test.dart` passed (7 cases, 75.0 s).
- Bug fixed: `LockScreen` copied `message` only in `initState`, so the "Could not open the vault"
  reason never showed after a failed session open (red/green `app_start_failure_test.dart`).
  Host suite 535 passed, analyzer clean, iOS simulator `integration_test/lock_test.dart` passed
  (7 cases, 76.5 s). Android lock e2e not rerun.
- Go recovery (`gofmt`, `vet`, `test`) and `tool/check_interop.dart` pass on this
  branch at its current source (rerun at iteration 46, Go tests cached); nothing crypto/recovery changed.
- `WebDavClient.list` now rejects a listing entry with no href or no file name
  with a FormatException (red/green test). Full host suite passed: 486 tests,
  analyzer clean. iOS simulator `integration_test/backup_test.dart` also passed (4 cases, 57.9 s
  test, 111 s build, loopback WebDAV). Android not rerun; no UI or vault code changed.
- Host test `lock_unlock_failure_test.dart`: a non-passcode unlock failure shows the retry message; no defect. `setup_screen_test.dart` now covers the restore storage-failure message too.
- Host tests now cover NAS recovery change-mode validation and confirm-cancel, Albums screen empty state, search and delete-cancel, camera-open recovery of an interrupted photo, viewer favorite and delete (cancel, delete one of two), gallery selection (select, favorite, name, tags, unreadable catalog, open viewer), `setup_screen.dart` validation, restore toggle, bad key and fingerprint confirm/reject, `name_dialog.dart`, `share_dialog.dart`, `view_sheet.dart`, `device_picker.dart`, PortableScreen restore and export validation, `recording_progress.dart`, `archive_worker.dart` untrusted-ZIP rejections, `import_screen.dart`, `checkedFileName`
  and `sortedTags`. Analyzer clean; new files pass; full suite reused from the
  baseline of 444 passing tests (only test files were added).
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
