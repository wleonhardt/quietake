import 'package:sodium/sodium.dart';

/// 128 random bits as lowercase hex: unguessable media tokens and copy names.
String randomHexToken(Sodium sodium) => sodium.randombytes
    .buf(16)
    .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
    .join();
