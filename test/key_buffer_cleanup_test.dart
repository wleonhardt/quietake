import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:sodium/sodium_sumo.dart';

class _CopyObserver implements SodiumSumo {
  _CopyObserver(this.delegate, {this.failCopy = false});
  final SodiumSumo delegate;
  final bool failCopy;
  final buffers = <Uint8List>[];

  @override
  CryptoSumo get crypto => delegate.crypto;

  @override
  SecureKey secureCopy(Uint8List data) {
    buffers.add(data);
    if (failCopy) throw StateError('synthetic allocation failure');
    return delegate.secureCopy(data);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ExtractObserver implements SecureKey {
  _ExtractObserver(this.delegate);
  final SecureKey delegate;
  final buffers = <Uint8List>[];

  @override
  Uint8List extractBytes() {
    final bytes = delegate.extractBytes();
    buffers.add(bytes);
    return bytes;
  }

  @override
  T runUnlockedSync<T>(SecureCallbackFn<T> callback, {bool writable = false}) =>
      delegate.runUnlockedSync(callback, writable: writable);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void expectCleared(Iterable<Uint8List> buffers) {
  expect(
    buffers.every((bytes) => bytes.every((byte) => byte == 0)),
    isTrue,
    reason: 'Owned temporary key buffers must be cleared after use',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SodiumSumo sodium;
  late SecureKey key;
  late String encoded;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });
  setUp(() {
    key = sodium.crypto.secretBox.keygen();
    encoded = key.runUnlockedSync(base64Encode);
    FlutterSecureStorage.setMockInitialValues({
      MasterKeyStore.cacheName: encoded,
    });
  });
  tearDown(() => key.dispose());

  for (final failCopy in [false, true]) {
    test(
      'recovery import clears its decoded key when allocation fails=$failCopy',
      () {
        final observed = _CopyObserver(sodium, failCopy: failCopy);
        final store = MasterKeyStore(observed, Directory.systemTemp);
        if (failCopy) {
          expect(() => store.importRecovery(encoded), throwsStateError);
        } else {
          final recovered = store.importRecovery(encoded);
          try {
            expect(recovered.runUnlockedSync(base64Encode), encoded);
          } finally {
            recovered.dispose();
          }
        }
        expect(observed.buffers, hasLength(1));
        expectCleared(observed.buffers);
      },
    );

    test(
      'biometric cache clears its decoded key when allocation fails=$failCopy',
      () async {
        final observed = _CopyObserver(sodium, failCopy: failCopy);
        final store = MasterKeyStore(observed, Directory.systemTemp);
        if (failCopy) {
          await expectLater(store.cachedKey(), throwsStateError);
        } else {
          final recovered = (await store.cachedKey())!;
          try {
            expect(recovered.runUnlockedSync(base64Encode), encoded);
          } finally {
            recovered.dispose();
          }
        }
        expect(observed.buffers, hasLength(1));
        expectCleared(observed.buffers);
      },
    );

    test(
      'media decrypt clears its unwrapped file key when allocation fails=$failCopy',
      () async {
        final plain = Uint8List.fromList([1, 2, 3, 4]);
        final cipher = await VaultCrypto(sodium)
            .encrypt(Stream.value(plain), key)
            .fold(<int>[], (result, part) => result..addAll(part));
        final observed = _CopyObserver(sodium, failCopy: failCopy);
        final decrypt = VaultCrypto(observed)
            .decrypt(Stream.value(cipher), key)
            .fold(<int>[], (result, part) => result..addAll(part));
        if (failCopy) {
          await expectLater(decrypt, throwsStateError);
        } else {
          expect(await decrypt, plain);
        }
        expect(observed.buffers, hasLength(1));
        expectCleared(observed.buffers);
      },
    );
  }

  test('key formatting and fingerprinting leave no uncleared byte copies', () {
    final observed = _ExtractObserver(key);
    final store = MasterKeyStore(sodium, Directory.systemTemp);
    expect(store.exportRecovery(observed).replaceAll(' ', ''), encoded);
    expect(MasterKeyStore.archivePassword(observed), encoded);
    expect(store.fingerprint(observed), store.fingerprint(key));
    expectCleared(observed.buffers);
  });
}
