import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Pixelates [regions] (rectangles in 0..1 image coordinates) of a decoded image
/// and returns a PNG built from raw pixels, so no metadata is carried over.
///
/// A photo with more than [maxPixels] pixels is scaled down while it is decoded,
/// because the raw copy takes four bytes a pixel and several copies are alive at once.
Future<Uint8List> redactToPng(
  Uint8List source,
  List<ui.Rect> regions, {
  int maxPixels = defaultMaxRedactPixels,
}) async {
  final scale = await _decodeScale(source, maxPixels);
  final codec = await ui.instantiateImageCodec(
    source,
    targetWidth: scale?.$1,
    targetHeight: scale?.$2,
  );
  final ui.Image image;
  try {
    image = (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
  final width = image.width, height = image.height;
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  if (data == null) throw const FormatException('Image could not be decoded');
  final pixels = data.buffer.asUint8List().sublist(0);
  for (final region in regions) {
    _pixelate(pixels, width, height, region);
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: width,
    height: height,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final out = await descriptor.instantiateCodec();
  try {
    final result = (await out.getNextFrame()).image;
    final png = await result.toByteData(format: ui.ImageByteFormat.png);
    result.dispose();
    if (png == null) throw const FormatException('Image could not be encoded');
    return png.buffer.asUint8List();
  } finally {
    out.dispose();
    descriptor.dispose();
    buffer.dispose();
  }
}

/// 40 megapixels is 160 MB of raw pixels.
const defaultMaxRedactPixels = 40 * 1000 * 1000;

/// Target size when the header says the image is over [maxPixels], else null.
Future<(int, int)?> _decodeScale(Uint8List source, int maxPixels) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(source);
  try {
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      final width = descriptor.width, height = descriptor.height;
      if (width * height <= maxPixels) return null;
      final factor = sqrt(maxPixels / (width * height));
      return (
        max(1, (width * factor).floor()),
        max(1, (height * factor).floor()),
      );
    } finally {
      descriptor.dispose();
    }
  } finally {
    buffer.dispose();
  }
}

void _pixelate(Uint8List px, int width, int height, ui.Rect region) {
  final left = (region.left * width).floor().clamp(0, width);
  final right = (region.right * width).ceil().clamp(0, width);
  final top = (region.top * height).floor().clamp(0, height);
  final bottom = (region.bottom * height).ceil().clamp(0, height);
  final w = right - left, h = bottom - top;
  if (w <= 0 || h <= 0) return;
  final longer = w > h ? w : h;
  // At most 4 blocks across, at least 16 px, never larger than the region.
  final block = min(max(16, (longer / 4).ceil()), longer);
  for (var by = top; by < bottom; by += block) {
    for (var bx = left; bx < right; bx += block) {
      final ex = bx + block < right ? bx + block : right;
      final ey = by + block < bottom ? by + block : bottom;
      var r = 0, g = 0, b = 0, a = 0;
      for (var y = by; y < ey; y++) {
        for (var x = bx; x < ex; x++) {
          final i = (y * width + x) * 4;
          r += px[i];
          g += px[i + 1];
          b += px[i + 2];
          a += px[i + 3];
        }
      }
      final n = (ex - bx) * (ey - by);
      for (var y = by; y < ey; y++) {
        for (var x = bx; x < ex; x++) {
          final i = (y * width + x) * 4;
          px[i] = r ~/ n;
          px[i + 1] = g ~/ n;
          px[i + 2] = b ~/ n;
          px[i + 3] = a ~/ n;
        }
      }
    }
  }
}
