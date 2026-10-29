import 'dart:io';
import 'dart:typed_data';

import 'long_video_bytes.dart';

/// Spreads unused mdat bytes between real chunks, so late seeks must decrypt a
/// large prefix without storing a large fixture or allocating it all in memory.
Future<void> writeLongVideo(File target, {int megabytes = 64}) async {
  final bytes = longVideoBytes();
  final data = ByteData.sublistView(bytes);
  final entries = <int>[];
  var mdat = -1;
  void boxes(int start, int end) {
    for (var at = start; at < end;) {
      final size = data.getUint32(at);
      final type = String.fromCharCodes(bytes.sublist(at + 4, at + 8));
      if (size < 8 || at + size > end) {
        throw const FormatException('Invalid fixture box');
      }
      if (type == 'mdat') mdat = at;
      if (type == 'stco') {
        final count = data.getUint32(at + 12);
        for (var i = 0; i < count; i++) {
          entries.add(at + 16 + i * 4);
        }
      } else if (const [
        'moov',
        'trak',
        'mdia',
        'minf',
        'stbl',
      ].contains(type)) {
        boxes(at + 8, at + size);
      }
      at += size;
    }
  }

  boxes(0, bytes.length);
  final offsets = entries.map(data.getUint32).toSet().toList()..sort();
  if (mdat < 0 || offsets.isEmpty || offsets.first <= mdat) {
    throw const FormatException('Fixture needs faststart and chunk offsets');
  }
  final padding = ((megabytes * 1024 * 1024 - bytes.length) ~/ offsets.length)
      .clamp(0, 1024 * 1024);
  final shifts = {
    for (var i = 0; i < offsets.length; i++) offsets[i]: (i + 1) * padding,
  };
  for (final entry in entries) {
    final offset = data.getUint32(entry);
    data.setUint32(entry, offset + shifts[offset]!);
  }
  data.setUint32(mdat, data.getUint32(mdat) + offsets.length * padding);
  final sink = target.openWrite();
  final zeros = Uint8List(padding);
  var previous = 0;
  try {
    for (final offset in offsets) {
      sink.add(Uint8List.sublistView(bytes, previous, offset));
      sink.add(zeros);
      previous = offset;
      // Drain regularly: IOSink.add otherwise retains the entire padded file.
      await sink.flush();
    }
    sink.add(Uint8List.sublistView(bytes, previous));
    await sink.flush();
  } finally {
    await sink.close();
  }
}
