# 013 Moments

Status: accepted.

## Decision

The Tags screen has a Moments button. Moments lists the local months that have
captures, newest first, each with its capture count. Opening a month shows the
Library filtered to that month, with a removable "November 2026" chip.

## Reasons and limits

- Months come from the capture time in each container file name, as the viewer
  Details and the Library sort already do. Nothing is decrypted, no index or
  catalog field is added, and nothing is saved.
- Captures whose names carry no parsable time (imports that kept another name)
  are left out of Moments and still appear in the normal Library.
- The month is a Library filter like Untagged. It combines with the existing text,
  kind and favorite filters inside that screen and is cleared by "Clear search and
  filters".
- Month boundaries use the phone's local time zone when the list is read.
- Years or days as extra levels and a map or place grouping are not planned.
