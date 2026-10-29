# Quietake brand assets

Decision 035 selects the Camera studio direction. The vector master combines a
camera outline with a Q-shaped lens. Geometry is authored in the repository; no
external image service or font dependency is required. Earlier pocket-and-light
exploration remains in `release/brand-exploration/2026-10-21/` as history.

- Graphite: `#121923` for the dark canvas, icon and native privacy cover.
- Cobalt: `#2850B9` for light-mode primary actions; `#4E70E8` for the lens mark.
- Pale blue: `#BFD1FF` for dark-mode primary actions and camera outline.
- Light canvas/text: `#F1F3F6` / `#142033`; dark text: `#EDF3FF`.
- Descriptor: “Private camera”. Supporting artwork copy: “Capture. Keep. Yours.”

The app follows system light/dark appearance and offers system high-contrast
variants. Camera and media canvases remain dark. Semantic recording/error and
backup-status colors retain their meanings. Typography uses platform fonts.

The runtime PNG is 256×256, displayed at 80 logical pixels. Android adaptive
foregrounds fit inside the central safe region; the launcher supplies its own
mask. The monochrome vector preserves the camera and lens cutouts with even-odd
fills. iOS and legacy Android exports have opaque backgrounds without baked-in
masks. Internal `tucklight` resource filenames are retained; they are not display
names and do not require a data or package migration.

After editing `quietake.svg`, regenerate Flutter, native icons/splash images and
draft store artwork from the repository root:

```bash
python3 tool/export_brand.py
```

This uses `rsvg-convert` from librsvg and also generates the Android monochrome
vector. Store artwork remains a local draft, not a published listing. Name,
publisher, domain, signing and publication gates remain in `release/README.md`.
