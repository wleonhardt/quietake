import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/camera/locked_capture_store.dart';
import 'package:quietake/cast/cast_backend.dart';
import 'package:quietake/crypto/pending_crypto.dart';
import 'package:quietake/cast/cast_controller.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/gallery/item.dart';
import 'package:quietake/media/media_server.dart';
import 'package:quietake/session.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:quietake/vault/pending_key_store.dart';
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

  test(
    'starting a session purges captures trashed more than 30 days ago',
    () async {
      final sodium = await SodiumSumoInit.init();
      final dir = await Directory.systemTemp.createTemp(
        'quietake-session-purge',
      );
      final key = sodium.crypto.secretBox.keygen();
      final seed = Vault(VaultCrypto(sodium), key.copy(), dir);
      final input = await File('${dir.path}/input').writeAsBytes([1, 2, 3]);
      final old = await seed.ingestAs(input, 'old.jpg');
      final input2 = await File('${dir.path}/input2').writeAsBytes([4, 5, 6]);
      final fresh = await seed.ingestAs(input2, 'fresh.jpg');
      await seed.trash(
        old,
        at: DateTime.now().subtract(const Duration(days: 31)),
      );
      await seed.trash(
        fresh,
        at: DateTime.now().subtract(const Duration(days: 1)),
      );
      await seed.catalog.close();
      seed.dispose();

      final session = await Session.start(
        MasterKeyStore(sodium, dir),
        key,
        FakeCastBackend(),
        vaultDir: dir,
      );
      try {
        expect(await old.exists(), isFalse);
        expect(await fresh.exists(), isTrue);
        expect(await session.vault.deletedNames(), {'old.jpg.shtr'});
        expect((await session.vault.trashedAt()).keys, ['fresh.jpg.shtr']);
      } finally {
        await session.close();
        await dir.delete(recursive: true);
      }
    },
  );

  test(
    'starting a session creates the key pair for captures taken while locked',
    () async {
      final sodium = await SodiumSumoInit.init();
      final dir = await Directory.systemTemp.createTemp(
        'quietake-session-pair',
      );
      final key = sodium.crypto.secretBox.keygen();
      final store = MasterKeyStore(sodium, dir);
      final session = await Session.start(
        store,
        key,
        FakeCastBackend(),
        vaultDir: dir,
      );
      try {
        Uint8List? pub;
        for (var i = 0; i < 50 && pub == null; i++) {
          pub = await PendingKeyStore(sodium, dir).publicKey();
          if (pub == null) {
            await Future<void>.delayed(const Duration(milliseconds: 20));
          }
        }
        expect(pub, isNotNull);
      } finally {
        await session.close();
        await dir.delete(recursive: true);
      }
    },
  );

  test('starting a session publishes captures sealed while locked', () async {
    final sodium = await SodiumSumoInit.init();
    final dir = await Directory.systemTemp.createTemp('quietake-session-pend');
    final key = sodium.crypto.secretBox.keygen();
    final keys = PendingKeyStore(sodium, dir);
    await keys.ensure(key);
    final locked = LockedCaptureStore(PendingCrypto(sodium), dir);
    await locked.save(
      await File('${dir.path}/c.jpg').writeAsBytes([7, 7, 7]),
      extension: 'jpg',
      publicKey: (await keys.publicKey())!,
    );
    final session = await Session.start(
      MasterKeyStore(sodium, dir),
      key,
      FakeCastBackend(),
      vaultDir: dir,
    );
    try {
      for (var i = 0; i < 100 && await locked.count() > 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(await locked.count(), 0);
      expect(await session.vault.list(), hasLength(1));
    } finally {
      await session.close();
      await dir.delete(recursive: true);
    }
  });
}
