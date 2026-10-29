import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/cast/cast_backend.dart';
import 'package:quietake/cast/cast_controller.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/gallery/item.dart';
import 'package:quietake/media/media_server.dart';
import 'package:quietake/session.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fake_cast_backend.dart';
import '../test_support/fixtures.dart';

/// Records disposal; the start path below never reads key bytes.
class _ObservedKey implements SecureKey {
  var disposed = false;
  @override
  void dispose() => disposed = true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('lock drops decrypted previews and ends an active cast', () async {
    final sodium = await SodiumSumoInit.init();
    final crypto = VaultCrypto(sodium);
    final dir = await Directory.systemTemp.createTemp('quietake-session');
    final vault = Vault(crypto, crypto.generateMasterKey(), dir);
    final backend = FakeCastBackend();
    final session = Session(
      vault: vault,
      server: await MediaServer.start(vault),
      cast: CastController(vault, backend),
      store: MasterKeyStore(sodium, dir),
    );
    try {
      final photo = VaultItem(
        await vault.ingestAs(
          File('${dir.path}/a.jpg')..writeAsBytesSync(fixtureBytes('tiny.jpg')),
          'a.jpg',
        ),
      );
      await session.previews.get(photo);
      expect(session.previews.retainedBytes, greaterThan(0));
      final lan = await MediaServer.lanAddress();
      if (lan != null) {
        await session.cast.start(const CastDevice('tv', 'TV'), photo);
        expect(session.cast.isCasting, isTrue);
      }
      await session.lock();
      expect(session.previews.retainedBytes, 0);
      expect(session.cast.isCasting, isFalse);
      if (lan != null) expect(backend.connected, isNull);
      // Still usable after unlock.
      await session.previews.get(photo);
      expect(session.previews.retainedBytes, greaterThan(0));
    } finally {
      await session.close();
      await dir.delete(recursive: true);
    }
  });

  test('a failed session start disposes the master key', () async {
    // No path_provider in a host test: Vault.defaultDir throws.
    final sodium = await SodiumSumoInit.init();
    final store = MasterKeyStore(sodium, Directory.systemTemp);
    final key = _ObservedKey();
    await expectLater(
      Session.start(store, key, FakeCastBackend()),
      throwsA(anything),
    );
    expect(key.disposed, isTrue);
  });
}
