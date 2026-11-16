# 018 Optional tag cover in catalog schema 1

Status: accepted. The owner chose to add an optional field on 2026-11-16.

## Decision

Catalog schema 1 gains an optional top-level `covers` object that maps a tag ID to
one capture name. The version stays 1. The key is written only when at least one
cover exists, so catalogs without covers are byte-for-byte what earlier clients
wrote. `PrivateCatalog.covers` reads it and `setCover(id, name)` sets or, with
null, clears it.

## Rules

- Decode rejects a cover whose tag does not exist or whose value is not a valid
  direct-child `.shtr` name. A cover naming media that is gone is allowed.
- Deleting a tag removes its cover. Merging keeps the destination cover, or takes
  the source cover when the destination has none. Confirmed media removal clears
  covers that name the removed capture.
- Older clients ignore the unknown key but drop it on their next save. That is an
  accepted loss because a cover is a display hint only.
- The Go recovery CLI exports the catalog as opaque bytes, so it needs no change.

## Slices

1. Data layer, docs and tests (this record).
2. Tags screen (done): the tag row shows the cover thumbnail through the session
   preview cache, a menu action "Set cover" opens a grid of up to 60 of the tag's
   newest captures, and "Clear cover" appears when one is set. A cover that is
   missing from the library shows the plain tag icon. Covered by the device test
   `integration_test/library_test.dart`; the host test covers only the empty
   picker because a catalog write from a widget test hangs `Session.close`.
3. Viewer shortcut to use the current capture: not built; add only if asked.
