# Private catalog schema 1

Decision 036 presents the existing flat albums as reusable tags. The `albums`
map and item membership fields below remain the schema-1 compatibility alias;
IDs, names and memberships are preserved without migration. Older clients still
display these same groups as albums. Multi-tag add/remove and merge each commit
one encrypted transaction. Merge unions memberships into the destination ID and
removes the source ID, including references to pending captures. Stale edits
using a removed ID fail instead of recreating it. Tag operations never delete
media or rewrite its encrypted container.

`quietake.catalog` is an authenticated v1 container in the private vault directory
and the WebDAV backup collection. It is separate from `.shtr` media. The master
key is the existing vault key; no key or wrapped passcode file is backed up with
this manifest. Encryption bytes follow `container-format.md` unchanged.

Decrypted UTF-8 JSON has this shape:

```json
{
  "version": 1,
  "albums": {"opaque-album-id": "Album name"},
  "items": {
    "2026-10-26T12-30-00.000Z.jpg.shtr": {
      "title": "Optional display name",
      "favorite": true,
      "albums": ["opaque-album-id"]
    }
  }
}
```

Names are trimmed and limited to 120 characters. Empty capture titles use the
immutable filename for name sorting. Album names are nonempty and unique ignoring
case when edited in the app. IDs are opaque; new IDs contain 128 random bits.
References use direct-child media filenames and must end in `.shtr`. Albums are
flat. Missing media references are harmless and never recreate or delete files.
The local deletion journal remains authoritative independently of this document.
Camera album choices use these existing memberships. After private staging,
the camera commits the destination filename's membership before publishing media.
An interrupted save recovers to the same name; until then the reference remains
invisible in Library. Metadata failure does not prevent secure media saving and
is reported separately. No plaintext organization sidecar or schema change is used.
Confirmed removal also prunes matching metadata during deletion, library reload
and sync, retaining other captures and albums. Damaged metadata is preserved for
repair and cannot block confirmed media removal; cleanup resumes after repair.

The plaintext budget is 1 MiB. Unknown schemas, invalid references and failed
container authentication are rejected before adoption. There is no automatic
reset or lossy migration. Missing manifests represent an empty library. Mutations
are serialized, encrypted directly from memory to a temporary sibling, and
atomically renamed before changing visible state. An interrupted sibling is
ignored. A failed reload disables writes until a successful reload. Recovery requires a
matching key even when this manifest is the vault's only encrypted content. One
catalog owner exists per unlocked vault; its initial load removes abandoned
encrypted upload directories before creating any live snapshot. Later reloads
preserve the current owner's in-flight snapshot.

Sync uploads an immutable encrypted snapshot after media transfers, including
same-length edits. Remote metadata restores only if the local manifest is absent;
absence is checked again after download and authentication inside the write
queue. Local edits win when both exist. Concurrent editing across installations
and remote version history are not supported. The normal session sync queue
retries committed edits arriving during transfers on its next pass. Interrupted
uploads retry on the next unlock; no OS-terminated uploader was added.

The current Go recovery CLI authenticates and exports this file as
`quietake.catalog.json`, or verifies it with `-check`. Earlier CLI versions skip
metadata and still recover media. Keep the JSON private: its names and grouping
are decrypted information.


Legacy `tucklight.catalog` containers remain readable through authenticated
portable restore, explicit legacy NAS restore and the recovery CLI. Their schema
and ciphertext are unchanged; only the restored local filename is normalized.
Ordinary sync refuses legacy or mixed collections rather than replaying deletions
or creating competing catalogs. See [identity migration](identity-migration.md).
