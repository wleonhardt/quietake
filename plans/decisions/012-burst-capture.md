# 012 Burst capture

Status: accepted.

## Decision

Pressing and holding the shutter takes five photos one after another. Each photo is
confirmed with the usual flash and saved through the same private capture path as a
single photo, one at a time. The status line reads "Saved 5 photos securely". A
custom accessibility action "Take 5 photos" offers the same without a gesture.

## Reasons and limits

- Photos are processed sequentially, so at most one plaintext file waits in private
  staging at a time and each is encrypted and published before the next is taken.
- The burst stops early if the app pauses or the screen becomes inactive. What was
  already saved stays saved. A camera error part way shows the usual error and keeps
  earlier photos.
- The burst size is fixed at five and each shot waits for the camera, so the rate is
  that of the camera, not a fast hardware burst.
- The shutter's tooltip uses manual trigger mode. The default long press tooltip
  would take the gesture from the burst.
- It is off while a self timer countdown runs and while recording.
