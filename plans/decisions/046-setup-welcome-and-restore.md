# 046 First run starts with a choice, and restore has its own page

Status: accepted as the default 2026-11-18 (review item R51; the owner has not seen the wording).
Built.

## Problem

The first screen was a passcode form followed by four links of equal weight: "I have a recovery
key", "Restore an encrypted ZIP", "Restore from NAS with backup passphrase" and the privacy
policy. A new user met two empty passcode fields with no word on what the passcode is for or
that nothing can reset it. A returning user had to find the right restore link among three
that name storage formats.

## Decision

Setup has three steps in one screen, with Back between them.

1. Welcome: the brand, two sentences on what the app does and that the passcode cannot be
   reset, then two buttons: "Create a new vault" (primary) and "Restore a vault I already
   have". The privacy policy link stays here.
2. Create: the passcode form as before, then the recovery key and its check (decisions 041
   and 042).
3. Restore: one page that lists the ways to restore, each with a line saying what it needs:
   - with the recovery key (the key form, then a new passcode);
   - from an encrypted ZIP (the ZIP and the recovery key);
   - from the backup server (the server address and the backup passphrase).

"Forgot passcode" on the lock screen still opens the recovery key form directly.

## Limits and open points

- One more tap before the first passcode.
- The wording is a draft for the owner (`plans/open-questions.md`); translations are drafts.
- The restore options are still three separate flows behind the page.

## Evidence

`test/setup_screen_test.dart` ("first run starts with a choice; Back returns step by step", the
privacy policy from the welcome step, the restore page opening the ZIP and server screens).
Device runs are listed in `plans/review-fixes.md`.
