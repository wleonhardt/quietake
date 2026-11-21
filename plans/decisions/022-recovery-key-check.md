# 022 Recovery key check

Status: accepted. Built from the "Recovery key drill" idea; the periodic reminder is not part of this step.

## Decision

Settings, under Recovery & export, gets a "Check my recovery key" button. It opens a
dialog where the owner types the recovery key they saved elsewhere. The app parses it
with `MasterKeyStore.importRecovery` and compares it with the live vault key through
`Vault.matchesKey`, which compares in constant time without exporting either key. The
dialog says one of: the key matches, the key does not match, or the text is not a
valid recovery key. It can be retried until the owner closes it.

## Reasons and limits

- The Check backup screen says a successful backup check does not test the copy of the
  key saved elsewhere. This closes that gap without a passcode prompt, because the
  vault is already unlocked and the check reveals no secret.
- The typed text lives only in a dialog-owned controller. It is never stored, logged or
  sent anywhere. The parsed key is disposed right after the comparison, and the field
  is cleared when the dialog closes and when the app pauses (the content stays alive
  behind the lock screen, so a typed key would otherwise survive it; the Change passcode
  screen and the Show recovery key prompt now do the same).
- The check reports nothing about how close a wrong key is.
- Activity in the field resets the idle-lock timer like the other secret fields.
- Messages are localized in Spanish, French and German like the rest of the app.

## Last-matched date and reminder (added 2026-11-17)

When a typed key matches, `MasterKeyStore.saveRecoveryChecked` saves only the date in the platform keystore (`quietake.recovery_checked`). Never the key, never what was typed. Settings shows a line under the button: "Never checked.", "Last matched <date>." or, after 90 days, "Last matched <date>. Check again every few months." It is a reminder line only: no notification, no changed behavior, and the 90 days are not configurable. A failed read shows "Never checked."; a failed write is ignored. The date is per phone and per keystore, not tied to one vault, so the date is dropped when a new vault is set up (`prepareKey`) or a portable backup is restored (`preparePortableKeyfile`); the iOS keychain can outlive an uninstall, so this stops a new vault from showing an old vault's date. Tests in `test/settings_access_test.dart` (never, mismatch does not count, match saves, old date asks again). Wording in en, es, fr, de is a draft for owner approval.
