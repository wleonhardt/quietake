import 'dart:typed_data';

/// Removes personal metadata from a JPEG without re-encoding its pixels: every
/// EXIF field except orientation, XMP, Photoshop/IPTC, comments and the
/// multi-picture directory. Orientation is rewritten into a minimal EXIF segment
/// so the photo keeps its rotation. Other formats, and JPEGs with nothing to
/// remove, are returned unchanged. A damaged layout throws before a copy is shared.
Uint8List withoutMetadata(Uint8List jpeg) {
  if (jpeg.length < 4 || jpeg[0] != 0xff || jpeg[1] != 0xd8) return jpeg;
  // Each entry is a marker start, its end and the bytes that replace it.
  final edits = <(int, int, List<int>)>[];
  int? orientation;
  var position = 2;
  var scanning = false;
  while (position < jpeg.length) {
    if (scanning) position = jpeg.indexOf(0xff, position);
    if (position < 0 || jpeg[position] != 0xff) {
      throw const FormatException('Invalid JPEG marker');
    }
    while (position < jpeg.length && jpeg[position] == 0xff) {
      position++;
    }
    if (position == jpeg.length) throw const FormatException('Truncated JPEG');
    final marker = jpeg[position++];
    final markerStart = position - 2;
    if (marker == 0xd9) break;
    if (marker == 0 && scanning ||
        marker >= 0xd0 && marker <= 0xd7 ||
        marker == 1) {
      continue;
    }
    if (position + 2 > jpeg.length) {
      throw const FormatException('Truncated JPEG');
    }
    final length = (jpeg[position] << 8) | jpeg[position + 1];
    final start = position + 2;
    final end = position + length;
    if (length < 2 || end > jpeg.length) {
      throw const FormatException('Truncated JPEG segment');
    }
    if (_isRemoved(jpeg, marker, start, end)) {
      var replacement = const <int>[];
      if (marker == 0xe1 && _isExif(jpeg, start, end)) {
        // Only the first EXIF segment can carry orientation.
        final found = orientation == null
            ? _orientation(jpeg, start + 6, end)
            : null;
        if (found != null) {
          orientation = found;
          replacement = _orientationSegment(found);
        }
      }
      edits.add((markerStart, end, replacement));
    }
    if (marker == 0xda) scanning = true;
    position = end;
  }
  if (edits.isEmpty) return jpeg;
  final out = BytesBuilder(copy: false);
  var from = 0;
  for (final (start, end, replacement) in edits) {
    out.add(Uint8List.sublistView(jpeg, from, start));
    out.add(replacement);
    from = end;
  }
  out.add(Uint8List.sublistView(jpeg, from));
  return out.takeBytes();
}

bool _hasPrefix(Uint8List b, int at, int end, List<int> prefix) {
  if (end - at < prefix.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (b[at + i] != prefix[i]) return false;
  }
  return true;
}

const _exif = [0x45, 0x78, 0x69, 0x66, 0, 0];
final _xmp = 'http://ns.adobe.com/xap/1.0/'.codeUnits;
const _mpf = [0x4d, 0x50, 0x46, 0];

bool _isExif(Uint8List b, int at, int end) => _hasPrefix(b, at, end, _exif);

bool _isRemoved(Uint8List b, int marker, int start, int end) =>
    marker == 0xfe ||
    marker == 0xed ||
    marker == 0xe1 &&
        (_isExif(b, start, end) || _hasPrefix(b, start, end, _xmp)) ||
    marker == 0xe2 && _hasPrefix(b, start, end, _mpf);

/// A minimal big-endian EXIF segment holding only the orientation.
List<int> _orientationSegment(int orientation) => [
  0xff, 0xe1, 0x00, 0x22, //
  ..._exif,
  0x4d, 0x4d, 0x00, 0x2a, 0, 0, 0, 8, // TIFF header, IFD0 at 8.
  0x00, 0x01, // One entry.
  0x01, 0x12, 0x00, 0x03, 0, 0, 0, 1, 0, orientation, 0, 0,
  0, 0, 0, 0, // No next directory.
];

/// Orientation 1-8 from IFD0 of the TIFF block in [at, end), or null if absent.
int? _orientation(Uint8List bytes, int at, int end) {
  if (end - at < 8) throw const FormatException('Truncated EXIF');
  final data = ByteData.sublistView(bytes, at, end);
  final Endian order;
  if (data.getUint16(0) == 0x4949) {
    order = Endian.little;
  } else if (data.getUint16(0) == 0x4d4d) {
    order = Endian.big;
  } else {
    throw const FormatException('Invalid EXIF byte order');
  }
  if (data.getUint16(2, order) != 42) {
    throw const FormatException('Invalid EXIF header');
  }
  final ifd = data.getUint32(4, order);
  if (ifd == 0) return null;
  if (ifd + 2 > data.lengthInBytes) {
    throw const FormatException('EXIF directory outside its segment');
  }
  final count = data.getUint16(ifd, order);
  if (ifd + 2 + count * 12 > data.lengthInBytes) {
    throw const FormatException('EXIF directory outside its segment');
  }
  for (var i = 0; i < count; i++) {
    final entry = ifd + 2 + i * 12;
    if (data.getUint16(entry, order) != 0x0112) continue;
    if (data.getUint16(entry + 2, order) != 3 ||
        data.getUint32(entry + 4, order) != 1) {
      return null;
    }
    final value = data.getUint16(entry + 8, order);
    return value >= 1 && value <= 8 ? value : null;
  }
  return null;
}
