# 023 Lock now Quick Settings tile

Status: accepted. Built from the "Lock now" idea; the Gallery button already exists.

## Decision

Android gets a Quick Settings tile named "Lock Quietake". Tapping it asks the running
app to lock at once, the same path as the Lock now button: playback pauses, an active
recording is saved, casting stops and the lock screen appears. The tile is a
`TileService` that calls a static bridge to the activity's existing `quietake/privacy`
channel with the method `lockNow`. Dart handles it in `ScreenPrivacy` and calls
`PrivacyController.lock`.

## Reasons and limits

- When the app process is not running there is nothing unlocked to lock, and the next
  start already shows the lock screen, so the tile does nothing then. It never starts
  the app and never needs the vault.
- The tile carries no secret and no state: it never shows lock status, so the panel
  reveals nothing about the vault. Its label and icon are generic.
- The bridge holds the channel only while the activity exists and is cleared on
  destroy, so a tile tap cannot reach a stale engine.
- iOS has no equivalent surface; this item is Android only.
- The tile label is translated in Spanish, French and German through Android string
  resources. The user adds the tile from the Quick Settings editor.
- Tests: a host test for the Dart handler. The Android emulator check taps the
  tile service through `adb shell cmd statusbar click-tile` where available;
  otherwise only the bridge call is checked and the tile tap itself is unverified.
