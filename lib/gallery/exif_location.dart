import 'dart:typed_data';

/// Returns [jpeg] with the EXIF GPS directory emptied in place: the GPS IFD's
/// entry count becomes zero while every offset, including orientation and the
/// rest of the metadata, stays valid. Anything that is not a JPEG with an EXIF
/// GPS directory comes back untouched (the same list).
Uint8List withoutLocation(Uint8List jpeg) {
  if (jpeg.length < 4 || jpeg[0] != 0xff || jpeg[1] != 0xd8) return jpeg;
  var position = 2;
  while (position + 4 <= jpeg.length && jpeg[position] == 0xff) {
    final marker = jpeg[position + 1];
    // Only APPn and COM segments precede the frame; EXIF is APP1.
    if (marker < 0xe0 || marker > 0xef && marker != 0xfe) break;
    final length = (jpeg[position + 2] << 8) | jpeg[position + 3];
    final start = position + 4;
    final end = position + 2 + length;
    if (length < 2 || end > jpeg.length) break;
    if (marker == 0xe1 && end - start > 14 && _isExif(jpeg, start)) {
      final gps = _gpsDirectory(jpeg, start + 6, end);
      if (gps == null) return jpeg;
      final out = Uint8List.fromList(jpeg);
      out[gps] = 0;
      out[gps + 1] = 0;
      return out;
    }
    position = end;
  }
  return jpeg;
}

bool _isExif(Uint8List b, int at) =>
    b[at] == 0x45 &&
    b[at + 1] == 0x78 &&
    b[at + 2] == 0x69 &&
    b[at + 3] == 0x66 &&
    b[at + 4] == 0 &&
    b[at + 5] == 0;

/// Absolute offset of the GPS IFD entry count, or null without a GPS tag.
int? _gpsDirectory(Uint8List b, int tiff, int end) {
  if (tiff + 8 > end) return null;
  final Endian order;
  if (b[tiff] == 0x49 && b[tiff + 1] == 0x49) {
    order = Endian.little;
  } else if (b[tiff] == 0x4d && b[tiff + 1] == 0x4d) {
    order = Endian.big;
  } else {
    return null;
  }
  final data = ByteData.sublistView(b, tiff, end);
  if (data.getUint16(2, order) != 42) return null;
  final ifd0 = data.getUint32(4, order);
  if (ifd0 + 2 > data.lengthInBytes) return null;
  final count = data.getUint16(ifd0, order);
  for (var i = 0; i < count; i++) {
    final entry = ifd0 + 2 + i * 12;
    if (entry + 12 > data.lengthInBytes) return null;
    if (data.getUint16(entry, order) != 0x8825) continue;
    final gps = data.getUint32(entry + 8, order);
    if (gps + 2 > data.lengthInBytes) return null;
    return tiff + gps;
  }
  return null;
}
