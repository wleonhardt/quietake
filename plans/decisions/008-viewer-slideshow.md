# 008 Viewer slideshow

Status: accepted.

## Decision

The viewer has a Start slideshow button. While on, it moves to the next photo every
4 seconds. It stops at the last capture, at a video, and when the user presses
Stop. It pauses a tick while a photo is zoomed, while sharing or deleting, and
while the viewer is not the active route or the app is not resumed.

## Reasons and limits

- Page changes from the timer are not user activity, so the idle lock timer is not
  reset. The vault still locks after the idle timeout and the lock closes the viewer.
- The screen is not kept awake. That needs a new platform plugin and its own
  decision, so the system may dim the screen during a long show.
- Videos are never auto-played or skipped silently: the show stops in front of one.
- The interval is fixed at 4 seconds and the show is not saved or looped.
