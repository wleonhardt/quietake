# 006 Capture grid overlay

Status: accepted.

## Decision

The capture screen has a Show grid / Hide grid button that draws rule-of-thirds
lines over the camera preview. The choice lasts for the open capture screen only.

## Reasons and limits

- The lines are a widget over the preview. They are never composited into the
  captured photo or video, so encrypted media is unchanged.
- Nothing is stored: no setting, no key, no file. The grid resets when the screen
  is rebuilt, for example after lock and unlock.
- The grid draws over whatever the preview shows, including Cast landscape.
  same preview widget.
