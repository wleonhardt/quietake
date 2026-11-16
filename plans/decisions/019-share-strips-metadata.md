# 019 Share copies keep only orientation

Status: accepted. The owner chose "every EXIF except orientation" on 2026-11-16. The
privacy policy and website wording below changed with it and still needs the
owner's review.

## Decision

The share option that was "Remove GPS from JPEG photo copies" now removes all
personal metadata from JPEG copies and is on by default. `withoutMetadata` in
`lib/gallery/exif_strip.dart` replaces `withoutLocation`:

- Every EXIF segment is removed, then one minimal big-endian EXIF segment with only
  orientation (1 to 8) is written at the first EXIF position. No orientation, or a
  value outside 1 to 8, leaves no EXIF segment.
- XMP, Photoshop/IPTC (APP13), comments (COM) and the multi-picture directory
  (MPF) are removed. JFIF, ICC profiles, quantization and scan data are untouched,
  so pixels are never re-encoded.
- A damaged JPEG or EXIF layout still throws before any copy reaches the chooser.
- PNG and video copies are unchanged. Video metadata removal stays a later item.
- Turning the switch off still shares the original bytes.

## Reasons and limits

- The earlier approach zeroed only GPS values and kept camera model, time and
  thumbnails, which can identify a device or show an unredacted preview. Rebuilding
  the segment drops all of it and removes the aliasing checks that approach needed.
- The EXIF thumbnail is removed, so a recipient never sees a pre-edit preview.
- Orientation alone can be set by a camera and says little; it is kept so photos
  do not appear rotated.
- The switch key stays `shareStripLocation` so existing tests and device runs keep
  working.
- The vault original and the in-app viewer are unchanged.
