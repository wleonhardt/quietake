# 011 Focus and exposure lock

Status: accepted.

## Decision

Pressing and holding on the camera preview focuses and meters at that point and
then locks focus and exposure. A label says "Focus and exposure locked" next to the
ring. The next tap on the preview returns both to automatic and focuses at the tap.

## Reasons and limits

- The lock belongs to the open camera controller. A lens switch, a pause or a
  reopened camera makes a new controller, which starts automatic, so the lock never
  carries across a camera release.
- A camera that refuses the lock shows "Could not lock focus and exposure on this
  camera." and stays automatic.
- Nothing is stored. The gesture has no button, so the preview's screen reader hint
  names it ("Press and hold to lock focus and exposure").
- Not tried on real camera hardware; simulators have no focus or metering.
