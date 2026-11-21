# 032 Subfolders in folder import

Status: accepted 2026-11-17 (owner chose the build-on list). Switch and native listing built; tags from folder names not built.

## Decision

Folder import (decision 020) can also read folders inside the chosen one, only when the person turns on "Include subfolders" on the Import screen. The switch is off every time the screen opens and is never saved.

- The platform picker gets `{'subfolders': bool}` on the `quietake/folder` `pick` call. Off means direct children only, exactly as before.
- On, Android walks the document tree breadth first and iOS walks the folder, both at most 6 levels down, and both stop at 10,001 entries so Dart can refuse a folder over the existing 10,000-file limit. iOS skips symbolic links and hidden files. Android document IDs are already unique across the tree; iOS entry IDs are the path below the chosen folder, and `copy` rejects an ID that is absolute or contains `..`.
- Nothing else changes: the same read-only source, 32 MiB photo and 512 MiB video bounds, chunks of 20, duplicate detection and encrypted resume ledger. A ledger from a run without subfolders stays valid, because entry IDs of direct children are unchanged.
- Policy: the published sentence "reads only that folder's files, not its subfolders" is true only while the switch is off. Draft G in decision 030 replaces it; publish it before any release that includes this switch.

## Not built

Turning each folder name into a tag (the idea's optional part): it would write folder names into the catalog, which needs its own owner call.

## Verification

Host test `import_screen_test.dart` (the switch is off by default and its state reaches the picker call); suite 850 passed; `flutter analyze` clean; Android Kotlin compile and JVM tests pass; the iOS simulator build, `startup_test.dart` and `import_test.dart` pass. Not verified: a real walk of a folder tree on either platform (the system pickers cannot be driven from a script), the 6-level and 10,001 bounds on a real tree, and the translations (native review).
