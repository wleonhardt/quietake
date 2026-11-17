import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sodium/sodium_sumo.dart';

/// Key pair for captures taken while the vault is locked (decision 028).
///
/// `vault.pendingkey.json` in the app documents folder holds the public key in
/// the clear, so a locked app can seal a capture, and the secret key encrypted
/// under the master key, so only an unlocked app can publish it. The keyfile
/// and the passcode are not involved; changing the passcode leaves this file
/// valid because the master key does not change.
class PendingKeyStore {
  PendingKeyStore(this.sodium, this.dir);

  final SodiumSumo sodium;
  final Directory dir;

  File get file => File('${dir.path}/vault.pendingkey.json');

  /// The public key, or null when no valid file exists.
  Future<Uint8List?> publicKey() async => (await _read())?.publicKey;

  /// Creates the pair when missing or when its secret does not open with
  /// [masterKey] (the vault key was replaced, so older pending files could not
  /// be published anyway). An existing valid pair is kept.
  Future<void> ensure(SecureKey masterKey) async {
    final current = await _read();
    if (current != null) {
      try {
        (await _open(current, masterKey)).dispose();
        return;
      } on Object {
        // Falls through to a new pair.
      }
    }
    final pair = sodium.crypto.box.keyPair();
    try {
      final nonce = sodium.randombytes.buf(sodium.crypto.secretBox.nonceBytes);
      final sealed = pair.secretKey.runUnlockedSync(
        (bytes) => sodium.crypto.secretBox.easy(
          message: bytes,
          nonce: nonce,
          key: masterKey,
        ),
      );
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(
        jsonEncode({
          'v': 1,
          'publicKey': base64Encode(pair.publicKey),
          'nonce': base64Encode(nonce),
          'secret': base64Encode(sealed),
        }),
        flush: true,
      );
      await tmp.rename(file.path);
    } finally {
      pair.secretKey.dispose();
    }
  }

  /// The secret key; the caller disposes it. Throws when the file is missing
  /// or [masterKey] does not match.
  Future<SecureKey> secretKey(SecureKey masterKey) async {
    final current = await _read();
    if (current == null) throw const FormatException('no pending key file');
    return _open(current, masterKey);
  }

  SecureKey _openSync(_Stored s, SecureKey masterKey) {
    final raw = sodium.crypto.secretBox.openEasy(
      cipherText: s.secret,
      nonce: s.nonce,
      key: masterKey,
    );
    try {
      return SecureKey.fromList(sodium, raw);
    } finally {
      raw.fillRange(0, raw.length, 0);
    }
  }

  Future<SecureKey> _open(_Stored s, SecureKey masterKey) async =>
      _openSync(s, masterKey);

  Future<_Stored?> _read() async {
    try {
      final j = jsonDecode(await file.readAsString());
      if (j is! Map || j['v'] != 1) return null;
      final pub = base64Decode(j['publicKey'] as String);
      final nonce = base64Decode(j['nonce'] as String);
      final secret = base64Decode(j['secret'] as String);
      if (pub.length != sodium.crypto.box.publicKeyBytes ||
          nonce.length != sodium.crypto.secretBox.nonceBytes ||
          secret.length !=
              sodium.crypto.box.secretKeyBytes +
                  sodium.crypto.secretBox.macBytes) {
        return null;
      }
      return _Stored(pub, nonce, secret);
    } on Object {
      return null;
    }
  }
}

class _Stored {
  const _Stored(this.publicKey, this.nonce, this.secret);
  final Uint8List publicKey;
  final Uint8List nonce;
  final Uint8List secret;
}
