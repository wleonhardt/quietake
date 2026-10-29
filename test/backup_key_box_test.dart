import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/vault/backup_passphrase.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:sodium/sodium_sumo.dart';

const phrase = 'synthetic river violet paper lantern canyon';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SodiumSumo sodium;
  late Directory dir;
  late MasterKeyStore store;
  setUpAll(() async => sodium = await SodiumSumoInit.init());
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('nas-box-test-');
    store = MasterKeyStore(sodium, dir);
  });
  tearDown(() => dir.delete(recursive: true));

  test(
    'escaped duplicate or aliased envelope keys are rejected before KDF',
    () async {
      final fixture = jsonDecode(
        await File('docs/recovery-vectors/v1.json').readAsString(),
      ) as Map<String, dynamic>;
      final box = fixture['box'] as Map<String, dynamic>;
      final original = jsonEncode(box);
      for (final field in box.entries) {
        final escaped = field.key.codeUnits
            .map((c) => r'\u' + c.toRadixString(16).padLeft(4, '0'))
            .join();
        final duplicate =
            '{"$escaped":${jsonEncode(field.value)},${original.substring(1)}';
        expect(
          () => MasterKeyStore.validateBackupBox(utf8.encode(duplicate)),
          throwsFormatException,
          reason: field.key,
        );
        final alias = original.replaceFirst('"${field.key}":', '"$escaped":');
        expect(
          () => MasterKeyStore.validateBackupBox(utf8.encode(alias)),
          throwsFormatException,
          reason: field.key,
        );
      }
    },
  );

  test('backup box preserves identity, randomizes wrapping and stores no credentials', () async {
    final key = sodium.crypto.secretBox.keygen();
    try {
      final box = await store.wrapBackupKey(key, phrase);
      final next = await store.wrapBackupKey(key, phrase);
      expect(box, isNot(next));
      expect(box, isNot(contains(base64Encode(key.extractBytes()))));
      expect(box, isNot(contains(phrase)));
      final opened = await store.openBackupKey(utf8.encode(box), phrase);
      try {
        expect(opened.extractBytes(), key.extractBytes());
      } finally {
        opened.dispose();
      }
      await expectLater(
        store.openBackupKey(
          utf8.encode(box),
          'another river violet paper lantern canyon',
        ),
        throwsFormatException,
      );
      expect(await store.keyfile.exists(), isFalse);
      expect(await dir.list().toList(), isEmpty);
    } finally {
      key.dispose();
    }
  });

  test(
    'untrusted parameters and oversized documents fail before derivation',
    () async {
      final key = sodium.crypto.secretBox.keygen();
      try {
        final original = jsonDecode(
          await store.wrapBackupKey(key, phrase),
        ) as Map<String, dynamic>;
        for (final entry in <String, Object>{
          'v': 3,
          'kdf': 'argon2i',
          'ops': 1,
          'mem': 1073741824,
          'salt': 'AA==',
          'nonce': '',
          'wrapped': 'AA==',
          'unexpected': true,
        }.entries) {
          final changed = {...original, entry.key: entry.value};
          await expectLater(
            store.openBackupKey(utf8.encode(jsonEncode(changed)), phrase),
            throwsFormatException,
          );
        }
        await expectLater(
          store.openBackupKey(List.filled(4097, 32), phrase),
          throwsFormatException,
        );
        await expectLater(
          store.openBackupKey(utf8.encode('{"v":1}'), phrase),
          throwsFormatException,
        );
        final bytes = base64Decode(original['wrapped'] as String)..[0] ^= 1;
        original['wrapped'] = base64Encode(bytes);
        await expectLater(
          store.openBackupKey(utf8.encode(jsonEncode(original)), phrase),
          throwsFormatException,
        );
      } finally {
        key.dispose();
      }
    },
  );

  test('an authenticated payload from another purpose is rejected', () async {
    final fixture = jsonDecode(
      await File('docs/recovery-vectors/v1.json').readAsString(),
    ) as Map<String, dynamic>;
    final box = Map<String, dynamic>.from(fixture['box'] as Map);
    final derived = sodium.crypto.pwhash.callStr(
      outLen: 32,
      password: phrase,
      salt: base64Decode(box['salt'] as String),
      opsLimit: 3,
      memLimit: 268435456,
      alg: CryptoPwhashAlgorithm.argon2id13,
    );
    try {
      final message = Uint8List.fromList([
        ...utf8.encode('tucklight.nas-recovery.x1\u0000'),
        ...base64Decode(fixture['public_key'] as String),
      ]);
      box['wrapped'] = base64Encode(
        sodium.crypto.secretBox.easy(
          message: message,
          nonce: base64Decode(box['nonce'] as String),
          key: derived,
        ),
      );
      await expectLater(
        store.openBackupKey(utf8.encode(jsonEncode(box)), phrase),
        throwsFormatException,
      );
    } finally {
      derived.dispose();
    }
    final duplicate = '{"v":1,${jsonEncode(fixture['box']).substring(1)}';
    await expectLater(
      store.openBackupKey(utf8.encode(duplicate), phrase),
      throwsFormatException,
    );
  });

  test('weak input never produces a box', () async {
    final key = sodium.crypto.secretBox.keygen();
    try {
      for (final weak in [
        '1234',
        'a' * 30,
        '1234567890' * 3,
        'a phrase with\na newline',
      ]) {
        await expectLater(
          store.wrapBackupKey(key, weak),
          throwsFormatException,
        );
      }
    } finally {
      key.dispose();
    }
  });

  test('six-word generator uses the complete unique EFF list', () async {
    final words = await BackupPassphrase.words();
    expect(words, hasLength(7776));
    final samples = <String>{};
    for (var i = 0; i < 10; i++) {
      final value = await BackupPassphrase.generate(sodium);
      BackupPassphrase.validate(value);
      expect(value.split(' '), hasLength(6));
      expect(value.split(' ').every(words.contains), isTrue);
      samples.add(value);
    }
    expect(samples, hasLength(10));
  });

  test(
    'public envelope fixture independently preserves synthetic key',
    () async {
      final fixture = jsonDecode(
        await File('docs/recovery-vectors/v1.json').readAsString(),
      ) as Map<String, dynamic>;
      final key = await store.openBackupKey(
        utf8.encode(jsonEncode(fixture['box'])),
        fixture['passphrase'] as String,
      );
      try {
        expect(
          key.extractBytes(),
          Uint8List.fromList(base64Decode(fixture['public_key'] as String)),
        );
      } finally {
        key.dispose();
      }
    },
  );
}
