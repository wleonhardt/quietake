# 026 NAS metadata hardening

Status: accepted 2026-11-16 (owner): option A, random remote names, plus a later owner-approved rename of existing remote files. Option B stays out. No code yet.

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

## Accepted 2026-11-16: slice plan (owner chose A plus later rename)

Reading `lib/sync/sync_service.dart` shows the remote name is the identity everywhere: the
listing, the deleted-name journal, `local` and `remote` maps, pull, verify and delete all
compare a remote name with a local file name. Random names therefore need a mapping layer, not
a rename at the upload call. Slices, each with tests and its own commit:

1. `RemoteNames`: a pure class mapping local name to remote name and back, with a generator
   (128-bit random hex plus `.shtr`), plus an optional `remoteNames` catalog field that old
   readers ignore. No sync change yet. Tests: round trip, uniqueness, rejects bad names.
2. Push: a new capture gets a random remote name that is saved in the local catalog before
   the upload starts, so a crash between upload and catalog upload leaves a mapped file, not an
   orphan. Captures already on the NAS keep their name (mapping maps a name to itself).
3. Pull, verify, delete and the deleted-name journal go through the mapping. A remote name
   missing from the authenticated catalog is never adopted or deleted without opening it with
   the key, and absence never means deletion (AGENTS.md).
4. Go recovery tool reads the catalog mapping, and prints generic names when the catalog is
   missing. Frozen vectors stay; `docs/nas-recovery.md` and `docs/container-format.md` change.
5. Rename of existing remote files: separate, owner-approved action in Settings with a
   dry run; copy under the new name, verify, then delete the old one.

Open risk for slice 3: restore on a fresh phone needs the catalog first to learn local names.
If the catalog is lost, media can still be opened by key but only under generic names.

## Slice 1b done: catalog field

`PrivateCatalog` now keeps an optional `remoteNames` object (local name to remote name), written
only when not empty, so older files load unchanged and older readers that ignore unknown keys
still work. `assignRemoteName(local)` is idempotent and saves before returning. `restore` adopts
the mapping from an incoming catalog. `forgetDeleted` deliberately leaves mappings alone: slice 3
must drop a mapping only after the remote delete succeeded.
Limit found: each mapping adds about 85 bytes to the 1 MiB catalog (`maxBytes`), so around
10,000 mapped captures would use most of it. Slice 2 must either raise the limit consciously or
store the mapping compactly (the 16-byte random value as hex is already the minimum for the name).
Compatibility risk found: an older app version that saves the catalog drops `remoteNames`
(documented in `docs/private-catalog.md`). Slice 2 must therefore also let `sync` rebuild a
missing mapping by opening remote containers with the key before it adopts or deletes anything.

## Slices 2 and 3 done together, behind a flag

Push alone would make the next sync treat every randomly named file as a new remote capture, so
push, pull, verify and delete moved together. `SyncService(useRandomNames: false)` is the switch;
`SyncController` does not pass it, so the app still uploads under capture names. What changed:
the remote listing is keyed by local name through `RemoteNames.localFor`, and every `dav` call
uses the real remote name. A vault with no catalog reads the mapping from the incoming catalog
before choosing names. New uploads are assigned in one catalog save (`assignRemoteNames`) before
the first upload. Tests: `random_remote_names_test.dart` (default unchanged, random upload and a
quiet second sync, fresh phone pull, confirmed delete, check backup); full host suite 770 passed.
Not done: slice 4 (Go recovery reads the mapping) must land before the flag is wired to the
controller; a lost mapping makes the next sync adopt randomly named files as new captures
(duplicates, no data loss), so rebuild by matching ciphertext is still open; the 1 MiB catalog
limit is unchanged; rename of existing remote files (slice 5).
