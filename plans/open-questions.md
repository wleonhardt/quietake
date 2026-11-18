# Open questions

## Open

- Store release timing remains undecided.
- Translations (de, es, fr) of every in-app wording draft need native review. The English wording was accepted by the owner on 2026-11-18.
- Decision 029: look at the generated gray icon on a real launcher.
- NAS restore dry run: the agent shell still sees `bw` locked; unlock it (the agent never types the master password) and hand over an empty test folder.
- Real-device checks nobody has done yet: the saved photo size after decision 034, a tile tap and "Open with" while the plain icon is on, pinch zoom, the flash button, biometric unlock once decision 033's second part is built.

## Resolved

- 2026-11-18 (owner, answers to the review questions):
  - Decision 033: bind the keystore key to biometrics and make biometric unlock a Settings switch, off by default. Clear a saved backup server when a brand-new vault is created.
  - Decision 034: video quality becomes a setting (720p, 1080p, 4K), 1080p by default.
  - Decision 024: a hidden area is one flat black block; the app says "covered".
  - Share metadata: PNG copies lose their metadata too; the changed policy, website and dialog sentences are drafted for approval. Video stays unchanged.
  - Restore gate: offer "Discard the unfinished restore" after a failed retry.
  - Sync: skip and report a server file that does not authenticate; cap a download of unknown size at 4 GiB.
  - Camera layout: controls go outside the picture.
  - Decision numbers: public records continue from 041; 027 (old meaning) and 036 to 040 in code comments are private-history records.
  - CI: run the selector from the base commit, add a pinned `govulncheck`, and add an iOS build job (no second Android API level).
  - Recovery tool: add a release workflow that builds binaries with checksums.
  - Share bundle: both readers refuse a colon and Windows device names.
  - Lock: close the session on lock and rebuild it on unlock.
  - Library index: keep the format, raise the size cap.
  - Recovery key: add a 24-word form; base64 stays valid everywhere.
  - Decision 031: the Android "Open with" filter stays narrow. Decision 028: the iOS control stays as it is, no capture extension. Decision 032: folder names do not become tags. Release code shrinking: not now.
  - Policy sentences F and G approved as written. Website wording drafts of review item R80 approved. English in-app wording drafts accepted.

- 2026-11-17 (owner): policy drafts A to E approved and published (decision 030); background job keeps foreground-assigned random names (026); Quick Settings tile label follows the plain icon and the iOS Lock Screen control is approved to build (028).
- 2026-11-16 (owner): decision 025 option B layout approved; decision 026 Settings rename action approved, with random names for new uploads enabled after it; decision 028 OS-level entry approved for both platforms; policy sentences are drafted by the agent for owner approval.
- Original source uses MPL-2.0.
