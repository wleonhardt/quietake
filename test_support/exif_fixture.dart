import 'dart:typed_data';

import 'fixtures.dart';

/// A real JPEG with orientation and synthetic GPS reference/coordinate fields.
Uint8List jpegWithGps({int orientation = 6, Endian order = Endian.little}) {
  final tiff = ByteData(92);
  void u16(int at, int value) => tiff.setUint16(at, value, order);
  void u32(int at, int value) => tiff.setUint32(at, value, order);
  u16(0, order == Endian.little ? 0x4949 : 0x4d4d);
  u16(2, 42);
  u32(4, 8);
  u16(8, 2);
  u16(10, 0x0112); // Orientation SHORT x1.
  u16(12, 3);
  u32(14, 1);
  u16(18, orientation);
  u16(22, 0x8825); // GPSInfo LONG x1 -> GPS directory at 38.
  u16(24, 4);
  u32(26, 1);
  u32(30, 38);
  u16(38, 2);
  u16(40, 1); // GPSLatitudeRef ASCII x2, inline.
  u16(42, 2);
  u32(44, 2);
  tiff.setUint8(48, 0x4e);
  u16(52, 2); // GPSLatitude RATIONAL x3, stored at 68.
  u16(54, 5);
  u32(56, 3);
  u32(60, 68);
  final coordinates = [37, 1, 47, 1, 1234567, 100000];
  for (var i = 0; i < coordinates.length; i++) {
    u32(68 + i * 4, coordinates[i]);
  }
  final payload = [0x45, 0x78, 0x69, 0x66, 0, 0, ...tiff.buffer.asUint8List()];
  final length = payload.length + 2;
  return Uint8List.fromList([
    0xff,
    0xd8,
    0xff,
    0xe1,
    length >> 8,
    length & 0xff,
    ...payload,
    ...fixtureBytes('tiny.jpg').skip(2),
  ]);
}

int gpsEntryCount(Uint8List jpeg) =>
    ByteData.sublistView(jpeg)
        .getUint16(12 + 38, jpeg[12] == 0x49 ? Endian.little : Endian.big);
