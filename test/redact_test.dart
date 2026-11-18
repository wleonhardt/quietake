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

  test('a region becomes one black block and the rest keeps its pixels', () async {
    final source = await gradientPng();
    final before = await _pixels(source);
    final out = await redactToPng(source, [
      const ui.Rect.fromLTRB(0.25, 0.25, 0.75, 0.75),
    ]);
    final after = await _pixels(out);
    // Outside the region nothing changed.
    expect(_at(after, 2, 2), _at(before, 2, 2));
    expect(_at(after, 62, 40), _at(before, 62, 40));
    // Inside, every pixel is opaque black: nothing of the source remains,
    // not even an average colour (decision 024, owner 2026-11-18).
    final colors = {
      for (var y = 16; y < 48; y++)
        for (var x = 16; x < 48; x++) _at(after, x, y).join(','),
    };
    expect(colors, {'0,0,0,255'});
  });

  test(
    'a photo over the pixel limit is scaled down before it is read',
    () async {
      final source = await gradientPng();
      final out = await redactToPng(source, const [
        ui.Rect.fromLTRB(0, 0, 0.5, 0.5),
      ], maxPixels: 1024);
      final codec = await ui.instantiateImageCodec(out);
      final image = (await codec.getNextFrame()).image;
      expect([image.width, image.height], [32, 32]);
      image.dispose();
      codec.dispose();
    },
  );

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

  test('a region smaller than one block becomes a single flat block', () async {
    final source = await gradientPng();
    final out = await redactToPng(source, [
      const ui.Rect.fromLTRB(0.5, 0.5, 0.6, 0.6),
    ]);
    final after = await _pixels(out);
    final before = await _pixels(source);
    // 0.5..0.6 of 64 px is pixels 32 to 38: one flat block.
    expect(_at(after, 32, 32), _at(after, 37, 37));
    expect(_at(after, 32, 32), isNot(_at(before, 32, 32)));
    expect(_at(after, 31, 31), _at(before, 31, 31));
  });

  test('a tiny image is fully hidden by a whole-image region', () async {
    final source = await gradientPng(size: 8);
    final out = await redactToPng(source, [const ui.Rect.fromLTRB(0, 0, 1, 1)]);
    final codec = await ui.instantiateImageCodec(out);
    final image = (await codec.getNextFrame()).image;
    final px = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
        .buffer
        .asUint8List();
    expect(px.sublist(0, 4), px.sublist(px.length - 4));
  });
}
