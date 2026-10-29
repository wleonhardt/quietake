import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:quietake/backup/restore_transaction.dart';
import 'package:quietake/vault/vault.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:sodium/sodium_sumo.dart';

/// In-memory keystore so the store runs on the host.
class _MemStorage extends FlutterSecureStoragePlatform {
  final map = <String, String>{};
  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async => map[key] = value;
  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => map[key];
  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => map.containsKey(key);
  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async => map.remove(key);
  @override
  Future<void> deleteAll({required Map<String, String> options}) async =>
      map.clear();
  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => Map.of(map);
}

class _FlakyStorage extends _MemStorage {
  bool failWrites = false;
  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    if (failWrites) throw PlatformException(code: 'keystore');
    map[key] = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SodiumSumo sodium;
  late Directory dir;
  late MasterKeyStore store;
  late _MemStorage mem;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('quietake-keys');
    mem = _MemStorage();
    FlutterSecureStoragePlatform.instance = mem;
    store = MasterKeyStore(sodium, dir, storage: const FlutterSecureStorage());
  });

  tearDown(() => dir.delete(recursive: true));

  Future<Directory> restoreStage(SecureKey key) async {
    final stage = await dir.createTemp('.portable-stage-');
    final validated = await stage.rename('${stage.path}.validated');
    final vault = Vault(VaultCrypto(sodium), key.copy(), validated);
    try {
      await vault.writeMetadata(
        File('${validated.path}/quietake.catalog'),
        utf8.encode(jsonEncode({'version': 1, 'albums': {}, 'items': {}})),
      );
      final plain = await File('${dir.path}/synthetic-input')
          .writeAsBytes([1, 2, 3]);
      await vault.ingestAs(plain, 'restored.jpg');
    } finally {
      vault.dispose();
    }
    return validated;
  }

  test('portable restore adopts only a fresh empty vault and preserves recovered identity', () async {
    final key = sodium.crypto.secretBox.keygen();
    try {
      final stage = await restoreStage(key);
      await RestoreTransaction(store)
          .commit(stage, key, 'new portable passcode');
      expect(await store.hasKeyfile, isTrue);
      expect(await store.hasCachedKey, isFalse);
      final opened = await store.unlockWithPasscode('new portable passcode');
      final restored = Vault(
        VaultCrypto(sodium),
        opened,
        Directory('${dir.path}/vault'),
      );
      try {
        expect(await restored.readAll((await restored.list()).single), [
          1,
          2,
          3,
        ]);
        expect(restored.matchesKey(key), isTrue);
      } finally {
        restored.dispose();
      }
      expect(
        await Directory('${dir.path}/.portable-restore').exists(),
        isFalse,
      );
    } finally {
      key.dispose();
    }
  });

  test(
    'portable restore refuses existing credentials without modifying them',
    () async {
      final existing = await store.createWithPasscode('existing passcode');
      final original = await store.keyfile.readAsBytes();
      final key = sodium.crypto.secretBox.keygen();
      try {
        final stage = await restoreStage(key);
        await expectLater(
          RestoreTransaction(store).commit(stage, key, 'other passcode'),
          throwsFormatException,
        );
        expect(await store.keyfile.readAsBytes(), original);
        expect(await stage.exists(), isTrue);
        final opened = await store.unlockWithPasscode('existing passcode');
        try {
          expect(
            VaultCrypto(sodium).sodium
                .memcmp(opened.extractBytes(), existing.extractBytes()),
            isTrue,
          );
        } finally {
          opened.dispose();
        }
      } finally {
        key.dispose();
        existing.dispose();
      }
    },
  );

  test(
    'portable restore refuses nonempty media even when credentials are absent',
    () async {
      final original = await Directory('${dir.path}/vault').create();
      final keep = await File('${original.path}/keep.jpg.shtr')
          .writeAsBytes([9]);
      final key = sodium.crypto.secretBox.keygen();
      try {
        final stage = await restoreStage(key);
        await expectLater(
          RestoreTransaction(store).commit(stage, key, 'new passcode'),
          throwsFormatException,
        );
        expect(await keep.readAsBytes(), [9]);
        expect(await store.hasKeyfile, isFalse);
      } finally {
        key.dispose();
      }
    },
  );

  test('interruption after ready resumes validated media and credentials on next startup', () async {
    final key = sodium.crypto.secretBox.keygen();
    try {
      final stage = await restoreStage(key);
      await expectLater(
        RestoreTransaction(store).commit(
          stage,
          key,
          'restored passcode',
          onProgress: (phase) {
            if (phase == 'Saving restored vault') {
              throw StateError('Synthetic process interruption');
            }
          },
        ),
        throwsStateError,
      );
      expect(await store.hasKeyfile, isFalse);
      expect(await Directory('${dir.path}/vault').exists(), isFalse);
      expect(await RestoreTransaction(store).resume(), isTrue);
      final opened = await store.unlockWithPasscode('restored passcode');
      final restored = Vault(
        VaultCrypto(sodium),
        opened,
        Directory('${dir.path}/vault'),
      );
      try {
        expect(await restored.readAll((await restored.list()).single), [
          1,
          2,
          3,
        ]);
      } finally {
        restored.dispose();
      }
      expect(await RestoreTransaction(store).resume(), isFalse);
    } finally {
      key.dispose();
    }
  });

  test('resume never adopts credentials when the prepared media is gone', () async {
    final key = sodium.crypto.secretBox.keygen();
    try {
      final stage = await restoreStage(key);
      await expectLater(
        RestoreTransaction(store).commit(
          stage,
          key,
          'restored passcode',
          onProgress: (phase) {
            if (phase == 'Saving restored vault') {
              throw StateError('Synthetic process interruption');
            }
          },
        ),
        throwsStateError,
      );
      // Storage cleanup removed the prepared vault; a session may have created
      // the empty target directory since.
      await Directory('${dir.path}/.portable-restore/vault')
          .delete(recursive: true);
      await Directory('${dir.path}/vault').create();
      await expectLater(
        RestoreTransaction(store).resume(),
        throwsA(isA<FormatException>()),
      );
      expect(await store.hasKeyfile, isFalse);
      expect(
        await File('${dir.path}/.portable-restore/ready').exists(),
        isTrue,
        reason: 'the journal stays for inspection, nothing is adopted',
      );
    } finally {
      key.dispose();
    }
  });

  test(
    'cancel before ready keeps the fresh vault empty and removes owned copies',
    () async {
      final key = sodium.crypto.secretBox.keygen();
      try {
        final stage = await restoreStage(key);
        await expectLater(
          RestoreTransaction(store)
              .commit(stage, key, 'new passcode', isCancelled: () => true),
          throwsStateError,
        );
        expect(await store.hasKeyfile, isFalse);
        expect(await Directory('${dir.path}/vault').exists(), isFalse);
        expect(
          await Directory('${dir.path}/.portable-restore').exists(),
          isFalse,
        );
      } finally {
        key.dispose();
      }
    },
  );

  test('create, unlock, wrong passcode, cache', () async {
    final key = await store.createWithPasscode('correct horse');
    expect(await store.hasKeyfile, isTrue);
    expect(await store.hasCachedKey, isTrue);
    final again = await store.unlockWithPasscode('correct horse');
    expect(again.extractBytes(), key.extractBytes());
    await expectLater(
      store.unlockWithPasscode('wrong'),
      throwsA(isA<WrongPasscodeException>()),
    );
    expect((await store.cachedKey())!.extractBytes(), key.extractBytes());
  });

  test('unlock succeeds when the biometric cache cannot be written', () async {
    final flaky = _FlakyStorage();
    FlutterSecureStoragePlatform.instance = flaky;
    final key = await store.createWithPasscode('correct horse');
    flaky.failWrites = true;
    final again = await store.unlockWithPasscode('correct horse');
    expect(again.extractBytes(), key.extractBytes());
  });

  test(
    'recovery restore never leaves a stale biometric cache behind',
    () async {
      final flaky = _FlakyStorage();
      FlutterSecureStoragePlatform.instance = flaky;
      final key = await store.createWithPasscode('old');
      final stale = base64Encode(
        sodium.crypto.secretBox.keygen().extractBytes(),
      );
      flaky.map[MasterKeyStore.cacheName] = stale;
      flaky.failWrites = true;
      final restored = await store.restoreFromRecovery(
        store.exportRecovery(key),
        'new',
      );
      expect(restored.extractBytes(), key.extractBytes());
      expect(flaky.map.containsKey(MasterKeyStore.cacheName), isFalse);
      expect(
        (await store.unlockWithPasscode('new')).extractBytes(),
        key.extractBytes(),
      );
    },
  );

  test('adopts a key that was already in the keystore', () async {
    final legacy = sodium.crypto.secretBox.keygen();
    mem.map[MasterKeyStore.cacheName] = base64Encode(legacy.extractBytes());
    final key = await store.createWithPasscode('pw');
    expect(key.extractBytes(), legacy.extractBytes());
  });

  test('recovery export round-trips and sets a new passcode', () async {
    final key = await store.createWithPasscode('old');
    final rec = store.exportRecovery(key);
    expect(rec.replaceAll(' ', '').length, 44);
    final restored = await store.restoreFromRecovery(rec, 'new');
    expect(restored.extractBytes(), key.extractBytes());
    await expectLater(
      store.unlockWithPasscode('old'),
      throwsA(isA<WrongPasscodeException>()),
    );
    expect(
      (await store.unlockWithPasscode('new')).extractBytes(),
      key.extractBytes(),
    );
  });

  test(
    'an empty vault adopts a typed key only after its fingerprint is confirmed',
    () async {
      final key = sodium.crypto.secretBox.keygen();
      final recovery = store.exportRecovery(key);
      final seen = <String>[];
      await expectLater(
        store.restoreFromRecovery(
          recovery,
          'new-passcode',
          confirmFingerprint: (fp) async {
            seen.add(fp);
            return false;
          },
        ),
        throwsA(isA<BadRecoveryKeyException>()),
      );
      expect(seen, [store.fingerprint(key)]);
      expect(seen.single, matches(RegExp(r'^[0-9a-f]{4} [0-9a-f]{4}$')));
      expect(await store.hasKeyfile, isFalse);
      expect(await store.hasCachedKey, isFalse);
      final restored = await store.restoreFromRecovery(
        recovery,
        'new-passcode',
        confirmFingerprint: (_) async => true,
      );
      expect(restored.extractBytes(), key.extractBytes());
      expect(await store.hasKeyfile, isTrue);
    },
  );

  test(
    'a live-session match proves the key without a fingerprint prompt',
    () async {
      // Forgot-passcode restore inside an unlocked but empty vault: the open
      // session already holds the key, so no fingerprint dialog may block it.
      final key = sodium.crypto.secretBox.keygen();
      final restored = await store.restoreFromRecovery(
        store.exportRecovery(key),
        'changed-passcode',
        acceptsKey: (candidate) =>
            listEquals(candidate.extractBytes(), key.extractBytes()),
        confirmFingerprint: (_) async => fail('live session is the proof'),
      );
      expect(restored.extractBytes(), key.extractBytes());
    },
  );

  test(
    'a vault with containers proves the key without a fingerprint prompt',
    () async {
      final key = await store.createWithPasscode('original');
      final vault = Vault(
        VaultCrypto(sodium),
        key,
        Directory('${dir.path}/vault')..createSync(),
      );
      await vault.ingestAs(
        File('${dir.path}/plain')..writeAsBytesSync([1, 2, 3]),
        'a.jpg',
      );
      final restored = await store.restoreFromRecovery(
        store.exportRecovery(key),
        'changed-passcode',
        confirmFingerprint: (_) async => fail('no prompt with proof on disk'),
      );
      expect(restored.extractBytes(), key.extractBytes());
    },
  );

  test('bad recovery keys are rejected without touching the keyfile', () async {
    await store.createWithPasscode('pw');
    final before = await store.keyfile.readAsString();
    for (final bad in ['short', 'not base64 !!', 'QUJD']) {
      await expectLater(
        store.restoreFromRecovery(bad, 'x'),
        throwsA(isA<BadRecoveryKeyException>()),
      );
    }
    expect(await store.keyfile.readAsString(), before);
  });

  test(
    'wrong valid recovery key preserves existing keyfile and cache',
    () async {
      final key = await store.createWithPasscode('original');
      final vault = Vault(
        VaultCrypto(sodium),
        key,
        Directory('${dir.path}/vault')..createSync(),
      );
      await vault.ingestAs(
        File('${dir.path}/plain')..writeAsBytesSync([1, 2, 3]),
        'a.jpg',
      );
      final before = await store.keyfile.readAsString();
      final cached = Map.of(mem.map);
      final wrong = sodium.crypto.secretBox.keygen();
      try {
        await expectLater(
          store.restoreFromRecovery(store.exportRecovery(wrong), 'changed'),
          throwsA(isA<BadRecoveryKeyException>()),
        );
        expect(await store.keyfile.readAsString(), before);
        expect(mem.map, cached);
        expect(await vault.readAll((await vault.list()).single), [1, 2, 3]);
        (await store.restoreFromRecovery(
          store.exportRecovery(key),
          'changed',
        )).dispose();
        (await store.unlockWithPasscode('changed')).dispose();
      } finally {
        key.dispose();
        wrong.dispose();
      }
    },
  );

  test(
    'metadata-only vault rejects wrong recovery key and preserves library',
    () async {
      final key = await store.createWithPasscode('original');
      final vault = Vault(
        VaultCrypto(sodium),
        key,
        Directory('${dir.path}/vault')..createSync(),
      );
      final wrong = sodium.crypto.secretBox.keygen();
      try {
        await vault.catalog.createAlbum('Only encrypted content');
        final metadata = await vault.catalog.file.readAsBytes();
        final before = await store.keyfile.readAsBytes();
        final cached = Map.of(mem.map);
        Future<void> wrongRestore() async {
          (await store.restoreFromRecovery(
            store.exportRecovery(wrong),
            'changed',
          )).dispose();
        }

        await expectLater(
          wrongRestore(),
          throwsA(isA<BadRecoveryKeyException>()),
        );
        expect(await store.keyfile.readAsBytes(), before);
        expect(mem.map, cached);
        final restored = await store.restoreFromRecovery(
          store.exportRecovery(key),
          'recovered',
        );
        try {
          expect(
            await VaultCrypto(sodium)
                .decrypt(vault.catalog.file.openRead(), restored)
                .expand((c) => c)
                .toList(),
            isNotEmpty,
          );
          expect(await vault.catalog.file.readAsBytes(), metadata);
        } finally {
          restored.dispose();
        }
      } finally {
        await vault.catalog.close();
        vault.dispose();
        wrong.dispose();
      }
    },
  );

  test('correct recovery key can replace a stale biometric cache', () async {
    final key = await store.createWithPasscode('original');
    final vault = Vault(
      VaultCrypto(sodium),
      key,
      Directory('${dir.path}/vault')..createSync(),
    );
    await vault.ingestAs(
      File('${dir.path}/plain')..writeAsBytesSync([1, 2, 3]),
      'a.jpg',
    );
    final stale = sodium.crypto.secretBox.keygen();
    mem.map[MasterKeyStore.cacheName] = base64Encode(stale.extractBytes());
    try {
      (await store.restoreFromRecovery(
        store.exportRecovery(key),
        'recovered',
      )).dispose();
      (await store.unlockWithPasscode('recovered')).dispose();
      expect(await vault.readAll((await vault.list()).single), [1, 2, 3]);
    } finally {
      key.dispose();
      stale.dispose();
    }
  });

  test('invalid keyfile metadata fails before password work and preserves the cache', () async {
    (await store.createWithPasscode('test-passcode')).dispose();
    final original =
        jsonDecode(await store.keyfile.readAsString()) as Map<String, dynamic>;
    final cached = mem.map[MasterKeyStore.cacheName];
    for (final mutation in <String, Object?>{
      'v': 99,
      'kdf': 'unknown',
      'ops': 0,
      'mem': 0,
      'salt': base64Encode([0]),
      'nonce': base64Encode([0]),
      'wrapped': base64Encode([0]),
      // Mistyped or missing fields are untrusted input, not a crash.
      'ops-typed': 'many',
      'mem-missing': null,
      'salt-typed': 7,
    }.entries) {
      final key = mutation.key.split('-').first;
      final value = mutation.value;
      final mutated = {...original};
      if (value == null) {
        mutated.remove(key);
      } else {
        mutated[key] = value;
      }
      await store.keyfile.writeAsString(jsonEncode(mutated));
      await expectLater(
        store.unlockWithPasscode('test-passcode'),
        throwsFormatException,
        reason: mutation.key,
      );
      expect(mem.map[MasterKeyStore.cacheName] == cached, isTrue);
    }
    for (final mutation in [
      {'ops': 4},
      {'mem': (1 << 28) + 1024},
    ]) {
      await store.keyfile.writeAsString(jsonEncode({...original, ...mutation}));
      await expectLater(
        store.unlockWithPasscode('test-passcode'),
        throwsFormatException,
      );
    }
    await store.keyfile.writeAsString(jsonEncode(original));
    (await store.unlockWithPasscode('test-passcode')).dispose();
  });

  test('keyfile records the KDF parameters', () async {
    await store.createWithPasscode('pw');
    final j = await store.keyfile.readAsString();
    expect(j, contains('"kdf":"argon2id13"'));
    expect(j, contains('"ops":${sodium.crypto.pwhash.opsLimitModerate}'));
    expect(j, contains('"mem":${sodium.crypto.pwhash.memLimitModerate}'));
  });
  test('changing passcode preserves media and recovery identity', () async {
    final key = await store.createWithPasscode('old-passcode');
    final vault = Vault(
      VaultCrypto(sodium),
      key,
      await Directory('${dir.path}/vault').create(),
    );
    try {
      final plain = await File('${dir.path}/capture')
          .writeAsBytes([1, 2, 3, 4]);
      final capture = await vault.ingestAs(plain, 'photo.jpg');
      final original = await capture.readAsBytes();
      final recovery = store.exportRecovery(key);
      await store.changePasscode('old-passcode', 'new-passcode');
      await expectLater(
        store.unlockWithPasscode('old-passcode'),
        throwsA(isA<WrongPasscodeException>()),
      );
      final unlocked = await store.unlockWithPasscode('new-passcode');
      try {
        expect(store.exportRecovery(unlocked), recovery);
        expect(
          await VaultCrypto(sodium)
              .decrypt(capture.openRead(), unlocked)
              .expand((b) => b)
              .toList(),
          [1, 2, 3, 4],
        );
        expect(await capture.readAsBytes(), original);
      } finally {
        unlocked.dispose();
      }
    } finally {
      vault.dispose();
    }
  });

  test(
    'wrong current passcode or invalid replacement leaves keyfile unchanged',
    () async {
      (await store.createWithPasscode('current-passcode')).dispose();
      final original = await store.keyfile.readAsBytes();
      await expectLater(
        store.changePasscode('wrong', 'replacement'),
        throwsA(isA<WrongPasscodeException>()),
      );
      await expectLater(
        store.changePasscode('current-passcode', '123'),
        throwsFormatException,
      );
      expect(await store.keyfile.readAsBytes(), original);
      (await store.unlockWithPasscode('current-passcode')).dispose();
    },
  );

  test(
    'failed rewrap preserves original passcode and encrypted keyfile',
    () async {
      (await store.createWithPasscode('current-passcode')).dispose();
      final original = await store.keyfile.readAsBytes();
      await Directory('${store.keyfile.path}.tmp').create();
      await expectLater(
        store.changePasscode('current-passcode', 'replacement'),
        throwsA(isA<FileSystemException>()),
      );
      expect(await store.keyfile.readAsBytes(), original);
      (await store.unlockWithPasscode('current-passcode')).dispose();
    },
  );
  test(
    'live recovery rejection preserves keyfile, cache and old passcode',
    () async {
      final current = await store.createWithPasscode('still-valid');
      final foreign = sodium.crypto.secretBox.keygen();
      try {
        final before = await store.keyfile.readAsBytes();
        final cached = mem.map[MasterKeyStore.cacheName];
        await expectLater(
          store.restoreFromRecovery(
            store.exportRecovery(foreign),
            'replacement',
            acceptsKey: (_) => false,
          ),
          throwsA(isA<BadRecoveryKeyException>()),
        );
        expect(
          base64Encode(await store.keyfile.readAsBytes()) ==
              base64Encode(before),
          isTrue,
        );
        expect(mem.map[MasterKeyStore.cacheName] == cached, isTrue);
        (await store.unlockWithPasscode('still-valid')).dispose();
      } finally {
        current.dispose();
        foreign.dispose();
      }
    },
  );
}
