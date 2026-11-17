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
