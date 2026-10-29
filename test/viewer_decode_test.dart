import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/gallery/viewer_screen.dart';

void main() {
  test('photos decode to the screen until the user zooms past 2x', () {
    const view = Size(400, 800);
    expect(viewerDecodeSide(view, 3, zoom: 1), 2400);
    expect(viewerDecodeSide(view, 3, zoom: 1.9), 2400);
    expect(viewerDecodeSide(view, 3, zoom: 2.5), 4096);
    expect(viewerDecodeSide(const Size(10000, 10), 1, zoom: 1), 4096);
  });
}
