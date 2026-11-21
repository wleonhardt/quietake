import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/crypto/pending_crypto.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/vault/pending_key_store.dart';
import 'package:sodium/sodium_sumo.dart';

void main() {
  late SodiumSumo sodium;
  late VaultCrypto vault;
  late Directory dir;
  late PendingKeyStore store;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
    vault = VaultCrypto(sodium);
  });
  setUp(() {
    dir = Directory.systemTemp.createTempSync('pending_keys');
    store = PendingKeyStore(sodium, dir);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('without a file there is no public key', () async {
    expect(await store.publicKey(), isNull);
  });

  test('ensure creates a pair that survives a new store instance', () async {
    final master = vault.generateMasterKey();
    await store.ensure(master);
    final first = await store.publicKey();
    expect(first, isNotNull);
    await PendingKeyStore(sodium, dir).ensure(master);
    expect(await PendingKeyStore(sodium, dir).publicKey(), first);
  });

  test('the public key is readable without the master key and the secret is not on disk', () async {
    final master = vault.generateMasterKey();
    await store.ensure(master);
    final secret = await store.secretKey(master);
    final raw = secret.extractBytes();
    final text = store.file.readAsBytesSync();
    expect(_contains(text, raw), isFalse);
    secret.dispose();
  });

  test('a stored pair seals while locked and publishes after unlock', () async {
    final master = vault.generateMasterKey();
    await store.ensure(master);
    final pub = (await store.publicKey())!;
    final crypto = PendingCrypto(sodium);
    final plain = File('${dir.path}/p')..writeAsBytesSync([1, 2, 3, 4, 5]);
    final sealed = File('${dir.path}/p.pending');
    await crypto.seal(plain, sealed, pub);
    final secret = await store.secretKey(master);
    final out = File('${dir.path}/p.shtr');
    await crypto.publish(sealed, out, pub, secret, master);
    secret.dispose();
    expect(await vault.plaintextLength(out), 5);
  });

  test('a wrong master key cannot open the secret', () async {
    await store.ensure(vault.generateMasterKey());
    await expectLater(
      store.secretKey(vault.generateMasterKey()),
      throwsA(anything),
    );
  });

  test(
    'a pair sealed under a replaced master key is renewed by ensure',
    () async {
      await store.ensure(vault.generateMasterKey());
      final old = await store.publicKey();
      await store.ensure(vault.generateMasterKey());
      expect(await store.publicKey(), isNot(old));
    },
  );

  test(
    'a damaged file reads as no public key and is replaced by ensure',
    () async {
      final master = vault.generateMasterKey();
      store.file.writeAsStringSync('{"v":1,"publicKey":"AAAA"}');
      expect(await store.publicKey(), isNull);
      await store.ensure(master);
      expect(await store.publicKey(), isNotNull);
      store.file.writeAsStringSync('not json');
      expect(await store.publicKey(), isNull);
    },
  );
}

bool _contains(List<int> hay, List<int> needle) {
  for (var i = 0; i + needle.length <= hay.length; i++) {
    var ok = true;
    for (var j = 0; j < needle.length; j++) {
      if (hay[i + j] != needle[j]) {
        ok = false;
        break;
      }
    }
    if (ok) return true;
  }
  return false;
}
