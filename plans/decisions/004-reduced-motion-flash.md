# 004 Reduced-motion capture flash

Status: accepted.

## Decision

When the system asks to reduce motion (`MediaQuery.disableAnimationsOf`), the
capture confirmation edge flash appears and disappears without its 160 ms fade.
The haptic tap and the 180 ms duration are unchanged, so the confirmation stays
visible. Without that setting nothing changes.

## Reasons and limits

- The flash is the only animated cue on the capture screen. The recording frame
  is a static border and needs no change.
- Test: `capture_flash_motion_test.dart`. It lives in its own file because a
  second shutter test after a photo test in one file fails to boot the fake
  camera (cause not found; each passes alone).
