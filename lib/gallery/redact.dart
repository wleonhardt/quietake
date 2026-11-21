import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Covers [regions] (rectangles in 0..1 image coordinates) of a decoded image
/// with black
/// and returns a PNG built from raw pixels, so no metadata is carried over.
///
/// A photo with more than [maxPixels] pixels is scaled down while it is decoded,
/// because the raw copy takes four bytes a pixel and several copies are alive at once.
Future<Uint8List> redactToPng(
  Uint8List source,
  List<ui.Rect> regions, {
  int maxPixels = defaultMaxRedactPixels,
}) async {
  final image = await decodeBounded(source, maxPixels: maxPixels);
  final width = image.width, height = image.height;
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  if (data == null) throw const FormatException('Image could not be decoded');
  final pixels = data.buffer.asUint8List().sublist(0);
  for (final region in regions) {
    _cover(pixels, width, height, region);
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

/// Decodes [source], scaled down when it has more than [maxPixels] pixels.
Future<ui.Image> decodeBounded(
  Uint8List source, {
  int maxPixels = defaultMaxRedactPixels,
}) async {
  final scale = await _decodeScale(source, maxPixels);
  final codec = await ui.instantiateImageCodec(
    source,
    targetWidth: scale?.$1,
    targetHeight: scale?.$2,
  );
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
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

/// One opaque black block: nothing under it survives, not even a colour.
void _cover(Uint8List px, int width, int height, ui.Rect region) {
  final left = (region.left * width).floor().clamp(0, width);
  final right = (region.right * width).ceil().clamp(0, width);
  final top = (region.top * height).floor().clamp(0, height);
  final bottom = (region.bottom * height).ceil().clamp(0, height);
  // One opaque black word per pixel, a row at a time: a byte-by-byte loop
  // over a large area held up the UI for a noticeable moment.
  final words = px.buffer.asUint32List(px.offsetInBytes, px.lengthInBytes ~/ 4);
  final black = Endian.host == Endian.little ? 0xff000000 : 0x000000ff;
  for (var y = top; y < bottom; y++) {
    words.fillRange(y * width + left, y * width + right, black);
  }
}
