# Open questions

## Open

- Store release timing remains undecided.
- Wording approval: policy sentence drafts are in `plans/decisions/030-policy-wording-drafts.md` (plain icon, lock screen camera, hidden areas, encrypted share, random NAS names). Mark each approved, edited or rejected; the website and in-app policy stay unchanged until then. The existing sentence that NAS names show capture time is already out of date for new uploads.
- App wording drafts to review (en, es, fr, de; translations also need native review): share dialog encryption and passphrase text, Import "Open encrypted share" and its help sentence, "Give NAS files random names" in Settings, and the recovery key last-matched line with its 90-day reminder.
- Owner calls: should the Android background job choose random names itself and report pairs (decision 026); the Quick Settings tile label says Quietake even when the plain icon is on (decision 028); the iOS Lock Screen control needs an Xcode extension target and iOS 18, so it stays unbuilt until you approve that.
- Decision 029: look at the generated gray icon on a real launcher.
- NAS restore dry run: the agent shell still sees `bw` locked; unlock it (the agent never types the master password) and hand over an empty test folder.

## Resolved

- 2026-11-16 (owner): decision 025 option B layout approved; decision 026 Settings rename action approved, with random names for new uploads enabled after it; decision 028 OS-level entry approved for both platforms; policy sentences are drafted by the agent for owner approval.
- Original source uses MPL-2.0.
