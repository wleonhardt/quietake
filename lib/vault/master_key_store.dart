import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sodium/sodium_sumo.dart';

import '../compat/legacy_identity.dart';
import '../crypto/vault_crypto.dart';
import '../library/private_catalog.dart';
import 'backup_passphrase.dart';

class WrongPasscodeException implements Exception {
  @override
  String toString() => 'wrong passcode';
}

class BadRecoveryKeyException implements Exception {
  BadRecoveryKeyException([
    this.message = 'recovery key is not 32 bytes of base64',
  ]);
  final String message;
  @override
  String toString() => message;
}

/// Where the vault master key lives and how it is unlocked.
///
/// - `vault.keyfile.json` in the app documents folder: the master key
///   wrapped with a key derived from the passcode by Argon2id (libsodium
///   pwhash, moderate limits). Losing it is fine as long as the recovery
///   key exists; losing both is total loss.
/// - Platform keystore entry `quietake.master_key`: the raw master key, so a
///   biometric prompt can unlock without the Argon2id round trip. Best effort:
///   refreshed on passcode unlock and recovery restore, and cleared when that
///   refresh fails so it can never hold a key the keyfile no longer has.
/// - Recovery key: the master key itself, base64, shown once at setup and on
///   demand after a passcode check. Enough on its own to read every container.
class MasterKeyStore {
  MasterKeyStore(this.sodium, this.dir, {FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final SodiumSumo sodium;
  final Directory dir;
  final FlutterSecureStorage _storage;

  static const cacheName = 'quietake.master_key';

  /// Minimum for new passcodes (decision 038); existing keyfiles keep unlocking.
  static const minPasscodeLength = 6;
  static const passcodeTooShort = 'Passcode needs at least 6 characters';

  File get keyfile => File('${dir.path}/vault.keyfile.json');

  Future<bool> get hasKeyfile => keyfile.exists();

  Future<bool> get hasCachedKey => _storage.containsKey(key: cacheName);

  /// Raw key from the keystore, for biometric unlock. Null when absent.
  Future<SecureKey?> cachedKey() async {
    final b64 = await _storage.read(key: cacheName);
    if (b64 == null) return null;
    final raw = base64Decode(b64);
    try {
      return SecureKey.fromList(sodium, raw);
    } finally {
      raw.fillRange(0, raw.length, 0);
    }
  }

  Future<void> clearCache() => _storage.delete(key: cacheName);

  /// First-run setup in one step; the UI uses [prepareKey] and
  /// [commitPasscode] so nothing is persisted before the recovery key is saved
  /// (decision 038).
  Future<SecureKey> createWithPasscode(String passcode) async {
    final key = await prepareKey();
    try {
      await commitPasscode(key, passcode);
    } catch (_) {
      key.dispose();
      rethrow;
    }
    return key;
  }

  /// The future vault key, persisted nowhere yet. Adopts a key already in the
  /// keystore (pre-passcode installs) so existing containers stay readable.
  Future<SecureKey> prepareKey() async =>
      await cachedKey() ?? sodium.crypto.secretBox.keygen();

  /// Makes [key] the vault identity: keyfile wrapped by [passcode], then the
  /// best-effort biometric cache.
  Future<void> commitPasscode(SecureKey key, String passcode) async {
    await _writeKeyfile(key, passcode);
    await _refreshCache(key);
  }

  Future<SecureKey> unlockWithPasscode(String passcode) async {
    final j = jsonDecode(await keyfile.readAsString());
    // Untrusted bytes: shape first, so a damaged file is a FormatException.
    if (j is! Map ||
        j['v'] != 1 ||
        j['kdf'] != 'argon2id13' ||
        j['salt'] is! String ||
        j['nonce'] is! String ||
        j['wrapped'] is! String ||
        j['ops'] is! int ||
        j['mem'] is! int) {
      throw const FormatException('unsupported keyfile parameters');
    }
    final salt = base64Decode(j['salt'] as String);
    final nonce = base64Decode(j['nonce'] as String);
    final wrapped = base64Decode(j['wrapped'] as String);
    final ops = j['ops'] as int;
    final mem = j['mem'] as int;
    final pw = sodium.crypto.pwhash;
    if (salt.length != pw.saltBytes ||
        nonce.length != sodium.crypto.secretBox.nonceBytes ||
        wrapped.length !=
            sodium.crypto.secretBox.keyBytes +
                sodium.crypto.secretBox.macBytes ||
        ops < pw.opsLimitMin ||
        ops > pw.opsLimitModerate ||
        mem < pw.memLimitMin ||
        mem > pw.memLimitModerate) {
      throw const FormatException('unsupported keyfile parameters');
    }
    final kek = await _derive(passcode, salt, ops, mem);
    try {
      final raw = sodium.crypto.secretBox.openEasy(
        cipherText: wrapped,
        nonce: nonce,
        key: kek,
      );
      final SecureKey key;
      try {
        key = SecureKey.fromList(sodium, raw);
      } finally {
        raw.fillRange(0, raw.length, 0);
      }
      await _refreshCache(key);
      return key;
    } on SodiumException {
      throw WrongPasscodeException();
    } finally {
      kek.dispose();
    }
  }

  /// Rewraps the existing vault key; encrypted captures and recovery stay valid.
  Future<void> changePasscode(
    String currentPasscode,
    String newPasscode,
  ) async {
    if (newPasscode.length < minPasscodeLength) {
      throw const FormatException(passcodeTooShort);
    }
    final key = await unlockWithPasscode(currentPasscode);
    try {
      await _writeKeyfile(key, newPasscode);
    } finally {
      key.dispose();
    }
  }

  /// The master key as base64 in groups of four, for a password manager or
  /// paper.
  String exportRecovery(SecureKey key) {
    final b64 = key.runUnlockedSync(base64Encode);
    return [
      for (var i = 0; i < b64.length; i += 4)
        b64.substring(i, (i + 4).clamp(0, b64.length)),
    ].join(' ');
  }

  /// Short, human-comparable identity of a key: 32 bits of BLAKE2b as hex.
  /// Shown with the recovery key and checked when an empty vault adopts a
  /// typed key (decision 038). It reveals nothing useful about the key.
  String fingerprint(SecureKey key) {
    final hash = key.runUnlockedSync(
      (bytes) => sodium.crypto.genericHash.call(
        message: bytes,
        outLen: sodium.crypto.genericHash.bytesMin,
      ),
    );
    final hex = hash
        .take(4)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 4)} ${hex.substring(4)}';
  }

  /// Rebuilds the keyfile from a recovery key and a new passcode. When the
  /// vault holds no container to prove the key, [confirmFingerprint] must
  /// accept the key's fingerprint before anything is written.
  Future<SecureKey> restoreFromRecovery(
    String recovery,
    String newPasscode, {
    bool Function(SecureKey)? acceptsKey,
    Future<bool> Function(String fingerprint)? confirmFingerprint,
  }) async {
    final key = importRecovery(recovery);
    try {
      if (acceptsKey != null && !acceptsKey(key)) {
        throw BadRecoveryKeyException(
          'Use the recovery key saved for this open vault',
        );
      }
      final vaultDir = Directory('${dir.path}/vault');
      final files = await vaultDir.exists()
          ? await vaultDir
                .list()
                .where(
                  (e) =>
                      e is File &&
                      (e.path.endsWith('.shtr') ||
                          e.uri.pathSegments.last == PrivateCatalog.fileName),
                )
                .cast<File>()
                .toList()
          : const <File>[];
      var matches = false;
      for (final file in files) {
        try {
          await VaultCrypto(sodium).decrypt(file.openRead(), key).first;
          matches = true;
          break;
        } on SodiumException {
          // Another intact container may still prove the recovery key.
        } on FormatException {
          // Ignore damaged containers while checking the remaining vault.
        }
      }
      if (files.isNotEmpty && !matches) {
        throw BadRecoveryKeyException('Recovery key could not open this vault');
      }
      // A live session that accepted the key is proof too (decision 027), so
      // only a cold restore into an empty vault asks for the fingerprint.
      if (files.isEmpty &&
          acceptsKey == null &&
          confirmFingerprint != null &&
          !await confirmFingerprint(fingerprint(key))) {
        throw BadRecoveryKeyException('Recovery key fingerprint not confirmed');
      }
      await _writeKeyfile(key, newPasscode);
      await _refreshCache(key);
      return key;
    } catch (_) {
      key.dispose();
      rethrow;
    }
  }

  /// The keyfile is authoritative; a cache that cannot follow it is removed.
  Future<void> _refreshCache(SecureKey key) async {
    try {
      await _cache(key);
    } catch (_) {
      await _storage.delete(key: cacheName);
    }
  }

  /// Parses a private recovery input without changing any stored credentials.
  SecureKey importRecovery(String recovery) {
    final Uint8List raw;
    try {
      raw = base64Decode(recovery.replaceAll(RegExp(r'[\s-]'), ''));
    } on FormatException {
      throw BadRecoveryKeyException();
    }
    try {
      if (raw.length != sodium.crypto.secretBox.keyBytes) {
        throw BadRecoveryKeyException();
      }
      return SecureKey.fromList(sodium, raw);
    } finally {
      raw.fillRange(0, raw.length, 0);
    }
  }

  static const recoveryBoxName = 'quietake.recovery.json';
  static const recoveryBoxLimit = 4096;
  static const _backupPurpose = 'quietake.nas-recovery';
  static const _backupMarker = 'quietake.nas-recovery.v2\u0000';

  static String _marker(Map<String, dynamic> value) =>
      value['v'] == 1 ? LegacyIdentity.recoveryMarker : _backupMarker;

  /// Reject untrusted sizes, fields and KDF costs before allocating Argon2 memory.
  static Map<String, dynamic> validateBackupBox(List<int> bytes) {
    if (bytes.isEmpty || bytes.length > recoveryBoxLimit) {
      throw const FormatException('Unsupported backup recovery file');
    }
    final text = utf8.decode(bytes);
    final fields = RegExp(r'"((?:[^"\\]|\\.)*)"\s*:')
        .allMatches(text)
        .map((m) => m.group(1)!)
        .toList();
    const expected = {
      'v',
      'purpose',
      'kdf',
      'ops',
      'mem',
      'salt',
      'nonce',
      'wrapped',
    };
    final value = jsonDecode(text);
    if (fields.length != expected.length ||
        fields.toSet().length != expected.length ||
        fields.any((name) => !expected.contains(name)) ||
        value is! Map<String, dynamic> ||
        value.length != expected.length ||
        !expected.every(value.containsKey) ||
        value['v'] is! int ||
        !((value['v'] == 2 && value['purpose'] == _backupPurpose) ||
            (value['v'] == 1 &&
                value['purpose'] == LegacyIdentity.recoveryPurpose)) ||
        value['kdf'] != 'argon2id13' ||
        value['ops'] is! int ||
        value['ops'] != 3 ||
        value['mem'] is! int ||
        value['mem'] != 268435456) {
      throw const FormatException('Unsupported backup recovery file');
    }
    for (final entry in {
      'salt': 16,
      'nonce': 24,
      'wrapped': utf8.encode(_marker(value)).length + 32 + 16,
    }.entries) {
      final encoded = value[entry.key];
      if (encoded is! String ||
          base64Decode(encoded).length != entry.value ||
          base64Encode(base64Decode(encoded)) != encoded) {
        throw const FormatException('Unsupported backup recovery file');
      }
    }
    return value;
  }

  /// A server envelope is separate from the weaker on-device passcode keyfile.
  Future<String> wrapBackupKey(SecureKey key, String passphrase) async {
    BackupPassphrase.validate(passphrase);
    final salt = sodium.randombytes.buf(16);
    final nonce = sodium.randombytes.buf(24);
    final kek = await _derive(passphrase, salt, 3, 268435456);
    Uint8List? message;
    try {
      final raw = key.extractBytes();
      try {
        final marker = utf8.encode(_backupMarker);
        message = Uint8List(marker.length + raw.length)
          ..setAll(0, marker)
          ..setAll(marker.length, raw);
      } finally {
        raw.fillRange(0, raw.length, 0);
      }
      final wrapped = sodium.crypto.secretBox.easy(
        message: message,
        nonce: nonce,
        key: kek,
      );
      return jsonEncode({
        'v': 2,
        'purpose': _backupPurpose,
        'kdf': 'argon2id13',
        'ops': 3,
        'mem': 268435456,
        'salt': base64Encode(salt),
        'nonce': base64Encode(nonce),
        'wrapped': base64Encode(wrapped),
      });
    } finally {
      message?.fillRange(0, message.length, 0);
      kek.dispose();
    }
  }

  /// Opens only in memory. Adoption still needs authenticated media and a new PIN.
  Future<SecureKey> openBackupKey(List<int> bytes, String passphrase) async {
    final value = validateBackupBox(bytes);
    BackupPassphrase.validate(passphrase);
    final kek = await _derive(
      passphrase,
      base64Decode(value['salt'] as String),
      3,
      268435456,
    );
    Uint8List? message;
    try {
      message = sodium.crypto.secretBox.openEasy(
        cipherText: base64Decode(value['wrapped'] as String),
        nonce: base64Decode(value['nonce'] as String),
        key: kek,
      );
      final marker = utf8.encode(_marker(value));
      for (var i = 0; i < marker.length; i++) {
        if (message[i] != marker[i]) {
          throw const FormatException('Backup recovery failed');
        }
      }
      return SecureKey.fromList(
        sodium,
        Uint8List.sublistView(message, marker.length),
      );
    } on SodiumException {
      throw const FormatException('Backup recovery failed');
    } finally {
      message?.fillRange(0, message.length, 0);
      kek.dispose();
    }
  }

  /// A random 256-bit ZIP password, never written into the portable archive.
  static String archivePassword(SecureKey key) =>
      key.runUnlockedSync(base64Encode);

  /// Prepares an encrypted keyfile inside the portable restore transaction.
  /// No biometric cache is changed; first passcode unlock can populate it.
  Future<File> preparePortableKeyfile(SecureKey key, String passcode) async {
    if (passcode.length < minPasscodeLength) {
      throw const FormatException(passcodeTooShort);
    }
    final target = File('${dir.path}/.portable-restore/vault.keyfile.json');
    await _writeKeyfile(key, passcode, destination: target);
    return target;
  }

  Future<void> _cache(SecureKey key) =>
      _storage.write(key: cacheName, value: key.runUnlockedSync(base64Encode));

  Future<void> _writeKeyfile(
    SecureKey key,
    String passcode, {
    File? destination,
  }) async {
    final target = destination ?? keyfile;
    final pw = sodium.crypto.pwhash;
    final salt = sodium.randombytes.buf(pw.saltBytes);
    final ops = pw.opsLimitModerate;
    final mem = pw.memLimitModerate;
    final kek = await _derive(passcode, salt, ops, mem);
    try {
      final nonce = sodium.randombytes.buf(sodium.crypto.secretBox.nonceBytes);
      final wrapped = key.runUnlockedSync(
        (bytes) => sodium.crypto.secretBox.easy(
          message: bytes,
          nonce: nonce,
          key: kek,
        ),
      );
      final tmp = File('${target.path}.tmp');
      await tmp.writeAsString(
        jsonEncode({
          'v': 1,
          'kdf': 'argon2id13',
          'salt': base64Encode(salt),
          'ops': ops,
          'mem': mem,
          'nonce': base64Encode(nonce),
          'wrapped': base64Encode(wrapped),
        }),
        flush: true,
      );
      await tmp.rename(target.path);
    } finally {
      kek.dispose();
    }
  }

  /// Argon2id on a worker isolate; moderate limits take a few hundred ms.
  Future<SecureKey> _derive(
    String passcode,
    Uint8List salt,
    int ops,
    int mem,
  ) => sodium.runIsolated(
    (keys, pairs) => sodium.crypto.pwhash.callStr(
      outLen: sodium.crypto.secretBox.keyBytes,
      password: passcode,
      salt: salt,
      opsLimit: ops,
      memLimit: mem,
      alg: CryptoPwhashAlgorithm.argon2id13,
    ),
  );
}
