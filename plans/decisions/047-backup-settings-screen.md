# 047 The backup server has its own Settings screen

Status: accepted as the default 2026-11-18 (review item R56; no owner question was open). Built.

## Problem

Settings was one long page. Its second section was a form (server address, user name,
password, background upload switches, Save, Test, check, rename, disconnect) that sat between
the privacy switches and the recovery key. A person looking for the lock timeout or the
recovery key scrolled past a form they may never use, and the form shared one busy state with
every other control on the page.

## Decision

- Settings keeps a "Backup" section with one row, "Backup server". The row shows the server's
  host name, or "Not set up".
- The row opens `BackupSettingsScreen` (`lib/settings/backup_settings_screen.dart`) with the
  form and every action that needs the server: Test connection, Save, Check saved backup,
  Rename files on the server, Disconnect, and on Android the background upload switches.
- The code moved as it was; no behaviour of the form changed. After Save or Disconnect the
  backup screen and Settings both close, so the person lands in the library as before.
- The rest of Settings (privacy, recovery and export, camera, storage, about) is unchanged.

## Limits

- One more tap to reach the server form.
- Recovery and export, camera and storage are still sections of one page.
- The row shows the host only; it does not say whether the last backup succeeded. The camera
  and library already show that state.

## Evidence

`test/settings_screen_test.dart` (the row says whether a server is set up, the form is not on
the Settings page, layout and contrast checks run on the backup screen),
`test/settings_access_test.dart` and `test/settings_connection_test.dart` (the form's
behaviour, now on its own screen). Device runs are listed in `plans/review-fixes.md`.
