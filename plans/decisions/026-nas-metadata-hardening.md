# 026 NAS metadata hardening

Status: proposed. Waiting for the owner's go or no-go and a choice of option. No code.

## Problem

`docs/container-format.md` says the NAS sees each container's name and exact length.
Names are the local capture names plus `.shtr`, such as `2026-10-26T12-30-00.000Z.jpg.shtr`,
so the NAS learns when each capture was taken, whether it is a photo or a video, and
roughly how large it is. `quietake.catalog` is the only other object. Content is already
unreadable.

## Options

A. Random remote names (recommended first step). New uploads use a random 128-bit hex
   name. The encrypted catalog records the mapping from local name to remote name, so
   the app can find and delete remote files. This removes time and media type from the
   NAS view. The independent recovery tool names its output by container name today, so
   it must read the catalog mapping or write generic names; that needs Go changes,
   updated vectors for the mapping field and a README note. Existing remote files keep
   their names until a separate, owner-approved rename step; the app never infers a
   deletion from absence (AGENTS.md).

B. Size padding. Hiding exact lengths needs a container change: the v1 length formula is
   fixed and readers treat any trailing bytes as corruption. Padding means container
   version 2, new frozen vectors and Go support. Not recommended until A is shipped.

C. Do nothing and keep the documented exposure.

## Risks to check before building A

- Sync must keep working when the catalog is missing or stale: a remote file with an
  unknown random name could look like a stray. The first step needs a recovery path
  that lists remote names and matches them by opening each container with the key.
- Backup must still authenticate ownership of everything it deletes or replaces.
- Moments and capture-time features read local names only and are unaffected.

## Needs the owner

- Go or no-go on A, and whether renaming existing remote files is ever wanted.
- Whether the recovery tool should print generic names or read the catalog.
