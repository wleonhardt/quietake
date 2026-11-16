# 020 Folder import with progress and resume

Status: accepted. The owner approved folder import with progress and resume on
2026-11-16. Built in slices; this record covers the shared pipeline first.

## Decision

A folder import copies the supported files of one chosen folder into the vault, a
bounded chunk at a time, and can be run again to finish what was interrupted.

- The platform gives Dart a `FolderSource`: a list of entries (stable id, name,
  size) and a call that copies one entry into the private staging directory.
  Originals are never opened for writing, moved or deleted, as with file import.
- `FolderImport` lists the folder, drops unsupported names, refuses more than 10,000
  files, and processes the rest in chunks of 20 through the existing
  `MediaImporter`, so validation, size limits, duplicate detection and
  encryption are unchanged. Staging is emptied after every chunk, so at most 20
  plaintext copies exist at once, only in private app storage.
- A shared digest cache lets later chunks reuse the vault scan done for earlier
  ones instead of repeating it per chunk.
- Resume uses an encrypted ledger of source entry IDs already imported or skipped
  as exact duplicates. The ledger lives in the vault directory under
  `.import/<folder key>.ledger`, is written with `Vault.writeMetadata` after
  every chunk, and is keyed by a hash of the folder identifier so no folder name
  is stored in clear. Failed and cancelled entries are not recorded, so a rerun
  retries them. Exact-duplicate detection still protects against a lost ledger.
- The ledger is local only. Sync uploads `.shtr` containers and the catalog, so
  the ledger is never sent to the NAS, and a lost ledger costs only time.

## Slices

1. Pipeline, ledger and `FolderSource` interface with host tests (this record).
2. Android folder picker (Storage Access Framework tree) and iOS folder picker.
3. Import screen: "Choose folder" button, progress by count, resume prompt, e2e.
4. Policy and README wording.

## Limits

- Subfolders are not walked; only direct children are imported. A recursive walk
  can be added once the owner asks.
- Progress counts files, not bytes.
