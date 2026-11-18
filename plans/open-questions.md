# Open questions

## Open

- Store release timing remains undecided.
- App wording drafts to review (en, es, fr, de; translations also need native review): share dialog encryption and passphrase text, Import "Open encrypted share" and its help sentence, "Give NAS files random names" in Settings, the recovery key last-matched line with its 90-day reminder, the lock screen photo count notice after unlock, the viewer "Use as cover of {tag}" button, the Include subfolders switch, and the multi-photo "Hide parts of these photos" text.
- Decision 028 iOS: the Lock Screen control opens the app only after the phone is unlocked. Build the LockedCameraCapture extension (native Swift sealing, App Group, entitlement) or keep this? Also add the control to a real Lock Screen, and create a provisioning profile for the `.control` bundle id.
- Policy sentences F (received share kept privately until unlock) and G (Include subfolders switch; must be published before a release that ships it) in decision 030: approve, edit or reject. Also: should folder names become tags on subfolder import?
- Decision 031 Android: the "Open with Quietake" filter is narrow, so Files, Gmail and most chat apps will often not list Quietake (their URIs carry no file name). Widen it to every `application/octet-stream` file, at the cost of showing Quietake for any unknown binary, or keep it narrow?
- Share metadata: PNG copies keep text, XMP and EXIF chunks, and the approved policy, website and share dialog say PNG and video copies are unchanged. Strip PNG metadata chunks too (needs those sentences changed)? Also JPEG copies now lose any data after the end of image marker (motion photo video, second picture); the policy sentence "without changing the picture" still holds, but the owner may want it mentioned.
- Decision 029: look at the generated gray icon on a real launcher.
- NAS restore dry run: the agent shell still sees `bw` locked; unlock it (the agent never types the master password) and hand over an empty test folder.

- Decision 033: bind the keystore copy of the master key to biometrics on both platforms and make biometric unlock an explicit choice in Settings? Today it is a prompt in the app, always on when the phone has biometrics. This changes the unlock flow and needs real devices with enrolled biometrics. Also: clear a saved NAS address and password when a new vault is created (they can survive an iOS reinstall)?
- Decision 034: video still records at 720p. Record at 1080p, or add a choice? Larger videos meet the 2 GiB portable backup limit sooner.

- Share bundle entry names: refuse a colon and Windows device names (`CON`, `NUL`, a trailing dot) in both readers? It tightens `docs/share-bundle.md`, so it needs the owner. Today a bundle opened by the recovery tool on Windows could name such a file.

- Decision numbers: code and tests cite decisions 027 and 036 to 040 from the private history (clipboard rule, search scope, application ID, staged MOVE, lock clears plaintext). The public records restarted at 001 and are now at 034, so public 027 already means something else and 036 onward will collide. Publish short public records for those rules and renumber the citations, or continue the public numbers from 041?

- CI: the check selector `tool/ci_scope.py` runs from the pull request's own checkout, so a pull request that edits it could select the light checks for itself. Run the selector from the base commit (and force full checks when it is missing there)? Also add a pinned `govulncheck` to the Go step? Both change the hosted workflow, which cannot be proven from a local checkout.

- Website wording drafts to approve (review item R80, not published until merged): the status line "In development · Android first · No app download yet", the sentence that says who the app is for, the button "See how it protects your photos" with "Explore the source" as the second link, "Source open under MPL-2.0", the backup sentence without the bare word WebDAV, and the Cast sentence that says its analytics cannot be turned off.

- Recovery tool: publish ready-made `quietake-recover` binaries (macOS, Windows, Linux) with checksums on each release, so recovery needs no Go install? It is a release step for the owner.

- Hidden areas (decision 024): draw each hidden area as one flat block instead of up to four coarse blocks across, and say "covered" instead of "pixelated" in the app, so the app matches the policy sentence "solid blocks" exactly?

- Restore gate: when an unfinished restore cannot resume, startup shows only Retry and the app is unreachable. Add "Discard the unfinished restore" (the backup file itself is never touched) after a failed retry?
- Sync: skip and report a server object that does not authenticate instead of stopping the whole pass, and cap a download when the server reports no size?

- Camera wording drafts (decision 035, en/de/es/fr, translations need native review): "Flash off", "Flash automatic", "Flash on", "This camera has no flash."

## Resolved

- 2026-11-17 (owner): policy drafts A to E approved and published (decision 030); background job keeps foreground-assigned random names (026); Quick Settings tile label follows the plain icon and the iOS Lock Screen control is approved to build (028).
- 2026-11-16 (owner): decision 025 option B layout approved; decision 026 Settings rename action approved, with random names for new uploads enabled after it; decision 028 OS-level entry approved for both platforms; policy sentences are drafted by the agent for owner approval.
- Original source uses MPL-2.0.
