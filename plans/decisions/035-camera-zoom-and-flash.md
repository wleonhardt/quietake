# 035 Camera zoom and flash

Status: accepted 2026-11-17 by the review loop as the obvious default (the owner asked for the
review findings to be fixed). Zoom and flash are built.

## Problem

The camera had no zoom and no flash control. Every camera people compare it with has both, and a
photo of something small or dark could not be taken well.

## Decision

- Zoom: a two-finger pinch on the preview sets the camera's zoom between the limits the camera
  reports. While zoomed, a small label shows the factor (for example `2.0×`); tapping it goes
  back to no zoom. A newly opened camera (a lens switch, the camera after a recording, a return
  to the app) starts without zoom. A camera that reports no zoom range ignores the pinch.
- Flash: one button cycles off, automatic and on for photos. Off is the start value, because the
  app is meant to be quiet. A camera that refuses the mode stays off.
- Nothing is saved between launches; both start from their defaults.

## Limits

- Zoom has no control for screen readers or for people who cannot pinch; the label only goes
  back. A slider or step buttons would close that gap.
- The zoom is the plugin's single zoom level. It does not switch between a phone's wide and
  telephoto lenses by itself on every device.
- Zoom during a recording uses the same pinch; it was not tried on a device.

## Evidence

Zoom: `test/capture_chrome_test.dart` ("pinching the preview zooms within the camera range", "a
camera without zoom ignores the pinch"). Not tried on a phone.

Flash, built 2026-11-17: the button is in the top row next to Cast. The app now sets the mode
itself when a camera opens, because the plugin's own start value differs by platform; a recording
camera is always set to off. Tests in the same file ("the flash starts off and cycles automatic,
on, off", "a camera without a flash says so and stays off"). There is no torch for video. Not
tried on a phone.
