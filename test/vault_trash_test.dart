import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/sync/sync_service.dart';
import 'package:quietake/sync/webdav_client.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fake_webdav_server.dart';

void main() {
  late Directory root;
  late Vault vault;
  late FakeWebDavServer server;
  late WebDavClient client;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('quietake-trash');
    final sodium = await SodiumSumoInit.init();
    vault = Vault(
      VaultCrypto(sodium),
      sodium.crypto.secretBox.keygen(),
      await Directory('${root.path}/vault').create(),
    );
    server = await FakeWebDavServer.start();
    server.collectionExists = true;
    client = WebDavClient(
      base: server.url,
      username: server.username,
      password: server.password,
    );
  });

  tearDown(() async {
    client.close();
    await server.close();
    await vault.catalog.close();
    vault.dispose();
    await root.delete(recursive: true);
  });

  Future<File> capture(String name) async {
    final source = await File('${root.path}/input').writeAsBytes([1, 2, 3]);
    return vault.ingestAs(source, name);
  }

  test('a trashed capture leaves the library and keeps its bytes', () async {
    final keep = await capture('keep.jpg');
    final gone = await capture('gone.jpg');
    final bytes = await gone.readAsBytes();

    await vault.trash(gone);

    expect((await vault.list()).map((f) => f.path), [keep.path]);
    expect(await gone.readAsBytes(), bytes);
    expect((await vault.trashedAt()).keys, ['gone.jpg.shtr']);
    // Trashing is not a deletion decision, so nothing is journaled.
    expect(await vault.deletedNames(), isEmpty);
  });

  test('restore brings a trashed capture back', () async {
    final file = await capture('back.jpg');
    await vault.trash(file);
    await vault.restore(file);

    expect((await vault.list()).map((f) => f.path), [file.path]);
    expect(await vault.trashedAt(), isEmpty);
  });

  test('purge deletes only captures trashed longer than 30 days', () async {
    final old = await capture('old.jpg');
    final fresh = await capture('fresh.jpg');
    final now = DateTime.utc(2026, 12, 1);
    await vault.trash(old, at: now.subtract(const Duration(days: 31)));
    await vault.trash(fresh, at: now.subtract(const Duration(days: 29)));

    expect(await vault.purgeTrash(now: now), 1);

    expect(await old.exists(), isFalse);
    expect(await vault.deletedNames(), {'old.jpg.shtr'});
    expect((await vault.trashedAt()).keys, ['fresh.jpg.shtr']);
    expect(await fresh.exists(), isTrue);
  });

  test('Delete now removes a trashed capture without waiting', () async {
    final file = await capture('now.jpg');
    await vault.trash(file);
    await vault.delete(file);

    expect(await file.exists(), isFalse);
    expect(await vault.trashedAt(), isEmpty);
    expect(await vault.deletedNames(), {'now.jpg.shtr'});
  });

  test('a file outside the vault cannot be trashed', () async {
    final outside = await File('${root.path}/x.jpg.shtr').writeAsBytes([1]);
    await expectLater(vault.trash(outside), throwsFormatException);
    expect(await Directory('${vault.dir.path}/.trash').exists(), isFalse);
  });

  test(
    'sync keeps the NAS copy of a trashed capture and does not pull it back',
    () async {
      final file = await capture('held.jpg');
      await SyncService(vault, client).sync();
      expect(server.files.keys, contains('held.jpg.shtr'));

      await vault.trash(file);
      server.log.clear();
      final report = await SyncService(vault, client).sync();
      // The held copy is not even downloaded.
      expect(
        server.log.where((l) => l.startsWith('GET') && l.contains('held')),
        isEmpty,
      );

      expect(server.files.keys, contains('held.jpg.shtr'));
      expect(report.pulled, 0);
      expect(report.deleted, 0);
      expect(await vault.list(), isEmpty);
      expect(await file.exists(), isTrue);
    },
  );

  test('purging a trashed capture lets sync remove the NAS copy', () async {
    final file = await capture('purged.jpg');
    await SyncService(vault, client).sync();
    await vault.trash(file, at: DateTime.utc(2026, 1, 1));

    expect(await vault.purgeTrash(now: DateTime.utc(2026, 12, 1)), 1);
    await SyncService(vault, client).sync();

    expect(server.files.keys, isNot(contains('purged.jpg.shtr')));
  });

  test('a restored capture is synced like any other', () async {
    final file = await capture('again.jpg');
    await vault.trash(file);
    await SyncService(vault, client).sync();
    expect(server.files.keys, isNot(contains('again.jpg.shtr')));

    await vault.restore(file);
    await SyncService(vault, client).sync();
    expect(server.files.keys, contains('again.jpg.shtr'));
  });
}
