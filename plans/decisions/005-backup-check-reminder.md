# 005 Backup check reminder

Status: accepted.

## Decision

The date of the last full backup check is saved in the platform keystore next to the
NAS settings, tied to the share URL and user name. The Check backup screen shows a
reminder when a saved backup was never fully checked or the last check is more than
30 days old. A new check clears it.

## Reasons and limits

- A successful check proves the encrypted copies on the NAS can be read with this
  vault's key. That proof ages, and in-memory state was lost at every restart.
- The date is only a reminder. It changes no sync or deletion behavior and never
  infers anything from absence.
- The date belongs to one share: another share or a disconnect drops it.
- The reminder shows on the Check backup screen only. It is not a notification and
  the 30-day age is not configurable.
- The date is read when the controller next loads settings (a sync or check), so a
  fresh launch shows the reminder after the first sync.
