import 'dart:typed_data';

/// A minimal JPEG: SOI, one EXIF APP1 (little-endian TIFF) whose IFD0 holds
/// Orientation = [orientation] and a GPS IFD with one entry, then EOI.
Uint8List jpegWithGps({int orientation = 6}) {
  final tiff = BytesBuilder();
  void u16(int v) => tiff.add([v & 0xff, v >> 8]);
  void u32(int v) =>
      tiff.add([v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff, v >> 24]);
  tiff.add([0x49, 0x49]); // II
  u16(42);
  u32(8); // IFD0 at offset 8
  u16(2); // two entries
  // Orientation SHORT x1
  u16(0x0112);
  u16(3);
  u32(1);
  u16(orientation);
  u16(0);
  // GPSInfo LONG x1 -> offset 38 (8 + 2 + 24 + 4)
  u16(0x8825);
  u16(4);
  u32(1);
  u32(38);
  u32(0); // next IFD
  // GPS IFD at 38: one entry, GPSLatitudeRef ASCII "N\0"
  u16(1);
  u16(0x0001);
  u16(2);
  u32(2);
  tiff.add([0x4e, 0, 0, 0]);
  u32(0);
  final payload = [0x45, 0x78, 0x69, 0x66, 0, 0, ...tiff.toBytes()];
  final length = payload.length + 2;
  return Uint8List.fromList([
    0xff,
    0xd8,
    0xff,
    0xe1,
    length >> 8,
    length & 0xff,
    ...payload,
    0xff,
    0xd9,
  ]);
}

/// Entry count of the GPS IFD in a fixture produced by [jpegWithGps].
int gpsEntryCount(Uint8List jpeg) {
  final tiff = 2 + 4 + 6;
  return jpeg[tiff + 38] | (jpeg[tiff + 39] << 8);
}
