# Portable encrypted backup

Settings → Create encrypted ZIP checks the current passcode and saves a copy
through the system Files picker. Keep the independent recovery key separately.
The archive does not contain the recovery key, local passcode, wrapped keyfile,
NAS credentials or deletion journal. Export leaves vault originals unchanged.

Fresh Setup → Restore encrypted ZIP selects a copy, asks for its recovery key and
a new local passcode, and validates every capture and the private library before
adoption. Restore is available only with no existing credentials, captures,
catalog or deletion journal. Existing vaults cannot merge or replace identities.
After restoration, unlock with the new passcode. That first unlock enables the
optional biometric cache. The recovery identity remains unchanged.

A ZIP is a snapshot of the current local library, not proof that the NAS is
current. Pending NAS deletions remain with the original installation because
this archive carries no deletion authority. Finish that installation's NAS sync
before reconnecting a restored vault to the same folder; otherwise old remote
captures may be downloaded again. Use one active installation per NAS folder;
concurrent writers and multi-device merging are not supported.

Preparation can be cancelled. Private staging is removed; the external source is
read-only. Once validated files and a wrapped keyfile have a durable ready marker,
startup finishes interrupted adoption. Failed completion preserves prepared
encrypted data and offers Retry. Do not clear app storage to fix this error;
retain the source ZIP and recovery key.

## Archive schema 1

This is an AES-256 WinZip archive with stored entries. Its password is the
normalized base64 representation of the existing random 256-bit recovery key.
The app accepts its normal recovery-key input form and normalizes it internally.
There is no weak user-selected ZIP password. Counts and encrypted byte lengths
remain visible in the ZIP directory, but capture names and titles do not.

- `item-00000.shtr`, etc.: unchanged authenticated v1 media containers.
- `catalog.shtr`: unchanged encrypted private catalog.
- `manifest.shtr`: encrypted v1 metadata container with a JSON object containing
  `version: 1`, `hash: "sha256"` and a `files` array. Each record maps `entry` to
  original `name`, complete encrypted `size` and hexadecimal SHA-256 `digest`.

The media container version remains 1. The manifest has its own schema version;
frozen container vectors and independent recovery CLI reads remain unchanged.
The first package permits at most 10,000 captures and a 2 GiB complete archive.
It rejects ZIP64, compression, comments, split archives, links, directories,
duplicate or colliding names, traversal, unexpected entries and malformed
lengths. Central metadata, manifest and catalog allocations have separate bounds.
Complete WinZip authentication, inner-container authentication, manifest hashes
and catalog schema validation all precede adoption.

Desktop recovery from this portable envelope is not automated by the recovery
CLI. Its existing folder/WebDAV inputs and v1 container recovery remain supported.
Use app restore for the complete portable schema and retain the source archive.
