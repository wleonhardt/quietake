import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../test_support/fixtures.dart';
import '../test_support/mp4.dart';

void main() {
  test('reads video sample description from the frozen synthetic fixture', () {
    expect(mp4SampleEntries(fixtureBytes('tiny.mp4')), ['avc1']);
  });

  test('payload codec strings are not sample descriptions', () {
    final payload = Uint8List.fromList([
      0,
      0,
      0,
      16,
      ...'mdatmp4aavc1'.codeUnits,
    ]);
    expect(mp4SampleEntries(payload), isEmpty);
  });

  test('rejects truncated MP4 boxes', () {
    expect(() => mp4SampleEntries(Uint8List(7)), throwsFormatException);
  });
}
