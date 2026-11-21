# 045 Thumbnails are stored encrypted on the phone

Status: accepted as the default 2026-11-18 (review item R39; no owner question was open). Built.

## Problem

Every tile in the library decrypted its whole capture to draw a 300 pixel preview, and kept
only 8 MiB of decoded previews in memory. Scrolling a library therefore decrypted and decoded
full photos again and again; with full-sensor photos (decision 034) each one is several
megabytes. A video tile needed the local media server and a native frame grab every time.

## Decision

- The first time a capture's preview is made, the app stores it as a small JPEG (longest side
  300 pixels) encrypted under the vault key, in `vault/.thumbs/<container name>.thumb`. Later
  the tile reads and decrypts that file only.
- The file is an ordinary v1 container. Its plaintext is one version byte (1), four bytes with
  the video duration in milliseconds (big-endian, `FFFFFFFF` for a photo), then the JPEG.
- It is a cache, not part of the vault's contents:
  - never uploaded, never in a ZIP backup, not read by the recovery tool (the `.thumb` suffix
    and the folder keep it out of every listing of `.shtr` files);
  - deleted with its capture; kept while the capture is in Recently deleted;
  - rebuilt from the capture when it is missing or does not decrypt or decode.
- The JPEG is encoded by the platform (`quietake/previews`, method `encode`), because Flutter
  can only encode PNG and a PNG preview is about eight times larger. If encoding or writing
  fails, the preview is still shown and nothing is stored, as before.
- Decoded previews are still held in memory under the same 8 MiB budget and dropped on lock.

## Limits

- The first view of each capture costs what every view cost before, plus a few milliseconds
  to encode and write. A restored or freshly synced library builds its thumbnails as it is
  scrolled.
- Thumbnails take space that Settings, Storage does not count: about 10 to 25 KiB each.
- The thumbnail files reveal the number of captures viewed and their container names to
  anyone who can read the app's private storage; the containers next to them reveal the same.
- Not measured on a phone.

## Evidence

`test/thumbnail_store_test.dart`: the thumbnail is stored encrypted, a second load does not
read the capture, a video keeps its duration, a damaged thumbnail is rebuilt, and deleting the
capture deletes the thumbnail. Device runs are listed in `plans/review-fixes.md`.
