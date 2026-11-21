import 'dart:typed_data';
import 'dart:ui' as ui;

/// A [size] x [size] PNG whose red channel is the column and green the row.
Future<Uint8List> gradientPng({int size = 64}) async {
  final raw = Uint8List(size * size * 4);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final i = (y * size + x) * 4;
      raw[i] = x * 255 ~/ (size - 1);
      raw[i + 1] = y * 255 ~/ (size - 1);
      raw[i + 2] = 90;
      raw[i + 3] = 255;
    }
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(raw);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: size,
    height: size,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final codec = await descriptor.instantiateCodec();
  final image = (await codec.getNextFrame()).image;
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  return png!.buffer.asUint8List();
}
