# 002 Viewer details

Status: accepted.

## Decision

The viewer app bar has a Details button (`Keys.viewerInfo`) that opens a small
dialog (`Keys.viewerInfoDialog`) with the capture's type, capture time, tag names
and encrypted size in bytes.

## Reasons and limits

- Every value comes from the vault file name, the private catalog or the size of
  the encrypted container. The dialog never decrypts the capture and reads no
  EXIF, so it adds no plaintext handling and no location data.
- The size is the encrypted container size, labelled as such. A plaintext size
  would need a decrypt or a stored field, which this change does not add.
- The capture time is parsed from the vault file name and shows Unknown when the
  name has no timestamp. It is local time without a zone label.
