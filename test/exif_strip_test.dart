import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/gallery/exif_strip.dart';

import '../test_support/exif_fixture.dart';
import '../test_support/fixtures.dart';

Uint8List segment(int marker, List<int> payload) {
  final length = payload.length + 2;
  return Uint8List.fromList([
    0xff,
    marker,
    length >> 8,
    length & 0xff,
    ...payload,
  ]);
}

/// Orientation from the first EXIF segment of [jpeg], or null without one.
int? orientationOf(Uint8List jpeg) {
  for (var i = 2; i + 4 < jpeg.length;) {
    if (jpeg[i] != 0xff) return null;
    final marker = jpeg[i + 1];
    if (marker == 0xda) return null;
    final length = (jpeg[i + 2] << 8) | jpeg[i + 3];
    if (marker == 0xe1 &&
        String.fromCharCodes(jpeg.sublist(i + 4, i + 8)) == 'Exif') {
      final tiff = ByteData.sublistView(jpeg, i + 10, i + 2 + length);
      final order = tiff.getUint16(0) == 0x4949 ? Endian.little : Endian.big;
      final ifd = tiff.getUint32(4, order);
      final count = tiff.getUint16(ifd, order);
      for (var e = 0; e < count; e++) {
        final at = ifd + 2 + e * 12;
        if (tiff.getUint16(at, order) == 0x0112) {
          return tiff.getUint16(at + 8, order);
        }
      }
      return null;
    }
    i += 2 + length;
  }
  return null;
}

bool contains(Uint8List bytes, String text) {
  final needle = text.codeUnits;
  for (var i = 0; i + needle.length <= bytes.length; i++) {
    var hit = true;
    for (var j = 0; j < needle.length && hit; j++) {
      hit = bytes[i + j] == needle[j];
    }
    if (hit) return true;
  }
  return false;
}

Future<void> expectDecodes(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  expect(frame.image.width, greaterThan(0));
  frame.image.dispose();
  codec.dispose();
}

/// tiny.jpg without its encoder comment, so it carries no removable metadata.
Uint8List cleanJpeg() {
  final bytes = fixtureBytes('tiny.jpg');
  expect(bytes[20], 0xff);
  expect(bytes[21], 0xfe);
  final length = (bytes[22] << 8) | bytes[23];
  return Uint8List.fromList([...bytes.take(20), ...bytes.skip(22 + length)]);
}

void main() {
  for (final order in [Endian.little, Endian.big]) {
    test('keeps only orientation and the pixels ($order)', () async {
      final original = jpegWithGps(orientation: 6, order: order);
      final saved = Uint8List.fromList(original);
      final stripped = withoutMetadata(original);
      expect(orientationOf(stripped), 6);
      // The GPS directory and coordinates are gone, not just zeroed.
      expect(stripped.length, lessThan(original.length - 40));
      expect(original, saved);
      final pixels = cleanJpeg().skip(2).toList();
      expect(stripped.sublist(stripped.length - pixels.length), pixels);
      await expectDecodes(stripped);
    });
  }

  test(
    'XMP, comments, Photoshop data and MPF are removed, ICC is kept',
    () async {
      final plain = fixtureBytes('tiny.jpg');
      final icc = segment(0xe2, [...'ICC_PROFILE'.codeUnits, 0, 1, 1, 9, 9]);
      final input = Uint8List.fromList([
        0xff,
        0xd8,
        ...segment(0xe1, [
          ...'http://ns.adobe.com/xap/1.0/'.codeUnits,
          0,
          ...'lat=37.8'.codeUnits,
        ]),
        ...segment(0xfe, 'taken at home'.codeUnits),
        ...segment(0xed, [
          ...'Photoshop 3.0'.codeUnits,
          0,
          ...'caption'.codeUnits,
        ]),
        ...segment(0xe2, [0x4d, 0x50, 0x46, 0, 1, 2]),
        ...icc,
        ...plain.skip(2),
      ]);
      final stripped = withoutMetadata(input);
      for (final secret in ['lat=37.8', 'taken at home', 'caption', 'xap']) {
        expect(contains(stripped, secret), isFalse, reason: secret);
      }
      expect(contains(stripped, 'ICC_PROFILE'), isTrue);
      expect(contains(stripped, 'MPF'), isFalse);
      await expectDecodes(stripped);
    },
  );

  test('a photo without orientation loses its EXIF segment entirely', () {
    final original = jpegWithGps();
    // Rename the orientation tag so IFD0 has none.
    ByteData.sublistView(original).setUint16(12 + 10, 0x0111, Endian.little);
    final stripped = withoutMetadata(original);
    expect(orientationOf(stripped), isNull);
    expect(contains(stripped, 'Exif'), isFalse);
    expect(stripped, cleanJpeg());
  });

  test('bytes after the end of image marker are removed', () async {
    final trailing = Uint8List.fromList([
      ...cleanJpeg(),
      ...jpegWithGps(),
      ...'MOTIONPHOTO lat=1.5'.codeUnits,
    ]);
    final stripped = withoutMetadata(trailing);
    expect(stripped, cleanJpeg());
    await expectDecodes(stripped);
  });

  test('an invalid orientation value is dropped', () {
    final original = jpegWithGps(orientation: 9);
    expect(contains(withoutMetadata(original), 'Exif'), isFalse);
  });

  test('media with nothing to remove is returned unchanged', () {
    for (final bytes in [
      cleanJpeg(),
      fixtureBytes('wide.png'),
      fixtureBytes('tiny.mp4'),
      Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]),
      Uint8List(0),
    ]) {
      expect(identical(withoutMetadata(bytes), bytes), isTrue);
    }
  });

  test('EXIF after image scan data is also removed', () {
    final plain = cleanJpeg();
    final exif = jpegWithGps(orientation: 3).sublist(2, 12 + 92);
    final input = Uint8List.fromList([
      ...plain.take(plain.length - 2),
      ...exif,
      0xff,
      0xd9,
    ]);
    final stripped = withoutMetadata(input);
    expect(contains(stripped, '\u0000\u0001\u0000\u0002'), isFalse);
    expect(stripped.length, lessThan(input.length - 40));
    expect(
      stripped.sublist(0, plain.length - 2),
      plain.sublist(0, plain.length - 2),
    );
  });

  test('damaged metadata fails without changing the input', () {
    final variants = <Uint8List>[
      Uint8List.sublistView(jpegWithGps(), 0, 30),
      for (final edit in <void Function(ByteData)>[
        (b) => b.setUint16(12, 0x1234), // Unknown byte order.
        (b) => b.setUint16(12 + 2, 41, Endian.little), // Bad TIFF magic.
        (b) =>
            b.setUint32(12 + 4, 5000, Endian.little), // IFD0 outside segment.
        (b) =>
            b.setUint16(12 + 8, 65535, Endian.little), // Entry count too big.
      ])
        (() {
          final b = jpegWithGps();
          edit(ByteData.sublistView(b));
          return b;
        })(),
    ];
    for (final bytes in variants) {
      final saved = Uint8List.fromList(bytes);
      expect(() => withoutMetadata(bytes), throwsFormatException);
      expect(bytes, saved);
    }
  });

  test('random damage only ever throws a FormatException', () {
    final random = Random(20261117);
    final base = jpegWithGps();
    for (var run = 0; run < 3000; run++) {
      final bytes = Uint8List.fromList(base);
      for (var i = random.nextInt(4); i >= 0; i--) {
        bytes[random.nextInt(bytes.length)] = random.nextInt(256);
      }
      final cut = random.nextInt(4) == 0
          ? Uint8List.sublistView(bytes, 0, random.nextInt(bytes.length))
          : bytes;
      try {
        final out = withoutMetadata(cut);
        expect(out.length, lessThanOrEqualTo(cut.length + 40));
      } on FormatException {
        // Damaged layouts are refused before a copy is shared.
      }
    }
  });
}
