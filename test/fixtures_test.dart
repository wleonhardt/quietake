import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../test_support/fixtures.dart';

void main() {
  for (final name in [
    'tiny.jpg',
    'tiny.mp4',
    'wide.png',
    'tall.png',
    'oversized.png',
  ]) {
    test('test-only $name keeps the original synthetic media bytes', () {
      expect(fixtureBytes(name), File('test_fixtures/$name').readAsBytesSync());
    });
  }
}
