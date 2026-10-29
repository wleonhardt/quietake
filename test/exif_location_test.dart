import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/gallery/exif_location.dart';

import '../test_support/exif_fixture.dart';
import '../test_support/fixtures.dart';

void main() {
  test('empties the GPS directory and keeps every other byte', () {
    final original = jpegWithGps(orientation: 6);
    expect(gpsEntryCount(original), 1);
    final stripped = withoutLocation(original);
    expect(stripped.length, original.length);
    expect(gpsEntryCount(stripped), 0);
    // Only the two count bytes differ; orientation and offsets survive.
    final changed = <int>[];
    for (var i = 0; i < original.length; i++) {
      if (original[i] != stripped[i]) changed.add(i);
    }
    const countAt = 2 + 4 + 6 + 38;
    expect(changed, isNotEmpty);
    expect(changed, everyElement(inInclusiveRange(countAt, countAt + 1)));
    expect(original, isNot(same(stripped)));
  });

  test('media without a GPS directory is returned untouched', () {
    for (final bytes in [
      fixtureBytes('tiny.jpg'),
      fixtureBytes('tiny.mp4'),
      Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]),
      Uint8List(0),
    ]) {
      expect(identical(withoutLocation(bytes), bytes), isTrue);
    }
  });

  test(
    'a truncated EXIF segment is left alone rather than indexed past the end',
    () {
      final broken = Uint8List.sublistView(jpegWithGps(), 0, 30);
      expect(identical(withoutLocation(broken), broken), isTrue);
    },
  );
}
