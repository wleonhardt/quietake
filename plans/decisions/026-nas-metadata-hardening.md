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

## Slice 4 done: recovery restores capture names

`recover/names.go` decrypts `quietake.catalog` in memory (2 MiB cap), reads `remoteNames`, and writes
randomly named containers under their capture names. Unreadable catalogs, unlisted files, duplicate
claims, non-`.shtr` or path-like local names and output collisions all keep the generic name and never
fail the run. Tests: `recover/names_test.go` (table) and a new Dart-to-Go case in
`tool/check_interop.dart`; Go checks and interop pass. Next: wire `useRandomNames` into
`SyncController` (default decision needed: on for new uploads only), then the lost-mapping rebuild.

## Lost mapping rebuild done

When an unmapped remote file has a random-looking name (32 hex digits plus `.shtr`) and no phone
copy under that name, sync compares its ciphertext with phone captures that have no NAS copy. A match
records the mapping (`PrivateCatalog.adoptRemoteNames`) and the file is neither adopted as a copy nor
deleted. No match means the file is pulled as a new capture, as before. This also repairs a vault whose
catalog an older app version saved without `remoteNames`. Limits: it needs the phone copy, so a fresh
phone with a lost catalog still adopts randomly named files under their random names (the recovery
tool cannot rename them either without the catalog); two identical remote copies match one capture and
the second stays unmapped on the NAS. Tests: `random_remote_names_test.dart` (rebuild, stray pulled),
`remote_names_test.dart` (adopt); host suite 773 passed.

## Restore fixed, catalog limit raised, controller option added

Found while preparing to wire the flag: in-app NAS restore (`NasRecovery.restore`) used remote names as
local names, which would have orphaned the catalog entries of a randomly named backup. It now maps names
through the staged catalog's `remoteNames` (test in `nas_recovery_test.dart`) and rejects a mapping that
would make two files share one name. The catalog plaintext budget is now 2 MiB (was 1 MiB) because each
mapping costs about 85 bytes; the recovery tool's in-memory cap is 4 MiB; an older app version rejects a
catalog over 1 MiB as too large (documented in `docs/private-catalog.md`). `SyncController` takes
`useRandomNames` (default false, passed to `SyncService`, tested). The app still passes false.
Before turning it on: owner review of policy and `docs/container-format.md` wording, a look at the
integration tests that assume capture names on the NAS (`integration_test/`), and a Settings switch or
a decision to enable it for all new uploads. Slice 5 (rename of existing remote files) is not built.

## Slice 5 service done: rename of existing remote files

`SyncService.renameRemote({dryRun})` renames captures that sit on the NAS under their readable name. Only a capture with an identical-size copy on the phone qualifies, and never one that is deleted, trashed, already mapped or already randomly named. The mapping is saved in the catalog first, each file moves on the server with one `MOVE` that cannot overwrite (instead of copy, verify and delete, because a server-side move never leaves two copies), a closing listing must show every new name at the old size and the old name gone, and then a normal sync uploads the catalog that carries the names. An interrupted run resumes with the saved mapping. Tests in `test/random_remote_names_test.dart` (dry run, rename and quiet next sync, restore on a fresh phone, second run, resume, capture missing on the phone). Not built: the Settings action with its dry-run preview and confirmation; it needs the owner to approve the wording and the decision to enable `useRandomNames` in the app, since a renamed vault must not be used with an older app version.

Owner answer 2026-11-16: build the Settings action (dry run preview, confirmation, rename) and enable random names for new uploads after it. Older app versions must not open a renamed vault, so the Settings text must say so.

## Settings action done 2026-11-16

Settings, Backup section, has "Give NAS files random names" (`Keys.settingsRenameRemote`, enabled only with a saved NAS). It runs `SyncController.renameRemote(dryRun: true)` through the exclusive recovery gate, says so when nothing qualifies, otherwise asks with the count and a warning that older versions on other phones cannot find renamed files, and on confirm renames and reports the count; a failure says the run can be repeated and nothing was lost. Strings exist in en, es, fr and de; the wording needs owner review and native review of the translations. Tests: controller test in `test/sync_controller_test.dart`, widget tests in `test/settings_access_test.dart` (disabled without a NAS, preview, dialog, rename, report), Android `settings_icon_test.dart` as a Settings regression. Not done: enabling `useRandomNames` for new uploads in the app (next slice), and a run against a real NAS.

## Random names enabled for new uploads 2026-11-16

`Session` now builds its `SyncController` with `useRandomNames: true` (parameter `randomRemoteNames`, default true), so every new upload from the foreground sync gets a random NAS name and the mapping goes into the catalog. Device tests and the Settings widget test pass `false` because they read capture names on a fake server; `test/session_test.dart` checks both values. Known limit: the Android background uploader (`BackgroundTransfer.kt`) still uploads a capture it has not seen confirmed under its capture name. Those few files keep a readable name until a later "Give NAS files random names" run renames them; teaching the native uploader the mapping is a follow-up. Older app versions on other phones cannot open a vault that uses random names, so the release notes and the rename dialog say to update every phone first. Not done: a device run of the random path, a run against a real NAS.

## Android background uploader and random names 2026-11-16

The foreground pass now hands the native job a `remoteNames` map (local name to NAS name) for captures that are not confirmed yet and for deleted captures, but only while names are random; otherwise the key is absent and the job behaves as before. `BackgroundTransfer` uploads a mapped capture under its mapped name, never uploads a capture that has no mapping (it waits for the foreground sync, so no capture name reaches the NAS), and removes both the readable and the mapped name when a deletion marker exists. `BackgroundUploads.kt` validates the map (at most 20000 entries, `.shtr` single-segment names). Tests: two new JVM tests in `BackgroundTransferTest.kt` (23 pass), Dart tests in `test/background_uploads_test.dart` and `test/sync_controller_test.dart`, Android `background_test.dart` still passes. Consequence to review with the owner: in random-name mode the background job does not upload captures taken after the last foreground pass, because their random names are only assigned by the foreground sync; the next foreground sync uploads them. A fix would let the job pick random names itself and report the pairs for the app to adopt through `adoptRemoteNames`.
