# 034 Photos use the full sensor

Status: accepted 2026-11-17 (owner asked for the fix after the whole-project review). Built.

## Problem

Both cameras opened with `ResolutionPreset.high`. In `camera_android_camerax` 0.7.6 that preset
bounds every use case, still capture included, at 1280x720 (read in the plugin source,
`_getResolutionSelectorFromPreset`). Photos on Android, the first release target, were therefore
about 0.9 megapixels. This was not measured on a device.

## Decision

- The photo camera (main screen and locked camera) opens with `ResolutionPreset.max`.
- The recording camera keeps `ResolutionPreset.high`, so video size and bitrate do not change.
  With `max` a recording would be 4K where the phone supports it, which the portable backup
  limit (2 GiB) and share limits do not fit.
- The plugin has one preset per camera, and the recording camera would bind later photos to the
  video preset. So after every recording, saved or not, the app closes the recording camera and
  opens the photo camera again. This also releases the microphone between recordings.

## Limits and open points

- Opening the photo camera again after a recording costs a short pause before the next capture.
- Video stays at 720p. Whether to record at 1080p, and whether the user should choose, is an
  owner call (see `plans/open-questions.md`).
- Larger photos take longer to encrypt and upload, and a burst takes longer.
- On iOS the photo size also depends on the capture format the plugin picks; not measured.

## Evidence

Host test `test/capture_resolution_test.dart` (photo camera at `max` before a recording, recording
camera at `high` with audio, photo camera back afterwards even when the save fails) and one added
check in `test/locked_camera_test.dart`. No device measurement of the saved photo size yet.
