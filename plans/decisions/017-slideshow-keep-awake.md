# 017 Slideshow keeps the screen awake

Status: accepted. The owner approved a small channel of our own instead of a plugin
on 2026-11-16.

## Decision

While the viewer slideshow runs, the screen stays on. The viewer calls the
`quietake/screen` method channel with `keepAwake` true when the slideshow starts and
false when it stops, reaches the end, or the viewer closes. Android sets and clears
`FLAG_KEEP_SCREEN_ON` on the activity window. iOS sets
`UIApplication.shared.isIdleTimerDisabled`. A failing call is ignored.

## Reasons and limits

- No new dependency, no new permission and no new data leave the app.
- The flag is for the visible window only. Locking the vault, whether by the idle
  timer or the Lock button, closes the viewer, which releases the screen. The idle
  lock still applies because the slideshow never counts as activity (decision 008).
- Android clears the flag automatically with the window; on iOS the flag is cleared
  by the viewer's dispose. If the app is killed the OS resets both.
- Verified by a host test with a mocked channel and by the viewer device tests on iOS
  and Android emulators; the actual dimming behavior is not observable in them.
