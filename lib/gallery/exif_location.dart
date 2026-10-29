import 'dart:typed_data';

/// Erases JPEG EXIF GPS directories and their values without re-encoding pixels.
/// Other formats are unchanged. Unsafe EXIF layouts fail before a copy is shared.
Uint8List withoutLocation(Uint8List jpeg) {
  if (jpeg.length < 4 || jpeg[0] != 0xff || jpeg[1] != 0xd8) return jpeg;
  final erase = <(int, int)>[];
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
    if (marker == 0xe1 && end - start >= 6 && _isExif(jpeg, start)) {
      erase.addAll(_gpsRanges(jpeg, start + 6, end));
    }
    if (marker == 0xda) scanning = true;
    position = end;
  }
  if (erase.isEmpty) return jpeg;
  final out = Uint8List.fromList(jpeg);
  for (final (start, end) in erase) {
    out.fillRange(start, end, 0);
  }
  return out;
}

bool _isExif(Uint8List b, int at) =>
    b[at] == 0x45 &&
    b[at + 1] == 0x78 &&
    b[at + 2] == 0x69 &&
    b[at + 3] == 0x66 &&
    b[at + 4] == 0 &&
    b[at + 5] == 0;

List<(int, int)> _gpsRanges(Uint8List bytes, int tiff, int end) {
  final data = ByteData.sublistView(bytes, tiff, end);
  void bound(int start, int size) {
    if (start < 0 || size < 0 || start + size > data.lengthInBytes) {
      throw const FormatException('EXIF field extends beyond its segment');
    }
  }

  bound(0, 8);
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
  final ranges = <({int start, int end, bool erase})>[];
  void range(int start, int size, bool erase) {
    bound(start, size);
    if (size > 0) ranges.add((start: start, end: start + size, erase: erase));
  }

  range(0, 8, false);
  final pending = <(int, bool)>[];
  final visited = <int>{};
  void enqueue(int offset, bool gps) {
    if (offset == 0) return;
    bound(offset, 2);
    if (!visited.add(offset)) {
      throw const FormatException('Repeated EXIF directory');
    }
    pending.add((offset, gps));
  }

  enqueue(data.getUint32(4, order), false);
  const sizes = [0, 1, 1, 2, 4, 8, 1, 1, 2, 4, 8, 4, 8, 4];
  while (pending.isNotEmpty) {
    final (offset, gps) = pending.removeLast();
    final count = data.getUint16(offset, order);
    range(offset, 2 + count * 12 + 4, gps);
    int? thumbnailOffset;
    int? thumbnailLength;
    for (var i = 0; i < count; i++) {
      final entry = offset + 2 + i * 12;
      final tag = data.getUint16(entry, order);
      final type = data.getUint16(entry + 2, order);
      final number = data.getUint32(entry + 4, order);
      if (type == 0 || type >= sizes.length) {
        throw const FormatException('Unsupported EXIF field type');
      }
      final size = sizes[type] * number;
      final value = size <= 4 ? entry + 8 : data.getUint32(entry + 8, order);
      bound(value, size);
      if (size > 4) range(value, size, gps);
      if (!gps && {0x8825, 0x8769, 0xa005, 0x014a}.contains(tag)) {
        if ((type != 4 && type != 13) ||
            number == 0 ||
            (tag != 0x014a && number != 1)) {
          throw const FormatException('Invalid EXIF directory pointer');
        }
        for (var j = 0; j < number; j++) {
          enqueue(data.getUint32(value + j * 4, order), tag == 0x8825);
        }
      }
      if (!gps && (tag == 0x0201 || tag == 0x0202)) {
        if (type != 4 || number != 1) {
          throw const FormatException('Invalid EXIF thumbnail');
        }
        if (tag == 0x0201) thumbnailOffset = data.getUint32(value, order);
        if (tag == 0x0202) thumbnailLength = data.getUint32(value, order);
      }
    }
    if (thumbnailOffset != null || thumbnailLength != null) {
      if (thumbnailOffset == null || thumbnailLength == null) {
        throw const FormatException('Incomplete EXIF thumbnail');
      }
      range(thumbnailOffset, thumbnailLength, false);
    }
    enqueue(data.getUint32(offset + 2 + count * 12, order), gps);
  }
  // GPS data must not alias orientation, pixels or another retained EXIF value.
  ranges.sort((a, b) => a.start.compareTo(b.start));
  var erasedEnd = 0;
  var retainedEnd = 0;
  final result = <(int, int)>[];
  for (final r in ranges) {
    if (r.erase) {
      if (r.start < retainedEnd) {
        throw const FormatException('GPS overlaps retained EXIF data');
      }
      if (r.end > erasedEnd) erasedEnd = r.end;
      result.add((tiff + r.start, tiff + r.end));
    } else {
      if (r.start < erasedEnd) {
        throw const FormatException('GPS overlaps retained EXIF data');
      }
      if (r.end > retainedEnd) retainedEnd = r.end;
    }
  }
  return result;
}
