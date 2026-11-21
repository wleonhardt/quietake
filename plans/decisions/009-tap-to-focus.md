# 009 Tap to focus

Status: accepted.

## Decision

Tapping the camera preview sets the focus point and the exposure point to the
tapped position and shows a ring there for 0.8 seconds. It works for photos and
while recording.

## Reasons and limits

- Both points are set on the open camera controller only. Nothing is stored and no
  captured file changes except through the camera's own focus and exposure.
- A camera that refuses manual focus or metering keeps automatic behavior. The
  refusal is ignored and shows no message, since the shot still works.
- The tap area is the whole preview. The control panels sit above it and take their
  own taps, so a tap on a button never moves focus.
- Exposure lock after the tap is a separate idea and stays on the list.
