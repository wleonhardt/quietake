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
  retries them. Exact-duplicate detection still protects against a lost ledger. A damaged or unreadable ledger is treated as lost: the
  folder restarts instead of failing every run (2026-11-17).
- The ledger is local only. Sync uploads `.shtr` containers and the catalog, so
  the ledger is never sent to the NAS, and a lost ledger costs only time.

## Slices

1. Pipeline, ledger and `FolderSource` interface with host tests (this record).
2. Native pickers (done): channel `quietake/folder` with `pick`, `copy`, `cancel` and
   `release`. Android uses `ACTION_OPEN_DOCUMENT_TREE` and `DocumentsContract`
   (`FolderImport.kt`); iOS uses a folder `UIDocumentPickerViewController` with
   security-scoped access held until `release` (`FolderImportPicker` in
   `PrivateImport.swift`, so the Xcode project needs no new entry). Both list only
   direct children, cap the list at 10,001 so Dart can refuse the folder, and copy
   one file at a time with the same 32 MiB photo and 512 MiB video bounds as file
   import. `PickedFolder` is the Dart `FolderSource` over the channel. No
   screen uses it yet, so device runs only prove the native code compiles and
   existing import still works; the pickers need the screen slice to be exercised.
3. Import screen (done): "Choose folder" button under "Choose files", count progress,
   one summary line, and "Choose the same folder again to continue" when files failed
   or were not started. Device test mocks the folder channel over real files.
4. Policy and website wording (done, owner review pending).

## Limits

- Subfolders are not walked; only direct children are imported. A recursive walk
  can be added once the owner asks.
- Progress counts files, not bytes.
