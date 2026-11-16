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
2. Tags screen: show the cover thumbnail and add a "Set cover" action that picks
   from the tag's captures, plus a viewer action to use the current capture.
