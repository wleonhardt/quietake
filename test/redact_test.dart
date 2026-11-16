import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/gallery/redact.dart';

import '../test_support/png_fixture.dart';

const _size = 64;

Future<Uint8List> _pixels(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  final image = (await codec.getNextFrame()).image;
  expect([image.width, image.height], [_size, _size]);
  return (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer
      .asUint8List();
}

List<int> _at(Uint8List px, int x, int y) {
  final i = (y * _size + x) * 4;
  return px.sublist(i, i + 4);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a region is pixelated and the rest keeps its pixels', () async {
    final source = await gradientPng();
    final before = await _pixels(source);
    final out = await redactToPng(source, [
      const ui.Rect.fromLTRB(0.25, 0.25, 0.75, 0.75),
    ]);
    final after = await _pixels(out);
    // Outside the region nothing changed.
    expect(_at(after, 2, 2), _at(before, 2, 2));
    expect(_at(after, 62, 40), _at(before, 62, 40));
    // Inside, neighbouring pixels of one block are identical and differ from the source.
    expect(_at(after, 20, 20), _at(after, 21, 21));
    expect(_at(after, 20, 20), isNot(_at(before, 20, 20)));
    // Detail is gone: the region holds at most 4 x 4 distinct blocks.
    final colors = {
      for (var y = 16; y < 48; y++)
        for (var x = 16; x < 48; x++) _at(after, x, y).join(','),
    };
    expect(colors.length, lessThanOrEqualTo(16));
  });

  test('no regions re-encodes the same pixels', () async {
    final source = await gradientPng();
    final out = await redactToPng(source, const []);
    expect(await _pixels(out), await _pixels(source));
  });

  test('regions outside or empty or beyond the image change nothing', () async {
    final source = await gradientPng();
    final out = await redactToPng(source, [
      const ui.Rect.fromLTRB(2, 2, 3, 3),
      const ui.Rect.fromLTRB(0.5, 0.5, 0.5, 0.9),
      const ui.Rect.fromLTRB(-1, -1, -0.5, -0.2),
    ]);
    expect(await _pixels(out), await _pixels(source));
  });

  test('a region past the edge is clamped to the image', () async {
    final source = await gradientPng();
    final before = await _pixels(source);
    final out = await redactToPng(source, [
      const ui.Rect.fromLTRB(0.5, 0.5, 2, 2),
    ]);
    final after = await _pixels(out);
    expect(_at(after, 63, 63), isNot(_at(before, 63, 63)));
    expect(_at(after, 10, 10), _at(before, 10, 10));
  });

  test('the output is a PNG with no metadata chunks', () async {
    final out = await redactToPng(await gradientPng(), const [
      ui.Rect.fromLTRB(0, 0, 0.5, 0.5),
    ]);
    expect(out.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
    final text = String.fromCharCodes(out);
    for (final chunk in ['eXIf', 'tEXt', 'iTXt', 'zTXt']) {
      expect(text.contains(chunk), isFalse, reason: chunk);
    }
  });

  test('bytes that are not an image are rejected', () async {
    expect(
      redactToPng(Uint8List.fromList([1, 2, 3]), const []),
      throwsA(anything),
    );
  });
}
