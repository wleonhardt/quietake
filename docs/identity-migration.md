# Moving an existing vault to Quietake

Quietake uses application ID `cam.quietake.app` (`cam.quietake.app.dev` for
isolated development tests). It installs alongside the earlier application.
An application rename does not transfer its private sandbox or biometric cache.

1. Open the earlier application and let pending captures finish saving securely.
2. Save the recovery key privately, then export an encrypted portable backup.
   Keep the original application and archive until recovery is verified.
3. Open the fresh Quietake installation and choose Restore portable backup.
   Select the archive, supply the saved recovery key, and choose a new local
   passcode. Restore requires an empty vault.
4. Unlock with that passcode and verify captures, titles, favorites and tags.
   Existing album IDs, names and memberships are preserved as tags.
5. Configure a new WebDAV backup folder and verify it. Existing remote collections
   with legacy metadata are read-only migration sources; Quietake does not rename
   or delete their files. Re-enable background backup explicitly if desired.

If the installed build predates portable export, preserve it. Commit `93d815b`
contains the export feature with the legacy application/storage IDs. A bridge
upgrade must match the original installation's signing identity and platform
entitlements, and requires explicit physical-device authorization. This work has
not built, signed or installed that bridge on a phone. CLI recovery remains an
alternative when a compatible upgrade is unavailable.

If the earlier app is unavailable, explicit NAS passphrase recovery can read a
complete legacy catalog/envelope pair. The independent recovery CLI also reads
legacy formats. If only a saved recovery key and a legacy NAS collection remain,
use that CLI; direct in-app legacy NAS migration with a raw recovery key is not
implemented. Portable restore and NAS passphrase restore preserve organization.
A mixed old/new collection is rejected; preserve both copies and choose a known
complete backup rather than deleting metadata to silence the error.

Restoration authenticates all files before adoption. It preserves encrypted media
bytes and recovery identity, normalizes the local catalog filename, and requires
fresh passcode authentication. An interruption after the encrypted restore journal
is ready resumes on startup. Before that point, only private staging is removed;
the source backup stays intact.

`.shtr` media format v1 and catalog schema 1 are unchanged. New storage uses
`quietake.catalog`, `quietake.master_key` and `quietake.recovery.json`. New NAS
recovery envelopes use schema 2; strict v1 decoding remains available. Exact old
strings remain only where needed for compatibility, protected test guards, frozen
fixtures or historical records.

Physical-device transfer, live NAS/Cast validation and publication remain separate
holds. Do not uninstall the earlier app based only on emulator test results.

Use the current Quietake app or recovery CLI for newly written backups. Legacy
apps do not understand schema 2 passphrase envelopes or the new catalog filename;
compatibility reads old backups into Quietake, not the reverse.
