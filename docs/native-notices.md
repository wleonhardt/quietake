# Android native open-source notices

Quietake displays native notices through its existing Flutter Licenses page.
The Android registration includes the retained coroutines notice and
`assets/licenses/google-play-services-NOTICES.json`.

The Google notice asset preserves the complete UTF-8 text slices indexed by
`third_party_licenses.json` in the resolved Google AARs. Its `artifacts` list
records Maven coordinates, versions and SHA-256 hashes. Its `licenses` list
contains component names, exact text and contributing coordinates. Only identical
component-name/text pairs are deduplicated. Version 1.0.0+4 contains 35 such pairs,
covering all 131 indexed slices across these six artifacts:

- play-services-cast and play-services-cast-framework 23.0.0.
- play-services-base 18.11.0 and play-services-basement 18.12.0.
- play-services-tasks 18.4.1 and play-services-flags 18.1.0.

For a native dependency update, resolve the release runtime graph first. For each
Google AAR, hash the archive, read its JSON index and extract exactly `length`
bytes at `start` from `third_party_licenses.txt`. Decode the complete UTF-8 slice
without reflowing or trimming it. Merge only equal names with byte-identical text,
retain all contributing coordinates, and update the bundled asset. Compare every
upstream slice with the resulting asset, then inspect the actual candidate bundle.

Do not limit notice discovery to filenames starting with LICENSE or NOTICE:
that misses these Google files. Retain other upstream licenses and attribution;
the original Quietake MPL license does not replace third-party terms.
Google describes its notice mechanism in its
[open-source notice guide](https://developers.google.com/android/guides/opensource).

Host widget checks wait for the actual license entries while allowing real asset
decoding isolates to finish. Device checks cover Google, MPL, EFF and coroutines
access, with the root lock gate protecting the underlying vault.
