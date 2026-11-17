# 024 Redacted share copies

Status: accepted. Step 1 (the pixel function) and step 2 (editing screen and share
dialog entry) are built.

## Decision

A share copy can have chosen regions hidden before it leaves the app. The vault
original never changes. Step 1 adds `redactToPng` in `lib/gallery/redact.dart`:

- Input: decoded image bytes (JPEG or PNG) and rectangles in 0..1 image
  coordinates. Output: a PNG, because Flutter can encode PNG but not JPEG and this
  adds no image package.
- Each rectangle is pixelated with large blocks, at most four blocks across its
  longer side and never smaller than 16 pixels, so a face or text under it cannot be
  recovered. A region or image shorter than 16 pixels becomes one flat block (a fix
  after review: it used to throw). The block color is the average of its source pixels.
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

## Step 2 as built

- The share dialog shows "Hide parts of this photo…" only when exactly one photo is
  selected. Videos and multi-item shares are unchanged.
- `RedactScreen` decrypts the photo into memory only while it is open, lets the owner
  drag rectangles (down position starts the rectangle), undo the last one and press
  Done. Going back keeps the earlier choice. The screen closes when the app locks.
- With areas chosen, the dialog hides the metadata switch (a PNG has none) and says the
  copy becomes a PNG with those areas pixelated. `shareMediaCopies` takes
  `redactions` keyed by capture name and shares `photo-<id>.png` as `image/png`.
- Drawing needs a pointer, so the screen also offers nine labeled section chips
  ("Row 2, column 3") that toggle one third of the photo each. They work with a
  keyboard or screen reader and share the same list of areas as dragging. Finer
  placement for assistive technology is not built.
- Tests: `redact_screen_test.dart`, `redact_test.dart`, `share_media_test.dart`,
  `share_dialog_test.dart`. `sharing_test.dart` drives the editor through a section chip
  on Android and iOS (shared copy is a PNG, vault original unchanged); the drag gesture
  itself is covered by host tests only.
