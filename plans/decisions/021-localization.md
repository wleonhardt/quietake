# 021 Spanish, French and German

Status: accepted. The owner asked for Spanish, French and German on 2026-11-16.

## Decision

The app uses Flutter's `gen-l10n`. English is the template (`lib/l10n/app_en.arb`);
`app_es.arb`, `app_fr.arb` and `app_de.arb` hold the translations. Generated Dart
files live next to them in `lib/l10n/` and are committed, so a build needs no
extra step. `MaterialApp` gets the generated delegates and supported locales,
which also translate Material's own strings (back button, dialogs, date pickers).
The device language picks the locale; an unsupported language falls back to
English. No language switch is added in Settings.

Widgets read strings through `context.l10n`, which falls back to English when a
test harness has no delegates, so existing tests need no change. Plurals use ICU
`plural` messages. German and French use the formal "Sie" and "vous", Spanish "tú".

## Rules

- `test/localization_test.dart` fails when a language misses a message, has an
  empty one, or uses different placeholders than English.
- New user-facing text goes into the ARB files in all four languages.
- Stable widget keys never depend on text, so device tests keep working.
- The privacy policy, website and long help text stay English until the owner
  reviews translations, because their wording is owner-approved.
- Translations were written by the assistant and need a native-speaker review
  before release; they are not yet verified for tone or terminology.
- iOS lists the four languages in `CFBundleLocalizations` so the system reports
  them; Android needs no extra entry.

## Slices

1. Setup, `context.l10n`, and the Recently deleted screen (done).
2. Lock screen, Setup, recovery key and Change passcode screens (done). Messages
   raised by the vault layer, such as a wrong passcode or a too-short passcode,
   stay English until the exception types carry codes.
3. Camera and capture screen (done). Status text is stored already translated, so a
   language change shows the old text until the next status; acceptable for a
   transient message.
4. Library, Tags, Moments, viewer, share and import. Tags screen, name dialog,
   merge picker, Moments, the view sheet and the tag picker, the gallery screen and the Import screen, the share dialog and the
   viewer are done (slice 4 complete). The viewer delete explanation is built from
   four localized sentences joined with spaces. Share preparation errors from the share layer stay English. Per-file import messages from the import layer stay English. Tile accessibility labels join localized parts with a comma. `monthLabel` now takes a context and uses
   `intl` `yMMMM`.
5. Settings, backup and NAS screens, and snackbar errors.
Strings built in code, such as month names in Moments, move to `intl` date
formatting in slice 4.
