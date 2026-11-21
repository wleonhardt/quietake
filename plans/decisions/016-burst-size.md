# 016 Burst size choice

Status: accepted.

## Decision

Press and hold on the shutter takes 3, 5 or 10 photos. Five stays the default.
Settings has a Camera section with "Photos in a burst". The choice is saved in
secure storage under `camera.burstSize`; an unreadable or unknown value gives five.
The screen reader action is named from the saved size, for example "Take 10 photos".

## Reasons and limits

- Decision 012 fixed the size at five and named a size choice as a follow-up.
- Capture still saves each photo through the normal private path one at a time, so
  a larger burst only takes longer; the rate is that of the camera.
- The capture screen reads the setting when it opens. A change in Settings applies
  the next time the camera screen opens.
- The status line still reads "Saved N photos securely".
