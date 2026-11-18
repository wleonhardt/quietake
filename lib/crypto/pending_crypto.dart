import 'dart:io';
import 'dart:typed_data';

import 'package:sodium/sodium_sumo.dart';

import 'vault_crypto.dart';

/// Transient format for a capture taken while the vault is locked
/// (decision 028). It is never uploaded and never replaces the v1 container.
///
/// ```
/// offset size  field
/// 0      4     magic "SHTP"
/// 4      1     version (1)
/// 5      1     reserved (0)
/// 6      80    wrap key sealed to the vault public key (crypto_box_seal)
/// 86     ...   an ordinary v1 container whose file key is wrapped with the wrap key
/// ```
///
/// Publishing opens the wrap key with the vault secret key, re-wraps only the
/// 32-byte file key under the master key and copies the rest unchanged, so the
/// result is a normal v1 container.
class PendingCrypto {
  PendingCrypto(this.sodium) : _vault = VaultCrypto(sodium);

  final SodiumSumo sodium;
  final VaultCrypto _vault;

  static const magic = [0x53, 0x48, 0x54, 0x50]; // SHTP
  static const version = 1;
  static const _prefix = 6;

  int get _sealedBytes =>
      sodium.crypto.secretBox.keyBytes + sodium.crypto.box.sealBytes;
  int get _nonceBytes => sodium.crypto.secretBox.nonceBytes;
  int get _wrappedBytes =>
      sodium.crypto.secretStream.keyBytes + sodium.crypto.secretBox.macBytes;
  int get _v1KeyPart => 10 + _nonceBytes + _wrappedBytes;

  KeyPair generateKeyPair() => sodium.crypto.box.keyPair();

  /// Encrypts [plain] into [out] so only the holder of the secret key can
  /// publish it. Needs no vault key.
  Future<void> seal(File plain, File out, Uint8List publicKey) async {
    final wrap = sodium.crypto.secretBox.keygen();
    try {
      final sealedKey = wrap.runUnlockedSync(
        (bytes) => sodium.crypto.box.seal(message: bytes, publicKey: publicKey),
      );
      final sink = out.openWrite();
      try {
        sink
          ..add(magic)
          ..add([version, 0])
          ..add(sealedKey);
        await sink.addStream(_vault.encrypt(plain.openRead(), wrap));
      } finally {
        await sink.close();
      }
    } finally {
      wrap.dispose();
    }
  }

  /// Writes an ordinary v1 container for [pending] to [out]. Nothing is left
  /// at [out] when the file is damaged or the key does not match.
  Future<void> publish(
    File pending,
    File out,
    Uint8List publicKey,
    SecureKey secretKey,
    SecureKey masterKey,
  ) async {
    final raf = await pending.open();
    final tmp = File('${out.path}.part');
    try {
      final head = await raf.read(_prefix + _sealedBytes + _v1KeyPart);
      if (head.length != _prefix + _sealedBytes + _v1KeyPart ||
          !_same(head.sublist(0, 4), magic) ||
          head[4] != version) {
        throw const FormatException('not a valid pending capture');
      }
      final wrapRaw = sodium.crypto.box.sealOpen(
        cipherText: head.sublist(_prefix, _prefix + _sealedBytes),
        publicKey: publicKey,
        secretKey: secretKey,
      );
      final wrap = SecureKey.fromList(sodium, wrapRaw);
      wrapRaw.fillRange(0, wrapRaw.length, 0);
      try {
        final v1 = head.sublist(_prefix + _sealedBytes);
        final fileKey = sodium.crypto.secretBox.openEasy(
          cipherText: v1.sublist(10 + _nonceBytes),
          nonce: v1.sublist(10, 10 + _nonceBytes),
          key: wrap,
        );
        final nonce = sodium.randombytes.buf(_nonceBytes);
        final Uint8List rewrapped;
        try {
          rewrapped = sodium.crypto.secretBox.easy(
            message: fileKey,
            nonce: nonce,
            key: masterKey,
          );
        } finally {
          fileKey.fillRange(0, fileKey.length, 0);
        }
        final sink = tmp.openWrite();
        try {
          sink
            ..add(v1.sublist(0, 10))
            ..add(nonce)
            ..add(rewrapped);
          while (true) {
            final chunk = await raf.read(1 << 20);
            if (chunk.isEmpty) break;
            sink.add(chunk);
          }
        } finally {
          await sink.close();
        }
        await tmp.rename(out.path);
      } finally {
        wrap.dispose();
      }
    } catch (_) {
      if (tmp.existsSync()) tmp.deleteSync();
      rethrow;
    } finally {
      await raf.close();
    }
  }

  static bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
