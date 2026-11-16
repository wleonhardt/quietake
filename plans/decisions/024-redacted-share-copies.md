# 024 Redacted share copies

Status: accepted for step 1 (the pixel function). The editing screen and the share
dialog entry are step 2 and are not built yet.

## Decision

A share copy can have chosen regions hidden before it leaves the app. The vault
original never changes. Step 1 adds `redactToPng` in `lib/gallery/redact.dart`:

- Input: decoded image bytes (JPEG or PNG) and rectangles in 0..1 image
  coordinates. Output: a PNG, because Flutter can encode PNG but not JPEG and this
  adds no image package.
- Each rectangle is pixelated with large blocks, at most four blocks across its
  longer side and never smaller than 16 pixels, so a face or text under it cannot be
  recovered. The block color is the average of its source pixels.
- The PNG is built from raw pixels, so it carries no EXIF, XMP or other metadata.
- Rectangles are clamped to the image; an empty or outside rectangle changes nothing.

## Reasons and limits

- Redaction is destructive in the copy only. The share dialog will say so and will
  keep the metadata switch for plain copies.
- Output size is larger than the JPEG source. Acceptable for an occasional share.
- Orientation follows what Flutter's decoder shows, the same as the gallery preview,
  so rectangles drawn on the preview line up with the pixels changed.
- Automatic face detection is not part of this decision.
- Step 2 must decrypt into private storage only, delete the copy after sharing like
  other share copies, and add Spanish, French and German text.
