import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/gallery/exif_location.dart';

import '../test_support/exif_fixture.dart';
import '../test_support/fixtures.dart';

void main() {
  for (final order in [Endian.little, Endian.big]) {
    test(
      'erases inline and referenced GPS bytes while preserving image and orientation ($order)',
      () async {
        final original = jpegWithGps(orientation: 6, order: order);
        final saved = Uint8List.fromList(original);
        final stripped = withoutLocation(original);
        expect(gpsEntryCount(stripped), 0);
        expect(stripped.sublist(12 + 38, 12 + 92), everyElement(0));
        expect(stripped.sublist(0, 12 + 38), original.sublist(0, 12 + 38));
        expect(stripped.sublist(12 + 92), original.sublist(12 + 92));
        expect(ByteData.sublistView(stripped).getUint16(12 + 18, order), 6);
        expect(original, saved);
        final codec = await ui.instantiateImageCodec(stripped);
        final frame = await codec.getNextFrame();
        expect(frame.image.width, greaterThan(0));
        frame.image.dispose();
        codec.dispose();
      },
    );
  }

  test('redacts every EXIF segment even after a non-APP marker', () {
    final jpeg = jpegWithGps();
    final segment = jpeg.sublist(2, 12 + 92);
    final input = Uint8List.fromList([
      0xff,
      0xd8,
      0xff,
      0xdb,
      0,
      4,
      0,
      0,
      ...segment,
      ...segment,
      ...jpeg.sublist(12 + 92),
    ]);
    final stripped = withoutLocation(input);
    for (final start in [8, 8 + segment.length]) {
      expect(
        stripped.sublist(start + 10 + 38, start + 10 + 92),
        everyElement(0),
      );
    }
  });

  test('media without EXIF GPS is unchanged', () {
    for (final bytes in [
      fixtureBytes('tiny.jpg'),
      fixtureBytes('wide.png'),
      fixtureBytes('tiny.mp4'),
      Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]),
      Uint8List(0),
    ]) {
      expect(identical(withoutLocation(bytes), bytes), isTrue);
    }
  });

  test('GPS in an EXIF segment after image scan data is also erased', () {
    final plain = fixtureBytes('tiny.jpg');
    final segment = jpegWithGps().sublist(2, 12 + 92);
    final input = Uint8List.fromList([
      ...plain.take(plain.length - 2),
      ...segment,
      0xff,
      0xd9,
    ]);
    final stripped = withoutLocation(input);
    final start = plain.length - 2 + 10;
    expect(stripped.sublist(start + 38, start + 92), everyElement(0));
    expect(
      stripped.sublist(0, plain.length - 2),
      plain.sublist(0, plain.length - 2),
    );
  });

  test(
    'malformed or overlapping GPS metadata fails without changing input',
    () {
      final variants = <Uint8List>[
        Uint8List.sublistView(jpegWithGps(), 0, 30),
        for (final edit in <void Function(ByteData)>[
          (b) =>
              b.setUint32(12 + 60, 90, Endian.little), // Value crosses segment.
          (b) => b.setUint32(12 + 60, 8, Endian.little), // Value aliases IFD0.
          (b) => b.setUint16(
            12 + 38,
            65535,
            Endian.little,
          ), // Truncated directory.
          (b) => b.setUint16(12 + 54, 99, Endian.little), // Unknown GPS type.
          (b) => b.setUint32(12 + 34, 8, Endian.little), // Directory cycle.
        ])
          (() {
            final b = jpegWithGps();
            edit(ByteData.sublistView(b));
            return b;
          })(),
      ];
      for (final bytes in variants) {
        final saved = Uint8List.fromList(bytes);
        expect(() => withoutLocation(bytes), throwsFormatException);
        expect(bytes, saved);
      }
    },
  );
}
