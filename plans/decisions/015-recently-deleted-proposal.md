# 015 Recently deleted (proposal)

Status: proposed. Needs the owner's answer to the open questions before slice 1.

## Why a proposal

Recently deleted changes what "delete" means: an encrypted copy stays on the phone
for a while. That touches the deletion journal, NAS sync, the privacy policy text
and what users expect from Delete. It is too large and too user-visible to build
one small step at a time without an agreed shape.

## Proposed design

- A trashed capture moves from the vault directory to `trash/NAME.shtr` with a
  small `trash/NAME.at` file holding the trash time. The container bytes do not
  change, so the v1 container contract and frozen vectors are untouched.
- `Vault.list()` does not list trashed captures, so the Library, Moments, counts
  and viewer ignore them. The catalog entry (title, tags, favorite) stays, because
  only the deletion journal authorizes metadata cleanup today.
- Restore moves the file back. Purge ("Delete now" or older than 30 days) runs the
  existing `Vault.delete` path, which writes the deletion marker and lets sync
  remove the NAS copy as it does today.
- Sync holds trashed names: it does not pull them back from the NAS, does not
  delete them there, and does not upload them. This keeps the rule that backup
  never infers deletion from absence. Without the hold, a NAS copy of a trashed
  capture would be downloaded again as a new capture.
- Slices: (1) vault layer with plain unit tests and the sync hold; (2) Delete moves
  to trash, plus a Recently deleted screen with Restore, Delete now and days left;
  (3) purge at startup and Settings storage text; (4) privacy policy and docs wording.

## Open questions for the owner

1. Should Delete keep captures for 30 days by default, or only after the user turns
   on a "Keep deleted captures for 30 days" setting? Default off keeps today's
   behavior and privacy expectation; default on matches common photo apps.
2. Is it acceptable that a deleted capture stays encrypted on the phone and on the
   NAS for up to 30 days? The privacy policy and `website/app-privacy.html` would
   need reviewed wording.
3. Should "Delete now" from the viewer skip the trash for people who want an
   immediate delete?

## Slice 4: documentation and proposed privacy policy wording

README and `docs/portable-backup.md` now describe Recently deleted. The portable ZIP
export lists the current library only, so trashed captures are not exported
(covered by `test/portable_backup_test.dart`).

The owner approved this wording on 2026-11-16. It is now in `assets/privacy-policy.json`
and `website/app-privacy.html` (updated date November 16, 2026), and `tool/ci_scope.py`
checks that the two match. The first sentences of "Retention and deletion" are:

> You can delete an individual capture from the viewer. By default Quietake first
> moves it to Recently deleted, where it stays encrypted on this device for 30 days
> and its copy on your WebDAV server is kept. You can restore it, delete it now, or
> let it expire; deleting now or expiry removes the local copy and requests
> deletion from the configured WebDAV server as described below. A Settings switch
> turns Recently deleted off, so Delete removes the capture immediately.

The rest of the section stays as written. The recovery-key warning applies to
Recently deleted captures too, since they are ordinary encrypted containers.
