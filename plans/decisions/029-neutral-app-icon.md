# 029 Neutral app icon

Status: accepted 2026-11-16 (owner): build the optional plain icon and name; the owner asked for the artwork to be generated, so it needs an owner look before shipping. Built in four slices, corrected 2026-11-17 (see the end of this record).

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

## Slice 1 done (Android alias, no behavior change)

Added the disabled `.NeutralAlias` activity alias, a vector icon (`mipmap/ic_neutral.xml` for all API
levels and an adaptive version in `mipmap-anydpi-v26` with a themed monochrome layer), the colour
`neutral_background` and the label "Tools" (de "Werkzeuge", es "Herramientas", fr "Outils"). Checked on
the Android emulator with a debug build of the dev ID: it installs, `query-activities` lists exactly one
launcher entry (`MainActivity`), the alias is registered and disabled, and the app launches. Not
checked: how the plain icon looks on a launcher (needs the alias enabled). The shell cannot change
component state (`SecurityException`), so slice 2 must be verified by an in-app call, for example a device
test that switches and reads the state with `PackageManager`.

## Slice 2 done (channel and switch)

`LauncherAppearance` (`lib/settings/launcher_appearance.dart`) talks to a new `quietake/appearance` channel:
`neutral` reads whether the alias is enabled and `setNeutral` enables the wanted entry first, then disables the
other, both with `DONT_KILL_APP`. Missing channel or a native error reads as unsupported or failed, never as an
exception. Tests: `launcher_appearance_test.dart` (mocked channel, 4 cases); `integration_test/launcher_icon_test.dart`
passes on the Android emulator (switch on, read back, switch off, read back) and on the iOS simulator (reports
no support). Not verified: what the launcher shows while the alias is enabled (the test restores the normal entry
at once), and whether the running app survives the switch on every launcher. Slice 3 adds the Settings row.

## Slice 3 done (Settings row)

A switch "Use a plain icon and name" sits in the Privacy card under Change passcode (`Keys.settingsPlainIcon`),
shown only where `LauncherAppearance.neutral()` reports support, so today only on Android. Its subtitle states the
limits: gray icon named Tools, the app may close for a moment, and Quietake stays visible in the app list and system
settings. A failed switch keeps the old state and shows "Could not change the app icon." Strings in en, es, fr, de
(the label in the manifest is separate and also translated). Tests: three cases in `settings_access_test.dart`
(row hidden without support, switch and warning, failure keeps state); host suite 782 passed, analyzer clean;
`privacy_test.dart` passes on the Android emulator with the row present. Owner review needed: this in-app wording
and whether the website privacy policy should mention the option (it does not today). Not verified: toggling through
the Settings UI on a device (the channel itself is device tested), and how the launcher looks with the plain entry.
Slice 4 is done: the iOS alternate icon `NeutralIcon` (1024 px bitmap, generated) and the same `quietake/appearance` channel through `setAlternateIconName`. iOS changes only the icon, never the name, and the system shows an alert that only a person can dismiss, so the iOS device test checks the read path and the switch itself is not driven in the simulator (a manual tap verified the icon changed). The Settings row wording says the name changes; on iOS it does not, so iOS shows its own wording (`settingsPlainIconBodyIos`) that says the name stays Quietake; the wording awaits owner review.

Device check of the Settings row: `integration_test/settings_icon_test.dart` opens Settings through the real app, turns the switch on and off and reads the launcher state back through the channel on the Android emulator. On iOS it checks the row and the read path only, because of the system alert. Not checked: how a real launcher draws the plain icon and name.

## Correction 2026-11-17: the switch must not disable the activity

Slice 2 switched entries by disabling `MainActivity` itself and enabling `.NeutralAlias`. Checked on the
Android emulator (API 33) with the plain entry on: the launcher entry still opened the app, but an explicit
start of `MainActivity` failed with "Activity class does not exist" (this is what the camera tile does) and
"Open with Quietake" for a `.quietake-share` file was no longer offered, because both belong to the disabled
activity. The risk named in the slice plan was never checked with the alias enabled.

Now the launcher filter lives only on two aliases: `.NormalAlias` (enabled) and `.NeutralAlias` (disabled).
`LauncherEntries.switchTo` picks which alias to enable and which to disable, and the activity is never
disabled. The switch also puts the activity back to its default state, which repairs a development install
that used the old switch. After the change, on the same emulator with the plain entry on: one launcher entry
(`.NeutralAlias`), `MainActivity` starts by explicit intent, the share file filter resolves, and `MainActivity`
is no longer listed as disabled. Tests: `LauncherEntriesTest` (JVM: the switch never names the activity, and
only the two aliases carry the launcher filter in the manifest); `integration_test/launcher_icon_test.dart`.

Limits: an existing home screen shortcut that points at `MainActivity` disappears when a build with this
change replaces an older one, because the launcher entry is now `.NormalAlias`. Not checked: a real tile tap
and a real "Open with" while the plain entry is on, and any launcher other than the emulator's.
