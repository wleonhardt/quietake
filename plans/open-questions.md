# Open questions

## Open

- Store release timing remains undecided.
- App wording drafts to review (en, es, fr, de; translations also need native review): share dialog encryption and passphrase text, Import "Open encrypted share" and its help sentence, "Give NAS files random names" in Settings, the recovery key last-matched line with its 90-day reminder, the lock screen photo count notice after unlock, the viewer "Use as cover of {tag}" button, the Include subfolders switch, and the multi-photo "Hide parts of these photos" text.
- Decision 028 iOS: the Lock Screen control opens the app only after the phone is unlocked. Build the LockedCameraCapture extension (native Swift sealing, App Group, entitlement) or keep this? Also add the control to a real Lock Screen, and create a provisioning profile for the `.control` bundle id.
- Policy sentences F (received share kept privately until unlock) and G (Include subfolders switch; must be published before a release that ships it) in decision 030: approve, edit or reject. Also: should folder names become tags on subfolder import?
- Decision 031 Android: the "Open with Quietake" filter is narrow, so Files, Gmail and most chat apps will often not list Quietake (their URIs carry no file name). Widen it to every `application/octet-stream` file, at the cost of showing Quietake for any unknown binary, or keep it narrow?
- Decision 029: look at the generated gray icon on a real launcher.
- NAS restore dry run: the agent shell still sees `bw` locked; unlock it (the agent never types the master password) and hand over an empty test folder.

## Resolved

- 2026-11-17 (owner): policy drafts A to E approved and published (decision 030); background job keeps foreground-assigned random names (026); Quick Settings tile label follows the plain icon and the iOS Lock Screen control is approved to build (028).
- 2026-11-16 (owner): decision 025 option B layout approved; decision 026 Settings rename action approved, with random names for new uploads enabled after it; decision 028 OS-level entry approved for both platforms; policy sentences are drafted by the agent for owner approval.
- Original source uses MPL-2.0.
