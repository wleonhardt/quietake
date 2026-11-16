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
- Next: continue `lib/` bug review. Read so far with no defect found:
  `media_server.dart`, `lock_screen.dart`, `restore_transaction.dart`,
  `capture_store.dart` (atomic `encryptFile` protects the
  prepared-video overwrite), `privacy_controller.dart`, `master_key_store.dart`, `webdav_client.dart` and the
  push path of `sync_service.dart`. Store-level passcode minimum is enforced
  only at UI/NAS entry points (tests rely on short ones). Still to read:
  `main.dart` lifecycle, rest of `sync/`. Add a failing test per bug found.
- NAS and simulator checks are authorized for the dev loop. The home NAS needs
  WebDAV credentials that live in HubnerDocs `.secrets`, which this loop must
  not read. A real-NAS run needs a test credential and an empty test folder
  handed over by the owner; until then loopback WebDAV tests stand in.

## Done

- Go recovery (`gofmt`, `vet`, `test`) and `tool/check_interop.dart` pass on this
  branch at its current source; nothing crypto/recovery changed.
- `WebDavClient.list` now rejects a listing entry with no href or no file name
  with a FormatException (red/green test). Full host suite passed: 486 tests,
  analyzer clean. iOS simulator `integration_test/backup_test.dart` also passed (4 cases, 57.9 s
  test, 111 s build, loopback WebDAV). Android not rerun; no UI or vault code changed.
- Host tests now cover `name_dialog.dart`, `share_dialog.dart`, `view_sheet.dart`, `device_picker.dart`, PortableScreen restore and export validation, `recording_progress.dart`, `archive_worker.dart` untrusted-ZIP rejections, `checkedFileName`
  and `sortedTags`. Analyzer clean; new files pass; full suite reused from the
  baseline of 444 passing tests (only test files were added).
- A widget test that ran the full export (isolate worker plus file IO) under
  `testWidgets` hung with no output after 3 minutes even with `runAsync` polling.
  Not diagnosed further; export success/save paths stay covered by
  `portable_backup_test.dart` and `integration_test/portable_test.dart`.
- Widget tests that touch real files must wrap that IO in `tester.runAsync`;
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
