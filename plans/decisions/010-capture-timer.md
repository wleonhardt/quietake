# 010 Capture self timer

Status: accepted.

## Decision

The capture screen has a Timer button that cycles off, 3 seconds and 10 seconds.
With a timer set, the shutter starts a visible countdown and takes the photo at
zero. Pressing the shutter again cancels it. The timer applies to photos only.

## Reasons and limits

- The choice and the countdown live in the open capture screen. Nothing is stored.
- The countdown stops when the app pauses, the screen becomes inactive (lock or
  another route) or the screen is closed, so a photo is never taken while the app is
  hidden or locked. Tags selected for the capture also reset on those events.
- Video recording and the Timer button are disabled during a countdown.
- A photo from the timer goes through the same capture path as the shutter, so it is
  encrypted and staged exactly like any other.
- Burst mode and exposure lock stay on the ideas list.
