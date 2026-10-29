import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:sodium/sodium_sumo.dart';

/// Encrypts and decrypts vault files in the `.shtr` container format.
///
/// Layout (all integers big-endian), see docs/container-format.md:
///
/// ```
/// offset size  field
/// 0      4     magic "SHTR"
/// 4      1     version (1)
/// 5      1     reserved (0)
/// 6      4     chunkSize
/// 10     24    secretbox nonce for the wrapped file key
/// 34     48    file key wrapped with the master key (32 key + 16 MAC)
/// 82     24    secretstream header
/// 106    ...   ciphertext chunks, each min(chunkSize, remaining) + 17 bytes
/// ```
///
/// The last chunk is always tagged FINAL and is shorter than a full chunk
/// (possibly empty). A file whose length is an exact multiple of chunkSize
/// therefore ends with a 17-byte empty FINAL chunk.
class VaultCrypto {
  VaultCrypto(this.sodium);

  final SodiumSumo sodium;

  static const magic = [0x53, 0x48, 0x54, 0x52]; // SHTR
  static const version = 1;
  static const defaultChunkSize = 256 * 1024;
  static const maxChunkSize = 1024 * 1024;
  static const _fixedHeaderBytes = 10;

  int get _nonceBytes => sodium.crypto.secretBox.nonceBytes;
  int get _wrappedKeyBytes =>
      sodium.crypto.secretStream.keyBytes + sodium.crypto.secretBox.macBytes;
  int get _streamHeaderBytes => sodium.crypto.secretStream.headerBytes;
  int get _aBytes => sodium.crypto.secretStream.aBytes;

  /// Total header length before the first ciphertext chunk.
  int get headerLength =>
      _fixedHeaderBytes + _nonceBytes + _wrappedKeyBytes + _streamHeaderBytes;

  SecureKey generateMasterKey() => sodium.crypto.secretBox.keygen();

  /// Plaintext length of a container, from its header and file size alone.
  Future<int> plaintextLength(File container) async {
    final raf = await container.open();
    try {
      final head = await raf.read(_fixedHeaderBytes);
      if (head.length < _fixedHeaderBytes ||
          !_listEquals(head.sublist(0, 4), magic) ||
          head[4] != version) {
        throw const FormatException('not a valid v1 .shtr container');
      }
      final chunkSize = ByteData.sublistView(head, 6, 10).getUint32(0);
      if (chunkSize == 0 || chunkSize > maxChunkSize) {
        throw const FormatException('unsupported chunk size');
      }
      final body = await raf.length() - headerLength;
      final full = body ~/ (chunkSize + _aBytes);
      final rem = body - full * (chunkSize + _aBytes);
      if (rem < _aBytes) throw const FormatException('truncated container');
      return full * chunkSize + rem - _aBytes;
    } finally {
      await raf.close();
    }
  }

  /// Encrypts [plain] as a stream of bytes into the container format.
  Stream<List<int>> encrypt(
    Stream<List<int>> plain,
    SecureKey masterKey, {
    int chunkSize = defaultChunkSize,
  }) async* {
    if (chunkSize <= 0 || chunkSize > maxChunkSize) {
      throw ArgumentError.value(
        chunkSize,
        'chunkSize',
        'unsupported chunk size',
      );
    }
    final fileKey = sodium.crypto.secretStream.keygen();
    try {
      final nonce = sodium.randombytes.buf(_nonceBytes);
      final wrapped = sodium.crypto.secretBox.easy(
        message: fileKey.extractBytes(),
        nonce: nonce,
        key: masterKey,
      );
      final header = BytesBuilder(copy: false)
        ..add(magic)
        ..addByte(version)
        ..addByte(0)
        ..add(_u32(chunkSize))
        ..add(nonce)
        ..add(wrapped);
      yield header.takeBytes();

      final messages = _chunk(plain, chunkSize);
      final cipher = sodium.crypto.secretStream.pushEx(
        messageStream: messages,
        key: fileKey,
      );
      await for (final c in cipher) {
        yield c.message;
      }
    } finally {
      fileKey.dispose();
    }
  }

  /// Decrypts a container byte stream. Throws on a wrong key, tampering or
  /// a truncated file.
  Stream<List<int>> decrypt(
    Stream<List<int>> cipher,
    SecureKey masterKey,
  ) async* {
    final reader = _ByteReader(cipher);
    SecureKey? fileKey;
    try {
      final fixedLen = _fixedHeaderBytes + _nonceBytes + _wrappedKeyBytes;
      final fixed = await reader.take(fixedLen);
      if (fixed.length != fixedLen ||
          !_listEquals(fixed.sublist(0, 4), magic) ||
          fixed[4] != version) {
        throw const FormatException('not a valid v1 .shtr container');
      }
      final chunkSize = ByteData.sublistView(fixed, 6, 10).getUint32(0);
      if (chunkSize == 0 || chunkSize > maxChunkSize) {
        throw const FormatException('unsupported chunk size');
      }
      fileKey = SecureKey.fromList(
        sodium,
        sodium.crypto.secretBox.openEasy(
          cipherText: fixed.sublist(10 + _nonceBytes, fixedLen),
          nonce: fixed.sublist(10, 10 + _nonceBytes),
          key: masterKey,
        ),
      );
      yield* sodium.crypto.secretStream.pullChunked(
        cipherStream: reader.rest(),
        key: fileKey,
        chunkSize: chunkSize,
      );
    } finally {
      fileKey?.dispose();
      await reader.cancel();
    }
  }

  Future<void> encryptFile(File plain, File out, SecureKey masterKey) async {
    final sink = out.openWrite();
    try {
      await sink.addStream(encrypt(plain.openRead(), masterKey));
    } finally {
      await sink.close();
    }
  }

  /// Splits plaintext into full chunks; the remainder (possibly empty) is
  /// emitted last with the FINAL tag.
  Stream<SecretStreamPlainMessage> _chunk(
    Stream<List<int>> source,
    int chunkSize,
  ) async* {
    var buf = BytesBuilder(copy: false);
    await for (final bytes in source) {
      buf.add(bytes);
      while (buf.length >= chunkSize) {
        final all = buf.takeBytes();
        yield SecretStreamPlainMessage(
          Uint8List.sublistView(all, 0, chunkSize),
        );
        buf = BytesBuilder(copy: false)
          ..add(Uint8List.sublistView(all, chunkSize));
      }
    }
    yield SecretStreamPlainMessage(
      buf.takeBytes(),
      tag: SecretStreamMessageTag.finalPush,
    );
  }

  static Uint8List _u32(int v) =>
      Uint8List(4)..buffer.asByteData().setUint32(0, v);

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Pulls a fixed prefix off a byte stream, then hands back the rest.
class _ByteReader {
  _ByteReader(Stream<List<int>> source) : _it = StreamIterator(source);

  final StreamIterator<List<int>> _it;
  Uint8List _carry = Uint8List(0);

  Future<Uint8List> take(int n) async {
    final buf = BytesBuilder(copy: false)..add(_carry);
    while (buf.length < n && await _it.moveNext()) {
      buf.add(_it.current);
    }
    final all = buf.takeBytes();
    if (all.length <= n) {
      _carry = Uint8List(0);
      return all;
    }
    _carry = Uint8List.sublistView(all, n);
    return Uint8List.sublistView(all, 0, n);
  }

  Future<void> cancel() => _it.cancel();

  Stream<List<int>> rest() async* {
    if (_carry.isNotEmpty) yield _carry;
    while (await _it.moveNext()) {
      yield _it.current;
    }
  }
}
