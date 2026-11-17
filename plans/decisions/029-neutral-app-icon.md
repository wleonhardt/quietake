# 029 Neutral app icon

Status: accepted 2026-11-16 (owner): build the optional plain icon and name; the owner asked for the artwork to be generated, so it needs an owner look before shipping. No code yet.

## Proposal

An optional plain icon and app name, chosen in Settings, so the app looks ordinary on a
home screen. Android uses an `activity-alias` with its own icon and label, switched with
`PackageManager.setComponentEnabledSetting`. iOS uses alternate icons
(`CFBundleAlternateIcons` and `setAlternateIconName`), which change the icon but not the
name shown under it.

## Limits to state in the product

- This reduces casual notice only. It does not hide the app from a package list, a
  forensic search or the system settings. The copy must not promise concealment.
- On Android the switch can briefly close the app; the user is warned first.
- The icon must not imitate another app or brand.

## Needs the owner

- Go or no-go, the artwork and label, and the wording of the setting.

## Accepted 2026-11-16: slice plan

The owner asked for the artwork to be generated. The launcher icon is already vector based
(`quietake_foreground.xml` inside an adaptive icon), so a plain icon needs no bitmap: a new
adaptive icon `ic_neutral` with a flat gray background and a simple geometric foreground. It must
not copy another app or brand. Label: "Tools" (owner may change it). Slices, each with its own commit:

1. Android only, no behavior change: `activity-alias` `.NeutralAlias` (disabled, same MAIN/LAUNCHER
   filter, `targetActivity=.MainActivity`, neutral icon and label) plus the vector icon files and the
   label in `values` (and es/fr/de). Check: Android build, app still launches, one launcher entry.
2. Bridge on the existing `quietake/privacy` channel (or a new `quietake/appearance` channel): read
   which entry is enabled, and switch by enabling one component and disabling the other with
   `DONT_KILL_APP`, enabling the new one first so a launcher entry always exists. Dart handler test
   with a mocked channel; device check with `adb shell pm` for the component state.
3. Settings row with a switch, a warning that the app may close for a moment and that this does not
   hide the app from the package list or settings, es/fr/de strings, widget test with a mocked channel,
   stable keys. Policy wording is owner-reviewed, so only the in-app text is added and flagged.
4. iOS: alternate icon only (the name under the icon cannot change); `CFBundleAlternateIcons` plus
   `setAlternateIconName` through the same channel. Needs bitmap artwork at several sizes, so it comes last
   and needs an owner look at the generated icons.
Risk to check in slice 1: the launcher intent on `.MainActivity` must stay valid when the alias is the
enabled entry (share targets, notification taps and the Quick Settings tile all target the activity or
service, not the launcher entry, so they are expected to keep working).
