# 044 Upright, the camera controls sit in bars outside the picture

Status: accepted 2026-11-18 (owner chose "Controls outside the picture"). Built.

## Problem

The camera controls sat on rounded panels over the viewfinder. The panels covered the top and
bottom of the picture, so the framing on screen was not the framing of the photo, and a status
message made the top panel grow over more of it.

## Decision

- When the screen is at least as tall as it is wide, the camera screen is a column: a top bar
  (backup state, flash, Cast, Lock), the picture, and a bottom bar (tags, timer, grid, switch
  camera, then Video, Photo, Library). The bars are opaque and extend under the status bar and
  the home indicator. Nothing permanent covers the picture.
- The recording timer sits in the top bar, so the picture keeps its place and size while a
  recording runs.
- Passing notices ("Saved securely", "Starting video", a camera error with Retry, the Cast
  state) appear on an opaque panel over the top of the picture and go away. They do not push
  the picture down: a picture that jumps under the finger is worse than a line of text over it.
- The zoom factor stays on the picture, at its bottom edge, as a small opaque label.
- Held sideways, the layout is unchanged: panels over the picture. Bars above and below would
  leave a strip of picture about a third of the screen high. Moving the controls to the short
  edges is review item R28, which waits for a phone to judge it on.

## Limits

- On a short phone the picture is smaller than before, because the bars take their height
  from it: at 360 x 640 a 3:4 picture is about 290 wide instead of 360.
- A long notice still covers the top of the picture while it shows.
- Not seen on a phone. The iOS simulator has no camera, so only the bars were looked at there.

## Evidence

`test/capture_chrome_test.dart` ("upright, the controls sit in bars outside the picture") and
`test/camera_controls_layout_test.dart` (320 x 640 upright and two sideways sizes, at normal and
double text size: every control keeps an opaque backing, tap targets and text contrast pass).
