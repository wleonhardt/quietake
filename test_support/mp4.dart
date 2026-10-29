import 'dart:typed_data';

/// Reads actual MP4 sample descriptions, rather than matching payload strings.
List<String> mp4SampleEntries(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  final entries = <String>[];
  void boxes(int start, int end, {bool samples = false}) {
    for (var offset = start; offset < end;) {
      if (offset + 8 > end) throw const FormatException('Truncated MP4 box');
      var size = data.getUint32(offset);
      final type = String.fromCharCodes(bytes.sublist(offset + 4, offset + 8));
      var header = 8;
      if (size == 1) {
        if (offset + 16 > end) {
          throw const FormatException('Truncated large box');
        }
        size = data.getUint64(offset + 8);
        header = 16;
      } else if (size == 0) {
        size = end - offset;
      }
      if (size < header || offset + size > end) {
        throw const FormatException('Invalid MP4 box size');
      }
      if (samples) {
        entries.add(type);
      } else if (const [
        'moov',
        'trak',
        'mdia',
        'minf',
        'stbl',
      ].contains(type)) {
        boxes(offset + header, offset + size);
      } else if (type == 'stsd') {
        if (size < header + 8) throw const FormatException('Invalid stsd');
        boxes(offset + header + 8, offset + size, samples: true);
      }
      offset += size;
    }
  }

  boxes(0, bytes.length);
  return entries;
}
