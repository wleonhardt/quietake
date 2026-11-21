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
- Policy wording: `website/app-privacy.html` (Optional sharing) and the in-app policy do not mention
  hiding areas. They say PNG copies are not changed, which stays true for ordinary copies; a
  redacted copy is a new PNG without metadata. This is not a contradiction, but the owner should
  decide whether to add a sentence. Policy text is owner-reviewed, so it is not edited here.

## Several photos at once (2026-11-17)

The share dialog now offers "Hide parts of these photos…" whenever the selection holds at least one photo (videos in a mixed selection are shared unchanged). It opens one `RedactScreen` per photo in order; backing out of a page stops there and keeps the earlier choices, and the label then reads "Hidden areas: N in M photos. Change…". `_regions` is a map by capture name, so `shareMediaCopies` (already keyed by name) needs no change. Photos with areas become metadata-free PNG copies; the metadata switch stays until every photo has areas. Each photo is decrypted only while its page is open, as before. en/es/fr/de strings, translations need native review. Face-box suggestions are not built (they need a dependency decision). Tests: `share_dialog_test.dart` (two photos, two pages, two PNGs); host suite 851 passed; iOS `sharing_test.dart` passes; Android not rerun. Policy sentence C already covers hiding parts of a photo before sharing; no change.

## Proposed policy sentence (draft, awaits owner review, not yet published)

Insert after "...PNG and video copies are not changed." in the Optional sharing section of
`website/app-privacy.html` and the matching in-app policy text:

> For a single photo you can also hide areas before sharing. The shared copy is then a new PNG in
> which those areas are replaced by coarse blocks and which carries no metadata; the original in
> your vault is not changed. Anything you leave visible, and the picture's own content, can still
> identify a place or person.

The policy tests and the in-app policy copy (with es/fr/de if translated) must change together with the website.

## Change 2026-11-18: a hidden area is one black block

The owner chose a flat black block over the coarse averaged blocks described above. The averaged
blocks still carried the colours of what they covered, and the approved policy sentence says
"solid blocks". `redactToPng` now paints every pixel of a hidden area opaque black, and the
share dialog says "covered in black" instead of "pixelated" (en, de, es, fr; translations need
native review). Test: `test/redact_test.dart`, "a region becomes one black block and the rest
keeps its pixels".
