# 030 Privacy policy wording drafts

Status: A to E approved by the owner 2026-11-17 and published in `assets/privacy-policy.json` and `website/app-privacy.html` (updated date November 17, 2026). Proposed 2026-11-16. The owner asked the agent to draft the privacy policy sentences for the features built since the policy was last updated, so the owner can approve, change or reject them. Nothing here is published: `website/app-privacy.html`, `website/privacy.html` and the in-app policy text are unchanged until the owner approves a sentence. Each draft says what the shipped code does today, names the section it would join, and lists what is not yet verified so the policy does not promise more than the app does.

How to use: mark each draft "approved", "approved with edits" (write the edit) or "rejected". Approved text is then copied into `website/app-privacy.html` and the in-app policy in one change, with the "Updated" date changed.

## A. Plain icon and name (decision 029)

Section: Screen privacy and local locking.

> Settings can switch Quietake to a plain gray icon. On Android the name under the icon also changes to "Tools"; on iOS only the icon changes and iOS shows a notice. This changes how the app looks on your home screen only. Quietake still appears in the app list and in system settings, and the choice does not hide the app from anyone who inspects the phone.

Facts checked in code: Android activity alias `.NeutralAlias`, label "Tools"; iOS alternate icon `NeutralIcon`, name unchanged; both rows carry the same warning in the app (`settingsPlainIconBody`, `settingsPlainIconBodyIos`). Not verified: how the icon looks on a real launcher.

## B. Camera on the lock screen (decision 028)

Section: Your vault.

> While the vault is locked you can open the camera from the lock screen. Photos taken this way are encrypted at once with a key that can only be opened by an unlocked Quietake, then stored in a hidden area of the app's private storage. The plaintext photo is deleted right after encryption. You cannot view these photos until you unlock; unlocking moves them into your vault as ordinary encrypted captures. The locked camera takes photos only, never records audio, and closes when the app goes to the background.

Facts checked in code: `PendingCrypto` seal to the vault public key, `.pending/` directory, `LockedCameraScreen` back camera without audio, pops on pause, `Session._publishLocked` at unlock. Wording choice for the owner: "photos only" matches the shipped screen; video is not offered. The Android Quick Settings tile "Quietake camera" now also opens the locked camera, also from the phone lock screen; suggested extra sentence: "On Android you can add a Quick Settings tile that opens this camera; the tile locks Quietake first and shows nothing else." The iOS Lock Screen control is not built yet; add a sentence when it ships.

## C. Hidden areas in shared photos (decision 024)

Section: Optional sharing, after the sentence about the default JPEG option.

> You can also hide parts of a photo before sharing. Quietake covers the areas you choose with solid blocks and shares the result as a new PNG without any metadata. The hidden areas are changed in the copy only; the original in your vault is not changed. Anyone who receives the copy sees the blocks, not what is under them.

Facts checked in code: `redactToPng`, `RedactScreen`, copy is a metadata-free PNG, vault original unchanged. The existing "PNG and video copies are not changed" sentence should read "PNG and video copies that are not redacted are not changed" if this is approved.

## D. Encrypted share (decision 025, not built in the app yet)

Section: Optional sharing. The share dialog now offers it (slice 4); publish with slice 5 (opening a bundle in the app) or earlier if the owner accepts the command-line tool as the only reader.

> Besides sharing normal copies, Quietake will be able to share a bundle that is encrypted with a passphrase made only for that share. Quietake shows the passphrase once; send it to the recipient by a different route from the file. The bundle never uses your vault key, recovery key or NAS credentials, so opening it reveals nothing about your vault. The file shows that it is a Quietake share, its total size and its encryption cost, and nothing else: names, counts and sizes of the items inside are encrypted. Anyone who has the file can try passphrase guesses offline, so the passphrase protects only as well as it is kept secret. Quietake and the open-source recovery tool can open a bundle with the passphrase.

Facts checked: `docs/share-bundle.md`, `lib/crypto/share_bundle.dart`, `recover -share`, frozen vectors. Wording choice: "six random words" is the planned passphrase; keep it out of the policy until the dialog generates one.

## E. NAS file names are random (decision 026)

Section: Optional WebDAV backup. This replaces the sentence "The server can see connection information, container names and sizes. Names include capture time (date added for imports) and media type; container lengths reveal exact media sizes."

> The server can see connection information, file names and sizes. New uploads use random file names, so the name shows neither the capture time nor the media type; the mapping from your captures to these names is kept in your encrypted catalog. Files uploaded by an earlier version keep their readable names until you choose "Give NAS files random names" in Settings. File sizes still reveal exact media sizes. Older versions of Quietake cannot open a vault whose files have random names, so update Quietake on every phone before renaming.

Also edit: the Android background-upload paragraph. Suggested added sentence: "With random file names, the background job uploads only files whose random name was already assigned by a foreground sync, so some new captures wait for the next time you open Quietake." Facts checked: `Session.randomRemoteNames`, `SyncService.renameRemote`, `BackgroundTransfer` mapping and its tests. Not verified against a real NAS or on a device with random names; the catalog limit is 2 MiB, which an older version rejects.

## Review notes

- Items A, B and C describe shipped behaviour and could be approved now. D must wait for the app dialog. E describes the current default and is the most important to publish, since the existing policy sentence about names including capture time is no longer true for new uploads.
- The "Updated" date on the policy and the policy's in-app copy should change together when any draft is approved.
- Nothing here has been reviewed by a lawyer or translated; the in-app policy is English only by decision 021.

## Owner answers 2026-11-17

- A, B, C, D and E approved as written, with two edits made when publishing: D says "can share" instead of "will be able to share" because the share dialog and Import now ship, and the lock-screen draft B omits the optional Quick Settings tile sentence, which was not part of the quoted text. The tile sentence stays available for a later edit.
- Decision 026: the Android background job keeps its current rule and uploads only files whose random name a foreground sync already assigned.
- Decision 028: the Quick Settings tile label should follow the plain icon (Tools when the plain icon is on). Not built yet.
- Decision 028: build the iOS Lock Screen control (Xcode extension target, iOS 18). Not built yet; add its sentence to the policy when it ships.

## F. Opening a received share from another app (decision 031, proposed 2026-11-17)

Section: Optional sharing, after the encrypted share paragraph. Not published; awaiting the owner.

> If another app opens a received Quietake share file with Quietake, Quietake keeps a private copy of that file inside the app until you unlock and enter its passphrase, then removes it. The file is still encrypted with the share passphrase and is never decrypted while Quietake is locked.

Facts checked in code: `IncomingShare` on Android and iOS, 513 MiB bound, stale copy removed at startup, the Dart side takes it only while unlocked. Not verified with a real Open with.

## G. Subfolders in folder import (decision 032, proposed 2026-11-17)

Section: Your vault, optional import paragraph. Not published; awaiting the owner. It replaces the clause "Quietake reads only that folder's files, not its subfolders".

> You can also choose one folder: Quietake reads only that folder's files unless you turn on "Include subfolders" for that import, and then it also reads the files in the folders inside it, up to six levels down.

Facts checked in code: the switch is off whenever the Import screen opens, and the native pickers walk subfolders only when it is on. Not verified on a real folder tree. Publish before a release that ships the switch.
